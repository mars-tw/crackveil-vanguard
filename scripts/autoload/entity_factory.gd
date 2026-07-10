extends Node

const NODE_POOL_SCRIPT: Script = preload("res://scripts/pooling/node_pool.gd")
const ENEMY_SPATIAL_INDEX_SCRIPT: Script = preload("res://scripts/services/enemy_spatial_index.gd")

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/Enemy.tscn")
const HERO_SCENE: PackedScene = preload("res://scenes/heroes/Hero.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/Projectile.tscn")
const ORBIT_PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/OrbitProjectile.tscn")
const EXPLOSION_AREA_SCENE: PackedScene = preload("res://scenes/projectiles/ExplosionArea.tscn")
const HAZARD_ZONE_SCENE: PackedScene = preload("res://scenes/projectiles/HazardZone.tscn")
const XP_GEM_SCENE: PackedScene = preload("res://scenes/pickups/XPGem.tscn")
const COIN_PICKUP_SCENE: PackedScene = preload("res://scenes/pickups/CoinPickup.tscn")
const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/vfx/DamageNumber.tscn")
const DEATH_BURST_SCENE: PackedScene = preload("res://scenes/vfx/DeathBurst.tscn")
const LIGHTNING_ARC_SCENE: PackedScene = preload("res://scenes/vfx/LightningArc.tscn")

const PREWARM_COUNTS: Dictionary = {
	"enemy": 220,
	"projectile": 240,
	"orbit_projectile": 40,
	"explosion": 80,
	"hazard_zone": 8,
	"xp_gem": 220,
	"coin": 220,
	"damage_number": 80,
	"death_burst": 28,
	"lightning_arc": 80
}

const DAMAGE_NUMBER_CAP := 64
const DAMAGE_NUMBER_MERGE_RADIUS := 48.0
const DAMAGE_NUMBER_MERGE_AGE := 0.24
const EXPLOSION_CAP := 36
const HAZARD_ZONE_CAP := 8
const ENEMY_PROJECTILE_CAP := 48
const DEATH_BURST_CAP := 20
const LIGHTNING_ARC_CAP := 32
const XP_GEM_CAP := 180
const COIN_CAP := 180

var pools: Dictionary = {}
var pool_root: Node = null
var enemy_spatial_index: Node = null
var next_enemy_spawn_token: int = 1
var enemy_group_scan_count: int = 0
var active_damage_numbers: Array[Node] = []
var active_enemy_projectiles: Array[Node] = []
var active_xp_gems: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enemy_spatial_index = ENEMY_SPATIAL_INDEX_SCRIPT.new()
	enemy_spatial_index.name = "EnemySpatialIndex"
	add_child(enemy_spatial_index)


func initialize_for_arena(arena: Node) -> void:
	if enemy_spatial_index != null and enemy_spatial_index.has_method("reset"):
		enemy_spatial_index.reset()

	pools.clear()
	active_damage_numbers.clear()
	active_enemy_projectiles.clear()
	active_xp_gems.clear()
	next_enemy_spawn_token = 1
	enemy_group_scan_count = 0
	pool_root = Node.new()
	pool_root.name = "Pools"
	arena.add_child(pool_root)

	_create_pool("enemy", ENEMY_SCENE)
	_create_pool("projectile", PROJECTILE_SCENE)
	_create_pool("orbit_projectile", ORBIT_PROJECTILE_SCENE)
	_create_pool("explosion", EXPLOSION_AREA_SCENE)
	_create_pool("hazard_zone", HAZARD_ZONE_SCENE)
	_create_pool("xp_gem", XP_GEM_SCENE)
	_create_pool("coin", COIN_PICKUP_SCENE)
	_create_pool("damage_number", DAMAGE_NUMBER_SCENE)
	_create_pool("death_burst", DEATH_BURST_SCENE)
	_create_pool("lightning_arc", LIGHTNING_ARC_SCENE)


func spawn_enemy(enemy_id: String, config: Dictionary, world_position: Vector2) -> Node:
	var enemy := _acquire("enemy")
	if enemy == null:
		return null
	enemy.pool_reset({
		"enemy_id": enemy_id,
		"config": config,
		"position": world_position,
		"spawn_token": _issue_enemy_spawn_token()
	})
	enemy_spatial_index.register(enemy)
	return enemy


func spawn_hero(hero_data: Resource, world_position: Vector2, is_leader: bool, squad_manager: Node, formation_index: int) -> Node:
	var hero := HERO_SCENE.instantiate()
	_get_runtime_parent().add_child(hero)
	hero.global_position = world_position
	if hero.has_method("setup"):
		hero.setup(hero_data, squad_manager, is_leader, formation_index)
	return hero


func spawn_projectile(world_position: Vector2, direction: Vector2, stats: Dictionary, source: Node) -> Node:
	var projectile := _acquire("projectile")
	if projectile == null:
		return null
	projectile.pool_reset({
		"position": world_position,
		"direction": direction,
		"stats": stats,
		"source": source
	})
	return projectile


func spawn_enemy_projectile(world_position: Vector2, direction: Vector2, stats: Dictionary, source: Node) -> Node:
	_compact_active_enemy_projectiles()
	if active_enemy_projectiles.size() >= ENEMY_PROJECTILE_CAP:
		return null
	var projectile := spawn_projectile(world_position, direction, stats, source)
	if projectile == null:
		return null
	active_enemy_projectiles.append(projectile)
	return projectile


func spawn_orbit_projectile(player_node: Node2D, weapon_node: Node, stats: Dictionary, index: int, total: int) -> Node:
	var projectile := _acquire("orbit_projectile")
	if projectile == null:
		return null
	projectile.pool_reset({
		"player": player_node,
		"weapon": weapon_node,
		"stats": stats,
		"index": index,
		"total": total
	})
	return projectile


func spawn_explosion(world_position: Vector2, stats: Dictionary, source: Node) -> Node:
	_apply_explosion_damage(world_position, stats, source)
	if get_pool_live_count("explosion") >= EXPLOSION_CAP:
		return null
	var explosion := _acquire("explosion")
	if explosion == null:
		return null
	explosion.pool_reset({
		"position": world_position,
		"stats": stats,
		"source": source
	})
	return explosion


func spawn_hazard_zone(world_position: Vector2, stats: Dictionary, source: Node) -> Node:
	if get_pool_live_count("hazard_zone") >= HAZARD_ZONE_CAP:
		return null
	var hazard := _acquire("hazard_zone")
	if hazard == null:
		return null
	hazard.pool_reset({
		"position": world_position,
		"stats": stats,
		"source": source
	})
	return hazard


func apply_explosion_damage(world_position: Vector2, stats: Dictionary, source: Node) -> void:
	_apply_explosion_damage(world_position, stats, source)


func spawn_lightning_arc(points: Array[Vector2], arc_color: Color, lifetime: float, sprite_path: String = "res://assets/sprites/proj_lightning.png") -> Node:
	if get_pool_live_count("lightning_arc") >= LIGHTNING_ARC_CAP:
		return null
	var arc := _acquire("lightning_arc")
	if arc == null:
		return null
	arc.pool_reset({
		"points": points,
		"color": arc_color,
		"lifetime": lifetime,
		"sprite_path": sprite_path
	})
	return arc


func spawn_xp_gem(world_position: Vector2, amount: int) -> Node:
	if get_pool_live_count("xp_gem") >= XP_GEM_CAP:
		_grant_xp_direct(amount)
		return null
	var gem := _acquire("xp_gem")
	if gem == null:
		_grant_xp_direct(amount)
		return null
	gem.pool_reset({
		"position": world_position,
		"amount": amount,
		"velocity": _random_scatter_velocity()
	})
	active_xp_gems.append(gem)
	return gem


func spawn_visible_xp_gem(world_position: Vector2, amount: int) -> Node:
	if get_pool_live_count("xp_gem") < XP_GEM_CAP:
		return spawn_xp_gem(world_position, amount)

	_compact_active_xp_gems()
	var merge_target := _nearest_active_xp_gem(world_position)
	if merge_target != null and merge_target.has_method("add_value"):
		merge_target.call("add_value", amount)
		return merge_target

	_grant_xp_direct(amount)
	return null


func spawn_gold_coin(world_position: Vector2, amount: int) -> Node:
	if get_pool_live_count("coin") >= COIN_CAP:
		_grant_gold_direct(amount)
		return null
	var coin := _acquire("coin")
	if coin == null:
		_grant_gold_direct(amount)
		return null
	coin.pool_reset({
		"position": world_position,
		"amount": amount,
		"velocity": _random_scatter_velocity()
	})
	return coin


func magnetize_xp_near(world_position: Vector2, radius: float) -> int:
	_compact_active_xp_gems()
	var collector := _nearest_living_hero(world_position)
	if collector == null:
		return 0

	var radius_squared := radius * radius
	var magnetized_count := 0
	for gem in active_xp_gems:
		if gem == null or not is_instance_valid(gem):
			continue
		if world_position.distance_squared_to(gem.global_position) > radius_squared:
			continue
		if gem.has_method("force_magnet_to"):
			gem.force_magnet_to(collector)
			magnetized_count += 1
	return magnetized_count


func spawn_damage_number(value: Variant, world_position: Vector2, number_color: Color = Color.WHITE) -> Node:
	var merged := _try_merge_damage_number(value, world_position, number_color)
	if merged != null:
		return merged
	_compact_active_damage_numbers()
	if active_damage_numbers.size() >= DAMAGE_NUMBER_CAP:
		return null
	var number := _acquire("damage_number")
	if number == null:
		return null
	active_damage_numbers.append(number)
	number.pool_reset({
		"value": value,
		"position": world_position,
		"color": number_color
	})
	return number


func spawn_death_burst(world_position: Vector2, burst_color: Color) -> Node:
	if get_pool_live_count("death_burst") >= DEATH_BURST_CAP:
		return null
	var burst := _acquire("death_burst")
	if burst == null:
		return null
	burst.pool_reset({
		"position": world_position,
		"color": burst_color
	})
	return burst


func release_enemy(enemy: Node) -> void:
	_mark_inactive_for_release(enemy)
	if enemy_spatial_index != null:
		enemy_spatial_index.unregister(enemy)
	_release("enemy", enemy)


func release_enemy_deferred(enemy: Node) -> void:
	_mark_inactive_for_release(enemy)
	if enemy_spatial_index != null:
		enemy_spatial_index.unregister(enemy)
	call_deferred("_release", "enemy", enemy)


func release_projectile(projectile: Node) -> void:
	_mark_inactive_for_release(projectile)
	active_enemy_projectiles.erase(projectile)
	call_deferred("_release", "projectile", projectile)


func release_orbit_projectile(projectile: Node) -> void:
	_mark_inactive_for_release(projectile)
	call_deferred("_release", "orbit_projectile", projectile)


func release_explosion(explosion: Node) -> void:
	_mark_inactive_for_release(explosion)
	_release("explosion", explosion)


func release_hazard_zone(hazard: Node) -> void:
	_mark_inactive_for_release(hazard)
	_release("hazard_zone", hazard)


func release_xp_gem(gem: Node) -> void:
	_mark_inactive_for_release(gem)
	active_xp_gems.erase(gem)
	_release("xp_gem", gem)


func release_gold_coin(coin: Node) -> void:
	_mark_inactive_for_release(coin)
	_release("coin", coin)


func release_damage_number(number: Node) -> void:
	_mark_inactive_for_release(number)
	active_damage_numbers.erase(number)
	_release("damage_number", number)


func release_death_burst(burst: Node) -> void:
	_mark_inactive_for_release(burst)
	_release("death_burst", burst)


func release_lightning_arc(arc: Node) -> void:
	_mark_inactive_for_release(arc)
	_release("lightning_arc", arc)


func find_nearest_enemy(center: Vector2, max_range: float) -> Node2D:
	if enemy_spatial_index == null:
		return null
	return enemy_spatial_index.find_nearest(center, max_range)


func get_enemies_in_radius(center: Vector2, radius: float) -> Array[Node2D]:
	if enemy_spatial_index == null:
		return []
	return enemy_spatial_index.get_enemies_in_radius(center, radius)


func get_enemy_live_count() -> int:
	if enemy_spatial_index == null:
		return 0
	return int(enemy_spatial_index.get("live_count"))


func get_pool_live_count(pool_name: String) -> int:
	if not pools.has(pool_name):
		return 0
	return int(pools[pool_name].live_count)


func get_pool_stats() -> Dictionary:
	var stats: Dictionary = {}
	for key in pools.keys():
		var pool = pools[key]
		stats[key] = {
			"live": pool.live_count,
			"free": pool.get_free_count(),
			"in_pool": pool.get_in_pool_count(),
			"duplicate_free": pool.get_duplicate_free_count(),
			"created": pool.total_created,
			"exhausted": pool.exhausted_count,
			"duplicate_releases": pool.duplicate_release_count,
			"foreign_releases": pool.rejected_foreign_release_count
		}
	if enemy_spatial_index != null:
		stats["enemy_queries"] = enemy_spatial_index.get("query_count")
	stats["enemy_group_scans"] = enemy_group_scan_count
	return stats


func reset_spatial_query_count() -> void:
	if enemy_spatial_index != null and enemy_spatial_index.has_method("reset_query_count"):
		enemy_spatial_index.reset_query_count()


func reset_debug_counters() -> void:
	enemy_group_scan_count = 0
	reset_spatial_query_count()


func record_enemy_group_scan(_reason: String = "") -> void:
	enemy_group_scan_count += 1


func _try_merge_damage_number(value: Variant, world_position: Vector2, number_color: Color) -> Node:
	if not (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT):
		return null
	var merge_radius := DAMAGE_NUMBER_MERGE_RADIUS
	if active_damage_numbers.size() >= DAMAGE_NUMBER_CAP:
		merge_radius *= 2.4
	for number in active_damage_numbers:
		if number == null or not is_instance_valid(number):
			continue
		if number.has_method("can_merge") and number.can_merge(world_position, merge_radius, DAMAGE_NUMBER_MERGE_AGE):
			if number.has_method("merge_value"):
				number.merge_value(value, world_position, number_color)
			return number
	return null


func _compact_active_damage_numbers() -> void:
	var compacted: Array[Node] = []
	for number in active_damage_numbers:
		if number == null or not is_instance_valid(number):
			continue
		var active_value: Variant = number.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		compacted.append(number)
	active_damage_numbers = compacted


func _compact_active_enemy_projectiles() -> void:
	var compacted: Array[Node] = []
	for projectile in active_enemy_projectiles:
		if projectile == null or not is_instance_valid(projectile):
			continue
		var active_value: Variant = projectile.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		compacted.append(projectile)
	active_enemy_projectiles = compacted


func _compact_active_xp_gems() -> void:
	var compacted: Array[Node] = []
	for gem in active_xp_gems:
		if gem == null or not is_instance_valid(gem):
			continue
		var active_value: Variant = gem.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		compacted.append(gem)
	active_xp_gems = compacted


func _nearest_active_xp_gem(world_position: Vector2) -> Node:
	var nearest: Node = null
	var best_distance_squared := INF
	for gem in active_xp_gems:
		if gem == null or not is_instance_valid(gem):
			continue
		var active_value: Variant = gem.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		var distance_squared := world_position.distance_squared_to(gem.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			nearest = gem
	return nearest


func _nearest_living_hero(world_position: Vector2) -> Node2D:
	var nearest: Node2D = null
	var best_distance_squared := INF
	var members: Array = []
	if GameManager.squad_manager != null and is_instance_valid(GameManager.squad_manager) and GameManager.squad_manager.has_method("get_members"):
		members = GameManager.squad_manager.get_members()
	elif GameManager.player != null and is_instance_valid(GameManager.player):
		members = [GameManager.player]

	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		if bool(member.get("is_alive")) == false:
			continue
		var distance_squared := world_position.distance_squared_to(member.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			nearest = member
	return nearest


func _apply_explosion_damage(world_position: Vector2, stats: Dictionary, _source: Node) -> void:
	var radius: float = float(stats.get("area_radius", 82.0))
	var damage_value: float = float(stats.get("damage", 10.0))

	for enemy in get_enemies_in_radius(world_position, radius + 24.0):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var active_value: Variant = enemy.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		var enemy_radius: float = float(enemy.get("radius"))
		var hit_distance: float = radius + enemy_radius
		if world_position.distance_squared_to(enemy.global_position) <= hit_distance * hit_distance:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage_value, world_position)


func _grant_xp_direct(amount: int) -> void:
	if amount <= 0:
		return
	GameManager.add_xp(amount)


func _grant_gold_direct(amount: int) -> void:
	if amount <= 0:
		return
	GameManager.add_gold(amount)


func _create_pool(pool_name: String, scene: PackedScene) -> void:
	var pool = NODE_POOL_SCRIPT.new(pool_name, scene, pool_root)
	pools[pool_name] = pool
	pool.warm(int(PREWARM_COUNTS.get(pool_name, 0)))


func _acquire(pool_name: String) -> Node:
	if not pools.has(pool_name):
		_create_pool(pool_name, _scene_for_pool(pool_name))
	var pool: RefCounted = pools[pool_name]
	return pool.acquire(_get_runtime_parent())


func _release(pool_name: String, node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not pools.has(pool_name):
		node.queue_free()
		return
	pools[pool_name].release(node)


func _mark_inactive_for_release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var active_value: Variant = node.get("is_active")
	if active_value != null:
		node.set("is_active", false)


func _issue_enemy_spawn_token() -> int:
	var token := next_enemy_spawn_token
	next_enemy_spawn_token += 1
	return token


func _scene_for_pool(pool_name: String) -> PackedScene:
	match pool_name:
		"enemy":
			return ENEMY_SCENE
		"projectile":
			return PROJECTILE_SCENE
		"orbit_projectile":
			return ORBIT_PROJECTILE_SCENE
		"explosion":
			return EXPLOSION_AREA_SCENE
		"hazard_zone":
			return HAZARD_ZONE_SCENE
		"xp_gem":
			return XP_GEM_SCENE
		"coin":
			return COIN_PICKUP_SCENE
		"damage_number":
			return DAMAGE_NUMBER_SCENE
		"death_burst":
			return DEATH_BURST_SCENE
		"lightning_arc":
			return LIGHTNING_ARC_SCENE
		_:
			return null


func _get_runtime_parent() -> Node:
	if GameManager.arena != null and is_instance_valid(GameManager.arena):
		var runtime := GameManager.arena.get_node_or_null("Runtime")
		if runtime != null:
			return runtime
		return GameManager.arena

	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	return get_tree().root


func _random_scatter_velocity() -> Vector2:
	return Vector2.RIGHT.rotated(randf() * TAU) * randf_range(70.0, 145.0)
