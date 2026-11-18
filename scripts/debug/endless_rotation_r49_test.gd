extends SceneTree

# CV_QA_PROFILE selects a save isolated from normal play. The separate natural
# run uses ordinary combat time and input. This test controls the clock.
var checks := 0
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("GameManager")
	var meta: Node = root.get_node("MetaProgress")
	if not "qa_" in meta.save_path:
		printerr("R49_ENDLESS_TEST requires an isolated CV_QA_PROFILE")
		quit(2)
		return
	var rotation: GDScript = load("res://scripts/services/endless_rotation.gd")
	for stage in ["garden", "moon"]:
		var order: Array = rotation.order(49004, stage, 27)
		check(order == rotation.order(49004, stage, 27), "a seed replays all three cycles in " + stage)
		for block in range(3):
			var cycle: Array = order.slice(block * 9, block * 9 + 9)
			for rule in rotation.POOL:
				check(cycle.count(rule) == 1, "%s cycle %d includes %s once" % [stage, block, rule])
		check(order[8] != order[9] and order[17] != order[18], "no consecutive repeat across cycles")
		if stage == "garden":
			check(order[0] == "vine_snare", "opens on the selected stage's own rule")
	check(rotation.order(49005, "garden", 9) != rotation.order(49004, "garden", 9), "seed changes later rules")
	for i in range(7):
		check(rotation.waves_left(i + 1) == 3 - i % 3 and rotation.segment_of(i + 1) == i / 3, "wave boundary %d" % (i + 1))
	var counts: Dictionary = rotation.read_counts(gm)
	check(counts.size() == rotation.POOL.size() * 2, "all nine hazard counter pairs exist")
	for key in counts:
		check(gm.get(key) != null, "counter field exists: " + key)
	var font: Font = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var words := FileAccess.get_file_as_string("res://scripts/services/endless_rotation.gd")
	for character in words:
		var cp := character.unicode_at(0)
		if cp > 127 and not font.has_char(cp):
			check(false, "missing font character: " + character)
	gm.selected_stage_id = "garden"
	gm.forced_run_seed = 49107
	gm.tactical_launch = false
	gm.run_mode = "campaign"
	var arena: Node = load("res://scenes/arena/Arena.tscn").instantiate()
	root.add_child(arena)
	for i in range(4):
		await process_frame
	check(gm.endless_order.is_empty(), "campaign runs have no rotation")
	gm.vine_snares_cast = 5
	gm.vine_snares_clean = 2
	var start_time := 200.0
	gm.elapsed_time = start_time
	var snare_script: GDScript = load("res://scripts/vfx/vine_snare.gd")
	var old_snare: Node = snare_script.spawn(arena, gm.player.global_position + Vector2(4000, 0))
	old_snare.set_process(false)
	gm.stage_victory_pending = true
	gm.continue_after_stage_victory()
	check(gm.endless_rule() == "vine_snare" and gm.get_endless_wave() == 1, "campaign continuation starts a new rotation at wave one")
	old_snare._process(1.2)
	old_snare._process(2.5)
	check(gm.vine_snares_clean == 3 and gm.endless_count_baseline.vine_snares_clean == 3, "a campaign snare resolved after continuation stays outside the endless tally")
	var second: String = gm.endless_rule(1)
	gm.elapsed_time = start_time + 89.99
	check(gm.endless_rule() == "vine_snare" and gm.get_endless_wave() == 3, "wave three retains the garden rule")
	gm.vine_snares_cast += 2
	gm.vine_snares_clean += 1
	gm.elapsed_time = start_time + 90.0
	check(gm.endless_rule() == second and gm.get_endless_wave() == 4, "wave four activates the forecast rule")
	var hud: Node = arena.get_node("HUD")
	hud._update_tactical_hint()
	check(hud.tactical_hint.visible and hud.tactical_hint.text.begins_with(rotation.top_line(second, gm.endless_rule(1), 3)), "live HUD names this rule, the next rule and waves remaining")
	gm.player_died()
	var screen: Node = arena.get_node("GameOverScreen")
	var data: Dictionary = screen.displayed_summary.get("endless_rotation", {})
	check(data.get("rules", []).size() == 2, "real defeat contains both rule rows")
	if data.get("rules", []).size() == 2:
		check(data.rules[0].cast == 2 and data.rules[0].ok == 1 and data.rules[0].waves == "1–3", "campaign counters excluded")
		check(data.rules[1].rule == second and data.rules[1].waves == "4" and data.rules[1].cast == 0, "no encounter is invented for the new wave")
		check(data.tip == rotation.TIPS.vine_snare, "tip explains the missed garden rule")
		var records: Array = screen._records()
		check(records[0].contains("荊藤纏地") and records[0].contains("1/2") and records[1].contains(rotation.rule_name(second)), "each rule and its outcome have a readable record card")
		check(screen.summary_label.text.contains(data.tip), "the result screen gives the next attempt one concrete tip")
	var saved := ConfigFile.new()
	check(saved.load(gm.campaign_save_path) == OK and saved.get_value("campaign", "endless_best", {}).get("garden", {}).get("wave", 0) >= 4, "best wave persists in the usual save")
	var empty_tally: Dictionary = rotation.tally("vine_snare", {}, {"vine_snares_clean": 1})
	check(empty_tally.ok == 0, "an old hazard resolving alone cannot count as an endless cast")
	print("R49_ENDLESS_TEST checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
