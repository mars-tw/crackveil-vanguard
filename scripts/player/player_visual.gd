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
var facing_direction: Vector2 = Vector2.RIGHT
var walk_phase: float = 0.0
var idle_phase: float = 0.0
var hit_squash_timer: float = 0.0
var sprite_base_scale: Vector2 = Vector2.ONE
var shadow_base_scale: Vector2 = Vector2.ONE
var aura_base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_ensure_sprite()
	_apply_sprite()
	set_process(true)


func _process(delta: float) -> void:
	if shadow != null:
		shadow.global_rotation = 0.0
	_update_procedural_motion(delta)


func configure_visual(new_sprite_path: String, new_scale: float, new_radius: float) -> void:
	sprite_path = new_sprite_path
	sprite_scale = new_scale
	body_radius = new_radius
	_apply_sprite()


func set_facing_direction(direction: Vector2) -> void:
	if direction.length_squared() > 0.001:
		facing_direction = direction.normalized()


func trigger_hit_squash() -> void:
	hit_squash_timer = 0.12


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
	sprite_base_scale = sprite.scale
	if shadow != null:
		ART_RESOURCES.fit_sprite(shadow, ART_RESOURCES.get_ellipse_shadow(), body_radius * 3.2)
		shadow_base_scale = shadow.scale
		shadow.position = Vector2(0.0, body_radius * 0.82)
	if aura != null:
		ART_RESOURCES.fit_sprite(aura, ART_RESOURCES.get_radial_glow(), body_radius * 5.2)
		aura_base_scale = aura.scale
		aura.modulate = Color(body_color.r * 0.45 + 0.2, body_color.g * 0.72 + 0.25, 1.0, 0.38)


func _update_procedural_motion(delta: float) -> void:
	if sprite == null:
		return
	var motion := _current_motion_velocity()
	var moving := motion.length_squared() > 9.0
	idle_phase += delta * 2.4
	if moving:
		walk_phase += delta * 8.4
	else:
		walk_phase += delta * 3.0
	if hit_squash_timer > 0.0:
		hit_squash_timer = max(hit_squash_timer - delta, 0.0)

	var bob := sin(walk_phase) * (3.6 if moving else 0.7)
	var breath := 1.0 + sin(idle_phase) * (0.012 if moving else 0.026)
	var squash := hit_squash_timer / 0.12 if hit_squash_timer > 0.0 else 0.0
	var squash_x := 1.0 + squash * 0.16
	var squash_y := 1.0 - squash * 0.12
	var tilt := 0.0
	if moving:
		var direction := motion.normalized()
		set_facing_direction(direction)
		tilt = clamp(direction.x, -1.0, 1.0) * 0.11
	if abs(facing_direction.x) > 0.05:
		sprite.flip_h = facing_direction.x < 0.0

	sprite.position = Vector2(0.0, bob)
	sprite.rotation = tilt
	sprite.scale = Vector2(sprite_base_scale.x * breath * squash_x, sprite_base_scale.y * breath * squash_y)
	if shadow != null:
		shadow.scale = shadow_base_scale * (1.0 - abs(bob) * 0.012)
	if aura != null:
		aura.scale = aura_base_scale * (1.0 + sin(idle_phase + 0.4) * 0.018)


func _current_motion_velocity() -> Vector2:
	var parent := get_parent()
	if parent == null:
		return Vector2.ZERO
	var desired_value: Variant = parent.get("desired_velocity")
	if desired_value is Vector2:
		return desired_value
	var velocity_value: Variant = parent.get("velocity")
	if velocity_value is Vector2:
		return velocity_value
	return Vector2.ZERO
