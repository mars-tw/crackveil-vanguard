extends Node2D

@export var cell_size: float = 96.0
@export var background_color: Color = Color(0.035, 0.043, 0.052)
@export var grid_color: Color = Color(0.12, 0.15, 0.17, 0.45)
@export var crack_color: Color = Color(0.18, 0.34, 0.42, 0.42)

var last_center_cell: Vector2i = Vector2i(999999, 999999)


func _process(_delta: float) -> void:
	var center := _get_center()
	var center_cell := Vector2i(floori(center.x / (cell_size * 0.5)), floori(center.y / (cell_size * 0.5)))
	if center_cell != last_center_cell:
		last_center_cell = center_cell
		queue_redraw()


func _draw() -> void:
	var center := _get_center()

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)

	var draw_size := viewport_size * 2.4
	var rect := Rect2(center - draw_size * 0.5, draw_size)
	draw_rect(rect, background_color, true)

	var min_x := int(floor(rect.position.x / cell_size)) - 1
	var max_x := int(ceil(rect.end.x / cell_size)) + 1
	var min_y := int(floor(rect.position.y / cell_size)) - 1
	var max_y := int(ceil(rect.end.y / cell_size)) + 1

	for x in range(min_x, max_x + 1):
		var world_x := float(x) * cell_size
		draw_line(Vector2(world_x, rect.position.y), Vector2(world_x, rect.end.y), grid_color, 1.0)

	for y in range(min_y, max_y + 1):
		var world_y := float(y) * cell_size
		draw_line(Vector2(rect.position.x, world_y), Vector2(rect.end.x, world_y), grid_color, 1.0)

	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			var h := _hash_cell(x, y)
			if h < 0.43:
				continue
			var base := Vector2(float(x) * cell_size, float(y) * cell_size)
			var start := base + Vector2(cell_size * _hash_cell(x + 17, y), cell_size * _hash_cell(x, y + 31))
			var mid := base + Vector2(cell_size * _hash_cell(x - 11, y + 5), cell_size * _hash_cell(x + 3, y - 13))
			var finish := base + Vector2(cell_size * _hash_cell(x + 29, y - 7), cell_size * _hash_cell(x - 19, y + 23))
			draw_line(start, mid, crack_color, 2.0)
			draw_line(mid, finish, crack_color.darkened(0.2), 1.5)


func _hash_cell(x: int, y: int) -> float:
	var value := sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
	return value - floor(value)


func _get_center() -> Vector2:
	if GameManager.player != null and is_instance_valid(GameManager.player):
		return GameManager.player.global_position
	return Vector2.ZERO
