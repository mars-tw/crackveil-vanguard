class_name Projectile
extends Area2D

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")

const TRAIL_NODE_CAP := 160
static var active_trail_nodes: int = 0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 560.0
var damage: float = 12.0
var source_weapon_id: String = ""
var max_range: float = 560.0
var radius: float = 4.5
var projectile_color: Color = Color(0.7, 0.96, 1.0)
var sprite_path: String = ""
var return_sprite_path: String = ""
var trail_sprite_path: String = ""
var impact_sprite_path: String = ""
var sprite_scale: float = 1.0
var pierce_left: int = 0
var traveled: float = 0.0
var source: Node = null
var hit_bodies: Dictionary = {}
var is_active: bool = false
var target_group: String = "enemies"
var riftline_fork_level: int = 0
var evo_rift_fan_level: int = 0
var motion_mode: String = "linear"
var lob_target_position: Vector2 = Vector2.ZERO
var lob_start_position: Vector2 = Vector2.ZERO
var lob_distance: float = 1.0
var lob_arc_height: float = 42.0
var lob_explosion_stats: Dictionary = {}
var lob_hazard_stats: Dictionary = {}
var lob_cluster_count: int = 1
var lob_cluster_radius: float = 0.0
var homing_turn_rate: float = 0.0
var homing_retarget_radius: float = 0.0
var homing_retarget_timer: float = 0.0
var homing_target: Node2D = null
var homing_target_token: int = 0
var boomerang_return_ratio: float = 0.52
var boomerang_catch_radius: float = 30.0
var boomerang_returning: bool = false
var boomerang_rebound_level: int = 0
var evo_razor_bulwark_level: int = 0
var missile_guidance_level: int = 0
var evo_hunter_swarm_level: int = 0
var fork_depth: int = 0
var fork_stats_cache: Dictionary = {}
var muzzle_flash_timer: float = 0.0
var muzzle_flash_base_scale: Vector2 = Vector2.ONE
var trail_registered: bool = false
var mobile_readability_active: bool = false
var visual_level: int = 0
var evolved_visual: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var sprite: Sprite2D = null
var glow: Sprite2D = null
var trail: Line2D = null
var trail_art: Sprite2D = null
var muzzle_flash: Sprite2D = null


func _ready() -> void:
	_ensure_sprite()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func pool_on_acquire() -> void:
	is_active = true
	visible = true
	set_process(true)
	set_physics_process(true)
	monitoring = true
	if not is_in_group("projectiles"):
		add_to_group("projectiles")
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		shape_node.disabled = false


func pool_on_release() -> void:
	is_active = false
	visible = false
	set_process(false)
	set_physics_process(false)
	monitoring = false
	remove_from_group("projectiles")
	hit_bodies.clear()
	source = null
	source_weapon_id = ""
	target_group = "enemies"
	riftline_fork_level = 0
	evo_rift_fan_level = 0
	motion_mode = "linear"
	lob_target_position = Vector2.ZERO
	lob_start_position = Vector2.ZERO
	lob_distance = 1.0
	lob_arc_height = 42.0
	lob_explosion_stats.clear()
	lob_hazard_stats.clear()
	lob_cluster_count = 1
	lob_cluster_radius = 0.0
	homing_turn_rate = 0.0
	homing_retarget_radius = 0.0
	homing_retarget_timer = 0.0
	homing_target = null
	homing_target_token = 0
	boomerang_return_ratio = 0.52
	boomerang_catch_radius = 30.0
	boomerang_returning = false
	return_sprite_path = ""
	trail_sprite_path = ""
	impact_sprite_path = ""
	boomerang_rebound_level = 0
	evo_razor_bulwark_level = 0
	missile_guidance_level = 0
	evo_hunter_swarm_level = 0
	fork_depth = 0
	fork_stats_cache.clear()
	traveled = 0.0
	muzzle_flash_timer = 0.0
	muzzle_flash_base_scale = Vector2.ONE
	mobile_readability_active = false
	visual_level = 0
	evolved_visual = false
	rotation = 0.0
	if sprite != null:
		sprite.rotation = 0.0
		sprite.position = Vector2.ZERO
	if glow != null:
		glow.visible = false
		glow.position = Vector2.ZERO
	if trail != null:
		trail.visible = false
	if trail_art != null:
		trail_art.visible = false
	if trail_registered:
		active_trail_nodes = max(0, active_trail_nodes - 1)
		trail_registered = false
	if muzzle_flash != null:
		muzzle_flash.visible = false
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		shape_node.disabled = true


func pool_reset(args: Dictionary) -> void:
	setup(args.get("position", Vector2.ZERO), args.get("direction", Vector2.RIGHT), args.get("stats", {}), args.get("source", null))


func setup(world_position: Vector2, projectile_direction: Vector2, projectile_stats: Dictionary, projectile_source: Node) -> void:
	global_position = world_position
	direction = projectile_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	speed = float(projectile_stats.get("projectile_speed", speed))
	damage = float(projectile_stats.get("damage", damage))
	source_weapon_id = str(projectile_stats.get("source_weapon_id", ""))
	max_range = float(projectile_stats.get("range", max_range))
	radius = float(projectile_stats.get("projectile_radius", radius))
	projectile_color = projectile_stats.get("color", projectile_color)
	sprite_path = str(projectile_stats.get("projectile_sprite_path", "res://assets/sprites/proj_bullet.png"))
	return_sprite_path = str(projectile_stats.get("projectile_return_sprite_path", ""))
	trail_sprite_path = str(projectile_stats.get("trail_sprite_path", ""))
	impact_sprite_path = str(projectile_stats.get("impact_sprite_path", ""))
	sprite_scale = float(projectile_stats.get("sprite_scale", 1.0))
	pierce_left = int(projectile_stats.get("pierce", pierce_left))
	target_group = str(projectile_stats.get("target_group", "enemies"))
	riftline_fork_level = int(projectile_stats.get("riftline_fork_level", 0))
	evo_rift_fan_level = int(projectile_stats.get("evo_rift_fan_level", 0))
	motion_mode = str(projectile_stats.get("motion_mode", "linear"))
	lob_target_position = projectile_stats.get("lob_target_position", world_position)
	lob_start_position = world_position
	lob_distance = max(1.0, world_position.distance_to(lob_target_position))
	lob_arc_height = float(projectile_stats.get("lob_arc_height", 42.0))
	lob_explosion_stats = projectile_stats.get("lob_explosion_stats", {}).duplicate(true)
	lob_hazard_stats = projectile_stats.get("lob_hazard_stats", {}).duplicate(true)
	lob_cluster_count = max(1, int(projectile_stats.get("lob_cluster_count", 1)))
	lob_cluster_radius = max(0.0, float(projectile_stats.get("lob_cluster_radius", 0.0)))
	if motion_mode == "lob":
		target_group = "none"
		max_range = lob_distance
		direction = (lob_target_position - world_position).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
	homing_turn_rate = float(projectile_stats.get("homing_turn_rate", 0.0))
	homing_retarget_radius = float(projectile_stats.get("homing_retarget_radius", 0.0))
	homing_retarget_timer = 0.0
	homing_target = projectile_stats.get("homing_target", null)
	homing_target_token = _hit_key_for(homing_target) if _is_homing_target_valid() else 0
	boomerang_return_ratio = float(projectile_stats.get("boomerang_return_ratio", 0.52))
	boomerang_catch_radius = float(projectile_stats.get("boomerang_catch_radius", 30.0))
	boomerang_returning = false
	boomerang_rebound_level = int(projectile_stats.get("boomerang_rebound_level", 0))
	evo_razor_bulwark_level = int(projectile_stats.get("evo_razor_bulwark_level", 0))
	missile_guidance_level = int(projectile_stats.get("missile_guidance_level", 0))
	evo_hunter_swarm_level = int(projectile_stats.get("evo_hunter_swarm_level", 0))
	visual_level = clamp(int(projectile_stats.get("visual_level", 0)), 0, 8)
	evolved_visual = bool(projectile_stats.get("evolved_visual", false))
	fork_depth = int(projectile_stats.get("fork_depth", 0))
	_rebuild_fork_stats_cache()
	source = projectile_source
	traveled = 0.0
	hit_bodies.clear()
	if target_group == "none":
		collision_mask = 0
		monitoring = false
	else:
		collision_mask = 1 if target_group == "heroes" else 2
		monitoring = true
	_apply_shape()
	_apply_sprite()
	rotation = direction.angle()
	muzzle_flash_timer = 0.06


func _physics_process(delta: float) -> void:
	if not is_active:
		return
	_refresh_projectile_readability()
	_update_motion(delta)
	var step := direction * speed * delta
	global_position += step
	traveled += speed * delta
	_tick_projectile_vfx(delta)
	if _should_release_after_step():
		is_active = false
		EntityFactory.release_projectile(self)


func _update_motion(delta: float) -> void:
	match motion_mode:
		"homing":
			_tick_homing(delta)
		"boomerang":
			_tick_boomerang(delta)


func _tick_homing(delta: float) -> void:
	if target_group != "enemies":
		return
	homing_retarget_timer -= delta
	if not _is_homing_target_valid() or homing_retarget_timer <= 0.0:
		homing_retarget_timer = 0.1 if missile_guidance_level <= 0 else 0.07
		var search_radius := homing_retarget_radius
		if search_radius <= 0.0:
			search_radius = max_range
		homing_target = EntityFactory.find_nearest_enemy(global_position, search_radius)
		homing_target_token = _hit_key_for(homing_target) if _is_homing_target_valid() else 0
	if not _is_homing_target_valid():
		return
	var desired: Vector2 = (homing_target.global_position - global_position).normalized()
	if desired == Vector2.ZERO:
		return
	var max_turn: float = max(0.1, homing_turn_rate) * delta
	var angle_delta := direction.angle_to(desired)
	direction = direction.rotated(clamp(angle_delta, -max_turn, max_turn)).normalized()
	rotation = direction.angle()


func _tick_boomerang(delta: float) -> void:
	if not boomerang_returning and traveled >= max_range * clamp(boomerang_return_ratio, 0.2, 0.82):
		boomerang_returning = true
		_apply_sprite()
		if boomerang_rebound_level > 0 or evo_razor_bulwark_level > 0:
			hit_bodies.clear()
	if not boomerang_returning or source == null or not is_instance_valid(source):
		return
	var desired: Vector2 = (source.global_position - global_position).normalized()
	if desired == Vector2.ZERO:
		return
	var turn_rate := 7.2 + float(boomerang_rebound_level) * 1.6 + float(evo_razor_bulwark_level) * 1.8
	var max_turn: float = turn_rate * delta
	var angle_delta := direction.angle_to(desired)
	direction = direction.rotated(clamp(angle_delta, -max_turn, max_turn)).normalized()
	rotation = direction.angle()


func _should_release_after_step() -> bool:
	if motion_mode == "lob":
		if traveled >= max_range:
			_on_lob_landed()
			return true
		return false
	if motion_mode == "boomerang":
		if boomerang_returning and source != null and is_instance_valid(source):
			if global_position.distance_squared_to(source.global_position) <= boomerang_catch_radius * boomerang_catch_radius:
				_play_boomerang_catch_feedback()
				return true
		return traveled >= max_range * (1.6 + float(evo_razor_bulwark_level) * 0.18)
	return traveled >= max_range


func _on_body_entered(body: Node) -> void:
	if not is_active or not can_hit(body):
		return

	var hit_key := _hit_key_for(body)
	if hit_bodies.has(hit_key):
		return

	hit_bodies[hit_key] = true
	if body.has_method("take_damage"):
		var applied_damage: float = float(body.take_damage(_damage_for_current_hit(), global_position))
		if target_group == "enemies":
			GameManager.record_weapon_damage(source, source_weapon_id, applied_damage)
			_apply_enemy_hit_feedback(body)
	_try_spawn_riftline_forks()

	if pierce_left <= 0:
		is_active = false
		EntityFactory.release_projectile(self)
	else:
		pierce_left -= 1


func _apply_enemy_hit_feedback(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	if source_weapon_id == "riftline_emitter" and body.has_method("apply_knockback"):
		var knockback_origin := global_position
		if source != null and is_instance_valid(source):
			knockback_origin = source.global_position
		var knockback_strength := 4.0 + minf(4.0, radius * 0.35)
		if bool(body.get("is_boss")):
			knockback_strength *= 0.62
		body.apply_knockback(knockback_origin, knockback_strength)
	if motion_mode == "homing":
		EntityFactory.spawn_death_burst(global_position, Color(1.0, 0.48, 0.22), 0.82, "burst")
		EntityFactory.spawn_death_burst(global_position, Color(0.48, 0.44, 0.38), 0.9, "smoke_ring")
	elif source_weapon_id == "rift_shield_boomerang" and impact_sprite_path != "":
		# The generated impact is emitted only after the active Area2D hit succeeds;
		# visual feedback never advances the damage timing.
		EntityFactory.spawn_death_burst(global_position, Color.WHITE, 0.82, "r24_weapon_impact", impact_sprite_path)


func _play_boomerang_catch_feedback() -> void:
	if AudioManager == null or not AudioManager.has_method("play_sfx"):
		return
	if target_group != "enemies":
		return
	AudioManager.play_sfx("boomerang_catch", false, -5.0, 1.0 + float(boomerang_rebound_level) * 0.04)


func _damage_for_current_hit() -> float:
	if motion_mode == "boomerang" and boomerang_returning:
		return damage * (1.0 + float(boomerang_rebound_level) * 0.18 + float(evo_razor_bulwark_level) * 0.22)
	return damage


func can_hit(body: Node) -> bool:
	if body == source:
		return false
	if body == null or not is_instance_valid(body):
		return false
	if not body.is_in_group(target_group):
		return false
	if target_group == "heroes":
		var alive_value: Variant = body.get("is_alive")
		return alive_value == null or bool(alive_value)
	var active_value: Variant = body.get("is_active")
	return active_value == null or bool(active_value)


func _hit_key_for(body: Node) -> int:
	if body != null and body.has_method("get_hit_token"):
		return int(body.get_hit_token())
	return int(body.get_instance_id())


func _is_homing_target_valid() -> bool:
	if homing_target == null or not is_instance_valid(homing_target):
		return false
	var active_value: Variant = homing_target.get("is_active")
	if active_value != null and not bool(active_value):
		return false
	if homing_target_token != 0 and homing_target.has_method("get_hit_token") and int(homing_target.get_hit_token()) != homing_target_token:
		return false
	return true


func _try_spawn_riftline_forks() -> void:
	if target_group != "enemies" or riftline_fork_level <= 0 or fork_depth > 0:
		return
	if fork_stats_cache.is_empty():
		return

	fork_stats_cache["pierce"] = max(0, min(pierce_left, riftline_fork_level - 1))
	var fork_angles: Array[float] = [-deg_to_rad(20.0), deg_to_rad(20.0)]
	if evo_rift_fan_level > 0:
		fork_angles = [-deg_to_rad(30.0), 0.0, deg_to_rad(30.0)]
	for angle in fork_angles:
		var fork_direction := direction.rotated(float(angle)).normalized()
		EntityFactory.call_deferred("spawn_fork_projectile", global_position + fork_direction * (radius + 4.0), fork_direction, fork_stats_cache.duplicate(true), source)


func _rebuild_fork_stats_cache() -> void:
	fork_stats_cache.clear()
	if target_group != "enemies" or riftline_fork_level <= 0 or fork_depth > 0:
		return

	var evolved_fan := evo_rift_fan_level > 0
	fork_stats_cache = {
		"damage": damage * (0.38 if evolved_fan else 0.5),
		"range": max_range * (0.58 if evolved_fan else (0.46 + 0.12 * float(min(riftline_fork_level, 2) - 1))),
		"projectile_speed": speed,
		"projectile_radius": radius,
		"pierce": max(0, min(pierce_left, riftline_fork_level - 1)),
		"color": projectile_color,
		"projectile_sprite_path": sprite_path,
		"sprite_scale": sprite_scale,
		"source_weapon_id": source_weapon_id,
		"target_group": "enemies",
		"riftline_fork_level": 0,
		"fork_depth": fork_depth + 1
	}


func _apply_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return

	var circle := shape_node.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		shape_node.shape = circle
	circle.radius = radius


func _ensure_sprite() -> void:
	if sprite != null and is_instance_valid(sprite):
		return
	glow = get_node_or_null("Glow") as Sprite2D
	if glow == null:
		glow = Sprite2D.new()
		glow.name = "Glow"
		add_child(glow)
	glow.texture = ART_RESOURCES.get_radial_glow()
	glow.centered = true
	glow.material = ART_RESOURCES.get_additive_material()
	glow.z_index = -2

	trail = get_node_or_null("Trail") as Line2D
	if trail == null:
		trail = Line2D.new()
		trail.name = "Trail"
		add_child(trail)
	trail.width = 5.0
	trail.material = ART_RESOURCES.get_additive_material()
	trail.z_index = -3
	trail.visible = false

	trail_art = get_node_or_null("TrailArt") as Sprite2D
	if trail_art == null:
		trail_art = Sprite2D.new()
		trail_art.name = "TrailArt"
		add_child(trail_art)
	trail_art.centered = true
	trail_art.z_index = -1
	trail_art.visible = false

	muzzle_flash = get_node_or_null("MuzzleFlash") as Sprite2D
	if muzzle_flash == null:
		muzzle_flash = Sprite2D.new()
		muzzle_flash.name = "MuzzleFlash"
		add_child(muzzle_flash)
	muzzle_flash.texture = ART_RESOURCES.get_radial_glow()
	muzzle_flash.centered = true
	muzzle_flash.material = ART_RESOURCES.get_additive_material()
	muzzle_flash.z_index = 2

	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	sprite.centered = true


func _apply_sprite() -> void:
	_ensure_sprite()
	var display_sprite_path := return_sprite_path if boomerang_returning and return_sprite_path != "" else sprite_path
	var texture: Texture2D = SPRITE_LOADER.get_texture(display_sprite_path)
	if texture == null:
		sprite.visible = false
		return
	sprite.visible = true
	sprite.modulate = Color.WHITE if source_weapon_id == "rift_shield_boomerang" else _projectile_display_color()
	var growth := _visual_growth(0.035, 0.14)
	SPRITE_LOADER.fit_sprite(sprite, texture, radius * 4.0 * growth, sprite_scale)
	match source_weapon_id:
		"riftline_emitter":
			sprite.scale.x *= 1.75
		"rift_seeker_missiles":
			sprite.scale.x *= 1.3
		"grenade_lob", "boss_ring":
			sprite.scale *= 1.16
		"rift_shield_boomerang":
			sprite.scale *= 1.12
	_configure_r24_trail_art()
	_configure_projectile_vfx()


func _configure_r24_trail_art() -> void:
	if trail_art == null:
		return
	if source_weapon_id != "rift_shield_boomerang" or trail_sprite_path == "":
		trail_art.visible = false
		return
	var texture := SPRITE_LOADER.get_texture(trail_sprite_path)
	if texture == null:
		trail_art.visible = false
		return
	trail_art.visible = true
	trail_art.texture = texture
	trail_art.modulate = Color(1.0, 1.0, 1.0, 0.72)
	trail_art.flip_h = false
	trail_art.position = Vector2(-radius * 1.5, 0.0)
	ART_RESOURCES.fit_sprite(trail_art, texture, radius * 7.2)


func _configure_projectile_vfx() -> void:
	var vfx_color := projectile_color
	var glow_alpha: float = 0.34
	var mobile_readability := MOBILE_TUNING.use_mobile_ui(_viewport_size_for_lod())
	mobile_readability_active = mobile_readability
	var enemy_projectile := target_group == "heroes"
	if source_weapon_id == "boss_ring":
		vfx_color = Color(0.9, 0.42, 1.0, 1.0)
		glow_alpha = 0.62
	elif target_group == "heroes":
		vfx_color = Color(1.0, 0.36, 0.18, 1.0)
		glow_alpha = 0.44
	elif fork_depth > 0:
		glow_alpha = 0.22
	elif motion_mode == "homing":
		glow_alpha = 0.42
	elif motion_mode == "boomerang":
		glow_alpha = 0.48
	if glow != null:
		glow.visible = true
		glow.position = Vector2.ZERO
		if enemy_projectile and source_weapon_id != "boss_ring":
			# A dark, normal-blended silhouette is the CVD-safe second channel for
			# enemy ember shots; player ember weapons keep their additive halo.
			glow.material = null
			glow.modulate = Color(0.008, 0.012, 0.02, 0.88 if mobile_readability else 0.76)
			ART_RESOURCES.fit_sprite(glow, ART_RESOURCES.get_radial_glow(), radius * (10.8 if mobile_readability else 9.8))
		else:
			glow.material = ART_RESOURCES.get_additive_material()
			glow.modulate = Color(vfx_color.r, vfx_color.g, vfx_color.b, glow_alpha)
			var glow_growth := _visual_growth(0.0225, 0.12)
			var glow_size := radius * (9.6 if source_weapon_id == "boss_ring" else (8.6 if motion_mode == "boomerang" else 7.8)) * glow_growth
			ART_RESOURCES.fit_sprite(glow, ART_RESOURCES.get_radial_glow(), glow_size)
	if trail != null:
		if not trail_registered and active_trail_nodes < TRAIL_NODE_CAP:
			active_trail_nodes += 1
			trail_registered = true
		trail.visible = trail_registered
		var trail_growth := _visual_growth(0.025, 0.14)
		trail.width = clamp(radius * (1.65 if motion_mode == "boomerang" else 1.45) * trail_growth, 3.0, 14.0)
		var alpha: float = 0.52 if target_group != "heroes" else 0.42
		if fork_depth > 0:
			alpha *= 0.62
		if motion_mode == "homing":
			alpha *= 1.18
		if motion_mode == "boomerang":
			alpha *= 1.25
		if enemy_projectile and mobile_readability:
			alpha = max(alpha, 0.66)
		if source_weapon_id == "riftline_emitter":
			var riftline_growth := 0.0 if mobile_readability else float(visual_level) * 0.21 + (1.1 if evolved_visual else 0.0)
			trail.width = clamp(2.4 + riftline_growth, 2.4, 6.8)
			alpha = 0.82
		elif source_weapon_id == "rail_lance":
			trail.width = clamp(radius * 0.92, 2.6, 5.2)
			alpha = 0.92
		elif source_weapon_id == "rift_seeker_missiles":
			trail.width = clamp(radius * 1.9 * trail_growth, 5.0, 15.0)
			vfx_color = Color(0.58, 0.66, 0.68, 1.0)
			alpha = 0.52
		elif source_weapon_id == "grenade_lob":
			vfx_color = Color(1.0, 0.38, 0.08, 1.0)
			alpha = 0.74
		elif source_weapon_id == "rift_shield_boomerang":
			trail.width = clamp(radius * 2.05 * trail_growth, 6.5, 16.0)
			alpha = 0.64
		elif source_weapon_id == "boss_ring":
			trail.width = clamp(radius * 1.15, 4.0, 10.0)
			alpha = 0.76
		trail.default_color = Color(vfx_color.r, vfx_color.g, vfx_color.b, alpha)
		var trail_time := 0.1 if source_weapon_id == "riftline_emitter" else (0.085 if source_weapon_id == "rift_seeker_missiles" else (0.072 if motion_mode == "boomerang" else 0.06))
		var max_length := 72.0
		if source_weapon_id == "riftline_emitter":
			max_length = 72.0 if mobile_readability else 96.0
		elif source_weapon_id == "rift_seeker_missiles":
			max_length = 56.0 if mobile_readability else 72.0
		var evolved_length_multiplier := 1.0 if mobile_readability else (1.09 if evolved_visual else 1.0)
		var length: float = clamp(speed * trail_time * evolved_length_multiplier, 20.0, max_length)
		trail.points = PackedVector2Array([Vector2(-length, 0.0), Vector2(-length * 0.32, 0.0), Vector2.ZERO])
	if muzzle_flash != null:
		muzzle_flash.visible = true
		muzzle_flash.modulate = Color(vfx_color.r, vfx_color.g, vfx_color.b, 0.72)
		ART_RESOURCES.fit_sprite(muzzle_flash, ART_RESOURCES.get_radial_glow(), radius * 8.5)
		muzzle_flash_base_scale = muzzle_flash.scale


func _visual_growth(level_step: float, evolved_bonus: float) -> float:
	# Mobile retains each weapon's color/shape language without increasing its
	# fill footprint as it levels. Desktop keeps a deliberately shallower ramp.
	if MOBILE_TUNING.mobile_lod_enabled(_viewport_size_for_lod()):
		return 1.0
	return 1.0 + float(visual_level) * level_step + (evolved_bonus if evolved_visual else 0.0)


func _projectile_display_color() -> Color:
	if source_weapon_id == "boss_ring":
		return Color(1.0, 0.66, 1.0, 1.0)
	if target_group == "heroes" and MOBILE_TUNING.use_mobile_ui(_viewport_size_for_lod()):
		return Color(1.0, 0.44, 0.16, 1.0)
	return projectile_color


func _refresh_projectile_readability() -> void:
	var next_mobile_readability := MOBILE_TUNING.use_mobile_ui(_viewport_size_for_lod())
	if next_mobile_readability == mobile_readability_active:
		return
	_apply_sprite()


func get_mobile_readability_debug_state() -> Dictionary:
	return {
		"mobile_readability": mobile_readability_active,
		"sprite_color": sprite.modulate if sprite != null else Color.TRANSPARENT,
		"glow_color": glow.modulate if glow != null else Color.TRANSPARENT,
		"trail_color": trail.default_color if trail != null else Color.TRANSPARENT
	}


func _tick_projectile_vfx(delta: float) -> void:
	if motion_mode == "lob":
		_tick_lob_arc_vfx()
	if source_weapon_id == "boss_ring" and sprite != null:
		sprite.rotation += delta * 3.8
		if glow != null:
			glow.modulate.a = 0.46 + sin(traveled * 0.045) * 0.16
	if muzzle_flash == null or not muzzle_flash.visible:
		return
	muzzle_flash_timer = max(muzzle_flash_timer - delta, 0.0)
	var ratio: float = muzzle_flash_timer / 0.06
	muzzle_flash.modulate.a = 0.72 * ratio
	muzzle_flash.scale = muzzle_flash_base_scale * (0.72 + ratio * 0.28)
	if muzzle_flash_timer <= 0.0:
		muzzle_flash.visible = false


func _tick_lob_arc_vfx() -> void:
	var t: float = clamp(traveled / max(1.0, lob_distance), 0.0, 1.0)
	var lift: float = sin(t * PI) * lob_arc_height
	if sprite != null:
		sprite.position = Vector2(0.0, -lift)
	if glow != null:
		glow.position = Vector2(0.0, -lift * 0.34)


func _on_lob_landed() -> void:
	if not lob_explosion_stats.is_empty():
		EntityFactory.spawn_explosion(lob_target_position, lob_explosion_stats, source)
	if not lob_hazard_stats.is_empty():
		EntityFactory.spawn_hazard_zone(lob_target_position, lob_hazard_stats, source)
	if lob_cluster_count <= 1 or lob_cluster_radius <= 0.0 or lob_explosion_stats.is_empty():
		return
	for index in range(1, lob_cluster_count):
		var angle := TAU * float(index) / float(lob_cluster_count) + 0.37
		var distance := lob_cluster_radius * (0.62 + 0.2 * float(index % 2))
		var cluster_position := lob_target_position + Vector2.RIGHT.rotated(angle) * distance
		var cluster_stats := lob_explosion_stats.duplicate(true)
		cluster_stats["damage"] = float(cluster_stats.get("damage", damage)) * 0.58
		cluster_stats["area_radius"] = float(cluster_stats.get("area_radius", radius * 8.0)) * 0.58
		EntityFactory.spawn_delayed_explosion(cluster_position, cluster_stats, source, 0.05 * float(index))


func _viewport_size_for_lod() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		return viewport_size
	var window_size := DisplayServer.window_get_size()
	if window_size.x > 0 and window_size.y > 0:
		return Vector2(window_size)
	return Vector2(1280.0, 720.0)
