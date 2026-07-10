extends "res://scripts/weapons/base_weapon.gd"


func _process(delta: float) -> void:
	if owner_player == null or data == null or not GameManager.game_running:
		return

	cooldown_timer -= delta
	if cooldown_timer > 0.0:
		return

	var target := find_nearest_enemy(data_float("range", 560.0))
	if target == null:
		return

	_fire_at(target)
	cooldown_timer = data_float("cooldown", 1.0)


func _fire_at(target: Node2D) -> void:
	var base_direction: Vector2 = (target.global_position - owner_player.global_position).normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.RIGHT

	var base_stats := _projectile_stats_for_fire()
	var evolved_fan := int(base_stats.get("evo_rift_fan_level", 0)) > 0
	var projectile_count: int = max(1, data_int("projectile_count", 1))
	var spread_degrees: float = data_float("spread_degrees", 24.0)
	if evolved_fan:
		projectile_count = clamp(projectile_count, 3, 5)
		spread_degrees = max(spread_degrees, 52.0)
	var spread: float = deg_to_rad(min(spread_degrees, spread_degrees * 0.32 * float(projectile_count - 1)))
	for index in range(projectile_count):
		var angle_offset: float = 0.0
		if projectile_count > 1:
			angle_offset = -spread * 0.5 + spread * float(index) / float(projectile_count - 1)

		var direction: Vector2 = base_direction.rotated(angle_offset).normalized()
		var spawn_position: Vector2 = owner_player.global_position + direction * 20.0
		var shot_stats := base_stats.duplicate(true)
		if evolved_fan and abs(angle_offset) > 0.001:
			shot_stats["damage"] = float(shot_stats.get("damage", 10.0)) * 0.82
			shot_stats["range"] = float(shot_stats.get("range", 520.0)) * 0.82
		EntityFactory.spawn_projectile(spawn_position, direction, shot_stats, owner_player)

	register_trigger()


func _projectile_stats_for_fire() -> Dictionary:
	var stats := data_projectile_stats().duplicate(true)
	stats["damage"] = float(stats.get("damage", data_float("damage", 10.0))) * GameManager.get_outgoing_damage_multiplier(owner_player)
	return stats
