extends Node

const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
var failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	EntityFactory.initialize_for_arena(self)
	GameManager.game_running = false
	var checks_before := Projectile.readability_check_count
	var ticks_before := Projectile.physics_tick_count
	var redraw_before := Projectile.dart_redraw_request_count
	var stats := {"source_weapon_id": "riftline_emitter", "projectile_speed": 0.0, "range": 100000.0, "damage": 16.0, "pierce": 2, "target_group": "enemies"}
	var projectile: Node = EntityFactory.spawn_projectile(Vector2.ZERO, Vector2.RIGHT, stats, null)
	projectile.set_physics_process(false)
	for index in range(60):
		projectile._physics_process(1.0 / 60.0)
	_check(Projectile.readability_check_count == checks_before, "friendly dart performed per-tick device checks")
	_check(Projectile.physics_tick_count - ticks_before == 60, "logic cadence was reduced")
	_check(Projectile.dart_redraw_request_count - redraw_before >= 29 and Projectile.dart_redraw_request_count - redraw_before <= 31, "glint cadence is outside 30 Hz")
	_check(int(projectile.cel_render_kind) == 1 and (projectile.dart_body as PackedVector2Array).size() == 4, "cached dart body is missing")
	var friendly_checks: int = Projectile.readability_check_count - checks_before
	var logic_ticks: int = Projectile.physics_tick_count - ticks_before
	var redraw_requests: int = Projectile.dart_redraw_request_count - redraw_before
	EntityFactory.release_projectile(projectile)
	await get_tree().process_frame
	_check(int(projectile.cel_render_kind) == 0 and (projectile.dart_body as PackedVector2Array).is_empty(), "release retained cached weapon geometry")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child(viewport)
	var enemy: Node = preload("res://scenes/projectiles/Projectile.tscn").instantiate()
	viewport.add_child(enemy)
	enemy.pool_on_acquire()
	enemy.set_physics_process(false)
	MOBILE.set_device_hints_override_for_tests({"ua_mobile": true, "ua_phone": true, "touch_available": true, "mouse_available": false})
	enemy.setup(Vector2.ZERO, Vector2.RIGHT, {"target_group": "heroes", "projectile_speed": 0.0, "range": 100000.0}, null)
	_check(enemy.mobile_readability_active == true, "hostile palette failed to start with phone readability")
	MOBILE.set_device_hints_override_for_tests({"ua_mobile": false, "touch_available": false, "mouse_available": true})
	for index in range(13):
		enemy._physics_process(1.0 / 60.0)
	_check(enemy.mobile_readability_active == false, "hostile palette failed to refresh within 200 ms")
	enemy.pool_on_release()
	viewport.queue_free()
	var explosion: Node = EntityFactory.spawn_explosion(Vector2.ZERO, {"damage": 0.0, "area_radius": 30.0}, null)
	if explosion != null:
		_check(explosion.mobile_lod_active == false, "desktop explosion cached incorrect tier")
		EntityFactory.release_explosion(explosion)
	MOBILE.set_device_hints_override_for_tests()
	print("PROJECTILE_PERF_R36 friendly_device_checks=%d physics_ticks=%d dart_redraws=%d" % [friendly_checks, logic_ticks, redraw_requests])
	if not failed:
		print("PROJECTILE_PERF_R36_PASS no_friendly_per_tick_bridge=true movement_60hz=true cosmetic_glint_30hz=true hostile_readability=true cleanup=true")
	get_tree().quit(1 if failed else 0)

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("PROJECTILE_PERF_R36_FAIL " + message)
