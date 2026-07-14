extends Node

const BACKGROUND_SCRIPT := preload("res://scripts/arena/arena_background.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const RUN_THEME := preload("res://scripts/arena/run_theme.gd")
const MAIN_MENU_SCRIPT := preload("res://scripts/ui/main_menu.gd")
const CONTRACT_SCREEN_SCRIPT := preload("res://scripts/ui/contract_screen.gd")
const LEVEL_UP_SCREEN_SCRIPT := preload("res://scripts/ui/level_up_screen.gd")
const FIRST_RUN_GUIDE_SCRIPT := preload("res://scripts/ui/first_run_guide.gd")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const RIFT_SHOP_SCRIPT := preload("res://scripts/ui/rift_shop_screen.gd")
const STAGE_VICTORY_SCRIPT := preload("res://scripts/ui/stage_victory_screen.gd")
const GAME_OVER_SCRIPT := preload("res://scripts/ui/game_over_screen.gd")
const SQUAD_MANAGER_SCRIPT := preload("res://scripts/heroes/squad_manager.gd")
const HERO10_DATA := preload("res://resources/heroes/rift_shepherd.tres")
const HERO10_WEAPON := preload("res://resources/weapons/rift_constructs.tres")
const DEFAULT_SQUAD := preload("res://resources/squads/default_squad.tres")
const WEAPON_CATALOG := preload("res://resources/weapons/weapon_catalog.tres")

class BondHero:
	extends Node
	var hero_id: String = ""
	var is_alive: bool = true

	func _init(new_hero_id: String) -> void:
		hero_id = new_hero_id

var current_phase: String = "boot"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(14014)
	call_deferred("_watchdog")
	call_deferred("_run_tests")


func _watchdog() -> void:
	await get_tree().create_timer(20.0, true).timeout
	if current_phase != "done":
		_fail("watchdog timeout at phase: " + current_phase)


func _run_tests() -> void:
	current_phase = "formfactor"
	if not await _test_formfactor_matrix_and_live_switch():
		return
	current_phase = "hero10"
	if not _test_hero10_content_and_bonds():
		return
	current_phase = "mobile_ui"
	var mobile_ok := await _test_mobile_ui_scaling()
	if not mobile_ok:
		return
	current_phase = "ui_spacing"
	if not await _test_ui_spacing_matrix():
		return
	current_phase = "camera"
	if not _test_camera_zoom_branch():
		return
	current_phase = "background"
	if not await _test_background_evolution_determinism():
		return
	current_phase = "press_capture"
	if not await _test_press_capture_contract():
		return

	current_phase = "done"
	print("R14_REGRESSION_PASS")
	get_tree().quit(0)


func _test_hero10_content_and_bonds() -> bool:
	if str(HERO10_DATA.get("id")) != "rift_shepherd" or str(HERO10_DATA.get("passive_id")) != "shepherd":
		_fail("hero10 identity/passive contract drifted")
		return false
	if not is_equal_approx(float(HERO10_DATA.get("max_hp")), 96.0) or not is_equal_approx(float(HERO10_DATA.get("move_speed")), 218.0):
		_fail("hero10 balance stats drifted")
		return false
	var available_heroes: Array = DEFAULT_SQUAD.get("available_heroes")
	if available_heroes.size() != 10 or int(DEFAULT_SQUAD.get("max_members")) != 9:
		_fail("hero10 roster must remain 10 choose 9")
		return false
	var available_weapons: Array = WEAPON_CATALOG.get("available_weapons")
	if available_weapons.size() != 11 or str(HERO10_WEAPON.get("behavior_id")) != "rift_construct":
		_fail("hero10 weapon catalog/behavior contract drifted")
		return false
	if not is_equal_approx(float(HERO10_WEAPON.get("damage")), 7.0) or not is_equal_approx(float(HERO10_WEAPON.get("cooldown")), 2.4):
		_fail("rift_constructs baseline damage/cooldown drifted")
		return false
	if int(HERO10_WEAPON.get("projectile_count")) != 3 or int(HERO10_WEAPON.get("hard_cap_global")) != 6 or int(HERO10_WEAPON.get("max_targets_per_tick")) != 2:
		_fail("rift_constructs cap/target budget drifted")
		return false
	var weapon_script_text := FileAccess.get_file_as_string("res://scripts/weapons/rift_construct_weapon.gd")
	var construct_script_text := FileAccess.get_file_as_string("res://scripts/projectiles/rift_construct.gd")
	if "get_nodes_in_group(\"enemies\")" in weapon_script_text or "get_nodes_in_group(\"enemies\")" in construct_script_text:
		_fail("rift constructs introduced a forbidden enemies group scan")
		return false
	if "_on_attack_impact" not in weapon_script_text or "attack_impact" not in weapon_script_text:
		_fail("rift constructs lost frame-2 impact lock")
		return false

	var manager := SQUAD_MANAGER_SCRIPT.new()
	add_child(manager)
	var bond_members: Array[Node] = []
	for hero_id in ["ember_grenadier", "pulse_artificer", "void_weaver", "rift_sniper", "orbit_guard", "echo_singer", "rift_captain", "rift_shepherd"]:
		var member := BondHero.new(hero_id)
		manager.add_child(member)
		bond_members.append(member)
	manager.set("members", bond_members)
	manager.recompute_bonds()
	if manager.get_active_bond_count() != 4:
		_fail("all four hero bonds did not activate")
		return false
	(bond_members[5] as BondHero).is_alive = false
	manager.recompute_bonds()
	if manager.has_active_bond("bond_guard_echo") or manager.get_active_bond_count() != 3:
		_fail("bond did not deactivate immediately on member death")
		return false
	manager.queue_free()
	if str(ProjectSettings.get_setting("application/config/version", "")) != "0.13.0-r14":
		_fail("hero10 release version drifted")
		return false
	print("R14_HERO10 roster=10/9 weapons=11 construct_cap=6 targets=2 bonds=4 impact=frame2")
	return true


func _test_formfactor_matrix_and_live_switch() -> bool:
	var phone := Vector2(390.0, 844.0)
	var tablet := Vector2(1024.0, 768.0)
	var touch_desktop := Vector2(1920.0, 1080.0)
	var desktop := Vector2(1536.0, 864.0)
	var phone_hints := {"mobile_os": false, "ua_mobile": true, "ua_phone": true, "ua_tablet": false, "touch_available": true, "mouse_available": false}
	var tablet_hints := {"mobile_os": false, "ua_mobile": true, "ua_phone": false, "ua_tablet": true, "touch_available": true, "mouse_available": false}
	var touch_desktop_hints := {"mobile_os": false, "ua_mobile": false, "ua_phone": false, "ua_tablet": false, "touch_available": true, "mouse_available": true}
	var desktop_hints := {"mobile_os": false, "ua_mobile": false, "ua_phone": false, "ua_tablet": false, "touch_available": false, "mouse_available": true}
	var cases := [
		{"size": phone, "hints": phone_hints, "tier": "phone", "joystick": true},
		{"size": tablet, "hints": tablet_hints, "tier": "tablet", "joystick": true},
		{"size": touch_desktop, "hints": touch_desktop_hints, "tier": "desktop", "joystick": false},
		{"size": desktop, "hints": desktop_hints, "tier": "desktop", "joystick": false},
		# Layout remains phone-sized on a narrow mouse window, but input capability
		# must not invent a virtual joystick when no touch source exists.
		{"size": phone, "hints": desktop_hints, "tier": "phone", "joystick": false}
	]
	for formfactor_case in cases:
		var size: Vector2 = formfactor_case.size
		var hints: Dictionary = formfactor_case.hints
		var expected_tier: String = formfactor_case.tier
		if MOBILE_TUNING.layout_tier_name(size, false, hints) != expected_tier:
			_fail("form-factor tier mismatch for %s: expected %s got %s" % [str(size), expected_tier, MOBILE_TUNING.layout_tier_name(size, false, hints)])
			return false
		if MOBILE_TUNING.should_show_virtual_joystick(size, false, hints) != bool(formfactor_case.joystick):
			_fail("joystick matrix mismatch for %s" % str(size))
			return false
	if absf(MOBILE_TUNING.ui_scale(phone, false, phone_hints) - 1.96) > 0.001:
		_fail("phone scale drifted")
		return false
	if absf(MOBILE_TUNING.ui_scale(tablet, false, tablet_hints) - MOBILE_TUNING.TABLET_UI_SCALE) > 0.001 or MOBILE_TUNING.touch_target(tablet, false, tablet_hints) < 44.0:
		_fail("tablet scale or touch target drifted")
		return false
	if absf(MOBILE_TUNING.ui_scale(touch_desktop, false, touch_desktop_hints) - 1.0) > 0.001:
		_fail("touch desktop scale drifted")
		return false
	if not MOBILE_TUNING.should_show_virtual_joystick(touch_desktop, true, touch_desktop_hints):
		_fail("forced desktop joystick did not become available")
		return false
	PlayerSettings.debug_use_save_path("user://formfactor_settings_test.cfg", true)
	PlayerSettings.set_force_joystick_visible(true)
	PlayerSettings.load_settings()
	if not bool(PlayerSettings.get("force_joystick_visible")):
		_fail("force joystick setting did not persist")
		return false
	PlayerSettings.set_force_joystick_visible(false)
	if not await _test_seed_width_for_tier(tablet, tablet_hints, "tablet"):
		return false
	if not await _test_seed_width_for_tier(touch_desktop, touch_desktop_hints, "touch desktop"):
		return false
	if not await _test_seed_width_for_tier(desktop, desktop_hints, "desktop"):
		return false

	MOBILE_TUNING.set_device_hints_override_for_tests(phone_hints)
	var viewport := _make_ui_viewport(phone)
	var hud := HUD_SCRIPT.new()
	viewport.add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	if not hud.virtual_joystick.visible:
		_fail("live phone HUD hid joystick")
		return false
	if hud.pause_force_joystick_check == null:
		_fail("pause settings missing force joystick toggle")
		return false
	MOBILE_TUNING.set_device_hints_override_for_tests(tablet_hints)
	viewport.size = Vector2i(1024, 768)
	hud._apply_responsive_layout()
	await get_tree().process_frame
	if MOBILE_TUNING.layout_tier_name(tablet) != "tablet" or not hud.virtual_joystick.visible:
		_fail("live phone-to-tablet switch failed")
		return false
	if float(hud.virtual_joystick.get("stick_radius")) > 100.0:
		_fail("tablet joystick kept phone-sized radius")
		return false
	MOBILE_TUNING.set_device_hints_override_for_tests(touch_desktop_hints)
	viewport.size = Vector2i(1920, 1080)
	hud._apply_responsive_layout()
	await get_tree().process_frame
	if MOBILE_TUNING.layout_tier_name(touch_desktop) != "desktop" or hud.virtual_joystick.visible:
		_fail("live tablet-to-touch-desktop switch failed")
		return false
	if hud.hp_label.get_theme_font_size("font_size") != 20:
		_fail("live desktop switch did not restore desktop HUD font")
		return false
	hud.set_touch_controls_forced_visible(true)
	await get_tree().process_frame
	if not hud.virtual_joystick.visible or absf(MOBILE_TUNING.ui_scale(touch_desktop) - 1.0) > 0.001:
		_fail("force joystick changed desktop layout or remained hidden")
		return false
	hud.set_touch_controls_forced_visible(false)
	viewport.queue_free()
	MOBILE_TUNING.set_device_hints_override_for_tests()
	print("R14_FORMFACTOR phone=phone tablet=tablet touch_desktop=desktop desktop=desktop seed_max=%.0f" % MOBILE_TUNING.SEED_ROW_MAX_WIDTH)
	return true


func _test_seed_width_for_tier(size: Vector2, hints: Dictionary, label: String) -> bool:
	MOBILE_TUNING.set_device_hints_override_for_tests(hints)
	var viewport := _make_ui_viewport(size)
	var menu := MAIN_MENU_SCRIPT.new()
	viewport.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	if menu.seed_row.size.x > MOBILE_TUNING.SEED_ROW_MAX_WIDTH + 0.5:
		_fail("%s main menu seed row exceeded max width: %.1f" % [label, menu.seed_row.size.x])
		return false
	var contract := CONTRACT_SCREEN_SCRIPT.new()
	viewport.add_child(contract)
	await get_tree().process_frame
	contract.show_options(_sample_options())
	await get_tree().process_frame
	if contract.seed_row.size.x > MOBILE_TUNING.SEED_ROW_MAX_WIDTH + 0.5:
		_fail("%s contract seed row exceeded max width: %.1f" % [label, contract.seed_row.size.x])
		return false
	viewport.queue_free()
	return true


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
	if not await _test_shop_mobile_layout(portrait):
		return false
	if not await _test_shop_mobile_layout(landscape):
		return false
	if not await _test_stage_victory_mobile_layout(portrait):
		return false
	if not await _test_stage_victory_mobile_layout(landscape):
		return false
	if not await _test_game_over_mobile_layout(portrait):
		return false
	if not await _test_game_over_mobile_layout(landscape):
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
	if menu.seed_row.size.x > MOBILE_TUNING.SEED_ROW_MAX_WIDTH + 0.5:
		_fail("main menu seed row exceeded max width: %.1f" % menu.seed_row.size.x)
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
	if menu.force_joystick_check == null:
		_fail("main menu settings missing force joystick toggle")
		return false
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
	if screen.seed_row.size.x > MOBILE_TUNING.SEED_ROW_MAX_WIDTH + 0.5:
		_fail("contract seed row exceeded max width: %.1f" % screen.seed_row.size.x)
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
	if portrait and first_button.custom_minimum_size.y < 200.0:
		_fail("level up portrait card height below readable floor")
		return false
	var upgrade_icon := first_button.get_node_or_null("UpgradeIcon") as TextureRect
	if upgrade_icon == null or upgrade_icon.texture == null or upgrade_icon.get_global_rect().size.x < 40.0:
		_fail("level up card is missing its upper visual icon")
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


func _test_shop_mobile_layout(size: Vector2) -> bool:
	var viewport := _make_ui_viewport(size)
	var screen := RIFT_SHOP_SCRIPT.new()
	viewport.add_child(screen)
	await get_tree().process_frame
	GameManager.gold = 99
	screen.show_options(_sample_shop_options())
	await get_tree().process_frame
	if not _control_inside_viewport(screen.panel, size, "shop panel"):
		return false
	if not _control_inside_viewport(screen.card_scroll, size, "shop card scroll"):
		return false
	if not _control_inside_viewport(screen.skip_button, size, "shop skip button"):
		return false
	if screen.option_buttons.is_empty():
		_fail("shop options were not created")
		return false
	if _controls_overlap(screen.card_scroll, screen.skip_button):
		_fail("shop scroll viewport overlaps skip button")
		return false
	if size.x > size.y and screen.card_grid.columns != 3:
		_fail("shop landscape did not use three columns")
		return false
	viewport.queue_free()
	return true


func _test_stage_victory_mobile_layout(size: Vector2) -> bool:
	var viewport := _make_ui_viewport(size)
	var screen := STAGE_VICTORY_SCRIPT.new()
	viewport.add_child(screen)
	await get_tree().process_frame
	screen.show_summary(_sample_summary())
	await get_tree().process_frame
	if not _control_inside_viewport(screen.panel, size, "stage victory panel"):
		return false
	if not _control_inside_viewport(screen.summary_scroll, size, "stage victory summary scroll"):
		return false
	if not _control_inside_viewport(screen.copy_seed_button, size, "stage victory copy seed"):
		return false
	if not _control_inside_viewport(screen.continue_button, size, "stage victory continue"):
		return false
	if screen.main_menu_button != null and not _control_inside_viewport(screen.main_menu_button, size, "stage victory main menu"):
		return false
	if _controls_overlap(screen.summary_scroll, screen.copy_seed_button) or _controls_overlap(screen.summary_scroll, screen.continue_button):
		_fail("stage victory summary overlaps action buttons")
		return false
	viewport.queue_free()
	return true


func _test_game_over_mobile_layout(size: Vector2) -> bool:
	var viewport := _make_ui_viewport(size)
	var screen := GAME_OVER_SCRIPT.new()
	viewport.add_child(screen)
	await get_tree().process_frame
	screen.show_summary(_sample_summary())
	await get_tree().process_frame
	if not _control_inside_viewport(screen.panel, size, "game over panel"):
		return false
	if not _control_inside_viewport(screen.body_scroll, size, "game over body scroll"):
		return false
	if not _control_inside_viewport(screen.copy_seed_button, size, "game over copy seed"):
		return false
	if not _control_inside_viewport(screen.restart_button, size, "game over restart"):
		return false
	if screen.main_menu_button != null and not _control_inside_viewport(screen.main_menu_button, size, "game over main menu"):
		return false
	if _controls_overlap(screen.body_scroll, screen.copy_seed_button) or _controls_overlap(screen.body_scroll, screen.restart_button):
		_fail("game over body overlaps action buttons")
		return false
	viewport.queue_free()
	return true


func _make_ui_viewport(size: Vector2) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(size.x), int(size.y))
	viewport.disable_3d = true
	add_child(viewport)
	return viewport


func _test_ui_spacing_matrix() -> bool:
	var sizes := [Vector2(1920.0, 1080.0), Vector2(1024.0, 768.0), Vector2(390.0, 844.0)]
	for size in sizes:
		if not await _test_ui_spacing_at_size(size):
			return false
	print("R13_UI_SPACING viewports=1920x1080,1024x768,390x844 gap>=8 touch>=44")
	return true


func _test_ui_spacing_at_size(size: Vector2) -> bool:
	var viewport := _make_ui_viewport(size)
	var menu := MAIN_MENU_SCRIPT.new()
	viewport.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _assert_adjacent_gap([menu.start_button, menu.meta_button, menu.achievements_button, menu.settings_button], true, 8.0, "main menu %s" % str(size)):
		return false
	menu._show_panel("settings")
	await get_tree().process_frame
	if not _assert_adjacent_gap([menu.mute_check, menu.damage_numbers_check, menu.screen_shake_check, menu.force_joystick_check], true, 8.0, "settings checks %s" % str(size)):
		return false
	if size.x <= 430.0 and not _assert_touch_targets([menu.start_button, menu.mute_check, menu.damage_numbers_check, menu.screen_shake_check, menu.force_joystick_check], 44.0, "menu/settings %s" % str(size)):
		return false
	menu._show_panel("meta")
	await get_tree().process_frame
	var meta_controls: Array[Control] = []
	for child in menu.side_content.get_children():
		if child is Button:
			meta_controls.append(child as Control)
	if not _assert_adjacent_gap(meta_controls, true, 8.0, "echo upgrades %s" % str(size)):
		return false

	var guide := FIRST_RUN_GUIDE_SCRIPT.new()
	viewport.add_child(guide)
	await get_tree().process_frame
	if not _assert_adjacent_gap([guide.dont_show_check, guide.start_button], true, 8.0, "briefing actions %s" % str(size)):
		return false
	if size.x <= 430.0 and not _assert_touch_targets([guide.dont_show_check, guide.start_button], 44.0, "briefing %s" % str(size)):
		return false

	var level_up := LEVEL_UP_SCREEN_SCRIPT.new()
	viewport.add_child(level_up)
	await get_tree().process_frame
	level_up.show_options(_sample_options())
	await get_tree().process_frame
	if not _assert_adjacent_gap(level_up.option_buttons, level_up.card_grid.columns == 1, 8.0, "upgrade cards %s" % str(size)):
		return false
	for card in level_up.option_buttons:
		var icon := (card as Button).get_node_or_null("UpgradeIcon") as TextureRect
		if icon == null or icon.texture == null:
			_fail("upgrade icon missing at %s" % str(size))
			return false

	var shop := RIFT_SHOP_SCRIPT.new()
	viewport.add_child(shop)
	await get_tree().process_frame
	shop.show_options(_sample_shop_options())
	await get_tree().process_frame
	if not _assert_adjacent_gap(shop.option_buttons, shop.card_grid.columns == 1, 8.0, "shop cards %s" % str(size)):
		return false

	var contract := CONTRACT_SCREEN_SCRIPT.new()
	viewport.add_child(contract)
	await get_tree().process_frame
	contract.show_options(_sample_options())
	await get_tree().process_frame
	if not _assert_adjacent_gap(contract.option_buttons, contract.card_grid.columns == 1, 8.0, "contract cards %s" % str(size)):
		return false

	var hud := HUD_SCRIPT.new()
	viewport.add_child(hud)
	await get_tree().process_frame
	hud.pause_overlay.visible = true
	await get_tree().process_frame
	if not _assert_adjacent_gap([hud.pause_mute_check, hud.pause_damage_numbers_check, hud.pause_screen_shake_check, hud.pause_force_joystick_check], true, 8.0, "pause checks %s" % str(size)):
		return false
	if size.x <= 430.0 and not _assert_touch_targets([hud.pause_mute_check, hud.pause_damage_numbers_check, hud.pause_screen_shake_check, hud.pause_force_joystick_check, hud.pause_resume_button], 44.0, "pause %s" % str(size)):
		return false
	viewport.queue_free()
	await get_tree().process_frame
	return true


func _assert_adjacent_gap(controls: Array, vertical: bool, minimum_gap: float, label: String) -> bool:
	if controls.size() < 2:
		return true
	for index in range(1, controls.size()):
		var previous := controls[index - 1] as Control
		var current := controls[index] as Control
		if previous == null or current == null:
			_fail(label + " has a missing adjacent control")
			return false
		var previous_rect := previous.get_global_rect()
		var current_rect := current.get_global_rect()
		if previous_rect.intersects(current_rect):
			_fail("%s controls overlap: %s / %s" % [label, str(previous_rect), str(current_rect)])
			return false
		var gap := current_rect.position.y - previous_rect.end.y if vertical else current_rect.position.x - previous_rect.end.x
		if gap < minimum_gap - 0.5:
			_fail("%s gap %.1f below %.1f" % [label, gap, minimum_gap])
			return false
	return true


func _assert_touch_targets(controls: Array, minimum_height: float, label: String) -> bool:
	for control_value in controls:
		var control := control_value as Control
		if control == null or control.get_global_rect().size.y < minimum_height - 0.5:
			_fail("%s touch target below %.1f" % [label, minimum_height])
			return false
	return true


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


func _sample_shop_options() -> Array:
	return [
		{"id": "heal", "name": "Shop Alpha", "description": "Readable offer copy stays inside the card.", "cost": 4},
		{"id": "damage", "name": "Shop Beta", "description": "Compact landscape cards must not touch the action button.", "cost": 8},
		{"id": "refresh", "name": "Shop Gamma", "description": "Three columns remain tappable at 844 by 390.", "cost": 12}
	]


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


func _test_press_capture_contract() -> bool:
	var viewport := _make_ui_viewport(Vector2(1280.0, 720.0))
	var hud := HUD_SCRIPT.new()
	viewport.add_child(hud)
	await get_tree().process_frame
	hud._on_boss_phase_transition_requested()
	if not hud.boss_intro_label.visible or "PHASE II" not in hud.boss_intro_label.text:
		_fail("Boss phase-two danger banner missing")
		return false
	if hud.boss_intro_label.modulate.r <= hud.boss_intro_label.modulate.b:
		_fail("Boss phase-two danger banner is not heat-red")
		return false

	var adaptive_layers := EntityFactory.get_visual_composite_layer_count(Vector2(1280.0, 720.0), false)
	hud.set_screenshot_beauty_mode(true)
	if hud.root.visible or not bool(GameManager.get("screenshot_beauty_mode")):
		_fail("F12 beauty mode did not hide HUD or set capture flag")
		return false
	var beauty_layers := EntityFactory.get_visual_composite_layer_count(Vector2(1280.0, 720.0), false)
	if beauty_layers != 4:
		_fail("beauty mode did not force four VFX layers")
		return false
	hud.set_screenshot_beauty_mode(false)
	if not hud.root.visible or bool(GameManager.get("screenshot_beauty_mode")):
		_fail("beauty mode did not restore HUD and adaptive LOD")
		return false
	viewport.queue_free()
	print("R14_PRESS_CAPTURE phase_banner=heat_red adaptive_layers=%d beauty_layers=%d" % [adaptive_layers, beauty_layers])
	return true


func DECOR_OFFSET() -> float:
	return 245.0 * 16.0


func _fail(message: String) -> void:
	MOBILE_TUNING.set_device_hints_override_for_tests()
	printerr("R14_REGRESSION_FAIL: " + message)
	get_tree().quit(1)
