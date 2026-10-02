extends Node2D

# Draw contact strokes instead of stretching the legacy bitmap across space.
const MAX_CONTACT_STREAK := 18.0
const MAX_LIFETIME := 0.12

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
	queue_redraw()


func pool_on_release() -> void:
	is_active = false
	visible = false
	set_process(false)
	points.clear()
	age = 0.0
	rotation = 0.0
	position = Vector2.ZERO
	scale = Vector2.ONE
	for segment in segments:
		if segment != null and is_instance_valid(segment):
			segment.visible = false
			segment.rotation = 0.0
			segment.texture = null
			segment.position = Vector2.ZERO
			segment.scale = Vector2.ONE
			segment.modulate = Color.TRANSPARENT
	queue_redraw()


func pool_reset(args: Dictionary) -> void:
	setup(
		args.get("points", []),
		args.get("color", Color(0.6, 0.9, 1.0)),
		float(args.get("lifetime", 0.22)),
		str(args.get("sprite_path", "res://assets/sprites/proj_lightning.png")),
		float(args.get("width", 24.0))
	)


func setup(world_points: Array[Vector2], color_value: Color, duration: float, new_sprite_path: String = "res://assets/sprites/proj_lightning.png", width_value: float = 24.0) -> void:
	points = world_points.duplicate()
	arc_color = color_value
	lifetime = clampf(duration, 0.08, MAX_LIFETIME)
	sprite_path = new_sprite_path
	arc_width = clamp(width_value, 8.0, 48.0)
	age = 0.0
	rotation = 0.0
	position = Vector2.ZERO
	scale = Vector2.ONE
	_sync_segments()
	queue_redraw()


func _process(delta: float) -> void:
	if not is_active:
		return
	age += delta
	if age >= lifetime:
		is_active = false
		EntityFactory.release_lightning_arc(self)
	else:
		queue_redraw()


func _sync_segments() -> void:
	# Clear previously pooled billboard geometry as well as hiding it. No new
	# segments are made: weapon damage has already resolved its hit snapshot.
	for segment in segments:
		if segment != null and is_instance_valid(segment):
			segment.visible = false
			segment.texture = null
			segment.position = Vector2.ZERO
			segment.rotation = 0.0
			segment.scale = Vector2.ONE
			segment.modulate = Color.TRANSPARENT


func _draw() -> void:
	if not is_active or points.size() < 2:
		return
	var alpha := pow(1.0 - clampf(age / lifetime, 0.0, 1.0), 1.8)
	var tint := arc_color.lerp(Color.WHITE, 0.84)
	tint.a = alpha * 0.86
	for index in range(1, points.size()):
		var incoming := points[index] - points[index - 1]
		if incoming.length_squared() < 0.01:
			continue
		var direction := incoming.normalized()
		var contact := to_local(points[index])
		var length := minf(MAX_CONTACT_STREAK, incoming.length())
		draw_line(contact - direction * length, contact, tint, 1.8, true)
		draw_circle(contact, 1.5, Color(1.0, 0.97, 0.82, alpha * 0.8))


func get_debug_state() -> Dictionary:
	var visible_segments := 0
	for segment in segments:
		if segment != null and is_instance_valid(segment) and segment.visible:
			visible_segments += 1
	return {"active": is_active, "points": points.size(), "legacy_segments_visible": visible_segments, "max_contact_streak": MAX_CONTACT_STREAK, "lifetime": lifetime, "age": age}
