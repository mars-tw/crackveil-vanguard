extends Node2D

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")

var burst_color: Color = Color(1.0, 0.4, 0.4)
var burst_scale: float = 1.0
var age: float = 0.0
var lifetime: float = 0.32
var is_active: bool = false
var sprite: Sprite2D = null
var glow: Sprite2D = null
var particles: CPUParticles2D = null


func _ready() -> void:
	_ensure_sprite()


func pool_on_acquire() -> void:
	is_active = true
	visible = true
	set_process(true)


func pool_on_release() -> void:
	is_active = false
	visible = false
	set_process(false)
	age = 0.0
	rotation = 0.0
	if sprite != null:
		sprite.visible = false
		sprite.rotation = 0.0
	if glow != null:
		glow.visible = false
	if particles != null:
		particles.emitting = false
	burst_scale = 1.0


func pool_reset(args: Dictionary) -> void:
	setup(args.get("position", Vector2.ZERO), args.get("color", Color.WHITE), float(args.get("scale", 1.0)))


func setup(world_position: Vector2, color_value: Color, scale_value: float = 1.0) -> void:
	global_position = world_position
	burst_color = color_value
	burst_scale = clamp(scale_value, 0.75, 3.4)
	age = 0.0
	rotation = 0.0
	_apply_sprite()
	_emit_particles()


func _process(delta: float) -> void:
	if not is_active:
		return
	age += delta
	if age >= lifetime:
		is_active = false
		EntityFactory.release_death_burst(self)
	else:
		_update_sprite_state()


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

	particles = get_node_or_null("BurstParticles") as CPUParticles2D
	if particles == null:
		particles = CPUParticles2D.new()
		particles.name = "BurstParticles"
		add_child(particles)
	particles.texture = ART_RESOURCES.get_particle_core()
	particles.material = ART_RESOURCES.get_additive_material()
	particles.one_shot = true
	particles.amount = 16
	particles.lifetime = 0.34
	particles.explosiveness = 0.92
	particles.randomness = 0.48
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 7.0
	particles.direction = Vector2.RIGHT
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 45.0
	particles.initial_velocity_max = 155.0
	particles.scale_amount_min = 0.18
	particles.scale_amount_max = 0.58
	particles.z_index = 3

	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	sprite.centered = true


func _apply_sprite() -> void:
	_ensure_sprite()
	var texture: Texture2D = SPRITE_LOADER.get_texture("res://assets/sprites/fx_explosion.png")
	if texture == null:
		sprite.visible = false
		return
	sprite.visible = true
	if glow != null:
		glow.visible = true
	_update_sprite_state()


func _update_sprite_state() -> void:
	if sprite == null:
		return
	var t: float = clamp(age / lifetime, 0.0, 1.0)
	var texture := sprite.texture
	if texture != null:
		SPRITE_LOADER.fit_sprite(sprite, texture, (56.0 + 34.0 * t) * burst_scale, 1.0)
	sprite.rotation += 1.8 * get_process_delta_time()
	sprite.modulate = Color(burst_color.r, burst_color.g, burst_color.b, 1.0 - t)
	if glow != null:
		ART_RESOURCES.fit_sprite(glow, ART_RESOURCES.get_radial_glow(), (104.0 + 58.0 * t) * burst_scale)
		glow.modulate = Color(burst_color.r, burst_color.g, burst_color.b, (1.0 - t) * 0.56)


func _emit_particles() -> void:
	if particles == null:
		return
	particles.amount = int(clamp(round(22.0 * burst_scale), 16.0, 56.0))
	particles.initial_velocity_min = 66.0 * burst_scale
	particles.initial_velocity_max = 210.0 * burst_scale
	particles.scale_amount_min = 0.22 * burst_scale
	particles.scale_amount_max = 0.72 * burst_scale
	particles.color = Color(burst_color.r, burst_color.g, burst_color.b, 0.88)
	particles.restart()
	particles.emitting = true
