extends SceneTree

# Controlled real-Arena settlement integration. This is not a natural playthrough.
var checks := 0
var failures: Array[String] = []
var gm: Node
var meta: Node
var arena: Node

func _initialize() -> void:
	await process_frame
	gm = root.get_node("GameManager")
	meta = root.get_node("MetaProgress")
	if OS.get_environment("CV_QA_PROFILE").is_empty() or not "qa_" in str(meta.save_path):
		printerr("EXPEDITION_INTEGRATION refused: isolated QA profile required")
		quit(2)
		return
	root.get_node("AudioManager").set_muted(true)
	meta.reset_progress()
	gm.set_process(false)
	gm.selected_stage_id = "moon"
	gm.run_mode = "campaign"
	gm.pending_starting_formal = false
	arena = load("res://scenes/arena/Arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	gm.game_running = false
	arena.get_node("EnemySpawner").set_process(false)
	gm.tactical_director.set_process(false)
	gm.tactical_director.relay.set_process(false)
	gm.active_starting_formal = false
	gm.expedition_seeded = false
	gm.tactical_launch = false
	gm.starting_run_id = "expedition-integration-one"
	gm.tactical_director.relay.step = 2
	gm.tactical_director.relay.completed = false
	gm.stage_victory_pending = false
	var defeated := {"elapsed_time":0.0,"kills":0,"gold":0,"level":1,"settlement_reason":"defeat","captain_dead":true}
	var result: Dictionary = gm._summary_with_echo(defeated)
	_check(result.expedition_result.status == "ineligible", "nonformal run cannot progress missions")
	_check(int(_row("moon_field").progress) == 0, "nonformal run leaves progress unchanged")
	gm.active_starting_formal = true
	gm.expedition_seeded = true
	result = gm._summary_with_echo(defeated)
	_check(result.expedition_result.status == "ineligible", "seeded formal launch is excluded")
	gm.expedition_seeded = false
	gm.tactical_launch = true
	result = gm._summary_with_echo(defeated)
	_check(result.expedition_result.status == "ineligible", "tactical practice launch is excluded")
	gm.tactical_launch = false
	result = gm._summary_with_echo(defeated)
	_check(result.stage_id == "moon", "defeat summary receives selected stage identity")
	_check(int(result.seal_state.step) == 2, "mission sees live relay counters after enrichment")
	_check(int(result.squad_total) == gm.squad_manager.recruited_once.size(), "mission sees actual recruited roster")
	_check(result.expedition_result.status == "recorded" and int(result.expedition_result.reward) == 4, "formal real-Arena settlement awards moon field mission")
	_check(_row("moon_field").status == "completed", "field completion is persisted")
	_check(int(result.echo_progress.shards) == meta.shards, "settlement wallet includes expedition award")
	_test_result_screens(result)
	var balance: int = meta.shards
	result = gm._summary_with_echo(defeated)
	_check(int(result.expedition_result.reward) == 0 and meta.shards == balance, "same settlement cannot double-pay")
	meta.load_progress()
	result = gm._summary_with_echo(defeated)
	_check(int(result.expedition_result.reward) == 0 and meta.shards == balance, "reload preserves duplicate-payment protection")
	gm.tactical_director.relay.step = 3
	gm.tactical_director.relay.completed = true
	gm.tactical_director.relay.wrong_penalties = 0
	gm.stage_victory_pending = true
	var victory := {"elapsed_time":0.0,"kills":0,"gold":0,"level":1,"settlement_reason":"victory","boss_killed":false}
	gm.run_mode = "endless"
	result = gm._summary_with_echo(victory)
	_check(result.expedition_result.status == "ineligible" and _row("moon_mastery").status == "active", "same-run endless continuation cannot claim campaign mastery")
	gm.run_mode = "campaign"
	result = gm._summary_with_echo(victory)
	_check(result.campaign_clear and int(result.expedition_result.reward) == 6, "true campaign completion consumes enriched relay state")
	_check(_row("moon_mastery").status == "completed", "mastery completion reaches journal")
	_test_pending_retry()
	gm.selected_stage_id = "moon"
	await _test_board()
	gm.game_running = false
	gm.stage_victory_pending = false
	gm.system_pause_owners.clear()
	paused = false
	arena.queue_free()
	await process_frame
	await _test_menu_entry()
	print("EXPEDITION_INTEGRATION status=%s checks=%d failures=%s" % ["PASS" if failures.is_empty() else "FAIL", checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _test_pending_retry() -> void:
	var summary := {"stage_id":"garden","starting_mode":"campaign","settlement_reason":"defeat","captain_dead":true,"seal_state":{"vine_snares":2,"vine_clean":2,"vine_hits":0}}
	var balance: int = meta.shards
	meta.debug_save_fault = "valid_prefix"
	var result: Dictionary = gm._record_expedition_settlement("expedition-save-retry", summary, true)
	_check(result.status == "save_failed", "failed save is reported by integration adapter")
	_check(meta.shards == balance and _row("garden_field").status == "active", "failed save grants neither reward nor completion")
	_check(gm.pending_expedition_settlements.has("expedition-save-retry"), "failed progress remains retryable")
	meta.debug_save_fault = ""
	_check(gm.retry_expedition_settlements(), "retry persists pending progress")
	_check(meta.shards == balance + 4 and _row("garden_field").status == "completed", "successful retry pays once")
	_check(gm.pending_expedition_settlements.is_empty(), "successful retry clears pending record")
	_check(gm.retry_expedition_settlements() and meta.shards == balance + 4, "repeated retry cannot duplicate reward")

func _test_board() -> void:
	var before_connections: int = meta.progress_changed.get_connections().size()
	for dimensions in [Vector2i(320,568), Vector2i(430,932), Vector2i(844,390), Vector2i(1280,720)]:
		var width: int = dimensions.x
		var view := SubViewport.new()
		view.size = dimensions
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(view)
		var scroll := ScrollContainer.new()
		scroll.size = Vector2(dimensions)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		view.add_child(scroll)
		var board: VBoxContainer = load("res://scripts/ui/expedition_board.gd").new()
		scroll.add_child(board)
		var requests: Array[String] = []
		board.stage_requested.connect(func(id: String): requests.append(id))
		for frame in range(4): await process_frame
		_check(board.find_child("moon_field", false, false) != null and board.find_child("moon_mastery", false, false) != null, "journal renders selected biome cards at %d" % width)
		for button in board.find_children("*", "Button", true, false):
			var box: Rect2 = button.get_global_rect()
			_check(box.size.x >= 44.0 and box.size.y >= 44.0, "journal touch target is at least 44 px at %d" % width)
			_check(box.position.x >= -1.0 and box.end.x <= float(width) + 1.0, "journal button fits horizontal viewport at %d" % width)
		_button(board, "在地圖查看此戰場").pressed.emit()
		_check(requests == ["moon"], "journal navigation emits selected biome once")
		_button(board, "下一關").pressed.emit()
		await process_frame
		_button(board, "在地圖查看此戰場").pressed.emit()
		_check(requests == ["moon", "garden"], "refresh replaces navigation without duplicate callbacks")
		_check(board.find_child("garden_field", false, false) != null, "next biome renders its own missions")
		view.queue_free()
		await process_frame
	_check(meta.progress_changed.get_connections().size() == before_connections, "journal create/free leaves no persistent signal connections")

func _test_result_screens(summary: Dictionary) -> void:
	for path in ["GameOverScreen", "StageVictoryScreen"]:
		var screen: Node = arena.get_node(path)
		screen.show_summary(summary)
		_check("額外殘響 +4" in str(screen.summary_label.text), path + " shows the saved extra reward")
		var records: Array = screen._records()
		_check(str(records).contains("空庭重連") and str(records).contains("殘響 +4 已保存"), path + " records actual completed mission and credited reward")
		var failed := summary.duplicate(true)
		failed.expedition_result = {"status":"save_failed","completed":[],"reward":0}
		screen.show_summary(failed)
		_check("任務尚未保存" in str(screen.summary_label.text) and not "額外殘響" in str(screen.summary_label.text), path + " never presents an unsaved reward as paid")
		_check(str(screen._records()).contains("獎勵未入帳"), path + " explains failed-save recovery")
		screen.root.hide()

func _test_menu_entry() -> void:
	var mobile: GDScript = load("res://scripts/services/mobile_tuning.gd")
	mobile.set_device_hints_override_for_tests({"ua_mobile":true,"ua_phone":true,"touch_available":true,"primary_coarse":true,"mouse_available":false})
	root.size = Vector2i(430, 932)
	var menu: Node = load("res://scenes/ui/MainMenu.tscn").instantiate()
	root.add_child(menu)
	for frame in range(3): await process_frame
	_check(menu.achievements_button.text == "遠征任務・成就", "main menu exposes the journal entry")
	menu._show_panel("achievements")
	for frame in range(4): await process_frame
	_check(menu.side_content.find_child("ExpeditionBoard", true, false) != null, "main menu opens expedition board by default")
	var board: Node = menu.side_content.find_child("ExpeditionBoard", true, false)
	var initial_size: int = _label_named(board, "空庭重連").get_theme_font_size("font_size")
	_button(board, "下一關").pressed.emit()
	for frame in range(4): await process_frame
	_check(_label_named(board, "識破荊棘").get_theme_font_size("font_size") == initial_size, "paging preserves the phone's accessible font scale")
	_button(board, "上一關").pressed.emit()
	for frame in range(4): await process_frame
	_check(_label_named(board, "空庭重連").get_theme_font_size("font_size") == initial_size, "paging back preserves the phone's accessible font scale")
	menu.journal_section = "achievements"
	menu._show_panel("achievements")
	await process_frame
	_check(menu.side_content.find_child("AchievementsGrid", true, false) != null and menu.side_content.find_child("ExpeditionBoard", true, false) == null, "legacy achievements remain reachable and replace mission page")
	menu.journal_section = "expeditions"
	menu._show_panel("achievements")
	await process_frame
	_check(menu.side_content.find_child("ExpeditionBoard", true, false) != null, "returning from achievements rebuilds journal")
	menu.queue_free()
	await process_frame
	mobile.set_device_hints_override_for_tests({})

func _label_named(parent: Node, value: String) -> Label:
	for item in parent.find_children("*", "Label", true, false):
		if item.text == value: return item
	return null

func _button(parent: Node, text: String) -> Button:
	for item in parent.find_children("*", "Button", true, false):
		if item.text == text: return item
	return null

func _row(id: String) -> Dictionary:
	for row in meta.get_expedition_rows():
		if row.id == id: return row
	return {}

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("EXPEDITION_INTEGRATION_FAIL " + label)
