extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena/Arena.tscn")

var arena: Node = null
var squad_manager: Node = null
var leader: Node2D = null
var current_phase: String = "boot"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(11011)
	call_deferred("_watchdog")
	call_deferred("_run_tests")


func _watchdog() -> void:
	await get_tree().create_timer(18.0, true).timeout
	if current_phase != "done":
		_fail("watchdog timeout at phase: " + current_phase)


func _run_tests() -> void:
	current_phase = "setup"
	arena = ARENA_SCENE.instantiate()
	add_child(arena)
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

	current_phase = "loadout"
	if not _test_r11_loadout():
		return
	current_phase = "new_weapons"
	if not await _test_new_weapon_hits():
		return
	current_phase = "boomerang_hit_table"
	if not _test_boomerang_rebound_hit_table():
		return
	current_phase = "evolution_stats"
	if not _test_evolution_stats_apply_once():
		return
	current_phase = "upgrade_pool"
	if not _test_upgrade_choices_keep_non_leader_card():
		return
	current_phase = "animation"
	if not await _test_procedural_animation_changes_transforms():
		return
	current_phase = "group_scan"
	var pool_stats: Dictionary = EntityFactory.get_pool_stats()
	if int(pool_stats.get("enemy_group_scans", 0)) != 0:
		_fail("R11 introduced enemy group scans")
		return

	current_phase = "done"
	print("R11_REGRESSION_PASS pool_stats=" + JSON.stringify({
		"enemy_queries": int(pool_stats.get("enemy_queries", 0)),
		"enemy_group_scans": int(pool_stats.get("enemy_group_scans", 0))
	}))
	get_tree().quit(0)


func _prepare_run_state() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	GameManager.game_running = true
	GameManager.is_game_over = false
	GameManager.waiting_for_contract = false
	GameManager.waiting_for_upgrade = false
	GameManager.waiting_for_shop = false
	GameManager.stage_victory_pending = false
	GameManager.manual_paused = false
	GameManager.system_pause_owners.clear()
	GameManager.level = 7
	GameManager.xp = 0
	GameManager.xp_required = 99999999
	GameManager.player = leader
	GameManager.squad_manager = squad_manager
	EntityFactory.reset_debug_counters()


func _test_r11_loadout() -> bool:
	var captain: Node = squad_manager.get_member_by_id("rift_captain")
	var guard: Node = squad_manager.get_member_by_id("orbit_guard")
	var scout: Node = squad_manager.get_member_by_id("arc_scout")
	if captain == null or guard == null or scout == null:
		_fail("starting squad missing R11 members")
		return false
	if not _has_weapon(captain, "riftline_emitter") or not _has_weapon(captain, "orbit_blades") or not _has_weapon(captain, "arc_chain"):
		_fail("captain does not carry all three flagship weapons")
		return false
	if not _has_weapon(guard, "rift_shield_boomerang") or _has_weapon(guard, "orbit_blades"):
		_fail("orbit_guard weapon transfer failed")
		return false
	if not _has_weapon(scout, "rift_seeker_missiles") or _has_weapon(scout, "arc_chain"):
		_fail("arc_scout weapon transfer failed")
		return false
	print("R11_LOADOUT captain=riftline+orbit+chain guard=boomerang scout=missiles")
	return true


func _test_new_weapon_hits() -> bool:
	_release_active_enemies()
	var guard: Node = squad_manager.get_member_by_id("orbit_guard")
	var scout: Node = squad_manager.get_member_by_id("arc_scout")
	if guard == null or scout == null:
		_fail("new weapon owners missing")
		return false

	_disable_all_weapons_except(guard, "rift_shield_boomerang")
	guard.global_position = Vector2.ZERO
	var boomerang_weapon := _weapon_node(guard, "rift_shield_boomerang")
	var boomerang_target := EntityFactory.spawn_enemy("r11_boomerang_target", _target_config(140.0), Vector2(190.0, 0.0))
	var boomerang_hp_before: float = float(boomerang_target.get("hp"))
	for _index in range(150):
		await get_tree().physics_frame
	var boomerang_hp_after: float = float(boomerang_target.get("hp"))
	if boomerang_hp_after >= boomerang_hp_before or int(boomerang_weapon.get("trigger_count")) <= 0:
		_fail("boomerang weapon did not damage target")
		return false

	_release_active_enemies()
	_disable_all_weapons_except(scout, "rift_seeker_missiles")
	scout.global_position = Vector2.ZERO
	var missile_weapon := _weapon_node(scout, "rift_seeker_missiles")
	var missile_target := EntityFactory.spawn_enemy("r11_missile_target", _target_config(120.0), Vector2(240.0, 80.0))
	var missile_hp_before: float = float(missile_target.get("hp"))
	for _index in range(140):
		await get_tree().physics_frame
	var missile_hp_after: float = float(missile_target.get("hp"))
	if missile_hp_after >= missile_hp_before or int(missile_weapon.get("trigger_count")) <= 0:
		_fail("homing missile weapon did not damage target")
		return false
	print("R11_NEW_WEAPONS boomerang_hp %.1f->%.1f missile_hp %.1f->%.1f" % [
		boomerang_hp_before,
		boomerang_hp_after,
		missile_hp_before,
		missile_hp_after
	])
	return true


func _test_boomerang_rebound_hit_table() -> bool:
	_release_active_enemies()
	var guard: Node = squad_manager.get_member_by_id("orbit_guard")
	if guard == null:
		_fail("boomerang rebound owner missing")
		return false
	var enemy := EntityFactory.spawn_enemy("r11_boomerang_rebound_target", _target_config(80.0), guard.global_position + Vector2(160.0, 0.0))
	if enemy == null:
		_fail("boomerang rebound target spawn failed")
		return false

	var base_stats := _manual_boomerang_stats(0)
	var base_projectile := EntityFactory.spawn_projectile(enemy.global_position, Vector2.RIGHT, base_stats, guard)
	if base_projectile == null:
		_fail("base boomerang projectile spawn failed")
		return false
	var base_hp_before: float = float(enemy.get("hp"))
	base_projectile._on_body_entered(enemy)
	var base_hp_after_first: float = float(enemy.get("hp"))
	base_projectile._on_body_entered(enemy)
	var base_hp_after_second: float = float(enemy.get("hp"))
	if base_hp_after_first >= base_hp_before or not is_equal_approx(base_hp_after_second, base_hp_after_first):
		_fail("base boomerang hit table contract failed")
		return false
	EntityFactory.release_projectile(base_projectile)

	var rebound_stats := _manual_boomerang_stats(1)
	var rebound_projectile := EntityFactory.spawn_projectile(enemy.global_position, Vector2.RIGHT, rebound_stats, guard)
	if rebound_projectile == null:
		_fail("rebound boomerang projectile spawn failed")
		return false
	var rebound_hp_before: float = float(enemy.get("hp"))
	rebound_projectile._on_body_entered(enemy)
	var rebound_hp_after_out: float = float(enemy.get("hp"))
	rebound_projectile.set("traveled", float(rebound_stats.get("range")) * 0.53)
	rebound_projectile._tick_boomerang(0.016)
	if not bool(rebound_projectile.get("boomerang_returning")):
		_fail("rebound boomerang did not enter return state")
		return false
	rebound_projectile._on_body_entered(enemy)
	var rebound_hp_after_return: float = float(enemy.get("hp"))
	if rebound_hp_after_out >= rebound_hp_before or rebound_hp_after_return >= rebound_hp_after_out:
		_fail("rebound boomerang did not allow return hit")
		return false
	EntityFactory.release_projectile(rebound_projectile)
	EntityFactory.release_enemy(enemy)
	print("R11_BOOMERANG_HIT_TABLE base_second_blocked=true rebound_return_hit=true")
	return true


func _test_evolution_stats_apply_once() -> bool:
	var guard: Node = squad_manager.get_member_by_id("orbit_guard")
	var scout: Node = squad_manager.get_member_by_id("arc_scout")
	if guard == null or scout == null:
		_fail("evolution stat owners missing")
		return false

	var boomerang_weapon := _weapon_node(guard, "rift_shield_boomerang")
	if boomerang_weapon == null:
		_fail("boomerang weapon missing for evolution stat test")
		return false
	boomerang_weapon.apply_data_upgrade("boomerang_rebound")
	boomerang_weapon.apply_data_upgrade("boomerang_rebound")
	boomerang_weapon.apply_data_upgrade("evo_razor_bulwark")
	var boomerang_data: Resource = boomerang_weapon.get("data")
	var boomerang_stats: Dictionary = boomerang_weapon._projectile_stats_for_fire()
	var expected_pierce := int(boomerang_data.get("pierce")) + int(boomerang_data.get_modifier_level("boomerang_rebound"))
	var actual_pierce := int(boomerang_stats.get("pierce", -1))
	if actual_pierce != expected_pierce:
		_fail("evo razor pierce applied more than once: expected %d got %d" % [expected_pierce, actual_pierce])
		return false

	var missile_weapon := _weapon_node(scout, "rift_seeker_missiles")
	if missile_weapon == null:
		_fail("missile weapon missing for evolution stat test")
		return false
	missile_weapon.apply_data_upgrade("missile_guidance")
	missile_weapon.apply_data_upgrade("missile_guidance")
	missile_weapon.apply_data_upgrade("evo_hunter_swarm")
	var dummy_target := Node2D.new()
	add_child(dummy_target)
	dummy_target.global_position = scout.global_position + Vector2(240.0, 0.0)
	var missile_data: Resource = missile_weapon.get("data")
	var missile_stats: Dictionary = missile_weapon._projectile_stats_for_fire(dummy_target)
	dummy_target.queue_free()
	var expected_turn_rate := float(missile_data.get("homing_turn_rate")) + float(missile_data.get_modifier_level("missile_guidance")) * 1.1
	var actual_turn_rate := float(missile_stats.get("homing_turn_rate", -1.0))
	if abs(actual_turn_rate - expected_turn_rate) > 0.001:
		_fail("evo hunter turn_rate applied more than once: expected %.3f got %.3f" % [expected_turn_rate, actual_turn_rate])
		return false

	print("R11_EVOLUTION_STATS pierce=%d turn_rate=%.2f" % [actual_pierce, actual_turn_rate])
	return true


func _test_upgrade_choices_keep_non_leader_card() -> bool:
	var pool: Array = [
		{
			"id": "upgrade_hero_weapon",
			"hero_id": "rift_captain",
			"weapon_id": "riftline_emitter",
			"upgrade_kind": "weapon_damage",
			"weight": 100.0
		},
		{
			"id": "upgrade_hero_weapon",
			"hero_id": "rift_captain",
			"weapon_id": "orbit_blades",
			"upgrade_kind": "weapon_damage",
			"weight": 100.0
		},
		{
			"id": "upgrade_hero_weapon",
			"hero_id": "rift_captain",
			"weapon_id": "arc_chain",
			"upgrade_kind": "weapon_damage",
			"weight": 100.0
		},
		{
			"id": "upgrade_hero_weapon",
			"hero_id": "orbit_guard",
			"weapon_id": "rift_shield_boomerang",
			"upgrade_kind": "weapon_damage",
			"weight": 0.1
		}
	]
	for index in range(40):
		seed(12000 + index)
		var choices: Array = GameManager._pick_upgrade_choices(pool, 3)
		if choices.size() != 3:
			_fail("pool guard returned wrong choice count")
			return false
		if not _choices_have_non_leader_card(choices):
			_fail("pool guard allowed all-leader three-choice hand")
			return false
	print("R11_POOL_HEALTH nonleader_three_choice_guard=true")
	return true


func _test_procedural_animation_changes_transforms() -> bool:
	var visual := leader.get_node_or_null("Visual")
	if visual == null:
		_fail("leader visual missing")
		return false
	var sprite: Sprite2D = visual.get("sprite")
	if sprite == null:
		_fail("leader sprite missing")
		return false
	var animated_sprite: AnimatedSprite2D = visual.get("animated_sprite")
	if animated_sprite == null or animated_sprite.sprite_frames == null or animated_sprite.sprite_frames.get_frame_count("walk") < 3:
		_fail("leader animated walk frames missing")
		return false
	var start_y := sprite.position.y
	GameManager.set_touch_move_vector(Vector2.RIGHT)
	for _index in range(18):
		await get_tree().physics_frame
		await get_tree().process_frame
	var moved_y := sprite.position.y
	var moved_rotation := sprite.rotation
	GameManager.set_touch_move_vector(Vector2.ZERO)
	leader.set_desired_velocity(Vector2.ZERO)
	if abs(moved_y - start_y) < 0.05 and abs(moved_rotation) < 0.01:
		_fail("leader procedural animation did not change transform")
		return false
	if str(animated_sprite.animation) != "walk":
		_fail("leader animated sprite did not switch to walk")
		return false

	var enemy := EntityFactory.spawn_enemy("r11_anim_fast", _moving_enemy_config(), leader.global_position + Vector2(220.0, 0.0))
	var enemy_sprite: Sprite2D = enemy.get("sprite")
	var enemy_animated_sprite: AnimatedSprite2D = enemy.get("animated_sprite")
	if enemy_animated_sprite == null or enemy_animated_sprite.sprite_frames == null or enemy_animated_sprite.sprite_frames.get_frame_count("walk") < 2:
		_fail("enemy animated walk frames missing")
		return false
	var enemy_start_y := enemy_sprite.position.y
	var enemy_max_bob := 0.0
	for _index in range(18):
		await get_tree().physics_frame
		await get_tree().process_frame
		enemy_max_bob = maxf(enemy_max_bob, abs(enemy_sprite.position.y - enemy_start_y))
	var enemy_moved_y := enemy_sprite.position.y
	if enemy_max_bob < 0.05:
		_fail("enemy procedural animation did not bob")
		return false
	if str(enemy_animated_sprite.animation) != "walk":
		_fail("enemy animated sprite did not switch to walk")
		return false
	print("R11_ANIMATION leader_y %.2f->%.2f tilt=%.3f enemy_y %.2f->%.2f max_bob=%.2f" % [
		start_y,
		moved_y,
		moved_rotation,
		enemy_start_y,
		enemy_moved_y,
		enemy_max_bob
	])
	return true


func _has_weapon(hero: Node, weapon_id: String) -> bool:
	var weapons: Dictionary = hero.get("weapons")
	return weapons.has(weapon_id)


func _weapon_node(hero: Node, weapon_id: String) -> Node:
	var weapons: Dictionary = hero.get("weapons")
	return weapons.get(weapon_id)


func _choices_have_non_leader_card(choices: Array) -> bool:
	for choice in choices:
		if not GameManager._is_leader_upgrade_option(choice):
			return true
	return false


func _disable_all_weapons_except(owner: Node, kept_weapon_id: String) -> void:
	var members: Array = squad_manager.get_members()
	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		var weapons: Dictionary = member.get("weapons")
		for weapon_id in weapons.keys():
			var weapon: Node = weapons.get(weapon_id)
			if weapon == null or not is_instance_valid(weapon):
				continue
			var keep: bool = member == owner and str(weapon_id) == kept_weapon_id
			weapon.set_process(keep)
			weapon.set_physics_process(keep)
			if not keep and weapon.has_method("release_owned_nodes"):
				weapon.release_owned_nodes()


func _release_active_enemies() -> void:
	var live_enemies: Array = EntityFactory.get("enemy_spatial_index").get("live_enemies")
	for enemy in live_enemies.duplicate():
		if enemy != null and is_instance_valid(enemy):
			EntityFactory.release_enemy(enemy)


func _target_config(hp_value: float) -> Dictionary:
	return {
		"max_hp": hp_value,
		"speed": 0.0,
		"damage": 0.0,
		"xp": 0,
		"gold": 0,
		"radius": 13.0,
		"color": Color(0.55, 0.78, 1.0),
		"sprite_path": "res://assets/sprites/enemy_grunt.png",
		"sprite_scale": 1.3,
		"attack_cooldown": 99.0
	}


func _moving_enemy_config() -> Dictionary:
	var config := _target_config(80.0)
	config["speed"] = 120.0
	config["behavior_id"] = "dasher"
	config["sprite_path"] = "res://assets/sprites/enemy_fast.png"
	config["sprite_scale"] = 1.25
	return config


func _manual_boomerang_stats(rebound_level: int) -> Dictionary:
	return {
		"damage": 5.0,
		"range": 200.0,
		"projectile_speed": 0.0,
		"projectile_radius": 8.0,
		"pierce": 10,
		"color": Color(0.78, 0.92, 1.0),
		"target_group": "enemies",
		"motion_mode": "boomerang",
		"boomerang_return_ratio": 0.52,
		"boomerang_catch_radius": 34.0,
		"boomerang_rebound_level": rebound_level
	}


func _fail(message: String) -> void:
	printerr("R11_REGRESSION_FAIL: " + message)
	get_tree().quit(1)
