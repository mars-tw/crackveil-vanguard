extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	_test_card_wording()
	_test_short_run_read()
	_test_boss_plate_style()
	_test_plate_drift()
	_test_wording()
	_test_r14_review_fixes()
	_test_version()
	if failures.is_empty():
		print("R14_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R14_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _test_card_wording() -> void:
	var relay_script: GDScript = load("res://scripts/services/formation_relay.gd")
	var pincer: String = relay_script.switch_card_for("pincer", "ring")
	_check(pincer.contains("隊長身邊隊員每擊受傷 14→4"), "the ring card says it is the allies near the captain who take 14→4")
	_check(relay_script.switch_card_for("front", "ring").contains("全隊受傷 -10%"), "the escort ring card names who takes less damage")

func _test_short_run_read() -> void:
	var result_script: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	_check(result_script.formation_read_line({"pressure_seconds": 6.0, "matched_seconds": 6.0, "wrong": 0}) == "", "a run with under ten seconds of attack waves shows no formation share")
	_check(result_script.formation_read_line({"pressure_seconds": 30.0, "matched_seconds": 15.0, "wrong": 2}) == "攻勢中對陣 50%・錯陣反噬 2 次", "a real run still reports its share and backlashes")

func _test_boss_plate_style() -> void:
	var enemy_script: GDScript = load("res://scripts/enemies/enemy.gd")
	var boss_bg: Color = enemy_script.BOSS_PLATE_BG
	_check(boss_bg.r > boss_bg.b * 3.0 and boss_bg.a >= 0.9, "the boss plate is a solid crimson, unlike the dark elite plates")
	var source := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	_check(source.contains("backing.bg_color = BOSS_PLATE_BG if is_boss else Color(0.02, 0.04, 0.08, 0.88)") and source.contains("backing.set_border_width_all(3 if is_boss else 1)"), "pooled plates switch between the boss and elite styles")

func _test_plate_drift() -> void:
	var enemy_script: GDScript = load("res://scripts/enemies/enemy.gd")
	_check(enemy_script.ELITE_LABEL_MAX_DRIFT >= 120.0 and enemy_script.ELITE_LABEL_MAX_DRIFT <= 200.0, "a plate may move aside but not drift far from its body")
	var source := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	_check(source.contains("slot.get_center().distance_to(xf * Vector2.ZERO) > ELITE_LABEL_MAX_DRIFT * scale_y"), "a drifted plate falls back to the compact mark beside the body")
	_check(enemy_script.STAGE_TINT_WEIGHT >= 0.28, "the stage tint is strong enough to see in screenshots")

func _test_wording() -> void:
	var director := FileAccess.get_file_as_string("res://scripts/services/tactical_director.gd")
	_check(not director.contains("\"Boss %s") and not director.contains("守關・Boss"), "the top bar says 首領, not Boss")

func _test_r14_review_fixes() -> void:
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	var block_start := relay_src.find("switch_card_text = switch_card_for(pressure.kind, current_formation)")
	_check(block_start >= 0 and relay_src.find("clear_wrong_notice()", block_start) > block_start and relay_src.find("clear_wrong_notice()", block_start) < block_start + 600, "a correct switch always clears the backlash toast")
	var result_src := FileAccess.get_file_as_string("res://scripts/ui/r4_result_screen.gd")
	_check(result_src.contains("\"回復 %d・減傷 %d HP（含羈絆）\"") and not result_src.contains("個人總計（含羈絆）\n"), "support cards use two lines so narrow cards keep their numbers")

func _test_version() -> void:
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.60.0-content-r31", "project version is 0.60.0-content-r31")
