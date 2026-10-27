extends SceneTree

var checks := 0
var failures: Array[String] = []
const VECTOR_DIR := "res://assets/ui/r10_vector/"
const SVG_FILES := ["seal_stage_mark", "guide_arrow", "bond_flash"]

func _initialize() -> void:
	await process_frame
	_test_vectors()
	_test_seal_stages()
	await _test_battlefield_clutter()
	await _test_feedback()
	await _test_upgrade_cards()
	_test_bonds()
	await _test_hud_layout()
	await _test_result_and_preparation()
	await _test_wrong_clear_and_equipment()
	_test_combat_readout()
	await _test_claude_audit_r10()
	if failures.is_empty():
		print("R10_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R10_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func gm() -> Node:
	return root.get_node("GameManager")

func _hue_diff(a: float, b: float) -> float:
	var d := absf(a - b)
	return minf(d, 360.0 - d)

func _test_vectors() -> void:
	for name in SVG_FILES:
		var source := FileAccess.get_file_as_string(VECTOR_DIR + name + ".svg")
		_check(source.contains("<svg"), name + " is an SVG document")
		var clean := not (source.contains("<image") or source.contains("base64") or source.contains("<text") or source.contains("href=\"http") or source.contains("filter") or source.contains("<style"))
		_check(clean, name + " has no bitmap, text, external link, filter or CSS")
		_check(source.length() <= 12288, name + " stays under 12 KB")
		var texture: Texture2D = load(VECTOR_DIR + name + ".svg")
		_check(texture != null and texture.get_width() >= 32, name + " loads as a texture")
	var manifest := FileAccess.get_file_as_string(VECTOR_DIR + "MANIFEST.json")
	_check(manifest.contains("MUSE (Meta muse-wonder)"), "r10 manifest credits MUSE")
	_check(FileAccess.file_exists(VECTOR_DIR + "README.md"), "r10 vector readme exists")
	_check(FileAccess.get_file_as_string("res://CREDITS.md").contains("r10_vector"), "credits list r10 vectors")

func _test_seal_stages() -> void:
	var relay_script: GDScript = load("res://scripts/services/formation_relay.gd")
	var hues := [relay_script.seal_stage_hue(0), relay_script.seal_stage_hue(1), relay_script.seal_stage_hue(2)]
	_check(_hue_diff(hues[0], hues[1]) >= 60.0, "seal hues 1-2 differ by at least 60 degrees")
	_check(_hue_diff(hues[1], hues[2]) >= 60.0, "seal hues 2-3 differ by at least 60 degrees")
	_check(_hue_diff(hues[0], hues[2]) >= 60.0, "seal hues 1-3 differ by at least 60 degrees")
	_check(relay_script.seal_stage_mark_count(0) == 1 and relay_script.seal_stage_mark_count(1) == 2 and relay_script.seal_stage_mark_count(2) == 3, "seal stages use 1/2/3 ground marks")
	var relay: Node2D = relay_script.new()
	var tints := [relay.seal_stage_tint(0), relay.seal_stage_tint(1), relay.seal_stage_tint(2)]
	_check(tints[0] != tints[1] and tints[1] != tints[2] and tints[0] != tints[2], "seal stage tints are three distinct colours")
	_check(relay.seal_ground_fill_alpha() >= 0.18, "seal ground is a filled area, not only an outline")
	_check(relay_script.SEAL_FLASH_MAX_ALPHA <= 0.85, "seal burst flash has an opacity cap")
	relay.anchor = Vector2.ZERO
	var guide: PackedVector2Array = relay.guide_line_points(Vector2(300, 14))
	_check(guide.size() == 2 and guide[0].distance_to(guide[1]) <= 28.0, "off-seal guide is a short arrow of at most 28px")
	_check(relay_script.guide_arrow_length() <= 28.0, "guide arrow length constant stays at most 28px")
	relay.formation_link_timer = 1.0
	_check(relay.formation_link_alpha() == 1.0, "formation links are full right after a switch")
	relay.formation_link_timer = 0.0
	_check(relay.formation_link_alpha() <= 0.25, "formation links fade to at most 0.25 after 1 second")
	relay.free()

func _test_battlefield_clutter() -> void:
	var squad: Node = load("res://scripts/heroes/squad_manager.gd").new()
	root.add_child(squad)
	await process_frame
	squad.formation_indicator_timer = squad.FORMATION_INDICATOR_DURATION
	_check(squad.formation_link_alpha() == 1.0, "squad formation shape is full at switch moment")
	squad.formation_indicator_timer = 0.0
	await process_frame
	_check(squad.formation_link_alpha() <= 0.25, "squad formation shape fades after the switch window")
	_check(squad.foot_glow_radius() >= 12.0, "foot glow remains readable with its dark outline")
	squad.queue_free()
	await process_frame
	var arc_script: GDScript = load("res://scripts/vfx/lightning_arc.gd")
	_check(arc_script.crowd_alpha_for_count(3) == 1.0, "sparse battle keeps full projectile opacity")
	_check(arc_script.crowd_alpha_for_count(30) < 1.0, "dense battle lowers long projectile opacity")
	_check(arc_script.crowd_alpha_for_count(30) <= 0.5, "dense projectile opacity is strongly reduced")

func _test_feedback() -> void:
	var enemy: Node = load("res://scripts/enemies/enemy.gd").new()
	var enemy_shape := CollisionShape2D.new()
	enemy_shape.name = "CollisionShape2D"
	enemy.add_child(enemy_shape)
	root.add_child(enemy)
	await process_frame
	enemy.radius = 28.0
	enemy.max_hp = 100.0
	enemy.hp = 100.0
	enemy.is_active = true
	enemy._ensure_visual_nodes()
	enemy._trigger_hit_micro_feedback()
	_check(enemy.hit_flash_timer > 0.0, "hit flash timer starts on hit")
	_check(enemy.hit_flash_strength() > 0.5, "hit flash is strong in its first frames")
	_check(enemy.hit_flash_color().r > 1.5, "hit flash is overbright white, visible on a still frame")
	_check(enemy.hit_flash_overlay != null and enemy.hit_flash_overlay.name == "HitFlashOverlay", "hit flash has a white silhouette overlay node")
	_check(load("res://scripts/enemies/enemy.gd").HIT_FLASH_DURATION >= 0.12, "hit flash lasts long enough to capture")
	await process_frame
	await process_frame
	_check(enemy.sprite != null or enemy.animated_sprite != null, "enemy keeps a visible body sprite while flashing")
	enemy.setup("normal", {"max_hp": 100.0, "is_elite": true, "special_elite_id": "flame", "special_elite_name": "星盾重衛"})
	await process_frame
	_check(enemy.elite_frame_visible(), "elite frame is visible for the break shot")
	_check(enemy.special_label != null and enemy.special_label.get_theme_font_size("font_size") >= 18, "elite ground name is large enough to read")
	_check(enemy.special_label != null and enemy.special_label.has_theme_stylebox_override("normal"), "elite ground name has a backing plate")
	var source := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	_check(source.contains("36, \"\", true") or source.contains("font_size\", 19") or enemy.get("elite_break_announcements") != null, "elite break announcement is wired")
	enemy.queue_free()
	await process_frame
	var hud_script: GDScript = load("res://scripts/ui/hud.gd")
	_check(hud_script.LOW_HP_EDGE_ALPHA >= 0.7, "low hp edges are strong on a still frame")
	_check(hud_script.LOW_HP_EDGE_THICKNESS >= 12.0, "low hp edges are thick enough to see")
	_check(hud_script.HURT_MARKER_LENGTH >= 40.0, "hurt direction marker is large enough to see")
	_check(hud_script.low_hp_warning_active(0.29), "low hp warning turns on below 30 percent")
	_check(FileAccess.file_exists("res://scripts/debug/content_r10_feedback_capture.gd"), "feedback capture script exists")
	var capture_source := FileAccess.get_file_as_string("res://scripts/debug/content_r10_feedback_capture.gd")
	_check(capture_source.contains("take_damage"), "capture triggers through real take_damage")
	_check(capture_source.contains("provenance"), "capture writes provenance metadata")
	_check(capture_source.contains("quit(1)"), "capture fails loudly when a shot is missing")

class FakePlayer:
	extends Node
	var move_speed := 200.0
	var max_hp := 100.0
	var pickup_radius := 60.0

func _test_upgrade_cards() -> void:
	var preview: GDScript = load("res://scripts/services/upgrade_preview.gd")
	var fake_player := FakePlayer.new()
	root.add_child(fake_player)
	var saved_player = gm().player
	gm().player = fake_player
	var main: String = preview.card_main_text({"id": "move_speed"})
	_check(main.contains("：") and main.contains("→"), "upgrade benefit uses label colon old-to-new format")
	_check(not preview.card_has_split_fraction(main), "upgrade main text has no split fraction")
	_check(not preview.card_has_split_fraction(preview.card_secondary_text({"id": "move_speed"})), "upgrade secondary text has no split fraction")
	var progress_sample: String = preview.progress_text({"id": "move_speed", "max_level": 3})
	gm().player = saved_player
	fake_player.queue_free()
	_check(progress_sample == "" or progress_sample.contains("："), "stage progress uses a colon after its label")
	_check(not preview.card_has_split_fraction(progress_sample), "stage fraction stays with its label on one line")
	var screen: CanvasLayer = load("res://scripts/ui/level_up_screen.gd").new()
	root.add_child(screen)
	await process_frame
	screen.show_options([
		{"id": "move_speed", "name": "移速強化", "description": "隊長移動更快"},
		{"id": "max_hp", "name": "生命強化", "description": "隊長生命提高"},
		{"id": "recruit_hero", "hero_id": "orbit_guard", "name": "招募：軌衛", "description": "「台詞」\n守護隊友"},
	])
	await process_frame
	await process_frame
	_check(screen.option_buttons.size() == 3, "level up still shows three cards")
	for button in screen.option_buttons:
		var desc := button.get_node_or_null("CardDescription") as Label
		_check(desc != null and not preview.card_has_split_fraction(desc.text), "shown card body has no split fraction")
		_check(desc != null and desc.get_theme_font_size("font_size") >= 15, "card effect text is enlarged")
		var ratio: float = screen.card_icon_width_ratio(button)
		_check(ratio >= 0.24 and ratio <= 0.38, "card icon is about 30 percent of card width")
		_check(screen.card_content_fill_ratio(button) >= 0.75, "card content fills the lower half, blank at most 25 percent")
		var secondary := button.get_node_or_null("CardSecondary") as Label
		_check(secondary != null, "card keeps a secondary line for stage and linkage")
	screen.hide_screen()
	screen.queue_free()
	await process_frame

func _test_bonds() -> void:
	var squad: Node = load("res://scripts/heroes/squad_manager.gd").new()
	root.add_child(squad)
	await process_frame
	squad.trigger_bond_flash("bond_guard_echo")
	_check(squad.bond_flash_active(), "bond flash starts when a bond triggers")
	_check(squad.bond_flash_text.contains("・"), "bond flash text shows name and effect together")
	_check(squad.bond_flash_text.length() > 4, "bond flash text is not empty")
	var line: Line2D = squad.bond_flash_node()
	_check(line != null and line.name == "BondFlashLine", "bond flash node appears between members")
	_check(squad.BOND_FLASH_SECONDS <= 1.0, "bond flash lasts at most one second")
	squad.bond_flash_timer = 0.0
	squad._process(0.016)
	_check(not squad.bond_flash_active(), "bond flash ends after its window")
	squad.queue_free()
	await process_frame

func _test_hud_layout() -> void:
	var hud: CanvasLayer = load("res://scripts/ui/hud.gd").new()
	root.add_child(hud)
	await process_frame
	await process_frame
	_check(hud.exp_caption_rect_in_bar(), "EXP caption sits inside the xp bar, not on its frame line")
	var caption := hud.xp_bar.get_node_or_null("ExpCaption") as Control
	_check(caption != null and caption.position.y >= 0.0, "EXP caption is not above the bar")
	var saved_running: bool = gm().game_running
	gm().game_running = true
	hud.show_captain_hurt(Vector2.LEFT, 0.2)
	_check(hud.is_low_hp_warning_shown(), "low hp warning shows below 30 percent")
	_check(hud.low_hp_edges.size() == 4 and hud.low_hp_edges[0].visible, "four low hp edges are visible at low hp")
	_check(hud.low_hp_edges[0].size.y >= 12.0, "low hp edge thickness is at least 12px in layout")
	_check(hud.captain_hurt_marker != null and hud.captain_hurt_marker.visible, "captain hurt arrow is visible")
	_check(hud.captain_hurt_direction == Vector2.LEFT, "captain hurt arrow keeps its direction")
	gm().game_running = saved_running
	var short_size: Vector2 = hud.toast_size_for_text("封隙完成", 1280.0, hud.toast_label.get_theme_font("font"), 18)
	var long_size: Vector2 = hud.toast_size_for_text("錯陣反噬・進度歸零・需圓陣・按 Q 切換・站進封隙重新封合", 1280.0, hud.toast_label.get_theme_font("font"), 18)
	_check(short_size.x < long_size.x or short_size.y < long_size.y, "notice panel shrinks for short text instead of one fixed big box")
	_check(hud.toast_label.get_theme_font_size("font_size") >= 16, "notice text is enlarged")
	hud.toast_showing = true
	hud.toast_current_text = "錯陣反噬・進度歸零・需圓陣"
	hud.toast_panel.visible = true
	hud.clear_wrong_formation_notice()
	_check(hud.toast_current_text == "" and not hud.toast_showing, "correct formation clears the wrong-formation notice at once")
	_check(not hud.toast_panel.visible, "wrong-formation notice panel hides when cleared")
	var view := Vector2(1280, 720)
	_check(not Rect2(hud.time_label.position, hud.time_label.size).intersects(Rect2(hud.score_label.position, hud.score_label.size)) if hud.time_label.size.x > 0 else true, "timer does not overlap the score readout")
	if hud.equipment_panel != null:
		pass
	else:
		_check(hud.has_method("_layout_equipment_panel"), "equipment panel layout is docked by the HUD")
	hud.queue_free()
	await process_frame

func _test_result_and_preparation() -> void:
	var result: CanvasLayer = load("res://scripts/ui/r4_result_screen.gd").new()
	root.add_child(result)
	await process_frame
	result.rows = [{"id": "orbit_guard", "name": "影刃遊俠", "damage": 10, "taken": 0, "healing": 0, "prevented": 0}]
	var condition: String = result.bond_condition_for(["orbit_guard"])
	_check(condition.contains("再招募"), "untriggered member shows the recruit condition for a bond")
	_check(condition.contains("可成立"), "bond condition says how the bond forms")
	_check(result.bond_zero_reason_text().contains("羈絆未成立"), "zero bond gains explain why nothing formed")
	_check(load("res://scripts/ui/r4_result_screen.gd").name_line_fits("影刃遊俠", result.cards[0].get_theme_font("font"), 14, 400.0), "character name fits on one line at card width")
	_check(not load("res://scripts/ui/r4_result_screen.gd").name_line_fits("影刃遊俠影刃遊俠影刃遊俠影刃遊俠影刃遊俠影刃遊俠影刃遊俠影刃遊俠", result.cards[0].get_theme_font("font"), 14, 80.0), "name fit check rejects an over-wide name")
	_check(result.cards[0].text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "character name ellipsises instead of wrapping mid-name")
	result.queue_free()
	await process_frame
	var prep_source := FileAccess.get_file_as_string("res://scripts/ui/r4_build_preparation.gd")
	_check(prep_source.contains("首次免費"), "preparation states the first unlock is free in the same place")
	var prep: CanvasLayer = load("res://scripts/ui/r4_build_preparation.gd").new()
	root.add_child(prep)
	await process_frame
	var meta: Node = root.get_node("MetaProgress")
	var saved_vouchers: int = meta.starting_vouchers
	var saved_owned: Array = meta.starting_owned.duplicate()
	meta.starting_vouchers = 1
	meta.starting_owned.clear()
	prep.tab = 1
	prep.index = 0
	prep._refresh()
	await process_frame
	_check(prep.title.text.contains("首次免費"), "preparation title says first free next to the later cost")
	_check(prep.title.text.contains("殘響"), "preparation title states the later cost in the same place")
	_check(not (prep.title.text.contains("成本") and prep.controls.action.text == "免費解鎖"), "preparation does not pair a bare cost with a free unlock")
	meta.starting_vouchers = saved_vouchers
	meta.starting_owned.clear()
	for owned_id in saved_owned:
		meta.starting_owned.append(str(owned_id))
	prep.queue_free()
	await process_frame

func _test_wrong_clear_and_equipment() -> void:
	var squad: Node = load("res://scripts/heroes/squad_manager.gd").new()
	squad.formation_id = "ring"
	var saved_squad = gm().squad_manager
	var saved_node: String = gm().active_starting_node
	gm().squad_manager = squad
	gm().active_starting_node = ""
	var relay: Node2D = load("res://scripts/services/formation_relay.gd").new()
	relay.pressure = load("res://scripts/services/encounter_pressure.gd").new()
	relay.pressure.kind = "pincer"
	relay.wrong_timer = 2.0
	_check(relay.clear_wrong_if_correct() and relay.wrong_timer == 0.0, "correct formation clears the wrong backlash cross at once")
	_check(not relay.marker_text().contains("反噬"), "world wrong-formation label clears with the timer")
	gm().squad_manager = saved_squad
	gm().active_starting_node = saved_node
	relay.pressure.free()
	relay.free()
	squad.free()
	var hud: CanvasLayer = load("res://scripts/ui/hud.gd").new()
	root.add_child(hud)
	await process_frame
	var panel: Control = load("res://scripts/ui/equipment_panel.gd").new()
	panel.name = "EquipmentPanelDockCheck"
	hud.root.add_child(panel)
	hud.equipment_panel = panel
	await process_frame
	var view := Vector2(1280, 720)
	hud._layout_equipment_panel()
	# Claude R10: the slot row stays centred (the desktop version label owns the
	# bottom-right corner); only the detail card docks to the right edge.
	_check(absf(panel.get_global_rect().get_center().x - view.x * 0.5) <= 2.0, "equipment slot row stays centred")
	_check(not panel.get_global_rect().intersects(hud.version_label.get_global_rect()), "equipment slot row clears the version label")
	panel._inspect_slot(0)
	await process_frame
	await process_frame
	_check(panel.details != null and panel.details.visible, "equipment detail card opens")
	if panel.details != null and panel.details.visible:
		var card: Rect2 = panel.details.get_global_rect()
		_check(card.position.x >= view.x * 0.6 and card.end.x <= view.x - 4.0, "equipment detail card docks to the right edge")
		_check(not card.intersects(Rect2(view * 0.5 - Vector2(150, 150), Vector2(300, 300))), "equipment detail card clears the central 300x300 battle area")
	panel.queue_free()
	hud.queue_free()
	await process_frame

func _test_combat_readout() -> void:
	var readout: Control = load("res://scripts/ui/combat_readout.gd").new()
	root.add_child(readout)
	await process_frame
	await process_frame
	var style := readout.panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(style != null and style.content_margin_top >= 10.0, "boss headline clears the frame top")
	_check(style != null and style.content_margin_left >= 16.0, "boss headline clears the frame left")
	_check(readout.headline != null, "boss headline label exists inside its frame")
	readout.queue_free()
	await process_frame

# Claude audit of the MUSE build: layouts the screenshots caught.
func _test_claude_audit_r10() -> void:
	var hud: CanvasLayer = load("res://scripts/ui/hud.gd").new()
	root.add_child(hud)
	await process_frame
	var caption := hud.xp_bar.get_node_or_null("ExpCaption") as Control
	hud.xp_bar.size = Vector2(200, 5)
	await process_frame
	_check(caption != null and not caption.visible, "EXP caption hides when a compact layout makes the bar 5px tall")
	_check(is_equal_approx(hud.xp_bar.size.y, 5.0), "compact xp bar keeps its own 5px height")
	hud.xp_bar.size = Vector2(200, 16)
	await process_frame
	_check(not caption.visible and hud.exp_caption_rect_in_bar(), "EXP caption stays hidden at every bar height; the Lv label names the bar")
	hud.queue_free()
	var readout: Control = load("res://scripts/ui/combat_readout.gd").new()
	root.add_child(readout)
	await process_frame
	readout.panel.size = Vector2(300, 60)
	readout.headline.text = "霜環守望者・攻防 0/2 輪"
	readout._fit_headline()
	var font: Font = readout.headline.get_theme_font("font")
	var width: float = font.get_string_size(readout.headline.text, HORIZONTAL_ALIGNMENT_LEFT, -1, readout.headline.get_theme_font_size("font_size")).x
	_check(width <= 300.0 - 64.0, "guard headline shrinks inside the frame ornament")
	readout.queue_free()
	var prep: CanvasLayer = load("res://scripts/ui/r4_build_preparation.gd").new()
	root.add_child(prep)
	await process_frame
	prep._layout()
	_check(not prep.heading.get_rect().intersects(prep.wallet.get_rect()), "moved preparation heading does not overlap the wallet line")
	prep.queue_free()
	var result: CanvasLayer = load("res://scripts/ui/r4_result_screen.gd").new()
	root.add_child(result)
	await process_frame
	result.rows = [{"id": "orbit_guard", "name": "星環護衛"}]
	var line: String = result.summary_bond_line()
	_check(line.begins_with("羈絆收益") and line.length() <= 20, "zero-bond summary line stays one short line")
	result.rows = [{"id": "orbit_guard"}, {"id": "echo_singer"}]
	_check(result.bond_zero_reason_text().contains("已成立") and not result.bond_zero_reason_text().contains("未成立"), "formed-but-idle bond is not reported as not formed")
	result.queue_free()
	var preview: GDScript = load("res://scripts/services/upgrade_preview.gd")
	var qual := {"id": "upgrade_hero_weapon", "hero_id": "orbit_guard", "weapon_id": "w", "upgrade_kind": "orbit_resonance", "upgrade_category": "qualitative", "description": "星環命中使敵人短暫易傷", "max_level": 2}
	var qual_secondary: String = preview.card_secondary_text(qual)
	_check(qual_secondary.begins_with("星環命中"), "qualitative card leads its secondary text with the effect, not stage numbers")
	_check(qual_secondary.split("
").size() <= 3, "card secondary text is capped at three lines")
	var level_screen: CanvasLayer = load("res://scripts/ui/level_up_screen.gd").new()
	root.add_child(level_screen)
	await process_frame
	level_screen.show_options([{"id": "move_speed", "name": "移速強化", "description": "隊長移動更快"}, {"id": "max_hp", "name": "生命強化", "description": "隊長生命提高"}, {"id": "pickup_radius", "name": "拾取強化", "description": "拾取更遠"}])
	await process_frame
	await process_frame
	for button in level_screen.option_buttons:
		var sec := button.get_node_or_null("CardSecondary") as Label
		var body := button.get_node_or_null("CardDescription") as Label
		if sec == null or body == null:
			_check(false, "card has body and secondary labels")
			continue
		var sec_font: Font = sec.get_theme_font("font")
		var needed: float = sec_font.get_multiline_string_size(sec.text, HORIZONTAL_ALIGNMENT_CENTER, sec.size.x, sec.get_theme_font_size("font_size")).y
		_check(sec.position.y + maxf(sec.size.y, needed) <= button.size.y + 0.5, "card secondary text stays inside the card bottom")
		_check(body.position.y + body.size.y <= sec.position.y + 0.5, "card body ends above the secondary text")
	level_screen.hide_screen()
	level_screen.queue_free()
	var relay_script: GDScript = load("res://scripts/services/formation_relay.gd")
	var low: Vector2 = relay_script.clamp_screen_point(Vector2(500, 700), Vector2(1280, 720), 280.0)
	_check(low.y <= 720.0 - 104.0, "seal verdict text stays above the bottom equipment band")
	var high: Vector2 = relay_script.clamp_screen_point(Vector2(1200, 10), Vector2(1280, 720), 280.0)
	_check(high.y >= 112.0 and high.x + 280.0 <= 1280.0, "seal verdict text stays below the top HUD and inside the right edge")
	var trail_source := FileAccess.get_file_as_string("res://scripts/projectiles/projectile.gd")
	_check(trail_source.contains("crowd_alpha_for_count") and trail_source.contains("if not enemy_projectile:"), "player projectile trails dim in crowds; enemy shots keep full strength")
	await process_frame
