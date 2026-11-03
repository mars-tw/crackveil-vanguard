extends Node2D

# R40: ninth-stage elites (月華靈森) plant a moon bloom in the crowd a short walk
# from the captain. The captain has LIMIT_SECONDS to reach it and spin (旋斬)
# beside it for CUT_SECONDS; that cuts the bud ("花蕾斬開") and nothing happens.
# Left alone, it opens: SPROUTS bloom wisps grow out of it, every enemy within
# HEAL_RADIUS heals HEAL_SHARE of its max HP, and the squad is rooted (a slow). The garden asked where
# to stand, the veil where to walk, the tide which formation; the bloom asks
# for the captain's own skill at the right place, with energy kept for it.
const LIMIT_SECONDS := 5.5
const RESULT_SECONDS := 2.0
const CUT_SECONDS := 0.6
const CUT_RADIUS := 96.0
const PLANT_DISTANCE := 250.0
const HEAL_RADIUS := 380.0
const HEAL_SHARE := 0.25
const ROOT_SECONDS := 1.6
const ROOT_SLOW := 0.4
const SPROUTS := 4
const SPROUT_CAP := 260
const MAX_ACTIVE := 1
const MIN_GAP_SECONDS := 12.0
const BLOOM := Color("d8b8ff")
const HAZARD := Color("ff9ad5")
const SAFE := Color("8ff0a4")
const LABEL := "月華花蕾・隊長走過去旋斬斬開"
const FONT := preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
const VINE_SNARE := preload("res://scripts/vfx/vine_snare.gd")
const R38_ENEMIES := preload("res://scripts/services/r38_enemy_catalog.gd")
static var last_spawned: Node2D = null
static var last_verdict_time := -99.0

var age := 0.0
var cut := 0.0
var done := false
var solved := false
var healed := 0
var sprouted := 0
var done_age := 0.0
# R41: why an open bloom failed, so the tip names the real fix.
var ever_near := false
var reason := ""
var sprouts: Array = []
const FAIL_TIPS := {"energy": "下次留能量旋斬", "walk": "下次先走到花蕾旁", "spin": "下次在花蕾旁按住旋斬"}
var mark_layer: Node2D = null

static func too_soon(now: float, last: float) -> bool:
	return now >= last and now - last < MIN_GAP_SECONDS

# Where the bud goes: toward the elite, a short walk from the captain.
static func plant_at(captain_at: Vector2, elite_at: Vector2) -> Vector2:
	var dir := (elite_at - captain_at)
	if dir.length() < 1.0:
		dir = Vector2.RIGHT
	return captain_at + dir.normalized() * minf(PLANT_DISTANCE, maxf(CUT_RADIUS * 1.8, dir.length()))

static func verdict_text(ok: bool, sprout_count: int) -> String:
	return "花蕾斬開・群怪不回血" if ok else "月華盛放・長出 %d 隻靈花" % sprout_count

# Low energy first; otherwise whether the captain ever reached the bud.
static func fail_reason(was_near: bool, short_of_energy: bool) -> String:
	return "energy" if short_of_energy else ("spin" if was_near else "walk")

# The top bar's second line while the bud is up (and for its verdict).
static func status_text(left: int, near: bool, finished: bool, ok: bool, sprout_count: int, why: String = "energy") -> String:
	if finished:
		return verdict_text(ok, sprout_count) if ok else "%s・%s" % [verdict_text(ok, sprout_count), FAIL_TIPS.get(why, FAIL_TIPS["energy"])]
	if near:
		return "月華花蕾・在旁邊按住旋斬・%d 秒" % left
	return "月華花蕾・%d 秒內走過去旋斬" % left

static func spawn(parent: Node, from: Node2D, captain: Node2D) -> Node2D:
	if parent.get_tree() == null or not is_instance_valid(captain) or not is_instance_valid(from):
		return null
	if parent.get_tree().get_nodes_in_group("moon_blooms").size() >= MAX_ACTIVE:
		return null
	if too_soon(GameManager.elapsed_time, last_verdict_time):
		return null
	# Not cast while the captain holds an open seal: one question at a time.
	if VINE_SNARE.off_seal(captain.global_position, 60.0) != captain.global_position:
		return null
	var bloom: Node2D = load("res://scripts/vfx/moon_bloom.gd").new()
	bloom.global_position = on_screen(captain, plant_at(captain.global_position, from.global_position))
	bloom.z_index = 0
	bloom.add_to_group("moon_blooms")
	parent.add_child(bloom)
	last_spawned = bloom
	return bloom

# Keeps the bud inside the view, clear of the HUD bands, so it can be seen and reached.
static func on_screen(captain: Node2D, at: Vector2) -> Vector2:
	if not captain.is_inside_tree():
		return at
	var xf := captain.get_viewport().get_canvas_transform()
	var view := captain.get_viewport().get_visible_rect().size
	var screen := xf * at
	screen = Vector2(clampf(screen.x, 220.0, maxf(220.0, view.x - 240.0)), clampf(screen.y, 200.0, maxf(200.0, view.y - 200.0)))
	return xf.affine_inverse() * screen

func seconds_left() -> int:
	return maxi(1, ceili(LIMIT_SECONDS - age))

func captain_near() -> bool:
	return is_instance_valid(GameManager.player) and GameManager.player.global_position.distance_to(global_position) <= CUT_RADIUS

static func low_energy(captain: Node) -> bool:
	if not is_instance_valid(captain) or not captain.has_method("get_channel_debug_state"):
		return false
	var state: Dictionary = captain.get_channel_debug_state()
	return bool(state.get("exhausted", false)) or float(state.get("energy", 999.0)) < 16.0

static func spinning(captain: Node) -> bool:
	if not is_instance_valid(captain) or not captain.has_method("get_channel_debug_state"):
		return false
	return bool(captain.get_channel_debug_state().get("active", false))

func status_line() -> String:
	return status_text(seconds_left(), captain_near(), done, solved, sprouted, reason)

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
		if captain_near():
			ever_near = true
		if captain_near() and spinning(GameManager.player):
			cut += delta
		if cut >= CUT_SECONDS:
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
		GameManager.moon_blooms_cut += 1
		EntityFactory.spawn_death_burst(global_position, SAFE, 2.6, "gold_rain")
		GameManager.request_combat_impact(4.0, 0.03)
		return
	reason = fail_reason(ever_near, low_energy(GameManager.player))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node2D and enemy.has_method("apply_support_heal") and (enemy as Node2D).global_position.distance_to(global_position) <= HEAL_RADIUS:
			if float(enemy.apply_support_heal(float(enemy.get("max_hp")) * HEAL_SHARE)) > 0.0:
				healed += 1
	var wisp: Dictionary = R38_ENEMIES.get_config("bloom_wisp")
	wisp["xp"] = 1
	wisp["gold"] = 1
	for i in range(SPROUTS):
		if EntityFactory.get_enemy_live_count() >= SPROUT_CAP:
			break
		var sprout: Node = EntityFactory.spawn_enemy("bloom_wisp", wisp.duplicate(), global_position + Vector2.RIGHT.rotated(TAU * float(i) / float(SPROUTS)) * 64.0)
		if sprout is Node2D:
			sprouts.append(sprout)
		sprouted += 1
	GameManager.moon_bloom_sprouts += sprouted
	for hero in get_tree().get_nodes_in_group("heroes"):
		if hero is Node2D and hero.get("is_alive") != false and hero.has_method("apply_movement_slow"):
			hero.apply_movement_slow(ROOT_SECONDS, ROOT_SLOW)
	GameManager.moon_bloom_heals += healed
	EntityFactory.spawn_death_burst(global_position, HAZARD, 3.2, "burst")

# A closed bud of six petals; it swells and pales toward the bloom.
func _bud(radius: float, open: float, tone: Color, alpha: float) -> void:
	for i in range(6):
		var dir := Vector2.UP.rotated(TAU * float(i) / 6.0)
		var tip := dir * radius * (0.75 + 0.55 * open)
		var side := dir.orthogonal() * radius * (0.22 + 0.2 * open)
		var petal := PackedVector2Array([Vector2.ZERO, side + dir * radius * 0.35, tip, -side + dir * radius * 0.35])
		draw_colored_polygon(petal, Color(tone, 0.55 * alpha))
		draw_polyline(PackedVector2Array([Vector2.ZERO, side + dir * radius * 0.35, tip, -side + dir * radius * 0.35, Vector2.ZERO]), Color("0d1426", 0.85 * alpha), 2.5, true)
	draw_circle(Vector2.ZERO, radius * 0.22, Color("fff3d6", alpha))

func _draw() -> void:
	if done:
		var fade := clampf(1.0 - done_age / RESULT_SECONDS, 0.0, 1.0)
		if solved:
			# the cut: two crossed slashes through a scattered bud
			for k in range(2):
				var d := Vector2.RIGHT.rotated(PI * 0.25 + PI * 0.5 * float(k))
				draw_line(-d * 70.0, d * 70.0, Color("0d1426", 0.8 * fade), 10.0, true)
				draw_line(-d * 70.0, d * 70.0, Color(SAFE, fade), 5.0, true)
		else:
			# the bloom: open petals and a ring sweeping out to the heal radius
			_bud(60.0, 1.0, HAZARD, fade)
			draw_arc(Vector2.ZERO, HEAL_RADIUS * clampf(done_age / 0.6, 0.0, 1.0), 0.0, TAU, 64, Color(HAZARD, 0.8 * fade), 4.0, true)
		return
	var open := clampf(age / LIMIT_SECONDS, 0.0, 1.0)
	var near := captain_near()
	var tone: Color = SAFE if near else BLOOM
	draw_circle(Vector2.ZERO, CUT_RADIUS, Color(tone, 0.12))
	draw_arc(Vector2.ZERO, CUT_RADIUS, 0.0, TAU, 48, Color("0d1426", 0.85), 7.0, true)
	draw_arc(Vector2.ZERO, CUT_RADIUS, 0.0, TAU, 48, Color(tone, 0.95), 3.0, true)
	# the heal reach, faint, so the cost of letting it open is on the ground
	draw_arc(Vector2.ZERO, HEAL_RADIUS, 0.0, TAU, 72, Color(HAZARD, 0.35), 2.0, true)
	_bud(34.0 + 14.0 * open, open, BLOOM, 1.0)
	# the time left as a ring, and the cut progress as a green arc inside it
	var left := clampf(1.0 - age / LIMIT_SECONDS, 0.0, 1.0)
	draw_arc(Vector2.ZERO, CUT_RADIUS + 12.0, -PI * 0.5, -PI * 0.5 + TAU * left, 48, Color("0d1426", 0.9), 7.0, true)
	draw_arc(Vector2.ZERO, CUT_RADIUS + 12.0, -PI * 0.5, -PI * 0.5 + TAU * left, 48, Color(HAZARD, 0.95), 3.5, true)
	if cut > 0.0:
		draw_arc(Vector2.ZERO, CUT_RADIUS - 10.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(cut / CUT_SECONDS, 0.0, 1.0), 40, Color(SAFE, 1.0), 6.0, true)

func _plate(plate: Rect2, text: String, tone: Color, size: int) -> void:
	mark_layer.draw_rect(plate, Color("0d1426", 0.92), true)
	mark_layer.draw_rect(plate, Color(tone, 0.95), false, 2.0)
	mark_layer.draw_string(FONT, plate.position + Vector2(10, size + 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("fff3fb"))

func _place_plate(rect: Rect2) -> Rect2:
	if not is_inside_tree():
		return rect
	var xf := get_viewport().get_canvas_transform() * get_global_transform()
	var view := get_viewport().get_visible_rect().size
	var screen := xf * rect
	var shift := Vector2(clampf(screen.position.x, 12.0, view.x - screen.size.x - 140.0) - screen.position.x, clampf(screen.position.y, 120.0, view.y - screen.size.y - 110.0) - screen.position.y)
	rect.position += shift / maxf(0.01, xf.get_scale().x)
	var placed: Rect2 = TIDE.first_clear(rect, xf, Enemy.active_label_areas_except(mark_layer))
	Enemy.reserve_label_area(xf * placed, mark_layer)
	return placed

const TIDE := preload("res://scripts/vfx/tide_sigil.gd")
const VINE := Color("7fd68a")

# R41: the bloom's cost on the ground: a vine loop under each slowed hero
# while the snare lasts, and a petal mark under each new spirit flower.
func _draw_aftermath() -> void:
	if done_age < ROOT_SECONDS:
		var hold := clampf(1.0 - done_age / ROOT_SECONDS, 0.0, 1.0)
		for hero in get_tree().get_nodes_in_group("heroes"):
			if hero is Node2D and hero.get("is_alive") != false:
				var at: Vector2 = (hero as Node2D).global_position - global_position + Vector2(0, 8)
				mark_layer.draw_arc(at, 26.0, 0.0, TAU, 28, Color("0d1426", 0.8 * hold), 6.0, true)
				mark_layer.draw_arc(at, 26.0, 0.0, TAU, 28, Color(VINE, hold), 3.0, true)
				for k in range(6):
					var d := Vector2.RIGHT.rotated(TAU * float(k) / 6.0 + done_age * 2.0)
					mark_layer.draw_line(at + d * 26.0, at + d * 34.0 + d.orthogonal() * 6.0, Color(VINE, hold), 3.0, true)
	var fade := clampf(1.0 - done_age / RESULT_SECONDS, 0.0, 1.0)
	for sprout in sprouts:
		if is_instance_valid(sprout):
			var at2: Vector2 = (sprout as Node2D).global_position - global_position
			for k in range(5):
				var d2 := Vector2.UP.rotated(TAU * float(k) / 5.0)
				mark_layer.draw_circle(at2 + d2 * 16.0, 7.0, Color(HAZARD, 0.85 * fade))
			mark_layer.draw_circle(at2, 6.0, Color("fff3d6", fade))

func _draw_marks() -> void:
	Enemy.clear_label_areas(mark_layer)
	if not done:
		var digit_at := Vector2(CUT_RADIUS * 0.72, -CUT_RADIUS * 0.72)
		mark_layer.draw_circle(digit_at, 17.0, Color("0d1426", 0.95))
		mark_layer.draw_arc(digit_at, 17.0, 0.0, TAU, 28, Color(HAZARD, 1.0), 2.5, true)
		mark_layer.draw_string(FONT, digit_at + Vector2(-7, 8), str(seconds_left()), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("fff3fb"))
		var w := FONT.get_string_size(LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		_plate(_place_plate(Rect2(Vector2(-w * 0.5 - 10, CUT_RADIUS + 22), Vector2(w + 20, 28))), LABEL, SAFE if captain_near() else HAZARD, 18)
		return
	if not solved:
		_draw_aftermath()
	var verdict := verdict_text(solved, sprouted)
	var w2 := FONT.get_string_size(verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	_plate(_place_plate(Rect2(Vector2(-w2 * 0.5 - 10, -CUT_RADIUS - 52), Vector2(w2 + 20, 30))), verdict, SAFE if solved else HAZARD, 20)
