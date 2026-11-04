extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	# The HP frame shows the real HP ratio; the cyan bar under it is experience.
	var hud_script: GDScript = load("res://scripts/ui/hud.gd")
	var rect: Rect2 = hud_script.hp_bar_rect(Rect2(18, 18, 20, 20), Rect2(44, 15, 150, 28), Rect2(214, 18, 38, 24), Rect2(20, 48, 230, 16))
	_check(rect == Rect2(14, 17, 194, 26), "the HP bar runs from the heart to the Lv label, above the XP bar")
	var stacked: Rect2 = hud_script.hp_bar_rect(Rect2(18, 18, 20, 20), Rect2(44, 15, 150, 28), Rect2(10, 60, 38, 24), Rect2(20, 10, 230, 16))
	_check(stacked.end.x == 200.0 and stacked.end.y == 43.0, "with the Lv label or XP bar elsewhere the HP bar keeps to the HP text")
	var src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(src.contains("hp_bar.value = clampf(float(hp) / maxf(1.0, float(max_hp)), 0.0, 1.0)") and src.contains("func _process(_delta: float) -> void:\n\t_sync_exp_caption()\n\t_sync_hp_bar()"), "the HP bar follows HP and the HUD layout every frame")
	_check(src.contains("hp_fill.bg_color = Color(\"c23a4e\", 0.78)") and src.find("root.add_child(hp_bar)") < src.find("root.add_child(hp_label)") and src.contains("hp_label.add_theme_constant_override(\"outline_size\", 4)"), "a red fill sits behind the outlined HP text")
	_check(src.contains("hp_bar.visible = hp_label.visible and rect.size.x > 24.0 and rect.size.y > 6.0"), "the HP bar hides with the HP text (pause) and when there is no room")
	# A seal hugging the screen edge gets the edge pointer and its formation badge.
	var relay: GDScript = load("res://scripts/services/formation_relay.gd")
	var view := Rect2(0, 0, 1366, 600)
	_check(relay.seal_in_view(view, Vector2(600, 300), 1.0) and not relay.seal_in_view(view, Vector2(40, 300), 1.0) and not relay.seal_in_view(view, Vector2(600, 560), 1.0) and relay.EDGE_MARGIN >= 100.0, "a seal near the edge counts as out of view")
	_check(not relay.seal_in_view(view, Vector2(200, 300), 2.0) and relay.seal_in_view(view, Vector2(240, 300), 2.0), "the edge margin scales with zoom")
	_check(FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd").contains("(seal_in_view(view, anchor, unit) and not seal_under_controls())"), "the pointer uses the edge margin")
	_check(FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd").contains("if pointer_layout.x >= 0.0 and pointer_needed():") and relay.new().pointer_needed() == false, "the marker follows a pointer only while one is needed now, never a stale one")
	var near: Array[Vector2] = relay.near_first(Vector2(600, 300), 214.0, [Vector2(12, 264), Vector2(600, 300)] as Array[Vector2])
	_check(near[0] == Vector2(600, 300) and near[1].distance_to(Vector2(600, 300)) <= 40.0 and near.find(Vector2(12, 264)) > 10, "a taken marker spot tries spots around the seal before the far grid")
	_check(FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd").contains("candidates = near_first(Vector2(x,y), width, candidates)"), "the marker uses the nearest-first order")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.71.0-content-r42", "project version is 0.71.0-content-r42")
	if failures.is_empty():
		print("R42_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R42_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
