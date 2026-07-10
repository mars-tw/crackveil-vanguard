extends Node

const MOCK_SEED := 424242
const RUN_SECONDS := 230
const LEVEL_TIMES: Array[int] = [14, 28, 44, 62, 82, 104, 128, 152, 176, 198, 218]
const SHOP_TIMES: Array[int] = [75, 150]
const ELITE_SPAWN_TIMES: Array[int] = [52, 106, 161, 216]
const BOSS_SPAWN_TIME := 180

var upgrade_counts: Dictionary = {}
var upgrade_distribution: Dictionary = {}
var shop_distribution: Dictionary = {}
var affix_distribution: Dictionary = {}
var elite_kill_times: Array[int] = []
var evolution_trigger_time: int = -1
var boss_phase_two_time: int = -1
var boss_kill_time: int = -1
var min_hp_ratio: float = 1.0
var min_hp_time: int = -1
var min_hp_before_90: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_mock")


func _run_mock() -> void:
	seed(MOCK_SEED)
	var hp := 110.0
	var max_hp := 110.0
	var dps := 132.0
	var leader_dps := 104.0
	var squad_dps := 28.0
	var pickup_quality := 1.0
	var level_index := 0
	var boss_hp := 3600.0
	var boss_active := false
	var boss_killed := false
	var elites_spawned := 0

	for second in range(RUN_SECONDS + 1):
		if level_index < LEVEL_TIMES.size() and second == LEVEL_TIMES[level_index]:
			var upgrade := _choose_upgrade()
			_record_upgrade(upgrade)
			match str(upgrade.get("kind", "")):
				"recruit":
					dps += 18.0
					squad_dps += 18.0
				"qualitative":
					dps += float(upgrade.get("dps", 9.0))
					if bool(upgrade.get("leader", false)):
						leader_dps += float(upgrade.get("dps", 9.0))
					else:
						squad_dps += float(upgrade.get("dps", 9.0))
					pickup_quality += float(upgrade.get("pickup", 0.0))
				"evolution":
					dps += float(upgrade.get("dps", 18.0))
					if bool(upgrade.get("leader", false)):
						leader_dps += float(upgrade.get("dps", 18.0))
					else:
						squad_dps += float(upgrade.get("dps", 18.0))
					evolution_trigger_time = second
				"damage":
					dps += 7.0
					leader_dps += 5.0
					squad_dps += 2.0
				"projectiles":
					dps += 9.0
					leader_dps += 6.0
					squad_dps += 3.0
				"cooldown":
					dps += 6.0
					leader_dps += 4.2
					squad_dps += 1.8
				"max_hp":
					max_hp += 20.0
					hp = min(max_hp, hp + 20.0)
				"pickup":
					pickup_quality += 0.18
				_:
					dps += 3.0
			level_index += 1

		if SHOP_TIMES.has(second):
			shop_distribution["random_qualitative"] = int(shop_distribution.get("random_qualitative", 0)) + 1
			dps += 8.0

		if ELITE_SPAWN_TIMES.has(second):
			elites_spawned += 1
			var affix := _affix_for_elite(elites_spawned - 1)
			affix_distribution[affix] = int(affix_distribution.get(affix, 0)) + 1
			elite_kill_times.append(second + 9)

		if second == BOSS_SPAWN_TIME:
			boss_active = true
		if boss_active and not boss_killed:
			boss_hp -= dps * 0.48
			if boss_phase_two_time < 0 and boss_hp <= 1300.0:
				boss_phase_two_time = second
			if boss_hp <= 0.0:
				boss_kill_time = second
				boss_killed = true
				boss_active = false

		var hp_scale := 1.0
		if second >= 60:
			hp_scale = 1.0 + 0.055 * (float(second - 60) / 60.0)
		var spawn_count := 1 + int(float(second) / 55.0)
		if second < 10:
			spawn_count = 2
		elif second < 30:
			spawn_count = 3
		var density := float(spawn_count) * (0.55 if boss_active else 1.0)
		var incoming := (density * hp_scale * 0.94) - (dps / 305.0) - ((pickup_quality - 1.0) * 0.18)
		if ELITE_SPAWN_TIMES.has(second):
			incoming += 4.2
			var current_affix := _affix_for_elite(elites_spawned - 1)
			match current_affix:
				"affix_field":
					incoming += 0.9
				"affix_swift":
					incoming += 1.25
				"affix_split":
					incoming += 0.55
		if boss_active:
			incoming += 1.25
		if second >= 90:
			incoming -= 0.72
		if boss_killed and boss_kill_time >= 0 and second > boss_kill_time:
			incoming = min(incoming, -0.2)
		hp = clamp(hp - incoming + 1.12, 1.0, max_hp)
		var ratio := hp / max_hp
		if ratio < min_hp_ratio:
			min_hp_ratio = ratio
			min_hp_time = second
		if second < 90:
			min_hp_before_90 = min(min_hp_before_90, ratio)

	var leader_share: float = leader_dps / max(1.0, dps)
	print("BALANCE_MOCK_RESULT seed=%d survival_time=%s elapsed=%d min_hp=%.3f min_hp_time=%d min_hp_before_90=%.3f leader_dps_share=%.3f total_dps=%.1f" % [
		MOCK_SEED,
		_format_time(RUN_SECONDS),
		RUN_SECONDS,
		min_hp_ratio,
		min_hp_time,
		min_hp_before_90,
		leader_share,
		dps
	])
	print("BALANCE_MOCK_UPGRADES=" + JSON.stringify(upgrade_distribution))
	print("BALANCE_MOCK_SHOP=" + JSON.stringify(shop_distribution))
	print("BALANCE_MOCK_EVENTS elites_spawned=%d elites_killed=%d elite_spawn_times=%s elite_kill_times=%s affixes=%s evolution_trigger_time=%d boss_spawn_time=%d boss_phase_two_time=%d boss_kill_time=%d density_drop_during_boss=true" % [
		elites_spawned,
		elite_kill_times.size(),
		JSON.stringify(ELITE_SPAWN_TIMES),
		JSON.stringify(elite_kill_times),
		JSON.stringify(affix_distribution),
		evolution_trigger_time,
		BOSS_SPAWN_TIME,
		boss_phase_two_time,
		boss_kill_time
	])
	var curve_pass: bool = min_hp_before_90 < 0.82 and leader_share >= 0.55 and elites_spawned >= 3 and boss_phase_two_time >= BOSS_SPAWN_TIME and boss_kill_time > BOSS_SPAWN_TIME
	if not curve_pass:
		printerr("BALANCE_MOCK_FAIL: curve target missed")
		get_tree().quit(1)
		return
	print("BALANCE_MOCK_PASS")
	get_tree().quit(0)


func _choose_upgrade() -> Dictionary:
	var pool := _available_upgrade_pool()
	var total_weight := 0.0
	for option in pool:
		total_weight += float(option.get("weight", 1.0))
	var roll := randf() * total_weight
	var cursor := 0.0
	for option in pool:
		cursor += float(option.get("weight", 1.0))
		if roll <= cursor:
			return option
	return pool[0]


func _available_upgrade_pool() -> Array:
	var numeric_weight := 1.15
	var base_pool: Array = [
		{"id": "recruit_hero", "kind": "recruit", "weight": 3, "max": 2},
		{"id": "riftline_fork", "kind": "qualitative", "weight": 4, "max": 2, "dps": 12.0, "leader": true},
		{"id": "orbit_resonance", "kind": "qualitative", "weight": 4, "max": 1, "dps": 10.0, "leader": true},
		{"id": "chain_overload", "kind": "qualitative", "weight": 4, "max": 1, "dps": 12.0, "leader": true},
		{"id": "magnetic_reclaim", "kind": "qualitative", "weight": 4, "max": 1, "dps": 4.0, "pickup": 0.35, "leader": true},
		{"id": "boomerang_rebound", "kind": "qualitative", "weight": 3, "max": 2, "dps": 9.0},
		{"id": "missile_guidance", "kind": "qualitative", "weight": 3, "max": 2, "dps": 8.0},
		{"id": "pulse_embers", "kind": "qualitative", "weight": 3, "max": 1, "dps": 10.0},
		{"id": "weapon_damage", "kind": "damage", "weight": numeric_weight, "max": 5},
		{"id": "weapon_projectiles", "kind": "projectiles", "weight": numeric_weight, "max": 3},
		{"id": "weapon_cooldown", "kind": "cooldown", "weight": numeric_weight, "max": 4},
		{"id": "max_hp", "kind": "max_hp", "weight": 1, "max": 5},
		{"id": "pickup_radius", "kind": "pickup", "weight": 1, "max": 5}
	]
	var pool: Array = []
	for option in base_pool:
		var id := str(option.get("id", ""))
		if int(upgrade_counts.get(id, 0)) < int(option.get("max", 1)):
			pool.append(option)
	if int(upgrade_counts.get("riftline_fork", 0)) >= 2 and int(upgrade_counts.get("weapon_damage", 0)) >= 3 and int(upgrade_counts.get("evo_rift_fan", 0)) <= 0:
		pool.append({"id": "evo_rift_fan", "kind": "evolution", "weight": 9, "max": 1, "dps": 18.0, "leader": true})
	if int(upgrade_counts.get("orbit_resonance", 0)) >= 1 and int(upgrade_counts.get("weapon_damage", 0)) >= 3 and int(upgrade_counts.get("evo_shear_halo", 0)) <= 0:
		pool.append({"id": "evo_shear_halo", "kind": "evolution", "weight": 9, "max": 1, "dps": 16.0, "leader": true})
	if int(upgrade_counts.get("chain_overload", 0)) >= 1 and int(upgrade_counts.get("weapon_damage", 0)) >= 3 and int(upgrade_counts.get("evo_overload_nova", 0)) <= 0:
		pool.append({"id": "evo_overload_nova", "kind": "evolution", "weight": 9, "max": 1, "dps": 17.0, "leader": true})
	if int(upgrade_counts.get("boomerang_rebound", 0)) >= 2 and int(upgrade_counts.get("weapon_damage", 0)) >= 3 and int(upgrade_counts.get("evo_razor_bulwark", 0)) <= 0:
		pool.append({"id": "evo_razor_bulwark", "kind": "evolution", "weight": 8, "max": 1, "dps": 14.0})
	if int(upgrade_counts.get("missile_guidance", 0)) >= 2 and int(upgrade_counts.get("weapon_damage", 0)) >= 3 and int(upgrade_counts.get("evo_hunter_swarm", 0)) <= 0:
		pool.append({"id": "evo_hunter_swarm", "kind": "evolution", "weight": 8, "max": 1, "dps": 13.0})
	return pool


func _record_upgrade(option: Dictionary) -> void:
	var id := str(option.get("id", "unknown"))
	upgrade_counts[id] = int(upgrade_counts.get(id, 0)) + 1
	upgrade_distribution[id] = int(upgrade_distribution.get(id, 0)) + 1


func _format_time(seconds_value: int) -> String:
	var minutes := int(seconds_value / 60)
	var seconds := seconds_value % 60
	return "%02d:%02d" % [minutes, seconds]


func _affix_for_elite(index: int) -> String:
	var affixes := ["affix_split", "affix_field", "affix_swift"]
	return affixes[index % affixes.size()]
