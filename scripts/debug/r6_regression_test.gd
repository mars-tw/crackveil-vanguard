extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena/Arena.tscn")

var arena: Node = null
var squad_manager: Node = null
var leader: Node2D = null
var spawner: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	arena = ARENA_SCENE.instantiate()
	add_child(arena)
	call_deferred("_run_tests")


func _run_tests() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	squad_manager = arena.get_node_or_null("SquadManager")
	spawner = arena.get_node_or_null("EnemySpawner")
	leader = GameManager.player
	if squad_manager == null or spawner == null or leader == null or not is_instance_valid(leader):
		_fail("arena setup failed")
		return

	spawner.set_process(false)
	_prepare_run_state()

	if not _test_elite_replaces_regular_enemy_at_cap():
		return
	if not _test_elite_visible_xp_never_direct_grants():
		return
	if not _test_shop_schedule_avoids_boss_window():
		return
	if not _test_contract_application_and_seed():
		return

	print("R6_REGRESSION_PASS")
	get_tree().quit(0)


func _prepare_run_state() -> void:
	GameManager.game_running = true
	GameManager.is_game_over = false
	GameManager.waiting_for_contract = false
	GameManager.waiting_for_upgrade = false
	GameManager.waiting_for_shop = false
	GameManager.stage_victory_pending = false
	GameManager.manual_paused = false
	GameManager.boss_active = false
	GameManager.active_contract_id = ""
	GameManager.active_contract_name = "無契約"
	GameManager.contract_modifiers.clear()
	GameManager.gold = 999
	GameManager.xp = 0
	GameManager.xp_required = 99999999
	get_tree().paused = false

	for member in squad_manager.get_members():
		if member == null or not is_instance_valid(member):
			continue
		member.set("max_hp", 120.0)
		member.set("current_hp", 120.0)
		member.set("pickup_radius", 80.0)


func _test_elite_replaces_regular_enemy_at_cap() -> bool:
	_release_active_enemies()
	var old_max := int(spawner.get("max_enemies"))
	spawner.set("max_enemies", 12)
	for index in range(12):
		var enemy := EntityFactory.spawn_enemy("r6_cap_normal", _enemy_config(30.0), leader.global_position + Vector2(float(index) * 28.0, 360.0))
		if enemy == null:
			_fail("failed to fill enemy cap for elite test")
			return false

	var reclaims_before := int(EntityFactory.get_pool_stats().get("elite_enemy_reclaims", 0))
	var spawned: bool = spawner._spawn_elite()
	if not spawned:
		_fail("elite did not spawn at cap")
		return false
	if EntityFactory.get_enemy_live_count() != 12:
		_fail("elite replacement changed enemy live cap")
		return false
	if _count_live_elites() != 1:
		_fail("elite replacement did not leave one live elite")
		return false
	var reclaims_after := int(EntityFactory.get_pool_stats().get("elite_enemy_reclaims", 0))
	if reclaims_after <= reclaims_before:
		_fail("elite replacement did not reclaim a regular enemy")
		return false

	spawner.set("max_enemies", old_max)
	_release_active_enemies()
	print("R6_E6_ELITE_CAP_REPLACEMENT live=12 reclaims=%d" % reclaims_after)
	return true


func _test_elite_visible_xp_never_direct_grants() -> bool:
	_release_active_xp_gems()
	GameManager.xp = 0
	var base_position := leader.global_position + Vector2(2600.0, 0.0)
	for index in range(EntityFactory.XP_GEM_CAP):
		var gem := EntityFactory.spawn_xp_gem(base_position + Vector2(float(index) * 4.0, 0.0), 1)
		if gem == null:
			_fail("failed to fill xp gem cap")
			return false

	var direct_before := int(EntityFactory.get_pool_stats().get("direct_xp_grants", 0))
	var merge_target := EntityFactory.spawn_visible_xp_gem(base_position, 24)
	if merge_target == null:
		_fail("visible xp merge returned null at cap")
		return false
	if GameManager.xp != 0:
		_fail("visible elite xp direct granted during merge path")
		return false
	if int(merge_target.get("value")) <= 1:
		_fail("visible elite xp did not merge into an active gem")
		return false

	EntityFactory.debug_clear_active_xp_gem_registry()
	var reclaim_target := EntityFactory.spawn_visible_xp_gem(base_position + Vector2(900.0, 0.0), 31)
	if reclaim_target == null:
		_fail("visible xp reclaim path returned null")
		return false
	if EntityFactory.get_pool_live_count("xp_gem") != EntityFactory.XP_GEM_CAP:
		_fail("visible xp reclaim changed xp gem cap")
		return false
	if GameManager.xp != 0:
		_fail("visible elite xp direct granted during reclaim path")
		return false
	var direct_after := int(EntityFactory.get_pool_stats().get("direct_xp_grants", 0))
	if direct_after != direct_before:
		_fail("visible elite xp used direct grant fallback")
		return false

	var stats := EntityFactory.get_pool_stats()
	print("R6_E4_VISIBLE_XP merge=%d reclaim=%d direct=%d" % [
		int(stats.get("visible_xp_merges", 0)),
		int(stats.get("visible_xp_reclaims", 0)),
		direct_after
	])
	_release_active_xp_gems()
	return true


func _test_shop_schedule_avoids_boss_window() -> bool:
	var expected := [75.0, 150.0, 240.0, 330.0]
	for index in range(expected.size()):
		var scheduled: float = GameManager._shop_time_for_index(index)
		if not is_equal_approx(scheduled, float(expected[index])):
			_fail("shop schedule mismatch index=%d expected=%.1f got=%.1f" % [index, float(expected[index]), scheduled])
			return false
		if GameManager._is_in_boss_shop_window(scheduled):
			_fail("scheduled shop lands inside boss window")
			return false

	GameManager.waiting_for_shop = false
	GameManager.waiting_for_upgrade = false
	GameManager.waiting_for_contract = false
	GameManager.stage_victory_pending = false
	GameManager.is_game_over = false
	GameManager.game_running = true
	GameManager.boss_active = false
	GameManager.elapsed_time = 180.0
	GameManager.next_shop_time = 180.0
	if GameManager._request_shop("r6_window_test"):
		_fail("shop opened inside boss window")
		return false
	if GameManager.waiting_for_shop:
		_fail("shop waiting flag set inside boss window")
		return false
	if not is_equal_approx(GameManager.next_shop_time, 205.0):
		_fail("shop did not delay to boss window end")
		return false

	GameManager.elapsed_time = 220.0
	GameManager.next_shop_time = 220.0
	GameManager.boss_active = true
	if GameManager._request_shop("r6_boss_active_test"):
		_fail("shop opened while boss_active")
		return false
	if GameManager.next_shop_time <= 220.0:
		_fail("boss_active shop retry did not move into the future")
		return false

	GameManager.stage_victory_pending = true
	GameManager.boss_active = false
	GameManager.next_shop_time = 210.0
	GameManager.elapsed_time = 220.0
	GameManager.continue_after_stage_victory()
	if GameManager.next_shop_time < 232.0:
		_fail("stage victory continue allowed immediate shop")
		return false

	print("R6_S3_SHOP_BOSS_WINDOW next_after_window=205 next_after_victory=%.1f" % GameManager.next_shop_time)
	return true


func _test_contract_application_and_seed() -> bool:
	seed(246813)
	var first_choices := GameManager._build_contract_choices()
	seed(246813)
	var second_choices := GameManager._build_contract_choices()
	if _contract_ids(first_choices) != _contract_ids(second_choices):
		_fail("contract choices are not seed reproducible")
		return false

	var old_max_hp := float(leader.get("max_hp"))
	GameManager.waiting_for_contract = true
	get_tree().paused = true
	GameManager.apply_contract({"id": "contract_glass_magnet"})
	if GameManager.active_contract_id != "contract_glass_magnet":
		_fail("glass magnet contract id not applied")
		return false
	if not GameManager.has_magnetic_reclaim():
		_fail("glass magnet did not enable magnetic reclaim")
		return false
	if not is_equal_approx(float(leader.get("max_hp")), old_max_hp * 0.92):
		_fail("glass magnet did not reduce max hp")
		return false

	GameManager.elapsed_time = 30.0
	GameManager.apply_contract({"id": "contract_golden_famine"})
	if GameManager.get_upgrade_choice_count() != 2:
		_fail("golden famine did not reduce early upgrade choices")
		return false
	if not is_equal_approx(GameManager.get_gold_drop_multiplier(), 1.4):
		_fail("golden famine gold multiplier mismatch")
		return false
	GameManager.elapsed_time = 100.0
	if GameManager.get_upgrade_choice_count() != 3:
		_fail("golden famine choice penalty did not expire")
		return false

	GameManager.elapsed_time = 20.0
	GameManager.apply_contract({"id": "contract_quiet_veil"})
	if not is_equal_approx(GameManager.get_spawn_timer_multiplier(), 1.25):
		_fail("quiet veil early spawn multiplier mismatch")
		return false
	GameManager.elapsed_time = 70.0
	if not is_equal_approx(GameManager.get_spawn_timer_multiplier(), 0.9):
		_fail("quiet veil late spawn multiplier mismatch")
		return false

	print("R6_CONTRACTS seed_ids=%s active=%s" % [JSON.stringify(_contract_ids(first_choices)), GameManager.active_contract_id])
	return true


func _contract_ids(choices: Array) -> Array[String]:
	var ids: Array[String] = []
	for choice in choices:
		ids.append(str(choice.get("id", "")))
	return ids


func _count_live_elites() -> int:
	var count := 0
	var live_enemies: Array = EntityFactory.get("enemy_spatial_index").get("live_enemies")
	for enemy in live_enemies:
		if enemy != null and is_instance_valid(enemy) and bool(enemy.get("is_active")) and bool(enemy.get("is_elite")):
			count += 1
	return count


func _release_active_enemies() -> void:
	var live_enemies: Array = EntityFactory.get("enemy_spatial_index").get("live_enemies")
	for enemy in live_enemies.duplicate():
		if enemy != null and is_instance_valid(enemy):
			EntityFactory.release_enemy(enemy)


func _release_active_xp_gems() -> void:
	var gems: Array = EntityFactory.get("active_xp_gems")
	for gem in gems.duplicate():
		if gem != null and is_instance_valid(gem):
			EntityFactory.release_xp_gem(gem)
	EntityFactory.debug_clear_active_xp_gem_registry()


func _enemy_config(hp: float) -> Dictionary:
	return {
		"max_hp": hp,
		"speed": 0.0,
		"damage": 0.0,
		"xp": 0,
		"gold": 0,
		"radius": 13.0,
		"color": Color(0.55, 0.78, 1.0),
		"sprite_path": "res://assets/sprites/enemy_grunt.png",
		"sprite_scale": 1.0,
		"attack_cooldown": 99.0
	}


func _fail(message: String) -> void:
	printerr("R6_REGRESSION_FAIL: " + message)
	get_tree().quit(1)
