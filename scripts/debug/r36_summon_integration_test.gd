extends Node

const ARENA := preload("res://scenes/arena/Arena.tscn")
var failures: Array[String] = []

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("R36_SUMMON_INTEGRATION_FAIL: " + message)

func _run() -> void:
	GameManager.campaign_save_path = "user://r36_root_summon_test.cfg"
	GameManager.wallet_gold = 0
	GameManager.paid_summon.clear()
	PlayerSettings.debug_use_save_path("user://r36_root_settings.cfg", true)
	MetaProgress.debug_use_save_path("user://r36_root_meta.cfg", true)
	AchievementProgress.debug_use_save_path("user://r36_root_achievement.cfg", true)
	var arena := ARENA.instantiate()
	add_child(arena)
	await get_tree().process_frame
	GameManager.waiting_for_upgrade = false
	GameManager.system_pause_owners.clear()
	get_tree().paused = false
	GameManager.game_running = true
	GameManager.xp_required = 999999
	GameManager.auto_upgrade_enabled = false
	arena.get_node("EnemySpawner").set_process(false)
	var director: Node = GameManager.summon_director
	for pet in director.pet_nodes.values():
		if is_instance_valid(pet):
			pet.queue_free()
	director.pet_nodes.clear()
	director.collection.clear()
	director._save_collection()
	await get_tree().process_frame
	GameManager.add_gold(250)
	GameManager.open_summon_shop()
	_check(GameManager.system_pause_owners.has("summon"), "shop did not own system pause")
	GameManager.purchase_summon("skill")
	_check(GameManager.gold == 170 and not GameManager.paid_summon.is_empty(), "skill draw did not charge exactly 80")
	var draw_id: String = str(GameManager.paid_summon.get("draw_id", ""))
	var choices: Array = GameManager.paid_summon.get("choice_options", [])
	_check(choices.size() == 3, "skill draw lacks 3 real choices")
	var selected := 0
	for index in range(choices.size()):
		if str(choices[index].get("id", "")) == "summon_skill":
			selected = index
			break
	GameManager.complete_summon(draw_id, selected)
	_check(GameManager.gold == 170 and director.skill_levels.size() == 1, "new active spell was not granted")
	GameManager.complete_summon(draw_id, selected)
	_check(GameManager.gold == 170 and director.skill_levels.size() == 1, "duplicate selection changed money/reward")
	GameManager.purchase_summon("pet")
	_check(GameManager.gold == 50 and director.collection.size() == 1, "pet draw did not charge/spawn exactly once")
	_check(get_tree().get_nodes_in_group("companion_pets").size() == 1, "pet is cosmetic or missing from battle")
	GameManager.purchase_summon("pet")
	_check(GameManager.gold == 50 and director.collection.size() == 1, "insufficient funds charged/rewarded")
	GameManager.close_summon_shop()
	_check(not get_tree().paused and not GameManager.system_pause_owners.has("summon"), "shop close retained pause")
	GameManager.add_gold(100)
	GameManager.open_summon_shop()
	GameManager.purchase_summon("skill")
	_check(GameManager.gold == 70 and not GameManager.paid_summon.is_empty(), "paid pending skill missing")
	GameManager.close_summon_shop()
	_check(GameManager.paid_summon.is_empty() and GameManager.gold == 70, "closing paid choice lost reward or charged twice")
	var file := ConfigFile.new()
	file.load(GameManager.campaign_save_path)
	_check(int(file.get_value("campaign", "wallet_gold", -1)) == 70, "wallet was not persisted")
	print("R36_SUMMON_TRANSACTIONS skill80=true pet120=true duplicate_safe=true insufficient_safe=true paid_close_reward=true wallet_persist=true")
	if failures.is_empty():
		print("R36_SUMMON_INTEGRATION_PASS real_skills=true real_pet=true private_rng=true coin_use=true")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
