extends Node

const ARENA := preload("res://scenes/arena/Arena.tscn")
const WORLD := preload("res://scripts/services/loop_world_topology.gd")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
var issues: Array[String] = []


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _record(ok: bool, id: String, detail: String) -> void:
	print("REVIEW_R36_ROOT %s=%s %s" % [id, "PASS" if ok else "ISSUE", detail])
	if not ok:
		issues.append(id)


func _run() -> void:
	GameManager.campaign_save_path = "user://r36_independent_root_review.cfg"
	GameManager.wallet_gold = 0
	GameManager.wallet_dirty = false
	GameManager.paid_summon.clear()
	PlayerSettings.debug_use_save_path("user://r36_independent_root_settings.cfg", true)
	MetaProgress.debug_use_save_path("user://r36_independent_root_meta.cfg", true)
	AchievementProgress.debug_use_save_path("user://r36_independent_root_achievement.cfg", true)
	var clean := ConfigFile.new()
	clean.set_value("pets", "collection", {})
	clean.save(GameManager.campaign_save_path.replace(".cfg", "_pets.cfg"))
	var arena: Node = ARENA.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	arena.get_node("EnemySpawner").set_process(false)
	var hero: Node = GameManager.player
	hero.set_auto_channel_enabled(false)
	for actor in get_tree().get_nodes_in_group("heroes"):
		actor.set_process(false)
		actor.set_physics_process(false)
		for child in actor.get_children():
			if child.is_in_group("hero_controllers"):
				child.set_process(false)
				child.set_physics_process(false)
		for weapon in (actor.get("weapons") as Dictionary).values():
			weapon.set_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	GameManager.waiting_for_upgrade = false
	GameManager.auto_upgrade_enabled = false
	GameManager.xp_required = 999999
	GameManager.system_pause_owners.clear()
	get_tree().paused = false
	var topology: Node = arena.get_node("LoopWorldTopology")
	topology.set_physics_process(false)
	MOBILE.set_device_hints_override_for_tests({"ua_mobile": true, "ua_tablet": true, "touch_available": true, "mouse_available": false})
	var tablet_zoom: Vector2 = hero.call("_leader_camera_zoom")
	var camera_view: Vector2 = hero.call("_camera_viewport_size")
	var ui_view := MOBILE.ui_layout_size(camera_view)
	print("REVIEW_R36_DEVICE actual_view=%s ui_view=%s tier=%d hints=%s" % [camera_view, ui_view, MOBILE.layout_tier(ui_view), MOBILE._runtime_device_hints()])
	_record(is_equal_approx(tablet_zoom.x, 1.12), "TABLET_ZOOM", "actual=%.2f expected=1.12" % tablet_zoom.x)
	MOBILE.set_device_hints_override_for_tests()
	hero.global_position = Vector2(4100.0, 3100.0)
	var enemy: Node = EntityFactory.spawn_enemy("review_rebase", {"max_hp": 9999.0, "speed": 0.0, "damage": 0.0, "radius": 13.0, "xp": 0, "gold": 0, "sprite_path": "res://assets/sprites/enemy_grunt.png"}, Vector2.ZERO)
	enemy.set_physics_process(false)
	var hazard: Node = EntityFactory.spawn_hazard_zone(Vector2.ZERO, {"area_radius": 10.0, "effect_lifetime": 10.0, "damage": 0.0}, hero)
	var construct: Node = EntityFactory.spawn_rift_construct(Vector2.ZERO, {"area_radius": 10.0, "effect_lifetime": 10.0, "damage": 0.0}, hero, null, 3)
	hazard.set_process(false)
	construct.set_process(false)
	topology.set("timer", 0.0)
	topology.call("_physics_process", 0.11)
	var expected := WORLD.nearest_image(Vector2.ZERO, hero.global_position)
	_record(enemy.global_position.is_equal_approx(expected), "ENEMY_REBASE", "enemy=%s expected=%s" % [enemy.global_position, expected])
	_record(EntityFactory.find_nearest_enemy(hero.global_position, 80.0) == enemy, "REBASE_INDEX_ATOMIC", "nearest query immediately after topology tick")
	_record(hazard.global_position.is_equal_approx(expected) and construct.global_position.is_equal_approx(expected), "PERSISTENT_GROUP_REBASE", "hazard=%s construct=%s expected=%s" % [hazard.global_position, construct.global_position, expected])
	EntityFactory.enemy_spatial_index.call("_update_enemy_cells")
	GameManager.add_gold(300)
	GameManager.open_summon_shop()
	GameManager.purchase_summon("skill")
	var token := str(GameManager.paid_summon.get("draw_id", ""))
	var director: Node = GameManager.summon_director
	var after_pay := GameManager.gold
	GameManager.complete_summon(token, 99)
	var keep_paid := not GameManager.paid_summon.is_empty() and GameManager.gold == after_pay
	var fully_aborted := GameManager.paid_summon.is_empty() and (director.get("pending") as Dictionary).is_empty() and GameManager.gold == after_pay + 80
	_record(keep_paid or fully_aborted, "INVALID_CHOICE_ATOMIC", "gm_paid=%s director_pending=%s gold=%d after_pay=%d" % [not GameManager.paid_summon.is_empty(), not (director.get("pending") as Dictionary).is_empty(), GameManager.gold, after_pay])
	if keep_paid:
		GameManager.complete_summon(token, 0)
	elif not fully_aborted:
		(director.get("pending") as Dictionary).clear()
		GameManager.paid_summon.clear()
	GameManager.close_summon_shop()
	var prior_path := GameManager.campaign_save_path
	GameManager.campaign_save_path = "user://r36_review_missing_directory/wallet.cfg"
	GameManager.wallet_dirty = true
	GameManager.call("_save_campaign")
	_record(GameManager.wallet_dirty, "FAILED_WALLET_SAVE_RETRY", "failed storage must retain dirty flag for retry")
	GameManager.campaign_save_path = prior_path
	GameManager.call("_save_campaign")
	print("REVIEW_R36_ROOT_RESULT issues=%s bounded_fixture=true production_unchanged=true independent_context=same_model" % [str(issues)])
	get_tree().quit(0 if issues.is_empty() else 1)
