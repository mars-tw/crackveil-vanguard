extends Node

const CATALOG := preload("res://scripts/services/stage_catalog.gd")
const WORLD_MAP := "res://scenes/ui/WorldMap.tscn"
const ARENA := "res://scenes/arena/Arena.tscn"
const TEST_PREFIX := "user://r34_campaign_transition_"

var failed := false
var finished := false
var deadline_msec := 0
var phase := "bootstrap"
var scene_instances := 0
var arena_instances := 0
var starting_members := 0
var scene_ids: Dictionary = {}
var last_boss_drop: Dictionary = {}


func _ready() -> void:
	if not bool(get_meta("persistent_runner", false)):
		call_deferred("_install_persistent_runner")
		return
	process_mode = PROCESS_MODE_ALWAYS
	deadline_msec = Time.get_ticks_msec() + 20000
	call_deferred("_run")


func _install_persistent_runner() -> void:
	var runner: Node = get_script().new()
	runner.name = "R34CampaignTransitionPersistentRunner"
	runner.set_meta("persistent_runner", true)
	get_tree().root.add_child(runner)


func _process(_delta: float) -> void:
	if bool(get_meta("persistent_runner", false)) and not finished and not failed and Time.get_ticks_msec() >= deadline_msec:
		_fail("20 second watchdog expired during " + phase)


func _run() -> void:
	phase = "isolate_save_paths"
	GameManager.campaign_save_path = TEST_PREFIX + "campaign.cfg"
	GameManager.campaign_clears.clear()
	var empty_save := ConfigFile.new()
	empty_save.set_value("campaign", "clears", [])
	if not _check(empty_save.save(GameManager.campaign_save_path) == OK, "isolated campaign save could not be created"):
		return
	MetaProgress.debug_use_save_path(TEST_PREFIX + "meta.cfg", true)
	PlayerSettings.debug_use_save_path(TEST_PREFIX + "settings.cfg", true)
	AchievementProgress.debug_use_save_path(TEST_PREFIX + "achievements.cfg", true)
	GameManager.game_running = false
	GameManager.manual_paused = false
	GameManager.system_pause_owners.clear()
	GameManager.clear_time_scale_owners()
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_MAP)
	var map := await _wait_scene(WORLD_MAP)
	if map == null:
		return
	var stages := CATALOG.get_stages()
	var buttons: Array = map.get("node_buttons")
	if not _check(buttons.size() == stages.size(), "world map does not expose six real stage buttons"):
		return
	phase = "press_all_six_world_map_nodes"
	for index in range(stages.size()):
		var id := str(stages[index].id)
		(buttons[index] as Button).pressed.emit()
		if not _check(GameManager.selected_stage_id == id and str(map.get("selected_id")) == id and (map.get("detail_boss") as Label).text.contains(str(stages[index].boss_name)), "real map button failed to select stage and boss: " + id):
			return
		print("R34_CAMPAIGN_MAP_NODE selected=%s real_button_pressed=true" % id)
	(buttons[0] as Button).pressed.emit()
	(map.get("start_button") as Button).pressed.emit()
	var old_refs: Array[WeakRef] = []
	for index in range(stages.size()):
		var stage: Dictionary = stages[index]
		var id := str(stage.id)
		phase = "enter_arena_" + id
		var arena := await _wait_scene(ARENA)
		if arena == null:
			return
		arena_instances += 1
		for previous in old_refs:
			if not _check(previous.get_ref() == null, "old scene/member/pool node survived the real next-stage transition: " + id):
				return
		if not _check(GameManager.arena == arena and GameManager.selected_stage_id == id and GameManager.current_run_theme_id == str(stage.theme_id), "Arena loaded the wrong selected stage or theme: " + id):
			return
		var background: Node = arena.get_node("Background")
		if not _check(str(background.get("current_theme_id")) == str(stage.theme_id), "painted background did not apply the selected theme: " + id):
			return
		if not _check(GameManager.game_running and not get_tree().paused and not GameManager.stage_victory_pending and not GameManager.waiting_for_upgrade and not GameManager.waiting_for_shop and not GameManager.waiting_for_contract and GameManager.system_pause_owners.is_empty() and GameManager.get_time_scale_owner_count() == 0, "new Arena retained old victory/modal/time-scale state: " + id):
			return
		var squad: Node = arena.get_node("SquadManager")
		var members: Array = squad.get_members()
		if starting_members == 0:
			starting_members = members.size()
		if not _check(members.size() == starting_members and get_tree().get_nodes_in_group("heroes").size() == starting_members and EntityFactory.pool_root.get_parent() == arena, "new Arena contains old squad or pools: " + id):
			return
		var loot: Node = arena.get_node("LootDirector")
		last_boss_drop.clear()
		loot.connect("loot_dropped", Callable(self, "_on_fixture_loot_dropped"))
		if not _check((loot.get("slots") as Dictionary).is_empty(), "equipment from the prior stage remained equipped: " + id):
			return
		_freeze_fixture_actors(arena)
		var spawner: Node = arena.get_node("EnemySpawner")
		if not _check(is_equal_approx(float(spawner.get("boss_time")), float(stage.boss_time)), "Arena did not apply its real stage boss timer: " + id):
			return
		# Controlled fixture: advance the real schedule, rather than spawning a
		# stand-in boss or calling GameManager.record_boss_kill directly.
		phase = "scheduled_boss_" + id
		GameManager.elapsed_time = float(stage.boss_time)
		spawner.call("_process", 0.001)
		var boss: Node = null
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.get("is_boss") == true:
				boss = enemy
				enemy.set_physics_process(false)
		if not _check(boss != null and str(boss.get("type_id")) == "stage_boss_" + id and str(boss.get("boss_pattern")) == str(stage.pattern) and GameManager.boss_spawned and GameManager.boss_active, "scheduled spawner did not create the selected real boss: " + id):
			return
		_freeze_fixture_actors(arena)
		var collected_before := int(loot.get("collected_count"))
		phase = "lethal_hit_and_death_poses_" + id
		boss.call("take_damage", 1000000.0, GameManager.player.global_position)
		if not _check(boss.get("is_dying") == true and str(boss.get("current_animation_name")) == "death" and not GameManager.boss_killed and GameManager.campaign_clears.size() == index, "boss clear or rewards skipped the actual death poses: " + id):
			return
		while not GameManager.stage_victory_pending and not failed:
			await get_tree().process_frame
		if failed:
			return
		await get_tree().process_frame
		# Observe the actual boss drop signal and confirm that exact UID was
		# claimed. pending/history snapshots precede the later source tag.
		var legendary_claimed := str(last_boss_drop.get("source", "")) == "boss" and int(last_boss_drop.get("rarity", -1)) == 3 and (loot.get("claimed_items") as Dictionary).has(int(last_boss_drop.get("uid", 0)))
		print("R34_CAMPAIGN_REWARD_STATE stage=%s legendary=%s collected=%d before=%d clears=%s boss_killed=%s paused=%s" % [id, legendary_claimed, int(loot.get("collected_count")), collected_before, GameManager.campaign_clears, GameManager.boss_killed, get_tree().paused])
		if not legendary_claimed:
			print("R34_CAMPAIGN_REWARD_DEBUG slots=%s claimed=%s" % [loot.get("slots"), loot.get("claimed_items")])
		if not _check(legendary_claimed and int(loot.get("collected_count")) > collected_before and GameManager.campaign_clears.size() == index + 1 and GameManager.campaign_clears.has(id) and GameManager.boss_killed and get_tree().paused, "real boss finalization did not claim a legendary and award exactly one clear: " + id):
			return
		var saved := ConfigFile.new()
		if not _check(saved.load(GameManager.campaign_save_path) == OK and (saved.get_value("campaign", "clears", []) as Array).size() == index + 1, "campaign clear was not persisted after boss death: " + id):
			return
		var victory: Node = arena.get_node("StageVictoryScreen")
		if not _check((victory.get("root") as Control).visible and str((victory.get("displayed_summary") as Dictionary).get("stage_id", "")) == id, "real stage victory UI did not receive the boss summary: " + id):
			return
		old_refs.clear()
		old_refs.append(weakref(arena))
		old_refs.append(weakref(squad))
		old_refs.append(weakref(EntityFactory.pool_root))
		for member in members:
			old_refs.append(weakref(member))
		phase = "press_victory_next_" + id
		(victory.get("copy_seed_button") as Button).pressed.emit()
		print("R34_CAMPAIGN_STAGE_PASS stage=%s theme=%s boss=%s death_poses=true legendary_claimed=true persisted_clears=%d next_button_pressed=true" % [id, str(stage.theme_id), str(stage.pattern), index + 1])
	phase = "final_world_map"
	var final_map := await _wait_scene(WORLD_MAP)
	if final_map == null:
		return
	for previous in old_refs:
		if not _check(previous.get_ref() == null, "final world map retained an old arena/member/pool root"):
			return
	if not _check(not GameManager.game_running and not get_tree().paused and not GameManager.stage_victory_pending and GameManager.system_pause_owners.is_empty() and GameManager.get_time_scale_owner_count() == 0 and get_tree().get_nodes_in_group("heroes").is_empty() and get_tree().get_nodes_in_group("projectiles").is_empty(), "final map retained old combat or pause state"):
		return
	var final_nodes: Array = final_map.get("node_buttons")
	for button in final_nodes:
		if not _check((button.get_node("Difficulty") as Label).text.contains("通關"), "a final map node did not show its clear status"):
			return
	if not _check((final_map.get("progress") as Label).text.contains("%d／%d" % [stages.size(), stages.size()]) and GameManager.campaign_clears.size() == stages.size(), "final world map did not show all six clears"):
		return
	finished = true
	print("R34_CAMPAIGN_TRANSITION_PASS controlled_fixture=true scene_instances=%d arenas=%d map_node_presses=6 real_start_press=1 real_next_presses=6 clears=6/6 checkmarks=6 old_nodes=0 old_modals=0 isolated_saves=true watchdog=20s" % [scene_instances, arena_instances])
	get_tree().quit(0)


func _wait_scene(path: String) -> Node:
	while not failed:
		var scene: Node = get_tree().current_scene
		if scene != null and scene.scene_file_path == path:
			await get_tree().process_frame
			await get_tree().process_frame
			if failed:
				return null
			if not scene_ids.has(scene.get_instance_id()):
				scene_ids[scene.get_instance_id()] = true
				scene_instances += 1
			return scene
		await get_tree().process_frame
	return null


func _freeze_fixture_actors(arena: Node) -> void:
	arena.get_node("EnemySpawner").set_process(false)
	for actor in get_tree().get_nodes_in_group("heroes"):
		actor.set_process(false)
		actor.set_physics_process(false)
		for child in actor.get_children():
			if child.is_in_group("hero_controllers"):
				child.set_process(false)
				child.set_physics_process(false)
		for weapon in (actor.get("weapons") as Dictionary).values():
			weapon.set_process(false)
			weapon.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.set_process(false)
		projectile.set_physics_process(false)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
	return condition


func _on_fixture_loot_dropped(item: Dictionary, _position: Vector2) -> void:
	if str(item.get("source", "")) == "boss":
		last_boss_drop = item.duplicate(true)


func _fail(message: String) -> void:
	if failed or finished:
		return
	failed = true
	printerr("R34_CAMPAIGN_TRANSITION_FAIL phase=%s: %s" % [phase, message])
	get_tree().quit(1)
