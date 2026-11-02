extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	var gm_src := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")
	_check(gm_src.contains("tactical_director.relay.synergy_damage += amount * (1.0 - 1.0 / float(tactical_director.relay.FORMATION_SYNERGY_MEMBER))") and gm_src.contains("\"synergy_damage\": float(relay_node.synergy_damage)"), "the damage the synergy added is measured on real member hits and carried to the result")
	var result_script: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	var line: String = result_script.formation_read_line({"pressure_seconds": 60.0, "matched_seconds": 52.4, "wrong": 0, "fast_seals": 3, "slow_seals": 0, "synergy_damage": 4321.4})
	_check(line == "攻勢中對陣 87%・錯陣反噬 0 次\n封合：快封 3・慢封 0・隊員協同 52 秒（多打 4321 HP）", "the result states the extra damage the synergy dealt")
	_check(not result_script.formation_read_line({"pressure_seconds": 60.0, "matched_seconds": 30.0, "wrong": 0, "fast_seals": 1, "slow_seals": 0}).contains("多打"), "runs without measured synergy damage do not claim any")
	_check(relay_src.contains("\"下一道 \" if seal_flash_time < SEAL_FLASH_SECONDS else \"\""), "right after a seal the next wave's line is labelled as the next one")
	var catalog: GDScript = load("res://scripts/services/starting_build_catalog.gd")
	_check(str(catalog.node("spec_prepare").get("benefit", "")) == "封合反擊 5→10 秒" and str(catalog.node("spec_prepare").get("cost_text", "")) == "封合整補 8→0 HP", "the prepare node reads as before → after values")
	_check(str(catalog.node("bond_harmony").get("benefit", "")).contains("1.5→2.5 HP") and str(catalog.node("bond_construct").get("cost_text", "")).begins_with("編隊上限 9→8 人") and str(catalog.node("bond_relay").get("cost_text", "")) == "工匠爆炸延遲 0→0.45 秒", "the remaining descriptive build lines now give numbers")
	_check(relay_src.contains("if synergy_active and not was_synergy:\n\t\tsynergy_pulse_time = 0.0") and relay_src.contains("draw_line(captain_at, at, Color(gold, 0.9 * pulse), 3.0, true)") and relay_src.contains("\t_draw_synergy()\n\tvar color: Color = COLORS[step]"), "the synergy switching on pulses gold links and foot rings on the squad")
	var relay_script: GDScript = load("res://scripts/services/formation_relay.gd")
	_check(relay_script.SYNERGY_PULSE_SECONDS > 0.4 and relay_script.SYNERGY_PULSE_SECONDS <= 1.0, "the pulse is short (0.5 to 1 s)")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.60.0-content-r31", "project version is 0.60.0-content-r31")
	if failures.is_empty():
		print("R21_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R21_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
