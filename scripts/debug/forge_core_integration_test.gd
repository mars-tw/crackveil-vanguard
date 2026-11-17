extends SceneTree

# R47 real-Arena gate for the gear core on 時輪工坊. Controlled, not a natural
# playthrough: the spawner and the seal director are paused so the test picks
# which elite appears and keeps seals out of the way. The cast (impact frame),
# the walk (touch input through the captain's own movement), the pick-up, the
# socket, the statuses on real enemies, the boss and the settlement all run
# through the game's own code.
var checks := 0
var failures: Array[String] = []
var gm: Node
var meta: Node
var factory: Node
var arena: Node
var CORE: GDScript
var toasts: Array[String] = []

func _initialize() -> void:
	await process_frame
	gm = root.get_node("GameManager")
	meta = root.get_node("MetaProgress")
	factory = root.get_node("EntityFactory")
	var profile := OS.get_environment("CV_QA_PROFILE")
	if profile.is_empty() or not "qa_" in str(meta.save_path):
		printerr("FORGE_CORE_INTEGRATION refused: isolated QA profile required")
		quit(2)
		return
	CORE = load("res://scripts/vfx/forge_core.gd")
	root.get_node("AudioManager").set_muted(true)
	meta.reset_progress()
	gm.selected_stage_id = "forge"
	gm.run_mode = "campaign"
	gm.pending_starting_formal = false
	gm.toast_requested.connect(func(message: String): toasts.append(message))
	arena = load("res://scenes/arena/Arena.tscn").instantiate()
	root.add_child(arena)
	for frame in range(4):
		await process_frame
	var spawner: Node = arena.get_node("EnemySpawner")
	spawner.set_process(false)
	gm.tactical_director.set_process(false)
	gm.tactical_director.relay.set_process(false)
	gm.tactical_director.relay.completed = true
	gm.auto_upgrade_enabled = true
	gm.system_pause_owners.clear()
	paused = false
	gm.game_running = true
	gm.is_game_over = false
	CORE.last_verdict_time = -99.0
	var captain: Node2D = gm.player
	_check(is_instance_valid(captain) and captain.is_alive, "the forge arena starts with a living captain")
	await _test_elite_cast(spawner, captain)
	await _test_boss(spawner, captain)
	await _test_overload(captain)
	_test_settlement()
	gm.set_touch_move_vector(Vector2.ZERO)
	gm.game_running = false
	gm.system_pause_owners.clear()
	paused = false
	arena.queue_free()
	for frame in range(3):
		await process_frame
	# Remove only this runner's isolated profile files; never real saves or others' QA.
	var directory := DirAccess.open(OS.get_user_data_dir())
	if directory != null:
		for filename in directory.get_files():
			if filename.begins_with("qa_%s_" % profile):
				DirAccess.remove_absolute(OS.get_user_data_dir().path_join(filename))
	print("FORGE_CORE_INTEGRATION status=%s checks=%d failures=%s" % ["PASS" if failures.is_empty() else "FAIL", checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _cores() -> Array:
	return root.get_tree().get_nodes_in_group("forge_cores")

func _hint() -> String:
	var hud: Node = arena.get_node("HUD")
	return str(hud.tactical_hint.text) if hud != null and is_instance_valid(hud.get("tactical_hint")) else ""

func _on_screen(world: Vector2) -> bool:
	var view: Rect2 = root.get_visible_rect()
	return view.has_point(root.get_canvas_transform() * world)

# Steers the captain with the touch stick (the same input a phone sends).
func _drive(target: Callable, done: Callable, max_frames: int) -> bool:
	for frame in range(max_frames):
		if done.call():
			gm.set_touch_move_vector(Vector2.ZERO)
			return true
		var to: Vector2 = target.call()
		gm.set_touch_move_vector(gm.player.global_position.direction_to(to))
		await physics_frame
	gm.set_touch_move_vector(Vector2.ZERO)
	return bool(done.call())

func _sturdy(config: Dictionary) -> Dictionary:
	config["max_hp"] = 99999.0
	config["speed"] = 0.0
	config["damage"] = 0.0
	return config

func _test_elite_cast(spawner: Node, captain: Node2D) -> void:
	spawner.debug_forced_special_elite_id = "shield"
	_check(spawner._spawn_special_elite(), "a forge special elite spawns")
	var elite: Node2D = null
	for enemy in root.get_tree().get_nodes_in_group("enemies"):
		if enemy.get("is_active") == true and str(enemy.get("special_elite_name")) == "輪盾重衛":
			elite = enemy
	_check(elite != null and str(elite.get("stage_skill")) == "forge_core", "the forge elite is 輪盾重衛 and carries the gear core rule")
	_check(toasts.any(func(t: String): return t.contains("輪盾重衛") and t.contains("出招時掉下齒核，隊長撿起送進基座，遠座更強")), "its entrance toast teaches the rule: %s" % str(toasts))
	if elite == null:
		return
	elite.global_position = captain.global_position + Vector2(420, 0)
	elite.set("special_timer", 99.0)
	_check(elite._start_attack(captain, 1.0, &"elite"), "the elite starts its cast")
	_check(_cores().is_empty(), "nothing drops when the cast only starts (anticipation)")
	for frame in range(240):
		if not _cores().is_empty():
			break
		await process_frame
	_check(_cores().size() == 1 and gm.forge_cores_cast == 1, "the core drops on the cast's impact frame")
	elite.set_physics_process(false)
	elite.global_position = captain.global_position + Vector2(-2400, 2400)
	if _cores().is_empty():
		return
	var core: Node2D = _cores()[0]
	_check(core.global_position.distance_to(captain.global_position) <= CORE.DROP_DISTANCE + 1.0 and (core.global_position - captain.global_position).x > 0.0, "the core drops between the captain and the elite")
	_check(_on_screen(core.global_position) and _on_screen(core.socket_global("near")) and _on_screen(core.socket_global("far")), "the core and both sockets are on screen")
	_check(core.socket_global("far").distance_to(captain.global_position) > core.socket_global("near").distance_to(captain.global_position), "the far socket is the longer walk")
	await process_frame
	_check(_hint().contains("時輪齒核・") and _hint().contains("秒內走過去撿起"), "the top bar tells the captain to pick it up: %s" % _hint())
	# Enemies and a shot near the far socket, one enemy out of reach, and the boss.
	var far_at: Vector2 = core.socket_global("far")
	var grunt: Node2D = factory.spawn_enemy("normal", _sturdy(spawner._enemy_base_config("normal")), far_at + Vector2(140, 60))
	var outsider: Node2D = factory.spawn_enemy("normal", _sturdy(spawner._enemy_base_config("normal")), far_at + Vector2(1100, 0))
	spawner._spawn_boss()
	var boss: Node2D = null
	for enemy in root.get_tree().get_nodes_in_group("enemies"):
		if enemy.get("is_active") == true and enemy.get("is_boss") == true:
			boss = enemy
	_check(grunt != null and outsider != null and boss != null and str(boss.get("boss_pattern")) == "gear_cross", "test enemies and the forge reaper are in the arena")
	if grunt == null or boss == null:
		return
	boss.set("max_hp", 999999.0)
	boss.set("hp", 999999.0)
	boss.set("speed", 0.0)
	boss.global_position = far_at + Vector2(0, 220)
	var shot_stats: Dictionary = CORE.shard_stats()
	shot_stats["projectile_speed"] = 1.0
	shot_stats["range"] = 5000.0
	var shot: Node2D = factory.spawn_enemy_projectile(far_at + Vector2(220, -160), Vector2.UP, shot_stats, null, "normal")
	_check(shot != null and shot.get("is_active") == true, "an enemy shot waits in the far socket's reach")
	# Walk onto the core with the touch stick.
	_check(await _drive(func(): return core.to_global(core.core_at), func(): return not is_instance_valid(core) or core.carried, 600), "walking onto the core picks it up")
	if not is_instance_valid(core):
		return
	_check(float(captain.get("movement_slow_strength")) >= CORE.CARRY_SLOW - 0.001, "carrying slows the captain")
	await process_frame
	_check(_hint().contains("搬運齒核・送進基座・遠座更強"), "the top bar follows the carry: %s" % _hint())
	# Hold the boss still so its volley clock only moves by the core's delay.
	boss.set_physics_process(false)
	boss.set("boss_ability_timer", 100.0)
	_check(await _drive(func(): return far_at, func(): return not is_instance_valid(core) or core.done, 900), "carrying the core to the far socket sets it")
	if not is_instance_valid(core):
		return
	_check(core.solved and core.socket_used == "far" and gm.forge_cores_set == 1 and gm.forge_cores_far == 1, "the far socket is credited")
	_check(grunt.has_status_effect("slow") and grunt.has_status_effect("vulnerable") and is_equal_approx(grunt._damage_taken_multiplier(), 1.3), "a real enemy in reach is slowed and takes 30% more damage")
	_check(not core.lagged_enemies.has(outsider), "an enemy out of reach is not lagged")
	_check(core.boss_delayed and core.lagged_enemies.has(boss) and is_equal_approx(float(boss.get("boss_ability_timer")), 103.0), "the boss in reach has its next volley pushed back 3 seconds (timer %.2f)" % float(boss.get("boss_ability_timer")))
	_check(core.shots_cleared >= 1 and (not is_instance_valid(shot) or shot.get("is_active") != true or str(shot.get("source_weapon_id")) != "forge_shard"), "the far socket clears the enemy shot in its reach (cleared %d)" % core.shots_cleared)
	_check(float(gm.temporary_squad_damage_timer) > 0.0, "the far socket rallies the squad (+15% damage window)")
	await process_frame
	_check(_hint().contains("遠座校準・敵群緩速 5 秒＋易傷・彈幕延後"), "the top bar gives the verdict: %s" % _hint())
	core.free()
	CORE.last_verdict_time = -99.0
	boss.set_meta("r47_boss", true)

func _find_boss() -> Node2D:
	for enemy in root.get_tree().get_nodes_in_group("enemies"):
		if enemy.get("is_active") == true and enemy.has_meta("r47_boss"):
			return enemy
	return null

func _test_boss(spawner: Node, captain: Node2D) -> void:
	var boss := _find_boss()
	if boss == null:
		_check(false, "the boss from the first step is still there")
		return
	boss.set_physics_process(false)
	boss.global_position = captain.global_position + Vector2(380, -60)
	var cast_before: int = gm.forge_cores_cast
	boss.set("hp", float(boss.get("max_hp")) * 0.45)
	boss._trigger_boss_phase_two()
	for frame in range(3):
		await process_frame
	_check(_cores().size() == 1 and gm.forge_cores_cast == cast_before + 1, "the forge reaper throws a core as it crosses half HP")
	for core in _cores():
		core.free()
	CORE.last_verdict_time = -99.0
	boss.set("boss_volley_index", 2)
	boss._fire_stage_boss_volley()
	_check(_cores().is_empty(), "no core on an ordinary volley")
	boss._fire_stage_boss_volley()
	_check(_cores().size() == 1 and gm.forge_cores_cast == cast_before + 2, "and another every fourth volley in phase two")

func _test_overload(captain: Node2D) -> void:
	if _cores().is_empty():
		_check(false, "a core is waiting for the overload test")
		return
	var core: Node2D = _cores()[0]
	var shards_before: int = _forge_shards()
	var hits_before: int = gm.forge_core_hits
	# The captain walks away; a member standing by the core is caught.
	captain.global_position = core.to_global(core.core_at) + Vector2(0, 400)
	var member: Node2D = null
	for hero in gm.squad_manager.get_members():
		if hero != captain and hero.is_alive:
			member = hero
			break
	for frame in range(int((CORE.LIMIT_SECONDS + 0.5) * 60.0)):
		if not is_instance_valid(core) or core.done:
			break
		if member != null:
			member.global_position = core.to_global(core.core_at) + Vector2(30, 0)
			# Only the overload may hit the member: a stray enemy shot just before
			# it would leave the member in invulnerability frames (seen 2 runs in 6).
			_clear_enemy_shots()
			if core.age >= CORE.LIMIT_SECONDS - 0.25:
				member.set("invulnerability_timer", 0.0)
		await physics_frame
	_check(is_instance_valid(core) and core.done and not core.solved and core.reason == "pick", "a core left on the ground overloads")
	_check(_forge_shards() - shards_before == CORE.SHARDS, "the overload bursts into %d gear shards (got %d)" % [CORE.SHARDS, _forge_shards() - shards_before])
	_check(member == null or gm.forge_core_hits > hits_before, "a hero beside the overload is hit")
	await process_frame
	_check(_hint().contains("齒核過載・碎片四散・下次先走過去撿起齒核"), "the top bar says what to do next time: %s" % _hint())

func _forge_shards() -> int:
	var count := 0
	for shot in factory.active_enemy_projectiles:
		if is_instance_valid(shot) and shot.get("is_active") == true and str(shot.get("source_weapon_id")) == "forge_shard":
			count += 1
	return count

func _test_settlement() -> void:
	var summary: Dictionary = gm._summary_with_echo({"elapsed_time": gm.elapsed_time, "kills": 0, "gold": 0, "level": 1, "settlement_reason": "defeat", "captain_dead": true})
	var seal: Dictionary = summary.get("seal_state", {})
	_check(int(seal.get("forge_cores", -1)) == gm.forge_cores_cast and int(seal.get("forge_cores", -1)) >= 3 and int(seal.get("forge_set", -1)) == 1 and int(seal.get("forge_far", -1)) == 1 and int(seal.get("forge_hits", -1)) == gm.forge_core_hits and int(seal.get("forge_lagged", -1)) >= 2, "the settlement carries the core counts: %s" % str(seal))
	var screen: Node = arena.get_node("GameOverScreen")
	screen.show_summary(summary)
	var texts := ""
	for label in screen.find_children("*", "Label", true, false):
		texts += str(label.text) + "\n"
	for label in screen.find_children("*", "RichTextLabel", true, false):
		texts += str(label.text) + "\n"
	var line: String = load("res://scripts/ui/r4_result_screen.gd").vine_line(seal)
	_check(line.contains("時輪齒核 %d 次・送進基座 1 次（遠座 1）" % gm.forge_cores_cast), "the result line reports the cores: %s" % line)
	_check(texts.contains("時輪齒核") or str(screen._records()).contains("時輪齒核"), "the result screen shows the core line")
	screen.root.hide()

func _clear_enemy_shots() -> void:
	var factory: Node = root.get_node("EntityFactory")
	for shot in factory.active_enemy_projectiles.duplicate():
		if is_instance_valid(shot) and shot.get("is_active") == true:
			shot.set("is_active", false)
			factory.release_projectile(shot)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FORGE_CORE_INTEGRATION_FAIL " + label)
