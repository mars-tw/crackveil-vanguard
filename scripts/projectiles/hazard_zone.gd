extends Node2D

var stats: Dictionary = {}
var source: Node = null
var age: float = 0.0
var tick_timer: float = 0.0
var is_active: bool = false
var redraw_request_count: int = 0
var last_alpha: float = 1.0


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
	last_alpha = 1.0
	modulate = Color.WHITE


func pool_reset(args: Dictionary) -> void:
	setup(args.get("position", Vector2.ZERO), args.get("stats", {}), args.get("source", null))


func setup(world_position: Vector2, hazard_stats: Dictionary, hazard_source: Node) -> void:
	global_position = world_position
	stats = hazard_stats
	source = hazard_source
	age = 0.0
	tick_timer = 0.0
	last_alpha = 1.0
	modulate = Color.WHITE
	_request_redraw()


func _process(delta: float) -> void:
	if not is_active:
		return

	age += delta
	tick_timer -= delta
	if tick_timer <= 0.0:
		_apply_tick_damage()
		tick_timer = float(stats.get("tick_interval", 0.24))

	if age >= float(stats.get("duration", 1.2)):
		is_active = false
		EntityFactory.release_hazard_zone(self)
		return

	_update_fade()


func _update_fade() -> void:
	var duration: float = max(0.001, float(stats.get("duration", 1.2)))
	var next_alpha: float = clamp(1.0 - age / duration, 0.0, 1.0)
	if abs(next_alpha - last_alpha) < 0.025:
		return
	last_alpha = next_alpha
	modulate = Color(1.0, 1.0, 1.0, next_alpha)
	queue_redraw()


func _apply_tick_damage() -> void:
	var radius: float = float(stats.get("area_radius", 56.0))
	var tick_damage: float = float(stats.get("damage_per_second", 4.0)) * float(stats.get("tick_interval", 0.24))

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
					float(stats.get("status_duration", float(stats.get("tick_interval", 0.24)))),
					float(stats.get("status_strength", 0.0))
				)
			var secondary_status_effect := str(stats.get("secondary_status_effect", ""))
			if secondary_status_effect != "" and enemy.has_method("apply_status_effect"):
				enemy.apply_status_effect(
					secondary_status_effect,
					float(stats.get("secondary_status_duration", float(stats.get("tick_interval", 0.24)))),
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
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.16))
	draw_circle(Vector2.ZERO, radius * 0.72, Color(color.r, color.g, color.b, 0.08))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.72), 2.5)
	draw_arc(Vector2.ZERO, radius * 0.72, 0.3, TAU + 0.3, 48, Color(0.58, 0.95, 1.0, 0.34), 1.25)
	for index in range(8):
		var angle := TAU * float(index) / 8.0 + age * 0.8
		var from := Vector2.RIGHT.rotated(angle) * radius * 0.36
		var to := Vector2.RIGHT.rotated(angle) * radius * 0.94
		draw_line(from, to, Color(color.r, color.g, color.b, 0.26), 1.0)


func _request_redraw() -> void:
	redraw_request_count += 1
	queue_redraw()
