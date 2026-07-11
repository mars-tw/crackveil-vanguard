extends Node

const NODE_POOL_SCRIPT: Script = preload("res://scripts/pooling/node_pool.gd")
const ENEMY_SPATIAL_INDEX_SCRIPT: Script = preload("res://scripts/services/enemy_spatial_index.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")

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
const CORPSE_GHOST_SCENE: PackedScene = preload("res://scenes/vfx/CorpseGhost.tscn")
const LIGHTNING_ARC_SCENE: PackedScene = preload("res://scenes/vfx/LightningArc.tscn")

const PREWARM_COUNTS: Dictionary = {
	"enemy": 220,
	"projectile": 320,
	"fork_projectile": 56,
	"orbit_projectile": 56,
	"explosion": 112,
	"hazard_zone": 18,
	"xp_gem": 220,
	"coin": 220,
	"damage_number": 96,
	"death_burst": 32,
	"corpse_ghost": 32,
	"lightning_arc": 112
}

const DAMAGE_NUMBER_CAP := 48
const DAMAGE_NUMBER_MERGE_RADIUS := 48.0
const DAMAGE_NUMBER_MERGE_AGE := 0.24
const EXPLOSION_CAP := 48
const HAZARD_ZONE_CAP := 16
const FORK_PROJECTILE_CAP := 48
const ENEMY_PROJECTILE_CAP := 72
const DEATH_BURST_CAP := 20
const CORPSE_GHOST_CAP := 24
const LIGHTNING_ARC_CAP := 48
const XP_GEM_CAP := 180
const COIN_CAP := 180
const ENEMY_GLOW_REFRESH_INTERVAL := 0.24
const DEATH_VISUALS_PER_FRAME := 5
const DEATH_VISUAL_QUEUE_CAP := 72
const REGULAR_DROPS_PER_PHYSICS_FRAME := 6
const REGULAR_DROP_QUEUE_CAP := 180

var pools: Dictionary = {}
var pool_root: Node = null
var enemy_spatial_index: Node = null
var enemy_glow_refresh_timer: float = 0.0
var next_enemy_spawn_token: int = 1
var enemy_group_scan_count: int = 0
var active_damage_numbers: Array[Node] = []
var active_enemy_projectiles: Array[Node] = []
var active_fork_projectiles: Array[Node] = []
var active_hazard_zones: Array[Node] = []
var active_xp_gems: Array[Node] = []
var enemy_projectile_reclaims: int = 0
var fork_projectile_cap_skips: int = 0
var hazard_zone_reclaims: int = 0
var elite_enemy_reclaims: int = 0
var visible_xp_merges: int = 0
var visible_xp_reclaims: int = 0
var direct_xp_grants: int = 0
var death_visual_queue: Array[Dictionary] = []
var death_visual_queue_drops: int = 0
var regular_drop_queue: Array[Dictionary] = []
var regular_drop_queue_fallbacks: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enemy_spatial_index = ENEMY_SPATIAL_INDEX_SCRIPT.new()
	enemy_spatial_index.name = "EnemySpatialIndex"
	add_child(enemy_spatial_index)


func _process(delta: float) -> void:
	_drain_death_visual_queue()
	if enemy_spatial_index == null or int(enemy_spatial_index.get("live_count")) <= 0:
		return
	enemy_glow_refresh_timer = max(enemy_glow_refresh_timer - delta, 0.0)
	if enemy_glow_refresh_timer > 0.0:
		return
	enemy_glow_refresh_timer = ENEMY_GLOW_REFRESH_INTERVAL
	_refresh_enemy_crowd_glows()


func _physics_process(_delta: float) -> void:
	_drain_regular_drop_queue()


func initialize_for_arena(arena: Node) -> void:
	SPRITE_LOADER.prewarm_gameplay_textures()
	if enemy_spatial_index != null and enemy_spatial_index.has_method("reset"):
		enemy_spatial_index.reset()

	pools.clear()
	active_damage_numbers.clear()
	active_enemy_projectiles.clear()
	active_fork_projectiles.clear()
	active_hazard_zones.clear()
	active_xp_gems.clear()
	next_enemy_spawn_token = 1
	enemy_glow_refresh_timer = 0.0
	enemy_group_scan_count = 0
	enemy_projectile_reclaims = 0
	fork_projectile_cap_skips = 0
	hazard_zone_reclaims = 0
	elite_enemy_reclaims = 0
	visible_xp_merges = 0
	visible_xp_reclaims = 0
	direct_xp_grants = 0
	death_visual_queue.clear()
	death_visual_queue_drops = 0
	regular_drop_queue.clear()
	regular_drop_queue_fallbacks = 0
	pool_root = Node.new()
	pool_root.name = "Pools"
	arena.add_child(pool_root)

	_create_pool("enemy", ENEMY_SCENE)
	_create_pool("projectile", PROJECTILE_SCENE)
	_create_pool("fork_projectile", PROJECTILE_SCENE)
	_create_pool("orbit_projectile", ORBIT_PROJECTILE_SCENE)
	_create_pool("explosion", EXPLOSION_AREA_SCENE)
	_create_pool("hazard_zone", HAZARD_ZONE_SCENE)
	_create_pool("xp_gem", XP_GEM_SCENE)
	_create_pool("coin", COIN_PICKUP_SCENE)
	_create_pool("damage_number", DAMAGE_NUMBER_SCENE)
	_create_pool("death_burst", DEATH_BURST_SCENE)
	_create_pool("corpse_ghost", CORPSE_GHOST_SCENE)
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
	if enemy.has_method("update_threat_glow_for_crowd_count"):
		enemy.update_threat_glow_for_crowd_count(get_enemy_live_count())
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


func spawn_fork_projectile(world_position: Vector2, direction: Vector2, stats: Dictionary, source: Node) -> Node:
	_compact_active_fork_projectiles()
	if active_fork_projectiles.size() >= FORK_PROJECTILE_CAP:
		fork_projectile_cap_skips += 1
		return null
	var projectile := _acquire("fork_projectile")
	if projectile == null:
		return null
	projectile.pool_reset({
		"position": world_position,
		"direction": direction,
		"stats": stats,
		"source": source
	})
	active_fork_projectiles.append(projectile)
	return projectile


func spawn_enemy_projectile(world_position: Vector2, direction: Vector2, stats: Dictionary, source: Node, priority: String = "normal") -> Node:
	_compact_active_enemy_projectiles()
	if active_enemy_projectiles.size() >= ENEMY_PROJECTILE_CAP:
		if priority == "boss":
			if not _reclaim_oldest_normal_enemy_projectile():
				return null
		else:
			return null
	var projectile := spawn_projectile(world_position, direction, stats, source)
	if projectile == null:
		return null
	projectile.set_meta("_enemy_projectile_priority", priority)
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


func spawn_delayed_explosion(world_position: Vector2, stats: Dictionary, source: Node, delay: float) -> void:
	_spawn_delayed_explosion(world_position, stats.duplicate(true), source, max(0.0, delay))


func spawn_hazard_zone(world_position: Vector2, stats: Dictionary, source: Node) -> Node:
	_compact_active_hazard_zones()
	if active_hazard_zones.size() >= HAZARD_ZONE_CAP:
		_reclaim_oldest_hazard_zone()
	var hazard := _acquire("hazard_zone")
	if hazard == null:
		return null
	hazard.pool_reset({
		"position": world_position,
		"stats": stats,
		"source": source
	})
	active_hazard_zones.append(hazard)
	return hazard


func apply_explosion_damage(world_position: Vector2, stats: Dictionary, source: Node) -> void:
	_apply_explosion_damage(world_position, stats, source)


func _spawn_delayed_explosion(world_position: Vector2, stats: Dictionary, source: Node, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	if not GameManager.game_running or bool(GameManager.get("is_game_over")):
		return
	var valid_source := source if source != null and is_instance_valid(source) else null
	spawn_explosion(world_position, stats, valid_source)


func spawn_lightning_arc(points: Array[Vector2], arc_color: Color, lifetime: float, sprite_path: String = "res://assets/sprites/proj_lightning.png", arc_width: float = 24.0) -> Node:
	if get_pool_live_count("lightning_arc") >= LIGHTNING_ARC_CAP:
		return null
	var arc := _acquire("lightning_arc")
	if arc == null:
		return null
	arc.pool_reset({
		"points": points,
		"color": arc_color,
		"lifetime": lifetime,
		"sprite_path": sprite_path,
		"width": arc_width
	})
	return arc


func spawn_xp_gem(world_position: Vector2, amount: int, scatter_scale: float = 1.0) -> Node:
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
		"velocity": _random_scatter_velocity(scatter_scale),
		"scatter_time": 0.24
	})
	active_xp_gems.append(gem)
	return gem


func spawn_visible_xp_gem(world_position: Vector2, amount: int, scatter_scale: float = 1.0) -> Node:
	if amount <= 0:
		return null
	if get_pool_live_count("xp_gem") < XP_GEM_CAP:
		return _spawn_visible_xp_gem_from_slot(world_position, amount, scatter_scale)

	_compact_active_xp_gems()
	var registry_has_target := not active_xp_gems.is_empty()
	if registry_has_target:
		var merge_target := _nearest_active_xp_gem(world_position)
		if merge_target != null and merge_target.has_method("add_value"):
			visible_xp_merges += 1
			merge_target.call("add_value", amount)
			return merge_target

	if _reclaim_xp_gem_for_visible(world_position):
		return _spawn_visible_xp_gem_from_slot(world_position, amount, scatter_scale)
	if get_pool_live_count("xp_gem") < XP_GEM_CAP:
		return _spawn_visible_xp_gem_from_slot(world_position, amount, scatter_scale)
	return null


func spawn_xp_gem_burst(world_position: Vector2, total_amount: int, gem_count: int, scatter_scale: float = 1.0) -> void:
	var pieces := _split_drop_amount(total_amount, gem_count)
	for index in range(pieces.size()):
		var offset := Vector2(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0))
		spawn_xp_gem(world_position + offset, int(pieces[index]), scatter_scale)


func spawn_visible_xp_gem_burst(world_position: Vector2, total_amount: int, gem_count: int, scatter_scale: float = 1.0) -> void:
	var pieces := _split_drop_amount(total_amount, gem_count)
	for index in range(pieces.size()):
		var offset := Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		spawn_visible_xp_gem(world_position + offset, int(pieces[index]), scatter_scale)


func spawn_gold_coin(world_position: Vector2, amount: int, scatter_scale: float = 1.0) -> Node:
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
		"velocity": _random_scatter_velocity(scatter_scale),
		"scatter_time": 0.24
	})
	return coin


func spawn_gold_coin_burst(world_position: Vector2, total_amount: int, coin_count: int, scatter_scale: float = 1.0) -> void:
	var pieces := _split_drop_amount(total_amount, coin_count)
	for index in range(pieces.size()):
		var offset := Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		spawn_gold_coin(world_position + offset, int(pieces[index]), scatter_scale)


func queue_regular_drop(xp_position: Vector2, xp_amount: int, coin_position: Vector2, gold_amount: int) -> void:
	if xp_amount <= 0 and gold_amount <= 0:
		return
	if regular_drop_queue.size() >= REGULAR_DROP_QUEUE_CAP:
		regular_drop_queue_fallbacks += 1
		_grant_xp_direct(xp_amount)
		_grant_gold_direct(gold_amount)
		return
	regular_drop_queue.append({
		"xp_position": xp_position,
		"xp_amount": xp_amount,
		"coin_position": coin_position,
		"gold_amount": gold_amount
	})


func _drain_regular_drop_queue() -> void:
	var count := mini(REGULAR_DROPS_PER_PHYSICS_FRAME, regular_drop_queue.size())
	for _index in range(count):
		var request: Dictionary = regular_drop_queue.pop_front()
		var xp_amount := int(request.get("xp_amount", 0))
		var gold_amount := int(request.get("gold_amount", 0))
		if xp_amount > 0:
			spawn_xp_gem(request.get("xp_position", Vector2.ZERO), xp_amount, 1.0)
		if gold_amount > 0:
			spawn_gold_coin(request.get("coin_position", Vector2.ZERO), gold_amount, 1.0)


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


func spawn_damage_number(value: Variant, world_position: Vector2, number_color: Color = Color.WHITE, font_size_override: int = 0) -> Node:
	if PlayerSettings != null and not bool(PlayerSettings.get("damage_numbers_enabled")):
		return null
	_compact_active_damage_numbers()
	var viewport_size := _viewport_size_for_lod()
	var effective_cap := MOBILE_TUNING.damage_number_cap(viewport_size, DAMAGE_NUMBER_CAP)
	var merged := _try_merge_damage_number(value, world_position, number_color, viewport_size, effective_cap)
	if merged != null:
		return merged
	if active_damage_numbers.size() >= effective_cap:
		return null
	var number := _acquire("damage_number")
	if number == null:
		return null
	var effective_font_size := MOBILE_TUNING.damage_number_font_size(viewport_size, font_size_override)
	active_damage_numbers.append(number)
	number.pool_reset({
		"value": value,
		"position": world_position,
		"color": number_color,
		"font_size": effective_font_size
	})
	return number


func spawn_combo_text(combo_count: int, world_position: Vector2) -> Node:
	if combo_count < 2:
		return null
	return spawn_damage_number("COMBO ×%d" % combo_count, world_position, Color(0.72, 1.0, 0.92), 24)


func spawn_death_burst(world_position: Vector2, burst_color: Color, burst_scale: float = 1.0, burst_style: String = "burst") -> Node:
	var viewport_size := _viewport_size_for_lod()
	if get_pool_live_count("death_burst") >= MOBILE_TUNING.death_burst_cap(viewport_size, DEATH_BURST_CAP):
		return null
	var burst := _acquire("death_burst")
	if burst == null:
		return null
	burst.pool_reset({
		"position": world_position,
		"color": burst_color,
		"scale": burst_scale,
		"style": burst_style,
		"particle_multiplier": MOBILE_TUNING.lod_particle_multiplier(viewport_size)
	})
	return burst


func spawn_corpse_ghost(world_position: Vector2, corpse_sprite_path: String, corpse_color: Color, corpse_radius: float, corpse_sprite_scale: float, flip_h: bool = false, sprite_rotation: float = 0.0) -> Node:
	var viewport_size := _viewport_size_for_lod()
	if corpse_sprite_path == "" or get_pool_live_count("corpse_ghost") >= MOBILE_TUNING.corpse_ghost_cap(viewport_size, CORPSE_GHOST_CAP):
		return null
	var ghost := _acquire("corpse_ghost")
	if ghost == null:
		return null
	ghost.pool_reset({
		"position": world_position,
		"sprite_path": corpse_sprite_path,
		"color": corpse_color,
		"radius": corpse_radius,
		"sprite_scale": corpse_sprite_scale,
		"flip_h": flip_h,
		"rotation": sprite_rotation
	})
	return ghost


func queue_death_visual(world_position: Vector2, corpse_sprite_path: String, corpse_color: Color, corpse_radius: float, corpse_sprite_scale: float, flip_h: bool, sprite_rotation: float, burst_scale: float, elite_gold_rain: bool = false) -> void:
	if death_visual_queue.size() >= DEATH_VISUAL_QUEUE_CAP:
		death_visual_queue_drops += 1
		return
	death_visual_queue.append({
		"position": world_position,
		"sprite_path": corpse_sprite_path,
		"color": corpse_color,
		"radius": corpse_radius,
		"sprite_scale": corpse_sprite_scale,
		"flip_h": flip_h,
		"rotation": sprite_rotation,
		"burst_scale": burst_scale,
		"elite_gold_rain": elite_gold_rain
	})


func _drain_death_visual_queue() -> void:
	var count := mini(DEATH_VISUALS_PER_FRAME, death_visual_queue.size())
	for _index in range(count):
		var request: Dictionary = death_visual_queue.pop_front()
		var position: Vector2 = request.get("position", Vector2.ZERO)
		spawn_corpse_ghost(
			position,
			str(request.get("sprite_path", "")),
			request.get("color", Color.WHITE),
			float(request.get("radius", 13.0)),
			float(request.get("sprite_scale", 1.0)),
			bool(request.get("flip_h", false)),
			float(request.get("rotation", 0.0))
		)
		spawn_death_burst(position, request.get("color", Color.WHITE), float(request.get("burst_scale", 1.0)))
		if bool(request.get("elite_gold_rain", false)):
			spawn_death_burst(position + Vector2(0.0, -18.0), Color(1.0, 0.76, 0.18), 1.75, "gold_rain")


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
	active_fork_projectiles.erase(projectile)
	var pool_name := str(projectile.get_meta("_node_pool_name", "projectile")) if projectile != null and is_instance_valid(projectile) else "projectile"
	if pool_name != "projectile" and pool_name != "fork_projectile":
		pool_name = "projectile"
	call_deferred("_release", pool_name, projectile)


func release_orbit_projectile(projectile: Node) -> void:
	_mark_inactive_for_release(projectile)
	call_deferred("_release", "orbit_projectile", projectile)


func release_explosion(explosion: Node) -> void:
	_mark_inactive_for_release(explosion)
	_release("explosion", explosion)


func release_hazard_zone(hazard: Node) -> void:
	_mark_inactive_for_release(hazard)
	active_hazard_zones.erase(hazard)
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


func release_corpse_ghost(ghost: Node) -> void:
	_mark_inactive_for_release(ghost)
	_release("corpse_ghost", ghost)


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


func get_enemy_active_count() -> int:
	if enemy_spatial_index == null:
		return 0
	var count := 0
	var live_enemies: Array = enemy_spatial_index.get("live_enemies")
	for enemy in live_enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var active_value: Variant = enemy.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		count += 1
	return count


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
	stats["enemy_projectile_reclaims"] = enemy_projectile_reclaims
	stats["fork_projectile_cap_skips"] = fork_projectile_cap_skips
	stats["hazard_zone_reclaims"] = hazard_zone_reclaims
	stats["elite_enemy_reclaims"] = elite_enemy_reclaims
	stats["visible_xp_merges"] = visible_xp_merges
	stats["visible_xp_reclaims"] = visible_xp_reclaims
	stats["direct_xp_grants"] = direct_xp_grants
	stats["death_visual_queue"] = death_visual_queue.size()
	stats["death_visual_queue_drops"] = death_visual_queue_drops
	stats["regular_drop_queue"] = regular_drop_queue.size()
	stats["regular_drop_queue_fallbacks"] = regular_drop_queue_fallbacks
	return stats


func reset_spatial_query_count() -> void:
	if enemy_spatial_index != null and enemy_spatial_index.has_method("reset_query_count"):
		enemy_spatial_index.reset_query_count()


func reset_debug_counters() -> void:
	enemy_group_scan_count = 0
	reset_spatial_query_count()


func record_enemy_group_scan(_reason: String = "") -> void:
	enemy_group_scan_count += 1


func debug_clear_active_xp_gem_registry() -> void:
	active_xp_gems.clear()


func reclaim_regular_enemy_for_elite(reference_position: Vector2) -> bool:
	var enemy := _farthest_regular_enemy(reference_position)
	if enemy == null:
		return false
	elite_enemy_reclaims += 1
	release_enemy(enemy)
	return true


func _try_merge_damage_number(value: Variant, world_position: Vector2, number_color: Color, viewport_size: Vector2, effective_cap: int) -> Node:
	if not (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT):
		return null
	var merge_radius := MOBILE_TUNING.damage_number_merge_radius(viewport_size, DAMAGE_NUMBER_MERGE_RADIUS, active_damage_numbers.size(), effective_cap)
	var merge_age := MOBILE_TUNING.damage_number_merge_age(viewport_size, DAMAGE_NUMBER_MERGE_AGE)
	var merge_target: Node = null
	var best_distance_squared := INF
	for number in active_damage_numbers:
		if number == null or not is_instance_valid(number):
			continue
		if number.has_method("can_merge") and number.can_merge(world_position, merge_radius, merge_age):
			var number_position := (number as Node2D).global_position if number is Node2D else world_position
			var distance_squared := number_position.distance_squared_to(world_position)
			if distance_squared < best_distance_squared:
				best_distance_squared = distance_squared
				merge_target = number
	if merge_target != null and merge_target.has_method("merge_value"):
		merge_target.merge_value(value, world_position, number_color)
		return merge_target
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


func _compact_active_fork_projectiles() -> void:
	var compacted: Array[Node] = []
	for projectile in active_fork_projectiles:
		if projectile == null or not is_instance_valid(projectile):
			continue
		var active_value: Variant = projectile.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		compacted.append(projectile)
	active_fork_projectiles = compacted


func _compact_active_hazard_zones() -> void:
	var compacted: Array[Node] = []
	for hazard in active_hazard_zones:
		if hazard == null or not is_instance_valid(hazard):
			continue
		var active_value: Variant = hazard.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		compacted.append(hazard)
	active_hazard_zones = compacted


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


func _refresh_enemy_crowd_glows() -> void:
	if enemy_spatial_index == null:
		return
	var enemy_count: int = int(enemy_spatial_index.get("live_count"))
	var live_enemies: Array = enemy_spatial_index.get("live_enemies")
	for enemy in live_enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var active_value: Variant = enemy.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		if enemy.has_method("update_threat_glow_for_crowd_count"):
			enemy.update_threat_glow_for_crowd_count(enemy_count)


func _rebuild_active_xp_gems_from_pool() -> void:
	active_xp_gems.clear()
	if not pools.has("xp_gem"):
		return
	var pool: RefCounted = pools["xp_gem"]
	if not pool.has_method("get_live_nodes"):
		return
	for gem in pool.get_live_nodes():
		if gem == null or not is_instance_valid(gem):
			continue
		var active_value: Variant = gem.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		active_xp_gems.append(gem)


func _reclaim_oldest_normal_enemy_projectile() -> bool:
	for projectile in active_enemy_projectiles.duplicate():
		if projectile == null or not is_instance_valid(projectile):
			continue
		var active_value: Variant = projectile.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		if str(projectile.get_meta("_enemy_projectile_priority", "normal")) == "boss":
			continue
		enemy_projectile_reclaims += 1
		release_projectile(projectile)
		return true
	return false


func _reclaim_oldest_hazard_zone() -> bool:
	_compact_active_hazard_zones()
	if active_hazard_zones.is_empty():
		return false
	var hazard := active_hazard_zones[0]
	hazard_zone_reclaims += 1
	release_hazard_zone(hazard)
	return true


func _reclaim_xp_gem_for_visible(world_position: Vector2) -> bool:
	if active_xp_gems.is_empty():
		_rebuild_active_xp_gems_from_pool()
	if active_xp_gems.is_empty():
		return false
	var reclaim_target := _farthest_active_xp_gem(world_position)
	if reclaim_target == null:
		return false
	visible_xp_reclaims += 1
	release_xp_gem(reclaim_target)
	return true


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


func _farthest_active_xp_gem(world_position: Vector2) -> Node:
	var farthest: Node = null
	var best_distance_squared := -1.0
	for gem in active_xp_gems:
		if gem == null or not is_instance_valid(gem):
			continue
		var active_value: Variant = gem.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		var distance_squared := world_position.distance_squared_to(gem.global_position)
		if distance_squared > best_distance_squared:
			best_distance_squared = distance_squared
			farthest = gem
	return farthest


func _spawn_visible_xp_gem_from_slot(world_position: Vector2, amount: int, scatter_scale: float = 1.0) -> Node:
	var gem := _acquire("xp_gem")
	if gem == null:
		return null
	gem.pool_reset({
		"position": world_position,
		"amount": amount,
		"velocity": _random_scatter_velocity(scatter_scale),
		"scatter_time": 0.24
	})
	active_xp_gems.append(gem)
	return gem


func _farthest_regular_enemy(reference_position: Vector2) -> Node:
	if enemy_spatial_index == null:
		return null
	var live_enemies: Array = enemy_spatial_index.get("live_enemies")
	var fallback: Node = null
	var farthest: Node = null
	var best_distance_squared := -1.0
	for enemy in live_enemies:
		if not _is_regular_reclaim_candidate(enemy):
			continue
		if fallback == null:
			fallback = enemy
		var distance_squared := reference_position.distance_squared_to(enemy.global_position)
		if distance_squared > best_distance_squared:
			best_distance_squared = distance_squared
			farthest = enemy
	return farthest if farthest != null else fallback


func _is_regular_reclaim_candidate(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var active_value: Variant = enemy.get("is_active")
	if active_value != null and not bool(active_value):
		return false
	if bool(enemy.get("is_elite")):
		return false
	if bool(enemy.get("is_boss")):
		return false
	return true


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
		var member_alive: Variant = member.get("is_alive")
		if member_alive != null and bool(member_alive) == false:
			continue
		var distance_squared := world_position.distance_squared_to(member.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			nearest = member
	return nearest


func _apply_explosion_damage(world_position: Vector2, stats: Dictionary, source: Node) -> void:
	var radius: float = float(stats.get("area_radius", 82.0))
	var damage_value: float = float(stats.get("damage", 10.0))
	var weapon_id := str(stats.get("source_weapon_id", ""))

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
				var applied_damage: float = float(enemy.take_damage(damage_value, world_position))
				GameManager.record_weapon_damage(source, weapon_id, applied_damage)


func _grant_xp_direct(amount: int) -> void:
	if amount <= 0:
		return
	direct_xp_grants += 1
	GameManager.add_xp(amount)


func _grant_gold_direct(amount: int) -> void:
	if amount <= 0:
		return
	GameManager.add_gold(amount)


func _create_pool(pool_name: String, scene: PackedScene) -> void:
	var pool = NODE_POOL_SCRIPT.new(pool_name, scene, pool_root)
	pools[pool_name] = pool
	pool.warm(int(PREWARM_COUNTS.get(pool_name, 0)))


func _viewport_size_for_lod() -> Vector2:
	var viewport := get_viewport()
	if viewport != null:
		var viewport_size := viewport.get_visible_rect().size
		if viewport_size.x > 0.0 and viewport_size.y > 0.0:
			return viewport_size
	var window_size := DisplayServer.window_get_size()
	if window_size.x > 0 and window_size.y > 0:
		return Vector2(window_size)
	return Vector2(1280.0, 720.0)


func _acquire(pool_name: String) -> Node:
	if not pools.has(pool_name):
		_create_pool(pool_name, _scene_for_pool(pool_name))
	var pool: RefCounted = pools[pool_name]
	return pool.acquire(_get_runtime_parent())


func _release(pool_name: String, node: Variant) -> void:
	if node == null or not is_instance_valid(node):
		return
	var pooled_node := node as Node
	if pooled_node == null:
		return
	if not pools.has(pool_name):
		pooled_node.queue_free()
		return
	pools[pool_name].release(pooled_node)


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
		"fork_projectile":
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
		"corpse_ghost":
			return CORPSE_GHOST_SCENE
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


func _split_drop_amount(total_amount: int, desired_count: int) -> Array[int]:
	var pieces: Array[int] = []
	if total_amount <= 0:
		return pieces
	var count: int = clamp(desired_count, 1, total_amount)
	var base_amount := int(total_amount / count)
	var remainder := total_amount % count
	for index in range(count):
		pieces.append(base_amount + (1 if index < remainder else 0))
	return pieces


func _random_scatter_velocity(scatter_scale: float = 1.0) -> Vector2:
	var safe_scale: float = max(0.15, scatter_scale)
	return Vector2.RIGHT.rotated(randf() * TAU) * randf_range(135.0, 260.0) * safe_scale
