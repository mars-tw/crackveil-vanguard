extends Node

const ARENA := preload("res://scenes/arena/Arena.tscn")
const GUIDE := preload("res://scripts/ui/first_run_guide.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const CATALOG := preload("res://scripts/services/equipment_catalog.gd")
const PHONE := {"ua_mobile": true, "ua_phone": true, "touch_available": true, "primary_coarse": true, "mouse_available": false}


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	MetaProgress.save_path = "user://r32_experience_meta.cfg"
	MetaProgress.load_progress()
	AchievementProgress.save_path = "user://r32_experience_achievements.cfg"
	AchievementProgress.load_progress()
	GameManager.forced_run_seed = 32002
	var arena := ARENA.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.waiting_for_contract = false
	GameManager.system_pause_owners.clear()
	get_tree().paused = false
	var loot := arena.get_node("LootDirector")
	if not _check(GameManager.loot_director == loot, "GM must bind the arena loot service"):
		return
	if not _check(_grade_count(arena) == 1, "only one CanvasModulate may own the world grade"):
		return
	var before_damage := GameManager.get_outgoing_damage_multiplier()
	var before_rate := GameManager.get_fire_rate_multiplier()
	var core := CATALOG.make_item("core", 2, 3, 9001)
	core["generation"] = loot.run_generation
	loot.collect_item(core)
	if not _check(GameManager.get_outgoing_damage_multiplier() > before_damage and GameManager.get_fire_rate_multiplier() > before_rate, "equipping core must increase real combat multipliers"):
		return
	var hero := GameManager.player
	var before_hp: float = hero.max_hp
	var armor := CATALOG.make_item("guard", 2, 3, 9002)
	armor["generation"] = loot.run_generation
	loot.collect_item(armor)
	loot.apply_member_bonuses(hero)
	if not _check(is_equal_approx(hero.max_hp, before_hp + float(armor.bonuses.max_hp)), "stat refresh must not apply equipment twice"):
		return
	if not _check(GameManager.get_incoming_damage_multiplier() >= GameManager.DAMAGE_TAKEN_SOFT_CAP_MIN, "equipment must respect the combined defense cap"):
		return
	var hud := arena.get_node("HUD")
	if not _check(hud.equipment_panel != null and GameManager.get_stats().equipment_slots.size() == 3, "three equipped slots must reach the real HUD"):
		return
	if not _check(not GameManager._has_purchasable_shop_reward([{"id": "refresh_shop", "cost": 0, "enabled": true}]), "refresh alone must not interrupt combat"):
		return
	GameManager.gold = 0
	var shop_was_requested := GameManager._request_shop("timed")
	if not _check(not shop_was_requested and not GameManager.waiting_for_shop, "empty-wallet runs must defer unusable shops"):
		return
	GameManager.game_running = false
	await _test_guide(Vector2i(1280, 720), {})
	await _test_guide(Vector2i(844, 390), PHONE)
	await _test_guide(Vector2i(390, 844), PHONE)
	MOBILE_TUNING.set_device_hints_override_for_tests()
	if get_tree().has_meta("r32_failed"):
		return
	print("R32_EXPERIENCE_PASS grade=single equipment=real-multipliers stat-delta=once shops=affordable guide=three-viewports")
	get_tree().quit(0)


func _test_guide(size: Vector2i, hints: Dictionary) -> void:
	MOBILE_TUNING.set_device_hints_override_for_tests(hints)
	var viewport := SubViewport.new()
	viewport.size = size
	add_child(viewport)
	var guide := GUIDE.new()
	viewport.add_child(guide)
	await get_tree().process_frame
	await get_tree().process_frame
	var body := guide.body_label.get_global_rect()
	var actions := guide.actions_box.get_global_rect()
	_check(not body.intersects(actions), "guide body overlaps the new skip/navigation controls at %s" % size)
	_check(guide.body_label.get_minimum_size().y <= guide.body_label.size.y + 1.0, "guide text clips at %s" % size)
	guide._on_previous_pressed()
	_check(not guide.root.visible, "first-page skip must dismiss the guide")
	viewport.queue_free()


func _grade_count(node: Node) -> int:
	var count := 1 if node is CanvasModulate else 0
	for child in node.get_children():
		count += _grade_count(child)
	return count


func _check(condition: bool, message: String) -> bool:
	if not condition:
		get_tree().set_meta("r32_failed", true)
		printerr("R32_EXPERIENCE_FAIL: " + message)
		get_tree().quit(1)
	return condition
