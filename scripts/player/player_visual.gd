extends Node2D

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")

@export var body_radius: float = 15.0
@export var body_color: Color = Color(0.35, 0.78, 1.0)
@export var core_color: Color = Color(0.88, 0.98, 1.0)
@export_file("*.png") var sprite_path: String = ""
@export var sprite_scale: float = 1.0

var sprite: Sprite2D = null
var shadow: Sprite2D = null
var aura: Sprite2D = null


func _ready() -> void:
	_ensure_sprite()
	_apply_sprite()
	set_process(true)


func _process(_delta: float) -> void:
	if shadow != null:
		shadow.global_rotation = 0.0


func configure_visual(new_sprite_path: String, new_scale: float, new_radius: float) -> void:
	sprite_path = new_sprite_path
	sprite_scale = new_scale
	body_radius = new_radius
	_apply_sprite()


func _ensure_sprite() -> void:
	if sprite != null and is_instance_valid(sprite):
		return
	shadow = get_node_or_null("Shadow") as Sprite2D
	if shadow == null:
		shadow = Sprite2D.new()
		shadow.name = "Shadow"
		add_child(shadow)
	shadow.texture = ART_RESOURCES.get_ellipse_shadow()
	shadow.centered = true
	shadow.z_index = -4
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.62)

	aura = get_node_or_null("Aura") as Sprite2D
	if aura == null:
		aura = Sprite2D.new()
		aura.name = "Aura"
		add_child(aura)
	aura.texture = ART_RESOURCES.get_radial_glow()
	aura.centered = true
	aura.material = ART_RESOURCES.get_additive_material()
	aura.z_index = -2

	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	sprite.centered = true
	sprite.z_index = 1


func _apply_sprite() -> void:
	_ensure_sprite()
	var texture: Texture2D = SPRITE_LOADER.get_texture(sprite_path)
	if texture == null:
		sprite.visible = false
		return
	sprite.visible = true
	SPRITE_LOADER.fit_sprite(sprite, texture, body_radius * 3.1, sprite_scale)
	if shadow != null:
		ART_RESOURCES.fit_sprite(shadow, ART_RESOURCES.get_ellipse_shadow(), body_radius * 3.2)
		shadow.position = Vector2(0.0, body_radius * 0.82)
	if aura != null:
		ART_RESOURCES.fit_sprite(aura, ART_RESOURCES.get_radial_glow(), body_radius * 5.2)
		aura.modulate = Color(body_color.r * 0.45 + 0.2, body_color.g * 0.72 + 0.25, 1.0, 0.38)
