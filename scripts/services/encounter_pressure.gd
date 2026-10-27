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
	GameManager.show_toast("%s｜預警 2 秒，留意地面刻線" % NAMES[kind], "battle", true)

func _process(delta: float) -> void:
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

func _draw_rune(at: Vector2, color: Color, size: float) -> void:
	draw_colored_polygon(PackedVector2Array([at+Vector2(0,-size),at+Vector2(size*0.7,0),at+Vector2(0,size),at+Vector2(-size*0.7,0)]),Color("101b30",0.85))
	draw_polyline(PackedVector2Array([at+Vector2(0,-size),at+Vector2(size*0.7,0),at+Vector2(0,size),at+Vector2(-size*0.7,0),at+Vector2(0,-size)]),color,1.6,true)

func _draw() -> void:
	if not enabled or not started or not GameManager.game_running or get_tree().paused or phase == "recovery":
		return
	var color := Color("ff637c") if phase == "active" else Color("edbc8d")
	var alpha := 0.14 if phase == "active" else 0.05
	var edge_alpha:=0.74+0.18*sin(clock*8.0)
	if kind in ["front","pincer"]:
		var lanes: Array[Rect2] = []
		lanes.assign([Rect2(anchor+Vector2(-40,-34),Vector2(285,68))] if kind == "front" else [Rect2(anchor+Vector2(-230,-85),Vector2(202,170)),Rect2(anchor+Vector2(28,-85),Vector2(202,170))])
		var salt := 0
		for lane in lanes:
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
	else:
		for target in targets:
			draw_circle(target,47,Color(color,alpha))
			var ring := PackedVector2Array()
			for i in range(25):
				var angle := i * TAU / 24.0
				ring.append(target + Vector2.from_angle(angle) * (47.0 + (1.6 if i % 2 == 0 else -1.6)))
			draw_polyline(ring,Color("101b30",0.85),7,true)
			draw_polyline(ring,Color(color,edge_alpha),2.6,true)
			for i in range(4):
				_draw_rune(target + Vector2.from_angle(i*PI/2+PI/4) * 47.0,Color(color,edge_alpha),7.0)
			draw_line(target-Vector2(13,0),target+Vector2(13,0),color,2,true)
			draw_line(target-Vector2(0,13),target+Vector2(0,13),color,2,true)
