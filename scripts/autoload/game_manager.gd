extends Node

signal stats_changed(stats: Dictionary)
signal level_up_requested(options: Array)
signal game_over_requested(summary: Dictionary)
signal pause_changed(is_paused: bool)
signal shop_requested(options: Array)
signal stage_victory_requested(summary: Dictionary)
signal contract_requested(options: Array)

const SHOP_FIRST_TIME := 75.0
const SHOP_SECOND_TIME := 150.0
const SHOP_INTERVAL := 90.0
const SHOP_BOSS_TIME := 180.0
const SHOP_BOSS_WINDOW_BEFORE := 15.0
const SHOP_BOSS_WINDOW_AFTER := 25.0
const SHOP_BOSS_ACTIVE_RETRY := 5.0
const SHOP_POST_VICTORY_GRACE := 12.0

const CONTRACT_POOL: Array = [
	{
		"id": "contract_blood_tax",
		"name": "血稅",
		"description": "全隊傷害 +12%，受擊傷害 +10%。",
		"rule_change": false
	},
	{
		"id": "contract_golden_famine",
		"name": "金饑",
		"description": "金幣掉落 +40%；90 秒前升級只給 2 張選項。",
		"rule_change": true
	},
	{
		"id": "contract_quiet_veil",
		"name": "靜幕",
		"description": "前 60 秒敵潮較疏；60 秒後敵潮加快補回壓力。",
		"rule_change": true
	},
	{
		"id": "contract_elite_beacon",
		"name": "精英信標",
		"description": "首次精英提前到 35 秒；精英額外 +3 金幣。",
		"rule_change": true
	},
	{
		"id": "contract_glass_magnet",
		"name": "玻璃磁界",
		"description": "開局即啟用磁暴回收；全隊最大 HP -8%。",
		"rule_change": true
	},
	{
		"id": "contract_single_thread",
		"name": "單線協定",
		"description": "隊長傷害 +18%；隊員傷害 -10%。",
		"rule_change": true
	}
]

const SHOP_POOLS: Dictionary = {
	"recovery": [
		{"id": "heal_30", "name": "裂隙急救", "description": "回復全隊 30 HP。", "base_cost": 8, "weight": 3.0},
		{"id": "heal_55", "name": "深層急救", "description": "回復全隊 55 HP。", "base_cost": 14, "weight": 1.35},
		{"id": "temporary_shield", "name": "帷幕護盾", "description": "全隊獲得 30 點暫時護盾，持續 12 秒。", "base_cost": 12, "weight": 2.0}
	],
	"power": [
		{"id": "random_qualitative", "name": "偏壓改裝", "description": "隨機取得一張可用質變升級。", "base_cost": 18, "weight": 2.0},
		{"id": "targeted_qualitative", "name": "定向改裝", "description": "指定一張目前可用的質變升級。", "base_cost": 24, "weight": 1.4},
		{"id": "squad_damage_boost", "name": "裂隙過載", "description": "全隊傷害 +15%，持續 20 秒。", "base_cost": 10, "weight": 1.8}
	],
	"gamble": [
		{"id": "refresh_shop", "name": "重整庫存", "description": "刷新本店商品。", "base_cost": 4, "weight": 2.0},
		{"id": "elite_xp_lure", "name": "精英餌標", "description": "下一隻精英額外掉落一顆可見大型 XP。", "base_cost": 9, "weight": 1.6}
	]
}

const PLAYER_UPGRADE_POOL: Array = [
	{
		"id": "move_speed",
		"name": "疾步校準",
		"description": "+20 移動速度",
		"weight": 1,
		"max_level": 6
	},
	{
		"id": "max_hp",
		"name": "裂隙護甲",
		"description": "+20 最大 HP，並回復 20 HP",
		"weight": 1,
		"max_level": 5
	},
	{
		"id": "pickup_radius",
		"name": "回收磁場",
		"description": "+24 拾取範圍",
		"weight": 1,
		"max_level": 5
	}
]

var arena: Node = null
var player: Node = null
var squad_manager: Node = null

var game_running: bool = false
var is_game_over: bool = false
var waiting_for_upgrade: bool = false
var waiting_for_shop: bool = false
var waiting_for_contract: bool = false
var stage_victory_pending: bool = false
var manual_paused: bool = false

var elapsed_time: float = 0.0
var kills: int = 0
var gold: int = 0
var level: int = 1
var xp: int = 0
var xp_required: int = 12
var stats_timer: float = 0.0
var touch_move_vector: Vector2 = Vector2.ZERO
var upgrade_counts: Dictionary = {}
var elites_spawned: int = 0
var elites_killed: int = 0
var elite_spawn_times: Array[float] = []
var elite_kill_times: Array[float] = []
var boss_active: bool = false
var boss_spawned: bool = false
var boss_killed: bool = false
var boss_spawn_time: float = -1.0
var boss_kill_time: float = -1.0
var boss_phase_two_time: float = -1.0
var next_shop_time: float = SHOP_FIRST_TIME
var shop_schedule_index: int = 0
var shop_refresh_count: int = 0
var forced_run_seed: int = 0
var current_run_seed: int = 0
var magnetic_reclaim_enabled: bool = false
var active_contract_id: String = ""
var active_contract_name: String = "無契約"
var contract_modifiers: Dictionary = {}
var temporary_squad_damage_timer: float = 0.0
var next_elite_bonus_xp: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_run(new_arena: Node, new_player: Node, new_squad_manager: Node = null, reset_player: bool = true) -> void:
	arena = new_arena
	player = new_player
	squad_manager = new_squad_manager
	game_running = true
	is_game_over = false
	waiting_for_upgrade = false
	waiting_for_shop = false
	waiting_for_contract = false
	stage_victory_pending = false
	manual_paused = false
	elapsed_time = 0.0
	kills = 0
	gold = 0
	level = 1
	xp = 0
	xp_required = 12
	stats_timer = 0.0
	touch_move_vector = Vector2.ZERO
	upgrade_counts.clear()
	elites_spawned = 0
	elites_killed = 0
	elite_spawn_times.clear()
	elite_kill_times.clear()
	boss_active = false
	boss_spawned = false
	boss_killed = false
	boss_spawn_time = -1.0
	boss_kill_time = -1.0
	boss_phase_two_time = -1.0
	shop_schedule_index = 0
	next_shop_time = _shop_time_for_index(shop_schedule_index)
	shop_refresh_count = 0
	magnetic_reclaim_enabled = false
	active_contract_id = ""
	active_contract_name = "無契約"
	contract_modifiers.clear()
	temporary_squad_damage_timer = 0.0
	next_elite_bonus_xp = 0
	get_tree().paused = false

	if reset_player and player != null and player.has_method("reset_for_run"):
		player.reset_for_run()

	if _should_request_contract():
		_request_contract()
	else:
		emit_stats()
		pause_changed.emit(false)


func _process(delta: float) -> void:
	if game_running and not get_tree().paused:
		elapsed_time += delta
		if temporary_squad_damage_timer > 0.0:
			temporary_squad_damage_timer = max(temporary_squad_damage_timer - delta, 0.0)
		stats_timer -= delta
		if stats_timer <= 0.0:
			stats_timer = 0.1
			emit_stats()
		if elapsed_time >= next_shop_time:
			if _request_shop("timed"):
				_schedule_next_shop_after(next_shop_time)


func emit_stats() -> void:
	stats_changed.emit(get_stats())


func get_stats() -> Dictionary:
	var hp_value := 0.0
	var max_hp_value := 0.0
	if player != null and is_instance_valid(player):
		if player.has_method("get_current_hp"):
			hp_value = player.get_current_hp()
		if player.has_method("get_max_hp"):
			max_hp_value = player.get_max_hp()

	return {
		"hp": hp_value,
		"max_hp": max_hp_value,
		"elapsed_time": elapsed_time,
		"kills": kills,
		"gold": gold,
		"level": level,
		"xp": xp,
		"xp_required": xp_required,
		"game_running": game_running,
		"manual_paused": manual_paused,
		"waiting_for_upgrade": waiting_for_upgrade,
		"waiting_for_shop": waiting_for_shop,
		"waiting_for_contract": waiting_for_contract,
		"magnetic_reclaim_enabled": magnetic_reclaim_enabled,
		"active_contract_id": active_contract_id,
		"active_contract_name": active_contract_name,
		"temporary_squad_damage_timer": temporary_squad_damage_timer,
		"is_game_over": is_game_over
	}


func add_kill(amount: int = 1) -> void:
	if not game_running:
		return
	kills += amount
	emit_stats()


func add_gold(amount: int) -> void:
	if not game_running:
		return
	gold += amount
	emit_stats()


func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if gold < amount:
		return false
	gold -= amount
	emit_stats()
	return true


func add_xp(amount: int) -> void:
	# 允許連續升級，但一次只開一個升級選單，避免 UI 與暫停狀態競態。
	if not game_running or is_game_over:
		return

	xp += amount
	while xp >= xp_required and not waiting_for_upgrade:
		xp -= xp_required
		level += 1
		xp_required = int(round(float(xp_required) * 1.25 + 5.0))
		_request_level_up()

	emit_stats()


func _request_level_up() -> void:
	waiting_for_upgrade = true
	get_tree().paused = true
	emit_stats()
	level_up_requested.emit(_build_upgrade_choices())


func _build_upgrade_choices() -> Array:
	var pool: Array = PLAYER_UPGRADE_POOL.duplicate(true)
	if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("build_upgrade_pool"):
		pool = squad_manager.build_upgrade_pool(pool)
	elif player != null and is_instance_valid(player) and player.has_method("build_upgrade_pool"):
		pool = player.build_upgrade_pool(pool)

	var filtered: Array = []
	for option in pool:
		if _is_upgrade_available(option):
			filtered.append(option)
	return _pick_weighted_choices(filtered, get_upgrade_choice_count())


func apply_upgrade(upgrade: Dictionary) -> void:
	if not waiting_for_upgrade or is_game_over:
		return

	_register_upgrade_pick(upgrade)
	if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("apply_upgrade"):
		squad_manager.apply_upgrade(upgrade)
	elif player != null and is_instance_valid(player) and player.has_method("apply_upgrade"):
		player.apply_upgrade(upgrade)

	waiting_for_upgrade = false

	if xp >= xp_required:
		_request_level_up()
	elif randf() < 0.1 and not waiting_for_shop and _request_shop("level_up_random"):
		return
	else:
		get_tree().paused = manual_paused
		emit_stats()


func _is_upgrade_available(upgrade: Dictionary) -> bool:
	var max_level := int(upgrade.get("max_level", 0))
	if max_level <= 0:
		return true
	return int(upgrade_counts.get(_upgrade_level_key(upgrade), 0)) < max_level


func _register_upgrade_pick(upgrade: Dictionary) -> void:
	var max_level := int(upgrade.get("max_level", 0))
	if max_level <= 0:
		return
	var key := _upgrade_level_key(upgrade)
	upgrade_counts[key] = int(upgrade_counts.get(key, 0)) + 1


func _upgrade_level_key(upgrade: Dictionary) -> String:
	if upgrade.has("level_key"):
		return str(upgrade.get("level_key"))
	return "%s|%s|%s|%s" % [
		str(upgrade.get("id", "")),
		str(upgrade.get("hero_id", "")),
		str(upgrade.get("weapon_id", "")),
		str(upgrade.get("upgrade_kind", ""))
	]


func _pick_weighted_choices(pool: Array, count: int) -> Array:
	var candidates := pool.duplicate(true)
	var choices: Array = []
	while choices.size() < count and not candidates.is_empty():
		var total_weight := 0.0
		for option in candidates:
			total_weight += max(0.0, float(option.get("weight", 1.0)))
		if total_weight <= 0.0:
			break

		var roll := randf() * total_weight
		var cursor := 0.0
		var selected_index := 0
		for index in range(candidates.size()):
			cursor += max(0.0, float(candidates[index].get("weight", 1.0)))
			if roll <= cursor:
				selected_index = index
				break
		choices.append(candidates[selected_index])
		candidates.remove_at(selected_index)
	return choices


func _request_shop(source: String = "timed") -> bool:
	if waiting_for_contract or waiting_for_upgrade or waiting_for_shop or stage_victory_pending or is_game_over or not game_running:
		return false
	if _should_delay_shop_for_boss():
		_delay_shop_for_boss(source)
		return false
	waiting_for_shop = true
	shop_refresh_count = 0
	get_tree().paused = true
	emit_stats()
	shop_requested.emit(_build_shop_options())
	return true


func _build_shop_options() -> Array:
	var options: Array = []
	for pool_name in ["recovery", "power", "gamble"]:
		var template := _pick_weighted_shop_template(SHOP_POOLS.get(pool_name, []))
		if template.is_empty():
			continue
		options.append(_shop_option(_materialize_shop_option(template)))
	return options


func _shop_option(option: Dictionary) -> Dictionary:
	var reason := _shop_option_disabled_reason(option)
	option["enabled"] = reason == ""
	option["disabled_reason"] = reason
	return option


func _shop_option_disabled_reason(option_or_id: Variant) -> String:
	var option: Dictionary = option_or_id if typeof(option_or_id) == TYPE_DICTIONARY else {"id": str(option_or_id)}
	var option_id := str(option.get("id", ""))
	match option_id:
		"heal_30", "heal_55":
			if squad_manager == null or not is_instance_valid(squad_manager) or not squad_manager.has_method("can_heal_members") or not squad_manager.can_heal_members():
				return "全隊已滿血"
		"random_qualitative":
			if squad_manager == null or not is_instance_valid(squad_manager) or not squad_manager.has_method("has_available_qualitative_upgrade") or not squad_manager.has_available_qualitative_upgrade():
				return "沒有可套用的質變"
		"targeted_qualitative":
			if not _can_apply_targeted_qualitative(option):
				return "沒有可指定的質變"
		"temporary_shield":
			if squad_manager == null or not is_instance_valid(squad_manager) or not squad_manager.has_method("get_member_count") or squad_manager.get_member_count() <= 0:
				return "沒有存活隊員"
		"squad_damage_boost":
			if squad_manager == null or not is_instance_valid(squad_manager) or not squad_manager.has_method("get_member_count") or squad_manager.get_member_count() <= 0:
				return "沒有存活隊員"
		"elite_xp_lure":
			if next_elite_bonus_xp > 0:
				return "下一隻精英已標記"
	return ""


func _is_shop_option_meaningful(option: Dictionary) -> bool:
	return _shop_option_disabled_reason(option) == ""


func apply_shop_purchase(option: Dictionary) -> void:
	if not waiting_for_shop or is_game_over:
		return
	var option_id := str(option.get("id", ""))
	if option_id == "skip":
		_close_shop()
		return

	if not _is_shop_option_meaningful(option):
		emit_stats()
		return

	var cost := int(option.get("cost", 0))
	if gold < cost:
		emit_stats()
		return

	var success := false
	match option_id:
		"heal_30":
			success = squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("heal_members") and squad_manager.heal_members(30.0)
		"heal_55":
			success = squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("heal_members") and squad_manager.heal_members(55.0)
		"random_qualitative":
			success = squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("apply_random_qualitative_upgrade") and squad_manager.apply_random_qualitative_upgrade()
		"targeted_qualitative":
			success = _apply_targeted_qualitative(option)
		"temporary_shield":
			success = squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("apply_temporary_shield") and squad_manager.apply_temporary_shield(30.0, 12.0)
		"squad_damage_boost":
			success = _apply_temporary_squad_damage(20.0)
		"elite_xp_lure":
			next_elite_bonus_xp += 20
			success = true
		"refresh_shop":
			success = true

	if success and spend_gold(cost):
		if option_id == "refresh_shop":
			shop_refresh_count += 1
			shop_requested.emit(_build_shop_options())
			emit_stats()
		else:
			_close_shop()
	elif not success:
		emit_stats()


func enable_magnetic_reclaim() -> void:
	magnetic_reclaim_enabled = true


func has_magnetic_reclaim() -> bool:
	return magnetic_reclaim_enabled


func apply_contract(contract: Dictionary) -> void:
	if is_game_over:
		return
	var contract_id := str(contract.get("id", ""))
	var definition := _contract_definition(contract_id)
	if definition.is_empty():
		return

	active_contract_id = contract_id
	active_contract_name = str(definition.get("name", "無契約"))
	contract_modifiers = _contract_modifiers_for(contract_id)
	waiting_for_contract = false
	_apply_contract_start_effects()
	get_tree().paused = manual_paused
	emit_stats()
	pause_changed.emit(false)


func get_upgrade_choice_count() -> int:
	var count := 3
	if active_contract_id == "contract_golden_famine" and elapsed_time < float(contract_modifiers.get("upgrade_choice_until", 0.0)):
		count = int(contract_modifiers.get("upgrade_choice_count", 2))
	return max(1, count)


func get_outgoing_damage_multiplier(source: Node = null) -> float:
	var multiplier := float(contract_modifiers.get("damage_multiplier", 1.0))
	if temporary_squad_damage_timer > 0.0:
		multiplier *= 1.15
	if active_contract_id == "contract_single_thread" and source != null and is_instance_valid(source):
		if bool(source.get("is_leader")):
			multiplier *= float(contract_modifiers.get("leader_damage_multiplier", 1.0))
		else:
			multiplier *= float(contract_modifiers.get("member_damage_multiplier", 1.0))
	return multiplier


func get_incoming_damage_multiplier() -> float:
	return float(contract_modifiers.get("incoming_damage_multiplier", 1.0))


func get_gold_drop_multiplier() -> float:
	return float(contract_modifiers.get("gold_drop_multiplier", 1.0))


func get_gold_drop_amount(base_amount: int) -> int:
	if base_amount <= 0:
		return 0
	var scaled := float(base_amount) * get_gold_drop_multiplier()
	var amount := int(floor(scaled))
	var fractional := scaled - float(amount)
	if randf() < fractional:
		amount += 1
	return max(1, amount)


func get_spawn_timer_multiplier() -> float:
	if active_contract_id != "contract_quiet_veil":
		return 1.0
	if elapsed_time < float(contract_modifiers.get("spawn_timer_switch", 60.0)):
		return float(contract_modifiers.get("spawn_timer_before", 1.25))
	return float(contract_modifiers.get("spawn_timer_after", 0.9))


func get_first_elite_time(fallback: float) -> float:
	return float(contract_modifiers.get("first_elite_time", fallback))


func get_elite_bonus_gold() -> int:
	return int(contract_modifiers.get("elite_bonus_gold", 0))


func consume_next_elite_bonus_xp() -> int:
	var amount := next_elite_bonus_xp
	next_elite_bonus_xp = 0
	return amount


func get_contract_summary() -> Dictionary:
	return {
		"id": active_contract_id,
		"name": active_contract_name,
		"rule_change": bool(_contract_definition(active_contract_id).get("rule_change", false))
	}


func _request_contract() -> void:
	waiting_for_contract = true
	get_tree().paused = true
	emit_stats()
	pause_changed.emit(true)
	contract_requested.emit(_build_contract_choices())


func _build_contract_choices() -> Array:
	return _pick_weighted_choices(CONTRACT_POOL.duplicate(true), 3)


func _contract_definition(contract_id: String) -> Dictionary:
	for definition in CONTRACT_POOL:
		if str(definition.get("id", "")) == contract_id:
			return definition
	return {}


func _contract_modifiers_for(contract_id: String) -> Dictionary:
	match contract_id:
		"contract_blood_tax":
			return {"damage_multiplier": 1.12, "incoming_damage_multiplier": 1.10}
		"contract_golden_famine":
			return {"gold_drop_multiplier": 1.40, "upgrade_choice_count": 2, "upgrade_choice_until": 90.0}
		"contract_quiet_veil":
			return {"spawn_timer_before": 1.25, "spawn_timer_after": 0.9, "spawn_timer_switch": 60.0}
		"contract_elite_beacon":
			return {"first_elite_time": 35.0, "elite_bonus_gold": 3}
		"contract_glass_magnet":
			return {"start_magnetic_reclaim": true, "max_hp_multiplier": 0.92}
		"contract_single_thread":
			return {"leader_damage_multiplier": 1.18, "member_damage_multiplier": 0.90}
		_:
			return {}


func _apply_contract_start_effects() -> void:
	if bool(contract_modifiers.get("start_magnetic_reclaim", false)):
		enable_magnetic_reclaim()

	var hp_multiplier: float = float(contract_modifiers.get("max_hp_multiplier", 1.0))
	if is_equal_approx(hp_multiplier, 1.0):
		return
	var members: Array = _get_squad_members()
	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		var old_max_hp: float = max(1.0, float(member.get("max_hp")))
		var old_current_hp: float = float(member.get("current_hp"))
		var hp_ratio: float = clamp(old_current_hp / old_max_hp, 0.0, 1.0)
		var new_max_hp: float = max(1.0, old_max_hp * hp_multiplier)
		member.set("max_hp", new_max_hp)
		member.set("current_hp", min(new_max_hp, new_max_hp * hp_ratio))


func _should_request_contract() -> bool:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		var scene_path := str(current_scene.scene_file_path)
		if scene_path.begins_with("res://scenes/debug/"):
			return false
	return true


func _pick_weighted_shop_template(pool: Array) -> Dictionary:
	if pool.is_empty():
		return {}
	var total_weight := 0.0
	for option in pool:
		total_weight += max(0.0, float(option.get("weight", 1.0)))
	if total_weight <= 0.0:
		return pool[0].duplicate(true)
	var roll := randf() * total_weight
	var cursor := 0.0
	for option in pool:
		cursor += max(0.0, float(option.get("weight", 1.0)))
		if roll <= cursor:
			return option.duplicate(true)
	return pool[pool.size() - 1].duplicate(true)


func _materialize_shop_option(template: Dictionary) -> Dictionary:
	var option := template.duplicate(true)
	var option_id := str(option.get("id", ""))
	var base_cost := int(option.get("base_cost", option.get("cost", 0)))
	var cost := _shop_price(base_cost)
	if option_id == "refresh_shop":
		cost = base_cost + shop_refresh_count
	option["cost"] = cost
	option.erase("base_cost")

	if option_id == "targeted_qualitative":
		var qualitative_options := _available_qualitative_shop_options()
		if not qualitative_options.is_empty():
			var upgrade: Dictionary = qualitative_options[randi() % qualitative_options.size()]
			option["hero_id"] = str(upgrade.get("hero_id", ""))
			option["weapon_id"] = str(upgrade.get("weapon_id", ""))
			option["upgrade_kind"] = str(upgrade.get("upgrade_kind", ""))
			option["name"] = "定向改裝：" + str(upgrade.get("name", "質變"))
			option["description"] = "直接取得這張質變升級。"
	return option


func _shop_price(base_cost: int) -> int:
	var stage_steps: int = int(floor(max(0.0, elapsed_time) / 180.0))
	var multiplier: float = 1.0 + min(0.6, float(stage_steps) * 0.15)
	return max(1, int(ceil(float(base_cost) * multiplier)))


func _available_qualitative_shop_options() -> Array:
	if squad_manager == null or not is_instance_valid(squad_manager) or not squad_manager.has_method("get_available_qualitative_shop_options"):
		return []
	return squad_manager.get_available_qualitative_shop_options()


func _can_apply_targeted_qualitative(option: Dictionary) -> bool:
	if squad_manager == null or not is_instance_valid(squad_manager) or not squad_manager.has_method("can_apply_qualitative_upgrade"):
		return false
	return squad_manager.can_apply_qualitative_upgrade(
		str(option.get("hero_id", "")),
		str(option.get("weapon_id", "")),
		str(option.get("upgrade_kind", ""))
	)


func _apply_targeted_qualitative(option: Dictionary) -> bool:
	if squad_manager == null or not is_instance_valid(squad_manager) or not squad_manager.has_method("apply_qualitative_upgrade"):
		return false
	return squad_manager.apply_qualitative_upgrade(
		str(option.get("hero_id", "")),
		str(option.get("weapon_id", "")),
		str(option.get("upgrade_kind", ""))
	)


func _apply_temporary_squad_damage(duration: float) -> bool:
	if squad_manager == null or not is_instance_valid(squad_manager) or not squad_manager.has_method("get_member_count") or squad_manager.get_member_count() <= 0:
		return false
	temporary_squad_damage_timer = max(temporary_squad_damage_timer, duration)
	return true


func _should_delay_shop_for_boss() -> bool:
	return bool(boss_active) or _is_in_boss_shop_window(elapsed_time)


func _delay_shop_for_boss(_source: String) -> void:
	if _is_in_boss_shop_window(elapsed_time):
		next_shop_time = _boss_window_end()
	elif bool(boss_active):
		next_shop_time = max(next_shop_time, elapsed_time + SHOP_BOSS_ACTIVE_RETRY)


func _is_in_boss_shop_window(time_value: float) -> bool:
	return time_value >= SHOP_BOSS_TIME - SHOP_BOSS_WINDOW_BEFORE and time_value <= SHOP_BOSS_TIME + SHOP_BOSS_WINDOW_AFTER


func _boss_window_end() -> float:
	return SHOP_BOSS_TIME + SHOP_BOSS_WINDOW_AFTER


func _schedule_next_shop_after(reference_time: float) -> void:
	while _shop_time_for_index(shop_schedule_index) <= reference_time + 0.001:
		shop_schedule_index += 1
	next_shop_time = _avoid_boss_window(_shop_time_for_index(shop_schedule_index))


func _avoid_boss_window(time_value: float) -> float:
	if _is_in_boss_shop_window(time_value):
		return _boss_window_end()
	return time_value


func _shop_time_for_index(index: int) -> float:
	if index <= 0:
		return SHOP_FIRST_TIME
	if index == 1:
		return SHOP_SECOND_TIME
	return SHOP_SECOND_TIME + SHOP_INTERVAL * float(index - 1)


func _get_squad_members() -> Array:
	if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("get_members"):
		return squad_manager.get_members()
	if player != null and is_instance_valid(player):
		return [player]
	return []


func _close_shop() -> void:
	waiting_for_shop = false
	get_tree().paused = manual_paused
	emit_stats()


func toggle_pause() -> void:
	if waiting_for_contract or waiting_for_upgrade or waiting_for_shop or stage_victory_pending or is_game_over or not game_running:
		return
	set_manual_pause(not manual_paused)


func set_manual_pause(value: bool) -> void:
	if waiting_for_contract or waiting_for_upgrade or waiting_for_shop or stage_victory_pending or is_game_over or not game_running:
		return
	manual_paused = value
	get_tree().paused = value
	pause_changed.emit(value)
	emit_stats()


func set_touch_move_vector(direction: Vector2) -> void:
	touch_move_vector = direction.limit_length(1.0)


func get_touch_move_vector() -> Vector2:
	return touch_move_vector


func player_died() -> void:
	if is_game_over:
		return

	var dead_player := player
	is_game_over = true
	game_running = false
	waiting_for_upgrade = false
	waiting_for_shop = false
	waiting_for_contract = false
	manual_paused = false
	if dead_player != null and is_instance_valid(dead_player):
		dead_player.set_process(false)
		dead_player.set_physics_process(false)
	player = null
	get_tree().paused = true
	emit_stats()
	game_over_requested.emit({
		"elapsed_time": elapsed_time,
		"kills": kills,
		"gold": gold,
		"level": level,
		"elites_killed": elites_killed,
		"boss_killed": boss_killed,
		"contract_name": active_contract_name
	})


func record_elite_spawn() -> void:
	elites_spawned += 1
	elite_spawn_times.append(elapsed_time)


func record_elite_kill() -> void:
	elites_killed += 1
	elite_kill_times.append(elapsed_time)


func record_boss_spawn() -> void:
	boss_spawned = true
	boss_spawn_time = elapsed_time


func set_boss_active(value: bool) -> void:
	boss_active = value


func record_boss_phase_two() -> void:
	if boss_phase_two_time < 0.0:
		boss_phase_two_time = elapsed_time


func record_boss_kill() -> void:
	if boss_killed:
		return
	boss_killed = true
	boss_active = false
	boss_kill_time = elapsed_time
	stage_victory_pending = true
	if elapsed_time >= next_shop_time:
		next_shop_time = elapsed_time + SHOP_POST_VICTORY_GRACE
	get_tree().paused = true
	emit_stats()
	stage_victory_requested.emit({
		"elapsed_time": elapsed_time,
		"kills": kills,
		"gold": gold,
		"level": level,
		"elites_killed": elites_killed,
		"contract_name": active_contract_name
	})


func continue_after_stage_victory() -> void:
	if not stage_victory_pending:
		return
	stage_victory_pending = false
	if elapsed_time >= next_shop_time:
		next_shop_time = elapsed_time + SHOP_POST_VICTORY_GRACE
	get_tree().paused = manual_paused
	emit_stats()


func format_time(seconds_value: float) -> String:
	var total_seconds := int(floor(seconds_value))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
