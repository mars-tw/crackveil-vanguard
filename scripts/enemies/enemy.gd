class_name Enemy
extends CharacterBody2D
const CRITICAL := preload("res://scripts/services/critical_strike_resolver.gd")
const TELEGRAPH := preload("res://scripts/vfx/monster_attack_telegraph.gd")

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const TRUE_ANIMATION_LIBRARY := preload("res://scripts/animation/true_animation_library.gd")
const COMBAT_FEEDBACK := preload("res://scripts/vfx/combat_feedback.gd")
const R38_ENEMIES := preload("res://scripts/services/r38_enemy_catalog.gd")
const THREAT_GLOW_DENSITY_START := 80
const THREAT_GLOW_DENSITY_FULL := 150
const HIT_FLASH_DURATION := 0.08
const ATTACK_IMPACT_FRAME := 2
const KNOCKBACK_DECELERATION := 1050.0
const ANIMATION_LOD_NEAR_DISTANCE := 180.0
const ANIMATION_LOD_MID_DISTANCE := 320.0
const ANIMATION_LOD_FAR_DISTANCE := 560.0
const REGULAR_LOCOMOTION_FPS_SCALE := 0.6
const MOBILE_ANIMATION_FPS_SCALE := 0.5
const MID_ANIMATION_FPS_SCALE := 0.5
const FAR_ANIMATION_FPS_SCALE := 0.25
const DEATH_CROWD_THRESHOLD := 120
const SIMPLIFIED_DEATH_FPS := 10.0
const IDLE_FRAME_SEQUENCE: Array[int] = [0, 1, 2, 3]
const WALK_FRAME_SEQUENCE: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
const REGULAR_WALK_FRAME_SEQUENCE: Array[int] = [0, 2, 4, 6]
const ATTACK_FRAME_SEQUENCE: Array[int] = [0, 1, 2, 3, 4, 5]
const HURT_FRAME_SEQUENCE: Array[int] = [0, 1, 2]
const DEATH_FRAME_SEQUENCE: Array[int] = [0, 1, 2, 3, 4, 5]
const SIMPLIFIED_DEATH_FRAME_SEQUENCE: Array[int] = [0, 5]
const BOSS_OUTER_COLOR := Color(0.38, 0.12, 0.92, 1.0)
const BOSS_OUTER_PHASE_TWO_COLOR := Color(0.72, 0.1, 0.58, 1.0)
const BOSS_CORE_COLOR := Color(1.0, 0.42, 0.92, 1.0)
const BOSS_CORE_PHASE_TWO_COLOR := Color(1.0, 0.16, 0.3, 1.0)

static var animation_runtime_mobile_lod_cache: int = -1

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
var boss_phase_volley_pending: bool = false
var boss_pattern: String = "legacy_ring"
var boss_dash: bool = false
var boss_ability_cooldown: float = 4.2
var boss_volley_index: int = 0
var boss_projectiles_fired: int = 0
var damage_hit_index: int = 0
var last_hit_critical: bool = false
var special_elite_id := ""
var special_elite_name := ""
var special_skill := ""
var special_cooldown := 3.0
var special_timer := 2.0
var special_casts := 0
var special_shield_active := false
var special_gold_drops := 0
var special_projectiles_fired := 0
var special_label: Label
var biome_skill := ""
var biome_cooldown := 3.5
var biome_timer := 1.4
var biome_radius := 145.0
var biome_heal := 12.0
var biome_casts := 0
var biome_damage_hits := 0
var biome_support_healing := 0.0
var biome_projectiles_fired := 0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var sprite: Sprite2D = null
var animated_sprite: AnimatedSprite2D = null
var affix_ring: Line2D = null
var affix_marker: Line2D = null
var hp_bar_bg: Line2D = null
var hp_bar_fg: Line2D = null
var attack_cue: Line2D = null
var attack_telegraph: Node2D = null
var shadow: Sprite2D = null
var threat_glow: Sprite2D = null
var boss_inner_glow: Sprite2D = null
var boss_core_glow: Sprite2D = null
var hit_flash_timer: float = 0.0
var threat_glow_base_alpha: float = 0.18
var last_visual_direction: Vector2 = Vector2.RIGHT
var animation_frames_ready: bool = false
var current_animation_name: StringName = &"idle"
var animation_mobile_lod: bool = false
var animation_tick_elapsed: float = 0.0
var animation_sequence: Array[int] = []
var animation_sequence_index: int = 0
var animation_locomotion_speed_scale: float = 1.0
var animation_effective_fps: float = 0.0
var animation_lod_tier: StringName = &"near"
var animation_frozen: bool = false
var is_dying: bool = false
var death_finalized: bool = false
var death_animation_profile: StringName = &"none"
var pending_attack_target: WeakRef = null
var pending_attack_kind: StringName = &"contact"
var pending_attack_damage_multiplier: float = 1.0
var pending_attack_direction: Vector2 = Vector2.RIGHT
var pending_ring_projectile_count: int = 10
var attack_hitbox_active: bool = false
var attack_hit_registry: Dictionary = {}
var attack_impact_count: int = 0
var knockback_velocity: Vector2 = Vector2.ZERO
var stagger_guard_timer: float = 0.0
var death_recoil_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	_ensure_visual_nodes()
	_apply_shape()


func pool_on_acquire() -> void:
	is_active = true
	visible = true
	set_process(false)
	set_physics_process(true)
	if EntityFactory.has_method("register_enemy_animation_client"):
		EntityFactory.register_enemy_animation_client(self)
	if not is_in_group("enemies"):
		add_to_group("enemies")
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		shape_node.disabled = false


func pool_on_release() -> void:
	_release_death_animation_profile()
	if EntityFactory.has_method("unregister_enemy_animation_client"):
		EntityFactory.unregister_enemy_animation_client(self)
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
	boss_phase_volley_pending = false
	boss_pattern = "legacy_ring"
	boss_dash = false
	boss_volley_index = 0
	boss_projectiles_fired = 0
	biome_skill = ""
	biome_timer = 1.4
	biome_cooldown = 3.5
	biome_radius = 145.0
	biome_heal = 12.0
	biome_casts = 0
	biome_damage_hits = 0
	biome_support_healing = 0.0
	biome_projectiles_fired = 0
	rotation = 0.0
	if sprite != null:
		sprite.rotation = 0.0
		sprite.position = Vector2.ZERO
	if animated_sprite != null:
		animated_sprite.stop()
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
	animation_mobile_lod = false
	current_animation_name = &"idle"
	animation_tick_elapsed = 0.0
	animation_sequence = []
	animation_sequence_index = 0
	animation_locomotion_speed_scale = 1.0
	animation_effective_fps = 0.0
	animation_lod_tier = &"near"
	animation_frozen = false
	is_dying = false
	death_finalized = false
	death_animation_profile = &"none"
	pending_attack_target = null
	pending_attack_kind = &"contact"
	pending_attack_damage_multiplier = 1.0
	pending_attack_direction = Vector2.RIGHT
	pending_ring_projectile_count = 10
	attack_hitbox_active = false
	attack_hit_registry.clear()
	attack_impact_count = 0
	knockback_velocity = Vector2.ZERO
	_hide_attack_cue()
	stagger_guard_timer = 0.0
	death_recoil_velocity = Vector2.ZERO
	last_visual_direction = Vector2.RIGHT
	threat_glow_base_alpha = 0.18
	if affix_ring != null:
		affix_ring.visible = false
	if affix_marker != null:
		affix_marker.visible = false
	if attack_cue != null:
		attack_cue.visible = false
	if attack_telegraph != null:
		attack_telegraph.hide_cue()
	_set_hp_bar_visible(false)
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		shape_node.disabled = true


func pool_reset(args: Dictionary) -> void:
	global_position = args.get("position", Vector2.ZERO)
	spawn_token = int(args.get("spawn_token", spawn_token + 1))
	setup(str(args.get("enemy_id", "normal")), args.get("config", {}))
	_constrain_to_stage()


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
	boss_ability_cooldown = float(config.get("boss_ability_cooldown", 4.8))
	boss_ability_timer = boss_ability_cooldown
	boss_pattern = str(config.get("boss_pattern", "legacy_ring"))
	boss_dash = bool(config.get("boss_dash", false))
	boss_volley_index = 0
	boss_projectiles_fired = 0
	damage_hit_index = 0
	last_hit_critical = false
	special_elite_id = str(config.get("special_elite_id", ""))
	special_elite_name = str(config.get("special_elite_name", ""))
	special_skill = str(config.get("special_skill", ""))
	special_cooldown = float(config.get("special_cooldown", 3.0))
	special_timer = 1.4
	special_casts = 0
	special_gold_drops = 0
	special_projectiles_fired = 0
	special_shield_active = special_skill == "shield_slam"
	biome_skill = str(config.get("biome_skill", ""))
	biome_cooldown = float(config.get("biome_cooldown", 3.5))
	biome_timer = minf(1.4, biome_cooldown)
	biome_radius = float(config.get("biome_radius", 145.0))
	biome_heal = float(config.get("biome_heal", 12.0))
	biome_casts = 0
	biome_damage_hits = 0
	biome_support_healing = 0.0
	biome_projectiles_fired = 0
	boss_phase_volley_pending = false
	rotation = 0.0
	hit_flash_timer = 0.0
	is_dying = false
	death_finalized = false
	death_animation_profile = &"none"
	animation_tick_elapsed = 0.0
	animation_sequence_index = 0
	animation_locomotion_speed_scale = 1.0
	animation_effective_fps = 0.0
	animation_lod_tier = &"near"
	animation_frozen = false
	pending_attack_target = null
	pending_attack_direction = Vector2.RIGHT
	pending_ring_projectile_count = 10
	attack_hitbox_active = false
	attack_hit_registry.clear()
	attack_impact_count = 0
	knockback_velocity = Vector2.ZERO
	stagger_guard_timer = 0.0
	death_recoil_velocity = Vector2.ZERO
	if attack_cue != null:
		attack_cue.visible = false
	_apply_shape()
	_apply_sprite()
	_apply_affix_visuals()
	if special_label == null:
		special_label = Label.new()
		special_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		special_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		special_label.add_theme_font_size_override("font_size", 14)
		special_label.add_theme_color_override("font_outline_color", Color("11192a"))
		special_label.add_theme_constant_override("outline_size", 3)
		add_child(special_label)
	special_label.text = special_elite_name
	special_label.size = Vector2(160, 22)
	special_label.position = Vector2(-80, -64 * animated_sprite.scale.y - 25)
	special_label.visible = special_elite_name != ""
	special_label.add_theme_color_override("font_color", body_color.lightened(0.45))
	_update_hp_bar()
	_set_hp_bar_visible(false)
	_request_camera_pressure_on_spawn()


func get_hit_token() -> int:
	return spawn_token


func _physics_process(delta: float) -> void:
	if not is_active:
		return
	_tick_hit_flash(delta)
	stagger_guard_timer = maxf(0.0, stagger_guard_timer - delta)

	_tick_status_effects(delta)
	attack_timer = max(attack_timer - delta, 0.0)
	if current_animation_name == &"hurt":
		velocity = knockback_velocity
		move_and_slide()
		_constrain_to_stage()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, delta * KNOCKBACK_DECELERATION)
		_tick_affix(delta)
		_tick_hp_bar(delta)
		return
	if current_animation_name == &"attack":
		velocity = Vector2.ZERO
		_tick_affix(delta)
		_tick_hp_bar(delta)
		return
	var target := _find_nearest_hero()
	if target == null or not is_instance_valid(target):
		return

	match behavior_id:
		"biome_skill":
			_physics_biome_skill(delta, target)
		"elite_special":
			_physics_special_elite(delta, target)
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


func _physics_chaser(target: Node2D) -> void:
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length_squared() > 1.0:
		velocity = to_target.normalized() * _effective_speed()
	else:
		velocity = Vector2.ZERO
	_move_and_face()
	_try_contact_attack(target)


func _physics_ranged(delta: float, target: Node2D) -> void:
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
			_start_attack(target, 1.0, &"ranged")
	_move_and_face()
	if distance_squared < (radius + _get_target_hit_radius(target) + 8.0) ** 2:
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
				_set_sprite_modulate(Color.WHITE)
				_hide_attack_cue()
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
				_show_attack_cue(&"dash", target)
			else:
				velocity = to_target.normalized() * _effective_speed() if to_target.length_squared() > 1.0 else Vector2.ZERO
			_move_and_face()
			_try_contact_attack(target)


func _physics_boss(delta: float, target: Node2D) -> void:
	if boss_phase_volley_pending and _start_attack(target, 0.82, &"ring"):
		pending_ring_projectile_count = 14
		boss_phase_volley_pending = false
		return
	var to_target: Vector2 = target.global_position - global_position
	if boss_dash:
		_physics_dasher(delta, target)
	else:
		if to_target.length_squared() > 130.0 * 130.0:
			velocity = to_target.normalized() * _effective_speed()
		else:
			velocity = Vector2.ZERO
		_move_and_face()
		_try_contact_attack(target, 1.15)

	boss_ability_timer -= delta
	if boss_ability_timer <= 0.0 and current_animation_name != &"attack":
		_start_attack(target, 0.82, &"ring")
		boss_ability_timer = boss_ability_cooldown * (0.72 if boss_phase_two_triggered else 1.0)

	if not boss_phase_two_triggered and hp <= max_hp * 0.5:
		_trigger_boss_phase_two()


func _physics_special_elite(delta: float, target: Node2D) -> void:
	special_timer = maxf(0.0, special_timer - delta)
	special_shield_active = special_skill == "shield_slam" and special_timer > 1.0
	if special_skill == "treasure":
		var away := (global_position - target.global_position).normalized()
		velocity = away * _effective_speed() if global_position.distance_to(target.global_position) < 440.0 else Vector2.ZERO
		_move_and_face()
		if special_timer <= 0.0 and special_gold_drops < 8:
			EntityFactory.spawn_gold_coin(global_position, 5, 0.5)
			special_gold_drops += 1
			special_timer = 1.8
		return
	if special_skill == "storm_charge":
		_physics_dasher(delta, target)
	else:
		var offset := target.global_position - global_position
		velocity = offset.normalized() * _effective_speed() if offset.length() > 175.0 else Vector2.ZERO
		_move_and_face()
		_try_contact_attack(target)
	if special_timer <= 0.0 and current_animation_name not in [&"attack", &"hurt"]:
		if _start_attack(target, 1.0, &"elite"):
			special_timer = special_cooldown


func _physics_biome_skill(delta: float, target: Node2D) -> void:
	biome_timer = maxf(0.0, biome_timer - delta)
	var offset := target.global_position - global_position
	var preferred := biome_radius * 0.72 if biome_skill == "coral_slam" else ranged_preferred_distance
	velocity = offset.normalized() * _effective_speed() if offset.length_squared() > preferred * preferred else Vector2.ZERO
	_move_and_face()
	if biome_timer <= 0.0 and (biome_skill != "coral_slam" or offset.length_squared() <= (biome_radius + 24.0) * (biome_radius + 24.0)):
		if _start_attack(target, 1.0, &"biome"):
			biome_timer = biome_cooldown
	elif biome_skill != "coral_slam":
		_try_contact_attack(target)


func _apply_biome_impact() -> void:
	biome_casts += 1
	match biome_skill:
		"coral_slam":
			for hero in get_tree().get_nodes_in_group("heroes"):
				if not hero is Node2D or hero.get("is_alive") == false or not hero.has_method("take_damage"):
					continue
				if global_position.distance_squared_to(hero.global_position) <= biome_radius * biome_radius and hero.take_damage(damage, global_position):
					biome_damage_hits += 1
		"bloom_support":
			_apply_bloom_support()
		"tide_bolts", "gear_fan":
			var angles: PackedFloat32Array = PackedFloat32Array([-0.13, 0.13, PI - 0.13, PI + 0.13]) if biome_skill == "tide_bolts" else PackedFloat32Array([-0.26, -0.13, 0.0, 0.13, 0.26])
			for angle in angles:
				var stats := _enemy_projectile_stats()
				stats["color"] = body_color.lightened(0.15)
				if EntityFactory.spawn_enemy_projectile(global_position + pending_attack_direction * (radius + 8.0), pending_attack_direction.rotated(angle), stats, self, "normal") != null:
					biome_projectiles_fired += 1


func _apply_bloom_support() -> void:
	var healed := 0
	for ally in EntityFactory.get_enemies_in_radius(global_position, biome_radius):
		if ally == self or not is_instance_valid(ally) or ally.get("is_boss") == true or ally.get("is_elite") == true or not ally.has_method("apply_support_heal"):
			continue
		var amount: float = ally.apply_support_heal(biome_heal)
		if amount > 0.0:
			biome_support_healing += amount
			healed += 1
			if healed >= 6:
				break


func apply_support_heal(amount: float) -> float:
	if not is_active or is_dying or hp <= 0.0 or amount <= 0.0:
		return 0.0
	var actual := minf(amount, max_hp - hp)
	if actual <= 0.0:
		return 0.0
	hp += actual
	hp_bar_timer = 0.4
	_update_hp_bar()
	_set_hp_bar_visible(true)
	EntityFactory.spawn_damage_number("+%d" % roundi(actual), global_position + Vector2(0.0, -radius - 12.0), Color("a4efbc"), 18)
	return actual


func get_biome_debug_state() -> Dictionary:
	return {"skill":biome_skill, "casts":biome_casts, "damage_hits":biome_damage_hits, "healing":biome_support_healing, "projectiles_fired":biome_projectiles_fired, "radius":biome_radius, "timer":biome_timer}


func _apply_special_elite_impact(target: Node2D) -> void:
	special_casts += 1
	if special_skill == "summoner":
		for index in range(5):
			if EntityFactory.get_enemy_live_count() >= death_spawn_cap:
				break
			EntityFactory.spawn_enemy("elite_summonling", {"max_hp":18.0, "speed":126.0, "damage":4.0, "xp":1, "gold":2, "radius":11.0, "sprite_path":"res://assets/sprites/enemy_grunt.png", "sprite_scale":1.2}, global_position + Vector2.RIGHT.rotated(TAU * float(index) / 5.0) * 75.0)
		return
	if special_skill == "shield_slam":
		for hero in get_tree().get_nodes_in_group("heroes"):
			if hero is Node2D and hero.global_position.distance_to(global_position) <= 145.0:
				hero.take_damage(damage, global_position)
		special_shield_active = false
		return
	var count := 10 if special_skill == "frost_ring" else 5 if special_skill == "storm_charge" else 8
	for index in range(count):
		var angle := pending_attack_direction.angle() + (float(index) - 2.0) * 0.16 if special_skill == "storm_charge" else TAU * float(index) / float(count)
		var stats := _enemy_projectile_stats()
		stats["color"] = body_color
		stats["projectile_speed"] = 380.0 if special_skill == "storm_charge" else ranged_projectile_speed
		if EntityFactory.spawn_enemy_projectile(global_position, Vector2.RIGHT.rotated(angle), stats, self, "elite") != null:
			special_projectiles_fired += 1
	if special_skill == "frost_ring":
		for hero in get_tree().get_nodes_in_group("heroes"):
			if hero is Node2D and hero.global_position.distance_to(global_position) < 170.0 and hero.has_method("apply_movement_slow"):
				hero.apply_movement_slow(1.0, 0.25)


func get_special_elite_debug_state() -> Dictionary:
	return {"id":special_elite_id, "name":special_elite_name, "skill":special_skill, "casts":special_casts, "projectiles_fired":special_projectiles_fired, "shield":special_shield_active, "gold_drops":special_gold_drops, "timer":special_timer}


func _move_and_face() -> void:
	move_and_slide()
	_constrain_to_stage()
	if velocity.length_squared() > 1.0:
		last_visual_direction = velocity.normalized()


func _constrain_to_stage() -> void:
	if is_instance_valid(GameManager.arena) and GameManager.arena.get_node_or_null("LoopWorldTopology") != null:
		return
	if not is_instance_valid(GameManager.arena):
		return
	var background := GameManager.arena.get_node_or_null("Background")
	if background != null and background.has_method("get_playable_rect"):
		var bounds: Rect2 = background.get_playable_rect().grow(-14.0)
		global_position = global_position.clamp(bounds.position, bounds.end)


func _try_contact_attack(target: Node2D, damage_multiplier: float = 1.0) -> void:
	var target_hit_radius: float = _get_target_hit_radius(target)
	var attack_distance: float = radius + target_hit_radius + 4.0
	if global_position.distance_squared_to(target.global_position) > attack_distance * attack_distance:
		return
	if attack_timer > 0.0:
		return
	_start_attack(target, damage_multiplier, &"contact")


func _start_attack(target: Node2D, damage_multiplier: float, attack_kind: StringName) -> bool:
	if not is_active or is_dying or current_animation_name in [&"attack", &"hurt", &"death"]:
		return false
	pending_attack_target = weakref(target) if target != null else null
	pending_attack_kind = attack_kind
	pending_attack_damage_multiplier = damage_multiplier
	pending_attack_direction = (target.global_position - global_position).normalized() if target != null else last_visual_direction
	if pending_attack_direction == Vector2.ZERO:
		pending_attack_direction = Vector2.RIGHT
	pending_ring_projectile_count = 10
	attack_hit_registry.clear()
	attack_hitbox_active = false
	attack_timer = attack_cooldown
	_play_animation_state(&"attack", true)
	_show_attack_cue(attack_kind, target)
	return true


func _apply_attack_impact() -> void:
	if not is_active or is_dying or current_animation_name != &"attack":
		return
	attack_hitbox_active = true
	_hide_attack_cue()
	attack_impact_count += 1
	var presentation := get_tree().get_first_node_in_group("combat_presentation")
	if presentation != null:
		var effect := "monster_bite"
		if pending_attack_kind == &"ranged":
			effect = "monster_fire"
		elif special_skill == "flame_nova":
			effect = "monster_fire"
		elif boss_pattern == "ice_frost" or affix_id == "affix_field":
			effect = "monster_frost"
		elif is_boss or is_elite:
			effect = "monster_shadow"
		presentation.play_effect(effect, global_position + pending_attack_direction * radius, pending_attack_direction, 0.85 if is_boss else 0.48)
	var target := pending_attack_target.get_ref() as Node2D if pending_attack_target != null else null
	match pending_attack_kind:
		&"biome":
			_apply_biome_impact()
		&"elite":
			_apply_special_elite_impact(target)
		&"ranged":
			_fire_ranged_projectile(target)
		&"ring":
			_fire_ring_projectiles(pending_ring_projectile_count)
		_:
			_apply_contact_impact(target)
	attack_hitbox_active = false


func _apply_contact_impact(target: Node2D) -> void:
	if target == null or not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	var hit_key := int(target.get_instance_id())
	if attack_hit_registry.has(hit_key):
		return
	var target_hit_radius: float = _get_target_hit_radius(target)
	var active_distance: float = radius + target_hit_radius + 8.0
	if global_position.distance_squared_to(target.global_position) > active_distance * active_distance:
		return
	attack_hit_registry[hit_key] = true
	if target.has_method("get_channel_debug_state"):
		target.take_damage(damage * pending_attack_damage_multiplier, global_position, is_boss)
	else:
		target.take_damage(damage * pending_attack_damage_multiplier, global_position)


func _fire_ranged_projectile(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var direction := pending_attack_direction
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	EntityFactory.spawn_enemy_projectile(global_position + direction * (radius + 8.0), direction, _enemy_projectile_stats(), self, "normal")


func _fire_ring_projectiles(count: int) -> void:
	if is_boss and boss_pattern != "legacy_ring":
		_fire_stage_boss_volley()
		return
	var projectile_count: int = max(1, count)
	var projectile_stats := _enemy_projectile_stats(0.82)
	var priority := "boss" if is_boss else "normal"
	if is_boss and GameManager.has_method("request_camera_threat_zoom"):
		GameManager.request_camera_threat_zoom(1.55)
	for index in range(projectile_count):
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / float(projectile_count))
		EntityFactory.spawn_enemy_projectile(global_position + direction * (radius + 8.0), direction, projectile_stats, self, priority)


func _boss_shot_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var phase := boss_phase_two_triggered
	var aim := pending_attack_direction.angle()
	match boss_pattern:
		"legacy_ring":
			var amount := 14 if phase else 10
			for ray in range(amount):
				plan.append({"angle": TAU * float(ray) / float(amount), "speed": 1.0})
		"moon_cross":
			for arm in range(4):
				for ray in range(-1, 2):
					plan.append({"angle": float(arm) * PI * 0.5 + float(ray) * 0.12 + (0.3 if phase else 0.0), "speed": 1.0})
		"garden_fan":
			var amount := 11 if phase else 7
			for ray in range(amount):
				plan.append({"angle": aim + (float(ray) - float(amount - 1) * 0.5) * 0.16, "speed": 1.18})
		"ember_spiral":
			var amount := 16 if phase else 9
			for ray in range(amount):
				plan.append({"angle": TAU * float(ray) / float(amount) + float(boss_volley_index) * 0.38, "speed": 0.78 + float(ray % 3) * 0.16})
		"storm_star":
			for arm in range(5):
				for ray in range(4 if phase else 2):
					plan.append({"angle": float(arm) * TAU / 5.0 + float(ray) * 0.07 + float(boss_volley_index) * 0.22, "speed": 1.28})
		"ice_frost":
			for arm in range(6):
				for layer in range(3 if phase else 2):
					plan.append({"angle": float(arm) * TAU / 6.0 + float(boss_volley_index % 2) * PI / 6.0, "speed": 0.62 + float(layer) * 0.38})
		"dune_barrage":
			var rays := 7 if phase else 5
			for lane in range(-1, 2):
				for ray in range(rays):
					plan.append({"angle":aim + float(lane) * 0.52 + (float(ray) - float(rays - 1) * 0.5) * 0.055, "speed":0.82 + float(lane + 1) * 0.15})
		"tidal_spiral":
			var rays := 9 if phase else 6
			for arm in range(2):
				for ray in range(rays):
					plan.append({"angle":float(arm) * PI + float(boss_volley_index) * 0.34 + float(ray) * 0.15, "speed":0.62 + float(ray) * 0.085})
		"bloom_petals":
			var rays := 4 if phase else 2
			for petal in range(6):
				for ray in range(rays):
					plan.append({"angle":float(petal) * TAU / 6.0 + float(boss_volley_index % 2) * PI / 6.0 + (float(ray) - float(rays - 1) * 0.5) * 0.075, "speed":0.74 + float(ray % 2) * 0.36})
		"gear_cross":
			var rays := 6 if phase else 4
			for arm in range(4):
				for ray in range(rays):
					plan.append({"angle":float(arm) * PI * 0.5 + float(boss_volley_index) * 0.24 + (float(ray) - float(rays - 1) * 0.5) * 0.055, "speed":0.65 + float(ray % 3) * 0.38})
		_:
			var amount := 16 if phase else 12
			for ray in range(amount):
				plan.append({"angle": TAU * float(ray) / float(amount) + float(boss_volley_index) * 0.16, "speed": 0.88})
			for ray in range(-1, 2):
				plan.append({"angle": aim + float(ray) * 0.09, "speed": 1.45})
	return plan


func _fire_stage_boss_volley() -> void:
	if boss_pattern == "bloom_petals":
		_apply_bloom_support()
	for shot in _boss_shot_plan():
		var stats := _enemy_projectile_stats(0.82)
		stats["projectile_speed"] = ranged_projectile_speed * float(shot.speed)
		stats["color"] = body_color.lightened(0.3)
		var direction := Vector2.RIGHT.rotated(float(shot.angle))
		if EntityFactory.spawn_enemy_projectile(global_position + direction * (radius + 8.0), direction, stats, self, "boss") != null:
			boss_projectiles_fired += 1
	boss_volley_index += 1


func get_boss_debug_state() -> Dictionary:
	return {"pattern": boss_pattern, "phase_two": boss_phase_two_triggered, "dash": boss_dash, "volleys": boss_volley_index, "projectiles_fired": boss_projectiles_fired, "next_plan": _boss_shot_plan(), "ability_cooldown": boss_ability_cooldown, "support_healing":biome_support_healing}


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
	_apply_boss_phase_visuals()
	EntityFactory.spawn_death_burst(global_position, Color(0.82, 0.42, 1.0), 3.1, "boss_phase")
	boss_phase_volley_pending = true
	# The phase transition is spectacular, but its damaging volley still obeys
	# anticipation -> active frame 2 -> recovery instead of firing on HP input.
	if current_animation_name == &"attack" and pending_attack_kind == &"ring":
		pending_ring_projectile_count = 14
		boss_phase_volley_pending = false
	elif _start_attack(_find_nearest_hero(), 0.82, &"ring"):
		pending_ring_projectile_count = 14
		boss_phase_volley_pending = false
	_spawn_boss_dashers(4)
	if GameManager.has_method("record_boss_phase_two"):
		GameManager.record_boss_phase_two()


func _apply_boss_phase_visuals() -> void:
	if boss_inner_glow != null:
		boss_inner_glow.modulate = Color(BOSS_OUTER_PHASE_TWO_COLOR.r, BOSS_OUTER_PHASE_TWO_COLOR.g, BOSS_OUTER_PHASE_TWO_COLOR.b, 0.36)
	if boss_core_glow != null:
		boss_core_glow.modulate = Color(BOSS_CORE_PHASE_TWO_COLOR.r, BOSS_CORE_PHASE_TWO_COLOR.g, BOSS_CORE_PHASE_TWO_COLOR.b, 0.84)


func _spawn_boss_dashers(count: int) -> void:
	for index in range(count):
		if EntityFactory.get_enemy_live_count() >= death_spawn_cap:
			return
		var angle := TAU * float(index) / float(max(1, count))
		EntityFactory.spawn_enemy("boss_dasher", _boss_dasher_config(), global_position + Vector2.RIGHT.rotated(angle) * 72.0)


func _boss_dasher_config() -> Dictionary:
	var biome_minions := {"dune_barrage":"sand_stalker", "tidal_spiral":"tide_siren", "bloom_petals":"bloom_wisp", "gear_cross":"clockwork_reaper"}
	if biome_minions.has(boss_pattern):
		var config := R38_ENEMIES.get_config(str(biome_minions[boss_pattern]))
		config["max_hp"] = minf(48.0, float(config["max_hp"]))
		config["xp"] = 1
		config["gold"] = 1
		return config
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


func has_status_effect(effect_id: String) -> bool:
	return status_timers.has(effect_id) and float(status_timers.get(effect_id, 0.0)) > 0.0


func apply_knockback(source_position: Vector2, strength: float) -> void:
	if not is_active or strength <= 0.0:
		return
	var direction := global_position - source_position
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	# Convert the legacy displacement-strength contract into a decelerating
	# physics impulse: v^2 / (2a) ~= strength.  This keeps the collider/root
	# authoritative while preserving the former 4-8 px weapon feel.
	var resistance := 0.18 if is_boss else (0.55 if is_elite else 1.0)
	var impulse_speed := sqrt(2.0 * KNOCKBACK_DECELERATION * strength) * resistance
	var impulse := direction.normalized() * impulse_speed
	if impulse.length_squared() > knockback_velocity.length_squared():
		knockback_velocity = impulse
	if current_animation_name not in [&"hurt", &"death"] and _can_stagger(0.0):
		_play_animation_state(&"hurt", true)
		_cancel_windup_on_stagger()
		stagger_guard_timer = 0.65 if is_boss else (0.38 if is_elite else 0.0)


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

	var final_amount := maxf(0.0, amount * _damage_taken_multiplier())
	if special_shield_active:
		final_amount *= 0.45
	if final_amount <= 0.0:
		return 0.0
	damage_hit_index += 1
	last_hit_critical = false
	if GameManager.game_running and GameManager.critical_strikes_enabled:
		var result := CRITICAL.resolve(final_amount, GameManager.current_run_seed, spawn_token, damage_hit_index)
		last_hit_critical = bool(result.critical)
		final_amount = float(result.damage)
	hp = max(hp - final_amount, 0.0)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("hit")
	var number_position := global_position + Vector2(float((spawn_token * 13 + damage_hit_index * 7) % 17 - 8), -radius - 10.0)
	var severity := final_amount / maxf(1.0, max_hp)
	var heavy_hit := severity >= 0.4
	if last_hit_critical:
		EntityFactory.spawn_damage_number("爆擊 %d" % roundi(final_amount), number_position, Color("ffe18c"), 28)
		GameManager.record_critical_hit(global_position, source_position, final_amount)
	else:
		EntityFactory.spawn_damage_number(final_amount, number_position, Color(1.0, 0.79, 0.38) if heavy_hit else Color(1.0, 0.96, 0.72), 23 if heavy_hit else 0)
	COMBAT_FEEDBACK.report_hit(global_position, source_position, severity, hp <= 0.0, is_elite or is_boss)
	hp_bar_timer = 0.55
	_trigger_hit_micro_feedback()
	_update_hp_bar()
	_set_hp_bar_visible(true)

	if hp <= 0.0:
		_die(source_position)
	else:
		var recoil_direction := global_position - source_position
		if recoil_direction.length_squared() > 0.001:
			var recoil_speed := lerpf(74.0, 155.0, clampf(severity * 2.0, 0.0, 1.0))
			recoil_speed *= 0.18 if is_boss else (0.55 if is_elite else 1.0)
			if last_hit_critical:
				recoil_speed *= 1.5
			var recoil := recoil_direction.normalized() * recoil_speed
			if recoil.length_squared() > knockback_velocity.length_squared():
				knockback_velocity = recoil
		# Dense multi-hit weapons may damage the same enemy several times during
		# one reaction.  Keep the in-flight hurt clip instead of restarting frame
		# zero (and rebuilding its sequence) for every hit.
		if current_animation_name != &"hurt" and _can_stagger(severity):
			_play_animation_state(&"hurt", true)
			_cancel_windup_on_stagger()
			stagger_guard_timer = 0.65 if is_boss else (0.38 if is_elite else 0.0)
	return final_amount


func _can_stagger(severity: float) -> bool:
	if not is_elite and not is_boss:
		return true
	if stagger_guard_timer > 0.0:
		return false
	# Preserve threatening active attacks under chip damage. A substantial hit
	# can still interrupt them and earns a real articulated hurt reaction.
	if current_animation_name == &"attack":
		return severity >= (0.045 if is_boss else 0.13)
	return true


func _cancel_windup_on_stagger() -> void:
	_hide_attack_cue()
	if (behavior_id == "dasher" or special_skill == "storm_charge") and behavior_state in ["windup", "dash"]:
		# An interrupted dash must earn a new visible windup after recovery.
		# It cannot resume an invisible charge from an already-hidden cue.
		behavior_state = "recover"
		behavior_timer = dash_recover
		velocity = Vector2.ZERO


func _trigger_hit_micro_feedback() -> void:
	# Every damage route (projectile, orbit, chain, hazard, hymn) converges here.
	hit_flash_timer = maxf(hit_flash_timer, HIT_FLASH_DURATION)


func _die(source_position: Vector2 = Vector2.ZERO) -> void:
	if not is_active or is_dying:
		return
	is_dying = true
	is_active = false
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	var death_direction := (global_position - source_position).normalized()
	death_recoil_velocity = death_direction * (35.0 if is_boss else (100.0 if is_elite else 180.0))
	attack_hitbox_active = false
	pending_attack_target = null
	_hide_attack_cue()
	status_timers.clear()
	status_strengths.clear()
	_set_hp_bar_visible(false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	if EntityFactory.has_method("acquire_enemy_death_animation_profile"):
		var crowded := EntityFactory.get_enemy_live_count() >= DEATH_CROWD_THRESHOLD
		death_animation_profile = EntityFactory.acquire_enemy_death_animation_profile(is_elite or is_boss, crowded)
	else:
		death_animation_profile = &"full"
	_play_animation_state(&"death", true)


func _finalize_death() -> void:
	if death_finalized:
		return
	death_finalized = true
	_release_death_animation_profile()
	GameManager.add_kill()
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		var thump_pitch := 0.68 if is_boss else (0.78 if is_elite else 0.92)
		if GameManager.has_method("get_kill_thump_pitch"):
			thump_pitch = GameManager.get_kill_thump_pitch(thump_pitch)
		AudioManager.play_sfx("kill_thump", false, -7.0, thump_pitch)
	if is_elite and GameManager.has_method("record_elite_kill"):
		GameManager.record_elite_kill()
	# Pool generation resets death_finalized; this guarded hook awards exactly
	# one equipment roll and runs before boss victory can pause the arena.
	var loot_director := get_tree().get_first_node_in_group("loot_director")
	if loot_director != null and loot_director.has_method("on_enemy_defeated"):
		loot_director.on_enemy_defeated(global_position, is_elite, is_boss, type_id)
	if is_boss and GameManager.has_method("record_boss_kill"):
		GameManager.record_boss_kill()
	var burst_scale := 2.25 if is_boss else (1.55 if is_elite else 1.0)
	EntityFactory.spawn_death_burst(
		global_position,
		body_color,
		burst_scale,
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
	animated_sprite.position = Vector2.ZERO
	animated_sprite.rotation = 0.0
	# Enemy frames are advanced by EntityFactory's shared 50 ms ticker.  Keeping
	# this child disabled prevents one internal AnimatedSprite process per enemy.
	animated_sprite.process_mode = Node.PROCESS_MODE_DISABLED

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
	attack_cue = get_node_or_null("AttackCue") as Line2D
	if attack_cue == null:
		attack_cue = Line2D.new()
		attack_cue.name = "AttackCue"
		add_child(attack_cue)
	attack_cue.z_index = -1
	attack_cue.visible = false
	_set_hp_bar_visible(false)


func _show_attack_cue(kind: StringName, target: Node2D) -> void:
	if attack_cue == null:
		return
	if attack_telegraph == null:
		attack_telegraph = TELEGRAPH.new()
		attack_telegraph.name = "AttackTelegraph"
		add_child(attack_telegraph)
	attack_telegraph.position = Vector2(0.0, 54.0 * animated_sprite.scale.y) if animated_sprite != null else Vector2.ZERO
	var area_radius := 145.0 if kind == &"elite" and special_skill == "shield_slam" else 0.0
	if kind == &"biome" and biome_skill == "coral_slam":
		area_radius = biome_radius
	if area_radius > 0.0:
		attack_telegraph.position = Vector2.ZERO
	var cue_kind: StringName = &"ring" if kind == &"elite" or (kind == &"biome" and biome_skill == "coral_slam") else &"ranged" if kind == &"biome" else kind
	attack_telegraph.show_cue(cue_kind, dash_direction if kind == &"dash" else pending_attack_direction, radius, is_boss or is_elite, body_color, area_radius)
	attack_cue.closed = false
	attack_cue.width = 2.2
	attack_cue.default_color = Color(1.0, 0.48, 0.21, 0.8)
	if kind == &"ring":
		attack_cue.closed = true
		attack_cue.width = 3.0
		attack_cue.default_color = Color(1.0, 0.42, 0.68, 0.9)
		attack_cue.points = _circle_points(radius * 2.15, 24)
	elif kind == &"ranged" or kind == &"dash":
		var direction := dash_direction if kind == &"dash" else pending_attack_direction
		var length := minf(dash_trigger_range, 165.0) if kind == &"dash" else 95.0
		var point := direction * length
		var side := direction.orthogonal() * 8.0
		attack_cue.points = PackedVector2Array([direction * (radius + 6.0), point, point - direction * 14.0 + side, point, point - direction * 14.0 - side])
	else:
		attack_cue.visible = false
		return
	attack_cue.visible = true
	# Retain the cue's public activity flag for animation contracts while the
	# ground decal provides the visible warning instead of an arrow line.
	attack_cue.modulate.a = 0.0
	attack_cue.points = PackedVector2Array()


func _hide_attack_cue() -> void:
	if attack_cue != null:
		attack_cue.visible = false
		attack_cue.points = PackedVector2Array()
	if attack_telegraph != null:
		attack_telegraph.hide_cue()


func _apply_sprite() -> void:
	_ensure_visual_nodes()
	sprite.rotation = 0.0
	sprite.position = Vector2.ZERO
	sprite.flip_h = false
	_setup_animation_frames(radius * 3.0, sprite_scale)
	if not animation_frames_ready:
		var texture: Texture2D = SPRITE_LOADER.get_texture(sprite_path)
		sprite.visible = texture != null
		if texture != null:
			SPRITE_LOADER.fit_sprite(sprite, texture, radius * 3.0, sprite_scale)
		push_error("Missing articulated enemy animation frames for %s" % sprite_path)
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
		shadow.position = Vector2(0.0, 54.0 * animated_sprite.scale.y) if animation_frames_ready else Vector2(0.0, radius * 0.86)
		ART_RESOURCES.fit_sprite(shadow, ART_RESOURCES.get_ellipse_shadow(), radius * (6.0 if is_boss else 4.5))
		shadow.modulate.a = 0.84 if is_boss else 0.68
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
		threat_glow_base_alpha = glow_alpha
		var enemy_count: int = EntityFactory.get_enemy_live_count() if EntityFactory != null and EntityFactory.has_method("get_enemy_live_count") else 0
		update_threat_glow_for_crowd_count(enemy_count)
	if boss_inner_glow != null:
		boss_inner_glow.visible = is_boss
		if is_boss:
			ART_RESOURCES.fit_sprite(boss_inner_glow, ART_RESOURCES.get_radial_glow(), radius * 5.85)
			boss_inner_glow.modulate = Color(BOSS_OUTER_COLOR.r, BOSS_OUTER_COLOR.g, BOSS_OUTER_COLOR.b, 0.3)
	if boss_core_glow != null:
		var mobile_boss_lod := MOBILE_TUNING.mobile_lod_enabled(get_viewport_rect().size)
		boss_core_glow.visible = is_boss and not mobile_boss_lod
		if is_boss:
			ART_RESOURCES.fit_sprite(boss_core_glow, ART_RESOURCES.get_radial_glow(), radius * 1.95)
			boss_core_glow.modulate = Color(BOSS_CORE_COLOR.r, BOSS_CORE_COLOR.g, BOSS_CORE_COLOR.b, 0.78)


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
	var ratio := hit_flash_timer / HIT_FLASH_DURATION
	var flash_weight := pow(ratio, 0.65)
	var flash_color := body_color.lerp(Color(1.0, 0.98, 0.9, 1.0), flash_weight)
	sprite.modulate = flash_color
	if animated_sprite != null:
		animated_sprite.modulate = flash_color
	if hit_flash_timer <= 0.0:
		sprite.modulate = Color.WHITE
		if animated_sprite != null:
			animated_sprite.modulate = Color.WHITE


func _update_visual_state() -> void:
	if not animation_frames_ready or animated_sprite == null:
		return
	if velocity.length_squared() > 4.0 and current_animation_name not in [&"attack", &"hurt", &"death"]:
		last_visual_direction = velocity.normalized()
	if abs(last_visual_direction.x) > 0.05:
		var flip := last_visual_direction.x < 0.0
		animated_sprite.flip_h = flip
		sprite.flip_h = flip
	if current_animation_name in [&"attack", &"hurt", &"death"]:
		return
	var moving := velocity.length_squared() > 4.0
	_play_animation_state(&"walk" if moving else &"idle")
	if moving:
		var speed_ratio: float = velocity.length() / max(1.0, speed)
		animation_locomotion_speed_scale = clamp(speed_ratio, 0.6, 1.9)
	else:
		animation_locomotion_speed_scale = 1.0


func _setup_animation_frames(target_diameter: float, scale_multiplier: float) -> void:
	animation_frames_ready = false
	current_animation_name = &"idle"
	if animated_sprite == null:
		return
	animation_mobile_lod = _animation_mobile_lod_enabled()
	var frames: SpriteFrames = TRUE_ANIMATION_LIBRARY.get_sprite_frames(sprite_path)
	if frames == null:
		animated_sprite.visible = false
		sprite.visible = true
		return
	animated_sprite.sprite_frames = frames
	animated_sprite.modulate = Color.WHITE
	var readability_scale := 1.2 if is_boss else 1.45 if is_elite else 1.8
	animated_sprite.scale = Vector2.ONE * (target_diameter / float(TRUE_ANIMATION_LIBRARY.CELL_SIZE)) * scale_multiplier * readability_scale
	animation_frames_ready = true
	animated_sprite.visible = true
	sprite.visible = false
	_play_animation_state(&"idle", true)


func _animation_mobile_lod_enabled() -> bool:
	# Device class is stable for a run. Cache the complete decision so pooled
	# respawns never query ProjectSettings, DisplayServer, or the web UA.
	if animation_runtime_mobile_lod_cache < 0:
		animation_runtime_mobile_lod_cache = 1 if MOBILE_TUNING.mobile_lod_enabled(get_viewport_rect().size) else 0
	return animation_runtime_mobile_lod_cache == 1


static func reset_animation_lod_cache_for_tests() -> void:
	animation_runtime_mobile_lod_cache = -1


func _play_animation_state(next_state: StringName, restart: bool = false) -> void:
	if not animation_frames_ready or animated_sprite == null:
		return
	if current_animation_name == next_state and not restart:
		return
	# Prevent the previous locomotion frame from firing a combat event during
	# AnimatedSprite2D's animation swap.
	current_animation_name = &"transition"
	animated_sprite.stop()
	animated_sprite.animation = next_state
	animated_sprite.set_frame_and_progress(0, 0.0)
	current_animation_name = next_state
	animated_sprite.speed_scale = 0.0
	animation_tick_elapsed = 0.0
	animation_sequence = _animation_sequence_for_state(next_state)
	animation_sequence_index = 0
	animation_frozen = false


func tick_shared_enemy_animation(delta: float, focus_position: Vector2, focus_valid: bool) -> void:
	if not animation_frames_ready or animated_sprite == null or not visible:
		return
	if is_active:
		_update_visual_state()
	elif not is_dying:
		return
	elif death_recoil_velocity.length_squared() > 0.01:
		# The articulated fall poses still run in full; a small ballistic slide
		# carries the attack direction after the disabled collider leaves combat.
		global_position += death_recoil_velocity * delta
		_constrain_to_stage()
		death_recoil_velocity = death_recoil_velocity.move_toward(Vector2.ZERO, 520.0 * delta)
	var playback_fps := _shared_animation_playback_fps(focus_position, focus_valid)
	animation_effective_fps = playback_fps
	if playback_fps <= 0.0:
		return
	animation_tick_elapsed += delta
	var frame_duration := 1.0 / playback_fps
	var frame_steps := int(floor(animation_tick_elapsed / frame_duration))
	if frame_steps <= 0:
		return
	animation_tick_elapsed -= float(frame_steps) * frame_duration
	for _step in range(frame_steps):
		if not _advance_shared_animation_frame():
			break


func _shared_animation_playback_fps(focus_position: Vector2, focus_valid: bool) -> float:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return 0.0
	var base_fps := _base_animation_fps(current_animation_name)
	if current_animation_name == &"death":
		animation_lod_tier = &"death_full" if death_animation_profile != &"simplified" else &"death_simplified"
		animation_frozen = false
		return base_fps if death_animation_profile != &"simplified" else SIMPLIFIED_DEATH_FPS
	if current_animation_name in [&"attack", &"hurt"]:
		animation_lod_tier = &"combat"
		animation_frozen = false
		return base_fps
	var distance_squared := 0.0 if not focus_valid else global_position.distance_squared_to(focus_position)
	var lod_scale := 1.0
	if focus_valid and distance_squared > ANIMATION_LOD_FAR_DISTANCE * ANIMATION_LOD_FAR_DISTANCE:
		animation_lod_tier = &"frozen"
		animation_frozen = true
		return 0.0
	elif focus_valid and distance_squared > ANIMATION_LOD_MID_DISTANCE * ANIMATION_LOD_MID_DISTANCE:
		animation_lod_tier = &"far"
		lod_scale = FAR_ANIMATION_FPS_SCALE
	elif focus_valid and distance_squared > ANIMATION_LOD_NEAR_DISTANCE * ANIMATION_LOD_NEAR_DISTANCE:
		animation_lod_tier = &"mid"
		lod_scale = MID_ANIMATION_FPS_SCALE
	else:
		animation_lod_tier = &"near"
	animation_frozen = false
	var archetype_scale := 1.0 if is_elite or is_boss else REGULAR_LOCOMOTION_FPS_SCALE
	var device_scale := MOBILE_ANIMATION_FPS_SCALE if animation_mobile_lod else 1.0
	var motion_scale := animation_locomotion_speed_scale if current_animation_name == &"walk" else 1.0
	return base_fps * archetype_scale * device_scale * lod_scale * motion_scale


func _base_animation_fps(state: StringName) -> float:
	match state:
		&"idle":
			return 4.0
		&"walk":
			return 10.0
		&"attack", &"hurt":
			return 12.0
		&"death":
			return 10.0
	return 0.0


func _animation_sequence_for_state(state: StringName) -> Array[int]:
	if state == &"death" and death_animation_profile == &"simplified" and not is_elite and not is_boss:
		return SIMPLIFIED_DEATH_FRAME_SEQUENCE
	if state == &"walk" and not is_elite and not is_boss:
		return REGULAR_WALK_FRAME_SEQUENCE
	match state:
		&"idle":
			return IDLE_FRAME_SEQUENCE
		&"walk":
			return WALK_FRAME_SEQUENCE
		&"attack":
			return ATTACK_FRAME_SEQUENCE
		&"hurt":
			return HURT_FRAME_SEQUENCE
		&"death":
			return DEATH_FRAME_SEQUENCE
	return []


func _advance_shared_animation_frame() -> bool:
	if animation_sequence.is_empty() or animated_sprite == null:
		return false
	var next_index := animation_sequence_index + 1
	if next_index >= animation_sequence.size():
		if current_animation_name in [&"idle", &"walk"]:
			next_index = 0
		else:
			_on_enemy_animation_finished()
			return false
	animation_sequence_index = next_index
	animated_sprite.set_frame_and_progress(animation_sequence[animation_sequence_index], 0.0)
	_on_enemy_animation_frame_changed()
	return true


func _release_death_animation_profile() -> void:
	if death_animation_profile == &"none":
		return
	if EntityFactory.has_method("release_enemy_death_animation_profile"):
		EntityFactory.release_enemy_death_animation_profile(death_animation_profile)
	death_animation_profile = &"none"


func _on_enemy_animation_frame_changed() -> void:
	if current_animation_name == &"attack" and animated_sprite != null and animated_sprite.frame == ATTACK_IMPACT_FRAME:
		_apply_attack_impact()


func _on_enemy_animation_finished() -> void:
	match current_animation_name:
		&"attack":
			pending_attack_target = null
			attack_hitbox_active = false
			if is_active:
				_play_animation_state(&"idle", true)
		&"hurt":
			knockback_velocity = Vector2.ZERO
			if is_active:
				_play_animation_state(&"idle", true)
		&"death":
			_finalize_death()


func get_enemy_art_lod_debug_state() -> Dictionary:
	var state_counts := {}
	if animated_sprite != null and animated_sprite.sprite_frames != null:
		for state in TRUE_ANIMATION_LIBRARY.STATE_ORDER:
			state_counts[state] = animated_sprite.sprite_frames.get_frame_count(state)
	return {
		"mobile_lod": animation_mobile_lod,
		"shared_ticker": animated_sprite != null and not animated_sprite.is_playing(),
		"lod_tier": String(animation_lod_tier),
		"effective_fps": animation_effective_fps,
		"frozen_on_current_pose": animation_frozen,
		"sequence_frames": animation_sequence.size(),
		"death_profile": String(death_animation_profile),
		"idle_frames": int(state_counts.get(&"idle", 0)),
		"walk_frames": int(state_counts.get(&"walk", 0)),
		"attack_frames": int(state_counts.get(&"attack", 0)),
		"hurt_frames": int(state_counts.get(&"hurt", 0)),
		"death_frames": int(state_counts.get(&"death", 0)),
		"walk_fps": animated_sprite.sprite_frames.get_animation_speed(&"walk") if animated_sprite != null and animated_sprite.sprite_frames != null else 0.0,
		"atlas_instance_id": TRUE_ANIMATION_LIBRARY.get_shared_atlas_instance_id()
	}


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
			marker_points = _triangle_marker_points(radius * 0.92)
		"affix_field":
			ring_radius = max(affix_field_radius, radius * 1.4)
			ring_color = Color(0.36, 0.92, 1.0, 0.42)
			marker_points = _square_marker_points(radius * 0.7)
		"affix_swift":
			ring_color = Color(1.0, 0.66, 0.24, 0.74)
			marker_points = _double_arrow_marker_points(radius * 0.78)
			marker_closed = false
		_:
			if not is_elite and not is_boss:
				return
	affix_ring.default_color = ring_color
	affix_ring.points = _circle_points(ring_radius, 40)
	affix_ring.visible = true
	if affix_marker != null:
		affix_marker.width = 4.0 if affix_id != "" else 3.0
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
