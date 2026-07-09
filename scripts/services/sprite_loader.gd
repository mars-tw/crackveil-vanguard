class_name SpriteLoader
extends RefCounted

static var texture_cache: Dictionary = {}


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
