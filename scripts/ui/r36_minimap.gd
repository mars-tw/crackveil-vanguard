extends Control

const WORLD := preload("res://scripts/services/loop_world_topology.gd")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
var clock := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	var view := MOBILE.ui_layout_size(get_viewport().get_visible_rect().size)
	var phone := MOBILE.layout_tier(view) == MOBILE.LayoutTier.PHONE
	size = Vector2(68, 88) if phone else Vector2(146, 172)
	position = Vector2(view.x - size.x - 12, 78)
	visible = GameManager.game_running and is_instance_valid(GameManager.player)
	clock += delta
	if clock >= 0.1:
		clock = 0.0
		queue_redraw()

func _point(world_position: Vector2, center: Vector2, radius: float) -> Vector2:
	var canonical := WORLD.canonical(world_position)
	return center + canonical / (WORLD.PERIOD * 0.5) * radius

func _draw() -> void:
	if not visible or not is_instance_valid(GameManager.player):
		return
	var center := Vector2(size.x * 0.5, size.x * 0.5)
	var radius := size.x * 0.43
	draw_circle(center, radius + 4, Color(0.015, 0.025, 0.055, 0.88))
	draw_arc(center, radius + 4, 0, TAU, 40, Color("aebfcd"), 1.5, true)
	var points := WORLD.ring_points()
	for index in range(points.size()):
		var a := _point(points[index], center, radius)
		var b := _point(points[(index + 1) % points.size()], center, radius)
		draw_line(a, b, Color(0.89, 0.72, 0.40, 0.64), 2, true)
		draw_circle(a, 3, Color("efce89"))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.get("is_active") == true and (enemy.get("is_boss") == true or enemy.get("is_elite") == true):
			draw_circle(_point(enemy.global_position, center, radius), 4 if enemy.get("is_boss") else 2.5, Color("ff8088"))
	draw_circle(_point(GameManager.player.global_position, center, radius), 4, Color("a0fff2"))
	var topology := GameManager.arena.get_node_or_null("LoopWorldTopology") if is_instance_valid(GameManager.arena) else null
	if topology != null:
		var name := str(topology.get_debug_state().get("area_name", "環狀世界"))
		var background := GameManager.arena.get_node_or_null("Background")
		if background != null and background.has_method("get_landmarks"):
			var landmarks: Array = background.get_landmarks()
			var id := int(topology.get_debug_state().get("nearest_landmark", 0))
			if id < landmarks.size():
				name = str(landmarks[id].get("name", name))
		draw_string(get_theme_default_font(), Vector2(4, size.x + 16), name, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 11, Color("e3ecf7"))
