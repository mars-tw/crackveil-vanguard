extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	_test_two_answers()
	_test_seal_rates()
	_test_counter_window()
	_test_cards_and_text()
	_test_r15_review_fixes()
	await _test_choice_and_result()
	_test_version()
	if failures.is_empty():
		print("R15_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R15_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _test_two_answers() -> void:
	var catalog: GDScript = load("res://scripts/services/starting_build_catalog.gd")
	for kind in ["front", "pincer", "artillery"]:
		var accepted := 0
		for formation in ["wedge", "ring", "scatter"]:
			if catalog.accepts("", kind, formation):
				accepted += 1
		_check(accepted == 2, "%s accepts exactly two formations" % kind)
	_check(not catalog.accepts("", "front", "scatter") and not catalog.accepts("", "pincer", "wedge") and not catalog.accepts("", "artillery", "ring"), "one formation per pressure is still wrong")
	_check(catalog.PRIMARY == {"front":"wedge","pincer":"ring","artillery":"scatter"}, "the primary answers keep the original counters")
	var pressure_script: GDScript = load("res://scripts/services/encounter_pressure.gd")
	_check(pressure_script.COUNTERS == catalog.PRIMARY, "pressure counters and primary answers agree")

func _test_seal_rates() -> void:
	var catalog: GDScript = load("res://scripts/services/starting_build_catalog.gd")
	_check(catalog.seal_rate("", "front", "wedge") == 1.0, "the primary answer seals at full speed")
	_check(catalog.seal_rate("", "front", "ring") == catalog.SECONDARY_SEAL_RATE and catalog.SECONDARY_SEAL_RATE < 1.0, "the secondary answer seals slower")
	_check(catalog.seal_rate("", "front", "scatter") == 0.0, "a wrong formation does not seal")
	_check(catalog.seal_rate("spec_escort", "front", "ring") == 0.85, "the escort build keeps its faster ring seal (R3 value)")
	_check(catalog.seal_rate("spec_collect", "pincer", "scatter") == 1.0, "the collect build keeps its full-speed scatter seal")
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(relay_src.contains("GameManager.STARTING_BUILD.seal_rate(GameManager.active_starting_node, pressure.kind, squad.get_formation_id())"), "seal progress uses the shared rate table")

func _test_counter_window() -> void:
	var catalog: GDScript = load("res://scripts/services/starting_build_catalog.gd")
	_check(catalog.counter_seconds("", "pincer", "ring") == 5.0, "the primary seal keeps the 5 s counter")
	_check(catalog.counter_seconds("", "pincer", "scatter") > catalog.counter_seconds("", "pincer", "ring"), "the secondary seal earns a longer counter window")
	_check(catalog.counter_seconds("spec_prepare", "pincer", "ring") == 10.0 and catalog.counter_seconds("spec_prepare", "pincer", "scatter") == 15.0, "the prepare node adds 5 s to every seal (10 s primary as in R3, 15 s secondary)")
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(relay_src.contains("counter_timer = GameManager.STARTING_BUILD.counter_seconds(") and relay_src.contains("seal_text(step+1, last_seal_counter"), "the seal banner states the real counter length")

func _test_cards_and_text() -> void:
	var relay_script: GDScript = load("res://scripts/services/formation_relay.gd")
	var secondary: String = relay_script.switch_card_for("front", "ring")
	_check(secondary.contains("慢封 9 秒") and secondary.contains("反擊 10 秒"), "the secondary switch card states its trade")
	var primary: String = relay_script.switch_card_for("front", "wedge")
	_check(primary.contains("快封 6 秒") and not primary.contains("慢封"), "the primary switch card says it seals fast")
	var relay: Node2D = relay_script.new()
	_check(relay.seal_text(1, 10).contains("反擊 +20% 10 秒"), "a secondary seal banner shows 10 s")
	_check(relay.seal_text(1).contains("5 秒"), "the default banner still shows 5 s (R11 contract)")
	relay.free()

func _test_r15_review_fixes() -> void:
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(relay_src.contains("\"錯陣反噬・進度歸零・%s・%s\" % [accepted_text(),switch_hint()]"), "the wrong-formation top bar lists every usable formation, like the badges")
	_check(not relay_src.contains("錯陣反噬・進度歸零・需%s"), "the top bar never names a single required formation")
	var relay_script: GDScript = load("res://scripts/services/formation_relay.gd")
	var relay: Node2D = relay_script.new()
	relay.pressure = load("res://scripts/services/encounter_pressure.gd").new()
	for row in [["front","可用：楔形／圓陣"],["pincer","可用：圓陣／散兵"],["artillery","可用：散兵／楔形"]]:
		relay.pressure.kind = row[0]
		_check(relay.accepted_text() == row[1], "the fast-seal answer is listed first for %s" % row[0])
	relay.pressure.free()
	relay.free()
	var catalog: GDScript = load("res://scripts/services/starting_build_catalog.gd")
	_check(catalog.SECONDARY_COUNTER_SECONDS >= 2.0 * catalog.PRIMARY_COUNTER_SECONDS, "the slower seal earns at least double the counter window")

func _test_choice_and_result() -> void:
	var pressure_script: GDScript = load("res://scripts/services/encounter_pressure.gd")
	_check(pressure_script.choice_text("pincer", "") == "快封圓陣／慢封散兵・慢封反擊10秒", "the wave warning names both answers and their counter windows")
	_check(pressure_script.choice_text("front", "spec_prepare").contains("慢封反擊15秒"), "the warning reflects the prepare node's real +5 s")
	var result_script: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	var line: String = result_script.formation_read_line({"pressure_seconds": 40.0, "matched_seconds": 30.0, "wrong": 1, "fast_seals": 2, "slow_seals": 1})
	_check(line.contains("快封 2") and line.contains("慢封 1"), "the result lists how many seals used each answer")
	_check(not line.contains("\r") and line.split("\n").size() == 2, "the seal line is a clean second line with no stray carriage return")
	_check(result_script.formation_read_line({"pressure_seconds": 40.0, "matched_seconds": 40.0, "wrong": 0}) == "攻勢中對陣 100%・錯陣反噬 0 次", "runs without seals keep the single line (R13/R14 contract)")
	var result: CanvasLayer = result_script.new()
	root.add_child(result)
	await process_frame
	result.gain_label.text = "實際破盾增傷 57 HP
攻勢中對陣 100%・錯陣反噬 0 次
封合：快封 3・慢封 0"
	result.progress_label.text = "第二次免費選擇 1/4 次結算"
	result._apply_responsive_layout()
	_check(result._text_height(result.gain_label, result.gain_label.size.x) <= result.gain_label.size.y + 1.0 and result.gain_label.get_rect().end.y <= result.progress_label.get_rect().position.y + 0.5, "a three-line gain block fits its box and pushes the progress line down")
	result.queue_free()
	await process_frame
	var pressure_src := FileAccess.get_file_as_string("res://scripts/services/encounter_pressure.gd")
	_check(pressure_src.contains("var primary := str(GameManager.STARTING_BUILD.PRIMARY.get(kind, \"\"))") and pressure_src.contains("if id != primary and GameManager.STARTING_BUILD.accepts("), "the ground badge lists the fast-seal answer first, like the top bar")
	_check(not pressure_src.contains("預警 2 秒・%s") and pressure_src.contains("｜預警・%s"), "the warning toast keeps the urgent 預警 word but no fixed 2 s")
	var hud_src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(hud_src.contains("left_limit = notice_left") and hud_src.contains("clampf(center_x - fitted.x * 0.5, left_limit,"), "a widened toast never slides under the left status column")
	var gm := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")
	_check(gm.contains("\"fast_seals\": relay_node.history.filter(") and gm.contains("\"slow_seals\": relay_node.history.filter("), "the counts come from the real seal history")

func _test_version() -> void:
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.72.0-content-r43", "project version is 0.72.0-content-r43")
