class_name Enemy
extends CharacterBody2D

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const THREAT_GLOW_DENSITY_START := 80
const THREAT_GLOW_DENSITY_FULL := 150

static var animation_frames_cache: Dictionary = {}

@export var type_id: String = "normal"
@export var max_hp: float = 18.0
@export var speed: float = 88.0
@export var damage: float = 8.0
@export var xp_value: int = 2
@export var gold_value: int = 1
@export var radius: float = 13.0
@export var body_color: Color = Color(0.92, 0.28, 0.32)
@export var attack_cooldown: float = 0.75

var hp: float = 18.0
var attack_timer: float = 0.0
var is_active: bool = false
var spawn_token: int = 0
var sprite_path: String = ""
var sprite_scale: float = 1.0
var hp_bar_timer: float = 0.0
var behavior_id: String = "chaser"
var status_timers: Dictionary = {}
var status_strengths: Dictionary = {}
var expired_status_ids: Array = []
var behavior_state: String = "chase"
var behavior_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var dash_trigger_range: float = 155.0
var dash_windup: float = 0.42
var dash_duration: float = 0.24
var dash_recover: float = 0.55
var dash_speed: float = 430.0
var ranged_preferred_distance: float = 245.0
var ranged_windup: float = 0.3
var ranged_projectile_damage: float = 5.0
var ranged_projectile_speed: float = 260.0
var ranged_projectile_range: float = 820.0
var ranged_projectile_radius: float = 6.0
var spawns_on_death: bool = false
var death_spawn_id: String = "normal"
var death_spawn_count: int = 0
var death_spawn_cap: int = 150
var is_elite: bool = false
var is_boss: bool = false
var elite_bonus_xp: int = 0
var affix_id: String = ""
var affix_field_radius: float = 0.0
var affix_field_slow_strength: float = 0.0
var affix_field_tick_timer: float = 0.0
var boss_phase_two_triggered: bool = false
var boss_ability_timer: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var sprite: Sprite2D = null
var animated_sprite: AnimatedSprite2D = null
var affix_ring: Line2D = null
var affix_marker: Line2D = null
var hp_bar_bg: Line2D = null
var hp_bar_fg: Line2D = null
var shadow: Sprite2D = null
var threat_glow: Sprite2D = null
var boss_inner_glow: Sprite2D = null
var boss_core_glow: Sprite2D = null
var hit_flash_timer: float = 0.0
var threat_glow_base_alpha: float = 0.18
var visual_walk_phase: float = 0.0
var visual_idle_phase: float = 0.0
var hit_squash_timer: float = 0.0
var last_visual_direction: Vector2 = Vector2.RIGHT
var sprite_base_scale: Vector2 = Vector2.ONE
var animated_sprite_base_scale: Vector2 = Vector2.ONE
var shadow_base_scale: Vector2 = Vector2.ONE
var threat_glow_base_scale: Vector2 = Vector2.ONE
var visual_bob_frequency: float = 7.2
var visual_bob_amplitude: float = 2.4
var visual_tilt_amount: float = 0.085
var visual_step_interval: float = 0.3
var animation_frames_ready: bool = false
var current_animation_name: String = ""


func _ready() -> void:
	_ensure_visual_nodes()
	_apply_shape()


func pool_on_acquire() -> void:
	is_active = true
	visible = true
	set_process(true)
	set_physics_process(true)
	if not is_in_group("enemies"):
		add_to_group("enemies")
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		shape_node.disabled = false


func pool_on_release() -> void:
	is_active = false
	visible = false
	set_process(false)
	set_physics_process(false)
	remove_from_group("enemies")
	velocity = Vector2.ZERO
	hp = 0.0
	attack_timer = 0.0
	hp_bar_timer = 0.0
	behavior_state = "chase"
	behavior_timer = 0.0
	dash_direction = Vector2.ZERO
	status_timers.clear()
	status_strengths.clear()
	expired_status_ids.clear()
	affix_id = ""
	affix_field_radius = 0.0
	affix_field_slow_strength = 0.0
	affix_field_tick_timer = 0.0
	boss_phase_two_triggered = false
	boss_ability_timer = 0.0
	rotation = 0.0
	if sprite != null:
		sprite.rotation = 0.0
		sprite.position = Vector2.ZERO
	if animated_sprite != null:
		animated_sprite.rotation = 0.0
		animated_sprite.position = Vector2.ZERO
		animated_sprite.visible = false
	if shadow != null:
		shadow.visible = false
	if threat_glow != null:
		threat_glow.visible = false
	if boss_inner_glow != null:
		boss_inner_glow.visible = false
	if boss_core_glow != null:
		boss_core_glow.visible = false
	hit_flash_timer = 0.0
	hit_squash_timer = 0.0
	visual_walk_phase = 0.0
	visual_idle_phase = 0.0
	last_visual_direction = Vector2.RIGHT
	threat_glow_base_alpha = 0.18
	if affix_ring != null:
		affix_ring.visible = false
	if affix_marker != null:
		affix_marker.visible = false
	_set_hp_bar_visible(false)
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		shape_node.disabled = true


func pool_reset(args: Dictionary) -> void:
	global_position = args.get("position", Vector2.ZERO)
	spawn_token = int(args.get("spawn_token", spawn_token + 1))
	setup(str(args.get("enemy_id", "normal")), args.get("config", {}))


func setup(enemy_type: String, config: Dictionary) -> void:
	type_id = enemy_type
	max_hp = float(config.get("max_hp", max_hp))
	hp = max_hp
	speed = float(config.get("speed", speed))
	damage = float(config.get("damage", damage))
	xp_value = int(config.get("xp", xp_value))
	gold_value = int(config.get("gold", gold_value))
	radius = float(config.get("radius", radius))
	body_color = config.get("color", body_color)
	sprite_path = str(config.get("sprite_path", _default_sprite_path_for_type(type_id)))
	sprite_scale = float(config.get("sprite_scale", 1.0))
	attack_cooldown = float(config.get("attack_cooldown", attack_cooldown))
	behavior_id = str(config.get("behavior_id", "chaser"))
	dash_trigger_range = float(config.get("dash_trigger_range", dash_trigger_range))
	dash_windup = float(config.get("dash_windup", dash_windup))
	dash_duration = float(config.get("dash_duration", dash_duration))
	dash_recover = float(config.get("dash_recover", dash_recover))
	dash_speed = float(config.get("dash_speed", dash_speed))
	ranged_preferred_distance = float(config.get("preferred_distance", ranged_preferred_distance))
	ranged_windup = float(config.get("windup", ranged_windup))
	ranged_projectile_damage = float(config.get("projectile_damage", damage * 0.75))
	ranged_projectile_speed = float(config.get("projectile_speed", ranged_projectile_speed))
	ranged_projectile_range = float(config.get("projectile_range", ranged_projectile_range))
	ranged_projectile_radius = float(config.get("projectile_radius", ranged_projectile_radius))
	spawns_on_death = bool(config.get("spawns_on_death", false))
	death_spawn_id = str(config.get("death_spawn_id", "normal"))
	death_spawn_count = int(config.get("death_spawn_count", 0))
	death_spawn_cap = int(config.get("death_spawn_cap", 150))
	is_elite = bool(config.get("is_elite", false))
	is_boss = bool(config.get("is_boss", false))
	elite_bonus_xp = int(config.get("elite_bonus_xp", 0))
	affix_id = str(config.get("affix_id", ""))
	affix_field_radius = float(config.get("affix_field_radius", 0.0))
	affix_field_slow_strength = float(config.get("affix_field_slow_strength", 0.0))
	affix_field_tick_timer = 0.0
	velocity = Vector2.ZERO
	attack_timer = 0.0
	hp_bar_timer = 0.0
	behavior_state = "chase"
	behavior_timer = 0.0
	dash_direction = Vector2.ZERO
	status_timers.clear()
	status_strengths.clear()
	expired_status_ids.clear()
	boss_phase_two_triggered = false
	boss_ability_timer = float(config.get("boss_ability_cooldown", 4.8))
	rotation = 0.0
	hit_flash_timer = 0.0
	_apply_shape()
	_apply_visual_motion_profile()
	_apply_sprite()
	_apply_affix_visuals()
	_update_hp_bar()
	_set_hp_bar_visible(false)
	_request_camera_pressure_on_spawn()


func _process(delta: float) -> void:
	if not is_active:
		return
	_update_procedural_visual(delta)


func get_hit_token() -> int:
	return spawn_token


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	_tick_status_effects(delta)
	var target := _find_nearest_hero()
	if target == null or not is_instance_valid(target):
		_tick_hit_flash(delta)
		return

	attack_timer = max(attack_timer - delta, 0.0)

	match behavior_id:
		"ranged":
			_physics_ranged(delta, target)
		"dasher":
			_physics_dasher(delta, target)
		"boss":
			_physics_boss(delta, target)
		_:
			_physics_chaser(target)

	_tick_affix(delta)
	_tick_hp_bar(delta)
	_tick_hit_flash(delta)


func _physics_chaser(target: Node2D) -> void:
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length_squared() > 1.0:
		velocity = to_target.normalized() * _effective_speed()
	else:
		velocity = Vector2.ZERO
	_move_and_face()
	_try_contact_attack(target)


func _physics_ranged(delta: float, target: Node2D) -> void:
	if behavior_state == "windup":
		behavior_timer = max(behavior_timer - delta, 0.0)
		velocity = Vector2.ZERO
		_move_and_face()
		_set_sprite_modulate(Color(1.0, 0.88, 0.36))
		if behavior_timer <= 0.0:
			_fire_ranged_projectile(target)
			behavior_state = "chase"
			attack_timer = attack_cooldown
			_set_sprite_modulate(body_color)
		return

	var to_target: Vector2 = target.global_position - global_position
	var distance_squared := to_target.length_squared()
	var preferred := ranged_preferred_distance
	if distance_squared > preferred * preferred * 1.18:
		velocity = to_target.normalized() * _effective_speed()
	elif distance_squared < preferred * preferred * 0.52:
		velocity = -to_target.normalized() * _effective_speed() * 0.75
	else:
		velocity = Vector2.ZERO
		if attack_timer <= 0.0:
			behavior_state = "windup"
			behavior_timer = ranged_windup
	_move_and_face()
	_try_contact_attack(target)


func _physics_dasher(delta: float, target: Node2D) -> void:
	match behavior_state:
		"windup":
			behavior_timer = max(behavior_timer - delta, 0.0)
			velocity = Vector2.ZERO
			_move_and_face()
			_set_sprite_modulate(Color(1.0, 0.55, 0.42))
			if behavior_timer <= 0.0:
				behavior_state = "dash"
				behavior_timer = dash_duration
				_set_sprite_modulate(body_color)
		"dash":
			behavior_timer = max(behavior_timer - delta, 0.0)
			velocity = dash_direction * dash_speed
			_move_and_face()
			_try_contact_attack(target, 1.35)
			if behavior_timer <= 0.0:
				behavior_state = "recover"
				behavior_timer = dash_recover
				velocity = Vector2.ZERO
		"recover":
			behavior_timer = max(behavior_timer - delta, 0.0)
			velocity = Vector2.ZERO
			_move_and_face()
			if behavior_timer <= 0.0:
				behavior_state = "chase"
		_:
			var to_target: Vector2 = target.global_position - global_position
			if to_target.length_squared() <= dash_trigger_range * dash_trigger_range and attack_timer <= 0.0:
				dash_direction = to_target.normalized()
				if dash_direction == Vector2.ZERO:
					dash_direction = Vector2.RIGHT
				behavior_state = "windup"
				behavior_timer = dash_windup
				attack_timer = attack_cooldown
				velocity = Vector2.ZERO
			else:
				velocity = to_target.normalized() * _effective_speed() if to_target.length_squared() > 1.0 else Vector2.ZERO
			_move_and_face()
			_try_contact_attack(target)


func _physics_boss(delta: float, target: Node2D) -> void:
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length_squared() > 180.0 * 180.0:
		velocity = to_target.normalized() * _effective_speed()
	else:
		velocity = Vector2.ZERO
	_move_and_face()
	_try_contact_attack(target, 1.15)

	boss_ability_timer -= delta
	if boss_ability_timer <= 0.0:
		_fire_ring_projectiles(10)
		boss_ability_timer = 5.4

	if not boss_phase_two_triggered and hp <= max_hp * 0.5:
		_trigger_boss_phase_two()


func _move_and_face() -> void:
	move_and_slide()
	if velocity.length_squared() > 1.0:
		last_visual_direction = velocity.normalized()


func _try_contact_attack(target: Node2D, damage_multiplier: float = 1.0) -> void:
	var target_hit_radius: float = _get_target_hit_radius(target)
	var attack_distance: float = radius + target_hit_radius + 4.0
	if global_position.distance_squared_to(target.global_position) > attack_distance * attack_distance:
		return
	if attack_timer > 0.0:
		return
	attack_timer = attack_cooldown
	if target.has_method("take_damage"):
		target.take_damage(damage * damage_multiplier, global_position)


func _fire_ranged_projectile(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var direction := (target.global_position - global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	EntityFactory.spawn_enemy_projectile(global_position + direction * (radius + 8.0), direction, _enemy_projectile_stats(), self, "normal")


func _fire_ring_projectiles(count: int) -> void:
	var projectile_count: int = max(1, count)
	var projectile_stats := _enemy_projectile_stats(0.82)
	var priority := "boss" if is_boss else "normal"
	if is_boss and GameManager.has_method("request_camera_threat_zoom"):
		GameManager.request_camera_threat_zoom(1.55)
	for index in range(projectile_count):
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / float(projectile_count))
		EntityFactory.spawn_enemy_projectile(global_position + direction * (radius + 8.0), direction, projectile_stats, self, priority)


func _enemy_projectile_stats(damage_multiplier: float = 1.0) -> Dictionary:
	return {
		"damage": ranged_projectile_damage * damage_multiplier,
		"range": ranged_projectile_range,
		"projectile_speed": ranged_projectile_speed,
		"projectile_radius": ranged_projectile_radius,
		"pierce": 0,
		"color": Color(0.94, 0.42, 1.0) if is_boss else Color(1.0, 0.35, 0.24),
		"projectile_sprite_path": "res://assets/vfx/kenney_particle/flare_cyan.png" if is_boss else "res://assets/sprites/proj_bullet.png",
		"sprite_scale": 1.12 if is_boss else 1.0,
		"source_weapon_id": "boss_ring" if is_boss else "enemy_shot",
		"visual_level": 5 if is_boss else 0,
		"evolved_visual": boss_phase_two_triggered if is_boss else false,
		"target_group": "heroes"
	}


func _trigger_boss_phase_two() -> void:
	boss_phase_two_triggered = true
	EntityFactory.spawn_death_burst(global_position, Color(0.82, 0.42, 1.0), 3.1, "boss_phase")
	_fire_ring_projectiles(14)
	_spawn_boss_dashers(4)
	if GameManager.has_method("record_boss_phase_two"):
		GameManager.record_boss_phase_two()


func _spawn_boss_dashers(count: int) -> void:
	for index in range(count):
		if EntityFactory.get_enemy_live_count() >= death_spawn_cap:
			return
		var angle := TAU * float(index) / float(max(1, count))
		EntityFactory.spawn_enemy("boss_dasher", _boss_dasher_config(), global_position + Vector2.RIGHT.rotated(angle) * 72.0)


func _boss_dasher_config() -> Dictionary:
	return {
		"max_hp": 28.0,
		"speed": 116.0,
		"damage": 7.0,
		"xp": 1,
		"gold": 1,
		"radius": 10.0,
		"color": Color(1.0, 0.54, 0.34),
		"sprite_path": "res://assets/sprites/enemy_fast.png",
		"sprite_scale": 1.34,
		"attack_cooldown": 0.9,
		"behavior_id": "dasher",
		"dash_trigger_range": 170.0,
		"dash_windup": 0.34,
		"dash_duration": 0.24,
		"dash_recover": 0.55,
		"dash_speed": 430.0,
		"spawns_on_death": false
	}


func _tick_hp_bar(delta: float) -> void:
	if hp_bar_timer > 0.0:
		hp_bar_timer = max(hp_bar_timer - delta, 0.0)
		if hp_bar_timer <= 0.0:
			_set_hp_bar_visible(false)


func _find_nearest_hero() -> Node2D:
	var nearest: Node2D = null
	var best_distance_squared := INF

	var heroes: Array = []
	if GameManager.squad_manager != null and is_instance_valid(GameManager.squad_manager) and GameManager.squad_manager.has_method("get_members"):
		heroes = GameManager.squad_manager.get_members()
	else:
		heroes = get_tree().get_nodes_in_group("heroes")

	for hero in heroes:
		if hero == null or not is_instance_valid(hero):
			continue
		var hero_alive: Variant = hero.get("is_alive")
		if hero_alive != null and bool(hero_alive) == false:
			continue
		var distance_squared: float = global_position.distance_squared_to(hero.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			nearest = hero

	return nearest


func apply_status_effect(effect_id: String, duration: float, strength: float) -> void:
	if not is_active or effect_id == "":
		return
	status_timers[effect_id] = max(float(status_timers.get(effect_id, 0.0)), duration)
	status_strengths[effect_id] = strength


func apply_knockback(source_position: Vector2, strength: float) -> void:
	if not is_active or strength <= 0.0:
		return
	var direction := global_position - source_position
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	global_position += direction.normalized() * strength


func _tick_status_effects(delta: float) -> void:
	if status_timers.is_empty():
		return
	expired_status_ids.clear()
	for effect_id in status_timers:
		status_timers[effect_id] = float(status_timers[effect_id]) - delta
		if float(status_timers[effect_id]) <= 0.0:
			expired_status_ids.append(effect_id)
	for effect_id in expired_status_ids:
		status_timers.erase(effect_id)
		status_strengths.erase(effect_id)


func _damage_taken_multiplier() -> float:
	var multiplier := 1.0
	if status_timers.has("vulnerable"):
		multiplier += float(status_strengths.get("vulnerable", 0.0))
	return multiplier


func _effective_speed() -> float:
	var multiplier := 1.0
	if status_timers.has("slow"):
		multiplier -= float(status_strengths.get("slow", 0.0))
	return speed * clamp(multiplier, 0.35, 1.6)


func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO) -> float:
	if hp <= 0.0 or not is_active:
		return 0.0

	var final_amount := amount * _damage_taken_multiplier()
	hp = max(hp - final_amount, 0.0)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("hit")
	var number_position := global_position + Vector2(randf_range(-8.0, 8.0), -radius - 10.0)
	EntityFactory.spawn_damage_number(final_amount, number_position, Color(1.0, 0.96, 0.72))
	hp_bar_timer = 0.55
	hit_flash_timer = 0.075
	hit_squash_timer = 0.11
	_update_hp_bar()
	_set_hp_bar_visible(true)

	if hp <= 0.0:
		_die(source_position)
	return final_amount


func _die(_source_position: Vector2 = Vector2.ZERO) -> void:
	if not is_active:
		return
	is_active = false
	status_timers.clear()
	status_strengths.clear()
	GameManager.add_kill()
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		var thump_pitch := 0.68 if is_boss else (0.78 if is_elite else 0.92)
		if GameManager.has_method("get_kill_thump_pitch"):
			thump_pitch = GameManager.get_kill_thump_pitch(thump_pitch)
		AudioManager.play_sfx("kill_thump", false, -7.0, thump_pitch)
	if is_elite and GameManager.has_method("record_elite_kill"):
		GameManager.record_elite_kill()
	if is_boss and GameManager.has_method("record_boss_kill"):
		GameManager.record_boss_kill()
	var burst_scale := 2.25 if is_boss else (1.55 if is_elite else 1.0)
	var corpse_flip := false
	var corpse_rotation := 0.0
	if animated_sprite != null and animated_sprite.visible:
		corpse_flip = animated_sprite.flip_h
		corpse_rotation = animated_sprite.rotation
	elif sprite != null:
		corpse_flip = sprite.flip_h
		corpse_rotation = sprite.rotation
	EntityFactory.queue_death_visual(
		global_position,
		sprite_path,
		body_color,
		radius,
		sprite_scale,
		corpse_flip,
		corpse_rotation,
		burst_scale,
		is_elite and not is_boss,
		"boss_death" if is_boss else ("elite_death" if is_elite else "burst")
	)

	var magnetic_reclaim := GameManager.has_method("has_magnetic_reclaim") and GameManager.has_magnetic_reclaim()
	var gold_drop := GameManager.get_gold_drop_amount(gold_value) if gold_value > 0 and GameManager.has_method("get_gold_drop_amount") else gold_value
	if not is_elite and not is_boss and not magnetic_reclaim:
		var coin_position := global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		EntityFactory.queue_regular_drop(global_position, xp_value, coin_position, gold_drop)
	elif xp_value > 0:
		if is_elite or is_boss:
			EntityFactory.call_deferred("spawn_xp_gem_burst", global_position, xp_value, 16 if is_boss else 7, 1.75 if is_boss else 1.35)
		else:
			EntityFactory.call_deferred("spawn_xp_gem", global_position, xp_value, 1.0)
	if elite_bonus_xp > 0:
		EntityFactory.call_deferred("spawn_visible_xp_gem_burst", global_position, elite_bonus_xp, 12 if is_boss else 6, 1.85 if is_boss else 1.45)
	if gold_value > 0 and (is_elite or is_boss):
		EntityFactory.call_deferred("spawn_gold_coin_burst", global_position, gold_drop, 10 if is_boss else 5, 1.7 if is_boss else 1.3)
	if spawns_on_death:
		_spawn_death_children()
	if magnetic_reclaim:
		EntityFactory.call_deferred("magnetize_xp_near", global_position, 155.0)
	if is_elite or is_boss:
		var shake := 9.0 if is_boss else 5.6
		if GameManager.has_method("request_combat_impact"):
			GameManager.request_combat_impact(shake, 0.15 if is_elite and not is_boss else 0.04)

	EntityFactory.release_enemy_deferred(self)


func _spawn_death_children() -> void:
	var count: int = max(0, death_spawn_count)
	for index in range(count):
		if EntityFactory.has_method("get_enemy_active_count") and EntityFactory.get_enemy_active_count() >= death_spawn_cap:
			return
		if not EntityFactory.has_method("get_enemy_active_count") and EntityFactory.get_enemy_live_count() >= death_spawn_cap:
			return
		var angle := TAU * float(index) / float(max(1, count))
		var child_position := global_position + Vector2.RIGHT.rotated(angle) * (radius + 12.0)
		EntityFactory.spawn_enemy(death_spawn_id, _death_child_config(), child_position)


func _death_child_config() -> Dictionary:
	var child_color := Color(0.95, 0.42, 0.35)
	if affix_id == "affix_split":
		child_color = Color(0.58, 1.0, 0.62)
	return {
		"max_hp": 12.0,
		"speed": 124.0,
		"damage": 4.0,
		"xp": 1,
		"gold": 0,
		"radius": 8.5,
		"color": child_color,
		"sprite_path": "res://assets/sprites/enemy_fast.png",
		"sprite_scale": 1.08,
		"attack_cooldown": 0.8,
		"behavior_id": "chaser",
		"spawns_on_death": false
	}


func _tick_affix(delta: float) -> void:
	if affix_id != "affix_field" or affix_field_radius <= 0.0 or affix_field_slow_strength <= 0.0:
		return
	affix_field_tick_timer = max(affix_field_tick_timer - delta, 0.0)
	if affix_field_tick_timer > 0.0:
		return
	affix_field_tick_timer = 0.12

	var members: Array = []
	if GameManager.squad_manager != null and is_instance_valid(GameManager.squad_manager) and GameManager.squad_manager.has_method("get_members"):
		members = GameManager.squad_manager.get_members()
	elif GameManager.player != null and is_instance_valid(GameManager.player):
		members = [GameManager.player]

	var radius_squared := affix_field_radius * affix_field_radius
	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		var member_alive: Variant = member.get("is_alive")
		if member_alive != null and bool(member_alive) == false:
			continue
		if global_position.distance_squared_to(member.global_position) > radius_squared:
			continue
		if member.has_method("apply_movement_slow"):
			member.apply_movement_slow(0.2, affix_field_slow_strength)


func _apply_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return

	var circle := shape_node.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		shape_node.shape = circle
	circle.radius = radius


func _get_target_hit_radius(target: Node) -> float:
	if target != null and target.has_method("get_hit_radius"):
		return float(target.get_hit_radius())
	var value: Variant = target.get("hit_radius") if target != null else null
	if value == null:
		return 12.0
	return float(value)


func _ensure_visual_nodes() -> void:
	shadow = get_node_or_null("Shadow") as Sprite2D
	if shadow == null:
		shadow = Sprite2D.new()
		shadow.name = "Shadow"
		add_child(shadow)
	shadow.texture = ART_RESOURCES.get_ellipse_shadow()
	shadow.centered = true
	shadow.z_index = -4
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.68)

	threat_glow = get_node_or_null("ThreatGlow") as Sprite2D
	if threat_glow == null:
		threat_glow = Sprite2D.new()
		threat_glow.name = "ThreatGlow"
		add_child(threat_glow)
	threat_glow.texture = ART_RESOURCES.get_radial_glow()
	threat_glow.centered = true
	threat_glow.material = ART_RESOURCES.get_additive_material()
	threat_glow.z_index = -3

	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	sprite.centered = true
	sprite.z_index = 0
	animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null:
		animated_sprite = AnimatedSprite2D.new()
		animated_sprite.name = "AnimatedSprite2D"
		add_child(animated_sprite)
	animated_sprite.centered = true
	animated_sprite.z_index = 0

	affix_ring = get_node_or_null("AffixRing") as Line2D
	if affix_ring == null:
		affix_ring = Line2D.new()
		affix_ring.name = "AffixRing"
		add_child(affix_ring)
	affix_ring.closed = true
	affix_ring.width = 3.0
	affix_ring.z_index = -1
	affix_ring.visible = false

	affix_marker = get_node_or_null("AffixMarker") as Line2D
	if affix_marker == null:
		affix_marker = Line2D.new()
		affix_marker.name = "AffixMarker"
		add_child(affix_marker)
	affix_marker.width = 3.0
	affix_marker.z_index = 3
	affix_marker.visible = false

	hp_bar_bg = get_node_or_null("HPBarBG") as Line2D
	if hp_bar_bg == null:
		hp_bar_bg = Line2D.new()
		hp_bar_bg.name = "HPBarBG"
		add_child(hp_bar_bg)
	hp_bar_bg.width = 4.0
	hp_bar_bg.default_color = Color(0.08, 0.04, 0.04, 0.95)
	hp_bar_bg.z_index = 4

	hp_bar_fg = get_node_or_null("HPBarFG") as Line2D
	if hp_bar_fg == null:
		hp_bar_fg = Line2D.new()
		hp_bar_fg.name = "HPBarFG"
		add_child(hp_bar_fg)
	hp_bar_fg.width = 3.0
	hp_bar_fg.default_color = Color(0.9, 0.16, 0.16, 0.96)
	hp_bar_fg.z_index = 5
	_set_hp_bar_visible(false)


func _apply_sprite() -> void:
	_ensure_visual_nodes()
	var texture: Texture2D = SPRITE_LOADER.get_texture(sprite_path)
	if texture == null:
		sprite.visible = false
		return
	sprite.visible = true
	sprite.modulate = body_color
	sprite.rotation = 0.0
	sprite.position = Vector2.ZERO
	sprite.flip_h = false
	SPRITE_LOADER.fit_sprite(sprite, texture, radius * 3.0, sprite_scale)
	sprite_base_scale = sprite.scale
	_setup_animation_frames(radius * 3.0, sprite_scale)
	_apply_shadow_and_glow()


func _set_sprite_modulate(color: Color) -> void:
	if sprite != null and hit_flash_timer <= 0.0:
		sprite.modulate = color
	if animated_sprite != null and hit_flash_timer <= 0.0:
		animated_sprite.modulate = color


func _apply_shadow_and_glow() -> void:
	if is_boss:
		_ensure_boss_volume_nodes()
	if shadow != null:
		shadow.visible = true
		shadow.position = Vector2(0.0, radius * 0.86)
		ART_RESOURCES.fit_sprite(shadow, ART_RESOURCES.get_ellipse_shadow(), radius * (5.4 if is_boss else 3.2))
		shadow.modulate.a = 0.84 if is_boss else 0.68
		shadow_base_scale = shadow.scale
	if threat_glow != null:
		threat_glow.visible = true
		var glow_diameter := radius * 4.2
		var glow_alpha := 0.18
		if is_elite:
			glow_diameter = radius * 5.6
			glow_alpha = 0.34
		if is_boss:
			glow_diameter = radius * 7.2
			glow_alpha = 0.46
		ART_RESOURCES.fit_sprite(threat_glow, ART_RESOURCES.get_radial_glow(), glow_diameter)
		threat_glow_base_scale = threat_glow.scale
		threat_glow_base_alpha = glow_alpha
		var enemy_count: int = EntityFactory.get_enemy_live_count() if EntityFactory != null and EntityFactory.has_method("get_enemy_live_count") else 0
		update_threat_glow_for_crowd_count(enemy_count)
	if boss_inner_glow != null:
		boss_inner_glow.visible = is_boss
		if is_boss:
			ART_RESOURCES.fit_sprite(boss_inner_glow, ART_RESOURCES.get_radial_glow(), radius * 5.1)
			boss_inner_glow.modulate = Color(0.38, 0.12, 0.92, 0.52)
	if boss_core_glow != null:
		var mobile_boss_lod := MOBILE_TUNING.mobile_lod_enabled(get_viewport_rect().size)
		boss_core_glow.visible = is_boss and not mobile_boss_lod
		if is_boss:
			ART_RESOURCES.fit_sprite(boss_core_glow, ART_RESOURCES.get_radial_glow(), radius * 2.35)
			boss_core_glow.modulate = Color(1.0, 0.42, 0.92, 0.48)


func _ensure_boss_volume_nodes() -> void:
	if boss_inner_glow == null:
		boss_inner_glow = get_node_or_null("BossInnerGlow") as Sprite2D
	if boss_inner_glow == null:
		boss_inner_glow = Sprite2D.new()
		boss_inner_glow.name = "BossInnerGlow"
		add_child(boss_inner_glow)
	boss_inner_glow.texture = ART_RESOURCES.get_radial_glow()
	boss_inner_glow.centered = true
	boss_inner_glow.material = ART_RESOURCES.get_additive_material()
	boss_inner_glow.z_index = -2

	if boss_core_glow == null:
		boss_core_glow = get_node_or_null("BossCoreGlow") as Sprite2D
	if boss_core_glow == null:
		boss_core_glow = Sprite2D.new()
		boss_core_glow.name = "BossCoreGlow"
		add_child(boss_core_glow)
	boss_core_glow.texture = ART_RESOURCES.get_radial_glow()
	boss_core_glow.centered = true
	boss_core_glow.material = ART_RESOURCES.get_additive_material()
	boss_core_glow.z_index = 1


func update_threat_glow_for_crowd_count(enemy_count: int) -> void:
	if threat_glow == null:
		return
	var glow_alpha: float = _threat_glow_alpha_for_count(enemy_count)
	threat_glow.modulate = Color(body_color.r, body_color.g * 0.82 + 0.06, body_color.b * 0.85 + 0.1, glow_alpha)


func _threat_glow_alpha_for_count(enemy_count: int) -> float:
	if is_boss or enemy_count <= THREAT_GLOW_DENSITY_START:
		return threat_glow_base_alpha
	var t: float = clamp(
		float(enemy_count - THREAT_GLOW_DENSITY_START) / float(THREAT_GLOW_DENSITY_FULL - THREAT_GLOW_DENSITY_START),
		0.0,
		1.0
	)
	var crowded_alpha: float = maxf(0.07, threat_glow_base_alpha * 0.42)
	if is_elite:
		crowded_alpha = maxf(0.28, threat_glow_base_alpha * 0.86)
	return lerpf(threat_glow_base_alpha, crowded_alpha, t)


func _request_camera_pressure_on_spawn() -> void:
	if not GameManager.has_method("request_camera_threat_zoom"):
		return
	if is_boss:
		GameManager.request_camera_threat_zoom(3.0)
	elif is_elite:
		GameManager.request_camera_threat_zoom(1.25)


func _tick_hit_flash(delta: float) -> void:
	if hit_flash_timer <= 0.0 or sprite == null:
		return
	hit_flash_timer = max(hit_flash_timer - delta, 0.0)
	var ratio := hit_flash_timer / 0.075
	var flash_color := Color(1.0, 0.98, 0.9, 1.0).lerp(body_color, 1.0 - ratio)
	sprite.modulate = flash_color
	if animated_sprite != null:
		animated_sprite.modulate = flash_color
	if hit_flash_timer <= 0.0:
		sprite.modulate = body_color
		if animated_sprite != null:
			animated_sprite.modulate = body_color


func _update_procedural_visual(delta: float) -> void:
	if sprite == null:
		return
	var visual_delta := maxf(delta, 1.0 / 120.0)
	var moving := velocity.length_squared() > 4.0
	visual_idle_phase += visual_delta * 2.0
	visual_walk_phase += visual_delta * (TAU / max(0.08, visual_step_interval) if moving else max(2.0, visual_bob_frequency * 0.34))
	if hit_squash_timer > 0.0:
		hit_squash_timer = max(hit_squash_timer - delta, 0.0)

	if moving:
		last_visual_direction = velocity.normalized()
	if abs(last_visual_direction.x) > 0.05:
		sprite.flip_h = last_visual_direction.x < 0.0
		if animated_sprite != null:
			animated_sprite.flip_h = sprite.flip_h
	_update_animation_state(moving)

	var step_phase := fposmod(visual_walk_phase, TAU)
	var foot_sign: float = -1.0 if int(floor(visual_walk_phase / TAU)) % 2 == 0 else 1.0
	var step_lift: float = maxf(0.0, sin(step_phase))
	var step_land: float = pow(maxf(0.0, cos(step_phase)), 8.0) if moving else 0.0
	var bob: float = (-step_lift * visual_bob_amplitude + step_land * visual_bob_amplitude * 0.24) if moving else sin(visual_walk_phase) * visual_bob_amplitude * 0.18
	var lateral_offset: float = foot_sign * step_lift * visual_bob_amplitude * 0.22 if moving else 0.0
	var breath := 1.0 + sin(visual_idle_phase) * (0.01 if moving else 0.022)
	var squash := hit_squash_timer / 0.11 if hit_squash_timer > 0.0 else 0.0
	var squash_x := 1.0 + squash * 0.18 + step_land * 0.035
	var squash_y := 1.0 - squash * 0.14 - step_land * 0.025
	var tilt: float = (foot_sign * step_lift * visual_tilt_amount + clamp(last_visual_direction.x, -1.0, 1.0) * visual_tilt_amount * 0.25) if moving else 0.0

	_apply_visual_transform(
		Vector2(lateral_offset, bob),
		tilt,
		Vector2(sprite_base_scale.x * breath * squash_x, sprite_base_scale.y * breath * squash_y)
	)
	if shadow != null:
		shadow.scale = shadow_base_scale * (1.0 - abs(bob) * 0.012)
	if threat_glow != null:
		threat_glow.scale = threat_glow_base_scale * (1.0 + sin(visual_idle_phase + 0.2) * (0.07 if is_boss else 0.012))
	if is_boss and boss_inner_glow != null and boss_core_glow != null:
		var boss_pulse := 0.5 + 0.5 * sin(visual_idle_phase * (1.5 if boss_phase_two_triggered else 1.0))
		boss_inner_glow.scale = Vector2.ONE * lerpf(0.82, 1.12, boss_pulse) * threat_glow_base_scale.length() * 0.7
		boss_inner_glow.modulate.a = lerpf(0.34, 0.64, boss_pulse)
		boss_core_glow.scale = Vector2.ONE * lerpf(0.72, 1.18, 1.0 - boss_pulse) * threat_glow_base_scale.length() * 0.34
		boss_core_glow.modulate.a = lerpf(0.32, 0.62, 1.0 - boss_pulse)


func _setup_animation_frames(target_diameter: float, scale_multiplier: float) -> void:
	animation_frames_ready = false
	current_animation_name = ""
	if animated_sprite == null:
		return
	var cached: Dictionary = animation_frames_cache.get(sprite_path, {})
	if cached.is_empty():
		cached = _build_animation_frames_cache_entry()
		animation_frames_cache[sprite_path] = cached
	var frames: SpriteFrames = cached.get("frames") as SpriteFrames
	if frames == null:
		animated_sprite.visible = false
		sprite.visible = true
		return
	animated_sprite.sprite_frames = frames
	animated_sprite.animation = "idle"
	animated_sprite.modulate = body_color
	animated_sprite.play()
	animation_frames_ready = true
	animated_sprite.visible = true
	sprite.visible = false
	var max_size := float(cached.get("max_size", 0.0))
	var scale_value := 1.0 if max_size <= 0.0 else target_diameter / max_size * scale_multiplier
	animated_sprite_base_scale = Vector2.ONE * scale_value
	sprite_base_scale = animated_sprite_base_scale


func _build_animation_frames_cache_entry() -> Dictionary:
	var idle_frames := _load_generated_frames("idle", 1)
	var walk_frames := _load_generated_frames("walk", 2)
	if idle_frames.is_empty() or walk_frames.size() < 2:
		return {"frames": null, "max_size": 0.0}
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 2.2)
	for texture in idle_frames:
		frames.add_frame("idle", texture)
	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 7.0)
	for texture in walk_frames:
		frames.add_frame("walk", texture)
	return {"frames": frames, "max_size": _max_animation_frame_size(idle_frames + walk_frames)}


func _max_animation_frame_size(frames: Array[Texture2D]) -> float:
	var max_size := 0.0
	for texture in frames:
		if texture == null:
			continue
		max_size = maxf(max_size, maxf(float(texture.get_width()), float(texture.get_height())))
	return max_size


func _load_generated_frames(animation_name: String, frame_count: int) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var base_name := sprite_path.get_file().get_basename()
	if base_name == "":
		return frames
	for index in range(frame_count):
		var path := "res://assets/sprites/generated/%s_%s_%d.png" % [base_name, animation_name, index]
		var texture := SPRITE_LOADER.get_texture(path)
		if texture == null:
			break
		frames.append(texture)
	return frames


func _update_animation_state(moving: bool) -> void:
	if not animation_frames_ready or animated_sprite == null:
		return
	var next_animation := "walk" if moving else "idle"
	if current_animation_name != next_animation:
		current_animation_name = next_animation
		animated_sprite.animation = next_animation
		animated_sprite.play(next_animation)
	if moving:
		var speed_ratio: float = velocity.length() / max(1.0, speed)
		animated_sprite.speed_scale = clamp(speed_ratio * 1.08, 0.65, 1.95)
	else:
		animated_sprite.speed_scale = 1.0


func _apply_visual_transform(new_position: Vector2, new_rotation: float, new_scale: Vector2) -> void:
	if sprite != null:
		sprite.position = new_position
		sprite.rotation = new_rotation
		sprite.scale = new_scale
	if animated_sprite != null:
		animated_sprite.position = new_position
		animated_sprite.rotation = new_rotation
		animated_sprite.scale = new_scale


func _apply_visual_motion_profile() -> void:
	if is_boss:
		visual_step_interval = 0.46
		visual_bob_frequency = TAU / visual_step_interval
		visual_bob_amplitude = 2.1
		visual_tilt_amount = 0.045
	elif type_id.contains("tank") or type_id.contains("elite") or is_elite:
		visual_step_interval = 0.38
		visual_bob_frequency = TAU / visual_step_interval
		visual_bob_amplitude = 2.2
		visual_tilt_amount = 0.055
	elif type_id.contains("fast") or behavior_id == "dasher":
		visual_step_interval = 0.18
		visual_bob_frequency = TAU / visual_step_interval
		visual_bob_amplitude = 3.2
		visual_tilt_amount = 0.13
	elif behavior_id == "ranged":
		visual_step_interval = 0.32
		visual_bob_frequency = TAU / visual_step_interval
		visual_bob_amplitude = 2.0
		visual_tilt_amount = 0.075
	else:
		visual_step_interval = 0.28
		visual_bob_frequency = TAU / visual_step_interval
		visual_bob_amplitude = 2.4
		visual_tilt_amount = 0.085


func _apply_affix_visuals() -> void:
	_ensure_visual_nodes()
	if affix_ring == null:
		return
	affix_ring.visible = false
	if affix_marker != null:
		affix_marker.visible = false
	if hp_bar_fg != null:
		hp_bar_fg.default_color = Color(0.9, 0.16, 0.16, 0.96)

	var ring_radius := radius * 1.32
	var ring_color := Color(1.0, 1.0, 1.0, 0.0)
	var marker_points := PackedVector2Array()
	var marker_closed := true
	if is_boss:
		ring_radius = radius * 1.62
		ring_color = Color(0.78, 0.44, 1.0, 0.86)
		marker_points = _diamond_marker_points(radius * 0.92)
	elif is_elite and affix_id == "":
		ring_radius = radius * 1.42
		ring_color = Color(0.98, 0.72, 1.0, 0.78)
		marker_points = _diamond_marker_points(radius * 0.72)
	match affix_id:
		"affix_split":
			ring_color = Color(0.58, 1.0, 0.62, 0.78)
			marker_points = _triangle_marker_points(radius * 0.78)
		"affix_field":
			ring_radius = max(affix_field_radius, radius * 1.4)
			ring_color = Color(0.36, 0.92, 1.0, 0.42)
			marker_points = _square_marker_points(radius * 0.58)
		"affix_swift":
			ring_color = Color(1.0, 0.66, 0.24, 0.74)
			marker_points = _double_arrow_marker_points(radius * 0.64)
			marker_closed = false
		_:
			if not is_elite and not is_boss:
				return
	affix_ring.default_color = ring_color
	affix_ring.points = _circle_points(ring_radius, 40)
	affix_ring.visible = true
	if affix_marker != null:
		affix_marker.default_color = Color(ring_color.r, ring_color.g, ring_color.b, 0.96)
		affix_marker.closed = marker_closed
		affix_marker.points = marker_points
		affix_marker.visible = not marker_points.is_empty()
	if hp_bar_fg != null:
		hp_bar_fg.default_color = Color(ring_color.r, ring_color.g, ring_color.b, 0.96)


func _circle_points(circle_radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segments: int = max(8, segments)
	for index in range(safe_segments):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / float(safe_segments)) * circle_radius)
	return points


func _triangle_marker_points(marker_radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.UP * marker_radius,
		Vector2.RIGHT.rotated(TAU / 12.0) * marker_radius,
		Vector2.LEFT.rotated(-TAU / 12.0) * marker_radius
	])


func _square_marker_points(marker_radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-marker_radius, -marker_radius),
		Vector2(marker_radius, -marker_radius),
		Vector2(marker_radius, marker_radius),
		Vector2(-marker_radius, marker_radius)
	])


func _diamond_marker_points(marker_radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, -marker_radius),
		Vector2(marker_radius, 0.0),
		Vector2(0.0, marker_radius),
		Vector2(-marker_radius, 0.0)
	])


func _double_arrow_marker_points(marker_radius: float) -> PackedVector2Array:
	var half := marker_radius * 0.55
	return PackedVector2Array([
		Vector2(-half, -marker_radius),
		Vector2(half, 0.0),
		Vector2(-half, marker_radius),
		Vector2(0.0, -marker_radius),
		Vector2(marker_radius, 0.0),
		Vector2(0.0, marker_radius)
	])


func _update_hp_bar() -> void:
	_ensure_visual_nodes()
	var bar_width: float = radius * 2.1
	var y: float = -radius - 11.0
	var ratio: float = clamp(hp / max(1.0, max_hp), 0.0, 1.0)
	hp_bar_bg.points = PackedVector2Array([Vector2(-bar_width * 0.5, y), Vector2(bar_width * 0.5, y)])
	hp_bar_fg.points = PackedVector2Array([Vector2(-bar_width * 0.5, y), Vector2(-bar_width * 0.5 + bar_width * ratio, y)])


func _set_hp_bar_visible(value: bool) -> void:
	if hp_bar_bg != null:
		hp_bar_bg.visible = value
	if hp_bar_fg != null:
		hp_bar_fg.visible = value


func _default_sprite_path_for_type(enemy_type: String) -> String:
	match enemy_type:
		"fast", "stress_fast":
			return "res://assets/sprites/enemy_fast.png"
		"tank", "stress_tank":
			return "res://assets/sprites/enemy_tank.png"
		_:
			return "res://assets/sprites/enemy_grunt.png"
