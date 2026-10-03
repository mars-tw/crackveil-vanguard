extends "res://scripts/weapons/impact_weapon_base.gd"

var healing_delivered := 0.0
var slowed_targets := 0

func reset_weapon() -> void:
	super.reset_weapon()
	healing_delivered = 0.0
	slowed_targets = 0

func _perform_impact(target: Node2D, direction: Vector2) -> void:
	var center := target.global_position
	var radius := data_float("area_radius", 88.0)
	var growth := int(data.get_modifier_level("tide_rejuvenation"))
	var evolved := bool(data.is_evolved())
	var amount := data_float("damage", 24.0) * GameManager.get_outgoing_damage_multiplier(owner_player)
	for enemy in EntityFactory.get_enemies_in_radius(center, radius):
		_record_hit(enemy, amount)
		if enemy.get("is_active") == true:
			enemy.apply_status_effect("slow", data_float("effect_lifetime", 1.3), 0.24 + 0.08 * growth)
			slowed_targets += 1
	# The pooled explosion is cosmetic here; exact damage/status was applied once.
	EntityFactory.spawn_explosion(center, {"damage": 0.0, "area_radius": radius, "effect_lifetime": 0.32,
		"color": data_color("color", Color.AQUAMARINE), "source_weapon_id": get_weapon_id(),
		"explosion_sprite_path": "res://assets/vfx/kenney_particle/burst_fire_cyan.png"}, owner_player)
	var heal := float(growth * 2 + (2 if evolved else 0))
	if owner_passive_id() == "tide_oracle":
		heal += owner_passive_value()
	var squad: Node = owner_player.get("squad_manager")
	if is_instance_valid(squad) and heal > 0.0:
		for member in squad.get_members():
			if not is_instance_valid(member) or member.get("is_alive") == false:
				continue
			if owner_player.global_position.distance_squared_to(member.global_position) > 340.0 * 340.0:
				continue
			var before := float(member.get("current_hp"))
			member.heal(heal)
			healing_delivered += float(member.get("current_hp")) - before
	if evolved:
		for index in range(6):
			var stats := data_projectile_stats().duplicate(true)
			stats.merge({"damage": amount * 0.28, "motion_mode": "homing", "homing_target": target,
				"homing_turn_rate": 6.8, "homing_retarget_radius": 460.0, "projectile_speed": 340.0,
				"range": 420.0, "projectile_radius": 6.0, "pierce": 1}, true)
			register_projectile_spawn(EntityFactory.spawn_projectile(center,
				direction.rotated(TAU * float(index) / 6.0), stats, owner_player))

func get_firepower_debug_state() -> Dictionary:
	var state := super.get_firepower_debug_state()
	state.merge({"healing_delivered": healing_delivered, "slowed_targets": slowed_targets})
	return state
