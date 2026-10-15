extends Node

const Tuning = preload("res://scripts/services/mobile_tuning.gd")
const Arena = preload("res://scenes/arena/Arena.tscn")
var failures := 0

func _ready() -> void:
	call_deferred("run_checks")

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)

func run_checks() -> void:
	Tuning.set_device_hints_override_for_tests({"mobile_os": true, "native_form_factor": "phone", "native_ui_size": Vector2(390, 844), "touch_available": true, "mouse_available": false})
	var arena := Arena.instantiate()
	get_tree().root.add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud = arena.get_node("HUD")
	var joystick: Control = hud.virtual_joystick
	check(not OS.has_feature("web"), "This probe must use native Godot, not a JS toolbar")
	check(joystick.visible, "Native phone joystick is visible without forcing it")
	check(hud.scale.x > 1.0, "Native design viewport scales UI into density-independent coordinates")
	check(ResourceLoader.exists("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf"), "Bundled CJK font is available")
	var player = GameManager.player
	var start: Vector2 = player.global_position
	var press := InputEventScreenTouch.new()
	press.index = 41
	press.pressed = true
	press.position = joystick.size * .5
	joystick._gui_input(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 41
	drag.position = press.position + Vector2(joystick.stick_radius * .85, 0)
	joystick._gui_input(drag)
	check(GameManager.get_touch_move_vector().x > .5, "Real ScreenTouch/ScreenDrag reaches GameManager movement")
	for frame in range(20):
		await get_tree().physics_frame
	check(player.global_position.x > start.x + 8, "Real player physics moves from native joystick")
	joystick.notification(NOTIFICATION_APPLICATION_PAUSED)
	check(GameManager.get_touch_move_vector() == Vector2.ZERO, "Background notification releases held movement")
	hud.pause_button.pressed.emit()
	check(get_tree().paused and GameManager.manual_paused, "Native HUD pause action works")
	hud.pause_resume_button.pressed.emit()
	check(not get_tree().paused, "Native HUD resume action works")
	Tuning.set_device_hints_override_for_tests()
	print("NATIVE_TOUCH_CHECKS=9 FAILURES=", failures)
	get_tree().quit(1 if failures else 0)
