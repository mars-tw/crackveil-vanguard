extends Node2D

# R29: second-stage elites (翠晶花園) root the ground. A green ring is warned for
# WARN_SECONDS, then for ACTIVE_SECONDS any hero standing inside is slowed and
# takes a small tick. Ring formation pulls members together, scatter spreads
# them out: the snare rewards spreading, so the garden asks a different
# positioning question than the first stage.
const WARN_SECONDS := 1.1
const ACTIVE_SECONDS := 2.4
const RADIUS := 96.0
const SLOW_STRENGTH := 0.45
const TICK_SECONDS := 0.4
const TICK_DAMAGE := 3.0

var age := 0.0
var tick := 0.0
var hits := 0

# R30: at most MAX_ACTIVE snares at once, so two elites casting together
# do not tile the ground with stacked rings.
const MAX_ACTIVE := 2
static var last_spawned: Node2D = null

# R31: a snare never lands on an open seal: it is pushed off the seal's area,
# so "spread out" and "stand in the seal" never ask for the same spot.
# R32: shared by every stage hazard; reach is the hazard's own outer radius.
const SEAL_CLEARANCE := 150.0
static func off_seal(at: Vector2, reach: float = RADIUS) -> Vector2:
	var director = GameManager.get("tactical_director")
	if director == null or not is_instance_valid(director) or director.get("relay") == null or not is_instance_valid(director.relay):
		return at
	var relay = director.relay
	if not relay.has_method("is_open") or not relay.is_open():
		return at
	var seal: Vector2 = relay.to_global(relay.anchor)
	var away := at - seal
	if away.length() >= SEAL_CLEARANCE + reach:
		return at
	if away.length() < 1.0:
		away = Vector2.RIGHT
	return seal + away.normalized() * (SEAL_CLEARANCE + reach)

static func spawn(parent: Node, at: Vector2) -> Node2D:
	if parent.get_tree() != null and parent.get_tree().get_nodes_in_group("vine_snares").size() >= MAX_ACTIVE:
		return null
	var snare: Node2D = load("res://scripts/vfx/vine_snare.gd").new()
	snare.global_position = off_seal(at)
	snare.z_index = 4
	snare.add_to_group("vine_snares")
	parent.add_child(snare)
	last_spawned = snare
	return snare

# R31: the slow marks sit on their own top layer (above heroes, formation
# lines and effects): a thorn ring with 緩 over every hero caught, fanned out
# when heroes overlap so each stays readable.
var mark_layer: Node2D = null

func _ready() -> void:
	mark_layer = Node2D.new()
	mark_layer.z_as_relative = false
	mark_layer.z_index = 120
	mark_layer.draw.connect(_draw_marks)
	add_child(mark_layer)

func caught_heroes() -> Array:
	var out: Array = []
	if age < WARN_SECONDS or not is_inside_tree():
		return out
	for hero in get_tree().get_nodes_in_group("heroes"):
		if hero is Node2D and hero.get("is_alive") != false and hero.global_position.distance_squared_to(global_position) <= RADIUS * RADIUS:
			out.append(hero)
	return out

func _draw_marks() -> void:
	var placed: Array[Vector2] = []
	for hero in caught_heroes():
		var mark: Vector2 = to_local(hero.global_position) + Vector2(0, -58)
		for other in placed:
			if mark.distance_to(other) < 26.0:
				mark.x += 26.0
		placed.append(mark)
		mark_layer.draw_circle(mark, 13.0, Color("1a0c12", 0.95))
		for i in range(8):
			var a := TAU * float(i) / 8.0
			mark_layer.draw_line(mark + Vector2.from_angle(a) * 13.0, mark + Vector2.from_angle(a) * 18.0, Color(HAZARD, 0.95), 2.0, true)
		mark_layer.draw_arc(mark, 13.0, 0.0, TAU, 24, Color(HAZARD, 1.0), 2.5, true)
		mark_layer.draw_string(FONT, mark + Vector2(-8, 6), "緩", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffe1e4"))

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	age += delta
	if age >= WARN_SECONDS + ACTIVE_SECONDS:
		queue_free()
		return
	if age >= WARN_SECONDS:
		tick -= delta
		if tick <= 0.0:
			tick = TICK_SECONDS
			_apply_tick()
	queue_redraw()

func _apply_tick() -> void:
	for hero in get_tree().get_nodes_in_group("heroes"):
		if not hero is Node2D or hero.get("is_alive") == false:
			continue
		if hero.global_position.distance_squared_to(global_position) > RADIUS * RADIUS:
			continue
		if hero.has_method("apply_movement_slow"):
			hero.apply_movement_slow(TICK_SECONDS + 0.1, SLOW_STRENGTH)
		if hero.has_method("take_damage"):
			hero.take_damage(TICK_DAMAGE, global_position)
		hits += 1
		GameManager.vine_snare_hits += 1

# R30: the snare reads as a hazard, not a friendly area: blood-red edge and
# thorny vines (green is the squad's colour), its name on a plate, and a
# slow mark over every hero standing in it.
const HAZARD := Color("ff5a6a")
const VINE := Color("6fbf5a")
const LABEL := "荊藤纏地・散開"
const FONT := preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")

func _thorn_vine(from: Vector2, to: Vector2, alpha: float) -> void:
	var points := PackedVector2Array()
	for i in range(9):
		var t := float(i) / 8.0
		var p := from.lerp(to, t)
		var side := (to - from).orthogonal().normalized() * sin(t * TAU * 1.5) * 9.0
		points.append(p + side)
	draw_polyline(points, Color("101b30", 0.8 * alpha), 6.0, true)
	draw_polyline(points, Color(VINE, alpha), 3.0, true)
	for i in range(1, 8, 2):
		var p2 := points[i]
		var dir := (points[i + 1] - points[i - 1]).normalized().orthogonal() * 7.0
		draw_line(p2, p2 + dir, Color(HAZARD, alpha), 2.0, true)

# The plate tries under the ring, then over it, and is skipped if both spots
# would cover rule text or an elite name plate (screen-space reserved rects).
func plate_slot(text_w: float) -> Rect2:
	for y in [RADIUS + 10.0, -RADIUS - 36.0]:
		var local := Rect2(Vector2(-text_w * 0.5 - 8, y), Vector2(text_w + 16, 26))
		if not is_inside_tree():
			return local
		var xf := get_viewport().get_canvas_transform() * get_global_transform()
		var screen := xf * local
		var blocked := false
		for area in Enemy.active_label_areas() + Enemy.elite_plate_rects():
			if screen.intersects(area.grow(4.0)):
				blocked = true
				break
		if not blocked:
			return local
	return Rect2()

func shows_plate() -> bool:
	if not is_inside_tree():
		return true
	for other in get_tree().get_nodes_in_group("vine_snares"):
		if other == self or not is_instance_valid(other):
			continue
		if float(other.get("age")) > age and other.global_position.distance_to(global_position) < RADIUS * 2.2:
			return false
	return true

func _draw() -> void:
	var active := age >= WARN_SECONDS
	var fade := 1.0 if not active else clampf(1.0 - (age - WARN_SECONDS) / ACTIVE_SECONDS, 0.3, 1.0)
	draw_circle(Vector2.ZERO, RADIUS, Color(HAZARD, (0.10 if not active else 0.22) * fade))
	var spin := age * (0.4 if not active else 0.8)
	for i in range(6):
		var a := TAU * float(i) / 6.0 + spin
		_thorn_vine(Vector2.from_angle(a) * RADIUS * 0.15, Vector2.from_angle(a + 0.7) * RADIUS * 0.92, (0.55 if not active else 0.95) * fade)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color("101b30", 0.9), 8.0, true)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(HAZARD, 0.95 * fade), 3.5, true)
	if not active:
		var left := clampf(1.0 - age / WARN_SECONDS, 0.0, 1.0)
		draw_arc(Vector2.ZERO, RADIUS + 11.0, -PI * 0.5, -PI * 0.5 + TAU * left, 40, Color("101b30", 0.9), 8.0, true)
		draw_arc(Vector2.ZERO, RADIUS + 11.0, -PI * 0.5, -PI * 0.5 + TAU * left, 40, Color(HAZARD, 0.95), 4.0, true)
	# Overlapping snares share one name plate (the oldest draws it), and the
	# plate hangs under the ring, away from the seal answer caption above it.
	var plate := plate_slot(FONT.get_string_size(LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x) if shows_plate() else Rect2()
	if plate.size != Vector2.ZERO:
		var size := 18
		draw_rect(plate, Color("1a0c12", 0.9), true)
		draw_rect(plate, Color(HAZARD, 0.9), false, 1.5)
		draw_string(FONT, plate.position + Vector2(8, 19), LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("ffd6db"))
	if is_instance_valid(mark_layer):
		mark_layer.queue_redraw()
