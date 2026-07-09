extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena/Arena.tscn")

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

	_prepare_heroes()

	if not _test_linear_projectile_spawn_token():
		return
	if not _test_orbit_projectile_spawn_token():
		return
	await get_tree().process_frame
	var double_release_ok: bool = await _test_double_release_guard()
	if not double_release_ok:
		return

	print("POOL_CONTRACT_PASS")
	get_tree().quit(0)


func _prepare_heroes() -> void:
	var members: Array = []
	if GameManager.squad_manager != null and is_instance_valid(GameManager.squad_manager) and GameManager.squad_manager.has_method("get_members"):
		members = GameManager.squad_manager.get_members()
	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		member.set("max_hp", 99999.0)
		member.set("current_hp", 99999.0)
		member.set("invulnerability_timer", 0.0)


func _test_linear_projectile_spawn_token() -> bool:
	var config := _enemy_config(30.0)
	var enemy_a := EntityFactory.spawn_enemy("contract_linear", config, leader.global_position + Vector2(140.0, 0.0))
	if enemy_a == null:
		_fail("linear test enemy A spawn failed")
		return false

	var enemy_instance_id := enemy_a.get_instance_id()
	var token_a := int(enemy_a.get_hit_token())
	var projectile := EntityFactory.spawn_projectile(enemy_a.global_position - Vector2(20.0, 0.0), Vector2.RIGHT, _projectile_stats(), leader)
	if projectile == null:
		_fail("linear test projectile spawn failed")
		return false

	var hp_a_before: float = float(enemy_a.get("hp"))
	projectile._on_body_entered(enemy_a)
	if float(enemy_a.get("hp")) >= hp_a_before:
		_fail("linear projectile did not damage enemy A")
		return false

	EntityFactory.release_enemy(enemy_a)
	var enemy_b := EntityFactory.spawn_enemy("contract_linear", config, leader.global_position + Vector2(140.0, 0.0))
	if enemy_b == null:
		_fail("linear test enemy B spawn failed")
		return false
	if enemy_b.get_instance_id() != enemy_instance_id:
		_fail("linear test did not reuse the same enemy node")
		return false

	var token_b := int(enemy_b.get_hit_token())
	if token_b == token_a:
		_fail("enemy spawn token did not change after reuse")
		return false

	var hp_b_before: float = float(enemy_b.get("hp"))
	projectile._on_body_entered(enemy_b)
	if float(enemy_b.get("hp")) >= hp_b_before:
		_fail("linear projectile treated reused enemy as already hit")
		return false

	EntityFactory.release_projectile(projectile)
	EntityFactory.release_enemy(enemy_b)
	print("POOL_CONTRACT_LINEAR token_a=%d token_b=%d reused_instance=true" % [token_a, token_b])
	return true


func _test_orbit_projectile_spawn_token() -> bool:
	var config := _enemy_config(32.0)
	var enemy_a := EntityFactory.spawn_enemy("contract_orbit", config, leader.global_position + Vector2(180.0, 20.0))
	if enemy_a == null:
		_fail("orbit test enemy A spawn failed")
		return false

	var enemy_instance_id := enemy_a.get_instance_id()
	var token_a := int(enemy_a.get_hit_token())
	var orbit := EntityFactory.spawn_orbit_projectile(leader, self, _orbit_stats(), 0, 1)
	if orbit == null:
		_fail("orbit projectile spawn failed")
		return false

	orbit.global_position = enemy_a.global_position
	var hp_a_before: float = float(enemy_a.get("hp"))
	orbit._damage_overlapping_enemies()
	if float(enemy_a.get("hp")) >= hp_a_before:
		_fail("orbit projectile did not damage enemy A")
		return false

	EntityFactory.release_enemy(enemy_a)
	var enemy_b := EntityFactory.spawn_enemy("contract_orbit", config, leader.global_position + Vector2(180.0, 20.0))
	if enemy_b == null:
		_fail("orbit test enemy B spawn failed")
		return false
	if enemy_b.get_instance_id() != enemy_instance_id:
		_fail("orbit test did not reuse the same enemy node")
		return false

	var token_b := int(enemy_b.get_hit_token())
	if token_b == token_a:
		_fail("orbit enemy spawn token did not change after reuse")
		return false

	orbit.global_position = enemy_b.global_position
	var hp_b_before: float = float(enemy_b.get("hp"))
	orbit._damage_overlapping_enemies()
	if float(enemy_b.get("hp")) >= hp_b_before:
		_fail("orbit projectile treated reused enemy as cooling down")
		return false

	EntityFactory.release_orbit_projectile(orbit)
	EntityFactory.release_enemy(enemy_b)
	print("POOL_CONTRACT_ORBIT token_a=%d token_b=%d reused_instance=true" % [token_a, token_b])
	return true


func _test_double_release_guard() -> bool:
	var projectile := EntityFactory.spawn_projectile(leader.global_position, Vector2.RIGHT, _projectile_stats(), leader)
	if projectile == null:
		_fail("double-release projectile spawn failed")
		return false

	var stats_before: Dictionary = EntityFactory.get_pool_stats()
	var before_duplicates := int(stats_before.get("projectile", {}).get("duplicate_releases", 0))
	EntityFactory.release_projectile(projectile)
	EntityFactory.release_projectile(projectile)
	await get_tree().process_frame
	await get_tree().process_frame

	var stats_after_release: Dictionary = EntityFactory.get_pool_stats()
	var projectile_stats: Dictionary = stats_after_release.get("projectile", {})
	if int(projectile_stats.get("duplicate_releases", 0)) <= before_duplicates:
		_fail("double-release guard did not record duplicate release")
		return false
	if int(projectile_stats.get("duplicate_free", 0)) != 0:
		_fail("projectile free list contains duplicate entries")
		return false

	var first := EntityFactory.spawn_projectile(leader.global_position, Vector2.RIGHT, _projectile_stats(), leader)
	var second := EntityFactory.spawn_projectile(leader.global_position + Vector2(8.0, 0.0), Vector2.RIGHT, _projectile_stats(), leader)
	if first == null or second == null:
		_fail("double-release acquire check spawn failed")
		return false
	if first == second:
		_fail("pool acquired the same live projectile twice")
		return false

	EntityFactory.release_projectile(first)
	EntityFactory.release_projectile(second)
	await get_tree().process_frame
	print("POOL_CONTRACT_DOUBLE_RELEASE duplicate_releases=%d duplicate_free=0" % int(projectile_stats.get("duplicate_releases", 0)))
	return true


func register_orbit_hit() -> void:
	pass


func _enemy_config(hp: float) -> Dictionary:
	return {
		"max_hp": hp,
		"speed": 0.0,
		"damage": 0.0,
		"xp": 0,
		"gold": 0,
		"radius": 13.0,
		"color": Color(0.55, 0.78, 1.0),
		"attack_cooldown": 99.0
	}


func _projectile_stats() -> Dictionary:
	return {
		"damage": 5.0,
		"range": 10000.0,
		"projectile_speed": 0.0,
		"projectile_radius": 6.0,
		"pierce": 999,
		"color": Color(0.72, 0.95, 1.0)
	}


func _orbit_stats() -> Dictionary:
	return {
		"damage": 6.0,
		"projectile_radius": 16.0,
		"pierce": 0,
		"hit_interval": 99.0,
		"orbit_radius": 60.0,
		"orbit_angular_speed": 0.0,
		"color": Color(0.86, 0.92, 1.0)
	}


func _fail(message: String) -> void:
	printerr("POOL_CONTRACT_FAIL: " + message)
	get_tree().quit(1)
