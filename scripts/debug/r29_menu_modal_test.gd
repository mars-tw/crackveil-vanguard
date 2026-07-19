extends Node

## R29 選單模態迴歸 gate：
## P0-1 設定面板單欄流式（390 直向單欄、桌機兩欄、滑桿不溢出、面板寬 clamp）
## P0-2 面板模態（近不透明深底、backdrop、ui_cancel 關閉、面板外點擊關閉）
## P1-4 玩法面板逐則列表結構

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const MAIN_MENU_SCRIPT := preload("res://scripts/ui/main_menu.gd")

var current_phase: String = "boot"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_watchdog")
	call_deferred("_run_tests")


func _watchdog() -> void:
	await get_tree().create_timer(20.0, true).timeout
	if current_phase != "done":
		_fail("watchdog timeout at phase: " + current_phase)


func _run_tests() -> void:
	current_phase = "portrait_modal"
	if not await _test_portrait_modal():
		return
	current_phase = "desktop_columns"
	if not await _test_desktop_columns():
		return
	current_phase = "done"
	print("R29_MENU_MODAL_PASS portrait=single_column desktop=two_column modal=backdrop+ui_cancel panel_alpha>=0.94")
	get_tree().quit(0)


func _test_portrait_modal() -> bool:
	var phone_hints := {"mobile_os": false, "ua_mobile": true, "ua_phone": true, "ua_tablet": false, "touch_available": true, "primary_coarse": true, "mouse_available": false}
	MOBILE_TUNING.set_device_hints_override_for_tests(phone_hints)
	var viewport := _make_ui_viewport(Vector2(390.0, 844.0))
	var menu := MAIN_MENU_SCRIPT.new()
	viewport.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	# P0-2a：面板底必須近不透明（alpha >= 0.94），modulate 不得再半透明。
	var panel_style := menu.side_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style == null or panel_style.bg_color.a < 0.94:
		_fail("side panel background not near-opaque (P0-2a)")
		return false

	menu._show_panel("guide")
	await get_tree().process_frame
	if not menu.side_panel.visible or menu.panel_backdrop == null or not menu.panel_backdrop.visible:
		_fail("guide panel did not raise modal backdrop")
		return false
	if menu.side_panel.modulate.a < 0.999:
		_fail("side panel modulate is translucent again")
		return false

	# P1-4：玩法面板為七則＋一提示的逐則列表。
	var label_count := 0
	for child in menu.side_content.get_children():
		if child is Label:
			label_count += 1
	if label_count != 8:
		_fail("guide panel row count drifted: %d" % label_count)
		return false

	# P0-2b：ui_cancel（Esc／Android back）關閉面板與 backdrop。
	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	menu._unhandled_input(cancel_event)
	await get_tree().process_frame
	if menu.side_panel.visible or menu.panel_backdrop.visible:
		_fail("ui_cancel did not close the panel")
		return false

	# P0-2b：面板外（backdrop）點擊關閉。
	menu._show_panel("achievements")
	await get_tree().process_frame
	if not menu.panel_backdrop.visible:
		_fail("achievements panel did not raise modal backdrop")
		return false
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	menu._on_backdrop_gui_input(click)
	await get_tree().process_frame
	if menu.side_panel.visible or menu.panel_backdrop.visible:
		_fail("backdrop tap did not close the panel")
		return false

	# P0-1：390 直向設定切換群單欄、控制不水平溢出、面板寬 clamp <= viewport-24。
	menu._show_panel("settings")
	await get_tree().process_frame
	await get_tree().process_frame
	if menu.settings_toggle_grid == null or menu.settings_toggle_grid.columns != 1:
		_fail("portrait settings toggles are not single column")
		return false
	var content_rect: Rect2 = menu.side_content.get_global_rect()
	for control_value in [menu.volume_slider, menu.ui_scale_slider, menu.damage_numbers_check, menu.force_joystick_check]:
		var control := control_value as Control
		if control == null:
			_fail("settings control missing")
			return false
		var rect := control.get_global_rect()
		if rect.end.x > content_rect.end.x + 0.75:
			_fail("settings control overflows content horizontally: " + str(rect))
			return false
	if menu.side_panel.get_global_rect().size.x > 390.0 - 24.0 + 0.75:
		_fail("panel width exceeds viewport-24 clamp")
		return false
	viewport.queue_free()
	MOBILE_TUNING.set_device_hints_override_for_tests()
	print("R29_PORTRAIT_MODAL panel_alpha=%.2f guide_rows=%d columns=1" % [panel_style.bg_color.a, label_count])
	return true


func _test_desktop_columns() -> bool:
	var desktop_hints := {"mobile_os": false, "ua_mobile": false, "ua_phone": false, "ua_tablet": false, "touch_available": false, "primary_coarse": false, "mouse_available": true}
	MOBILE_TUNING.set_device_hints_override_for_tests(desktop_hints)
	var viewport := _make_ui_viewport(Vector2(1280.0, 720.0))
	var menu := MAIN_MENU_SCRIPT.new()
	viewport.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	menu._show_panel("settings")
	await get_tree().process_frame
	if menu.settings_toggle_grid == null or menu.settings_toggle_grid.columns != 2:
		_fail("desktop settings toggles did not use two columns")
		return false
	viewport.queue_free()
	MOBILE_TUNING.set_device_hints_override_for_tests()
	print("R29_DESKTOP_COLUMNS columns=2")
	return true


func _make_ui_viewport(size: Vector2) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(size.x), int(size.y))
	viewport.disable_3d = true
	add_child(viewport)
	return viewport


func _fail(message: String) -> void:
	MOBILE_TUNING.set_device_hints_override_for_tests()
	printerr("R29_MENU_MODAL_FAIL: " + message)
	get_tree().quit(1)
