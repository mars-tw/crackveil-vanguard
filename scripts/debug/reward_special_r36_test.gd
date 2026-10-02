extends Node

const ARENA := preload("res://scenes/arena/Arena.tscn")
const ELITES := preload("res://scripts/services/special_elite_catalog.gd")
const NODE_POOL := preload("res://scripts/pooling/node_pool.gd")
var failures: Array[String] = []


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _check(ok: bool, id: String, details: String) -> void:
	print("REWARD_SPECIAL_R36 %s=%s %s" % [id, "PASS" if ok else "FAIL", details])
	if not ok:
		failures.append(id)


func _run() -> void:
	GameManager.campaign_save_path = "user://r36_reward_special_review.cfg"
	GameManager.wallet_gold = 0
	GameManager.wallet_dirty = false
	PlayerSettings.debug_use_save_path("user://r36_reward_special_settings.cfg", true)
	MetaProgress.debug_use_save_path("user://r36_reward_special_meta.cfg", true)
	AchievementProgress.debug_use_save_path("user://r36_reward_special_achievement.cfg", true)
	var clean := ConfigFile.new()
	clean.set_value("pets", "collection", {})
	clean.save(GameManager.campaign_save_path.replace(".cfg", "_pets.cfg"))
	var arena := ARENA.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	var spawner: Node = arena.get_node("EnemySpawner")
	spawner.set_process(false)
	arena.get_node("LoopWorldTopology").set_physics_process(false)
	var hero: Node2D = GameManager.player
	for actor in get_tree().get_nodes_in_group("heroes"):
		actor.set_process(false)
		actor.set_physics_process(false)
		for child in actor.get_children():
			if child.is_in_group("hero_controllers"):
				child.set_physics_process(false)
		for weapon in (actor.get("weapons") as Dictionary).values():
			weapon.set_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		EntityFactory.release_enemy(enemy)
	GameManager.waiting_for_upgrade = false
	GameManager.waiting_for_contract = false
	GameManager.system_pause_owners.clear()
	GameManager.xp_required = 999999
	GameManager.critical_strikes_enabled = false
	get_tree().paused = false
	GameManager.contract_modifiers = {"elite_bonus_gold": 3}
	GameManager.next_elite_bonus_xp = 20
	spawner.debug_forced_special_elite_id = "flame"
	var spawned: bool = spawner.call("_spawn_elite")
	var flame: Node = null
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if str(enemy.get("special_elite_id")) == "flame":
			flame = enemy
	_check(spawned and flame != null, "REAL_SPECIAL_SPAWN", "actual EntityFactory spawn from production spawner")
	if flame != null:
		flame.set_physics_process(false)
		_check(int(flame.get("gold_value")) == 27 and int(flame.get("elite_bonus_xp")) == 44 and GameManager.next_elite_bonus_xp == 0, "CONTRACT_AND_LURE", "gold=%d expected=27 xp_bonus=%d expected=44 pending=%d expected=0" % [int(flame.get("gold_value")), int(flame.get("elite_bonus_xp")), GameManager.next_elite_bonus_xp])
		EntityFactory.release_enemy(flame)
	# A deliberately empty real NodePool exercises the production acquire
	# failure path without allocating hundreds of irrelevant enemies.
	var original_pool: RefCounted = EntityFactory.pools["enemy"]
	var empty_pool := NODE_POOL.new("enemy", EntityFactory.ENEMY_SCENE, EntityFactory.pool_root)
	EntityFactory.pools["enemy"] = empty_pool
	GameManager.next_elite_bonus_xp = 20
	var history_before: int = spawner.special_elite_history.size()
	var index_before: int = spawner.special_elite_index
	var failed_special: bool = spawner.call("_spawn_elite")
	_check(not failed_special and GameManager.next_elite_bonus_xp == 20 and spawner.special_elite_history.size() == history_before and spawner.special_elite_index == index_before, "EXHAUSTED_POOL_PRESERVES_LURE", "spawn=%s pending=%d history_unchanged=%s cycle_unchanged=%s exhausted=%d" % [failed_special, GameManager.next_elite_bonus_xp, spawner.special_elite_history.size() == history_before, spawner.special_elite_index == index_before, empty_pool.exhausted_count])
	spawner.debug_forced_elite_affix_id = "affix_split"
	var failed_legacy: bool = spawner.call("_spawn_elite")
	_check(not failed_legacy and GameManager.next_elite_bonus_xp == 20, "LEGACY_FAILURE_PRESERVES_LURE", "spawn=%s pending=%d" % [failed_legacy, GameManager.next_elite_bonus_xp])
	EntityFactory.pools["enemy"] = original_pool
	spawner.debug_forced_elite_affix_id = ""
	spawner.debug_forced_special_elite_id = ""
	var charge: Node2D = EntityFactory.spawn_enemy("review_charge", ELITES.make_config("charge", 240), hero.global_position + Vector2(200, 0))
	charge.set_physics_process(false)
	charge.call("_physics_special_elite", 0.02, hero)
	_check(str(charge.get("behavior_state")) == "windup" and charge.get("attack_telegraph").get("active") == true, "VISIBLE_CHARGE_WINDUP", "production dash branch entered windup with active cue")
	charge.call("take_damage", 1.0, hero.global_position)
	_check(str(charge.get("current_animation_name")) == "hurt" and str(charge.get("behavior_state")) == "recover" and charge.get("velocity") == Vector2.ZERO and charge.get("attack_telegraph").get("active") == false, "CHARGE_INTERRUPT", "animation=%s behavior=%s velocity=%s cue=%s" % [charge.get("current_animation_name"), charge.get("behavior_state"), charge.get("velocity"), charge.get("attack_telegraph").get("active")])
	for frame in range(40):
		await get_tree().process_frame
	charge.call("_physics_special_elite", 0.02, hero)
	_check(str(charge.get("behavior_state")) == "recover" and charge.get("velocity") == Vector2.ZERO, "NO_BLIND_DASH_AFTER_HURT", "behavior=%s velocity=%s" % [charge.get("behavior_state"), charge.get("velocity")])
	charge.call("_physics_process", 0.8)
	charge.call("_physics_process", 0.4)
	_check(str(charge.get("behavior_state")) == "windup" and charge.get("attack_telegraph").get("active") == true, "REQUIRES_FRESH_WINDUP", "behavior=%s cue=%s" % [charge.get("behavior_state"), charge.get("attack_telegraph").get("active")])
	EntityFactory.release_enemy(charge)
	charge = EntityFactory.spawn_enemy("review_charge_active", ELITES.make_config("charge", 240), hero.global_position + Vector2(200, 0))
	charge.set_physics_process(false)
	charge.call("_physics_process", 0.02)
	charge.call("_physics_process", 0.55)
	charge.call("_physics_process", 0.02)
	_check(str(charge.get("behavior_state")) == "dash" and (charge.get("velocity") as Vector2).length() > 500.0, "REAL_ACTIVE_DASH", "behavior=%s velocity=%s" % [charge.get("behavior_state"), charge.get("velocity")])
	charge.call("take_damage", 1.0, hero.global_position)
	_check(str(charge.get("current_animation_name")) == "hurt" and str(charge.get("behavior_state")) == "recover" and charge.get("velocity") == Vector2.ZERO, "ACTIVE_DASH_INTERRUPT", "animation=%s behavior=%s velocity=%s" % [charge.get("current_animation_name"), charge.get("behavior_state"), charge.get("velocity")])
	EntityFactory.release_enemy(charge)
	var shield: Node2D = EntityFactory.spawn_enemy("review_shield", ELITES.make_config("shield", 240), hero.global_position + Vector2(100, 0))
	shield.set_physics_process(false)
	shield.call("_start_attack", hero, 1.0, &"elite")
	var cue: Node2D = shield.get("attack_telegraph")
	_check(is_equal_approx(float(cue.get("reach")), 145.0) and cue.scale.is_equal_approx(Vector2.ONE) and cue.position.is_equal_approx(Vector2.ZERO), "SHIELD_CUE_MATCHES_DAMAGE", "reach=%s scale=%s position=%s expected=145/ONE/ZERO" % [cue.get("reach"), cue.scale, cue.position])
	var reused_id := shield.get_instance_id()
	EntityFactory.release_enemy(shield)
	var regular: Node = EntityFactory.spawn_enemy("review_regular_reuse", {"max_hp": 18.0, "speed": 0.0, "damage": 0.0, "xp": 0, "gold": 0, "radius": 11.0, "sprite_path":"res://assets/sprites/enemy_grunt.png"}, hero.global_position + Vector2(300, 0))
	_check(regular.get_instance_id() == reused_id and str(regular.get("special_elite_id")) == "" and str(regular.get("special_skill")) == "" and not bool(regular.get("special_shield_active")) and not bool(regular.get("special_label").get("visible")) and int(regular.get("special_gold_drops")) == 0, "POOLED_REGULAR_CLEARS_SPECIAL_STATE", "same_node=%s id=%s skill=%s shield=%s name_visible=%s gold_drop_counter=%s" % [regular.get_instance_id() == reused_id, regular.get("special_elite_id"), regular.get("special_skill"), regular.get("special_shield_active"), regular.get("special_label").get("visible"), regular.get("special_gold_drops")])
	EntityFactory.release_enemy(regular)
	GameManager.critical_strikes_enabled = true
	if failures.is_empty():
		print("REWARD_SPECIAL_R36_PASS contract_gold=true paid_lure=true failed_spawn_atomic=true charge_interrupt=true independent_context=true")
		get_tree().quit(0)
	else:
		printerr("REWARD_SPECIAL_R36_FAILURES=" + str(failures))
		get_tree().quit(1)
