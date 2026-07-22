extends Node

## PLAYTEST-R1 NOT REACHED 終局 gate：
## - 既有 EnemySpawner 時間門檻生成 Boss。
## - 隊長受致命 impact 後完成逐格死亡，顯示敗北結算。
## - 敗北「再來一局」與「回主選單」按鈕存在、可用、signal 可觸發，
##   且 Arena runtime handler 確實已連接。
## - Boss 受致命 impact 後完成 hurt/death 流程，顯示勝利結算。
## - Web release preset 排除 QA hook 與 gate 資源。

const ARENA_SCENE := preload("res://scenes/arena/Arena.tscn")
const QA_HOOK := preload("res://scripts/debug/r31_endgame_qa_hook.gd")

var current_phase := "boot"
var restart_trigger_count := 0
var main_menu_trigger_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_watchdog")
	call_deferred("_run_tests")


func _watchdog() -> void:
	await get_tree().create_timer(35.0, true).timeout
	if current_phase != "done":
		_fail("watchdog timeout at phase: " + current_phase)


func _run_tests() -> void:
	current_phase = "release_isolation"
	if not _test_release_isolation_contract():
		return
	_prepare_test_saves()

	current_phase = "boss_and_defeat"
	var defeat_arena := await _new_arena()
	if defeat_arena == null:
		return
	var defeat_hook = QA_HOOK.new(defeat_arena)
	if not defeat_hook.is_authorized():
		_fail("live hook authorization failed; pass -- --qa-endgame=r31")
		return
	var boss_result: Dictionary = defeat_hook.advance_to("near_boss")
	if not _result_ok(boss_result, "near_boss"):
		return
	var boss: Node = boss_result.get("boss") as Node
	if boss == null or not is_instance_valid(boss) or not bool(boss.get("is_boss")):
		_fail("Boss runtime instance missing")
		return
	if not bool(GameManager.get("boss_spawned")) or not bool(GameManager.get("boss_active")):
		_fail("Boss GameManager state was not recorded")
		return
	print("R31_BOSS_REACHED elapsed=%.1f type=%s active=%s animation=%s" % [
		float(GameManager.get("elapsed_time")),
		str(boss.get("type_id")),
		str(boss.get("is_active")),
		str(boss.get("current_animation_name"))
	])

	var near_death_result: Dictionary = defeat_hook.advance_to("near_death")
	if not _result_ok(near_death_result, "near_death"):
		return
	var leader: Node = near_death_result.get("leader") as Node
	if leader == null or not is_instance_valid(leader) or absf(float(leader.get("current_hp")) - 1.0) > 0.001:
		_fail("near-death hook did not leave the leader at 1 HP")
		return
	var source_position: Vector2 = (leader as Node2D).global_position + Vector2.RIGHT * 64.0
	if not bool(leader.call("take_damage", 2.0, source_position)):
		_fail("lethal player impact was rejected")
		return
	var leader_visual: Node = leader.get("visual") as Node
	if leader_visual == null or str(leader_visual.get("current_animation_name")) != "death":
		_fail("player death did not enter the frame animation")
		return
	if not await _wait_until(Callable(self, "_game_over_visible").bind(defeat_arena), 180):
		_fail("defeat summary did not become visible after player death animation")
		return
	if not await _test_defeat_buttons(defeat_arena):
		return
	print("R31_DEFEAT_REACHED title=任務失敗 death_animation=frame-based retry=triggered main_menu=triggered")

	await _dispose_arena(defeat_arena)
	current_phase = "victory"
	var victory_arena := await _new_arena()
	if victory_arena == null:
		return
	var victory_hook = QA_HOOK.new(victory_arena)
	var victory_result: Dictionary = victory_hook.advance_to("victory")
	if not _result_ok(victory_result, "victory"):
		return
	if str(victory_result.get("death_animation", "")) != "death":
		_fail("Boss lethal impact did not enter the death animation")
		return
	if not await _wait_until(Callable(self, "_victory_visible").bind(victory_arena), 240):
		_fail("victory summary did not become visible after Boss death animation")
		return
	var victory_screen: Node = victory_arena.get_node_or_null("StageVictoryScreen")
	var victory_root: Control = victory_screen.get("root") as Control if victory_screen != null else null
	var victory_title: Label = victory_screen.get("title_label") as Label if victory_screen != null else null
	var victory_summary: Label = victory_screen.get("summary_label") as Label if victory_screen != null else null
	if victory_root == null or not victory_root.is_visible_in_tree() or victory_title == null or victory_title.text != "階段勝利":
		_fail("victory UI title/root missing")
		return
	if victory_summary == null or not victory_summary.text.contains("擊破守門者"):
		_fail("victory summary copy missing")
		return
	if not bool(GameManager.get("boss_killed")) or not bool(GameManager.get("stage_victory_pending")):
		_fail("victory GameManager state missing")
		return
	print("R31_VICTORY_REACHED title=%s boss_killed=true summary=visible" % victory_title.text)

	await _dispose_arena(victory_arena)
	current_phase = "done"
	print("R31_ENDGAME_GATE_PASS boss=spawned defeat=visible retry=triggered main_menu=triggered victory=visible web_hook=excluded")
	get_tree().quit(0)


func _test_release_isolation_contract() -> bool:
	var preset := ConfigFile.new()
	if preset.load("res://export_presets.cfg") != OK:
		_fail("cannot read export_presets.cfg")
		return false
	var exclude_filter := str(preset.get_value("preset.0", "exclude_filter", ""))
	for required_filter in ["scripts/debug/**", "scenes/debug/**"]:
		if not exclude_filter.contains(required_filter):
			_fail("Web release does not exclude " + required_filter)
			return false
	if QA_HOOK.is_authorized_for(false, PackedStringArray([QA_HOOK.AUTH_ARGUMENT])):
		_fail("release build could authorize QA hook")
		return false
	if QA_HOOK.is_authorized_for(true, PackedStringArray()):
		_fail("QA hook accepts a debug build without explicit argument")
		return false
	if not QA_HOOK.is_authorized_for(true, PackedStringArray([QA_HOOK.AUTH_ARGUMENT])):
		_fail("QA hook authorization contract drifted")
		return false
	print("R31_HOOK_ISOLATION debug_build+explicit_arg=required web_excludes=scripts/debug/**,scenes/debug/** marker=%s" % QA_HOOK.EXPORT_ABSENCE_MARKER)
	return true


func _prepare_test_saves() -> void:
	PlayerSettings.debug_use_save_path("user://r31_player_settings_test.cfg", true)
	MetaProgress.debug_use_save_path("user://r31_meta_progress_test.cfg", true)
	AchievementProgress.debug_use_save_path("user://r31_achievement_test.cfg", true)


func _new_arena() -> Node:
	_reset_runtime_state()
	var arena := ARENA_SCENE.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	if not bool(GameManager.get("game_running")) or GameManager.get("player") == null:
		_fail("Arena did not start a playable run")
		return null
	return arena


func _dispose_arena(arena: Node) -> void:
	get_tree().paused = false
	GameManager.clear_time_scale_owners()
	GameManager.system_pause_owners.clear()
	GameManager.game_running = false
	if arena != null and is_instance_valid(arena):
		arena.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _reset_runtime_state() -> void:
	get_tree().paused = false
	GameManager.clear_time_scale_owners()
	GameManager.system_pause_owners.clear()
	GameManager.game_running = false
	GameManager.is_game_over = false
	GameManager.waiting_for_upgrade = false
	GameManager.waiting_for_shop = false
	GameManager.waiting_for_contract = false
	GameManager.stage_victory_pending = false
	GameManager.manual_paused = false
	EntityFactory.reset_debug_counters()


func _game_over_visible(arena: Node) -> bool:
	if arena == null or not is_instance_valid(arena):
		return false
	var screen := arena.get_node_or_null("GameOverScreen")
	if screen == null:
		return false
	var root: Control = screen.get("root") as Control
	return bool(GameManager.get("is_game_over")) and root != null and root.is_visible_in_tree()


func _victory_visible(arena: Node) -> bool:
	if arena == null or not is_instance_valid(arena):
		return false
	var screen := arena.get_node_or_null("StageVictoryScreen")
	if screen == null:
		return false
	var root: Control = screen.get("root") as Control
	return bool(GameManager.get("boss_killed")) and root != null and root.is_visible_in_tree()


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _frame in range(max_frames):
		if bool(predicate.call()):
			return true
		await get_tree().process_frame
	return bool(predicate.call())


func _test_defeat_buttons(arena: Node) -> bool:
	var screen: Node = arena.get_node_or_null("GameOverScreen")
	if screen == null:
		_fail("GameOverScreen missing")
		return false
	var root: Control = screen.get("root") as Control
	var title: Label = screen.get("title_label") as Label
	var summary: Label = screen.get("summary_label") as Label
	var restart_button: Button = screen.get("restart_button") as Button
	var main_menu_button: Button = screen.get("main_menu_button") as Button
	if root == null or title == null or summary == null or restart_button == null or main_menu_button == null:
		_fail("defeat UI control missing")
		return false
	if title.text != "任務失敗" or not summary.text.contains("先鋒的殘響"):
		_fail("defeat UI copy missing")
		return false
	for button in [restart_button, main_menu_button]:
		if not button.is_visible_in_tree() or button.disabled or button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			_fail("defeat action button is not actionable: " + button.text)
			return false
	if restart_button.text != "再來一局" or main_menu_button.text != "回主選單":
		_fail("defeat action copy drifted")
		return false

	var restart_handler := Callable(arena, "_on_restart_requested")
	var main_menu_handler := Callable(arena, "_on_main_menu_requested")
	if not screen.restart_requested.is_connected(restart_handler):
		_fail("restart button signal is not connected to Arena")
		return false
	if not screen.main_menu_requested.is_connected(main_menu_handler):
		_fail("main-menu button signal is not connected to Arena")
		return false

	screen.restart_requested.connect(_on_restart_probe)
	screen.restart_requested.disconnect(restart_handler)
	restart_button.pressed.emit()
	await get_tree().process_frame
	if restart_trigger_count != 1 or root.visible:
		_fail("restart button did not trigger its action signal")
		return false

	var displayed_summary: Dictionary = screen.get("displayed_summary")
	screen.call("show_summary", displayed_summary)
	await get_tree().process_frame
	screen.main_menu_requested.connect(_on_main_menu_probe)
	screen.main_menu_requested.disconnect(main_menu_handler)
	main_menu_button.pressed.emit()
	await get_tree().process_frame
	if main_menu_trigger_count != 1 or root.visible:
		_fail("main-menu button did not trigger its action signal")
		return false
	return true


func _on_restart_probe() -> void:
	restart_trigger_count += 1


func _on_main_menu_probe() -> void:
	main_menu_trigger_count += 1


func _result_ok(result: Dictionary, path_id: String) -> bool:
	if bool(result.get("ok", false)):
		return true
	_fail("%s hook failed: %s" % [path_id, str(result.get("error", "unknown"))])
	return false


func _fail(message: String) -> void:
	get_tree().paused = false
	GameManager.clear_time_scale_owners()
	printerr("R31_ENDGAME_GATE_FAIL: " + message)
	get_tree().quit(1)
