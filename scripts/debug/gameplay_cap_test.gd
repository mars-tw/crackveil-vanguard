extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena/Arena.tscn")
const EXPLOSION_CAP_TEST := 36
const PICKUP_CAP_TEST := 180

var arena: Node = null
var leader: Node2D = null


func _ready() -> void:
	arena = ARENA_SCENE.instantiate()
	add_child(arena)
	call_deferred("_run_tests")


func _run_tests() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	leader = GameManager.player
	if leader == null or not is_instance_valid(leader):
		_fail("leader not found")
		return

	var spawner := arena.get_node_or_null("EnemySpawner")
	if spawner != null:
		spawner.set_process(false)

	_prepare_run_state()

	if not _test_explosion_damage_survives_visual_cap():
		return
	var pickup_ok: bool = await _test_pickup_value_survives_visual_cap()
	if not pickup_ok:
		return

	print("GAMEPLAY_CAP_PASS")
	get_tree().quit(0)


func _prepare_run_state() -> void:
	GameManager.game_running = true
	GameManager.is_game_over = false
	GameManager.waiting_for_upgrade = false
	GameManager.xp = 0
	GameManager.gold = 0
	GameManager.xp_required = 99999999
	get_tree().paused = false

	var members: Array = []
	if GameManager.squad_manager != null and is_instance_valid(GameManager.squad_manager) and GameManager.squad_manager.has_method("get_members"):
		members = GameManager.squad_manager.get_members()
	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		member.set("pickup_radius", 900.0)
		member.set("current_hp", 999999.0)
		member.set("max_hp", 999999.0)


func _test_explosion_damage_survives_visual_cap() -> bool:
	var harmless_stats := {
		"damage": 0.0,
		"area_radius": 1.0,
		"effect_lifetime": 30.0,
		"explosion_sprite_path": "res://assets/sprites/fx_explosion.png"
	}
	for index in range(EXPLOSION_CAP_TEST):
		EntityFactory.spawn_explosion(leader.global_position + Vector2(3000.0 + float(index) * 12.0, 3000.0), harmless_stats, leader)

	if EntityFactory.get_pool_live_count("explosion") < EXPLOSION_CAP_TEST:
		_fail("failed to fill explosion visual cap")
		return false

	var enemy := EntityFactory.spawn_enemy("cap_explosion_target", _enemy_config(80.0), leader.global_position + Vector2(160.0, 0.0))
	if enemy == null:
		_fail("explosion cap enemy spawn failed")
		return false

	var hp_before: float = float(enemy.get("hp"))
	var damaging_stats := {
		"damage": 18.0,
		"area_radius": 64.0,
		"effect_lifetime": 0.35,
		"explosion_sprite_path": "res://assets/sprites/fx_explosion.png"
	}
	var visual := EntityFactory.spawn_explosion(enemy.global_position, damaging_stats, leader)
	if visual != null:
		_fail("explosion visual cap did not trigger")
		return false

	var hp_after: float = float(enemy.get("hp"))
	if hp_after >= hp_before:
		_fail("explosion damage was skipped when visual cap was full")
		return false

	EntityFactory.release_enemy(enemy)
	print("GAMEPLAY_CAP_EXPLOSION hp_before=%.1f hp_after=%.1f visual_skipped=true" % [hp_before, hp_after])
	return true


func _test_pickup_value_survives_visual_cap() -> bool:
	GameManager.xp = 0
	GameManager.gold = 0
	var visible_xp_total := 0
	var visible_gold_total := 0
	var overflow_xp_total := 0
	var overflow_gold_total := 0

	for _index in range(PICKUP_CAP_TEST):
		EntityFactory.spawn_xp_gem(leader.global_position, 1)
		visible_xp_total += 1
		EntityFactory.spawn_gold_coin(leader.global_position, 1)
		visible_gold_total += 1

	if EntityFactory.get_pool_live_count("xp_gem") < PICKUP_CAP_TEST:
		_fail("failed to fill xp visual cap")
		return false
	if EntityFactory.get_pool_live_count("coin") < PICKUP_CAP_TEST:
		_fail("failed to fill coin visual cap")
		return false

	for index in range(25):
		var xp_value := 2 + (index % 3)
		var gold_value := 1 + (index % 4)
		overflow_xp_total += xp_value
		overflow_gold_total += gold_value
		var xp_node := EntityFactory.spawn_xp_gem(leader.global_position, xp_value)
		var coin_node := EntityFactory.spawn_gold_coin(leader.global_position, gold_value)
		if xp_node != null or coin_node != null:
			_fail("pickup visual cap did not trigger overflow fallback")
			return false

	for _frame in range(18):
		await get_tree().physics_frame

	var expected_xp := visible_xp_total + overflow_xp_total
	var expected_gold := visible_gold_total + overflow_gold_total
	if GameManager.xp != expected_xp:
		_fail("xp total mismatch expected=%d actual=%d" % [expected_xp, GameManager.xp])
		return false
	if GameManager.gold != expected_gold:
		_fail("gold total mismatch expected=%d actual=%d" % [expected_gold, GameManager.gold])
		return false

	print("GAMEPLAY_CAP_PICKUPS xp=%d gold=%d visual_cap_triggered=true" % [GameManager.xp, GameManager.gold])
	return true


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
	printerr("GAMEPLAY_CAP_FAIL: " + message)
	get_tree().quit(1)
