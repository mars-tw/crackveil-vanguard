extends Node

signal progress_changed

const SAVE_PATH := "user://veil_echo.cfg"

const TRACKS: Array[Dictionary] = [
	{
		"id": "echo_vitality",
		"name": "裂隙韌性",
		"description": "每階 +2% 最大 HP。",
		"max_level": 5,
		"base_cost": 18,
		"cost_step": 10
	},
	{
		"id": "echo_magnetism",
		"name": "回收餘波",
		"description": "每階 +6 拾取範圍。",
		"max_level": 5,
		"base_cost": 16,
		"cost_step": 9
	},
	{
		"id": "echo_focus",
		"name": "共鳴火花",
		"description": "每階 +1.5% 全隊傷害。",
		"max_level": 5,
		"base_cost": 22,
		"cost_step": 12
	}
]

const UNLOCKS: Array[Dictionary] = [
	{
		"id": "contract_slot",
		"name": "契約槽 +1",
		"description": "開局契約候選從 3 張提升到 4 張。",
		"required_lifetime_shards": 60
	},
	{
		"id": "opening_choice",
		"name": "起始選擇 +1",
		"description": "第一次升級多 1 張候選。",
		"required_lifetime_shards": 120
	}
]

var shards: int = 0
var lifetime_shards: int = 0
var upgrades: Dictionary = {}
var save_path: String = SAVE_PATH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_progress()


func load_progress() -> void:
	_reset_runtime_defaults()
	var config := ConfigFile.new()
	var error := config.load(save_path)
	if error != OK:
		return
	shards = max(0, int(config.get_value("echo", "shards", 0)))
	lifetime_shards = max(0, int(config.get_value("echo", "lifetime_shards", 0)))
	for track in TRACKS:
		var track_id := str(track.get("id", ""))
		upgrades[track_id] = clamp(
			int(config.get_value("upgrades", track_id, 0)),
			0,
			int(track.get("max_level", 1))
		)


func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("echo", "shards", shards)
	config.set_value("echo", "lifetime_shards", lifetime_shards)
	for track in TRACKS:
		var track_id := str(track.get("id", ""))
		config.set_value("upgrades", track_id, get_upgrade_level(track_id))
	config.save(save_path)


func reset_progress() -> void:
	_reset_runtime_defaults()
	save_progress()
	progress_changed.emit()


func debug_use_save_path(path: String, reset: bool = true) -> void:
	save_path = path if path != "" else SAVE_PATH
	if reset:
		reset_progress()
	else:
		load_progress()
		progress_changed.emit()


func award_run(summary: Dictionary) -> int:
	var amount := calculate_run_shards(summary)
	if amount <= 0:
		return 0
	shards += amount
	lifetime_shards += amount
	save_progress()
	progress_changed.emit()
	return amount


func calculate_run_shards(summary: Dictionary) -> int:
	if summary.has("_fixed_echo_delta"):
		return max(0, int(summary.get("_fixed_echo_delta", 0)))
	var elapsed := float(summary.get("elapsed_time", 0.0))
	var gold := int(summary.get("gold_earned", summary.get("gold", 0)))
	var kills := int(summary.get("kills", 0))
	var level := int(summary.get("level", 1))
	var elites := int(summary.get("elites_killed", 0))
	var boss_killed := bool(summary.get("boss_killed", false))
	var amount := int(floor(float(gold) * 0.25))
	amount += int(floor(float(kills) / 20.0))
	amount += int(floor(float(level) / 3.0))
	amount += elites * 2
	if boss_killed:
		amount += 8
	if elapsed >= 30.0:
		amount = max(1, amount)
	return amount


func buy_upgrade(track_id: String) -> bool:
	var track := _track_definition(track_id)
	if track.is_empty():
		return false
	var level := get_upgrade_level(track_id)
	if level >= int(track.get("max_level", 1)):
		return false
	var cost := get_upgrade_cost(track_id)
	if shards < cost:
		return false
	shards -= cost
	upgrades[track_id] = level + 1
	save_progress()
	progress_changed.emit()
	return true


func get_upgrade_cost(track_id: String) -> int:
	var track := _track_definition(track_id)
	if track.is_empty():
		return 999999
	return int(track.get("base_cost", 10)) + get_upgrade_level(track_id) * int(track.get("cost_step", 10))


func get_upgrade_level(track_id: String) -> int:
	return int(upgrades.get(track_id, 0))


func get_track_definitions() -> Array[Dictionary]:
	return TRACKS.duplicate(true)


func get_unlock_definitions() -> Array[Dictionary]:
	return UNLOCKS.duplicate(true)


func has_unlock(unlock_id: String) -> bool:
	for unlock in UNLOCKS:
		if str(unlock.get("id", "")) == unlock_id:
			return lifetime_shards >= int(unlock.get("required_lifetime_shards", 0))
	return false


func get_contract_choice_bonus() -> int:
	return 1 if has_unlock("contract_slot") else 0


func get_starting_upgrade_choice_bonus(run_level: int) -> int:
	return 1 if has_unlock("opening_choice") and run_level <= 2 else 0


func get_max_hp_multiplier() -> float:
	return 1.0 + float(get_upgrade_level("echo_vitality")) * 0.02


func get_pickup_radius_bonus() -> float:
	return float(get_upgrade_level("echo_magnetism")) * 6.0


func get_damage_multiplier() -> float:
	return 1.0 + float(get_upgrade_level("echo_focus")) * 0.015


func get_progress_summary() -> Dictionary:
	return {
		"shards": shards,
		"lifetime_shards": lifetime_shards,
		"vitality_level": get_upgrade_level("echo_vitality"),
		"magnetism_level": get_upgrade_level("echo_magnetism"),
		"focus_level": get_upgrade_level("echo_focus"),
		"contract_slot_unlocked": has_unlock("contract_slot"),
		"opening_choice_unlocked": has_unlock("opening_choice")
	}


func _reset_runtime_defaults() -> void:
	shards = 0
	lifetime_shards = 0
	upgrades.clear()
	for track in TRACKS:
		upgrades[str(track.get("id", ""))] = 0


func _track_definition(track_id: String) -> Dictionary:
	for track in TRACKS:
		if str(track.get("id", "")) == track_id:
			return track
	return {}
