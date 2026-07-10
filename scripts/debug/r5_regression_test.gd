extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena/Arena.tscn")

var arena: Node = null
var squad_manager: Node = null
var leader: Node2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	arena = ARENA_SCENE.instantiate()
	add_child(arena)
	call_deferred("_run_tests")


func _run_tests() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	squad_manager = arena.get_node_or_null("SquadManager")
	leader = GameManager.player
	if squad_manager == null or leader == null or not is_instance_valid(leader):
		_fail("arena setup failed")
		return

	var spawner := arena.get_node_or_null("EnemySpawner")
	if spawner != null:
		spawner.set_process(false)

	_prepare_run_state()

	if not _test_shop_full_health_disabled():
		return
	var magnetic_ok: bool = await _test_magnetic_reclaim_run_flag()
	if not magnetic_ok:
		return
	if not _test_shop_full_qualitative_disabled():
		return
	if not _test_boss_enemy_projectile_budget():
		return
	if not _test_fork_projectile_budget():
		return
	var hazard_ok: bool = await _test_hazard_lru_and_redraw()
	if not hazard_ok:
		return

	print("R5_REGRESSION_PASS")
	get_tree().quit(0)


func _prepare_run_state() -> void:
	GameManager.game_running = true
	GameManager.is_game_over = false
	GameManager.waiting_for_upgrade = false
	GameManager.waiting_for_shop = false
	GameManager.gold = 999
	GameManager.xp_required = 99999999
	get_tree().paused = false

	for member in squad_manager.get_members():
		if member == null or not is_instance_valid(member):
			continue
		member.set("max_hp", 120.0)
		member.set("current_hp", 120.0)
		member.set("pickup_radius", 80.0)


func _test_shop_full_health_disabled() -> bool:
	GameManager.waiting_for_shop = true
	var heal_option := _find_option(GameManager._build_shop_options(), "heal_30")
	if heal_option.is_empty():
		_fail("heal shop option missing")
		return false
	if bool(heal_option.get("enabled", true)):
		_fail("heal option enabled while all members are full hp")
		return false
	if not str(heal_option.get("disabled_reason", "")).contains("滿血"):
		_fail("heal option missing full-hp reason")
		return false

	var gold_before := GameManager.gold
	GameManager.apply_shop_purchase(heal_option)
	if GameManager.gold != gold_before:
		_fail("disabled heal purchase changed gold")
		return false
	if not GameManager.waiting_for_shop:
		_fail("disabled heal purchase closed shop")
		return false

	GameManager.waiting_for_shop = false
	print("R5_SHOP_HEAL_DISABLED reason=%s" % str(heal_option.get("disabled_reason", "")))
	return true


func _test_magnetic_reclaim_run_flag() -> bool:
	if squad_manager.has_weapon_modifier("magnetic_reclaim"):
		_fail("magnetic modifier unexpectedly present before test")
		return false

	GameManager.enable_magnetic_reclaim()
	_release_active_xp_gems()
	var gem := EntityFactory.spawn_xp_gem(leader.global_position + Vector2(130.0, 0.0), 1)
	if gem == null:
		_fail("magnetic test xp gem spawn failed")
		return false

	var enemy := EntityFactory.spawn_enemy("r5_magnetic_target", _enemy_config(1.0), leader.global_position)
	if enemy == null:
		_fail("magnetic test enemy spawn failed")
		return false
	enemy.take_damage(5.0, leader.global_position)

	await get_tree().process_frame
	await get_tree().process_frame

	if not bool(gem.get("magnetized")):
		_fail("run-level magnetic reclaim did not magnetize xp")
		return false

	EntityFactory.release_xp_gem(gem)
	print("R5_MAGNETIC_RUN_FLAG magnetized=true")
	return true


func _test_shop_full_qualitative_disabled() -> bool:
	var guard := 0
	while squad_manager.has_available_qualitative_upgrade() and guard < 16:
		if not squad_manager.apply_random_qualitative_upgrade():
			_fail("random qualitative returned false before pool was empty")
			return false
		guard += 1

	if squad_manager.has_available_qualitative_upgrade():
		_fail("qualitative pool still available after guard")
		return false

	GameManager.waiting_for_shop = true
	var qualitative_option := _find_option(GameManager._build_shop_options(), "random_qualitative")
	if qualitative_option.is_empty():
		_fail("random qualitative shop option missing")
		return false
	if bool(qualitative_option.get("enabled", true)):
		_fail("random qualitative option enabled when all qualitative upgrades are capped")
		return false
	if not str(qualitative_option.get("disabled_reason", "")).contains("質變"):
		_fail("random qualitative option missing capped reason")
		return false

	var gold_before := GameManager.gold
	GameManager.apply_shop_purchase(qualitative_option)
	if GameManager.gold != gold_before:
		_fail("disabled qualitative purchase changed gold")
		return false
	if not GameManager.waiting_for_shop:
		_fail("disabled qualitative purchase closed shop")
		return false

	GameManager.waiting_for_shop = false
	print("R5_SHOP_QUALITATIVE_DISABLED reason=%s applied=%d" % [str(qualitative_option.get("disabled_reason", "")), guard])
	return true


func _test_boss_enemy_projectile_budget() -> bool:
	_release_active_projectiles()
	var stats := _enemy_projectile_stats()
	for index in range(EntityFactory.ENEMY_PROJECTILE_CAP):
		EntityFactory.spawn_enemy_projectile(leader.global_position + Vector2(600.0 + float(index) * 4.0, 0.0), Vector2.LEFT, stats, leader, "normal")

	if _count_enemy_projectiles("normal") != EntityFactory.ENEMY_PROJECTILE_CAP:
		_fail("failed to fill normal enemy projectile budget")
		return false

	for index in range(14):
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / 14.0)
		EntityFactory.spawn_enemy_projectile(leader.global_position + direction * 260.0, direction, stats, leader, "boss")

	var boss_count := _count_enemy_projectiles("boss")
	if boss_count < 14:
		_fail("boss ring did not reserve 14 projectiles, got %d" % boss_count)
		return false
	if _active_enemy_projectile_count() > EntityFactory.ENEMY_PROJECTILE_CAP:
		_fail("enemy projectile budget exceeded cap")
		return false

	print("R5_ENEMY_PROJECTILE_BOSS_RESERVED boss=%d normal=%d reclaims=%d" % [
		boss_count,
		_count_enemy_projectiles("normal"),
		int(EntityFactory.get_pool_stats().get("enemy_projectile_reclaims", 0))
	])
	return true


func _test_fork_projectile_budget() -> bool:
	_release_active_projectiles()
	var stats_before: Dictionary = EntityFactory.get_pool_stats()
	var main_exhausted_before := int(stats_before.get("projectile", {}).get("exhausted", 0))
	var fork_stats := _fork_projectile_stats()
	for index in range(EntityFactory.FORK_PROJECTILE_CAP + 24):
		EntityFactory.spawn_fork_projectile(leader.global_position + Vector2(float(index) * 3.0, 420.0), Vector2.RIGHT, fork_stats, leader)

	if _active_fork_projectile_count() > EntityFactory.FORK_PROJECTILE_CAP:
		_fail("fork projectile budget exceeded cap")
		return false

	var main := EntityFactory.spawn_projectile(leader.global_position, Vector2.RIGHT, _main_projectile_stats(), leader)
	if main == null:
		_fail("main projectile failed after fork budget saturation")
		return false

	var stats_after: Dictionary = EntityFactory.get_pool_stats()
	var main_exhausted_after := int(stats_after.get("projectile", {}).get("exhausted", 0))
	if main_exhausted_after != main_exhausted_before:
		_fail("main projectile pool exhausted while spawning forks")
		return false

	EntityFactory.release_projectile(main)
	print("R5_FORK_BUDGET active=%d cap_skips=%d main_exhausted=%d" % [
		_active_fork_projectile_count(),
		int(stats_after.get("fork_projectile_cap_skips", 0)),
		main_exhausted_after
	])
	return true


func _test_hazard_lru_and_redraw() -> bool:
	_release_active_hazards()
	var stats := _hazard_stats()
	var oldest: Node = null
	for index in range(EntityFactory.HAZARD_ZONE_CAP):
		var hazard := EntityFactory.spawn_hazard_zone(leader.global_position + Vector2(float(index) * 20.0, -420.0), stats, leader)
		if hazard == null:
			_fail("initial hazard spawn failed")
			return false
		if index == 0:
			oldest = hazard

	var replacement_position := leader.global_position + Vector2(360.0, -420.0)
	var replacement := EntityFactory.spawn_hazard_zone(replacement_position, stats, leader)
	if replacement == null:
		_fail("hazard LRU replacement returned null")
		return false
	if EntityFactory.get_pool_live_count("hazard_zone") != EntityFactory.HAZARD_ZONE_CAP:
		_fail("hazard LRU changed live cap")
		return false

	if replacement == oldest:
		if replacement.global_position.distance_to(replacement_position) > 0.1:
			_fail("reused oldest hazard did not move to replacement position")
			return false
	elif oldest != null and is_instance_valid(oldest) and bool(oldest.get("is_active")):
		_fail("oldest hazard remained active after LRU replacement")
		return false

	var redraws_before := int(replacement.get("redraw_request_count"))
	for _frame in range(8):
		await get_tree().process_frame
	var redraws_after := int(replacement.get("redraw_request_count"))
	if redraws_after != redraws_before:
		_fail("hazard requested redraw during steady process frames")
		return false

	print("R5_HAZARD_LRU_REDRAW live=%d reclaims=%d redraws=%d" % [
		EntityFactory.get_pool_live_count("hazard_zone"),
		int(EntityFactory.get_pool_stats().get("hazard_zone_reclaims", 0)),
		redraws_after
	])
	return true


func _find_option(options: Array, option_id: String) -> Dictionary:
	for option in options:
		if str(option.get("id", "")) == option_id:
			return option
	return {}


func _count_enemy_projectiles(priority: String) -> int:
	var count := 0
	var projectiles: Array = EntityFactory.get("active_enemy_projectiles")
	for projectile in projectiles:
		if projectile == null or not is_instance_valid(projectile):
			continue
		if bool(projectile.get("is_active")) and str(projectile.get_meta("_enemy_projectile_priority", "normal")) == priority:
			count += 1
	return count


func _active_enemy_projectile_count() -> int:
	var count := 0
	var projectiles: Array = EntityFactory.get("active_enemy_projectiles")
	for projectile in projectiles:
		if projectile != null and is_instance_valid(projectile) and bool(projectile.get("is_active")):
			count += 1
	return count


func _active_fork_projectile_count() -> int:
	var count := 0
	var projectiles: Array = EntityFactory.get("active_fork_projectiles")
	for projectile in projectiles:
		if projectile != null and is_instance_valid(projectile) and bool(projectile.get("is_active")):
			count += 1
	return count


func _release_active_projectiles() -> void:
	var enemy_projectiles: Array = EntityFactory.get("active_enemy_projectiles")
	for projectile in enemy_projectiles.duplicate():
		if projectile != null and is_instance_valid(projectile):
			EntityFactory.release_projectile(projectile)
	var fork_projectiles: Array = EntityFactory.get("active_fork_projectiles")
	for projectile in fork_projectiles.duplicate():
		if projectile != null and is_instance_valid(projectile):
			EntityFactory.release_projectile(projectile)


func _release_active_hazards() -> void:
	var hazards: Array = EntityFactory.get("active_hazard_zones")
	for hazard in hazards.duplicate():
		if hazard != null and is_instance_valid(hazard):
			EntityFactory.release_hazard_zone(hazard)


func _release_active_xp_gems() -> void:
	var gems: Array = EntityFactory.get("active_xp_gems")
	for gem in gems.duplicate():
		if gem != null and is_instance_valid(gem):
			EntityFactory.release_xp_gem(gem)


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


func _enemy_projectile_stats() -> Dictionary:
	return {
		"damage": 1.0,
		"range": 9999.0,
		"projectile_speed": 0.0,
		"projectile_radius": 5.0,
		"pierce": 0,
		"color": Color(1.0, 0.35, 0.24),
		"projectile_sprite_path": "res://assets/sprites/proj_bullet.png",
		"sprite_scale": 1.0,
		"target_group": "heroes"
	}


func _main_projectile_stats() -> Dictionary:
	return {
		"damage": 1.0,
		"range": 9999.0,
		"projectile_speed": 0.0,
		"projectile_radius": 5.0,
		"pierce": 0,
		"color": Color(0.72, 0.95, 1.0),
		"projectile_sprite_path": "res://assets/sprites/proj_bullet.png",
		"sprite_scale": 1.0,
		"target_group": "enemies"
	}


func _fork_projectile_stats() -> Dictionary:
	var stats := _main_projectile_stats()
	stats["damage"] = 0.5
	stats["fork_depth"] = 1
	stats["riftline_fork_level"] = 0
	return stats


func _hazard_stats() -> Dictionary:
	return {
		"damage_per_second": 0.0,
		"area_radius": 24.0,
		"duration": 99.0,
		"tick_interval": 0.24,
		"color": Color(1.0, 0.48, 0.14)
	}


func _fail(message: String) -> void:
	printerr("R5_REGRESSION_FAIL: " + message)
	get_tree().quit(1)
