extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	# Stage 8 has its own rule: switch to the formation on the tide sigil.
	var catalog: GDScript = load("res://scripts/services/special_elite_catalog.gd")
	var tide_config: Dictionary = catalog.apply_stage_variant(catalog.make_config("shield", 40), "tide")
	_check(str(tide_config.get("stage_skill", "")) == "tide_sigil" and str(tide_config.get("stage_pressure", "")) == "潮紋換陣" and str(tide_config.get("special_elite_name", "")) == "潮盾重衛", "the eighth stage elites carry the tide sigil and their own names")
	var tide: GDScript = load("res://scripts/vfx/tide_sigil.gd")
	_check(tide.pick_required("wedge", [], 0.0) == "ring" and tide.pick_required("wedge", [], 0.99) == "scatter", "the sigil is one of the two formations the squad does not hold")
	_check(tide.pick_required("ring", ["wedge", "ring"], 0.5) == "wedge", "with a seal open the sigil also answers the seal")
	_check(tide.pick_required("wedge", ["wedge"], 0.5) == "", "no tide when the only seal answer is already held")
	_check(tide.label_for("ring") == "潮紋圓陣・浪到前換成圓陣" and tide.verdict_text(true, 0) == "潮紋對上・浪頭分開" and tide.verdict_text(false, 6) == "潮浪拍隊・6 人受傷", "the tide names the formation and both outcomes")
	_check(tide.WARN_SECONDS >= 4.0, "the warning leaves time for two formation switches")
	_check(tide.too_soon(20.0, 10.0) and not tide.too_soon(23.0, 10.0) and not tide.too_soon(5.0, 90.0) and tide.MIN_GAP_SECONDS >= 10.0 and FileAccess.get_file_as_string("res://scripts/vfx/tide_sigil.gd").contains("accepted = Array(GameManager.tactical_director.relay.accepted_formations())"), "tides keep a breather and only ask for formations the assault also accepts")
	var tsrc := FileAccess.get_file_as_string("res://scripts/vfx/tide_sigil.gd")
	var seal_plate := Rect2(Vector2(-100, 70), Vector2(200, 30))
	var moved: Rect2 = tide.first_clear(Rect2(Vector2(-90, 74), Vector2(180, 28)), Transform2D.IDENTITY, [seal_plate])
	_check(not moved.intersects(seal_plate) and moved.position.x == -90.0 and tsrc.contains("Enemy.reserve_label_area(xf * placed, mark_layer)") and tsrc.contains("_plate(_place_plate("), "the tide plate steps past a seal plate and registers itself")
	_check(tsrc.contains("if VINE_SNARE.off_seal(captain.global_position, 60.0) != captain.global_position:\n\t\treturn null") and tsrc.contains("mark_layer.z_index = 120"), "no tide while the captain holds an open seal; the sigil is on the top layer")
	_check(FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd").contains("if stage_skill == \"tide_sigil\" and is_instance_valid(GameManager.player) and is_inside_tree():\n\t\tTIDE_SIGIL.spawn(get_parent(), GameManager.player, randf())"), "a tide elite rolls the wave on every cast")
	_check(FileAccess.get_file_as_string("res://scripts/enemies/enemy_spawner.gd").contains("出招時推來潮浪，浪到前換成潮紋上的陣形"), "the elite toast teaches the tide rule")
	var result: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	_check(result.vine_line({"tide_sigils": 5, "tide_matched": 4, "tide_hits": 7}) == "潮紋換陣 5 次・換對 4 次・潮浪打中 7 人次", "the result reports the tide sigils")
	_check(result.victory_badges({"squad_total": 6, "squad_alive": 5, "seal_state": {"wrong": 1, "tide_sigils": 5, "tide_matched": 4}}) == "戰績：潮紋換陣 4/5", "a matched tide is a feat")
	_check(FileAccess.get_file_as_string("res://scripts/ui/hud.gd").contains("\"tide_required\": _tide_required(),"), "the HUD probe exposes the tide sigil for the review bot")
	# Lance outcomes are stamped on the top layer with different shapes.
	var lance: GDScript = load("res://scripts/vfx/veil_lance.gd")
	var vsrc := FileAccess.get_file_as_string("res://scripts/vfx/veil_lance.gd")
	_check(lance.STAMP_WORD_BLOCK == "擋下" and lance.STAMP_WORD_HIT % 30 == "刺中 30" and vsrc.contains("_draw_stamp(age - WARN_SECONDS)") and vsrc.contains("hexagon") and vsrc.contains("shard") and not vsrc.contains("spawn_damage_number") and vsrc.contains("draw_colored_polygon(hexagon.slice(0, 6)"), "a block stamps a shield hexagon and 擋下, a hit violet shards and 刺中 30, once")
	# Glyph route arrows and seconds.
	var gsrc := FileAccess.get_file_as_string("res://scripts/vfx/sand_glyphs.gd")
	_check(gsrc.contains("str(seconds_left())") and gsrc.contains("var chevron := PackedVector2Array("), "the tomb glyphs show the seconds left and a chevron route")
	# Guard plate: the frame no longer crosses the detail line.
	var readout: Control = load("res://scripts/ui/combat_readout.gd").new()
	get_root().add_child(readout)
	await process_frame
	readout.panel.size = Vector2(250, 56)
	readout._fit_ornament()
	_check(readout.ornament != null and readout.ornament.position == Vector2.ZERO and readout.ornament.size == readout.panel.size, "the guard plate frame covers the whole panel, outside the text")
	readout.queue_free()
	# Bond words above the heroes; top bar first line without the rule sheet.
	var squad_src := FileAccess.get_file_as_string("res://scripts/heroes/squad_manager.gd")
	var squad: GDScript = load("res://scripts/heroes/squad_manager.gd")
	_check(squad.BOND_TEXT_Z > 100 and squad_src.contains("bond_text_layer.draw_rect(plate"), "bond words draw above the heroes on a dark plate")
	var hud_src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(hud_src.contains("tactical_hint.text = \"%s｜封隙 %d/3%s\\n%s\" % [formation, relay.step, catch_up_tag, relay.next_action()]"), "the top bar's first line is formation, seals and catch-up only")
	var pressure: GDScript = load("res://scripts/services/encounter_pressure.gd")
	_check(pressure.pace_detail("front", "wedge") == "6秒・補8" and pressure.pace_detail("front", "ring") == "9秒・補16", "the ground tags carry each answer's seal time and heal")
	# Contribution parts never split: the page wraps between whole parts.
	var cjk: FontFile = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var parts := PackedStringArray(["迴響歌者 回復減傷 1285", "潮汐魔導 封隙 29 秒", "裂弧斥候 承傷 391"])
	var wrapped: String = result.wrap_parts("關鍵貢獻：", parts, cjk, 14, 300.0)
	var whole := true
	for row in wrapped.split("\n"):
		whole = whole and not row.begins_with("秒") and cjk.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= 300.0
	_check(wrapped.split("\n").size() >= 2 and whole and wrapped.contains("潮汐魔導 封隙 29 秒") and FileAccess.get_file_as_string("res://scripts/ui/r4_result_screen.gd").contains("var gain_h:=maxf(24.0,_gain_height(left_w-8))"), "contributions wrap between whole parts, never between a number and its unit")
	var font: FontFile = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var missing := ""
	for s in [tide.label_for("wedge"), tide.label_for("scatter"), "潮紋對上・浪頭分開", "潮浪拍隊・6 人受傷", "潮紋圓陣・已對上，守住陣形", "出招時推來潮浪，浪到前換成潮紋上的陣形", "潮紋換陣 5 次・換對 4 次・潮浪打中 7 人次", "戰績：潮紋換陣 4/5", "潮盾重衛浪爪獵將珊霧守望者海焰術士珊群召喚師", "6秒・補8", " "]:
		for i in range(str(s).length()):
			var c: int = str(s).unicode_at(i)
			if c > 0x7f and not font.has_char(c):
				missing += char(c)
	_check(missing == "", "every new string is covered by the CJK subset font (missing: %s)" % missing)
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.68.0-content-r39", "project version is 0.68.0-content-r39")
	if failures.is_empty():
		print("R39_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R39_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
