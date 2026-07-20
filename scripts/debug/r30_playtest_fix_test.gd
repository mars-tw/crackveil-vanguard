extends Node

## R30 PLAYTEST-R1 修正 gate：
## R1-01 844x390 HUD 垂直分層、R1-02 方向切換後 seed 列收斂、
## R1-03 首次簡報不透明遮罩、R1-04 鎖定標記不再使用缺字 U+25A1。

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const MAIN_MENU_SCRIPT := preload("res://scripts/ui/main_menu.gd")
const FIRST_RUN_GUIDE_SCRIPT := preload("res://scripts/ui/first_run_guide.gd")

const PHONE_HINTS := {
	"mobile_os": false,
	"ua_mobile": true,
	"ua_phone": true,
	"ua_tablet": false,
	"touch_available": true,
	"primary_coarse": true,
	"mouse_available": false
}

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
	current_phase = "landscape_hud"
	if not await _test_landscape_hud():
		return
	current_phase = "orientation_seed_reflow"
	if not await _test_orientation_seed_reflow():
		return
	current_phase = "guide_backdrop"
	if not await _test_guide_backdrop():
		return
	current_phase = "achievement_lock_glyph"
	if not await _test_achievement_lock_glyph():
		return
	current_phase = "done"
	MOBILE_TUNING.set_device_hints_override_for_tests()
	print("R30_PLAYTEST_FIX_PASS hud=844x390-nonoverlap seed=portrait-landscape-portrait guide=opaque-layer45 lock=CJK")
	get_tree().quit(0)


func _test_landscape_hud() -> bool:
	MOBILE_TUNING.set_device_hints_override_for_tests(PHONE_HINTS)
	var viewport := _make_ui_viewport(Vector2(844.0, 390.0))
	var hud := HUD_SCRIPT.new()
	viewport.add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	hud._on_stats_changed({
		"hp": 110,
		"max_hp": 110,
		"level": 1,
		"xp": 0,
		"xp_required": 12,
		"elapsed_time": 1.0,
		"kills": 0,
		"gold": 0,
		"echo_shards": 0,
		"manual_pause_visible": false
	})
	await get_tree().process_frame
	var hp_rect: Rect2 = hud.hp_label.get_global_rect()
	var level_rect: Rect2 = hud.level_label.get_global_rect()
	var xp_rect: Rect2 = hud.xp_readout_label.get_global_rect()
	var bar_rect: Rect2 = hud.xp_bar.get_global_rect()
	var panel_rect: Rect2 = hud.hud_panel.get_global_rect()
	if not hud.xp_readout_label.visible or hud.xp_readout_label.text != "經驗 0/12":
		_fail("landscape XP readout missing or unreadable")
		return false
	if hp_rect.end.y + 2.0 > level_rect.position.y:
		_fail("HP overlaps level row: %s / %s" % [str(hp_rect), str(level_rect)])
		return false
	if level_rect.end.y + 2.0 > xp_rect.position.y:
		_fail("level overlaps XP text row: %s / %s" % [str(level_rect), str(xp_rect)])
		return false
	if xp_rect.end.y + 2.0 > bar_rect.position.y:
		_fail("XP text overlaps XP bar: %s / %s" % [str(xp_rect), str(bar_rect)])
		return false
	for rect in [hp_rect, level_rect, xp_rect, bar_rect]:
		if rect.position.x < panel_rect.position.x - 0.75 or rect.end.x > panel_rect.end.x + 0.75 or rect.position.y < panel_rect.position.y - 0.75 or rect.end.y > panel_rect.end.y + 0.75:
			_fail("HUD stat escaped panel: %s outside %s" % [str(rect), str(panel_rect)])
			return false
	if hud.hp_label.get_theme_font_size("font_size") != 24 or hud.level_label.get_theme_font_size("font_size") != 18:
		_fail("landscape Web font caps drifted")
		return false
	viewport.queue_free()
	print("R30_HUD_844X390 hp=%s level=%s xp=%s bar=%s" % [str(hp_rect), str(level_rect), str(xp_rect), str(bar_rect)])
	return true


func _test_orientation_seed_reflow() -> bool:
	MOBILE_TUNING.set_device_hints_override_for_tests(PHONE_HINTS)
	var viewport := _make_ui_viewport(Vector2(390.0, 844.0))
	var menu := MAIN_MENU_SCRIPT.new()
	viewport.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	viewport.size = Vector2i(844, 390)
	await get_tree().process_frame
	await get_tree().process_frame
	viewport.size = Vector2i(390, 844)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var row_rect: Rect2 = menu.seed_row.get_global_rect()
	var input_rect: Rect2 = menu.seed_input.get_global_rect()
	var button_rect: Rect2 = menu.seed_start_button.get_global_rect()
	if row_rect.position.x < -0.75 or row_rect.end.x > 390.75:
		_fail("seed row stayed wider than portrait viewport: " + str(row_rect))
		return false
	for rect in [input_rect, button_rect]:
		if rect.position.x < row_rect.position.x - 0.75 or rect.end.x > row_rect.end.x + 0.75:
			_fail("seed child clipped after rotation: %s outside %s" % [str(rect), str(row_rect)])
			return false
	if menu.seed_row.size.x > menu.menu_box.size.x + 0.75:
		_fail("portrait seed row did not return to menu width: row=%.1f menu=%.1f rect=%s" % [menu.seed_row.size.x, menu.menu_box.size.x, str(row_rect)])
		return false
	viewport.queue_free()
	print("R30_SEED_REFLOW row=%s input=%s button=%s" % [str(row_rect), str(input_rect), str(button_rect)])
	return true


func _test_guide_backdrop() -> bool:
	var viewport := _make_ui_viewport(Vector2(1366.0, 768.0))
	var guide := FIRST_RUN_GUIDE_SCRIPT.new()
	viewport.add_child(guide)
	await get_tree().process_frame
	guide.force_show()
	await get_tree().process_frame
	if guide.layer != 45 or guide.backdrop == null or guide.backdrop.color.a < 0.999:
		_fail("first-run guide lost opaque top-layer backdrop")
		return false
	if not guide.root.visible or not guide.backdrop.is_visible_in_tree():
		_fail("first-run guide backdrop not visible")
		return false
	viewport.queue_free()
	print("R30_GUIDE_BACKDROP layer=%d alpha=%.2f" % [guide.layer, guide.backdrop.color.a])
	return true


func _test_achievement_lock_glyph() -> bool:
	var menu := MAIN_MENU_SCRIPT.new()
	var button: Button = menu._make_achievement_badge({
		"unlocked": false,
		"name": "測試成就",
		"description": "鎖定標記測試"
	})
	if not button.text.begins_with("鎖\n") or button.text.contains("□") or button.text.contains("�"):
		_fail("achievement badge still uses missing-glyph placeholder: " + button.text)
		return false
	button.queue_free()
	menu.queue_free()
	print("R30_ACHIEVEMENT_LOCK glyph=鎖 codepoint=U+9396")
	return true


func _make_ui_viewport(size: Vector2) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(size.x), int(size.y))
	viewport.disable_3d = true
	add_child(viewport)
	return viewport


func _fail(message: String) -> void:
	MOBILE_TUNING.set_device_hints_override_for_tests()
	printerr("R30_PLAYTEST_FIX_FAIL: " + message)
	get_tree().quit(1)
