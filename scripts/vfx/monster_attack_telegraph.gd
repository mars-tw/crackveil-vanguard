extends Node2D

const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const REDRAW_INTERVAL := 1.0 / 30.0
var active := false
var feature := false
var kind: StringName = &"contact"
var forward := Vector2.RIGHT
var reach := 50.0
var age := 0.0
var tint := Color("ff865d")
var redraw_clock := 0.0
var cone := PackedVector2Array()
var arrow := PackedVector2Array()
var cue_angle := 0.0
var cue_half_angle := 0.70
var cue_length := 50.0
var redraw_requests := 0

func _ready() -> void:
	add_to_group("attack_telegraphs")
	z_index = -3
	visible = false
	set_process(false)
	scale = Vector2.ONE

func show_cue(next_kind: StringName, direction: Vector2, radius: float, is_feature: bool, color: Color, damage_radius: float = 0.0) -> void:
	var cap := 5 if MOBILE.mobile_lod_enabled(get_viewport_rect().size) else 10
	var live := 0
	for other in get_tree().get_nodes_in_group("attack_telegraphs"):
		if other != self and other.get("active") == true:
			live += 1
	if not is_feature and live >= cap:
		hide_cue()
		return
	active = true
	feature = is_feature
	kind = next_kind
	forward = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	# The shield slam keeps its exact circular world-space hit radius. Direction
	# arrows also stay in world space so vertical attacks never look compressed.
	reach = damage_radius if damage_radius > 0.0 else clampf(radius * 2.1, 42.0, 92.0)
	scale = Vector2.ONE
	tint = color.lightened(0.20) if is_feature else Color("ff865d")
	age = 0.0
	redraw_clock = 0.0
	_rebuild_direction_geometry()
	visible = true
	set_process(true)
	redraw_requests += 1
	queue_redraw()

func hide_cue() -> void:
	active = false
	visible = false
	age = 0.0
	redraw_clock = 0.0
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	redraw_clock += delta
	if redraw_clock < REDRAW_INTERVAL:
		return
	redraw_clock = fmod(redraw_clock, REDRAW_INTERVAL)
	redraw_requests += 1
	queue_redraw()

func _rebuild_direction_geometry() -> void:
	cone.clear()
	arrow.clear()
	if kind == &"ring":
		return
	cue_angle = forward.angle()
	cue_half_angle = 0.25 if kind in [&"dash", &"ranged"] else 0.70
	cue_length = 112.0 if kind == &"dash" else 86.0 if kind == &"ranged" else reach
	cone.append(Vector2.ZERO)
	for step in range(13):
		cone.append(Vector2.RIGHT.rotated(cue_angle - cue_half_angle + 2.0 * cue_half_angle * float(step) / 12.0) * cue_length)
	var tip := forward * cue_length
	var side := forward.orthogonal() * 6.0
	arrow.append(tip - forward * 11.0 - side)
	arrow.append(tip)
	arrow.append(tip - forward * 11.0 + side)

func _draw() -> void:
	if not active:
		return
	var progress := clampf(age / 0.50, 0.0, 1.0)
	var alpha := 0.07 + progress * 0.07
	var stroke := Color(tint, 0.72 + progress * 0.20)
	if kind == &"ring":
		draw_circle(Vector2.ZERO, reach, Color(tint, alpha))
		# The danger boundary stays fixed; only the faint inner cue advances.
		draw_arc(Vector2.ZERO, reach, 0.0, TAU, 40, Color(tint, 0.17), 7.0, true)
		draw_arc(Vector2.ZERO, reach, 0.0, TAU, 40, stroke, 2.5, true)
		if feature:
			draw_arc(Vector2.ZERO, reach * (0.62 + progress * 0.25), 0.0, TAU, 32, Color(tint, 0.19), 1.0, true)
		for ray in range(6):
			var axis := Vector2.RIGHT.rotated(float(ray) * TAU / 6.0)
			draw_line(axis * (reach - 10.0), axis * reach, Color(tint, 0.85), 3.0, true)
	else:
		draw_colored_polygon(cone, Color(tint, alpha))
		draw_arc(Vector2.ZERO, cue_length, cue_angle - cue_half_angle, cue_angle + cue_half_angle, 16, stroke, 2.0, true)
		draw_line(Vector2.ZERO, forward * (cue_length - 15.0), Color(tint, 0.30), 1.2, true)
		draw_polyline(arrow, stroke, 2.8, true)

func get_debug_state() -> Dictionary:
	return {"active": active, "kind": str(kind), "age": age, "feature": feature, "reach": reach, "scale": scale, "position": position, "direction": forward, "direction_tip": forward * cue_length, "redraw_hz": 30, "redraw_requests": redraw_requests, "cached_cone_points": cone.size()}
