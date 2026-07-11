extends Control

var cooldown_ratio: float = 0.0
var ring_width: float = 6.0
var ready_color: Color = Color(0.5, 1.0, 0.82, 0.86)
var cooldown_color: Color = Color(0.22, 0.88, 1.0, 0.9)
var track_color: Color = Color(0.04, 0.08, 0.11, 0.68)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_cooldown_ratio(value: float) -> void:
	cooldown_ratio = clamp(value, 0.0, 1.0)
	queue_redraw()


func set_ring_width(value: float) -> void:
	ring_width = max(2.0, value)
	queue_redraw()


func _draw() -> void:
	var diameter: float = min(size.x, size.y)
	if diameter <= 2.0:
		return
	var center := size * 0.5
	var radius := diameter * 0.5 - ring_width * 0.5 - 2.0
	draw_arc(center, radius, 0.0, TAU, 64, track_color, ring_width, true)
	if cooldown_ratio > 0.01:
		var end_angle := -PI * 0.5 + TAU * cooldown_ratio
		draw_arc(center, radius, -PI * 0.5, end_angle, 64, cooldown_color, ring_width, true)
	else:
		draw_arc(center, radius, 0.0, TAU, 64, ready_color, ring_width, true)
