extends Node

const CATALOG := preload("res://scripts/services/stage_catalog.gd")
const HERO_SCENE := preload("res://scenes/heroes/Hero.tscn")
const CAPTAIN := preload("res://resources/heroes/rift_captain.tres")
const SPAWNER := preload("res://scripts/enemies/enemy_spawner.gd")
const BASE_COUNTS := [12, 7, 9, 10, 12, 15, 15, 12, 12, 16]
const PHASE_COUNTS := [12, 11, 16, 20, 18, 19, 21, 18, 24, 24]

class Bounds:
	extends Node2D
	func get_map_world_rect() -> Rect2:
		return Rect2(Vector2(-648.0, -369.0), Vector2(1240.0, 790.0))
	func get_playable_rect() -> Rect2:
		return Rect2(Vector2(-338.0, -171.5), Vector2(620.0, 395.0))

var failed := false
var hero: Node2D
var fixture_arena: Node2D


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	GameManager.campaign_save_path = "user://r34_independent_stage_probe.cfg"
	MetaProgress.save_path = "user://r34_independent_stage_meta.cfg"
	AchievementProgress.save_path = "user://r34_independent_stage_achievements.cfg"
	GameManager.game_running = false
	EntityFactory.initialize_for_arena(self)
	fixture_arena = Node2D.new()
	add_child(fixture_arena)
	var background := Bounds.new()
	background.name = "Background"
	fixture_arena.add_child(background)
	GameManager.arena = fixture_arena
	hero = HERO_SCENE.instantiate()
	add_child(hero)
	hero.setup(CAPTAIN, null, true, 0)
	hero.set_process(false)
	hero.set_physics_process(false)
	for child in hero.get_children():
		if child.is_in_group("hero_controllers"):
			child.set_process(false)
			child.set_physics_process(false)
	for weapon in (hero.get("weapons") as Dictionary).values():
		weapon.set_process(false)
		weapon.set_physics_process(false)
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.set_physics_process(false)
	GameManager.player = hero
	GameManager.squad_manager = null
	GameManager.game_running = true
	get_tree().paused = false
	for frame in range(3):
		await get_tree().process_frame
	await _test_six_patterns()
	_test_dash_pool_reuse()
	_test_campaign_reset()
	await _test_finite_camera()
	if failed:
		return
	print("INDEPENDENT_STAGE_R34_PASS six_patterns=real_frame2 frost_slow=true dash_pool_safe=true campaign_reset=true finite_camera=true")
	get_tree().quit(0)


func _test_six_patterns() -> void:
	var fingerprints: Dictionary = {}
	var stages := CATALOG.get_stages()
	for index in range(stages.size()):
		var stage: Dictionary = stages[index]
		GameManager.select_stage(str(stage.id))
		GameManager.boss_phase_two_time = -1.0
		hero.global_position = Vector2(240.0, 0.0)
		var boss: Node = EntityFactory.spawn_enemy("independent_stage_boss", CATALOG.get_boss_config(str(stage.id)), Vector2.ZERO)
		boss.set_physics_process(false)
		for frame in range(3):
			await get_tree().process_frame
		fingerprints[JSON.stringify(boss.call("_boss_shot_plan"))] = true
		_assert(bool(boss.call("_start_attack", hero, 0.82, &"ring")), "boss anticipation failed: " + str(stage.id))
		_assert(EntityFactory.get_pool_live_count("projectile") == 0, "boss fired on input: " + str(stage.id))
		await get_tree().create_timer(0.075).timeout
		_assert(EntityFactory.get_pool_live_count("projectile") == 0, "boss fired before impact poses: " + str(stage.id))
		await get_tree().create_timer(0.16).timeout
		_assert(EntityFactory.get_pool_live_count("projectile") == int(BASE_COUNTS[index]) and int(boss.get("attack_impact_count")) == 1, "boss frame 2 volley count mismatch: " + str(stage.id))
		_clear_shots()
		await get_tree().process_frame
		await get_tree().create_timer(0.36).timeout
		boss.call("_trigger_boss_phase_two")
		_assert(EntityFactory.get_pool_live_count("projectile") == 0, "boss phase transition fired without anticipation: " + str(stage.id))
		await get_tree().create_timer(0.075).timeout
		_assert(EntityFactory.get_pool_live_count("projectile") == 0, "phase volley skipped anticipation: " + str(stage.id))
		await get_tree().create_timer(0.16).timeout
		_assert(EntityFactory.get_pool_live_count("projectile") == int(PHASE_COUNTS[index]), "phase 2 did not use its real stage pattern: " + str(stage.id))
		if str(stage.id) == "frost":
			hero.global_position = Vector2(20.0, 0.0)
			hero.set("movement_slow_timer", 0.0)
			hero.set("movement_slow_strength", 0.0)
			boss.call("_tick_affix", 0.13)
			_assert(float(hero.get("movement_slow_strength")) >= 0.219, "Frost radius existed but its slow was not applied")
		_clear_shots()
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy != boss:
				EntityFactory.release_enemy(enemy)
		EntityFactory.release_enemy(boss)
		await get_tree().process_frame
		print("INDEPENDENT_STAGE_R34_PATTERN %s base=%d phase2=%d anticipation_zero=true true_impact=true" % [str(stage.pattern), int(BASE_COUNTS[index]), int(PHASE_COUNTS[index])])
	_assert(fingerprints.size() == CATALOG.get_stages().size(), "six bosses share the same projectile plan")


func _test_dash_pool_reuse() -> void:
	var regular_config: Dictionary = SPAWNER.ENEMY_CONFIGS["dasher"].duplicate(true)
	var prior: Node = EntityFactory.spawn_enemy("previous_dasher", regular_config, Vector2.ZERO)
	var instance := prior.get_instance_id()
	EntityFactory.release_enemy(prior)
	var stage_config := CATALOG.get_boss_config("storm")
	var boss: Node = EntityFactory.spawn_enemy("storm_reused", stage_config, Vector2.ZERO)
	boss.set_physics_process(false)
	_assert(boss.get_instance_id() == instance, "reuse exercise did not obtain the same enemy instance")
	_assert(str(boss.get("boss_pattern")) == "storm_star" and bool(boss.get("boss_dash")) and int(boss.get("boss_volley_index")) == 0 and int(boss.get("boss_projectiles_fired")) == 0, "boss fields survived the previous pool generation")
	for key in ["dash_trigger_range", "dash_windup", "dash_duration", "dash_recover", "dash_speed"]:
		_assert(stage_config.has(key) and is_equal_approx(float(boss.get(key)), float(stage_config.get(key, -1.0))), "boss inherited previous regular dash property: " + key)
	EntityFactory.release_enemy(boss)
	print("INDEPENDENT_STAGE_R34_POOL same_instance=true pattern_reset=true dash_properties=explicit")


func _test_campaign_reset() -> void:
	GameManager.campaign_clears.clear()
	GameManager.select_stage("moon")
	GameManager.boss_killed = false
	GameManager.record_boss_kill()
	GameManager.record_boss_kill()
	_assert(GameManager.campaign_clears == ["moon"] and GameManager.stage_victory_pending and get_tree().paused, "boss clear was duplicated or did not pause at victory")
	GameManager.waiting_for_shop = true
	GameManager.waiting_for_upgrade = true
	GameManager.waiting_for_contract = true
	GameManager.touch_move_vector = Vector2.RIGHT
	GameManager.acquire_time_scale("stale_probe_owner", 0.2)
	var old_token := int(GameManager.run_token)
	GameManager.select_stage("garden")
	GameManager.tactical_launch = false
	GameManager.start_run(fixture_arena, hero, null, false)
	_assert(GameManager.game_running and not get_tree().paused and not GameManager.waiting_for_shop and not GameManager.waiting_for_upgrade and not GameManager.waiting_for_contract and not GameManager.stage_victory_pending and not GameManager.boss_killed, "new stage retained prior modal/victory state")
	_assert(GameManager.get_time_scale_owner_count() == 0 and is_equal_approx(Engine.time_scale, 1.0) and GameManager.touch_move_vector == Vector2.ZERO and int(GameManager.run_token) == old_token + 1, "new run retained old input/timer ownership")
	_assert(CATALOG.get_next_stage_id("forge") == "" and not GameManager.select_stage("not_a_stage"), "final/invalid stage transitions are not bounded")
	print("INDEPENDENT_STAGE_R34_CAMPAIGN boss_award_once=true pause=true fresh_run_modals=0 time_owners=0 touch=zero run_token=renewed")


func _test_finite_camera() -> void:
	var background: Node = fixture_arena.get_node("Background")
	var bounds: Rect2 = background.get_map_world_rect()
	var playable: Rect2 = background.get_playable_rect().grow(-12.0)
	hero.global_position = Vector2(9999.0, -9999.0)
	hero.call("_constrain_to_stage")
	_assert(hero.global_position.is_equal_approx(Vector2(playable.end.x, playable.position.y)), "hero collider was not constrained to finite ground")
	for size in [Vector2i(1280, 720), Vector2i(844, 390), Vector2i(390, 844)]:
		get_viewport().size = size
		await get_tree().process_frame
		await get_tree().process_frame
		var zoom: Vector2 = hero.call("_fit_stage_camera", Vector2.ONE * 1.28)
		var actual_viewport: Vector2 = hero.get_viewport_rect().size
		var view: Vector2 = actual_viewport / zoom
		_assert(absf(actual_viewport.x / actual_viewport.y - float(size.x) / float(size.y)) < 0.01, "fixture resize did not create the requested camera aspect ratio")
		_assert(view.x <= bounds.size.x and view.y <= bounds.size.y, "camera view exposes an area larger than the complete map: " + str(size))
		var camera: Camera2D = hero.get("camera")
		_assert(camera.limit_left == ceili(bounds.position.x) and camera.limit_right == floori(bounds.end.x) and camera.limit_top == ceili(bounds.position.y) and camera.limit_bottom == floori(bounds.end.y), "camera limits do not match shifted map bounds")
		print("INDEPENDENT_STAGE_R34_CAMERA requested=%s internal=%s zoom=%s visible_world=%s" % [size, actual_viewport, zoom, view])
	print("INDEPENDENT_STAGE_R34_BOUNDS shifted_map=true collider_clamp=true landscape_and_portrait_view_fit=true")


func _clear_shots() -> void:
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		if str(projectile.get("target_group")) == "heroes":
			EntityFactory.release_projectile(projectile)


func _assert(condition: bool, message: String) -> void:
	if condition or failed:
		return
	failed = true
	printerr("INDEPENDENT_STAGE_R34_FAIL: " + message)
	get_tree().quit(1)
