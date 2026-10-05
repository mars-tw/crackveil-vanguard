class_name Hero
extends CharacterBody2D

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const COMBAT_FEEDBACK := preload("res://scripts/vfx/combat_feedback.gd")
const DAMAGE_NUMBER_METRICS := preload("res://scripts/vfx/damage_number.gd")

const LEADER_CAMERA_ZOOM := Vector2(1.28, 1.28)
const LEADER_THREAT_CAMERA_ZOOM := Vector2(1.12, 1.12)
const LEADER_CAMERA_ZOOM_LERP_SPEED := 7.5
const RIFT_PULSE_COOLDOWN := 2.35
const RIFT_PULSE_RANGE := 360.0
const RIFT_PULSE_HALF_ANGLE := deg_to_rad(69.0)
const RIFT_PULSE_DAMAGE := 72.0
const RIFT_PULSE_KNOCKBACK := 108.0
const RIFT_PULSE_SLOW_DURATION := 0.55
const RIFT_PULSE_SLOW_STRENGTH := 0.34
const RIFT_PULSE_MAX_TARGETS := 48
const AUTO_CLEAVE_COOLDOWN := 0.40
const AUTO_CLEAVE_RANGE := 220.0
const AUTO_CLEAVE_HALF_ANGLE := deg_to_rad(57.5)
const AUTO_CLEAVE_DAMAGE := 26.0
const MOMENTUM_CHARGE_SECONDS := 1.15
const COMBO_ANIMATIONS: Array[StringName] = [&"attack_combo_a", &"attack_combo_b", &"attack_combo_finisher"]
const CHANNEL_HOLD_THRESHOLD := 0.23
const CHANNEL_INTERVAL := 0.34
const CHANNEL_MAX_ENERGY := 180.0
const CHANNEL_ENERGY_COST := 8.0
const CHANNEL_START_ENERGY := 16.0
const CHANNEL_ENERGY_REGEN := 32.0
const CHANNEL_RANGE := 280.0
const CHANNEL_DAMAGE := 38.0
const AUTO_CHANNEL_TRIGGER_RANGE := 360.0
const AUTO_CHANNEL_START_ENERGY := 80.0
const AUTO_CHANNEL_STOP_ENERGY := 40.0
const DRAW_CUT_STEP_MAX := 200.0
const DRAW_CUT_STEP_TARGET_RANGE := RIFT_PULSE_RANGE + DRAW_CUT_STEP_MAX - 24.0
const DRAW_CUT_ANTICIPATION_SECONDS := 2.0 / 18.0
const EMPTY_AUTO_CLEAVE_RETRY := 0.08

@export var weapon_catalog: Resource = preload("res://resources/weapons/weapon_catalog.tres")
@export var invulnerability_time: float = 0.65

var hero_data: Resource = null
var squad_manager: Node = null
var is_leader: bool = false
var formation_index: int = 0
var hero_id: String = ""
var display_name: String = "未命名英雄"
var passive_id: String = ""
var passive_value: float = 0.0
var max_hp: float = 100.0
var current_hp: float = 100.0
var temporary_shield_hp: float = 0.0
var temporary_shield_timer: float = 0.0
var move_speed: float = 220.0
var pickup_radius: float = 80.0
var hit_radius: float = 13.0
var invulnerability_timer: float = 0.0
var last_move_direction: Vector2 = Vector2.RIGHT
var desired_velocity: Vector2 = Vector2.ZERO
var movement_slow_timer: float = 0.0
var movement_slow_strength: float = 0.0
var weapons: Dictionary = {}
var weapon_order: Array[String] = []
var is_alive: bool = true
var facing_refresh_timer: float = 0.0
var cached_facing_enemy: Node2D = null
var cached_facing_token: int = 0
var screen_shake_timer: float = 0.0
var screen_shake_duration: float = 0.0
var screen_shake_strength: float = 0.0
var active_ability_cooldown_timer: float = 0.0
var active_ability_cast_count: int = 0
var active_ability_pending: bool = false
var pending_active_ability_direction: Vector2 = Vector2.RIGHT
var active_ability_queued: bool = false
var active_ability_queue_timer: float = 0.0
var auto_cleave_cooldown_timer: float = 0.15
var auto_cleave_pending: bool = false
var pending_cleave_direction: Vector2 = Vector2.RIGHT
var pending_ability_charge: float = 0.0
var momentum_charge: float = 0.0
var auto_cleave_count: int = 0
var auto_cleave_hit_count: int = 0
var active_ability_hit_count: int = 0
var cleave_kills_total: int = 0
var last_cleave_hit_count: int = 0
var last_cleave_kill_count: int = 0
var peak_cleave_hit_count: int = 0
var impact_feedback_cooldown: float = 0.0
var charge_draw_timer: float = 0.0
var reclaim_generation: int = 0
var death_finalized: bool = false
var combo_index: int = 0
var pending_combo_index: int = 0
var combo_impact_counts: Array[int] = [0, 0, 0]
var attack_direction_lock := Vector2.RIGHT
var active_ability_touch_held: bool = false
var active_ability_hold_timer: float = 0.0
var channel_energy: float = CHANNEL_MAX_ENERGY
var channel_active: bool = false
var channel_exhausted: bool = false
var channel_pending: bool = false
var channel_reserved_energy: float = 0.0
var channel_cooldown_timer: float = 0.0
var channel_impacts: int = 0
var channel_hits: int = 0
var channel_energy_spent: float = 0.0
var channel_effect_started: bool = false
var auto_channel_enabled: bool = false
var auto_channel_active: bool = false
var auto_channel_user_override: bool = false
var auto_channel_actions: int = 0
var auto_channel_scan_timer: float = 0.0
var auto_channel_has_target: bool = false
var auto_channel_manual_guard: float = 0.0
var draw_cut_step_active := false
var draw_cut_step_direction := Vector2.RIGHT
var draw_cut_step_remaining := 0.0
var draw_cut_step_timer := 0.0
var draw_cut_step_target: Node2D = null
var draw_cut_step_token := 0
var draw_cut_step_distance := 0.0
var draw_cut_step_total_distance := 0.0
var draw_cut_assisted_casts := 0
var draw_cut_step_aborts := 0
var draw_cut_step_last_reason := "idle"
var active_ability_empty_impacts := 0
var auto_cleave_target_queries := 0
var cleave_candidate_checks := 0
var cleave_cone_sqrt_calls := 0
var presentation_cached_ref: WeakRef = null
var presentation_cached_arena_id := 0
var presentation_cached_generation := -1
var presentation_retry_msec := 0
var presentation_lookups := 0
var presentation_ready_checks := 0

@onready var visual: Node2D = $Visual
@onready var weapons_root: Node2D = $Weapons
@onready var camera: Camera2D = $Camera2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("heroes")
	_connect_visual_animation_signals()


func _connect_visual_animation_signals() -> void:
	if visual == null:
		return
	var impact_callback := Callable(self, "_on_visual_attack_impact")
	if visual.has_signal("attack_impact") and not visual.is_connected("attack_impact", impact_callback):
		visual.connect("attack_impact", impact_callback)
	var death_callback := Callable(self, "_on_visual_death_finished")
	if visual.has_signal("death_finished") and not visual.is_connected("death_finished", death_callback):
		visual.connect("death_finished", death_callback)
	var pause_callback := Callable(self, "_on_combat_pause_changed")
	if not GameManager.pause_changed.is_connected(pause_callback):
		GameManager.pause_changed.connect(pause_callback)


func setup(new_hero_data: Resource, new_squad_manager: Node, leader_flag: bool, slot_index: int) -> void:
	hero_data = new_hero_data.duplicate(true) if new_hero_data != null else null
	squad_manager = new_squad_manager
	is_leader = leader_flag
	formation_index = slot_index
	_apply_hero_data()
	reset_for_run()
	_configure_controller()


func _apply_hero_data() -> void:
	if hero_data == null:
		return

	hero_id = str(hero_data.get("id"))
	display_name = str(hero_data.get("display_name"))
	passive_id = str(hero_data.get("passive_id"))
	passive_value = float(hero_data.get("passive_value"))
	max_hp = float(hero_data.get("max_hp"))
	move_speed = float(hero_data.get("move_speed"))
	pickup_radius = float(hero_data.get("pickup_radius"))
	hit_radius = float(hero_data.get("hit_radius"))
	name = hero_id

	if visual != null:
		if visual.has_method("configure_visual"):
			visual.configure_visual(
				str(hero_data.get("sprite_path")),
				float(hero_data.get("sprite_scale")),
				hit_radius + 2.0,
				hero_data.get("body_color"),
				hero_data.get("core_color")
			)
		else:
			visual.set("body_color", hero_data.get("body_color"))
			visual.set("core_color", hero_data.get("core_color"))

	var shape_node := collision_shape
	if shape_node != null:
		var circle := CircleShape2D.new()
		circle.radius = hit_radius
		shape_node.shape = circle

	if camera != null:
		camera.enabled = is_leader
		if is_leader:
			camera.zoom = _leader_camera_zoom()
			camera.make_current()
		else:
			camera.zoom = Vector2.ONE


func reset_for_run() -> void:
	_stop_channel(true)
	_end_draw_cut_step("reset")
	draw_cut_step_distance = 0.0
	draw_cut_step_total_distance = 0.0
	draw_cut_assisted_casts = 0
	draw_cut_step_aborts = 0
	active_ability_empty_impacts = 0
	auto_cleave_target_queries = 0
	cleave_candidate_checks = 0
	cleave_cone_sqrt_calls = 0
	presentation_cached_ref = null
	presentation_cached_generation = -1
	presentation_retry_msec = 0
	presentation_lookups = 0
	presentation_ready_checks = 0
	combo_index = 0
	pending_combo_index = 0
	combo_impact_counts = [0, 0, 0]
	attack_direction_lock = Vector2.RIGHT
	active_ability_touch_held = false
	active_ability_hold_timer = 0.0
	channel_energy = CHANNEL_MAX_ENERGY
	channel_exhausted = false
	channel_cooldown_timer = 0.0
	channel_impacts = 0
	channel_hits = 0
	channel_energy_spent = 0.0
	auto_channel_active = false
	auto_channel_actions = 0
	auto_channel_scan_timer = 0.0
	auto_channel_has_target = false
	auto_channel_manual_guard = 0.0
	if not auto_channel_user_override:
		auto_channel_enabled = MOBILE_TUNING.use_mobile_ui(_camera_viewport_size())
	reclaim_generation += 1
	current_hp = max_hp
	temporary_shield_hp = 0.0
	temporary_shield_timer = 0.0
	invulnerability_timer = 0.0
	last_move_direction = Vector2.RIGHT
	desired_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	screen_shake_timer = 0.0
	screen_shake_duration = 0.0
	screen_shake_strength = 0.0
	active_ability_cooldown_timer = 0.0
	active_ability_cast_count = 0
	active_ability_pending = false
	active_ability_queued = false
	active_ability_queue_timer = 0.0
	auto_cleave_cooldown_timer = 0.15
	auto_cleave_pending = false
	pending_ability_charge = 0.0
	momentum_charge = 0.0
	auto_cleave_count = 0
	auto_cleave_hit_count = 0
	active_ability_hit_count = 0
	cleave_kills_total = 0
	last_cleave_hit_count = 0
	last_cleave_kill_count = 0
	peak_cleave_hit_count = 0
	impact_feedback_cooldown = 0.0
	pending_active_ability_direction = Vector2.RIGHT
	death_finalized = false
	movement_slow_timer = 0.0
	movement_slow_strength = 0.0
	is_alive = true
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)
	if not is_in_group("heroes"):
		add_to_group("heroes")
	if is_leader and not is_in_group("players"):
		add_to_group("players")
	if visual != null:
		visual.visible = true
		visual.modulate = Color.WHITE
		if visual.has_method("reset_facing_direction"):
			visual.reset_facing_direction()
		if visual.has_method("_resume_locomotion"):
			visual.call("_resume_locomotion")
	if camera != null:
		camera.offset = Vector2.ZERO
		if is_leader:
			camera.zoom = _leader_camera_zoom()
	_clear_weapons()
	_equip_starting_weapons()
	set_physics_process(true)
	set_process(true)


func _clear_weapons() -> void:
	weapons.clear()
	weapon_order.clear()
	if weapons_root == null:
		return

	for child in weapons_root.get_children():
		child.set_process(false)
		child.set_physics_process(false)
		if child.has_method("release_owned_nodes"):
			child.release_owned_nodes()
		child.free()


func _equip_starting_weapons() -> void:
	if hero_data == null:
		return

	var starting_weapon_ids: PackedStringArray = hero_data.get("starting_weapon_ids")
	for weapon_id in starting_weapon_ids:
		unlock_weapon(str(weapon_id))


func _configure_controller() -> void:
	for child in get_children():
		if child.is_in_group("hero_controllers"):
			child.queue_free()

	if is_leader:
		var controller := preload("res://scripts/heroes/player_controller.gd").new()
		controller.name = "PlayerController"
		add_child(controller)
		controller.setup(self)
	else:
		var follower := preload("res://scripts/heroes/follower_controller.gd").new()
		follower.name = "FollowerController"
		add_child(follower)
		follower.setup(self, squad_manager, formation_index)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if desired_velocity.length_squared() > 1.0:
		last_move_direction = desired_velocity.normalized()

	_tick_movement_slow(delta)
	velocity = desired_velocity.limit_length(move_speed * 1.35) * _movement_multiplier()
	var stepping := _draw_cut_step_valid()
	if stepping:
		velocity = draw_cut_step_direction * minf(draw_cut_step_remaining / maxf(delta, 0.0001), DRAW_CUT_STEP_MAX / DRAW_CUT_ANTICIPATION_SECONDS)
	var previous_position := global_position
	move_and_slide()
	_constrain_to_stage()
	if stepping:
		var distance := maxf(0.0, (global_position - previous_position).dot(draw_cut_step_direction))
		draw_cut_step_distance += distance
		draw_cut_step_total_distance += distance
		draw_cut_step_remaining = maxf(0.0, draw_cut_step_remaining - distance)
		draw_cut_step_timer -= delta
		if draw_cut_step_timer <= 0.0 or draw_cut_step_remaining <= 0.01:
			_end_draw_cut_step("anticipation_complete")
	_update_facing(delta)

	if invulnerability_timer > 0.0:
		invulnerability_timer = max(invulnerability_timer - delta, 0.0)
	if temporary_shield_timer > 0.0:
		temporary_shield_timer = max(temporary_shield_timer - delta, 0.0)
		if temporary_shield_timer <= 0.0:
			temporary_shield_hp = 0.0


func _process(delta: float) -> void:
	_tick_active_ability_cooldown(delta)
	_tick_captain_cleave(delta)
	_update_flash()
	_update_camera_zoom(delta)
	_update_camera_shake(delta)


func set_move_direction(direction: Vector2) -> void:
	desired_velocity = direction.normalized() * move_speed


func _input(event: InputEvent) -> void:
	if not is_leader or hero_id != "rift_captain" or not is_alive:
		return
	if event.is_action_released("active_ability") and not active_ability_touch_held:
		active_ability_hold_timer = 0.0
		channel_exhausted = false
		_stop_channel()


func _on_combat_pause_changed(_visible_manual_pause: bool) -> void:
	if get_tree() != null and get_tree().paused:
		_end_draw_cut_step("pause")
		active_ability_touch_held = false
		active_ability_hold_timer = 0.0
		channel_exhausted = false
		_stop_channel()


func set_desired_velocity(new_velocity: Vector2) -> void:
	desired_velocity = new_velocity


func apply_movement_slow(duration: float, strength: float) -> void:
	if not is_alive:
		return
	movement_slow_timer = max(movement_slow_timer, duration)
	movement_slow_strength = max(movement_slow_strength, clamp(strength, 0.0, 0.65))


func _tick_movement_slow(delta: float) -> void:
	if movement_slow_timer <= 0.0:
		movement_slow_strength = 0.0
		return
	movement_slow_timer = max(movement_slow_timer - delta, 0.0)
	if movement_slow_timer <= 0.0:
		movement_slow_strength = 0.0


func _movement_multiplier() -> float:
	return 1.0 - clamp(movement_slow_strength, 0.0, 0.65)


func get_facing_direction() -> Vector2:
	return get_visual_facing_direction()


func get_locomotion_facing_direction() -> Vector2:
	# A direction key and Space may arrive in the same controller tick.
	if desired_velocity.length_squared() > 1.0:
		return desired_velocity.normalized()
	if last_move_direction == Vector2.ZERO:
		return Vector2.RIGHT
	return last_move_direction.normalized()


func get_visual_facing_direction() -> Vector2:
	if visual != null:
		if visual.has_method("is_attack_animation") and visual.is_attack_animation():
			return attack_direction_lock
		if visual.has_method("get_animation_state") and visual.get_animation_state() in [&"hurt", &"death"]:
			return visual.get("facing_direction")
	return get_locomotion_facing_direction()


func begin_directional_attack(direction: Vector2, animation_name: StringName = &"attack") -> bool:
	if visual == null or not visual.has_method("play_attack"):
		return false
	var aim := direction.normalized() if direction.length_squared() > 0.001 else get_facing_direction()
	if not bool(visual.call("play_attack", animation_name)):
		return false
	# Commit once, only after the authored animation accepts this cast.
	attack_direction_lock = aim
	visual.call("set_facing_direction", aim)
	return true


func try_cast_active_ability() -> bool:
	if auto_channel_active and active_ability_cooldown_timer <= 0.0 and is_alive and GameManager.game_running and not get_tree().paused:
		_stop_channel()
		auto_channel_manual_guard = 0.45
	if not can_cast_active_ability():
		return false
	# A Space press during the recovery of an automatic cut is buffered. It
	# still starts a new authored attack, and damage remains on frame 2.
	if _captain_attack_busy():
		active_ability_queued = true
		active_ability_queue_timer = 0.65
		return true
	return _begin_active_ability()


func _begin_active_ability() -> bool:
	var target := get_nearest_enemy(DRAW_CUT_STEP_TARGET_RANGE)
	var forward := (target.global_position - global_position).normalized() if is_instance_valid(target) else get_facing_direction()
	if forward == Vector2.ZERO:
		forward = get_facing_direction()
	if visual == null or not visual.has_method("play_attack"):
		push_error("Active ability requires the articulated attack animation")
		return false
	if not begin_directional_attack(forward, &"attack_combo_a"):
		return false
	active_ability_cooldown_timer = RIFT_PULSE_COOLDOWN
	active_ability_cast_count += 1
	active_ability_pending = true
	active_ability_queued = false
	pending_active_ability_direction = forward
	pending_ability_charge = momentum_charge
	momentum_charge = 0.0
	_begin_draw_cut_step(target, forward)
	GameManager.emit_stats()
	return true


func _begin_draw_cut_step(target: Node2D, forward: Vector2) -> void:
	_end_draw_cut_step("new_cast")
	draw_cut_step_distance = 0.0
	if not is_instance_valid(target):
		return
	var distance := global_position.distance_to(target.global_position)
	# Close-range casts remain stationary. A manual new draw cut can close the
	# ranged build's empty outer gap during its real anticipation body poses.
	if distance <= RIFT_PULSE_RANGE:
		return
	draw_cut_step_remaining = minf(DRAW_CUT_STEP_MAX, distance - RIFT_PULSE_RANGE * 0.72)
	draw_cut_step_direction = forward
	draw_cut_step_timer = DRAW_CUT_ANTICIPATION_SECONDS
	draw_cut_step_target = target
	draw_cut_step_token = _hit_key_for(target)
	draw_cut_step_active = true
	draw_cut_step_last_reason = "anticipation"
	draw_cut_assisted_casts += 1


func _draw_cut_step_valid() -> bool:
	if not draw_cut_step_active:
		return false
	if not active_ability_pending or not is_alive or not GameManager.game_running:
		_end_draw_cut_step("inactive")
		return false
	if not is_instance_valid(draw_cut_step_target) or draw_cut_step_target.get("is_active") != true or _hit_key_for(draw_cut_step_target) != draw_cut_step_token:
		_end_draw_cut_step("target_invalid")
		return false
	if visual != null and visual.has_method("get_animation_state") and visual.call("get_animation_state") in [&"hurt", &"death"]:
		_end_draw_cut_step("hurt")
		return false
	return true


func _end_draw_cut_step(reason: String) -> void:
	if draw_cut_step_active and reason in ["hurt", "death", "pause", "reset", "target_invalid", "inactive"]:
		draw_cut_step_aborts += 1
	draw_cut_step_active = false
	draw_cut_step_remaining = 0.0
	draw_cut_step_timer = 0.0
	draw_cut_step_target = null
	draw_cut_step_token = 0
	draw_cut_step_last_reason = reason


func _on_visual_attack_impact() -> void:
	if not is_alive:
		return
	if channel_pending:
		channel_pending = false
		channel_reserved_energy = 0.0
		channel_energy_spent += CHANNEL_ENERGY_COST
		channel_impacts += 1
		var channel_hit_count := _damage_cleave(attack_direction_lock, CHANNEL_RANGE, PI, CHANNEL_DAMAGE, 54.0, 36, true)
		channel_hits += channel_hit_count
		if not channel_effect_started:
			channel_effect_started = _set_channel_presentation(true)
		if not channel_effect_started:
			_play_combat_presentation("cyclone", attack_direction_lock, 3.4, CHANNEL_RANGE, PI, true)
		if channel_hit_count > 0 and channel_impacts % 3 == 0:
			_request_cleave_impact(3.8, 0.0)
		return
	if active_ability_pending:
		_end_draw_cut_step("impact")
		active_ability_pending = false
		var hit_count := _cast_rift_pulse_damage(pending_active_ability_direction)
		active_ability_hit_count += hit_count
		if hit_count == 0:
			active_ability_empty_impacts += 1
		_spawn_rift_pulse_visuals(pending_active_ability_direction)
		if hit_count > 0:
			_request_cleave_impact(6.0 + minf(2.0, float(hit_count) * 0.2), 0.045)
			EntityFactory.call_deferred("magnetize_xp_near", global_position, RIFT_PULSE_RANGE + 60.0)
			_reclaim_draw_cut_drops(global_position, reclaim_generation)
		if AudioManager != null and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("cleave_heavy", false, -4.0, 0.94)
		return
	if auto_cleave_pending:
		auto_cleave_pending = false
		auto_cleave_count += 1
		var finisher := pending_combo_index == 2
		var swing_damage: float = float([AUTO_CLEAVE_DAMAGE, 30.0, 44.0][pending_combo_index])
		var swing_range := 260.0 if finisher else AUTO_CLEAVE_RANGE
		var swing_angle := PI if finisher else (deg_to_rad(72.5) if pending_combo_index == 1 else AUTO_CLEAVE_HALF_ANGLE)
		var count := _damage_cleave(pending_cleave_direction, swing_range, swing_angle, float(swing_damage), 62.0 if finisher else 36.0, 32 if finisher else 20)
		auto_cleave_hit_count += count
		combo_impact_counts[pending_combo_index] += 1
		combo_index = (pending_combo_index + 1) % 3
		_play_combat_presentation("cyclone" if finisher else ("slash_b" if pending_combo_index == 1 else "slash_a"), pending_cleave_direction, 3.15 if finisher else 2.65, swing_range, swing_angle, finisher)
		if count > 0 and finisher:
			_request_cleave_impact(2.5, 0.0)
		if AudioManager != null and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("cleave", false, -10.0, 1.04)


func can_cast_active_ability() -> bool:
	return (
		is_leader
		and hero_id == "rift_captain"
		and is_alive
		and active_ability_cooldown_timer <= 0.0
		and not active_ability_queued
		and not active_ability_pending
		and not channel_active
		and not channel_pending
		and GameManager.game_running
		and not get_tree().paused
	)


func get_active_ability_cooldown_remaining() -> float:
	return max(active_ability_cooldown_timer, 0.0)


func get_active_ability_cooldown_duration() -> float:
	return RIFT_PULSE_COOLDOWN


func get_active_ability_cooldown_ratio() -> float:
	return clamp(active_ability_cooldown_timer / RIFT_PULSE_COOLDOWN, 0.0, 1.0)


func get_active_ability_cast_count() -> int:
	return active_ability_cast_count


func _tick_active_ability_cooldown(delta: float) -> void:
	if active_ability_cooldown_timer <= 0.0:
		return
	active_ability_cooldown_timer = max(active_ability_cooldown_timer - delta, 0.0)


func _tick_captain_cleave(delta: float) -> void:
	if not is_leader or hero_id != "rift_captain" or not is_alive or not GameManager.game_running or get_tree().paused:
		return
	impact_feedback_cooldown = maxf(0.0, impact_feedback_cooldown - delta)
	auto_cleave_cooldown_timer = maxf(0.0, auto_cleave_cooldown_timer - delta)
	_tick_channel(delta)
	if desired_velocity.length_squared() > move_speed * move_speed * 0.1:
		momentum_charge = minf(1.0, momentum_charge + delta / MOMENTUM_CHARGE_SECONDS)
	charge_draw_timer -= delta
	if charge_draw_timer <= 0.0:
		charge_draw_timer = 0.08
		queue_redraw()
	# A dying/disabled visual cannot leave a pending hit armed forever.
	if (auto_cleave_pending or active_ability_pending) and not _captain_attack_busy():
		auto_cleave_pending = false
		active_ability_pending = false
		_end_draw_cut_step("inactive")
	if channel_pending and not _captain_attack_busy():
		_cancel_channel_pending()
	if channel_active:
		if channel_effect_started:
			_set_channel_presentation(true)
		if channel_cooldown_timer <= 0.0 and not _captain_attack_busy():
			_begin_channel_swing()
		return
	if active_ability_queued:
		active_ability_queue_timer -= delta
		if active_ability_queue_timer <= 0.0:
			active_ability_queued = false
		elif not _captain_attack_busy():
			_begin_active_ability()
		return
	if auto_cleave_cooldown_timer > 0.0 or _captain_attack_busy() or active_ability_pending:
		return
	auto_cleave_target_queries += 1
	var target := get_nearest_enemy(AUTO_CLEAVE_RANGE + 12.0)
	if target == null or not is_instance_valid(target) or visual == null or not visual.has_method("play_attack"):
		auto_cleave_cooldown_timer = EMPTY_AUTO_CLEAVE_RETRY
		return
	pending_combo_index = combo_index
	var aim := (target.global_position - global_position).normalized()
	if not begin_directional_attack(aim, COMBO_ANIMATIONS[pending_combo_index]):
		return
	pending_cleave_direction = attack_direction_lock
	auto_cleave_pending = true
	auto_cleave_cooldown_timer = AUTO_CLEAVE_COOLDOWN


func _captain_attack_busy() -> bool:
	return visual != null and ((visual.has_method("is_attack_animation") and bool(visual.call("is_attack_animation"))) or (visual.has_method("get_animation_state") and visual.call("get_animation_state") in [&"hurt", &"death"]))


func set_active_ability_held(value: bool) -> void:
	active_ability_touch_held = value
	if not value and not Input.is_action_pressed("active_ability"):
		active_ability_hold_timer = 0.0
		channel_exhausted = false
		_stop_channel()


func set_auto_channel_enabled(value: bool) -> void:
	auto_channel_user_override = true
	auto_channel_enabled = value
	if not value and auto_channel_active and not active_ability_touch_held and not Input.is_action_pressed("active_ability"):
		_stop_channel()


func _tick_channel(delta: float) -> void:
	channel_cooldown_timer = maxf(0.0, channel_cooldown_timer - delta)
	auto_channel_manual_guard = maxf(0.0, auto_channel_manual_guard - delta)
	var held := active_ability_touch_held or Input.is_action_pressed("active_ability")
	if not held:
		active_ability_hold_timer = 0.0
		channel_exhausted = false
		if (channel_active or channel_pending or channel_effect_started) and not auto_channel_active:
			_stop_channel()
	else:
		auto_channel_active = false
		active_ability_hold_timer += delta
		if active_ability_hold_timer >= CHANNEL_HOLD_THRESHOLD and not channel_exhausted and channel_energy >= CHANNEL_START_ENERGY:
			if not channel_active:
				# A long gesture takes over an unstarted tap buffered during a
				# prior swing. Do not fire that old tap when the channel ends.
				active_ability_queued = false
				active_ability_queue_timer = 0.0
			channel_active = true
	if not held and auto_channel_enabled and auto_channel_manual_guard <= 0.0 and not active_ability_pending and not active_ability_queued:
		auto_channel_scan_timer -= delta
		if auto_channel_scan_timer <= 0.0:
			auto_channel_scan_timer = 0.12
			auto_channel_has_target = get_nearest_enemy(AUTO_CHANNEL_TRIGGER_RANGE) != null
		if auto_channel_active:
			if not auto_channel_has_target or (channel_energy <= AUTO_CHANNEL_STOP_ENERGY and not channel_pending):
				_stop_channel()
		elif auto_channel_has_target and channel_energy >= AUTO_CHANNEL_START_ENERGY:
			auto_channel_active = true
			channel_active = true
			auto_channel_actions += 1
	if not channel_active and not channel_pending and not held:
		channel_energy = minf(CHANNEL_MAX_ENERGY, channel_energy + delta * CHANNEL_ENERGY_REGEN)


func _begin_channel_swing() -> void:
	if channel_energy < CHANNEL_ENERGY_COST:
		channel_exhausted = true
		_stop_channel()
		return
	if not begin_directional_attack(_active_ability_direction(), &"attack_combo_finisher"):
		return
	channel_energy -= CHANNEL_ENERGY_COST
	channel_reserved_energy = CHANNEL_ENERGY_COST
	channel_pending = true
	channel_cooldown_timer = CHANNEL_INTERVAL


func _cancel_channel_pending() -> void:
	if channel_pending:
		channel_energy = minf(CHANNEL_MAX_ENERGY, channel_energy + channel_reserved_energy)
	channel_pending = false
	channel_reserved_energy = 0.0


func _stop_channel(reset: bool = false) -> void:
	var was_pending := channel_pending
	var was_active := channel_active or channel_pending or channel_effect_started
	_cancel_channel_pending()
	channel_active = false
	auto_channel_active = false
	if channel_effect_started:
		_set_channel_presentation(false)
	channel_effect_started = false
	if was_pending and not reset and visual != null and visual.has_method("finish_attack_recovery"):
		visual.call("finish_attack_recovery")
	if not reset and was_active:
		auto_cleave_cooldown_timer = maxf(auto_cleave_cooldown_timer, 0.25)


func _presentation_service() -> Node:
	var arena_id := GameManager.arena.get_instance_id() if is_instance_valid(GameManager.arena) else 0
	if presentation_cached_arena_id == arena_id and presentation_cached_generation == reclaim_generation:
		var cached: Node = presentation_cached_ref.get_ref() if presentation_cached_ref != null else null
		if is_instance_valid(cached) and cached.is_inside_tree():
			return cached
		if presentation_cached_ref != null:
			# A positively cached service was removed: a replacement in this same
			# frame must be discoverable immediately, not wait for the miss TTL.
			presentation_retry_msec = 0
		if Time.get_ticks_msec() < presentation_retry_msec:
			return null
	presentation_cached_ref = null
	presentation_cached_arena_id = arena_id
	presentation_cached_generation = reclaim_generation
	presentation_retry_msec = Time.get_ticks_msec() + 250
	var tree := get_tree()
	presentation_lookups += 1
	var service: Node = tree.get_first_node_in_group("combat_presentation") if tree != null else null
	if service != null and service.has_method("get_debug_state"):
		presentation_ready_checks += 1
		var state: Dictionary = service.call("get_debug_state")
		if state.get("assets_ready", true) == false:
			return null
	if service != null:
		presentation_cached_ref = weakref(service)
	return service


func _set_channel_presentation(value: bool) -> bool:
	var service := _presentation_service()
	if service == null or not service.has_method("set_channel"):
		return false
	service.call("set_channel", self, value, global_position, attack_direction_lock, 3.4)
	return true


func _play_combat_presentation(kind: String, direction: Vector2, strength: float, fallback_range: float, fallback_angle: float, heavy: bool) -> void:
	var service := _presentation_service()
	if service != null and service.has_method("play_effect"):
		service.call("play_effect", kind, global_position, direction, strength)
	else:
		COMBAT_FEEDBACK.report_slash(global_position, direction, fallback_range, fallback_angle, heavy)


func get_channel_debug_state() -> Dictionary:
	return {"energy": channel_energy, "energy_max": CHANNEL_MAX_ENERGY, "energy_ratio": channel_energy / CHANNEL_MAX_ENERGY, "held": active_ability_touch_held or Input.is_action_pressed("active_ability"), "hold_seconds": active_ability_hold_timer, "active": channel_active, "pending": channel_pending, "exhausted": channel_exhausted, "impacts": channel_impacts, "hits": channel_hits, "energy_spent": channel_energy_spent, "combo_index": combo_index, "combo_impacts": combo_impact_counts.duplicate(), "auto_channel_enabled": auto_channel_enabled, "auto_channel_active": auto_channel_active, "auto_channel_actions": auto_channel_actions, "mode": "manual" if (active_ability_touch_held or Input.is_action_pressed("active_ability")) else ("automatic" if auto_channel_active else "idle"), "pose_name": str(visual.call("get_animation_state")) if visual != null else "missing", "effect_active": channel_effect_started}


func get_debug_state() -> Dictionary:
	return {"alive": is_alive, "generation": reclaim_generation, "cleave": get_cleave_debug_state(), "channel": get_channel_debug_state(), "animation": visual.call("get_debug_state") if visual != null and visual.has_method("get_debug_state") else {}}


func _exit_tree() -> void:
	_stop_channel(true)


func _request_cleave_impact(strength: float, hitstop: float) -> void:
	if impact_feedback_cooldown > 0.0:
		return
	impact_feedback_cooldown = 0.22
	if GameManager.has_method("request_combat_impact"):
		GameManager.request_combat_impact(strength, hitstop)


func _reclaim_draw_cut_drops(cut_origin: Vector2, generation: int) -> void:
	# Death poses finish before their rewards spawn. Reclaim again after those
	# poses, rather than making a convincing effect that vacuums an empty area.
	await get_tree().create_timer(0.7, false, false, false).timeout
	if not is_inside_tree() or not is_alive or generation != reclaim_generation or not GameManager.game_running:
		return
	EntityFactory.magnetize_xp_near(cut_origin, RIFT_PULSE_RANGE + 60.0)


func _draw() -> void:
	if not is_leader or hero_id != "rift_captain" or not is_alive or momentum_charge < 0.06:
		return
	var feet := Vector2(0.0, 11.0)
	var tint := Color(1.0, 0.72, 0.26, 0.72)
	draw_arc(feet, 23.0, PI * 0.15, PI * 0.15 + PI * 1.7 * momentum_charge, 24, Color(0.02, 0.025, 0.025, 0.88), 5.0, true)
	draw_arc(feet, 23.0, PI * 0.15, PI * 0.15 + PI * 1.7 * momentum_charge, 24, tint, 2.4, true)
	if momentum_charge >= 0.99 and active_ability_cooldown_timer <= 0.0:
		draw_circle(feet + Vector2(0.0, 23.0), 2.6, Color(1.0, 0.96, 0.68))


func _active_ability_direction() -> Vector2:
	var target := get_nearest_enemy(RIFT_PULSE_RANGE + 120.0)
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target.length_squared() > 1.0:
			return to_target.normalized()
	return get_facing_direction()


func _cast_rift_pulse_damage(forward: Vector2) -> int:
	var count := _damage_cleave(forward, RIFT_PULSE_RANGE, RIFT_PULSE_HALF_ANGLE, RIFT_PULSE_DAMAGE * (1.0 + pending_ability_charge * 0.5), RIFT_PULSE_KNOCKBACK, RIFT_PULSE_MAX_TARGETS, true)
	if count > 0 and GameManager.has_method("request_captain_ability_hit_flash"):
		GameManager.request_captain_ability_hit_flash()
	return count


func _damage_cleave(forward: Vector2, cleave_range: float, half_angle: float, base_damage: float, knockback: float, target_cap: int, heavy: bool = false) -> int:
	var damaged_count := 0
	var killed_count := 0
	var pulse_damage := base_damage * GameManager.get_outgoing_damage_multiplier(self)
	var forward_normalized := forward.normalized()
	var cosine := cos(half_angle)
	var cosine_squared := cosine * cosine
	for enemy in EntityFactory.get_enemies_in_radius(global_position, cleave_range + 42.0):
		if damaged_count >= target_cap:
			break
		if enemy == null or not is_instance_valid(enemy):
			continue
		var active_value: Variant = enemy.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		cleave_candidate_checks += 1
		var to_enemy: Vector2 = enemy.global_position - global_position
		var distance_squared := to_enemy.length_squared()
		var enemy_radius: float = float(enemy.get("radius"))
		var range_limit := cleave_range + enemy_radius
		if distance_squared > range_limit * range_limit:
			continue
		# Bodies already touching the captain belong to the blade's inner cut.
		if distance_squared > 1600.0 and half_angle < PI - 0.001:
			var projection := forward_normalized.dot(to_enemy)
			if half_angle <= PI * 0.5:
				if projection < 0.0 or projection * projection < distance_squared * cosine_squared - 0.001:
					continue
			else:
				cleave_cone_sqrt_calls += 1
				if projection < sqrt(distance_squared) * cosine:
					continue
		if enemy.has_method("take_damage"):
			var actual_damage := float(enemy.take_damage(pulse_damage, global_position))
			if actual_damage <= 0.0:
				continue
			GameManager.record_weapon_damage(self, "captain_blade", actual_damage, "draw_cut" if heavy else "auto_cut")
			damaged_count += 1
			if enemy.get("is_dying") == true:
				killed_count += 1
		if enemy.has_method("apply_knockback"):
			enemy.apply_knockback(global_position, knockback)
		if enemy.has_method("apply_status_effect"):
			enemy.apply_status_effect("slow", RIFT_PULSE_SLOW_DURATION, RIFT_PULSE_SLOW_STRENGTH)
	last_cleave_hit_count = damaged_count
	last_cleave_kill_count = killed_count
	cleave_kills_total += killed_count
	peak_cleave_hit_count = maxi(peak_cleave_hit_count, damaged_count)
	return damaged_count


func _spawn_rift_pulse_visuals(forward: Vector2) -> void:
	_play_combat_presentation("slash_a", forward, 4.35, RIFT_PULSE_RANGE, RIFT_PULSE_HALF_ANGLE, true)


func get_cleave_debug_state() -> Dictionary:
	return {"attack_direction": [attack_direction_lock.x, attack_direction_lock.y], "auto_cuts": auto_cleave_count, "auto_hits": auto_cleave_hit_count, "active_hits": active_ability_hit_count, "empty_active_impacts": active_ability_empty_impacts, "kills": cleave_kills_total, "last_hits": last_cleave_hit_count, "last_kills": last_cleave_kill_count, "max_hits": peak_cleave_hit_count, "momentum": momentum_charge, "queued": active_ability_queued, "auto_pending": auto_cleave_pending, "active_pending": active_ability_pending, "auto_cooldown": auto_cleave_cooldown_timer, "step_active": draw_cut_step_active, "step_distance": draw_cut_step_distance, "step_total_distance": draw_cut_step_total_distance, "assisted_casts": draw_cut_assisted_casts, "step_aborts": draw_cut_step_aborts, "step_reason": draw_cut_step_last_reason, "auto_target_queries": auto_cleave_target_queries, "candidate_checks": cleave_candidate_checks, "cone_sqrt_calls": cleave_cone_sqrt_calls, "presentation_lookups": presentation_lookups, "presentation_ready_checks": presentation_ready_checks}


func _update_facing(_delta: float) -> void:
	if visual != null and visual.has_method("set_facing_direction"):
		visual.set_facing_direction(get_visual_facing_direction())


func _is_cached_facing_enemy_valid() -> bool:
	if cached_facing_enemy == null or not is_instance_valid(cached_facing_enemy):
		return false
	var active_value: Variant = cached_facing_enemy.get("is_active")
	if active_value != null and not bool(active_value):
		return false
	if cached_facing_enemy.has_method("get_hit_token") and int(cached_facing_enemy.get_hit_token()) != cached_facing_token:
		return false
	return true


func _hit_key_for(body: Node) -> int:
	if body == null or not is_instance_valid(body):
		return 0
	if body.has_method("get_hit_token"):
		return int(body.get_hit_token())
	return int(body.get_instance_id())


func _update_flash() -> void:
	if visual == null:
		return

	if invulnerability_timer > 0.0:
		var flash_on := int(invulnerability_timer * 22.0) % 2 == 0
		visual.modulate = Color(1.0, 0.35, 0.32, 0.55) if flash_on else Color.WHITE
	else:
		visual.modulate = Color.WHITE


func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO, force_heavy_reaction: bool = false) -> bool:
	if invulnerability_timer > 0.0 or current_hp <= 0.0 or not is_alive:
		return false
	_end_draw_cut_step("hurt")

	var final_incoming := amount * (GameManager.get_incoming_damage_multiplier(self) if GameManager.has_method("get_incoming_damage_multiplier") else 1.0)
	var remaining_damage := final_incoming
	if temporary_shield_hp > 0.0:
		var absorbed: float = min(temporary_shield_hp, remaining_damage)
		temporary_shield_hp -= absorbed
		remaining_damage -= absorbed
	current_hp = max(current_hp - remaining_damage, 0.0)
	invulnerability_timer = invulnerability_time

	var number_position := global_position + Vector2(0.0, -30.0)
	if source_position != Vector2.ZERO:
		number_position += (global_position - source_position).normalized() * 8.0
	EntityFactory.spawn_damage_number(final_incoming, number_position, Color(1.0, 0.28, 0.22))
	if visual != null and visual.has_method("play_hurt"):
		var heavy_reaction := remaining_damage >= max_hp * 0.12 or (force_heavy_reaction and remaining_damage > 0.0)
		visual.call("play_hurt", source_position, heavy_reaction)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("hurt", false, -10.0, 0.92 if is_leader else 1.08)

	GameManager.emit_stats()
	if current_hp <= 0.0:
		_die()
	return true


func request_screen_shake(strength: float, duration: float) -> void:
	if not is_leader or camera == null:
		return
	if PlayerSettings != null and not bool(PlayerSettings.get("screen_shake_enabled")):
		return
	screen_shake_strength = max(screen_shake_strength, strength)
	screen_shake_duration = max(screen_shake_duration, duration)
	screen_shake_timer = max(screen_shake_timer, duration)


func _update_camera_zoom(delta: float) -> void:
	if camera == null or not is_leader:
		return
	var target_zoom := _leader_camera_zoom()
	if GameManager.has_method("is_camera_threat_zoom_requested") and GameManager.is_camera_threat_zoom_requested():
		target_zoom = _leader_threat_camera_zoom()
	var weight: float = 1.0 - exp(-delta * LEADER_CAMERA_ZOOM_LERP_SPEED)
	camera.zoom = camera.zoom.lerp(target_zoom, clamp(weight, 0.0, 1.0))


func _leader_camera_zoom() -> Vector2:
	return _fit_stage_camera(MOBILE_TUNING.leader_camera_zoom(_camera_viewport_size()))


func _leader_threat_camera_zoom() -> Vector2:
	return _fit_stage_camera(MOBILE_TUNING.leader_threat_camera_zoom(_camera_viewport_size()))


func _stage_background() -> Node:
	if is_instance_valid(GameManager.arena):
		return GameManager.arena.get_node_or_null("Background")
	return null


func _constrain_to_stage() -> void:
	if is_instance_valid(GameManager.arena) and GameManager.arena.get_node_or_null("LoopWorldTopology") != null:
		return
	var background := _stage_background()
	if background == null or not background.has_method("get_playable_rect"):
		return
	var bounds: Rect2 = background.get_playable_rect().grow(-12.0)
	global_position = global_position.clamp(bounds.position, bounds.end)


func _fit_stage_camera(base_zoom: Vector2) -> Vector2:
	if is_instance_valid(GameManager.arena) and GameManager.arena.get_node_or_null("LoopWorldTopology") != null:
		if camera != null:
			camera.limit_left = -10000000
			camera.limit_right = 10000000
			camera.limit_top = -10000000
			camera.limit_bottom = 10000000
			camera.limit_smoothed = false
		var view := MOBILE_TUNING.ui_layout_size(_camera_viewport_size())
		var zoom := 1.0
		var tier := MOBILE_TUNING.layout_tier(view)
		if tier == MOBILE_TUNING.LayoutTier.TABLET:
			zoom = 1.12
		elif tier == MOBILE_TUNING.LayoutTier.PHONE:
			zoom = 2.2 if view.y > view.x else 1.22
		return Vector2.ONE * zoom
	var background := _stage_background()
	if background == null or not background.has_method("get_map_world_rect"):
		return base_zoom
	var bounds: Rect2 = background.get_map_world_rect()
	if camera != null:
		camera.limit_left = ceili(bounds.position.x)
		camera.limit_right = floori(bounds.end.x)
		camera.limit_top = ceili(bounds.position.y)
		camera.limit_bottom = floori(bounds.end.y)
		camera.limit_smoothed = false
	var view := _camera_viewport_size()
	var fit := maxf(view.x / bounds.size.x, view.y / bounds.size.y) * 1.03
	return Vector2.ONE * maxf(base_zoom.x, fit)


func _camera_viewport_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(1280.0, 720.0)
	return viewport_size


func _update_camera_shake(delta: float) -> void:
	if camera == null or not is_leader:
		return
	if screen_shake_timer <= 0.0:
		camera.offset = Vector2.ZERO
		return
	screen_shake_timer = max(screen_shake_timer - delta, 0.0)
	var ratio: float = screen_shake_timer / max(0.001, screen_shake_duration)
	var amount: float = screen_shake_strength * ratio * ratio
	camera.offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
	if screen_shake_timer <= 0.0:
		camera.offset = Vector2.ZERO


func heal(amount: float) -> bool:
	if not is_alive or amount <= 0.0:
		return false
	var before := current_hp
	current_hp = min(max_hp, current_hp + amount)
	GameManager.emit_stats()
	return current_hp > before


func add_temporary_shield(amount: float, duration: float) -> void:
	if not is_alive:
		return
	temporary_shield_hp = max(temporary_shield_hp, amount)
	temporary_shield_timer = max(temporary_shield_timer, duration)


func _die() -> void:
	_end_draw_cut_step("death")
	_stop_channel(true)
	is_alive = false
	reclaim_generation += 1
	active_ability_pending = false
	active_ability_queued = false
	auto_cleave_pending = false
	queue_redraw()
	if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("recompute_bonds"):
		squad_manager.recompute_bonds()
	remove_from_group("heroes")
	set_physics_process(false)
	velocity = Vector2.ZERO
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	if weapons_root != null:
		for child in weapons_root.get_children():
			child.set_process(false)
			child.set_physics_process(false)
			if child.has_method("release_owned_nodes"):
				child.release_owned_nodes()
	if visual != null and visual.has_method("play_death") and bool(visual.call("play_death")):
		return
	_finalize_death()


func _on_visual_death_finished() -> void:
	_finalize_death()


func _finalize_death() -> void:
	if death_finalized:
		return
	death_finalized = true
	if is_leader:
		set_process(false)
		if camera != null:
			# Preserve the bounded battlefield behind the defeat screen.
			camera.enabled = true
			camera.offset = Vector2.ZERO
		GameManager.player_died()
	else:
		EntityFactory.call_deferred("spawn_death_burst", global_position, Color(0.7, 0.82, 1.0))
		if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("member_died"):
			squad_manager.member_died(self)
		queue_free()


func build_upgrade_pool(base_pool: Array) -> Array:
	if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("build_upgrade_pool"):
		return squad_manager.build_upgrade_pool(base_pool)
	return base_pool


func apply_upgrade(upgrade: Dictionary) -> void:
	if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("apply_upgrade"):
		squad_manager.apply_upgrade(upgrade)
	else:
		apply_personal_upgrade(upgrade)


func apply_personal_upgrade(upgrade: Dictionary) -> void:
	var upgrade_id: String = upgrade.get("id", "")

	match upgrade_id:
		"move_speed":
			move_speed += 20.0
		"max_hp":
			max_hp += 20.0
			current_hp = min(current_hp + 20.0, max_hp)
		"pickup_radius":
			pickup_radius += 24.0

	GameManager.emit_stats()


func unlock_weapon(weapon_id: String) -> bool:
	if weapon_id == "" or weapons.has(weapon_id) or weapon_catalog == null:
		return false

	var source_data: Resource = weapon_catalog.get_weapon_data(weapon_id)
	if source_data == null:
		return false

	var weapon_scene: PackedScene = source_data.get("weapon_scene")
	if weapon_scene == null:
		return false

	var weapon_node: Node = weapon_scene.instantiate()
	weapons_root.add_child(weapon_node)
	if weapon_node.has_method("setup"):
		weapon_node.setup(self, source_data)

	weapons[weapon_id] = weapon_node
	weapon_order.append(weapon_id)
	return true


func upgrade_weapon(weapon_id: String, upgrade_kind: String) -> bool:
	var weapon: Node = weapons.get(weapon_id)
	if weapon == null or not is_instance_valid(weapon):
		return false

	if weapon.has_method("apply_data_upgrade"):
		return bool(weapon.apply_data_upgrade(upgrade_kind))
	return false


func get_weapon_trigger_counts() -> Dictionary:
	var counts: Dictionary = {}
	for weapon_id in weapon_order:
		var weapon: Node = weapons.get(weapon_id)
		if weapon != null and is_instance_valid(weapon):
			counts[weapon_id] = int(weapon.get("trigger_count"))
	return counts


func get_firepower_debug_state() -> Dictionary:
	var projectile_weapons: Dictionary = {}
	for weapon_id in weapon_order:
		var weapon: Node = weapons.get(weapon_id)
		if weapon != null and weapon.has_method("get_firepower_debug_state"):
			projectile_weapons[weapon_id] = weapon.call("get_firepower_debug_state")
	var ranged: Node = weapons.get("riftline_emitter")
	var orbit: Node = weapons.get("orbit_blades")
	var chain: Node = weapons.get("arc_chain")
	return {
		"projectile_weapons": projectile_weapons,
		"r37_polish": {"draw_cut_step_max": DRAW_CUT_STEP_MAX, "assisted_casts": draw_cut_assisted_casts, "step_total_distance": draw_cut_step_total_distance, "empty_active_impacts": active_ability_empty_impacts, "auto_target_queries": auto_cleave_target_queries, "cleave_candidate_checks": cleave_candidate_checks, "cleave_cone_sqrt_calls": cleave_cone_sqrt_calls, "presentation_lookups": presentation_lookups, "presentation_ready_checks": presentation_ready_checks, "damage_number_layout_updates": DAMAGE_NUMBER_METRICS.label_layout_updates, "damage_number_process_updates": DAMAGE_NUMBER_METRICS.process_updates, "damage_number_alpha_updates": DAMAGE_NUMBER_METRICS.alpha_updates, "damage_number_scale_updates": DAMAGE_NUMBER_METRICS.scale_updates},
		"engine_physics_frames": Engine.get_physics_frames(),
		"projectile_physics_ticks": Projectile.physics_tick_count,
		"projectile_readability_checks": Projectile.readability_check_count,
		"dart_redraw_requests": Projectile.dart_redraw_request_count,
		"projectiles_logical": EntityFactory.get_pool_live_count("projectile") + EntityFactory.get_pool_live_count("fork_projectile"),
		"enemies_live": int(EntityFactory.enemy_spatial_index.get("live_count")) if is_instance_valid(EntityFactory.enemy_spatial_index) else 0,
		"enemy_spatial_queries": int(EntityFactory.enemy_spatial_index.get("query_count")) if is_instance_valid(EntityFactory.enemy_spatial_index) else 0,
		"friendly_projectiles_visible": Projectile.active_friendly_visuals,
		"friendly_visual_rejections": Projectile.friendly_visual_rejections,
		"projectile_visual_caps": {"desktop": Projectile.FRIENDLY_VISUAL_DESKTOP_CAP, "phone": Projectile.FRIENDLY_VISUAL_PHONE_CAP, "tablet": Projectile.FRIENDLY_VISUAL_TABLET_CAP},
		"riftline": ranged.get_firepower_debug_state() if ranged != null and ranged.has_method("get_firepower_debug_state") else {},
		"auto_cleave_interval": AUTO_CLEAVE_COOLDOWN,
		"orbit_blades": int(orbit.call("data_int", "projectile_count", 0)) if orbit != null else 0,
		"orbit_angular_speed": float(orbit.call("data_float", "orbit_angular_speed", 0.0)) if orbit != null else 0.0,
		"chain_targets": int(chain.call("data_int", "chain_count", 0)) if chain != null else 0,
		"chain_cooldown": float(chain.call("scaled_cooldown", chain.call("data_float", "cooldown", 0.0))) if chain != null else 0.0,
	}


func get_nearest_enemy(max_range: float = 1000000.0) -> Node2D:
	return EntityFactory.find_nearest_enemy(global_position, max_range)


func get_current_hp() -> float:
	return current_hp


func get_max_hp() -> float:
	return max_hp


func get_pickup_radius() -> float:
	return pickup_radius


func get_hit_radius() -> float:
	return hit_radius
