extends Node

const HERO_SCENE := preload("res://scenes/heroes/Hero.tscn")
const CAPTAIN_DATA := preload("res://resources/heroes/rift_captain.tres")
const RAIL_SCRIPT := preload("res://scripts/weapons/rail_lance_weapon.gd")
const RAIL_DATA := preload("res://resources/weapons/rail_lance.tres")
const CHAIN_SCRIPT := preload("res://scripts/weapons/chain_lightning_weapon.gd")
const CHAIN_DATA := preload("res://resources/weapons/arc_chain.tres")
const FEEDBACK_SCRIPT := preload("res://scripts/vfx/combat_feedback.gd")

var failed: bool = false
var hero: Node2D


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameManager.game_running = false
	EntityFactory.initialize_for_arena(self)
	hero = HERO_SCENE.instantiate()
	add_child(hero)
	hero.setup(CAPTAIN_DATA, null, true, 0)
	hero.set_process(false)
	hero.set_physics_process(false)
	for controller in hero.get_children():
		if controller.is_in_group("hero_controllers"):
			controller.set_process(false)
			controller.set_physics_process(false)
	for weapon in (hero.get("weapons") as Dictionary).values():
		weapon.set_process(false)
		weapon.set_physics_process(false)
	GameManager.player = hero
	GameManager.squad_manager = null
	GameManager.waiting_for_upgrade = false
	GameManager.waiting_for_contract = false
	GameManager.waiting_for_shop = false
	GameManager.manual_paused = false
	GameManager.system_pause_owners.clear()
	get_tree().paused = false
	_test_arc_reuse()
	await _test_projectile_reuse()
	await _test_orbit_and_burst_reuse()
	await _test_opening_firepower()
	await _test_weapon_damage_and_expiry()
	if failed:
		return
	print("ATTACK_VFX_R34_POOL_PASS reuse_per_type=10 stale_points=0 stretched_bitmap_segments=0 damage_preserved=true")
	get_tree().quit(0)


func _test_arc_reuse() -> void:
	var expected_id := 0
	for iteration in range(10):
		var arc: Node = EntityFactory.spawn_lightning_arc([Vector2.ZERO, Vector2(900.0, 0.0)], Color.CYAN, 1.0, "res://assets/sprites/proj_lightning.png", 48.0)
		if expected_id == 0:
			expected_id = arc.get_instance_id()
		_assert(arc.get_instance_id() == expected_id, "arc exercise did not reuse the same pooled instance")
		var state: Dictionary = arc.get_debug_state()
		_assert(float(state["lifetime"]) <= 0.12 and float(state["max_contact_streak"]) <= 18.0 and int(state["legacy_segments_visible"]) == 0, "arc recreated the stretched triangle renderer")
		# Reproduce stale pre-R34 billboard state before releasing this instance.
		if (arc.get("segments") as Array).is_empty():
			var legacy := Sprite2D.new()
			arc.add_child(legacy)
			(arc.get("segments") as Array).append(legacy)
		var old: Sprite2D = (arc.get("segments") as Array)[0]
		old.visible = true
		old.texture = load("res://assets/sprites/proj_lightning.png")
		old.position = Vector2(450.0, -170.0)
		old.scale = Vector2(25.0, 14.0)
		EntityFactory.release_lightning_arc(arc)
		_assert((arc.get("points") as Array).is_empty() and not old.visible and old.texture == null and old.position == Vector2.ZERO and old.scale == Vector2.ONE, "arc release retained old billboard geometry or points")
	print("ATTACK_VFX_R34_ARC same_instance_reuses=10 old_texture=null points=0 lifetime<=0.12 contact_length<=18")


func _test_projectile_reuse() -> void:
	var expected_id := 0
	var target := _enemy(Vector2(120.0, 0.0))
	for iteration in range(10):
		var hostile: Node = EntityFactory.spawn_projectile(Vector2(-1000.0, -1000.0), Vector2.RIGHT, {"source_weapon_id": "test_hostile", "target_group": "heroes", "damage": 1.0}, null)
		hostile.set_physics_process(false)
		if expected_id == 0:
			expected_id = hostile.get_instance_id()
		var old_trail: Line2D = hostile.get("trail")
		_assert(not old_trail.points.is_empty(), "hostile setup did not seed a previous trail to exercise")
		EntityFactory.release_projectile(hostile)
		await get_tree().process_frame
		_assert(old_trail.points.is_empty() and not old_trail.visible, "projectile release only hid its old trail")
		var dart: Node = EntityFactory.spawn_projectile(Vector2.ZERO, Vector2.RIGHT, {"source_weapon_id": "riftline_emitter", "target_group": "enemies", "damage": 20.0, "pierce": 1, "projectile_radius": 6.0}, hero)
		dart.set_physics_process(false)
		_assert(dart.get_instance_id() == expected_id and (dart.get("trail") as Line2D).points.is_empty() and not (dart.get("trail") as Line2D).visible, "friendly pool generation retained hostile trail points")
		var hp_before := float(target.get("hp"))
		dart.call("_on_body_entered", target)
		_assert(float(target.get("hp")) < hp_before, "removing friendly trail removed the actual projectile hit")
		EntityFactory.release_projectile(dart)
		await get_tree().process_frame
	EntityFactory.release_enemy(target)
	print("ATTACK_VFX_R34_PROJECTILE same_instance_reuses=10 hostile_to_friendly_points=0 real_damage_hits=10")


func _test_orbit_and_burst_reuse() -> void:
	var orbit_id := 0
	var burst_id := 0
	for iteration in range(10):
		var orbit: Node = EntityFactory.spawn_orbit_projectile(hero, null, {"projectile_radius": 10.5, "orbit_radius": 88.0, "damage": 8.0}, 0, 1)
		orbit.set_physics_process(false)
		if orbit_id == 0:
			orbit_id = orbit.get_instance_id()
		_assert(orbit.get_instance_id() == orbit_id and (orbit.get("trail") as Line2D).points.is_empty() and not (orbit.get("trail") as Line2D).visible, "orbit retained a permanent following line")
		(orbit.get("trail") as Line2D).points = PackedVector2Array([Vector2(-300.0, 0.0), Vector2.ZERO])
		EntityFactory.release_orbit_projectile(orbit)
		await get_tree().process_frame
		_assert((orbit.get("trail") as Line2D).points.is_empty(), "orbit release retained line geometry")
		var burst: Node = EntityFactory.spawn_death_burst(Vector2.ZERO, Color.WHITE, 1.0, "level_column")
		if burst_id == 0:
			burst_id = burst.get_instance_id()
		_assert(burst.get_instance_id() == burst_id, "burst exercise did not reuse its pooled instance")
		EntityFactory.release_death_burst(burst)
		_assert((burst.get("column") as Line2D).points.is_empty() and (burst.get("shockwave") as Line2D).points.is_empty(), "burst release retained column or shockwave points")
	print("ATTACK_VFX_R34_ORBIT_BURST same_instance_reuses=10 orbit_points=0 column_points=0 shockwave_points=0")


func _test_weapon_damage_and_expiry() -> void:
	var first := _enemy(Vector2(120.0, 0.0))
	var second := _enemy(Vector2(260.0, 0.0))
	var rail := RAIL_SCRIPT.new()
	var chain := CHAIN_SCRIPT.new()
	add_child(rail)
	add_child(chain)
	rail.setup(hero, RAIL_DATA)
	chain.setup(hero, CHAIN_DATA)
	rail.set_process(false)
	chain.set_process(false)
	GameManager.game_running = true
	for iteration in range(10):
		var first_before := float(first.get("hp"))
		var second_before := float(second.get("hp"))
		rail.call("_fire_lance", first)
		_assert(float(first.get("hp")) < first_before and float(second.get("hp")) < second_before, "rail lost its penetrating damage after shortening visual strokes")
		first_before = float(first.get("hp"))
		second_before = float(second.get("hp"))
		chain.call("_cast_chain", first)
		_assert(float(first.get("hp")) < first_before and float(second.get("hp")) < second_before, "chain lost a real linked-target hit after removing connections")
		await get_tree().create_timer(0.15).timeout
		_assert(EntityFactory.get_pool_live_count("lightning_arc") == 0, "completed rail/chain stroke did not return to the pool")
	var feedback := FEEDBACK_SCRIPT.new()
	add_child(feedback)
	for iteration in range(10):
		FEEDBACK_SCRIPT.report_slash(Vector2.ZERO, Vector2.RIGHT, 270.0, deg_to_rad(69.0), true)
		await get_tree().create_timer(0.20).timeout
		_assert(int(feedback.get_debug_state()["live_effects"]) == 0, "completed main crescent retained an afterimage entry")
	print("ATTACK_VFX_R34_DAMAGE rail_casts=10 chain_casts=10 every_cast_hits_two_targets=true all_strokes_expire=true crescent_cycles=10 live_after_expiry=0")


func _test_opening_firepower() -> void:
	var targets: Array[Node] = []
	for point in [Vector2(350.0, 0.0), Vector2(350.0, -80.0), Vector2(350.0, 80.0), Vector2(445.0, 0.0), Vector2(445.0, -100.0), Vector2(445.0, 100.0)]:
		targets.append(_enemy(point))
	var weapon: Node = (hero.get("weapons") as Dictionary).get("riftline_emitter")
	weapon.reset_weapon()
	weapon.set_process(true)
	GameManager.game_running = true
	await get_tree().create_timer(2.1).timeout
	weapon.set_process(false)
	var state: Dictionary = weapon.get_firepower_debug_state()
	_assert(int(state["volley_size"]) == 12 and int(state["projectiles_fired"]) >= 60 and float(state["projectiles_per_second"]) >= 30.0, "opening weapon did not actually emit twelve-shot volleys at the new cadence")
	var damaged_targets := 0
	for target in targets:
		if float(target.get("hp")) < 3000.0:
			damaged_targets += 1
	_assert(damaged_targets == 6, "opening fan and pierce did not damage both rows across all three lanes")
	_assert(weapon.apply_data_upgrade("weapon_projectiles") and weapon.apply_data_upgrade("weapon_projectiles"), "12 to 16 to 20 projectile-count upgrades failed")
	_assert(not weapon.apply_data_upgrade("weapon_projectiles"), "completed volley cap continued to offer a ineffective count upgrade")
	var before := int(weapon.get_firepower_debug_state()["projectiles_fired"])
	weapon.call("_fire_at", targets[0])
	_assert(int(weapon.get_firepower_debug_state()["projectiles_fired"]) == before + 20, "12 to 20 upgrade changed a label without spawning twenty actual projectiles")
	_assert(weapon.apply_data_upgrade("evo_rift_fan"), "fan evolution failed after reaching the volley cap")
	before = int(weapon.get_firepower_debug_state()["projectiles_fired"])
	weapon.call("_fire_at", targets[0])
	_assert(int(weapon.get_firepower_debug_state()["projectiles_fired"]) == before + 20, "evolution reduced a capped twenty-shot volley")
	var hero_state: Dictionary = hero.get_firepower_debug_state()
	_assert(int(hero_state["orbit_blades"]) == 3 and is_equal_approx(float(hero_state["orbit_angular_speed"]), 5.1) and float(hero_state["auto_cleave_interval"]) >= 1.0 / 3.0 and float(hero_state["auto_cleave_interval"]) <= 0.48 and int(hero_state["chain_targets"]) == 4, "opening firepower readout diverged from real weapon data or outran authored recovery")
	for target in targets:
		EntityFactory.release_enemy(target)
	print("ATTACK_VFX_R34_FIREPOWER actual_projectiles=%d active_seconds=%.3f measured_rate=%.2f/s hit_lanes=3 hit_rows=2 starter_volley=12 upgrade_volley=20 evolved_volley=20 orbit=3 auto_interval=%.2f" % [int(state["projectiles_fired"]), float(state["seconds"]), float(state["projectiles_per_second"]), float(hero_state["auto_cleave_interval"])])


func _enemy(position: Vector2) -> Node:
	var enemy: Node = EntityFactory.spawn_enemy("r34_vfx_target", {"max_hp": 3000.0, "speed": 0.0, "damage": 0.0, "xp": 0, "gold": 0, "radius": 13.0, "sprite_path": "res://assets/sprites/enemy_grunt.png"}, position)
	enemy.set_physics_process(false)
	return enemy


func _assert(condition: bool, message: String) -> void:
	if condition or failed:
		return
	failed = true
	printerr("ATTACK_VFX_R34_POOL_FAIL: " + message)
	get_tree().quit(1)
