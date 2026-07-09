extends "res://scripts/weapons/base_weapon.gd"

var orbiters: Array[Node] = []
var orbit_dirty: bool = true


func setup(player_node: Node2D, weapon_data: Resource) -> void:
	super.setup(player_node, weapon_data)
	orbit_dirty = true
	_sync_orbiters()


func _process(_delta: float) -> void:
	if owner_player == null or data == null or not GameManager.game_running:
		return
	if orbit_dirty:
		_sync_orbiters()


func _on_data_changed() -> void:
	orbit_dirty = true
	_sync_orbiters()


func mark_dirty() -> void:
	orbit_dirty = true


func _sync_orbiters() -> void:
	if owner_player == null or data == null:
		return

	var live_orbiters: Array[Node] = []
	for orbiter in orbiters:
		if orbiter != null and is_instance_valid(orbiter):
			live_orbiters.append(orbiter)
	orbiters = live_orbiters

	var desired_count: int = max(1, data_int("projectile_count", 1))
	var completed_sync := true
	while orbiters.size() < desired_count:
		var orbiter: Node = EntityFactory.spawn_orbit_projectile(owner_player, self, data_effect_stats(), orbiters.size(), desired_count)
		if orbiter == null:
			completed_sync = false
			break
		orbiters.append(orbiter)

	while orbiters.size() > desired_count:
		var extra: Node = orbiters.pop_back()
		if extra != null and is_instance_valid(extra):
			EntityFactory.release_orbit_projectile(extra)

	for index in range(orbiters.size()):
		var orbiter: Node = orbiters[index]
		if orbiter != null and is_instance_valid(orbiter) and orbiter.has_method("configure_orbit"):
			orbiter.configure_orbit(index, desired_count, data_effect_stats())

	orbit_dirty = not completed_sync


func register_orbit_hit() -> void:
	register_trigger()


func release_owned_nodes() -> void:
	for orbiter in orbiters:
		if orbiter != null and is_instance_valid(orbiter):
			EntityFactory.release_orbit_projectile(orbiter)
	orbiters.clear()


func _exit_tree() -> void:
	release_owned_nodes()
