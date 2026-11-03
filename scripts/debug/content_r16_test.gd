extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	_test_slow_seal_heal()
	_test_visible_pace()
	_test_no_new_cover()
	_test_version()
	if failures.is_empty():
		print("R16_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R16_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _test_slow_seal_heal() -> void:
	var catalog: GDScript = load("res://scripts/services/starting_build_catalog.gd")
	_check(catalog.seal_heal("front", "wedge") == 8.0, "the fast seal keeps the +8 heal (R6/R11 contract)")
	_check(catalog.seal_heal("front", "ring") == 16.0, "the slow seal heals twice as much")
	var relay_script: GDScript = load("res://scripts/services/formation_relay.gd")
	var relay: Node2D = relay_script.new()
	_check(relay.seal_text(2) == "封合 2/3・整補 +8・反擊 +20% 5 秒", "the default banner is unchanged")
	_check(relay.seal_text(1, 10, 16) == "封合 1/3・整補 +16・反擊 +20% 10 秒", "a slow seal banner shows +16 and 10 s")
	relay.free()
	var src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(src.contains("squad.heal_members(float(last_seal_heal))") and src.contains("healing_forgone+=minf(last_seal_heal,"), "the real heal and the prepare node's forgone heal use the same amount")
	var pressure_script: GDScript = load("res://scripts/services/encounter_pressure.gd")
	_check(load("res://scripts/services/formation_relay.gd").compare_text("front").contains("慢9秒整補16"), "the slow seal's larger heal is named (top bar since R19)")

func _test_visible_pace() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(src.contains("\"%s・%s・陣形正確・%s・隊員 +80%%\" % [pressure.status_text(),label,pace]") and src.contains("\"慢封 %d 秒・反擊 %d 秒\""), "the top bar always says fast or slow seal for the held formation")
	var pressure_src := FileAccess.get_file_as_string("res://scripts/services/encounter_pressure.gd")
	_check(src.contains("var tag := (\"・慢封\" if is_instance_valid(pressure)"), "the fast/slow tag stays on the top bar while the seal fills")
	_check(pressure_src.contains("var pace := \"快\" if i == 0 and accepted[i] == primary else \"慢\""), "each ground badge is tagged fast or slow")

func _test_no_new_cover() -> void:
	var hud_script: GDScript = load("res://scripts/ui/hud.gd")
	var font: Font = ThemeDB.fallback_font
	var long_line := "重盾正面推進・攻勢生效・可用：楔形／圓陣・陣形正確・慢封・反擊 10 秒"
	var size: int = hud_script.fitted_hint_size("圓陣｜封隙 0/3
" + long_line, font, 420.0, 15)
	_check(font.get_string_size(long_line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= 420.0 or size == 10, "a long top-bar line shrinks to its box instead of running under the kill/gold panel")
	_check(hud_script.fitted_hint_size("短", font, 420.0, 15) == 15, "short top-bar lines keep their normal size")
	var pressure_src := FileAccess.get_file_as_string("res://scripts/services/encounter_pressure.gd")
	var squad_src := FileAccess.get_file_as_string("res://scripts/heroes/squad_manager.gd")
	_check(squad_src.contains("if bond_flash_text != \"\" and not Enemy.label_area_reserved(text_screen, 40.0):"), "the bond flash line yields to the switch card and badges")
	_check(pressure_src.contains("if _answer_under_hud(center):") and pressure_src.contains("Enemy.hud_panel_rects("), "ground badges under the HUD panels are not drawn half-cut")

func _test_version() -> void:
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.70.0-content-r41", "project version is 0.70.0-content-r41")
