extends Node

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const JOYSTICK_SCRIPT := preload("res://scripts/ui/virtual_joystick.gd")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const CONTRACT_SCREEN_SCRIPT := preload("res://scripts/ui/contract_screen.gd")
const LEVEL_UP_SCREEN_SCRIPT := preload("res://scripts/ui/level_up_screen.gd")
const STAGE_VICTORY_SCRIPT := preload("res://scripts/ui/stage_victory_screen.gd")
const GAME_OVER_SCRIPT := preload("res://scripts/ui/game_over_screen.gd")
const BACKGROUND_SCRIPT := preload("res://scripts/arena/arena_background.gd")

var current_phase: String = "boot"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(1001)
	call_deferred("_watchdog")
	call_deferred("_run_tests")


func _watchdog() -> void:
	await get_tree().create_timer(12.0, true).timeout
	if current_phase != "done":
		_fail("watchdog timeout at phase: " + current_phase)


func _run_tests() -> void:
	current_phase = "ergonomics"
	print("M1_PHASE ergonomics")
	if not await _test_mobile_ergonomics():
		return
	current_phase = "hud"
	print("M1_PHASE hud")
	if not await _test_mobile_hud_readability():
		return
	current_phase = "flow"
	print("M1_PHASE flow")
	if not await _test_mobile_flow_confirmations():
		return
	current_phase = "lod"
	print("M1_PHASE lod")
	if not await _test_mobile_lod_profile():
		return
	current_phase = "results"
	print("M1_PHASE results")
	if not await _test_result_thumb_reach():
		return

	current_phase = "done"
	print("M1_REGRESSION_PASS")
	get_tree().quit(0)


func _test_mobile_ergonomics() -> bool:
	var portrait := Vector2(390.0, 844.0)
	var landscape := Vector2(844.0, 390.0)
	var sizes: Array[Vector2] = [portrait, landscape]
	for index in range(sizes.size()):
		var size: Vector2 = sizes[index]
		var portrait_mode: bool = size.y > size.x
		var joystick: Control = JOYSTICK_SCRIPT.new()
		var joystick_size: Vector2 = joystick.configure_for_viewport(size, true, 1)
		var visual_radius: float = float(joystick.get("stick_radius"))
		if abs(float(joystick.get("heat_zone_multiplier")) - MOBILE_TUNING.MOBILE_JOYSTICK_HEAT_ZONE_MULTIPLIER) > 0.001:
			_fail("joystick heat multiplier drifted")
			return false
		if joystick_size.x < visual_radius * 2.0 * MOBILE_TUNING.MOBILE_JOYSTICK_HEAT_ZONE_MULTIPLIER - 0.5:
			_fail("joystick heat zone below M1 multiplier")
			return false
		var joystick_rect: Rect2 = MOBILE_TUNING.joystick_rect(size, joystick_size, true)
		var ability_rect: Rect2 = MOBILE_TUNING.ability_button_rect(size, true)
		if not _rect_inside(joystick_rect, size) or not _rect_inside(ability_rect, size):
			_fail("thumb controls outside viewport")
			return false
		if joystick_rect.grow(10.0).intersects(ability_rect.grow(10.0)):
			_fail("joystick and ability heat zones overlap")
			return false
		if portrait_mode and ability_rect.size.x < 92.0:
			_fail("portrait ability button below 92px")
			return false
		if not portrait_mode and ability_rect.size.x < 84.0:
			_fail("landscape ability button below 84px")
			return false
		if ability_rect.get_center().y < size.y * 0.72:
			_fail("ability button not in lower thumb band")
			return false
		joystick.queue_free()
	print("M1_ERGONOMICS portrait_ability=%.0f landscape_ability=%.0f heat=%.2f" % [
		MOBILE_TUNING.ability_button_size(portrait, true),
		MOBILE_TUNING.ability_button_size(landscape, true),
		MOBILE_TUNING.MOBILE_JOYSTICK_HEAT_ZONE_MULTIPLIER
	])
	return true


func _test_mobile_hud_readability() -> bool:
	var size := Vector2(390.0, 844.0)
	var viewport := _make_ui_viewport(size)
	var hud := HUD_SCRIPT.new()
	viewport.add_child(hud)
	await get_tree().process_frame
	if hud.has_method("set_touch_controls_forced_visible"):
		hud.set_touch_controls_forced_visible(true)
	hud._on_stats_changed({
		"hp": 88,
		"max_hp": 120,
		"level": 6,
		"xp": 32,
		"xp_required": 90,
		"elapsed_time": 96.0,
		"kills": 144,
		"gold": 77,
		"echo_shards": 8,
		"manual_pause_visible": false,
		"run_theme_name": "Void"
	})
	await get_tree().process_frame
	if hud.gold_icon.visible:
		_fail("mobile HUD still shows gold icon")
		return false
	if hud.theme_label.visible:
		_fail("mobile HUD still shows theme label")
		return false
	if hud.version_label.visible:
		_fail("mobile HUD still shows version label")
		return false
	if hud.score_label.text.find("金幣") >= 0 or hud.score_label.text.find("殘響") >= 0:
		_fail("mobile score label still contains economy text")
		return false
	if hud.active_ability_cooldown_ring == null:
		_fail("cooldown ring missing")
		return false
	if hud.active_ability_cooldown_ring.size != hud.active_ability_button.size:
		_fail("cooldown ring not aligned with ability button")
		return false
	var pause_rect := hud.pause_button.get_global_rect()
	var ability_rect := MOBILE_TUNING.ability_button_rect(size, true)
	if pause_rect.get_center().y > size.y * 0.16:
		_fail("pause button too close to lower thumb zone")
		return false
	if pause_rect.grow(24.0).intersects(ability_rect):
		_fail("pause button overlaps ability thumb zone")
		return false
	viewport.queue_free()
	print("M1_HUD score=%s pause=%s ability=%s" % [hud.score_label.text, str(pause_rect), str(ability_rect)])
	return true


func _test_mobile_flow_confirmations() -> bool:
	var size := Vector2(390.0, 844.0)
	if not await _test_contract_confirmation(size):
		return false
	if not await _test_level_up_confirmation(size):
		return false
	print("M1_FLOW_CONFIRMATIONS contract=true level_up=true")
	return true


func _test_contract_confirmation(size: Vector2) -> bool:
	var viewport := _make_ui_viewport(size)
	var screen := CONTRACT_SCREEN_SCRIPT.new()
	viewport.add_child(screen)
	await get_tree().process_frame
	var emitted: Array[Dictionary] = []
	screen.contract_selected.connect(func(contract: Dictionary) -> void:
		emitted.append(contract)
	)
	screen.show_options([
		{"id": "m1_contract", "name": "M1 Contract", "description": "Touch confirmation regression."}
	])
	await get_tree().process_frame
	var first_button: Button = screen.option_buttons[0]
	first_button.pressed.emit()
	await get_tree().process_frame
	if emitted.size() != 0 or not screen.root.visible:
		_fail("contract first tap selected instead of confirming")
		return false
	if first_button.text.find("再次點擊確認") < 0:
		_fail("contract first tap did not mark confirm state")
		return false
	first_button.pressed.emit()
	await get_tree().process_frame
	if emitted.size() != 1 or screen.root.visible:
		_fail("contract second tap did not select")
		return false
	viewport.queue_free()
	return true


func _test_level_up_confirmation(size: Vector2) -> bool:
	var viewport := _make_ui_viewport(size)
	var screen := LEVEL_UP_SCREEN_SCRIPT.new()
	viewport.add_child(screen)
	await get_tree().process_frame
	var emitted: Array[Dictionary] = []
	screen.upgrade_selected.connect(func(upgrade: Dictionary) -> void:
		emitted.append(upgrade)
	)
	screen.show_options([
		{"id": "m1_upgrade", "name": "M1 Upgrade", "description": "Touch confirmation regression."}
	])
	await get_tree().process_frame
	var first_button: Button = screen.option_buttons[0]
	first_button.pressed.emit()
	await get_tree().process_frame
	if emitted.size() != 0 or not screen.root.visible:
		_fail("level up first tap selected instead of confirming")
		return false
	if first_button.text.find("再次點擊確認") < 0:
		_fail("level up first tap did not mark confirm state")
		return false
	first_button.pressed.emit()
	await get_tree().process_frame
	if emitted.size() != 1 or screen.root.visible:
		_fail("level up second tap did not select")
		return false
	viewport.queue_free()
	return true


func _test_mobile_lod_profile() -> bool:
	var desktop := Vector2(1280.0, 720.0)
	var portrait := Vector2(390.0, 844.0)
	MOBILE_TUNING.set_force_mobile_lod_for_tests(false)
	if MOBILE_TUNING.mobile_lod_enabled(desktop, false):
		_fail("desktop unexpectedly uses mobile LOD")
		return false
	if abs(MOBILE_TUNING.lod_particle_multiplier(desktop, false) - 1.0) > 0.001:
		_fail("desktop particle multiplier changed")
		return false
	if MOBILE_TUNING.damage_number_cap(desktop, EntityFactory.DAMAGE_NUMBER_CAP, false) != EntityFactory.DAMAGE_NUMBER_CAP:
		_fail("desktop damage number cap changed")
		return false
	if not MOBILE_TUNING.mobile_lod_enabled(portrait, true):
		_fail("portrait did not enable mobile LOD")
		return false
	if abs(MOBILE_TUNING.lod_particle_multiplier(portrait, true) - 0.6) > 0.001:
		_fail("mobile particle multiplier drifted")
		return false
	if MOBILE_TUNING.damage_number_cap(portrait, EntityFactory.DAMAGE_NUMBER_CAP, true) != 30:
		_fail("mobile damage number cap drifted")
		return false
	if MOBILE_TUNING.death_burst_cap(portrait, EntityFactory.DEATH_BURST_CAP, true) != 12:
		_fail("mobile death burst cap drifted")
		return false
	if MOBILE_TUNING.corpse_ghost_cap(portrait, EntityFactory.CORPSE_GHOST_CAP, true) != 12:
		_fail("mobile corpse ghost cap drifted")
		return false
	if abs(MOBILE_TUNING.hazard_tick_interval(portrait, 0.24, true) - 0.372) > 0.001:
		_fail("mobile hazard tick interval drifted")
		return false

	MOBILE_TUNING.set_force_mobile_lod_for_tests(true)
	var viewport := _make_ui_viewport(portrait)
	var background := BACKGROUND_SCRIPT.new()
	viewport.add_child(background)
	await get_tree().process_frame
	var background_state: Dictionary = background.get_mobile_lod_debug_state()
	if not bool(background_state.get("mobile_lod", false)):
		_fail("background did not see mobile LOD")
		return false
	if int(background_state.get("dust_amount", 0)) > 54:
		_fail("background dust amount did not reduce")
		return false
	if int(background_state.get("decor_target", 0)) > 70:
		_fail("background decor target did not reduce")
		return false
	viewport.queue_free()
	MOBILE_TUNING.set_force_mobile_lod_for_tests(false)
	print("M1_LOD particle=0.60 damage_cap=30 hazard_tick=0.372 death_burst_cap=12 corpse_cap=12")
	return true


func _test_result_thumb_reach() -> bool:
	var size := Vector2(390.0, 844.0)
	var viewport := _make_ui_viewport(size)
	var stage := STAGE_VICTORY_SCRIPT.new()
	viewport.add_child(stage)
	await get_tree().process_frame
	stage.show_summary(_sample_summary())
	await get_tree().process_frame
	if not _control_inside_viewport(stage.continue_button, size, "stage continue"):
		return false
	if stage.continue_button.get_global_rect().get_center().y < size.y * 0.66:
		_fail("stage continue button above thumb reach band")
		return false

	var game_over := GAME_OVER_SCRIPT.new()
	viewport.add_child(game_over)
	await get_tree().process_frame
	game_over.show_summary(_sample_summary())
	await get_tree().process_frame
	if not _control_inside_viewport(game_over.restart_button, size, "game over restart"):
		return false
	if game_over.restart_button.get_global_rect().get_center().y < size.y * 0.66:
		_fail("game over restart button above thumb reach band")
		return false
	viewport.queue_free()
	print("M1_RESULT_THUMB_REACH stage_y=%.1f game_over_y=%.1f" % [
		stage.continue_button.get_global_rect().get_center().y,
		game_over.restart_button.get_global_rect().get_center().y
	])
	return true


func _make_ui_viewport(size: Vector2) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = Vector2i(int(size.x), int(size.y))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	return viewport


func _sample_summary() -> Dictionary:
	return {
		"elapsed_time": 213.0,
		"kills": 188,
		"gold": 64,
		"gold_earned": 91,
		"level": 8,
		"elites_spawned": 4,
		"elites_killed": 3,
		"boss_spawned": true,
		"boss_active": false,
		"boss_phase_two_reached": true,
		"boss_killed": true,
		"contract_name": "Regression Contract",
		"echo_shards_earned": 9,
		"echo_shards_run_total": 9,
		"echo_progress": {"shards": 18},
		"achievement_unlocks": []
	}


func _control_inside_viewport(control: Control, size: Vector2, label: String) -> bool:
	if control == null:
		_fail(label + " control missing")
		return false
	var rect := control.get_global_rect()
	if not _rect_inside(rect, size):
		_fail("%s outside viewport: %s size=%s" % [label, str(rect), str(size)])
		return false
	return true


func _rect_inside(rect: Rect2, size: Vector2) -> bool:
	var epsilon := 0.75
	return rect.position.x >= -epsilon and rect.position.y >= -epsilon and rect.end.x <= size.x + epsilon and rect.end.y <= size.y + epsilon


func _fail(message: String) -> void:
	printerr("M1_REGRESSION_FAIL: " + message)
	MOBILE_TUNING.set_force_mobile_lod_for_tests(false)
	get_tree().quit(1)
