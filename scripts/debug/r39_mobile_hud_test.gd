extends Node

const ARENA := preload("res://scenes/arena/Arena.tscn")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const ROSTER := preload("res://resources/squads/default_squad.tres")
const SIZES: Array[Vector2i] = [Vector2i(844,390), Vector2i(390,844), Vector2i(360,640), Vector2i(320,568), Vector2i(667,375), Vector2i(640,360)]
var failures: Array[String] = []
var evidence: Array[Dictionary] = []
var viewport: SubViewport
var arena: Node
var hud: Node
var actor: Node

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	if "--r39-parse-only" in OS.get_cmdline_user_args():
		print("R39_PARSE_ONLY_PASS (no HUD/input checks executed)")
		get_tree().quit(0)
		return
	GameManager.campaign_save_path = "user://r39_mobile_hud_campaign.cfg"
	GameManager.wallet_gold = 0
	GameManager.paid_summon.clear()
	PlayerSettings.debug_use_save_path("user://r39_mobile_hud_settings.cfg", true)
	MetaProgress.debug_use_save_path("user://r39_mobile_hud_meta.cfg", true)
	AchievementProgress.debug_use_save_path("user://r39_mobile_hud_achievements.cfg", true)
	var pets := ConfigFile.new()
	pets.save("user://r39_mobile_hud_campaign_pets.cfg")
	GameManager.set_process(false)
	MOBILE.set_device_hints_override_for_tests({"ua_mobile":true, "ua_phone":true, "ua_tablet":false, "touch_available":true, "primary_coarse":true, "mouse_available":false})
	var diagnose := "--r39-diagnose-portrait" in OS.get_cmdline_user_args()
	var test_sizes: Array[Vector2i] = SIZES.duplicate()
	if diagnose:
		test_sizes.assign([Vector2i(390,844)])
	for size in test_sizes:
		await _new_arena(size)
		if not _api_ready():
			await _cleanup()
			break
		_check_geometry(size)
		_print_ability_metrics()
		if diagnose:
			await _cleanup()
			continue
		await _test_joystick_settings(size)
		await _test_pause_and_shop_input(size)
		if size == Vector2i(390,844):
			await _test_same_arena_rotation()
		await _cleanup()
	MOBILE.set_device_hints_override_for_tests({})
	get_tree().paused = false
	GameManager.set_touch_move_vector(Vector2.ZERO)
	_check(ROSTER.max_members == 9 and ROSTER.starting_heroes.size() == 3, "HUD revision altered initial roster or party cap")
	var result := {"sizes": evidence, "failures": failures, "diagnostic_only": diagnose,
		"test_input": "not executed (font/style diagnostic only)" if diagnose else "SubViewport.push_input physical ScreenTouch index7/ScreenDrag and MouseButton routing",
		"fixture_setup": "isolated save paths/reset defaults and wallet0; combat processing disabled only in test fixture",
		"input_interval_state_checks": "not executed" if diagnose else "HP/current run seed/private draw RNG unchanged; no purchases or injected HP/RNG", "cleanup_paused": get_tree().paused}
	DirAccess.make_dir_recursive_absolute("res://docs/evidence/r39")
	var file := FileAccess.open("res://docs/evidence/r39/" + ("mobile_hud_diagnostic.json" if diagnose else "mobile_hud_test.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t"))
	if diagnose:
		print("R39_DIAGNOSTIC_COMPLETE failures=%d (geometry/fonts/styles only; no touch/input checks)" % failures.size())
	else:
		print("R39_MOBILE_HUD_" + ("PASS" if failures.is_empty() else "FAIL") + " sizes=6 physical_touch=true same_arena_rotate=true cleanup_unpaused=true")
	get_tree().quit(0 if failures.is_empty() else 1)

func _new_arena(size: Vector2i) -> void:
	viewport = SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	arena = ARENA.instantiate()
	viewport.add_child(arena)
	await get_tree().process_frame
	arena.get_node("EnemySpawner").set_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	for member in GameManager.squad_manager.get_members():
		member.set_process(false)
		for weapon in member.weapons.values():
			weapon.set_process(false)
	actor = GameManager.player
	hud = arena.get_node("HUD")
	for _frame in range(10):
		await get_tree().process_frame
	GameManager.emit_stats()
	for _frame in range(4):
		await get_tree().process_frame

func _api_ready() -> bool:
	var ready := is_instance_valid(hud.get("phone_equipment_button")) and is_instance_valid(hud.get("pause_auto_button"))
	ready = ready and hud.has_method("_reset_touch_input") and hud.virtual_joystick.has_method("reset_input")
	_check(ready, "required R39 HUD/reset API is missing; do not treat pending implementation as PASS")
	return ready

func _check_geometry(size: Vector2i) -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(size))
	var center := Rect2(Vector2(size.x * 0.25, size.y * 0.28), Vector2(size.x * 0.5, size.y * 0.36))
	var controls := {"joystick": hud.virtual_joystick, "ability": hud.active_ability_button, "summon": hud.summon_button, "gear": hud.get("phone_equipment_button")}
	var rects := {}
	var occupied_area := 0.0
	for key in controls:
		var control: Control = controls[key]
		_check(control.is_visible_in_tree(), "phone essential control hidden: %s %s" % [size,key])
		var rect := control.get_global_rect()
		rects[key] = rect
		occupied_area += rect.get_area()
		_check(screen.encloses(rect), "phone essential outside viewport: %s %s %s" % [size,key,rect])
		_check(not center.intersects(rect), "phone essential covers central battle region: %s %s %s" % [size,key,rect])
		if key != "joystick":
			_check(rect.size.x >= 44.0 and rect.size.y >= 44.0, "body button under44 touch target: %s %s %s" % [size,key,rect])
		if key == "joystick":
			_check(rect.size.x <= 132.01 and rect.size.y <= 132.01, "default phone joystick exceeds132 heat zone")
		elif key == "ability":
			_check(rect.size.x <= 64.01 and rect.size.y <= 64.01, "phone ability exceeds64")
		elif key == "summon":
			_check(rect.size.x <= 64.01 and rect.size.y <= 44.01, "phone summon exceeds64x44")
		else:
			_check(rect.size.x <= 44.01 and rect.size.y <= 44.01, "phone gear exceeds44x44")
	var names: Array = rects.keys()
	for first in range(names.size()):
		for second in range(first+1, names.size()):
			_check(not (rects[names[first]] as Rect2).intersects(rects[names[second]]), "phone touch hit rectangles overlap: %s %s/%s" % [size,names[first],names[second]])
	var fraction := occupied_area / screen.get_area()
	_check(fraction <= 0.100001, "phone essential hitrect budget exceeded10%%: %s %.3f%%" % [size, fraction * 100.0])
	_check(not hud.auto_button.is_visible_in_tree(), "phone auto button still obstructs battlefield")
	_check(not hud.equipment_panel.is_visible_in_tree(), "phone expanded equipment row still obstructs battlefield")
	var rows := {}
	for key in rects:
		rows[key] = {"x": rects[key].position.x, "y": rects[key].position.y, "width": rects[key].size.x, "height": rects[key].size.y}
	evidence.append({"size": [size.x,size.y], "control_rects": rows, "control_area_fraction": fraction,
		"central_rect": str(center), "old_auto_hidden": not hud.auto_button.visible, "equipment_hidden": not hud.equipment_panel.visible})
	print("R39_PHONE_GEOMETRY size=%s essential_area=%.3f%% center_clear=true hitrects=%s" % [size,fraction*100.0,str(rows)])

func _joy_touch(pressed: bool, position: Vector2, index: int = 7) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = position
	viewport.push_input(event, true)

func _print_ability_metrics() -> void:
	var button: Button = hud.active_ability_button
	var font_size := button.get_theme_font_size("font_size")
	var font := button.get_theme_font("font")
	print("R39_ABILITY_METRICS actual=%s intrinsic=%s custom_min=%s font_size=%d font_height=%s text=%s" % [button.size,button.get_minimum_size(),button.custom_minimum_size,font_size,font.get_height(font_size),JSON.stringify(button.text)])
	for state in ["normal","hover","pressed","disabled","focus","hover_pressed"]:
		var style: StyleBox = button.get_theme_stylebox(state)
		print("R39_ABILITY_STYLE state=%s type=%s min=%s margins=%s" % [state,style.get_class(),style.get_minimum_size(),Vector4(style.get_content_margin(SIDE_LEFT),style.get_content_margin(SIDE_TOP),style.get_content_margin(SIDE_RIGHT),style.get_content_margin(SIDE_BOTTOM))])

func _test_joystick_settings(size: Vector2i) -> void:
	var max_radius := 48.0 if size.y > size.x and size.x <= 360 else 56.0 if size.y > size.x else 52.0
	for index in [0,2,1]:
		PlayerSettings.set_joystick_size_index(index)
		for _frame in range(4):
			await get_tree().process_frame
		_check(hud.virtual_joystick.stick_radius <= max_radius, "phone joystick setting exceeds supported compact radius")
		_check(Rect2(Vector2.ZERO,Vector2(size)).encloses(hud.virtual_joystick.get_global_rect()), "nondefault joystick heat area outside phone")
	print("R39_JOYSTICK_SETTINGS size=%s settings=3 bounded_radius=%.0f default_restored=true" % [size,max_radius])

func _joy_drag(position: Vector2, index: int = 7) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = Vector2(28.0,-12.0)
	viewport.push_input(event, true)

func _mouse_press(button: Button, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = button.get_global_rect().get_center()
	viewport.push_input(event, true)

func _click(button: Button) -> void:
	_mouse_press(button, true)
	await get_tree().process_frame
	_mouse_press(button, false)
	for _frame in range(3):
		await get_tree().process_frame

func _start_real_joy() -> Vector2:
	var center: Vector2 = hud.virtual_joystick.get_global_rect().get_center()
	_joy_touch(true, center)
	_joy_drag(center + Vector2(28.0,-12.0))
	await get_tree().physics_frame
	_check(hud.virtual_joystick.active_touch_index == 7 and hud.virtual_joystick.direction.length() > 0.1 and GameManager.get_touch_move_vector().length() > 0.1, "physical touch index7/drag did not reach real joystick")
	return center

func _check_reset(reason: String) -> void:
	_check(hud.virtual_joystick.direction == Vector2.ZERO and hud.virtual_joystick.active_touch_index == -1 and not hud.virtual_joystick.mouse_active and GameManager.get_touch_move_vector() == Vector2.ZERO,
		"sticky movement remains after " + reason)
	_check(not actor.active_ability_touch_held, "sticky held skill remains after " + reason)

func _test_pause_and_shop_input(size: Vector2i) -> void:
	var hp_before: float = actor.current_hp
	var seed_before: int = GameManager.current_run_seed
	var rng_before: int = GameManager.summon_director.private_rng.state
	var center: Vector2 = await _start_real_joy()
	_mouse_press(hud.active_ability_button, true)
	await get_tree().process_frame
	_check(actor.active_ability_touch_held, "real ability button_down did not start held state")
	GameManager.set_manual_pause(true)
	await get_tree().process_frame
	_check_reset("manual pause")
	_joy_drag(center + Vector2(40,0))
	_joy_touch(false, center + Vector2(40,0))
	_mouse_press(hud.active_ability_button, false)
	_check_reset("old paused drag/release")
	GameManager.set_manual_pause(false)
	await get_tree().process_frame
	center = await _start_real_joy()
	_joy_touch(false, center)
	_check_reset("fresh touch release after resume")
	await _click(hud.get("phone_equipment_button"))
	_check(GameManager.manual_paused and hud.pause_active_tab == "run" and hud.pause_run_page.is_visible_in_tree(), "phone gear physical click did not open actual pause Run details")
	_check(not hud.pause_run_stats_label.text.is_empty() and hud.pause_run_stats_label.text.contains("本局") and hud.pause_run_stats_label.text.contains("空槽"), "pause Run did not preserve actual empty gear summaries")
	await _click(hud.pause_run_tab_button)
	var toggle: Button = hud.get("pause_auto_button")
	_check(toggle.is_visible_in_tree() and toggle.get_global_rect().size.y >= 44.0, "phone auto option missing44 target in pause Run")
	var auto_before: bool = GameManager.auto_upgrade_enabled
	await _click(toggle)
	_check(GameManager.auto_upgrade_enabled != auto_before and actor.auto_channel_enabled == GameManager.auto_upgrade_enabled, "pause auto true click did not invoke real battle toggle")
	await _click(toggle)
	_check(GameManager.auto_upgrade_enabled == auto_before, "pause auto second click did not restore mode")
	await _click(hud.pause_resume_button)
	_check(not GameManager.manual_paused and not get_tree().paused, "physical resume button left game paused")
	center = await _start_real_joy()
	_mouse_press(hud.active_ability_button, true)
	await get_tree().process_frame
	await _click(hud.summon_button)
	_check(GameManager.system_pause_owners.has("summon") and GameManager.summon_screen.root.visible, "summon button physical click did not open real modal")
	_check_reset("summon modal")
	_joy_drag(center + Vector2(35,0))
	_joy_touch(false, center)
	_mouse_press(hud.active_ability_button, false)
	await _click(GameManager.summon_screen.close_button)
	_check(not get_tree().paused and not GameManager.system_pause_owners.has("summon"), "summon physical close left system pause")
	_check_reset("summon close old touch")
	center = await _start_real_joy()
	_joy_touch(false, center)
	_check_reset("fresh touch after summon close")
	_check(is_equal_approx(actor.current_hp,hp_before) and GameManager.current_run_seed == seed_before and GameManager.summon_director.private_rng.state == rng_before, "UI input sequence altered HP/seed/private draw RNG")
	print("R39_PHONE_INPUT size=%s touch7=true manual_reset=true old_drag_ignored=true gear_run=true pause_auto=true summon_reset=true hp_seed_rng_unchanged=true" % size)

func _test_same_arena_rotation() -> void:
	var original_arena_id := arena.get_instance_id()
	for size in [Vector2i(844,390), Vector2i(640,360), Vector2i(390,844)]:
		var old_center: Vector2 = await _start_real_joy()
		_mouse_press(hud.active_ability_button, true)
		viewport.size = size
		for _frame in range(6):
			await get_tree().process_frame
		_check_reset("same-arena rotate to " + str(size))
		_joy_drag(old_center + Vector2(32,0))
		_joy_touch(false, old_center)
		_mouse_press(hud.active_ability_button, false)
		_check_reset("old touch after rotate")
		# Allow the normal button-up visual tween to finish before measuring its
		# default hit area. A held-button squash must not make a large target pass.
		await get_tree().create_timer(0.13, true).timeout
		_check_geometry(size)
		var center: Vector2 = await _start_real_joy()
		_joy_touch(false, center)
		_check_reset("fresh touch after rotate")
	_check(arena.get_instance_id() == original_arena_id, "rotation fixture secretly replaced Arena")
	print("R39_PHONE_ROTATE same_arena=true portrait_landscape640_portrait=true old_pointer_clear=true fresh_touch=true")

func _cleanup() -> void:
	GameManager.set_manual_pause(false)
	GameManager.game_running = false
	GameManager.system_pause_owners.clear()
	get_tree().paused = false
	GameManager.set_touch_move_vector(Vector2.ZERO)
	GameManager.player = null
	GameManager.squad_manager = null
	GameManager.arena = null
	viewport.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("R39_MOBILE_HUD_FAIL " + message)
