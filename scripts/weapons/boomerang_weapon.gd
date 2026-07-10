extends "res://scripts/weapons/base_weapon.gd"


func _process(delta: float) -> void:
	if owner_player == null or data == null or not GameManager.game_running:
		return

	cooldown_timer -= delta
	if cooldown_timer > 0.0:
		return

	var target := find_nearest_enemy(data_float("range", 520.0))
	if target == null:
		return

	_throw_at(target)
	cooldown_timer = data_float("cooldown", 1.0)


func _throw_at(target: Node2D) -> void:
	var base_direction := (target.global_position - owner_player.global_position).normalized()
	if base_direction == Vector2.ZERO:
		base_direction = _owner_facing_direction()

	var base_stats := _projectile_stats_for_fire()
	var projectile_count: int = max(1, data_int("projectile_count", 1))
	var spread_degrees: float = data_float("spread_degrees", 18.0)
	var spread: float = deg_to_rad(spread_degrees) * float(max(0, projectile_count - 1))
	for index in range(projectile_count):
		var angle_offset := 0.0
		if projectile_count > 1:
			angle_offset = -spread * 0.5 + spread * float(index) / float(projectile_count - 1)
		var direction := base_direction.rotated(angle_offset).normalized()
		var side_offset := direction.rotated(PI * 0.5) * (float(index) - float(projectile_count - 1) * 0.5) * 10.0
		var spawn_position: Vector2 = owner_player.global_position + direction * 24.0 + side_offset
		EntityFactory.spawn_projectile(spawn_position, direction, base_stats, owner_player)

	register_trigger()
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("fire", false, -2.0, 0.82)


func _projectile_stats_for_fire() -> Dictionary:
	var stats := data_projectile_stats().duplicate(true)
	stats["motion_mode"] = "boomerang"
	stats["damage"] = float(stats.get("damage", data_float("damage", 10.0))) * GameManager.get_outgoing_damage_multiplier(owner_player)
	stats["pierce"] = int(stats.get("pierce", data_int("pierce", 2))) + int(stats.get("boomerang_rebound_level", 0))
	stats["projectile_radius"] = float(stats.get("projectile_radius", data_float("projectile_radius", 8.0)))
	if int(stats.get("evo_razor_bulwark_level", 0)) > 0:
		stats["range"] = float(stats.get("range", data_float("range", 520.0))) * 1.08
	return stats


func _owner_facing_direction() -> Vector2:
	if owner_player != null and owner_player.has_method("get_facing_direction"):
		return owner_player.get_facing_direction()
	return Vector2.RIGHT
