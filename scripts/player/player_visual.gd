extends Node2D

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")

@export var body_radius: float = 15.0
@export var body_color: Color = Color(0.35, 0.78, 1.0)
@export var core_color: Color = Color(0.88, 0.98, 1.0)
@export_file("*.png") var sprite_path: String = ""
@export var sprite_scale: float = 1.0

var sprite: Sprite2D = null


func _ready() -> void:
	_ensure_sprite()
	_apply_sprite()


func configure_visual(new_sprite_path: String, new_scale: float, new_radius: float) -> void:
	sprite_path = new_sprite_path
	sprite_scale = new_scale
	body_radius = new_radius
	_apply_sprite()


func _ensure_sprite() -> void:
	if sprite != null and is_instance_valid(sprite):
		return
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
	SPRITE_LOADER.fit_sprite(sprite, texture, body_radius * 3.1, sprite_scale)
