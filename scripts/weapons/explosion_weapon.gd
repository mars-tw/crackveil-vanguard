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

	var effect_stats := _effect_stats_for_fire()
	EntityFactory.spawn_explosion(detonation_position, effect_stats, owner_player)
	if int(effect_stats.get("pulse_embers_level", 0)) > 0 or int(effect_stats.get("evo_ember_well_level", 0)) > 0:
		EntityFactory.spawn_hazard_zone(detonation_position, _make_ember_stats(effect_stats), owner_player)
	if int(effect_stats.get("evo_ember_well_level", 0)) > 0:
		EntityFactory.spawn_delayed_explosion(
			detonation_position,
			_make_ember_well_delayed_explosion_stats(effect_stats),
			owner_player,
			0.45
		)
	register_trigger()
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("fire")
	cooldown_timer = scaled_cooldown(data_float("cooldown", 1.0))


func _effect_stats_for_fire() -> Dictionary:
	var stats := data_effect_stats().duplicate(true)
	stats["damage"] = float(stats.get("damage", data_float("damage", 18.0))) * GameManager.get_outgoing_damage_multiplier(owner_player)
	if str(owner_player.get("hero_id")) == "pulse_artificer" and squad_has_bond("bond_ember_pulse"):
		stats["area_radius"] = float(stats.get("area_radius", data_float("area_radius", 82.0))) * 1.08
	return stats


func _make_ember_stats(effect_stats: Dictionary) -> Dictionary:
	if int(effect_stats.get("evo_ember_well_level", 0)) > 0:
		return {
			"damage_per_second": float(effect_stats.get("damage", 18.0)) * 0.2 * (1.06 if squad_has_bond("bond_ember_pulse") else 1.0),
			"source_weapon_id": str(effect_stats.get("source_weapon_id", get_weapon_id())),
			"area_radius": float(effect_stats.get("area_radius", 82.0)) * 0.72,
			"duration": 2.0,
			"tick_interval": 0.45,
			"color": Color(1.0, 0.32, 0.14),
			"status_effect": "slow",
			"status_duration": 0.7,
			"status_strength": 0.18
		}
	return {
		"damage_per_second": float(effect_stats.get("damage", 18.0)) * 0.22 * (1.06 if squad_has_bond("bond_ember_pulse") else 1.0),
		"source_weapon_id": str(effect_stats.get("source_weapon_id", get_weapon_id())),
		"area_radius": float(effect_stats.get("area_radius", 82.0)) * 0.64,
		"duration": 1.2,
		"tick_interval": 0.24,
		"color": effect_stats.get("color", Color(1.0, 0.48, 0.14))
	}


func _make_ember_well_delayed_explosion_stats(effect_stats: Dictionary) -> Dictionary:
	return {
		"damage": float(effect_stats.get("damage", 18.0)) * 0.55,
		"source_weapon_id": str(effect_stats.get("source_weapon_id", get_weapon_id())),
		"area_radius": float(effect_stats.get("area_radius", 82.0)) * 0.82,
		"effect_lifetime": 0.24,
		"explosion_sprite_path": str(effect_stats.get("explosion_sprite_path", "res://assets/vfx/kenney_particle/burst_fire_ember.png")),
		"color": Color(1.0, 0.52, 0.2),
		"sprite_scale": float(effect_stats.get("sprite_scale", 1.0)) * 0.82,
		"visual_level": int(effect_stats.get("visual_level", 0)),
		"evolved_visual": bool(effect_stats.get("evolved_visual", false))
	}
