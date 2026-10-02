extends Node

const FEEDBACK_SCRIPT := preload("res://scripts/vfx/combat_feedback.gd")
const SPAWNER_SCRIPT := preload("res://scripts/enemies/enemy_spawner.gd")
const NUMBER_SCRIPT := preload("res://scripts/vfx/damage_number.gd")
const MOBILE_SETTING := "crackveil/debug/force_mobile_lod"

class Target:
	extends Node2D
	var hit_radius: float = 13.0
	var hits: int = 0
	func take_damage(_amount: float, _position: Vector2 = Vector2.ZERO) -> void:
		hits += 1
	func get_hit_radius() -> float:
		return hit_radius

class LootObserver:
	extends Node
	var defeats: int = 0
	func on_enemy_defeated(_position: Vector2, _elite: bool, _boss: bool, _type_id: String) -> void:
		defeats += 1

var failed: bool = false
var feedback: Node2D
var spawner: Node2D


func _ready() -> void:
	EntityFactory.initialize_for_arena(self)
	GameManager.game_running = false
	GameManager.elapsed_time = 60.0
	GameManager.boss_active = false
	spawner = SPAWNER_SCRIPT.new()
	add_child(spawner)
	spawner.set_process(false)
	await get_tree().process_frame
	feedback = get_tree().get_first_node_in_group("combat_feedback")
	_assert(feedback != null, "spawner did not attach the single feedback batch")
	if failed:
		return
	await _test_impact_batch()
	await _test_feature_stagger_and_loot_guard()
	await _test_phase_volley_telegraph()
	_test_dash_interrupt()
	_test_pack_cap_and_formation()
	_test_damage_text_readability()
	if failed:
		return
	print("COMBAT_R32_REGRESSION_PASS")
	get_tree().quit(0)


func _test_impact_batch() -> void:
	for index in range(8):
		FEEDBACK_SCRIPT.report_hit(Vector2(float(index) * 12.0, 0.0), Vector2(-30.0, 0.0), 1.0, true, false)
	var state: Dictionary = feedback.get_debug_state()
	_assert(int(state["kills"]) == 8 and int(state["harvest_announcements"]) == 1, "lethal hit batch did not announce first cleave")
	await get_tree().create_timer(0.31).timeout
	state = feedback.get_debug_state()
	_assert(int(state["harvest_announcements"]) == 2, "eight kills did not escalate after announcement cooldown")
	_assert(is_equal_approx(Engine.time_scale, 1.0) and GameManager.get_time_scale_owner_count() == 0, "harvest feedback acquired a global slow-motion owner")
	for index in range(120):
		FEEDBACK_SCRIPT.report_hit(Vector2.ZERO, Vector2.LEFT, 0.5, false, false)
	state = feedback.get_debug_state()
	_assert(int(state["live_effects"]) <= int(state["effect_cap"]), "desktop impact effect cap exceeded")
	_assert(int(state["dropped_hit_effects"]) > 0, "crowd stress did not exercise cosmetic overflow")
	ProjectSettings.set_setting(MOBILE_SETTING, true)
	FEEDBACK_SCRIPT.report_hit(Vector2.ZERO, Vector2.LEFT, 0.5, false, false)
	state = feedback.get_debug_state()
	_assert(int(state["effect_cap"]) == 12 and int(state["live_effects"]) <= 12, "mobile impact effect cap exceeded")
	ProjectSettings.set_setting(MOBILE_SETTING, false)
	feedback.set_feedback_enabled(false)
	FEEDBACK_SCRIPT.report_hit(Vector2.ZERO, Vector2.LEFT, 1.0, true, false)
	state = feedback.get_debug_state()
	_assert(int(state["live_effects"]) == 0 and int(state["recent_kills"]) == 0, "disabled feedback retained effects or stale kill window")
	feedback.set_feedback_enabled(true)
	await get_tree().create_timer(0.05).timeout
	print("COMBAT_R32_BATCH kills=8 harvest_tiers=3/8 desktop_cap=28 mobile_cap=12 slowmo_owners=0 cosmetic_overflow=true")


func _test_feature_stagger_and_loot_guard() -> void:
	var observer := LootObserver.new()
	observer.add_to_group("loot_director")
	add_child(observer)
	var enemy: Node = EntityFactory.spawn_enemy("boss_stagger_test", _enemy_config(true), Vector2.ZERO)
	enemy.set_physics_process(false)
	var target := Target.new()
	target.position = Vector2(24.0, 0.0)
	add_child(target)
	_assert(bool(enemy.call("_start_attack", target, 1.0, &"contact")), "boss test attack failed to enter anticipation")
	var hp_before := float(enemy.get("hp"))
	_assert(float(enemy.take_damage(-25.0, Vector2.LEFT)) == 0.0 and is_equal_approx(float(enemy.get("hp")), hp_before), "negative hit healed enemy or emitted damage")
	enemy.take_damage(1.0, Vector2.LEFT)
	_assert(StringName(enemy.get("current_animation_name")) == &"attack", "chip damage interrupted a feature enemy attack")
	await get_tree().create_timer(0.23).timeout
	_assert(target.hits == 1 and int(enemy.get("attack_impact_count")) == 1, "feature enemy lost its impact frame under chip damage")
	await get_tree().create_timer(0.34).timeout
	enemy.take_damage(1.0, Vector2.LEFT)
	_assert(StringName(enemy.get("current_animation_name")) == &"hurt", "feature enemy lost its articulated hurt reaction")
	await get_tree().create_timer(0.29).timeout
	enemy.call("_start_attack", target, 1.0, &"contact")
	enemy.take_damage(1.0, Vector2.LEFT)
	_assert(StringName(enemy.get("current_animation_name")) == &"attack", "stagger guard failed on rapid repeated damage")
	# Use a regular enemy for the reward hook: boss victory is a separate arena
	# contract and intentionally pauses the simulation.
	EntityFactory.release_enemy(enemy)
	enemy = EntityFactory.spawn_enemy("loot_guard_test", _enemy_config(false), Vector2.ZERO)
	enemy.set_physics_process(false)
	enemy.take_damage(9999.0, Vector2.LEFT)
	_assert(StringName(enemy.get("current_animation_name")) == &"death" and bool(enemy.get("is_dying")), "lethal impact skipped the death poses")
	_assert(observer.defeats == 0, "loot rolled before death animation completed")
	await get_tree().create_timer(0.67).timeout
	_assert(observer.defeats == 1, "pooled enemy death awarded loot more or less than once")
	var reused: Node = EntityFactory.spawn_enemy("loot_reuse_test", _enemy_config(false), Vector2.ZERO)
	reused.set_physics_process(false)
	reused.take_damage(9999.0, Vector2.LEFT)
	await get_tree().create_timer(0.67).timeout
	_assert(observer.defeats == 2, "pool reuse did not reset the one-defeat reward guard")
	observer.queue_free()
	target.queue_free()
	print("COMBAT_R32_FEATURE negative_damage=ignored chip_attack_interrupt=0 impact_frame=2 hurt_poses=true loot_per_lifetime=1")


func _enemy_config(boss: bool) -> Dictionary:
	return {"max_hp": 100.0, "speed": 0.0, "damage": 1.0, "xp": 0, "gold": 0, "radius": 13.0, "attack_cooldown": 0.1, "sprite_path": "res://assets/sprites/enemy_boss.png" if boss else "res://assets/sprites/enemy_grunt.png", "is_boss": boss}


func _test_phase_volley_telegraph() -> void:
	var enemy: Node = EntityFactory.spawn_enemy("phase_volley_test", _enemy_config(true), Vector2.ZERO)
	enemy.set_physics_process(false)
	var before := EntityFactory.get_pool_live_count("projectile")
	enemy.call("_trigger_boss_phase_two")
	var cue: Line2D = enemy.get("attack_cue")
	var ground_cue: Node = enemy.get("attack_telegraph")
	_assert(cue.visible and cue.closed and ground_cue != null and bool(ground_cue.get("active")) and str(ground_cue.get("kind")) == "ring", "boss phase did not show its radial ground anticipation cue")
	_assert(EntityFactory.get_pool_live_count("projectile") == before, "phase volley fired immediately on the HP transition")
	await get_tree().create_timer(0.11).timeout
	_assert(EntityFactory.get_pool_live_count("projectile") == before, "phase volley fired during anticipation")
	await get_tree().create_timer(0.12).timeout
	_assert(EntityFactory.get_pool_live_count("projectile") == before + 14 and not cue.visible, "phase volley did not release fourteen projectiles on frame 2")
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		EntityFactory.release_projectile(projectile)
	EntityFactory.release_enemy(enemy)
	print("COMBAT_R32_PHASE anticipation_projectiles=0 impact_frame=2 projectiles=14 telegraph=radial")


func _test_pack_cap_and_formation() -> void:
	spawner.max_enemies = EntityFactory.get_enemy_live_count() + 7
	var spawned := int(spawner.call("_spawn_harvest_pack"))
	_assert(spawned == 7 and EntityFactory.get_enemy_live_count() == spawner.max_enemies, "pack spawn did not honor available cap")
	_assert(int(spawner.call("_spawn_harvest_pack")) == 0, "full enemy cap allowed another harvest pack")
	var harvest: Array[Node] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if str(enemy.get("type_id")) == "harvest_grunt":
			harvest.append(enemy)
	for enemy in harvest:
		for other in harvest:
			_assert(enemy.global_position.distance_to(other.global_position) < 140.0, "pack spread escaped a normal cleave area")
	_assert(harvest.size() == 7, "harvest pack lost its enemy identity")
	# Boss insertion must reclaim a remote regular enemy at the same cap.
	spawner.call("_spawn_boss")
	_assert(bool(spawner.boss_spawned) and EntityFactory.get_enemy_live_count() == spawner.max_enemies, "boss could not enter a saturated arena")
	print("COMBAT_R32_PACK count=7 span<140 hard_cap=true boss_reclaims_one=true")


func _test_dash_interrupt() -> void:
	var config := _enemy_config(false)
	config["behavior_id"] = "dasher"
	var enemy: Node = EntityFactory.spawn_enemy("dash_interrupt_test", config, Vector2.ZERO)
	enemy.set_physics_process(false)
	var target := Target.new()
	target.position = Vector2(120.0, 0.0)
	add_child(target)
	enemy.call("_physics_dasher", 0.0, target)
	var cue: Line2D = enemy.get("attack_cue")
	_assert(str(enemy.get("behavior_state")) == "windup" and cue.visible, "dash did not expose its locked direction before charging")
	enemy.take_damage(1.0, Vector2.LEFT)
	_assert(str(enemy.get("behavior_state")) == "recover" and not cue.visible, "interrupted dash retained an invisible pending charge")
	EntityFactory.release_enemy(enemy)
	target.queue_free()
	print("COMBAT_R32_DASH telegraph=locked_direction interrupted_windup=recover invisible_resume=false")


func _test_damage_text_readability() -> void:
	var number := NUMBER_SCRIPT.new()
	add_child(number)
	number.pool_on_acquire()
	seed(85493)
	var expected_random := randf()
	seed(85493)
	number.pool_reset({"value": "SLAUGHTER ×128", "position": Vector2.ZERO, "color": Color.WHITE, "font_size": 27})
	_assert(is_equal_approx(randf(), expected_random), "cosmetic damage number advanced gameplay RNG")
	var value_label: Label = number.value_label
	_assert(value_label.size.x > 128.0 and value_label.size.x <= 420.0, "long harvest caption is clipped by old fixed width")
	_assert(number.lifetime > 0.62 and number.scale.x > 1.0, "harvest caption lost its readable hold or pop")
	number.pool_on_release()
	_assert(number.scale == Vector2.ONE, "damage number pool reuse leaked previous pop scale")
	number.queue_free()
	print("COMBAT_R32_TEXT caption_width=dynamic outline=true hold=0.86 pop_reset=true gameplay_rng_unchanged=true")


func _assert(condition: bool, message: String) -> void:
	if condition or failed:
		return
	failed = true
	printerr("COMBAT_R32_REGRESSION_FAIL: " + message)
	get_tree().quit(1)
