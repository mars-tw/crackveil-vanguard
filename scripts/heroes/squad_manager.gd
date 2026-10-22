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
var active_bonds: Dictionary = {}

const NUMERIC_UPGRADE_MAX_LEVELS: Dictionary = {
	"weapon_damage": 5,
	"weapon_cooldown": 4,
	"weapon_projectiles": 3
}
const LEADER_WEAPON_WEIGHT_MULTIPLIER := 1.35
const FOLLOWER_WEAPON_WEIGHT_MULTIPLIER := 0.82
const RECRUIT_LEVEL_GATES: Dictionary = {
	4: 2,
	5: 3,
	6: 4,
	7: 5,
	8: 6,
	9: 8
}
const FORMATION_OFFSETS: Array[Vector2] = [
	Vector2.ZERO,
	Vector2(-46.0, 58.0),
	Vector2(46.0, 58.0),
	Vector2(-92.0, 106.0),
	Vector2(0.0, 116.0),
	Vector2(92.0, 106.0),
	Vector2(-68.0, 170.0),
	Vector2(0.0, 184.0),
	Vector2(68.0, 170.0)
]

# R42 陣形戰術：玩家即時切換小隊站位，站位與數值同時改變，羈絆與四名英雄
# 的被動會依陣形產生共鳴。這是本作與一般自動射擊生存遊戲最大的差異。
const FORMATION_ORDER: Array[String] = ["wedge", "ring", "scatter"]
const FORMATION_SWITCH_COOLDOWN := 4.0
const FORMATION_GUARD_COOLDOWN_MULTIPLIER := 0.6
const FORMATION_INDICATOR_DURATION := 1.4
const FORMATION_DEFINITIONS: Dictionary = {
	"wedge": {
		"name": "楔形突擊",
		"short": "楔形",
		"summary": "隊友前壓到兩翼：全隊傷害 +15%，受到傷害 +8%",
		"effect": "傷害 +15%｜受傷 +8%",
		"tactic": "前方優先集火，集中突破",
		"damage": 1.15,
		"incoming": 1.08,
		"pickup": 1.0,
		"speed": 1.0,
		"color": Color(1.0, 0.46, 0.24)
	},
	"ring": {
		"name": "圓陣護衛",
		"short": "圓陣",
		"summary": "隊友圍住隊長：受到傷害 -10%，全隊傷害 -8%",
		"effect": "受傷 -10%｜傷害 -8%",
		"tactic": "護圈內再減傷 8%，靠攏就位",
		"damage": 0.92,
		"incoming": 0.90,
		"pickup": 1.0,
		"speed": 1.0,
		"color": Color(0.36, 0.78, 1.0)
	},
	"scatter": {
		"name": "散兵游擊",
		"short": "散兵",
		"summary": "隊友大範圍散開：拾取範圍 +60%、移動 +8%，全隊傷害 -5%",
		"effect": "拾取 +60%｜移動 +8%｜傷害 -5%",
		"tactic": "分散回收，腳下虛線為拾取範圍",
		"damage": 0.95,
		"incoming": 1.0,
		"pickup": 1.6,
		"speed": 1.08,
		"color": Color(0.52, 1.0, 0.56)
	}
}
const WEDGE_OFFSETS: Array[Vector2] = [
	Vector2.ZERO,
	Vector2(-76.0, -62.0),
	Vector2(76.0, -62.0),
	Vector2(-148.0, -18.0),
	Vector2(148.0, -18.0),
	Vector2(-46.0, -132.0),
	Vector2(46.0, -132.0),
	Vector2(-212.0, 34.0),
	Vector2(212.0, 34.0)
]
const RING_INNER_RADIUS := 96.0
const RING_OUTER_RADIUS := 158.0
const SCATTER_RADIUS := 236.0
# 羈絆 × 陣形共鳴：羈絆成立且處在對應陣形時才生效。
const BOND_FORMATION_RESONANCE: Dictionary = {
	"bond_ember_pulse": {"formation": "wedge", "damage": 1.08, "text": "燼脈聯爆 × 楔形：傷害 +8%", "short": "燼脈 傷害+8%"},
	"bond_void_rail": {"formation": "scatter", "damage": 1.08, "text": "縫獵協議 × 散兵：傷害 +8%", "short": "縫獵 傷害+8%"},
	"bond_guard_echo": {"formation": "ring", "regen": 1.5, "text": "星盾和聲 × 圓陣：每秒回復 1.5 HP", "short": "星盾 回復1.5/秒"},
	"bond_captain_shepherd": {"formation": "ring", "damage": 1.08, "text": "牧長裂約 × 圓陣：傷害 +8%", "short": "牧長 傷害+8%"}
}

var formation_id: String = "wedge"
var formation_cooldown: float = 0.0
var formation_switch_count: int = 0
var formation_indicator_timer: float = 0.0
var _resonance_regen_accumulator: float = 0.0
var tactical_draw_clock := 0.0
var bond_reveal_timer := 0.0
var bond_reveal_text := ""
var nearest_threat: Node2D

const BOND_DEFINITIONS: Array[Dictionary] = [
	{"id": "bond_ember_pulse", "name": "燼脈聯爆", "hero_ids": ["ember_grenadier", "pulse_artificer"]},
	{"id": "bond_void_rail", "name": "縫獵協議", "hero_ids": ["void_weaver", "rift_sniper"]},
	{"id": "bond_guard_echo", "name": "星盾和聲", "hero_ids": ["orbit_guard", "echo_singer"]},
	{"id": "bond_captain_shepherd", "name": "牧長裂約", "hero_ids": ["rift_captain", "rift_shepherd"]},
]

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
	],
	"grenade_lob": [
		{
			"upgrade_kind": "grenade_cluster",
			"name": "分裂燼彈",
			"description": "榴彈落地後追加小範圍連爆。"
		}
	],
	"void_net": [
		{
			"upgrade_kind": "void_anchor",
			"name": "虛空錨點",
			"description": "力場持續更久，減速更強。"
		}
	],
	"rail_lance": [
		{
			"upgrade_kind": "rail_focus",
			"name": "裂光校準",
			"description": "狙擊線更寬，貫通傷害更穩定。"
		}
	],
	"echo_hymn": [
		{
			"upgrade_kind": "echo_crescendo",
			"name": "漸強和聲",
			"description": "治療量與增傷光環持續時間提升。"
		}
	],
	"rift_construct": [
		{
			"upgrade_kind": "construct_anchor",
			"name": "裂錨定駐",
			"description": "第 1 級：壽命 +1.2 秒、半徑 +8；第 2 級：每次並肩投放 2 具，單具傷害 ×0.85。"
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
	recompute_bonds()

	return leader


func clear_squad() -> void:
	for member in members:
		if member != null and is_instance_valid(member):
			member.queue_free()
	members.clear()
	member_ids.clear()
	recruited_once.clear()
	dead_ids.clear()
	active_bonds.clear()
	leader = null
	bond_reveal_timer = 0.0
	bond_reveal_text = ""
	nearest_threat = null
	formation_id = FORMATION_ORDER[0]
	formation_cooldown = 0.0
	formation_switch_count = 0
	formation_indicator_timer = 0.0
	_resonance_regen_accumulator = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	tactical_draw_clock += delta
	bond_reveal_timer = maxf(0.0, bond_reveal_timer - delta)
	if tactical_draw_clock >= 0.05:
		tactical_draw_clock = 0.0
		if is_instance_valid(leader) and GameManager.game_running:
			nearest_threat = EntityFactory.find_nearest_enemy(leader.global_position,420.0)
		queue_redraw()
	if formation_cooldown > 0.0:
		formation_cooldown = maxf(0.0, formation_cooldown - delta)
	if formation_indicator_timer > 0.0:
		formation_indicator_timer = maxf(0.0, formation_indicator_timer - delta)
		queue_redraw()
	_tick_formation_resonance(delta)


func _tick_formation_resonance(delta: float) -> void:
	var regen := get_formation_regen_per_second()
	if regen <= 0.0 or not GameManager.game_running or get_tree().paused:
		_resonance_regen_accumulator = 0.0
		return
	_resonance_regen_accumulator += delta
	if _resonance_regen_accumulator >= 1.0:
		_resonance_regen_accumulator -= 1.0
		heal_members(regen)


# ---------------------------------------------------------------- 陣形戰術

func get_formation_id() -> String:
	return formation_id


func get_formation_definition(id: String = "") -> Dictionary:
	return FORMATION_DEFINITIONS.get(formation_id if id == "" else id, FORMATION_DEFINITIONS["wedge"])


func get_formation_name() -> String:
	return str(get_formation_definition().get("name", ""))


func get_formation_switch_cooldown_duration() -> float:
	var duration := FORMATION_SWITCH_COOLDOWN
	if has_living_passive("guard"):
		duration *= FORMATION_GUARD_COOLDOWN_MULTIPLIER
	return duration


func get_formation_cooldown_remaining() -> float:
	return formation_cooldown


func can_switch_formation() -> bool:
	return formation_cooldown <= 0.0 and leader != null and is_instance_valid(leader)


func cycle_formation() -> bool:
	var index := FORMATION_ORDER.find(formation_id)
	return set_formation(FORMATION_ORDER[(index + 1) % FORMATION_ORDER.size()])


func set_formation(new_id: String, force: bool = false) -> bool:
	if not FORMATION_DEFINITIONS.has(new_id) or new_id == formation_id:
		return false
	if not force and not can_switch_formation():
		return false
	formation_id = new_id
	formation_switch_count += 1
	formation_cooldown = get_formation_switch_cooldown_duration()
	formation_indicator_timer = FORMATION_INDICATOR_DURATION
	if has_living_passive("guard"):
		apply_temporary_shield(14.0, 2.5)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("recruit", false, -6.0, 0.88 + 0.08 * float(FORMATION_ORDER.find(new_id)))
	if GameManager.has_signal("toast_requested"):
		var text := "%s：%s" % [get_formation_name(), str(get_formation_definition().get("effect", ""))]
		var shorts := PackedStringArray()
		for bond_id in get_active_resonance_ids():
			shorts.append(str(BOND_FORMATION_RESONANCE[bond_id].get("short", bond_id)))
		if not shorts.is_empty():
			text += "\n共鳴：" + "、".join(shorts)
		GameManager.toast_requested.emit(text)
	if AchievementProgress != null and AchievementProgress.has_method("record_formation_switch"):
		AchievementProgress.record_formation_switch()
	queue_redraw()
	GameManager.queue_stats_emit()
	return true


func has_living_passive(passive: String) -> bool:
	for member in members:
		if member != null and is_instance_valid(member) and bool(member.get("is_alive")) and str(member.get("passive_id")) == passive:
			return true
	return false


func _living_passive_value(passive: String) -> float:
	for member in members:
		if member != null and is_instance_valid(member) and bool(member.get("is_alive")) and str(member.get("passive_id")) == passive:
			var hero_data_value: Variant = member.get("hero_data")
			if hero_data_value is Resource:
				return float((hero_data_value as Resource).get("passive_value"))
	return 0.0


func get_active_resonance_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for bond_id in BOND_FORMATION_RESONANCE.keys():
		if active_bonds.has(bond_id) and str(BOND_FORMATION_RESONANCE[bond_id].get("formation", "")) == formation_id:
			ids.append(str(bond_id))
	return ids


func get_active_resonance_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for bond_id in get_active_resonance_ids():
		texts.append(str(BOND_FORMATION_RESONANCE[bond_id].get("text", bond_id)))
	return texts


func get_formation_damage_multiplier() -> float:
	var multiplier := float(get_formation_definition().get("damage", 1.0))
	for bond_id in get_active_resonance_ids():
		multiplier *= float(BOND_FORMATION_RESONANCE[bond_id].get("damage", 1.0))
	if formation_id == "wedge":
		multiplier *= 1.0 + _living_passive_value("blast")
	return multiplier


func get_formation_incoming_multiplier() -> float:
	return float(get_formation_definition().get("incoming", 1.0))


func get_formation_pickup_multiplier() -> float:
	return float(get_formation_definition().get("pickup", 1.0)) * (1.0 + _living_passive_value("support"))


func get_formation_speed_multiplier() -> float:
	return float(get_formation_definition().get("speed", 1.0))


func get_follower_speed_multiplier() -> float:
	return get_formation_speed_multiplier() * (1.0 + _living_passive_value("scout"))


func get_formation_regen_per_second() -> float:
	var regen := 0.0
	for bond_id in get_active_resonance_ids():
		regen += float(BOND_FORMATION_RESONANCE[bond_id].get("regen", 0.0))
	return regen


func get_formation_debug_state() -> Dictionary:
	return {
		"formation": formation_id,
		"switches": formation_switch_count,
		"cooldown": formation_cooldown,
		"damage": get_formation_damage_multiplier(),
		"incoming": get_formation_incoming_multiplier(),
		"pickup": get_formation_pickup_multiplier(),
		"speed": get_formation_speed_multiplier(),
		"regen": get_formation_regen_per_second(),
		"resonance": get_active_resonance_ids()
	}


func _draw() -> void:
	if leader == null or not is_instance_valid(leader) or not GameManager.game_running:
		return
	var color: Color = get_formation_definition().get("color", Color.WHITE)
	var origin := to_local(leader.global_position)
	var forward: Vector2 = leader.get_locomotion_facing_direction()
	if is_instance_valid(nearest_threat) and nearest_threat.is_active:
		var point := to_local(nearest_threat.global_position)
		draw_arc(point,22,0,TAU,28,Color("ff586f"),2.0,true)
		draw_polyline(PackedVector2Array([point+Vector2(-9,-42),point+Vector2(0,-32),point+Vector2(9,-42)]),Color("ff8999"),3,true)
	if formation_id == "ring":
		# This boundary is the exact spatial cover test below.
		draw_circle(origin, RING_INNER_RADIUS, Color(color, 0.055))
		draw_arc(origin, RING_INNER_RADIUS, 0, TAU, 64, Color(color, 0.78), 2.2, true)
		for angle in range(8):
			var point := origin + Vector2.from_angle(angle * TAU / 8) * RING_INNER_RADIUS
			draw_line(point - Vector2(4, 0), point + Vector2(4, 0), color, 2, true)
	elif formation_id == "wedge":
		var tip := origin + forward * 135
		var side := forward.orthogonal() * 70
		draw_polyline(PackedVector2Array([origin + side, tip, origin - side]), Color(color, 0.7), 2.0, true)
	for member in get_members():
		if not is_instance_valid(member) or not member.is_alive:
			continue
		var point := to_local(member.global_position)
		# Captain uses a double diamond, companions a small formation ring.
		if member == leader:
			var diamond := PackedVector2Array([point + Vector2(0,-17),point + Vector2(23,0),point + Vector2(0,13),point + Vector2(-23,0),point + Vector2(0,-17)])
			draw_polyline(diamond, Color("dcf9ff"), 2.2, true)
		else:
			draw_arc(point, 16, 0, TAU, 24, Color(color,0.85), 1.8, true)
		if formation_id == "scatter":
			var radius: float = member.get_pickup_radius()
			for segment in range(12):
				draw_arc(point, radius, segment * TAU / 12, (segment + 0.55) * TAU / 12, 4, Color(color,0.30),1.2,true)
		elif formation_id == "wedge":
			var tip := point + forward * 36
			draw_polyline(PackedVector2Array([tip-forward.rotated(-0.65)*12,tip,tip-forward.rotated(0.65)*12]),Color(color,0.9),2,true)
	if bond_reveal_timer > 0:
		for definition in active_bonds.values():
			var a: Node = get_member_by_id(definition.hero_ids[0])
			var b: Node = get_member_by_id(definition.hero_ids[1])
			if is_instance_valid(a) and is_instance_valid(b):
				draw_line(to_local(a.global_position),to_local(b.global_position),Color("e4b7ff"),2,true)
				for member in [a,b]:
					draw_arc(to_local(member.global_position),23,0,TAU,28,Color("e4b7ff"),2.5,true)


func select_formation_target(owner: Node2D, max_range: float) -> Node2D:
	var nearest := EntityFactory.find_nearest_enemy(owner.global_position, max_range)
	if formation_id != "wedge" or not is_instance_valid(leader):
		return nearest
	var forward: Vector2 = leader.get_locomotion_facing_direction()
	var best: Node2D = null
	var distance := INF
	for enemy in EntityFactory.get_enemies_in_radius(owner.global_position,max_range):
		var offset: Vector2 = enemy.global_position - leader.global_position
		if offset.normalized().dot(forward) < 0.35:
			continue
		var candidate: float = owner.global_position.distance_squared_to(enemy.global_position)
		if candidate < distance:
			distance = candidate
			best = enemy
	return best if best != null else nearest


func get_spatial_cover_multiplier(target: Node) -> float:
	if formation_id != "ring" or not is_instance_valid(leader) or not is_instance_valid(target) or not target is Node2D:
		return 1.0
	return 0.92 if leader.global_position.distance_to(target.global_position) <= RING_INNER_RADIUS else 1.0


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
	var next_slot := get_member_count() + 1
	if not _can_offer_recruit_for_slot(next_slot):
		return
	var recruit_weight := _recruit_option_weight(next_slot)

	var available_heroes: Array = squad_data.get("available_heroes")
	for hero_data in available_heroes:
		if hero_data == null:
			continue
		var hero_id: String = str(hero_data.get("id"))
		if member_ids.has(hero_id) or recruited_once.has(hero_id) or dead_ids.has(hero_id):
			continue
		var recruit_description: String = str(hero_data.get("description"))
		var hero_quote_value = hero_data.get("quote")
		var hero_quote: String = str(hero_quote_value) if hero_quote_value != null else ""
		if not hero_quote.is_empty():
			recruit_description = "「%s」\n%s" % [hero_quote, recruit_description]
		pool.append({
			"id": "recruit_hero",
			"hero_id": hero_id,
			"name": "招募：" + str(hero_data.get("display_name")),
			"description": recruit_description,
			"weight": recruit_weight
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
	if weapon_data.has_method("get_qualitative_upgrade_definitions"):
		definitions = weapon_data.call("get_qualitative_upgrade_definitions")
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
	if hero != null and AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("recruit", false, -3.0, 1.06)
	recompute_bonds()
	return true


func member_died(member: Node) -> void:
	members.erase(member)
	if member != null:
		var hero_id: String = str(member.get("hero_id"))
		member_ids.erase(hero_id)
		dead_ids[hero_id] = true
	_reindex_formation()
	recompute_bonds()


func recompute_bonds() -> void:
	# Bond timing specification (DESIGN §3.2 / GROK §3.3 closure):
	# - membership events (start/recruit/death/reset) are the only flag recompute
	#   triggers; there is no per-frame roster scan;
	# - weapon modifiers are pull-based and read active_bonds at cast/tick time,
	#   so qualitative upgrades, evolutions, and runtime rebuilds cannot cache a
	#   stale radius/damage/heal modifier;
	# - growth changes still rebuild each WeaponData stats cache normally;
	# - a bond cap decrease is exceptional and eagerly syncs runtime limits in
	#   this same event cycle;
	# - excess constructs are reclaimed oldest-first (FIFO), shattering only
	#   while their shepherd owner remains alive; owner death releases all with
	#   trigger_shatter=false from Hero._die().
	var previous := active_bonds.keys()
	active_bonds.clear()
	for definition in BOND_DEFINITIONS:
		var enabled := true
		for hero_id_value in definition.get("hero_ids", []):
			var member := get_member_by_id(str(hero_id_value))
			if member == null or not is_instance_valid(member) or not bool(member.get("is_alive")):
				enabled = false
				break
		if enabled:
			active_bonds[str(definition.get("id", ""))] = definition
	_sync_dynamic_bond_limits()
	if active_bonds.is_empty():
		bond_reveal_text = ""
		bond_reveal_timer = 0.0
	for id in active_bonds:
		if not previous.has(id):
			var definition: Dictionary = active_bonds[id]
			var names := PackedStringArray()
			for hero_id in definition.hero_ids:
				var member := get_member_by_id(hero_id)
				var data: Variant = member.get("hero_data")
				names.append(str(data.get("display_name")) if data is Resource else str(hero_id))
			var effect: String = {"bond_guard_echo":"全隊減傷 5%", "bond_ember_pulse":"爆裂範圍 +8%", "bond_void_rail":"緩速目標貫槍 +12%", "bond_captain_shepherd":"裂傀強化"}.get(id,"")
			if id == "bond_guard_echo" and formation_id == "ring":
				effect += "・圓陣回復 1.5 HP／秒"
			bond_reveal_text = "%s｜%s\n%s" % [definition.name, "＋".join(names), effect]
			bond_reveal_timer = 4.0
			GameManager.show_toast(bond_reveal_text)
	if OS.is_debug_build():
		print("BONDS_ACTIVE=%s" % str(active_bonds.keys()))
	GameManager.queue_stats_emit()


func _sync_dynamic_bond_limits() -> void:
	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		var weapons_value: Variant = member.get("weapons")
		if typeof(weapons_value) != TYPE_DICTIONARY:
			continue
		for weapon in (weapons_value as Dictionary).values():
			if weapon != null and is_instance_valid(weapon) and weapon.has_method("sync_dynamic_limits"):
				weapon.sync_dynamic_limits(true)


func has_active_bond(bond_id: String) -> bool:
	return active_bonds.has(bond_id)


func get_active_bond_names() -> PackedStringArray:
	var names := PackedStringArray()
	for definition in BOND_DEFINITIONS:
		var bond_id := str(definition.get("id", ""))
		if active_bonds.has(bond_id):
			names.append(str(definition.get("name", bond_id)))
	return names


func get_active_bond_count() -> int:
	return active_bonds.size()


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
	# Formation follows travel, independently of a locked melee aim.
	var forward: Vector2 = leader.get_locomotion_facing_direction() if leader.has_method("get_locomotion_facing_direction") else leader.get_facing_direction() if leader.has_method("get_facing_direction") else Vector2.RIGHT
	var right: Vector2 = forward.rotated(PI * 0.5)
	return leader.global_position + right * local_offset.x - forward * local_offset.y


func get_formation_local_offset(slot_index: int) -> Vector2:
	if slot_index <= 0:
		return Vector2.ZERO
	# Local offsets are (lateral, back); a negative back value is ahead of the captain.
	match formation_id:
		"wedge":
			if slot_index < WEDGE_OFFSETS.size():
				return WEDGE_OFFSETS[slot_index]
		"ring":
			var inner_count := 6
			var on_inner := slot_index <= inner_count
			var ring_count := inner_count if on_inner else 8
			var ring_index := slot_index - 1 if on_inner else slot_index - inner_count - 1
			var angle := TAU * float(ring_index) / float(ring_count) + (0.0 if on_inner else PI / 8.0)
			var radius := RING_INNER_RADIUS if on_inner else RING_OUTER_RADIUS
			return Vector2(cos(angle), sin(angle)) * radius
		"scatter":
			var spread_angle := TAU * float(slot_index - 1) / 8.0 + PI / 8.0
			var spread_radius := SCATTER_RADIUS * (0.78 if slot_index % 2 == 0 else 1.0)
			return Vector2(cos(spread_angle), sin(spread_angle)) * spread_radius
	if slot_index < FORMATION_OFFSETS.size():
		return FORMATION_OFFSETS[slot_index]

	var row: int = int((slot_index - 1) / 2) + 1
	var side: float = -1.0 if slot_index % 2 == 1 else 1.0
	var lateral: float = side * (slot_spacing_x + float(row - 1) * row_spacing_x_growth)
	var back: float = row_spacing_y * float(row)
	return Vector2(lateral, back)


func _can_offer_recruit_for_slot(slot_count: int) -> bool:
	var required_level := int(RECRUIT_LEVEL_GATES.get(slot_count, 8))
	return int(GameManager.get("level")) >= required_level


func _recruit_option_weight(slot_count: int) -> float:
	var level_value: int = int(GameManager.get("level"))
	var max_members: int = int(squad_data.get("max_members")) if squad_data != null else 9
	var curve_target: int = int(clamp(3 + int(floor(float(max(0, level_value - 1)) / 1.15)), 3, max_members))
	if get_member_count() < curve_target:
		return 4.2 if slot_count <= 6 else 3.4
	return 2.5 if slot_count <= 6 else 1.9


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
	if weapon_data.has_method("get_count_upgrade_description"):
		var custom: String = weapon_data.call("get_count_upgrade_description")
		if not custom.is_empty():
			return custom
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
		"grenade_lob":
			return "+%d 榴彈，爆炸半徑 +%s" % [int(weapon_data.get("projectile_count_upgrade")), _format_number(float(weapon_data.get("area_radius_upgrade")))]
		"void_net":
			return "力場半徑 +%s，施放距離 +%s" % [_format_number(float(weapon_data.get("area_radius_upgrade"))), _format_number(float(weapon_data.get("range_upgrade")))]
		"rail_lance":
			return "+%d 貫通，射程 +%s" % [int(weapon_data.get("pierce_upgrade")), _format_number(float(weapon_data.get("range_upgrade")))]
		"echo_hymn":
			return "+%d 和聲層，脈衝半徑 +%s" % [int(weapon_data.get("projectile_count_upgrade")), _format_number(float(weapon_data.get("area_radius_upgrade")))]
		"rift_construct":
			return "裂傀壽命 +0.4 秒"
		_:
			return "強化武器參數"


func _format_number(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return "%.1f" % value
