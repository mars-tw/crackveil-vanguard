extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena/Arena.tscn")

var arena: Node = null
var squad_manager: Node = null
var leader: Node2D = null
var captain: Node2D = null
var orbit_weapon: Node = null
var target_enemy: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(10505)
	arena = ARENA_SCENE.instantiate()
	add_child(arena)
	call_deferred("_run_repro")


func _run_repro() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	squad_manager = arena.get_node_or_null("SquadManager")
	leader = GameManager.player
	captain = squad_manager.get_member_by_id("rift_captain") if squad_manager != null else null
	if captain == null or not is_instance_valid(captain):
		_fail("rift_captain not found")
		return

	var spawner := arena.get_node_or_null("EnemySpawner")
	if spawner != null:
		spawner.set_process(false)

	_prepare_repro_state()
	orbit_weapon = _weapon_node(captain, "orbit_blades")
	if orbit_weapon == null:
		_fail("captain orbit weapon not found")
		return
	_disable_non_orbit_weapons()

	var weapon_data: Resource = orbit_weapon.get("data")
	var radius := float(weapon_data.get("orbit_radius"))
	target_enemy = EntityFactory.spawn_enemy("orbit_repro_target", _target_config(), captain.global_position + Vector2(radius, 0.0))
	if target_enemy == null:
		_fail("target enemy spawn failed")
		return

	var hp_before := float(target_enemy.get("hp"))
	var trigger_before := int(orbit_weapon.get("trigger_count"))
	for _index in range(120):
		await get_tree().physics_frame
	var hp_after := float(target_enemy.get("hp"))
	var trigger_after := int(orbit_weapon.get("trigger_count"))

	if hp_after >= hp_before or trigger_after <= trigger_before:
		_fail("orbit blade did not damage target hp %.2f->%.2f triggers %d->%d" % [
			hp_before,
			hp_after,
			trigger_before,
			trigger_after
		])
		return

	print("ORBIT_REPRO_PASS radius=%.1f hp %.2f->%.2f triggers %d->%d active=%s" % [
		radius,
		hp_before,
		hp_after,
		trigger_before,
		trigger_after,
		str(bool(target_enemy.get("is_active")))
	])
	get_tree().quit(0)


func _prepare_repro_state() -> void:
	get_tree().paused = false
	GameManager.game_running = true
	GameManager.is_game_over = false
	GameManager.waiting_for_contract = false
	GameManager.waiting_for_upgrade = false
	GameManager.waiting_for_shop = false
	GameManager.stage_victory_pending = false
	GameManager.system_pause_owners.clear()
	GameManager.player = leader
	GameManager.squad_manager = squad_manager
	if leader != null:
		leader.global_position = Vector2.ZERO
	if captain != null:
		captain.global_position = Vector2.ZERO
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


func _disable_non_orbit_weapons() -> void:
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


func _target_config() -> Dictionary:
	return {
		"max_hp": 80.0,
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
	printerr("ORBIT_REPRO_FAIL: " + message)
	get_tree().quit(1)
