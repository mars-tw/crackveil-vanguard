extends Node

const PERIOD := Vector2(4096.0, 3072.0)
const RING_RADII := Vector2(1400.0, 1000.0)
const LANDMARK_NAMES := ["曜光祭壇", "風暴晶塔", "星門驛站", "靈獸花庭", "帷幕石環", "焰星營地", "霜晶泉眼", "月影鐘樓"]
var timer := 0.0
var rebases := 0
var max_travel := 0.0
var origin := Vector2.ZERO

static func canonical(position: Vector2) -> Vector2:
	return Vector2(fposmod(position.x + PERIOD.x * 0.5, PERIOD.x) - PERIOD.x * 0.5, fposmod(position.y + PERIOD.y * 0.5, PERIOD.y) - PERIOD.y * 0.5)

static func nearest_image(position: Vector2, reference: Vector2) -> Vector2:
	return reference + canonical(position - reference)

static func ring_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		points.append(Vector2(cos(angle) * RING_RADII.x, sin(angle) * RING_RADII.y))
	return points

func _ready() -> void:
	add_to_group("loop_world")

func set_run_origin(position: Vector2) -> void:
	origin = position

func _physics_process(delta: float) -> void:
	if not GameManager.game_running or not is_instance_valid(GameManager.player):
		return
	var player_position: Vector2 = GameManager.player.global_position
	max_travel = maxf(max_travel, player_position.distance_to(origin))
	timer -= delta
	if timer > 0.0:
		return
	timer = 0.10
	var index_dirty := false
	for group in ["enemies", "heroes", "pickups", "equipment_drops", "hazard_zones", "rift_constructs", "companion_pets"]:
		for actor in get_tree().get_nodes_in_group(group):
			if not actor is Node2D or actor == GameManager.player or not is_instance_valid(actor):
				continue
			var mapped := nearest_image(actor.global_position, player_position)
			var shift: Vector2 = mapped - actor.global_position
			if shift.length_squared() < 1.0:
				continue
			if actor.has_method("rebase_world"):
				actor.rebase_world(shift)
			else:
				actor.global_position += shift
			rebases += 1
			index_dirty = index_dirty or group == "enemies"
	for actors in [EntityFactory.active_hazard_zones, EntityFactory.active_rift_constructs]:
		for actor in actors:
			if not is_instance_valid(actor) or not actor is Node2D:
				continue
			var mapped := nearest_image(actor.global_position, player_position)
			if mapped.distance_squared_to(actor.global_position) >= 1.0:
				actor.global_position = mapped
				rebases += 1
	if index_dirty and is_instance_valid(EntityFactory.enemy_spatial_index):
		EntityFactory.enemy_spatial_index._update_enemy_cells()

func get_debug_state() -> Dictionary:
	var position: Vector2 = GameManager.player.global_position if is_instance_valid(GameManager.player) else Vector2.ZERO
	var wrapped := canonical(position)
	var points := ring_points()
	var nearest := 0
	var distance := INF
	for index in range(points.size()):
		var gap := canonical(points[index] - wrapped).length()
		if gap < distance:
			distance = gap
			nearest = index
	return {"period": PERIOD, "player": position, "canonical": wrapped, "area_name": LANDMARK_NAMES[nearest], "nearest_landmark": nearest, "landmark_distance": distance, "rebases": rebases, "max_travel": max_travel, "hard_bounds": false}
