extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var gm: GDScript = load("res://scripts/autoload/game_manager.gd")
	_check(gm.squad_catch_up(1400.0, 50.0) == 1.0, "no catch-up before the run has 1500 damage")
	var early: float = gm.squad_catch_up(2400.0, 100.0)
	var late: float = gm.squad_catch_up(9600.0, 400.0)
	_check(early > 1.0 and early < late and late <= gm.SQUAD_CATCH_UP_MAX, "the catch-up grows in with the run's damage instead of opening at the cap")
	var enemy: GDScript = load("res://scripts/enemies/enemy.gd")
	_check(enemy.compact_elite_mark("藤爪獵將・2") == "藤爪" and enemy.compact_elite_mark("雷爪獵將") == "雷爪", "a compact elite plate keeps the elite's own short name")
	_check(enemy.compact_elite_mark("") == "菁英", "unnamed elites keep the generic mark")
	var enemy_src := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	_check(enemy_src.contains("if is_elite and stage_tint_strength > 0.0:\n\t\trest_color = rest_color.lerp(body_color, stage_tint_strength)") and enemy_src.contains("stage_tint_strength = 0.55 if str(config.get(\"stage_pressure\", \"\")) != \"\" else 0.0"), "a later-stage elite wears its stage tint on the body")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.57.0-content-r28", "project version is 0.57.0-content-r28")
	if failures.is_empty():
		print("R28_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R28_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
