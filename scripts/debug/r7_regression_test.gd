extends Node

const ARENA_SCENE: PackedScene = preload("res://scenes/arena/Arena.tscn")

var arena: Node = null
var squad_manager: Node = null
var leader: Node2D = null
var spawner: Node = null
var hud: CanvasLayer = null
var contract_screen: CanvasLayer = null
var test_selected_contract_id: String = ""
var current_phase: String = "boot"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	arena = ARENA_SCENE.instantiate()
	add_child(arena)
	call_deferred("_watchdog")
	call_deferred("_run_tests")


func _run_tests() -> void:
	current_phase = "initial_frames"
	await get_tree().process_frame
	await get_tree().process_frame

	current_phase = "setup"
	squad_manager = arena.get_node_or_null("SquadManager")
	spawner = arena.get_node_or_null("EnemySpawner")
	hud = arena.get_node_or_null("HUD") as CanvasLayer
	contract_screen = arena.get_node_or_null("ContractScreen") as CanvasLayer
	leader = GameManager.player
	if squad_manager == null or spawner == null or hud == null or contract_screen == null or leader == null or not is_instance_valid(leader):
		_fail("arena setup failed")
		return

	spawner.set_process(false)
	_prepare_run_state()

	current_phase = "contract_meta"
	if not _test_contract_meta_purchase_applies_current_run():
		return
	current_phase = "contract_pause"
	if not _test_system_pause_contract_exclusion():
		return
	current_phase = "affix_split"
	var split_ok: bool = await _test_affix_split_and_cap()
	if not split_ok:
		return
	current_phase = "affix_field_swift"
	if not _test_affix_field_and_swift():
		return
	current_phase = "weapon_evolutions"
	if not _test_weapon_evolutions():
		return
	current_phase = "ember_delay"
	var ember_ok: bool = await _test_ember_well_delayed_burst()
	if not ember_ok:
		return
	current_phase = "meta_roundtrip"
	if not _test_meta_progress_roundtrip_and_reset():
		return
	current_phase = "echo_delta"
	if not _test_echo_delta_victory_continue_death():
		return

	current_phase = "done"
	print("R7_REGRESSION_PASS")
	get_tree().quit(0)


func _watchdog() -> void:
	await get_tree().create_timer(20.0, true).timeout
	if current_phase != "done":
		_fail("watchdog timeout at phase: " + current_phase)


func _prepare_run_state() -> void:
	GameManager.game_running = true
	GameManager.is_game_over = false
	GameManager.waiting_for_contract = false
	GameManager.waiting_for_upgrade = false
	GameManager.waiting_for_shop = false
	GameManager.stage_victory_pending = false
	GameManager.manual_paused = false
	GameManager.system_pause_owners.clear()
	GameManager.boss_active = false
	GameManager.active_contract_id = ""
	GameManager.active_contract_name = "無契約"
	GameManager.contract_modifiers.clear()
	GameManager.echo_shards_awarded_this_run = 0
	GameManager.level = 7
	GameManager.xp = 0
	GameManager.xp_required = 99999999
	GameManager.gold = 999
	GameManager.gold_earned = 999
	get_tree().paused = false


func _test_contract_meta_purchase_applies_current_run() -> bool:
	MetaProgress.debug_use_save_path("user://r7_meta_test.cfg", true)
	GameManager.apply_current_meta_progress_to_squad()
	var hp_before: float = float(leader.get("max_hp"))
	var pickup_before: float = float(leader.get("pickup_radius"))
	MetaProgress.set("shards", 100)
	MetaProgress.save_progress()

	contract_screen._on_meta_upgrade_pressed("echo_vitality")
	contract_screen._on_meta_upgrade_pressed("echo_magnetism")

	var hp_after: float = float(leader.get("max_hp"))
	var pickup_after: float = float(leader.get("pickup_radius"))
	if not is_equal_approx(hp_after, hp_before * 1.02):
		_fail("contract meta vitality did not apply to current run")
		return false
	if not is_equal_approx(pickup_after, pickup_before + 6.0):
		_fail("contract meta magnetism did not apply to current run")
		return false

	GameManager.apply_current_meta_progress_to_squad()
	if not is_equal_approx(float(leader.get("max_hp")), hp_after) or not is_equal_approx(float(leader.get("pickup_radius")), pickup_after):
		_fail("contract meta reapply stacked instead of delta-applying")
		return false

	if not squad_manager.recruit_hero("line_mender"):
		_fail("line mender recruit failed for meta snapshot test")
		return false
	var recruit: Node = squad_manager.get_member_by_id("line_mender")
	if recruit == null or not is_instance_valid(recruit):
		_fail("recruited hero missing for meta snapshot test")
		return false
	if not is_equal_approx(float(recruit.get("max_hp")), 90.0 * 1.02):
		_fail("recruited hero did not receive meta hp snapshot")
		return false
	if not is_equal_approx(float(recruit.get("pickup_radius")), 72.0 + 6.0):
		_fail("recruited hero did not receive meta pickup snapshot")
		return false

	print("R7_META_CONTRACT_APPLY hp %.2f->%.2f pickup %.2f->%.2f recruit_hp=%.2f" % [
		hp_before,
		hp_after,
		pickup_before,
		pickup_after,
		float(recruit.get("max_hp"))
	])
	return true


func _test_system_pause_contract_exclusion() -> bool:
	test_selected_contract_id = ""
	GameManager.waiting_for_contract = false
	GameManager.waiting_for_upgrade = false
	GameManager.waiting_for_shop = false
	GameManager.stage_victory_pending = false
	GameManager.is_game_over = false
	GameManager.game_running = true
	GameManager.system_pause_owners.clear()
	GameManager.manual_paused = false
	get_tree().paused = false
	GameManager.set_manual_pause(true)
	var pause_overlay := hud.get("pause_overlay") as Control
	if pause_overlay == null:
		_fail("pause overlay missing for contract modal test")
		return false
	if not pause_overlay.visible:
		_fail("manual pause overlay did not show before contract modal test")
		return false

	GameManager.waiting_for_contract = true
	GameManager._request_system_pause("contract")
	if not get_tree().paused:
		_fail("contract system pause did not pause tree")
		return false
	if pause_overlay.visible:
		_fail("pause overlay remained visible over contract modal")
		return false
	if int(contract_screen.layer) <= int(hud.layer):
		_fail("contract screen layer is not above HUD")
		return false

	if not contract_screen.contract_selected.is_connected(Callable(self, "_record_contract_selection")):
		contract_screen.contract_selected.connect(Callable(self, "_record_contract_selection"), CONNECT_ONE_SHOT)
	contract_screen.show_options([
		{
			"id": "contract_blood_tax",
			"name": "血稅",
			"description": "全隊傷害 +12%，受擊傷害 +10%。"
		}
	])
	var buttons: Array = contract_screen.get("option_buttons")
	if buttons.is_empty():
		_fail("contract modal built no buttons")
		return false
	var first_button := buttons[0] as Button
	if first_button == null:
		_fail("contract modal first option is not a button")
		return false
	first_button.pressed.emit()
	if test_selected_contract_id != "contract_blood_tax":
		_fail("contract card did not receive top-level button press")
		return false

	GameManager.waiting_for_contract = false
	GameManager.manual_paused = false
	GameManager.system_pause_owners.clear()
	GameManager.active_contract_id = ""
	GameManager.active_contract_name = "無契約"
	GameManager.contract_modifiers.clear()
	get_tree().paused = false
	hud._on_pause_changed(false)
	print("R7_CONTRACT_PAUSE_EXCLUSION contract_layer=%d hud_layer=%d" % [int(contract_screen.layer), int(hud.layer)])
	return true


func _test_affix_split_and_cap() -> bool:
	_release_active_enemies()
	var old_max := int(spawner.get("max_enemies"))
	spawner.set("max_enemies", 10)
	spawner.set("debug_forced_elite_affix_id", "affix_split")
	if not spawner._spawn_elite():
		_fail("split elite did not spawn")
		return false
	var split_elite := _first_live_elite()
	if split_elite == null or str(split_elite.get("affix_id")) != "affix_split":
		_fail("split elite affix id missing")
		return false
	split_elite.take_damage(999999.0, leader.global_position)
	await get_tree().process_frame
	if _count_active_type("affix_split_spawnling") != 2:
		_fail("split elite did not create two spawnlings with available cap")
		return false

	_release_active_enemies()
	spawner.set("max_enemies", 4)
	for index in range(4):
		EntityFactory.spawn_enemy("r7_cap_regular", _regular_config(), leader.global_position + Vector2(float(index) * 30.0, 420.0))
	if not spawner._spawn_elite():
		_fail("split elite did not replace regular at cap")
		return false
	split_elite = _first_live_elite()
	if split_elite == null:
		_fail("split elite missing after cap replacement")
		return false
	split_elite.take_damage(999999.0, leader.global_position)
	await get_tree().process_frame
	var active_after_split := EntityFactory.get_enemy_active_count()
	if active_after_split > 4:
		_fail("split spawnlings exceeded enemy cap")
		return false

	spawner.set("max_enemies", old_max)
	spawner.set("debug_forced_elite_affix_id", "")
	_release_active_enemies()
	print("R7_AFFIX_SPLIT spawnlings=2 capped_active=%d" % active_after_split)
	return true


func _test_affix_field_and_swift() -> bool:
	_release_active_enemies()
	spawner.set("debug_forced_elite_affix_id", "affix_field")
	if not spawner._spawn_elite():
		_fail("field elite did not spawn")
		return false
	var field_elite := _first_live_elite()
	if field_elite == null:
		_fail("field elite missing")
		return false
	field_elite.global_position = leader.global_position + Vector2(40.0, 0.0)
	leader.set("movement_slow_timer", 0.0)
	field_elite._tick_affix(0.2)
	if float(leader.get("movement_slow_timer")) <= 0.0:
		_fail("field affix did not apply movement slow")
		return false
	if field_elite.get_node_or_null("AffixRing") == null:
		_fail("field affix visual ring missing")
		return false

	_release_active_enemies()
	spawner.set("debug_forced_elite_affix_id", "affix_swift")
	if not spawner._spawn_elite():
		_fail("swift elite did not spawn")
		return false
	var swift_elite := _first_live_elite()
	if swift_elite == null:
		_fail("swift elite missing")
		return false
	var swift_dash_value: float = float(swift_elite.get("dash_speed"))
	var swift_damage_value: float = float(swift_elite.get("damage"))
	if str(swift_elite.get("behavior_id")) != "dasher" or swift_dash_value < 450.0:
		_fail("swift affix did not switch to dash speed mode")
		return false
	if swift_damage_value > 16.5:
		_fail("swift affix damage did not stay in glass-cannon band")
		return false

	spawner.set("debug_forced_elite_affix_id", "")
	_release_active_enemies()
	print("R7_AFFIX_FIELD_SWIFT slow_timer=%.2f swift_dash=%.1f swift_damage=%.2f" % [
		float(leader.get("movement_slow_timer")),
		swift_dash_value,
		swift_damage_value
	])
	return true


func _test_weapon_evolutions() -> bool:
	GameManager.level = 7
	squad_manager.recruit_hero("pulse_artificer")
	var specs: Array[Dictionary] = [
		{"hero": "rift_captain", "weapon": "riftline_emitter", "required": "riftline_fork", "count": 2, "evo": "evo_rift_fan"},
		{"hero": "orbit_guard", "weapon": "orbit_blades", "required": "orbit_resonance", "count": 1, "evo": "evo_shear_halo"},
		{"hero": "pulse_artificer", "weapon": "pulse_bloom", "required": "pulse_embers", "count": 1, "evo": "evo_ember_well"},
		{"hero": "arc_scout", "weapon": "arc_chain", "required": "chain_overload", "count": 1, "evo": "evo_overload_nova"}
	]

	var evolved: Array[String] = []
	for spec in specs:
		var hero: Node = squad_manager.get_member_by_id(str(spec.get("hero", "")))
		if hero == null:
			_fail("missing hero for evolution: " + str(spec.get("hero", "")))
			return false
		var weapon := _weapon_node(hero, str(spec.get("weapon", "")))
		if weapon == null:
			_fail("missing weapon for evolution: " + str(spec.get("weapon", "")))
			return false
		for _index in range(int(spec.get("count", 1))):
			if not weapon.apply_data_upgrade(str(spec.get("required", ""))):
				_fail("failed to apply required modifier: " + str(spec.get("required", "")))
				return false
		if not _find_upgrade_option(str(spec.get("evo", ""))).is_empty():
			_fail("evolution offered before weapon damage investment: " + str(spec.get("evo", "")))
			return false
		for _damage_index in range(3):
			if not weapon.apply_data_upgrade("weapon_damage"):
				_fail("failed to apply weapon damage investment for evolution: " + str(spec.get("weapon", "")))
				return false
		var option := _find_upgrade_option(str(spec.get("evo", "")))
		if option.is_empty():
			_fail("evolution option not offered: " + str(spec.get("evo", "")))
			return false
		if int(option.get("weight", 0)) < 8:
			_fail("evolution option weight too low")
			return false
		squad_manager.apply_upgrade(option)
		var weapon_data: Resource = weapon.get("data")
		if weapon_data == null or not weapon_data.has_method("has_modifier") or not weapon_data.has_modifier(str(spec.get("evo", ""))):
			_fail("evolution modifier not applied: " + str(spec.get("evo", "")))
			return false
		if not _find_upgrade_option(str(spec.get("evo", ""))).is_empty():
			_fail("evolution option remained after one-time trigger")
			return false
		var post_evo_damage_option := _find_numeric_option(
			str(spec.get("hero", "")),
			str(spec.get("weapon", "")),
			"weapon_damage"
		)
		if post_evo_damage_option.is_empty() or float(post_evo_damage_option.get("weight", 1.0)) > 0.36:
			_fail("evolved weapon numeric weight was not reduced")
			return false
		evolved.append(str(spec.get("evo", "")))

	print("R7_EVOLUTIONS evolved=%s" % JSON.stringify(evolved))
	return true


func _test_meta_progress_roundtrip_and_reset() -> bool:
	MetaProgress.debug_use_save_path("user://r7_meta_test.cfg", true)
	var earned := MetaProgress.award_run({
		"elapsed_time": 210.0,
		"kills": 120,
		"gold_earned": 120,
		"level": 10,
		"elites_killed": 3,
		"boss_killed": true
	})
	if earned <= 0 or int(MetaProgress.get("shards")) <= 0:
		_fail("meta award produced no shards")
		return false
	var saved_shards := int(MetaProgress.get("shards"))
	MetaProgress.set("shards", 0)
	MetaProgress.load_progress()
	if int(MetaProgress.get("shards")) != saved_shards:
		_fail("meta save/load did not restore shards")
		return false
	if not MetaProgress.buy_upgrade("echo_vitality"):
		_fail("meta upgrade purchase failed")
		return false
	if int(MetaProgress.get_upgrade_level("echo_vitality")) != 1:
		_fail("meta upgrade level not persisted in memory")
		return false
	MetaProgress.award_run({
		"elapsed_time": 60.0,
		"kills": 0,
		"gold_earned": 480,
		"level": 1,
		"elites_killed": 0,
		"boss_killed": false
	})
	if not MetaProgress.has_unlock("contract_slot") or not MetaProgress.has_unlock("opening_choice"):
		_fail("meta lifetime unlock thresholds failed")
		return false
	MetaProgress.load_progress()
	if int(MetaProgress.get_upgrade_level("echo_vitality")) != 1:
		_fail("meta upgrade did not survive reload")
		return false
	MetaProgress.reset_progress()
	MetaProgress.load_progress()
	if int(MetaProgress.get("shards")) != 0 or int(MetaProgress.get("lifetime_shards")) != 0 or int(MetaProgress.get_upgrade_level("echo_vitality")) != 0:
		_fail("meta reset did not persist clean zero state")
		return false

	print("R7_META roundtrip_shards=%d earned=%d reset_ok=true" % [saved_shards, earned])
	return true


func _test_ember_well_delayed_burst() -> bool:
	var hero: Node = squad_manager.get_member_by_id("pulse_artificer")
	if hero == null:
		_fail("pulse artificer missing for ember well delayed burst test")
		return false
	var weapon := _weapon_node(hero, "pulse_bloom")
	if weapon == null:
		_fail("pulse bloom missing for ember well delayed burst test")
		return false
	var weapon_data: Resource = weapon.get("data")
	if weapon_data == null or not weapon_data.has_method("has_modifier") or not weapon_data.has_modifier("evo_ember_well"):
		_fail("ember well evolution missing before delayed burst test")
		return false
	var effect_stats: Dictionary = weapon._effect_stats_for_fire()
	var delayed_stats: Dictionary = weapon._make_ember_well_delayed_explosion_stats(effect_stats)
	if not is_equal_approx(float(delayed_stats.get("damage", 0.0)), float(effect_stats.get("damage", 0.0)) * 0.55):
		_fail("ember well delayed burst damage coefficient mismatch")
		return false
	if float(delayed_stats.get("area_radius", 0.0)) <= 0.0:
		_fail("ember well delayed burst missing radius")
		return false

	_release_active_enemies()
	var enemy := EntityFactory.spawn_enemy("r7_ember_target", _regular_config(), leader.global_position + Vector2(48.0, 0.0))
	if enemy == null:
		_fail("ember delayed burst target spawn failed")
		return false
	var hp_before: float = float(enemy.get("hp"))
	EntityFactory.spawn_delayed_explosion(enemy.global_position, delayed_stats, leader, 0.02)
	await get_tree().create_timer(0.08).timeout
	if float(enemy.get("hp")) >= hp_before:
		_fail("ember delayed burst did not apply explosion damage")
		return false
	var hp_after: float = float(enemy.get("hp"))
	_release_active_enemies()
	print("R7_EMBER_WELL_DELAYED_BURST damage=%.2f hp %.2f->%.2f" % [
		float(delayed_stats.get("damage", 0.0)),
		hp_before,
		hp_after
	])
	return true


func _test_echo_delta_victory_continue_death() -> bool:
	MetaProgress.debug_use_save_path("user://r7_meta_test.cfg", true)
	_prepare_run_state()
	GameManager.player = leader
	GameManager.elapsed_time = 210.0
	GameManager.kills = 120
	GameManager.gold = 60
	GameManager.gold_earned = 80
	GameManager.level = 8
	GameManager.elites_killed = 2
	GameManager.boss_killed = false
	var victory_expected := MetaProgress.calculate_run_shards(_echo_summary(true))
	GameManager.record_boss_kill()
	var first_award := int(GameManager.get("echo_shards_awarded_this_run"))
	if first_award != victory_expected:
		_fail("victory echo award mismatch")
		return false
	GameManager.continue_after_stage_victory()
	GameManager.player = leader
	GameManager.game_running = true
	GameManager.elapsed_time = 260.0
	GameManager.kills += 40
	GameManager.gold += 50
	GameManager.gold_earned += 50
	GameManager.level = 10
	GameManager.elites_killed += 1
	var final_expected := MetaProgress.calculate_run_shards(_echo_summary(true))
	GameManager.player_died()
	var final_award := int(GameManager.get("echo_shards_awarded_this_run"))
	if final_award != final_expected:
		_fail("victory-continue-death echo total double-counted or missed delta")
		return false
	if int(MetaProgress.get("shards")) != final_expected:
		_fail("meta shard balance did not equal final delta total")
		return false
	if final_award - first_award != final_expected - victory_expected:
		_fail("death echo award was not only the post-victory delta")
		return false

	print("R7_ECHO_DELTA victory=%d final=%d death_delta=%d" % [
		first_award,
		final_award,
		final_award - first_award
	])
	return true


func _find_upgrade_option(upgrade_kind: String) -> Dictionary:
	var pool: Array = squad_manager.build_upgrade_pool([])
	for option in pool:
		if str(option.get("upgrade_kind", "")) == upgrade_kind:
			return option
	return {}


func _find_numeric_option(hero_id: String, weapon_id: String, upgrade_kind: String) -> Dictionary:
	var pool: Array = squad_manager.build_upgrade_pool([])
	for option in pool:
		if str(option.get("hero_id", "")) != hero_id:
			continue
		if str(option.get("weapon_id", "")) != weapon_id:
			continue
		if str(option.get("upgrade_kind", "")) == upgrade_kind:
			return option
	return {}


func _echo_summary(boss_value: bool) -> Dictionary:
	return {
		"elapsed_time": GameManager.elapsed_time,
		"kills": GameManager.kills,
		"gold": GameManager.gold,
		"gold_earned": GameManager.gold_earned,
		"level": GameManager.level,
		"elites_killed": GameManager.elites_killed,
		"boss_killed": boss_value,
		"contract_name": GameManager.active_contract_name
	}


func _record_contract_selection(contract: Dictionary) -> void:
	test_selected_contract_id = str(contract.get("id", ""))


func _weapon_node(hero: Node, weapon_id: String) -> Node:
	var weapons: Dictionary = hero.get("weapons")
	return weapons.get(weapon_id)


func _first_live_elite() -> Node:
	var live_enemies: Array = EntityFactory.get("enemy_spatial_index").get("live_enemies")
	for enemy in live_enemies:
		if enemy != null and is_instance_valid(enemy) and bool(enemy.get("is_active")) and bool(enemy.get("is_elite")):
			return enemy
	return null


func _count_active_type(type_id: String) -> int:
	var count := 0
	var live_enemies: Array = EntityFactory.get("enemy_spatial_index").get("live_enemies")
	for enemy in live_enemies:
		if enemy != null and is_instance_valid(enemy) and bool(enemy.get("is_active")) and str(enemy.get("type_id")) == type_id:
			count += 1
	return count


func _release_active_enemies() -> void:
	var live_enemies: Array = EntityFactory.get("enemy_spatial_index").get("live_enemies")
	for enemy in live_enemies.duplicate():
		if enemy != null and is_instance_valid(enemy):
			EntityFactory.release_enemy(enemy)


func _regular_config() -> Dictionary:
	return {
		"max_hp": 30.0,
		"speed": 0.0,
		"damage": 0.0,
		"xp": 0,
		"gold": 0,
		"radius": 13.0,
		"color": Color(0.55, 0.78, 1.0),
		"sprite_path": "res://assets/sprites/enemy_grunt.png",
		"sprite_scale": 1.0,
		"attack_cooldown": 99.0
	}


func _fail(message: String) -> void:
	printerr("R7_REGRESSION_FAIL: " + message)
	get_tree().quit(1)
