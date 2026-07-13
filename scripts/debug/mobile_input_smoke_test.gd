extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena/Arena.tscn")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")

var arena: Node = null
var hud: CanvasLayer = null
var leader: Node2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Phone layout comes from the viewport. The force flag below only guarantees
	# joystick availability and must never be used to scale a desktop layout.
	get_window().size = Vector2i(390, 844)
	# The project stretch canvas keeps a 720px logical short side in headless;
	# inject a handset UA so this remains a faithful Web phone scenario.
	MOBILE_TUNING.set_device_hints_override_for_tests({
		"mobile_os": false,
		"ua_mobile": true,
		"ua_phone": true,
		"ua_tablet": false,
		"touch_available": true,
		"mouse_available": false
	})
	arena = ARENA_SCENE.instantiate()
	add_child(arena)
	call_deferred("_run_test")


func _run_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	leader = GameManager.player
	hud = arena.get_node_or_null("HUD") as CanvasLayer
	if leader == null or not is_instance_valid(leader):
		_fail("leader not found")
		return
	if hud == null:
		_fail("HUD not found")
		return

	if hud.has_method("set_touch_controls_forced_visible"):
		hud.set_touch_controls_forced_visible(true)
	await get_tree().process_frame

	var layout_ok: bool = await _check_portrait_layout()
	if not layout_ok:
		return
	var joystick_ok: bool = await _check_virtual_joystick_movement()
	if not joystick_ok:
		return
	if not _check_pause_button_touch_path():
		return

	print("MOBILE_INPUT_SMOKE_PASS")
	MOBILE_TUNING.set_device_hints_override_for_tests()
	get_tree().quit(0)


func _check_portrait_layout() -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	var joystick := hud.get("virtual_joystick") as Control
	var pause_button := hud.get("pause_button") as Control
	if joystick == null or not joystick.visible:
		_fail("virtual joystick not visible in forced portrait mode")
		return false
	if not _rect_inside(joystick.get_global_rect(), viewport_size):
		_fail("virtual joystick outside portrait viewport")
		return false
	if pause_button == null or not _rect_inside(pause_button.get_global_rect(), viewport_size):
		_fail("pause button outside portrait viewport")
		return false
	var visual_radius := float(joystick.get("stick_radius"))
	if visual_radius < viewport_size.x * 0.22:
		_fail("virtual joystick visual radius below 22 percent portrait width")
		return false
	if joystick.size.x < visual_radius * 2.0 * MOBILE_TUNING.MOBILE_JOYSTICK_HEAT_ZONE_MULTIPLIER - 1.0:
		_fail("virtual joystick heat zone below M1 multiplier")
		return false

	var level_screen := arena.get_node_or_null("LevelUpScreen")
	if level_screen != null and level_screen.has_method("show_options"):
		level_screen.show_options([
			{"id": "a", "name": "強化裂線", "description": "提高直線彈傷害"},
			{"id": "b", "name": "加快步伐", "description": "提高小隊移動速度"},
			{"id": "c", "name": "補強星環", "description": "增加環繞刃數量"}
		])
		await get_tree().process_frame
		var grid := level_screen.get("card_grid") as GridContainer
		if grid == null or grid.columns != 1:
			_fail("level up cards did not switch to portrait single column")
			return false
		for child in grid.get_children():
			var control := child as Control
			if control != null and not _rect_inside(control.get_global_rect(), viewport_size):
				_fail("level up card outside portrait viewport")
				return false
		var level_root := level_screen.get("root") as Control
		if level_root != null:
			level_root.visible = false

	var game_over := arena.get_node_or_null("GameOverScreen")
	if game_over != null and game_over.has_method("show_summary"):
		game_over.show_summary({"elapsed_time": 91.0, "kills": 12, "gold": 34, "level": 4})
		await get_tree().process_frame
		var panel := game_over.get("panel") as Control
		if panel == null or not _rect_inside(panel.get_global_rect(), viewport_size):
			_fail("game over panel outside portrait viewport")
			return false
		var game_over_root := game_over.get("root") as Control
		if game_over_root != null:
			game_over_root.visible = false

	print("MOBILE_LAYOUT_SMOKE viewport=%s joystick=%s" % [str(viewport_size), str(joystick.get_global_rect())])
	return true


func _check_virtual_joystick_movement() -> bool:
	var joystick := hud.get("virtual_joystick") as Control
	if joystick == null:
		_fail("virtual joystick missing")
		return false

	var start_position := leader.global_position
	var radius := float(joystick.get("stick_radius"))
	var center := Vector2(radius + 18.0, joystick.size.y - radius - 18.0)
	var touch := InputEventScreenTouch.new()
	touch.index = 7
	touch.pressed = true
	touch.position = center
	joystick._gui_input(touch)

	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = center + Vector2(radius * 0.82, 0.0)
	joystick._gui_input(drag)

	if GameManager.get_touch_move_vector().x < 0.65:
		_fail("touch joystick did not set rightward vector")
		return false

	for _frame in range(24):
		await get_tree().physics_frame

	if leader.global_position.x <= start_position.x + 12.0:
		_fail("leader did not move from touch joystick")
		return false

	var release := InputEventScreenTouch.new()
	release.index = 7
	release.pressed = false
	release.position = center + Vector2(58.0, 0.0)
	joystick._gui_input(release)
	await get_tree().physics_frame

	if GameManager.get_touch_move_vector().length() > 0.02:
		_fail("touch joystick did not reset on release")
		return false

	print("MOBILE_INPUT_MOVE start_x=%.2f end_x=%.2f" % [start_position.x, leader.global_position.x])
	return true


func _check_pause_button_touch_path() -> bool:
	var pause_button := hud.get("pause_button") as Button
	if pause_button == null:
		_fail("pause button not found")
		return false

	pause_button.pressed.emit()
	if not get_tree().paused or not GameManager.manual_paused:
		_fail("pause button did not pause")
		return false
	pause_button.pressed.emit()
	if get_tree().paused or GameManager.manual_paused:
		_fail("pause button did not resume")
		return false

	print("MOBILE_PAUSE_BUTTON_PASS")
	return true


func _rect_inside(rect: Rect2, viewport_size: Vector2) -> bool:
	return rect.position.x >= -1.0 and rect.position.y >= -1.0 and rect.end.x <= viewport_size.x + 1.0 and rect.end.y <= viewport_size.y + 1.0


func _fail(message: String) -> void:
	MOBILE_TUNING.set_device_hints_override_for_tests()
	printerr("MOBILE_INPUT_SMOKE_FAIL: " + message)
	get_tree().quit(1)
