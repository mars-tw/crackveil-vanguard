class_name NodePool
extends RefCounted

var pool_name: String = ""
var scene: PackedScene
var pool_root: Node
var free_list: Array[Node] = []
var live_list: Array[Node] = []
var live_count: int = 0
var total_created: int = 0
var exhausted_count: int = 0
var duplicate_release_count: int = 0
var rejected_foreign_release_count: int = 0
var _in_pool: Dictionary = {}


func _init(new_pool_name: String = "", new_scene: PackedScene = null, new_pool_root: Node = null) -> void:
	pool_name = new_pool_name
	scene = new_scene
	pool_root = new_pool_root


func warm(count: int) -> void:
	if scene == null or pool_root == null:
		return

	for _index in range(count):
		var node := scene.instantiate()
		total_created += 1
		pool_root.add_child(node)
		node.set_meta("_node_pool_name", pool_name)
		_deactivate_new_node(node)
		_in_pool[node.get_instance_id()] = true
		free_list.append(node)


func acquire(active_parent: Node) -> Node:
	var node: Node = null
	while not free_list.is_empty():
		var candidate: Node = free_list.pop_back()
		if candidate == null or not is_instance_valid(candidate):
			continue
		var candidate_id := candidate.get_instance_id()
		if not _in_pool.has(candidate_id):
			duplicate_release_count += 1
			push_warning("Pool free-list duplicate/live entry discarded: %s" % pool_name)
			continue
		_in_pool.erase(candidate_id)
		node = candidate
		break

	if node == null:
		exhausted_count += 1
		push_warning("Pool exhausted: %s. Spawn skipped to avoid hot-path instantiate." % pool_name)
		return null

	node.set_meta("_node_pool_name", pool_name)
	if node.get_parent() != active_parent:
		node.reparent(active_parent)
	if not live_list.has(node):
		live_list.append(node)
	live_count += 1
	if node.has_method("pool_on_acquire"):
		node.pool_on_acquire()
	return node


func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return

	var instance_id := node.get_instance_id()
	if str(node.get_meta("_node_pool_name", "")) != pool_name:
		rejected_foreign_release_count += 1
		push_warning("Pool rejected foreign release: %s got %s" % [pool_name, node.name])
		return
	if _in_pool.has(instance_id):
		duplicate_release_count += 1
		push_warning("Pool double release ignored: %s node=%s" % [pool_name, node.name])
		return

	if node.has_method("pool_on_release"):
		node.pool_on_release()
	if pool_root != null and node.get_parent() != pool_root:
		node.reparent(pool_root)
	live_list.erase(node)
	live_count = max(live_count - 1, 0)
	_in_pool[instance_id] = true
	free_list.append(node)


func get_free_count() -> int:
	return free_list.size()


func get_in_pool_count() -> int:
	return _in_pool.size()


func get_live_nodes() -> Array[Node]:
	var compacted: Array[Node] = []
	for node in live_list:
		if node != null and is_instance_valid(node):
			compacted.append(node)
	live_list = compacted
	live_count = live_list.size()
	return live_list.duplicate()


func get_duplicate_free_count() -> int:
	var seen: Dictionary = {}
	var duplicate_count := 0
	for node in free_list:
		if node == null or not is_instance_valid(node):
			continue
		var instance_id := node.get_instance_id()
		if seen.has(instance_id):
			duplicate_count += 1
		else:
			seen[instance_id] = true
	return duplicate_count


func _deactivate_new_node(node: Node) -> void:
	if node.has_method("pool_on_release"):
		node.pool_on_release()
	else:
		node.visible = false
		node.set_process(false)
		node.set_physics_process(false)
