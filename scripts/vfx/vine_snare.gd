extends Node2D

# R29: second-stage elites (翠晶花園) root the ground. A green ring is warned for
# WARN_SECONDS, then for ACTIVE_SECONDS any hero standing inside is slowed and
# takes a small tick. Ring formation pulls members together, scatter spreads
# them out: the snare rewards spreading, so the garden asks a different
# positioning question than the first stage.
const WARN_SECONDS := 1.1
const ACTIVE_SECONDS := 2.4
const RADIUS := 96.0
const SLOW_STRENGTH := 0.45
const TICK_SECONDS := 0.4
const TICK_DAMAGE := 3.0

var age := 0.0
var tick := 0.0
var hits := 0

static func spawn(parent: Node, at: Vector2) -> Node2D:
	var snare: Node2D = load("res://scripts/vfx/vine_snare.gd").new()
	snare.global_position = at
	snare.z_index = 4
	parent.add_child(snare)
	return snare

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	age += delta
	if age >= WARN_SECONDS + ACTIVE_SECONDS:
		queue_free()
		return
	if age >= WARN_SECONDS:
		tick -= delta
		if tick <= 0.0:
			tick = TICK_SECONDS
			_apply_tick()
	queue_redraw()

func _apply_tick() -> void:
	for hero in get_tree().get_nodes_in_group("heroes"):
		if not hero is Node2D or hero.get("is_alive") == false:
			continue
		if hero.global_position.distance_squared_to(global_position) > RADIUS * RADIUS:
			continue
		if hero.has_method("apply_movement_slow"):
			hero.apply_movement_slow(TICK_SECONDS + 0.1, SLOW_STRENGTH)
		if hero.has_method("take_damage"):
			hero.take_damage(TICK_DAMAGE, global_position)
		hits += 1

func _draw() -> void:
	var green := Color("8fe39a")
	if age < WARN_SECONDS:
		var left := clampf(1.0 - age / WARN_SECONDS, 0.0, 1.0)
		draw_circle(Vector2.ZERO, RADIUS, Color(green, 0.12))
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color("101b30", 0.85), 7.0, true)
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(green, 0.95), 3.0, true)
		draw_arc(Vector2.ZERO, RADIUS + 10.0, -PI * 0.5, -PI * 0.5 + TAU * left, 40, Color(green, 0.9), 4.0, true)
	else:
		var fade := clampf(1.0 - (age - WARN_SECONDS) / ACTIVE_SECONDS, 0.25, 1.0)
		draw_circle(Vector2.ZERO, RADIUS, Color("3f8a4a", 0.32 * fade))
		for i in range(8):
			var a := TAU * float(i) / 8.0 + age * 0.6
			var from := Vector2.from_angle(a) * RADIUS * 0.25
			var to := Vector2.from_angle(a + 0.5) * RADIUS * 0.95
			draw_line(from, to, Color("101b30", 0.7 * fade), 6.0, true)
			draw_line(from, to, Color(green, 0.9 * fade), 3.0, true)
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(green, 0.9 * fade), 3.0, true)
