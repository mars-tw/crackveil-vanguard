extends Node2D

var stats: Dictionary = {}
var source: Node = null
var age: float = 0.0
var tick_timer: float = 0.0
var is_active: bool = false


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


func pool_reset(args: Dictionary) -> void:
	setup(args.get("position", Vector2.ZERO), args.get("stats", {}), args.get("source", null))


func setup(world_position: Vector2, hazard_stats: Dictionary, hazard_source: Node) -> void:
	global_position = world_position
	stats = hazard_stats
	source = hazard_source
	age = 0.0
	tick_timer = 0.0
	queue_redraw()


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
			if enemy.has_method("take_damage"):
				enemy.take_damage(tick_damage, global_position)


func _draw() -> void:
	if not is_active:
		return
	var duration: float = max(0.001, float(stats.get("duration", 1.2)))
	var t: float = clamp(age / duration, 0.0, 1.0)
	var radius: float = float(stats.get("area_radius", 56.0))
	var color: Color = stats.get("color", Color(1.0, 0.42, 0.12, 1.0))
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.2 * (1.0 - t)))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.54 * (1.0 - t)), 2.0)
