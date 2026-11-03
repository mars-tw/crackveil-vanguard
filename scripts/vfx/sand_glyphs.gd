extends Node2D

# R38: seventh-stage elites (曜砂王陵) light two tomb glyphs, 先 and 後, on
# either side of the captain. The captain has LIMIT_SECONDS to step on 先 and
# then 後; doing so breaks the seal ("印記解開") and nothing happens. Stepping
# on 後 first does not count, and running out of time sends a sandstorm over
# the whole squad. Earlier stages asked where the squad stands; the tomb asks
# for a route in order, which the captain walks alone.
const LIMIT_SECONDS := 5.0
const RESULT_SECONDS := 2.0
const SPREAD := 170.0
const GLYPH_RADIUS := 52.0
const STORM_DAMAGE := 14.0
const STORM_SLOW_SECONDS := 1.4
const STORM_SLOW := 0.5
const MAX_ACTIVE := 1
const HAZARD := Color("f0b44c")
const SAFE := Color("8ff0a4")
const LABEL := "王陵雙印・隊長先踩「先」再踩「後」"
const FONT := preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
const VINE_SNARE := preload("res://scripts/vfx/vine_snare.gd")
const PYLONS := preload("res://scripts/vfx/storm_pylons.gd")
static var last_spawned: Node2D = null
static var last_verdict_time := -99.0

var half := Vector2(SPREAD, 0.0)
var age := 0.0
var stepped := 0
var done := false
var solved := false
var done_age := 0.0
var mark_layer: Node2D = null

static func spawn(parent: Node, captain: Node2D) -> Node2D:
	if parent.get_tree() == null or not is_instance_valid(captain):
		return null
	if parent.get_tree().get_nodes_in_group("sand_glyphs").size() >= MAX_ACTIVE:
		return null
	# Not cast while the captain holds an open seal: one question at a time.
	if VINE_SNARE.off_seal(captain.global_position, 60.0) != captain.global_position:
		return null
	var glyphs: Node2D = load("res://scripts/vfx/sand_glyphs.gd").new()
	# the same on-screen axis the storm pylons use, scaled to this spread
	glyphs.half = PYLONS.onscreen_half(captain).normalized() * SPREAD
	glyphs.global_position = captain.global_position
	glyphs.z_index = 0
	glyphs.add_to_group("sand_glyphs")
	parent.add_child(glyphs)
	last_spawned = glyphs
	return glyphs

# The glyph the captain must step on next (0 = 先, 1 = 後), as an offset.
func next_offset() -> Vector2:
	return -half if stepped == 0 else half

# Advance the sequence for a captain at `captain_at`; returns the new step.
static func advance_step(step: int, pair_at: Vector2, captain_at: Vector2, half_offset: Vector2) -> int:
	var target := pair_at + (-half_offset if step == 0 else half_offset)
	if step < 2 and captain_at.distance_to(target) <= GLYPH_RADIUS:
		return step + 1
	return step

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
		if done_age >= RESULT_SECONDS:
			queue_free()
			return
	else:
		age += delta
		if is_instance_valid(GameManager.player):
			stepped = advance_step(stepped, global_position, GameManager.player.global_position, half)
		if stepped >= 2:
			_finish(true)
		elif age >= LIMIT_SECONDS:
			_finish(false)
	queue_redraw()
	if is_instance_valid(mark_layer):
		mark_layer.queue_redraw()

func _finish(ok: bool) -> void:
	done = true
	solved = ok
	last_verdict_time = GameManager.elapsed_time
	if ok:
		GameManager.sand_glyphs_solved += 1
		EntityFactory.spawn_death_burst(global_position + half, SAFE, 2.4, "gold_rain")
		return
	for hero in get_tree().get_nodes_in_group("heroes"):
		if not hero is Node2D or hero.get("is_alive") == false:
			continue
		if hero.has_method("take_damage"):
			hero.take_damage(STORM_DAMAGE, hero.global_position + Vector2(0, -1))
		if hero.has_method("apply_movement_slow"):
			hero.apply_movement_slow(STORM_SLOW_SECONDS, STORM_SLOW)
		GameManager.sand_storm_hits += 1
	EntityFactory.spawn_death_burst(global_position, HAZARD, 3.2, "burst")

func _glyph(at: Vector2, word: String, state: int) -> void:
	# state: 0 waiting, 1 next, 2 stepped
	var tone: Color = SAFE if state == 2 else HAZARD
	var alpha := 0.95 if state != 0 else 0.55
	draw_circle(at, GLYPH_RADIUS, Color(tone, 0.14 if state != 0 else 0.07))
	draw_arc(at, GLYPH_RADIUS, 0.0, TAU, 40, Color("0d1426", 0.9), 7.0, true)
	draw_arc(at, GLYPH_RADIUS, 0.0, TAU, 40, Color(tone, alpha), 3.0, true)
	# a square tomb seal inside the ring
	var s := GLYPH_RADIUS * 0.55
	draw_polyline(PackedVector2Array([at + Vector2(-s, -s), at + Vector2(s, -s), at + Vector2(s, s), at + Vector2(-s, s), at + Vector2(-s, -s)]), Color(tone, alpha), 3.0, true)
	if state == 1:
		var pulse := 0.5 + 0.5 * sin(age * 8.0)
		draw_arc(at, GLYPH_RADIUS + 8.0 + 4.0 * pulse, 0.0, TAU, 40, Color(tone, 0.8), 3.0, true)

func _draw() -> void:
	if done:
		return
	var a := -half
	var b := half
	# a dotted route from 先 to 後
	var steps := 10
	for i in range(steps):
		var t := float(i) / float(steps - 1)
		draw_circle(a.lerp(b, t), 3.0, Color(HAZARD, 0.55))
	_glyph(a, "先", 2 if stepped >= 1 else 1)
	_glyph(b, "後", 2 if stepped >= 2 else (1 if stepped == 1 else 0))
	var left := clampf(1.0 - age / LIMIT_SECONDS, 0.0, 1.0)
	var at := a if stepped == 0 else b
	draw_arc(at, GLYPH_RADIUS + 18.0, -PI * 0.5, -PI * 0.5 + TAU * left, 48, Color("0d1426", 0.9), 7.0, true)
	draw_arc(at, GLYPH_RADIUS + 18.0, -PI * 0.5, -PI * 0.5 + TAU * left, 48, Color(HAZARD, 0.95), 3.5, true)

func _draw_marks() -> void:
	if not done:
		for k in range(2):
			var at := -half if k == 0 else half
			var word := "先" if k == 0 else "後"
			mark_layer.draw_circle(at, 17.0, Color("0d1426", 0.95))
			mark_layer.draw_arc(at, 17.0, 0.0, TAU, 28, Color(SAFE if stepped > k else HAZARD, 1.0), 2.5, true)
			mark_layer.draw_string(FONT, at + Vector2(-10, 8), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("fff3d6"))
		var w := FONT.get_string_size(LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var plate := Rect2(Vector2(-w * 0.5 - 8, GLYPH_RADIUS + 30), Vector2(w + 16, 26))
		if is_inside_tree():
			var xf := get_viewport().get_canvas_transform() * get_global_transform()
			var view := get_viewport().get_visible_rect().size
			var screen := xf * plate
			var shift := Vector2(clampf(screen.position.x, 12.0, view.x - screen.size.x - 140.0) - screen.position.x, clampf(screen.position.y, 120.0, view.y - screen.size.y - 70.0) - screen.position.y)
			plate.position += shift / maxf(0.01, xf.get_scale().x)
		mark_layer.draw_rect(plate, Color("0d1426", 0.92), true)
		mark_layer.draw_rect(plate, Color(HAZARD, 0.9), false, 1.5)
		mark_layer.draw_string(FONT, plate.position + Vector2(8, 19), LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("fff3d6"))
		return
	var verdict := "印記解開・無人受傷" if solved else "砂暴襲隊・印記未解"
	var tone: Color = SAFE if solved else HAZARD
	var w2 := FONT.get_string_size(verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var cap: Vector2 = to_local(GameManager.player.global_position) if is_instance_valid(GameManager.player) else Vector2.ZERO
	var box := Rect2(Vector2(cap.x - w2 * 0.5 - 10, cap.y - 110), Vector2(w2 + 20, 30))
	mark_layer.draw_rect(box, Color("0d1426", 0.92), true)
	mark_layer.draw_rect(box, Color(tone, 0.95), false, 2.0)
	mark_layer.draw_string(FONT, box.position + Vector2(10, 22), verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("fff3d6"))
