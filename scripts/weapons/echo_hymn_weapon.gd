extends "res://scripts/weapons/base_weapon.gd"

const MAX_ECHO_TARGETS := 18


func _process(delta: float) -> void:
	if owner_player == null or data == null or not GameManager.game_running:
		return

	cooldown_timer -= delta
	if cooldown_timer > 0.0:
		return

	_cast_hymn()
	cooldown_timer = scaled_cooldown(data_float("cooldown", 1.0))


func _cast_hymn() -> void:
	var stats := data_effect_stats().duplicate(true)
	var crescendo_level := int(stats.get("echo_crescendo_level", 0))
	var evolved := int(stats.get("evo_resonant_chorus_level", 0)) > 0
	var passive_bonus := owner_passive_value() if owner_passive_id() == "echo_singer" else 0.0
	var pulse_level: int = max(0, data_int("projectile_count", 1) - 1)
	var radius: float = data_float("area_radius", 118.0) * (1.0 + passive_bonus * 0.8)
	var heal_amount: float = data_float("damage", 10.0) * (0.42 + float(crescendo_level) * 0.08 + float(pulse_level) * 0.05 + passive_bonus + (0.16 if evolved else 0.0))
	if squad_has_bond("bond_guard_echo"):
		heal_amount *= 1.10
	var aura_duration: float = 2.2 + float(crescendo_level) * 0.45 + float(pulse_level) * 0.22 + (1.1 if evolved else 0.0)

	if GameManager.squad_manager != null and is_instance_valid(GameManager.squad_manager) and GameManager.squad_manager.has_method("heal_members"):
		GameManager.squad_manager.heal_members(heal_amount)
	GameManager.temporary_squad_damage_timer = max(float(GameManager.get("temporary_squad_damage_timer")), aura_duration)

	_damage_nearby_enemies(radius, stats, evolved)
	_spawn_hymn_visuals(radius, stats, evolved)
	register_trigger()
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("pulse", false, -6.0, 1.18)


func _damage_nearby_enemies(radius: float, stats: Dictionary, evolved: bool) -> void:
	var pulse_damage: float = data_float("damage", 10.0) * GameManager.get_outgoing_damage_multiplier(owner_player) * (0.34 if evolved else 0.22)
	var hits: int = 0
	var hit_ids: Dictionary = {}
	for center in _hymn_centers(radius):
		for enemy in EntityFactory.get_enemies_in_radius(center, radius + 24.0):
			if hits >= MAX_ECHO_TARGETS:
				return
			if enemy == null or not is_instance_valid(enemy):
				continue
			var hit_key := _hit_key_for(enemy)
			if hit_ids.has(hit_key):
				continue
			var enemy_radius: float = float(enemy.get("radius"))
			if center.distance_squared_to(enemy.global_position) > (radius + enemy_radius) * (radius + enemy_radius):
				continue
			hit_ids[hit_key] = true
			if enemy.has_method("take_damage"):
				var applied_damage: float = float(enemy.take_damage(pulse_damage, center))
				GameManager.record_weapon_damage(owner_player, get_weapon_id(), applied_damage)
				hits += 1
			if evolved and enemy.has_method("apply_knockback"):
				enemy.apply_knockback(center, 18.0)
			if evolved and enemy.has_method("apply_status_effect"):
				enemy.apply_status_effect("slow", 0.5, 0.16)


func _hymn_centers(radius: float) -> Array[Vector2]:
	var centers: Array[Vector2] = [owner_player.global_position]
	var members: Array = []
	if GameManager.squad_manager != null and is_instance_valid(GameManager.squad_manager) and GameManager.squad_manager.has_method("get_members"):
		members = GameManager.squad_manager.get_members()
	for member in members:
		if member == null or not is_instance_valid(member) or member == owner_player:
			continue
		var member_alive: Variant = member.get("is_alive")
		if member_alive != null and bool(member_alive) == false:
			continue
		if owner_player.global_position.distance_squared_to(member.global_position) <= radius * radius:
			centers.append(member.global_position)
	return centers


func _hit_key_for(body: Node) -> int:
	if body != null and body.has_method("get_hit_token"):
		return int(body.get_hit_token())
	return int(body.get_instance_id())


func _spawn_hymn_visuals(radius: float, stats: Dictionary, evolved: bool) -> void:
	var color: Color = stats.get("color", data_color("color", Color(0.52, 0.96, 1.0)))
	var visual_level := int(stats.get("visual_level", 0))
	EntityFactory.spawn_death_burst(owner_player.global_position, color, (1.25 if evolved else 0.95) * (1.0 + float(visual_level) * 0.045), "level_column")
	var members: Array = []
	if GameManager.squad_manager != null and is_instance_valid(GameManager.squad_manager) and GameManager.squad_manager.has_method("get_members"):
		members = GameManager.squad_manager.get_members()
	for member in members:
		if member == null or not is_instance_valid(member) or member == owner_player:
			continue
		var member_alive: Variant = member.get("is_alive")
		if member_alive != null and bool(member_alive) == false:
			continue
		if owner_player.global_position.distance_squared_to(member.global_position) > radius * radius:
			continue
		EntityFactory.spawn_lightning_arc(
			[owner_player.global_position, member.global_position],
			color,
			0.16,
			data_string("lightning_sprite_path", "res://assets/sprites/proj_lightning.png"),
			18.0 if evolved else 13.0
		)
