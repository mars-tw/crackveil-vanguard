extends Node

const HERO_SCENE := preload("res://scenes/heroes/Hero.tscn")
const DATA := [preload("res://resources/heroes/rift_captain.tres"), preload("res://resources/heroes/arc_scout.tres"), preload("res://resources/heroes/orbit_guard.tres")]
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const PHONE := {"ua_mobile": true, "ua_phone": true, "touch_available": true, "mouse_available": false}

var failed := false
var members: Array[Node] = []
var shooters: Array[Node] = []
var targets: Array[Node] = []
var peak_projectiles := 0
var peak_forks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	MetaProgress.debug_use_save_path("user://r36_firepower_meta.cfg", true)
	AchievementProgress.debug_use_save_path("user://r36_firepower_achievement.cfg", true)
	GameManager.game_running = false
	EntityFactory.initialize_for_arena(self)
	for index in range(DATA.size()):
		var hero: Node = HERO_SCENE.instantiate()
		add_child(hero)
		hero.setup(DATA[index], null, index == 0, index)
		hero.position = Vector2(0.0, float(index - 1) * 24.0)
		hero.set_process(false)
		hero.set_physics_process(false)
		hero.set_auto_channel_enabled(false)
		for child in hero.get_children():
			if child.is_in_group("hero_controllers"):
				child.set_process(false)
				child.set_physics_process(false)
		for weapon in (hero.get("weapons") as Dictionary).values():
			weapon.set_process(false)
			weapon.set_physics_process(false)
		members.append(hero)
	shooters = [(members[0].get("weapons") as Dictionary)["riftline_emitter"], (members[1].get("weapons") as Dictionary)["rift_seeker_missiles"], (members[2].get("weapons") as Dictionary)["rift_shield_boomerang"]]
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.set_physics_process(false)
	GameManager.player = members[0]
	GameManager.squad_manager = null
	GameManager.system_pause_owners.clear()
	GameManager.game_running = true
	get_tree().paused = false
	for row_x in [340.0, 460.0]:
		for angle in [-15.0, -7.0, 7.0, 15.0]:
			var point := Vector2(row_x, tan(deg_to_rad(angle)) * row_x - 24.0)
			targets.append(_enemy(point))
	for weapon in shooters:
		weapon.reset_weapon()
		weapon.set_process(true)
	var clock_before := GameManager.elapsed_time
	while GameManager.elapsed_time - clock_before < 10.0:
		await get_tree().process_frame
		peak_projectiles = maxi(peak_projectiles, EntityFactory.get_pool_live_count("projectile"))
	var total := 0
	for weapon in shooters:
		weapon.set_process(false)
		var state: Dictionary = weapon.get_firepower_debug_state()
		total += int(state["projectiles_fired"])
		_assert(int(state["projectiles_rejected"]) == 0, "starter rejected logical projectiles: " + str(state["weapon_id"]))
		print("FIREPOWER_R36_EMISSION weapon=%s actual=%d seconds=%.3f bps=%.2f volley=%d rejected=%d" % [state["weapon_id"], int(state["projectiles_fired"]), float(state["seconds"]), float(state["projectiles_per_second"]), int(state["volley_size"]), int(state["projectiles_rejected"])])
	var elapsed := GameManager.elapsed_time - clock_before
	_assert(float(total) / elapsed >= 30.0 and float(total) / elapsed <= 45.0, "starter actual ten-second emission did not reach the promised 30-45 shots/s")
	var damaged := 0
	for target in targets:
		if float(target.get("hp")) < 1000000.0:
			damaged += 1
	_assert(damaged == 8, "the real fan did not hit all four lanes across both rows")
	var linear: Node = shooters[0]
	_assert(linear.apply_data_upgrade("weapon_projectiles") and int(linear.get_firepower_debug_state()["volley_size"]) == 16, "first count upgrade did not spawn sixteen-shot data")
	_assert(linear.apply_data_upgrade("weapon_projectiles") and int(linear.get_firepower_debug_state()["volley_size"]) == 20 and not linear.apply_data_upgrade("weapon_projectiles"), "count cap is not a real 12-16-20 progression")
	linear.apply_data_upgrade("riftline_fork")
	linear.apply_data_upgrade("riftline_fork")
	linear.set_process(true)
	clock_before = GameManager.elapsed_time
	while GameManager.elapsed_time - clock_before < 4.0:
		await get_tree().process_frame
		peak_projectiles = maxi(peak_projectiles, EntityFactory.get_pool_live_count("projectile"))
		peak_forks = maxi(peak_forks, EntityFactory.get_pool_live_count("fork_projectile"))
	linear.set_process(false)
	for column in range(9):
		for row in range(17):
			targets.append(_enemy(Vector2(200.0 + float(column) * 30.0, -184.0 + float(row) * 20.0)))
	_assert(linear.apply_data_upgrade("evo_rift_fan"), "wide-fan evolution failed")
	linear.set_process(true)
	clock_before = GameManager.elapsed_time
	while GameManager.elapsed_time - clock_before < 3.0:
		await get_tree().process_frame
		peak_projectiles = maxi(peak_projectiles, EntityFactory.get_pool_live_count("projectile"))
		peak_forks = maxi(peak_forks, EntityFactory.get_pool_live_count("fork_projectile"))
	linear.set_process(false)
	print("FIREPOWER_R36_PRESSURE actual_starter_bps=%.2f hits=%d lanes=4 rows=2 max_volley=20 peak_projectiles=%d peak_forks=%d fork_cap_skips=%d" % [float(total) / elapsed, damaged, peak_projectiles, peak_forks, EntityFactory.fork_projectile_cap_skips])
	_assert(EntityFactory.fork_projectile_cap_skips == 0, "dense evolved fan discarded fork damage at the old logical cap")
	_cleanup_projectiles()
	await get_tree().process_frame
	await get_tree().process_frame
	await _test_visual_budget_keeps_damage()
	if failed:
		return
	print("FIREPOWER_R36_PASS emission=actual ten_seconds=true four_lane_damage=true upgrades=12/16/20 cosmetic_cap_only=true hit_tokens=true cleanup=true")
	get_tree().quit(0)


func _test_visual_budget_keeps_damage() -> void:
	MOBILE.set_device_hints_override_for_tests(PHONE)
	var shots: Array[Node] = []
	var hidden: Node = null
	for index in range(200):
		var shot: Node = EntityFactory.spawn_projectile(Vector2(-1000.0, -1000.0), Vector2.RIGHT, {"source_weapon_id": "riftline_emitter", "damage": 16.0, "pierce": 2, "range": 800.0, "projectile_radius": 6.0}, members[0])
		_assert(shot != null, "logical pool exhausted before the phone's cosmetic stress scenario")
		if shot == null:
			return
		shots.append(shot)
		if bool(shot.get("cosmetic_suppressed")):
			hidden = shot
	_assert(hidden != null and Projectile.active_friendly_visuals == 180, "phone budget did not cap visible slots at 180")
	var target := _enemy(Vector2(100.0, 0.0))
	var before := float(target.get("hp"))
	hidden.call("_on_body_entered", target)
	var after := float(target.get("hp"))
	_assert(after < before and bool(hidden.get("monitoring")) and hidden.is_physics_processing(), "invisible overflow lost its real collision or damage")
	hidden.call("_on_body_entered", target)
	_assert(float(target.get("hp")) == after, "overflow hit registry damaged the same generation twice")
	var old_token := int(target.get_hit_token())
	EntityFactory.release_enemy(target)
	var reused := _enemy(Vector2(100.0, 0.0))
	_assert(int(reused.get_hit_token()) != old_token, "target pool token did not change")
	hidden.call("_on_body_entered", reused)
	_assert(float(reused.get("hp")) < 1000000.0, "overflow registry incorrectly blocked a new target generation")
	for shot in shots:
		EntityFactory.release_projectile(shot)
	EntityFactory.release_enemy(reused)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(Projectile.active_friendly_visuals == 0 and EntityFactory.get_pool_live_count("projectile") == 0 and EntityFactory.get_pool_live_count("fork_projectile") == 0, "projectile cleanup retained logical nodes or visible-slot reservations")
	MOBILE.set_device_hints_override_for_tests()
	print("FIREPOWER_R36_LOD logical=200 phone_visible=180 hidden_real_damage=true same_generation_once=true recycled_generation_hits=true release_visible_slots=0")


func _cleanup_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		if str(projectile.get_meta("_node_pool_name", "")) == "orbit_projectile":
			EntityFactory.release_orbit_projectile(projectile)
		else:
			EntityFactory.release_projectile(projectile)


func _enemy(point: Vector2) -> Node:
	var enemy: Node = EntityFactory.spawn_enemy("r36_firepower_fixture", {"max_hp": 1000000.0, "speed": 0.0, "damage": 0.0, "xp": 0, "gold": 0, "radius": 13.0, "sprite_path": "res://assets/sprites/enemy_grunt.png"}, point)
	enemy.set_physics_process(false)
	return enemy


func _assert(condition: bool, message: String) -> void:
	if condition or failed:
		return
	failed = true
	printerr("FIREPOWER_R36_FAIL: " + message)
	get_tree().quit(1)
