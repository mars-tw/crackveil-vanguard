extends Node2D

# R47: tenth-stage elites (時輪工坊) drop a stalled gear core (停擺齒核) between
# the captain and themselves and light two sockets. The captain walks onto the
# core to pick it up, then carries it into a socket before LIMIT_SECONDS run
# out (carrying slows the captain a little):
# - the near socket (近座・穩) sits on the captain's side, a short walk; it lags
#   the enemies around it;
# - the far socket (遠座・強) sits past the elite, through the crowd; it lags a
#   wider area for longer, makes it vulnerable, clears enemy shots in reach,
#   gives the squad +15% damage for a while and pushes a caught boss's next
#   volley back.
# Left too long the core overloads: heroes beside it are hit and it bursts
# into gear shards (enemy shots that can be dodged). The garden asked where to
# stand and the bloom for the captain's skill at a spot; the forge asks which
# route to take, and how much risk to carry through.
const LIMIT_SECONDS := 9.0
const RESULT_SECONDS := 2.0
const PICK_RADIUS := 56.0
const SOCKET_RADIUS := 50.0
const DROP_DISTANCE := 150.0
const NEAR_DISTANCE := 210.0
const FAR_DISTANCE := 430.0
const CARRY_SLOW := 0.15
const CARRY_LIFT := Vector2(0, -64)
const SOCKETS := {
	"near": {"radius": 340.0, "lag": 3.0, "slow": 0.5, "vulnerable": 0.0, "volley_delay": 0.0, "clear_shots": false, "rally": 0.0},
	"far": {"radius": 460.0, "lag": 5.0, "slow": 0.65, "vulnerable": 0.3, "volley_delay": 3.0, "clear_shots": true, "rally": 6.0}
}
const OVERLOAD_RADIUS := 150.0
const OVERLOAD_DAMAGE := 14.0
const SHARDS := 10
const SHARD_DAMAGE := 6.0
const MAX_ACTIVE := 1
const MIN_GAP_SECONDS := 12.0
const GEAR := Color("cfbadf")
const BRASS := Color("f2c66d")
const NEAR_TONE := Color("9fe3ff")
const HAZARD := Color("ff8a6a")
const SAFE := Color("8ff0a4")
const INK := Color("0d1426")
const LABEL := "時輪齒核・隊長撿起送進基座"
const SOCKET_TAGS := {"near": "穩", "far": "強"}
const FAIL_TIPS := {"pick": "下次先走過去撿起齒核", "carry": "下次撿起後直接走向基座"}
# Hand-painted replacements: drawn instead of the vector gear when present.
const ART := {"core": "res://assets/art/r47/forge_core.png", "near": "res://assets/art/r47/forge_socket_near.png", "far": "res://assets/art/r47/forge_socket_far.png"}
const FONT := preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
const MOON_BLOOM := preload("res://scripts/vfx/moon_bloom.gd")
const VINE_SNARE := preload("res://scripts/vfx/vine_snare.gd")
const TIDE := preload("res://scripts/vfx/tide_sigil.gd")
static var last_spawned: Node2D = null
static var last_verdict_time := -99.0

var age := 0.0
var carried := false
var done := false
var solved := false
var socket_used := ""
var reason := ""
var hits := 0
var lagged := 0
var shots_cleared := 0
var boss_delayed := false
var done_age := 0.0
var sortie_token := -1
# Local offsets from the drop point (this node's origin).
var core_at := Vector2.ZERO
var sockets := {"near": Vector2(-NEAR_DISTANCE, 0), "far": Vector2(FAR_DISTANCE, 0)}
var lagged_enemies: Array = []
var textures := {}
var mark_layer: Node2D = null

static func too_soon(now: float, last: float) -> bool:
	return now >= last and now - last < MIN_GAP_SECONDS

# Where the core drops: toward the elite, a short walk from the captain.
static func drop_at(captain_at: Vector2, elite_at: Vector2) -> Vector2:
	var dir := elite_at - captain_at
	if dir.length() < 1.0:
		dir = Vector2.RIGHT
	return captain_at + dir.normalized() * minf(DROP_DISTANCE, maxf(PICK_RADIUS * 1.6, dir.length() * 0.6))

static func clamp_to(band: Rect2, at: Vector2) -> Vector2:
	return Vector2(clampf(at.x, band.position.x, band.end.x), clampf(at.y, band.position.y, band.end.y))

# The two sockets, kept inside `band` (world units): the near one on the
# captain's side of the core, the far one past it toward the elite (behind the
# captain only when a narrow phone band leaves no room past the core). Neither
# sits on the core, on the captain or on the other socket, and the far one is
# always the longer walk from the captain.
const NEAR_TURNS := [0.75, -0.75, 1.15, -1.15, 0.35, -0.35, PI * 0.5, -PI * 0.5]
const FAR_TURNS := [0.0, 0.45, -0.45, 0.9, -0.9, 1.35, -1.35, PI, PI - 0.5, PI + 0.5]
static func pick_sockets(captain_at: Vector2, core: Vector2, axis: Vector2, band: Rect2) -> Dictionary:
	if axis.length() < 0.01:
		axis = Vector2.RIGHT
	axis = axis.normalized()
	var core_gap := SOCKET_RADIUS + PICK_RADIUS + 24.0
	var near := Vector2.INF
	var near_fallback := core
	for turn in NEAR_TURNS:
		var spot := clamp_to(band, core - axis.rotated(turn) * NEAR_DISTANCE)
		if spot.distance_to(core) > near_fallback.distance_to(core):
			near_fallback = spot
		if spot.distance_to(core) >= core_gap and spot.distance_to(captain_at) >= SOCKET_RADIUS + 24.0:
			near = spot
			break
	if near == Vector2.INF:
		near = near_fallback
	var far := Vector2.INF
	var best := -INF
	for turn in FAR_TURNS:
		var spot := clamp_to(band, core + axis.rotated(turn) * FAR_DISTANCE)
		var clear := spot.distance_to(near) >= SOCKET_RADIUS * 2.6 and spot.distance_to(core) >= core_gap
		var score := spot.distance_to(captain_at) - absf(wrapf(turn, -PI, PI)) * 20.0 - (0.0 if clear else 100000.0)
		if score > best:
			best = score
			far = spot
	if far.distance_to(captain_at) < near.distance_to(captain_at):
		var swap := near
		near = far
		far = swap
	return {"near": near, "far": far}

# The spawn area in world units: the moon bloom's band (between the top bar
# and the buttons, clear of the side controls) seen through the camera.
static func world_band(captain: Node2D) -> Rect2:
	if not captain.is_inside_tree():
		return Rect2(captain.global_position - Vector2(560, 300), Vector2(1120, 600))
	var xf := captain.get_viewport().get_canvas_transform()
	var view := captain.get_viewport().get_visible_rect().size
	var layout := MobileTuning.ui_layout_size(view)
	var unit := view.x / maxf(1.0, layout.x)
	var band := MOON_BLOOM.spawn_band(layout)
	return xf.affine_inverse() * Rect2(band.position * unit, band.size * unit)

static func spawn(parent: Node, from: Node2D, captain: Node2D) -> Node2D:
	if parent == null or parent.get_tree() == null or not is_instance_valid(captain) or not is_instance_valid(from):
		return null
	if parent.get_tree().get_nodes_in_group("forge_cores").size() >= MAX_ACTIVE:
		return null
	if too_soon(GameManager.elapsed_time, last_verdict_time):
		return null
	# Not cast while the captain holds an open seal: one question at a time.
	if VINE_SNARE.off_seal(captain.global_position, 60.0) != captain.global_position:
		return null
	var band := world_band(captain)
	var drop := clamp_to(band, VINE_SNARE.off_seal(drop_at(captain.global_position, from.global_position), PICK_RADIUS))
	var spots := pick_sockets(captain.global_position, drop, from.global_position - captain.global_position, band)
	var core: Node2D = load("res://scripts/vfx/forge_core.gd").new()
	core.global_position = drop
	core.sockets = {"near": Vector2(spots.near) - drop, "far": Vector2(spots.far) - drop}
	core.z_index = 0
	core.add_to_group("forge_cores")
	parent.add_child(core)
	last_spawned = core
	return core

static func lag_seconds(socket: String) -> int:
	return int(float((SOCKETS.get(socket, SOCKETS["near"]) as Dictionary).lag))

static func verdict_text(ok: bool, socket: String, boss: bool) -> String:
	if not ok:
		return "齒核過載・碎片四散"
	# Player words say 緩速 (as everywhere else in the game), so 縫獵協議's
	# 緩速目標 bonus visibly applies; 時滯 stays the code's name for it.
	var text := "遠座校準・敵群緩速 %d 秒＋易傷" % lag_seconds("far") if socket == "far" else "近座校準・敵群緩速 %d 秒" % lag_seconds("near")
	return text + ("・彈幕延後" if boss else "")

static func fail_reason(was_carried: bool) -> String:
	return "carry" if was_carried else "pick"

# The top bar's second line while the core is up (and for its verdict).
static func status_text(left: int, carrying: bool, finished: bool, ok: bool, socket: String, boss: bool, why: String = "pick") -> String:
	if finished:
		return verdict_text(true, socket, boss) if ok else "%s・%s" % [verdict_text(false, "", false), FAIL_TIPS.get(why, FAIL_TIPS["pick"])]
	if carrying:
		return "搬運齒核・送進基座・遠座更強・%d 秒" % left
	return "時輪齒核・%d 秒內走過去撿起" % left

# Lags every enemy within the socket's reach; the far socket also clears the
# enemy shots there. Returns what it did, for the verdict and the result.
static func apply_lag(tree: SceneTree, at: Vector2, config: Dictionary) -> Dictionary:
	var out := {"lagged": 0, "boss": false, "shots": 0, "enemies": []}
	var reach := float(config.get("radius", 0.0))
	for enemy in tree.get_nodes_in_group("enemies"):
		if not enemy is Node2D or not enemy.has_method("apply_time_lag") or (enemy as Node2D).global_position.distance_to(at) > reach:
			continue
		if enemy.apply_time_lag(float(config.lag), float(config.slow), float(config.vulnerable), float(config.volley_delay)):
			out.lagged += 1
			if out.enemies.size() < 24:
				out.enemies.append(enemy)
			if enemy.get("is_boss") == true and float(config.volley_delay) > 0.0:
				out.boss = true
	if bool(config.get("clear_shots", false)):
		for shot in EntityFactory.active_enemy_projectiles.duplicate():
			if is_instance_valid(shot) and shot is Node2D and shot.get("is_active") == true and (shot as Node2D).global_position.distance_to(at) <= reach:
				shot.set("is_active", false)
				EntityFactory.release_projectile(shot)
				out.shots += 1
	return out

func seconds_left() -> int:
	return maxi(1, ceili(LIMIT_SECONDS - age))

func core_global() -> Vector2:
	if carried and is_instance_valid(GameManager.player):
		return GameManager.player.global_position + CARRY_LIFT
	return to_global(core_at)

func socket_global(id: String) -> Vector2:
	return to_global(Vector2(sockets.get(id, Vector2.ZERO)))

func socket_under(at: Vector2) -> String:
	for id in ["far", "near"]:
		if at.distance_to(socket_global(id)) <= SOCKET_RADIUS:
			return id
	return ""

func status_line() -> String:
	return status_text(seconds_left(), carried, done, solved, socket_used, boss_delayed, reason)

func _ready() -> void:
	sortie_token = GameManager.run_token
	for key in ART:
		if ResourceLoader.exists(ART[key]):
			textures[key] = load(ART[key])
	mark_layer = Node2D.new()
	mark_layer.z_as_relative = false
	mark_layer.z_index = 120
	mark_layer.draw.connect(_draw_marks)
	add_child(mark_layer)

# Only a live sortie can pick up, deliver or overload a core; a settled, ended
# or replaced run takes it away with no credit and no penalty.
func _sortie_live() -> bool:
	return sortie_token == GameManager.run_token and GameManager.game_running and not GameManager.is_game_over and is_instance_valid(GameManager.player) and GameManager.player.get("is_alive") != false

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if done:
		done_age += delta
		if done_age >= result_seconds():
			queue_free()
			return
	else:
		if not _sortie_live():
			queue_free()
			return
		age += delta
		var captain: Node2D = GameManager.player
		if not carried and captain.global_position.distance_to(to_global(core_at)) <= PICK_RADIUS:
			carried = true
			if AudioManager != null and AudioManager.has_method("play_sfx"):
				AudioManager.play_sfx("pickup")
		if carried:
			if captain.has_method("apply_movement_slow"):
				captain.apply_movement_slow(0.2, CARRY_SLOW)
			var socket := socket_under(captain.global_position)
			if socket != "":
				_deliver(socket)
		if not done and age >= LIMIT_SECONDS:
			_overload()
	queue_redraw()
	if is_instance_valid(mark_layer):
		mark_layer.queue_redraw()

# A delivered core stays while its lag lasts, so the lagged marks can show.
func result_seconds() -> float:
	return maxf(RESULT_SECONDS, float(lag_seconds(socket_used))) if solved else RESULT_SECONDS

func _deliver(id: String) -> void:
	done = true
	solved = true
	socket_used = id
	carried = false
	core_at = Vector2(sockets[id])
	last_verdict_time = GameManager.elapsed_time
	GameManager.forge_cores_set += 1
	if id == "far":
		GameManager.forge_cores_far += 1
	var config: Dictionary = SOCKETS[id]
	var at := socket_global(id)
	var result := apply_lag(get_tree(), at, config)
	lagged = int(result.lagged)
	boss_delayed = bool(result.boss)
	shots_cleared = int(result.shots)
	lagged_enemies = result.enemies
	GameManager.forge_core_lagged += lagged
	if float(config.rally) > 0.0:
		GameManager.grant_forge_rally(float(config.rally))
	EntityFactory.spawn_death_burst(at, SAFE, 2.6, "gold_rain")
	GameManager.request_combat_impact(4.0, 0.03)

func _overload() -> void:
	var at := core_global()
	done = true
	solved = false
	reason = fail_reason(carried)
	carried = false
	core_at = to_local(at)
	last_verdict_time = GameManager.elapsed_time
	for hero in get_tree().get_nodes_in_group("heroes"):
		if hero is Node2D and hero.get("is_alive") != false and hero.has_method("take_damage") and (hero as Node2D).global_position.distance_to(at) <= OVERLOAD_RADIUS:
			if hero.take_damage(OVERLOAD_DAMAGE, at):
				hits += 1
	GameManager.forge_core_hits += hits
	for i in range(SHARDS):
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(SHARDS))
		EntityFactory.spawn_enemy_projectile(at + dir * 24.0, dir, shard_stats(), null, "normal")
	EntityFactory.spawn_death_burst(at, HAZARD, 3.0, "burst")

static func shard_stats() -> Dictionary:
	return {"damage": SHARD_DAMAGE, "range": 520.0, "projectile_speed": 230.0, "projectile_radius": 6.0, "pierce": 0, "color": BRASS, "projectile_sprite_path": "res://assets/sprites/proj_bullet.png", "sprite_scale": 1.0, "source_weapon_id": "forge_shard", "visual_level": 0, "evolved_visual": false, "target_group": "heroes"}

# A gear: teeth around a rim, a hub and spokes, turning with `spin`.
func _gear(canvas: CanvasItem, center: Vector2, radius: float, tone: Color, alpha: float, spin: float) -> void:
	var points := PackedVector2Array()
	var teeth := 10
	for i in range(teeth * 4):
		var angle := spin + TAU * float(i) / float(teeth * 4)
		var r := radius * (1.22 if i % 4 in [1, 2] else 1.0)
		points.append(center + Vector2.RIGHT.rotated(angle) * r)
	canvas.draw_colored_polygon(points, Color(tone, 0.9 * alpha))
	points.append(points[0])
	canvas.draw_polyline(points, Color(INK, 0.9 * alpha), 2.5, true)
	canvas.draw_circle(center, radius * 0.55, Color(INK, 0.55 * alpha))
	for k in range(3):
		var spoke := Vector2.RIGHT.rotated(spin + TAU * float(k) / 3.0) * radius * 0.55
		canvas.draw_line(center - spoke, center + spoke, Color(tone.lightened(0.25), alpha), 3.0, true)
	canvas.draw_circle(center, radius * 0.2, Color("fff3d6", alpha))

func _socket(id: String, center: Vector2, alpha: float) -> void:
	var tone: Color = BRASS if id == "far" else NEAR_TONE
	if textures.has(id):
		var size := Vector2.ONE * SOCKET_RADIUS * 2.4
		draw_texture_rect(textures[id], Rect2(center - size * 0.5, size), false, Color(1, 1, 1, alpha))
		return
	draw_circle(center, SOCKET_RADIUS, Color(tone, 0.14 * alpha))
	draw_arc(center, SOCKET_RADIUS, 0.0, TAU, 40, Color(INK, 0.85 * alpha), 7.0, true)
	draw_arc(center, SOCKET_RADIUS, 0.0, TAU, 40, Color(tone, 0.95 * alpha), 3.0, true)
	# eight notches the core's teeth lock into
	for k in range(8):
		var d := Vector2.RIGHT.rotated(TAU * float(k) / 8.0)
		draw_line(center + d * (SOCKET_RADIUS - 12.0), center + d * (SOCKET_RADIUS - 2.0), Color(tone, alpha), 3.0, true)

func _core(canvas: CanvasItem, center: Vector2, alpha: float, spin: float) -> void:
	if textures.has("core"):
		var size := Vector2.ONE * 64.0
		canvas.draw_texture_rect(textures["core"], Rect2(center - size * 0.5, size), false, Color(1, 1, 1, alpha))
		return
	_gear(canvas, center, 24.0, GEAR, alpha, spin)

# The time left as a ring around the core, wherever it is.
func _timer_ring(canvas: CanvasItem, center: Vector2) -> void:
	var left := clampf(1.0 - age / LIMIT_SECONDS, 0.0, 1.0)
	canvas.draw_arc(center, 36.0, -PI * 0.5, -PI * 0.5 + TAU * left, 40, Color(INK, 0.9), 7.0, true)
	canvas.draw_arc(center, 36.0, -PI * 0.5, -PI * 0.5 + TAU * left, 40, Color(HAZARD, 0.95), 3.5, true)

func _draw() -> void:
	if done:
		var fade := clampf(1.0 - done_age / RESULT_SECONDS, 0.0, 1.0)
		if solved:
			var config: Dictionary = SOCKETS[socket_used]
			_socket(socket_used, core_at, maxf(fade, 0.35))
			_core(self, core_at, 1.0, done_age * 3.0)
			draw_arc(core_at, float(config.radius) * clampf(done_age / 0.5, 0.0, 1.0), 0.0, TAU, 72, Color(SAFE, 0.8 * fade), 4.0, true)
		else:
			# the overload: shards flung out and a ring sweeping to the blast reach
			for i in range(SHARDS):
				var d := Vector2.RIGHT.rotated(TAU * float(i) / float(SHARDS))
				var at := core_at + d * (20.0 + 90.0 * clampf(done_age / 0.5, 0.0, 1.0))
				draw_colored_polygon(PackedVector2Array([at + d * 9.0, at + d.orthogonal() * 5.0, at - d * 6.0, at - d.orthogonal() * 5.0]), Color(BRASS, fade))
			draw_arc(core_at, OVERLOAD_RADIUS * clampf(done_age / 0.4, 0.0, 1.0), 0.0, TAU, 56, Color(HAZARD, 0.85 * fade), 4.0, true)
		return
	var from := to_local(core_global())
	# faint routes from the core (or the carried core) to both sockets
	for id in ["near", "far"]:
		var to: Vector2 = sockets[id]
		var tone: Color = BRASS if id == "far" else NEAR_TONE
		if from.distance_to(to) > SOCKET_RADIUS + 30.0:
			var dir := from.direction_to(to)
			draw_dashed_line(from + dir * 30.0, to - dir * (SOCKET_RADIUS + 4.0), Color(tone, 0.55), 2.0, 10.0, true)
		_socket(id, to, 1.0)
	if not carried:
		draw_circle(core_at, PICK_RADIUS, Color(GEAR, 0.10))
		draw_arc(core_at, PICK_RADIUS, 0.0, TAU, 40, Color(INK, 0.8), 6.0, true)
		draw_arc(core_at, PICK_RADIUS, 0.0, TAU, 40, Color(GEAR, 0.9), 2.5, true)
	# a carried core is drawn on the top layer (over the captain), in _draw_marks
	if not carried:
		_timer_ring(self, core_at)
		_core(self, core_at, 1.0, age * 0.4)

func _plate(plate: Rect2, text: String, tone: Color, size: int) -> void:
	mark_layer.draw_rect(plate, Color(INK, 0.92), true)
	mark_layer.draw_rect(plate, Color(tone, 0.95), false, 2.0)
	mark_layer.draw_string(FONT, plate.position + Vector2(10, size + 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("fff3fb"))

func _place_plate(rect: Rect2) -> Rect2:
	if not is_inside_tree():
		return rect
	var xf := get_viewport().get_canvas_transform() * get_global_transform()
	var view := get_viewport().get_visible_rect().size
	# Margins in layout units, so a 3x phone keeps the same HUD clearance.
	var unit := view.x / maxf(1.0, MobileTuning.ui_layout_size(view).x)
	var screen := xf * rect
	var shift := Vector2(clampf(screen.position.x, 12.0 * unit, view.x - screen.size.x - 140.0 * unit) - screen.position.x, clampf(screen.position.y, 120.0 * unit, view.y - screen.size.y - 110.0 * unit) - screen.position.y)
	rect.position += shift / maxf(0.01, xf.get_scale().x)
	var taken := Enemy.active_label_areas_except(mark_layer)
	if not done:
		for id in ["near", "far"]:
			taken.append(xf * Rect2(Vector2(sockets[id]) - Vector2.ONE * SOCKET_RADIUS, Vector2.ONE * SOCKET_RADIUS * 2.0))
	var placed: Rect2 = TIDE.first_clear(rect, xf, taken)
	Enemy.reserve_label_area(xf * placed, mark_layer)
	return placed

# A plate pushed away from its core draws a line back to the core's ring.
static func core_link(plate: Rect2, core: Vector2) -> PackedVector2Array:
	var near := Vector2(clampf(core.x, plate.position.x, plate.end.x), clampf(core.y, plate.position.y, plate.end.y))
	var ring := PICK_RADIUS + 4.0
	if near.distance_to(core) <= ring + 40.0:
		return PackedVector2Array()
	return PackedVector2Array([near, core + core.direction_to(near) * ring])

# The seconds dot takes the first free corner around the core.
const DIGIT_CORNERS := [Vector2(1, -1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]
static func digit_spot(center: Vector2, xf: Transform2D, taken: Array) -> Vector2:
	for corner in DIGIT_CORNERS:
		var at: Vector2 = center + corner * 40.0
		var screen: Rect2 = xf * Rect2(at - Vector2(18, 18), Vector2(36, 36))
		var hit := false
		for area in taken:
			if screen.intersects(area):
				hit = true
				break
		if not hit:
			return at
	return center + DIGIT_CORNERS[0] * 40.0

func _draw_marks() -> void:
	Enemy.clear_label_areas(mark_layer)
	var xf := get_viewport().get_canvas_transform() * get_global_transform() if is_inside_tree() else Transform2D.IDENTITY
	if not done:
		# socket tags first, reserved so plates and name tags step off them
		for id in ["near", "far"]:
			var at: Vector2 = sockets[id]
			if is_inside_tree():
				Enemy.reserve_label_area(xf * Rect2(at - Vector2.ONE * SOCKET_RADIUS, Vector2.ONE * SOCKET_RADIUS * 2.0), mark_layer)
			mark_layer.draw_string(FONT, at + Vector2(-12, 10), str(SOCKET_TAGS[id]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("fff3d6"))
		var from := to_local(core_global())
		if carried:
			_timer_ring(mark_layer, from)
			_core(mark_layer, from, 1.0, age * 2.2)
		var taken := Enemy.active_label_areas()
		taken.append_array(Enemy.hud_areas())
		var digit_at := digit_spot(from, xf, taken)
		if is_inside_tree():
			Enemy.reserve_label_area(xf * Rect2(digit_at - Vector2(18, 18), Vector2(36, 36)), mark_layer)
		mark_layer.draw_circle(digit_at, 16.0, Color(INK, 0.95))
		mark_layer.draw_arc(digit_at, 16.0, 0.0, TAU, 28, Color(HAZARD, 1.0), 2.5, true)
		mark_layer.draw_string(FONT, digit_at + Vector2(-7, 8), str(seconds_left()), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("fff3fb"))
		if carried:
			return
		var w := FONT.get_string_size(LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var placed := _place_plate(Rect2(core_at + Vector2(-w * 0.5 - 10, PICK_RADIUS + 16), Vector2(w + 20, 28)))
		var link := core_link(placed, core_at)
		if link.size() == 2:
			mark_layer.draw_line(link[0], link[1], Color(INK, 0.75), 5.0, true)
			mark_layer.draw_dashed_line(link[0], link[1], Color(GEAR, 0.95), 2.0, 9.0, true)
		_plate(placed, LABEL, GEAR, 18)
		return
	if solved:
		# a small clock over every lagged enemy while the lag lasts
		var hold := clampf(1.0 - done_age / result_seconds(), 0.0, 1.0)
		for enemy in lagged_enemies:
			if is_instance_valid(enemy) and enemy is Node2D and enemy.get("is_active") == true:
				var at: Vector2 = (enemy as Node2D).global_position - global_position + Vector2(0, -34)
				mark_layer.draw_circle(at, 9.0, Color(INK, 0.85 * hold))
				mark_layer.draw_arc(at, 9.0, 0.0, TAU, 20, Color(SAFE, hold), 2.0, true)
				mark_layer.draw_line(at, at + Vector2(0, -6), Color(SAFE, hold), 2.0, true)
				mark_layer.draw_line(at, at + Vector2(5, 0), Color(SAFE, hold), 2.0, true)
	if done_age >= RESULT_SECONDS:
		return
	var verdict := verdict_text(solved, socket_used, boss_delayed)
	var w2 := FONT.get_string_size(verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	_plate(_place_plate(Rect2(core_at + Vector2(-w2 * 0.5 - 10, -SOCKET_RADIUS - 52), Vector2(w2 + 20, 30))), verdict, SAFE if solved else HAZARD, 20)
