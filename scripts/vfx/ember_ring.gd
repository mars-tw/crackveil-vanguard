extends Node2D

# R31: third-stage elites (緋星熔庭) ring the squad in fire. An orange band
# between INNER and OUTER is warned for WARN_SECONDS, then bursts once: heroes
# standing on the band take BURST_DAMAGE. The centre is safe, so the forge asks
# the opposite of the garden's snare (spread out): gather in.
const WARN_SECONDS := 1.4
const BURST_SECONDS := 0.5
const INNER := 64.0
const OUTER := 170.0
const BURST_DAMAGE := 14.0
# One ring at a time: the band is wide, two overlapping rings would leave no
# readable safe centre.
const MAX_ACTIVE := 1
const HAZARD := Color("ff8a3d")
const LABEL := "熔火環爆・往中心集合"
const FONT := preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
const VINE_SNARE := preload("res://scripts/vfx/vine_snare.gd")
# R32: heroes caught by the burst wear a 燒 mark for MARK_SECONDS on the top
# layer, and the band burns with flame tongues instead of a flat orange disc.
const MARK_SECONDS := 1.2
const FLAME := Color("ffd27a")
static var last_spawned: Node2D = null
var burned: Array = []
var mark_layer: Node2D = null

var age := 0.0
var burst_done := false
var hits := 0

static func spawn(parent: Node, at: Vector2) -> Node2D:
	if parent.get_tree() != null and parent.get_tree().get_nodes_in_group("ember_rings").size() >= MAX_ACTIVE:
		return null
	var ring: Node2D = load("res://scripts/vfx/ember_ring.gd").new()
	# R32: the burning band never covers an open seal (same rule as the snare),
	# so "gather in" and "stand in the seal" never ask for different spots.
	ring.global_position = VINE_SNARE.off_seal(at, OUTER)
	ring.z_index = 4
	ring.add_to_group("ember_rings")
	parent.add_child(ring)
	last_spawned = ring
	return ring

func _ready() -> void:
	mark_layer = Node2D.new()
	mark_layer.z_as_relative = false
	mark_layer.z_index = 120
	mark_layer.draw.connect(_draw_marks)
	add_child(mark_layer)

func _draw_marks() -> void:
	if age < WARN_SECONDS or age >= WARN_SECONDS + MARK_SECONDS:
		return
	var placed: Array[Vector2] = []
	for hero in burned:
		if not is_instance_valid(hero):
			continue
		var mark: Vector2 = to_local(hero.global_position) + Vector2(0, -58)
		for other in placed:
			if mark.distance_to(other) < 26.0:
				mark.x += 26.0
		placed.append(mark)
		mark_layer.draw_circle(mark, 13.0, Color("1f0f06", 0.95))
		for i in range(6):
			var a := TAU * float(i) / 6.0 - PI * 0.5
			var base := mark + Vector2.from_angle(a) * 13.0
			mark_layer.draw_colored_polygon(PackedVector2Array([base + Vector2.from_angle(a).orthogonal() * 3.5, mark + Vector2.from_angle(a) * 19.0, base - Vector2.from_angle(a).orthogonal() * 3.5]), Color(HAZARD, 0.95))
		mark_layer.draw_arc(mark, 13.0, 0.0, TAU, 24, Color(HAZARD, 1.0), 2.5, true)
		mark_layer.draw_string(FONT, mark + Vector2(-8, 6), "燒", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffe1c4"))

static func on_band(offset: Vector2) -> bool:
	var d := offset.length()
	return d >= INNER and d <= OUTER

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	age += delta
	if age >= WARN_SECONDS and not burst_done:
		burst_done = true
		_burst()
	if age >= WARN_SECONDS + maxf(BURST_SECONDS, MARK_SECONDS):
		queue_free()
		return
	queue_redraw()
	if is_instance_valid(mark_layer):
		mark_layer.queue_redraw()

func _burst() -> void:
	burned.clear()
	for hero in get_tree().get_nodes_in_group("heroes"):
		if not hero is Node2D or hero.get("is_alive") == false:
			continue
		if not on_band(hero.global_position - global_position):
			continue
		if hero.has_method("take_damage"):
			hero.take_damage(BURST_DAMAGE, global_position)
		hits += 1
		burned.append(hero)
		GameManager.ember_ring_hits += 1
	# R32: a ring the whole squad dodged counts toward the result's clean rings.
	if hits == 0:
		GameManager.ember_rings_clean += 1

# The plate tries under the ring, then over it, and is skipped if both spots
# would cover rule text or an elite name plate.
func plate_slot(text_w: float) -> Rect2:
	for y in [OUTER + 18.0, -OUTER - 44.0]:
		var local := Rect2(Vector2(-text_w * 0.5 - 8, y), Vector2(text_w + 16, 26))
		if not is_inside_tree():
			return local
		var screen := (get_viewport().get_canvas_transform() * get_global_transform()) * local
		var blocked := false
		for area in Enemy.active_label_areas() + Enemy.elite_plate_rects():
			if screen.intersects(area.grow(4.0)):
				blocked = true
				break
		if not blocked:
			return local
	return Rect2()

# Flame tongues rising off a circle; they flicker in height so the band reads
# as fire, not as a flat orange area.
func _flames(radius: float, count: int, height: float, alpha: float) -> void:
	for i in range(count):
		var a := TAU * float(i) / float(count) + age * 0.5
		var flick := 0.55 + 0.45 * sin(age * 13.0 + float(i) * 1.7)
		var base := Vector2.from_angle(a) * radius
		# At least 8 px tall: a flatter tongue is a degenerate triangle.
		var tip := base + Vector2(Vector2.from_angle(a).x * 3.0, -maxf(height * flick, 8.0))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-6, 0), tip, base + Vector2(6, 0)]), Color(HAZARD, alpha))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-3, 0), base.lerp(tip, 0.6), base + Vector2(3, 0)]), Color(FLAME, alpha))

func _draw() -> void:
	var bursting := age >= WARN_SECONDS
	var fade := 1.0 if not bursting else clampf(1.0 - (age - WARN_SECONDS) / BURST_SECONDS, 0.0, 1.0)
	var band := Color(HAZARD, (0.18 if not bursting else 0.55) * fade)
	draw_arc(Vector2.ZERO, (INNER + OUTER) * 0.5, 0.0, TAU, 64, band, OUTER - INNER, true)
	if not bursting:
		_flames(OUTER - 4.0, 28, 16.0, 0.75)
	elif fade > 0.0:
		_flames(INNER + 24.0, 14, 30.0, 0.9 * fade)
		_flames((INNER + OUTER) * 0.5, 22, 38.0, 0.9 * fade)
		_flames(OUTER - 16.0, 30, 30.0, 0.9 * fade)
	for r in [INNER, OUTER]:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color("101b30", 0.85 * fade), 7.0, true)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(HAZARD, 0.95 * fade), 3.0, true)
	if not bursting:
		var left := clampf(1.0 - age / WARN_SECONDS, 0.0, 1.0)
		draw_arc(Vector2.ZERO, OUTER + 11.0, -PI * 0.5, -PI * 0.5 + TAU * left, 48, Color("101b30", 0.9), 8.0, true)
		draw_arc(Vector2.ZERO, OUTER + 11.0, -PI * 0.5, -PI * 0.5 + TAU * left, 48, Color(HAZARD, 0.95), 4.0, true)
		# safe centre: a calm ring with inward chevrons
		draw_arc(Vector2.ZERO, INNER - 8.0, 0.0, TAU, 32, Color("ffe6a6", 0.9), 2.0, true)
		for i in range(4):
			var a := TAU * float(i) / 4.0 + PI * 0.25
			var tip := Vector2.from_angle(a) * (INNER + 8.0)
			var back := Vector2.from_angle(a) * (INNER + 26.0)
			var side := Vector2.from_angle(a).orthogonal() * 9.0
			draw_polyline(PackedVector2Array([back + side, tip, back - side]), Color("ffe6a6", 0.95), 3.0, true)
	var plate := plate_slot(FONT.get_string_size(LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x) if not bursting else Rect2()
	if plate.size != Vector2.ZERO:
		var size := 18
		draw_rect(plate, Color("1f0f06", 0.9), true)
		draw_rect(plate, Color(HAZARD, 0.9), false, 1.5)
		draw_string(FONT, plate.position + Vector2(8, 19), LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("ffe1c4"))
