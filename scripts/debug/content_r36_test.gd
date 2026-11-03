extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	# The frost wall reads as ice in the scene.
	var wall: GDScript = load("res://scripts/vfx/frost_wall.gd")
	var wsrc := FileAccess.get_file_as_string("res://scripts/vfx/frost_wall.gd")
	_check(wsrc.contains("func _ice_segment(from: Vector2, to: Vector2) -> void:") and wsrc.contains("# frost haze streaming ahead of the wall") and wsrc.contains("Color(\"e8f8ff\", 0.95), THICKNESS * 0.4"), "the frost wall has haze ahead, a lit top face and spikes")
	_check(wall.MARK_SECONDS >= 2.0 and wsrc.contains("last_verdict_time = GameManager.elapsed_time"), "the pass verdict stays two seconds and is time-stamped")
	_check(FileAccess.get_file_as_string("res://scripts/ui/hud.gd").contains("\"frost_verdict_at\":"), "the HUD probe exposes the frost verdict for capture")
	# Large event words keep out of the right HUD column.
	var dn: GDScript = load("res://scripts/vfx/damage_number.gd")
	var dsrc := FileAccess.get_file_as_string("res://scripts/vfx/damage_number.gd")
	_check(dn.RIGHT_COLUMN_CLEAR >= 120.0 and dsrc.contains("if font_size >= PLATE_YIELD_FONT_SIZE and text_rect.end.x > css.x - RIGHT_COLUMN_CLEAR:"), "擊破・name slides out of the right HUD column")
	# The seal callout steps above the banner when it would cover other text.
	var rsrc := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(rsrc.contains("func _covers_other_text(local_rect: Rect2) -> bool:") and rsrc.contains("if _covers_other_text(box_c):\n\t\t\tbox_c.position.y = at.y - 25 - 32"), "the seal callout moves above the banner instead of covering badges")
	# The guard readout fits its 56 px region; the preparation subtitle clears the corner.
	var readout: Control = load("res://scripts/ui/combat_readout.gd").new()
	get_root().add_child(readout)
	await process_frame
	var style: StyleBoxFlat = readout.panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(style != null and style.content_margin_top >= 10.0 and style.content_margin_top + style.content_margin_bottom <= 14.0, "the guard readout keeps the frame top and leaves room for its detail line")
	readout.queue_free()
	_check(FileAccess.get_file_as_string("res://scripts/ui/r4_build_preparation.gd").contains("_place(rule_label,24,35,"), "the preparation subtitle starts clear of the corner ornament")
	# The result's first page is lighter; tallies live under 紀錄.
	var result_src := FileAccess.get_file_as_string("res://scripts/ui/r4_result_screen.gd")
	_check(not result_src.contains("if catch_line != \"\":gain_label.text") and result_src.contains("result.insert(0,\"戰況統計\\n\"+\"\\n\".join(tally))"), "catch-up and hazard tallies move to the 紀錄 page")
	_check(result_src.contains("gain_label.add_theme_constant_override(\"line_spacing\",4)"), "the gold lines get extra line spacing")
	var font: FontFile = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var missing := ""
	for s in ["戰況統計"]:
		for i in range(s.length()):
			var c: int = s.unicode_at(i)
			if c > 0x7f and not font.has_char(c):
				missing += char(c)
	_check(missing == "", "every new string is covered by the CJK subset font (missing: %s)" % missing)
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.67.0-content-r38", "project version is 0.67.0-content-r38")
	if failures.is_empty():
		print("R36_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R36_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
