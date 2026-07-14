extends Node2D

const REDRAW_INTERVAL := 0.08

var stats: Dictionary = {}
var source: Node2D = null
var weapon_node: Node = null
var age: float = 0.0
var attack_timer: float = 0.0
var attack_speed_boost_timer: float = 0.0
var hit_flash_timer: float = 0.0
var redraw_timer: float = 0.0
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
	weapon_node = null
	age = 0.0
	attack_timer = 0.0
	attack_speed_boost_timer = 0.0
	hit_flash_timer = 0.0
	redraw_timer = 0.0
	rotation = 0.0
	modulate = Color.WHITE


func pool_reset(args: Dictionary) -> void:
	global_position = args.get("position", Vector2.ZERO)
	stats = args.get("stats", {}).duplicate(true)
	source = args.get("source", null)
	weapon_node = args.get("weapon", null)
	age = 0.0
	attack_timer = max(0.08, float(stats.get("hit_interval", 0.55)) * 0.45)
	attack_speed_boost_timer = 0.0
	hit_flash_timer = 0.0
	redraw_timer = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not is_active:
		return
	if not _source_is_alive():
		expire(false)
		return

	age += delta
	attack_speed_boost_timer = max(attack_speed_boost_timer - delta, 0.0)
	hit_flash_timer = max(hit_flash_timer - delta, 0.0)
	var attack_speed := 1.15 if attack_speed_boost_timer > 0.0 else 1.0
	attack_timer -= delta * attack_speed
	if attack_timer <= 0.0:
		_apply_tick_damage()
		attack_timer = max(0.08, float(stats.get("hit_interval", 0.55)))
	if age >= float(stats.get("effect_lifetime", 5.5)):
		expire(true)
		return

	redraw_timer -= delta
	if redraw_timer <= 0.0:
		redraw_timer = REDRAW_INTERVAL
		queue_redraw()


func apply_orbit_speed_boost(duration: float = 1.0) -> void:
	if not is_active:
		return
	attack_speed_boost_timer = max(attack_speed_boost_timer, duration)


func expire(trigger_shatter: bool = true) -> void:
	if not is_active:
		return
	is_active = false
	if trigger_shatter:
		_spawn_shatter()
	EntityFactory.release_rift_construct(self)


func _apply_tick_damage() -> void:
	var radius := float(stats.get("area_radius", 54.0))
	var candidates: Array[Node2D] = EntityFactory.get_enemies_in_radius(global_position, radius + 24.0)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var distance_a := global_position.distance_squared_to(a.global_position)
		var distance_b := global_position.distance_squared_to(b.global_position)
		if not is_equal_approx(distance_a, distance_b):
			return distance_a < distance_b
		return a.get_instance_id() < b.get_instance_id()
	)
	var damage_value := float(stats.get("damage", 7.0)) * _construct_damage_multiplier()
	var max_targets := clampi(int(stats.get("max_targets_per_tick", 2)), 1, 2)
	var hit_count := 0
	for enemy in candidates:
		if hit_count >= max_targets:
			break
		if enemy == null or not is_instance_valid(enemy):
			continue
		var active_value: Variant = enemy.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		var enemy_radius := float(enemy.get("radius"))
		var hit_distance := radius + enemy_radius
		if global_position.distance_squared_to(enemy.global_position) > hit_distance * hit_distance:
			continue
		if enemy.has_method("take_damage"):
			var applied_damage := float(enemy.take_damage(damage_value, global_position))
			GameManager.record_weapon_damage(source, str(stats.get("source_weapon_id", "rift_constructs")), applied_damage)
			hit_count += 1
	if hit_count > 0:
		hit_flash_timer = 0.1


func _construct_damage_multiplier() -> float:
	var multiplier := 1.0
	var squad := GameManager.squad_manager
	if squad != null and is_instance_valid(squad):
		var captain: Node2D = squad.get("leader") as Node2D
		if captain != null and is_instance_valid(captain):
			var captain_range := float(captain.get("hit_radius")) + 140.0
			if global_position.distance_squared_to(captain.global_position) <= captain_range * captain_range:
				multiplier *= 1.16 if squad.has_method("has_active_bond") and squad.has_active_bond("bond_captain_shepherd") else 1.10
	if int(stats.get("evo_mirror_flock_level", 0)) > 0 and EntityFactory.has_rift_construct_neighbor(self, 120.0):
		multiplier *= 1.12
	return min(multiplier, 1.25)


func _spawn_shatter() -> void:
	var color: Color = stats.get("color", Color(0.55, 0.82, 1.0))
	if int(stats.get("evo_mirror_flock_level", 0)) > 0 and _source_is_alive():
		EntityFactory.spawn_explosion(global_position, {
			"damage": float(stats.get("damage", 7.0)) * 0.55,
			"source_weapon_id": str(stats.get("source_weapon_id", "rift_constructs")),
			"area_radius": 70.0,
			"effect_lifetime": 0.2,
			"color": color,
			"visual_level": int(stats.get("visual_level", 0)),
			"evolved_visual": true,
		}, source)
	EntityFactory.spawn_death_burst(global_position, color, 0.72, "spark")


func _source_is_alive() -> bool:
	if source == null or not is_instance_valid(source):
		return false
	var alive_value: Variant = source.get("is_alive")
	return alive_value == null or bool(alive_value)


func _draw() -> void:
	if not is_active:
		return
	var color: Color = stats.get("color", Color(0.55, 0.82, 1.0))
	var pulse: float = 0.5 + 0.5 * sin(age * 5.2)
	var flash: float = clampf(hit_flash_timer / 0.1, 0.0, 1.0)
	var radius: float = 12.0 + pulse * 1.4
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for index in range(6):
		var angle := TAU * float(index) / 6.0 + age * 0.22
		outer.append(Vector2.RIGHT.rotated(angle) * radius)
		inner.append(Vector2.RIGHT.rotated(-angle) * radius * 0.48)
	draw_colored_polygon(outer, Color(color.r * 0.35, color.g * 0.35, color.b * 0.5, 0.72))
	draw_polyline(outer + PackedVector2Array([outer[0]]), color.lerp(Color.WHITE, flash), 2.0, true)
	draw_colored_polygon(inner, Color(color.r, color.g, color.b, 0.55 + flash * 0.35))
	draw_circle(Vector2.ZERO, 3.2 + pulse, Color(0.94, 0.99, 1.0, 0.92))
	var attack_ratio: float = clampf(1.0 - attack_timer / maxf(0.08, float(stats.get("hit_interval", 0.55))), 0.0, 1.0)
	draw_arc(Vector2.ZERO, radius + 5.0, -PI * 0.5, -PI * 0.5 + TAU * attack_ratio, 24, Color(color.r, color.g, color.b, 0.58), 1.6)


func get_source_owner() -> Node2D:
	return source
