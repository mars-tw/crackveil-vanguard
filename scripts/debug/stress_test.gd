extends Node

const ENEMY_COUNT := 150
const PROJECTILE_COUNT := 100
const START_FRAME := 10
const END_FRAME := 420
const MAX_ENEMY_REFILL_PER_FRAME := 24
const MAX_PROJECTILE_REFILL_PER_FRAME := 8

var arena: Node = null
var squad_manager: Node = null
var leader: Node2D = null
var frame_count: int = 0
var initialized: bool = false
var measured_frames: int = 0
var enemy_spawn_counter: int = 0
var projectile_spawn_counter: int = 0
var frame_times_ms: Array[float] = []
var last_frame_tick_usec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	arena = load("res://scenes/arena/Arena.tscn").instantiate()
	add_child(arena)


func _process(_delta: float) -> void:
	frame_count += 1

	if not initialized and frame_count >= START_FRAME:
		_initialize_stress()

	if initialized:
		_record_wall_frame_time()
		_keep_run_unpaused()
		_refill_enemies()
		_refill_projectiles()

	if frame_count >= END_FRAME:
		_finish_stress()


func _initialize_stress() -> void:
	initialized = true
	squad_manager = arena.get_node_or_null("SquadManager")
	leader = squad_manager.get("leader") if squad_manager != null else null
	if leader == null or not is_instance_valid(leader):
		_fail("leader not found")
		return

	var spawner := arena.get_node_or_null("EnemySpawner")
	if spawner != null:
		spawner.set_process(false)

	_prepare_heroes_for_stress()
	GameManager.xp_required = 99999999
	GameManager.waiting_for_upgrade = false
	GameManager.game_running = true
	EntityFactory.reset_debug_counters()

	_refill_enemies(true)
	_refill_projectiles(true)
	_spawn_initial_vfx()
	frame_times_ms.clear()
	measured_frames = 0
	last_frame_tick_usec = Time.get_ticks_usec()
	print("STRESS_INIT enemies=%d projectiles=%d" % [
		EntityFactory.get_enemy_live_count(),
		EntityFactory.get_pool_live_count("projectile")
	])


func _prepare_heroes_for_stress() -> void:
	var members: Array = []
	if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("get_members"):
		members = squad_manager.get_members()

	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		member.set("max_hp", 999999.0)
		member.set("current_hp", 999999.0)
		member.set("invulnerability_time", 0.08)
		member.set("invulnerability_timer", 0.0)
		member.set("pickup_radius", 460.0)


func _keep_run_unpaused() -> void:
	if get_tree().paused:
		get_tree().paused = false
	GameManager.waiting_for_upgrade = false
	GameManager.manual_paused = false
	GameManager.is_game_over = false
	GameManager.game_running = true


func _refill_enemies(fill_all: bool = false) -> void:
	var live_count := EntityFactory.get_enemy_live_count()
	var missing: int = max(0, ENEMY_COUNT - live_count)
	var spawn_count: int = missing if fill_all else min(missing, MAX_ENEMY_REFILL_PER_FRAME)
	for _index in range(spawn_count):
		_spawn_enemy_for_stress()


func _spawn_enemy_for_stress() -> void:
	var type_index := enemy_spawn_counter % 10
	var enemy_id := "stress_normal"
	var config := _normal_enemy_config()
	if type_index in [3, 7]:
		enemy_id = "stress_fast"
		config = _fast_enemy_config()
	elif type_index == 9:
		enemy_id = "stress_tank"
		config = _tank_enemy_config()

	var center := _combat_center()
	var angle := randf() * TAU
	var distance := randf_range(120.0, 320.0)
	var jitter := Vector2(randf_range(-26.0, 26.0), randf_range(-26.0, 26.0))
	EntityFactory.spawn_enemy(enemy_id, config, center + Vector2.RIGHT.rotated(angle) * distance + jitter)
	enemy_spawn_counter += 1


func _refill_projectiles(fill_all: bool = false) -> void:
	var live_projectiles := EntityFactory.get_pool_live_count("projectile")
	var missing: int = max(0, PROJECTILE_COUNT - live_projectiles)
	var spawn_count: int = missing if fill_all else min(missing, MAX_PROJECTILE_REFILL_PER_FRAME)
	for _index in range(spawn_count):
		_spawn_projectile_for_stress()


func _spawn_projectile_for_stress() -> void:
	var target := _pick_projectile_target()
	var center := _combat_center()
	var target_position := center + Vector2(randf_range(-180.0, 180.0), randf_range(-120.0, 120.0))
	if target != null and is_instance_valid(target):
		target_position = target.global_position

	var angle := randf() * TAU
	var origin := target_position + Vector2.RIGHT.rotated(angle) * randf_range(140.0, 260.0)
	var direction := (target_position - origin).normalized().rotated(randf_range(-0.16, 0.16))
	EntityFactory.spawn_projectile(origin, direction, _stress_projectile_stats(), leader)
	projectile_spawn_counter += 1


func _pick_projectile_target() -> Node2D:
	var candidates: Array[Node2D] = EntityFactory.get_enemies_in_radius(_combat_center(), 760.0)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


func _spawn_initial_vfx() -> void:
	for index in range(60):
		var position := _combat_center() + Vector2(randf_range(-220.0, 220.0), randf_range(-160.0, 160.0))
		EntityFactory.spawn_damage_number(index, position, Color(1.0, 0.9, 0.4))
		EntityFactory.spawn_death_burst(position + Vector2(0.0, 18.0), Color(0.7, 0.9, 1.0))


func _normal_enemy_config() -> Dictionary:
	return {
		"max_hp": 30.0,
		"speed": 88.0,
		"damage": 6.0,
		"xp": 1,
		"gold": 1,
		"radius": 13.0,
		"color": Color(0.72, 0.28, 0.36),
		"sprite_path": "res://assets/sprites/enemy_grunt.png",
		"sprite_scale": 1.3,
		"attack_cooldown": 0.75
	}


func _fast_enemy_config() -> Dictionary:
	return {
		"max_hp": 22.0,
		"speed": 142.0,
		"damage": 4.0,
		"xp": 1,
		"gold": 1,
		"radius": 10.0,
		"color": Color(0.95, 0.72, 0.26),
		"sprite_path": "res://assets/sprites/enemy_fast.png",
		"sprite_scale": 1.25,
		"attack_cooldown": 0.55
	}


func _tank_enemy_config() -> Dictionary:
	return {
		"max_hp": 85.0,
		"speed": 54.0,
		"damage": 12.0,
		"xp": 3,
		"gold": 2,
		"radius": 20.0,
		"color": Color(0.48, 0.36, 0.76),
		"sprite_path": "res://assets/sprites/enemy_tank.png",
		"sprite_scale": 1.36,
		"attack_cooldown": 1.05
	}


func _stress_projectile_stats() -> Dictionary:
	return {
		"damage": 8.0,
		"range": 1100.0,
		"projectile_speed": 430.0,
		"projectile_radius": 5.5,
		"pierce": 1,
		"color": Color(0.62, 0.93, 1.0),
		"projectile_sprite_path": "res://assets/sprites/proj_bullet.png",
		"sprite_scale": 1.35
	}


func _combat_center() -> Vector2:
	if leader != null and is_instance_valid(leader):
		return leader.global_position
	return Vector2.ZERO


func _finish_stress() -> void:
	var stats := _calculate_frame_stats()
	var pool_stats: Dictionary = EntityFactory.get_pool_stats()
	var enemy_queries := int(pool_stats.get("enemy_queries", 0))
	var enemy_group_scans := int(pool_stats.get("enemy_group_scans", 0))
	var queries_per_frame: float = float(enemy_queries) / max(1.0, float(measured_frames))
	var group_scans_per_frame: float = float(enemy_group_scans) / max(1.0, float(measured_frames))

	print("STRESS_RESULT enemies=%d projectiles=%d measured_frames=%d avg_ms=%.3f p95_ms=%.3f max_ms=%.3f avg_fps=%.2f p95_fps=%.2f min_fps=%.2f" % [
		EntityFactory.get_enemy_live_count(),
		int(pool_stats.get("projectile", {}).get("live", 0)),
		measured_frames,
		float(stats.get("avg_ms", 0.0)),
		float(stats.get("p95_ms", 0.0)),
		float(stats.get("max_ms", 0.0)),
		float(stats.get("avg_fps", 0.0)),
		float(stats.get("p95_fps", 0.0)),
		float(stats.get("min_fps", 0.0))
	])
	print("STRESS_COUNTERS enemy_spatial_queries=%d queries_per_frame=%.2f enemy_group_scans=%d group_scans_per_frame=%.3f kills=%d gold=%d xp=%d" % [
		enemy_queries,
		queries_per_frame,
		enemy_group_scans,
		group_scans_per_frame,
		GameManager.kills,
		GameManager.gold,
		GameManager.xp
	])
	print("STRESS_POOL_STATS=" + JSON.stringify(pool_stats))

	var validation_error := _validate_pool_stats(pool_stats)
	if validation_error != "":
		_fail(validation_error)
		return

	if float(stats.get("min_fps", 0.0)) < 59.5:
		print("STRESS_PERF_BELOW_60=true")
	else:
		print("STRESS_PERF_BELOW_60=false")

	print("STRESS_PASS")
	get_tree().quit(0)


func _calculate_frame_stats() -> Dictionary:
	if frame_times_ms.is_empty():
		return {
			"avg_ms": 0.0,
			"p95_ms": 0.0,
			"max_ms": 0.0,
			"avg_fps": 0.0,
			"p95_fps": 0.0,
			"min_fps": 0.0
		}

	var total := 0.0
	for value in frame_times_ms:
		total += value

	var sorted: Array[float] = frame_times_ms.duplicate()
	sorted.sort()
	var avg_ms := total / float(frame_times_ms.size())
	var p95_ms := _percentile(sorted, 0.95)
	var max_ms: float = sorted[sorted.size() - 1]
	return {
		"avg_ms": avg_ms,
		"p95_ms": p95_ms,
		"max_ms": max_ms,
		"avg_fps": 1000.0 / max(0.001, avg_ms),
		"p95_fps": 1000.0 / max(0.001, p95_ms),
		"min_fps": 1000.0 / max(0.001, max_ms)
	}


func _record_wall_frame_time() -> void:
	var now_usec := Time.get_ticks_usec()
	if last_frame_tick_usec > 0:
		measured_frames += 1
		frame_times_ms.append(float(now_usec - last_frame_tick_usec) / 1000.0)
	last_frame_tick_usec = now_usec


func _percentile(sorted_values: Array[float], percentile: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := int(ceil(float(sorted_values.size()) * percentile)) - 1
	index = clamp(index, 0, sorted_values.size() - 1)
	return sorted_values[index]


func _validate_pool_stats(pool_stats: Dictionary) -> String:
	for key in pool_stats.keys():
		var entry: Variant = pool_stats[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var pool_entry: Dictionary = entry
		if int(pool_entry.get("exhausted", 0)) > 0:
			return "%s pool exhausted" % key
		if int(pool_entry.get("duplicate_free", 0)) > 0:
			return "%s pool free list has duplicate entries" % key
		if int(pool_entry.get("duplicate_releases", 0)) > 0:
			return "%s pool saw duplicate releases during stress" % key
		if int(pool_entry.get("foreign_releases", 0)) > 0:
			return "%s pool saw foreign releases during stress" % key
	return ""


func _fail(message: String) -> void:
	printerr("STRESS_FAIL: " + message)
	get_tree().quit(1)
