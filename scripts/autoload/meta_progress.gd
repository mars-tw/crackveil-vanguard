extends Node

signal progress_changed

const SAVE_PATH := "user://veil_echo.cfg"
const TACTICAL := preload("res://scripts/services/tactical_catalog.gd")
const STARTING := preload("res://scripts/services/starting_build_catalog.gd")

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
var tactical_medals: Dictionary = {}
var formation_seals: Dictionary = {}
var save_path: String = SAVE_PATH
var starting_owned: Array[String] = []
var starting_equipped := ""
var starting_team := "legacy"
var starting_vouchers := 1
var starting_settlements: Array[String] = []
var starting_second_granted := false
var starting_ready := true
var debug_save_fault := "" # Honoured only by debug builds with an explicit QA profile.
var debug_save_fault_remaining := -1


func _ready() -> void:
	save_path=preload("res://scripts/services/qa_profile.gd").path(SAVE_PATH)
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_progress()


func load_progress() -> void:
	_reset_runtime_defaults()
	var recovered := _recover_transaction()
	var config := ConfigFile.new()
	var source := save_path
	if not recovered and FileAccess.file_exists(save_path+".r3-backup"): source=save_path+".r3-backup"
	var error := config.load(source)
	if error != OK:
		if not recovered:
			starting_ready=false
			_queue_save_failure()
			return
		if FileAccess.file_exists(save_path):
			save_progress()
			_queue_load_failure_toast()
		return
	starting_ready=recovered
	shards = max(0, int(config.get_value("echo", "shards", 0)))
	lifetime_shards = max(0, int(config.get_value("echo", "lifetime_shards", 0)))
	for id in config.get_value("starting", "owned", []):
		if not STARTING.node(str(id)).is_empty() and not starting_owned.has(str(id)): starting_owned.append(str(id))
	starting_equipped = str(config.get_value("starting","equipped",""))
	if not starting_owned.has(starting_equipped): starting_equipped=""
	starting_team = str(config.get_value("starting","team","legacy"))
	if not STARTING.TEAMS.has(starting_team): starting_team="legacy"
	starting_vouchers = maxi(0,int(config.get_value("starting","vouchers",1)))
	for id in config.get_value("starting","settlements",[]):
		if not starting_settlements.has(str(id)): starting_settlements.append(str(id))
	starting_second_granted = bool(config.get_value("starting","second_granted",false))
	for stage in TACTICAL.STAGES.get_stages():
		tactical_medals[str(stage.id)] = clampi(int(config.get_value("tactical", str(stage.id), 0)), 0, 7)
		formation_seals[str(stage.id)] = bool(config.get_value("formation_seals", str(stage.id), false))
	for track in TRACKS:
		var track_id := str(track.get("id", ""))
		upgrades[track_id] = clamp(
			int(config.get_value("upgrades", track_id, 0)),
			0,
			int(track.get("max_level", 1))
		)
	if starting_ready and not config.has_section_key("starting","schema"):
		starting_ready=save_progress()


func save_progress() -> bool:
	if not _recover_transaction():
		starting_ready=false
		_queue_save_failure()
		return false
	var config := ConfigFile.new()
	# Keep unknown future/legacy sections rather than erasing them on migration.
	if FileAccess.file_exists(save_path): config.load(save_path)
	config.set_value("starting","schema",1)
	config.set_value("starting","owned",starting_owned)
	config.set_value("starting","equipped",starting_equipped)
	config.set_value("starting","team",starting_team)
	config.set_value("starting","vouchers",starting_vouchers)
	config.set_value("starting","settlements",starting_settlements)
	config.set_value("starting","second_granted",starting_second_granted)
	config.set_value("echo", "shards", shards)
	config.set_value("echo", "lifetime_shards", lifetime_shards)
	for stage in TACTICAL.STAGES.get_stages():
		config.set_value("tactical", str(stage.id), int(tactical_medals.get(str(stage.id), 0)))
		config.set_value("formation_seals", str(stage.id), bool(formation_seals.get(str(stage.id), false)))
	for track in TRACKS:
		var track_id := str(track.get("id", ""))
		config.set_value("upgrades", track_id, get_upgrade_level(track_id))
	return _save_verified_transaction(config)


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
	if not save_progress():
		shards -= amount
		lifetime_shards -= amount
		return 0
	if has_unlock("contract_slot") and AchievementProgress != null and AchievementProgress.has_method("record_contract_slot_unlock"):
		AchievementProgress.record_contract_slot_unlock()
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
	if not save_progress():
		shards += cost
		upgrades[track_id]=level
		return false
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
	return (1.0 + float(get_upgrade_level("echo_focus")) * 0.015) * (1.0 + get_tactical_damage_bonus())


func award_tactical_medal(stage_id: String, medal_id: String) -> int:
	var definition := TACTICAL.medal(medal_id)
	if definition.is_empty() or TACTICAL.STAGES.get_stage(stage_id).is_empty():
		return -1
	var before := int(tactical_medals.get(stage_id, 0))
	if before & int(definition.bit):
		return 0
	var reward := int(definition.reward)
	tactical_medals[stage_id] = before | int(definition.bit)
	shards += reward
	lifetime_shards += reward
	if not save_progress():
		tactical_medals[stage_id] = before
		shards -= reward
		lifetime_shards -= reward
		return -1
	progress_changed.emit()
	return reward


func award_formation_seal(stage_id: String) -> int:
	if TACTICAL.STAGES.get_stage(stage_id).is_empty():
		return -1
	if bool(formation_seals.get(stage_id, false)):
		return 0
	formation_seals[stage_id] = true
	shards += 4
	lifetime_shards += 4
	if not save_progress():
		formation_seals[stage_id] = false
		shards -= 4
		lifetime_shards -= 4
		return -1
	progress_changed.emit()
	return 4


func get_tactical_medal_count(stage_id: String = "") -> int:
	if stage_id.is_empty():
		var total := 0
		for stage in TACTICAL.STAGES.get_stages():
			total += get_tactical_medal_count(str(stage.id))
		return total
	var mask := int(tactical_medals.get(stage_id, 0))
	return (mask & 1) + ((mask >> 1) & 1) + ((mask >> 2) & 1)


func get_tactical_damage_bonus() -> float:
	var mastered := 0
	for stage in TACTICAL.STAGES.get_stages():
		if int(tactical_medals.get(str(stage.id), 0)) == 7:
			mastered += 1
	return float(mini(5, mastered)) * 0.01


func get_tactical_collection_text() -> String:
	var text := "戰術收藏 %d/30｜全隊傷害 +%d%%\n每關三徽記：走位換陣／雙菁英／Boss\n首取殘響 +3／+5／+8；集齊一關傷害 +1%%（上限 5%%）" % [get_tactical_medal_count(), roundi(get_tactical_damage_bonus()*100)]
	for stage in TACTICAL.STAGES.get_stages():
		text += "\n%s　%d/3" % [stage.name, get_tactical_medal_count(str(stage.id))]
	var selected := GameManager.selected_stage_id
	if get_tactical_medal_count(selected) == 3:
		text += "\n" + str(TACTICAL.RECORDS.get(selected, ""))
	return text


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
	tactical_medals.clear()
	formation_seals.clear()
	starting_owned.clear()
	starting_equipped=""
	starting_team="legacy"
	starting_vouchers=1
	starting_settlements.clear()
	starting_second_granted=false
	starting_ready=true
	for track in TRACKS:
		upgrades[str(track.get("id", ""))] = 0


func _track_definition(track_id: String) -> Dictionary:
	for track in TRACKS:
		if str(track.get("id", "")) == track_id:
			return track
	return {}


func _queue_load_failure_toast() -> void:
	if GameManager != null and GameManager.has_method("queue_toast"):
		GameManager.queue_toast("殘響存檔載入失敗，已安全重置。")

func purchase_starting_node(id: String) -> bool:
	if not starting_ready: return false
	var row := STARTING.node(id)
	if row.is_empty() or starting_owned.has(id): return false
	var before := _starting_snapshot()
	if starting_vouchers>0: starting_vouchers-=1
	elif shards>=int(row.cost): shards-=int(row.cost)
	else: return false
	starting_owned.append(id)
	return _commit_starting(before)

func equip_starting_node(id: String) -> bool:
	if not starting_ready: return false
	if id!="" and not starting_owned.has(id): return false
	if id==starting_equipped: return true
	var before := _starting_snapshot()
	starting_equipped=id
	return _commit_starting(before)

func select_starting_team(id: String) -> bool:
	if not starting_ready: return false
	if not STARTING.TEAMS.has(id): return false
	if id==starting_team: return true
	var before := _starting_snapshot()
	starting_team=id
	return _commit_starting(before)

func record_starting_settlement(id: String, summary: Dictionary, formal: bool) -> bool:
	if starting_settlement_status(id,summary,formal)!="eligible": return false
	var before := _starting_snapshot()
	starting_settlements.append(id)
	if starting_settlements.size()>=4 and not starting_second_granted:
		starting_vouchers+=1
		starting_second_granted=true
	return _commit_starting(before)

func starting_settlement_status(id: String, summary: Dictionary, formal: bool) -> String:
	if not formal or id.is_empty(): return "ineligible"
	if starting_settlements.has(id): return "recorded"
	var reason:=str(summary.get("settlement_reason",""))
	var true_defeat:=reason=="defeat" and bool(summary.get("captain_dead",false))
	var true_victory:=reason=="victory" and bool(summary.get("campaign_clear",false))
	if not true_defeat and not true_victory: return "ineligible"
	return "eligible" if starting_ready else "save_failed"

func _starting_snapshot() -> Dictionary:
	return {"shards":shards,"starting_owned":starting_owned.duplicate(),"starting_equipped":starting_equipped,"starting_team":starting_team,"starting_vouchers":starting_vouchers,"starting_settlements":starting_settlements.duplicate(),"starting_second_granted":starting_second_granted}

func _commit_starting(before: Dictionary) -> bool:
	if not save_progress():
		for key in before: set(key,before[key])
		return false
	progress_changed.emit()
	return true

func _digest(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): context.update(bytes)
	return context.finish().hex_encode()

func _write_verified(path: String, bytes: PackedByteArray) -> bool:
	var stream:=FileAccess.open(path,FileAccess.WRITE)
	if stream==null:return false
	stream.store_buffer(bytes)
	stream.flush()
	var error:=stream.get_error()
	stream.close()
	return error==OK and FileAccess.get_file_as_bytes(path)==bytes

func _queue_save_failure() -> void:
	GameManager.queue_toast("殘響尚未保存，請確認儲存空間後再試。")

func _remove_owned(path: String) -> void:
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func _clear_transaction() -> void:
	_remove_owned(save_path+".r3-journal")
	_remove_owned(save_path+".r3-backup")
	var directory:=DirAccess.open(save_path.get_base_dir())
	if directory!=null:
		for name in directory.get_files():
			if name.begins_with(save_path.get_file()+".r3-temp-"):
				_remove_owned(save_path.get_base_dir().path_join(name))

func _recover_transaction() -> bool:
	var journal_path:=save_path+".r3-journal"
	var backup_path:=save_path+".r3-backup"
	if not FileAccess.file_exists(journal_path):
		# A crash during temp/backup preparation cannot have removed the target.
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(save_path): return false
		_clear_transaction()
		return true
	var parser:=JSON.new()
	var parsed:=parser.parse(FileAccess.get_file_as_string(journal_path))
	var record: Variant=parser.data if parsed==OK else null
	if not record is Dictionary:
		if not FileAccess.file_exists(save_path) and not FileAccess.file_exists(backup_path):
			_clear_transaction()
			return true # Interrupted first journal write; no prior target existed.
		if FileAccess.file_exists(save_path) and FileAccess.file_exists(backup_path) and FileAccess.get_file_as_bytes(save_path)==FileAccess.get_file_as_bytes(backup_path):
			_clear_transaction()
			return true
		return false
	var current: String=_digest(FileAccess.get_file_as_bytes(save_path)) if FileAccess.file_exists(save_path) else ""
	if current!="" and (current==str(record.get("new","")) or current==str(record.get("old",""))):
		_clear_transaction()
		return true
	if str(record.get("old",""))=="" and not FileAccess.file_exists(save_path):
		_clear_transaction()
		return true # Interrupted first save; the free choice remains unspent.
	if FileAccess.file_exists(backup_path):
		var bytes:=FileAccess.get_file_as_bytes(backup_path)
		if OS.is_debug_build() and not OS.get_environment("CV_QA_PROFILE").is_empty() and debug_save_fault=="recovery_failure":return false
		if _digest(bytes)==str(record.get("old","")) and _write_verified(save_path,bytes):
			_clear_transaction()
			return true
	return false # Keep the verified recovery data and block further transactions.

func _save_verified_transaction(config: ConfigFile) -> bool:
	var expected:=config.encode_to_text().to_utf8_buffer()
	var temporary:=save_path+".r3-temp-%d" % Time.get_ticks_usec()
	var backup:=save_path+".r3-backup"
	var journal:=save_path+".r3-journal"
	var fault:=debug_save_fault if OS.is_debug_build() and not OS.get_environment("CV_QA_PROFILE").is_empty() else ""
	if debug_save_fault_remaining>0:
		debug_save_fault_remaining-=1
		if debug_save_fault_remaining==0: debug_save_fault=""
	var written:=expected
	if fault=="valid_prefix":
		# A legal ConfigFile prefix still lacks the complete intended payload.
		written="[echo]\nshards=1\n".to_utf8_buffer()
	if not _write_verified(temporary,written) or FileAccess.get_file_as_bytes(temporary)!=expected:
		_remove_owned(temporary)
		_queue_save_failure()
		return false
	var check:=ConfigFile.new()
	if check.parse(FileAccess.get_file_as_string(temporary))!=OK:
		_remove_owned(temporary)
		_queue_save_failure()
		return false
	var existed:=FileAccess.file_exists(save_path)
	var original:=FileAccess.get_file_as_bytes(save_path) if existed else PackedByteArray()
	if existed and not _write_verified(backup,original):
		_remove_owned(temporary)
		_remove_owned(backup)
		_queue_save_failure()
		return false
	var record:={"old":_digest(original) if existed else "","new":_digest(expected)}
	if fault=="interrupt_during_journal":
		_write_verified(journal,"{".to_utf8_buffer())
		starting_ready=false
		return false
	if not _write_verified(journal,JSON.stringify(record).to_utf8_buffer()):
		_clear_transaction()
		_queue_save_failure()
		return false
	if fault=="interrupt_before_replace":
		starting_ready=false
		return false # Deliberately retain journal/temp only in the controlled QA case.
	var result:=OK
	if fault in ["replace_after_remove","interrupt_after_remove"]:
		_remove_owned(save_path)
		result=ERR_CANT_CREATE
		if fault=="interrupt_after_remove":
			starting_ready=false
			return false
	else:
		# Godot Windows rename removes an existing destination before moving.
		# The verified journal/old bytes make that failure window recoverable.
		result=DirAccess.rename_absolute(temporary,save_path)
	if result==OK and FileAccess.get_file_as_bytes(save_path)==expected:
		if fault!="interrupt_after_install": _clear_transaction()
		return true
	var restored:=not existed and not FileAccess.file_exists(save_path)
	if existed:
		restored=(FileAccess.file_exists(save_path) and FileAccess.get_file_as_bytes(save_path)==original) or _write_verified(save_path,original)
	_remove_owned(temporary)
	if restored: _clear_transaction()
	else: starting_ready=false
	_queue_save_failure()
	return false
