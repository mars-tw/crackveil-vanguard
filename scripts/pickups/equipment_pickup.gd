extends Node2D

const CATALOG := preload("res://scripts/services/equipment_catalog.gd")
const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")

var director: Node = null
var item: Dictionary = {}
var age: float = 0.0
var animation_timer: float = 0.0
var start_angle: float = 0.0
var drift: Vector2 = Vector2.ZERO
var magnetized: bool = false
var collected: bool = false
var rarity_color := Color.WHITE
var name_label: Label = null
var glow: Sprite2D = null
var shadow: Sprite2D = null


func setup(loot_director: Node, equipment: Dictionary, angle: float = 0.0) -> void:
	director = loot_director
	item = equipment.duplicate(true)
	rarity_color = item.get("color", Color.WHITE)
	start_angle = angle
	drift = Vector2.RIGHT.rotated(angle) * 95.0
	z_index = 4
	add_to_group("equipment_drops")
	shadow = Sprite2D.new()
	shadow.texture = ART_RESOURCES.get_ellipse_shadow()
	shadow.modulate = Color(0, 0, 0, 0.66)
	shadow.position.y = 7.0
	shadow.z_index = -2
	ART_RESOURCES.fit_sprite(shadow, shadow.texture, 37.0)
	add_child(shadow)
	glow = Sprite2D.new()
	glow.texture = ART_RESOURCES.get_radial_glow()
	glow.material = ART_RESOURCES.get_additive_material()
	glow.modulate = Color(rarity_color, 0.3)
	glow.z_index = -1
	ART_RESOURCES.fit_sprite(glow, glow.texture, 67.0)
	add_child(glow)
	name_label = Label.new()
	name_label.text = "%s · %s" % [str(item.get("rarity_name", "")), str(item.get("name", ""))]
	name_label.position = Vector2(-110.0, 14.0)
	name_label.size = Vector2(220.0, 28.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", rarity_color.lightened(0.18))
	name_label.add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.04))
	name_label.add_theme_constant_override("outline_size", 4)
	add_child(name_label)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if collected or item.is_empty():
		return
	age += delta
	animation_timer += delta
	if age < 0.32:
		global_position += drift * delta
		drift = drift.move_toward(Vector2.ZERO, 330.0 * delta)
	else:
		var collector := _find_collector()
		if collector != null:
			var distance := global_position.distance_to(collector.global_position)
			var radius := maxf(145.0, float(collector.get_pickup_radius()) + 42.0) if collector.has_method("get_pickup_radius") else 145.0
			if distance <= radius:
				magnetized = true
			if magnetized:
				global_position = global_position.move_toward(collector.global_position, (390.0 + maxf(0.0, radius - distance) * 5.0) * delta)
				if global_position.distance_squared_to(collector.global_position) <= 24.0 * 24.0:
					collect_now()
	# Ten maximum drops, capped at ten redraws/sec while the world is running.
	if animation_timer >= 0.1:
		animation_timer = 0.0
		if glow != null:
			glow.modulate.a = 0.24 + sin(age * 4.0 + start_angle) * 0.06
		queue_redraw()


func _find_collector() -> Node2D:
	var members: Array = []
	if GameManager.squad_manager != null and is_instance_valid(GameManager.squad_manager):
		members = GameManager.squad_manager.get_members()
	elif GameManager.player != null and is_instance_valid(GameManager.player):
		members = [GameManager.player]
	var nearest: Node2D = null
	var nearest_distance := INF
	for member in members:
		if member == null or not is_instance_valid(member) or member.get("is_alive") == false:
			continue
		var distance: float = global_position.distance_squared_to(member.global_position)
		if distance < nearest_distance:
			nearest = member as Node2D
			nearest_distance = distance
	return nearest


func collect_now() -> void:
	if collected:
		return
	collected = true
	remove_from_group("equipment_drops")
	if director != null and is_instance_valid(director):
		director.collect_item(item)
	queue_free()


func _draw() -> void:
	if item.is_empty():
		return
	var tier := int(item.get("rarity", 0))
	var beam_height := 48.0 + float(tier) * 19.0
	var beam_width := 4.0 + float(tier) * 2.0
	var beam_points := PackedVector2Array([Vector2(-beam_width, 2), Vector2(-beam_width * 0.3, -beam_height), Vector2(beam_width * 0.3, -beam_height), Vector2(beam_width, 2)])
	draw_polygon(beam_points, PackedColorArray([Color(rarity_color, 0.40), Color(rarity_color, 0), Color(rarity_color, 0), Color(rarity_color, 0.40)]))
	draw_arc(Vector2.ZERO, 17.0 + sin(age * 3.0) * 1.2, 0, TAU, 24, Color(rarity_color, 0.7), 1.4, true)
	var bob := Vector2(0, -7.0 - sin(age * 4.0 + start_angle) * 2.0)
	draw_circle(bob, 12.0, Color(0.02, 0.04, 0.08, 0.98))
	draw_arc(bob, 12.0, 0, TAU, 20, rarity_color, 2.0, true)
	match str(item.get("slot", "core")):
		"core":
			var crystal := PackedVector2Array([bob + Vector2(0, -9), bob + Vector2(7, 0), bob + Vector2(0, 9), bob + Vector2(-7, 0)])
			draw_colored_polygon(crystal, rarity_color)
			draw_line(bob + Vector2(0, -6), bob + Vector2(0, 5), rarity_color.lightened(0.6), 2.0, true)
		"guard":
			var shield := PackedVector2Array([bob + Vector2(-7, -7), bob + Vector2(7, -7), bob + Vector2(6, 4), bob + Vector2(0, 10), bob + Vector2(-6, 4)])
			draw_colored_polygon(shield, rarity_color)
			draw_line(bob + Vector2(0, -4), bob + Vector2(0, 6), rarity_color.lightened(0.6), 2.0, true)
		"boots":
			var boot := PackedVector2Array([bob + Vector2(-5, -7), bob + Vector2(3, -7), bob + Vector2(3, 2), bob + Vector2(8, 4), bob + Vector2(8, 8), bob + Vector2(-5, 8)])
			draw_colored_polygon(boot, rarity_color)
			draw_line(bob + Vector2(-3, -3), bob + Vector2(1, -3), rarity_color.lightened(0.6), 2.0, true)
	for index in range(tier + 1):
		draw_circle(Vector2((float(index) - float(tier) * 0.5) * 6.0, -26.0), 1.8, rarity_color.lightened(0.35))
