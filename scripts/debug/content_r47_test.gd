extends SceneTree

# R47 unit gate: the tenth stage's gear core (時輪齒核). Positions, words,
# pick-up, both sockets, overload and the guards are driven step by step on
# test doubles; the real-Arena path is in forge_core_integration_test.gd.
var checks := 0
var failures: Array[String] = []
# Loaded after the autoloads exist (a preload would compile before GameManager).
var CORE: GDScript

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
	CORE = load("res://scripts/vfx/forge_core.gd")
	_test_catalog_and_words()
	_test_positions()
	await _test_live_core()
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.79.0-content-r50", "current project version is 0.79.0-content-r50")
	if failures.is_empty():
		print("R47_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R47_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _test_catalog_and_words() -> void:
	# The tenth stage fields its own roster and rule instead of the first stage's.
	var catalog: GDScript = load("res://scripts/services/special_elite_catalog.gd")
	var forge: Dictionary = catalog.apply_stage_variant(catalog.make_config("shield", 40), "forge")
	_check(str(forge.get("stage_skill", "")) == "forge_core" and str(forge.get("stage_pressure", "")) == "時輪齒核" and str(forge.get("special_elite_name", "")) == "輪盾重衛", "tenth stage elites carry the gear core and their own names")
	var names := PackedStringArray()
	for id in ["shield", "charge", "frost", "flame", "summoner"]:
		names.append(str(catalog.apply_stage_variant(catalog.make_config(id, 40), "forge").get("special_elite_name", "")))
	_check(names == PackedStringArray(["輪盾重衛", "齒爪獵將", "汽霧守望者", "熔齒術士", "齒群召喚師"]), "all five forge elites are renamed")
	_check(str(catalog.apply_stage_variant(catalog.make_config("shield", 40), "moon").get("special_elite_name", "")) == "星盾重衛", "the first stage keeps the original roster")
	var enemy_src := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	_check(enemy_src.contains("if stage_skill == \"forge_core\" and is_instance_valid(GameManager.player) and is_inside_tree():\n\t\t_cast_forge_core()"), "a forge elite drops a core on its cast (the impact frame)")
	_check(enemy_src.contains("if boss_pattern == \"gear_cross\":\n\t\tcall_deferred(\"_cast_forge_core\", spawn_token)") and enemy_src.contains("if boss_pattern == \"gear_cross\" and boss_phase_two_triggered and boss_volley_index % FORGE_CORE_VOLLEYS == 0:"), "the forge boss throws a core at half HP and every few volleys after")
	_check(FileAccess.get_file_as_string("res://scripts/enemies/enemy_spawner.gd").contains("出招時掉下齒核，隊長撿起送進基座，遠座更強"), "the elite toast teaches the core rule")
	# Words: the action, both sockets, the boss delay and what to do next time.
	_check(CORE.status_text(7, false, false, false, "", false) == "時輪齒核・7 秒內走過去撿起" and CORE.status_text(4, true, false, false, "", false) == "搬運齒核・送進基座・遠座更強・4 秒", "the top bar names the next step and the seconds left")
	_check(CORE.verdict_text(true, "near", false) == "近座校準・敵群緩速 3 秒" and CORE.verdict_text(true, "far", false) == "遠座校準・敵群緩速 5 秒＋易傷" and CORE.verdict_text(true, "far", true) == "遠座校準・敵群緩速 5 秒＋易傷・彈幕延後", "the verdict names the socket, its lag and a delayed boss volley")
	_check(CORE.status_text(1, false, true, false, "", false, "pick") == "齒核過載・碎片四散・下次先走過去撿起齒核" and CORE.status_text(1, false, true, false, "", false, "carry") == "齒核過載・碎片四散・下次撿起後直接走向基座", "an overload says why it failed")
	_check(CORE.fail_reason(false) == "pick" and CORE.fail_reason(true) == "carry", "the fail reason follows whether the core was ever carried")
	var near: Dictionary = CORE.SOCKETS.near
	var far: Dictionary = CORE.SOCKETS.far
	_check(float(far.radius) > float(near.radius) and float(far.lag) > float(near.lag) and float(far.slow) > float(near.slow) and float(far.vulnerable) > 0.0 and float(near.vulnerable) == 0.0 and bool(far.clear_shots) and not bool(near.clear_shots) and float(far.rally) > 0.0 and float(far.volley_delay) > 0.0, "the far socket is the stronger reward in every way")
	_check(CORE.LIMIT_SECONDS >= 8.0 and CORE.CARRY_SLOW <= 0.2 and CORE.MAX_ACTIVE == 1 and CORE.MIN_GAP_SECONDS >= 10.0 and CORE.OVERLOAD_DAMAGE > 0.0 and CORE.SHARDS >= 8, "time to walk both ways, a light carry slow, one core at a time with a breather")
	_check(CORE.too_soon(20.0, 10.0) and not CORE.too_soon(23.0, 10.0) and not CORE.too_soon(5.0, 90.0), "cores keep a breather between them, and a new run is not blocked by the last one")
	var result: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	_check(result.vine_line({"forge_cores": 4, "forge_set": 3, "forge_far": 2, "forge_hits": 1}) == "時輪齒核 4 次・送進基座 3 次（遠座 2）・過載打中 1 人次" and result.vine_line({}) == "", "the result reports the cores")
	_check(result.victory_badges({"squad_total": 6, "squad_alive": 5, "seal_state": {"wrong": 1, "forge_cores": 4, "forge_set": 3}}) == "戰績：校準時輪 3/4" and result.victory_badges({"squad_total": 6, "squad_alive": 5, "seal_state": {"wrong": 1, "forge_cores": 2, "forge_set": 0}}) == "", "a set core is a feat, a core only dropped is not")
	var hud_src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(hud_src.contains("for core in get_tree().get_nodes_in_group(\"forge_cores\"):\n\t\tif core is Node2D and core.has_method(\"status_line\"):\n\t\t\treturn str(core.call(\"status_line\"))") and hud_src.contains("\"forge_screen\": _forge_screen(),"), "the top bar follows a core; the review probe sees it")
	var gm_src := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")
	_check(gm_src.contains("\tforge_cores_cast = 0\n\tforge_cores_set = 0\n\tforge_cores_far = 0\n\tforge_core_hits = 0\n\tforge_core_lagged = 0") and gm_src.contains("\"forge_cores\": forge_cores_cast, \"forge_set\": forge_cores_set, \"forge_far\": forge_cores_far, \"forge_hits\": forge_core_hits"), "core counts reset each run and reach the result")
	# 縫獵協議 reads the same slow status the lag puts on.
	_check(FileAccess.get_file_as_string("res://scripts/weapons/rail_lance_weapon.gd").contains("enemy.has_status_effect(\"slow\")") and enemy_src.contains("apply_status_effect(\"slow\", seconds, slow)") and enemy_src.contains("apply_status_effect(\"vulnerable\", seconds, vulnerable)"), "a lagged enemy counts as slowed for 縫獵協議 and takes the existing vulnerable bonus")
	var font: FontFile = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var missing := ""
	for s in [CORE.LABEL, CORE.SOCKET_TAGS.near, CORE.SOCKET_TAGS.far, CORE.status_text(7, false, false, false, "", false), CORE.status_text(4, true, false, false, "", false), CORE.verdict_text(true, "far", true), CORE.verdict_text(true, "near", false), CORE.status_text(1, false, true, false, "", false, "pick"), CORE.status_text(1, false, true, false, "", false, "carry"), "出招時掉下齒核，隊長撿起送進基座，遠座更強", "時輪齒核 4 次・送進基座 3 次（遠座 2）・過載打中 1 人次", "戰績：校準時輪 3/4", "輪盾重衛齒爪獵將汽霧守望者熔齒術士齒群召喚師"]:
		for i in range(str(s).length()):
			var c: int = str(s).unicode_at(i)
			if c > 0x7f and not font.has_char(c):
				missing += char(c)
	_check(missing == "", "every new string is covered by the CJK subset font (missing: %s)" % missing)

func _test_positions() -> void:
	# The core drops toward the elite, a short walk from the captain.
	_check(CORE.drop_at(Vector2.ZERO, Vector2(1000, 0)) == Vector2(CORE.DROP_DISTANCE, 0) and CORE.drop_at(Vector2.ZERO, Vector2(40, 0)).length() >= CORE.PICK_RADIUS * 1.5, "the core drops toward the elite, never under the captain")
	# A wide desktop band: near on the captain's side, far past the core.
	var captain := Vector2(640, 360)
	var band := Rect2(220, 200, 820, 320)
	var core: Vector2 = CORE.clamp_to(band, CORE.drop_at(captain, Vector2(1100, 360)))
	var spots: Dictionary = CORE.pick_sockets(captain, core, Vector2.RIGHT, band)
	_check(_sockets_ok(captain, core, spots, band), "desktop sockets stay in view, clear of the core, the captain and each other: %s" % str(spots))
	_check(Vector2(spots.near).x < core.x and Vector2(spots.far).x > core.x, "desktop: near on the captain's side, far past the core")
	# A narrow phone band, core pushed against its edge: still two usable sockets.
	var phone := Rect2(0, 0, 384, 101)
	var phone_captain := Vector2(192, 50)
	var phone_core: Vector2 = CORE.clamp_to(phone, CORE.drop_at(phone_captain, Vector2(900, 50)))
	var phone_spots: Dictionary = CORE.pick_sockets(phone_captain, phone_core, Vector2.RIGHT, phone)
	_check(_sockets_ok(phone_captain, phone_core, phone_spots, phone), "phone sockets stay in view, clear of the core, the captain and each other: %s" % str(phone_spots))
	# Any direction: the far socket is never the shorter walk.
	var all_ok := true
	for k in range(12):
		var dir := Vector2.RIGHT.rotated(TAU * float(k) / 12.0)
		var c: Vector2 = CORE.clamp_to(band, CORE.drop_at(captain, captain + dir * 500.0))
		if not _sockets_ok(captain, c, CORE.pick_sockets(captain, c, dir, band), band):
			all_ok = false
	_check(all_ok, "for every elite direction the sockets are usable and far is the longer walk")
	# A plate pushed away from its core points back at it.
	_check(CORE.core_link(Rect2(-130, CORE.PICK_RADIUS + 16, 260, 28), Vector2.ZERO).is_empty(), "a plate under its core draws no line")
	var link: PackedVector2Array = CORE.core_link(Rect2(300, -20, 260, 28), Vector2.ZERO)
	_check(link.size() == 2 and link[0] == Vector2(300, 0) and is_equal_approx(link[1].length(), CORE.PICK_RADIUS + 4.0), "a plate pushed aside draws a line from its nearest edge to the core's ring")
	var held: Array[Rect2] = [Rect2(20, -80, 60, 60)]
	_check(CORE.digit_spot(Vector2.ZERO, Transform2D.IDENTITY, []) == Vector2(40, -40) and CORE.digit_spot(Vector2.ZERO, Transform2D.IDENTITY, held) == Vector2(-40, -40), "the seconds dot moves to a free corner")

func _sockets_ok(captain: Vector2, core: Vector2, spots: Dictionary, band: Rect2) -> bool:
	var near: Vector2 = spots.near
	var far: Vector2 = spots.far
	var inside: bool = band.grow(0.5).has_point(near) and band.grow(0.5).has_point(far) and band.grow(0.5).has_point(core)
	var apart: bool = near.distance_to(far) >= CORE.SOCKET_RADIUS * 2.0 and near.distance_to(core) >= CORE.SOCKET_RADIUS + CORE.PICK_RADIUS and far.distance_to(core) >= CORE.SOCKET_RADIUS + CORE.PICK_RADIUS
	var off_captain: bool = near.distance_to(captain) > CORE.SOCKET_RADIUS and far.distance_to(captain) > CORE.SOCKET_RADIUS
	return inside and apart and off_captain and far.distance_to(captain) >= near.distance_to(captain)

func _make_core(at: Vector2) -> Node2D:
	var node: Node2D = CORE.new()
	node.global_position = at
	node.sockets = {"near": Vector2(-200, 0), "far": Vector2(400, 0)}
	node.add_to_group("forge_cores")
	root.add_child(node)
	return node

func _test_live_core() -> void:
	var gm: Node = root.get_node("GameManager")
	var saved := {"player": gm.player, "game_running": gm.game_running, "is_game_over": gm.is_game_over, "run_token": gm.run_token, "elapsed_time": gm.elapsed_time}
	for key in ["forge_cores_cast", "forge_cores_set", "forge_cores_far", "forge_core_hits", "forge_core_lagged"]:
		saved[key] = gm.get(key)
		gm.set(key, 0)
	var captain := TestCaptain.new()
	captain.add_to_group("heroes")
	root.add_child(captain)
	gm.player = captain
	gm.game_running = true
	gm.is_game_over = false
	var inside := TestEnemy.new()
	inside.add_to_group("enemies")
	root.add_child(inside)
	var boss := TestEnemy.new()
	boss.is_boss = true
	boss.add_to_group("enemies")
	root.add_child(boss)
	var outside := TestEnemy.new()
	outside.add_to_group("enemies")
	root.add_child(outside)
	# Far socket: walk onto the core, carry it (slowed), set it in the far socket.
	var core := _make_core(Vector2(1000, 1000))
	captain.global_position = Vector2(700, 1000)
	inside.global_position = Vector2(1400 + 300, 1000)
	boss.global_position = Vector2(1400, 1200)
	outside.global_position = Vector2(1400 + 700, 1000)
	core._process(0.5)
	_check(not core.carried and captain.slowed == 0.0, "a core is not picked up from across the field")
	captain.global_position = Vector2(1010, 1000)
	core._process(0.1)
	_check(core.carried and captain.slowed > 0.0 and captain.slowed <= CORE.CARRY_SLOW, "walking onto the core picks it up and the carry slows the captain a little")
	_check(core.core_global() == captain.global_position + CORE.CARRY_LIFT, "the carried core rides above the captain")
	captain.global_position = Vector2(870, 1000)
	core._process(0.1)
	_check(not core.done, "carrying past the near socket's edge does not set it")
	captain.global_position = Vector2(1395, 1010)
	core._process(0.1)
	_check(core.done and core.solved and core.socket_used == "far", "carrying the core into the far socket sets it")
	_check(inside.lag == [5.0, 0.65, 0.3, 3.0] and boss.lag == [5.0, 0.65, 0.3, 3.0] and outside.lag.is_empty(), "the far socket lags (slow and vulnerable) every enemy in its reach and only those")
	_check(core.boss_delayed and core.status_line() == "遠座校準・敵群緩速 5 秒＋易傷・彈幕延後", "a boss in reach is named in the verdict")
	_check(gm.forge_cores_set == 1 and gm.forge_cores_far == 1 and gm.forge_core_lagged == 2 and is_equal_approx(CORE.last_verdict_time, gm.elapsed_time), "a set core is counted, with its socket and the enemies it lagged")
	_check(is_equal_approx(core.result_seconds(), 5.0), "a set core stays while its lag lasts")
	core._process(5.1)
	await process_frame
	_check(not is_instance_valid(core), "the core leaves after its lag")
	# Near socket: the smaller, shorter lag.
	inside.lag = []
	boss.lag = []
	core = _make_core(Vector2(1000, 1000))
	inside.global_position = Vector2(800 + 200, 1000)
	captain.global_position = Vector2(1000, 1000)
	core._process(0.1)
	captain.global_position = Vector2(800, 1000)
	core._process(0.1)
	_check(core.solved and core.socket_used == "near" and inside.lag == [3.0, 0.5, 0.0, 0.0] and not core.boss_delayed, "the near socket lags nearby enemies for 3 seconds, without the vulnerable bonus")
	core.free()
	# Never picked up: the core overloads where it lies and says why.
	var shots_before: int = _live_enemy_shots()
	core = _make_core(Vector2(1000, 1000))
	captain.global_position = Vector2(1100, 1000)
	captain.hurt = 0
	core._process(CORE.LIMIT_SECONDS + 0.1)
	_check(core.done and not core.solved and core.reason == "pick" and captain.hurt == 1 and core.hits == 1 and gm.forge_core_hits == 1, "a core left on the ground overloads and hits the heroes beside it")
	# Pools only exist inside an Arena; the shard count is checked in the integration gate.
	var shard_src := FileAccess.get_file_as_string("res://scripts/vfx/forge_core.gd")
	_check(shard_src.contains("for i in range(SHARDS):") and shard_src.contains("EntityFactory.spawn_enemy_projectile(at + dir * 24.0, dir, shard_stats(), null, \"normal\")") and str(CORE.shard_stats().target_group) == "heroes" and _live_enemy_shots() >= shots_before, "the overload bursts into gear shards aimed at the squad")
	_check(core.status_line() == "齒核過載・碎片四散・下次先走過去撿起齒核", "the top bar says to pick it up next time")
	_release_enemy_shots()
	core.free()
	# Carried too long: the core overloads on the captain.
	core = _make_core(Vector2(1000, 1000))
	captain.global_position = Vector2(1000, 1000)
	core._process(0.1)
	captain.global_position = Vector2(1000, 1300)
	core._process(CORE.LIMIT_SECONDS)
	_check(core.done and not core.solved and core.reason == "carry" and core.core_at.distance_to(core.to_local(captain.global_position + CORE.CARRY_LIFT)) < 1.0, "a core carried too long overloads where the captain holds it")
	_check(core.status_line().ends_with("下次撿起後直接走向基座"), "the top bar says to head straight for a socket next time")
	_release_enemy_shots()
	core.free()
	# Guards: pause, a stopped sortie and a replaced run give nothing.
	var before: int = gm.forge_cores_set
	var hits_before: int = gm.forge_core_hits
	core = _make_core(Vector2(1000, 1000))
	paused = true
	core._process(CORE.LIMIT_SECONDS + 1.0)
	paused = false
	_check(core.age == 0.0 and not core.done, "pause does not run the core's clock")
	gm.run_token += 1
	captain.global_position = Vector2(1000, 1000)
	core._process(0.1)
	await process_frame
	_check(not is_instance_valid(core) and gm.forge_cores_set == before and gm.forge_core_hits == hits_before, "a core from a previous sortie leaves with no credit and no penalty")
	core = _make_core(Vector2(1000, 1000))
	gm.game_running = false
	core._process(CORE.LIMIT_SECONDS + 1.0)
	await process_frame
	_check(not is_instance_valid(core) and gm.forge_core_hits == hits_before, "a stopped sortie neither credits nor overloads a core")
	gm.game_running = true
	# Spawning: one at a time, a breather after a verdict, never on an open seal.
	var parent := Node2D.new()
	root.add_child(parent)
	var elite := Node2D.new()
	parent.add_child(elite)
	# The captain sits mid-screen, as the camera keeps it in play.
	captain.global_position = root.get_visible_rect().size * 0.5
	elite.global_position = captain.global_position + Vector2(500, 0)
	CORE.last_verdict_time = -99.0
	var first: Node2D = CORE.spawn(parent, elite, captain)
	_check(first != null and first.is_in_group("forge_cores") and CORE.spawn(parent, elite, captain) == null, "only one core at a time")
	if first != null:
		var drop: Vector2 = first.global_position
		_check(drop.distance_to(captain.global_position) <= CORE.DROP_DISTANCE + 0.5 and drop.x > captain.global_position.x, "the live core drops toward the elite")
		first.free()
	CORE.last_verdict_time = gm.elapsed_time
	_check(CORE.spawn(parent, elite, captain) == null, "no new core right after a verdict")
	CORE.last_verdict_time = -99.0
	var src := FileAccess.get_file_as_string("res://scripts/vfx/forge_core.gd")
	_check(src.contains("if VINE_SNARE.off_seal(captain.global_position, 60.0) != captain.global_position:\n\t\treturn null") and src.contains("mark_layer.z_index = 120") and src.contains("Enemy.reserve_label_area(xf * placed, mark_layer)") and src.contains("taken.append_array(Enemy.hud_areas())"), "no core on an open seal; marks sit on the top layer and step around plates, badges and the HUD")
	# Art pipeline: painted textures replace the vector gear when present.
	_check(src.contains("if ResourceLoader.exists(ART[key]):") and src.contains("draw_texture_rect(textures[id]") and src.contains("draw_texture_rect(textures[\"core\"]"), "hand-painted core and sockets are used when their files exist")
	# Both art paths draw on the ground and, while carried, on the top layer.
	var vector := _make_core(Vector2(1000, 1000))
	var painted := _make_core(Vector2(1200, 1000))
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	painted.textures = {"core": texture, "near": texture, "far": texture}
	var drawn := {"ground": 0, "marks": 0}
	for node in [vector, painted]:
		node.draw.connect(func(): drawn.ground += 1)
		node.mark_layer.draw.connect(func(): drawn.marks += 1)
		node.queue_redraw()
	await process_frame
	await process_frame
	vector.carried = true
	painted.carried = true
	for node in [vector, painted]:
		node.queue_redraw()
		node.mark_layer.queue_redraw()
	await process_frame
	await process_frame
	_check(is_instance_valid(vector) and is_instance_valid(painted) and drawn.ground >= 4 and drawn.marks >= 4, "vector and painted cores draw on the ground and carried on the top layer (draws %s)" % str(drawn))
	_check(src.contains("if carried:\n\t\t\t_timer_ring(mark_layer, from)\n\t\t\t_core(mark_layer, from, 1.0, age * 2.2)"), "a carried core is drawn over the captain, not under the squad")
	_check(src.contains("taken.append(xf * Rect2(Vector2(sockets[id]) - Vector2.ONE * SOCKET_RADIUS, Vector2.ONE * SOCKET_RADIUS * 2.0))"), "the core's plate steps off its own sockets")
	vector.free()
	painted.free()
	parent.free()
	for node in [captain, inside, boss, outside]:
		node.free()
	for key in saved:
		gm.set(key, saved[key])

func _live_enemy_shots() -> int:
	var factory: Node = root.get_node("EntityFactory")
	var count := 0
	for shot in factory.active_enemy_projectiles:
		if is_instance_valid(shot) and shot.get("is_active") == true:
			count += 1
	return count

func _release_enemy_shots() -> void:
	var factory: Node = root.get_node("EntityFactory")
	for shot in factory.active_enemy_projectiles.duplicate():
		if is_instance_valid(shot) and shot.get("is_active") == true:
			shot.set("is_active", false)
			factory.release_projectile(shot)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("R47_FAIL " + label)
