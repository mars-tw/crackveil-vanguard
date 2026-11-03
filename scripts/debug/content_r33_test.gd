extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	# The fourth stage has its own rule: split onto two pylons.
	var catalog: GDScript = load("res://scripts/services/special_elite_catalog.gd")
	var storm: Dictionary = catalog.apply_stage_variant(catalog.make_config("shield", 40), "storm")
	_check(str(storm.get("stage_skill", "")) == "storm_pylon" and str(storm.get("stage_pressure", "")) == "雷柱分流", "the fourth stage elites carry the storm pylons")
	var pylons: GDScript = load("res://scripts/vfx/storm_pylons.gd")
	var half: Vector2 = pylons.lateral_half(null)
	var off: Array[Vector2] = pylons.pylon_offsets(half)
	_check(off.size() == 2 and off[0] == -off[1] and absf(half.length() - pylons.SPREAD) < 0.01, "two pylons stand SPREAD to each side of the captain")
	_check(pylons.split_by(Vector2.ZERO, off[0], [off[1]], half) and not pylons.split_by(Vector2.ZERO, off[1], [off[0]], half), "the captain on the captain pylon and a member on the member pylon split the bolt (R35: roles)")
	_check(not pylons.split_by(Vector2.ZERO, Vector2.ZERO, [off[0], off[1]], half), "members alone on both pylons do not split it: the captain must stand on one")
	_check(not pylons.split_by(Vector2.ZERO, off[0], [off[0]], half), "captain and member on the same pylon do not split it")
	# The answer is walking onto a pylon in scatter: walking turns the squad, and
	# the scatter rear slots land on the far pylon; wedge and ring stay too tight.
	var squad_script: GDScript = load("res://scripts/heroes/squad_manager.gd")
	var squad: Node2D = squad_script.new()
	var forward: Vector2 = off[0].normalized()
	var right: Vector2 = forward.rotated(PI * 0.5)
	var members := {}
	for formation in ["scatter", "wedge", "ring"]:
		squad.formation_id = formation
		var points: Array = []
		for slot in range(1, 5):
			var local: Vector2 = squad.get_formation_local_offset(slot)
			points.append(off[0] + right * local.x - forward * local.y)
		members[formation] = points
	squad.free()
	_check(pylons.split_by(Vector2.ZERO, off[0], members["scatter"], half), "a four-member scatter squad splits the bolt once the captain steps onto a pylon")
	_check(not pylons.split_by(Vector2.ZERO, off[0], members["wedge"], half) and not pylons.split_by(Vector2.ZERO, off[0], members["ring"], half), "a four-member wedge or ring squad cannot")
	_check(pylons.WARN_SECONDS >= 2.0 and pylons.MAX_ACTIVE == 1, "the pylons are warned for two seconds, one pair at a time")
	var node: Node2D = pylons.new()
	get_root().add_child(node)
	node._process(0.5)
	_check(not node.struck and node.hits == 0, "nothing strikes during the warning")
	node.queue_free()
	var src := FileAccess.get_file_as_string("res://scripts/vfx/storm_pylons.gd")
	_check(src.contains("if VINE_SNARE.off_seal(at, PYLON_RADIUS) != at:
		return null") and src.contains("pair.global_position = at"), "pylons are cast around the captain and never near an open seal")
	_check(src.contains("mark_layer.z_index = 120") and src.contains("\"電\""), "shocked heroes wear a 電 mark on the top layer")
	var enemy_src := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	_check(enemy_src.contains("if stage_skill == \"storm_pylon\" and is_instance_valid(GameManager.player) and is_inside_tree():\n\t\tSTORM_PYLONS.spawn(get_parent(), GameManager.player.global_position, STORM_PYLONS.onscreen_half(GameManager.player))"), "a storm elite drops pylons beside the captain on every cast")
	_check(FileAccess.get_file_as_string("res://scripts/enemies/enemy_spawner.gd").contains("出招時兩側落下雷柱，隊長踩隊長柱、散兵接隊員柱"), "the elite toast teaches the storm rule")
	# Result: the storm line, the badge wording, key contributions.
	var result: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	_check(result.vine_line({"storm_pylons": 4, "storm_grounded": 1, "storm_hits": 5}) == "雷柱分流 4 次・成功分流 1 次・被電 5 人次", "the result reports the storm pylons")
	var badges: String = result.victory_badges({"squad_total": 8, "squad_alive": 7, "seal_state": {"wrong": 1, "ember_rings": 14, "ember_clean": 6, "storm_pylons": 3, "storm_grounded": 2}})
	_check(badges == "戰績：躲過熔火環 6/14・雷柱分流 2/3", "the ember badge no longer reads 全躲 for a partial count")
	var rows := [{"name": "隊長", "role": "captain", "seal": 0.0, "taken": 900.0}, {"name": "甲", "role": "member", "seal": 23.4, "taken": 50.0}, {"name": "乙", "role": "member", "seal": 2.0, "taken": 340.0}, {"name": "丙", "role": "member", "healing": 100.0, "prevented": 20.0}]
	_check(result.key_contribution_line(rows).replace(char(0xa0), " ") == "關鍵貢獻：丙 回復減傷 120・甲 封隙 23 秒・乙 承傷 340", "three members are named for support, seal time and hits taken")
	_check(result.key_contribution_line([{"name": "隊長", "role": "captain", "taken": 50.0}]) == "", "no line without member contributions")
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(relay_src.contains("row[\"seal\"] = float(row.get(\"seal\", 0.0)) + maxf(0.0, delta)"), "each settled member banks its own seal seconds")
	_check(FileAccess.get_file_as_string("res://scripts/ui/hud.gd").contains("\"hazard_mark_at\":"), "the HUD probe exposes the last hazard mark for capture")
	_check(FileAccess.get_file_as_string("res://scripts/qa/start_stage.gd").contains("q.get('cv_r19_test')==='1'?(q.get('cv_start_stage')"), "the start-stage QA hook only works with the test flag and lives in scripts/qa")
	_check(FileAccess.get_file_as_string("res://scripts/services/qa_bridge.gd").contains("if not OS.has_feature(\"web\"):
		return \"\"
	var hook := _qa(\"start_stage\")"), "phones never read a start stage")
	var font: FontFile = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var missing := ""
	for s in [str(pylons.LABEL), "站到電", "出招時兩側落下雷柱，隊長踩隊長柱、散兵接隊員柱", "雷柱分流 4 次・成功分流 1 次・被電 5 人次", badges, "關鍵貢獻：丙 回復減傷 120・甲 封隙 23 秒・乙 承傷 340"]:
		for i in range(str(s).length()):
			var c: int = str(s).unicode_at(i)
			if c > 0x7f and not font.has_char(c):
				missing += char(c)
	_check(missing == "", "every new string is covered by the CJK subset font (missing: %s)" % missing)
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.69.0-content-r40", "project version is 0.69.0-content-r40")
	if failures.is_empty():
		print("R33_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R33_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
