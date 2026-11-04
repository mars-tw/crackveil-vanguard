extends Node2D

# The shapes are tactical UI over existing animated enemies, not character art.
# Each cycle locks its geometry during anticipation; damage exists only in active.
const KINDS := ["front", "pincer", "artillery"]
const COUNTERS := {"front":"wedge", "pincer":"ring", "artillery":"scatter"}
const NAMES := {"front":"重盾正面推進", "pincer":"兩翼包抄", "artillery":"遠射鎖定落點"}
const WARNING := 2.0
const ACTIVE := 0.55
const RECOVERY := 4.95
var kind := "front"
var anchor := Vector2.ZERO
var clock := 0.0
var cycles := 0
var impacts := 0
var hits := 0
var avoided := 0
var started := false
var phase := "warning"
var targets: Array[Vector2] = []
var hit_registry: Dictionary = {}
var enemies: Array[WeakRef] = []
var events: Array[Dictionary] = []
var enabled := true
# Presentation receipt of the last resolved impact; derived from the same
# hit registry and damage branch above, never fed back into combat.
var cycle_protected := 0
var last_result: Dictionary = {}
var result_age := 99.0
const ZONE_FILL_WARNING := 0.03
const ZONE_FILL_ACTIVE := 0.07
const ZONE_EDGE_WIDTH := 2.2
const FONT := preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
const FORMATION_ORDER := ["wedge", "ring", "scatter"]
const FORMATION_NAMES := {"wedge": "楔形", "ring": "圓陣", "scatter": "散兵"}
const FORMATION_COLORS := {"wedge": Color("ffae78"), "ring": Color("91dafa"), "scatter": Color("b2ec9b")}

func configure(point: Vector2, index: int) -> void:
	anchor = point
	var offset: int = {"moon":0,"garden":1,"ember":2}.get(GameManager.selected_stage_id,0)
	kind = KINDS[(index + int(offset)) % 3]
	clock = 0.0
	cycles = 0
	started = false
	phase = "waiting"
	targets.clear()
	hit_registry.clear()
	# A new seal starts without the previous seal's verdict.
	last_result = {}
	result_age = 99.0
	for ref in enemies:
		var enemy: Object = ref.get_ref()
		if is_instance_valid(enemy):
			enemy.set_meta("seal_guard",false)
	enemies.clear()
	z_index = 2
	if not is_instance_valid(tag_layer):
		tag_layer = Node2D.new()
		tag_layer.name = "PaceTagLayer"
		tag_layer.z_as_relative = false
		tag_layer.z_index = PACE_TAG_Z
		tag_layer.draw.connect(_draw_pace_tags)
		add_child(tag_layer)
	queue_redraw()

func begin() -> void:
	if started:
		return
	started = true
	_spawn_threats()
	_lock_warning()

func _spawn_threats() -> void:
	var spawner := GameManager.arena.get_node_or_null("EnemySpawner") if is_instance_valid(GameManager.arena) else null
	if spawner == null:
		return
	var profile: String = {"front":"shield","pincer":"charge","artillery":"frost"}[kind]
	var offsets: Array[Vector2] = []
	offsets.assign([Vector2(155,-35)] if kind == "front" else [Vector2(-150,20),Vector2(150,20)] if kind == "pincer" else [Vector2(-150,-95),Vector2(150,-95)])
	for offset in offsets:
		var enemy: Node = spawner.spawn_tactical_guard(profile)
		if is_instance_valid(enemy):
			enemy.global_position = anchor + offset
			enemy.set_meta("seal_guard",true)
			enemies.append(weakref(enemy))

func _lock_warning() -> void:
	phase = "warning"
	hit_registry.clear()
	cycle_protected = 0
	targets.clear()
	if kind == "artillery" and is_instance_valid(GameManager.squad_manager):
		for member in GameManager.squad_manager.get_members():
			if member.is_alive and targets.size() < 3:
				targets.append(member.global_position)
	events.append({"phase":"warning","kind":kind,"time":GameManager.elapsed_time,"cycle":cycles + 1})
	# No fixed seconds here: the top bar counts the warning down live.
	GameManager.show_toast("%s｜預警・%s" % [NAMES[kind], choice_text(kind, GameManager.active_starting_node)], "battle", true)

# R15: before the wave lands, name both answers and what each costs, so the
# player can choose without trial and error.
static func choice_text(pressure_kind: String, node_id: String) -> String:
	var catalog: GDScript = load("res://scripts/services/starting_build_catalog.gd")
	var names := {"wedge":"楔形","ring":"圓陣","scatter":"散兵"}
	var primary := str(catalog.PRIMARY.get(pressure_kind, ""))
	var secondary := str(catalog.SECONDARY.get(pressure_kind, ""))
	# Short enough for one toast line: the slow answer's extra reward only.
	# R17: both seal times, so the trade can be compared at a glance.
	# R19: the top bar now carries both seal times and heals for the whole wave,
	# so the toast names the two answers and the slow one's longer counter only.
	return "快封%s／慢封%s・慢封反擊%d秒" % [names.get(primary, ""), names.get(secondary, ""), int(catalog.counter_seconds(node_id, pressure_kind, secondary))]

func _exit_tree() -> void:
	DAMAGE_NUMBER_SCRIPT.focus_dim = false

func _process(delta: float) -> void:
	DAMAGE_NUMBER_SCRIPT.focus_dim = enabled and started and GameManager.game_running and phase in ["warning", "active"]
	if not enabled or not started or get_tree().paused or not GameManager.game_running:
		return
	advance(delta)
	queue_redraw()

func advance(delta: float) -> void:
	if not started:
		return
	clock += maxf(0,delta)
	result_age += maxf(0,delta)
	if phase == "warning" and clock >= WARNING:
		phase = "active"
		impacts += 1
		events.append({"phase":"active","kind":kind,"time":GameManager.elapsed_time,"cycle":cycles + 1})
	if phase == "active":
		for member in GameManager.squad_manager.get_members():
			if not member.is_alive or hit_registry.has(member.get_instance_id()):
				continue
			if contains_danger(member.global_position):
				hit_registry[member.get_instance_id()] = true
				var protected: bool = kind == "pincer" and GameManager.squad_manager.get_formation_id() == "ring" and member.global_position.distance_to(GameManager.player.global_position) <= 96
				if member.take_damage(4.0 if protected else 14.0,anchor):
					hits += 1
					if protected:
						cycle_protected += 1
		if clock >= WARNING + ACTIVE:
			phase = "recovery"
			cycles += 1
			if not hit_registry.has(GameManager.player.get_instance_id()):
				avoided += 1
			var alive := 0
			for member in GameManager.squad_manager.get_members():
				if member.is_alive:
					alive += 1
			var formation: String = GameManager.squad_manager.get_formation_id()
			last_result = {"kind":kind,"members":alive,"hit":hit_registry.size(),"protected":cycle_protected,"reduced":cycle_protected*10,"formation":formation,"correct":GameManager.STARTING_BUILD.accepts(GameManager.active_starting_node,kind,formation)}
			result_age = 0.0
			events.append({"phase":"recovery","kind":kind,"time":GameManager.elapsed_time,"cycle":cycles})
	if clock >= WARNING + ACTIVE + RECOVERY:
		clock = 0
		_lock_warning()

func contains_danger(point: Vector2) -> bool:
	var local := point - anchor
	match kind:
		"front": return local.x > -40 and local.x < 245 and absf(local.y) < 34
		"pincer": return absf(local.x) > 28 and absf(local.x) < 230 and absf(local.y) < 85
		"artillery":
			for target in targets:
				if point.distance_to(target) < 47:
					return true
	return false

func status_text() -> String:
	if not started:
		return str(NAMES[kind])
	return "%s・%s" % [NAMES[kind],"預警 %.1f 秒" % maxf(0,WARNING-clock) if phase == "warning" else "攻勢生效" if phase == "active" else "攻勢間隙"]

# Cracked stone edge: deterministic zig-zag so the frame reads as a rift
# fissure, not a debug rectangle. Geometry matches contains_danger exactly.
func _crack_points(from: Vector2, to: Vector2, salt: int) -> PackedVector2Array:
	var points := PackedVector2Array([from])
	var length := from.distance_to(to)
	var steps := maxi(2, int(length / 17.0))
	var normal := (to - from).normalized().orthogonal()
	for i in range(1, steps):
		var jitter := float(((i * 37 + salt * 11) % 7) - 3) * 1.15
		points.append(from.lerp(to, float(i) / steps) + normal * jitter)
	points.append(to)
	return points

func seal_banner_showing() -> bool:
	var relay := get_parent()
	return relay != null and relay.get("seal_flash_time") != null and float(relay.get("seal_flash_time")) < float(relay.get("SEAL_FLASH_SECONDS"))

func _draw_rune(at: Vector2, color: Color, size: float) -> void:
	draw_colored_polygon(PackedVector2Array([at+Vector2(0,-size),at+Vector2(size*0.7,0),at+Vector2(0,size),at+Vector2(-size*0.7,0)]),Color("101b30",0.85))
	draw_polyline(PackedVector2Array([at+Vector2(0,-size),at+Vector2(size*0.7,0),at+Vector2(0,size),at+Vector2(-size*0.7,0),at+Vector2(0,-size)]),color,1.6,true)

# The danger zone itself names the formation that answers it, from the same
# accepts() table that gates the seal; it blinks red while the squad is wrong.
const BADGES := {"wedge": preload("res://assets/ui/r8_vector/badge_wedge.svg"), "ring": preload("res://assets/ui/r8_vector/badge_ring.svg"), "scatter": preload("res://assets/ui/r8_vector/badge_scatter.svg")}
const WRONG_RING := preload("res://assets/ui/r8_vector/badge_wrong_ring.svg")
const BADGE_SIZE := 64.0

func answer_label(accepted: Array) -> String:
	var names := PackedStringArray()
	for each in accepted:
		names.append(FORMATION_NAMES[each])
	if names.is_empty():
		return ""
	return ("\u9700\uff1a" + "\uff0f".join(names)) if names.size() == 1 else ("\u53ef\u7528\uff1a" + "\uff0f".join(names))

func _answer_under_hud(center: Vector2) -> bool:
	if not is_inside_tree():
		return false
	var xf := get_viewport().get_canvas_transform() * get_global_transform()
	var area: Rect2 = xf * Rect2(center + Vector2(-100, -BADGE_SIZE * 0.5 - 26), Vector2(200, BADGE_SIZE + 60))
	for panel in Enemy.hud_panel_rects(get_viewport().get_visible_rect().size):
		if area.intersects(panel):
			return true
	return false

# R18: the bottom equipment bar (published by the HUD in layout units) also
# hides ground text; local rects are converted to those units before testing.
func _under_equipment_bar(local_rect: Rect2) -> bool:
	if not is_inside_tree():
		return false
	var view := get_viewport().get_visible_rect().size
	var to_px := view.x / maxf(1.0, MobileTuning.ui_layout_size(view).x)
	var px: Rect2 = get_viewport().get_canvas_transform() * get_global_transform() * local_rect
	return DAMAGE_NUMBER_SCRIPT.blocked_by_hud(Rect2(px.position / to_px, px.size / to_px))

const DAMAGE_NUMBER_SCRIPT := preload("res://scripts/vfx/damage_number.gd")
const PACE_TAG_Z := 97
var tag_layer: Node2D = null
var pace_tags: Array = []
const TAG_WIDTH := 80.0
const TAG_HEIGHT := 50.0
const DETAIL_SIZE := 19
# R39: "6秒 補8" under the 楔快／圓慢 tag: this build's seal time and heal.
# R40: wider and larger so the numbers read at phone size; the two tags sit
# slightly outward from their badges so the wider plates never touch.
static func pace_detail(kind_value: String, id: String) -> String:
	var catalog: GDScript = load("res://scripts/services/starting_build_catalog.gd")
	var node: String = str(GameManager.active_starting_node) if is_instance_valid(GameManager) else ""
	return "%d秒 補%d" % [int(catalog.seal_seconds(node, kind_value, id)), int(catalog.seal_heal(kind_value, id))]
func _draw_pace_tags() -> void:
	for row in pace_tags:
		var tag: Rect2 = row[0]
		var fast: bool = row[1] == "快"
		var tint := Color("ffd27a") if fast else Color("7fe3ff")
		tag_layer.draw_rect(tag, Color("08121f", 0.92), true)
		tag_layer.draw_rect(tag, tint, false, 2.0, true)
		tag_layer.draw_string(FONT, tag.position + Vector2(0, 22), str(row[2]) + str(row[1]), HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 22, tint)
		# R39: the seal seconds and heal under the name (moved off the top bar).
		if row.size() > 3:
			tag_layer.draw_string_outline(FONT, tag.position + Vector2(0, 44), str(row[3]), HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, DETAIL_SIZE, 4, Color("08121f", 0.95))
			tag_layer.draw_string(FONT, tag.position + Vector2(0, 44), str(row[3]), HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, DETAIL_SIZE, Color("f4faff"))

# R40: one tag per badge; `side` is -0.5 / +0.5 for the left / right badge.
static func pace_tag_rect(badge: Rect2, side: float, below: bool) -> Rect2:
	var spread := maxf(0.0, TAG_WIDTH - (BADGE_SIZE + 6.0)) * 0.5 + 2.0
	var x := badge.position.x + badge.size.x * 0.5 - TAG_WIDTH * 0.5 + signf(side) * spread
	var y := badge.end.y + 4.0 if below else badge.position.y - TAG_HEIGHT - 4.0
	return Rect2(Vector2(x, y), Vector2(TAG_WIDTH, TAG_HEIGHT))

# The badges plus their tags, for the label registry.
static func tags_area(center: Vector2, count: int, below: bool) -> Rect2:
	var icons := Rect2(center - Vector2(count * (BADGE_SIZE + 6.0) * 0.5, BADGE_SIZE * 0.5), Vector2(count * (BADGE_SIZE + 6.0), BADGE_SIZE))
	var badge := Rect2(center - Vector2.ONE * BADGE_SIZE * 0.5, Vector2.ONE * BADGE_SIZE)
	var left := pace_tag_rect(Rect2(badge.position - Vector2((BADGE_SIZE + 6.0) * 0.5 * (count - 1), 0), badge.size), -0.5, below)
	var right := pace_tag_rect(Rect2(badge.position + Vector2((BADGE_SIZE + 6.0) * 0.5 * (count - 1), 0), badge.size), 0.5, below)
	return icons.merge(left).merge(right)

func _tags_blocked_above(center: Vector2, count: int) -> bool:
	if not is_inside_tree():
		return false
	var xf := get_viewport().get_canvas_transform() * get_global_transform()
	var above: Rect2 = xf * tags_area(center, count, false)
	var below: Rect2 = xf * tags_area(center, count, true)
	var hit_above := false
	var hit_below := false
	for area in Enemy.active_label_areas_except(self):
		hit_above = hit_above or above.intersects(area)
		hit_below = hit_below or below.intersects(area)
	return hit_above and not hit_below and not _under_equipment_bar(tags_area(center, count, true))

# R44: the badges, or both tag rows (above and below), would sit on a HUD
# button or panel the HUD reserved this frame.
func _answer_hits_hud(center: Vector2, count: int) -> bool:
	if not is_inside_tree():
		return false
	var xf := get_viewport().get_canvas_transform() * get_global_transform()
	var hud := Enemy.hud_areas()
	var icons: Rect2 = xf * Rect2(center - Vector2(count * (BADGE_SIZE + 6.0) * 0.5, BADGE_SIZE * 0.5), Vector2(count * (BADGE_SIZE + 6.0), BADGE_SIZE))
	var above: Rect2 = xf * tags_area(center, count, false)
	var below: Rect2 = xf * tags_area(center, count, true)
	return answer_hits(icons, above, below, count, hud)

static func answer_hits(icons: Rect2, above: Rect2, below: Rect2, count: int, hud: Array[Rect2]) -> bool:
	var hit := func(rect: Rect2) -> bool:
		for area in hud:
			if rect.intersects(area):
				return true
		return false
	return hit.call(icons) or (count > 1 and hit.call(above) and hit.call(below))

# R41: above or below whichever artillery target leaves the badge and its tags
# clear of the HUD, instead of vanishing when the first target sits under the top bar.
func answer_spot(targets: Array) -> Vector2:
	for target in targets:
		for dy in [-96.0, 120.0]:
			var center: Vector2 = target + Vector2(0, dy)
			if not _answer_under_hud(center) and not _under_equipment_bar(tags_area(center, 2, false)) and not _answer_hits_hud(center, 2):
				return center
	return targets[0] + Vector2(0, -96)

func _draw_answer(center: Vector2) -> void:
	# R11: the next seal's answer badge waits until the seal banner fades, so it
	# never covers the banner's reward line.
	if seal_banner_showing():
		return
	# R15: the fast-seal (primary) answer first, matching the top bar.
	var accepted: Array[String] = []
	var primary := str(GameManager.STARTING_BUILD.PRIMARY.get(kind, ""))
	if GameManager.STARTING_BUILD.accepts(GameManager.active_starting_node, kind, primary):
		accepted.append(primary)
	for id in FORMATION_ORDER:
		if id != primary and GameManager.STARTING_BUILD.accepts(GameManager.active_starting_node, kind, id):
			accepted.append(id)
	if accepted.is_empty():
		return
	# R16: a badge that would sit under the HUD panels (HP, timer, top bar,
	# boss bar) is left to the seal marker and top bar instead of being cut.
	if _answer_under_hud(center):
		return
	if _under_equipment_bar(Rect2(center - Vector2.ONE * BADGE_SIZE * 0.5, Vector2.ONE * BADGE_SIZE)):
		return
	# R44: nor under a HUD button or panel (楔形, 旋斬, 連斬): a half-covered
	# "圓慢 9秒 補16" reads as 補1, so the badge waits for a clear spot.
	if _answer_hits_hud(center, accepted.size()):
		return
	var current: String = GameManager.squad_manager.get_formation_id() if is_instance_valid(GameManager.squad_manager) else ""
	var wrong := not accepted.has(current)
	# Original vector badge of the answering formation (two side by side when
	# the node accepts an alternative); the red ring pulses while wrong.
	var count := accepted.size()
	# R40: the tags go under the badges when a HUD notice or another plate
	# already holds the space above them.
	var tags_below := count > 1 and _tags_blocked_above(center, count)
	for i in range(count):
		var offset := Vector2((i - (count - 1) * 0.5) * (BADGE_SIZE + 6.0), 0)
		var rect := Rect2(center + offset - Vector2.ONE * BADGE_SIZE * 0.5, Vector2.ONE * BADGE_SIZE)
		draw_texture_rect(BADGES[accepted[i]], rect, false)
		# R16: each badge says whether it is the fast or the slow answer.
		if count > 1:
			var pace := "快" if i == 0 and accepted[i] == primary else "慢"
			# R17: a solid tag (gold fast, cyan slow) that reads over links and crowds.
			# R19: the tag names the formation too (楔快／圓慢), so the badge reads
			# without knowing the icon.
			var tag := pace_tag_rect(rect, i - (count - 1) * 0.5, tags_below)
			# R17: drawn on a layer above effects, name plates and the crown.
			pace_tags.append([tag, pace, str(FORMATION_NAMES[accepted[i]]).substr(0, 1), pace_detail(kind, accepted[i])])
		if wrong:
			var pulse := 0.6 + 0.4 * absf(sin(clock * 6.0))
			draw_texture_rect(WRONG_RING, rect.grow(6.0), false, Color(1, 1, 1, pulse))
	# R20: with two answers the 楔快／圓慢 tags already name both formations and
	# the top bar compares them, so the "可用：…" caption is not repeated here
	# (it stays for a single required answer and for a wrong formation).
	if count > 1 and not wrong:
		if is_inside_tree():
			var xf_tags := get_viewport().get_canvas_transform() * get_global_transform()
			Enemy.reserve_label_area(xf_tags * tags_area(center, count, tags_below), self)
		return
	var text := answer_label(accepted)
	var at := center + Vector2(-90, BADGE_SIZE * 0.5 + 24)
	# R40: tags moved under the badges keep this caption above them instead.
	if tags_below:
		at = center + Vector2(-90, -BADGE_SIZE * 0.5 - 10.0)
	var badge_text_width: float = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var badge_backing := Rect2(at + Vector2(90 - badge_text_width * 0.5 - 8, -19), Vector2(badge_text_width + 16, 26))
	# R18: a label that would slide under the equipment bar moves above the
	# fast/slow tags instead of being covered by the slot buttons.
	if _under_equipment_bar(badge_backing):
		at = center + Vector2(-90, -BADGE_SIZE * 0.5 - (TAG_HEIGHT + 8.0 if count > 1 and not tags_below else 10.0))
		badge_backing = Rect2(at + Vector2(90 - badge_text_width * 0.5 - 8, -19), Vector2(badge_text_width + 16, 26))
	# R11: elite name plates step aside from this badge instead of stacking on it.
	if is_inside_tree():
		var xf := get_viewport().get_canvas_transform() * get_global_transform()
		var icons := Rect2(center - Vector2(count * (BADGE_SIZE + 6.0) * 0.5, BADGE_SIZE * 0.5), Vector2(count * (BADGE_SIZE + 6.0), BADGE_SIZE))
		Enemy.reserve_label_area(xf * icons.merge(badge_backing), self)
	draw_rect(badge_backing, Color("08121f", 0.88), true)
	draw_rect(badge_backing, Color("ff8a99" if wrong else FORMATION_COLORS[accepted[0]], 0.85), false, 1.5, true)
	draw_string_outline(FONT, at, text, HORIZONTAL_ALIGNMENT_CENTER, 180, 20, 7, Color("08121f", 0.92))
	draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_CENTER, 180, 20, Color("ff8a99") if wrong else FORMATION_COLORS[accepted[0]])

func _draw() -> void:
	Enemy.clear_label_areas(self)
	pace_tags.clear()
	if is_instance_valid(tag_layer):
		tag_layer.queue_redraw()
	if not enabled or not started or not GameManager.game_running or get_tree().paused or phase == "recovery":
		return
	var color := Color("ff637c") if phase == "active" else Color("edbc8d")
	var alpha := ZONE_FILL_ACTIVE if phase == "active" else ZONE_FILL_WARNING
	var edge_alpha:=0.74+0.18*sin(clock*8.0)
	if kind in ["front","pincer"]:
		var lanes: Array[Rect2] = []
		lanes.assign([Rect2(anchor+Vector2(-40,-34),Vector2(285,68))] if kind == "front" else [Rect2(anchor+Vector2(-230,-85),Vector2(202,170)),Rect2(anchor+Vector2(28,-85),Vector2(202,170))])
		var salt := 0
		# R23: a pincer draws its answer once, on the lane nearer the captain; the
		# second lane keeps its chevrons only, so the centre is not four badges
		# and four tags repeating the same two answers.
		var answer_lane := 0
		if lanes.size() > 1 and is_instance_valid(GameManager.player):
			var captain_at := to_local(GameManager.player.global_position)
			answer_lane = 0 if captain_at.distance_to(lanes[0].get_center()) <= captain_at.distance_to(lanes[1].get_center()) else 1
		for lane_index in range(lanes.size()):
			var lane: Rect2 = lanes[lane_index]
			draw_rect(lane,Color(color,alpha),true)
			var nw:=lane.position
			var ne:=lane.position+Vector2(lane.size.x,0)
			var sw:=lane.position+Vector2(0,lane.size.y)
			var se:=lane.position+lane.size
			for side in [[nw,ne],[ne,se],[se,sw],[sw,nw]]:
				salt += 1
				var crack := _crack_points(side[0],side[1],salt)
				draw_polyline(crack,Color("101b30",0.85),7,true)
				draw_polyline(crack,Color(color,edge_alpha),2.6,true)
			for point in [nw,ne,sw,se]:
				_draw_rune(point,Color(color,edge_alpha),9.0)
			for i in range(1,3):
				_draw_rune(nw.lerp(ne,i/3.0),Color(color,edge_alpha*0.8),5.0)
				_draw_rune(sw.lerp(se,i/3.0),Color(color,edge_alpha*0.8),5.0)
			for i in range(3):
				var tip := lane.position+Vector2(28+i*55,lane.size.y/2)
				var dir := -1.0 if kind == "front" or lane.get_center().x > anchor.x else 1.0
				draw_polyline(PackedVector2Array([tip+Vector2(-dir*11,-12),tip,tip+Vector2(-dir*11,12)]),Color("101b30",0.8),6,true)
				draw_polyline(PackedVector2Array([tip+Vector2(-dir*11,-12),tip,tip+Vector2(-dir*11,12)]),color,3,true)
			# Answer badge sits past the chevrons, on top of the lane art.
			if lane_index == answer_lane:
				_draw_answer(lane.position + Vector2(lane.size.x - 52, lane.size.y / 2))
	else:
		for target in targets:
			draw_circle(target,47,Color(color,alpha))
			var ring := PackedVector2Array()
			for i in range(25):
				var angle := i * TAU / 24.0
				ring.append(target + Vector2.from_angle(angle) * (47.0 + (1.6 if i % 2 == 0 else -1.6)))
			# R20: landing rings read first: a heavier solid edge, and while the
			# wave is warned a countdown arc that closes as the strike nears.
			draw_polyline(ring,Color("101b30",0.9),9,true)
			draw_polyline(ring,Color(color,maxf(edge_alpha,0.9)),4.0,true)
			if phase == "warning":
				var left := clampf(1.0 - clock / WARNING, 0.0, 1.0)
				draw_arc(target, 58.0, -PI * 0.5, -PI * 0.5 + TAU * left, 40, Color("101b30",0.9), 8.0, true)
				draw_arc(target, 58.0, -PI * 0.5, -PI * 0.5 + TAU * left, 40, Color("ffe6a6"), 4.0, true)
			if is_inside_tree():
				Enemy.reserve_plate_area(get_viewport().get_canvas_transform() * get_global_transform() * Rect2(target - Vector2.ONE * 62.0, Vector2.ONE * 124.0), self)
			for i in range(4):
				_draw_rune(target + Vector2.from_angle(i*PI/2+PI/4) * 47.0,Color(color,edge_alpha),7.0)
			draw_line(target-Vector2(13,0),target+Vector2(13,0),color,2,true)
			draw_line(target-Vector2(0,13),target+Vector2(0,13),color,2,true)
		if not targets.is_empty():
			_draw_answer(answer_spot(targets))
