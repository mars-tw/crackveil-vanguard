extends SceneTree

# R48 unit gate for 時輪工坊: the shorter clock, a hit knocking the carried core
# loose, the new counts, the forge result card with its next-run tip, and the
# two gear-core expedition missions. Driven on test doubles like R47; the
# real-Arena path is in forge_core_r48_integration_test.gd.
# Run with CV_QA_PROFILE=content_r48 (the mission checks write an isolated save).
var checks := 0
var failures: Array[String] = []
var CORE: GDScript
var RESULT: GDScript
var CATALOG: GDScript

class TestCaptain extends Node2D:
	var is_alive := true
	var slowed := 0.0
	var hurt := 0
	func apply_movement_slow(_duration: float, strength: float) -> void:
		slowed = maxf(slowed, strength)
	func take_damage(_amount: float, _from: Vector2 = Vector2.ZERO) -> bool:
		hurt += 1
		return true

class TestEnemy extends Node2D:
	var is_active := true
	var is_boss := false
	var lag: Array = []
	func apply_time_lag(seconds: float, slow: float, vulnerable: float, volley_delay: float) -> bool:
		lag = [seconds, slow, vulnerable, volley_delay]
		return true

func _initialize() -> void:
	await process_frame
	var profile := OS.get_environment("CV_QA_PROFILE")
	if profile.is_empty():
		printerr("Run with CV_QA_PROFILE=content_r48 to isolate player saves.")
		quit(2)
		return
	CORE = load("res://scripts/vfx/forge_core.gd")
	RESULT = load("res://scripts/ui/r4_result_screen.gd")
	CATALOG = load("res://scripts/services/expedition_catalog.gd")
	_test_clock()
	await _test_knock_loose()
	_test_result_card()
	_test_missions()
	_test_words()
	# Remove only this runner's isolated profile files; never real saves or others' QA.
	var directory := DirAccess.open(OS.get_user_data_dir())
	if directory != null:
		for filename in directory.get_files():
			if filename.begins_with("qa_%s_" % profile):
				DirAccess.remove_absolute(OS.get_user_data_dir().path_join(filename))
	if failures.is_empty():
		print("R48_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R48_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _slowest_hero_speed() -> float:
	var slowest := INF
	var directory := DirAccess.open("res://resources/heroes")
	for filename in directory.get_files():
		if filename.ends_with(".tres"):
			var hero: Resource = load("res://resources/heroes/" + filename)
			if hero != null and hero.get("move_speed") != null:
				slowest = minf(slowest, float(hero.get("move_speed")))
	return slowest

func _test_clock() -> void:
	# The far socket cannot simply move further out: on the desktop band it
	# already sits on the band's edge, so the clock is what was shortened.
	var captain := Vector2(640, 360)
	var band := Rect2(220, 200, 820, 320)
	var core: Vector2 = CORE.clamp_to(band, CORE.drop_at(captain, Vector2(1100, 360)))
	var spots: Dictionary = CORE.pick_sockets(captain, core, Vector2.RIGHT, band)
	_check(is_equal_approx(Vector2(spots.far).x, band.end.x) and core.distance_to(Vector2(spots.far)) < CORE.FAR_DISTANCE, "the far socket is already clamped to the on-screen band (%s), so pushing it further changes nothing" % str(spots.far))
	_check(CORE.LIMIT_SECONDS < 9.0 and CORE.LIMIT_SECONDS >= 7.0 and CORE.FAR_DISTANCE == 430.0, "R48 shortens the clock from 9 s (now %.1f) and leaves the far socket's reach alone" % CORE.LIMIT_SECONDS)
	# Still room to walk both ways twice: the slowest hero, the longest far
	# route for any elite direction, carry slow included, fits in half the clock.
	var speed := _slowest_hero_speed()
	var worst := 0.0
	for k in range(24):
		var dir := Vector2.RIGHT.rotated(TAU * float(k) / 24.0)
		var c: Vector2 = CORE.clamp_to(band, CORE.drop_at(captain, captain + dir * 500.0))
		var s: Dictionary = CORE.pick_sockets(captain, c, dir, band)
		var walk: float = maxf(0.0, captain.distance_to(c) - CORE.PICK_RADIUS) / speed + maxf(0.0, c.distance_to(Vector2(s.far)) - CORE.SOCKET_RADIUS) / (speed * (1.0 - CORE.CARRY_SLOW))
		worst = maxf(worst, walk)
	_check(speed >= 200.0 and worst * 2.0 <= CORE.LIMIT_SECONDS, "the slowest hero (%.0f) walks the longest far route in %.2f s, under half the clock" % [speed, worst])
	_check(CORE.KNOCK_DISTANCE > CORE.PICK_RADIUS and CORE.KNOCK_DISTANCE < CORE.NEAR_DISTANCE and CORE.KNOCK_SECONDS > 0.2 and CORE.KNOCK_SECONDS < 1.0, "a knock throws the core clear of the captain but within a short walk, briefly out of reach")

func _make_core(at: Vector2) -> Node2D:
	var node: Node2D = CORE.new()
	node.global_position = at
	node.sockets = {"near": Vector2(-200, 0), "far": Vector2(400, 0)}
	node.add_to_group("forge_cores")
	root.add_child(node)
	return node

func _test_knock_loose() -> void:
	var gm: Node = root.get_node("GameManager")
	var saved := {"player": gm.player, "game_running": gm.game_running, "is_game_over": gm.is_game_over, "run_token": gm.run_token, "elapsed_time": gm.elapsed_time}
	for key in ["forge_cores_cast", "forge_cores_set", "forge_cores_far", "forge_core_hits", "forge_core_lagged", "forge_core_drops", "forge_core_overloads", "forge_boss_delays"]:
		saved[key] = gm.get(key)
		gm.set(key, 0)
	var captain := TestCaptain.new()
	captain.add_to_group("heroes")
	root.add_child(captain)
	gm.player = captain
	gm.game_running = true
	gm.is_game_over = false
	var boss := TestEnemy.new()
	boss.is_boss = true
	boss.add_to_group("enemies")
	root.add_child(boss)
	boss.global_position = Vector2(1400, 1150)
	# Pick up, head for the far socket, get hit on the way.
	var core := _make_core(Vector2(1000, 1000))
	captain.global_position = Vector2(1000, 1000)
	core._process(0.1)
	_check(core.carried and core.pick_spot == Vector2.ZERO, "picking up remembers where the core lay")
	captain.global_position = Vector2(1250, 1000)
	core._process(1.0)
	var age_before: float = core.age
	gm.captain_hurt_requested.emit(Vector2.RIGHT, 0.8)
	_check(not core.carried and core.drops == 1 and gm.forge_core_drops == 1 and not core.done, "a hit while carrying knocks the core loose (counted, not a verdict)")
	_check(core.to_global(core.core_at).is_equal_approx(Vector2(1250 - CORE.KNOCK_DISTANCE, 1000)), "it flies %d back the way the captain came (landed %s)" % [int(CORE.KNOCK_DISTANCE), str(core.to_global(core.core_at))])
	_check(core.knock_left > 0.0 and core.ground_draw_at() != core.core_at and core.ground_draw_at().y < core.core_at.y, "it is drawn on its arc while in the air")
	_check(core.status_line() == "齒核脫手・走回去撿起・%d 秒" % core.seconds_left(), "the top bar says it was knocked loose and to walk back: %s" % core.status_line())
	gm.captain_hurt_requested.emit(Vector2.RIGHT, 0.6)
	_check(core.drops == 1, "a hit with nothing carried knocks nothing")
	captain.global_position = core.to_global(core.core_at)
	core._process(CORE.KNOCK_SECONDS * 0.5)
	_check(not core.carried, "it cannot be caught while it is still in the air")
	core._process(CORE.KNOCK_SECONDS)
	_check(core.carried and core.ground_draw_at() == core.core_at, "once landed, walking onto it picks it up again")
	_check(core.age > age_before + CORE.KNOCK_SECONDS, "the clock kept running while it was loose")
	captain.global_position = core.socket_global("far")
	core._process(0.1)
	_check(core.solved and core.socket_used == "far" and core.boss_delayed and gm.forge_boss_delays == 1 and gm.forge_cores_far == 1, "a re-picked core still sets, and a delayed reaper volley is counted")
	gm.captain_hurt_requested.emit(Vector2.RIGHT, 0.5)
	_check(core.drops == 1 and gm.forge_core_drops == 1, "a hit after the verdict changes nothing")
	core.free()
	# The captain hit right where the core was picked up: it flies away from the hit.
	core = _make_core(Vector2(1000, 1000))
	captain.global_position = Vector2(1000, 1000)
	core._process(0.1)
	core._on_captain_hurt(Vector2.UP, 0.5)
	_check(core.to_global(core.core_at).is_equal_approx(Vector2(1000, 1000 + CORE.KNOCK_DISTANCE)), "with no way back to throw it, it flies away from the hit")
	core.free()
	# A knocked core stays on screen.
	core = _make_core(Vector2(920, 1000))
	core.band = Rect2(900, 900, 400, 200)
	captain.global_position = Vector2(920, 1000)
	core._process(0.1)
	captain.global_position = Vector2(965, 1000)
	core._on_captain_hurt(Vector2.RIGHT, 0.5)
	_check(core.drops == 1 and core.to_global(core.core_at).is_equal_approx(Vector2(900, 1000)), "a knock toward the band's edge lands on the edge, still on screen (%s)" % str(core.to_global(core.core_at)))
	core.free()
	# Knocked loose and never picked up again: the overload says why.
	var overloads_before: int = gm.forge_core_overloads
	core = _make_core(Vector2(1000, 1000))
	captain.global_position = Vector2(1000, 1000)
	core._process(0.1)
	captain.global_position = Vector2(1200, 1000)
	core._process(0.1)
	core._on_captain_hurt(Vector2.RIGHT, 0.5)
	captain.global_position = Vector2(1200, 1400)
	core._process(CORE.LIMIT_SECONDS)
	_check(core.done and not core.solved and core.reason == "drop" and gm.forge_core_overloads == overloads_before + 1, "a loose core left on the ground overloads as a drop")
	_check(core.status_line() == "齒核過載・碎片四散・下次搬運時繞開敵群", "the top bar says to steer around the crowd next time: %s" % core.status_line())
	_check(CORE.fail_reason(false) == "pick" and CORE.fail_reason(true) == "carry" and CORE.fail_reason(false, true) == "drop" and CORE.fail_reason(true, true) == "carry", "fail reasons: never picked, carried too long, knocked loose")
	_release_enemy_shots()
	core.free()
	# A run that ended takes a loose core away without credit or overload.
	core = _make_core(Vector2(1000, 1000))
	captain.global_position = Vector2(1000, 1000)
	core._process(0.1)
	gm.run_token += 1
	core._on_captain_hurt(Vector2.RIGHT, 0.5)
	_check(core.drops == 0, "a core from a previous sortie is not knocked loose")
	core._process(0.1)
	await process_frame
	_check(not is_instance_valid(core), "and leaves with no credit")
	var src := FileAccess.get_file_as_string("res://scripts/vfx/forge_core.gd")
	_check(src.contains("GameManager.captain_hurt_requested.connect(_on_captain_hurt)"), "the core listens to the captain's own hurt signal (only landed hits)")
	var gm_src := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")
	_check(gm_src.contains("\tforge_core_drops = 0\n\tforge_core_overloads = 0\n\tforge_boss_delays = 0") and gm_src.contains("\"forge_near\": forge_cores_set - forge_cores_far, \"forge_drops\": forge_core_drops, \"forge_overloads\": forge_core_overloads, \"forge_boss_delays\": forge_boss_delays"), "the new counts reset each run and reach the result")
	for node in [captain, boss]:
		node.free()
	for key in saved:
		gm.set(key, saved[key])

func _release_enemy_shots() -> void:
	var factory: Node = root.get_node("EntityFactory")
	for shot in factory.active_enemy_projectiles.duplicate():
		if is_instance_valid(shot) and shot.get("is_active") == true:
			shot.set("is_active", false)
			factory.release_projectile(shot)

func _test_result_card() -> void:
	var seal := {"forge_cores": 6, "forge_set": 4, "forge_far": 3, "forge_near": 1, "forge_hits": 2, "forge_drops": 2, "forge_overloads": 1, "forge_boss_delays": 1}
	_check(RESULT.forge_card(seal) == "時輪齒核 6 枚・搬運脫手 2 次\n送進近座 1 次・遠座 3 次\n過載打中 2 人次・彈幕延後 1 次\n下次：搬運時繞開敵群，被打中齒核會脫手", "the forge card lists near and far sets, overload hits and delayed volleys: %s" % RESULT.forge_card(seal))
	_check(RESULT.forge_card({}) == "" and RESULT.forge_card({"forge_cores": 0}) == "", "no card on a run without cores")
	# Older summaries (R47) without the new keys: near from set - far, zeros elsewhere.
	_check(RESULT.forge_card({"forge_cores": 4, "forge_set": 3, "forge_far": 2, "forge_hits": 1}).begins_with("時輪齒核 4 枚\n送進近座 1 次・遠座 2 次\n過載打中 1 人次・彈幕延後 0 次\n"), "an R47 summary still reads correctly")
	var limit := int(CORE.LIMIT_SECONDS)
	_check(RESULT.forge_tip({"forge_overloads": 1, "forge_drops": 1}) == "下次：搬運時繞開敵群，被打中齒核會脫手", "tip: overloads after drops -> steer around the crowd")
	_check(RESULT.forge_tip({"forge_overloads": 2}) == "下次：齒核一掉下就走過去撿，%d 秒內送進基座" % limit, "tip: overloads without drops -> go pick it up, with the real clock")
	_check(RESULT.forge_tip({"forge_set": 3, "forge_far": 1}) == "下次：多送遠座，緩速更久還有易傷", "tip: near sets -> try the far socket")
	_check(RESULT.forge_tip({"forge_set": 3, "forge_far": 3, "forge_drops": 2}) == "下次：搬運時繞開敵群，被打中齒核會脫手", "tip: far but knocked loose -> steer around the crowd")
	_check(RESULT.forge_tip({"forge_set": 3, "forge_far": 3}) == "下次：首領進到遠座範圍再送，彈幕會延後", "tip: clean far runs without a delayed volley -> catch the reaper")
	_check(RESULT.forge_tip({"forge_set": 3, "forge_far": 3, "forge_boss_delays": 1}) == "下次：照樣送遠座，首領在範圍內時再送", "tip: a clean run keeps its route")
	for tip_seal in [{"forge_overloads": 1, "forge_drops": 1}, {"forge_overloads": 2}, {"forge_set": 3, "forge_far": 1}, {"forge_set": 3, "forge_far": 3}, {"forge_set": 3, "forge_far": 3, "forge_boss_delays": 1}]:
		_check(RESULT.forge_tip(tip_seal).begins_with("下次：") and RESULT.forge_tip(tip_seal).length() <= 22, "every tip is one short sentence: %s" % RESULT.forge_tip(tip_seal))
	_check(RESULT.vine_line(seal, true) == "" and RESULT.vine_line(seal) == "時輪齒核 6 次・送進基座 4 次（遠座 3）・過載打中 2 人次", "the tally line skips the cores only when the forge card is shown")
	var src := FileAccess.get_file_as_string("res://scripts/ui/r4_result_screen.gd")
	_check(src.contains("var hazards := vine_line(data.get(\"seal_state\",{}), forge != \"\")") and src.contains("if forge != \"\":result.insert(0,forge)"), "the forge card is the first record and the tally does not repeat it")

func _test_missions() -> void:
	var ids := {}
	var budget := 0
	var forge_rows := 0
	for mission in CATALOG.MISSIONS:
		ids[mission.id] = true
		budget += int(mission.reward)
		if mission.stage_id == "forge":
			forge_rows += 1
	_check(ids.size() == 22 and budget == 110 and forge_rows == 4, "the forge gains two missions: 22 in all, 110 echo")
	var field := _mission("forge_core_field")
	var mastery := _mission("forge_core_mastery")
	_check(int(field.get("reward", 0)) == 4 and int(mastery.get("reward", 0)) == 6 and str(field.get("metric", "")) == "forge_far" and int(field.get("target", 0)) == 2, "field and mastery pay like every other biome (4／6)")
	_check(_mission("forge_field").get("name") == "工坊集結" and _mission("forge_mastery").get("name") == "一起回來", "the two R46 forge missions stay as they were")
	var defeat := _summary(false, 2)
	_check(CATALOG.value_for(field, defeat) == 2 and CATALOG.value_for(mastery, defeat) == 0, "two far sets in one sortie complete the field mission, even in defeat")
	_check(CATALOG.value_for(field, _summary(false, 1)) == 1, "one far set is progress 1／2")
	_check(CATALOG.value_for(mastery, _summary(true, 3)) == 1 and CATALOG.value_for(mastery, _summary(true, 2)) == 0 and CATALOG.value_for(mastery, _summary(false, 5)) == 0, "mastery needs three far sets and a forge clear")
	var near_only := _summary(true, 0)
	near_only.seal_state.forge_set = 5
	_check(CATALOG.value_for(field, near_only) == 0 and CATALOG.value_for(mastery, near_only) == 0, "near sets do not count toward far missions")
	for invalid in [-1, "3", NAN, INF, 2.5, null, true]:
		var bad := _summary(true, 3)
		bad.seal_state.forge_far = invalid
		_check(CATALOG.value_for(field, bad) == 0 and CATALOG.value_for(mastery, bad) == 0, "invalid far evidence fails closed: %s" % str(invalid))
	var elsewhere := _summary(true, 3)
	elsewhere.stage_id = "bloom"
	_check(CATALOG.value_for(field, elsewhere) == 0 and CATALOG.value_for(mastery, elsewhere) == 0, "far sets elsewhere do not count")
	# Saves: an old save with the R46 forge missions claimed keeps them; the new ones start fresh.
	var meta: Node = root.get_node("MetaProgress")
	meta.reset_progress()
	var legacy := ConfigFile.new()
	legacy.set_value("echo", "shards", 12)
	legacy.set_value("echo", "lifetime_shards", 40)
	legacy.set_value("expedition_claimed", "forge_field", true)
	legacy.set_value("expedition_claimed", "forge_mastery", true)
	_check(legacy.save(meta.save_path) == OK and "qa_" in str(meta.save_path), "legacy fixture saved only in the isolated profile")
	meta.load_progress()
	_check(meta.expedition_claimed.get("forge_field", false) and meta.expedition_claimed.get("forge_mastery", false) and not meta.expedition_claimed.get("forge_core_field", true) and int(meta.expedition_progress.get("forge_core_mastery", -1)) == 0, "an old save keeps its forge claims and gets no free new ones")
	var first: Dictionary = meta.record_expedition_run("r48-a", _summary(false, 2), true)
	_check(first.status == "recorded" and first.completed == ["forge_core_field"] and int(first.reward) == 4 and meta.shards == 16, "two far sets pay the field mission once")
	_check(int(meta.record_expedition_run("r48-b", _summary(false, 2), true).reward) == 0, "no replay payout")
	var second: Dictionary = meta.record_expedition_run("r48-c", _summary(true, 3), true)
	_check(second.completed == ["forge_core_mastery"] and int(second.reward) == 6 and meta.shards == 22 and meta.lifetime_shards == 50, "three far sets and a forge clear pay the mastery mission")
	meta.load_progress()
	_check(meta.expedition_claimed.get("forge_core_field", false) and meta.expedition_claimed.get("forge_core_mastery", false) and meta.shards == 22, "both claims and the wallet survive a reload")
	var rows: Array = meta.get_expedition_rows().filter(func(row): return row.stage_id == "forge")
	_check(rows.size() == 4 and rows.all(func(row): return row.status == "completed"), "the journal shows four forge missions")
	meta.reset_progress()

func _mission(id: String) -> Dictionary:
	for mission in CATALOG.MISSIONS:
		if mission.id == id:
			return mission
	return {}

func _summary(clear: bool, far: int) -> Dictionary:
	return {"stage_id": "forge", "starting_mode": "campaign", "settlement_reason": "victory" if clear else "defeat", "campaign_clear": clear, "captain_dead": not clear, "squad_total": 0, "squad_alive": 0, "seal_state": {"step": 0, "completed": clear, "wrong": 0, "forge_cores": far + 1, "forge_set": far, "forge_far": far}}

func _test_words() -> void:
	var font: FontFile = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var strings: Array = [CORE.status_text(5, false, false, false, "", false, "pick", true), CORE.status_text(1, false, true, false, "", false, "drop"), RESULT.forge_card({"forge_cores": 6, "forge_set": 4, "forge_far": 3, "forge_near": 1, "forge_hits": 2, "forge_drops": 2})]
	for tip_seal in [{"forge_overloads": 1, "forge_drops": 1}, {"forge_overloads": 2}, {"forge_set": 3, "forge_far": 1}, {"forge_set": 3, "forge_far": 3}, {"forge_set": 3, "forge_far": 3, "forge_boss_delays": 1}]:
		strings.append(RESULT.forge_tip(tip_seal))
	for id in ["forge_core_field", "forge_core_mastery"]:
		var mission := _mission(id)
		strings.append_array([mission.name, mission.description, mission.lore])
	var missing := ""
	for s in strings:
		for i in range(str(s).length()):
			var c: int = str(s).unicode_at(i)
			if c > 0x7f and not font.has_char(c) and not missing.contains(char(c)):
				missing += char(c)
	_check(missing == "", "every new string is covered by the CJK subset font (missing: %s)" % missing)
	# The top bar keeps the R47 width: the drop line is no longer than the carry line.
	_check(CORE.status_text(5, false, false, false, "", false, "pick", true).length() <= CORE.status_text(5, true, false, false, "", false).length(), "the knocked-loose line fits where the carry line did")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("R48_FAIL " + label)
