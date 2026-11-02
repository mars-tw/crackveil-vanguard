extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var relay_script: GDScript = load("res://scripts/services/formation_relay.gd")
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(relay_script.FORMATION_SYNERGY_MEMBER == 1.8, "formation synergy gives members +80% damage")
	_check(relay_src.contains("synergy_active = correct and pressure.started and pressure.phase in [\"warning\",\"active\"]") and relay_src.contains("\tsettled = 0\n\tsynergy_active = false"), "synergy is on only while a warned or active wave is answered, and drops otherwise")
	var gm_src := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")
	_check(gm_src.contains("source.get(\"hero_id\") != null and source.get(\"is_leader\") == false") and gm_src.contains("multiplier *= float(tactical_director.relay.FORMATION_SYNERGY_MEMBER)"), "the bonus applies to members only, never the captain or pets")
	_check(relay_src.contains("return \"%s・陣形正確・隊員增傷 +80%%\" % pressure.status_text()") and relay_src.contains("・陣形正確・%s・隊員 +80%%\""), "the top bar says the members' bonus while it is on")
	var result_script: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	var line: String = result_script.formation_read_line({"pressure_seconds": 60.0, "matched_seconds": 52.4, "wrong": 1, "fast_seals": 3, "slow_seals": 0})
	_check(line == "攻勢中對陣 87%・錯陣反噬 1 次\n封合：快封 3・慢封 0・隊員協同 52 秒", "the result reports how long the members fought with synergy")
	var catalog: GDScript = load("res://scripts/services/starting_build_catalog.gd")
	var gunner: Dictionary = catalog.node("crew_gunner")
	var escort: Dictionary = catalog.node("spec_escort")
	var step: Dictionary = catalog.node("spec_step")
	_check(str(gunner.get("cost_text", "")) == "隊長回能 100%→75%" and str(escort.get("cost_text", "")) == "移速 100%→88%；圓陣正面封合 6→7 秒" and str(step.get("cost_text", "")) == "換陣冷卻 4→7 秒", "build costs read as before → after values")
	var signed := 0
	for row in catalog.NODES:
		for key in ["benefit", "cost_text"]:
			var text := str(row.get(key, ""))
			if text.contains(" +") and text.ends_with("%") or text.contains(" -") and text.ends_with("%"):
				signed += 1
	_check(signed == 0, "no build text is left as a bare +N%/-N% change")
	var pressure_src := FileAccess.get_file_as_string("res://scripts/services/encounter_pressure.gd")
	_check(pressure_src.contains("if count > 1 and not wrong:") and pressure_src.contains("var text := answer_label(accepted)"), "two-answer badges drop the repeated 可用 caption; single and wrong keep it")
	_check(pressure_src.contains("draw_arc(target, 58.0, -PI * 0.5, -PI * 0.5 + TAU * left, 40, Color(\"ffe6a6\"), 4.0, true)") and pressure_src.contains("Enemy.reserve_plate_area(get_viewport().get_canvas_transform() * get_global_transform() * Rect2(target - Vector2.ONE * 62.0"), "landing rings get a countdown arc and keep name plates off them")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.61.0-content-r32", "project version is 0.61.0-content-r32")
	if failures.is_empty():
		print("R20_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R20_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
