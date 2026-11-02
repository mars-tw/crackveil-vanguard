extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var gm_src := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")
	_check(gm_src.contains("row[\"role\"] = \"captain\" if source.get(\"is_leader\") == true else \"member\""), "each damage row records whether a captain or a member dealt it")
	var result_script: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	var line: String = result_script.damage_share_line([{"id": "captain", "role": "captain", "damage": 600.0}, {"id": "scout", "role": "member", "damage": 250.0}, {"id": "guard", "role": "member", "damage": 150.0}])
	_check(line == "輸出：隊長 60%・隊員合計 40%（2 人）", "the result states the captain / member split of the run's damage")
	_check(result_script.damage_share_line([{"id": "captain", "role": "captain", "damage": 600.0}]) == "" and result_script.damage_share_line([]) == "", "no split line without member damage")
	var result_src := FileAccess.get_file_as_string("res://scripts/ui/r4_result_screen.gd")
	_check(result_src.contains("var share_line := damage_share_line(rows)\n\tif share_line != \"\":gain_label.text += \"\\n\" + share_line"), "the split line is shown on the result screen")
	var pressure_src := FileAccess.get_file_as_string("res://scripts/services/encounter_pressure.gd")
	_check(pressure_src.contains("if lane_index == answer_lane:\n\t\t\t\t_draw_answer(") and pressure_src.contains("answer_lane = 0 if captain_at.distance_to(lanes[0].get_center())"), "a pincer draws its answer badges once, on the lane nearer the captain")
	var screen = result_script.new()
	var held_right: String = screen._defeat_advice({"step": 1, "completed": false, "wrong": 1, "required": "scatter", "accepted": ["scatter", "wedge"], "formation": "scatter"})
	_check(held_right.contains("散兵陣形對了") and not held_right.contains("當時散兵"), "a defeat in an accepted formation is not described as a wrong formation")
	var held_secondary: String = screen._defeat_advice({"step": 1, "completed": false, "wrong": 1, "required": "scatter", "accepted": ["scatter", "wedge"], "formation": "wedge"})
	_check(held_secondary.contains("楔形陣形對了"), "the slow-seal answer also counts as a right formation")
	var held_wrong: String = screen._defeat_advice({"step": 1, "completed": false, "wrong": 2, "required": "scatter", "accepted": ["scatter", "wedge"], "formation": "ring"})
	_check(held_wrong.contains("需散兵、當時圓陣") and held_wrong.contains("2 次"), "a defeat in a wrong formation still names need, held and count")
	screen.free()
	_check(gm_src.contains("\"accepted\": Array(relay_node.accepted_formations()),"), "the seal state carries every accepted formation")
	_check(result_src.contains("if portrait and page_capacity>1 and card_h<PORTRAIT_CARD_MIN_H*scale and not portrait_single_card:") and result_src.contains("if portrait_single_card and view.y>view.x:return 1") and result_script.PORTRAIT_CARD_MIN_H >= 48.0, "a cramped portrait result shows one readable card per page instead of two cut cards")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.62.0-content-r33", "project version is 0.62.0-content-r33")
	if failures.is_empty():
		print("R23_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R23_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
