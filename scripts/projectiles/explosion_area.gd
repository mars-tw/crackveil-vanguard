extends Node2D

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")
const VFX_ROOT := "res://assets/vfx/kenney_particle/"

var stats: Dictionary = {}
var source: Node = null
var age: float = 0.0
var is_active: bool = false
var sprite: Sprite2D = null
var glow: Sprite2D = null
var shockwave_sprite: Sprite2D = null
var core_flash: Sprite2D = null
var smoke_sprite: Sprite2D = null
var debris_particles: CPUParticles2D = null


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
	stats = {}
	source = null
	age = 0.0
	rotation = 0.0
	if sprite != null:
		sprite.visible = false
		sprite.rotation = 0.0
	if glow != null:
		glow.visible = false
	if shockwave_sprite != null:
		shockwave_sprite.visible = false
	if core_flash != null:
		core_flash.visible = false
	if smoke_sprite != null:
		smoke_sprite.visible = false
	if debris_particles != null:
		debris_particles.emitting = false


func pool_reset(args: Dictionary) -> void:
	setup(args.get("position", Vector2.ZERO), args.get("stats", {}), args.get("source", null))


func setup(world_position: Vector2, effect_stats: Dictionary, effect_source: Node) -> void:
	global_position = world_position
	stats = effect_stats
	source = effect_source
	age = 0.0
	rotation = 0.0
	_apply_sprite()
	_emit_debris()


func _process(delta: float) -> void:
	if not is_active:
		return
	age += delta
	if age >= float(stats.get("effect_lifetime", 0.32)):
		is_active = false
		EntityFactory.release_explosion(self)
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

	core_flash = get_node_or_null("CoreFlash") as Sprite2D
	if core_flash == null:
		core_flash = Sprite2D.new()
		core_flash.name = "CoreFlash"
		add_child(core_flash)
	core_flash.texture = ART_RESOURCES.get_radial_glow()
	core_flash.centered = true
	core_flash.material = ART_RESOURCES.get_additive_material()
	core_flash.z_index = 4

	shockwave_sprite = get_node_or_null("ShockwaveSprite") as Sprite2D
	if shockwave_sprite == null:
		shockwave_sprite = Sprite2D.new()
		shockwave_sprite.name = "ShockwaveSprite"
		add_child(shockwave_sprite)
	shockwave_sprite.centered = true
	shockwave_sprite.material = ART_RESOURCES.get_additive_material()
	shockwave_sprite.z_index = -1

	smoke_sprite = get_node_or_null("Smoke") as Sprite2D
	if smoke_sprite == null:
		smoke_sprite = Sprite2D.new()
		smoke_sprite.name = "Smoke"
		add_child(smoke_sprite)
	smoke_sprite.centered = true
	smoke_sprite.z_index = 2

	debris_particles = get_node_or_null("Debris") as CPUParticles2D
	if debris_particles == null:
		debris_particles = CPUParticles2D.new()
		debris_particles.name = "Debris"
		add_child(debris_particles)
	debris_particles.one_shot = true
	debris_particles.explosiveness = 0.94
	debris_particles.randomness = 0.46
	debris_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	debris_particles.direction = Vector2.RIGHT
	debris_particles.spread = 180.0
	debris_particles.gravity = Vector2(0.0, 90.0)
	debris_particles.z_index = 3

	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	sprite.centered = true


func _apply_sprite() -> void:
	_ensure_sprite()
	var suffix := "ember.png" if _uses_ember_palette() else "cyan.png"
	var texture_path := str(stats.get("explosion_sprite_path", VFX_ROOT + "burst_fire_" + suffix))
	if texture_path == "" or texture_path.ends_with("fx_explosion.png"):
		texture_path = VFX_ROOT + "burst_fire_" + suffix
	var texture: Texture2D = SPRITE_LOADER.get_texture(texture_path)
	if texture == null:
		sprite.visible = false
		return
	sprite.visible = true
	var layer_count := int(stats.get("composite_layers", 4))
	if glow != null:
		glow.visible = layer_count >= 3
	if core_flash != null:
		core_flash.visible = layer_count >= 3
	if shockwave_sprite != null:
		shockwave_sprite.texture = SPRITE_LOADER.get_texture(VFX_ROOT + "shockwave_" + suffix)
		shockwave_sprite.visible = shockwave_sprite.texture != null
	if smoke_sprite != null:
		smoke_sprite.texture = SPRITE_LOADER.get_texture(VFX_ROOT + "smoke_ring_" + suffix)
		smoke_sprite.visible = layer_count >= 3 and smoke_sprite.texture != null
	sprite.modulate = Color.WHITE
	_update_sprite_state()


func _update_sprite_state() -> void:
	if sprite == null:
		return
	var lifetime: float = max(0.001, float(stats.get("effect_lifetime", 0.32)))
	var t: float = clamp(age / lifetime, 0.0, 1.0)
	var radius: float = float(stats.get("area_radius", 82.0))
	var upgrade_scale: float = 1.0 + min(8, int(stats.get("visual_level", 0))) * 0.055 + (0.24 if bool(stats.get("evolved_visual", false)) else 0.0)
	radius *= upgrade_scale
	var texture := sprite.texture
	if texture != null:
		var target_size := radius * (2.25 + t * 0.42)
		SPRITE_LOADER.fit_sprite(sprite, texture, target_size, float(stats.get("sprite_scale", 1.0)))
	var color: Color = stats.get("color", Color(1.0, 0.6, 0.25))
	var burst_alpha := 1.0 - smoothstep(0.28, 1.0, t)
	sprite.modulate = Color(1.0, 1.0, 1.0, burst_alpha)
	sprite.rotation = t * 0.32
	if shockwave_sprite != null and shockwave_sprite.texture != null:
		var ring_t: float = clamp(t / 0.82, 0.0, 1.0)
		SPRITE_LOADER.fit_sprite(shockwave_sprite, shockwave_sprite.texture, radius * lerpf(1.2, 3.65, ring_t))
		shockwave_sprite.modulate = Color(1.0, 1.0, 1.0, (1.0 - ring_t) * 0.82)
	if glow != null and glow.visible:
		ART_RESOURCES.fit_sprite(glow, ART_RESOURCES.get_radial_glow(), radius * (3.15 + t * 0.7))
		glow.modulate = Color(color.r, color.g, color.b, (1.0 - t) * 0.5)
	if core_flash != null and core_flash.visible:
		var flash_t: float = clamp(t / 0.24, 0.0, 1.0)
		ART_RESOURCES.fit_sprite(core_flash, ART_RESOURCES.get_radial_glow(), radius * lerpf(1.15, 2.4, flash_t))
		core_flash.modulate = Color(1.0, 0.97, 0.82, (1.0 - flash_t) * 0.96)
	if smoke_sprite != null and smoke_sprite.visible and smoke_sprite.texture != null:
		var smoke_t: float = clamp((t - 0.18) / 0.82, 0.0, 1.0)
		SPRITE_LOADER.fit_sprite(smoke_sprite, smoke_sprite.texture, radius * lerpf(1.35, 3.05, smoke_t))
		smoke_sprite.rotation = -0.16 + smoke_t * 0.3
		smoke_sprite.modulate = Color(0.52, 0.46, 0.5, sin(smoke_t * PI) * 0.44)


func _emit_debris() -> void:
	if debris_particles == null or int(stats.get("composite_layers", 4)) < 4:
		return
	var radius: float = float(stats.get("area_radius", 82.0))
	var particle_multiplier: float = float(stats.get("particle_multiplier", 1.0))
	debris_particles.texture = SPRITE_LOADER.get_texture(VFX_ROOT + ("burst_arc_ember.png" if _uses_ember_palette() else "burst_arc_cyan.png"))
	debris_particles.amount = max(4, int(round(clamp(radius / 5.5, 12.0, 30.0) * particle_multiplier)))
	debris_particles.lifetime = max(0.28, float(stats.get("effect_lifetime", 0.32)) * 1.18)
	debris_particles.emission_sphere_radius = radius * 0.12
	debris_particles.initial_velocity_min = radius * 1.3
	debris_particles.initial_velocity_max = radius * 2.8
	debris_particles.scale_amount_min = 0.08
	debris_particles.scale_amount_max = 0.24
	debris_particles.color = Color(1.0, 1.0, 1.0, 0.88)
	debris_particles.restart()
	debris_particles.emitting = true


func _uses_ember_palette() -> bool:
	var color: Color = stats.get("color", Color(1.0, 0.6, 0.25))
	return color.r > color.b * 1.08 and color.r > color.g * 0.94
