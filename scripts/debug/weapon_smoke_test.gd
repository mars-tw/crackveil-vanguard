extends Node

const EXPECTED_INITIAL_WEAPONS: Array[String] = [
	"rift_captain:riftline_emitter",
	"rift_captain:orbit_blades",
	"rift_captain:arc_chain",
	"orbit_guard:rift_shield_boomerang",
	"arc_scout:rift_seeker_missiles"
]

const RECRUIT_HERO_IDS: Array[String] = [
	"pulse_artificer",
	"line_mender",
	"ember_grenadier",
	"void_weaver",
	"rift_sniper",
	"echo_singer"
]
const EXPECTED_RECRUIT_WEAPONS: Array[String] = [
	"pulse_artificer:pulse_bloom",
	"line_mender:riftline_emitter",
	"ember_grenadier:grenade_lob",
	"void_weaver:void_net",
	"rift_sniper:rail_lance",
	"echo_singer:echo_hymn"
]

var arena: Node = null
var squad_manager: Node = null
var leader: Node2D = null
var frame_count: int = 0
var initialized: bool = false
var recruit_index: int = 0
var follow_checked: bool = false
var max_follow_error: float = 0.0


func _ready() -> void:
	arena = load("res://scenes/arena/Arena.tscn").instantiate()
	add_child(arena)


func _process(_delta: float) -> void:
	frame_count += 1

	if not initialized and frame_count >= 5:
		_initialize_test()

	if initialized and recruit_index < RECRUIT_HERO_IDS.size() and frame_count >= 180 + recruit_index * 42:
		_run_recruit_check()

	if initialized and not follow_checked and recruit_index >= RECRUIT_HERO_IDS.size() and frame_count >= 620:
		_run_follow_check()

	if frame_count >= 960:
		_finish_test()


func _initialize_test() -> void:
	initialized = true
	squad_manager = arena.get_node_or_null("SquadManager")
	if squad_manager == null:
		_fail("SquadManager not found")
		return

	var spawner := arena.get_node_or_null("EnemySpawner")
	if spawner != null:
		spawner.set_process(false)

	if squad_manager.get_member_count() != 3:
		_fail("expected 3 starting heroes, got %d" % squad_manager.get_member_count())
		return

	leader = squad_manager.get("leader")
	if leader == null or not is_instance_valid(leader):
		_fail("leader not found")
		return

	print("WEAPON_SMOKE_INITIAL_COUNT=3")
	leader.global_position += Vector2(190.0, -40.0)
	_spawn_enemy_clusters_for_members()


func _run_recruit_check() -> void:
	var hero_id := RECRUIT_HERO_IDS[recruit_index]
	if not squad_manager.recruit_hero(hero_id):
		_fail("recruit upgrade failed for " + hero_id)
		return

	recruit_index += 1
	var expected_count := 3 + recruit_index
	if squad_manager.get_member_count() != expected_count:
		_fail("expected %d heroes after recruit, got %d" % [expected_count, squad_manager.get_member_count()])
		return

	print("WEAPON_SMOKE_RECRUIT_COUNT=%d latest=%s" % [squad_manager.get_member_count(), hero_id])
	_spawn_enemy_clusters_for_members()


func _run_follow_check() -> void:
	follow_checked = true
	max_follow_error = 0.0
	var members: Array = squad_manager.get_members()
	for slot_index in range(1, members.size()):
		var member: Node2D = members[slot_index]
		var target_position: Vector2 = squad_manager.get_formation_world_position(slot_index)
		var error: float = member.global_position.distance_to(target_position)
		max_follow_error = max(max_follow_error, error)

	print("WEAPON_SMOKE_FOLLOW_MAX_ERROR=%.2f" % max_follow_error)
	if max_follow_error > 92.0:
		_fail("followers did not settle into formation")


func _spawn_enemy_clusters_for_members() -> void:
	var members: Array = squad_manager.get_members()
	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		_spawn_cluster(member.global_position)


func _spawn_cluster(center: Vector2) -> void:
	var positions: Array[Vector2] = [
		center + Vector2(44.0, 0.0),
		center + Vector2(-44.0, 8.0),
		center + Vector2(0.0, 52.0),
		center + Vector2(92.0, -18.0),
		center + Vector2(156.0, 22.0)
	]

	var config: Dictionary = {
		"max_hp": 9999.0,
		"speed": 0.0,
		"damage": 0.0,
		"xp": 0,
		"gold": 0,
		"radius": 14.0,
		"color": Color(0.55, 0.78, 1.0),
		"attack_cooldown": 10.0
	}

	for position in positions:
		EntityFactory.spawn_enemy("squad_smoke", config, position)


func _finish_test() -> void:
	var counts: Dictionary = {}
	if squad_manager != null and is_instance_valid(squad_manager):
		counts = squad_manager.get_weapon_trigger_counts()

	print("WEAPON_SMOKE_COUNTS=" + JSON.stringify(counts))

	for key in EXPECTED_INITIAL_WEAPONS:
		if int(counts.get(key, 0)) <= 0:
			_fail(key + " did not trigger")
			return

	for key in EXPECTED_RECRUIT_WEAPONS:
		if int(counts.get(key, 0)) <= 0:
			_fail(key + " did not trigger after recruit")
			return

	if not follow_checked:
		_fail("follow check did not run")
		return

	print("WEAPON_SMOKE_PASS: 9-member squad, following, weapons, and recruit upgrades verified")
	get_tree().quit(0)


func _fail(message: String) -> void:
	printerr("WEAPON_SMOKE_FAIL: " + message)
	get_tree().quit(1)
