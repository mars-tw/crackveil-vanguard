extends "res://scripts/weapons/base_weapon.gd"

const MAX_RAIL_TARGETS := 14


func _process(delta: float) -> void:
	if owner_player == null or data == null or not GameManager.game_running:
		return

	cooldown_timer -= delta
	if cooldown_timer > 0.0:
		return

	var target := find_nearest_enemy(data_float("range", 760.0))
	if target == null:
		return

	_fire_lance(target)
	cooldown_timer = scaled_cooldown(data_float("cooldown", 1.0))


func _fire_lance(target: Node2D) -> void:
	var origin := owner_player.global_position
	var direction := (target.global_position - origin).normalized()
	if direction == Vector2.ZERO:
		direction = _owner_facing_direction()

	var effect_stats := data_effect_stats().duplicate(true)
	var focus_level := int(effect_stats.get("rail_focus_level", 0))
	var evolved := int(effect_stats.get("evo_star_piercer_level", 0)) > 0
	var visual_level := int(effect_stats.get("visual_level", 0))
	var passive_bonus := owner_passive_value() if owner_passive_id() == "rift_sniper" else 0.0
	var beam_range := data_float("range", 760.0)
	var beam_width := data_float("projectile_radius", 7.0) + float(focus_level) * 1.4 + (2.0 if evolved else 0.0)
	var max_targets: int = min(MAX_RAIL_TARGETS, max(1, data_int("pierce", 3) + 1 + focus_level + (4 if evolved else 0)))
	var base_damage := data_float("damage", 30.0) * GameManager.get_outgoing_damage_multiplier(owner_player) * (1.0 + float(focus_level) * 0.12 + passive_bonus)
	var hits := _collect_lance_hits(origin, direction, beam_range, beam_width, max_targets)

	var hit_points: Array[Vector2] = [origin]
	var damage_value := base_damage
	var final_hit_position := origin + direction * beam_range
	for hit in hits:
		var enemy: Node = hit.get("enemy")
		if enemy == null or not is_instance_valid(enemy):
			continue
		final_hit_position = enemy.global_position
		hit_points.append(enemy.global_position)
		if enemy.has_method("take_damage"):
			var applied_damage: float = float(enemy.take_damage(damage_value, origin))
			GameManager.record_weapon_damage(owner_player, get_weapon_id(), applied_damage)
		if evolved and enemy.has_method("apply_status_effect"):
			enemy.apply_status_effect("vulnerable", 0.55, 0.16)
		damage_value *= 0.92

	if hit_points.size() == 1:
		hit_points.append(origin + direction * beam_range)
	else:
		hit_points.append(origin + direction * beam_range)
	EntityFactory.spawn_lightning_arc(
		hit_points,
		data_color("color", Color(0.72, 0.96, 1.0)).lerp(Color.WHITE, 0.24),
		data_float("effect_lifetime", 0.18),
		data_string("lightning_sprite_path", "res://assets/sprites/proj_lightning.png"),
		beam_width * (4.6 if evolved else 3.7) * (1.0 + float(visual_level) * 0.045)
	)
	if evolved and hits.size() > 0:
		EntityFactory.spawn_explosion(final_hit_position, _make_tail_flash_stats(base_damage, beam_width), owner_player)
	else:
		EntityFactory.spawn_death_burst(final_hit_position, data_color("color", Color(0.72, 0.96, 1.0)), 0.86, "spark")

	register_trigger()
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("fire", false, -3.5, 1.34)


func _collect_lance_hits(origin: Vector2, direction: Vector2, beam_range: float, beam_width: float, max_targets: int) -> Array:
	var result: Array = []
	var query_center := origin + direction * beam_range * 0.5
	for enemy in EntityFactory.get_enemies_in_radius(query_center, beam_range * 0.5 + beam_width + 32.0):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - origin
		var projection := to_enemy.dot(direction)
		if projection < 0.0 or projection > beam_range:
			continue
		var enemy_radius: float = float(enemy.get("radius"))
		if abs(to_enemy.cross(direction)) > beam_width + enemy_radius:
			continue
		result.append({"projection": projection, "enemy": enemy})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("projection", 0.0)) < float(b.get("projection", 0.0)))
	if result.size() > max_targets:
		result.resize(max_targets)
	return result


func _make_tail_flash_stats(base_damage: float, beam_width: float) -> Dictionary:
	return {
		"damage": base_damage * 0.34,
		"source_weapon_id": get_weapon_id(),
		"area_radius": max(46.0, beam_width * 5.8),
		"effect_lifetime": 0.18,
		"explosion_sprite_path": "res://assets/vfx/kenney_particle/burst_fire_cyan.png",
		"color": data_color("color", Color(0.72, 0.96, 1.0)),
		"sprite_scale": 0.72,
		"visual_level": int(data_effect_stats().get("visual_level", 0)),
		"evolved_visual": bool(data_effect_stats().get("evolved_visual", false))
	}


func _owner_facing_direction() -> Vector2:
	if owner_player != null and owner_player.has_method("get_facing_direction"):
		return owner_player.get_facing_direction()
	return Vector2.RIGHT
