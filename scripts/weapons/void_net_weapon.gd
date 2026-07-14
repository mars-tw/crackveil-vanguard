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

	_cast_net(target.global_position)
	cooldown_timer = scaled_cooldown(data_float("cooldown", 1.0))


func _cast_net(target_position: Vector2) -> void:
	var effect_stats := _make_net_stats()
	EntityFactory.spawn_hazard_zone(target_position, effect_stats, owner_player)
	EntityFactory.spawn_death_burst(target_position, effect_stats.get("color", Color(0.58, 0.42, 1.0)), 1.12, "spark")
	register_trigger()
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("pulse", false, -7.0, 0.68)


func _make_net_stats() -> Dictionary:
	var stats := data_effect_stats().duplicate(true)
	var anchor_level := int(stats.get("void_anchor_level", 0))
	var evolved := int(stats.get("evo_event_horizon_level", 0)) > 0
	var passive_bonus := owner_passive_value() if owner_passive_id() == "void_weaver" else 0.0
	var radius: float = float(stats.get("area_radius", data_float("area_radius", 76.0))) * (1.0 + passive_bonus)
	return {
		"damage_per_second": data_float("damage", 9.0) * GameManager.get_outgoing_damage_multiplier(owner_player) * (0.38 + float(anchor_level) * 0.08 + (0.1 if evolved else 0.0)),
		"source_weapon_id": get_weapon_id(),
		"area_radius": radius,
		"duration": data_float("effect_lifetime", 2.6) + float(anchor_level) * 0.55 + (0.8 if evolved else 0.0) + (0.4 if squad_has_bond("bond_void_rail") else 0.0),
		"tick_interval": 0.32,
		"color": stats.get("color", data_color("color", Color(0.58, 0.42, 1.0))),
		"status_effect": "slow",
		"status_duration": 0.48 + (0.18 if evolved else 0.0),
		"status_strength": 0.24 + float(anchor_level) * 0.08 + (0.06 if evolved else 0.0),
		"secondary_status_effect": "vulnerable" if evolved else "",
		"secondary_status_duration": 0.42,
		"secondary_status_strength": 0.12
	}
