extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var relay_script: GDScript = load("res://scripts/services/formation_relay.gd")
	_check(relay_script.compare_text("front") == "楔形快6秒整補8／圓陣慢9秒整補16", "the top bar lists both answers with seal time and heal, fast answer first")
	_check(relay_script.compare_text("pincer") == "圓陣快6秒整補8／散兵慢9秒整補16", "pincer lists ring fast and scatter slow")
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(not relay_src.contains("\"▶\""), "the top bar marker uses a glyph the game font has (▶ drew as a box)")
	var pressure_src := FileAccess.get_file_as_string("res://scripts/services/encounter_pressure.gd")
	_check(pressure_src.contains("if _under_equipment_bar(badge_backing):") and pressure_src.contains("DAMAGE_NUMBER_SCRIPT.blocked_by_hud("), "the ground answer label moves above the badges instead of under the equipment bar")
	_check(pressure_src.contains("if _under_equipment_bar(Rect2(center - Vector2.ONE * BADGE_SIZE * 0.5"), "badges that would sit under the equipment bar are left to the top bar")
	var hud_src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(hud_src.contains("var compare: String = relay.compare_line()") and hud_src.contains("(\"｜\" + compare) if compare != \"\" else \"\""), "the comparison follows the held formation on the first top-bar line, which has room on phones")
	_check(relay_src.contains("return \"%s・陣形正確・隊員增傷 +80%%\" % pressure.status_text()"), "the second line keeps only the wave status when two answers are compared")
	var font: Font = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var first: String = "楔形｜封隙 0/3｜" + relay_script.compare_text("front")
	var second: String = "重盾正面推進・預警 1.3 秒・陣形正確"
	_check(font.get_string_size(first, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= 315.0 and font.get_string_size(second, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= 315.0, "both top-bar lines fit the 835-wide phone mission box (315 px text) at 12 px")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.65.0-content-r36", "project version is 0.65.0-content-r36")
	if failures.is_empty():
		print("R18_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R18_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
