extends SceneTree

const CATALOG := preload("res://scripts/services/expedition_catalog.gd")
var checks := 0
var failures: Array[String] = []

class TestCaptain extends Node2D:
	var is_alive := true

func _initialize() -> void:
	await process_frame
	if OS.get_environment("CV_QA_PROFILE") != "expedition_r46":
		printerr("Run with CV_QA_PROFILE=expedition_r46 to isolate player saves.")
		quit(2)
		return
	var meta: Node = root.get_node("MetaProgress")
	var path: String = meta.save_path
	meta.reset_progress()
	var ids := {}
	var budget := 0
	for mission in CATALOG.MISSIONS:
		_check(not ids.has(mission.id), "unique mission " + str(mission.id))
		ids[mission.id] = true
		_check(not CATALOG.STAGES.get_stage(mission.stage_id).is_empty(), "known biome " + str(mission.id))
		budget += int(mission.reward)
	_check(ids.size() == 22 and budget == 110, "twenty-two finite missions total exactly 110 echo")
	# Existing saves get no retroactive commission rewards and keep their data.
	var legacy := ConfigFile.new()
	legacy.set_value("echo", "shards", 27)
	legacy.set_value("echo", "lifetime_shards", 90)
	legacy.set_value("tactical", "moon", 7)
	legacy.set_value("upgrades", "echo_focus", 2)
	legacy.set_value("future", "keep", "preserved")
	_check(legacy.save(path) == OK, "legacy fixture saved only in isolated profile")
	meta.load_progress()
	_check(meta.shards == 27 and meta.lifetime_shards == 90 and meta.get_upgrade_level("echo_focus") == 2 and meta.get_tactical_medal_count("moon") == 3, "legacy wallet upgrades and medals preserved")
	_check(meta.get_expedition_rows().all(func(row): return row.progress == 0 and row.status == "active"), "legacy medals grant no retrospective missions")
	var partial := _summary("moon", false)
	partial.seal_state = {"step":1, "completed":false, "wrong":0}
	var first: Dictionary = meta.record_expedition_run("run-a", partial, true)
	_check(first.status == "recorded" and first.reward == 0 and meta.expedition_progress.moon_field == 1, "partial formal defeat saves best progress")
	_check(meta.record_expedition_run("run-a", partial, true).status == "unchanged", "same settlement never adds progress twice")
	_check(meta.record_expedition_run("run-b", partial, true).status == "unchanged" and meta.expedition_progress.moon_field == 1, "separate weak sorties do not accumulate a single-run objective")
	partial.seal_state.step = 2
	var complete: Dictionary = meta.record_expedition_run("run-c", partial, true)
	_check(complete.completed == ["moon_field"] and complete.reward == 4 and meta.shards == 31, "completion and wallet committed together")
	_check(meta.record_expedition_run("run-c", partial, true).reward == 0 and meta.shards == 31, "reward is once-only")
	var cleared := _summary("moon", true)
	_check(meta.record_expedition_run("", cleared, true).status == "ineligible", "empty identity rejected")
	_check(meta.record_expedition_run("seeded", cleared, false).status == "ineligible", "seeded or non-formal summaries are not eligible")
	cleared.starting_mode = "endless"
	_check(meta.record_expedition_run("run-c", cleared, true).status == "ineligible", "victory followed by endless settlement cannot award campaign missions")
	cleared.starting_mode = "campaign"
	cleared.settlement_reason = "quit"
	_check(meta.record_expedition_run("quit", cleared, true).status == "ineligible", "abandoned run is not a settlement")
	cleared.settlement_reason = "victory"
	meta.debug_save_fault = "valid_prefix"
	var failed: Dictionary = meta.record_expedition_run("failed-save", cleared, true)
	_check(failed.status == "save_failed" and failed.reward == 0 and failed.completed.is_empty(), "failed transaction advertises no earned rewards")
	_check(meta.shards == 31 and not meta.expedition_claimed.get("moon_mastery", false), "failed transaction restores progress claim and wallet")
	meta.debug_save_fault = ""
	_check(meta.record_expedition_run("failed-save", cleared, true).reward == 6, "failed save remains retryable once storage works")
	meta.load_progress()
	_check(meta.shards == 37 and meta.expedition_claimed.moon_mastery and meta.record_expedition_run("failed-save", cleared, true).reward == 0, "claims and wallet survive reload without replay payout")
	var reread := ConfigFile.new()
	reread.load(path)
	_check(reread.get_value("future", "keep", "") == "preserved", "unknown save sections survive mission migration")
	meta.reset_progress()
	_check(meta.expedition_claimed.is_empty() and meta.expedition_progress.is_empty(), "reset clears all expedition state")
	var earned := 0
	for stage in CATALOG.STAGES.get_stages():
		var summary := _summary(stage.id, true)
		var result: Dictionary = meta.record_expedition_run("full-" + str(stage.id), summary, true)
		_check(result.status == "recorded" and result.completed.size() == (4 if stage.id == "forge" else 2) and result.reward == (20 if stage.id == "forge" else 10), "every biome commission genuinely attainable: " + str(stage.id))
		earned += int(result.reward)
		_check(meta.record_expedition_run("replay-" + str(stage.id), summary, true).reward == 0, "no replay farming: " + str(stage.id))
	_check(earned == 110 and meta.shards == 110 and meta.lifetime_shards == 110, "finite reward cap is enforced across all biomes")
	_check(meta.get_expedition_rows().all(func(row): return row.status == "completed" and row.progress == row.target), "journal reflects every persisted completion")
	for mission in CATALOG.MISSIONS:
		var empty := _summary(mission.stage_id, true)
		empty.seal_state = {}
		empty.squad_total = 0
		empty.squad_alive = 0
		_check(CATALOG.value_for(mission, empty) == 0, "missing evidence cannot unlock " + str(mission.id))
		var other := _summary("unknown", true)
		_check(CATALOG.value_for(mission, other) == 0, "wrong biome cannot unlock " + str(mission.id))
	var garden := _summary("garden", true)
	garden.seal_state.vine_hits = 1
	_check(CATALOG.value_for(CATALOG.MISSIONS[2], garden) == 0 and CATALOG.value_for(CATALOG.MISSIONS[3], garden) == 0, "one tangled member invalidates clean vine commissions")
	for invalid in [-1, "0", NAN, INF, 0.5, null, false]:
		garden.seal_state.vine_hits = invalid
		_check(CATALOG.value_for(CATALOG.MISSIONS[2], garden) == 0 and CATALOG.value_for(CATALOG.MISSIONS[3], garden) == 0, "invalid damage evidence fails closed: " + str(invalid))
	var warning_only := _summary("garden", true)
	warning_only.seal_state.erase("vine_clean")
	_check(CATALOG.value_for(CATALOG.MISSIONS[2], warning_only) == 0 and CATALOG.value_for(CATALOG.MISSIONS[3], warning_only) == 0, "spawned snares without completed avoidance are not dodged")
	for pair in [["ember",5,"ember_clean"],["frost",9,"frost_clean"]]:
		var pending := _summary(pair[0], true)
		pending.seal_state[pair[2]] = 0
		_check(CATALOG.value_for(CATALOG.MISSIONS[pair[1]], pending) == 0, "mastery requires completed hazards rather than casts: " + str(pair[0]))
	await _test_vine_resolution()
	# Remove only this runner's isolated profiles; never real saves or others' QA.
	var directory := DirAccess.open(OS.get_user_data_dir())
	if directory != null:
		for filename in directory.get_files():
			if filename.begins_with("qa_expedition_r46_"):
				DirAccess.remove_absolute(OS.get_user_data_dir().path_join(filename))
	print("EXPEDITION_R46 status=%s checks=%d failures=%s" % ["PASS" if failures.is_empty() else "FAIL", checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _summary(stage_id: String, clear: bool) -> Dictionary:
	return {"stage_id":stage_id, "starting_mode":"campaign", "settlement_reason":"victory" if clear else "defeat", "campaign_clear":clear, "captain_dead":not clear, "squad_total":5, "squad_alive":5, "seal_state":{"step":3,"completed":true,"wrong":0,"vine_snares":3,"vine_clean":3,"vine_hits":0,"ember_rings":3,"ember_clean":3,"ember_hits":0,"storm_grounded":3,"frost_walls":3,"frost_clean":3,"frost_hits":0,"veil_lances":3,"veil_blocked":3,"veil_hits":0,"sand_solved":3,"tide_matched":3,"bloom_cut":3,"bloom_heals":0,"forge_far":3}}

func _test_vine_resolution() -> void:
	var gm: Node = root.get_node("GameManager")
	var saved := {"player":gm.player,"game_running":gm.game_running,"is_game_over":gm.is_game_over,"run_token":gm.run_token,"vine_snares_clean":gm.vine_snares_clean}
	var captain := TestCaptain.new()
	root.add_child(captain)
	gm.player = captain
	gm.game_running = true
	gm.is_game_over = false
	gm.vine_snares_clean = 0
	var hazard: GDScript = load("res://scripts/vfx/vine_snare.gd")
	var live: Node2D = hazard.new()
	root.add_child(live)
	live._process(1.2)
	live._process(2.4)
	live._finish()
	_check(gm.vine_snares_clean == 1, "one fully resolved untouched vine counts only once")
	var hit: Node2D = hazard.new()
	root.add_child(hit)
	hit.hits = 1
	hit._process(1.2)
	hit._process(2.4)
	_check(gm.vine_snares_clean == 1, "a hit vine is never clean")
	var suspended: Node2D = hazard.new()
	root.add_child(suspended)
	paused = true
	suspended._process(9.0)
	paused = false
	_check(suspended.age == 0.0 and gm.vine_snares_clean == 1, "pause does not simulate hazard time")
	suspended.queue_free()
	var dead: Node2D = hazard.new()
	root.add_child(dead)
	captain.is_alive = false
	dead._process(1.2)
	dead._process(2.4)
	_check(gm.vine_snares_clean == 1, "no clean credit after captain death")
	captain.is_alive = true
	var stale: Node2D = hazard.new()
	root.add_child(stale)
	gm.run_token += 1
	stale._process(1.2)
	stale._process(2.4)
	_check(gm.vine_snares_clean == 1, "previous sortie hazards cannot credit the next sortie")
	var skipped: Node2D = hazard.new()
	root.add_child(skipped)
	skipped._process(9.0)
	_check(gm.vine_snares_clean == 1, "a skipped warning and active window is not a completed dodge")
	var ended: Node2D = hazard.new()
	root.add_child(ended)
	gm.game_running = false
	ended._process(1.2)
	ended._process(2.4)
	_check(gm.vine_snares_clean == 1, "a stopped sortie receives no hazard credit")
	var freed: Node2D = hazard.new()
	root.add_child(freed)
	freed.queue_free()
	await process_frame
	_check(gm.vine_snares_clean == 1, "freeing unresolved hazards creates no avoidance credit")
	for key in saved:
		gm.set(key,saved[key])
	captain.queue_free()
	await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
