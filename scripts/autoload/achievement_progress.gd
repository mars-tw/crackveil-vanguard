extends Node

signal achievement_unlocked(achievement: Dictionary)

const SAVE_PATH := "user://crackveil_achievements.cfg"

const DEFINITIONS: Array[Dictionary] = [
	{
		"id": "first_elite_kill",
		"name": "精英首獵",
		"description": "首次擊殺精英。"
	},
	{
		"id": "first_evolution",
		"name": "武器覺醒",
		"description": "首次完成武器進化。"
	},
	{
		"id": "first_boss_kill",
		"name": "守門者倒下",
		"description": "首次擊破 Boss。"
	},
	{
		"id": "full_squad",
		"name": "五人滿編",
		"description": "隊伍達到 5 人。"
	},
	{
		"id": "affix_split_seen",
		"name": "裂殖目擊",
		"description": "首次遭遇裂殖精英。"
	},
	{
		"id": "affix_field_seen",
		"name": "磁滯目擊",
		"description": "首次遭遇磁滯精英。"
	},
	{
		"id": "affix_swift_seen",
		"name": "疾閃目擊",
		"description": "首次遭遇疾閃精英。"
	},
	{
		"id": "echo_contract_slot",
		"name": "契約擴展",
		"description": "用殘響解鎖第 4 張契約選項。"
	},
	{
		"id": "survive_5_min",
		"name": "五分鐘防線",
		"description": "單局存活 5 分鐘。"
	},
	{
		"id": "kills_500",
		"name": "殲滅 500",
		"description": "單局擊殺達到 500。"
	}
]

var unlocked: Dictionary = {}
var run_unlocked_ids: Array[String] = []
var save_path: String = SAVE_PATH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_progress()


func start_run() -> void:
	run_unlocked_ids.clear()


func load_progress() -> void:
	unlocked.clear()
	var config := ConfigFile.new()
	var error := config.load(save_path)
	if error != OK:
		if FileAccess.file_exists(save_path):
			save_progress()
			_queue_load_failure_toast()
		return
	for achievement in DEFINITIONS:
		var achievement_id := str(achievement.get("id", ""))
		if bool(config.get_value("achievements", achievement_id, false)):
			unlocked[achievement_id] = int(config.get_value("unlocked_at", achievement_id, 0))


func save_progress() -> void:
	var config := ConfigFile.new()
	for achievement in DEFINITIONS:
		var achievement_id := str(achievement.get("id", ""))
		config.set_value("achievements", achievement_id, unlocked.has(achievement_id))
		if unlocked.has(achievement_id):
			config.set_value("unlocked_at", achievement_id, int(unlocked.get(achievement_id, 0)))
	config.save(save_path)


func reset_progress() -> void:
	unlocked.clear()
	run_unlocked_ids.clear()
	save_progress()


func debug_use_save_path(path: String, reset: bool = true) -> void:
	save_path = path if path != "" else SAVE_PATH
	if reset:
		reset_progress()
	else:
		load_progress()


func unlock(achievement_id: String) -> bool:
	if achievement_id == "" or unlocked.has(achievement_id):
		return false
	var definition := get_definition(achievement_id)
	if definition.is_empty():
		return false
	unlocked[achievement_id] = Time.get_unix_time_from_system()
	run_unlocked_ids.append(achievement_id)
	save_progress()
	achievement_unlocked.emit(definition)
	if GameManager != null and GameManager.has_method("show_toast"):
		GameManager.show_toast("成就解鎖！%s" % str(definition.get("name", "")))
	return true


func record_elite_kill() -> void:
	unlock("first_elite_kill")


func record_evolution() -> void:
	unlock("first_evolution")


func record_boss_kill() -> void:
	unlock("first_boss_kill")


func record_squad_size(member_count: int, max_members: int) -> void:
	if member_count >= 5 or (max_members > 0 and member_count >= max_members and max_members >= 5):
		unlock("full_squad")


func record_affix_encounter(affix_id: String) -> void:
	match affix_id:
		"affix_split":
			unlock("affix_split_seen")
		"affix_field":
			unlock("affix_field_seen")
		"affix_swift":
			unlock("affix_swift_seen")


func record_survival_time(seconds_value: float) -> void:
	if seconds_value >= 300.0:
		unlock("survive_5_min")


func record_kills(kill_count: int) -> void:
	if kill_count >= 500:
		unlock("kills_500")


func record_contract_slot_unlock() -> void:
	unlock("echo_contract_slot")


func is_unlocked(achievement_id: String) -> bool:
	return unlocked.has(achievement_id)


func get_definition(achievement_id: String) -> Dictionary:
	for achievement in DEFINITIONS:
		if str(achievement.get("id", "")) == achievement_id:
			return achievement.duplicate(true)
	return {}


func get_achievement_definitions() -> Array[Dictionary]:
	return DEFINITIONS.duplicate(true)


func get_display_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for achievement in DEFINITIONS:
		var row := achievement.duplicate(true)
		row["unlocked"] = unlocked.has(str(achievement.get("id", "")))
		rows.append(row)
	return rows


func get_run_unlocked_ids() -> Array[String]:
	return run_unlocked_ids.duplicate()


func get_run_unlocked_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for achievement_id in run_unlocked_ids:
		var definition := get_definition(achievement_id)
		if not definition.is_empty():
			result.append(definition)
	return result


func get_unlocked_count() -> int:
	return unlocked.size()


func get_total_count() -> int:
	return DEFINITIONS.size()


func _queue_load_failure_toast() -> void:
	if GameManager != null and GameManager.has_method("queue_toast"):
		GameManager.queue_toast("成就檔載入失敗，已安全重置。")
