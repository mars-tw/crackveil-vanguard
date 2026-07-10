extends "res://scripts/weapons/base_weapon.gd"


func _process(delta: float) -> void:
	if owner_player == null or data == null or not GameManager.game_running:
		return

	cooldown_timer -= delta
	if cooldown_timer > 0.0:
		return

	var target := find_nearest_enemy(data_float("range", 520.0))
	var detonation_position: Vector2 = owner_player.global_position
	if target != null:
		detonation_position = target.global_position

	var effect_stats := data_effect_stats()
	EntityFactory.spawn_explosion(detonation_position, effect_stats, owner_player)
	if int(effect_stats.get("pulse_embers_level", 0)) > 0:
		EntityFactory.spawn_hazard_zone(detonation_position, _make_ember_stats(effect_stats), owner_player)
	register_trigger()
	cooldown_timer = data_float("cooldown", 1.0)


func _make_ember_stats(effect_stats: Dictionary) -> Dictionary:
	return {
		"damage_per_second": float(effect_stats.get("damage", 18.0)) * 0.22,
		"area_radius": float(effect_stats.get("area_radius", 82.0)) * 0.64,
		"duration": 1.2,
		"tick_interval": 0.24,
		"color": effect_stats.get("color", Color(1.0, 0.48, 0.14))
	}
