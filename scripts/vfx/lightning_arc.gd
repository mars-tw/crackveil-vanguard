extends Node2D

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")

var points: Array[Vector2] = []
var arc_color: Color = Color(0.6, 0.9, 1.0)
var age: float = 0.0
var lifetime: float = 0.22
var sprite_path: String = "res://assets/sprites/proj_lightning.png"
var arc_width: float = 24.0
var is_active: bool = false
var segments: Array[Sprite2D] = []


func pool_on_acquire() -> void:
	is_active = true
	visible = true
	set_process(true)


func pool_on_release() -> void:
	is_active = false
	visible = false
	set_process(false)
	points.clear()
	age = 0.0
	rotation = 0.0
	for segment in segments:
		if segment != null and is_instance_valid(segment):
			segment.visible = false
			segment.rotation = 0.0


func pool_reset(args: Dictionary) -> void:
	setup(
		args.get("points", []),
		args.get("color", Color(0.6, 0.9, 1.0)),
		float(args.get("lifetime", 0.22)),
		str(args.get("sprite_path", "res://assets/sprites/proj_lightning.png"))
	)


func setup(world_points: Array[Vector2], color_value: Color, duration: float, new_sprite_path: String = "res://assets/sprites/proj_lightning.png") -> void:
	points = world_points.duplicate()
	arc_color = color_value
	lifetime = max(0.05, duration)
	sprite_path = new_sprite_path
	arc_width = 24.0
	age = 0.0
	rotation = 0.0
	_sync_segments()
	_update_segment_alpha()


func _process(delta: float) -> void:
	if not is_active:
		return
	age += delta
	if age >= lifetime:
		is_active = false
		EntityFactory.release_lightning_arc(self)
	else:
		_update_segment_alpha()


func _sync_segments() -> void:
	var segment_count: int = max(0, points.size() - 1)
	while segments.size() < segment_count:
		var segment := Sprite2D.new()
		segment.name = "LightningSegment"
		segment.centered = true
		add_child(segment)
		segments.append(segment)

	var texture: Texture2D = SPRITE_LOADER.get_texture(sprite_path)
	for index in range(segments.size()):
		var segment: Sprite2D = segments[index]
		if index >= segment_count or texture == null:
			segment.visible = false
			continue

		var start: Vector2 = points[index]
		var finish: Vector2 = points[index + 1]
		var segment_delta: Vector2 = finish - start
		var length: float = max(1.0, segment_delta.length())
		segment.visible = true
		segment.texture = texture
		segment.global_position = (start + finish) * 0.5
		segment.rotation = segment_delta.angle()
		var texture_width: float = max(1.0, float(texture.get_width()))
		var texture_height: float = max(1.0, float(texture.get_height()))
		segment.scale = Vector2(length / texture_width, arc_width / texture_height)


func _update_segment_alpha() -> void:
	var alpha: float = 1.0 - clamp(age / lifetime, 0.0, 1.0)
	for segment in segments:
		if segment != null and is_instance_valid(segment) and segment.visible:
			segment.modulate = Color(arc_color.r, arc_color.g, arc_color.b, alpha)
