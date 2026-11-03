extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	# Stage 6 has its own rule: the captain covers the locked member.
	var catalog: GDScript = load("res://scripts/services/special_elite_catalog.gd")
	var veil: Dictionary = catalog.apply_stage_variant(catalog.make_config("shield", 40), "veil")
	_check(str(veil.get("stage_skill", "")) == "veil_lance" and str(veil.get("stage_pressure", "")) == "影槍鎖定", "the sixth stage elites carry the shadow lance")
	var lance: GDScript = load("res://scripts/vfx/veil_lance.gd")
	_check(lance.covered(Vector2.ZERO, Vector2(lance.COVER - 1.0, 0)) and not lance.covered(Vector2.ZERO, Vector2(lance.COVER + 1.0, 0)), "the captain covers a member within COVER")
	# The answer is a walk: in every formation the locked (farthest) member is out of reach.
	var squad_script: GDScript = load("res://scripts/heroes/squad_manager.gd")
	var squad: Node2D = squad_script.new()
	var reach_ok := true
	for formation in ["wedge", "ring", "scatter"]:
		squad.formation_id = formation
		var farthest := 0.0
		for slot in range(1, 6):
			farthest = maxf(farthest, squad.get_formation_local_offset(slot).length())
		if farthest <= lance.COVER:
			reach_ok = false
	squad.free()
	_check(reach_ok, "in every formation the farthest member stands beyond COVER, so the captain must move")
	_check(lance.WARN_SECONDS >= 2.4 and lance.LANCE_DAMAGE >= 25.0 and lance.MAX_ACTIVE == 1, "the lance warns long enough to walk over and hurts when it lands")
	var src := FileAccess.get_file_as_string("res://scripts/vfx/veil_lance.gd")
	_check(src.contains("member.set(\"pinned_until\", Time.get_ticks_msec() + int(WARN_SECONDS * 1000.0))") and FileAccess.get_file_as_string("res://scripts/heroes/hero.gd").contains("desired_velocity = Vector2.ZERO if pinned_until > Time.get_ticks_msec() else new_velocity"), "the locked member is pinned in place until the strike")
	_check(src.contains("if VINE_SNARE.off_seal(captain.global_position, 60.0) != captain.global_position:\n\t\treturn null"), "no lance while the captain holds an open seal")
	_check(src.contains("mark_layer.z_index = 120") and src.contains("\"鎖\"") and src.contains("(\"隊長護住%s\" % target_name) if blocked else (\"%s被影槍刺中\" % target_name)"), "the locked member is marked and the strike names who was covered or hit")
	_check(FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd").contains("if stage_skill == \"veil_lance\" and is_instance_valid(GameManager.player) and is_inside_tree():\n\t\tVEIL_LANCE.spawn(get_parent(), self, GameManager.player)"), "a veil elite locks a lance on every cast")
	_check(FileAccess.get_file_as_string("res://scripts/enemies/enemy_spawner.gd").contains("出招時影槍鎖定一名隊員，隊長走到他身邊護住"), "the elite toast teaches the veil rule")
	var result: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	_check(result.vine_line({"veil_lances": 5, "veil_blocked": 3, "veil_hits": 2}) == "影槍鎖定 5 次・隊長護住 3 次・隊員被刺 2 次", "the result reports the shadow lances")
	_check(result.victory_badges({"squad_total": 6, "squad_alive": 5, "seal_state": {"wrong": 1, "veil_lances": 5, "veil_blocked": 3}}) == "戰績：隊長護住影槍 3/5", "a blocked lance is a feat")
	# R36 severe fixes.
	var rsrc := FileAccess.get_file_as_string("res://scripts/ui/r4_result_screen.gd")
	_check(rsrc.contains("wrapped+=maxi(1,ceili(line_w/maxf(1.0,width-2.0)))") and rsrc.contains("var column_bottom:=size.y-56.0-8.0"), "the result column measures wrapped lines and keeps 8 px off the footer")
	var psrc := FileAccess.get_file_as_string("res://scripts/vfx/storm_pylons.gd")
	_check(psrc.contains("# R37: climb above answer badges and plates instead of covering them.") and psrc.contains("box.position.y -= 36.0"), "the split verdict climbs above answer badges")
	_check(FileAccess.get_file_as_string("res://scripts/vfx/frost_wall.gd").contains("\twall.z_index = 0\n"), "the frost wall draws under seal labels")
	_check(psrc.contains("Enemy.clear_label_areas(mark_layer)\n\t\tfor attempt in range(3):") and psrc.contains("if top_screen < TOP_SAFE:"), "the split verdict ignores its own last reservation and stays below the top bar")
	_check(FileAccess.get_file_as_string("res://scripts/vfx/frost_wall.gd").contains("clampf(screen.position.y, 120.0, view.y - screen.size.y - 70.0)"), "the frost plate stays on screen below the top bar")
	_check(FileAccess.get_file_as_string("res://scripts/ui/hud.gd").contains("\"veil_target_screen\": _veil_target_screen(),"), "the HUD probe exposes the locked member for the review bot")
	var font: FontFile = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var missing := ""
	for s in [lance.LABEL_FORMAT % "裂弧斥候", "鎖", "隊長護住裂弧斥候", "裂弧斥候被影槍刺中", "出招時影槍鎖定一名隊員，隊長走到他身邊護住", "影槍鎖定 5 次・隊長護住 3 次・隊員被刺 2 次", "戰績：隊長護住影槍 3/5"]:
		for i in range(str(s).length()):
			var c: int = str(s).unicode_at(i)
			if c > 0x7f and not font.has_char(c):
				missing += char(c)
	_check(missing == "", "every new string is covered by the CJK subset font (missing: %s)" % missing)
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.70.0-content-r41", "project version is 0.70.0-content-r41")
	if failures.is_empty():
		print("R37_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R37_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
