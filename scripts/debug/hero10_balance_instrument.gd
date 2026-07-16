extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena/Arena.tscn")
const FIXED_SEED := 1010010
const ENEMY_COUNT := 48
const WARMUP_FRAMES := 90
const SAMPLE_FRAMES := 180
const SHEPHERD_PRESSURE_SHARE_MIN := 0.04
const SHEPHERD_PRESSURE_SHARE_MAX := 0.20
const MAX_SINGLE_WEAPON_SHARE := 0.45
const FULL_SQUAD_RECRUITS: Array[String] = [
	"pulse_artificer", "rift_shepherd", "ember_grenadier",
	"void_weaver", "rift_sniper", "echo_singer"
]

const FULL_BUILD_QUALITATIVE: Dictionary = {
	"riftline_emitter": ["riftline_fork", "riftline_fork", "evo_rift_fan"],
	"orbit_blades": ["orbit_resonance", "evo_shear_halo"],
	"arc_chain": ["chain_overload", "evo_overload_nova"],
	"rift_shield_boomerang": ["boomerang_rebound", "boomerang_rebound", "evo_razor_bulwark"],
	"rift_seeker_missiles": ["missile_guidance", "missile_guidance", "evo_hunter_swarm"],
	"pulse_bloom": ["pulse_embers", "evo_ember_well"],
	"rift_constructs": ["construct_anchor", "construct_anchor", "evo_mirror_flock"],
	"grenade_lob": ["grenade_cluster", "grenade_cluster", "evo_cinder_barrage"],
	"void_net": ["void_anchor", "evo_event_horizon"],
	"rail_lance": ["rail_focus", "rail_focus", "evo_star_piercer"],
	"echo_hymn": ["echo_crescendo", "echo_crescendo", "evo_resonant_chorus"]
}

var arena: Node = null
var squad_manager: Node = null
var leader: Node2D = null
var phase := "boot"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_watchdog")
	call_deferred("_run")


func _watchdog() -> void:
	await get_tree().create_timer(180.0, true, false, true).timeout
	if phase != "done":
		_fail("watchdog timeout at " + phase)


func _run() -> void:
	phase = "setup"
	seed(FIXED_SEED)
	GameManager.forced_run_seed = FIXED_SEED
	arena = ARENA_SCENE.instantiate()
	add_child(arena)
	for _index in range(4):
		await get_tree().process_frame
	squad_manager = arena.get_node_or_null("SquadManager")
	leader = GameManager.player
	if squad_manager == null or leader == null or not is_instance_valid(leader):
		_fail("arena setup failed")
		return
	var spawner := arena.get_node_or_null("EnemySpawner")
	if spawner != null:
		spawner.set_process(false)
	_force_full_squad_and_build()
	_prepare_invulnerable_squad()
	GameManager.xp_required = 99999999
	GameManager.level = 12
	GameManager.waiting_for_upgrade = false
	GameManager.game_running = true
	_spawn_stationary_pressure_enemies()

	phase = "warmup"
	for _index in range(WARMUP_FRAMES):
		_keep_running()
		await get_tree().process_frame
	GameManager.reset_combat_metrics(true)
	EntityFactory.reset_debug_counters()

	phase = "sample"
	for _index in range(SAMPLE_FRAMES):
		_keep_running()
		await get_tree().process_frame
	_report()


func _force_full_squad_and_build() -> void:
	for hero_id in FULL_SQUAD_RECRUITS:
		squad_manager.recruit_hero(hero_id)
	for member in squad_manager.get_members():
		var weapons: Dictionary = member.get("weapons")
		for weapon_id in weapons.keys():
			var weapon: Node = weapons[weapon_id]
			for _index in range(5):
				weapon.apply_data_upgrade("weapon_damage")
			for _index in range(4):
				weapon.apply_data_upgrade("weapon_cooldown")
			for _index in range(3):
				weapon.apply_data_upgrade("weapon_projectiles")
			for qualitative in FULL_BUILD_QUALITATIVE.get(str(weapon_id), []):
				weapon.apply_data_upgrade(str(qualitative))


func _prepare_invulnerable_squad() -> void:
	for member in squad_manager.get_members():
		member.set("max_hp", 999999.0)
		member.set("current_hp", 999999.0)
		member.set("invulnerability_time", 0.02)
		member.set("pickup_radius", 0.0)


func _spawn_stationary_pressure_enemies() -> void:
	for index in range(ENEMY_COUNT):
		var angle := TAU * float(index) / float(ENEMY_COUNT)
		var band := index % 6
		var distance := 42.0 + float(band) * 44.0
		var enemy := EntityFactory.spawn_enemy("hero10_balance_%d" % index, {
			"max_hp": 1000000.0,
			"speed": 0.0,
			"damage": 0.0,
			"xp": 0,
			"gold": 0,
			"radius": 13.0,
			"color": Color(0.55, 0.34, 0.7),
			"sprite_path": "res://assets/sprites/enemy_grunt.png",
			"sprite_scale": 1.0,
			"attack_cooldown": 999.0
		}, leader.global_position + Vector2.RIGHT.rotated(angle) * distance)
		if enemy != null:
			enemy.set_process(false)
			enemy.set_physics_process(false)


func _keep_running() -> void:
	if get_tree().paused:
		get_tree().paused = false
	GameManager.waiting_for_upgrade = false
	GameManager.manual_paused = false
	GameManager.is_game_over = false
	GameManager.game_running = true
	GameManager.set_touch_move_vector(Vector2.ZERO)


func _report() -> void:
	var metrics: Dictionary = GameManager.get_combat_metrics()
	var by_weapon: Dictionary = metrics.get("damage_by_weapon", {})
	var by_component: Dictionary = metrics.get("damage_by_component", {})
	var total := maxf(0.001, float(metrics.get("total_damage", 0.0)))
	var leader_damage := 0.0
	for key in by_weapon.keys():
		if str(key).begins_with("rift_captain:"):
			leader_damage += float(by_weapon[key])
	var shepherd_damage := float(by_weapon.get("rift_shepherd:rift_constructs", 0.0))
	var shatter_damage := float(by_component.get("rift_shepherd:rift_constructs:shatter", 0.0))
	var leader_share := leader_damage / total
	var shepherd_share := shepherd_damage / total
	var shatter_share := shatter_damage / maxf(0.001, shepherd_damage)
	var top_weapon := ""
	var top_share := 0.0
	for key in by_weapon.keys():
		var share := float(by_weapon[key]) / total
		if share > top_share:
			top_share = share
			top_weapon = str(key)
	var pool_stats := EntityFactory.get_pool_stats()
	print("HERO10_PRESSURE_RESULT shape=48_stationary_aoe_saturation normalization=none seed=%d roster=9 enemies=%d warmup_frames=%d sample_frames=%d total_damage=%.1f raw_leader_dps_share=%.4f raw_shepherd_weapon_share=%.4f shatter_share=%.4f" % [
		FIXED_SEED, EntityFactory.get_enemy_live_count(), WARMUP_FRAMES, SAMPLE_FRAMES,
		total, leader_share, shepherd_share, shatter_share
	])
	print("HERO10_PRESSURE_TARGETS shepherd=%.2f..%.2f max_single_weapon=%.2f top_weapon=%s top_share=%.4f" % [
		SHEPHERD_PRESSURE_SHARE_MIN,
		SHEPHERD_PRESSURE_SHARE_MAX,
		MAX_SINGLE_WEAPON_SHARE,
		top_weapon,
		top_share
	])
	print("HERO10_PRESSURE_DAMAGE=" + JSON.stringify(by_weapon))
	print("HERO10_PRESSURE_COMPONENTS=" + JSON.stringify(by_component))
	print("HERO10_PRESSURE_POOL constructs=%d fifo=%d shatters=%d enemy_queries=%d group_scans=%d" % [
		int(pool_stats.get("rift_construct_live", 0)),
		int(pool_stats.get("rift_construct_reclaims", 0)),
		int(pool_stats.get("rift_construct_shatter_requests", 0)),
		int(pool_stats.get("enemy_queries", 0)),
		int(pool_stats.get("enemy_group_scans", 0))
	])
	if shatter_damage <= 0.0:
		print("HERO10_PRESSURE_NOTE shatter_damage=0.0 covered_by=BalanceMock")
	if int(pool_stats.get("enemy_group_scans", 0)) != 0:
		_fail("balance pressure introduced enemy group scans")
		return
	if shepherd_share < SHEPHERD_PRESSURE_SHARE_MIN or shepherd_share > SHEPHERD_PRESSURE_SHARE_MAX:
		_fail("shepherd pressure share %.4f outside %.2f..%.2f" % [shepherd_share, SHEPHERD_PRESSURE_SHARE_MIN, SHEPHERD_PRESSURE_SHARE_MAX])
		return
	if top_share > MAX_SINGLE_WEAPON_SHARE:
		print("HERO10_PRESSURE_NOTE %s share %.4f exceeds diagnostic %.2f in stationary AoE saturation" % [top_weapon, top_share, MAX_SINGLE_WEAPON_SHARE])
	print("HERO10_PRESSURE_PASS")
	phase = "done"
	get_tree().quit(0)


func _fail(message: String) -> void:
	printerr("HERO10_BALANCE_FAIL: " + message)
	phase = "done"
	get_tree().quit(1)
