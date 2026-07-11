class_name ArtResources
extends RefCounted

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")

const RADIAL_GLOW_PATH := "res://assets/art/radial_glow.png"
const ELLIPSE_SHADOW_PATH := "res://assets/art/ellipse_shadow.png"
const PARTICLE_CORE_PATH := "res://assets/art/particle_core.png"
const VIGNETTE_PATH := "res://assets/art/vignette.png"
const ICON_HEALTH_PATH := "res://assets/art/icon_health.png"
const ICON_XP_PATH := "res://assets/art/icon_xp.png"
const ICON_GOLD_PATH := "res://assets/art/icon_gold.png"

static var additive_material: CanvasItemMaterial = null


static func get_additive_material() -> CanvasItemMaterial:
	if additive_material == null:
		additive_material = CanvasItemMaterial.new()
		additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		additive_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return additive_material


static func get_radial_glow() -> Texture2D:
	return SPRITE_LOADER.get_texture(RADIAL_GLOW_PATH)


static func get_ellipse_shadow() -> Texture2D:
	return SPRITE_LOADER.get_texture(ELLIPSE_SHADOW_PATH)


static func get_particle_core() -> Texture2D:
	return SPRITE_LOADER.get_texture(PARTICLE_CORE_PATH)


static func get_vignette() -> Texture2D:
	return SPRITE_LOADER.get_texture(VIGNETTE_PATH)


static func get_health_icon() -> Texture2D:
	return SPRITE_LOADER.get_texture(ICON_HEALTH_PATH)


static func get_xp_icon() -> Texture2D:
	return SPRITE_LOADER.get_texture(ICON_XP_PATH)


static func get_gold_icon() -> Texture2D:
	return SPRITE_LOADER.get_texture(ICON_GOLD_PATH)


static func fit_sprite(sprite: Sprite2D, texture: Texture2D, target_diameter: float) -> void:
	if sprite == null or texture == null:
		return
	sprite.texture = texture
	sprite.centered = true
	var max_size: float = max(float(texture.get_width()), float(texture.get_height()))
	sprite.scale = Vector2.ONE if max_size <= 0.0 else Vector2.ONE * (target_diameter / max_size)
