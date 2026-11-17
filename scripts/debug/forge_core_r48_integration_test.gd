extends SceneTree

# R48 real-Arena gate for 時輪工坊. Controlled, not a natural playthrough (that
# is ForgeCoreNaturalRun.tscn): the spawner and the seal director are paused.
# The elite's cast, the touch-stick walk, a real hit on the captain through
# the hero's own take_damage, the knock, the re-pick, both far sets with the
# reaper in reach, an overload after a knock, the settlement, the forge result
# card, the two new expedition missions and the journal page all run through
# the game's own code. Run with CV_QA_PROFILE=forge_core_r48.
var checks := 0
var failures: Array[String] = []
var gm: Node
var meta: Node
var arena: Node
var CORE: GDScript

func _initialize() -> void:
	await process_frame
	gm = root.get_node("GameManager")
	meta = root.get_node("MetaProgress")
	var profile := OS.get_environment("CV_QA_PROFILE")
	if profile.is_empty() or not "qa_" in str(meta.save_path):
		printerr("FORGE_CORE_R48_INTEGRATION refused: isolated QA profile required")
		quit(2)
		return
	CORE = load("res://scripts/vfx/forge_core.gd")
	root.get_node("AudioManager").set_muted(true)
	meta.reset_progress()
	gm.selected_stage_id = "forge"
	gm.run_mode = "campaign"
	gm.pending_starting_formal = false
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
	var boss := await _test_knock_and_far(spawner, captain)
	if boss != null:
		await _test_second_far(boss, captain)
		await _test_overload_after_knock(boss, captain)
	await _test_settlement()
	await _test_journal()
	gm.set_touch_move_vector(Vector2.ZERO)
	gm.game_running = false
	gm.stage_victory_pending = false
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
	print("FORGE_CORE_R48_INTEGRATION status=%s checks=%d failures=%s" % ["PASS" if failures.is_empty() else "FAIL", checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _cores() -> Array:
	return root.get_tree().get_nodes_in_group("forge_cores").filter(func(core): return not bool(core.get("done")))

func _hint() -> String:
	var hud: Node = arena.get_node("HUD")
	return str(hud.tactical_hint.text) if hud != null and is_instance_valid(hud.get("tactical_hint")) else ""

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

func _test_knock_and_far(spawner: Node, captain: Node2D) -> Node2D:
	spawner.debug_forced_special_elite_id = "shield"
	_check(spawner._spawn_special_elite(), "a forge special elite spawns")
	var elite: Node2D = null
	for enemy in root.get_tree().get_nodes_in_group("enemies"):
		if enemy.get("is_active") == true and str(enemy.get("stage_skill")) == "forge_core":
			elite = enemy
	if elite == null:
		_check(false, "the forge elite carries the gear core rule")
		return null
	elite.global_position = captain.global_position + Vector2(420, 0)
	elite.set("special_timer", 99.0)
	_check(elite._start_attack(captain, 1.0, &"elite"), "the elite starts its cast")
	for frame in range(240):
		if not _cores().is_empty():
			break
		await process_frame
	_check(_cores().size() == 1, "the core drops on the cast's impact frame")
	elite.set_physics_process(false)
	elite.set_process(false)
	elite.global_position = captain.global_position + Vector2(-2400, 2400)
	if _cores().is_empty():
		return null
	var core: Node2D = _cores()[0]
	_check(core.band.has_area() and core.band.has_point(core.global_position), "the core remembers its on-screen band")
	spawner._spawn_boss()
	var boss: Node2D = null
	for enemy in root.get_tree().get_nodes_in_group("enemies"):
		if enemy.get("is_active") == true and enemy.get("is_boss") == true:
			boss = enemy
	if boss == null:
		_check(false, "the forge reaper is in the arena")
		return null
	boss.set("max_hp", 999999.0)
	boss.set("hp", 999999.0)
	boss.set("speed", 0.0)
	# Held still and silent: only the test's own hit may land on the captain.
	boss.set_physics_process(false)
	boss.set_process(false)
	boss.set("boss_ability_timer", 100.0)
	var far_at: Vector2 = core.socket_global("far")
	boss.global_position = far_at + Vector2(0, 220)
	# Only the test's own hit may land: clear the elite's shots still in flight.
	_clear_enemy_shots()
	_check(await _drive(func(): return core.to_global(core.core_at), func(): return core.carried, 600), "walking onto the core picks it up")
	# Carry partway toward the far socket, then take a real hit.
	var pick_at: Vector2 = core.to_global(core.pick_spot)
	await _drive(func(): return far_at, func(): return gm.player.global_position.distance_to(pick_at) >= 90.0 or core.done, 300)
	_check(core.carried and not core.done, "still carrying, partway to the far socket")
	captain.set("invulnerability_timer", 0.0)
	var hp_before: float = float(captain.get("current_hp"))
	var hit_at: Vector2 = captain.global_position
	_check(captain.take_damage(4.0, hit_at + Vector2(40, 0)), "a real hit lands on the captain")
	_check(float(captain.get("current_hp")) < hp_before or float(captain.get("temporary_shield_hp")) >= 0.0, "the hit went through the hero's own damage path")
	_check(not core.carried and core.drops == 1 and gm.forge_core_drops == 1 and not core.done, "the hit knocks the carried core loose")
	var landed: Vector2 = core.to_global(core.core_at)
	var expected: Vector2 = CORE.clamp_to(core.band, hit_at + hit_at.direction_to(pick_at) * CORE.KNOCK_DISTANCE)
	_check(landed.distance_to(expected) < 1.0, "it lands %d back toward the pick-up spot (landed %s, expected %s)" % [int(CORE.KNOCK_DISTANCE), str(landed), str(expected)])
	_check(not captain.take_damage(4.0, hit_at + Vector2(40, 0)) and core.drops == 1, "a hit inside the invulnerability frames neither lands nor knocks again")
	for frame in range(3):
		await process_frame
	_check(_hint().get_slice("\n", 1).begins_with("齒核脫手・走回去撿起・"), "the top bar says it was knocked loose: %s" % _hint())
	_check(not arena.get_node("HUD")._forge_screen().is_empty() and not bool(arena.get_node("HUD")._forge_screen().carried), "the review probe sees the loose core on the ground")
	# Walk back for it; then on to the far socket with the reaper in reach.
	_check(await _drive(func(): return core.to_global(core.core_at), func(): return core.carried, 600), "walking back onto it picks it up again")
	_check(await _drive(func(): return far_at if core.carried else core.to_global(core.core_at), func(): return core.done, 900), "and it still reaches the far socket in time")
	_check(core.solved and core.socket_used == "far" and core.boss_delayed and gm.forge_boss_delays == 1 and gm.forge_cores_far == 1, "the far set pushes the reaper's volley back and is counted")
	print("FORGE_CORE_R48_FIRST solved=%s drops=%d age=%.2f" % [str(core.solved), core.drops, core.age])
	_check(core.age < CORE.LIMIT_SECONDS, "delivered with %.1f s of the %.0f left" % [CORE.LIMIT_SECONDS - core.age, CORE.LIMIT_SECONDS])
	core.free()
	CORE.last_verdict_time = -99.0
	return boss

func _test_second_far(boss: Node2D, captain: Node2D) -> void:
	boss.global_position = captain.global_position + Vector2(380, -60)
	boss.set("boss_ability_timer", 100.0)
	_check(boss._cast_forge_core(), "the reaper throws another core")
	if _cores().is_empty():
		return
	var core: Node2D = _cores()[0]
	var far_at: Vector2 = core.socket_global("far")
	boss.global_position = far_at + Vector2(0, 200)
	_clear_enemy_shots()
	_check(await _drive(func(): return core.to_global(core.core_at), func(): return core.carried, 600), "picked up")
	_check(await _drive(func(): return far_at if core.carried else core.to_global(core.core_at), func(): return core.done, 900) and core.solved and core.socket_used == "far", "a clean second far set")
	_check(gm.forge_cores_far == 2 and gm.forge_boss_delays == 2, "two far sets, two delayed volleys")
	core.free()
	CORE.last_verdict_time = -99.0

func _test_overload_after_knock(boss: Node2D, captain: Node2D) -> void:
	boss.global_position = captain.global_position + Vector2(380, -60)
	_check(boss._cast_forge_core(), "a third core")
	if _cores().is_empty():
		return
	var core: Node2D = _cores()[0]
	var overloads_before: int = gm.forge_core_overloads
	_clear_enemy_shots()
	_check(await _drive(func(): return core.to_global(core.core_at), func(): return core.carried, 600), "picked up")
	var pick_at: Vector2 = core.to_global(core.pick_spot)
	await _drive(func(): return core.socket_global("far"), func(): return gm.player.global_position.distance_to(pick_at) >= 70.0 or core.done, 300)
	captain.set("invulnerability_timer", 0.0)
	captain.take_damage(4.0, captain.global_position + Vector2(0, -40))
	_check(core.drops == 1 and not core.carried, "knocked loose again")
	# Walk away from it and leave it.
	var away: Vector2 = captain.global_position + core.to_global(core.core_at).direction_to(captain.global_position) * 600.0
	await _drive(func(): return away, func(): return core.done, int((CORE.LIMIT_SECONDS + 0.5) * 60.0))
	_check(core.done and not core.solved and core.reason == "drop" and gm.forge_core_overloads == overloads_before + 1, "a loose core left on the ground overloads, as a drop")
	for frame in range(3):
		await process_frame
	_check(_hint().get_slice("\n", 1) == "齒核過載・碎片四散・下次搬運時繞開敵群", "the top bar says to steer around the crowd: %s" % _hint())
	for frame in range(int((CORE.RESULT_SECONDS + 0.3) * 60.0)):
		await process_frame

func _test_settlement() -> void:
	gm.active_starting_formal = true
	gm.expedition_seeded = false
	gm.tactical_launch = false
	gm.starting_run_id = "forge-r48-integration"
	gm.stage_victory_pending = false
	var summary: Dictionary = gm._summary_with_echo({"elapsed_time": gm.elapsed_time, "kills": 0, "gold": 0, "level": 1, "settlement_reason": "defeat", "captain_dead": true})
	var seal: Dictionary = summary.get("seal_state", {})
	_check(int(seal.get("forge_far", -1)) == 2 and int(seal.get("forge_near", -1)) == 0 and int(seal.get("forge_drops", -1)) == 2 and int(seal.get("forge_overloads", -1)) == 1 and int(seal.get("forge_boss_delays", -1)) == 2, "the settlement carries the R48 counts: %s" % str(seal))
	var expedition: Dictionary = summary.get("expedition_result", {})
	_check(expedition.get("status") == "recorded" and Array(expedition.get("completed", [])).has("forge_core_field") and not Array(expedition.get("completed", [])).has("forge_core_mastery"), "a formal sortie with two far sets completes 遠座校準: %s" % str(expedition))
	_check(_row("forge_core_field").status == "completed" and _row("forge_core_mastery").status == "active", "the journal records the field mission only")
	var screen: Node = arena.get_node("GameOverScreen")
	screen.show_summary(summary)
	var records: Array = screen._records()
	var card: String = str(records[0]) if not records.is_empty() else ""
	_check(card.begins_with("時輪齒核 %d 枚・搬運脫手 2 次\n送進近座 0 次・遠座 2 次\n過載打中 %d 人次・彈幕延後 2 次\n下次：" % [gm.forge_cores_cast, gm.forge_core_hits]), "the forge card is the first record: %s" % card)
	_check(card.ends_with("下次：搬運時繞開敵群，被打中齒核會脫手"), "its tip follows the run (an overload after knocks)")
	_check(not str(records.slice(1)).contains("時輪齒核"), "no other record repeats the core counts")
	_check(str(records).contains("遠座校準"), "the completed mission is named under 紀錄")
	screen.root.hide()
	# The card on the 紀錄 tab fits without trimming: a result screen of its own
	# in a viewport of each size (desktop, phone landscape, phone portrait).
	for dimensions in [Vector2i(1280, 720), Vector2i(844, 390), Vector2i(430, 932)]:
		var view := SubViewport.new()
		view.size = dimensions
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(view)
		var sized: Node = load("res://scenes/ui/GameOverScreen.tscn").instantiate()
		view.add_child(sized)
		for frame in range(3):
			await process_frame
		sized.show_summary(summary)
		sized.tab = 2
		sized.page = 0
		sized._refresh()
		await process_frame
		var label: Label = sized.cards[0]
		var font_size: int = label.get_theme_font_size("font_size")
		var height: float = sized._text_height(label, label.size.x)
		print("FORGE_CORE_R48_CARD %dx%d font=%d text_h=%.0f card_h=%.0f card_w=%.0f" % [dimensions.x, dimensions.y, font_size, height, label.size.y, label.size.x])
		_check(label.text == card and font_size >= 10 and height <= label.size.y + 1.0 and label.get_global_rect().end.x <= float(dimensions.x) + 1.0, "at %dx%d the forge card fits (font %d, text %.0f of %.0f px)" % [dimensions.x, dimensions.y, font_size, height, label.size.y])
		view.queue_free()
		await process_frame
	# A forge clear with three far sets completes the mastery mission.
	gm.forge_cores_far = 3
	gm.forge_cores_set = 3
	gm.stage_victory_pending = true
	gm.tactical_director.relay.completed = true
	gm.starting_run_id = "forge-r48-integration-clear"
	var cleared: Dictionary = gm._summary_with_echo({"elapsed_time": gm.elapsed_time, "kills": 0, "gold": 0, "level": 1, "settlement_reason": "victory", "boss_killed": true})
	_check(cleared.get("campaign_clear") == true and Array(cleared.expedition_result.get("completed", [])).has("forge_core_mastery") and int(cleared.expedition_result.get("reward", 0)) >= 6, "a forge clear with three far sets completes 時輪再轉: %s" % str(cleared.expedition_result))
	_check(int(gm._summary_with_echo({"elapsed_time": gm.elapsed_time, "settlement_reason": "victory", "boss_killed": true}).expedition_result.get("reward", -1)) == 0, "the same settlement never pays twice")
	gm.stage_victory_pending = false

func _test_journal() -> void:
	gm.selected_stage_id = "forge"
	for dimensions in [Vector2i(320, 568), Vector2i(430, 932), Vector2i(844, 390), Vector2i(1280, 720)]:
		var width: int = dimensions.x
		var view := SubViewport.new()
		view.size = dimensions
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(view)
		var scroll := ScrollContainer.new()
		scroll.size = Vector2(dimensions)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		view.add_child(scroll)
		var board: VBoxContainer = load("res://scripts/ui/expedition_board.gd").new()
		scroll.add_child(board)
		for frame in range(4):
			await process_frame
		var cards := 0
		for id in ["forge_field", "forge_mastery", "forge_core_field", "forge_core_mastery"]:
			var card: Control = board.find_child(id, false, false)
			if card != null:
				cards += 1
				_check(card.get_global_rect().end.x <= float(width) + 1.0, "%s fits the width at %d" % [id, width])
		_check(cards == 4, "the forge page lists four missions at %d" % width)
		_check(_label_with(board, "遠座校準") and _label_with(board, "時輪再轉") and _label_with(board, "已完成・殘響 4 已領取"), "the new missions show by name, the field one as claimed, at %d" % width)
		for button in board.find_children("*", "Button", true, false):
			var box: Rect2 = button.get_global_rect()
			_check(box.size.y >= 44.0 and box.position.x >= -1.0 and box.end.x <= float(width) + 1.0, "journal buttons stay touchable at %d" % width)
		view.queue_free()
		await process_frame

func _clear_enemy_shots() -> void:
	var factory: Node = root.get_node("EntityFactory")
	for shot in factory.active_enemy_projectiles.duplicate():
		if is_instance_valid(shot) and shot.get("is_active") == true:
			shot.set("is_active", false)
			factory.release_projectile(shot)

func _label_with(parent: Node, text: String) -> bool:
	for item in parent.find_children("*", "Label", true, false):
		if str(item.text) == text:
			return true
	return false

func _row(id: String) -> Dictionary:
	for row in meta.get_expedition_rows():
		if row.id == id:
			return row
	return {}

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FORGE_CORE_R48_INTEGRATION_FAIL " + label)
