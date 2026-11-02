extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var gm_script: GDScript = load("res://scripts/autoload/game_manager.gd")
	_check(gm_script.SQUAD_SHARE_MEMBER == 2.5 and gm_script.SQUAD_SHARE_CAPTAIN == 0.75, "members carry more of the fight (x2.5) and the captain less (x0.75)")
	var gm_src := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")
	_check(gm_src.contains("if source.get(\"is_leader\") == true:\n\t\t\tmultiplier *= SQUAD_SHARE_CAPTAIN\n\t\telif source.get(\"is_leader\") == false:\n\t\t\tmultiplier *= SQUAD_SHARE_MEMBER"), "the share applies only to heroes; pets and other sources keep their damage")
	var result_src := FileAccess.get_file_as_string("res://scripts/ui/r4_result_screen.gd")
	_check(result_src.contains("		while fitted_size > 10 and _text_height(cards[number], card_rect.size.x-indent-4) > card_rect.size.y-bars_h-4:") and not result_src.contains("while group and fitted_size > 10"), "every result card shrinks to fit instead of ending in an ellipsis")
	var r33 := FileAccess.get_file_as_string("res://scripts/debug/combat_r33_regression_test.gd")
	_check(r33.contains("charged_damage >= 107.9 * float(GameManager.SQUAD_SHARE_CAPTAIN)") and r33.contains("* float(GameManager.SQUAD_SHARE_CAPTAIN) - 0.001 and"), "the charged-swing check keeps its +50% rule, scaled by the captain share")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.56.0-content-r27", "project version is 0.56.0-content-r27")
	if failures.is_empty():
		print("R22_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R22_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
