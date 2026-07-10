extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena/Arena.tscn")
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/ui/MainMenu.tscn")

var arena: Node = null
var squad_manager: Node = null
var leader: Node2D = null
var current_phase: String = "boot"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(10505)
	call_deferred("_watchdog")
	call_deferred("_run_tests")


func _watchdog() -> void:
	await get_tree().create_timer(20.0, true).timeout
	if current_phase != "done":
		_fail("watchdog timeout at phase: " + current_phase)


func _run_tests() -> void:
	current_phase = "active_ability"
	if not await _test_active_ability_damage_and_cooldown():
		return
	current_phase = "orbit_hit"
	if not await _test_orbit_blade_hits_static_target():
		return
	current_phase = "pickup_scatter"
	if not await _test_pickup_scatter_then_magnet():
		return
	current_phase = "pickup_force_magnet"
	if not await _test_force_magnet_interrupts_scatter():
		return
	current_phase = "main_menu_flow"
	if not await _test_main_menu_and_return_wiring():
		return
	current_phase = "done"
	print("R10_5_REGRESSION_PASS")
	get_tree().quit(0)


func _setup_arena(prepare_state: bool = true) -> void:
	if arena != null and is_instance_valid(arena):
		await get_tree().process_frame
		await get_tree().physics_frame
		arena.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	arena = ARENA_SCENE.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	squad_manager = arena.get_node_or_null("SquadManager")
	leader = GameManager.player
	var spawner: Node = arena.get_node_or_null("EnemySpawner")
	if spawner != null:
		spawner.set_process(false)
	if prepare_state:
		_prepare_run_state()


func _prepare_run_state() -> void:
	get_tree().paused = false
	GameManager.game_running = true
	GameManager.is_game_over = false
	GameManager.waiting_for_contract = false
	GameManager.waiting_for_upgrade = false
	GameManager.waiting_for_shop = false
	GameManager.stage_victory_pending = false
	GameManager.manual_paused = false
	GameManager.system_pause_owners.clear()
	GameManager.player = leader
	GameManager.squad_manager = squad_manager
	GameManager.xp = 0
	GameManager.xp_required = 999999
	GameManager.level = 1
	if leader != null and is_instance_valid(leader):
		leader.global_position = Vector2.ZERO
		leader.set("last_move_direction", Vector2.RIGHT)


func _test_active_ability_damage_and_cooldown() -> bool:
	await _setup_arena()
	if leader == null or not is_instance_valid(leader):
		_fail("leader missing for active ability")
		return false
	var enemy: Node = EntityFactory.spawn_enemy("r10_pulse_target", _target_config(120.0), leader.global_position + Vector2(126.0, 0.0))
	if enemy == null:
		_fail("active ability target spawn failed")
		return false
	var hp_before: float = float(enemy.get("hp"))
	var cast_ok: bool = bool(leader.call("try_cast_active_ability"))
	await get_tree().physics_frame
	var hp_after: float = float(enemy.get("hp"))
	var cooldown_remaining: float = float(leader.call("get_active_ability_cooldown_remaining"))
	if not cast_ok or hp_after >= hp_before:
		_fail("rift pulse did not damage target hp %.2f->%.2f cast=%s" % [hp_before, hp_after, str(cast_ok)])
		return false
	if cooldown_remaining < 2.6:
		_fail("rift pulse cooldown too short: %.2f" % cooldown_remaining)
		return false
	if bool(leader.call("try_cast_active_ability")):
		_fail("rift pulse recast during cooldown")
		return false
	print("R10_5_ACTIVE_ABILITY hp %.2f->%.2f cooldown=%.2f" % [hp_before, hp_after, cooldown_remaining])
	return true


func _test_orbit_blade_hits_static_target() -> bool:
	await _setup_arena()
	var orbit_guard: Node = squad_manager.get_member_by_id("orbit_guard") if squad_manager != null else null
	if orbit_guard == null or not is_instance_valid(orbit_guard):
		_fail("orbit_guard missing")
		return false
	orbit_guard.global_position = Vector2.ZERO
	_disable_non_orbit_weapons(orbit_guard)
	_freeze_heroes()
	var orbit_weapon: Node = _weapon_node(orbit_guard, "orbit_blades")
	if orbit_weapon == null:
		_fail("orbit weapon missing")
		return false
	var weapon_data: Resource = orbit_weapon.get("data")
	var radius: float = float(weapon_data.get("orbit_radius"))
	var enemy: Node = EntityFactory.spawn_enemy("r10_orbit_target", _target_config(90.0), orbit_guard.global_position + Vector2(radius, 0.0))
	var hp_before: float = float(enemy.get("hp"))
	var trigger_before: int = int(orbit_weapon.get("trigger_count"))
	for _index in range(120):
		await get_tree().physics_frame
	var hp_after: float = float(enemy.get("hp"))
	var trigger_after: int = int(orbit_weapon.get("trigger_count"))
	if hp_after >= hp_before or trigger_after <= trigger_before:
		_fail("orbit blade no hit hp %.2f->%.2f triggers %d->%d" % [hp_before, hp_after, trigger_before, trigger_after])
		return false
	print("R10_5_ORBIT_HIT radius=%.1f hp %.2f->%.2f triggers %d->%d" % [radius, hp_before, hp_after, trigger_before, trigger_after])
	return true


func _test_pickup_scatter_then_magnet() -> bool:
	await _setup_arena()
	if leader == null or not is_instance_valid(leader):
		_fail("leader missing for pickup test")
		return false
	leader.set("pickup_radius", 180.0)
	GameManager.xp = 0
	var gem: Node = EntityFactory.spawn_xp_gem(leader.global_position + Vector2(18.0, 0.0), 5, 1.0)
	if gem == null:
		_fail("xp gem spawn failed")
		return false
	for _index in range(10):
		await get_tree().physics_frame
	if int(GameManager.xp) != 0:
		_fail("pickup collected during scatter delay")
		return false
	for _index in range(90):
		await get_tree().physics_frame
	if int(GameManager.xp) < 5:
		_fail("pickup did not magnetize after scatter, xp=%d" % int(GameManager.xp))
		return false
	print("R10_5_PICKUP_SCATTER xp=%d" % int(GameManager.xp))
	return true


func _test_force_magnet_interrupts_scatter() -> bool:
	await _setup_arena()
	if leader == null or not is_instance_valid(leader):
		_fail("leader missing for force magnet test")
		return false
	leader.set("pickup_radius", 8.0)
	GameManager.xp = 0
	var gem: Node = EntityFactory.spawn_xp_gem(leader.global_position + Vector2(72.0, 0.0), 7, 1.0)
	if gem == null:
		_fail("force magnet xp gem spawn failed")
		return false
	await get_tree().physics_frame
	if float(gem.get("scatter_timer")) <= 0.0:
		_fail("force magnet test gem had no scatter window")
		return false
	gem.call("force_magnet_to", leader)
	await get_tree().physics_frame
	if float(gem.get("scatter_timer")) > 0.0 or not bool(gem.get("magnetized")):
		_fail("force magnet did not interrupt scatter")
		return false
	for _index in range(60):
		if int(GameManager.xp) >= 7:
			break
		await get_tree().physics_frame
	if int(GameManager.xp) < 7:
		_fail("force magnet did not collect during scatter, xp=%d" % int(GameManager.xp))
		return false
	print("R10_5_FORCE_MAGNET_INTERRUPT xp=%d" % int(GameManager.xp))
	return true


func _test_main_menu_and_return_wiring() -> bool:
	var menu: Node = MAIN_MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	if menu.get("start_button") == null or menu.get("meta_button") == null or menu.get("achievements_button") == null or menu.get("settings_button") == null:
		_fail("main menu missing required buttons")
		return false
	var side_panel: Panel = menu.get("side_panel")
	if side_panel == null or side_panel.visible:
		_fail("main menu side panel did not start collapsed")
		return false
	var meta_button: Button = menu.get("meta_button")
	meta_button.pressed.emit()
	await get_tree().process_frame
	if not side_panel.visible:
		_fail("main menu meta button did not open side panel")
		return false
	var meta_buttons: Dictionary = menu.get("meta_buttons")
	if meta_buttons.size() != 3:
		_fail("main menu meta panel did not build three tracks")
		return false
	menu.queue_free()
	await _setup_arena(false)
	if GameManager.has_method("_request_contract"):
		GameManager.call("_request_contract")
		await get_tree().process_frame
	var contract_screen: Node = arena.get_node_or_null("ContractScreen")
	if contract_screen == null or not _screen_visible(contract_screen):
		_fail("arena did not open contract screen after start")
		return false
	GameManager.apply_contract({"id": "contract_blood_tax"})
	leader = GameManager.player
	GameManager.player_died()
	await get_tree().process_frame
	var game_over_screen: Node = arena.get_node_or_null("GameOverScreen")
	if game_over_screen == null or not _screen_visible(game_over_screen):
		_fail("death did not show game over")
		return false
	if not game_over_screen.has_signal("main_menu_requested") or not arena.has_method("_on_main_menu_requested"):
		_fail("return-to-main-menu wiring missing")
		return false
	print("R10_5_MENU_FLOW menu=true contract=true death=true return_signal=true")
	return true


func _disable_non_orbit_weapons(orbit_guard: Node) -> void:
	var orbit_weapon: Node = _weapon_node(orbit_guard, "orbit_blades")
	var members: Array = squad_manager.get_members() if squad_manager != null and squad_manager.has_method("get_members") else []
	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		var weapons: Dictionary = member.get("weapons")
		for weapon_id in weapons.keys():
			var weapon: Node = weapons.get(weapon_id)
			if weapon == null or not is_instance_valid(weapon) or weapon == orbit_weapon:
				continue
			weapon.set_process(false)
			weapon.set_physics_process(false)
			if weapon.has_method("release_owned_nodes"):
				weapon.release_owned_nodes()


func _freeze_heroes() -> void:
	var members: Array = squad_manager.get_members() if squad_manager != null and squad_manager.has_method("get_members") else []
	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		if member.has_method("set_desired_velocity"):
			member.set_desired_velocity(Vector2.ZERO)
		member.set_physics_process(false)
		for child in member.get_children():
			if child.is_in_group("hero_controllers"):
				child.set_physics_process(false)
				child.set_process(false)


func _weapon_node(hero: Node, weapon_id: String) -> Node:
	var weapons: Dictionary = hero.get("weapons")
	return weapons.get(weapon_id)


func _screen_visible(screen: Node) -> bool:
	var screen_root: Variant = screen.get("root")
	return screen_root is Control and (screen_root as Control).visible


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
		"sprite_scale": 1.0,
		"attack_cooldown": 99.0
	}


func _fail(message: String) -> void:
	printerr("R10_5_REGRESSION_FAIL: " + message)
	get_tree().quit(1)
