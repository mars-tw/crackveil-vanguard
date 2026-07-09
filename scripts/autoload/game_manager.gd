extends Node

signal stats_changed(stats: Dictionary)
signal level_up_requested(options: Array)
signal game_over_requested(summary: Dictionary)
signal pause_changed(is_paused: bool)

const PLAYER_UPGRADE_POOL: Array = [
	{
		"id": "move_speed",
		"name": "疾步校準",
		"description": "+20 移動速度"
	},
	{
		"id": "max_hp",
		"name": "裂隙護甲",
		"description": "+20 最大 HP，並回復 20 HP"
	},
	{
		"id": "pickup_radius",
		"name": "回收磁場",
		"description": "+24 拾取範圍"
	}
]

var arena: Node = null
var player: Node = null
var squad_manager: Node = null

var game_running: bool = false
var is_game_over: bool = false
var waiting_for_upgrade: bool = false
var manual_paused: bool = false

var elapsed_time: float = 0.0
var kills: int = 0
var gold: int = 0
var level: int = 1
var xp: int = 0
var xp_required: int = 12
var stats_timer: float = 0.0
var touch_move_vector: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_run(new_arena: Node, new_player: Node, new_squad_manager: Node = null, reset_player: bool = true) -> void:
	arena = new_arena
	player = new_player
	squad_manager = new_squad_manager
	game_running = true
	is_game_over = false
	waiting_for_upgrade = false
	manual_paused = false
	elapsed_time = 0.0
	kills = 0
	gold = 0
	level = 1
	xp = 0
	xp_required = 12
	stats_timer = 0.0
	touch_move_vector = Vector2.ZERO
	get_tree().paused = false

	if reset_player and player != null and player.has_method("reset_for_run"):
		player.reset_for_run()

	emit_stats()
	pause_changed.emit(false)


func _process(delta: float) -> void:
	if game_running and not get_tree().paused:
		elapsed_time += delta
		stats_timer -= delta
		if stats_timer <= 0.0:
			stats_timer = 0.1
			emit_stats()


func emit_stats() -> void:
	stats_changed.emit(get_stats())


func get_stats() -> Dictionary:
	var hp_value := 0.0
	var max_hp_value := 0.0
	if player != null and is_instance_valid(player):
		if player.has_method("get_current_hp"):
			hp_value = player.get_current_hp()
		if player.has_method("get_max_hp"):
			max_hp_value = player.get_max_hp()

	return {
		"hp": hp_value,
		"max_hp": max_hp_value,
		"elapsed_time": elapsed_time,
		"kills": kills,
		"gold": gold,
		"level": level,
		"xp": xp,
		"xp_required": xp_required,
		"game_running": game_running,
		"manual_paused": manual_paused,
		"waiting_for_upgrade": waiting_for_upgrade,
		"is_game_over": is_game_over
	}


func add_kill(amount: int = 1) -> void:
	if not game_running:
		return
	kills += amount
	emit_stats()


func add_gold(amount: int) -> void:
	if not game_running:
		return
	gold += amount
	emit_stats()


func add_xp(amount: int) -> void:
	# 允許連續升級，但一次只開一個升級選單，避免 UI 與暫停狀態競態。
	if not game_running or is_game_over:
		return

	xp += amount
	while xp >= xp_required and not waiting_for_upgrade:
		xp -= xp_required
		level += 1
		xp_required = int(round(float(xp_required) * 1.25 + 5.0))
		_request_level_up()

	emit_stats()


func _request_level_up() -> void:
	waiting_for_upgrade = true
	get_tree().paused = true
	emit_stats()
	level_up_requested.emit(_build_upgrade_choices())


func _build_upgrade_choices() -> Array:
	var pool: Array = PLAYER_UPGRADE_POOL.duplicate(true)
	if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("build_upgrade_pool"):
		pool = squad_manager.build_upgrade_pool(pool)
	elif player != null and is_instance_valid(player) and player.has_method("build_upgrade_pool"):
		pool = player.build_upgrade_pool(pool)

	pool.shuffle()
	var choices: Array = []
	var choice_count: int = min(3, pool.size())
	for index in range(choice_count):
		choices.append(pool[index])
	return choices


func apply_upgrade(upgrade: Dictionary) -> void:
	if not waiting_for_upgrade or is_game_over:
		return

	if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("apply_upgrade"):
		squad_manager.apply_upgrade(upgrade)
	elif player != null and is_instance_valid(player) and player.has_method("apply_upgrade"):
		player.apply_upgrade(upgrade)

	waiting_for_upgrade = false

	if xp >= xp_required:
		_request_level_up()
	else:
		get_tree().paused = manual_paused
		emit_stats()


func toggle_pause() -> void:
	if waiting_for_upgrade or is_game_over or not game_running:
		return
	set_manual_pause(not manual_paused)


func set_manual_pause(value: bool) -> void:
	if waiting_for_upgrade or is_game_over or not game_running:
		return
	manual_paused = value
	get_tree().paused = value
	pause_changed.emit(value)
	emit_stats()


func set_touch_move_vector(direction: Vector2) -> void:
	touch_move_vector = direction.limit_length(1.0)


func get_touch_move_vector() -> Vector2:
	return touch_move_vector


func player_died() -> void:
	if is_game_over:
		return

	var dead_player := player
	is_game_over = true
	game_running = false
	waiting_for_upgrade = false
	manual_paused = false
	if dead_player != null and is_instance_valid(dead_player):
		dead_player.set_process(false)
		dead_player.set_physics_process(false)
	player = null
	get_tree().paused = true
	emit_stats()
	game_over_requested.emit({
		"elapsed_time": elapsed_time,
		"kills": kills,
		"gold": gold,
		"level": level
	})


func format_time(seconds_value: float) -> String:
	var total_seconds := int(floor(seconds_value))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
