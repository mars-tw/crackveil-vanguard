extends "res://scripts/weapons/base_weapon.gd"

const MAX_GRENADES_PER_SALVO := 5


func _process(delta: float) -> void:
	if owner_player == null or data == null or not GameManager.game_running:
		return

	cooldown_timer -= delta
	if cooldown_timer > 0.0:
		return

	var target := find_nearest_enemy(data_float("range", 560.0))
	if target == null:
		return

	_lob_at(target)
	cooldown_timer = scaled_cooldown(data_float("cooldown", 1.0))


func _lob_at(target: Node2D) -> void:
	var origin: Vector2 = owner_player.global_position
	var base_direction: Vector2 = (target.global_position - origin).normalized()
	if base_direction == Vector2.ZERO:
		base_direction = _owner_facing_direction()

	var effect_stats := _effect_stats_for_fire()
	var projectile_count: int = min(MAX_GRENADES_PER_SALVO, max(1, data_int("projectile_count", 1)))
	var spread_distance: float = min(86.0, data_float("area_radius", 82.0) * 0.72)
	var side: Vector2 = base_direction.rotated(PI * 0.5)
	for index in range(projectile_count):
		var lane: float = float(index) - float(projectile_count - 1) * 0.5
		var target_position: Vector2 = target.global_position + side * lane * spread_distance
		var spawn_position: Vector2 = origin + base_direction * 18.0 + side * lane * 6.0
		var shot_stats := _projectile_stats_for_lob(target_position, effect_stats)
		EntityFactory.spawn_projectile(spawn_position, base_direction, shot_stats, owner_player)

	register_trigger()
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("fire", false, -4.0, 0.74)


func _projectile_stats_for_lob(target_position: Vector2, effect_stats: Dictionary) -> Dictionary:
	var stats := data_projectile_stats().duplicate(true)
	var cluster_level := int(effect_stats.get("grenade_cluster_level", 0))
	var evolved := int(effect_stats.get("evo_cinder_barrage_level", 0)) > 0
	stats["motion_mode"] = "lob"
	stats["target_group"] = "none"
	stats["lob_target_position"] = target_position
	stats["lob_arc_height"] = clamp(target_position.distance_to(owner_player.global_position) * 0.14, 34.0, 92.0)
	stats["lob_explosion_stats"] = _make_explosion_stats(effect_stats)
	stats["lob_hazard_stats"] = _make_burn_stats(effect_stats)
	stats["lob_cluster_count"] = 1 + cluster_level + (2 if evolved else 0)
	stats["lob_cluster_radius"] = float(effect_stats.get("area_radius", 82.0)) * (0.62 if evolved else 0.46)
	stats["projectile_sprite_path"] = data_string("projectile_sprite_path", "res://assets/sprites/proj_bullet.png")
	stats["projectile_radius"] = data_float("projectile_radius", 6.0)
	stats["damage"] = 0.0
	stats["pierce"] = 0
	return stats


func _effect_stats_for_fire() -> Dictionary:
	var stats := data_effect_stats().duplicate(true)
	var passive_bonus := owner_passive_value() if owner_passive_id() == "ember_grenadier" else 0.0
	stats["damage"] = float(stats.get("damage", data_float("damage", 18.0))) * GameManager.get_outgoing_damage_multiplier(owner_player) * (1.0 + passive_bonus)
	stats["area_radius"] = float(stats.get("area_radius", data_float("area_radius", 82.0))) * (1.0 + passive_bonus * 0.7)
	return stats


func _make_explosion_stats(effect_stats: Dictionary) -> Dictionary:
	return {
		"damage": float(effect_stats.get("damage", data_float("damage", 18.0))),
		"source_weapon_id": get_weapon_id(),
		"area_radius": float(effect_stats.get("area_radius", data_float("area_radius", 82.0))),
		"effect_lifetime": data_float("effect_lifetime", 0.34),
		"explosion_sprite_path": data_string("explosion_sprite_path", "res://assets/vfx/kenney_particle/burst_fire_ember.png"),
		"color": effect_stats.get("color", data_color("color", Color(1.0, 0.48, 0.18))),
		"sprite_scale": data_float("sprite_scale", 1.0)
	}


func _make_burn_stats(effect_stats: Dictionary) -> Dictionary:
	var evolved := int(effect_stats.get("evo_cinder_barrage_level", 0)) > 0
	return {
		"damage_per_second": float(effect_stats.get("damage", data_float("damage", 18.0))) * (0.22 if evolved else 0.16),
		"source_weapon_id": get_weapon_id(),
		"area_radius": float(effect_stats.get("area_radius", data_float("area_radius", 82.0))) * (0.64 if evolved else 0.48),
		"duration": 1.8 if evolved else 1.15,
		"tick_interval": 0.34,
		"color": effect_stats.get("color", data_color("color", Color(1.0, 0.48, 0.18))),
		"status_effect": "slow",
		"status_duration": 0.42,
		"status_strength": 0.12 if evolved else 0.08
	}


func _owner_facing_direction() -> Vector2:
	if owner_player != null and owner_player.has_method("get_facing_direction"):
		return owner_player.get_facing_direction()
	return Vector2.RIGHT
