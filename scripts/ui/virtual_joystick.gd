class_name CrackveilVirtualJoystick
extends Control

signal direction_changed(direction: Vector2)

@export var stick_radius: float = 58.0
@export var knob_radius: float = 22.0

var direction: Vector2 = Vector2.ZERO
var active_touch_index: int = -1
var mouse_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(156.0, 156.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed and active_touch_index == -1:
			active_touch_index = touch_event.index
			_update_direction(touch_event.position)
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
				_update_direction(mouse_button.position)
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


func _update_direction(local_position: Vector2) -> void:
	var center := size * 0.5
	var delta := local_position - center
	if delta.length() > stick_radius:
		delta = delta.normalized() * stick_radius
	direction = delta / stick_radius
	if direction.length_squared() < 0.012:
		direction = Vector2.ZERO
	direction_changed.emit(direction)
	queue_redraw()


func _reset_direction() -> void:
	active_touch_index = -1
	mouse_active = false
	direction = Vector2.ZERO
	direction_changed.emit(direction)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var base_color := Color(0.08, 0.12, 0.16, 0.46)
	var ring_color := Color(0.58, 0.82, 1.0, 0.62)
	var knob_color := Color(0.68, 0.92, 1.0, 0.82)
	draw_circle(center, stick_radius + 8.0, base_color)
	draw_arc(center, stick_radius, 0.0, TAU, 48, ring_color, 3.0)
	draw_circle(center + direction * stick_radius, knob_radius, knob_color)
	draw_circle(center + direction * stick_radius, knob_radius * 0.45, Color(1.0, 1.0, 1.0, 0.76))
