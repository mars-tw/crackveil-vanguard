extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var catalog: GDScript = load("res://scripts/services/special_elite_catalog.gd")
	var base: Dictionary = catalog.make_config("shield", 40)
	var garden: Dictionary = catalog.apply_stage_variant(catalog.make_config("shield", 40), "garden")
	_check(str(garden.special_elite_name) == "荊盾重衛" and str(base.special_elite_name) == "星盾重衛", "the second stage fields its own elite names")
	_check(float(garden.speed) > float(base.speed) and str(garden.special_skill) == str(base.special_skill), "a stage changes the elite pressure but keeps its skill (and formation answer)")
	_check(catalog.apply_stage_variant(catalog.make_config("shield", 40), "moon").get("special_elite_name") == "星盾重衛", "the first stage keeps the original roster")
	var spawner_src := FileAccess.get_file_as_string("res://scripts/enemies/enemy_spawner.gd")
	_check(spawner_src.count("SPECIAL_ELITES.apply_stage_variant(SPECIAL_ELITES.make_config(") == 2, "both special and tactical elites take the stage variant")
	var result: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	_check(result.catch_up_line({"catch_up_peak": 1.84, "catch_up_damage": 2310.4}) == "隊員追擊最高 ×1.8・多打 2310 HP", "the result explains the catch-up, its peak and the damage it added")
	_check(result.catch_up_line({"catch_up_peak": 1.0, "catch_up_damage": 0.0}) == "", "no catch-up line when it never triggered")
	var hud_src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(hud_src.contains("var catch_up_tag := (\"｜隊員追擊 ×%.1f\" % catch_up) if catch_up >= 1.05 else \"\""), "the top bar names the catch-up while it is active")
	var gm_src := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")
	_check(gm_src.contains("catch_up_damage += amount * (1.0 - 1.0 / catch_up)") and gm_src.contains("\"catch_up_peak\": catch_up_peak, \"catch_up_damage\": catch_up_damage,"), "the catch-up damage is measured on real member hits and carried to the result")
	var result_src := FileAccess.get_file_as_string("res://scripts/ui/r4_result_screen.gd")
	_check(result_src.contains("rows.sort_custom(func(a, b): return float(a.get(\"damage\", 0.0)) > float(b.get(\"damage\", 0.0)))"), "the output tab lists heroes by damage dealt")
	_check(result_src.contains("while gain_font>10 and gain_label.text!=\"\" and 58+summary_h+_gain_height(left_w)+progress_room>size.y-226:"), "the portrait gain lines shrink to fit instead of running under the tabs")
	_check(result_src.contains("while 56.0+summary_h+gain_h+2.0+progress_line_h>column_bottom and (gain_font>10 or summary_font>11):") and result_src.contains("_place(progress_label,20,gain_y+gain_h+2,left_w-8,progress_line_h)"), "the landscape left column shrinks gain then summary until the progress line fits above the footer")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.70.0-content-r41", "project version is 0.70.0-content-r41")
	if failures.is_empty():
		print("R27_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R27_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
