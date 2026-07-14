extends Node

signal stats_changed(stats: Dictionary)
signal level_up_requested(options: Array)
signal game_over_requested(summary: Dictionary)
signal pause_changed(is_paused: bool)
signal shop_requested(options: Array)
signal stage_victory_requested(summary: Dictionary)
signal contract_requested(options: Array)
signal toast_requested(message: String)
signal guide_replay_requested
signal level_flash_requested
signal combo_pulse_requested(combo_count: int)
signal combo_milestone_requested(combo_count: int)
signal combo_break_requested(combo_count: int)
signal boss_intro_requested(boss_name: String)
signal boss_phase_transition_requested
signal captain_ability_hit_flash_requested

const SHOP_FIRST_TIME := 75.0
const SHOP_SECOND_TIME := 150.0
const SHOP_INTERVAL := 90.0
const SHOP_BOSS_TIME := 180.0
const SHOP_BOSS_WINDOW_BEFORE := 15.0
const SHOP_BOSS_WINDOW_AFTER := 25.0
const SHOP_BOSS_ACTIVE_RETRY := 5.0
const SHOP_POST_VICTORY_GRACE := 12.0
const COMBO_WINDOW := 1.15
const COMBO_MILESTONES: Array[int] = [25, 50, 100]
const COMBO_FIRE_RATE_BUFF_DURATION := 5.0

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

const FALLBACK_UPGRADE_POOL: Array = [
	{
		"id": "fallback_heal",
		"name": "緊急整補",
		"description": "全隊回復 18 HP。升級池耗盡時的保底選項。",
		"weight": 1,
		"upgrade_category": "fallback"
	},
	{
		"id": "fallback_gold",
		"name": "裂隙拾荒",
		"description": "立刻取得 8 金幣。升級池耗盡時的保底選項。",
		"weight": 1,
		"upgrade_category": "fallback"
	},
	{
		"id": "fallback_damage",
		"name": "短路超載",
		"description": "全隊傷害 +15%，持續 12 秒。升級池耗盡時的保底選項。",
		"weight": 1,
		"upgrade_category": "fallback"
	}
]

const AFFIX_TOASTS: Dictionary = {
	"affix_split": "裂殖精英——死亡時分裂！",
	"affix_field": "力場精英——靠近會緩速！",
	"affix_swift": "迅捷精英——高速衝刺突入！"
}

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
var system_pause_owners: Dictionary = {}

var elapsed_time: float = 0.0
var kills: int = 0
var gold: int = 0
var gold_earned: int = 0
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
var current_run_theme_id: String = ""
var current_run_theme_name: String = ""
var magnetic_reclaim_enabled: bool = false
var active_contract_id: String = ""
var active_contract_name: String = "無契約"
var contract_modifiers: Dictionary = {}
var temporary_squad_damage_timer: float = 0.0
var combo_fire_rate_timer: float = 0.0
var next_elite_bonus_xp: int = 0
var echo_shards_awarded_this_run: int = 0
var seen_affix_toasts: Dictionary = {}
var pending_toasts: Array[String] = []
var run_token: int = 0
var hit_stop_token: int = 0
var time_scale_owner_tokens: Dictionary = {}
var time_scale_owner_scales: Dictionary = {}
var time_scale_next_token: int = 1
var stats_emit_pending: bool = false
var camera_threat_zoom_timer: float = 0.0
var combo_count: int = 0
var combo_last_kill_time: float = -999.0
var last_combo_pulse_count: int = 0
var last_combo_milestone_count: int = 0
var upgrade_entry_token: int = 0
var combat_metrics_enabled: bool = false
var combat_damage_by_weapon: Dictionary = {}
var combat_damage_total: float = 0.0
# Debug-build capture aid. Runtime systems may read this flag only to raise
# presentation LOD; gameplay cadence and release builds must remain unchanged.
var screenshot_beauty_mode: bool = false

const META_HP_APPLIED_KEY := "_cv_meta_hp_multiplier_applied"
const META_PICKUP_APPLIED_KEY := "_cv_meta_pickup_bonus_applied"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_run(new_arena: Node, new_player: Node, new_squad_manager: Node = null, reset_player: bool = true) -> void:
	clear_time_scale_owners()
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
	gold_earned = 0
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
	combo_fire_rate_timer = 0.0
	next_elite_bonus_xp = 0
	echo_shards_awarded_this_run = 0
	seen_affix_toasts.clear()
	run_token += 1
	camera_threat_zoom_timer = 0.0
	combo_count = 0
	combo_last_kill_time = -999.0
	last_combo_pulse_count = 0
	last_combo_milestone_count = 0
	upgrade_entry_token += 1
	if AchievementProgress != null and AchievementProgress.has_method("start_run"):
		AchievementProgress.start_run()
	system_pause_owners.clear()
	_sync_pause_state()

	if reset_player and player != null and player.has_method("reset_for_run"):
		player.reset_for_run()
	_apply_meta_progress_start_effects()
	_schedule_survival_achievement_timer(run_token)

	if _should_request_contract():
		_request_contract()
	else:
		emit_stats()
		_emit_pause_changed()


func _process(delta: float) -> void:
	if game_running and not get_tree().paused:
		elapsed_time += delta
		if temporary_squad_damage_timer > 0.0:
			temporary_squad_damage_timer = max(temporary_squad_damage_timer - delta, 0.0)
		if combo_fire_rate_timer > 0.0:
			combo_fire_rate_timer = max(combo_fire_rate_timer - delta, 0.0)
		if camera_threat_zoom_timer > 0.0:
			camera_threat_zoom_timer = max(camera_threat_zoom_timer - delta, 0.0)
		_tick_combo_break()
		stats_timer -= delta
		if stats_timer <= 0.0:
			stats_timer = 0.1
			emit_stats()
		if elapsed_time >= next_shop_time:
			if _request_shop("timed"):
				_schedule_next_shop_after(next_shop_time)


func _schedule_survival_achievement_timer(token: int) -> void:
	await get_tree().create_timer(300.0, false).timeout
	if token != run_token or not game_running or is_game_over:
		return
	if AchievementProgress != null and AchievementProgress.has_method("record_survival_time"):
		AchievementProgress.record_survival_time(elapsed_time)


func show_toast(message: String) -> void:
	if message == "":
		return
	toast_requested.emit(message)


func request_captain_ability_hit_flash() -> void:
	captain_ability_hit_flash_requested.emit()


func acquire_time_scale(owner: String, scale: float) -> int:
	if owner == "":
		return 0
	var token := time_scale_next_token
	time_scale_next_token += 1
	time_scale_owner_tokens[owner] = token
	time_scale_owner_scales[owner] = clamp(scale, 0.05, 1.0)
	_sync_time_scale()
	return token


func release_time_scale(owner: String, token: int = 0) -> void:
	if owner == "":
		return
	if token > 0 and int(time_scale_owner_tokens.get(owner, 0)) != token:
		return
	time_scale_owner_tokens.erase(owner)
	time_scale_owner_scales.erase(owner)
	_sync_time_scale()


func clear_time_scale_owners() -> void:
	time_scale_owner_tokens.clear()
	time_scale_owner_scales.clear()
	Engine.time_scale = 1.0


func get_time_scale_owner_count() -> int:
	return time_scale_owner_scales.size()


func _sync_time_scale() -> void:
	if time_scale_owner_scales.is_empty():
		Engine.time_scale = 1.0
		return
	var scale := 1.0
	for owner in time_scale_owner_scales.keys():
		scale = min(scale, float(time_scale_owner_scales[owner]))
	Engine.time_scale = scale


func request_combat_impact(shake_strength: float = 4.0, hit_stop_duration: float = 0.04) -> void:
	if player != null and is_instance_valid(player) and player.has_method("request_screen_shake"):
		player.request_screen_shake(shake_strength, 0.16)
	if hit_stop_duration <= 0.0 or get_tree().paused:
		return
	hit_stop_token += 1
	var owner := "hit_stop:%d" % hit_stop_token
	var local_token := acquire_time_scale(owner, 0.18)
	await get_tree().create_timer(hit_stop_duration, true, false, true).timeout
	release_time_scale(owner, local_token)


func request_camera_threat_zoom(duration: float = 1.4) -> void:
	camera_threat_zoom_timer = max(camera_threat_zoom_timer, max(0.0, duration))


func is_camera_threat_zoom_requested() -> bool:
	return camera_threat_zoom_timer > 0.0


func queue_toast(message: String) -> void:
	if message == "":
		return
	pending_toasts.append(message)


func consume_pending_toasts() -> Array[String]:
	var result: Array[String] = pending_toasts.duplicate()
	pending_toasts.clear()
	return result


func request_guide_replay() -> void:
	guide_replay_requested.emit()


func seed_from_text(text: String) -> int:
	var source := text.strip_edges()
	var digits := ""
	var last_digits := ""
	for index in range(source.length()):
		var codepoint := source.unicode_at(index)
		if codepoint >= 48 and codepoint <= 57:
			digits += String.chr(codepoint)
		elif digits != "":
			last_digits = digits
			digits = ""
	if digits != "":
		last_digits = digits
	if last_digits == "":
		return 0
	var value := int(last_digits)
	return value if value > 0 else 0


func copy_current_run_seed_to_clipboard() -> bool:
	if current_run_seed <= 0:
		show_toast("本局種子尚未建立。")
		return false
	DisplayServer.clipboard_set(str(current_run_seed))
	show_toast("已複製本局種子：%d" % current_run_seed)
	return true


func emit_stats() -> void:
	stats_changed.emit(get_stats())


func queue_stats_emit() -> void:
	if stats_emit_pending:
		return
	stats_emit_pending = true
	call_deferred("_flush_queued_stats_emit")


func _flush_queued_stats_emit() -> void:
	stats_emit_pending = false
	emit_stats()


func set_current_run_theme(theme_id: String, theme_name: String) -> void:
	current_run_theme_id = theme_id
	current_run_theme_name = theme_name


func get_stats() -> Dictionary:
	var hp_value := 0.0
	var max_hp_value := 0.0
	var active_bond_names := PackedStringArray()
	if player != null and is_instance_valid(player):
		if player.has_method("get_current_hp"):
			hp_value = player.get_current_hp()
		if player.has_method("get_max_hp"):
			max_hp_value = player.get_max_hp()
	if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("get_active_bond_names"):
		active_bond_names = squad_manager.get_active_bond_names()

	return {
		"hp": hp_value,
		"max_hp": max_hp_value,
		"elapsed_time": elapsed_time,
		"kills": kills,
		"gold": gold,
		"gold_earned": gold_earned,
		"echo_shards": int(MetaProgress.get("shards")) if MetaProgress != null else 0,
		"level": level,
		"xp": xp,
		"xp_required": xp_required,
		"game_running": game_running,
		"manual_paused": manual_paused,
		"system_paused": _has_system_pause_owner(),
		"manual_pause_visible": _is_manual_pause_visible(),
		"waiting_for_upgrade": waiting_for_upgrade,
		"waiting_for_shop": waiting_for_shop,
		"waiting_for_contract": waiting_for_contract,
		"magnetic_reclaim_enabled": magnetic_reclaim_enabled,
		"active_contract_id": active_contract_id,
		"active_contract_name": active_contract_name,
		"run_seed": current_run_seed,
		"run_theme_id": current_run_theme_id,
		"run_theme_name": current_run_theme_name,
		"active_bond_names": active_bond_names,
		"active_bond_count": active_bond_names.size(),
		"temporary_squad_damage_timer": temporary_squad_damage_timer,
		"combo_fire_rate_timer": combo_fire_rate_timer,
		"is_game_over": is_game_over
	}


func is_system_pause_active() -> bool:
	return _has_system_pause_owner()


func _request_system_pause(owner: String) -> void:
	if owner == "":
		return
	system_pause_owners[owner] = true
	_sync_pause_state()
	_emit_pause_changed()


func _release_system_pause(owner: String) -> void:
	if owner == "":
		return
	system_pause_owners.erase(owner)
	_sync_pause_state()
	_emit_pause_changed()


func _clear_system_pauses() -> void:
	system_pause_owners.clear()
	_sync_pause_state()
	_emit_pause_changed()


func _has_system_pause_owner() -> bool:
	return not system_pause_owners.is_empty()


func _is_manual_pause_visible() -> bool:
	return manual_paused and not _has_system_pause_owner()


func _sync_pause_state() -> void:
	get_tree().paused = manual_paused or _has_system_pause_owner()


func _emit_pause_changed() -> void:
	pause_changed.emit(_is_manual_pause_visible())


func add_kill(amount: int = 1) -> void:
	if not game_running:
		return
	kills += amount
	_record_combo_kill(amount)
	if AchievementProgress != null and AchievementProgress.has_method("record_kills"):
		AchievementProgress.record_kills(kills)
	queue_stats_emit()


func _record_combo_kill(amount: int) -> void:
	if amount <= 0:
		return
	if elapsed_time - combo_last_kill_time <= COMBO_WINDOW:
		combo_count += amount
	else:
		combo_count = amount
		last_combo_pulse_count = 0
		last_combo_milestone_count = 0
	combo_last_kill_time = elapsed_time
	if combo_count < 3:
		return
	var combo_position := Vector2.ZERO
	if player != null and is_instance_valid(player):
		combo_position = player.global_position + Vector2(0.0, -72.0)
	if combo_count < 10 or combo_count % 5 == 0:
		EntityFactory.spawn_combo_text(combo_count, combo_position)
	if combo_count >= 10 and combo_count % 10 == 0 and combo_count != last_combo_pulse_count:
		last_combo_pulse_count = combo_count
		_trigger_combo_pulse(combo_count, combo_position)
	_try_trigger_combo_milestone(combo_count, combo_position)


func _trigger_combo_pulse(pulse_count: int, world_position: Vector2) -> void:
	combo_pulse_requested.emit(pulse_count)
	EntityFactory.spawn_death_burst(world_position, Color(0.62, 1.0, 0.9), 1.75)
	request_combat_impact(2.8, 0.018)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		var pitch: float = 0.92 + min(0.68, float(pulse_count / 10) * 0.08)
		AudioManager.play_sfx("combo", false, -3.0, pitch)


func _try_trigger_combo_milestone(current_combo: int, world_position: Vector2) -> void:
	for milestone in COMBO_MILESTONES:
		if current_combo >= milestone and last_combo_milestone_count < milestone:
			_trigger_combo_milestone(milestone, world_position)


func _trigger_combo_milestone(milestone: int, world_position: Vector2) -> void:
	last_combo_milestone_count = milestone
	combo_fire_rate_timer = max(combo_fire_rate_timer, COMBO_FIRE_RATE_BUFF_DURATION)
	combo_milestone_requested.emit(milestone)
	EntityFactory.spawn_death_burst(world_position, Color(1.0, 0.78, 0.24), 2.15, "gold_rain")
	request_combat_impact(4.2, 0.026)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("combo_milestone", false, -2.0, 0.96 + min(0.24, float(milestone) / 420.0))


func _tick_combo_break() -> void:
	if combo_count < 3:
		return
	if elapsed_time - combo_last_kill_time <= COMBO_WINDOW:
		return
	var broken_combo := combo_count
	combo_count = 0
	last_combo_pulse_count = 0
	last_combo_milestone_count = 0
	combo_break_requested.emit(broken_combo)


func add_gold(amount: int) -> void:
	if not game_running:
		return
	gold += amount
	gold_earned += max(0, amount)
	queue_stats_emit()


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
	while _try_request_pending_level_up():
		pass

	queue_stats_emit()


func _request_level_up() -> void:
	if not _can_request_level_up():
		return
	waiting_for_upgrade = true
	upgrade_entry_token += 1
	var local_token := upgrade_entry_token
	var choices := _build_upgrade_choices()
	_spawn_level_up_ritual()
	var time_scale_owner := "level_up:%d" % local_token
	var time_scale_token := acquire_time_scale(time_scale_owner, 0.35)
	emit_stats()
	_finish_level_up_slowmo(local_token, choices, time_scale_owner, time_scale_token)


func _spawn_level_up_ritual() -> void:
	if player == null or not is_instance_valid(player):
		return
	EntityFactory.spawn_death_burst(player.global_position, Color(0.68, 1.0, 0.88), 1.35, "level_column")


func _finish_level_up_slowmo(local_token: int, choices: Array, time_scale_owner: String, time_scale_token: int) -> void:
	await get_tree().create_timer(0.3, true, false, true).timeout
	if local_token != upgrade_entry_token:
		release_time_scale(time_scale_owner, time_scale_token)
		return
	if not waiting_for_upgrade or is_game_over or stage_victory_pending or not game_running:
		release_time_scale(time_scale_owner, time_scale_token)
		return
	release_time_scale(time_scale_owner, time_scale_token)
	_request_system_pause("upgrade")
	emit_stats()
	level_up_requested.emit(choices)


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
	var choices := _pick_upgrade_choices(filtered, get_upgrade_choice_count())
	if choices.is_empty():
		return _build_fallback_upgrade_choices()
	return choices


func apply_upgrade(upgrade: Dictionary) -> void:
	if not waiting_for_upgrade or is_game_over:
		return
	upgrade_entry_token += 1
	clear_time_scale_owners()

	_register_upgrade_pick(upgrade)
	var upgrade_id := str(upgrade.get("id", ""))
	var was_fallback := _apply_fallback_upgrade(upgrade_id)
	if was_fallback:
		pass
	elif squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("apply_upgrade"):
		squad_manager.apply_upgrade(upgrade)
	elif player != null and is_instance_valid(player) and player.has_method("apply_upgrade"):
		player.apply_upgrade(upgrade)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("upgrade")

	waiting_for_upgrade = false

	if _try_request_pending_level_up():
		return
	elif not was_fallback and randf() < 0.1 and not waiting_for_shop and _request_shop("level_up_random"):
		_release_system_pause("upgrade")
		return
	else:
		_release_system_pause("upgrade")
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


func _pick_upgrade_choices(pool: Array, count: int) -> Array:
	var choices := _pick_weighted_choices(pool, count)
	if count < 3 or choices.is_empty() or _has_non_leader_upgrade_choice(choices):
		return choices

	var selected_keys: Dictionary = {}
	for choice in choices:
		selected_keys[_upgrade_level_key(choice)] = true

	var non_leader_candidates: Array = []
	for option in pool:
		if _is_leader_upgrade_option(option):
			continue
		if selected_keys.has(_upgrade_level_key(option)):
			continue
		non_leader_candidates.append(option)
	if non_leader_candidates.is_empty():
		return choices

	var replacement := _pick_weighted_choices(non_leader_candidates, 1)
	if replacement.is_empty():
		return choices

	var replace_index := _leader_upgrade_replacement_index(choices)
	if replace_index >= 0:
		choices[replace_index] = replacement[0]
	return choices


func _has_non_leader_upgrade_choice(choices: Array) -> bool:
	for choice in choices:
		if not _is_leader_upgrade_option(choice):
			return true
	return false


func _leader_upgrade_replacement_index(choices: Array) -> int:
	for index in range(choices.size() - 1, -1, -1):
		if _is_leader_upgrade_option(choices[index]):
			return index
	return -1


func _is_leader_upgrade_option(option: Dictionary) -> bool:
	if str(option.get("id", "")) != "upgrade_hero_weapon":
		return false
	var hero_id := str(option.get("hero_id", ""))
	if hero_id == "":
		return false
	if squad_manager == null or not is_instance_valid(squad_manager) or not squad_manager.has_method("get_member_by_id"):
		return false
	var member: Node = squad_manager.get_member_by_id(hero_id)
	return member != null and is_instance_valid(member) and bool(member.get("is_leader"))


func _build_fallback_upgrade_choices() -> Array:
	return FALLBACK_UPGRADE_POOL.duplicate(true)


func _apply_fallback_upgrade(upgrade_id: String) -> bool:
	match upgrade_id:
		"fallback_heal":
			if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("heal_members"):
				squad_manager.heal_members(18.0)
			elif player != null and is_instance_valid(player) and player.has_method("heal"):
				player.heal(18.0)
			return true
		"fallback_gold":
			add_gold(8)
			return true
		"fallback_damage":
			_apply_temporary_squad_damage(12.0)
			return true
	return false


func _can_request_level_up() -> bool:
	return (
		game_running
		and not is_game_over
		and not waiting_for_upgrade
		and not waiting_for_shop
		and not waiting_for_contract
		and not stage_victory_pending
	)


func _try_request_pending_level_up() -> bool:
	if xp < xp_required or not _can_request_level_up():
		return false
	xp -= xp_required
	level += 1
	xp_required = int(round(float(xp_required) * 1.25 + 5.0))
	level_flash_requested.emit()
	_request_level_up()
	return true


func _request_shop(source: String = "timed") -> bool:
	if waiting_for_contract or waiting_for_upgrade or waiting_for_shop or stage_victory_pending or is_game_over or not game_running:
		return false
	if _should_delay_shop_for_boss():
		_delay_shop_for_boss(source)
		return false
	waiting_for_shop = true
	shop_refresh_count = 0
	_request_system_pause("shop")
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
	_release_system_pause("contract")
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("contract")
	if _try_request_pending_level_up():
		return
	emit_stats()


func get_upgrade_choice_count() -> int:
	var count := 3
	if active_contract_id == "contract_golden_famine" and elapsed_time < float(contract_modifiers.get("upgrade_choice_until", 0.0)):
		count = int(contract_modifiers.get("upgrade_choice_count", 2))
	if MetaProgress.has_method("get_starting_upgrade_choice_bonus"):
		count += int(MetaProgress.get_starting_upgrade_choice_bonus(level))
	return max(1, count)


func get_outgoing_damage_multiplier(source: Node = null) -> float:
	var multiplier := float(contract_modifiers.get("damage_multiplier", 1.0))
	if MetaProgress.has_method("get_damage_multiplier"):
		multiplier *= float(MetaProgress.get_damage_multiplier())
	if temporary_squad_damage_timer > 0.0:
		multiplier *= 1.15
	if active_contract_id == "contract_single_thread" and source != null and is_instance_valid(source):
		if bool(source.get("is_leader")):
			multiplier *= float(contract_modifiers.get("leader_damage_multiplier", 1.0))
		else:
			multiplier *= float(contract_modifiers.get("member_damage_multiplier", 1.0))
	return multiplier


func get_fire_rate_multiplier(_source: Node = null) -> float:
	return 1.1 if combo_fire_rate_timer > 0.0 else 1.0


func get_kill_thump_pitch(base_pitch: float) -> float:
	var combo_value: float = max(0.0, float(combo_count))
	var lift: float = min(0.16, log(combo_value + 1.0) / log(101.0) * 0.16)
	return clamp(base_pitch + lift, 0.55, 1.28)


func get_incoming_damage_multiplier(target: Node = null) -> float:
	var reduction_multiplier := 1.0
	if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("has_active_bond"):
		if squad_manager.has_active_bond("bond_guard_echo"):
			reduction_multiplier *= 0.95
	if target != null and is_instance_valid(target) and str(target.get("passive_id")) == "shepherd":
		var construct_count := mini(4, EntityFactory.get_rift_construct_count_for_owner(target))
		reduction_multiplier *= 1.0 - float(construct_count) * 0.02
	reduction_multiplier = max(0.85, reduction_multiplier)
	return float(contract_modifiers.get("incoming_damage_multiplier", 1.0)) * reduction_multiplier


func reset_combat_metrics(enabled: bool = true) -> void:
	combat_metrics_enabled = enabled
	combat_damage_by_weapon.clear()
	combat_damage_total = 0.0


func record_weapon_damage(source: Node, weapon_id: String, amount: float) -> void:
	if not combat_metrics_enabled or amount <= 0.0:
		return
	var hero_id := "unknown"
	if source != null and is_instance_valid(source):
		hero_id = str(source.get("hero_id"))
	if weapon_id == "":
		weapon_id = "unknown"
	var key := hero_id + ":" + weapon_id
	combat_damage_by_weapon[key] = float(combat_damage_by_weapon.get(key, 0.0)) + amount
	combat_damage_total += amount


func get_combat_metrics() -> Dictionary:
	return {
		"enabled": combat_metrics_enabled,
		"total_damage": combat_damage_total,
		"damage_by_weapon": combat_damage_by_weapon.duplicate(true)
	}


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
	_request_system_pause("contract")
	emit_stats()
	contract_requested.emit(_build_contract_choices())


func _build_contract_choices() -> Array:
	var count := 3
	if MetaProgress.has_method("get_contract_choice_bonus"):
		count += int(MetaProgress.get_contract_choice_bonus())
	return _pick_weighted_choices(CONTRACT_POOL.duplicate(true), count)


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


func apply_current_meta_progress_to_squad() -> void:
	_apply_meta_progress_to_members(_get_squad_members())


func apply_current_meta_progress_to_member(member: Node) -> void:
	_apply_meta_progress_to_members([member])


func _apply_meta_progress_start_effects() -> void:
	apply_current_meta_progress_to_squad()


func _apply_meta_progress_to_members(members: Array) -> void:
	if not MetaProgress.has_method("get_max_hp_multiplier"):
		return
	var hp_multiplier: float = float(MetaProgress.get_max_hp_multiplier())
	var pickup_bonus: float = float(MetaProgress.get_pickup_radius_bonus()) if MetaProgress.has_method("get_pickup_radius_bonus") else 0.0
	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		var previous_hp_multiplier: float = _as_float(member.get_meta(META_HP_APPLIED_KEY, 1.0), 1.0)
		if previous_hp_multiplier <= 0.0:
			previous_hp_multiplier = 1.0
		var old_max_hp: float = max(1.0, _as_float(member.get("max_hp"), 1.0))
		var old_current_hp: float = _as_float(member.get("current_hp"), old_max_hp)
		var hp_ratio: float = clamp(old_current_hp / old_max_hp, 0.0, 1.0)
		var base_max_hp: float = max(1.0, old_max_hp / previous_hp_multiplier)
		var new_max_hp: float = max(1.0, base_max_hp * hp_multiplier)
		member.set("max_hp", new_max_hp)
		member.set("current_hp", min(new_max_hp, new_max_hp * hp_ratio))
		member.set_meta(META_HP_APPLIED_KEY, hp_multiplier)

		var previous_pickup_bonus: float = _as_float(member.get_meta(META_PICKUP_APPLIED_KEY, 0.0), 0.0)
		var base_pickup_radius: float = max(0.0, _as_float(member.get("pickup_radius"), 80.0) - previous_pickup_bonus)
		member.set("pickup_radius", base_pickup_radius + pickup_bonus)
		member.set_meta(META_PICKUP_APPLIED_KEY, pickup_bonus)


func _as_float(value: Variant, fallback: float = 0.0) -> float:
	match typeof(value):
		TYPE_FLOAT, TYPE_INT:
			return float(value)
		_:
			return fallback


func _summary_with_echo(summary: Dictionary) -> Dictionary:
	var enriched := summary.duplicate(true)
	var total_eligible: int = 0
	if MetaProgress.has_method("calculate_run_shards"):
		total_eligible = int(MetaProgress.calculate_run_shards(enriched))
	var delta: int = max(0, total_eligible - echo_shards_awarded_this_run)
	var awarded: int = 0
	if delta > 0 and MetaProgress.has_method("award_run"):
		awarded = int(MetaProgress.award_run(_summary_for_echo_delta(enriched, delta)))
		echo_shards_awarded_this_run += awarded
	enriched["echo_shards_earned"] = awarded
	enriched["echo_shards_run_total"] = echo_shards_awarded_this_run
	if MetaProgress.has_method("get_progress_summary"):
		enriched["echo_progress"] = MetaProgress.get_progress_summary()
	enriched["run_seed"] = current_run_seed
	if AchievementProgress != null and AchievementProgress.has_method("get_run_unlocked_definitions"):
		enriched["achievement_unlocks"] = AchievementProgress.get_run_unlocked_definitions()
	return enriched


func _summary_for_echo_delta(summary: Dictionary, desired_delta: int) -> Dictionary:
	var delta_summary := summary.duplicate(true)
	delta_summary["gold"] = 0
	delta_summary["gold_earned"] = 0
	delta_summary["kills"] = 0
	delta_summary["level"] = 0
	delta_summary["elites_killed"] = 0
	delta_summary["boss_killed"] = false
	delta_summary["elapsed_time"] = 0.0
	delta_summary["_fixed_echo_delta"] = desired_delta
	return delta_summary


func _close_shop() -> void:
	waiting_for_shop = false
	_release_system_pause("shop")
	if _try_request_pending_level_up():
		return
	emit_stats()


func toggle_pause() -> void:
	if waiting_for_contract or waiting_for_upgrade or waiting_for_shop or stage_victory_pending or is_game_over or not game_running:
		return
	set_manual_pause(not manual_paused)


func set_manual_pause(value: bool) -> void:
	if waiting_for_contract or waiting_for_upgrade or waiting_for_shop or stage_victory_pending or is_game_over or not game_running:
		return
	manual_paused = value
	_sync_pause_state()
	_emit_pause_changed()
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
	upgrade_entry_token += 1
	clear_time_scale_owners()
	waiting_for_upgrade = false
	waiting_for_shop = false
	waiting_for_contract = false
	stage_victory_pending = false
	manual_paused = false
	system_pause_owners.clear()
	if dead_player != null and is_instance_valid(dead_player):
		dead_player.set_process(false)
		dead_player.set_physics_process(false)
	player = null
	_request_system_pause("game_over")
	if AchievementProgress != null and AchievementProgress.has_method("record_survival_time"):
		AchievementProgress.record_survival_time(elapsed_time)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("death")
	emit_stats()
	var summary := {
		"elapsed_time": elapsed_time,
		"kills": kills,
		"gold": gold,
		"gold_earned": gold_earned,
		"level": level,
		"elites_spawned": elites_spawned,
		"elites_killed": elites_killed,
		"boss_spawned": boss_spawned,
		"boss_active": boss_active,
		"boss_phase_two_reached": boss_phase_two_time >= 0.0,
		"boss_killed": boss_killed,
		"contract_name": active_contract_name
	}
	game_over_requested.emit(_summary_with_echo(summary))


func record_elite_spawn() -> void:
	elites_spawned += 1
	elite_spawn_times.append(elapsed_time)


func record_elite_kill() -> void:
	elites_killed += 1
	elite_kill_times.append(elapsed_time)
	if AchievementProgress != null and AchievementProgress.has_method("record_elite_kill"):
		AchievementProgress.record_elite_kill()


func record_boss_spawn(boss_name: String = "VEIL GATEKEEPER") -> void:
	boss_spawned = true
	boss_spawn_time = elapsed_time
	boss_intro_requested.emit(boss_name)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("boss_roar", false, -2.5, 0.92)


func set_boss_active(value: bool) -> void:
	boss_active = value


func record_boss_phase_two() -> void:
	if boss_phase_two_time < 0.0:
		boss_phase_two_time = elapsed_time
		boss_phase_transition_requested.emit()


func record_boss_kill() -> void:
	if boss_killed:
		return
	boss_killed = true
	boss_active = false
	upgrade_entry_token += 1
	clear_time_scale_owners()
	boss_kill_time = elapsed_time
	if AchievementProgress != null and AchievementProgress.has_method("record_boss_kill"):
		AchievementProgress.record_boss_kill()
	if AchievementProgress != null and AchievementProgress.has_method("record_survival_time"):
		AchievementProgress.record_survival_time(elapsed_time)
	waiting_for_upgrade = false
	waiting_for_shop = false
	waiting_for_contract = false
	system_pause_owners.clear()
	stage_victory_pending = true
	if elapsed_time >= next_shop_time:
		next_shop_time = elapsed_time + SHOP_POST_VICTORY_GRACE
	_request_system_pause("stage_victory")
	emit_stats()
	var summary := {
		"elapsed_time": elapsed_time,
		"kills": kills,
		"gold": gold,
		"gold_earned": gold_earned,
		"level": level,
		"elites_spawned": elites_spawned,
		"elites_killed": elites_killed,
		"boss_spawned": boss_spawned,
		"boss_active": false,
		"boss_phase_two_reached": boss_phase_two_time >= 0.0,
		"boss_killed": true,
		"contract_name": active_contract_name
	}
	stage_victory_requested.emit(_summary_with_echo(summary))


func continue_after_stage_victory() -> void:
	if not stage_victory_pending:
		return
	stage_victory_pending = false
	if elapsed_time >= next_shop_time:
		next_shop_time = elapsed_time + SHOP_POST_VICTORY_GRACE
	_release_system_pause("stage_victory")
	if _try_request_pending_level_up():
		return
	emit_stats()


func notify_affix_encounter(affix_id: String) -> void:
	if not AFFIX_TOASTS.has(affix_id) or seen_affix_toasts.has(affix_id):
		return
	seen_affix_toasts[affix_id] = true
	if AchievementProgress != null and AchievementProgress.has_method("record_affix_encounter"):
		AchievementProgress.record_affix_encounter(affix_id)
	show_toast(str(AFFIX_TOASTS.get(affix_id, "")))


func format_time(seconds_value: float) -> String:
	var total_seconds := int(floor(seconds_value))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
