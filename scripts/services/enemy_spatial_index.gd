class_name EnemySpatialIndex
extends Node

@export var cell_size: float = 128.0

var cells: Dictionary = {}
var enemy_cell: Dictionary = {}
var live_enemies: Array[Node2D] = []
var live_count: int = 0
var query_count: int = 0


func _physics_process(_delta: float) -> void:
	_update_enemy_cells()


func reset() -> void:
	cells.clear()
	enemy_cell.clear()
	live_enemies.clear()
	live_count = 0
	query_count = 0


func reset_query_count() -> void:
	query_count = 0


func register(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if live_enemies.has(enemy):
		return

	live_enemies.append(enemy)
	live_count = live_enemies.size()
	var cell := _cell_of(enemy.global_position)
	enemy_cell[enemy.get_instance_id()] = cell
	if not cells.has(cell):
		cells[cell] = []
	cells[cell].append(enemy)


func unregister(enemy: Node2D) -> void:
	if enemy == null:
		return

	live_enemies.erase(enemy)
	live_count = live_enemies.size()
	var instance_id := enemy.get_instance_id()
	var old_cell: Vector2i = enemy_cell.get(instance_id, Vector2i(2147483647, 2147483647))
	if cells.has(old_cell):
		cells[old_cell].erase(enemy)
		if cells[old_cell].is_empty():
			cells.erase(old_cell)
	enemy_cell.erase(instance_id)


func find_nearest(center: Vector2, max_range: float) -> Node2D:
	query_count += 1
	var nearest: Node2D = null
	var best_distance_squared: float = max_range * max_range

	var radius_cells: int = int(ceil(max_range / cell_size))
	var center_cell := _cell_of(center)
	for x in range(center_cell.x - radius_cells, center_cell.x + radius_cells + 1):
		for y in range(center_cell.y - radius_cells, center_cell.y + radius_cells + 1):
			var bucket: Array = cells.get(Vector2i(x, y), [])
			for enemy in bucket:
				if enemy == null or not is_instance_valid(enemy):
					continue
				var active_value: Variant = enemy.get("is_active")
				if active_value != null and not bool(active_value):
					continue
				var distance_squared: float = center.distance_squared_to(enemy.global_position)
				if distance_squared < best_distance_squared:
					best_distance_squared = distance_squared
					nearest = enemy

	return nearest


func get_enemies_in_radius(center: Vector2, radius: float) -> Array[Node2D]:
	query_count += 1
	var result: Array[Node2D] = []
	var radius_squared: float = radius * radius
	var min_cell := _cell_of(center - Vector2(radius, radius))
	var max_cell := _cell_of(center + Vector2(radius, radius))

	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var bucket: Array = cells.get(Vector2i(x, y), [])
			for enemy in bucket:
				if enemy == null or not is_instance_valid(enemy):
					continue
				var active_value: Variant = enemy.get("is_active")
				if active_value != null and not bool(active_value):
					continue
				if center.distance_squared_to(enemy.global_position) <= radius_squared:
					result.append(enemy)

	return result


func _update_enemy_cells() -> void:
	var compacted: Array[Node2D] = []
	for enemy in live_enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var active_value: Variant = enemy.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		compacted.append(enemy)
		var instance_id := enemy.get_instance_id()
		var old_cell: Vector2i = enemy_cell.get(instance_id, Vector2i(2147483647, 2147483647))
		var new_cell := _cell_of(enemy.global_position)
		if old_cell == new_cell:
			continue
		if cells.has(old_cell):
			cells[old_cell].erase(enemy)
			if cells[old_cell].is_empty():
				cells.erase(old_cell)
		if not cells.has(new_cell):
			cells[new_cell] = []
		cells[new_cell].append(enemy)
		enemy_cell[instance_id] = new_cell

	live_enemies = compacted
	live_count = live_enemies.size()


func _cell_of(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.y / cell_size))
