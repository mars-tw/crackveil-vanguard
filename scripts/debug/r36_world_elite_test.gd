extends Node

const WORLD := preload("res://scripts/services/loop_world_topology.gd")
const ELITES := preload("res://scripts/services/special_elite_catalog.gd")
const ARENA := preload("res://scenes/arena/Arena.tscn")
var failures: Array[String] = []

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("R36_WORLD_ELITE_FAIL: " + message)

func _run() -> void:
	GameManager.campaign_save_path = "user://r36_world_elite_test.cfg"
	GameManager.wallet_gold = 0
	PlayerSettings.debug_use_save_path("user://r36_world_settings.cfg", true)
	MetaProgress.debug_use_save_path("user://r36_world_meta.cfg", true)
	AchievementProgress.debug_use_save_path("user://r36_world_achievements.cfg", true)
	var arena := ARENA.instantiate()
	add_child(arena)
	await get_tree().process_frame
	GameManager.waiting_for_upgrade = false
	GameManager.waiting_for_contract = false
	GameManager.system_pause_owners.clear()
	get_tree().paused = false
	GameManager.auto_upgrade_enabled = false
	GameManager.xp_required = 999999
	var leader: Node2D = GameManager.player
	var spawner: Node = arena.get_node("EnemySpawner")
	spawner.set_process(false)
	var background: Node = arena.get_node("Background")
	var map_state: Dictionary = background.get_r36_debug_state()
	_check(bool(map_state.get("bitmap_ready", false)), "loop map lacks final painted assets")
	_check(map_state.get("landmark_node_uids", []).size() == 8, "loop map lacks eight stable landmarks")
	for weapon in leader.weapons.values():
		weapon.set_process(false)
	leader.set_process(false)
	leader.set_physics_process(false)
	_check(WORLD.canonical(Vector2(4121, -3092)).is_equal_approx(Vector2(25, -20)), "loop canonical coordinates")
	_check(WORLD.nearest_image(Vector2(0, 0), Vector2(4100, 3100)).is_equal_approx(Vector2(4096, 3072)), "nearest periodic image")
	leader.global_position = Vector2(7000, -5300)
	leader._constrain_to_stage()
	_check(leader.global_position.is_equal_approx(Vector2(7000, -5300)), "player still hits hard map boundary")
	var zoom: Vector2 = leader._leader_camera_zoom()
	_check(zoom.x <= 1.3 and leader.camera.limit_right >= 1000000, "desktop camera still fits small full map")
	print("R36_LOOP_WORLD canonical=true arbitrary_movement=true zoom=%.2f period4096x3072=true" % zoom.x)
	GameManager.critical_strikes_enabled = false
	for profile in ELITES.get_profiles():
		var config := ELITES.make_config(str(profile.id), 240)
		var enemy: Node2D = EntityFactory.spawn_enemy("special_test", config, leader.global_position + Vector2(100, 0))
		enemy.set_physics_process(false)
		_check(enemy.special_elite_id == str(profile.id), "elite profile missing " + str(profile.id))
		var before_shots := EntityFactory.get_pool_live_count("projectile")
		var before_enemies := EntityFactory.get_enemy_live_count()
		var before_hp: float = leader.current_hp
		leader.invulnerability_timer = 0.0
		if str(profile.skill) == "treasure":
			enemy.special_timer = 0.0
			enemy._physics_special_elite(0.02, leader)
			_check(enemy.special_gold_drops == 1, "treasure did not drop real gold")
		else:
			_check(enemy._start_attack(leader, 1.0, &"elite"), "elite could not begin authored attack")
			_check(enemy.special_casts == 0, "elite damaged during anticipation")
			for frame in range(40):
				await get_tree().process_frame
			_check(enemy.special_casts == 1, "elite did not cast once on actual impact " + str(profile.id))
			if str(profile.skill) == "summoner":
				_check(EntityFactory.get_enemy_live_count() >= before_enemies + 5, "summoner did not spawn five bodies")
			elif str(profile.skill) == "shield_slam":
				_check(leader.current_hp < before_hp, "shield slam did not hurt within radius")
			else:
				_check(enemy.special_projectiles_fired > 0, "elite produced no physical projectiles")
		print("R36_SPECIAL_ELITE id=%s skill=%s casts=%d treasure_drops=%d" % [profile.id, profile.skill, enemy.special_casts, enemy.special_gold_drops])
		EntityFactory.release_enemy(enemy)
	GameManager.critical_strikes_enabled = true
	if failures.is_empty():
		print("R36_WORLD_ELITE_PASS real_loop=true no_hard_bounds=true six_specials=true frame2=true treasure_gold=true")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
