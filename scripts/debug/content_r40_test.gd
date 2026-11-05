extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	# Stage 9 asks for the captain's own skill at the right place.
	var catalog: GDScript = load("res://scripts/services/special_elite_catalog.gd")
	var bloom_config: Dictionary = catalog.apply_stage_variant(catalog.make_config("shield", 40), "bloom")
	_check(str(bloom_config.get("stage_skill", "")) == "moon_bloom" and str(bloom_config.get("stage_pressure", "")) == "月華花蕾" and str(bloom_config.get("special_elite_name", "")) == "月盾重衛", "the ninth stage elites carry the moon bloom and their own names")
	var bloom: GDScript = load("res://scripts/vfx/moon_bloom.gd")
	_check(bloom.plant_at(Vector2.ZERO, Vector2(1000, 0)) == Vector2(bloom.PLANT_DISTANCE, 0) and is_equal_approx(bloom.plant_at(Vector2.ZERO, Vector2(50, 0)).length(), bloom.CUT_RADIUS * 1.8), "the bud is planted toward the elite, a short walk from the captain")
	_check(bloom.too_soon(20.0, 10.0) and not bloom.too_soon(23.0, 10.0) and not bloom.too_soon(5.0, 90.0), "blooms keep a breather between them")
	_check(bloom.LIMIT_SECONDS >= 5.0 and bloom.CUT_SECONDS <= 1.0 and bloom.HEAL_SHARE > 0.0 and bloom.SPROUTS >= 3 and bloom.CUT_RADIUS >= 80.0, "the bud leaves time to walk over and spin, and costs heals when it opens")
	_check(bloom.verdict_text(true, 0) == "花蕾斬開・群怪不回血" and bloom.verdict_text(false, 4) == "月華盛放・長出 4 隻靈花" and bloom.status_text(3, false, false, false, 0) == "月華花蕾・3 秒內走過去旋斬" and bloom.status_text(2, true, false, false, 0) == "月華花蕾・在旁邊按住旋斬・2 秒" and bloom.status_text(1, false, true, false, 4) == "月華盛放・長出 4 隻靈花・下次留能量旋斬", "the bloom names the action, both outcomes and what to do next time")
	_check(not bloom.spinning(null), "no captain, no spin")
	var bsrc := FileAccess.get_file_as_string("res://scripts/vfx/moon_bloom.gd")
	_check(bsrc.contains("if VINE_SNARE.off_seal(captain.global_position, 60.0) != captain.global_position:\n\t\treturn null") and bsrc.contains("mark_layer.z_index = 120") and bsrc.contains("if captain_near() and spinning(GameManager.player):") and bsrc.contains("enemy.apply_support_heal(float(enemy.get(\"max_hp\")) * HEAL_SHARE)") and bsrc.contains("EntityFactory.spawn_enemy(\"bloom_wisp\"") and bsrc.contains("bloom.global_position = on_screen(captain, plant_at("), "no bloom on an open seal; the cut needs the captain beside it spinning; an open bloom heals the crowd")
	_check(FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd").contains("if stage_skill == \"moon_bloom\" and is_instance_valid(GameManager.player) and is_inside_tree():\n\t\tMOON_BLOOM.spawn(get_parent(), self, GameManager.player)"), "a bloom elite plants a bud on every cast")
	_check(FileAccess.get_file_as_string("res://scripts/enemies/enemy_spawner.gd").contains("出招時種下月華花蕾，隊長走過去旋斬斬開"), "the elite toast teaches the bloom rule")
	var result: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	_check(result.vine_line({"moon_blooms": 5, "bloom_cut": 2, "bloom_sprouts": 12}) == "月華花蕾 5 次・斬開 2 次・長出靈花 12 隻" and result.victory_badges({"squad_total": 6, "squad_alive": 5, "seal_state": {"wrong": 1, "moon_blooms": 5, "bloom_cut": 2}}) == "戰績：斬開月華 2/5", "the result reports the blooms and counts a cut as a feat")
	var hud_src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(hud_src.contains("\"bloom_screen\": _bloom_screen(),") and hud_src.contains("for group in [\"tide_sigils\", \"moon_blooms\"]:"), "the HUD probe exposes the bloom; the top bar follows a tide or a bloom")
	# The top bar no longer says "陣形正確" while a wave is about to break.
	var tide: GDScript = load("res://scripts/vfx/tide_sigil.gd")
	_check(tide.status_text("ring", 3, false, false, false, 0) == "潮紋圓陣・3 秒內換成圓陣" and tide.status_text("ring", 2, true, false, false, 0) == "潮紋圓陣・已對上，守住陣形・2 秒" and tide.status_text("ring", 1, false, true, false, 6) == "潮浪拍隊・6 人受傷・浪到時要是圓陣" and tide.status_text("ring", 1, true, true, true, 0) == "潮紋對上・浪頭分開", "while a tide is up the top bar's second line is the tide's")
	_check(hud_src.contains("catch_up_tag, _tide_or(relay.next_action())]") and hud_src.contains("_tide_or(GameManager.tactical_director.current_hint())]"), "both top bar forms give way to the tide or bloom line")
	# Ground answer tags: larger numbers, never touching each other.
	var pressure: GDScript = load("res://scripts/services/encounter_pressure.gd")
	var cjk: FontFile = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var left_badge := Rect2(Vector2(-67, -32), Vector2(64, 64))
	var right_badge := Rect2(Vector2(3, -32), Vector2(64, 64))
	var left_tag: Rect2 = pressure.pace_tag_rect(left_badge, -0.5, false)
	var right_tag: Rect2 = pressure.pace_tag_rect(right_badge, 0.5, false)
	_check(not left_tag.intersects(right_tag) and left_tag.end.y < left_badge.position.y and pressure.DETAIL_SIZE >= 18 and cjk.get_string_size(pressure.pace_detail("front", "ring"), HORIZONTAL_ALIGNMENT_LEFT, -1, pressure.DETAIL_SIZE).x <= pressure.TAG_WIDTH - 6.0, "the two tags never touch and the larger seconds/heal line fits its tag")
	var below: Rect2 = pressure.pace_tag_rect(left_badge, -0.5, true)
	var psrc := FileAccess.get_file_as_string("res://scripts/services/encounter_pressure.gd")
	_check(below.position.y > left_badge.end.y and psrc.contains("var tags_below := count > 1 and _tags_blocked_above(center, count)") and psrc.contains("Enemy.active_label_areas_except(self)"), "the tags move under the badges when a notice or plate holds the space above")
	_check(hud_src.contains("Enemy.reserve_label_area(toast_panel.get_global_rect(), toast_panel)"), "the battle notice registers its area so ground text steps around it")
	# The shared registry leaves out the caller's own areas.
	var owner_a := Node.new()
	var owner_b := Node.new()
	var enemy_script: GDScript = load("res://scripts/enemies/enemy.gd")
	enemy_script.reserve_label_area(Rect2(0, 0, 10, 10), owner_a)
	enemy_script.reserve_label_area(Rect2(50, 0, 10, 10), owner_b)
	var others: Array[Rect2] = enemy_script.active_label_areas_except(owner_a)
	_check(others.has(Rect2(50, 0, 10, 10)) and not others.has(Rect2(0, 0, 10, 10)), "a placer sees every registered area but its own")
	enemy_script.clear_label_areas(owner_a)
	enemy_script.clear_label_areas(owner_b)
	owner_a.free()
	owner_b.free()
	# The lance stamp rises past an answer tag instead of covering it.
	var lance: GDScript = load("res://scripts/vfx/veil_lance.gd")
	var tag_area := Rect2(Vector2(-40, -40), Vector2(80, 50))
	var moved: Vector2 = lance.first_clear_base(Vector2(-30, 0), Vector2(60, 36), Transform2D.IDENTITY, [tag_area])
	_check(moved.y < 0.0 and not Rect2(moved + Vector2(-6, -36), Vector2(72, 44)).intersects(tag_area), "the 擋下／刺中 word steps up past a tag already there")
	var font: FontFile = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var missing := ""
	for s in [bloom.LABEL, bloom.verdict_text(true, 0), bloom.status_text(1, false, true, false, 4), bloom.status_text(2, true, false, false, 0), "出招時種下月華花蕾，隊長走過去旋斬斬開", "月華花蕾 5 次・斬開 2 次・長出靈花 12 隻", "戰績：斬開月華 2/5", "月盾重衛花爪獵將靈霧守望者月焰術士花群召喚師", tide.status_text("ring", 1, false, true, false, 6), tide.status_text("ring", 2, true, false, false, 0), "9秒 補16"]:
		for i in range(str(s).length()):
			var c: int = str(s).unicode_at(i)
			if c > 0x7f and not font.has_char(c):
				missing += char(c)
	_check(missing == "", "every new string is covered by the CJK subset font (missing: %s)" % missing)
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.74.0-content-r45", "project version is 0.74.0-content-r45")
	if failures.is_empty():
		print("R40_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R40_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
