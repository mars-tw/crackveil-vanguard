extends Node

const BACKGROUND_SCRIPT := preload("res://scripts/arena/arena_background.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const RUN_THEME := preload("res://scripts/arena/run_theme.gd")
const MAIN_MENU_SCRIPT := preload("res://scripts/ui/main_menu.gd")
const CONTRACT_SCREEN_SCRIPT := preload("res://scripts/ui/contract_screen.gd")
const LEVEL_UP_SCREEN_SCRIPT := preload("res://scripts/ui/level_up_screen.gd")
const FIRST_RUN_GUIDE_SCRIPT := preload("res://scripts/ui/first_run_guide.gd")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")

var current_phase: String = "boot"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(14014)
	call_deferred("_watchdog")
	call_deferred("_run_tests")


func _watchdog() -> void:
	await get_tree().create_timer(12.0, true).timeout
	if current_phase != "done":
		_fail("watchdog timeout at phase: " + current_phase)


func _run_tests() -> void:
	current_phase = "mobile_ui"
	var mobile_ok := await _test_mobile_ui_scaling()
	if not mobile_ok:
		return
	current_phase = "camera"
	if not _test_camera_zoom_branch():
		return
	current_phase = "background"
	if not await _test_background_evolution_determinism():
		return

	current_phase = "done"
	print("R14_REGRESSION_PASS")
	get_tree().quit(0)


func _test_mobile_ui_scaling() -> bool:
	var portrait := Vector2(390.0, 844.0)
	var landscape := Vector2(844.0, 390.0)
	var narrow_desktop := Vector2(680.0, 900.0)
	var desktop := Vector2(1280.0, 720.0)
	if not MOBILE_TUNING.use_mobile_ui(portrait, false):
		_fail("portrait viewport did not use mobile UI")
		return false
	if not MOBILE_TUNING.use_mobile_ui(landscape, false):
		_fail("landscape viewport did not use mobile UI")
		return false
	if not MOBILE_TUNING.use_mobile_ui(narrow_desktop, false):
		_fail("narrow desktop viewport did not use mobile UI")
		return false
	if MOBILE_TUNING.ui_scale(portrait, true) < 1.9 or MOBILE_TUNING.ui_scale(landscape, true) < 1.8:
		_fail("mobile UI scale below readability floor")
		return false

	var root := Control.new()
	var button := Button.new()
	button.add_theme_font_size_override("font_size", 20)
	button.custom_minimum_size = Vector2(120.0, 38.0)
	root.add_child(button)
	add_child(root)
	MOBILE_TUNING.apply_control_tree(root, portrait, true)
	var mobile_font := button.get_theme_font_size("font_size")
	if mobile_font < 38:
		_fail("button font did not scale enough: %d" % mobile_font)
		return false
	if button.custom_minimum_size.y < 72.0:
		_fail("touch target below mobile readability floor")
		return false
	MOBILE_TUNING.apply_control_tree(root, desktop, false)
	if button.get_theme_font_size("font_size") != 20:
		_fail("desktop font override was not restored")
		return false
	root.queue_free()
	if not await _test_main_menu_mobile_layout(portrait):
		return false
	if not await _test_main_menu_mobile_layout(landscape):
		return false
	if not await _test_contract_mobile_layout(portrait):
		return false
	if not await _test_contract_mobile_layout(landscape):
		return false
	if not await _test_level_up_mobile_layout(portrait):
		return false
	if not await _test_level_up_mobile_layout(landscape):
		return false
	if not await _test_guide_mobile_layout(portrait):
		return false
	if not await _test_guide_mobile_layout(landscape):
		return false
	if not await _test_hud_mobile_layout(portrait):
		return false
	if not await _test_hud_mobile_layout(landscape):
		return false
	print("R14_MOBILE_UI portrait_scale=%.2f landscape_scale=%.2f font=%d touch=%.1f" % [
		MOBILE_TUNING.ui_scale(portrait, true),
		MOBILE_TUNING.ui_scale(landscape, true),
		mobile_font,
		MOBILE_TUNING.touch_target(portrait, true)
	])
	return true


func _test_main_menu_mobile_layout(size: Vector2) -> bool:
	var viewport := _make_ui_viewport(size)
	var menu := MAIN_MENU_SCRIPT.new()
	viewport.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var portrait := size.y > size.x
	if menu.settings_button == null or not menu.settings_button.visible:
		_fail("main menu settings button missing")
		return false
	if not _control_inside_viewport(menu.settings_button, size, "main menu settings"):
		return false
	if not _control_inside_viewport(menu.menu_box, size, "main menu button stack"):
		return false
	if menu.start_button.custom_minimum_size.y < 56.0:
		_fail("main menu button height below 56px")
		return false
	if portrait and menu.start_button.custom_minimum_size.x < size.x * 0.84:
		_fail("main menu portrait button width below 84 percent")
		return false
	if menu.start_button.get_theme_font_size("font_size") < 22:
		_fail("main menu button font below 22px")
		return false
	menu._show_panel("settings")
	await get_tree().process_frame
	if not _control_inside_viewport(menu.side_panel, size, "main menu settings panel"):
		return false
	if menu.side_scroll == null or menu.side_scroll.size.y <= 0.0:
		_fail("main menu settings panel has no scrollable body")
		return false
	viewport.queue_free()
	return true


func _test_contract_mobile_layout(size: Vector2) -> bool:
	var viewport := _make_ui_viewport(size)
	var screen := CONTRACT_SCREEN_SCRIPT.new()
	viewport.add_child(screen)
	await get_tree().process_frame
	screen.show_options(_sample_options())
	await get_tree().process_frame
	var portrait := size.y > size.x
	if not _control_inside_viewport(screen.panel, size, "contract panel"):
		return false
	if not _control_inside_viewport(screen.card_scroll, size, "contract card scroll"):
		return false
	if portrait and screen.card_grid.columns != 1:
		_fail("contract portrait cards are not single column")
		return false
	if not portrait and screen.card_grid.columns < 3:
		_fail("contract landscape cards did not use available width")
		return false
	if screen.option_buttons.is_empty():
		_fail("contract options were not created")
		return false
	var first_button: Button = screen.option_buttons[0]
	if first_button.get_theme_font_size("font_size") < 18:
		_fail("contract card font below 18px")
		return false
	if portrait and first_button.custom_minimum_size.x < size.x * 0.78:
		_fail("contract portrait card width below readable floor")
		return false
	if screen.card_scroll.size.y < (180.0 if portrait else 160.0):
		_fail("contract card scroll area too short")
		return false
	viewport.queue_free()
	return true


func _test_level_up_mobile_layout(size: Vector2) -> bool:
	var viewport := _make_ui_viewport(size)
	var screen := LEVEL_UP_SCREEN_SCRIPT.new()
	viewport.add_child(screen)
	await get_tree().process_frame
	screen.show_options(_sample_options())
	await get_tree().process_frame
	var portrait := size.y > size.x
	if not _control_inside_viewport(screen.panel, size, "level up panel"):
		return false
	if not _control_inside_viewport(screen.card_scroll, size, "level up card scroll"):
		return false
	if portrait and screen.card_grid.columns != 1:
		_fail("level up portrait cards are not single column")
		return false
	if not portrait and screen.card_grid.columns != 3:
		_fail("level up landscape cards are not three columns")
		return false
	if screen.option_buttons.is_empty():
		_fail("level up options were not created")
		return false
	var first_button: Button = screen.option_buttons[0]
	if first_button.get_theme_font_size("font_size") < 18:
		_fail("level up card font below 18px")
		return false
	if portrait and first_button.custom_minimum_size.y < 240.0:
		_fail("level up portrait card height below readable floor")
		return false
	viewport.queue_free()
	return true


func _test_guide_mobile_layout(size: Vector2) -> bool:
	var viewport := _make_ui_viewport(size)
	var guide := FIRST_RUN_GUIDE_SCRIPT.new()
	viewport.add_child(guide)
	await get_tree().process_frame
	if not _control_inside_viewport(guide.panel, size, "guide panel"):
		return false
	if not _control_inside_viewport(guide.body_label, size, "guide body"):
		return false
	if guide.body_label.get_theme_font_size("font_size") < 20:
		_fail("guide body font below 20px")
		return false
	if guide.start_button.custom_minimum_size.y < 56.0:
		_fail("guide start touch target below 56px")
		return false
	viewport.queue_free()
	return true


func _test_hud_mobile_layout(size: Vector2) -> bool:
	var viewport := _make_ui_viewport(size)
	var hud := HUD_SCRIPT.new()
	viewport.add_child(hud)
	await get_tree().process_frame
	hud._on_stats_changed({
		"hp": 100,
		"max_hp": 120,
		"level": 5,
		"xp": 42,
		"xp_required": 80,
		"elapsed_time": 75.0,
		"kills": 123,
		"gold": 45,
		"echo_shards": 6,
		"manual_pause_visible": false,
		"run_theme_name": "Void"
	})
	await get_tree().process_frame
	if hud.hp_label.get_theme_font_size("font_size") < 24:
		_fail("HUD HP font below mobile floor")
		return false
	if hud.time_label.get_theme_font_size("font_size") < 28:
		_fail("HUD timer font below mobile floor")
		return false
	if not _control_inside_viewport(hud.pause_button, size, "HUD pause button"):
		return false
	if not _control_inside_viewport(hud.hud_panel, size, "HUD stat panel"):
		return false
	if not _control_inside_viewport(hud.score_panel, size, "HUD score panel"):
		return false
	if _controls_overlap(hud.time_label, hud.pause_button):
		_fail("HUD timer overlaps pause button")
		return false
	if _controls_overlap(hud.score_label, hud.pause_button):
		_fail("HUD score overlaps pause button")
		return false
	viewport.queue_free()
	return true


func _make_ui_viewport(size: Vector2) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(size.x), int(size.y))
	viewport.disable_3d = true
	add_child(viewport)
	return viewport


func _sample_options() -> Array:
	return [
		{
			"name": "Readable Alpha",
			"description": "Large mobile text wraps cleanly without hiding the action."
		},
		{
			"name": "Readable Beta",
			"description": "Cards must remain tappable in portrait and landscape."
		},
		{
			"name": "Readable Gamma",
			"description": "Narrow layouts use scrollable space instead of clipping."
		}
	]


func _control_inside_viewport(control: Control, size: Vector2, label: String) -> bool:
	if control == null:
		_fail(label + " control missing")
		return false
	var rect := control.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_fail(label + " has empty rect")
		return false
	var epsilon := 0.75
	if rect.position.x < -epsilon or rect.position.y < -epsilon:
		_fail("%s starts outside viewport: %s" % [label, str(rect)])
		return false
	if rect.end.x > size.x + epsilon or rect.end.y > size.y + epsilon:
		_fail("%s overflows viewport: %s size=%s" % [label, str(rect), str(size)])
		return false
	return true


func _controls_overlap(a: Control, b: Control) -> bool:
	if a == null or b == null:
		return false
	var a_rect := a.get_global_rect()
	var b_rect := b.get_global_rect()
	return a_rect.intersects(b_rect)


func _test_camera_zoom_branch() -> bool:
	var portrait := Vector2(390.0, 844.0)
	var desktop := Vector2(1280.0, 720.0)
	var desktop_zoom := MOBILE_TUNING.leader_camera_zoom(desktop, false)
	var mobile_zoom := MOBILE_TUNING.leader_camera_zoom(portrait, true)
	var mobile_threat := MOBILE_TUNING.leader_threat_camera_zoom(portrait, true)
	if abs(desktop_zoom.x - 1.28) > 0.001:
		_fail("desktop camera zoom changed")
		return false
	if mobile_zoom.x < 1.5 or mobile_zoom.x > 1.6:
		_fail("mobile camera zoom outside 1.5-1.6: %.2f" % mobile_zoom.x)
		return false
	if mobile_threat.x >= mobile_zoom.x or mobile_threat.x <= 1.28:
		_fail("mobile threat zoom did not scale with base zoom")
		return false
	print("R14_CAMERA desktop=%.2f mobile=%.2f threat=%.2f" % [
		desktop_zoom.x,
		mobile_zoom.x,
		mobile_threat.x
	])
	return true


func _test_background_evolution_determinism() -> bool:
	var seed_a := 14001
	var seed_b := 14002
	var bg_a := BACKGROUND_SCRIPT.new()
	var bg_b := BACKGROUND_SCRIPT.new()
	var bg_c := BACKGROUND_SCRIPT.new()
	add_child(bg_a)
	add_child(bg_b)
	add_child(bg_c)
	await get_tree().process_frame

	bg_a.configure_run_theme(seed_a, RUN_THEME.select_theme_id(seed_a))
	bg_b.configure_run_theme(seed_a, RUN_THEME.select_theme_id(seed_a))
	bg_c.configure_run_theme(seed_b, RUN_THEME.select_theme_id(seed_b))
	var center := Vector2(512.0, -384.0)
	var interval := float(bg_a.get("evolution_interval"))
	if interval < 60.0 or interval > 90.0:
		_fail("evolution interval outside 60-90s")
		return false
	var sig_a := bg_a.get_background_evolution_signature(center, interval + 2.0)
	var sig_b := bg_b.get_background_evolution_signature(center, interval + 2.0)
	var sig_c := bg_c.get_background_evolution_signature(center, interval + 2.0)
	var sig_early := bg_a.get_background_evolution_signature(center, 0.0)
	var sig_far := bg_a.get_background_evolution_signature(center + Vector2(DECOR_OFFSET(), 0.0), interval + 2.0)
	if sig_a != sig_b:
		_fail("background evolution not reproducible for same seed")
		return false
	if sig_a == sig_c:
		_fail("background evolution did not change across seeds")
		return false
	if sig_a == sig_early:
		_fail("background signature did not evolve over time")
		return false
	if sig_a == sig_far:
		_fail("decor density zone did not change across travel")
		return false
	bg_a.set("boss_flash_timer", float(bg_a.get("boss_flash_duration")) * 0.5)
	if float(bg_a.call("_boss_flash_ratio")) < 0.9:
		_fail("boss flash ratio did not peak")
		return false
	print("R14_BACKGROUND interval=%.2f sig_len=%d" % [interval, sig_a.length()])
	return true


func DECOR_OFFSET() -> float:
	return 245.0 * 16.0


func _fail(message: String) -> void:
	printerr("R14_REGRESSION_FAIL: " + message)
	get_tree().quit(1)
