extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	_test_stage_tints()
	_test_hit_flash_overlay()
	_test_elite_break()
	_test_switch_card()
	_test_required_wording()
	_test_boss_plate()
	_test_duplicate_elite_names()
	_test_formation_read()
	_test_version()
	if failures.is_empty():
		print("R13_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R13_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _test_stage_tints() -> void:
	var enemy_script: GDScript = load("res://scripts/enemies/enemy.gd")
	var catalog: GDScript = load("res://scripts/services/stage_catalog.gd")
	var seen := {}
	for stage in catalog.STAGES:
		var tint: Color = enemy_script.stage_rest_color(stage.color)
		seen[tint.to_html(false)] = true
		_check(tint.a == 1.0, "stage tint keeps full opacity for %s" % stage.id)
		_check(tint.get_luminance() >= 0.75, "stage tint stays light so sprites keep their brightness (%s)" % stage.id)
		_check(tint != Color.WHITE, "stage %s tints regular enemies" % stage.id)
	_check(seen.size() == catalog.STAGES.size(), "every stage has its own enemy tint")
	_check(enemy_script.STAGE_TINT_WEIGHT >= 0.15 and enemy_script.STAGE_TINT_WEIGHT <= 0.3, "tint weight is light, not a recolour")
	var source := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	_check(source.contains("if is_elite or is_boss or not is_instance_valid(GameManager):\n\t\treturn Color.WHITE") or source.contains("if is_elite or is_boss or not is_instance_valid(GameManager):\r\n\t\treturn Color.WHITE"), "elites and bosses keep their own art colours")
	_check(source.contains("sprite.modulate = rest_color") and source.contains("animated_sprite.modulate = rest_color"), "hit flash and spawn return to the stage tint, not plain white")
	_check(source.contains("if color == Color.WHITE:") and source.contains("color = rest_color"), "behaviour colour resets go back to the stage tint")

func _test_hit_flash_overlay() -> void:
	var enemy_script: GDScript = load("res://scripts/enemies/enemy.gd")
	_check(enemy_script.HIT_FLASH_OVERLAY_MAX_ALPHA <= 0.45, "the white hit overlay lets the body outline and colour show through")
	_check(enemy_script.HIT_FLASH_DURATION >= 0.12, "hit flash still lasts long enough to read (R10 contract)")

func _test_elite_break() -> void:
	var enemy_script: GDScript = load("res://scripts/enemies/enemy.gd")
	var enemy: CharacterBody2D = enemy_script.new()
	enemy.radius = 28.0
	enemy.special_elite_name = "霜環守望者"
	_check(enemy.elite_break_text() == "擊破・霜環守望者", "elite break card names the elite")
	enemy.special_elite_name = ""
	_check(enemy.elite_break_text() == "擊破", "unnamed elites keep the plain break word")
	enemy.death_dissolve_age = 0.0
	var start: float = enemy.elite_break_ring_radius()
	enemy.death_dissolve_age = enemy_script.ELITE_BREAK_RING_SECONDS
	var end: float = enemy.elite_break_ring_radius()
	_check(end > start * 2.5, "the gold break ring expands over its lifetime")
	_check(enemy_script.ELITE_BREAK_RING_SECONDS >= 0.4 and enemy_script.ELITE_BREAK_RING_SECONDS <= 1.0, "the break ring is a short beat")
	enemy.free()
	var source := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	_check(source.contains("elite_break_ring = elite_frame_visible() and not is_boss"), "only elites (not the boss) get the break ring")
	_check(source.contains("elite_break_ring = false"), "pooled enemies reset the break ring")

func _test_switch_card() -> void:
	var relay_script: GDScript = load("res://scripts/services/formation_relay.gd")
	var pincer: String = relay_script.switch_card_for("pincer", "ring")
	_check(pincer.contains("圓陣") and pincer.contains("兩翼包抄") and pincer.contains("每擊受傷 14→4"), "ring vs pincer card says the 14→4 is damage per hit, not a head count")
	var relay_src0 := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(relay_src0.contains("pressure.result_age = maxf(pressure.result_age, 2.4)"), "switching into the right formation clears the old wrong-formation verdict")
	var front: String = relay_script.switch_card_for("front", "wedge")
	_check(front.contains("楔形") and front.contains("+15%"), "wedge vs front card states the real +15% output")
	var artillery: String = relay_script.switch_card_for("artillery", "scatter")
	_check(artillery.contains("散兵") and artillery.contains("+8%"), "scatter vs artillery card states the real +8% move speed")
	var escort: String = relay_script.switch_card_for("front", "ring")
	_check(escort.contains("-10%") and not escort.contains("14→4"), "escort ring vs front does not claim the pincer protection")
	var pressure_src := FileAccess.get_file_as_string("res://scripts/services/encounter_pressure.gd")
	_check(pressure_src.contains("4.0 if protected else 14.0"), "the 14→4 claim matches the pressure rule")
	var squad_src := FileAccess.get_file_as_string("res://scripts/heroes/squad_manager.gd")
	_check(squad_src.contains("1.15") and squad_src.contains("1.08"), "the +15% and +8% claims match the formation table")
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(relay_src.contains("GameManager.STARTING_BUILD.accepts(GameManager.active_starting_node, pressure.kind, current_formation)"), "the card only shows when switching into an accepted formation")
	_check(relay_src.contains("_reserve_for_plates(box)"), "the switch card reserves its area from plates and numbers")
	_check(relay_src.contains("var span := width + 16.0") and relay_src.contains("HORIZONTAL_ALIGNMENT_CENTER, span, 18,"), "the switch card draw width follows its text, so the end is never cut")

func _test_required_wording() -> void:
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(not relay_src.contains("\"建議%s\""), "the top bar no longer calls a required formation a suggestion")
	_check(relay_src.contains("else \"需%s\" % NAMES[ORDER.find(needed)]"), "the top bar says 需 like the world badge")

func _test_boss_plate() -> void:
	var spawner_src := FileAccess.get_file_as_string("res://scripts/enemies/enemy_spawner.gd")
	_check(spawner_src.contains("config[\"special_elite_name\"] = str(stage.get(\"boss_name\", \"\"))"), "the gatekeeper wears its name plate on the field")

func _test_duplicate_elite_names() -> void:
	var enemy_script: GDScript = load("res://scripts/enemies/enemy.gd")
	var first: CharacterBody2D = enemy_script.new()
	var second: CharacterBody2D = enemy_script.new()
	first.is_active = true
	second.is_active = true
	var a: String = enemy_script.numbered_elite_name("雷爪獵將", first.get_instance_id())
	var b: String = enemy_script.numbered_elite_name("雷爪獵將", second.get_instance_id())
	_check(a == "雷爪獵將", "the first live elite keeps its plain name")
	_check(b == "雷爪獵將・2", "a second live elite with the same name is numbered")
	first.is_active = false
	var third: CharacterBody2D = enemy_script.new()
	third.is_active = true
	_check(enemy_script.numbered_elite_name("雷爪獵將", third.get_instance_id()) == "雷爪獵將", "a defeated elite frees its number")
	_check(enemy_script.numbered_elite_name("", second.get_instance_id()) == "", "a regular enemy releases its elite number")
	first.free()
	second.free()
	third.free()

func _test_formation_read() -> void:
	var result_script: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	_check(result_script.formation_read_line({"pressure_seconds": 40.0, "matched_seconds": 30.0, "wrong": 1}) == "攻勢中對陣 75%・錯陣反噬 1 次", "result states the real share of attack-wave time in an accepted formation")
	_check(result_script.formation_read_line({}) == "", "runs without attack waves show no formation line")
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(relay_src.contains("pressure_seconds += maxf(0.0, delta)") and relay_src.contains("matched_seconds += maxf(0.0, delta)"), "the share comes from real attack-wave timers")
	var gm_src := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")
	_check(gm_src.contains("\"matched_seconds\": float(relay_node.matched_seconds)"), "the run summary carries the timers to the result screen")

func _test_version() -> void:
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.56.0-content-r27", "project version is 0.56.0-content-r27")
