extends Node2D

var text_value: String = "0"
var number_color: Color = Color.WHITE
var velocity: Vector2 = Vector2(0.0, -46.0)
var age: float = 0.0
var lifetime: float = 0.62
var font_size: int = 18
var is_active: bool = false
var numeric_total: float = 0.0
var has_numeric_value: bool = true

var shadow_label: Label = null
var value_label: Label = null


func _ready() -> void:
	_ensure_labels()


func pool_on_acquire() -> void:
	is_active = true
	visible = true
	set_process(true)
	_ensure_labels()
	_set_labels_visible(true)


func pool_on_release() -> void:
	is_active = false
	visible = false
	set_process(false)
	age = 0.0
	text_value = "0"
	numeric_total = 0.0
	has_numeric_value = true
	rotation = 0.0
	_set_labels_visible(false)


func pool_reset(args: Dictionary) -> void:
	setup(args.get("value", 0), args.get("position", Vector2.ZERO), args.get("color", Color.WHITE))


func setup(value: Variant, world_position: Vector2, color_value: Color) -> void:
	global_position = world_position
	number_color = color_value
	age = 0.0
	lifetime = 0.62
	rotation = 0.0
	velocity = Vector2(randf_range(-14.0, 14.0), -randf_range(34.0, 48.0))
	_set_value(value)
	_update_labels()


func can_merge(world_position: Vector2, merge_radius: float, max_age: float) -> bool:
	return is_active and has_numeric_value and age <= max_age and global_position.distance_squared_to(world_position) <= merge_radius * merge_radius


func merge_value(value: Variant, world_position: Vector2, color_value: Color) -> void:
	if not has_numeric_value:
		return
	numeric_total += float(value)
	text_value = str(int(round(numeric_total)))
	number_color = color_value
	global_position = global_position.lerp(world_position, 0.35)
	age = min(age, 0.08)
	lifetime = 0.68
	velocity = velocity.lerp(Vector2(0.0, -48.0), 0.5)
	_update_labels()


func _process(delta: float) -> void:
	if not is_active:
		return
	age += delta
	global_position += velocity * delta
	velocity = velocity.move_toward(Vector2(0.0, -18.0), 90.0 * delta)
	if age >= lifetime:
		is_active = false
		EntityFactory.release_damage_number(self)
	else:
		_update_alpha()


func _set_value(value: Variant) -> void:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		has_numeric_value = true
		numeric_total = float(value)
		text_value = str(int(round(numeric_total)))
	else:
		has_numeric_value = false
		numeric_total = 0.0
		text_value = str(value)


func _ensure_labels() -> void:
	shadow_label = get_node_or_null("ShadowLabel") as Label
	if shadow_label == null:
		shadow_label = Label.new()
		shadow_label.name = "ShadowLabel"
		add_child(shadow_label)

	value_label = get_node_or_null("ValueLabel") as Label
	if value_label == null:
		value_label = Label.new()
		value_label.name = "ValueLabel"
		add_child(value_label)

	for label in [shadow_label, value_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(72.0, 24.0)
		label.position = Vector2(-36.0, -12.0)
		label.add_theme_font_size_override("font_size", font_size)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 100

	shadow_label.position += Vector2(1.0, 1.0)


func _update_labels() -> void:
	_ensure_labels()
	shadow_label.text = text_value
	value_label.text = text_value
	shadow_label.modulate = Color(0.02, 0.02, 0.025, 1.0)
	value_label.modulate = number_color


func _update_alpha() -> void:
	var alpha: float = 1.0 - clamp(age / lifetime, 0.0, 1.0)
	if shadow_label != null:
		shadow_label.modulate = Color(0.02, 0.02, 0.025, alpha)
	if value_label != null:
		value_label.modulate = Color(number_color.r, number_color.g, number_color.b, alpha)


func _set_labels_visible(value: bool) -> void:
	if shadow_label != null:
		shadow_label.visible = value
	if value_label != null:
		value_label.visible = value
