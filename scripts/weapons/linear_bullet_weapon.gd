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

	var projectile_count: int = max(1, data_int("projectile_count", 1))
	var spread_degrees: float = data_float("spread_degrees", 24.0)
	var spread: float = deg_to_rad(min(spread_degrees, spread_degrees * 0.32 * float(projectile_count - 1)))
	for index in range(projectile_count):
		var angle_offset: float = 0.0
		if projectile_count > 1:
			angle_offset = -spread * 0.5 + spread * float(index) / float(projectile_count - 1)

		var direction: Vector2 = base_direction.rotated(angle_offset).normalized()
		var spawn_position: Vector2 = owner_player.global_position + direction * 20.0
		EntityFactory.spawn_projectile(spawn_position, direction, _projectile_stats_for_fire(), owner_player)

	register_trigger()


func _projectile_stats_for_fire() -> Dictionary:
	var stats := data_projectile_stats().duplicate(true)
	stats["damage"] = float(stats.get("damage", data_float("damage", 10.0))) * GameManager.get_outgoing_damage_multiplier(owner_player)
	return stats
