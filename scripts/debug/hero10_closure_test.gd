extends Node

const SQUAD_MANAGER_SCRIPT := preload("res://scripts/heroes/squad_manager.gd")

var failed := false
var manager: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EntityFactory.initialize_for_arena(self)
	await get_tree().process_frame
	_setup_full_squad()
	if failed:
		return
	_test_growth_pull_and_cap_fifo()
	if failed:
		return
	_test_late_recruit_damage_reduction_and_heal_removal()
	if failed:
		return
	_test_aoe_bond_survives_growth_rebuilds()
	if failed:
		return
	_test_soft_caps()
	if failed:
		return
	print("HERO10_CLOSURE_PASS")
	get_tree().quit(0)


func _setup_full_squad() -> void:
	manager = SQUAD_MANAGER_SCRIPT.new()
	add_child(manager)
	var leader: Node = manager.start_squad()
	_assert(leader != null, "starting squad failed")
	GameManager.squad_manager = manager
	GameManager.player = leader
	GameManager.arena = self
	GameManager.game_running = true
	for hero_id in ["pulse_artificer", "rift_shepherd", "ember_grenadier", "void_weaver", "rift_sniper", "echo_singer"]:
		_assert(manager.recruit_hero(hero_id), "failed to recruit " + hero_id)
	_disable_weapon_processing()
	_assert(manager.get_member_count() == 9, "closure squad must be full")
	_assert(manager.get_active_bond_count() == 4, "full squad must activate all four bonds")


func _disable_weapon_processing() -> void:
	for member in manager.get_members():
		for weapon in (member.get("weapons") as Dictionary).values():
			weapon.set_process(false)


func _test_growth_pull_and_cap_fifo() -> void:
	var shepherd: Node = manager.get_member_by_id("rift_shepherd")
	var captain: Node = manager.get_member_by_id("rift_captain")
	var weapon: Node = (shepherd.get("weapons") as Dictionary).get("rift_constructs")
	_assert(weapon != null, "shepherd weapon missing")
	_assert(int(weapon.call("_owner_active_cap", weapon.call("_construct_stats"))) == 5, "pre-evolution bond cap must be 5")
	for upgrade in ["construct_anchor", "construct_anchor", "weapon_damage", "weapon_damage", "weapon_damage", "evo_mirror_flock"]:
		_assert(weapon.apply_data_upgrade(upgrade), "failed shepherd growth upgrade: " + upgrade)
	var stats: Dictionary = weapon.call("_construct_stats")
	_assert(int(stats.get("construct_anchor_level", 0)) == 2 and int(stats.get("evo_mirror_flock_level", 0)) == 1, "growth stats cache did not rebuild")
	_assert(int(weapon.call("_owner_active_cap", stats)) == 6, "evolution + passive + bond cap must clamp to 6")

	for index in range(6):
		EntityFactory.spawn_rift_construct(captain.global_position + Vector2(float(index) * 8.0, 0.0), stats, shepherd, weapon, 6)
	var before: Array[Node] = EntityFactory.get_rift_constructs_for_owner(shepherd)
	_assert(before.size() == 6, "failed to fill evolved construct cap")
	var oldest_id := before[0].get_instance_id()
	var capped_multiplier := float(before[0].call("_construct_damage_multiplier"))
	_assert(is_equal_approx(capped_multiplier, 1.25), "construct damage soft cap did not clamp captain + flock sources")

	# Captain death disables the bond in the same event cycle. The former +1
	# slot must disappear immediately and the oldest registry entry is reclaimed.
	captain.set("is_alive", false)
	manager.recompute_bonds()
	var after: Array[Node] = EntityFactory.get_rift_constructs_for_owner(shepherd)
	_assert(not manager.has_active_bond("bond_captain_shepherd"), "captain death did not disable bond")
	_assert(after.size() == 5, "bond cap decrease did not immediately trim to 5")
	for construct in after:
		_assert(construct.get_instance_id() != oldest_id, "cap decrease did not reclaim FIFO oldest")
	var no_dead_captain_bonus := float(after[0].call("_construct_damage_multiplier"))
	_assert(no_dead_captain_bonus <= 1.1201, "dead captain retained proximity damage")
	print("HERO10_BOND_CAP growth=L2+evo cap=6->5 fifo_oldest=true captain_bonus=0 shatter_on_live_owner=true")

	EntityFactory.release_rift_constructs_for_owner(shepherd, false)
	captain.set("is_alive", true)
	manager.recompute_bonds()


func _test_late_recruit_damage_reduction_and_heal_removal() -> void:
	var guard: Node = manager.get_member_by_id("orbit_guard")
	var echo: Node = manager.get_member_by_id("echo_singer")
	var late_member: Node = manager.get_member_by_id("rift_sniper")
	_assert(manager.has_active_bond("bond_guard_echo"), "guard/echo bond missing")
	_assert(is_equal_approx(GameManager.get_incoming_damage_multiplier(late_member), 0.95), "pull DR did not apply to a later recruit")

	var echo_weapon: Node = (echo.get("weapons") as Dictionary).get("echo_hymn")
	late_member.set("current_hp", 0.0)
	var hp_before := float(late_member.get("current_hp"))
	echo_weapon.call("_cast_hymn")
	var bonded_heal := float(late_member.get("current_hp")) - hp_before
	guard.set("is_alive", false)
	manager.recompute_bonds()
	late_member.set("current_hp", 0.0)
	echo_weapon.call("_cast_hymn")
	var baseline_heal := float(late_member.get("current_hp"))
	_assert(not manager.has_active_bond("bond_guard_echo"), "guard death did not disable bond")
	_assert(is_equal_approx(GameManager.get_incoming_damage_multiplier(late_member), 1.0), "guard DR became sticky after bond loss")
	_assert(is_equal_approx(bonded_heal, baseline_heal * 1.10), "echo heal did not return exactly to baseline after bond loss")
	print("HERO10_BOND_GUARD late_recruit_dr=0.95->1.00 heal_mul=1.10->1.00 sticky=false")
	guard.set("is_alive", true)
	manager.recompute_bonds()


func _test_aoe_bond_survives_growth_rebuilds() -> void:
	var pulse: Node = manager.get_member_by_id("pulse_artificer")
	var ember: Node = manager.get_member_by_id("ember_grenadier")
	var pulse_weapon: Node = (pulse.get("weapons") as Dictionary).get("pulse_bloom")
	var ember_weapon: Node = (ember.get("weapons") as Dictionary).get("grenade_lob")
	for upgrade in ["pulse_embers", "evo_ember_well"]:
		_assert(pulse_weapon.apply_data_upgrade(upgrade), "pulse growth upgrade failed: " + upgrade)
	for upgrade in ["grenade_cluster", "grenade_cluster", "evo_cinder_barrage"]:
		_assert(ember_weapon.apply_data_upgrade(upgrade), "grenade growth upgrade failed: " + upgrade)

	manager.active_bonds.erase("bond_ember_pulse")
	var pulse_without: Dictionary = pulse_weapon.call("_effect_stats_for_fire")
	var ember_without: Dictionary = ember_weapon.call("_effect_stats_for_fire")
	var ember_burn_without: Dictionary = ember_weapon.call("_make_burn_stats", ember_without)
	manager.recompute_bonds()
	var pulse_with: Dictionary = pulse_weapon.call("_effect_stats_for_fire")
	var ember_with: Dictionary = ember_weapon.call("_effect_stats_for_fire")
	var ember_burn_with: Dictionary = ember_weapon.call("_make_burn_stats", ember_with)
	_assert(is_equal_approx(float(pulse_with.get("area_radius")), float(pulse_without.get("area_radius")) * 1.08), "pulse lost +8% bond radius after evolution rebuild")
	_assert(is_equal_approx(float(ember_with.get("area_radius")), float(ember_without.get("area_radius")) * 1.08), "grenade lost +8% bond radius after evolution rebuild")
	_assert(is_equal_approx(float(ember_burn_with.get("damage_per_second")), float(ember_burn_without.get("damage_per_second")) * 1.06), "grenade burn lost +6% bond damage after evolution rebuild")
	print("HERO10_BOND_GROWTH pulse_radius=1.08 grenade_radius=1.08 burn_tick=1.06 rebuild_safe=true")


func _test_soft_caps() -> void:
	var shepherd: Node = manager.get_member_by_id("rift_shepherd")
	var weapon: Node = (shepherd.get("weapons") as Dictionary).get("rift_constructs")
	var stats: Dictionary = weapon.call("_construct_stats")
	for index in range(4):
		EntityFactory.spawn_rift_construct(shepherd.global_position + Vector2(float(index) * 6.0, 0.0), stats, shepherd, weapon, 6)
	var original_modifiers: Dictionary = GameManager.contract_modifiers.duplicate(true)
	GameManager.contract_modifiers["incoming_damage_multiplier"] = 0.50
	var incoming := GameManager.get_incoming_damage_multiplier(shepherd)
	GameManager.contract_modifiers = original_modifiers
	_assert(is_equal_approx(incoming, 0.85), "all-source incoming damage soft cap was bypassed")
	var constructs: Array[Node] = EntityFactory.get_rift_constructs_for_owner(shepherd)
	_assert(not constructs.is_empty() and is_equal_approx(float(constructs[0].call("_construct_damage_multiplier")), 1.25), "single-weapon damage soft cap was bypassed")
	EntityFactory.release_rift_constructs_for_owner(shepherd, false)
	print("HERO10_SOFT_CAP incoming_min=0.85 construct_damage_max=1.25")


func _assert(condition: bool, message: String) -> void:
	if condition or failed:
		return
	failed = true
	printerr("HERO10_CLOSURE_FAIL: " + message)
	get_tree().quit(1)
