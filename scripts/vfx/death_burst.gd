extends Node2D

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")

var burst_color: Color = Color(1.0, 0.4, 0.4)
var burst_scale: float = 1.0
var burst_style: String = "burst"
var particle_multiplier: float = 1.0
var age: float = 0.0
var lifetime: float = 0.32
var is_active: bool = false
var sprite: Sprite2D = null
var glow: Sprite2D = null
var particles: CPUParticles2D = null
var column: Line2D = null
var shockwave: Line2D = null


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
	if column != null:
		column.visible = false
	if shockwave != null:
		shockwave.visible = false
	burst_scale = 1.0
	burst_style = "burst"
	particle_multiplier = 1.0


func pool_reset(args: Dictionary) -> void:
	setup(
		args.get("position", Vector2.ZERO),
		args.get("color", Color.WHITE),
		float(args.get("scale", 1.0)),
		str(args.get("style", "burst")),
		float(args.get("particle_multiplier", 1.0))
	)


func setup(world_position: Vector2, color_value: Color, scale_value: float = 1.0, style_value: String = "burst", particle_multiplier_value: float = 1.0) -> void:
	global_position = world_position
	burst_color = color_value
	burst_scale = clamp(scale_value, 0.75, 3.4)
	burst_style = style_value
	particle_multiplier = clamp(particle_multiplier_value, 0.2, 1.0)
	lifetime = _lifetime_for_style()
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

	column = get_node_or_null("Column") as Line2D
	if column == null:
		column = Line2D.new()
		column.name = "Column"
		add_child(column)
	column.material = ART_RESOURCES.get_additive_material()
	column.z_index = 2
	column.visible = false

	shockwave = get_node_or_null("Shockwave") as Line2D
	if shockwave == null:
		shockwave = Line2D.new()
		shockwave.name = "Shockwave"
		add_child(shockwave)
	shockwave.closed = true
	shockwave.material = ART_RESOURCES.get_additive_material()
	shockwave.z_index = 1
	shockwave.visible = false

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
	if column != null:
		column.visible = burst_style == "level_column"
		column.width = 18.0 * burst_scale
		column.default_color = Color(burst_color.r, burst_color.g, burst_color.b, 0.92)
	if shockwave != null:
		shockwave.visible = burst_style == "level_column" or burst_style == "smoke_ring"
		shockwave.width = 5.0 * burst_scale
		shockwave.default_color = Color(burst_color.r, burst_color.g, burst_color.b, 0.62)
	_update_sprite_state()


func _update_sprite_state() -> void:
	if sprite == null:
		return
	var t: float = clamp(age / lifetime, 0.0, 1.0)
	var texture := sprite.texture
	var base_size := _sprite_base_size(t)
	if texture != null:
		SPRITE_LOADER.fit_sprite(sprite, texture, base_size * burst_scale, 1.0)
	sprite.rotation += 1.8 * get_process_delta_time()
	var sprite_alpha := (1.0 - t) * _sprite_alpha_multiplier()
	sprite.modulate = Color(burst_color.r, burst_color.g, burst_color.b, sprite_alpha)
	if glow != null:
		ART_RESOURCES.fit_sprite(glow, ART_RESOURCES.get_radial_glow(), _glow_base_size(t) * burst_scale)
		glow.modulate = Color(burst_color.r, burst_color.g, burst_color.b, (1.0 - t) * _glow_alpha_multiplier())
	if column != null and column.visible:
		var height := lerpf(76.0, 228.0, min(1.0, t * 1.45)) * burst_scale
		column.width = lerpf(24.0, 4.0, t) * burst_scale
		column.default_color = Color(burst_color.r, burst_color.g, burst_color.b, (1.0 - t) * 0.86)
		column.points = PackedVector2Array([Vector2(0.0, 12.0), Vector2(0.0, -height)])
	if shockwave != null and shockwave.visible:
		var ring_radius := lerpf(18.0, 86.0 if burst_style == "level_column" else 54.0, t) * burst_scale
		shockwave.default_color = Color(burst_color.r, burst_color.g, burst_color.b, (1.0 - t) * (0.58 if burst_style == "level_column" else 0.32))
		shockwave.points = _circle_points(ring_radius, 36)


func _emit_particles() -> void:
	if particles == null:
		return
	_configure_particles_for_style()
	particles.restart()
	particles.emitting = true


func _configure_particles_for_style() -> void:
	particles.gravity = Vector2.ZERO
	particles.direction = Vector2.RIGHT
	particles.spread = 180.0
	particles.emission_sphere_radius = 7.0 * burst_scale
	particles.color = Color(burst_color.r, burst_color.g, burst_color.b, 0.88)
	match burst_style:
		"spark":
			particles.amount = _scaled_particle_amount(12.0, 8.0, 24.0)
			particles.lifetime = 0.22
			particles.initial_velocity_min = 120.0 * burst_scale
			particles.initial_velocity_max = 255.0 * burst_scale
			particles.scale_amount_min = 0.12 * burst_scale
			particles.scale_amount_max = 0.34 * burst_scale
		"smoke_ring":
			particles.amount = _scaled_particle_amount(18.0, 12.0, 28.0)
			particles.lifetime = 0.42
			particles.initial_velocity_min = 45.0 * burst_scale
			particles.initial_velocity_max = 105.0 * burst_scale
			particles.scale_amount_min = 0.38 * burst_scale
			particles.scale_amount_max = 0.92 * burst_scale
			particles.color = Color(burst_color.r, burst_color.g, burst_color.b, 0.42)
		"gold_rain":
			particles.amount = _scaled_particle_amount(30.0, 18.0, 54.0)
			particles.lifetime = 0.48
			particles.direction = Vector2(0.0, -1.0)
			particles.spread = 72.0
			particles.gravity = Vector2(0.0, 420.0)
			particles.initial_velocity_min = 165.0 * burst_scale
			particles.initial_velocity_max = 310.0 * burst_scale
			particles.scale_amount_min = 0.16 * burst_scale
			particles.scale_amount_max = 0.46 * burst_scale
		"level_column":
			particles.amount = _scaled_particle_amount(26.0, 18.0, 44.0)
			particles.lifetime = 0.52
			particles.direction = Vector2(0.0, -1.0)
			particles.spread = 34.0
			particles.initial_velocity_min = 135.0 * burst_scale
			particles.initial_velocity_max = 280.0 * burst_scale
			particles.scale_amount_min = 0.18 * burst_scale
			particles.scale_amount_max = 0.52 * burst_scale
		_:
			particles.amount = _scaled_particle_amount(22.0, 16.0, 56.0)
			particles.lifetime = 0.34
			particles.initial_velocity_min = 66.0 * burst_scale
			particles.initial_velocity_max = 210.0 * burst_scale
			particles.scale_amount_min = 0.22 * burst_scale
			particles.scale_amount_max = 0.72 * burst_scale


func _scaled_particle_amount(base_amount: float, min_amount: float, max_amount: float) -> int:
	var unscaled_amount: float = clamp(round(base_amount * burst_scale), min_amount, max_amount)
	return max(1, int(round(unscaled_amount * particle_multiplier)))


func _lifetime_for_style() -> float:
	match burst_style:
		"spark":
			return 0.24
		"smoke_ring":
			return 0.48
		"gold_rain":
			return 0.56
		"level_column":
			return 0.62
		_:
			return 0.32


func _sprite_base_size(t: float) -> float:
	match burst_style:
		"spark":
			return 32.0 + 20.0 * t
		"smoke_ring":
			return 42.0 + 46.0 * t
		"gold_rain":
			return 48.0 + 30.0 * t
		"level_column":
			return 68.0 + 42.0 * t
		_:
			return 56.0 + 34.0 * t


func _glow_base_size(t: float) -> float:
	match burst_style:
		"spark":
			return 58.0 + 28.0 * t
		"smoke_ring":
			return 110.0 + 76.0 * t
		"gold_rain":
			return 132.0 + 70.0 * t
		"level_column":
			return 154.0 + 94.0 * t
		_:
			return 104.0 + 58.0 * t


func _sprite_alpha_multiplier() -> float:
	return 0.42 if burst_style == "smoke_ring" else 1.0


func _glow_alpha_multiplier() -> float:
	match burst_style:
		"spark":
			return 0.42
		"smoke_ring":
			return 0.30
		"level_column":
			return 0.68
		_:
			return 0.56


func _circle_points(circle_radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segments: int = max(8, segments)
	for index in range(safe_segments):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / float(safe_segments)) * circle_radius)
	return points
