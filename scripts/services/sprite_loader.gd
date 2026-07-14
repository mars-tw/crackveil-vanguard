class_name SpriteLoader
extends RefCounted

static var texture_cache: Dictionary = {}

const GAMEPLAY_PREWARM_PATHS: Array[String] = [
	"res://assets/sprites/enemy_grunt.png",
	"res://assets/sprites/enemy_fast.png",
	"res://assets/sprites/enemy_tank.png",
	"res://assets/sprites/hero_captain.png",
	"res://assets/sprites/hero_rift_sniper.png",
	"res://assets/sprites/hero_void_weaver.png",
	"res://assets/sprites/hero_arc_scout.png",
	"res://assets/sprites/hero_echo_singer.png",
	"res://assets/sprites/hero_ember_grenadier.png",
	"res://assets/sprites/hero_line_mender.png",
	"res://assets/sprites/hero_orbit_guard.png",
	"res://assets/sprites/hero_pulse_artificer.png",
	"res://assets/sprites/hero_shepherd.png",
	"res://assets/sprites/true_character_atlas.png",
	"res://assets/sprites/proj_bullet.png",
	"res://assets/sprites/proj_blade.png",
	"res://assets/sprites/proj_lightning.png",
	"res://assets/sprites/gem_xp.png",
	"res://assets/sprites/coin.png",
	"res://assets/art/radial_glow.png",
	"res://assets/art/ellipse_shadow.png",
	"res://assets/art/particle_core.png",
	"res://assets/vfx/kenney_particle/burst_fire_cyan.png",
	"res://assets/vfx/kenney_particle/burst_fire_ember.png",
	"res://assets/vfx/kenney_particle/burst_arc_cyan.png",
	"res://assets/vfx/kenney_particle/burst_arc_ember.png",
	"res://assets/vfx/kenney_particle/smoke_ring_cyan.png",
	"res://assets/vfx/kenney_particle/smoke_ring_ember.png",
	"res://assets/vfx/kenney_particle/flare_cyan.png",
	"res://assets/vfx/kenney_particle/flare_ember.png",
	"res://assets/vfx/kenney_particle/level_column_cyan.png",
	"res://assets/vfx/kenney_particle/level_column_ember.png",
	"res://assets/vfx/kenney_particle/shockwave_cyan.png",
	"res://assets/vfx/kenney_particle/shockwave_ember.png"
]


static func get_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if texture_cache.has(path):
		return texture_cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var resource := load(path)
		texture = resource as Texture2D
	else:
		var image := Image.new()
		var error := image.load(path)
		if error == OK:
			texture = ImageTexture.create_from_image(image)

	if texture == null:
		push_warning("Sprite not found or not loadable: %s" % path)
		return null

	texture_cache[path] = texture
	return texture


static func prewarm_gameplay_textures() -> int:
	var loaded_count := 0
	for path in GAMEPLAY_PREWARM_PATHS:
		if get_texture(path) != null:
			loaded_count += 1
	return loaded_count


static func fit_sprite(sprite: Sprite2D, texture: Texture2D, target_diameter: float, scale_multiplier: float = 1.0) -> void:
	if sprite == null or texture == null:
		return
	sprite.texture = texture
	sprite.centered = true
	var max_size: float = max(float(texture.get_width()), float(texture.get_height()))
	if max_size <= 0.0:
		sprite.scale = Vector2.ONE
	else:
		var scale_value: float = target_diameter / max_size * scale_multiplier
		sprite.scale = Vector2.ONE * scale_value
