extends Node2D

# Original articulated cel art. The baked sprite frames retain the game's
# independent physics roots, impact events and animation timing.
var character_id := "hero_captain"
var state := "idle"
var frame := 0

const INK := Color("151c32")
const HERO_COLORS := ["477cf2", "2c9d87", "905cda", "2ab6d5", "ed9ba9", "ef774a", "dfcc92", "8b74df", "36b7af", "6dacc7"]
const IDS := ["hero_captain", "hero_rift_sniper", "hero_void_weaver", "hero_arc_scout", "hero_echo_singer", "hero_ember_grenadier", "hero_line_mender", "hero_orbit_guard", "hero_pulse_artificer", "hero_shepherd", "enemy_grunt", "enemy_fast", "enemy_tank", "enemy_elite_field", "enemy_elite_split", "enemy_elite_swift", "enemy_boss"]


func set_pose(id: String, animation: String, index: int) -> void:
	character_id = id
	state = animation
	frame = index
	queue_redraw()


func _poly(points: Array, color: Color, width: float = 1.3) -> void:
	var polygon := PackedVector2Array()
	for point in points:
		polygon.append(point)
	draw_colored_polygon(polygon, color)
	polygon.append(polygon[0])
	draw_polyline(polygon, INK, width, true)


func _limb(a: Vector2, b: Vector2, c: Vector2, color: Color, width: float) -> void:
	draw_polyline(PackedVector2Array([a, b, c]), INK, width + 2.1, true)
	draw_polyline(PackedVector2Array([a, b, c]), color, width, true)
	draw_line(a + Vector2(-0.7, 0), b + Vector2(-0.7, 0), color.lightened(0.35), 1.0, true)
	draw_circle(b, width * 0.42, color.darkened(0.16))


func _draw() -> void:
	var index := IDS.find(character_id)
	var enemy := index >= 10
	var heavy := character_id in ["enemy_tank", "enemy_boss", "hero_orbit_guard"]
	var caster := character_id in ["hero_void_weaver", "hero_echo_singer", "hero_line_mender", "hero_shepherd"]
	var accent := Color(HERO_COLORS[maxi(0, index) % 10])
	if enemy:
		accent = Color("69758e") if index == 10 else Color("7468a2") if index == 11 else Color("818d9f")
		if index >= 13:
			accent = Color("9b67c3") if index != 16 else Color("ab586f")
	var skin := Color("ffe0c2") if not enemy else Color("bcc6cf")
	var trim := Color("ffe0a0") if not enemy else Color("ef6883")
	var walk := sin(float(frame) * TAU / 8.0) if state == "walk" else 0.0
	var idle := sin(float(frame) * TAU / 4.0) if state == "idle" else 0.0
	var attack := state == "attack"
	var hurt := state == "hurt"
	var death := clampf(float(frame) / 5.0, 0.0, 1.0) if state == "death" else 0.0
	var bend := 2.0 if hurt else 0.0
	var head_offset := Vector2(2.0 if attack and frame >= 2 else -2.0 if hurt else 0.0, bend)
	var hip := Vector2(0.0, 6.0 + bend)
	var chest := Vector2(0.0, -7.0 + bend)
	var shoulder_width := 12.0 if heavy else 9.0
	var leg_width := 6.4 if heavy else 4.5
	# Every state changes joint poses. The death lean accompanies bent knees,
	# falling arms and a changing head position; it is not a rotated flat image.
	draw_set_transform(Vector2(32.0, 34.0 + death * 8.0), death * 1.32, Vector2.ONE)
	var left_knee := hip + Vector2(-6.0 - walk * 2.0, 8.0 - absf(walk) * 2.0 + death * 2.0)
	var right_knee := hip + Vector2(7.0 + walk * 2.0, 9.0 - absf(walk) * 2.0 + death * 5.0)
	var left_foot := hip + Vector2(-7.0 + walk * 5.0 - death * 5.0, 18.0 + walk * 2.2 - death * 6.0)
	var right_foot := hip + Vector2(8.0 - walk * 5.0 + death * 4.0, 18.0 - walk * 2.2 - death * 3.0)
	var boot := accent.darkened(0.52)
	_limb(hip + Vector2(-4, 0), left_knee, left_foot, boot, leg_width)
	_limb(hip + Vector2(4, 0), right_knee, right_foot, accent.darkened(0.3), leg_width)
	_poly([left_foot + Vector2(-4, -3), left_foot + Vector2(4, -3), left_foot + Vector2(7, 1), left_foot + Vector2(-5, 2)], boot)
	_poly([right_foot + Vector2(-4, -3), right_foot + Vector2(4, -3), right_foot + Vector2(7, 1), right_foot + Vector2(-5, 2)], boot.lightened(0.08))
	if not enemy:
		var cloak := accent.darkened(0.3)
		_poly([Vector2(-10, -15), Vector2(9, -14), Vector2(16 + walk * 2, 13), Vector2(6, 9), Vector2(0, 17), Vector2(-14 + walk * 2, 13)], cloak)
		draw_line(Vector2(-8, -11), Vector2(-10 + walk * 2, 11), accent.lightened(0.2), 1.2, true)
	var left_shoulder := chest + Vector2(-shoulder_width, 0)
	var right_shoulder := chest + Vector2(shoulder_width, 0)
	var left_elbow := left_shoulder + Vector2(-3, 7 + walk * 2)
	var right_elbow := right_shoulder + Vector2(3, 6 - walk * 2)
	var left_hand := left_elbow + Vector2(-1, 6 - walk * 3)
	var right_hand := right_elbow + Vector2(1, 7 + walk * 3)
	var blade_angle := -0.5
	if attack:
		var poses := [Vector2(4, -20), Vector2(11, -18), Vector2(21, -1), Vector2(19, 9), Vector2(13, 12), Vector2(10, 5)]
		right_hand = poses[clampi(frame, 0, 5)]
		right_elbow = right_shoulder.lerp(right_hand, 0.52) + Vector2(-3, -2)
		left_hand = Vector2(-4, -4) if frame < 2 else Vector2(6, 6)
		left_elbow = left_shoulder.lerp(left_hand, 0.5) + Vector2(-4, 2)
		blade_angle = [-1.85, -1.3, -0.04, 0.9, 1.35, -0.6][clampi(frame, 0, 5)]
	if hurt:
		right_hand = Vector2(4, -1 - frame)
		left_hand = Vector2(-1, 3 + frame)
	if death > 0.0:
		left_elbow += Vector2(-5, 6) * death
		right_elbow += Vector2(6, 7) * death
		left_hand += Vector2(-9, 6) * death
		right_hand += Vector2(8, 9) * death
	_limb(left_shoulder, left_elbow, left_hand, accent.darkened(0.2), 4.8 if heavy else 4.0)
	_poly([chest + Vector2(-shoulder_width, -3), chest + Vector2(shoulder_width, -3), hip + Vector2(8, 2), hip + Vector2(-8, 2)], accent)
	_poly([chest + Vector2(-3, -2), chest + Vector2(8, -2), hip + Vector2(4, -1), hip + Vector2(-1, -1)], accent.lightened(0.33), 0.8)
	if not enemy:
		# Split ivory breastplate, gold piping and fitted waist distinguish armor
		# from a flat colored shirt while retaining the tiny readable silhouette.
		var plate := Color("e6ecf5") if not caster else accent.lightened(0.45)
		_poly([chest + Vector2(-7,-2), chest + Vector2(-3,-5), chest + Vector2(0,-1), hip + Vector2(-1,-3), hip + Vector2(-6,-1)], plate, 0.8)
		_poly([chest + Vector2(1,-1), chest + Vector2(4,-5), chest + Vector2(8,-2), hip + Vector2(6,-1), hip + Vector2(1,-3)], plate.lightened(0.05), 0.8)
		draw_line(chest + Vector2(-7,-2), chest + Vector2(-1,2), trim, 1.2, true)
		draw_line(chest + Vector2(8,-2), chest + Vector2(1,2), trim, 1.2, true)
		draw_circle(chest + Vector2(0,4), 2.0, trim)
		draw_circle(chest + Vector2(0,4), 0.8, Color("8be8ff"))
		for knee in [left_knee, right_knee]:
			_poly([knee + Vector2(-2,-2),knee + Vector2(2,-2),knee + Vector2(3,2),knee + Vector2(0,4),knee + Vector2(-3,2)], plate, 0.7)
	draw_line(hip + Vector2(-8, 0), hip + Vector2(8, 0), trim, 2.1, true)
	draw_circle(hip, 2.2, trim.lightened(0.25))
	_poly([left_shoulder + Vector2(-4, -4), left_shoulder + Vector2(5, -5), left_shoulder + Vector2(6, 1), left_shoulder + Vector2(-5, 2)], accent.lightened(0.16))
	_poly([right_shoulder + Vector2(-4, -5), right_shoulder + Vector2(5, -4), right_shoulder + Vector2(6, 2), right_shoulder + Vector2(-5, 1)], accent.lightened(0.38))
	if not enemy:
		draw_line(left_shoulder + Vector2(-5,1), left_shoulder + Vector2(5,-2), trim, 1.2, true)
		draw_line(right_shoulder + Vector2(-4,-2), right_shoulder + Vector2(6,2), trim, 1.2, true)
	_limb(right_shoulder, right_elbow, right_hand, accent.lightened(0.2), 5.0 if heavy else 4.0)
	var head := Vector2(1, -21) + head_offset + Vector2(0, idle * 0.35)
	var face_radius := 9.0 if heavy else 7.5
	draw_circle(head, face_radius + 1.5, INK)
	draw_circle(head, face_radius, skin)
	draw_circle(head + Vector2(-3, 1), face_radius * 0.52, skin.darkened(0.14))
	if enemy:
		_poly([head + Vector2(-8, -3), head + Vector2(-12, -12), head + Vector2(-3, -7)], accent.darkened(0.32))
		_poly([head + Vector2(4, -7), head + Vector2(12, -13), head + Vector2(9, -1)], accent.lightened(0.18))
		_poly([head + Vector2(-8, -3), head + Vector2(-5, -9), head + Vector2(5, -9), head + Vector2(9, -1), head + Vector2(5, 4), head + Vector2(-6, 3)], accent.darkened(0.1))
		draw_line(head + Vector2(-5, 0), head + Vector2(-1, 1), trim.lightened(0.5), 2.2, true)
		draw_line(head + Vector2(3, 1), head + Vector2(7, -1), trim.lightened(0.5), 2.2, true)
		_poly([head + Vector2(-4, 5), head + Vector2(5, 5), head + Vector2(2, 8)], Color("faf0db"), 0.8)
	else:
		var hair := Color("26395a") if index == 0 else accent.darkened(0.55)
		_poly([head + Vector2(-8, -1), head + Vector2(-9, -7), head + Vector2(-5, -11), head + Vector2(-2, -9), head + Vector2(2, -12), head + Vector2(5, -8), head + Vector2(9, -7), head + Vector2(7, -1), head + Vector2(3, -5), head + Vector2(0, -1), head + Vector2(-3, -5)], hair)
		draw_line(head + Vector2(-5, -6), head + Vector2(0, -8), hair.lightened(0.46), 1.4, true)
		draw_line(head + Vector2(2, -9), head + Vector2(5, -6), hair.lightened(0.3), 1.0, true)
		draw_line(head + Vector2(-3, 1), head + Vector2(0, 1), INK, 1.1, true)
		draw_line(head + Vector2(3, 1), head + Vector2(6, 1), INK, 1.1, true)
		if death < 0.8:
			draw_circle(head + Vector2(-1, 1), 1.1, Color("45c9f4"))
			draw_circle(head + Vector2(5, 1), 1.1, Color("45c9f4"))
		if caster:
			_poly([head + Vector2(-11, -4), head + Vector2(0, -18), head + Vector2(11, -4)], accent, 1.4)
			draw_line(head + Vector2(-11, -4), head + Vector2(11, -4), trim, 2.0, true)
		elif heavy:
			draw_arc(head, 10.0, PI, TAU, 12, trim, 2.0, true)
	draw_circle(left_hand, 3.1, skin)
	draw_circle(right_hand, 3.1, skin)
	if enemy:
		for hand in [left_hand, right_hand]:
			for claw in range(3):
				draw_line(hand + Vector2(float(claw - 1) * 2.5, 0), hand + Vector2(float(claw - 1) * 3.5, 7), Color("ece5de"), 1.5, true)
	elif caster:
		draw_line(right_hand + Vector2(0, 8), right_hand + Vector2(0, -23), INK, 4.0, true)
		draw_line(right_hand + Vector2(0, 8), right_hand + Vector2(0, -23), trim.darkened(0.12), 2.0, true)
		draw_circle(right_hand + Vector2(0, -22), 4, accent.lightened(0.55))
	else:
		var direction := Vector2.RIGHT.rotated(blade_angle)
		var normal := direction.orthogonal()
		var hilt := right_hand
		var length := 16.0 if attack else 14.0
		_poly([hilt + direction * 3 - normal * 2, hilt + direction * length - normal * 2, hilt + direction * (length + 4), hilt + direction * length + normal * 2, hilt + direction * 3 + normal * 2], Color("edf5ff"), 1.1)
		draw_line(hilt - normal * 5, hilt + normal * 5, trim, 2.2, true)
		draw_line(hilt + direction * 4, hilt + direction * (length + 2), Color("b3dcfa"), 1.0, true)
	draw_set_transform(Vector2.ZERO)
