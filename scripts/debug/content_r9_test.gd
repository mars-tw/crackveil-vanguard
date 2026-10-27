extends SceneTree

var checks := 0
var failures: Array[String] = []
const VECTOR_DIR := "res://assets/ui/r9_vector/"
const ICON_FILES := ["icon_damage", "icon_cooldown", "icon_projectiles", "icon_qualitative", "icon_evolution", "icon_recruit", "icon_speed", "icon_hp", "icon_pickup", "icon_supply", "icon_elite_halo", "icon_seal_stage"]

func _initialize() -> void:
	await process_frame
	_test_vector_sources()
	_test_stage_zone()
	_test_upgrade_cards()
	await _test_upgrade_screen()
	_test_seal_stages_and_elite()
	_test_combat_feedback()
	await _test_hud()
	_test_minor_fixes()
	_test_claude_audit_fixes()
	if failures.is_empty():
		print("R9_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R9_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func gm() -> Node:
	return root.get_node("GameManager")

func _test_vector_sources() -> void:
	for name in ICON_FILES:
		var source := FileAccess.get_file_as_string(VECTOR_DIR + name + ".svg")
		_check(source.contains("<svg"), name + " is an SVG document")
		var clean := not (source.contains("<image") or source.contains("base64") or source.contains("<text") or source.contains("href=\"http") or source.contains("filter") or source.contains("<style"))
		_check(clean, name + " has no bitmap, text, external link, filter or CSS")
		_check(source.length() <= 12288, name + " stays under 12 KB")
	var manifest := FileAccess.get_file_as_string(VECTOR_DIR + "MANIFEST.json")
	_check(manifest.contains("MUSE (Meta muse-wonder)"), "manifest credits MUSE")
	_check(FileAccess.file_exists(VECTOR_DIR + "README.md"), "r9 vector readme exists")

func _test_stage_zone() -> void:
	var pressure: Node2D = load("res://scripts/services/encounter_pressure.gd").new()
	_check(pressure.ZONE_FILL_ACTIVE <= 0.08, "danger zone active fill is low opacity")
	_check(pressure.ZONE_FILL_WARNING <= 0.04, "danger zone warning fill is lower opacity")
	_check(pressure.ZONE_EDGE_WIDTH <= 2.6, "danger zone edge stays a thin glow")
	pressure.free()
	var relay: Node2D = load("res://scripts/services/formation_relay.gd").new()
	relay.anchor = Vector2.ZERO
	_check(relay.seal_ground_fill_alpha() <= 0.20, "seal ground tint is low opacity")
	_check(relay.member_zone_state(Vector2(10, 10)) == "inside", "member near seal is inside")
	_check(relay.member_zone_state(Vector2(300, 0)) == "outside", "member far from seal is outside")
	var guide: PackedVector2Array = relay.guide_line_points(Vector2(300, 0))
	_check(guide.size() == 2 and guide[1].distance_to(Vector2.ZERO) < guide[0].distance_to(Vector2.ZERO), "outside member guide points toward the seal")
	relay.free()
	var squad: Node = load("res://scripts/heroes/squad_manager.gd").new()
	_check(squad.foot_glow_radius() >= 12.0, "member foot glow is readable")
	_check(squad.FOOT_GLOW_ALPHA <= 0.25, "member foot glow stays translucent")
	squad.free()

func _test_upgrade_cards() -> void:
	var preview: GDScript = load("res://scripts/services/upgrade_preview.gd")
	var cases := [
		[{"id": "upgrade_hero_weapon", "upgrade_kind": "weapon_damage"}, "damage"],
		[{"id": "upgrade_hero_weapon", "upgrade_kind": "weapon_cooldown"}, "cooldown"],
		[{"id": "upgrade_hero_weapon", "upgrade_kind": "weapon_projectiles"}, "projectiles"],
		[{"id": "upgrade_hero_weapon", "upgrade_kind": "riftline_fork", "upgrade_category": "qualitative"}, "qualitative"],
		[{"id": "upgrade_hero_weapon", "upgrade_kind": "evo", "upgrade_category": "evolution"}, "evolution"],
		[{"id": "recruit_hero", "hero_id": "orbit_guard"}, "recruit"],
		[{"id": "move_speed"}, "speed"],
		[{"id": "max_hp"}, "hp"],
		[{"id": "pickup_radius"}, "pickup"],
	]
	var keys := {}
	for case in cases:
		var key: String = preview.icon_key(case[0])
		_check(key == case[1], "icon key for " + str(case[1]))
		keys[key] = true
		var texture: Texture2D = load(VECTOR_DIR + "icon_" + key + ".svg")
		_check(texture != null and texture.get_width() >= 32, "vector icon loads for " + key)
	_check(keys.size() >= 9, "upgrade categories use distinct icons")
	for option in [{"id": "move_speed"}, {"id": "max_hp"}, {"id": "recruit_hero", "hero_id": "orbit_guard", "description": "test"}]:
		var main: String = preview.card_main_text(option)
		_check(main.split("\n").size() <= 3, "card main text within 3 lines for " + str(option.get("id")))
	_check(not preview.card_main_text({"id": "recruit_hero", "hero_id": "orbit_guard"}).begins_with("「"), "recruit card does not open with a quote mark")
	var fixed: String = preview.fix_orphan_punctuation("第一行\n」第二行")
	_check(not fixed.split("\n")[1].begins_with("」") if fixed.split("\n").size() > 1 else fixed.contains("第一行」"), "closing punctuation never starts a line")
	var qual := {"id": "upgrade_hero_weapon", "hero_id": "orbit_guard", "weapon_id": "w", "upgrade_kind": "orbit_resonance", "upgrade_category": "qualitative", "description": "星環命中使敵人短暫易傷"}
	_check(preview.card_secondary_text(qual).contains("星環"), "qualitative detail moves to secondary text")
	_check(preview.card_main_text(qual).split("\n").size() <= 3, "qualitative main text within 3 lines")

func _test_upgrade_screen() -> void:
	var screen: CanvasLayer = load("res://scripts/ui/level_up_screen.gd").new()
	root.add_child(screen)
	await process_frame
	screen.show_options([
		{"id": "move_speed", "name": "移速強化", "description": "隊長移動更快"},
		{"id": "max_hp", "name": "生命強化", "description": "隊長生命提高"},
		{"id": "recruit_hero", "hero_id": "orbit_guard", "name": "招募：軌衛", "description": "「台詞」\n守護隊友"},
	])
	await process_frame
	_check(screen.option_buttons.size() == 3, "level up shows three cards")
	var seen := {}
	for button in screen.option_buttons:
		var icon := button.get_node_or_null("UpgradeIcon") as TextureRect
		_check(icon != null and icon.texture != null, "card has a vector icon")
		if icon != null and icon.texture != null:
			seen[icon.texture.resource_path] = true
		var desc := button.get_node_or_null("CardDescription") as Label
		_check(desc != null and desc.text.split("\n").size() <= 3, "shown card body within 3 lines")
		_check(button.get_node_or_null("CardSecondary") != null, "card has a secondary line")
	_check(seen.size() == 3, "three cards use three different icons")
	screen.hide_screen()
	screen.queue_free()
	await process_frame

func _test_seal_stages_and_elite() -> void:
	var relay: Node2D = load("res://scripts/services/formation_relay.gd").new()
	var tints := [relay.seal_stage_tint(0), relay.seal_stage_tint(1), relay.seal_stage_tint(2)]
	_check(tints[0] != tints[1] and tints[1] != tints[2] and tints[0] != tints[2], "each seal stage has its own ground tint")
	var edges := [relay.seal_stage_edge(0), relay.seal_stage_edge(1), relay.seal_stage_edge(2)]
	_check(edges[0] != edges[1] and edges[1] != edges[2], "each seal stage has its own edge glow")
	relay.free()
	var enemy: Node = load("res://scripts/enemies/enemy.gd").new()
	enemy.radius = 28.0
	_check(enemy.elite_display_scale() == 1.0 and not enemy.elite_frame_visible(), "normal enemy has no elite display boost")
	enemy.is_elite = true
	_check(enemy.elite_display_scale() > 1.0 and enemy.elite_frame_visible(), "elite enemy displays larger with a frame")
	var elite_scale: float = enemy.elite_display_scale()
	enemy.special_elite_id = "flame"
	_check(enemy.elite_display_scale() > elite_scale, "special elite displays larger than a normal elite")
	_check(enemy.radius == 28.0, "elite display scale never changes collision radius")
	enemy.free()

func _test_combat_feedback() -> void:
	var feedback: GDScript = load("res://scripts/vfx/combat_feedback.gd")
	_check(feedback.feedback_kind(false, false, false) == "hit", "normal hit kind")
	_check(feedback.feedback_kind(false, true, false) == "critical", "critical hit kind differs")
	_check(feedback.feedback_kind(true, false, false) == "kill", "kill kind differs")
	_check(feedback.feedback_kind(true, false, true) == "elite_kill", "elite kill kind differs")
	var enemy: Node = load("res://scripts/enemies/enemy.gd").new()
	enemy._trigger_hit_micro_feedback()
	_check(enemy.hit_flash_timer > 0.0 and enemy.hit_flash_strength() > 0.0, "enemy flashes on hit")
	enemy.is_dying = true
	enemy.death_dissolve_age = 0.25
	_check(enemy.death_dissolve_alpha() < 1.0 and enemy.death_dissolve_alpha() >= 0.15, "killed enemy dissolves")
	enemy.free()
	var hud_script: GDScript = load("res://scripts/ui/hud.gd")
	_check(hud_script.low_hp_warning_active(0.20), "low hp warning turns on below 30 percent")
	_check(not hud_script.low_hp_warning_active(0.50), "low hp warning stays off above 30 percent")
	_check(hud_script.notices_duplicate("楔形｜封隙 1/3\n站進封隙累積封合", "站進封隙累積封合"), "mission and notice duplicates are detected")
	_check(not hud_script.notices_duplicate("楔形｜封隙 1/3", "菁英來襲"), "different notices are not duplicates")

func _test_hud() -> void:
	var hud: CanvasLayer = load("res://scripts/ui/hud.gd").new()
	root.add_child(hud)
	await process_frame
	_check(hud.hud_panel.get_node_or_null("RiftFrameOrnament") != null, "hp panel uses the rift frame")
	_check(hud.score_panel.get_node_or_null("RiftFrameOrnament") != null, "score panel uses the rift frame")
	_check(hud.tactical_hint.get_node_or_null("RiftFrameOrnament") != null, "mission line uses the rift frame")
	_check(hud.formation_button.get_node_or_null("RiftFrameOrnament") != null, "formation button uses the rift frame")
	_check(hud.summon_button.get_node_or_null("RiftFrameOrnament") != null, "summon button uses the rift frame")
	_check(hud.active_ability_button.get_node_or_null("RiftFrameOrnament") != null, "ability button uses the rift frame")
	_check(hud.low_hp_edges.size() == 4, "low hp warning has four screen edges")
	hud.show_captain_hurt(Vector2.LEFT, 0.2)
	_check(hud.is_low_hp_warning_shown(), "captain hurt at low hp shows the border warning")
	_check(hud.captain_hurt_marker != null and hud.captain_hurt_direction == Vector2.LEFT, "captain hurt direction is recorded")
	hud.queue_free()
	await process_frame
	var tuning: GDScript = load("res://scripts/services/mobile_tuning.gd")
	tuning.set_device_hints_override_for_tests({"touch_available": true, "mouse_available": false, "primary_coarse": true})
	var relay: Node2D = load("res://scripts/services/formation_relay.gd").new()
	_check(relay.switch_hint() == "點陣形鈕", "touch platform says tap the formation button")
	tuning.set_device_hints_override_for_tests({})
	_check(relay.switch_hint().contains("按 Q"), "desktop platform keeps the Q key hint")
	relay.free()

func _test_minor_fixes() -> void:
	var relay: Node2D = load("res://scripts/services/formation_relay.gd").new()
	_check(relay.result_text({"formation": "ring", "members": 4, "hit": 4, "protected": 4, "reduced": 40, "correct": true}).contains("減傷 40"), "ring verdict reports the measured reduction")
	_check(not relay.result_text({"formation": "ring", "members": 4, "hit": 4, "protected": 4, "reduced": 40, "correct": true}).contains("x0"), "ring verdict has no placeholder multiplier")
	relay.free()
	var ornament: GDScript = load("res://scripts/ui/rift_frame_ornament.gd")
	_check(ornament.TITLE_SAFE_LEFT >= 28.0, "panel frame keeps a title safe inset")
	var pressure: Node2D = load("res://scripts/services/encounter_pressure.gd").new()
	_check(pressure.answer_label(["ring"]) == "需：圓陣", "single required formation is labelled as required")
	_check(pressure.answer_label(["wedge", "ring"]).begins_with("可用："), "alternative formations are labelled as usable")
	_check(FileAccess.get_file_as_string("res://scripts/services/encounter_pressure.gd").contains("badge_backing"), "badge caption has a backing plate")
	pressure.free()
	_check(FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd").contains("FormationButton"), "ground marker avoids the formation button area")
	# Wrong-formation cross clears as soon as the correct formation is held.
	var squad: Node = load("res://scripts/heroes/squad_manager.gd").new()
	squad.formation_id = "ring"
	var saved_squad = gm().squad_manager
	var saved_node: String = gm().active_starting_node
	gm().squad_manager = squad
	gm().active_starting_node = ""
	var relay2: Node2D = load("res://scripts/services/formation_relay.gd").new()
	relay2.pressure = load("res://scripts/services/encounter_pressure.gd").new()
	relay2.pressure.kind = "pincer"
	relay2.wrong_timer = 2.0
	_check(relay2.clear_wrong_if_correct() and relay2.wrong_timer == 0.0, "correct formation clears the backlash cross at once")
	squad.formation_id = "wedge"
	relay2.wrong_timer = 2.0
	_check(not relay2.clear_wrong_if_correct() and relay2.wrong_timer > 0.0, "wrong formation keeps the backlash cross")
	gm().squad_manager = saved_squad
	gm().active_starting_node = saved_node
	relay2.pressure.free()
	relay2.free()
	squad.free()
	var screen: CanvasLayer = load("res://scripts/ui/r4_result_screen.gd").new()
	_check(screen.bar_fraction(100.0, 100.0) == 1.0 and screen.bar_fraction(50.0, 100.0) == 0.5, "result bars scale with their values")
	screen.tab = 0
	var top_card: Dictionary = screen._card_visual({"id": "a", "damage": 100, "taken": 0}, [{"id": "a", "damage": 100, "taken": 0}, {"id": "b", "damage": 50, "taken": 0}])
	var half_card: Dictionary = screen._card_visual({"id": "b", "damage": 50, "taken": 0}, [{"id": "a", "damage": 100, "taken": 0}, {"id": "b", "damage": 50, "taken": 0}])
	_check(float(top_card.bars[0][0]) > float(half_card.bars[0][0]), "single column result bars are not all equal length")
	screen.free()


# Fixes found while Claude audited the R9 release screenshots.
func _test_claude_audit_fixes() -> void:
	var enemy: Node = load("res://scripts/enemies/enemy.gd").new()
	enemy.radius = 28.0
	enemy.is_elite = true
	enemy._ensure_visual_nodes()
	enemy.elite_halo.visible = true
	enemy._ensure_visual_nodes()
	_check(enemy.elite_halo.visible, "rebuilding enemy visuals keeps the elite halo shown")
	enemy.free()
	var hud_script: Script = load("res://scripts/ui/hud.gd")
	_check(hud_script.notices_duplicate("楔形｜封隙 1/3
錯陣反噬・進度歸零・需圓陣・按 Q 切換", "錯陣反噬：進度歸零・需圓陣・按 Q 切換"), "duplicate notice is caught when only punctuation differs")
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(hud_source.contains("mission_surface.content_margin_left = 18.0"), "mission bar text clears the frame corners")
	var preview: Script = load("res://scripts/services/upgrade_preview.gd")
	var fork: String = preview.icon_key({"id": "upgrade_hero_weapon", "upgrade_category": "qualitative", "name": "裂隙隊長：裂線分叉"})
	var magnet: String = preview.icon_key({"id": "upgrade_hero_weapon", "upgrade_category": "qualitative", "name": "裂隙隊長：磁暴回收"})
	_check(fork != magnet and fork == "projectiles" and magnet == "pickup", "two qualitative cards get icons of their own effects")
	# R8 frame corners: strokes must stay inside their nine-slice patch with a
	# 1px gutter, or stretching smears a dark band over the first character.
	var corner_re := RegEx.new()
	corner_re.compile("<rect x=\"([\\d.]+)\" y=\"([\\d.]+)\" width=\"([\\d.]+)\" height=\"[\\d.]+\" fill=\"[^\"]*\" stroke=\"#07101c\" stroke-width=\"([\\d.]+)\"")
	for frame in [["button_frame", 64.0, 16.0], ["card_frame", 96.0, 24.0], ["panel_frame", 192.0, 48.0]]:
		var svg := FileAccess.get_file_as_string("res://assets/ui/r8_vector/%s.svg" % frame[0])
		var inside := true
		var found := 0
		for m in corner_re.search_all(svg):
			found += 1
			var x := float(m.get_string(1))
			var w := float(m.get_string(3))
			var half := float(m.get_string(4)) * 0.5
			var left_side: bool = x < float(frame[1]) * 0.5
			if left_side and x + w + half > frame[2] - 1.0 + 0.001:
				inside = false
			if not left_side and x - half < frame[1] - frame[2] + 1.0 - 0.001:
				inside = false
		_check(found == 4 and inside, "%s corner strokes stay inside the nine-slice patch" % frame[0])
	var level_source := FileAccess.get_file_as_string("res://scripts/ui/level_up_screen.gd")
	_check(level_source.contains("secondary.offset_top = -50.0") and level_source.contains("description.offset_bottom = -54.0"), "upgrade card secondary text has room for two lines without overlap")
	var relay_source := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	var result_screen: Variant = load("res://scripts/ui/r4_result_screen.gd").new()
	var solo: Dictionary = result_screen._card_visual({"id": "rift_captain", "damage": 178, "taken": 110}, [{"id": "rift_captain", "damage": 178, "taken": 110}])
	_check(float(solo.bars[0][0]) > float(solo.bars[1][0]) and float(solo.bars[1][0]) > 0.0, "a single-row result page keeps damage and damage taken bars at different lengths")
	result_screen.free()
	_check(relay_source.contains("elif is_open() and member.global_position.distance_to(anchor) <= GUIDE_LINE_RANGE:"), "guide lines only appear near an open seal")
	var relay_script: Script = load("res://scripts/services/formation_relay.gd")
	_check(float(relay_script.GUIDE_LINE_RANGE) <= 400.0, "guide line range stays local to the seal")
	var readout_source := FileAccess.get_file_as_string("res://scripts/ui/combat_readout.gd")
	_check(readout_source.contains("style.content_margin_left = 16.0"), "combat readout text clears the frame corners")
