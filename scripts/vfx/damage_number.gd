extends Node2D

static var visual_rng: RandomNumberGenerator = _create_visual_rng()
static var label_layout_updates: int = 0
static var process_updates: int = 0
static var alpha_updates: int = 0
static var scale_updates: int = 0

var text_value: String = "0"
var number_color: Color = Color.WHITE
var velocity: Vector2 = Vector2(0.0, -46.0)
var age: float = 0.0
var lifetime: float = 0.62
var font_size: int = 18
var is_active: bool = false
var numeric_total: float = 0.0
var has_numeric_value: bool = true
var pop_strength: float = 0.0
var applied_font_size: int = -1
var applied_label_size := Vector2.ZERO
var applied_alpha: float = 1.0
var pop_finished := false

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
	font_size = 18
	pop_strength = 0.0
	pop_finished = true
	applied_alpha = 1.0
	modulate = Color.WHITE
	scale = Vector2.ONE
	rotation = 0.0
	_set_labels_visible(false)


func setup(value: Variant, world_position: Vector2, color_value: Color) -> void:
	global_position = world_position
	number_color = color_value
	age = 0.0
	lifetime = 0.62
	rotation = 0.0
	velocity = Vector2(visual_rng.randf_range(-14.0, 14.0), -visual_rng.randf_range(34.0, 48.0))
	_set_value(value)
	pop_strength = 0.22 if font_size > 20 else 0.1
	pop_finished = false
	applied_alpha = 1.0
	modulate = Color.WHITE
	scale = Vector2.ONE * (1.0 + pop_strength)
	if not has_numeric_value:
		lifetime = 0.86
		velocity = Vector2(0.0, -34.0)
	_update_labels()


func pool_reset(args: Dictionary) -> void:
	var override_size := int(args.get("font_size", 0))
	font_size = override_size if override_size > 0 else 18
	setup(args.get("value", 0), args.get("position", Vector2.ZERO), args.get("color", Color.WHITE))
	_apply_label_font_size()


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
	pop_strength = 0.16
	pop_finished = false
	applied_alpha = 1.0
	modulate = Color.WHITE
	_update_labels()


func _process(delta: float) -> void:
	if not is_active:
		return
	process_updates += 1
	age += delta
	if not pop_finished:
		scale_updates += 1
		scale = Vector2.ONE * (1.0 + pop_strength * (1.0 - smoothstep(0.0, 0.13, age)))
		if age >= 0.13:
			pop_finished = true
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


static func _create_visual_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 432149
	return rng


func _ensure_labels() -> void:
	if is_instance_valid(value_label):
		return
	value_label = get_node_or_null("ValueLabel") as Label
	if value_label == null:
		value_label = Label.new()
		value_label.name = "ValueLabel"
		add_child(value_label)

	# One Label's native dark outline carries contrast. A second copied text
	# Label previously doubled layout/theme notifications for every merged hit.
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.z_index = 100
	value_label.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.045, 0.95))
	_apply_label_font_size()


func _apply_label_font_size() -> void:
	if value_label == null:
		return
	if applied_font_size != font_size:
		value_label.add_theme_font_size_override("font_size", font_size)
		value_label.add_theme_constant_override("outline_size", 3 if font_size > 20 else 2)
		applied_font_size = font_size
		label_layout_updates += 1
	var text_width := maxf(128.0, float(text_value.length()) * float(font_size) * 0.65)
	var label_size := Vector2(minf(420.0, text_width), 42.0) if font_size > 20 else Vector2(72.0, 28.0)
	if applied_label_size != label_size:
		value_label.size = label_size
		value_label.position = -label_size * 0.5
		applied_label_size = label_size
		label_layout_updates += 1


func _update_labels() -> void:
	_ensure_labels()
	if value_label.text != text_value:
		value_label.text = text_value
	value_label.modulate = Color(number_color.r, number_color.g, number_color.b, 1.0)
	_apply_label_font_size()


func _update_alpha() -> void:
	# Hold the readable value through the initial impact, then fade at the tail.
	var alpha: float = 1.0 - smoothstep(0.42, 1.0, clampf(age / lifetime, 0.0, 1.0))
	if absf(alpha - applied_alpha) > 0.001:
		applied_alpha = alpha
		alpha_updates += 1
		modulate = Color(1.0, 1.0, 1.0, alpha)


func _set_labels_visible(value: bool) -> void:
	if shadow_label != null:
		shadow_label.visible = value
	if value_label != null:
		value_label.visible = value


func get_render_debug_state() -> Dictionary:
	return {"label_nodes": 1 if is_instance_valid(value_label) else 0, "font_size": font_size, "alpha": applied_alpha, "pop_finished": pop_finished, "layout_updates": label_layout_updates, "process_updates": process_updates, "alpha_updates": alpha_updates, "scale_updates": scale_updates}
