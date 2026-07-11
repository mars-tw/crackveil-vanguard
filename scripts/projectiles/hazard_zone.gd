extends Node2D

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const BASE_VISUAL_REDRAW_INTERVAL := 0.05

var stats: Dictionary = {}
var source: Node = null
var age: float = 0.0
var tick_timer: float = 0.0
var tick_interval: float = 0.24
var is_active: bool = false
var redraw_request_count: int = 0
var last_alpha: float = 1.0
var visual_redraw_timer: float = 0.0
var visual_redraw_interval: float = BASE_VISUAL_REDRAW_INTERVAL
var mobile_lod_active: bool = false


func pool_on_acquire() -> void:
	is_active = true
	visible = true
	set_process(true)


func pool_on_release() -> void:
	is_active = false
	visible = false
	set_process(false)
	stats = {}
	source = null
	age = 0.0
	tick_timer = 0.0
	tick_interval = 0.24
	last_alpha = 1.0
	visual_redraw_timer = 0.0
	visual_redraw_interval = BASE_VISUAL_REDRAW_INTERVAL
	mobile_lod_active = false
	modulate = Color.WHITE


func pool_reset(args: Dictionary) -> void:
	setup(args.get("position", Vector2.ZERO), args.get("stats", {}), args.get("source", null))


func setup(world_position: Vector2, hazard_stats: Dictionary, hazard_source: Node) -> void:
	global_position = world_position
	stats = hazard_stats
	source = hazard_source
	age = 0.0
	tick_timer = 0.0
	tick_interval = MOBILE_TUNING.hazard_tick_interval(_viewport_size_for_lod(), float(stats.get("tick_interval", 0.24)))
	last_alpha = 1.0
	visual_redraw_timer = 0.0
	modulate = Color.WHITE
	_refresh_visual_lod(true)


func _process(delta: float) -> void:
	if not is_active:
		return

	_refresh_visual_lod()
	age += delta
	tick_timer -= delta
	if tick_timer <= 0.0:
		_apply_tick_damage()
		tick_timer = tick_interval

	if age >= float(stats.get("duration", 1.2)):
		is_active = false
		EntityFactory.release_hazard_zone(self)
		return

	_update_fade(delta)


func _update_fade(delta: float) -> void:
	visual_redraw_timer -= delta
	if visual_redraw_timer > 0.0:
		return
	visual_redraw_timer = visual_redraw_interval
	var duration: float = max(0.001, float(stats.get("duration", 1.2)))
	var next_alpha: float = clamp(1.0 - age / duration, 0.0, 1.0)
	if abs(next_alpha - last_alpha) < 0.001:
		return
	last_alpha = next_alpha
	modulate = Color(1.0, 1.0, 1.0, next_alpha)
	_request_redraw()


func _apply_tick_damage() -> void:
	var radius: float = float(stats.get("area_radius", 56.0))
	var tick_damage: float = float(stats.get("damage_per_second", 4.0)) * tick_interval

	for enemy in EntityFactory.get_enemies_in_radius(global_position, radius + 24.0):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var active_value: Variant = enemy.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		var enemy_radius: float = float(enemy.get("radius"))
		var hit_distance: float = radius + enemy_radius
		if global_position.distance_squared_to(enemy.global_position) <= hit_distance * hit_distance:
			var status_effect := str(stats.get("status_effect", ""))
			if status_effect != "" and enemy.has_method("apply_status_effect"):
				enemy.apply_status_effect(
					status_effect,
					float(stats.get("status_duration", tick_interval)),
					float(stats.get("status_strength", 0.0))
				)
			var secondary_status_effect := str(stats.get("secondary_status_effect", ""))
			if secondary_status_effect != "" and enemy.has_method("apply_status_effect"):
				enemy.apply_status_effect(
					secondary_status_effect,
					float(stats.get("secondary_status_duration", tick_interval)),
					float(stats.get("secondary_status_strength", 0.0))
				)
			if enemy.has_method("take_damage"):
				var applied_damage: float = float(enemy.take_damage(tick_damage, global_position))
				GameManager.record_weapon_damage(source, str(stats.get("source_weapon_id", "")), applied_damage)


func _draw() -> void:
	if not is_active:
		return
	var radius: float = float(stats.get("area_radius", 56.0))
	var color: Color = stats.get("color", Color(1.0, 0.42, 0.12, 1.0))
	var mobile_readability := MOBILE_TUNING.use_mobile_ui(_viewport_size_for_lod())
	var outer_segments := 40 if mobile_lod_active else 64
	var inner_segments := 32 if mobile_lod_active else 48
	var spoke_count := 5 if mobile_lod_active else 8
	if mobile_readability:
		draw_arc(Vector2.ZERO, radius + 1.0, 0.0, TAU, outer_segments, Color(0.015, 0.018, 0.024, 0.92), 7.0)
		draw_arc(Vector2.ZERO, radius * 0.72, 0.3, TAU + 0.3, inner_segments, Color(0.015, 0.018, 0.024, 0.72), 4.0)
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.16))
	draw_circle(Vector2.ZERO, radius * 0.72, Color(color.r, color.g, color.b, 0.08))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, outer_segments, Color(color.r, color.g, color.b, 0.86 if mobile_readability else 0.72), 4.5 if mobile_readability else 2.5)
	draw_arc(Vector2.ZERO, radius * 0.72, 0.3, TAU + 0.3, inner_segments, Color(0.58, 0.95, 1.0, 0.46 if mobile_readability else 0.34), 2.4 if mobile_readability else 1.25)
	for index in range(spoke_count):
		var angle := TAU * float(index) / float(spoke_count) + age * 0.8
		var from := Vector2.RIGHT.rotated(angle) * radius * 0.36
		var to := Vector2.RIGHT.rotated(angle) * radius * 0.94
		draw_line(from, to, Color(color.r, color.g, color.b, 0.32 if mobile_readability else 0.26), 1.6 if mobile_readability else 1.0)


func _request_redraw() -> void:
	redraw_request_count += 1
	queue_redraw()


func _refresh_visual_lod(force_refresh: bool = false) -> void:
	var next_mobile_lod := MOBILE_TUNING.mobile_lod_enabled(_viewport_size_for_lod())
	if not force_refresh and next_mobile_lod == mobile_lod_active:
		return
	mobile_lod_active = next_mobile_lod
	visual_redraw_interval = MOBILE_TUNING.hazard_visual_redraw_interval(_viewport_size_for_lod(), BASE_VISUAL_REDRAW_INTERVAL)
	visual_redraw_timer = 0.0
	_request_redraw()


func get_mobile_lod_debug_state() -> Dictionary:
	return {
		"mobile_lod": mobile_lod_active,
		"tick_interval": tick_interval,
		"tick_damage": float(stats.get("damage_per_second", 4.0)) * tick_interval,
		"visual_redraw_interval": visual_redraw_interval
	}


func _viewport_size_for_lod() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		return viewport_size
	var window_size := DisplayServer.window_get_size()
	if window_size.x > 0 and window_size.y > 0:
		return Vector2(window_size)
	return Vector2(1280.0, 720.0)
