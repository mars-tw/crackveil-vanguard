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
var elite_kill_times: Array[int] = []
var boss_phase_two_time: int = -1
var boss_kill_time: int = -1
var min_hp_ratio: float = 1.0
var min_hp_before_90: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_mock")


func _run_mock() -> void:
	seed(MOCK_SEED)
	var hp := 110.0
	var max_hp := 110.0
	var dps := 88.0
	var pickup_quality := 1.0
	var level_index := 0
	var boss_hp := 2600.0
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
				"qualitative":
					dps += float(upgrade.get("dps", 9.0))
					pickup_quality += float(upgrade.get("pickup", 0.0))
				"damage":
					dps += 7.0
				"projectiles":
					dps += 9.0
				"cooldown":
					dps += 6.0
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
		if second >= 90:
			hp_scale = 1.0 + 0.04 * (float(second - 90) / 60.0)
		var spawn_count := 1 + int(float(second) / 60.0)
		var density := float(spawn_count) * (0.55 if boss_active else 1.0)
		var incoming := (density * hp_scale * 1.18) - (dps / 260.0) - ((pickup_quality - 1.0) * 0.16)
		if ELITE_SPAWN_TIMES.has(second):
			incoming += 7.5
		if boss_active:
			incoming += 2.4
		hp = clamp(hp - incoming + 0.9, 1.0, max_hp)
		var ratio := hp / max_hp
		min_hp_ratio = min(min_hp_ratio, ratio)
		if second < 90:
			min_hp_before_90 = min(min_hp_before_90, ratio)

	print("BALANCE_MOCK_RESULT seed=%d survival_time=%s elapsed=%d min_hp=%.3f min_hp_before_90=%.3f" % [
		MOCK_SEED,
		_format_time(RUN_SECONDS),
		RUN_SECONDS,
		min_hp_ratio,
		min_hp_before_90
	])
	print("BALANCE_MOCK_UPGRADES=" + JSON.stringify(upgrade_distribution))
	print("BALANCE_MOCK_SHOP=" + JSON.stringify(shop_distribution))
	print("BALANCE_MOCK_EVENTS elites_spawned=%d elites_killed=%d elite_spawn_times=%s elite_kill_times=%s boss_spawn_time=%d boss_phase_two_time=%d boss_kill_time=%d density_drop_during_boss=true" % [
		elites_spawned,
		elite_kill_times.size(),
		JSON.stringify(ELITE_SPAWN_TIMES),
		JSON.stringify(elite_kill_times),
		BOSS_SPAWN_TIME,
		boss_phase_two_time,
		boss_kill_time
	])
	var curve_pass := min_hp_before_90 < 0.82 and elites_spawned >= 3 and boss_phase_two_time >= BOSS_SPAWN_TIME and boss_kill_time > BOSS_SPAWN_TIME
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
	var base_pool: Array = [
		{"id": "recruit_hero", "kind": "recruit", "weight": 4, "max": 2},
		{"id": "riftline_fork", "kind": "qualitative", "weight": 3, "max": 2, "dps": 12.0},
		{"id": "orbit_resonance", "kind": "qualitative", "weight": 3, "max": 1, "dps": 9.0},
		{"id": "pulse_embers", "kind": "qualitative", "weight": 3, "max": 1, "dps": 10.0},
		{"id": "chain_overload", "kind": "qualitative", "weight": 3, "max": 1, "dps": 11.0},
		{"id": "magnetic_reclaim", "kind": "qualitative", "weight": 3, "max": 1, "dps": 4.0, "pickup": 0.35},
		{"id": "weapon_damage", "kind": "damage", "weight": 1, "max": 5},
		{"id": "weapon_projectiles", "kind": "projectiles", "weight": 1, "max": 3},
		{"id": "weapon_cooldown", "kind": "cooldown", "weight": 1, "max": 4},
		{"id": "max_hp", "kind": "max_hp", "weight": 1, "max": 5},
		{"id": "pickup_radius", "kind": "pickup", "weight": 1, "max": 5}
	]
	var pool: Array = []
	for option in base_pool:
		var id := str(option.get("id", ""))
		if int(upgrade_counts.get(id, 0)) < int(option.get("max", 1)):
			pool.append(option)
	return pool


func _record_upgrade(option: Dictionary) -> void:
	var id := str(option.get("id", "unknown"))
	upgrade_counts[id] = int(upgrade_counts.get(id, 0)) + 1
	upgrade_distribution[id] = int(upgrade_distribution.get(id, 0)) + 1


func _format_time(seconds_value: int) -> String:
	var minutes := int(seconds_value / 60)
	var seconds := seconds_value % 60
	return "%02d:%02d" % [minutes, seconds]
