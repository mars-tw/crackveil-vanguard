class_name CrackveilVirtualJoystick
extends Control

signal direction_changed(direction: Vector2)

@export var stick_radius: float = 86.0
@export var knob_radius: float = 26.0
@export var heat_zone_multiplier: float = 1.24
@export var dead_zone: float = 0.045

var direction: Vector2 = Vector2.ZERO
var active_touch_index: int = -1
var mouse_active: bool = false
var dynamic_center: Vector2 = Vector2.ZERO
var center_active: bool = false
var feedback_scale: float = 1.0
var feedback_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_radius(stick_radius)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed and active_touch_index == -1:
			active_touch_index = touch_event.index
			center_active = true
			dynamic_center = _clamped_center(touch_event.position)
			_update_direction(touch_event.position)
			_animate_feedback(0.92)
			accept_event()
		elif not touch_event.pressed and touch_event.index == active_touch_index:
			_reset_direction()
			accept_event()
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if drag_event.index == active_touch_index:
			_update_direction(drag_event.position)
			accept_event()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			mouse_active = mouse_button.pressed
			if mouse_active:
				center_active = true
				dynamic_center = _clamped_center(mouse_button.position)
				_update_direction(mouse_button.position)
				_animate_feedback(0.92)
			else:
				_reset_direction()
			accept_event()
	elif event is InputEventMouseMotion and mouse_active:
		var motion := event as InputEventMouseMotion
		_update_direction(motion.position)
		accept_event()


func get_direction() -> Vector2:
	return direction


func force_direction_for_test(new_direction: Vector2) -> void:
	direction = new_direction.limit_length(1.0)
	direction_changed.emit(direction)
	queue_redraw()


func configure_for_viewport(viewport_size: Vector2, mobile: bool, size_index: int = 1, tablet: bool = false) -> Vector2:
	var safe_size: Vector2 = viewport_size
	if safe_size.x <= 0.0 or safe_size.y <= 0.0:
		safe_size = Vector2(390.0, 844.0)
	var portrait: bool = safe_size.y > safe_size.x
	var clamped_index: int = clamp(size_index, 0, 2)
	var radius: float = 66.0
	if mobile:
		var portrait_ratios: Array[float] = [0.20, 0.24, 0.27]
		var landscape_ratios: Array[float] = [0.17, 0.20, 0.22]
		var base_axis: float = safe_size.x if portrait else min(safe_size.x, safe_size.y)
		var ratio: float = float(portrait_ratios[clamped_index] if portrait else landscape_ratios[clamped_index])
		radius = max(70.0 if portrait else 64.0, base_axis * ratio)
	elif tablet:
		var tablet_radii := [74.0, 86.0, 98.0] if portrait else [70.0, 82.0, 94.0]
		radius = tablet_radii[clamped_index]
	else:
		var desktop_radii: Array[float] = [58.0, 66.0, 76.0]
		radius = desktop_radii[clamped_index]
	_apply_radius(radius)
	return custom_minimum_size


func _update_direction(local_position: Vector2) -> void:
	var center: Vector2 = dynamic_center if center_active else _default_center()
	var delta: Vector2 = local_position - center
	if delta.length() > stick_radius:
		delta = delta.normalized() * stick_radius
	var raw_direction: Vector2 = delta / max(1.0, stick_radius)
	var magnitude: float = raw_direction.length()
	if magnitude < dead_zone:
		direction = Vector2.ZERO
	elif magnitude > 0.001:
		direction = raw_direction.normalized() * min(1.0, pow(magnitude, 0.9))
	else:
		direction = Vector2.ZERO
	direction_changed.emit(direction)
	queue_redraw()


func _reset_direction() -> void:
	active_touch_index = -1
	mouse_active = false
	center_active = false
	dynamic_center = _default_center()
	direction = Vector2.ZERO
	direction_changed.emit(direction)
	_animate_feedback(1.0)
	queue_redraw()


func _draw() -> void:
	var center := dynamic_center if center_active else _default_center()
	var radius := stick_radius * feedback_scale
	var base_color := Color(0.025, 0.075, 0.12, 0.5 if center_active else 0.4)
	var ring_color := Color(0.42, 0.86, 1.0, 0.76 if center_active else 0.56)
	var knob_color := Color(0.46, 0.9, 1.0, 0.9)
	# 疊兩層半透明圓與偏心亮斑，做出不靠 shader 的低成本玻璃感。
	draw_circle(center, radius + 10.0, Color(0.0, 0.02, 0.06, 0.26))
	draw_circle(center, radius + 6.0, base_color)
	draw_arc(center, radius, 0.0, TAU, 48, ring_color, 3.0)
	draw_arc(center, radius - 7.0, -2.75, -0.35, 32, Color(0.82, 0.98, 1.0, 0.24), 2.0)
	var knob_center := center + direction * radius
	draw_circle(knob_center, knob_radius + 4.0, Color(0.0, 0.04, 0.08, 0.42))
	draw_circle(knob_center, knob_radius, knob_color)
	draw_circle(knob_center - Vector2(knob_radius * 0.2, knob_radius * 0.24), knob_radius * 0.42, Color(1.0, 1.0, 1.0, 0.66))


func _animate_feedback(target_scale: float) -> void:
	if feedback_tween != null and feedback_tween.is_valid():
		feedback_tween.kill()
	feedback_tween = create_tween()
	feedback_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	feedback_tween.tween_method(_set_feedback_scale, feedback_scale, target_scale, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_feedback_scale(value: float) -> void:
	feedback_scale = value
	queue_redraw()


func _apply_radius(radius: float) -> void:
	stick_radius = max(32.0, radius)
	knob_radius = max(22.0, stick_radius * 0.3)
	var heat_radius: float = stick_radius * max(1.0, heat_zone_multiplier)
	custom_minimum_size = Vector2.ONE * heat_radius * 2.0
	if not center_active:
		dynamic_center = _default_center()
	queue_redraw()


func _default_center() -> Vector2:
	var basis := size if size.x > 0.0 and size.y > 0.0 else custom_minimum_size
	return basis * 0.5


func _clamped_center(local_position: Vector2) -> Vector2:
	var basis := size if size.x > 0.0 and size.y > 0.0 else custom_minimum_size
	var margin := stick_radius + 8.0
	if basis.x <= margin * 2.0 or basis.y <= margin * 2.0:
		return basis * 0.5
	return Vector2(
		clamp(local_position.x, margin, basis.x - margin),
		clamp(local_position.y, margin, basis.y - margin)
	)
