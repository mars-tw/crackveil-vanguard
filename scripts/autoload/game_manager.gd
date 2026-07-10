extends Node

signal stats_changed(stats: Dictionary)
signal level_up_requested(options: Array)
signal game_over_requested(summary: Dictionary)
signal pause_changed(is_paused: bool)
signal shop_requested(options: Array)
signal stage_victory_requested(summary: Dictionary)

const PLAYER_UPGRADE_POOL: Array = [
	{
		"id": "move_speed",
		"name": "疾步校準",
		"description": "+20 移動速度",
		"weight": 1,
		"max_level": 6
	},
	{
		"id": "max_hp",
		"name": "裂隙護甲",
		"description": "+20 最大 HP，並回復 20 HP",
		"weight": 1,
		"max_level": 5
	},
	{
		"id": "pickup_radius",
		"name": "回收磁場",
		"description": "+24 拾取範圍",
		"weight": 1,
		"max_level": 5
	}
]

var arena: Node = null
var player: Node = null
var squad_manager: Node = null

var game_running: bool = false
var is_game_over: bool = false
var waiting_for_upgrade: bool = false
var waiting_for_shop: bool = false
var stage_victory_pending: bool = false
var manual_paused: bool = false

var elapsed_time: float = 0.0
var kills: int = 0
var gold: int = 0
var level: int = 1
var xp: int = 0
var xp_required: int = 12
var stats_timer: float = 0.0
var touch_move_vector: Vector2 = Vector2.ZERO
var upgrade_counts: Dictionary = {}
var elites_spawned: int = 0
var elites_killed: int = 0
var elite_spawn_times: Array[float] = []
var elite_kill_times: Array[float] = []
var boss_active: bool = false
var boss_spawned: bool = false
var boss_killed: bool = false
var boss_spawn_time: float = -1.0
var boss_kill_time: float = -1.0
var boss_phase_two_time: float = -1.0
var next_shop_time: float = 90.0
var forced_run_seed: int = 0
var magnetic_reclaim_enabled: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_run(new_arena: Node, new_player: Node, new_squad_manager: Node = null, reset_player: bool = true) -> void:
	arena = new_arena
	player = new_player
	squad_manager = new_squad_manager
	game_running = true
	is_game_over = false
	waiting_for_upgrade = false
	waiting_for_shop = false
	stage_victory_pending = false
	manual_paused = false
	elapsed_time = 0.0
	kills = 0
	gold = 0
	level = 1
	xp = 0
	xp_required = 12
	stats_timer = 0.0
	touch_move_vector = Vector2.ZERO
	upgrade_counts.clear()
	elites_spawned = 0
	elites_killed = 0
	elite_spawn_times.clear()
	elite_kill_times.clear()
	boss_active = false
	boss_spawned = false
	boss_killed = false
	boss_spawn_time = -1.0
	boss_kill_time = -1.0
	boss_phase_two_time = -1.0
	next_shop_time = 90.0
	magnetic_reclaim_enabled = false
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
		if elapsed_time >= next_shop_time:
			next_shop_time += 90.0
			_request_shop()


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
		"waiting_for_shop": waiting_for_shop,
		"magnetic_reclaim_enabled": magnetic_reclaim_enabled,
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


func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if gold < amount:
		return false
	gold -= amount
	emit_stats()
	return true


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

	var filtered: Array = []
	for option in pool:
		if _is_upgrade_available(option):
			filtered.append(option)
	return _pick_weighted_choices(filtered, 3)


func apply_upgrade(upgrade: Dictionary) -> void:
	if not waiting_for_upgrade or is_game_over:
		return

	_register_upgrade_pick(upgrade)
	if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("apply_upgrade"):
		squad_manager.apply_upgrade(upgrade)
	elif player != null and is_instance_valid(player) and player.has_method("apply_upgrade"):
		player.apply_upgrade(upgrade)

	waiting_for_upgrade = false

	if xp >= xp_required:
		_request_level_up()
	elif randf() < 0.1 and not waiting_for_shop:
		_request_shop()
	else:
		get_tree().paused = manual_paused
		emit_stats()


func _is_upgrade_available(upgrade: Dictionary) -> bool:
	var max_level := int(upgrade.get("max_level", 0))
	if max_level <= 0:
		return true
	return int(upgrade_counts.get(_upgrade_level_key(upgrade), 0)) < max_level


func _register_upgrade_pick(upgrade: Dictionary) -> void:
	var max_level := int(upgrade.get("max_level", 0))
	if max_level <= 0:
		return
	var key := _upgrade_level_key(upgrade)
	upgrade_counts[key] = int(upgrade_counts.get(key, 0)) + 1


func _upgrade_level_key(upgrade: Dictionary) -> String:
	if upgrade.has("level_key"):
		return str(upgrade.get("level_key"))
	return "%s|%s|%s|%s" % [
		str(upgrade.get("id", "")),
		str(upgrade.get("hero_id", "")),
		str(upgrade.get("weapon_id", "")),
		str(upgrade.get("upgrade_kind", ""))
	]


func _pick_weighted_choices(pool: Array, count: int) -> Array:
	var candidates := pool.duplicate(true)
	var choices: Array = []
	while choices.size() < count and not candidates.is_empty():
		var total_weight := 0.0
		for option in candidates:
			total_weight += max(0.0, float(option.get("weight", 1.0)))
		if total_weight <= 0.0:
			break

		var roll := randf() * total_weight
		var cursor := 0.0
		var selected_index := 0
		for index in range(candidates.size()):
			cursor += max(0.0, float(candidates[index].get("weight", 1.0)))
			if roll <= cursor:
				selected_index = index
				break
		choices.append(candidates[selected_index])
		candidates.remove_at(selected_index)
	return choices


func _request_shop() -> void:
	if waiting_for_upgrade or waiting_for_shop or stage_victory_pending or is_game_over or not game_running:
		return
	waiting_for_shop = true
	get_tree().paused = true
	emit_stats()
	shop_requested.emit(_build_shop_options())


func _build_shop_options() -> Array:
	var options := [
		_shop_option({
			"id": "heal_30",
			"name": "裂隙急救",
			"description": "花 8 金幣，回復全隊 30 HP",
			"cost": 8
		}),
		_shop_option({
			"id": "random_qualitative",
			"name": "偏壓改裝",
			"description": "花 18 金幣，隨機取得一張質變升級",
			"cost": 18
		}),
		_shop_option({
			"id": "temporary_shield",
			"name": "帷幕護盾",
			"description": "花 12 金幣，獲得 30 點暫時護盾",
			"cost": 12
		})
	]
	return options


func _shop_option(option: Dictionary) -> Dictionary:
	var option_id := str(option.get("id", ""))
	var reason := _shop_option_disabled_reason(option_id)
	option["enabled"] = reason == ""
	option["disabled_reason"] = reason
	return option


func _shop_option_disabled_reason(option_id: String) -> String:
	match option_id:
		"heal_30":
			if squad_manager == null or not is_instance_valid(squad_manager) or not squad_manager.has_method("can_heal_members") or not squad_manager.can_heal_members():
				return "全隊已滿血"
		"random_qualitative":
			if squad_manager == null or not is_instance_valid(squad_manager) or not squad_manager.has_method("has_available_qualitative_upgrade") or not squad_manager.has_available_qualitative_upgrade():
				return "沒有可套用的質變"
		"temporary_shield":
			if squad_manager == null or not is_instance_valid(squad_manager) or not squad_manager.has_method("get_member_count") or squad_manager.get_member_count() <= 0:
				return "沒有存活隊員"
	return ""


func _is_shop_option_meaningful(option_id: String) -> bool:
	return _shop_option_disabled_reason(option_id) == ""


func apply_shop_purchase(option: Dictionary) -> void:
	if not waiting_for_shop or is_game_over:
		return
	var option_id := str(option.get("id", ""))
	if option_id == "skip":
		_close_shop()
		return

	if not _is_shop_option_meaningful(option_id):
		emit_stats()
		return

	var cost := int(option.get("cost", 0))
	if gold < cost:
		emit_stats()
		return

	var success := false
	match option_id:
		"heal_30":
			success = squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("heal_members") and squad_manager.heal_members(30.0)
		"random_qualitative":
			success = squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("apply_random_qualitative_upgrade") and squad_manager.apply_random_qualitative_upgrade()
		"temporary_shield":
			success = squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("apply_temporary_shield") and squad_manager.apply_temporary_shield(30.0, 12.0)

	if success and spend_gold(cost):
		_close_shop()
	elif not success:
		emit_stats()


func enable_magnetic_reclaim() -> void:
	magnetic_reclaim_enabled = true


func has_magnetic_reclaim() -> bool:
	return magnetic_reclaim_enabled


func _close_shop() -> void:
	waiting_for_shop = false
	get_tree().paused = manual_paused
	emit_stats()


func toggle_pause() -> void:
	if waiting_for_upgrade or waiting_for_shop or stage_victory_pending or is_game_over or not game_running:
		return
	set_manual_pause(not manual_paused)


func set_manual_pause(value: bool) -> void:
	if waiting_for_upgrade or waiting_for_shop or stage_victory_pending or is_game_over or not game_running:
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
		"level": level,
		"elites_killed": elites_killed,
		"boss_killed": boss_killed
	})


func record_elite_spawn() -> void:
	elites_spawned += 1
	elite_spawn_times.append(elapsed_time)


func record_elite_kill() -> void:
	elites_killed += 1
	elite_kill_times.append(elapsed_time)


func record_boss_spawn() -> void:
	boss_spawned = true
	boss_spawn_time = elapsed_time


func set_boss_active(value: bool) -> void:
	boss_active = value


func record_boss_phase_two() -> void:
	if boss_phase_two_time < 0.0:
		boss_phase_two_time = elapsed_time


func record_boss_kill() -> void:
	if boss_killed:
		return
	boss_killed = true
	boss_active = false
	boss_kill_time = elapsed_time
	stage_victory_pending = true
	get_tree().paused = true
	emit_stats()
	stage_victory_requested.emit({
		"elapsed_time": elapsed_time,
		"kills": kills,
		"gold": gold,
		"level": level,
		"elites_killed": elites_killed
	})


func continue_after_stage_victory() -> void:
	if not stage_victory_pending:
		return
	stage_victory_pending = false
	get_tree().paused = manual_paused
	emit_stats()


func format_time(seconds_value: float) -> String:
	var total_seconds := int(floor(seconds_value))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
