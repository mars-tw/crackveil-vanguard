extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	_test_plate_edges_and_gap()
	_test_plate_above_captain_ring()
	_test_damage_numbers_avoid_equipment_bar()
	_test_amber_verdict()
	_test_marker_avoids_rule_text()
	await _test_scaled_hud_reservation()
	await _test_result_roster()
	_test_version()
	if failures.is_empty():
		print("R12_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R12_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _test_plate_edges_and_gap() -> void:
	var enemy_script: GDScript = load("res://scripts/enemies/enemy.gd")
	var view := Vector2(1558, 720)
	var size := Vector2(200, 30)
	var left: Rect2 = enemy_script.clamp_label_to_screen(Rect2(Vector2(-60, 300), size), view)
	_check(left.position.x >= 8.0 and left.size == size, "plate near the left edge is pulled fully on screen")
	var right: Rect2 = enemy_script.clamp_label_to_screen(Rect2(Vector2(1500, 300), size), view)
	_check(right.end.x <= view.x - 8.0, "plate near the right edge is pulled fully on screen")
	var inside := Rect2(Vector2(600, 300), size)
	_check(enemy_script.clamp_label_to_screen(inside, view) == inside, "plate in open field is not moved")
	var clamped_slot: Rect2 = enemy_script.elite_label_slot(left, Rect2(Vector2(left.position.x, 420), size), view, _none())
	_check(clamped_slot.size != Vector2.ZERO and clamped_slot.position.x >= 0.0, "left-edge elite still gets a plate after clamping")
	_check(enemy_script.ELITE_LABEL_GAP >= 8.0, "plates keep at least 8 px from other text frames")
	var badge := Rect2(Vector2(600, 300), Vector2(180, 40))
	var touching: Array[Rect2] = [badge.grow(enemy_script.ELITE_LABEL_GAP)]
	var beside := Rect2(Vector2(784, 300), size)
	_check(enemy_script.elite_label_slot(beside, Rect2(Vector2(784, 420), size), view, touching).position.y != 300.0, "a plate 4 px from a badge no longer counts as free")
	var crowded: Array[Rect2] = [Rect2(Vector2(560, 290), Vector2(280, 50)), Rect2(Vector2(560, 410), Vector2(280, 90))]
	var full_above := Rect2(Vector2(600, 300), size)
	var full_below := Rect2(Vector2(600, 420), size)
	_check(enemy_script.elite_label_slot(full_above, full_below, view, crowded).size == Vector2.ZERO, "crowded field has no room for a full name plate")
	var mark: Vector2 = enemy_script.ELITE_MARK_SIZE
	var mark_slot: Rect2 = enemy_script.elite_label_slot(Rect2(Vector2(682, 250), mark), Rect2(Vector2(682, 520), mark), view, crowded)
	_check(mark_slot.size == mark, "a compact elite mark still finds room where the name plate cannot")
	_check(mark.x <= 64.0 and str(enemy_script.ELITE_MARK_TEXT) == "菁英", "compact mark is small and drawn as a glyph, not the name")
	var source := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	_check(source.contains("special_label.text = compact_elite_mark(special_elite_name) if compact else special_elite_name") and enemy_script.compact_elite_mark("") == "菁英", "hidden plates fall back to the compact mark")
	_check(source.contains("Vector2(side_x, -18)") and source.count("Vector2(-side_x -") >= 2, "plate and compact mark also try both sides of the body before giving up")
	_check(source.contains("taken[i] = taken[i].grow(ELITE_LABEL_GAP)"), "placement grows every taken frame by the gap")
	_check(source.contains("clamp_label_to_screen(Rect2(xf * above_local") and source.contains("clamp_label_to_screen(Rect2(xf * below_local"), "both plate positions are clamped before slot choice")

func _test_plate_above_captain_ring() -> void:
	var enemy_script: GDScript = load("res://scripts/enemies/enemy.gd")
	var identity: Node2D = load("res://scripts/arena/r4_battle_identity.gd").new()
	identity._ready()
	_check(enemy_script.ELITE_LABEL_Z > identity.z_index, "elite plates draw above the captain ring layer")
	_check(enemy_script.ELITE_LABEL_Z < 100, "damage numbers (z 100) still draw above plates")
	identity.free()

func _test_damage_numbers_avoid_equipment_bar() -> void:
	var number_script: GDScript = load("res://scripts/vfx/damage_number.gd")
	var bar := Rect2(Vector2(574, 674), Vector2(410, 38))
	var blockers: Array[Rect2] = [bar]
	number_script.hud_blockers = blockers
	_check(number_script.blocked_by_hud(Rect2(Vector2(640, 660), Vector2(80, 24))), "number crossing the equipment bar is hidden")
	_check(number_script.blocked_by_hud(Rect2(Vector2(640, 652), Vector2(80, 24))), "number touching the bar's top edge is hidden")
	_check(not number_script.blocked_by_hud(Rect2(Vector2(640, 500), Vector2(80, 24))), "number above the bar stays visible")
	var empty: Array[Rect2] = []
	number_script.hud_blockers = empty
	_check(not number_script.blocked_by_hud(Rect2(Vector2(640, 660), Vector2(80, 24))), "no blockers when the bar is hidden")
	var hud := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(hud.contains("DAMAGE_NUMBER.hud_blockers = blockers"), "HUD publishes the equipment bar rect each layout")
	var number_source := FileAccess.get_file_as_string("res://scripts/vfx/damage_number.gd")
	_check(number_source.contains("if blocked_by_hud(text_rect):"), "numbers check the HUD blockers every frame")
	var setup_body := number_source.substr(number_source.find("func setup("), number_source.find("func pool_reset(") - number_source.find("func setup("))
	_check(setup_body.contains("_update_hud_visibility()"), "a new number is hidden on its spawn frame, before the game can pause")
	_check(number_source.contains("\t\t_update_hud_visibility()"), "the same check still runs every frame")
	var view := Vector2(1366, 600)
	_check(number_script.clamp_to_screen(Vector2(700, 4), Vector2(40, 12), view).y >= 12.0, "a crit near the top edge is pulled fully on screen")
	_check(number_script.clamp_to_screen(Vector2(700, 598), Vector2(40, 12), view).y <= 588.0, "a crit near the bottom edge is pulled fully on screen")
	_check(number_script.clamp_to_screen(Vector2(700, 300), Vector2(40, 12), view) == Vector2(700, 300), "numbers in the field are not moved")
	var verdict_area: Array[Rect2] = [Rect2(Vector2(500, 200), Vector2(280, 58))]
	_check(number_script.covers_rule_text(Rect2(Vector2(600, 230), Vector2(80, 40)), verdict_area), "a number or 擊破 over a verdict line is hidden")
	_check(not number_script.covers_rule_text(Rect2(Vector2(600, 320), Vector2(80, 40)), verdict_area), "numbers away from rule text stay visible")
	_check(number_source.contains("var screen_rect := Rect2(screen - value_label.size * scale * 0.5, value_label.size * scale)") and number_source.contains("covers_rule_text(screen_rect, Enemy.active_label_areas())"), "numbers check reserved rule text in viewport pixels")
	_check(number_source.contains("if value_label.visible and font_size >= PLATE_YIELD_FONT_SIZE:") and number_source.contains("Enemy.reserve_label_area(screen_rect, self)"), "擊破 and 破甲 reserve their area so plates move aside")
	_check(number_source.contains("font_size < PLATE_YIELD_FONT_SIZE and covers_rule_text(screen_rect, Enemy.elite_plate_rects())"), "small numbers hide over elite name plates")
	_check(number_script.PLATE_YIELD_FONT_SIZE > 22 and number_script.PLATE_YIELD_FONT_SIZE <= 36, "only the large event words (36/38 px), not crit numbers (22 px), push plates")
	_check(number_source.find("Enemy.clear_label_areas(self)") < number_source.find("covers_rule_text(screen_rect"), "a word clears its own area before testing rule text, so it never hides itself")

func _test_amber_verdict() -> void:
	var relay_script: GDScript = load("res://scripts/services/formation_relay.gd")
	var correct_hit := {"formation":"scatter","members":9,"hit":3,"protected":0,"reduced":0,"correct":true}
	var wrong := {"formation":"wedge","members":7,"hit":7,"protected":0,"reduced":0,"correct":false}
	var amber: Color = relay_script.verdict_color(correct_hit)
	_check(amber.s >= 0.7, "amber verdict is saturated enough to read as amber at thumbnail size")
	_check(amber.get_luminance() >= 0.55, "amber verdict stays bright on the dark backing")
	_check(absf(amber.h - relay_script.verdict_color(wrong).h) > 0.06, "amber hue stays clearly apart from the wrong-formation red")
	var source := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(source.contains("Color(0.03,0.05,0.09,0.84*fade)"), "verdict backing is darker for contrast")

func _test_marker_avoids_rule_text() -> void:
	var relay_script: GDScript = load("res://scripts/services/formation_relay.gd")
	var badge: Array[Rect2] = [Rect2(Vector2(500, 400), Vector2(180, 40))]
	_check(relay_script.marker_hits_text(Rect2(Vector2(520, 380), Vector2(214, 30)), badge), "marker over a seal badge is rejected")
	_check(relay_script.marker_hits_text(Rect2(Vector2(520, 368), Vector2(214, 30)), badge), "marker touching a badge's top edge is rejected")
	_check(not relay_script.marker_hits_text(Rect2(Vector2(520, 300), Vector2(214, 30)), badge), "marker away from rule text is accepted")
	var source := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(source.contains("if marker_hits_text(Rect2(candidate_rect.position*scale_factor,candidate_rect.size*scale_factor),text_areas):clear=false"), "marker candidates are checked against reserved rule text")
	_check(not source.contains("elite_plate_rects"), "the marker keeps its place; plates are the ones that move aside")
	_check(source.contains("Rect2(point + Vector2(-50, -40), Vector2(100, 96)), self)"), "off-screen seal pointer and its ordinal reserve their area from plates")
	var enemy_script: GDScript = load("res://scripts/enemies/enemy.gd")
	_check(enemy_script.ELITE_LABEL_SIZE.y >= 34.0, "reserved plate slot covers the drawn plate height")
	_check(enemy_script.ELITE_LABEL_EDGE >= 16.0, "edge margin absorbs one frame of camera lag")

func _test_scaled_hud_reservation() -> void:
	var es: GDScript = load("res://scripts/enemies/enemy.gd")
	var seal_owner := Node2D.new()
	root.add_child(seal_owner)
	es.reserve_plate_area(Rect2(Vector2(700, 300), Vector2(112, 112)), seal_owner)
	_check(not es.label_area_reserved(Vector2(756, 356), 0.0), "a seal badge area does not hide the captain crown or ally icons")
	_check(es.active_plate_only_areas().size() == 1, "the seal badge area is visible to plate placement")
	es.clear_label_areas(seal_owner)
	_check(es.active_plate_only_areas().is_empty(), "clearing the seal's areas on redraw also clears its plate-only area")
	seal_owner.free()
	var panels: Array[Rect2] = es.hud_panel_rects(Vector2(1558, 720))
	_check(panels.size() >= 7, "plates receive every HUD panel rect")
	var enemy_src := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	_check(enemy_src.contains("taken.append_array(hud_panel_rects(view))") and enemy_src.contains("taken.append_array(active_plate_only_areas())"), "plates avoid HUD panels and seal badges")
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(relay_src.contains("Enemy.reserve_plate_area(") and relay_src.contains("Vector2(300, 190) * unit"), "seal badge reserved for plates; off-screen pointer clears the kill/gold panel")
	var enemy_script: GDScript = load("res://scripts/enemies/enemy.gd")
	var layer := CanvasLayer.new()
	layer.scale = Vector2(1.85, 1.85)
	root.add_child(layer)
	var marker := Label.new()
	marker.position = Vector2(12, 196)
	marker.size = Vector2(214, 30)
	layer.add_child(marker)
	await process_frame
	enemy_script.clear_label_areas(marker)
	enemy_script.reserve_label_area(marker.get_global_rect(), marker)
	var css_point := Vector2(200, 210)
	var viewport_point := css_point * 1.85
	_check(enemy_script.label_area_reserved(viewport_point, 0.0), "a scaled HUD label is reserved where it is actually drawn")
	_check(not enemy_script.label_area_reserved(Vector2(100, 205), 0.0), "the reservation is not left at the unscaled CSS position")
	enemy_script.clear_label_areas(marker)
	layer.queue_free()
	await process_frame

func _test_result_roster() -> void:
	var result: CanvasLayer = load("res://scripts/ui/r4_result_screen.gd").new()
	root.add_child(result)
	await process_frame
	result.rows = [{"id": "orbit_guard", "name": "星環護衛"}, {"id": "echo_singer", "name": "回聲歌者"}]
	var line: String = result.summary_bond_line()
	_check(line.begins_with("羈絆收益") and line.length() <= 20, "summary bond line keeps the R10 one-line contract")
	_check(line.contains("已成立") and not line.contains(" 0"), "formed-but-idle bond no longer reads as a zero result")
	result.rows = [{"id": "ember_grenadier", "name": "燼焰擲彈兵"}, {"id": "pulse_artificer", "name": "脈衝工匠"}]
	var ember_line: String = result.summary_bond_line()
	_check(ember_line.begins_with("羈絆收益") and ember_line.length() <= 20 and ember_line.contains("燼脈聯爆已生效"), "a formed passive bond is reported as active, not untriggered")
	var ember_reason: String = result.bond_zero_reason_text()
	_check(ember_reason.contains("爆裂範圍 +8%") and ember_reason.contains("楔形時另加傷害 +8%") and not ember_reason.contains("換") and not ember_reason.contains("未觸發"), "support text states the passive effect and its resonance formation")
	_check(result.formed_bond_note("bond_guard_echo").contains("受傷時"), "星盾和聲 explains it needs incoming damage")
	var squad_source := FileAccess.get_file_as_string("res://scripts/heroes/squad_manager.gd")
	_check(squad_source.contains("var effect: String = str(BOND_BASE_EFFECT.get(id,\"\"))"), "bond reveal and result screen share one effect table")
	result.rows = [{"id": "orbit_guard", "name": "星環護衛"}, {"id": "echo_singer", "name": "回聲歌者"}]
	var names: Array = ["裂隙隊長", "脈衝工匠", "裂弧斥候", "影刃遊俠", "燼焰擲彈兵", "裂光狙擊手", "星環護衛", "回聲歌者"]
	result.support_rows = [{"id": "support_zero_group", "name": "未觸發隊員", "member_ids": ["orbit_guard", "echo_singer"], "member_names": names}]
	result.tab = 1
	result._refresh()
	await process_frame
	var card: Label = result.cards[0]
	_check(card.text.contains("回聲歌者"), "grouped card text holds the last member name")
	_check(card.text.begins_with("無回復／減傷 8 人"), "the card says what it counts: healing and prevention, not bond triggers")
	_check(not card.text.contains("未觸發"), "the card no longer calls bond members untriggered")
	for roster_line in card.text.split("\n").slice(1):
		_check(roster_line.split("、").size() <= 5, "roster lines hold at most five whole names")
	_check(card.text.split("\n").size() <= 3, "the card stays within three lines so it never shrinks or trims a name")
	result.support_rows = [{"id": "support_zero_group", "name": "未觸發隊員", "member_ids": ["rift_captain"], "member_names": names + ["線紋修補者"]}]
	result.rows = [{"id": "rift_captain", "name": "裂隙隊長"}]
	result._refresh()
	await process_frame
	_check(result.cards[0].text.split("\n").size() <= 3 and result.cards[0].text.contains("線紋修補者"), "with no bond formed, nine names still fit in three lines with the last name shown")
	_check(card.get_theme_font_size("font_size") >= 12, "the roster stays at a readable size")
	_check(not card.text.contains("成立起生效") and not card.text.contains("另加傷害"), "the untriggered-member card never claims a bond effect for those members")
	_check(card.autowrap_mode != TextServer.AUTOWRAP_OFF, "grouped roster card wraps")
	_check(card.get_line_count() >= 3, "grouped roster spans its own lines")
	_check(card.get_visible_line_count() >= card.get_line_count(), "every wrapped roster line is visible in the card")
	result.tab = 0
	result.rows = [{"id": "orbit_guard", "name": "星環護衛", "damage": 10, "taken": 0, "healing": 0, "prevented": 0}]
	result._refresh()
	await process_frame
	_check(result.cards[0].autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "single-character cards keep their R4 word wrapping")
	result.queue_free()
	await process_frame

func _none() -> Array[Rect2]:
	var empty: Array[Rect2] = []
	return empty

func _test_version() -> void:
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.72.0-content-r43", "project version is 0.72.0-content-r43")
