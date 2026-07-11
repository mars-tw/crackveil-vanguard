extends Node

const BACKGROUND_SCRIPT := preload("res://scripts/arena/arena_background.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const RUN_THEME := preload("res://scripts/arena/run_theme.gd")

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
	if not _test_mobile_ui_scaling():
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
	var desktop := Vector2(1280.0, 720.0)
	if not MOBILE_TUNING.use_mobile_ui(portrait, true):
		_fail("portrait viewport did not use mobile UI")
		return false
	if not MOBILE_TUNING.use_mobile_ui(landscape, true):
		_fail("landscape viewport did not use mobile UI")
		return false
	if MOBILE_TUNING.ui_scale(portrait, true) < 1.6 or MOBILE_TUNING.ui_scale(landscape, true) < 1.6:
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
	if mobile_font < 32:
		_fail("button font did not scale enough: %d" % mobile_font)
		return false
	if button.custom_minimum_size.y < 48.0:
		_fail("touch target below 48px")
		return false
	MOBILE_TUNING.apply_control_tree(root, desktop, false)
	if button.get_theme_font_size("font_size") != 20:
		_fail("desktop font override was not restored")
		return false
	root.queue_free()
	print("R14_MOBILE_UI portrait_scale=%.2f landscape_scale=%.2f font=%d touch=%.1f" % [
		MOBILE_TUNING.ui_scale(portrait, true),
		MOBILE_TUNING.ui_scale(landscape, true),
		mobile_font,
		MOBILE_TUNING.touch_target(portrait, true)
	])
	return true


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
