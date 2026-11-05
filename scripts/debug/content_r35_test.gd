extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	# The fifth stage has its own rule: squeeze through a frost wall's opening.
	var catalog: GDScript = load("res://scripts/services/special_elite_catalog.gd")
	var frost: Dictionary = catalog.apply_stage_variant(catalog.make_config("shield", 40), "frost")
	_check(str(frost.get("stage_skill", "")) == "frost_wall" and str(frost.get("stage_pressure", "")) == "霜牆穿縫", "the fifth stage elites carry the frost wall")
	var wall: GDScript = load("res://scripts/vfx/frost_wall.gd")
	_check(wall.in_gap(0.0, 0.0) and wall.in_gap(100.0, 0.0) and not wall.in_gap(130.0, 0.0), "the opening is GAP wide around its centre")
	_check(wall.in_gap(150.0, 100.0) and not wall.in_gap(-60.0, 100.0), "the opening moves with its offset")
	# The answer is a tight ring lined up with the opening: six ring members fit
	# (96 to each side), wedge and scatter reach 148 / 236 and lose members.
	var squad_script: GDScript = load("res://scripts/heroes/squad_manager.gd")
	var squad: Node2D = squad_script.new()
	var widest := {}
	for formation in ["ring", "wedge", "scatter"]:
		squad.formation_id = formation
		var outside := 0
		for slot in range(1, 7):
			if not wall.in_gap(squad.get_formation_local_offset(slot).x, 0.0):
				outside += 1
		widest[formation] = outside
	squad.free()
	_check(widest["ring"] == 0, "a six-member ring fits through the opening")
	_check(widest["wedge"] >= 2 and widest["scatter"] >= 3, "wedge and scatter lose members to the ice")
	_check(wall.START_AHEAD > 0.0 and wall.SPEED > 0.0 and (wall.START_AHEAD / wall.SPEED) >= 2.0, "the wall gives at least two seconds to line up")
	var src := FileAccess.get_file_as_string("res://scripts/vfx/frost_wall.gd")
	_check(src.contains("if VINE_SNARE.off_seal(captain.global_position, 60.0) != captain.global_position:\n\t\treturn null"), "no frost wall while the captain holds an open seal")
	_check(src.contains("mark_layer.z_index = 120") and src.contains("\"凍\"") and src.contains("\"全員穿過霜牆\" if hits == 0 else \"霜牆凍住 %d 人\" % hits"), "frozen heroes wear a 凍 mark and the pass ends with a verdict")
	_check(FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd").contains("if stage_skill == \"frost_wall\" and is_instance_valid(GameManager.player) and is_inside_tree():\n\t\tFROST_WALL.spawn(get_parent(), GameManager.player, randf_range(-1.0, 1.0))"), "a frost elite pushes a wall on every cast")
	_check(FileAccess.get_file_as_string("res://scripts/enemies/enemy_spawner.gd").contains("出招時推來霜牆，圓陣對準缺口穿過"), "the elite toast teaches the frost rule")
	var result: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	_check(result.vine_line({"frost_walls": 5, "frost_clean": 2, "frost_hits": 7}) == "霜牆穿縫 5 次・全員穿過 2 次・被凍 7 人次", "the result reports the frost walls")
	_check(result.victory_badges({"squad_total": 6, "squad_alive": 5, "seal_state": {"wrong": 1, "frost_walls": 5, "frost_clean": 2}}) == "戰績：全員穿過霜牆 2/5", "a beaten frost wall is a feat")
	# Pylons have roles and a split names the member who caught it.
	var pylons: GDScript = load("res://scripts/vfx/storm_pylons.gd")
	var psrc := FileAccess.get_file_as_string("res://scripts/vfx/storm_pylons.gd")
	_check(pylons.CAPTAIN_PYLON == 0 and pylons.MEMBER_PYLON == 1 and psrc.contains("var tag := (\"隊長\" if index == CAPTAIN_PYLON else \"隊員\") + (\"到\" if manned_m else \"站這\")") and psrc.contains("mark_layer.draw_string(FONT, tag_box.position"), "each pylon says whose it is: 隊長站這 / 隊員站這")
	_check(psrc.contains("\"分流成功・%s接住雷柱\" % catcher"), "a split names the member who caught it")
	# A closed seal names the member who held it longest.
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(relay_src.contains("member_callout = \"%s・守住封隙\" % str(member_callout_hero.get(\"display_name\"))"), "a closed seal names its longest-held member over their head")
	_check(relay_src.contains("var box_c := Rect2(at + Vector2(230 - w_c / 2 - 10, 13), Vector2(w_c + 20, 28))") and relay_src.contains("_reserve_for_plates(box_c)"), "the seal callout hangs under the seal banner and plates step around it")
	# Key contribution numbers match the member cards (both truncate).
	_check(result.key_contribution_line([{"name": "乙", "role": "member", "healing": 289.7}]).replace(char(0xa0), " ") == "關鍵貢獻：乙 回復減傷 289", "key contributions truncate like the member cards")
	_check(FileAccess.get_file_as_string("res://scripts/ui/hud.gd").contains("\"frost_gap_screen\": _frost_gap_screen(),"), "the HUD probe exposes the frost opening for the review bot")
	var font: FontFile = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var missing := ""
	for s in [str(wall.LABEL), "凍", "全員穿過霜牆", "霜牆凍住 3 人", "出招時推來霜牆，圓陣對準缺口穿過", "霜牆穿縫 5 次・全員穿過 2 次・被凍 7 人次", "隊長站這隊員站這隊長到隊員到", "分流成功・裂弧斥候接住雷柱", "裂弧斥候・守住封隙", str(pylons.LABEL)]:
		for i in range(str(s).length()):
			var c: int = str(s).unicode_at(i)
			if c > 0x7f and not font.has_char(c):
				missing += char(c)
	_check(missing == "", "every new string is covered by the CJK subset font (missing: %s)" % missing)
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.74.0-content-r45", "project version is 0.74.0-content-r45")
	if failures.is_empty():
		print("R35_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R35_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
