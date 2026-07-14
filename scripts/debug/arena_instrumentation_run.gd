extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena/Arena.tscn")
const FIXED_SEED := 771101
const SAMPLE_SECONDS := 16.0
const REAL_TIMEOUT_MSEC := 25000
const FULL_SQUAD_RECRUITS: Array[String] = [
	"pulse_artificer",
	"rift_shepherd",
	"ember_grenadier",
	"void_weaver",
	"rift_sniper",
	"echo_singer"
]
const EXPECTED_FULL_SQUAD_WEAPONS: Array[String] = [
	"orbit_guard:rift_shield_boomerang",
	"arc_scout:rift_seeker_missiles",
	"pulse_artificer:pulse_bloom",
	"rift_shepherd:rift_constructs",
	"ember_grenadier:grenade_lob",
	"void_weaver:void_net",
	"rift_sniper:rail_lance",
	"echo_singer:echo_hymn"
]
const EXPECTED_DAMAGE_WEAPONS: Array[String] = [
	"orbit_guard:rift_shield_boomerang",
	"arc_scout:rift_seeker_missiles",
	"pulse_artificer:pulse_bloom",
	"rift_shepherd:rift_constructs",
	"ember_grenadier:grenade_lob",
	"void_weaver:void_net",
	"rift_sniper:rail_lance"
]

var arena: Node = null
var squad_manager: Node = null
var leader: Node2D = null
var current_phase := "boot"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_watchdog")
	call_deferred("_run_probe")


func _watchdog() -> void:
	await get_tree().create_timer(25.0, true, false, true).timeout
	if current_phase != "done":
		_fail("watchdog timeout at phase: " + current_phase)


func _run_probe() -> void:
	current_phase = "setup"
	GameManager.forced_run_seed = FIXED_SEED
	GameManager.reset_combat_metrics(true)
	_connect_automation()

	arena = ARENA_SCENE.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	squad_manager = arena.get_node_or_null("SquadManager")
	leader = GameManager.player
	if squad_manager == null or leader == null or not is_instance_valid(leader):
		_fail("arena setup failed")
		return
	_hide_first_run_guide()
	_force_full_squad()
	_force_new_weapon_evolutions()

	current_phase = "sample"
	var real_deadline := Time.get_ticks_msec() + REAL_TIMEOUT_MSEC
	while GameManager.game_running and GameManager.elapsed_time < SAMPLE_SECONDS:
		if Time.get_ticks_msec() > real_deadline:
			_fail("real-time sample timeout")
			return
		GameManager.set_touch_move_vector(_movement_for_time(GameManager.elapsed_time))
		await get_tree().process_frame

	GameManager.set_touch_move_vector(Vector2.ZERO)
	if not _report_probe():
		return
	current_phase = "done"
	get_tree().quit(0)


func _connect_automation() -> void:
	var level_callable := Callable(self, "_on_level_up_requested")
	var shop_callable := Callable(self, "_on_shop_requested")
	var victory_callable := Callable(self, "_on_stage_victory_requested")
	if not GameManager.level_up_requested.is_connected(level_callable):
		GameManager.level_up_requested.connect(level_callable)
	if not GameManager.shop_requested.is_connected(shop_callable):
		GameManager.shop_requested.connect(shop_callable)
	if not GameManager.stage_victory_requested.is_connected(victory_callable):
		GameManager.stage_victory_requested.connect(victory_callable)


func _on_level_up_requested(choices: Array) -> void:
	if choices.is_empty():
		return
	call_deferred("_apply_upgrade_deferred", _prefer_non_leader_choice(choices))


func _apply_upgrade_deferred(choice: Dictionary) -> void:
	if GameManager.waiting_for_upgrade:
		GameManager.apply_upgrade(choice)


func _on_shop_requested(_options: Array) -> void:
	call_deferred("_skip_shop_deferred")


func _skip_shop_deferred() -> void:
	if GameManager.waiting_for_shop:
		GameManager.apply_shop_purchase({"id": "skip"})


func _on_stage_victory_requested(_summary: Dictionary) -> void:
	call_deferred("_continue_victory_deferred")


func _continue_victory_deferred() -> void:
	if GameManager.stage_victory_pending:
		GameManager.continue_after_stage_victory()


func _prefer_non_leader_choice(choices: Array) -> Dictionary:
	for choice in choices:
		if not GameManager._is_leader_upgrade_option(choice):
			return choice
	return choices[0]


func _hide_first_run_guide() -> void:
	var guide := arena.get_node_or_null("FirstRunGuide")
	if guide == null:
		return
	var root: Variant = guide.get("root")
	if root is Control:
		(root as Control).visible = false


func _force_new_weapon_evolutions() -> void:
	var guard: Node = squad_manager.get_member_by_id("orbit_guard")
	var scout: Node = squad_manager.get_member_by_id("arc_scout")
	var pulse: Node = squad_manager.get_member_by_id("pulse_artificer")
	var shepherd: Node = squad_manager.get_member_by_id("rift_shepherd")
	var ember: Node = squad_manager.get_member_by_id("ember_grenadier")
	var void_member: Node = squad_manager.get_member_by_id("void_weaver")
	var sniper: Node = squad_manager.get_member_by_id("rift_sniper")
	var echo: Node = squad_manager.get_member_by_id("echo_singer")
	_apply_weapon_upgrades(guard, "rift_shield_boomerang", ["boomerang_rebound", "boomerang_rebound", "evo_razor_bulwark"])
	_apply_weapon_upgrades(scout, "rift_seeker_missiles", ["missile_guidance", "missile_guidance", "evo_hunter_swarm"])
	_apply_weapon_upgrades(pulse, "pulse_bloom", ["pulse_embers", "evo_ember_well"])
	_apply_weapon_upgrades(shepherd, "rift_constructs", ["weapon_damage", "weapon_damage", "weapon_damage", "construct_anchor", "construct_anchor", "evo_mirror_flock"])
	_apply_weapon_upgrades(ember, "grenade_lob", ["grenade_cluster", "grenade_cluster", "evo_cinder_barrage"])
	_apply_weapon_upgrades(void_member, "void_net", ["void_anchor", "evo_event_horizon"])
	_apply_weapon_upgrades(sniper, "rail_lance", ["rail_focus", "rail_focus", "evo_star_piercer"])
	_apply_weapon_upgrades(echo, "echo_hymn", ["echo_crescendo", "echo_crescendo", "evo_resonant_chorus"])


func _force_full_squad() -> void:
	for hero_id in FULL_SQUAD_RECRUITS:
		squad_manager.recruit_hero(hero_id)


func _apply_weapon_upgrades(hero: Node, weapon_id: String, upgrades: Array) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var weapons: Dictionary = hero.get("weapons")
	var weapon: Node = weapons.get(weapon_id)
	if weapon == null or not is_instance_valid(weapon) or not weapon.has_method("apply_data_upgrade"):
		return
	for upgrade in upgrades:
		weapon.apply_data_upgrade(upgrade)


func _movement_for_time(time_value: float) -> Vector2:
	var angle: float = time_value * 0.72
	return Vector2(cos(angle), sin(angle * 0.73)).limit_length(1.0)


func _report_probe() -> bool:
	var elapsed: float = maxf(0.001, float(GameManager.elapsed_time))
	var metrics: Dictionary = GameManager.get_combat_metrics()
	var damage_by_weapon: Dictionary = metrics.get("damage_by_weapon", {})
	var damage_by_component: Dictionary = metrics.get("damage_by_component", {})
	var dps_by_weapon: Dictionary = {}
	for key in damage_by_weapon.keys():
		dps_by_weapon[key] = round(float(damage_by_weapon[key]) / elapsed * 100.0) / 100.0
	var trigger_counts: Dictionary = {}
	if squad_manager != null and squad_manager.has_method("get_weapon_trigger_counts"):
		trigger_counts = squad_manager.get_weapon_trigger_counts()
	var hp := 0.0
	var max_hp := 0.0
	if leader != null and is_instance_valid(leader):
		hp = float(leader.get("current_hp"))
		max_hp = float(leader.get("max_hp"))
	var pool_stats: Dictionary = EntityFactory.get_pool_stats()
	print("ARENA_INSTRUMENT_RESULT seed=%d seconds=%.2f survived=%s kills=%d hp=%.1f/%.1f total_damage=%.1f" % [
		GameManager.current_run_seed,
		elapsed,
		str(GameManager.game_running and not GameManager.is_game_over),
		GameManager.kills,
		hp,
		max_hp,
		float(metrics.get("total_damage", 0.0))
	])
	print("ARENA_INSTRUMENT_DPS=" + JSON.stringify(dps_by_weapon))
	var total_damage := maxf(0.001, float(metrics.get("total_damage", 0.0)))
	var leader_damage := 0.0
	for key in damage_by_weapon.keys():
		if str(key).begins_with("rift_captain:"):
			leader_damage += float(damage_by_weapon[key])
	var shepherd_damage := float(damage_by_weapon.get("rift_shepherd:rift_constructs", 0.0))
	var shatter_damage := float(damage_by_component.get("rift_shepherd:rift_constructs:shatter", 0.0))
	var leader_share := leader_damage / total_damage
	var shepherd_share := shepherd_damage / total_damage
	var shatter_share := shatter_damage / maxf(0.001, shepherd_damage)
	print("HERO10_BALANCE_INSTRUMENT leader_dps_share=%.4f shepherd_weapon_share=%.4f shatter_share=%.4f leader_damage=%.1f shepherd_damage=%.1f shatter_damage=%.1f" % [
		leader_share,
		shepherd_share,
		shatter_share,
		leader_damage,
		shepherd_damage,
		shatter_damage
	])
	print("ARENA_INSTRUMENT_TRIGGERS=" + JSON.stringify(trigger_counts))
	print("ARENA_INSTRUMENT_POOL_STATS=" + JSON.stringify(pool_stats))
	if float(metrics.get("total_damage", 0.0)) <= 0.0:
		_fail("no weapon damage recorded")
		return false
	for key in EXPECTED_FULL_SQUAD_WEAPONS:
		if int(trigger_counts.get(key, 0)) <= 0:
			_fail("full squad weapon trigger missing: " + key)
			return false
	for key in EXPECTED_DAMAGE_WEAPONS:
		if not dps_by_weapon.has(key):
			_fail("full squad weapon DPS missing: " + key)
			return false
	print("ARENA_INSTRUMENT_PASS")
	return true


func _fail(message: String) -> void:
	printerr("ARENA_INSTRUMENT_FAIL: " + message)
	current_phase = "done"
	get_tree().quit(1)
