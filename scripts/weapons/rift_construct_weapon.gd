extends "res://scripts/weapons/base_weapon.gd"

var pending_target: WeakRef = null
var pending_target_token: int = 0
var attack_pending: bool = false
var owner_visual: Node = null
var debug_target_acquisitions: int = 0
var debug_cast_starts: int = 0
var debug_cast_rejections: int = 0
var debug_cast_cancellations: int = 0
var debug_impact_events: int = 0
var debug_impact_whiffs: int = 0


func setup(player_node: Node2D, weapon_data: Resource) -> void:
	super.setup(player_node, weapon_data)
	owner_visual = owner_player.get_node_or_null("Visual") if owner_player != null else null
	if owner_visual != null and owner_visual.has_signal("attack_impact"):
		var callback := Callable(self, "_on_attack_impact")
		if not owner_visual.is_connected("attack_impact", callback):
			owner_visual.connect("attack_impact", callback)


func _process(delta: float) -> void:
	if owner_player == null or data == null or not GameManager.game_running:
		return
	if attack_pending:
		if owner_visual == null or not owner_visual.has_method("get_animation_state") or owner_visual.get_animation_state() != &"attack":
			debug_cast_cancellations += 1
			attack_pending = false
			pending_target = null
			pending_target_token = 0
		return
	cooldown_timer -= delta
	if cooldown_timer > 0.0:
		return
	var target := find_nearest_enemy(data_float("range", 420.0))
	if target == null:
		return
	debug_target_acquisitions += 1
	_begin_cast(target)


func _begin_cast(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target) or attack_pending:
		return false
	if owner_visual == null or not owner_visual.has_method("play_attack"):
		debug_cast_rejections += 1
		return false
	pending_target = weakref(target)
	pending_target_token = _target_token(target)
	if not bool(owner_visual.call("play_attack")):
		debug_cast_rejections += 1
		pending_target = null
		pending_target_token = 0
		return false
	attack_pending = true
	debug_cast_starts += 1
	cooldown_timer = scaled_cooldown(data_float("cooldown", 2.4))
	var direction := (target.global_position - owner_player.global_position).normalized()
	if direction != Vector2.ZERO and owner_visual.has_method("set_facing_direction"):
		owner_visual.call("set_facing_direction", direction)
	return true


func _on_attack_impact() -> void:
	if not attack_pending:
		return
	debug_impact_events += 1
	attack_pending = false
	var target := pending_target.get_ref() as Node2D if pending_target != null else null
	pending_target = null
	# In a full squad the originally marked enemy may be recycled during the two
	# anticipation frames. Reacquire only for that lifecycle change, and only on
	# the active frame. A living target that simply left range remains a whiff.
	if _target_lifecycle_ended(target):
		target = find_nearest_enemy(data_float("range", 420.0))
		pending_target_token = _target_token(target)
	if not _target_is_valid_at_impact(target):
		debug_impact_whiffs += 1
		pending_target_token = 0
		return
	pending_target_token = 0
	_deploy_constructs(target)


func _target_is_valid_at_impact(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target) or owner_player == null or not is_instance_valid(owner_player):
		return false
	if _target_token(target) != pending_target_token:
		return false
	var active_value: Variant = target.get("is_active")
	if active_value != null and not bool(active_value):
		return false
	var max_range := data_float("range", 420.0)
	return owner_player.global_position.distance_squared_to(target.global_position) <= max_range * max_range


func _target_lifecycle_ended(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return true
	if _target_token(target) != pending_target_token:
		return true
	var active_value: Variant = target.get("is_active")
	return active_value != null and not bool(active_value)


func _deploy_constructs(target: Node2D) -> void:
	var direction := (target.global_position - owner_player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = owner_player.get_facing_direction() if owner_player.has_method("get_facing_direction") else Vector2.RIGHT
	var side := direction.rotated(PI * 0.5)
	var stats := _construct_stats()
	var anchor_level := int(stats.get("construct_anchor_level", 0))
	var spawn_count := 2 if anchor_level >= 2 else 1
	var active_cap := _owner_active_cap(stats)
	var spawn_offset := float(stats.get("spawn_offset", 72.0))
	for index in range(spawn_count):
		var lane := float(index) - float(spawn_count - 1) * 0.5
		var position := owner_player.global_position + direction * spawn_offset + side * lane * 30.0
		EntityFactory.spawn_rift_construct(position, stats, owner_player, self, active_cap)
	register_trigger()
	EntityFactory.spawn_death_burst(owner_player.global_position + direction * 30.0, stats.get("color", Color(0.55, 0.82, 1.0)), 0.76, "spark")
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("pulse", false, -7.0, 0.88)


func _construct_stats() -> Dictionary:
	var stats := data_effect_stats().duplicate(true)
	var anchor_level := int(stats.get("construct_anchor_level", 0))
	stats["damage"] = data_float("damage", 7.0) * GameManager.get_outgoing_damage_multiplier(owner_player) * (0.85 if anchor_level >= 2 else 1.0)
	stats["effect_lifetime"] = data_float("effect_lifetime", 5.5) + (1.2 if anchor_level >= 1 else 0.0)
	stats["area_radius"] = data_float("area_radius", 54.0) + (8.0 if anchor_level >= 1 else 0.0)
	stats["source_weapon_id"] = get_weapon_id()
	return stats


func _owner_active_cap(stats: Dictionary) -> int:
	var cap := data_int("projectile_count", 3)
	if owner_passive_id() == "shepherd":
		cap += int(owner_passive_value())
	var squad := GameManager.squad_manager
	if squad != null and is_instance_valid(squad) and squad.has_method("has_active_bond") and squad.has_active_bond("bond_captain_shepherd"):
		cap += 1
	return mini(cap, int(stats.get("hard_cap_global", 6)))


func _target_token(target: Node) -> int:
	if target != null and target.has_method("get_hit_token"):
		return int(target.get_hit_token())
	return 0 if target == null else int(target.get_instance_id())


func release_owned_nodes() -> void:
	attack_pending = false
	pending_target = null
	pending_target_token = 0
	if owner_player != null and is_instance_valid(owner_player):
		EntityFactory.release_rift_constructs_for_owner(owner_player, false)


func get_debug_state() -> Dictionary:
	return {
		"targets": debug_target_acquisitions,
		"casts": debug_cast_starts,
		"rejections": debug_cast_rejections,
		"cancellations": debug_cast_cancellations,
		"impacts": debug_impact_events,
		"whiffs": debug_impact_whiffs,
		"pending": attack_pending,
		"cooldown": cooldown_timer,
		"visual_state": str(owner_visual.call("get_animation_state")) if owner_visual != null and owner_visual.has_method("get_animation_state") else "missing"
	}
