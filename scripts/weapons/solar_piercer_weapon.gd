extends "res://scripts/weapons/impact_weapon_base.gd"

func _perform_impact(_target: Node2D, direction: Vector2) -> void:
	var origin := owner_player.global_position
	var spear_range := data_float("range", 390.0)
	var width := data_float("projectile_radius", 12.0)
	var lanes := mini(8, data_int("projectile_count", 2))
	var brand := int(data.get_modifier_level("solar_brand"))
	var evolved := bool(data.is_evolved())
	var amount := data_float("damage", 34.0) * GameManager.get_outgoing_damage_multiplier(owner_player)
	if owner_passive_id() == "solar_lancer":
		amount *= 1.0 + owner_passive_value()
	var hit_once: Dictionary = {}
	for lane in range(lanes):
		var offset := (float(lane) - float(lanes - 1) * 0.5) * 22.0
		var start := origin + direction.orthogonal() * offset
		var candidates: Array = []
		for enemy in EntityFactory.get_enemies_in_radius(start + direction * spear_range * 0.5, spear_range * 0.5 + width + 40.0):
			var relative: Vector2 = enemy.global_position - start
			var projection := relative.dot(direction)
			if projection >= 0.0 and projection <= spear_range and absf(relative.cross(direction)) <= width + float(enemy.get("radius")):
				candidates.append({"enemy": enemy, "projection": projection})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.projection) < float(b.projection))
		var points: Array[Vector2] = [start + direction * 16.0]
		var pierced := 0
		var tail := start + direction * minf(70.0, spear_range)
		for candidate in candidates:
			var enemy: Node2D = candidate.enemy
			if hit_once.has(enemy.get_instance_id()) or enemy.get("is_active") != true:
				continue
			hit_once[enemy.get_instance_id()] = true
			tail = enemy.global_position
			points.append(tail)
			_record_hit(enemy, amount * pow(0.94, float(pierced)))
			if brand > 0 and enemy.get("is_active") == true:
				enemy.apply_status_effect("vulnerable", 1.4, 0.10 * brand)
			pierced += 1
			if pierced >= data_int("pierce", 3) + 1:
				break
		if points.size() == 1:
			points.append(tail)
		EntityFactory.spawn_lightning_arc(points, data_color("color", Color.GOLD), 0.14,
			"res://assets/sprites/proj_lightning.png", 26.0)
		if evolved and pierced > 0:
			EntityFactory.spawn_explosion(tail, {"damage": amount * 0.35, "area_radius": 52.0, "effect_lifetime": 0.2,
				"color": data_color("color", Color.GOLD), "source_weapon_id": get_weapon_id(),
				"explosion_sprite_path": "res://assets/vfx/kenney_particle/burst_fire_cyan.png"}, owner_player)
