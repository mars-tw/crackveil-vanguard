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

	_fire_salvo(target)
	cooldown_timer = data_float("cooldown", 1.0)


func _fire_salvo(target: Node2D) -> void:
	var base_direction := (target.global_position - owner_player.global_position).normalized()
	if base_direction == Vector2.ZERO:
		base_direction = _owner_facing_direction()

	var projectile_count: int = max(1, data_int("projectile_count", 1))
	var spread_degrees: float = data_float("spread_degrees", 28.0)
	var spread: float = deg_to_rad(min(72.0, spread_degrees * float(max(1, projectile_count - 1))))
	var base_stats := _projectile_stats_for_fire(target)
	for index in range(projectile_count):
		var angle_offset := 0.0
		if projectile_count > 1:
			angle_offset = -spread * 0.5 + spread * float(index) / float(projectile_count - 1)
		var direction := base_direction.rotated(angle_offset).normalized()
		var side_offset := direction.rotated(PI * 0.5) * (float(index) - float(projectile_count - 1) * 0.5) * 8.0
		var spawn_position: Vector2 = owner_player.global_position + direction * 22.0 + side_offset
		EntityFactory.spawn_projectile(spawn_position, direction, base_stats, owner_player)

	register_trigger()
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("fire", false, -3.0, 1.18)


func _projectile_stats_for_fire(target: Node2D) -> Dictionary:
	var stats := data_projectile_stats().duplicate(true)
	var guidance_level := int(stats.get("missile_guidance_level", 0))
	var evolved := int(stats.get("evo_hunter_swarm_level", 0)) > 0
	stats["motion_mode"] = "homing"
	stats["homing_target"] = target
	stats["homing_turn_rate"] = float(stats.get("homing_turn_rate", data_float("homing_turn_rate", 5.4))) + float(guidance_level) * 1.1
	stats["homing_retarget_radius"] = float(stats.get("homing_retarget_radius", data_float("homing_retarget_radius", 620.0))) + float(guidance_level) * 70.0
	stats["damage"] = float(stats.get("damage", data_float("damage", 10.0))) * GameManager.get_outgoing_damage_multiplier(owner_player)
	if guidance_level >= 2:
		stats["range"] = float(stats.get("range", data_float("range", 560.0))) * 1.12
	if evolved:
		stats["pierce"] = max(1, int(stats.get("pierce", 0)))
		stats["homing_turn_rate"] = float(stats.get("homing_turn_rate", 5.4)) + 1.4
	return stats


func _owner_facing_direction() -> Vector2:
	if owner_player != null and owner_player.has_method("get_facing_direction"):
		return owner_player.get_facing_direction()
	return Vector2.RIGHT
