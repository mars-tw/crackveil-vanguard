extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	# Stage 7 has its own rule: step on 先 then 後.
	var catalog: GDScript = load("res://scripts/services/special_elite_catalog.gd")
	var dunes: Dictionary = catalog.apply_stage_variant(catalog.make_config("shield", 40), "dunes")
	_check(str(dunes.get("stage_skill", "")) == "sand_glyphs" and str(dunes.get("stage_pressure", "")) == "王陵雙印" and str(dunes.get("special_elite_name", "")) == "砂盾重衛", "the seventh stage elites carry the tomb glyphs and their own names")
	var glyphs: GDScript = load("res://scripts/vfx/sand_glyphs.gd")
	var half := Vector2(glyphs.SPREAD, 0)
	_check(glyphs.advance_step(0, Vector2.ZERO, -half, half) == 1, "stepping on 先 first counts")
	_check(glyphs.advance_step(0, Vector2.ZERO, half, half) == 0, "stepping on 後 first does not count")
	_check(glyphs.advance_step(1, Vector2.ZERO, half, half) == 2, "後 after 先 solves the pair")
	_check(glyphs.advance_step(1, Vector2.ZERO, Vector2.ZERO, half) == 1, "standing between the glyphs does nothing")
	_check(glyphs.LIMIT_SECONDS >= 4.0 and 2.0 * glyphs.SPREAD > 2.0 * glyphs.GLYPH_RADIUS + 120.0, "the route is long enough to need walking and short enough to finish in time")
	var src := FileAccess.get_file_as_string("res://scripts/vfx/sand_glyphs.gd")
	_check(src.contains("if VINE_SNARE.off_seal(captain.global_position, 60.0) != captain.global_position:\n\t\treturn null"), "no glyphs while the captain holds an open seal")
	_check(src.contains("\"印記解開・無人受傷\" if solved else \"砂暴襲隊・印記未解\"") and src.contains("mark_layer.z_index = 120"), "solving or failing ends with a verdict on the top layer")
	_check(FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd").contains("if stage_skill == \"sand_glyphs\" and is_instance_valid(GameManager.player) and is_inside_tree():\n\t\tSAND_GLYPHS.spawn(get_parent(), GameManager.player)"), "a tomb elite lights the glyphs on every cast")
	_check(FileAccess.get_file_as_string("res://scripts/enemies/enemy_spawner.gd").contains("出招時兩側亮起印記，隊長先踩「先」再踩「後」"), "the elite toast teaches the tomb rule")
	var result: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	_check(result.vine_line({"sand_glyphs": 4, "sand_solved": 3, "sand_hits": 8}) == "王陵雙印 4 次・解開 3 次・砂暴打中 8 人次", "the result reports the tomb glyphs")
	_check(result.victory_badges({"squad_total": 6, "squad_alive": 5, "seal_state": {"wrong": 1, "sand_glyphs": 4, "sand_solved": 3}}) == "戰績：解開王陵雙印 3/4", "a solved glyph pair is a feat")
	_check(FileAccess.get_file_as_string("res://scripts/ui/hud.gd").contains("\"glyph_next_screen\": _glyph_next_screen(),"), "the HUD probe exposes the next glyph for the review bot")
	# Lance feedback and the landscape result fix.
	var vsrc := FileAccess.get_file_as_string("res://scripts/vfx/veil_lance.gd")
	_check(vsrc.contains("EntityFactory.spawn_death_burst(guard_at, SAFE, 2.6, \"gold_rain\")") and vsrc.contains("EntityFactory.spawn_death_burst(target.global_position, HAZARD, 2.2, \"burst\")") and vsrc.contains("STAMP_WORD_BLOCK if blocked else STAMP_WORD_HIT"), "a block and a hit each get their own burst and word")
	var rsrc := FileAccess.get_file_as_string("res://scripts/ui/r4_result_screen.gd")
	_check(rsrc.contains("progress_label.visible=progress_fits") and rsrc.contains("if progress_in_records:result.insert(0,\"整備進度\\n\"+progress_label.text)"), "a progress line with no room moves to 紀錄 instead of into the footer")
	var font: FontFile = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var missing := ""
	for s in [str(glyphs.LABEL), "先後", "印記解開・無人受傷", "砂暴襲隊・印記未解", "出招時兩側亮起印記，隊長先踩「先」再踩「後」", "王陵雙印 4 次・解開 3 次・砂暴打中 8 人次", "戰績：解開王陵雙印 3/4", "擋下刺中整備進度", "砂盾重衛砂爪獵將砂霧守望者曜焰術士砂群召喚師"]:
		for i in range(str(s).length()):
			var c: int = str(s).unicode_at(i)
			if c > 0x7f and not font.has_char(c):
				missing += char(c)
	_check(missing == "", "every new string is covered by the CJK subset font (missing: %s)" % missing)
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.71.0-content-r42", "project version is 0.71.0-content-r42")
	if failures.is_empty():
		print("R38_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R38_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
