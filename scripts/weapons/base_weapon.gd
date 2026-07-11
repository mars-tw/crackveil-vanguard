extends Node2D

var owner_player: Node2D = null
var data: Resource = null
var cooldown_timer: float = 0.0
var trigger_count: int = 0
var projectile_stats_cache: Dictionary = {}
var effect_stats_cache: Dictionary = {}
var stats_cache_dirty: bool = true


func setup(player_node: Node2D, weapon_data: Resource) -> void:
	owner_player = player_node
	if weapon_data != null and weapon_data.has_method("make_runtime_copy"):
		data = weapon_data.make_runtime_copy()
	else:
		data = weapon_data.duplicate(true)
	name = get_weapon_id()
	_rebuild_stats_cache()
	reset_weapon()


func reset_weapon() -> void:
	cooldown_timer = _initial_cooldown_stagger()
	trigger_count = 0


func get_weapon_id() -> String:
	if data == null:
		return ""
	return str(data.get("id"))


func get_display_name() -> String:
	if data == null:
		return "未命名武器"
	return str(data.get("display_name"))


func apply_data_upgrade(upgrade_kind: String) -> bool:
	if data == null:
		return false
	if data.has_method("can_apply_upgrade") and not data.can_apply_upgrade(upgrade_kind):
		return false
	if data.has_method("apply_upgrade"):
		data.apply_upgrade(upgrade_kind)
	else:
		return false
	stats_cache_dirty = true
	_rebuild_stats_cache()
	_on_data_changed()
	return true


func _on_data_changed() -> void:
	pass


func register_trigger() -> void:
	trigger_count += 1


func scaled_cooldown(base_cooldown: float) -> float:
	var multiplier := 1.0
	if GameManager != null and GameManager.has_method("get_fire_rate_multiplier"):
		multiplier = max(0.1, float(GameManager.get_fire_rate_multiplier(owner_player)))
	return max(0.02, base_cooldown / multiplier)


func find_nearest_enemy(max_range: float) -> Node2D:
	if owner_player == null or not is_instance_valid(owner_player):
		return null

	return EntityFactory.find_nearest_enemy(owner_player.global_position, max_range)


func get_enemies_in_radius(center: Vector2, radius: float) -> Array[Node2D]:
	return EntityFactory.get_enemies_in_radius(center, radius)


func data_float(property_name: String, fallback: float) -> float:
	if data == null:
		return fallback
	var value: Variant = data.get(property_name)
	if value == null:
		return fallback
	return float(value)


func data_int(property_name: String, fallback: int) -> int:
	if data == null:
		return fallback
	var value: Variant = data.get(property_name)
	if value == null:
		return fallback
	return int(value)


func data_string(property_name: String, fallback: String) -> String:
	if data == null:
		return fallback
	var value: Variant = data.get(property_name)
	if value == null:
		return fallback
	return str(value)


func data_color(property_name: String, fallback: Color) -> Color:
	if data == null:
		return fallback
	var value: Variant = data.get(property_name)
	if typeof(value) != TYPE_COLOR:
		return fallback
	return value


func owner_passive_id() -> String:
	if owner_player == null or not is_instance_valid(owner_player):
		return ""
	var hero_data_value: Variant = owner_player.get("hero_data")
	if hero_data_value == null:
		return ""
	var hero_data_resource: Resource = hero_data_value as Resource
	if hero_data_resource == null:
		return ""
	return str(hero_data_resource.get("passive_id"))


func owner_passive_value() -> float:
	if owner_player == null or not is_instance_valid(owner_player):
		return 0.0
	var hero_data_value: Variant = owner_player.get("hero_data")
	if hero_data_value == null:
		return 0.0
	var hero_data_resource: Resource = hero_data_value as Resource
	if hero_data_resource == null:
		return 0.0
	return float(hero_data_resource.get("passive_value"))


func data_projectile_stats() -> Dictionary:
	if stats_cache_dirty:
		_rebuild_stats_cache()
	return projectile_stats_cache


func data_effect_stats() -> Dictionary:
	if stats_cache_dirty:
		_rebuild_stats_cache()
	return effect_stats_cache


func _rebuild_stats_cache() -> void:
	projectile_stats_cache = data.to_projectile_stats() if data != null and data.has_method("to_projectile_stats") else {}
	effect_stats_cache = data.to_effect_stats() if data != null and data.has_method("to_effect_stats") else {}
	var weapon_id := get_weapon_id()
	projectile_stats_cache["source_weapon_id"] = weapon_id
	effect_stats_cache["source_weapon_id"] = weapon_id
	stats_cache_dirty = false


func _initial_cooldown_stagger() -> float:
	var slot_index: int = 0
	if owner_player != null and is_instance_valid(owner_player):
		var slot_value: Variant = owner_player.get("formation_index")
		if typeof(slot_value) == TYPE_INT or typeof(slot_value) == TYPE_FLOAT:
			slot_index = int(slot_value)
	var id_hash: int = abs(hash(get_weapon_id())) % 97
	return 0.08 + fposmod(float(slot_index) * 0.053 + float(id_hash) * 0.003, 0.28)
