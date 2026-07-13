extends Node

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const JOYSTICK_SCRIPT := preload("res://scripts/ui/virtual_joystick.gd")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const CONTRACT_SCREEN_SCRIPT := preload("res://scripts/ui/contract_screen.gd")
const LEVEL_UP_SCREEN_SCRIPT := preload("res://scripts/ui/level_up_screen.gd")
const STAGE_VICTORY_SCRIPT := preload("res://scripts/ui/stage_victory_screen.gd")
const GAME_OVER_SCRIPT := preload("res://scripts/ui/game_over_screen.gd")
const BACKGROUND_SCRIPT := preload("res://scripts/arena/arena_background.gd")
const HAZARD_SCRIPT := preload("res://scripts/projectiles/hazard_zone.gd")
const PROJECTILE_SCENE := preload("res://scenes/projectiles/Projectile.tscn")

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
	print("M1_FLOW_CONFIRMATIONS contract=true level_up_window_ms=%d" % LEVEL_UP_SCREEN_SCRIPT.MOBILE_CONFIRM_WINDOW_MSEC)
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
		{"id": "m1_upgrade_a", "name": "M1 Upgrade A", "description": "Touch confirmation regression A."},
		{"id": "m1_upgrade_b", "name": "M1 Upgrade B", "description": "Touch confirmation regression B."}
	])
	await get_tree().process_frame
	var first_button: Button = screen.option_buttons[0]
	var second_button: Button = screen.option_buttons[1]
	var first_text := first_button.text
	first_button.pressed.emit()
	await get_tree().process_frame
	if emitted.size() != 0 or not screen.root.visible:
		_fail("level up first tap selected instead of confirming")
		return false
	if screen.pending_mobile_confirm_button != first_button or first_button.text != first_text:
		_fail("level up first tap did not highlight without obscuring card text")
		return false
	second_button.pressed.emit()
	await get_tree().process_frame
	if emitted.size() != 0 or screen.pending_mobile_confirm_button != second_button:
		_fail("level up different card tap did not switch highlight")
		return false
	first_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().create_timer(0.38, true).timeout
	first_button.pressed.emit()
	await get_tree().process_frame
	if emitted.size() != 0 or screen.pending_mobile_confirm_button != first_button:
		_fail("level up expired confirm window selected instead of restarting")
		return false
	first_button.pressed.emit()
	await get_tree().process_frame
	if emitted.size() != 1 or screen.root.visible:
		_fail("level up same-card tap inside 350ms did not select")
		return false
	viewport.queue_free()
	return true


func _test_mobile_lod_profile() -> bool:
	var desktop := Vector2(1280.0, 720.0)
	var narrow_desktop := Vector2(620.0, 900.0)
	var portrait := Vector2(390.0, 844.0)
	var tablet := Vector2(1024.0, 768.0)
	var touch_desktop := Vector2(1920.0, 1080.0)
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
	var desktop_mouse_hints := {"mobile_os": false, "ua_mobile": false, "touch_available": false, "mouse_available": true}
	var touch_desktop_hints := {"mobile_os": false, "ua_mobile": false, "touch_available": true, "mouse_available": true}
	var touch_only_hints := {"mobile_os": false, "ua_mobile": false, "touch_available": true, "mouse_available": false}
	var mobile_ua_hints := {"mobile_os": false, "ua_mobile": true, "touch_available": true, "mouse_available": true}
	var tablet_hints := {"mobile_os": false, "ua_mobile": true, "ua_phone": false, "ua_tablet": true, "touch_available": true, "mouse_available": false}
	var touch_desktop_formfactor_hints := {"mobile_os": false, "ua_mobile": false, "ua_phone": false, "ua_tablet": false, "touch_available": true, "mouse_available": true}
	if MOBILE_TUNING.layout_tier_name(portrait, false, mobile_ua_hints) != "phone":
		_fail("390x844 form factor stopped being phone")
		return false
	if MOBILE_TUNING.layout_tier_name(tablet, false, tablet_hints) != "tablet":
		_fail("1024x768 touch form factor stopped being tablet")
		return false
	if MOBILE_TUNING.layout_tier_name(touch_desktop, false, touch_desktop_formfactor_hints) != "desktop":
		_fail("1920x1080 touch desktop form factor was downgraded")
		return false
	if MOBILE_TUNING.mobile_lod_enabled(touch_desktop, false, touch_desktop_formfactor_hints):
		_fail("touch desktop form-factor fix changed M1 LOD semantics")
		return false
	if MOBILE_TUNING.mobile_lod_enabled(narrow_desktop, false, desktop_mouse_hints):
		_fail("narrow mouse desktop unexpectedly uses mobile LOD")
		return false
	if MOBILE_TUNING.mobile_lod_enabled(desktop, false, touch_desktop_hints):
		_fail("touch desktop with mouse unexpectedly uses mobile LOD")
		return false
	if not MOBILE_TUNING.mobile_lod_enabled(desktop, false, touch_only_hints):
		_fail("touch-only device did not enable mobile LOD")
		return false
	if not MOBILE_TUNING.mobile_lod_enabled(desktop, false, mobile_ua_hints):
		_fail("mobile UA hint did not enable mobile LOD")
		return false
	if not MOBILE_TUNING.use_mobile_ui(narrow_desktop, false):
		_fail("narrow desktop stopped receiving responsive UI")
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
	if MOBILE_TUNING.death_burst_cap(portrait, EntityFactory.DEATH_BURST_CAP, true) != 8:
		_fail("mobile death burst cap drifted")
		return false
	if MOBILE_TUNING.corpse_ghost_cap(portrait, EntityFactory.CORPSE_GHOST_CAP, true) != 12:
		_fail("mobile corpse ghost cap drifted")
		return false
	if abs(MOBILE_TUNING.hazard_tick_interval(portrait, 0.24, true) - 0.24) > 0.001:
		_fail("mobile hazard gameplay tick diverged")
		return false
	var desktop_damage := _simulate_hazard_damage(51037, false)
	var mobile_damage := _simulate_hazard_damage(51037, true)
	if desktop_damage != mobile_damage:
		_fail("same-seed hazard damage diverged across LOD: desktop=%s mobile=%s" % [str(desktop_damage), str(mobile_damage)])
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
	var mobile_dust := int(background_state.get("dust_amount", 0))
	MOBILE_TUNING.set_force_mobile_lod_for_tests(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var restored_background_state: Dictionary = background.get_mobile_lod_debug_state()
	if bool(restored_background_state.get("applied_mobile_lod", true)):
		_fail("background did not restore desktop LOD after rotation/resize")
		return false
	if int(restored_background_state.get("dust_amount", 0)) <= mobile_dust:
		_fail("live dust amount did not restore on mobile-to-desktop switch")
		return false
	if int(restored_background_state.get("decor_target", 0)) != BACKGROUND_SCRIPT.DECOR_POOL_SIZE:
		_fail("live decor target did not restore on mobile-to-desktop switch")
		return false

	var hazard := HAZARD_SCRIPT.new()
	viewport.add_child(hazard)
	hazard.pool_on_acquire()
	hazard.setup(Vector2.ZERO, {"tick_interval": 0.24, "damage_per_second": 10.0, "duration": 10.0}, null)
	await get_tree().process_frame
	var desktop_hazard_state: Dictionary = hazard.get_mobile_lod_debug_state()
	MOBILE_TUNING.set_force_mobile_lod_for_tests(true)
	await get_tree().process_frame
	var mobile_hazard_state: Dictionary = hazard.get_mobile_lod_debug_state()
	if not bool(mobile_hazard_state.get("mobile_lod", false)):
		_fail("live hazard did not apply mobile visual LOD")
		return false
	if abs(float(mobile_hazard_state.get("tick_interval", 0.0)) - float(desktop_hazard_state.get("tick_interval", -1.0))) > 0.0001:
		_fail("live hazard visual LOD changed gameplay tick")
		return false
	if float(mobile_hazard_state.get("visual_redraw_interval", 0.0)) <= float(desktop_hazard_state.get("visual_redraw_interval", 0.0)):
		_fail("mobile hazard visual redraw interval did not reduce redraw frequency")
		return false
	MOBILE_TUNING.set_force_mobile_lod_for_tests(false)
	await get_tree().process_frame
	var restored_hazard_state: Dictionary = hazard.get_mobile_lod_debug_state()
	if bool(restored_hazard_state.get("mobile_lod", true)) or abs(float(restored_hazard_state.get("visual_redraw_interval", 0.0)) - HAZARD_SCRIPT.BASE_VISUAL_REDRAW_INTERVAL) > 0.0001:
		_fail("live hazard did not restore desktop visual LOD")
		return false
	hazard.queue_free()

	viewport.size = Vector2i(390, 844)
	var projectile := PROJECTILE_SCENE.instantiate()
	viewport.add_child(projectile)
	projectile.pool_on_acquire()
	projectile.setup(Vector2.ZERO, Vector2.RIGHT, {
		"projectile_speed": 0.0,
		"damage": 1.0,
		"range": 10000.0,
		"projectile_radius": 5.0,
		"target_group": "heroes"
	}, null)
	await get_tree().process_frame
	if not bool(projectile.get_mobile_readability_debug_state().get("mobile_readability", false)):
		_fail("live enemy projectile did not start with portrait readability")
		return false
	viewport.size = Vector2i(1280, 720)
	await get_tree().process_frame
	projectile._refresh_projectile_readability()
	if bool(projectile.get_mobile_readability_debug_state().get("mobile_readability", true)):
		_fail("live enemy projectile did not restore desktop readability after resize")
		return false
	projectile.queue_free()
	viewport.queue_free()
	MOBILE_TUNING.set_force_mobile_lod_for_tests(false)
	print("M1_LOD particle=0.60 damage_cap=30 hazard_tick=0.240 visual_redraw=%.4f same_seed_damage=%.3f ticks=%d dust_mobile=%d dust_desktop=%d" % [
		float(mobile_hazard_state.get("visual_redraw_interval", 0.0)),
		float(mobile_damage.get("damage", 0.0)),
		int(mobile_damage.get("ticks", 0)),
		mobile_dust,
		int(restored_background_state.get("dust_amount", 0))
	])
	return true


func _simulate_hazard_damage(run_seed: int, force_mobile_lod: bool) -> Dictionary:
	MOBILE_TUNING.set_force_mobile_lod_for_tests(force_mobile_lod)
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var damage_total := 0.0
	var tick_total := 0
	for sample in range(36):
		var base_interval := rng.randf_range(0.18, 0.46)
		var tick_interval := MOBILE_TUNING.hazard_tick_interval(Vector2(390.0, 844.0), base_interval)
		var damage_per_second := rng.randf_range(3.0, 18.0)
		var duration := rng.randf_range(0.28, 2.4)
		var age := 0.0
		var tick_timer := 0.0
		while age < duration:
			var delta := rng.randf_range(0.012, 0.021)
			age += delta
			tick_timer -= delta
			if tick_timer <= 0.0:
				damage_total += damage_per_second * tick_interval
				tick_total += 1
				tick_timer = tick_interval
	return {"damage": snappedf(damage_total, 0.000001), "ticks": tick_total}


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
