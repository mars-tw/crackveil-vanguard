extends Node

const HERO_SCENE := preload("res://scenes/heroes/Hero.tscn")
const CAPTAIN_DATA := preload("res://resources/heroes/rift_captain.tres")
const FEEDBACK_SCRIPT := preload("res://scripts/vfx/combat_feedback.gd")

var hero: Node2D
var feedback: Node2D
var failed: bool = false
var impacts: int = 0
var impact_frames: Array[int] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameManager.game_running = false
	EntityFactory.initialize_for_arena(self)
	feedback = FEEDBACK_SCRIPT.new()
	add_child(feedback)
	hero = HERO_SCENE.instantiate()
	add_child(hero)
	hero.setup(CAPTAIN_DATA, null, true, 0)
	hero.set_physics_process(false)
	for controller in hero.get_children():
		if controller.is_in_group("hero_controllers"):
			controller.set_process(false)
			controller.set_physics_process(false)
	for weapon in (hero.get("weapons") as Dictionary).values():
		weapon.set_process(false)
		weapon.set_physics_process(false)
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.set_physics_process(false)
	GameManager.player = hero
	GameManager.squad_manager = null
	GameManager.waiting_for_upgrade = false
	GameManager.waiting_for_contract = false
	GameManager.waiting_for_shop = false
	GameManager.manual_paused = false
	GameManager.system_pause_owners.clear()
	GameManager.xp_required = 999999
	get_tree().paused = false
	GameManager.game_running = true
	hero.get_node("Visual").attack_impact.connect(_on_impact)
	# Atlas upload/prewarm can make the first unbounded headless frame long.
	# Begin timing only after the setup frame has been processed, not inside
	# that frame with a delta that also includes resource/scene construction.
	for frame in range(3):
		await get_tree().process_frame
	await _test_fan_impact()
	await _test_auto_and_buffer()
	await _test_momentum_and_pool()
	await _test_delayed_reclaim()
	_test_first_run_projectile()
	_test_mobile_slash_projection()
	_test_capped_feedback()
	if failed:
		return
	print("COMBAT_R33_PASS frame2=true auto_cleave=true space_buffer=true momentum=50_percent cone=true effects_capped=true projectile=data_damage_and_pierce")
	get_tree().quit(0)


func _test_fan_impact() -> void:
	hero.set("auto_cleave_cooldown_timer", 999.0)
	var front: Array[Node] = []
	for position in [Vector2(100.0, 0.0), Vector2(130.0, -65.0), Vector2(130.0, 65.0), Vector2(170.0, 90.0), Vector2(230.0, 0.0)]:
		front.append(_enemy(position, 24.0))
	var rear := _enemy(Vector2(-160.0, 0.0), 24.0)
	var remote := _enemy(Vector2(Hero.RIFT_PULSE_RANGE + 60.0, 0.0), 24.0)
	# The first enemy SpriteFrames creation can also occur lazily on spawn.
	for frame in range(3):
		await get_tree().process_frame
	_assert(bool(hero.try_cast_active_ability()), "Space did not begin the authored anticipation")
	_assert(impacts == 0, "Space damaged on input rather than impact")
	for enemy in front:
		_assert(float(enemy.get("hp")) == 24.0, "trash HP changed before frame 2")
	await get_tree().create_timer(0.055, true, false, true).timeout
	_assert(impacts == 0, "Space skipped its visible anticipation poses")
	await get_tree().create_timer(0.24, true, false, true).timeout
	_assert(impacts == 1 and impact_frames[0] == 2, "Space did not apply once at frame 2")
	for enemy in front:
		_assert(bool(enemy.get("is_dying")) and str(enemy.get("current_animation_name")) == "death", "fan failed to clear a front trash body with true death poses")
	_assert(float(rear.get("hp")) == 24.0 and float(remote.get("hp")) == 24.0, "fan damaged outside its directional footprint")
	_assert(int(hero.get_cleave_debug_state()["active_hits"]) == 5, "wide fan lost one of its five targets")
	_assert(not bool(hero.try_cast_active_ability()), "Space recast bypassed the shortened cooldown")
	_assert(is_equal_approx(float(hero.get_active_ability_cooldown_duration()), 2.35), "R33 active cooldown drifted")
	EntityFactory.release_enemy(rear)
	EntityFactory.release_enemy(remote)
	await get_tree().create_timer(0.6, true, false, true).timeout
	_assert(GameManager.get_time_scale_owner_count() == 0 and is_equal_approx(Engine.time_scale, 1.0), "cut left a global hitstop owner alive")
	print("COMBAT_R33_FAN targets=5 instant_damage=0 impact_frame=2 death_poses=true outside_cone=ignored cooldown=2.35")


func _test_auto_and_buffer() -> void:
	var target := _enemy(Vector2(90.0, 0.0), 300.0)
	hero.set("active_ability_cooldown_timer", 0.0)
	hero.set("auto_cleave_cooldown_timer", 0.0)
	hero.call("_tick_captain_cleave", 0.0)
	_assert(bool(hero.get("auto_cleave_pending")), "nearest close enemy did not earn an automatic slash")
	_assert(float(target.get("hp")) == 300.0, "automatic slash damaged during anticipation")
	_assert(bool(hero.try_cast_active_ability()) and bool(hero.get("active_ability_queued")), "Space was swallowed while automatic slash was in recovery")
	_assert(not bool(hero.try_cast_active_ability()), "one buffered Space allowed duplicate queue entries")
	hero.set("auto_cleave_cooldown_timer", 999.0)
	var casts_before := int(hero.get_active_ability_cast_count())
	await get_tree().create_timer(0.9, true, false, true).timeout
	_assert(int(hero.get_cleave_debug_state()["auto_cuts"]) == 1, "automatic swing emitted duplicate damage events")
	_assert(int(hero.get_active_ability_cast_count()) == casts_before + 1, "buffered Space did not start a new real attack")
	_assert(int(hero.get_cleave_debug_state()["active_hits"]) == 6, "buffered Space missed the still-living target")
	_assert(not bool(hero.get("active_ability_queued")) and not bool(hero.get("active_ability_pending")), "buffered attack remained armed after impact")
	EntityFactory.release_enemy(target)
	print("COMBAT_R33_BUFFER auto_impact_once=true space_during_recovery=queued next_frame2_hit=true duplicate_queue=false")


func _test_momentum_and_pool() -> void:
	await get_tree().create_timer(0.4, true, false, true).timeout
	var target := _enemy(Vector2(100.0, 0.0), 300.0)
	hero.set("active_ability_cooldown_timer", 0.0)
	hero.set("auto_cleave_cooldown_timer", 999.0)
	hero.set_desired_velocity(Vector2.RIGHT * 230.0)
	hero.call("_tick_captain_cleave", 1.2)
	_assert(is_equal_approx(float(hero.get("momentum_charge")), 1.0), "ordinary movement failed to charge the next draw cut")
	hero.set_desired_velocity(Vector2.ZERO)
	var hp_before := float(target.get("hp"))
	_assert(bool(hero.try_cast_active_ability()), "charged Space failed to start")
	_assert(is_equal_approx(float(hero.get("momentum_charge")), 0.0), "charged swing did not consume its charge")
	await get_tree().create_timer(0.35, true, false, true).timeout
	var charged_damage := hp_before - float(target.get("hp"))
	_assert(charged_damage >= 107.9, "full charge did not deliver 50 percent more actual damage")
	var stale_token := int(target.get_hit_token())
	EntityFactory.release_enemy(target)
	var reused := _enemy(Vector2(500.0, 0.0), 300.0)
	_assert(int(reused.get_hit_token()) != stale_token, "enemy pool token was not renewed")
	await get_tree().create_timer(0.35, true, false, true).timeout
	_assert(float(reused.get("hp")) == 300.0, "finished cut damaged a recycled enemy generation")
	EntityFactory.release_enemy(reused)
	print("COMBAT_R33_MOMENTUM charge_seconds=1.15 damage=%.1f charge_consumed=true pool_generation_safe=true" % charged_damage)


func _test_first_run_projectile() -> void:
	var weapon: Node = (hero.get("weapons") as Dictionary).get("riftline_emitter")
	var stats: Dictionary = weapon.call("_projectile_stats_for_fire")
	_assert(float(stats.get("damage")) >= float(weapon.call("data_float", "damage", 0.0)) and int(stats.get("pierce")) == int(weapon.call("data_int", "pierce", 0)) and int(stats.get("pierce")) > 0, "first-run dart diverged from real damage/pierce data")
	var dart: Node = EntityFactory.spawn_projectile(Vector2.ZERO, Vector2.RIGHT, stats, hero)
	_assert(bool(dart.call("_uses_hard_dart")), "captain projectile did not switch to the short solid dart")
	_assert(not (dart.get("glow") as Sprite2D).visible and not (dart.get("trail") as Line2D).visible, "solid dart retained the long additive cyan fog")
	EntityFactory.release_projectile(dart)
	var enemy_stats := stats.duplicate(true)
	enemy_stats["target_group"] = "heroes"
	var hostile: Node = EntityFactory.spawn_projectile(Vector2.ZERO, Vector2.RIGHT, enemy_stats, null)
	_assert(not bool(hostile.call("_uses_hard_dart")), "hostile shot acquired the friendly blade silhouette")
	EntityFactory.release_projectile(hostile)
	print("COMBAT_R33_DART base_damage=%.1f pierce=%d speed=%.1f long_bloom=false enemy_shape=distinct" % [float(stats.get("damage")), int(stats.get("pierce")), float(stats.get("projectile_speed"))])


func _test_delayed_reclaim() -> void:
	hero.set("active_ability_cooldown_timer", 0.0)
	hero.set("auto_cleave_cooldown_timer", 999.0)
	var enemy := _enemy(Vector2(250.0, 0.0), 24.0)
	enemy.set("xp_value", 10)
	_assert(bool(hero.try_cast_active_ability()), "reclaim test cut did not start")
	await get_tree().create_timer(0.35, true, false, true).timeout
	_assert(EntityFactory.get_pool_live_count("xp_gem") == 0, "XP reward appeared before the death poses ended")
	await get_tree().create_timer(0.57, true, false, true).timeout
	var found_forced_gem := false
	for pickup in get_tree().get_nodes_in_group("pickups"):
		if str(pickup.get("pickup_kind")) == "xp" and pickup.get("forced_collector") == hero and pickup.get("magnetized") == true:
			found_forced_gem = true
	_assert(found_forced_gem, "delayed cut reclaim missed XP generated by the finished death poses")
	print("COMBAT_R33_RECLAIM reward_after_death=true delayed_vacuum=0.7_seconds forced_collector=true")


func _test_capped_feedback() -> void:
	for index in range(90):
		FEEDBACK_SCRIPT.report_slash(Vector2.ZERO, Vector2.RIGHT, 270.0, deg_to_rad(69.0), true)
	var state: Dictionary = feedback.get_debug_state()
	_assert(int(state["live_effects"]) <= int(state["effect_cap"]), "anime slash overflow bypassed the existing impact budget")
	ProjectSettings.set_setting("crackveil/debug/force_mobile_lod", true)
	FEEDBACK_SCRIPT.report_slash(Vector2.ZERO, Vector2.RIGHT, 270.0, deg_to_rad(69.0), true)
	state = feedback.get_debug_state()
	_assert(int(state["live_effects"]) <= 12, "mobile large cuts exceeded the twelve-effect batch")
	ProjectSettings.set_setting("crackveil/debug/force_mobile_lod", false)
	print("COMBAT_R33_VFX desktop_cap=28 mobile_cap=12 composite_cut=true")


func _test_mobile_slash_projection() -> void:
	ProjectSettings.set_setting("crackveil/debug/force_mobile_lod", false)
	_assert(feedback.get_slash_visual_scale() == Vector2.ONE, "desktop cut acquired the mobile projection")
	ProjectSettings.set_setting("crackveil/debug/force_mobile_lod", true)
	var projection: Vector2 = feedback.get_slash_visual_scale()
	_assert(is_equal_approx(projection.x, 0.84) and is_equal_approx(projection.y, 0.504), "mobile cut did not compress its full canvas around the cast origin")
	FEEDBACK_SCRIPT.report_slash(Vector2(430.0, 320.0), Vector2.UP, 270.0, deg_to_rad(69.0), true)
	var effect: Dictionary = (feedback.get("effects") as Array).back()
	_assert(effect["position"] == Vector2(430.0, 320.0) and effect["direction"] == Vector2.UP and float(effect["size"]) == 270.0, "visual projection modified the source direction or gameplay-size contract")
	var up_visual_tip := Vector2.UP * 270.0 * projection
	_assert(absf(up_visual_tip.y) < 150.0, "up-facing mobile blade still escaped the short viewport")
	ProjectSettings.set_setting("crackveil/debug/force_mobile_lod", false)
	print("COMBAT_R33_MOBILE_SLASH world_origin=stable direction=up gameplay_radius=270 visual_scale=0.84/0.504 up_visual_tip=136.08")


func _enemy(position: Vector2, hp: float) -> Node:
	var enemy: Node = EntityFactory.spawn_enemy("r33_blade_target", {"max_hp": hp, "speed": 0.0, "damage": 0.0, "xp": 0, "gold": 0, "radius": 13.0, "sprite_path": "res://assets/sprites/enemy_grunt.png"}, position)
	enemy.set_physics_process(false)
	return enemy


func _on_impact() -> void:
	impacts += 1
	impact_frames.append((hero.get_node("Visual").get("animated_sprite") as AnimatedSprite2D).frame)


func _assert(condition: bool, message: String) -> void:
	if condition or failed:
		return
	failed = true
	printerr("COMBAT_R33_FAIL: " + message)
	get_tree().quit(1)
