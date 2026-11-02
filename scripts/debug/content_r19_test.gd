extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var relay_script: GDScript = load("res://scripts/services/formation_relay.gd")
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(relay_src.contains("if not is_open() or not (pressure.phase in [\"warning\", \"active\"] or wrong_timer > 0) or accepted_formations().size() < 2:"), "the top-bar comparison also shows while the squad holds a wrong formation")
	var pressure_script: GDScript = load("res://scripts/services/encounter_pressure.gd")
	_check(pressure_script.choice_text("front", "") == "快封楔形／慢封圓陣・慢封反擊10秒", "the warning toast no longer repeats the top bar's seal times and heals")
	_check(pressure_script.choice_text("pincer", "spec_prepare") == "快封圓陣／慢封散兵・慢封反擊15秒", "the toast keeps the slow seal's real counter window")
	_check(relay_script.switch_card_for("pincer", "ring").contains("隊長身邊隊員每擊受傷 14→4"), "the ring card says the allies take 14→4 per hit, not that they deal it")
	var pressure_src := FileAccess.get_file_as_string("res://scripts/services/encounter_pressure.gd")
	_check(pressure_src.contains("pace_tags.append([tag, pace, str(FORMATION_NAMES[accepted[i]]).substr(0, 1)])") and pressure_src.contains("str(row[2]) + str(row[1])") and pressure_src.contains("Vector2(52, 28)"), "ground tags name the formation (楔快／圓慢) as well as the pace")
	var fast: Color = relay_script.seal_flash_color(false)
	var slow: Color = relay_script.seal_flash_color(true)
	_check(fast.r > fast.b and slow.b > slow.r, "a fast seal flashes gold and a slow seal cyan")
	_check(relay_src.contains("seal_flash_slow = GameManager.STARTING_BUILD.is_secondary(pressure.kind, squad.get_formation_id())") and relay_src.contains("text_layer.draw_arc(seal_flash_at, CAPTAIN_RADIUS * (1.0 + 2.2 * wave)"), "the seal flash colour follows the answer used and a wave runs out from the seal")
	var result_script: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	_check(result_script.defeat_cause({"captain_dead": true, "seal_state": {"step": 0}}) == "失敗原因：隊長倒下・第 1 道", "a defeat names the cause and the seal it fell at")
	_check(result_script.defeat_cause({"captain_dead": true, "boss_active": true, "seal_state": {"step": 3, "completed": true}}) == "失敗原因：隊長倒下・首領戰", "a defeat during the boss says so")
	_check(result_script.defeat_cause({"captain_dead": true}) == "失敗原因：隊長倒下", "runs without seal data still name the cause")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.62.0-content-r33", "project version is 0.62.0-content-r33")
	if failures.is_empty():
		print("R19_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R19_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
