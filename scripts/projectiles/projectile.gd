class_name Projectile
extends Area2D

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")

const TRAIL_NODE_CAP := 160
static var active_trail_nodes: int = 0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 560.0
var damage: float = 12.0
var max_range: float = 560.0
var radius: float = 4.5
var projectile_color: Color = Color(0.7, 0.96, 1.0)
var sprite_path: String = ""
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

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var sprite: Sprite2D = null
var glow: Sprite2D = null
var trail: Line2D = null
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
	target_group = "enemies"
	riftline_fork_level = 0
	evo_rift_fan_level = 0
	motion_mode = "linear"
	homing_turn_rate = 0.0
	homing_retarget_radius = 0.0
	homing_retarget_timer = 0.0
	homing_target = null
	homing_target_token = 0
	boomerang_return_ratio = 0.52
	boomerang_catch_radius = 30.0
	boomerang_returning = false
	boomerang_rebound_level = 0
	evo_razor_bulwark_level = 0
	missile_guidance_level = 0
	evo_hunter_swarm_level = 0
	fork_depth = 0
	fork_stats_cache.clear()
	traveled = 0.0
	muzzle_flash_timer = 0.0
	muzzle_flash_base_scale = Vector2.ONE
	rotation = 0.0
	if sprite != null:
		sprite.rotation = 0.0
	if glow != null:
		glow.visible = false
	if trail != null:
		trail.visible = false
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
	max_range = float(projectile_stats.get("range", max_range))
	radius = float(projectile_stats.get("projectile_radius", radius))
	projectile_color = projectile_stats.get("color", projectile_color)
	sprite_path = str(projectile_stats.get("projectile_sprite_path", "res://assets/sprites/proj_bullet.png"))
	sprite_scale = float(projectile_stats.get("sprite_scale", 1.0))
	pierce_left = int(projectile_stats.get("pierce", pierce_left))
	target_group = str(projectile_stats.get("target_group", "enemies"))
	riftline_fork_level = int(projectile_stats.get("riftline_fork_level", 0))
	evo_rift_fan_level = int(projectile_stats.get("evo_rift_fan_level", 0))
	motion_mode = str(projectile_stats.get("motion_mode", "linear"))
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
	fork_depth = int(projectile_stats.get("fork_depth", 0))
	_rebuild_fork_stats_cache()
	source = projectile_source
	traveled = 0.0
	hit_bodies.clear()
	collision_mask = 1 if target_group == "heroes" else 2
	_apply_shape()
	_apply_sprite()
	rotation = direction.angle()
	muzzle_flash_timer = 0.06


func _physics_process(delta: float) -> void:
	if not is_active:
		return
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
	if motion_mode == "boomerang":
		if boomerang_returning and source != null and is_instance_valid(source):
			if global_position.distance_squared_to(source.global_position) <= boomerang_catch_radius * boomerang_catch_radius:
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
		body.take_damage(_damage_for_current_hit(), global_position)
	_try_spawn_riftline_forks()

	if pierce_left <= 0:
		is_active = false
		EntityFactory.release_projectile(self)
	else:
		pierce_left -= 1


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
		EntityFactory.spawn_fork_projectile(global_position + fork_direction * (radius + 4.0), fork_direction, fork_stats_cache, source)


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
	var texture: Texture2D = SPRITE_LOADER.get_texture(sprite_path)
	if texture == null:
		sprite.visible = false
		return
	sprite.visible = true
	sprite.modulate = projectile_color
	SPRITE_LOADER.fit_sprite(sprite, texture, radius * 4.0, sprite_scale)
	_configure_projectile_vfx()


func _configure_projectile_vfx() -> void:
	var vfx_color := projectile_color
	var glow_alpha: float = 0.34
	if target_group == "heroes":
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
		glow.modulate = Color(vfx_color.r, vfx_color.g, vfx_color.b, glow_alpha)
		ART_RESOURCES.fit_sprite(glow, ART_RESOURCES.get_radial_glow(), radius * (8.6 if motion_mode == "boomerang" else 7.8))
	if trail != null:
		if not trail_registered and active_trail_nodes < TRAIL_NODE_CAP:
			active_trail_nodes += 1
			trail_registered = true
		trail.visible = trail_registered
		trail.width = clamp(radius * (1.65 if motion_mode == "boomerang" else 1.45), 3.0, 10.0)
		var alpha: float = 0.52 if target_group != "heroes" else 0.42
		if fork_depth > 0:
			alpha *= 0.62
		if motion_mode == "homing":
			alpha *= 1.18
		if motion_mode == "boomerang":
			alpha *= 1.25
		trail.default_color = Color(vfx_color.r, vfx_color.g, vfx_color.b, alpha)
		var length: float = clamp(speed * (0.072 if motion_mode == "boomerang" else 0.06), 20.0, 72.0)
		trail.points = PackedVector2Array([Vector2(-length, 0.0), Vector2(-length * 0.32, 0.0), Vector2.ZERO])
	if muzzle_flash != null:
		muzzle_flash.visible = true
		muzzle_flash.modulate = Color(vfx_color.r, vfx_color.g, vfx_color.b, 0.72)
		ART_RESOURCES.fit_sprite(muzzle_flash, ART_RESOURCES.get_radial_glow(), radius * 8.5)
		muzzle_flash_base_scale = muzzle_flash.scale


func _tick_projectile_vfx(delta: float) -> void:
	if muzzle_flash == null or not muzzle_flash.visible:
		return
	muzzle_flash_timer = max(muzzle_flash_timer - delta, 0.0)
	var ratio: float = muzzle_flash_timer / 0.06
	muzzle_flash.modulate.a = 0.72 * ratio
	muzzle_flash.scale = muzzle_flash_base_scale * (0.72 + ratio * 0.28)
	if muzzle_flash_timer <= 0.0:
		muzzle_flash.visible = false
