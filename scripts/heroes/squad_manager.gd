extends Node2D

@export var squad_data: Resource = preload("res://resources/squads/default_squad.tres")
@export var slot_spacing_x: float = 46.0
@export var row_spacing_y: float = 58.0
@export var row_spacing_x_growth: float = 16.0

var members: Array[Node] = []
var member_ids: Dictionary = {}
var recruited_once: Dictionary = {}
var dead_ids: Dictionary = {}
var leader: Node = null

const NUMERIC_UPGRADE_MAX_LEVELS: Dictionary = {
	"weapon_damage": 5,
	"weapon_cooldown": 4,
	"weapon_projectiles": 3
}
const LEADER_WEAPON_WEIGHT_MULTIPLIER := 1.35
const FOLLOWER_WEAPON_WEIGHT_MULTIPLIER := 0.82

const QUALITATIVE_UPGRADES: Dictionary = {
	"linear": [
		{
			"upgrade_kind": "riftline_fork",
			"name": "裂線分叉",
			"description": "命中後裂出 ±20° 碎彈，裂片傷害 50%"
		}
	],
	"orbit": [
		{
			"upgrade_kind": "orbit_resonance",
			"name": "星環共鳴",
			"description": "星環命中使敵人短暫易傷 +20%"
		}
	],
	"explosion": [
		{
			"upgrade_kind": "pulse_embers",
			"name": "脈衝餘燼",
			"description": "爆炸留下 1.2 秒低傷燃燒區"
		}
	],
	"chain_lightning": [
		{
			"upgrade_kind": "chain_overload",
			"name": "雷鏈過載",
			"description": "雷鏈末跳引發小範圍爆裂"
		},
		{
			"upgrade_kind": "magnetic_reclaim",
			"name": "磁暴回收",
			"description": "擊殺時短距吸引附近 XP"
		}
	],
	"boomerang": [
		{
			"upgrade_kind": "boomerang_rebound",
			"name": "返刃共振",
			"description": "迴旋鏢返場可二次命中；每級提高返場傷害與穿透"
		}
	],
	"homing_missile": [
		{
			"upgrade_kind": "missile_guidance",
			"name": "獵隙導引",
			"description": "飛彈轉向更快；第 2 級提高重取目標頻率與鎖定距離"
		}
	]
}


func start_squad() -> Node:
	clear_squad()
	if squad_data != null:
		squad_data = squad_data.duplicate(true)
	if squad_data == null:
		return null

	var starting_heroes: Array = squad_data.get("starting_heroes")
	for index in range(starting_heroes.size()):
		var hero_data: Resource = starting_heroes[index]
		if hero_data == null:
			continue
		_spawn_member(hero_data, index == 0)

	return leader


func clear_squad() -> void:
	for member in members:
		if member != null and is_instance_valid(member):
			member.queue_free()
	members.clear()
	member_ids.clear()
	recruited_once.clear()
	dead_ids.clear()
	leader = null


func _spawn_member(hero_data: Resource, leader_flag: bool) -> Node:
	if hero_data == null:
		return null

	var slot_index: int = members.size()
	var spawn_position := Vector2.ZERO
	if leader != null and is_instance_valid(leader):
		spawn_position = get_formation_world_position(slot_index)

	var hero := EntityFactory.spawn_hero(hero_data, spawn_position, leader_flag, self, slot_index)
	members.append(hero)
	var hero_id: String = str(hero_data.get("id"))
	member_ids[hero_id] = true
	recruited_once[hero_id] = true
	if leader_flag:
		leader = hero
	return hero


func build_upgrade_pool(base_pool: Array) -> Array:
	var pool: Array = base_pool.duplicate(true)
	_append_recruit_options(pool)
	_append_weapon_upgrade_options(pool)
	return pool


func _append_recruit_options(pool: Array) -> void:
	if squad_data == null:
		return
	if get_member_count() >= int(squad_data.get("max_members")):
		return

	var available_heroes: Array = squad_data.get("available_heroes")
	for hero_data in available_heroes:
		if hero_data == null:
			continue
		var hero_id: String = str(hero_data.get("id"))
		if member_ids.has(hero_id) or recruited_once.has(hero_id) or dead_ids.has(hero_id):
			continue
		pool.append({
			"id": "recruit_hero",
			"hero_id": hero_id,
			"name": "招募：" + str(hero_data.get("display_name")),
			"description": str(hero_data.get("description")),
			"weight": 4
		})


func _append_weapon_upgrade_options(pool: Array) -> void:
	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		var hero_name: String = str(member.get("display_name"))
		var weapon_order: Array = member.get("weapon_order")
		var weapons: Dictionary = member.get("weapons")
		for weapon_id in weapon_order:
			var weapon: Node = weapons.get(weapon_id)
			if weapon == null or not is_instance_valid(weapon):
				continue
			var weapon_data: Resource = weapon.get("data")
			if weapon_data == null:
				continue
			var numeric_weight: float = _numeric_upgrade_weight(member, weapon_data)
			pool.append({
				"id": "upgrade_hero_weapon",
				"hero_id": str(member.get("hero_id")),
				"weapon_id": str(weapon_id),
				"upgrade_kind": "weapon_damage",
				"name": hero_name + "：" + str(weapon_data.get("display_name")) + "增幅",
				"description": "+%s 傷害" % _format_number(float(weapon_data.get("damage_upgrade"))),
				"weight": numeric_weight,
				"max_level": int(NUMERIC_UPGRADE_MAX_LEVELS.get("weapon_damage", 5)),
				"level_key": _weapon_level_key(member, weapon_id, "weapon_damage")
			})
			if _weapon_has_meaningful_cooldown_upgrade(weapon_data):
				pool.append({
					"id": "upgrade_hero_weapon",
					"hero_id": str(member.get("hero_id")),
					"weapon_id": str(weapon_id),
					"upgrade_kind": "weapon_cooldown",
					"name": hero_name + "：" + str(weapon_data.get("display_name")) + "冷卻",
					"description": "冷卻 -%d%%" % int(round((1.0 - float(weapon_data.get("cooldown_upgrade_multiplier"))) * 100.0)),
					"weight": numeric_weight,
					"max_level": int(NUMERIC_UPGRADE_MAX_LEVELS.get("weapon_cooldown", 4)),
					"level_key": _weapon_level_key(member, weapon_id, "weapon_cooldown")
				})
			pool.append({
				"id": "upgrade_hero_weapon",
				"hero_id": str(member.get("hero_id")),
				"weapon_id": str(weapon_id),
				"upgrade_kind": "weapon_projectiles",
				"name": hero_name + "：" + str(weapon_data.get("display_name")) + "擴張",
				"description": _get_count_upgrade_description(weapon_data),
				"weight": numeric_weight,
				"max_level": int(NUMERIC_UPGRADE_MAX_LEVELS.get("weapon_projectiles", 3)),
				"level_key": _weapon_level_key(member, weapon_id, "weapon_projectiles")
			})
			_append_qualitative_upgrade_options(pool, member, weapon_id, weapon_data, hero_name)
			_append_evolution_upgrade_option(pool, member, weapon_id, weapon_data, hero_name)


func _append_qualitative_upgrade_options(pool: Array, member: Node, weapon_id: String, weapon_data: Resource, hero_name: String) -> void:
	var behavior_id := str(weapon_data.get("behavior_id"))
	var definitions: Array = QUALITATIVE_UPGRADES.get(behavior_id, [])
	for definition in definitions:
		var upgrade_kind := str(definition.get("upgrade_kind", ""))
		if weapon_data.has_method("can_apply_upgrade") and not weapon_data.can_apply_upgrade(upgrade_kind):
			continue
		var max_level := 1
		if weapon_data.has_method("get_modifier_max_level"):
			max_level = int(weapon_data.get_modifier_max_level(upgrade_kind))
		pool.append({
			"id": "upgrade_hero_weapon",
			"hero_id": str(member.get("hero_id")),
			"weapon_id": str(weapon_id),
			"upgrade_kind": upgrade_kind,
			"name": hero_name + "：" + str(definition.get("name", "質變升級")),
			"description": str(definition.get("description", "")),
			"weight": 4 if bool(member.get("is_leader")) else 3,
			"max_level": max_level,
			"level_key": _weapon_level_key(member, weapon_id, upgrade_kind),
			"upgrade_category": "qualitative"
		})


func _append_evolution_upgrade_option(pool: Array, member: Node, weapon_id: String, weapon_data: Resource, hero_name: String) -> void:
	if weapon_data == null or not weapon_data.has_method("can_offer_evolution"):
		return
	if not weapon_data.can_offer_evolution(int(GameManager.get("level"))):
		return
	var definition: Dictionary = weapon_data.get_evolution_definition()
	var evolution_id := str(definition.get("evolution_id", ""))
	if evolution_id == "":
		return
	pool.append({
		"id": "upgrade_hero_weapon",
		"hero_id": str(member.get("hero_id")),
		"weapon_id": str(weapon_id),
		"upgrade_kind": evolution_id,
		"name": hero_name + "：" + str(definition.get("name", "武器進化")),
		"description": str(definition.get("description", "武器進化為新形態。")),
		"weight": 9 if bool(member.get("is_leader")) else 8,
		"max_level": 1,
		"level_key": _weapon_level_key(member, weapon_id, evolution_id),
		"upgrade_category": "evolution"
	})


func _weapon_has_meaningful_cooldown_upgrade(weapon_data: Resource) -> bool:
	if float(weapon_data.get("cooldown")) <= 0.0:
		return false
	return float(weapon_data.get("cooldown_upgrade_multiplier")) < 0.999


func _numeric_upgrade_weight(member: Node, weapon_data: Resource) -> float:
	var weight := LEADER_WEAPON_WEIGHT_MULTIPLIER if member != null and bool(member.get("is_leader")) else FOLLOWER_WEAPON_WEIGHT_MULTIPLIER
	if weapon_data != null and weapon_data.has_method("is_evolved") and weapon_data.is_evolved():
		weight *= 0.35
	return weight


func _weapon_level_key(member: Node, weapon_id: String, upgrade_kind: String) -> String:
	return "%s|%s|%s" % [str(member.get("hero_id")), str(weapon_id), upgrade_kind]


func apply_upgrade(upgrade: Dictionary) -> void:
	var upgrade_id: String = upgrade.get("id", "")
	match upgrade_id:
		"recruit_hero":
			recruit_hero(str(upgrade.get("hero_id", "")))
		"upgrade_hero_weapon":
			var hero := get_member_by_id(str(upgrade.get("hero_id", "")))
			var upgrade_kind := str(upgrade.get("upgrade_kind", "weapon_damage"))
			if hero != null and hero.has_method("upgrade_weapon"):
				var applied: bool = hero.upgrade_weapon(str(upgrade.get("weapon_id", "")), upgrade_kind)
				if applied and upgrade_kind == "magnetic_reclaim" and GameManager.has_method("enable_magnetic_reclaim"):
					GameManager.enable_magnetic_reclaim()
				if applied and str(upgrade.get("upgrade_category", "")) == "evolution" and AchievementProgress != null and AchievementProgress.has_method("record_evolution"):
					AchievementProgress.record_evolution()
		_:
			if leader != null and is_instance_valid(leader) and leader.has_method("apply_personal_upgrade"):
				leader.apply_personal_upgrade(upgrade)

	GameManager.emit_stats()


func heal_members(amount: float) -> bool:
	var applied := false
	for member in get_members():
		if member == null or not is_instance_valid(member):
			continue
		if member.has_method("heal"):
			applied = member.heal(amount) or applied
	return applied


func can_heal_members() -> bool:
	for member in get_members():
		if member == null or not is_instance_valid(member):
			continue
		if bool(member.get("is_alive")) == false:
			continue
		if float(member.get("current_hp")) < float(member.get("max_hp")):
			return true
	return false


func apply_temporary_shield(amount: float, duration: float) -> bool:
	var applied := false
	for member in get_members():
		if member == null or not is_instance_valid(member):
			continue
		if member.has_method("add_temporary_shield"):
			member.add_temporary_shield(amount, duration)
			applied = true
	return applied


func apply_random_qualitative_upgrade() -> bool:
	var options: Array = _collect_available_qualitative_options()
	if options.is_empty():
		return false
	var option: Dictionary = options[randi() % options.size()]
	return apply_qualitative_upgrade(
		str(option.get("hero_id", "")),
		str(option.get("weapon_id", "")),
		str(option.get("upgrade_kind", ""))
	)


func has_available_qualitative_upgrade() -> bool:
	return not _collect_available_qualitative_options().is_empty()


func get_available_qualitative_shop_options() -> Array:
	return _collect_available_qualitative_options()


func can_apply_qualitative_upgrade(hero_id: String, weapon_id: String, upgrade_kind: String) -> bool:
	var hero := get_member_by_id(hero_id)
	if hero == null or not is_instance_valid(hero):
		return false
	var weapons: Dictionary = hero.get("weapons")
	var weapon: Node = weapons.get(weapon_id)
	if weapon == null or not is_instance_valid(weapon):
		return false
	var weapon_data: Resource = weapon.get("data")
	if weapon_data == null or not weapon_data.has_method("can_apply_upgrade"):
		return false
	return weapon_data.can_apply_upgrade(upgrade_kind)


func apply_qualitative_upgrade(hero_id: String, weapon_id: String, upgrade_kind: String) -> bool:
	if not can_apply_qualitative_upgrade(hero_id, weapon_id, upgrade_kind):
		return false
	var hero := get_member_by_id(hero_id)
	if hero == null or not hero.has_method("upgrade_weapon"):
		return false
	var applied: bool = hero.upgrade_weapon(weapon_id, upgrade_kind)
	if applied and upgrade_kind == "magnetic_reclaim" and GameManager.has_method("enable_magnetic_reclaim"):
		GameManager.enable_magnetic_reclaim()
	return applied


func _collect_available_qualitative_options() -> Array:
	var options: Array = []
	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		var hero_name: String = str(member.get("display_name"))
		var weapon_order: Array = member.get("weapon_order")
		var weapons: Dictionary = member.get("weapons")
		for weapon_id in weapon_order:
			var weapon: Node = weapons.get(weapon_id)
			if weapon == null or not is_instance_valid(weapon):
				continue
			var weapon_data: Resource = weapon.get("data")
			if weapon_data == null:
				continue
			_append_qualitative_upgrade_options(options, member, str(weapon_id), weapon_data, hero_name)
	return options


func has_weapon_modifier(modifier_id: String) -> bool:
	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		var weapons: Dictionary = member.get("weapons")
		for weapon_id in weapons.keys():
			var weapon: Node = weapons.get(weapon_id)
			if weapon == null or not is_instance_valid(weapon):
				continue
			var weapon_data: Resource = weapon.get("data")
			if weapon_data != null and weapon_data.has_method("has_modifier") and weapon_data.has_modifier(modifier_id):
				return true
	return false


func recruit_hero(hero_id: String) -> bool:
	if squad_data == null or hero_id == "" or member_ids.has(hero_id) or recruited_once.has(hero_id) or dead_ids.has(hero_id):
		return false
	if get_member_count() >= int(squad_data.get("max_members")):
		return false

	var hero_data: Resource = squad_data.get_hero_data(hero_id)
	if hero_data == null:
		return false

	var hero := _spawn_member(hero_data, false)
	if hero != null and GameManager.has_method("apply_current_meta_progress_to_member"):
		GameManager.apply_current_meta_progress_to_member(hero)
	if hero != null and AchievementProgress != null and AchievementProgress.has_method("record_squad_size"):
		AchievementProgress.record_squad_size(get_member_count(), int(squad_data.get("max_members")))
	return true


func member_died(member: Node) -> void:
	members.erase(member)
	if member != null:
		var hero_id: String = str(member.get("hero_id"))
		member_ids.erase(hero_id)
		dead_ids[hero_id] = true
	_reindex_formation()


func get_member_count() -> int:
	var count := 0
	for member in members:
		if member != null and is_instance_valid(member):
			count += 1
	return count


func get_member_by_id(hero_id: String) -> Node:
	for member in members:
		if member != null and is_instance_valid(member) and str(member.get("hero_id")) == hero_id:
			return member
	return null


func get_members() -> Array[Node]:
	return members


func _reindex_formation() -> void:
	var live_members: Array[Node] = []
	for member in members:
		if member != null and is_instance_valid(member):
			live_members.append(member)
	members = live_members
	for index in range(members.size()):
		var member := members[index]
		if member == null or not is_instance_valid(member):
			continue
		member.set("formation_index", index)
		for child in member.get_children():
			if child.name == "FollowerController" and child.has_method("setup"):
				child.setup(member, self, index)


func get_formation_world_position(slot_index: int) -> Vector2:
	if leader == null or not is_instance_valid(leader):
		return Vector2.ZERO
	if slot_index <= 0:
		return leader.global_position

	var local_offset := get_formation_local_offset(slot_index)
	var forward: Vector2 = leader.get_facing_direction() if leader.has_method("get_facing_direction") else Vector2.RIGHT
	var right: Vector2 = forward.rotated(PI * 0.5)
	return leader.global_position + right * local_offset.x - forward * local_offset.y


func get_formation_local_offset(slot_index: int) -> Vector2:
	if slot_index <= 0:
		return Vector2.ZERO

	var row: int = int((slot_index - 1) / 2) + 1
	var side: float = -1.0 if slot_index % 2 == 1 else 1.0
	var lateral: float = side * (slot_spacing_x + float(row - 1) * row_spacing_x_growth)
	var back: float = row_spacing_y * float(row)
	return Vector2(lateral, back)


func get_weapon_trigger_counts() -> Dictionary:
	var counts: Dictionary = {}
	for member in get_members():
		if member == null or not member.has_method("get_weapon_trigger_counts"):
			continue
		var hero_counts: Dictionary = member.get_weapon_trigger_counts()
		for weapon_id in hero_counts.keys():
			counts[str(member.get("hero_id")) + ":" + str(weapon_id)] = int(hero_counts[weapon_id])
	return counts


func _get_count_upgrade_description(weapon_data: Resource) -> String:
	match str(weapon_data.get("behavior_id")):
		"linear":
			return "+%d 發投射物，+%d 穿透" % [int(weapon_data.get("projectile_count_upgrade")), int(weapon_data.get("pierce_upgrade"))]
		"orbit":
			return "+%d 環繞飛刀，+%d 穿透" % [int(weapon_data.get("projectile_count_upgrade")), int(weapon_data.get("pierce_upgrade"))]
		"explosion":
			return "+%s 爆炸半徑" % _format_number(float(weapon_data.get("area_radius_upgrade")))
		"chain_lightning":
			return "+%d 連鎖，+%s 跳躍距離" % [int(weapon_data.get("chain_count_upgrade")), _format_number(float(weapon_data.get("range_upgrade")))]
		"boomerang":
			return "+%d 迴旋鏢，+%d 穿透，+%s 射程" % [int(weapon_data.get("projectile_count_upgrade")), int(weapon_data.get("pierce_upgrade")), _format_number(float(weapon_data.get("range_upgrade")))]
		"homing_missile":
			return "+%d 追蹤飛彈，+%d 穿透" % [int(weapon_data.get("projectile_count_upgrade")), int(weapon_data.get("pierce_upgrade"))]
		_:
			return "強化武器參數"


func _format_number(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return "%.1f" % value
