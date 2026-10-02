extends Node2D

const SPAWNER := preload("res://scripts/enemies/enemy_spawner.gd")

var failed: bool = false
var spawner: Node2D
var camera: Camera2D
var camera_viewport: SubViewport

func _ready() -> void:
	GameManager.game_running = false
	GameManager.player = null
	GameManager.squad_manager = null
	GameManager.loot_director = null
	GameManager.boss_active = false
	EntityFactory.initialize_for_arena(self)
	camera_viewport = SubViewport.new()
	camera_viewport.size = Vector2i(1280, 720)
	add_child(camera_viewport)
	spawner = SPAWNER.new()
	camera_viewport.add_child(spawner)
	spawner.set_process(false)
	camera = Camera2D.new()
	camera.position = Vector2(400.0, -250.0)
	camera.zoom = Vector2(1.28, 1.28)
	camera.offset = Vector2(12.0, -8.0)
	camera_viewport.add_child(camera)
	camera.make_current()
	camera.force_update_scroll()
	await get_tree().process_frame
	_test_cadence()
	_test_camera_boundaries_and_seed()
	_test_reclamation_and_cap()
	if not failed:
		print("SPAWN_DENSITY_R32_PASS")
		get_tree().quit(0)

func _test_cadence() -> void:
	var previous_rate := 0.0
	for elapsed in [10.0, 29.9, 30.0, 37.0, 55.0, 68.0, 99.0, 109.0, 120.0, 180.0]:
		var cadence: Dictionary = spawner.call("_spawn_cadence", elapsed, false)
		var rate := float(cadence["count"]) / float(cadence["interval"])
		_check(rate >= previous_rate, "encounter flow dropped at %.1f seconds" % elapsed)
		previous_rate = rate
		var boss_cadence: Dictionary = spawner.call("_spawn_cadence", elapsed, true)
		var boss_rate := float(boss_cadence["count"]) / float(boss_cadence["interval"])
		_check(boss_rate < rate * 0.65, "boss pressure reduction lost at %.1f seconds" % elapsed)
	var before: Dictionary = spawner.call("_spawn_cadence", 29.9, false)
	var after: Dictionary = spawner.call("_spawn_cadence", 30.0, false)
	_check(int(before["count"]) == 6 and int(after["count"]) == 6 and absf(float(before["interval"]) - float(after["interval"])) < 0.005, "30 second cadence seam is not continuous")
	_check(float(after["count"]) / float(after["interval"]) >= 18.0, "R34 horde flow is below 18 enemies per second")
	print("SPAWN_DENSITY_CADENCE R34 t30=5/0.270 boss_rate<65% baseline_monotonic=true")

func _test_camera_boundaries_and_seed() -> void:
	for spec in [{"size": Vector2i(1280, 720), "zoom": 1.28}, {"size": Vector2i(1280, 720), "zoom": 1.12}, {"size": Vector2i(390, 844), "zoom": 1.56}, {"size": Vector2i(844, 390), "zoom": 1.56}]:
		camera_viewport.size = spec["size"]
		camera.zoom = Vector2.ONE * float(spec["zoom"])
		camera.force_update_scroll()
		_check_one_camera_shape()
	camera_viewport.size = Vector2i(1280, 720)
	camera.zoom = Vector2(1.28, 1.28)
	camera.force_update_scroll()

func _check_one_camera_shape() -> void:
	var world_view: Rect2 = spawner.call("_get_world_view_rect")
	var expected_size := spawner.get_viewport_rect().size / camera.zoom
	_check(world_view.size.is_equal_approx(expected_size), "spawn bounds still use viewport pixels instead of camera world units")
	_check(world_view.get_center().distance_to(camera.get_screen_center_position()) < 0.1, "spawn bounds ignore the actual camera center/offset")
	var first := PackedVector2Array()
	seed(9137)
	for index in range(64):
		var point: Vector2 = spawner.call("_get_spawn_position")
		first.append(point)
		_check(not world_view.has_point(point), "enemy spawned in the visible camera rectangle")
		_check(world_view.grow(spawner.spawn_margin + 0.1).has_point(point), "enemy spawned beyond world-view margin")
	seed(9137)
	for index in range(64):
		_check(first[index].is_equal_approx(spawner.call("_get_spawn_position")), "identical seed/camera did not reproduce spawn positions")
	print("SPAWN_DENSITY_CAMERA viewport=%s zoom=%.2f world_view=%s samples=64 visible_spawns=0 seed_reproducible=true" % [camera_viewport.size, camera.zoom.x, world_view])

func _test_reclamation_and_cap() -> void:
	var view: Rect2 = spawner.call("_get_world_view_rect")
	var regular_config := {"max_hp": 100.0, "speed": 0.0, "damage": 0.0, "xp": 2, "gold": 1, "sprite_path": "res://assets/sprites/enemy_grunt.png"}
	var visible_enemy: Node = EntityFactory.spawn_enemy("visible_guard", regular_config, view.get_center())
	visible_enemy.set_physics_process(false)
	var near_margin: Node = EntityFactory.spawn_enemy("new_spawn_guard", regular_config, view.end + Vector2(100.0, 0.0))
	near_margin.set_physics_process(false)
	for index in range(14):
		var enemy: Node = EntityFactory.spawn_enemy("remote_regular", regular_config, view.end + Vector2(5000.0 + float(index) * 20.0, 0.0))
		enemy.set_physics_process(false)
	var feature_config := regular_config.duplicate(true)
	feature_config["is_elite"] = true
	var elite: Node = EntityFactory.spawn_enemy("remote_elite_guard", feature_config, view.end + Vector2(6000.0, 0.0))
	elite.set_physics_process(false)
	feature_config["is_elite"] = false
	feature_config["is_boss"] = true
	feature_config["sprite_path"] = "res://assets/sprites/enemy_boss.png"
	var boss: Node = EntityFactory.spawn_enemy("remote_boss_guard", feature_config, view.end + Vector2(6100.0, 0.0))
	boss.set_physics_process(false)
	var dying: Node = EntityFactory.spawn_enemy("remote_death_guard", regular_config, view.end + Vector2(6200.0, 0.0))
	dying.set_physics_process(false)
	dying.take_damage(101.0, Vector2.ZERO)
	var kills_before := GameManager.kills
	var xp_before := GameManager.xp
	var gold_before := GameManager.gold
	var live_before := EntityFactory.get_enemy_live_count()
	seed(6789)
	var expected_random := randf()
	seed(6789)
	var retired := int(spawner.call("_reclaim_remote_regular_enemies"))
	_check(is_equal_approx(randf(), expected_random), "remote reclamation advanced gameplay RNG")
	_check(retired == 10 and EntityFactory.get_enemy_live_count() == live_before - 10, "remote retirement budget was not bounded to ten")
	_check(visible_enemy.is_active and near_margin.is_active and elite.is_active and boss.is_active and dying.is_dying, "retirement removed visible/new/feature/death enemy")
	_check(GameManager.kills == kills_before and GameManager.xp == xp_before and GameManager.gold == gold_before, "remote retirement awarded kill/drop rewards")
	_check(int(spawner.call("_reclaim_remote_regular_enemies")) == 4, "remaining remote regular enemies were not reclaimed")
	var frames: SpriteFrames = visible_enemy.animated_sprite.sprite_frames
	_check(frames.get_frame_count(&"walk") == 8 and frames.get_frame_count(&"attack") == 6 and frames.get_frame_count(&"death") == 6, "density repair replaced articulated enemy poses")
	spawner.max_enemies = EntityFactory.get_enemy_live_count() + 2
	spawner.first_elite_time_applied = true
	spawner.next_elite_time = 999.0
	spawner.boss_spawned = true
	spawner.next_harvest_pack_time = 999.0
	spawner.spawn_timer = 0.0
	GameManager.elapsed_time = 37.0
	GameManager.game_running = true
	spawner.call("_process", 0.0)
	GameManager.game_running = false
	_check(EntityFactory.get_enemy_live_count() == spawner.max_enemies, "midgame cadence exceeded the enemy cap")
	var pool: Dictionary = EntityFactory.get_pool_stats()["enemy"]
	_check(int(pool["duplicate_releases"]) == 0 and int(pool["foreign_releases"]) == 0, "remote reclamation violated enemy pooling contract")
	print("SPAWN_DENSITY_RECLAIM budget=10 remaining=4 visible_preserved=true spawn_margin_preserved=true elite_boss_death_preserved=true reward_delta=0 rng_delta=0 hard_cap=true pool_errors=0")

func _check(condition: bool, message: String) -> void:
	if condition or failed:
		return
	failed = true
	printerr("SPAWN_DENSITY_R32_FAIL: " + message)
	get_tree().quit(1)
