extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var catalog: GDScript = load("res://scripts/services/special_elite_catalog.gd")
	var ember: Dictionary = catalog.apply_stage_variant(catalog.make_config("shield", 40), "ember")
	_check(str(ember.get("stage_skill", "")) == "ember_ring" and str(ember.get("special_elite_name", "")) == "熔盾重衛", "the third stage elites carry the ember ring")
	var ring: GDScript = load("res://scripts/vfx/ember_ring.gd")
	_check(not ring.on_band(Vector2(20, 0)) and ring.on_band(Vector2(100, 0)) and not ring.on_band(Vector2(220, 0)), "the centre and the outside are safe, only the band burns")
	_check(ring.WARN_SECONDS >= 1.0 and ring.MAX_ACTIVE == 1, "the ring is warned for over a second and only one is active at a time")
	var node: Node2D = ring.new()
	get_root().add_child(node)
	node._process(0.5)
	_check(not node.burst_done and node.hits == 0, "nothing burns during the warning")
	node.queue_free()
	var enemy_src := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	_check(enemy_src.contains("if stage_skill == \"ember_ring\" and is_instance_valid(target) and is_inside_tree():\n\t\tEMBER_RING.spawn(get_parent(), target.global_position)"), "a forge elite rings its target on every cast")
	var spawner_src := FileAccess.get_file_as_string("res://scripts/enemies/enemy_spawner.gd")
	_check(spawner_src.contains("出招時火環包圍，往中心集合"), "the elite toast teaches the forge rule")
	var snare: GDScript = load("res://scripts/vfx/vine_snare.gd")
	var snare_src := FileAccess.get_file_as_string("res://scripts/vfx/vine_snare.gd")
	_check(snare.SEAL_CLEARANCE >= 120.0 and snare_src.contains("snare.global_position = off_seal(at)"), "a garden snare is pushed off an open seal")
	var result: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	_check(result.vine_line({"ember_rings": 3, "ember_hits": 4}) == "熔火環爆 3 次・全員躲過 0 次・被燒 4 人次", "the result reports the forge rings")
	var font: FontFile = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var missing := ""
	for s in [str(ring.LABEL), "出招時火環包圍，往中心集合", "熔火環爆 3 次・全員躲過 0 次・被燒 4 人次"]:
		for i in range(str(s).length()):
			var c: int = str(s).unicode_at(i)
			if c > 0x7f and not font.has_char(c):
				missing += char(c)
	_check(missing == "", "every new string is covered by the CJK subset font (missing: %s)" % missing)
	_check(snare_src.contains("mark_layer.z_as_relative = false") and snare_src.contains("if mark.distance_to(other) < 26.0:"), "slow marks draw on a top layer and fan out when heroes overlap")
	_check(FileAccess.get_file_as_string("res://scripts/vfx/ember_ring.gd").contains("for area in Enemy.active_label_areas() + Enemy.elite_plate_rects():"), "the ring name plate steps around rule text and elite plates")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.61.0-content-r32", "project version is 0.61.0-content-r32")
	if failures.is_empty():
		print("R31_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R31_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
