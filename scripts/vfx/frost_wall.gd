extends Node2D

# R35: fifth-stage elites (星霜聖域) push a frost wall at the squad. The wall
# starts START_AHEAD in front of the captain and sweeps back through the squad
# at SPEED; a GAP-wide opening sits at a random offset along it. Each hero the
# wall crosses outside the opening is frozen: FREEZE_DAMAGE and a slow. The
# answer is to line the captain up with the opening and hold a tight ring:
# six ring members fit through (inner ring 96 to each side), wedge and scatter
# reach 148 / 236 to the sides and lose members to the ice. The garden asked
# the squad to spread, the forge to gather, the storm to stretch between two
# points, the frost to squeeze through one.
const START_AHEAD := 360.0
const PASS_BEHIND := 280.0
const SPEED := 160.0
const HALF_LENGTH := 460.0
const GAP := 260.0
const GAP_OFFSET_MAX := 120.0
const THICKNESS := 40.0
const FREEZE_DAMAGE := 12.0
const FREEZE_SLOW_SECONDS := 1.6
const FREEZE_SLOW := 0.6
const MAX_ACTIVE := 1
# R36: the pass verdict stays 2 s so the squad can read it.
const MARK_SECONDS := 2.0
const ICE := Color("cfefff")
const HAZARD := Color("7fd4ff")
const SAFE := Color("8ff0a4")
const LABEL := "霜牆穿縫・圓陣對準缺口"
const FONT := preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
const VINE_SNARE := preload("res://scripts/vfx/vine_snare.gd")
static var last_spawned: Node2D = null
static var last_mark_time := -99.0
# R36: game time of the last finished pass (QA capture hook for the verdict).
static var last_verdict_time := -99.0

var forward := Vector2.RIGHT
var travel := 0.0
var gap_offset := 0.0
var crossed := {}
var frozen: Array = []
var hits := 0
var done := false
var done_age := 0.0
var mark_layer: Node2D = null

static func spawn(parent: Node, captain: Node2D, offset_seed: float) -> Node2D:
	if not is_instance_valid(captain) or parent.get_tree() == null:
		return null
	if parent.get_tree().get_nodes_in_group("frost_walls").size() >= MAX_ACTIVE:
		return null
	# Not cast while the captain holds an open seal: one question at a time.
	if VINE_SNARE.off_seal(captain.global_position, 60.0) != captain.global_position:
		return null
	var wall: Node2D = load("res://scripts/vfx/frost_wall.gd").new()
	var facing := Vector2.RIGHT
	if captain.has_method("get_locomotion_facing_direction"):
		facing = captain.get_locomotion_facing_direction()
	wall.forward = facing.normalized() if facing.length() > 0.01 else Vector2.RIGHT
	wall.gap_offset = clampf(offset_seed, -1.0, 1.0) * GAP_OFFSET_MAX
	wall.global_position = captain.global_position + wall.forward * START_AHEAD
	wall.rotation = 0.0
	# R37: below the seal (z 1) so seal labels stay on top of the ice.
	wall.z_index = 0
	wall.add_to_group("frost_walls")
	parent.add_child(wall)
	last_spawned = wall
	return wall

# A hero at lateral offset `lateral` (from the wall centre) slips through when
# its whole body is inside the opening.
static func in_gap(lateral: float, gap_offset_value: float) -> bool:
	return absf(lateral - gap_offset_value) <= GAP * 0.5 - 12.0

func right() -> Vector2:
	return forward.orthogonal() * -1.0

func gap_center() -> Vector2:
	return global_position + right() * gap_offset

func _ready() -> void:
	mark_layer = Node2D.new()
	mark_layer.z_as_relative = false
	mark_layer.z_index = 120
	mark_layer.draw.connect(_draw_marks)
	add_child(mark_layer)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if done:
		done_age += delta
		if done_age >= MARK_SECONDS:
			queue_free()
			return
	else:
		var step := SPEED * delta
		global_position -= forward * step
		travel += step
		_check_crossings()
		if travel >= START_AHEAD + PASS_BEHIND:
			_finish()
	queue_redraw()
	if is_instance_valid(mark_layer):
		mark_layer.queue_redraw()

func _check_crossings() -> void:
	for hero in get_tree().get_nodes_in_group("heroes"):
		if not hero is Node2D or hero.get("is_alive") == false:
			continue
		var id: int = hero.get_instance_id()
		if crossed.has(id):
			continue
		var rel: Vector2 = hero.global_position - global_position
		# the wall has reached the hero once the hero is no longer behind it
		if rel.dot(forward) < 0.0:
			continue
		crossed[id] = true
		var lateral := rel.dot(right())
		if absf(lateral) > HALF_LENGTH or in_gap(lateral, gap_offset):
			continue
		if hero.has_method("take_damage"):
			hero.take_damage(FREEZE_DAMAGE, hero.global_position + forward)
		if hero.has_method("apply_movement_slow"):
			hero.apply_movement_slow(FREEZE_SLOW_SECONDS, FREEZE_SLOW)
		hits += 1
		frozen.append(hero)
		GameManager.frost_wall_hits += 1
		last_mark_time = GameManager.elapsed_time

func _finish() -> void:
	done = true
	last_verdict_time = GameManager.elapsed_time
	if hits == 0:
		GameManager.frost_walls_clean += 1

# R36: the wall reads as ice in the scene, not a HUD strip: a frost haze
# streams ahead of it in its travel direction, the wall has a lit top face and
# a shadowed front face of irregular blocks with spikes, and the opening has
# glowing green posts with arrows through it.
func _ice_segment(from: Vector2, to: Vector2) -> void:
	var r := right()
	var ahead := -forward
	var length := (to - from).length()
	var along := (to - from).normalized()
	# frost haze streaming ahead of the wall
	for k in range(3):
		var off := ahead * (34.0 + 26.0 * float(k))
		draw_line(from + off, to + off, Color(ICE, 0.18 - 0.05 * float(k)), 26.0, true)
	# shadow, front face, top face
	draw_line(from + Vector2(0, 10), to + Vector2(0, 10), Color("0d1426", 0.55), THICKNESS + 10.0, true)
	draw_line(from, to, Color("0d1426", 0.9), THICKNESS + 6.0, true)
	draw_line(from, to, Color("8fc7e6", 0.95), THICKNESS, true)
	draw_line(from + ahead * (THICKNESS * 0.25), to + ahead * (THICKNESS * 0.25), Color("e8f8ff", 0.95), THICKNESS * 0.4, true)
	# irregular block seams and spikes pointing the way the wall moves
	var step := 34.0
	for i in range(int(length / step)):
		var at: Vector2 = from + along * (step * 0.5 + step * float(i))
		var seam := r * 0.0 + along * (step * 0.5)
		draw_line(at + seam - ahead * (THICKNESS * 0.5), at + seam + ahead * (THICKNESS * 0.5), Color("5f9cc2", 0.8), 2.0, true)
		var spike := 22.0 + 10.0 * float(i % 3)
		draw_colored_polygon(PackedVector2Array([at - along * 9.0 + ahead * (THICKNESS * 0.5), at + ahead * (THICKNESS * 0.5 + spike), at + along * 9.0 + ahead * (THICKNESS * 0.5)]), Color(HAZARD, 0.95))
		draw_colored_polygon(PackedVector2Array([at - along * 4.0 + ahead * (THICKNESS * 0.5), at + ahead * (THICKNESS * 0.5 + spike * 0.6), at + along * 4.0 + ahead * (THICKNESS * 0.5)]), Color("f2fbff", 0.95))

func _draw() -> void:
	if done:
		return
	var r := right()
	var a := r * -HALF_LENGTH
	var b := r * HALF_LENGTH
	var g0 := r * (gap_offset - GAP * 0.5)
	var g1 := r * (gap_offset + GAP * 0.5)
	for seg in [[a, g0], [g1, b]]:
		_ice_segment(seg[0], seg[1])
	# the opening: glowing posts and arrows pointing through it
	for edge in [g0, g1]:
		draw_circle(edge, 15.0, Color(SAFE, 0.25))
		draw_circle(edge, 10.0, Color("0d1426", 0.9))
		draw_circle(edge, 7.0, Color(SAFE, 1.0))
	var mid := r * gap_offset
	draw_line(g0, g1, Color(SAFE, 0.35), 4.0, true)
	for i in range(3):
		var tip := mid + forward * (-30.0 - 26.0 * float(i))
		draw_polyline(PackedVector2Array([tip + forward * 14.0 + r * 14.0, tip, tip + forward * 14.0 - r * 14.0]), Color("0d1426", 0.9), 6.0, true)
		draw_polyline(PackedVector2Array([tip + forward * 14.0 + r * 14.0, tip, tip + forward * 14.0 - r * 14.0]), Color(SAFE, 1.0), 3.0, true)

func _draw_marks() -> void:
	var r := right()
	if not done:
		var w := FONT.get_string_size(LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var at := r * gap_offset + forward * 40.0
		var plate := Rect2(at + Vector2(-w * 0.5 - 8, -13), Vector2(w + 16, 26))
		# R37: the plate stays on screen and below the top bar even when the
		# opening itself is still off screen.
		if is_inside_tree():
			var xf := get_viewport().get_canvas_transform() * get_global_transform()
			var view := get_viewport().get_visible_rect().size
			var screen := xf * plate
			var unit := view.x / maxf(1.0, MobileTuning.ui_layout_size(view).x)
			var shift := Vector2(clampf(screen.position.x, 12.0 * unit, view.x - screen.size.x - 140.0 * unit) - screen.position.x, clampf(screen.position.y, 120.0 * unit, view.y - screen.size.y - 70.0 * unit) - screen.position.y)
			plate.position += shift / maxf(0.01, xf.get_scale().x)
		mark_layer.draw_rect(plate, Color("0d1426", 0.92), true)
		mark_layer.draw_rect(plate, Color(HAZARD, 0.9), false, 1.5)
		mark_layer.draw_string(FONT, plate.position + Vector2(8, 19), LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("eaf8ff"))
	var placed: Array[Vector2] = []
	for hero in frozen:
		if not is_instance_valid(hero):
			continue
		var mark: Vector2 = to_local(hero.global_position) + Vector2(0, -58)
		for other in placed:
			if mark.distance_to(other) < 26.0:
				mark.x += 26.0
		placed.append(mark)
		mark_layer.draw_circle(mark, 13.0, Color("0d1426", 0.95))
		mark_layer.draw_arc(mark, 13.0, 0.0, TAU, 24, Color(HAZARD, 1.0), 2.5, true)
		for i in range(6):
			var d := Vector2.from_angle(TAU * float(i) / 6.0)
			mark_layer.draw_line(mark + d * 13.0, mark + d * 19.0, Color(ICE, 1.0), 2.0, true)
		mark_layer.draw_string(FONT, mark + Vector2(-8, 6), "凍", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("eaf8ff"))
	if done:
		var verdict := "全員穿過霜牆" if hits == 0 else "霜牆凍住 %d 人" % hits
		var tone: Color = SAFE if hits == 0 else HAZARD
		var w2 := FONT.get_string_size(verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var cap: Vector2 = to_local(GameManager.player.global_position) if is_instance_valid(GameManager.player) else Vector2.ZERO
		var top := cap.y - 110.0
		for at2 in placed:
			top = minf(top, at2.y - 52.0)
		var box := Rect2(Vector2(cap.x - w2 * 0.5 - 10, top), Vector2(w2 + 20, 30))
		mark_layer.draw_rect(box, Color("0d1426", 0.92), true)
		mark_layer.draw_rect(box, Color(tone, 0.95), false, 2.0)
		mark_layer.draw_string(FONT, box.position + Vector2(10, 22), verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("eaf8ff"))
