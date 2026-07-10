extends "res://scripts/weapons/base_weapon.gd"


func _process(delta: float) -> void:
	if owner_player == null or data == null or not GameManager.game_running:
		return

	cooldown_timer -= delta
	if cooldown_timer > 0.0:
		return

	var first_target := find_nearest_enemy(data_float("range", 560.0))
	if first_target == null:
		return

	_cast_chain(first_target)
	register_trigger()
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("fire")
	cooldown_timer = data_float("cooldown", 1.0)


func _cast_chain(first_target: Node2D) -> void:
	var chain_targets: Array[Node2D] = []
	var used_ids: Dictionary = {}
	var current: Node2D = first_target

	while current != null and chain_targets.size() < max(1, data_int("chain_count", 4)):
		chain_targets.append(current)
		used_ids[_hit_key_for(current)] = true
		current = _find_next_chain_target(current.global_position, used_ids)

	var points: Array[Vector2] = [owner_player.global_position]
	var damage_value: float = data_float("damage", 12.0) * GameManager.get_outgoing_damage_multiplier(owner_player)
	var final_target_position := Vector2.ZERO
	var has_final_target := false
	for target in chain_targets:
		if target == null or not is_instance_valid(target):
			continue
		points.append(target.global_position)
		final_target_position = target.global_position
		has_final_target = true
		if target.has_method("take_damage"):
			target.take_damage(damage_value, owner_player.global_position)
		damage_value *= data_float("chain_damage_falloff", 0.86)

	var effect_stats := data_effect_stats()
	if int(effect_stats.get("evo_overload_nova_level", 0)) > 0 and has_final_target:
		EntityFactory.spawn_explosion(final_target_position, _make_nova_stats(), owner_player)
		_cast_overload_nova(final_target_position, used_ids)
	elif int(effect_stats.get("chain_overload_level", 0)) > 0 and has_final_target:
		EntityFactory.spawn_explosion(final_target_position, _make_overload_stats(), owner_player)

	EntityFactory.spawn_lightning_arc(
		points,
		data_color("color", Color(0.6, 0.9, 1.0)),
		data_float("effect_lifetime", 0.22),
		data_string("lightning_sprite_path", "res://assets/sprites/proj_lightning.png")
	)


func _make_overload_stats() -> Dictionary:
	return {
		"damage": data_float("damage", 12.0) * 0.42 * GameManager.get_outgoing_damage_multiplier(owner_player),
		"area_radius": max(42.0, data_float("chain_radius", 170.0) * 0.32),
		"effect_lifetime": 0.22,
		"explosion_sprite_path": "res://assets/sprites/fx_explosion.png",
		"color": data_color("color", Color(0.6, 0.9, 1.0)),
		"sprite_scale": 0.72
	}


func _make_nova_stats() -> Dictionary:
	return {
		"damage": data_float("damage", 12.0) * 0.54 * GameManager.get_outgoing_damage_multiplier(owner_player),
		"area_radius": max(68.0, data_float("chain_radius", 170.0) * 0.42),
		"effect_lifetime": 0.28,
		"explosion_sprite_path": "res://assets/sprites/fx_explosion.png",
		"color": data_color("color", Color(0.72, 1.0, 0.92)),
		"sprite_scale": 0.86
	}


func _cast_overload_nova(origin: Vector2, used_ids: Dictionary) -> void:
	var nova_radius: float = max(120.0, data_float("chain_radius", 170.0) * 0.82)
	var max_targets := 3
	var damage_value: float = data_float("damage", 12.0) * 0.32 * GameManager.get_outgoing_damage_multiplier(owner_player)
	var arc_points: Array[Vector2] = [origin]
	var hits := 0
	for enemy in EntityFactory.get_enemies_in_radius(origin, nova_radius):
		if hits >= max_targets:
			break
		if enemy == null or not is_instance_valid(enemy):
			continue
		if used_ids.has(_hit_key_for(enemy)):
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage_value, origin)
			arc_points.append(enemy.global_position)
			hits += 1
	if arc_points.size() > 1:
		EntityFactory.spawn_lightning_arc(
			arc_points,
			data_color("color", Color(0.72, 1.0, 0.92)),
			0.18,
			data_string("lightning_sprite_path", "res://assets/sprites/proj_lightning.png")
		)


func _find_next_chain_target(origin: Vector2, used_ids: Dictionary) -> Node2D:
	var nearest: Node2D = null
	var chain_radius: float = data_float("chain_radius", 170.0)
	var best_distance_squared: float = chain_radius * chain_radius

	for enemy in EntityFactory.get_enemies_in_radius(origin, chain_radius):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if used_ids.has(_hit_key_for(enemy)):
			continue
		var distance_squared: float = origin.distance_squared_to(enemy.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			nearest = enemy

	return nearest


func _hit_key_for(body: Node) -> int:
	if body != null and body.has_method("get_hit_token"):
		return int(body.get_hit_token())
	return int(body.get_instance_id())
