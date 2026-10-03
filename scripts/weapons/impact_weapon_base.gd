extends "res://scripts/weapons/base_weapon.gd"

var owner_visual: Node = null
var attack_pending := false
var pending_target: WeakRef = null
var pending_spawn_token := 0
var pending_direction := Vector2.RIGHT
var cast_starts := 0
var impact_events := 0
var cancelled_casts := 0
var whiffs := 0
var damage_hits := 0

func setup(player_node: Node2D, weapon_data: Resource) -> void:
	_disconnect_visual()
	super.setup(player_node, weapon_data)
	owner_visual = owner_player.get_node_or_null("Visual")
	if owner_visual != null and owner_visual.has_signal("attack_impact"):
		owner_visual.connect("attack_impact", Callable(self, "_on_attack_impact"))

func _disconnect_visual() -> void:
	if is_instance_valid(owner_visual) and owner_visual.is_connected("attack_impact", Callable(self, "_on_attack_impact")):
		owner_visual.disconnect("attack_impact", Callable(self, "_on_attack_impact"))
	owner_visual = null

func _exit_tree() -> void:
	_disconnect_visual()
	_cancel_cast()

func reset_weapon() -> void:
	super.reset_weapon()
	_cancel_cast()
	cast_starts = 0
	impact_events = 0
	cancelled_casts = 0
	whiffs = 0
	damage_hits = 0

func _process(delta: float) -> void:
	if not is_instance_valid(owner_player) or data == null:
		_cancel_cast()
		return
	if not GameManager.game_running or owner_player.get("is_alive") == false:
		_cancel_cast()
		return
	firing_clock += delta
	if attack_pending:
		if not is_instance_valid(owner_visual) or owner_visual.call("get_animation_state") != &"attack":
			cancelled_casts += 1
			_cancel_cast()
		return
	cooldown_timer -= delta
	if cooldown_timer > 0.0:
		return
	var target := find_nearest_enemy(data_float("range", 400.0))
	if target != null:
		_begin_cast(target)

func _begin_cast(target: Node2D) -> bool:
	if not is_instance_valid(target) or attack_pending or not is_instance_valid(owner_visual):
		return false
	if not GameManager.game_running or owner_player.get("is_alive") == false:
		return false
	var direction := (target.global_position - owner_player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	if not bool(owner_visual.call("play_attack")):
		return false
	# Hero._update_facing holds this direction while any real attack animation
	# is busy, including follower casts. Keep its shared lock aligned with aim.
	owner_player.set("attack_direction_lock", direction)
	owner_visual.call("set_facing_direction", direction)
	pending_target = weakref(target)
	pending_spawn_token = int(target.get("spawn_token"))
	pending_direction = direction
	attack_pending = true
	cast_starts += 1
	cooldown_timer = scaled_cooldown(data_float("cooldown", 1.2))
	return true

func _on_attack_impact() -> void:
	if not attack_pending:
		return
	var target := pending_target.get_ref() as Node2D if pending_target != null else null
	var token := pending_spawn_token
	var direction := pending_direction
	_cancel_cast()
	if not GameManager.game_running or not is_instance_valid(owner_player) or owner_player.get("is_alive") == false:
		return
	impact_events += 1
	if not is_instance_valid(target) or target.get("is_active") != true or int(target.get("spawn_token")) != token:
		whiffs += 1
		return
	var max_range := data_float("range", 400.0)
	if owner_player.global_position.distance_squared_to(target.global_position) > max_range * max_range:
		whiffs += 1
		return
	_perform_impact(target, direction)
	register_trigger()

func _cancel_cast() -> void:
	attack_pending = false
	pending_target = null
	pending_spawn_token = 0

func _perform_impact(_target: Node2D, _direction: Vector2) -> void:
	pass

func _record_hit(enemy: Node, amount: float) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	var actual := float(enemy.call("take_damage", amount, owner_player.global_position))
	if actual > 0.0:
		damage_hits += 1
		GameManager.record_weapon_damage(owner_player, get_weapon_id(), actual)

func get_firepower_debug_state() -> Dictionary:
	var state := super.get_firepower_debug_state()
	state.merge({"cast_starts": cast_starts, "impact_events": impact_events, "cancelled_casts": cancelled_casts,
		"whiffs": whiffs, "damage_hits": damage_hits, "pending": attack_pending, "impact_frame": 2,
		"evolved": data.is_evolved() if data != null else false})
	return state
