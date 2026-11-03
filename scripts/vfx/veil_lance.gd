extends Node2D

# R37: sixth-stage elites (帷幕王庭) lock a shadow lance on one named member.
# For WARN_SECONDS a beam runs from the elite to that member and a ring marks
# the member; at the strike, if the captain stands within COVER of the member
# the captain blocks it ("隊長護住"), otherwise the member takes LANCE_DAMAGE.
# The garden asked the squad to spread, the forge to gather, the storm to
# stretch between two points, the frost to squeeze through one gap; the veil
# asks the captain to leave the formation's centre and stand by one member.
const WARN_SECONDS := 2.6
const STRIKE_SECONDS := 0.4
const COVER := 80.0
const LANCE_DAMAGE := 30.0
const MAX_ACTIVE := 1
const MARK_SECONDS := 2.0
const HAZARD := Color("c58bff")
const SAFE := Color("8ff0a4")
const LABEL_FORMAT := "影槍鎖定%s・隊長走過去護住"
const FONT := preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
const VINE_SNARE := preload("res://scripts/vfx/vine_snare.gd")
static var last_spawned: Node2D = null
static var last_verdict_time := -99.0

var source: Node2D = null
var target: Node2D = null
var target_name := ""
var age := 0.0
var struck := false
var blocked := false
var mark_layer: Node2D = null

# A member to lock: the one farthest from the captain, so the answer is a walk.
static func pick_target(captain: Node2D, members: Array) -> Node2D:
	var best: Node2D = null
	var best_d := -1.0
	for member in members:
		if not is_instance_valid(member) or member == captain or member.get("is_alive") == false:
			continue
		var d: float = (member as Node2D).global_position.distance_to(captain.global_position)
		if d > best_d:
			best_d = d
			best = member
	return best

static func spawn(parent: Node, from: Node2D, captain: Node2D) -> Node2D:
	if parent.get_tree() == null or not is_instance_valid(captain) or not is_instance_valid(from):
		return null
	if parent.get_tree().get_nodes_in_group("veil_lances").size() >= MAX_ACTIVE:
		return null
	# Not cast while the captain holds an open seal: one question at a time.
	if VINE_SNARE.off_seal(captain.global_position, 60.0) != captain.global_position:
		return null
	var member := pick_target(captain, parent.get_tree().get_nodes_in_group("heroes"))
	if member == null:
		return null
	var lance: Node2D = load("res://scripts/vfx/veil_lance.gd").new()
	lance.source = from
	lance.target = member
	lance.target_name = str(member.get("display_name")) if member.get("display_name") != null else "隊員"
	lance.z_index = 4
	# the locked member is pinned by the shadow until the strike, so the
	# answer is the captain walking over, not the formation dragging them away
	if member.get("pinned_until") != null:
		member.set("pinned_until", Time.get_ticks_msec() + int(WARN_SECONDS * 1000.0))
	lance.add_to_group("veil_lances")
	parent.add_child(lance)
	last_spawned = lance
	return lance

static func covered(captain_at: Vector2, member_at: Vector2) -> bool:
	return captain_at.distance_to(member_at) <= COVER

func _ready() -> void:
	mark_layer = Node2D.new()
	mark_layer.z_as_relative = false
	mark_layer.z_index = 120
	mark_layer.draw.connect(_draw_marks)
	add_child(mark_layer)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if not is_instance_valid(target) or target.get("is_alive") == false:
		queue_free()
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
	last_verdict_time = GameManager.elapsed_time
	blocked = is_instance_valid(GameManager.player) and covered(GameManager.player.global_position, target.global_position)
	# R38: each outcome has its own hit: a green shield burst on a block, a
	# violet burst on the member when it lands. R39: the word is the stamp
	# alone; the floating number repeated it beside the stamp.
	if blocked:
		GameManager.veil_lances_blocked += 1
		var guard_at: Vector2 = GameManager.player.global_position
		EntityFactory.spawn_death_burst(guard_at, SAFE, 2.6, "gold_rain")
		GameManager.request_combat_impact(4.0, 0.03)
		return
	if target.has_method("take_damage"):
		target.take_damage(LANCE_DAMAGE, _from())
	EntityFactory.spawn_death_burst(target.global_position, HAZARD, 2.2, "burst")
	GameManager.veil_lance_hits += 1

func _from() -> Vector2:
	return source.global_position if is_instance_valid(source) else target.global_position + Vector2(0, -320)

func _draw() -> void:
	var a := to_local(_from())
	var b := to_local(target.global_position)
	if not struck:
		var left := clampf(1.0 - age / WARN_SECONDS, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(age * 9.0)
		draw_line(a, b, Color("0d1426", 0.7), 9.0, true)
		draw_line(a, b, Color(HAZARD, 0.35 + 0.35 * pulse), 4.0, true)
		var guarded := is_instance_valid(GameManager.player) and covered(GameManager.player.global_position, target.global_position)
		var tone: Color = SAFE if guarded else HAZARD
		draw_arc(b, COVER, 0.0, TAU, 48, Color("0d1426", 0.85), 7.0, true)
		draw_arc(b, COVER, 0.0, TAU, 48, Color(tone, 0.95), 3.0, true)
		draw_arc(b, COVER + 9.0, -PI * 0.5, -PI * 0.5 + TAU * left, 40, Color(tone, 0.9), 3.5, true)
		draw_circle(b, COVER, Color(tone, 0.10))
	else:
		var fade := clampf(1.0 - (age - WARN_SECONDS) / STRIKE_SECONDS, 0.0, 1.0)
		if fade > 0.0:
			var end := to_local(GameManager.player.global_position) if blocked and is_instance_valid(GameManager.player) else b
			draw_line(a, end, Color("0d1426", 0.8 * fade), 14.0, true)
			draw_line(a, end, Color(SAFE if blocked else HAZARD, fade), 8.0, true)

func _draw_marks() -> void:
	var b := to_local(target.global_position)
	if not struck:
		var text := LABEL_FORMAT % target_name
		var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var plate := Rect2(b + Vector2(-w * 0.5 - 8, COVER + 14), Vector2(w + 16, 26))
		mark_layer.draw_rect(plate, Color("0d1426", 0.92), true)
		mark_layer.draw_rect(plate, Color(HAZARD, 0.9), false, 1.5)
		mark_layer.draw_string(FONT, plate.position + Vector2(8, 19), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f3e8ff"))
		# the locked member's head mark
		var m := b + Vector2(0, -58)
		mark_layer.draw_circle(m, 13.0, Color("0d1426", 0.95))
		mark_layer.draw_arc(m, 13.0, 0.0, TAU, 24, Color(HAZARD, 1.0), 2.5, true)
		mark_layer.draw_string(FONT, m + Vector2(-8, 6), "鎖", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f3e8ff"))
		return
	if age >= WARN_SECONDS + MARK_SECONDS:
		return
	_draw_stamp(age - WARN_SECONDS)
	var verdict := ("隊長護住%s" % target_name) if blocked else ("%s被影槍刺中" % target_name)
	var tone: Color = SAFE if blocked else HAZARD
	var w2 := FONT.get_string_size(verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var box := Rect2(b + Vector2(-w2 * 0.5 - 10, -110), Vector2(w2 + 20, 30))
	mark_layer.draw_rect(box, Color("0d1426", 0.92), true)
	mark_layer.draw_rect(box, Color(tone, 0.95), false, 2.0)
	mark_layer.draw_string(FONT, box.position + Vector2(10, 22), verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f3e8ff"))

# R39: the outcome stamped on the top layer, so it is never under a hero or
# dropped by the damage-number cap. A block reads as a green hexagon shield
# around the captain with 「擋下」; a hit as violet shards bursting from the
# member with 「刺中 30」. The two shapes differ even without the words.
const STAMP_WORD_BLOCK := "擋下"
const STAMP_WORD_HIT := "刺中 %d"
func stamp_word() -> String:
	return STAMP_WORD_BLOCK if blocked else STAMP_WORD_HIT % int(LANCE_DAMAGE)

# R40: rises in steps until the word box clears every registered label area.
const STAMP_STEPS := [0.0, -44.0, -88.0, -132.0, 44.0]
static func first_clear_base(base: Vector2, box: Vector2, xf: Transform2D, taken: Array) -> Vector2:
	for step in STAMP_STEPS:
		var rect := Rect2(base + Vector2(-6, -box.y + step), box + Vector2(12, 8))
		var screen: Rect2 = xf * rect
		var hit := false
		for area in taken:
			if screen.intersects(area):
				hit = true
				break
		if not hit:
			return base + Vector2(0, step)
	return base

func clear_stamp_base(base: Vector2, box: Vector2) -> Vector2:
	if not is_inside_tree():
		return base
	var xf := get_viewport().get_canvas_transform() * get_global_transform()
	return first_clear_base(base, box, xf, Enemy.active_label_areas_except(mark_layer))

func _draw_stamp(since: float) -> void:
	var fade := clampf(1.0 - maxf(0.0, since - 1.2) / 0.8, 0.0, 1.0)
	if fade <= 0.0:
		return
	var grow := clampf(since / 0.25, 0.0, 1.0)
	var at := to_local(GameManager.player.global_position) if blocked and is_instance_valid(GameManager.player) else to_local(target.global_position)
	if blocked:
		var hexagon := PackedVector2Array()
		for i in range(7):
			hexagon.append(at + Vector2.RIGHT.rotated(TAU * float(i) / 6.0 + PI / 6.0) * (40.0 + 22.0 * grow))
		mark_layer.draw_polyline(hexagon, Color("0d1426", 0.85 * fade), 9.0, true)
		mark_layer.draw_polyline(hexagon, Color(SAFE, fade), 4.5, true)
		# the fill takes the six corners only: the closing seventh point repeats
		# the first and makes the polygon fail to triangulate
		mark_layer.draw_colored_polygon(hexagon.slice(0, 6), Color(SAFE, 0.16 * fade))
	else:
		for i in range(8):
			var dir := Vector2.RIGHT.rotated(TAU * float(i) / 8.0 + 0.2)
			var inner := at + dir * (18.0 + 10.0 * grow)
			var outer := at + dir * (44.0 + 30.0 * grow)
			var side := dir.orthogonal() * 6.0
			var shard := PackedVector2Array([inner - side, outer, inner + side])
			mark_layer.draw_colored_polygon(shard, Color(HAZARD, fade))
			mark_layer.draw_polyline(PackedVector2Array([inner - side, outer, inner + side, inner - side]), Color("0d1426", 0.8 * fade), 2.0, true)
	var word := stamp_word()
	var size := 36
	var w := FONT.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := at + Vector2(-w * 0.5, -150.0 - 10.0 * grow)
	# R40: the word steps up past answer tags, notices and plates already there
	base = clear_stamp_base(base, Vector2(w, float(size)))
	mark_layer.draw_string_outline(FONT, base, word, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color("0d1426", 0.95 * fade))
	# the hit word is a light violet: the lance violet alone sank into the veil floor
	mark_layer.draw_string(FONT, base, word, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(SAFE if blocked else Color("f2d2ff"), fade))
