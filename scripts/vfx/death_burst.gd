extends Node2D

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")

var burst_color: Color = Color(1.0, 0.4, 0.4)
var age: float = 0.0
var lifetime: float = 0.32
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
	if sprite != null:
		sprite.visible = false
		sprite.rotation = 0.0


func pool_reset(args: Dictionary) -> void:
	setup(args.get("position", Vector2.ZERO), args.get("color", Color.WHITE))


func setup(world_position: Vector2, color_value: Color) -> void:
	global_position = world_position
	burst_color = color_value
	age = 0.0
	rotation = 0.0
	_apply_sprite()


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
	_update_sprite_state()


func _update_sprite_state() -> void:
	if sprite == null:
		return
	var t: float = clamp(age / lifetime, 0.0, 1.0)
	var texture := sprite.texture
	if texture != null:
		SPRITE_LOADER.fit_sprite(sprite, texture, 44.0 + 24.0 * t, 1.0)
	sprite.rotation += 1.8 * get_process_delta_time()
	sprite.modulate = Color(burst_color.r, burst_color.g, burst_color.b, 1.0 - t)
