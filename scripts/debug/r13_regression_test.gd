extends Node2D

var current_phase: String = "boot"
var player: CharacterBody2D = null
var milestone_count: int = 0
var break_count: int = 0
var boss_intro_name: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(13013)
	call_deferred("_watchdog")
	call_deferred("_run_tests")


func _watchdog() -> void:
	await get_tree().create_timer(12.0, true).timeout
	if current_phase != "done":
		_fail("watchdog timeout at phase: " + current_phase)


func _run_tests() -> void:
	current_phase = "setup"
	_setup_runtime()
	current_phase = "combo"
	if not _test_combo_milestone_and_break():
		return
	current_phase = "boss"
	if not _test_boss_intro_signal():
		return
	current_phase = "weapon_feedback"
	if not _test_weapon_hit_feedback():
		return
	current_phase = "level_ritual"
	if not _test_level_up_ritual():
		return

	current_phase = "done"
	print("R13_REGRESSION_PASS")
	get_tree().quit(0)


func _setup_runtime() -> void:
	EntityFactory.initialize_for_arena(self)
	player = CharacterBody2D.new()
	player.name = "R13Player"
	player.global_position = Vector2.ZERO
	player.add_to_group("heroes")
	add_child(player)
	GameManager.start_run(self, player, null, false)
	GameManager.waiting_for_contract = false
	GameManager.game_running = true
	if not GameManager.combo_milestone_requested.is_connected(_on_combo_milestone):
		GameManager.combo_milestone_requested.connect(_on_combo_milestone)
	if not GameManager.combo_break_requested.is_connected(_on_combo_break):
		GameManager.combo_break_requested.connect(_on_combo_break)
	if not GameManager.boss_intro_requested.is_connected(_on_boss_intro):
		GameManager.boss_intro_requested.connect(_on_boss_intro)


func _test_combo_milestone_and_break() -> bool:
	milestone_count = 0
	break_count = 0
	for _index in range(25):
		GameManager.elapsed_time += 0.12
		GameManager.add_kill()
	if milestone_count != 25:
		_fail("combo milestone 25 did not emit")
		return false
	if float(GameManager.get("combo_fire_rate_timer")) < 4.9:
		_fail("combo fire-rate buff timer missing")
		return false
	if float(GameManager.get_fire_rate_multiplier(player)) < 1.09:
		_fail("combo fire-rate multiplier not applied")
		return false
	GameManager._process(1.22)
	if break_count != 25:
		_fail("combo break fade signal did not emit")
		return false
	print("R13_COMBO milestone=%d fire_rate=%.2f break=%d" % [
		milestone_count,
		float(GameManager.get_fire_rate_multiplier(player)),
		break_count
	])
	return true


func _test_boss_intro_signal() -> bool:
	boss_intro_name = ""
	GameManager.record_boss_spawn("TEST BOSS")
	if boss_intro_name != "TEST BOSS":
		_fail("boss intro signal missing")
		return false
	print("R13_BOSS_INTRO name=" + boss_intro_name)
	return true


func _test_weapon_hit_feedback() -> bool:
	var enemy := EntityFactory.spawn_enemy("r13_enemy", _enemy_config(), Vector2(42.0, 0.0))
	if enemy == null:
		_fail("failed to spawn enemy for hit feedback")
		return false
	var before_position: Vector2 = enemy.global_position
	var projectile := EntityFactory.spawn_projectile(Vector2.ZERO, Vector2.RIGHT, _riftline_projectile_stats(), player)
	if projectile == null:
		_fail("failed to spawn riftline projectile")
		return false
	projectile._on_body_entered(enemy)
	var pushed_distance := before_position.distance_to(enemy.global_position)
	if pushed_distance < 3.8 or pushed_distance > 8.4:
		_fail("riftline knockback outside 4-8px range: %.2f" % pushed_distance)
		return false
	EntityFactory.release_projectile(projectile)

	var death_bursts_before := EntityFactory.get_pool_live_count("death_burst")
	var missile := EntityFactory.spawn_projectile(Vector2.ZERO, Vector2.RIGHT, _missile_projectile_stats(), player)
	if missile == null:
		_fail("failed to spawn missile projectile")
		return false
	missile._on_body_entered(enemy)
	var death_bursts_after := EntityFactory.get_pool_live_count("death_burst")
	if death_bursts_after - death_bursts_before < 2:
		_fail("missile hit did not spawn burst plus smoke ring")
		return false
	EntityFactory.release_projectile(missile)

	var arc := EntityFactory.spawn_lightning_arc([Vector2.ZERO, Vector2(80.0, 0.0)], Color.WHITE, 0.12, "res://assets/sprites/proj_lightning.png", 36.0)
	if arc == null or abs(float(arc.get("arc_width")) - 36.0) > 0.01:
		_fail("lightning arc width not applied")
		return false
	print("R13_WEAPON_FEEL knockback=%.2f missile_bursts=%d arc_width=%.1f" % [
		pushed_distance,
		death_bursts_after - death_bursts_before,
		float(arc.get("arc_width")) if arc != null else 0.0
	])
	return true


func _test_level_up_ritual() -> bool:
	GameManager.waiting_for_upgrade = false
	GameManager.waiting_for_shop = false
	GameManager.waiting_for_contract = false
	GameManager.stage_victory_pending = false
	GameManager.xp = GameManager.xp_required - 1
	var before_count := EntityFactory.get_pool_live_count("death_burst")
	GameManager.add_xp(1)
	var after_count := EntityFactory.get_pool_live_count("death_burst")
	if after_count <= before_count:
		_fail("level-up ritual did not spawn pooled visual")
		return false
	print("R13_LEVEL_RITUAL death_burst_delta=%d" % [after_count - before_count])
	return true


func _enemy_config() -> Dictionary:
	return {
		"max_hp": 999.0,
		"speed": 0.0,
		"damage": 1.0,
		"xp": 0,
		"gold": 0,
		"radius": 12.0,
		"color": Color(0.8, 0.3, 0.3),
		"sprite_path": "res://assets/sprites/enemy_grunt.png",
		"sprite_scale": 1.0
	}


func _riftline_projectile_stats() -> Dictionary:
	return {
		"damage": 1.0,
		"range": 200.0,
		"projectile_speed": 0.0,
		"projectile_radius": 8.0,
		"pierce": 1,
		"color": Color(0.72, 1.0, 0.92),
		"projectile_sprite_path": "res://assets/sprites/proj_bullet.png",
		"source_weapon_id": "riftline_emitter",
		"target_group": "enemies"
	}


func _missile_projectile_stats() -> Dictionary:
	var stats := _riftline_projectile_stats()
	stats["source_weapon_id"] = "rift_seeker_missiles"
	stats["motion_mode"] = "homing"
	stats["projectile_radius"] = 7.0
	stats["color"] = Color(1.0, 0.48, 0.22)
	return stats


func _on_combo_milestone(combo_count: int) -> void:
	milestone_count = combo_count


func _on_combo_break(combo_count: int) -> void:
	break_count = combo_count


func _on_boss_intro(boss_name: String) -> void:
	boss_intro_name = boss_name


func _fail(message: String) -> void:
	printerr("R13_REGRESSION_FAIL: " + message)
	get_tree().quit(1)
