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
	cooldown_timer = data_float("cooldown", 1.0)


func _cast_chain(first_target: Node2D) -> void:
	var chain_targets: Array[Node2D] = []
	var used_ids: Dictionary = {}
	var current: Node2D = first_target

	while current != null and chain_targets.size() < max(1, data_int("chain_count", 4)):
		chain_targets.append(current)
		used_ids[current.get_instance_id()] = true
		current = _find_next_chain_target(current.global_position, used_ids)

	var points: Array[Vector2] = [owner_player.global_position]
	var damage_value: float = data_float("damage", 12.0)
	for target in chain_targets:
		if target == null or not is_instance_valid(target):
			continue
		points.append(target.global_position)
		if target.has_method("take_damage"):
			target.take_damage(damage_value, owner_player.global_position)
		damage_value *= data_float("chain_damage_falloff", 0.86)

	EntityFactory.spawn_lightning_arc(
		points,
		data_color("color", Color(0.6, 0.9, 1.0)),
		data_float("effect_lifetime", 0.22),
		data_string("lightning_sprite_path", "res://assets/sprites/proj_lightning.png")
	)


func _find_next_chain_target(origin: Vector2, used_ids: Dictionary) -> Node2D:
	var nearest: Node2D = null
	var chain_radius: float = data_float("chain_radius", 170.0)
	var best_distance_squared: float = chain_radius * chain_radius

	for enemy in EntityFactory.get_enemies_in_radius(origin, chain_radius):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if used_ids.has(enemy.get_instance_id()):
			continue
		var distance_squared: float = origin.distance_squared_to(enemy.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			nearest = enemy

	return nearest
