extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var minimap: GDScript = load("res://scripts/ui/r36_minimap.gd")
	_check(minimap.stage_label_for("campaign", "garden") == "第2關・翠晶花園", "a campaign stage names itself under the minimap")
	_check(minimap.stage_label_for("endless", "garden") == "" and minimap.stage_label_for("campaign", "no_such_stage") == "", "endless runs and unknown stages keep the landmark name")
	var minimap_src := FileAccess.get_file_as_string("res://scripts/ui/r36_minimap.gd")
	_check(minimap_src.contains("var text_x := size.x - 2 - text_w if text_w > size.x - 8 else (size.x - text_w) * 0.5") and minimap_src.contains("name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size"),"a stage label wider than the minimap is drawn in full, not clipped")
	var result_script: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	var line: String = result_script.damage_share_line([{"role": "captain", "damage": 900.0}, {"role": "member", "damage": 100.0}, {"role": "member", "damage": 0.0}, {"role": "member", "damage": 0.0}])
	_check(line == "輸出：隊長 90%・隊員合計 10%（3 人）", "the member head count includes members who landed no hit")
	var gm_src := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")
	_check(gm_src.contains("row[\"role\"] = \"captain\" if is_instance_valid(player) and str(player.get(\"hero_id\")) == str(id) else \"member\""), "every recruited hero carries its role into the result")
	var number: GDScript = load("res://scripts/vfx/damage_number.gd")
	var pressure_src := FileAccess.get_file_as_string("res://scripts/services/encounter_pressure.gd")
	_check(number.FOCUS_DIM_ALPHA < 0.6 and pressure_src.contains("DAMAGE_NUMBER_SCRIPT.focus_dim = enabled and started and GameManager.game_running and phase in [\"warning\", \"active\"]") and pressure_src.contains("func _exit_tree() -> void:\n\tDAMAGE_NUMBER_SCRIPT.focus_dim = false"), "plain damage numbers step back while an attack wave is warned or active")
	var number_src := FileAccess.get_file_as_string("res://scripts/vfx/damage_number.gd")
	_check(number_src.contains("if focus_dim and prefix == \"\":\n\t\talpha *= FOCUS_DIM_ALPHA"), "critical hits (prefixed numbers) keep full strength")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.69.0-content-r40", "project version is 0.69.0-content-r40")
	if failures.is_empty():
		print("R24_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R24_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
