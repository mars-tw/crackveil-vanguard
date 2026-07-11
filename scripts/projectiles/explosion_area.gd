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


func pool_reset(args: Dictionary) -> void:
	setup(args.get("position", Vector2.ZERO), args.get("stats", {}), args.get("source", null))


func setup(world_position: Vector2, effect_stats: Dictionary, effect_source: Node) -> void:
	global_position = world_position
	stats = effect_stats
	source = effect_source
	age = 0.0
	rotation = 0.0
	_apply_sprite()


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

	shockwave_sprite = get_node_or_null("ShockwaveSprite") as Sprite2D
	if shockwave_sprite == null:
		shockwave_sprite = Sprite2D.new()
		shockwave_sprite.name = "ShockwaveSprite"
		add_child(shockwave_sprite)
	shockwave_sprite.centered = true
	shockwave_sprite.material = ART_RESOURCES.get_additive_material()
	shockwave_sprite.z_index = -1

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
	if glow != null:
		glow.visible = true
	if shockwave_sprite != null:
		shockwave_sprite.texture = SPRITE_LOADER.get_texture(VFX_ROOT + "shockwave_" + suffix)
		shockwave_sprite.visible = shockwave_sprite.texture != null
	sprite.modulate = Color.WHITE
	_update_sprite_state()


func _update_sprite_state() -> void:
	if sprite == null:
		return
	var lifetime: float = max(0.001, float(stats.get("effect_lifetime", 0.32)))
	var t: float = clamp(age / lifetime, 0.0, 1.0)
	var radius: float = float(stats.get("area_radius", 82.0))
	var texture := sprite.texture
	if texture != null:
		var target_size := radius * (2.25 + t * 0.42)
		SPRITE_LOADER.fit_sprite(sprite, texture, target_size, float(stats.get("sprite_scale", 1.0)))
	var color: Color = stats.get("color", Color(1.0, 0.6, 0.25))
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0 - t)
	if shockwave_sprite != null and shockwave_sprite.texture != null:
		SPRITE_LOADER.fit_sprite(shockwave_sprite, shockwave_sprite.texture, radius * (2.05 + t * 1.15))
		shockwave_sprite.modulate = Color(1.0, 1.0, 1.0, (1.0 - t) * 0.74)
	if glow != null:
		ART_RESOURCES.fit_sprite(glow, ART_RESOURCES.get_radial_glow(), radius * (2.95 + t * 0.62))
		glow.modulate = Color(color.r, color.g, color.b, (1.0 - t) * 0.46)


func _uses_ember_palette() -> bool:
	var color: Color = stats.get("color", Color(1.0, 0.6, 0.25))
	return color.r > color.b * 1.08 and color.r > color.g * 0.94
