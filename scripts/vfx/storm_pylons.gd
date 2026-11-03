extends Node2D

# R33: fourth-stage elites (雷霆浮島) drop two lightning pylons (雷柱) SPREAD
# to each side of the captain. The bolt is split, and nobody is hurt, when the
# captain stands on one pylon and a member on the other at the strike;
# otherwise lightning hits every hero within STRIKE_RADIUS. Walking onto a
# pylon turns the squad towards it, which puts the scatter formation's rear
# slots (184 / 236 behind) on the far pylon; wedge and ring stay too tight.
# The garden asked the squad to spread, the forge to gather, the storm to
# stretch the squad between two points.
# 2.8 s: time to walk onto a pylon and let the squad settle behind.
const WARN_SECONDS := 2.8
const SPREAD := 110.0
const STRIKE_SECONDS := 0.5
const PYLON_RADIUS := 95.0
const STRIKE_RADIUS := 300.0
# R34: the bolt hurts more and stuns the step: 20 damage and a one-second slow.
const STRIKE_DAMAGE := 20.0
const SHOCK_SLOW_SECONDS := 1.0
const SHOCK_SLOW := 0.5
const MAX_ACTIVE := 1
const MARK_SECONDS := 1.2
const HAZARD := Color("ffe14d")
const BOLT := Color("9fd8ff")
const SAFE := Color("8ff0a4")
const LABEL := "雷柱分流・隊長柱＋隊員柱"
const FONT := preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
const VINE_SNARE := preload("res://scripts/vfx/vine_snare.gd")
static var last_spawned: Node2D = null
static var last_mark_time := -99.0
# R34: game time of the last split bolt (QA capture hook).
static var last_split_time := -99.0

var age := 0.0
# Offset from the centre to one pylon; the other is at -half.
var half := Vector2(SPREAD, 0.0)
var struck := false
var grounded := false
# R34: why a bolt was not split, shown over the pair after the strike.
var fail_reason := ""
# R35: the member who held the member's pylon on a split, named in the verdict.
var catcher := ""
var hits := 0
var shocked: Array = []
var mark_layer: Node2D = null

# The pylons stand across the captain's path (to its left and right as it
# faces now), so either one is a short side step away.
static func lateral_half(captain: Node2D) -> Vector2:
	var forward := Vector2.RIGHT
	if is_instance_valid(captain) and captain.has_method("get_locomotion_facing_direction"):
		forward = captain.get_locomotion_facing_direction()
	return forward.rotated(PI * 0.5).normalized() * SPREAD

# R34: any axis works (the captain walks onto either pylon and the squad turns
# behind it), so the pair is laid along the direction that keeps both pylons
# farthest from the screen edges and the top bar; lateral wins ties.
const SAFE_TOP := 150.0
# R37: verdict boxes stay below the two-line top bar.
const TOP_SAFE := 120.0
const SAFE_BOTTOM := 120.0
const SAFE_SIDE := 60.0
static func onscreen_half(captain: Node2D) -> Vector2:
	var lateral := lateral_half(captain)
	if not is_instance_valid(captain) or not captain.is_inside_tree():
		return lateral
	var xf := captain.get_viewport().get_canvas_transform()
	var view := captain.get_viewport().get_visible_rect().size
	var best := lateral
	var best_margin := -INF
	for step in range(8):
		var candidate := lateral.rotated(PI * 0.25 * float(step))
		var margin := INF
		for side in [-1.0, 1.0]:
			var screen: Vector2 = xf * (captain.global_position + candidate * side)
			margin = minf(margin, minf(minf(screen.x - SAFE_SIDE, view.x - SAFE_SIDE - screen.x), minf(screen.y - SAFE_TOP, view.y - SAFE_BOTTOM - screen.y)))
		if margin > best_margin + 1.0:
			best_margin = margin
			best = candidate
	return best

static func spawn(parent: Node, at: Vector2, half_offset: Vector2 = Vector2(SPREAD, 0.0)) -> Node2D:
	if parent.get_tree() != null and parent.get_tree().get_nodes_in_group("storm_pylons").size() >= MAX_ACTIVE:
		return null
	# The pylons only make sense around the captain, so instead of being pushed
	# off an open seal (snare, ring) they are not cast while the captain stands
	# at one: the seal and the pylons never ask two questions at once.
	if VINE_SNARE.off_seal(at, PYLON_RADIUS) != at:
		return null
	var pair: Node2D = load("res://scripts/vfx/storm_pylons.gd").new()
	pair.global_position = at
	pair.half = half_offset
	pair.z_index = 4
	pair.add_to_group("storm_pylons")
	parent.add_child(pair)
	last_spawned = pair
	return pair

static func pylon_offsets(half_offset: Vector2) -> Array[Vector2]:
	return [-half_offset, half_offset]

# How many of the two pylons have a living hero standing on them.
static func covered(pair_at: Vector2, hero_positions: Array, half_offset: Vector2) -> int:
	var count := 0
	for offset in pylon_offsets(half_offset):
		for at in hero_positions:
			if (at as Vector2).distance_to(pair_at + offset) <= PYLON_RADIUS:
				count += 1
				break
	return count

# R35: the pylons have roles, so the squad never has to guess: the first is
# the captain's (隊長柱), the second a member's (隊員柱).
const CAPTAIN_PYLON := 0
const MEMBER_PYLON := 1

# R34: the missing half of a failed split, in a few words.
static func fail_reason_for(pair_at: Vector2, captain_at: Vector2, half_offset: Vector2) -> String:
	if captain_at.distance_to(pair_at + pylon_offsets(half_offset)[CAPTAIN_PYLON]) > PYLON_RADIUS:
		return "隊長沒有踩隊長柱"
	return "隊員柱沒有人"

# Split: the captain on the captain's pylon and a member on the member's pylon.
static func split_by(pair_at: Vector2, captain_at: Vector2, member_positions: Array, half_offset: Vector2) -> bool:
	var offsets := pylon_offsets(half_offset)
	if captain_at.distance_to(pair_at + offsets[CAPTAIN_PYLON]) > PYLON_RADIUS:
		return false
	for at in member_positions:
		if (at as Vector2).distance_to(pair_at + offsets[MEMBER_PYLON]) <= PYLON_RADIUS:
			return true
	return false

func _ready() -> void:
	mark_layer = Node2D.new()
	mark_layer.z_as_relative = false
	mark_layer.z_index = 120
	mark_layer.draw.connect(_draw_marks)
	add_child(mark_layer)

func _hero_positions() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	for hero in get_tree().get_nodes_in_group("heroes"):
		if hero is Node2D and hero.get("is_alive") != false:
			out.append(hero.global_position)
	return out

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	age += delta
	if age >= WARN_SECONDS and not struck:
		struck = true
		_strike()
	if age >= WARN_SECONDS + maxf(STRIKE_SECONDS, MARK_SECONDS):
		queue_free()
		return
	queue_redraw()
	if is_instance_valid(mark_layer):
		mark_layer.queue_redraw()

func _strike() -> void:
	shocked.clear()
	var members: Array = []
	for hero in get_tree().get_nodes_in_group("heroes"):
		if hero is Node2D and hero.get("is_alive") != false and hero != GameManager.player:
			members.append(hero.global_position)
	grounded = is_instance_valid(GameManager.player) and split_by(global_position, GameManager.player.global_position, members, half)
	if grounded:
		GameManager.storm_pylons_grounded += 1
		last_split_time = GameManager.elapsed_time
		var post: Vector2 = global_position + pylon_offsets(half)[MEMBER_PYLON]
		for hero in get_tree().get_nodes_in_group("heroes"):
			if hero != GameManager.player and hero is Node2D and hero.global_position.distance_to(post) <= PYLON_RADIUS and hero.get("display_name") != null:
				catcher = str(hero.get("display_name"))
				break
		return
	if is_instance_valid(GameManager.player):
		fail_reason = fail_reason_for(global_position, GameManager.player.global_position, half)
	for hero in get_tree().get_nodes_in_group("heroes"):
		if not hero is Node2D or hero.get("is_alive") == false:
			continue
		if hero.global_position.distance_to(global_position) > STRIKE_RADIUS:
			continue
		if hero.has_method("take_damage"):
			hero.take_damage(STRIKE_DAMAGE, global_position)
		if hero.has_method("apply_movement_slow"):
			hero.apply_movement_slow(SHOCK_SLOW_SECONDS, SHOCK_SLOW)
		hits += 1
		shocked.append(hero)
		GameManager.storm_pylon_hits += 1
	if hits > 0:
		last_mark_time = GameManager.elapsed_time

# R34: the name plate and the split result draw on the top layer, so the
# captain's floor halo and squad markers never cover them.
func _draw_marks() -> void:
	if not struck:
		# R35: each pylon's role on a small plate, above halos and crowns
		var offsets_m := pylon_offsets(half)
		for index in range(2):
			var post: Vector2 = global_position + offsets_m[index]
			var manned_m := false
			if index == CAPTAIN_PYLON:
				manned_m = is_instance_valid(GameManager.player) and GameManager.player.global_position.distance_to(post) <= PYLON_RADIUS
			else:
				for hero in get_tree().get_nodes_in_group("heroes"):
					if hero != GameManager.player and hero is Node2D and hero.global_position.distance_to(post) <= PYLON_RADIUS:
						manned_m = true
						break
			var tag := ("隊長" if index == CAPTAIN_PYLON else "隊員") + ("到" if manned_m else "站這")
			var tag_w := FONT.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			var tag_box := Rect2(offsets_m[index] + Vector2(-tag_w * 0.5 - 6, PYLON_RADIUS - 34), Vector2(tag_w + 12, 26))
			mark_layer.draw_rect(tag_box, Color("0d1426", 0.9), true)
			mark_layer.draw_rect(tag_box, Color(SAFE if manned_m else HAZARD, 0.95), false, 1.5)
			mark_layer.draw_string(FONT, tag_box.position + Vector2(6, 19), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("fff6c8"))
		var plate := plate_slot(FONT.get_string_size(LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x)
		if plate.size != Vector2.ZERO:
			mark_layer.draw_rect(plate, Color("0d1426", 0.92), true)
			mark_layer.draw_rect(plate, Color(HAZARD, 0.9), false, 1.5)
			mark_layer.draw_string(FONT, plate.position + Vector2(8, 19), LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("fff6c8"))
		return
	if age >= WARN_SECONDS + MARK_SECONDS:
		return
	var placed: Array[Vector2] = []
	for hero in shocked:
		if not is_instance_valid(hero):
			continue
		var mark: Vector2 = to_local(hero.global_position) + Vector2(0, -58)
		for other in placed:
			if mark.distance_to(other) < 26.0:
				mark.x += 26.0
		placed.append(mark)
		mark_layer.draw_circle(mark, 13.0, Color("0d1426", 0.95))
		mark_layer.draw_arc(mark, 13.0, 0.0, TAU, 24, Color(HAZARD, 1.0), 2.5, true)
		mark_layer.draw_polyline(PackedVector2Array([mark + Vector2(6, -20), mark + Vector2(-2, -13), mark + Vector2(3, -13), mark + Vector2(-5, -6)]), Color(HAZARD, 1.0), 2.5, true)
		mark_layer.draw_string(FONT, mark + Vector2(-8, 6), "電", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("fff6c8"))
	# The verdict sits above every mark and is drawn last, so no mark covers it.
	var top := -PYLON_RADIUS - 70.0
	for at in placed:
		top = minf(top, at.y - 52.0)
	var verdict := ("分流成功・%s接住雷柱" % catcher if catcher != "" else "分流成功・無人受傷") if grounded else "分流失敗・" + fail_reason
	var tone: Color = SAFE if grounded else HAZARD
	var w := FONT.get_string_size(verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var box := Rect2(Vector2(-w * 0.5 - 10, top), Vector2(w + 20, 30))
	# R37: climb above answer badges and plates instead of covering them.
	# Its own reservation from the previous frame is cleared first (otherwise
	# the box collides with itself and climbs off screen), and it never goes
	# above the top bar.
	if is_inside_tree():
		var xf := get_viewport().get_canvas_transform() * get_global_transform()
		Enemy.clear_label_areas(mark_layer)
		for attempt in range(3):
			var screen := xf * box
			var hit := false
			for area in Enemy.active_label_areas() + Enemy.elite_plate_rects():
				if screen.intersects(area.grow(4.0)):
					hit = true
					break
			if not hit:
				break
			box.position.y -= 36.0
		var top_screen: float = (xf * box).position.y
		if top_screen < TOP_SAFE:
			box.position.y += (TOP_SAFE - top_screen) / maxf(0.01, xf.get_scale().y)
		Enemy.reserve_label_area(xf * box, mark_layer)
	mark_layer.draw_rect(box, Color("0d1426", 0.92), true)
	mark_layer.draw_rect(box, Color(tone, 0.95), false, 2.0)
	mark_layer.draw_string(FONT, box.position + Vector2(10, 22), verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("fff6c8"))

func _zigzag(from: Vector2, to: Vector2, segments: int, jitter: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var side := (to - from).orthogonal().normalized()
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var wobble := 0.0 if i == 0 or i == segments else sin(age * 31.0 + float(i) * 2.3) * jitter
		points.append(from.lerp(to, t) + side * wobble)
	draw_polyline(points, Color("0d1426", color.a * 0.9), width + 3.0, true)
	draw_polyline(points, color, width, true)

func plate_slot(text_w: float) -> Rect2:
	for y in [PYLON_RADIUS + 30.0, -PYLON_RADIUS - 56.0]:
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

func _draw() -> void:
	var offsets := pylon_offsets(half)
	var heroes := _hero_positions()
	if not struck:
		var left := clampf(1.0 - age / WARN_SECONDS, 0.0, 1.0)
		# the strike reach, faint, so the squad sees who would be hit
		draw_arc(Vector2.ZERO, STRIKE_RADIUS, 0.0, TAU, 72, Color(HAZARD, 0.35), 2.0, true)
		_zigzag(offsets[0], offsets[1], 9, 7.0, Color(BOLT, 0.55), 2.0)
		for index in range(2):
			var offset: Vector2 = offsets[index]
			# the captain's pylon is manned by the captain, the member's by any member
			var manned := false
			if index == CAPTAIN_PYLON:
				manned = is_instance_valid(GameManager.player) and GameManager.player.global_position.distance_to(global_position + offset) <= PYLON_RADIUS
			else:
				for hero in get_tree().get_nodes_in_group("heroes"):
					if hero != GameManager.player and hero is Node2D and hero.global_position.distance_to(global_position + offset) <= PYLON_RADIUS:
						manned = true
						break
			var tone: Color = SAFE if manned else HAZARD
			draw_circle(offset, PYLON_RADIUS, Color(tone, 0.16))
			draw_arc(offset, PYLON_RADIUS, 0.0, TAU, 40, Color("0d1426", 0.9), 7.0, true)
			draw_arc(offset, PYLON_RADIUS, 0.0, TAU, 40, Color(tone, 0.95), 3.0, true)
			draw_arc(offset, PYLON_RADIUS + 9.0, -PI * 0.5, -PI * 0.5 + TAU * left, 36, Color(tone, 0.9), 3.5, true)
			# the pylon itself: a post with a bolt on top
			draw_rect(Rect2(offset + Vector2(-5, -30), Vector2(10, 30)), Color("2a3550", 0.95), true)
			_zigzag(offset + Vector2(0, -44), offset + Vector2(0, -30), 3, 4.0, Color(HAZARD, 0.95), 2.5)
			# R35: the role tag is drawn on the top layer (see _draw_marks)
	else:
		var fade := clampf(1.0 - (age - WARN_SECONDS) / STRIKE_SECONDS, 0.0, 1.0)
		if fade > 0.0:
			if grounded:
				for offset in offsets:
					_zigzag(offset + Vector2(0, -220), offset, 10, 9.0, Color(SAFE, fade), 3.0)
			else:
				draw_circle(Vector2.ZERO, STRIKE_RADIUS, Color(HAZARD, 0.22 * fade))
				for i in range(6):
					var a := TAU * float(i) / 6.0 + age
					_zigzag(Vector2.ZERO, Vector2.from_angle(a) * STRIKE_RADIUS, 8, 10.0, Color(HAZARD, fade), 3.0)
