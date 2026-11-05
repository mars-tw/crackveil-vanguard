extends Node2D

# R39: eighth-stage elites (珊潮遺都) raise a tide wave marked with one
# formation's sigil. The wave rolls in from the far side of the screen for
# WARN_SECONDS; when it reaches the squad, a squad holding the marked formation
# splits it ("潮紋對上・浪頭分開") and nobody is hurt. Any other formation and
# the wave breaks over every hero: WAVE_DAMAGE and a slow. The sigil is never
# the formation the squad already holds, so the answer is a formation switch.
# Earlier stages asked where to stand or walk; the tide asks which formation.
const WARN_SECONDS := 4.5
const START_AHEAD := 460.0
const RESULT_SECONDS := 2.0
const BAND_HALF := 520.0
const BAND := 46.0
const WAVE_DAMAGE := 16.0
const SLOW_SECONDS := 1.4
const SLOW := 0.55
const MAX_ACTIVE := 1
const MIN_GAP_SECONDS := 12.0
const WATER := Color("5fd0ea")
const FOAM := Color("e9fbff")
const HAZARD := Color("ff9a8a")
const SAFE := Color("8ff0a4")
const LABEL_FORMAT := "潮紋%s・浪到前換成%s"
const FONT := preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
const VINE_SNARE := preload("res://scripts/vfx/vine_snare.gd")
const RELAY := preload("res://scripts/services/formation_relay.gd")
static var last_spawned: Node2D = null
static var last_verdict_time := -99.0

var required := "ring"
# the direction the wave travels: from the far side of the screen to the squad
var travel_dir := Vector2.LEFT
var age := 0.0
var done := false
var matched := false
var done_age := 0.0
var hits := 0
var mark_layer: Node2D = null

# The sigil: a formation the squad does not hold. While a seal is open, only
# formations that also answer the seal, so the two never contradict; none left
# means no tide this cast.
static func too_soon(now: float, last: float) -> bool:
	return now >= last and now - last < MIN_GAP_SECONDS

static func pick_required(current: String, accepted: Array, seed_value: float) -> String:
	var candidates: Array[String] = []
	for id in RELAY.ORDER:
		if id == current:
			continue
		if not accepted.is_empty() and not accepted.has(id):
			continue
		candidates.append(id)
	if candidates.is_empty():
		return ""
	return candidates[clampi(int(floor(clampf(seed_value, 0.0, 0.999) * candidates.size())), 0, candidates.size() - 1)]

static func formation_name(id: String) -> String:
	return str(RELAY.NAMES[maxi(0, RELAY.ORDER.find(id))])

static func label_for(id: String) -> String:
	return LABEL_FORMAT % [formation_name(id), formation_name(id)]

static func verdict_text(ok: bool, hit_count: int) -> String:
	return "潮紋對上・浪頭分開" if ok else "潮浪拍隊・%d 人受傷" % hit_count

static func spawn(parent: Node, captain: Node2D, seed_value: float) -> Node2D:
	if parent.get_tree() == null or not is_instance_valid(captain):
		return null
	if parent.get_tree().get_nodes_in_group("tide_sigils").size() >= MAX_ACTIVE:
		return null
	# a breather between tides: one formation question at a time
	if too_soon(GameManager.elapsed_time, last_verdict_time):
		return null
	# Not cast while the captain holds an open seal: one question at a time.
	if VINE_SNARE.off_seal(captain.global_position, 60.0) != captain.global_position:
		return null
	if not is_instance_valid(GameManager.squad_manager):
		return null
	# R39: the sigil is always one of the formations the current assault also
	# accepts, so answering the tide never walks the squad into a wrong-formation
	# backlash; when the squad holds the only accepted one, no tide is raised.
	var accepted: Array = []
	if is_instance_valid(GameManager.tactical_director) and is_instance_valid(GameManager.tactical_director.relay):
		accepted = Array(GameManager.tactical_director.relay.accepted_formations())
	var id := pick_required(str(GameManager.squad_manager.get_formation_id()), accepted, seed_value)
	if id == "":
		return null
	var tide: Node2D = load("res://scripts/vfx/tide_sigil.gd").new()
	tide.required = id
	# the wave comes from the side of the screen with more room
	var travel := Vector2.LEFT
	if captain.is_inside_tree():
		var screen: Vector2 = captain.get_viewport().get_canvas_transform() * captain.global_position
		travel = Vector2.RIGHT if screen.x > captain.get_viewport().get_visible_rect().size.x * 0.5 else Vector2.LEFT
	tide.travel_dir = travel
	tide.global_position = captain.global_position
	tide.z_index = 0
	tide.add_to_group("tide_sigils")
	parent.add_child(tide)
	last_spawned = tide
	return tide

func _ready() -> void:
	mark_layer = Node2D.new()
	mark_layer.z_as_relative = false
	mark_layer.z_index = 120
	mark_layer.draw.connect(_draw_marks)
	add_child(mark_layer)

# R40: the top bar's second line while a tide is up, so it never says
# "陣形正確" for the assault while the wave is about to break on the squad.
static func status_text(required_id: String, left: int, holds: bool, finished: bool, ok: bool, hit_count: int) -> String:
	var name := formation_name(required_id)
	if finished:
		return verdict_text(ok, hit_count) if ok else "%s・浪到時要是%s" % [verdict_text(ok, hit_count), name]
	if holds:
		return "潮紋%s・已對上，守住陣形・%d 秒" % [name, left]
	return "潮紋%s・%d 秒內換成%s" % [name, left, name]

func status_line() -> String:
	return status_text(required, seconds_left(), holds_required(), done, matched, hits)

func seconds_left() -> int:
	return maxi(1, ceili(WARN_SECONDS - age))

func holds_required() -> bool:
	return is_instance_valid(GameManager.squad_manager) and str(GameManager.squad_manager.get_formation_id()) == required

# The wave front, relative to the captain: START_AHEAD away at the cast and on
# the squad at WARN_SECONDS.
func front_offset() -> Vector2:
	return -travel_dir * START_AHEAD * clampf(1.0 - age / WARN_SECONDS, 0.0, 1.0)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	# the tide rolls toward the squad wherever it walks
	if is_instance_valid(GameManager.player):
		global_position = GameManager.player.global_position
	if done:
		done_age += delta
		if done_age >= RESULT_SECONDS:
			queue_free()
			return
	else:
		age += delta
		if age >= WARN_SECONDS:
			_finish()
	queue_redraw()
	if is_instance_valid(mark_layer):
		mark_layer.queue_redraw()

func _finish() -> void:
	done = true
	matched = holds_required()
	last_verdict_time = GameManager.elapsed_time
	if matched:
		GameManager.tide_sigils_matched += 1
		EntityFactory.spawn_death_burst(global_position, SAFE, 2.6, "gold_rain")
		GameManager.request_combat_impact(3.0, 0.03)
		return
	for hero in get_tree().get_nodes_in_group("heroes"):
		if not hero is Node2D or hero.get("is_alive") == false:
			continue
		if hero.has_method("take_damage"):
			hero.take_damage(WAVE_DAMAGE, hero.global_position - travel_dir)
		if hero.has_method("apply_movement_slow"):
			hero.apply_movement_slow(SLOW_SECONDS, SLOW)
		hits += 1
	GameManager.tide_wave_hits += hits
	EntityFactory.spawn_death_burst(global_position, WATER, 3.0, "burst")
	GameManager.request_combat_impact(5.0, 0.05)

# One wave band across the screen at `front`, with a foam crest facing the way
# it rolls and a wet trail behind.
func _wave(front: Vector2, alpha: float) -> void:
	var along := travel_dir.orthogonal()
	var a := front - along * BAND_HALF
	var b := front + along * BAND_HALF
	for k in range(3):
		var back := -travel_dir * (BAND + 30.0 * float(k + 1))
		draw_line(a + back, b + back, Color(WATER, (0.16 - 0.04 * float(k)) * alpha), 30.0, true)
	draw_line(a, b, Color("0d1426", 0.85 * alpha), BAND + 8.0, true)
	draw_line(a, b, Color("2c8fb0", 0.95 * alpha), BAND, true)
	draw_line(a + travel_dir * (BAND * 0.22), b + travel_dir * (BAND * 0.22), Color(WATER, alpha), BAND * 0.45, true)
	# a curling foam crest
	var crest := PackedVector2Array()
	var steps := 40
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		crest.append(a.lerp(b, t) + travel_dir * (BAND * 0.5 + 8.0 * sin(t * 26.0 + age * 7.0)))
	draw_polyline(crest, Color("0d1426", 0.8 * alpha), 8.0, true)
	draw_polyline(crest, Color(FOAM, alpha), 4.0, true)

func _draw() -> void:
	if not done:
		_wave(front_offset(), 1.0)
		return
	# the answer splits the wave around the squad; a wrong formation lets it
	# break over everyone and wash on past
	var fade := clampf(1.0 - done_age / RESULT_SECONDS, 0.0, 1.0)
	if matched:
		var along := travel_dir.orthogonal()
		var part := 90.0 + 260.0 * done_age
		for side in [-1.0, 1.0]:
			var center: Vector2 = along * side * (part + BAND_HALF * 0.5)
			draw_line(center - along * BAND_HALF * 0.5, center + along * BAND_HALF * 0.5, Color(WATER, 0.7 * fade), BAND * 0.6, true)
		draw_arc(Vector2.ZERO, 90.0 + 40.0 * done_age, 0.0, TAU, 48, Color(SAFE, 0.9 * fade), 4.0, true)
	else:
		_wave(travel_dir * 240.0 * done_age, fade)

func _plate(plate: Rect2, text: String, tone: Color, size: int) -> void:
	mark_layer.draw_rect(plate, Color("0d1426", 0.92), true)
	mark_layer.draw_rect(plate, Color(tone, 0.95), false, 2.0)
	mark_layer.draw_string(FONT, plate.position + Vector2(10, size + 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("f2fbff"))

func _keep_on_screen(rect: Rect2) -> Rect2:
	if not is_inside_tree():
		return rect
	var xf := get_viewport().get_canvas_transform() * get_global_transform()
	var view := get_viewport().get_visible_rect().size
	var screen := xf * rect
	# R44: margins in layout units, so a 3x phone keeps the same HUD clearance.
	var unit := view.x / maxf(1.0, MobileTuning.ui_layout_size(view).x)
	var shift := Vector2(clampf(screen.position.x, 12.0 * unit, view.x - screen.size.x - 140.0 * unit) - screen.position.x, clampf(screen.position.y, 120.0 * unit, view.y - screen.size.y - 70.0 * unit) - screen.position.y)
	rect.position += shift / maxf(0.01, xf.get_scale().x)
	return rect

# R39: the plate checks the shared label registry and steps down or up past a
# seal or elite plate already there, then registers itself so later plates
# step around it in turn.
const PLATE_STEPS := [0.0, 36.0, -36.0, 72.0, -72.0, 108.0]
static func first_clear(rect: Rect2, xf: Transform2D, taken: Array) -> Rect2:
	for step in PLATE_STEPS:
		var tried := Rect2(rect.position + Vector2(0, step), rect.size)
		var screen: Rect2 = xf * tried
		var hit := false
		for area in taken:
			if screen.intersects(area):
				hit = true
				break
		if not hit:
			return tried
	return rect

# R45: the disc, its countdown ring and the seconds dot.
static func sigil_area(center: Vector2) -> Rect2:
	return Rect2(center - Vector2(54, 60), Vector2(114, 114))

# Spots along the crest, already kept on screen: the first one clear of
# badges and plates, else the one they cover least (near the screen edge every
# spot can be taken, and the sigil then sat right on 「楔快」).
const SIGIL_STEPS := [0.0, 110.0, -110.0, 220.0, -220.0, 330.0, -330.0]
static func least_covered(spots: Array, xf: Transform2D, taken: Array) -> Vector2:
	var best: Vector2 = spots[0]
	var best_cover := INF
	for spot in spots:
		var screen: Rect2 = xf * sigil_area(spot)
		var cover := 0.0
		for area in taken:
			cover += screen.intersection(area).get_area()
		if cover <= 0.0:
			return spot
		if cover < best_cover:
			best_cover = cover
			best = spot
	return best

func _place_plate(rect: Rect2) -> Rect2:
	rect = _keep_on_screen(rect)
	if not is_inside_tree():
		return rect
	var xf := get_viewport().get_canvas_transform() * get_global_transform()
	var placed := _keep_on_screen(first_clear(rect, xf, Enemy.active_label_areas()))
	Enemy.reserve_label_area(xf * placed, mark_layer)
	return placed

func _draw_marks() -> void:
	Enemy.clear_label_areas(mark_layer)
	if not done:
		# the sigil rides the wave crest, with the seconds left beside it
		var crest := front_offset() + travel_dir * (BAND * 0.5)
		var sigil := _keep_on_screen(Rect2(crest - Vector2(40, 40), Vector2(80, 80)))
		var center := sigil.get_center()
		# R45: the sigil slides along the crest off answer badges and plates.
		if is_inside_tree():
			var xf := get_viewport().get_canvas_transform() * get_global_transform()
			var spots: Array[Vector2] = []
			for step in SIGIL_STEPS:
				spots.append(_keep_on_screen(Rect2(center + travel_dir.orthogonal() * step - Vector2(40, 40), Vector2(80, 80))).get_center())
			center = least_covered(spots, xf, Enemy.active_label_areas())
			Enemy.reserve_label_area(xf * sigil_area(center), mark_layer)
		var ok := holds_required()
		var tone: Color = SAFE if ok else HAZARD
		mark_layer.draw_circle(center, 42.0, Color("0d1426", 0.92))
		mark_layer.draw_arc(center, 42.0, 0.0, TAU, 40, Color(tone, 1.0), 3.5, true)
		mark_layer.draw_texture_rect(RELAY.BADGES.get(required, RELAY.BADGES.ring), Rect2(center - Vector2(30, 30), Vector2(60, 60)), false)
		var left := clampf(1.0 - age / WARN_SECONDS, 0.0, 1.0)
		mark_layer.draw_arc(center, 50.0, -PI * 0.5, -PI * 0.5 + TAU * left, 48, Color("0d1426", 0.9), 7.0, true)
		mark_layer.draw_arc(center, 50.0, -PI * 0.5, -PI * 0.5 + TAU * left, 48, Color(WATER, 1.0), 3.5, true)
		var digit := str(seconds_left())
		var dot := center + Vector2(40, -40)
		mark_layer.draw_circle(dot, 17.0, Color("0d1426", 0.95))
		mark_layer.draw_arc(dot, 17.0, 0.0, TAU, 28, Color(WATER, 1.0), 2.5, true)
		mark_layer.draw_string(FONT, dot + Vector2(-7, 8), digit, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f2fbff"))
		# the rule under the captain; green once the squad holds the sigil
		var text := label_for(required) if not ok else "潮紋%s・已對上，守住陣形" % formation_name(required)
		var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		_plate(_place_plate(Rect2(Vector2(-w * 0.5 - 10, 74), Vector2(w + 20, 28))), text, tone, 18)
		return
	var verdict := verdict_text(matched, hits)
	var tone2: Color = SAFE if matched else HAZARD
	var w2 := FONT.get_string_size(verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	_plate(_place_plate(Rect2(Vector2(-w2 * 0.5 - 10, -116), Vector2(w2 + 20, 30))), verdict, tone2, 20)
