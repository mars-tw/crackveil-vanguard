extends Node

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")

const ENEMY_COUNT := 150
const PROJECTILE_COUNT := 80
const STRESS_RUN_SEED := 52002
const START_FRAME := 10
const WARMUP_FRAME_COUNT := 180
const MEASURED_FRAME_TARGET := 411
const MAX_ENEMY_REFILL_PER_FRAME := 6
const MAX_PROJECTILE_REFILL_PER_FRAME := 4
const FULL_SQUAD_RECRUITS: Array[String] = [
	"pulse_artificer",
	"line_mender",
	"ember_grenadier",
	"void_weaver",
	"rift_sniper",
	"echo_singer"
]
const EXPECTED_FULL_SQUAD_WEAPONS: Array[String] = [
	"rift_captain:riftline_emitter",
	"rift_captain:orbit_blades",
	"rift_captain:arc_chain",
	"orbit_guard:rift_shield_boomerang",
	"arc_scout:rift_seeker_missiles",
	"pulse_artificer:pulse_bloom",
	"line_mender:riftline_emitter",
	"ember_grenadier:grenade_lob",
	"void_weaver:void_net",
	"rift_sniper:rail_lance",
	"echo_singer:echo_hymn"
]
const MOBILE_LOD_VIEWPORT_SIZE := Vector2i(390, 844)
const DESKTOP_VIEWPORT_SIZE := Vector2i(1280, 720)
const SPIKE_THRESHOLD_MS := 20.0
const TRACKED_POOL_NAMES: Array[String] = [
	"enemy", "projectile", "fork_projectile", "orbit_projectile",
	"explosion", "hazard_zone", "xp_gem", "coin", "damage_number",
	"death_burst", "corpse_ghost", "lightning_arc"
]

@export var mobile_lod_scenario: bool = false

var arena: Node = null
var squad_manager: Node = null
var leader: Node2D = null
var frame_count: int = 0
var initialized: bool = false
var measuring: bool = false
var measured_frames: int = 0
var enemy_spawn_counter: int = 0
var projectile_spawn_counter: int = 0
var frame_times_ms: Array[float] = []
var last_frame_tick_usec: int = 0
var spike_records: Array[Dictionary] = []
var previous_pool_stats: Dictionary = {}
var previous_kills: int = 0
var previous_texture_cache_size: int = 0
var pending_enemy_refills: int = 0
var pending_projectile_refills: int = 0
var warmup_evolutions: int = 0
var baseline_source: String = "UNSPECIFIED"
var machine_condition: String = "UNSPECIFIED"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	baseline_source = _stress_arg_value("--baseline-source=", "UNSPECIFIED")
	machine_condition = _stress_arg_value("--machine-condition=", "UNSPECIFIED")
	mobile_lod_scenario = mobile_lod_scenario or _has_stress_arg("--mobile-lod")
	MOBILE_TUNING.set_force_mobile_lod_for_tests(mobile_lod_scenario)
	var target_size := MOBILE_LOD_VIEWPORT_SIZE if mobile_lod_scenario else DESKTOP_VIEWPORT_SIZE
	get_window().size = target_size
	get_window().content_scale_size = target_size
	arena = load("res://scenes/arena/Arena.tscn").instantiate()
	arena.set("run_seed", STRESS_RUN_SEED)
	add_child(arena)


func _process(_delta: float) -> void:
	frame_count += 1

	if not initialized and frame_count >= START_FRAME:
		_initialize_stress()

	if initialized:
		if not measuring and frame_count >= START_FRAME + WARMUP_FRAME_COUNT:
			_begin_measurement()
		elif measuring:
			_record_wall_frame_time()
		_keep_run_unpaused()
		_refill_enemies()
		_refill_projectiles()

	if measuring and measured_frames >= MEASURED_FRAME_TARGET:
		_finish_stress()


func _initialize_stress() -> void:
	initialized = true
	squad_manager = arena.get_node_or_null("SquadManager")
	leader = squad_manager.get("leader") if squad_manager != null else null
	if leader == null or not is_instance_valid(leader):
		_fail("leader not found")
		return

	var spawner := arena.get_node_or_null("EnemySpawner")
	if spawner != null:
		spawner.set_process(false)

	_prepare_full_squad_for_stress()
	_prepare_heroes_for_stress()
	GameManager.xp_required = 99999999
	GameManager.level = 12
	GameManager.waiting_for_upgrade = false
	GameManager.game_running = true
	GameManager.reset_combat_metrics(true)
	EntityFactory.reset_debug_counters()

	_refill_enemies(true)
	_refill_projectiles(true)
	_spawn_initial_vfx()
	_capture_event_baseline()
	var viewport_size := get_viewport().get_visible_rect().size
	var death_burst_live := EntityFactory.get_pool_live_count("death_burst")
	var composite_layers := MOBILE_TUNING.vfx_composite_layer_count(
		viewport_size,
		mobile_lod_scenario,
		EntityFactory.get_enemy_live_count(),
		death_burst_live
	)
	print("STRESS_PROVENANCE baseline_source=%s machine_condition=%s" % [baseline_source, machine_condition])
	print("STRESS_SCENARIO seed=%d mobile_lod=%s viewport=%s composite_layers=%d vfx_live=%d particle_multiplier=%.2f damage_cap=%d hazard_tick=%.3f hazard_visual_redraw=%.4f death_burst_cap=%d corpse_cap=%d" % [
		STRESS_RUN_SEED,
		str(mobile_lod_scenario),
		str(viewport_size),
		composite_layers,
		death_burst_live,
		MOBILE_TUNING.lod_particle_multiplier(viewport_size, mobile_lod_scenario),
		MOBILE_TUNING.damage_number_cap(viewport_size, EntityFactory.DAMAGE_NUMBER_CAP, mobile_lod_scenario),
		MOBILE_TUNING.hazard_tick_interval(viewport_size, 0.24, mobile_lod_scenario),
		MOBILE_TUNING.hazard_visual_redraw_interval(viewport_size, 0.05, mobile_lod_scenario),
		MOBILE_TUNING.death_burst_cap(viewport_size, EntityFactory.DEATH_BURST_CAP, mobile_lod_scenario),
		MOBILE_TUNING.corpse_ghost_cap(viewport_size, EntityFactory.CORPSE_GHOST_CAP, mobile_lod_scenario)
	])
	print("STRESS_INIT members=%d enemies=%d projectiles=%d" % [
		squad_manager.get_member_count(),
		EntityFactory.get_enemy_live_count(),
		EntityFactory.get_pool_live_count("projectile")
	])
	print("STRESS_WARMUP pools=%d textures=%d audio_runtime=%s evolutions=%d" % [
		_count_pool_entries(previous_pool_stats),
		previous_texture_cache_size,
		str(AudioManager.audio_runtime_enabled if AudioManager != null else false),
		warmup_evolutions
	])


func _begin_measurement() -> void:
	measuring = true
	frame_times_ms.clear()
	spike_records.clear()
	measured_frames = 0
	last_frame_tick_usec = Time.get_ticks_usec()
	GameManager.reset_combat_metrics(true)
	EntityFactory.reset_debug_counters()
	_capture_event_baseline()
	print("STRESS_MEASURE_BEGIN warmup_frames=%d enemies=%d projectiles=%d textures=%d" % [
		WARMUP_FRAME_COUNT,
		EntityFactory.get_enemy_live_count(),
		EntityFactory.get_pool_live_count("projectile"),
		previous_texture_cache_size
	])


func _prepare_full_squad_for_stress() -> void:
	for hero_id in FULL_SQUAD_RECRUITS:
		squad_manager.recruit_hero(hero_id)
	_force_weapon_upgrades_for_stress()


func _force_weapon_upgrades_for_stress() -> void:
	_apply_weapon_upgrades(squad_manager.get_member_by_id("rift_captain"), "riftline_emitter", ["weapon_damage", "weapon_damage", "weapon_damage", "riftline_fork", "riftline_fork", "evo_rift_fan"])
	_apply_weapon_upgrades(squad_manager.get_member_by_id("rift_captain"), "orbit_blades", ["weapon_damage", "weapon_damage", "weapon_damage", "weapon_projectiles", "orbit_resonance", "evo_shear_halo"])
	_apply_weapon_upgrades(squad_manager.get_member_by_id("rift_captain"), "arc_chain", ["weapon_damage", "weapon_damage", "weapon_damage", "chain_overload", "evo_overload_nova"])
	_apply_weapon_upgrades(squad_manager.get_member_by_id("orbit_guard"), "rift_shield_boomerang", ["weapon_damage", "weapon_projectiles", "boomerang_rebound", "boomerang_rebound", "evo_razor_bulwark"])
	_apply_weapon_upgrades(squad_manager.get_member_by_id("arc_scout"), "rift_seeker_missiles", ["weapon_damage", "weapon_projectiles", "missile_guidance", "missile_guidance", "evo_hunter_swarm"])
	_apply_weapon_upgrades(squad_manager.get_member_by_id("pulse_artificer"), "pulse_bloom", ["weapon_damage", "weapon_damage", "pulse_embers", "evo_ember_well"])
	_apply_weapon_upgrades(squad_manager.get_member_by_id("line_mender"), "riftline_emitter", ["weapon_damage", "riftline_fork", "riftline_fork", "evo_rift_fan"])
	_apply_weapon_upgrades(squad_manager.get_member_by_id("ember_grenadier"), "grenade_lob", ["weapon_damage", "weapon_projectiles", "grenade_cluster", "grenade_cluster", "evo_cinder_barrage"])
	_apply_weapon_upgrades(squad_manager.get_member_by_id("void_weaver"), "void_net", ["weapon_damage", "weapon_projectiles", "void_anchor", "evo_event_horizon"])
	_apply_weapon_upgrades(squad_manager.get_member_by_id("rift_sniper"), "rail_lance", ["weapon_damage", "weapon_cooldown", "rail_focus", "rail_focus", "evo_star_piercer"])
	_apply_weapon_upgrades(squad_manager.get_member_by_id("echo_singer"), "echo_hymn", ["weapon_damage", "weapon_projectiles", "echo_crescendo", "echo_crescendo", "evo_resonant_chorus"])


func _apply_weapon_upgrades(hero: Node, weapon_id: String, upgrades: Array) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var weapons: Dictionary = hero.get("weapons")
	var weapon: Node = weapons.get(weapon_id)
	if weapon == null or not is_instance_valid(weapon) or not weapon.has_method("apply_data_upgrade"):
		return
	for upgrade in upgrades:
		weapon.apply_data_upgrade(str(upgrade))
		if str(upgrade).begins_with("evo_"):
			warmup_evolutions += 1


func _prepare_heroes_for_stress() -> void:
	var members: Array = []
	if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("get_members"):
		members = squad_manager.get_members()

	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		member.set("max_hp", 999999.0)
		member.set("current_hp", 999999.0)
		member.set("invulnerability_time", 0.08)
		member.set("invulnerability_timer", 0.0)
		member.set("pickup_radius", 460.0)


func _keep_run_unpaused() -> void:
	if get_tree().paused:
		get_tree().paused = false
	GameManager.waiting_for_upgrade = false
	GameManager.manual_paused = false
	GameManager.is_game_over = false
	GameManager.game_running = true


func _refill_enemies(fill_all: bool = false) -> void:
	var live_count := EntityFactory.get_enemy_live_count()
	var missing: int = max(0, ENEMY_COUNT - live_count)
	var spawn_count: int = missing if fill_all else min(missing, MAX_ENEMY_REFILL_PER_FRAME)
	if initialized and not fill_all:
		pending_enemy_refills += spawn_count
	for _index in range(spawn_count):
		_spawn_enemy_for_stress()


func _spawn_enemy_for_stress() -> void:
	var type_index := enemy_spawn_counter % 10
	var enemy_id := "stress_normal"
	var config := _normal_enemy_config()
	if type_index in [3, 7]:
		enemy_id = "stress_fast"
		config = _fast_enemy_config()
	elif type_index == 9:
		enemy_id = "stress_tank"
		config = _tank_enemy_config()

	var center := _combat_center()
	var angle := randf() * TAU
	var distance := randf_range(120.0, 320.0)
	var jitter := Vector2(randf_range(-26.0, 26.0), randf_range(-26.0, 26.0))
	EntityFactory.spawn_enemy(enemy_id, config, center + Vector2.RIGHT.rotated(angle) * distance + jitter)
	enemy_spawn_counter += 1


func _refill_projectiles(fill_all: bool = false) -> void:
	var live_projectiles := EntityFactory.get_pool_live_count("projectile")
	var missing: int = max(0, PROJECTILE_COUNT - live_projectiles)
	var spawn_count: int = missing if fill_all else min(missing, MAX_PROJECTILE_REFILL_PER_FRAME)
	if initialized and not fill_all:
		pending_projectile_refills += spawn_count
	for _index in range(spawn_count):
		_spawn_projectile_for_stress()


func _spawn_projectile_for_stress() -> void:
	var target := _pick_projectile_target()
	var center := _combat_center()
	var target_position := center + Vector2(randf_range(-180.0, 180.0), randf_range(-120.0, 120.0))
	if target != null and is_instance_valid(target):
		target_position = target.global_position

	var angle := randf() * TAU
	var origin := target_position + Vector2.RIGHT.rotated(angle) * randf_range(140.0, 260.0)
	var direction := (target_position - origin).normalized().rotated(randf_range(-0.16, 0.16))
	EntityFactory.spawn_projectile(origin, direction, _stress_projectile_stats(), leader)
	projectile_spawn_counter += 1


func _pick_projectile_target() -> Node2D:
	var candidates: Array[Node2D] = EntityFactory.get_enemies_in_radius(_combat_center(), 760.0)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


func _spawn_initial_vfx() -> void:
	for index in range(60):
		var position := _combat_center() + Vector2(randf_range(-220.0, 220.0), randf_range(-160.0, 160.0))
		EntityFactory.spawn_damage_number(index, position, Color(1.0, 0.9, 0.4))
		EntityFactory.spawn_death_burst(position + Vector2(0.0, 18.0), Color(0.7, 0.9, 1.0))


func _normal_enemy_config() -> Dictionary:
	return {
		"max_hp": 92.0,
		"speed": 88.0,
		"damage": 6.0,
		"xp": 1,
		"gold": 1,
		"radius": 13.0,
		"color": Color(0.72, 0.28, 0.36),
		"sprite_path": "res://assets/sprites/enemy_grunt.png",
		"sprite_scale": 1.3,
		"attack_cooldown": 0.75
	}


func _fast_enemy_config() -> Dictionary:
	return {
		"max_hp": 68.0,
		"speed": 142.0,
		"damage": 4.0,
		"xp": 1,
		"gold": 1,
		"radius": 10.0,
		"color": Color(0.95, 0.72, 0.26),
		"sprite_path": "res://assets/sprites/enemy_fast.png",
		"sprite_scale": 1.25,
		"attack_cooldown": 0.55
	}


func _tank_enemy_config() -> Dictionary:
	return {
		"max_hp": 230.0,
		"speed": 54.0,
		"damage": 12.0,
		"xp": 3,
		"gold": 2,
		"radius": 20.0,
		"color": Color(0.48, 0.36, 0.76),
		"sprite_path": "res://assets/sprites/enemy_tank.png",
		"sprite_scale": 1.36,
		"attack_cooldown": 1.05
	}


func _stress_projectile_stats() -> Dictionary:
	return {
		"damage": 8.0,
		"range": 1100.0,
		"projectile_speed": 430.0,
		"projectile_radius": 5.5,
		"pierce": 1,
		"color": Color(0.62, 0.93, 1.0),
		"projectile_sprite_path": "res://assets/sprites/proj_bullet.png",
		"sprite_scale": 1.35
	}


func _combat_center() -> Vector2:
	if leader != null and is_instance_valid(leader):
		return leader.global_position
	return Vector2.ZERO


func _finish_stress() -> void:
	var stats := _calculate_frame_stats()
	var pool_stats: Dictionary = EntityFactory.get_pool_stats()
	var enemy_queries := int(pool_stats.get("enemy_queries", 0))
	var enemy_group_scans := int(pool_stats.get("enemy_group_scans", 0))
	var queries_per_frame: float = float(enemy_queries) / max(1.0, float(measured_frames))
	var group_scans_per_frame: float = float(enemy_group_scans) / max(1.0, float(measured_frames))

	print("STRESS_RESULT baseline_source=%s machine_condition=%s enemies=%d projectiles=%d measured_frames=%d avg_ms=%.3f p95_ms=%.3f max_ms=%.3f avg_fps=%.2f p95_fps=%.2f min_fps=%.2f" % [
		baseline_source,
		machine_condition,
		EntityFactory.get_enemy_live_count(),
		int(pool_stats.get("projectile", {}).get("live", 0)),
		measured_frames,
		float(stats.get("avg_ms", 0.0)),
		float(stats.get("p95_ms", 0.0)),
		float(stats.get("max_ms", 0.0)),
		float(stats.get("avg_fps", 0.0)),
		float(stats.get("p95_fps", 0.0)),
		float(stats.get("min_fps", 0.0))
	])
	print("STRESS_COUNTERS enemy_spatial_queries=%d queries_per_frame=%.2f enemy_group_scans=%d group_scans_per_frame=%.3f kills=%d gold=%d xp=%d" % [
		enemy_queries,
		queries_per_frame,
		enemy_group_scans,
		group_scans_per_frame,
		GameManager.kills,
		GameManager.gold,
		GameManager.xp
	])
	print("STRESS_POOL_STATS=" + JSON.stringify(pool_stats))
	print("STRESS_WEAPON_TRIGGERS=" + JSON.stringify(squad_manager.get_weapon_trigger_counts()))
	_print_spike_trace()

	var validation_error := _validate_pool_stats(pool_stats)
	if validation_error != "":
		_fail(validation_error)
		return

	if float(stats.get("min_fps", 0.0)) < 59.5:
		print("STRESS_PERF_BELOW_60=true")
	else:
		print("STRESS_PERF_BELOW_60=false")

	var trigger_validation := _validate_full_squad_triggers()
	if trigger_validation != "":
		_fail(trigger_validation)
		return

	print("STRESS_PASS")
	get_tree().quit(0)


func _has_stress_arg(flag: String) -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == flag:
			return true
	return false


func _stress_arg_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_args():
		var value := str(argument)
		if value.begins_with(prefix):
			var parsed := value.trim_prefix(prefix).strip_edges().replace(" ", "_")
			return parsed if parsed != "" else fallback
	return fallback


func _calculate_frame_stats() -> Dictionary:
	if frame_times_ms.is_empty():
		return {
			"avg_ms": 0.0,
			"p95_ms": 0.0,
			"max_ms": 0.0,
			"avg_fps": 0.0,
			"p95_fps": 0.0,
			"min_fps": 0.0
		}

	var total := 0.0
	for value in frame_times_ms:
		total += value

	var sorted: Array[float] = frame_times_ms.duplicate()
	sorted.sort()
	var avg_ms := total / float(frame_times_ms.size())
	var p95_ms := _percentile(sorted, 0.95)
	var max_ms: float = sorted[sorted.size() - 1]
	return {
		"avg_ms": avg_ms,
		"p95_ms": p95_ms,
		"max_ms": max_ms,
		"avg_fps": 1000.0 / max(0.001, avg_ms),
		"p95_fps": 1000.0 / max(0.001, p95_ms),
		"min_fps": 1000.0 / max(0.001, max_ms)
	}


func _record_wall_frame_time() -> void:
	var now_usec := Time.get_ticks_usec()
	if last_frame_tick_usec > 0:
		measured_frames += 1
		var frame_ms := float(now_usec - last_frame_tick_usec) / 1000.0
		frame_times_ms.append(frame_ms)
		var kills_now := int(GameManager.kills)
		var kills_delta := kills_now - previous_kills
		previous_kills = kills_now
		var texture_count := SPRITE_LOADER.texture_cache.size()
		var texture_delta := texture_count - previous_texture_cache_size
		previous_texture_cache_size = texture_count
		if frame_ms > SPIKE_THRESHOLD_MS:
			spike_records.append({
				"frame": measured_frames,
				"ms": frame_ms,
				"enemy_refills": pending_enemy_refills,
				"projectile_refills": pending_projectile_refills,
				"kills_delta": kills_delta,
				"texture_delta": texture_delta,
				"elites_spawned": int(GameManager.elites_spawned),
				"boss_spawned": bool(GameManager.boss_spawned)
			})
		_pending_refill_reset()
	last_frame_tick_usec = now_usec


func _capture_event_baseline() -> void:
	previous_pool_stats = _capture_pool_live_counts()
	previous_kills = int(GameManager.kills)
	previous_texture_cache_size = SPRITE_LOADER.texture_cache.size()
	_pending_refill_reset()


func _format_spike_events(record: Dictionary) -> String:
	var labels: Array[String] = []
	var enemy_refills := int(record.get("enemy_refills", 0))
	var projectile_refills := int(record.get("projectile_refills", 0))
	var kills_delta := int(record.get("kills_delta", 0))
	if enemy_refills > 0:
		labels.append("spawn_wave:enemy+%d(pool_reuse)" % enemy_refills)
	if projectile_refills > 0:
		labels.append("spawn_wave:projectile+%d(pool_reuse)" % projectile_refills)
	if kills_delta > 0:
		labels.append("kills:+%d(drop_vfx/gc_pressure)" % kills_delta)
	if int(record.get("elites_spawned", 0)) > 0:
		labels.append("elite_spawn:active")
	if bool(record.get("boss_spawned", false)):
		labels.append("boss_spawn")
	var texture_delta := int(record.get("texture_delta", 0))
	if texture_delta > 0:
		labels.append("texture_first_use:+%d" % texture_delta)
	return "steady" if labels.is_empty() else ";".join(labels)


func _pending_refill_reset() -> void:
	pending_enemy_refills = 0
	pending_projectile_refills = 0


func _print_spike_trace() -> void:
	print("STRESS_SPIKE_SUMMARY threshold_ms=%.1f count=%d" % [SPIKE_THRESHOLD_MS, spike_records.size()])
	for record in spike_records:
		print("STRESS_SPIKE frame=%d ms=%.3f events=%s" % [
			int(record.get("frame", 0)),
			float(record.get("ms", 0.0)),
			_format_spike_events(record)
		])


func _count_pool_entries(pool_stats: Dictionary) -> int:
	return pool_stats.size()


func _capture_pool_live_counts() -> Dictionary:
	var counts: Dictionary = {}
	for pool_name in TRACKED_POOL_NAMES:
		counts[pool_name] = EntityFactory.get_pool_live_count(pool_name)
	return counts


func _percentile(sorted_values: Array[float], percentile: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := int(ceil(float(sorted_values.size()) * percentile)) - 1
	index = clamp(index, 0, sorted_values.size() - 1)
	return sorted_values[index]


func _validate_pool_stats(pool_stats: Dictionary) -> String:
	for key in pool_stats.keys():
		var entry: Variant = pool_stats[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var pool_entry: Dictionary = entry
		if int(pool_entry.get("exhausted", 0)) > 0:
			return "%s pool exhausted" % key
		if int(pool_entry.get("duplicate_free", 0)) > 0:
			return "%s pool free list has duplicate entries" % key
		if int(pool_entry.get("duplicate_releases", 0)) > 0:
			return "%s pool saw duplicate releases during stress" % key
		if int(pool_entry.get("foreign_releases", 0)) > 0:
			return "%s pool saw foreign releases during stress" % key
	return ""


func _validate_full_squad_triggers() -> String:
	if squad_manager == null or not squad_manager.has_method("get_weapon_trigger_counts"):
		return "squad trigger counts unavailable"
	var counts: Dictionary = squad_manager.get_weapon_trigger_counts()
	for key in EXPECTED_FULL_SQUAD_WEAPONS:
		if int(counts.get(key, 0)) <= 0:
			return "full squad weapon did not trigger: " + key
	return ""


func _fail(message: String) -> void:
	printerr("STRESS_FAIL: " + message)
	get_tree().quit(1)
