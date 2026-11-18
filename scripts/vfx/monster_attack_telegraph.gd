extends Node2D

const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const REDRAW_INTERVAL := 1.0 / 30.0
const DANGER := Color("ff4569")
const ORDINARY := Color("e59468")
const INK := Color("321628")
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

func show_cue(next_kind: StringName, direction: Vector2, radius: float, is_feature: bool, _color: Color, damage_radius: float = 0.0) -> void:
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
	tint = DANGER if feature else ORDINARY
	z_index = 42 if feature else -3
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
		var boundary_width := clampf(reach * 0.05, 3.5, 8.0)
		draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48, INK, boundary_width + 3.0, true)
		draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48, stroke, boundary_width, true)
		if feature:
			draw_arc(Vector2.ZERO, reach * (0.62 + progress * 0.25), 0.0, TAU, 32, Color(tint, 0.19), 1.0, true)
		for ray in range(6):
			var axis := Vector2.RIGHT.rotated(float(ray) * TAU / 6.0)
			draw_line(axis * (reach - 10.0), axis * reach, Color(tint, 0.85), 3.0, true)
	else:
		draw_set_transform(Vector2.ZERO, cue_angle)
		var end := Vector2(cue_length, 0)
		match kind:
			&"dash":
				for offset in [24.0, 0.0]:
					var tip := end - Vector2(offset, 0)
					_stroke(PackedVector2Array([tip + Vector2(-17,-13), tip, tip + Vector2(-17,13)]), stroke)
			&"ranged":
				for x in [0.38, 0.60, 0.82]:
					var mid: Vector2 = end * x
					_stroke(PackedVector2Array([mid - Vector2(4,0), mid + Vector2(4,0)]), stroke)
				_stroke(PackedVector2Array([end+Vector2(-9,-6), end, end+Vector2(-9,6)]), stroke)
			_:
				draw_set_transform(Vector2.ZERO)
				draw_colored_polygon(cone, Color(tint, alpha))
				_stroke(PackedVector2Array([cone[1], Vector2.ZERO, cone[-1]]), stroke)
				draw_arc(Vector2.ZERO, cue_length, cue_angle - cue_half_angle, cue_angle + cue_half_angle, 16, stroke, 3.5, true)
		draw_set_transform(Vector2.ZERO)
	if feature:
		# All high-threat attacks carry the same ink-backed rose diamond. Keep it
		# beside the footprint so it cannot hide the projectile path or slam edge.
		var badge := Vector2(0, -reach+13) if kind == &"ring" else forward * (cue_length * 0.61) + forward.orthogonal()*14
		var diamond := PackedVector2Array([badge+Vector2.UP*11, badge+Vector2.RIGHT*11, badge+Vector2.DOWN*11, badge+Vector2.LEFT*11])
		draw_colored_polygon(diamond, INK)
		diamond.append(diamond[0])
		draw_polyline(diamond, DANGER, 3.4, true)

func _stroke(points: PackedVector2Array, color: Color) -> void:
	draw_polyline(points, INK, 8.0, true)
	draw_polyline(points, color, 4.5, true)

func get_debug_state() -> Dictionary:
	return {"active": active, "kind": str(kind), "age": age, "feature": feature, "reach": reach, "scale": scale, "position": position, "direction": forward, "direction_tip": forward * cue_length, "redraw_hz": 30, "redraw_requests": redraw_requests, "cached_cone_points": cone.size()}
