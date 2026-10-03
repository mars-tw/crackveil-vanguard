extends "res://scripts/weapons/impact_weapon_base.gd"

func _perform_impact(_target: Node2D, direction: Vector2) -> void:
	var count := mini(8, data_int("projectile_count", 2))
	var growth := int(data.get_modifier_level("shadow_return"))
	var stats := data_projectile_stats().duplicate(true)
	var amount := data_float("damage", 22.0) * GameManager.get_outgoing_damage_multiplier(owner_player)
	if owner_passive_id() == "shadow_ronin":
		amount *= 1.0 + owner_passive_value()
	stats.merge({"damage": amount, "motion_mode": "boomerang", "boomerang_rebound_level": growth,
		"evo_razor_bulwark_level": 1 if data.is_evolved() else 0,
		"range": data_float("range", 380.0) + (35.0 if growth >= 2 else 0.0)}, true)
	for index in range(count):
		var angle := deg_to_rad(data_float("spread_degrees", 16.0)) * (float(index) - float(count - 1) * 0.5)
		var forward := direction.rotated(angle)
		var offset := direction.orthogonal() * (float(index) - float(count - 1) * 0.5) * 10.0
		register_projectile_spawn(EntityFactory.spawn_projectile(owner_player.global_position + forward * 22.0 + offset,
			forward, stats, owner_player))
