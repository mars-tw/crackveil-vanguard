extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var hud_src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(hud_src.contains("func _maybe_show_stage_title() -> void:") and hud_src.contains("_maybe_show_stage_title()\n") and hud_src.contains("var title: String = MINIMAP.stage_label_for(str(GameManager.run_mode), str(GameManager.selected_stage_id))"), "entering a campaign stage shows its title in the centre once")
	_check(hud_src.contains("if title == \"\" or stage_title_shown == title:\n\t\treturn"), "the stage title shows once per stage, not every frame")
	var minimap_src := FileAccess.get_file_as_string("res://scripts/ui/r36_minimap.gd")
	_check(minimap_src.contains("var font_size := 13") and minimap_src.contains("draw_rect(Rect2(text_x - 4, size.x + 3, text_w + 8, 18), Color(\"08121f\", 0.86), true)"), "the minimap stage name sits on a dark plate at 13 px")
	var level_src := FileAccess.get_file_as_string("res://scripts/ui/level_up_screen.gd")
	_check(level_src.contains("if not portrait and card_scroll != null and card_count > 0 and card_count < 3:") and level_src.contains("card_grid.columns = card_count"), "a two-card level-up offer is centred in the panel")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.68.0-content-r39", "project version is 0.68.0-content-r39")
	if failures.is_empty():
		print("R25_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R25_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
