extends Node2D

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")

var sprite_path: String = ""
var ghost_color: Color = Color.WHITE
var body_radius: float = 13.0
var sprite_scale: float = 1.0
var age: float = 0.0
var lifetime: float = 0.34
var is_active: bool = false
var sprite: Sprite2D = null


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
	sprite_path = ""
	body_radius = 13.0
	sprite_scale = 1.0
	if sprite != null:
		sprite.visible = false
		sprite.rotation = 0.0
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE


func pool_reset(args: Dictionary) -> void:
	setup(
		args.get("position", Vector2.ZERO),
		str(args.get("sprite_path", "")),
		args.get("color", Color.WHITE),
		float(args.get("radius", 13.0)),
		float(args.get("sprite_scale", 1.0)),
		bool(args.get("flip_h", false)),
		float(args.get("rotation", 0.0))
	)


func setup(world_position: Vector2, path: String, color_value: Color, radius_value: float, scale_value: float, flip_h: bool, rotation_value: float) -> void:
	global_position = world_position
	sprite_path = path
	ghost_color = color_value
	body_radius = max(1.0, radius_value)
	sprite_scale = scale_value
	age = 0.0
	rotation = 0.0
	_ensure_sprite()
	sprite.flip_h = flip_h
	sprite.rotation = rotation_value
	_apply_sprite()


func _process(delta: float) -> void:
	if not is_active:
		return
	age += delta
	if age >= lifetime:
		is_active = false
		EntityFactory.release_corpse_ghost(self)
		return
	var t: float = clamp(age / lifetime, 0.0, 1.0)
	sprite.position = Vector2(0.0, lerpf(0.0, 5.0, t))
	sprite.modulate = Color(ghost_color.r, ghost_color.g, ghost_color.b, (1.0 - t) * 0.38)
	sprite.scale *= 1.0 + delta * 0.05


func _ensure_sprite() -> void:
	if sprite != null and is_instance_valid(sprite):
		return
	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	sprite.centered = true
	sprite.z_index = -1


func _apply_sprite() -> void:
	var texture := SPRITE_LOADER.get_texture(sprite_path)
	if texture == null:
		sprite.visible = false
		return
	sprite.visible = true
	SPRITE_LOADER.fit_sprite(sprite, texture, body_radius * 3.0, sprite_scale)
	sprite.modulate = Color(ghost_color.r, ghost_color.g, ghost_color.b, 0.38)
