extends Node

const LOOT := preload("res://scripts/services/loot_director.gd")
const CATALOG := preload("res://scripts/services/equipment_catalog.gd")
const PREVIEW := preload("res://scripts/services/upgrade_preview.gd")
const LEVEL_SCREEN := preload("res://scripts/ui/level_up_screen.gd")
const PANEL := preload("res://scripts/ui/equipment_panel.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")

class TestHero extends Node2D:
	var is_alive := true
	var hero_id := "test"
	var max_hp := 100.0
	var current_hp := 70.0
	var move_speed := 200.0
	var pickup_radius := 92.0
	var weapons: Dictionary = {}
	func get_pickup_radius() -> float:
		return pickup_radius
	func get_current_hp() -> float:
		return current_hp
	func get_max_hp() -> float:
		return max_hp

class TestWeapon extends Node:
	var data: Resource

class TestSquad extends Node:
	var members: Array = []
	func get_members() -> Array:
		return members
	func get_member_count() -> int:
		return members.size()
	func get_member_by_id(hero_id: String) -> Node:
		for member in members:
			if member.hero_id == hero_id:
				return member
		return null

var errors: Array[String] = []
var test_arena: Node2D
var director: Node
var hero: TestHero
var squad: TestSquad


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_tests")


func _run_tests() -> void:
	GameManager.game_running = true
	GameManager.system_pause_owners.clear()
	get_tree().paused = false
	test_arena = Node2D.new()
	add_child(test_arena)
	director = LOOT.new()
	test_arena.add_child(director)
	hero = TestHero.new()
	test_arena.add_child(hero)
	squad = TestSquad.new()
	squad.members = [hero]
	add_child(squad)
	GameManager.player = hero
	GameManager.squad_manager = squad
	GameManager.arena = test_arena
	GameManager.level = 1
	GameManager.loot_director = director
	EntityFactory.initialize_for_arena(test_arena)
	director.setup(test_arena, 32768)
	_test_drop_pity_and_rng()
	_test_monotonic_equipment()
	_test_equipment_deltas()
	await _test_world_pickup_and_boss()
	await _test_live_upgrade_preview()
	await _test_mobile_readability()
	GameManager.player = null
	GameManager.squad_manager = null
	GameManager.arena = null
	GameManager.loot_director = null
	MOBILE_TUNING.set_device_hints_override_for_tests()
	if errors.is_empty():
		print("R32_LOOT_PASS seeds=500 first_drop<=12 max_dry_gap<=28 rng=isolated slots=3 rare_pity=4 elite>=rare boss=legendary duplicate=safe delta=idempotent recruit=synced physical=magnet upgrade=live_readonly layouts=3")
		get_tree().quit(0)
	else:
		for error in errors:
			push_error(error)
		get_tree().quit(1)


func _test_drop_pity_and_rng() -> void:
	var max_first := 0
	var max_gap := 0
	var total_drops := 0
	for run_seed in range(1, 501):
		director.reset_run(run_seed)
		var gap := 0
		var common_run := 0
		var opening_slots: Dictionary = {}
		for kill_index in range(300):
			gap += 1
			var item: Dictionary = director.roll_drop(false, false, 1)
			if item.is_empty():
				continue
			if director.drop_count == 1:
				max_first = maxi(max_first, gap)
			max_gap = maxi(max_gap, gap)
			_assert(gap <= (12 if director.drop_count == 1 else 28), "dry run exceeded pity at seed %d kill %d" % [run_seed, kill_index])
			gap = 0
			common_run = common_run + 1 if int(item.rarity) == 0 else 0
			_assert(common_run <= 3, "rarity pity failed")
			if director.drop_count <= 3:
				opening_slots[str(item.slot)] = true
				if director.drop_count == 3:
					_assert(opening_slots.size() == 3, "opening three drops did not fill all slots")
			total_drops += 1
		_assert(director.drop_count > 0, "seed had no drops")
		_assert(gap < 28, "tail dry interval exceeded pity")
		for elite_index in range(4):
			_assert(int(director.roll_drop(true, false, 1).rarity) >= 1, "elite did not guarantee rare")
		_assert(int(director.roll_drop(false, true, 1).rarity) == 3, "boss did not guarantee legendary")
	var first_sequence := _sequence(191919)
	var second_sequence := _sequence(191919)
	_assert(first_sequence == second_sequence, "loot stream is not repeatable with same seed")
	seed(9381)
	var expected := randf()
	seed(9381)
	director.reset_run(91)
	for index in range(30):
		director.roll_drop(true, false, 1)
	_assert(randf() == expected, "loot consumed encounter global RNG")
	print("R32_LOOT_PITY seeds=500 regular_kills=150000 drops=%d max_first=%d max_gap=%d" % [total_drops, max_first, max_gap])


func _sequence(run_seed: int) -> Array:
	director.reset_run(run_seed)
	var sequence: Array = []
	for index in range(200):
		var item: Dictionary = director.roll_drop(false, false, 2)
		if not item.is_empty():
			sequence.append([index, item.slot, item.rarity, item.power])
	return sequence


func _test_monotonic_equipment() -> void:
	for slot in CATALOG.SLOTS:
		var items: Array[Dictionary] = []
		for rarity in range(4):
			for item_level in range(1, 21):
				items.append(CATALOG.make_item(slot, rarity, item_level, 1))
		for stronger in items:
			for weaker in items:
				if float(stronger.power) <= float(weaker.power) + 0.001:
					continue
				for key in stronger.bonuses:
					_assert(float(stronger.bonuses[key]) + 0.001 >= float(weaker.bonuses[key]), "auto-equip would reduce %s on %s" % [str(key), slot])
	print("R32_EQUIPMENT_MONOTONIC slots=3 levels=20 rarities=4 stronger_items_never_reduce_any_stat=true")


func _make_item(slot: String, rarity: int, item_level: int, uid: int) -> Dictionary:
	var item := CATALOG.make_item(slot, rarity, item_level, uid)
	item["generation"] = director.run_generation
	return item


func _test_equipment_deltas() -> void:
	director.reset_run(100)
	var guard := _make_item("guard", 1, 1, 5001)
	_assert(director.collect_item(guard), "rare armor failed to equip")
	_assert(is_equal_approx(hero.max_hp, 124) and is_equal_approx(hero.current_hp, 94), "armor did not add max HP and heal its added capacity")
	hero.max_hp += 20
	hero.current_hp += 20
	director.apply_member_bonuses(hero)
	_assert(is_equal_approx(hero.max_hp, 144), "equipment sync erased a personal level upgrade")
	var better := _make_item("guard", 2, 1, 5002)
	_assert(director.collect_item(better), "stronger armor was not equipped")
	_assert(is_equal_approx(hero.max_hp, 156) and is_equal_approx(hero.current_hp, 126), "replacement stacked full bonus instead of delta")
	var before_gold := GameManager.gold
	_assert(not director.collect_item(guard), "duplicate item was re-claimed")
	_assert(GameManager.gold == before_gold and director.collected_count == 2, "duplicate produced rewards")
	var weaker := _make_item("guard", 0, 1, 5003)
	_assert(not director.collect_item(weaker), "weaker equipment replaced stronger item")
	_assert(GameManager.gold == before_gold + int(weaker.salvage_gold), "weaker equipment did not salvage to gold")
	var boots := _make_item("boots", 1, 1, 5004)
	director.collect_item(boots)
	_assert(is_equal_approx(hero.move_speed, 220) and is_equal_approx(hero.pickup_radius, 116), "boots had no movement/pickup effect")
	var core := _make_item("core", 1, 1, 5005)
	director.collect_item(core)
	_assert(GameManager.get_outgoing_damage_multiplier(hero) >= 1.12, "equipped core did not reach actual damage calculation")
	_assert(GameManager.get_fire_rate_multiplier(hero) >= 1.04, "equipped core did not reach actual fire-rate calculation")
	_assert(GameManager.get_incoming_damage_multiplier(hero) >= GameManager.DAMAGE_TAKEN_SOFT_CAP_MIN and GameManager.get_incoming_damage_multiplier(hero) < 1.0, "armor bypassed global reduction cap or had no effect")
	_assert(GameManager.get_stats().get("equipment_slots", []).size() == 3, "runtime stats omitted equipment")
	var recruit := TestHero.new()
	test_arena.add_child(recruit)
	director.apply_member_bonuses(recruit)
	director.apply_member_bonuses(recruit)
	_assert(is_equal_approx(recruit.max_hp, 136) and is_equal_approx(recruit.move_speed, 220), "new recruit equipment inheritance missing or stacked")
	recruit.queue_free()
	director.reset_run(101)
	_assert(is_equal_approx(hero.max_hp, 120) and is_equal_approx(hero.move_speed, 200) and is_equal_approx(hero.pickup_radius, 92), "new run retained old gear bonuses or removed level upgrades")
	print("R32_EQUIPMENT_DELTA hp=100+20+36 movement=200+20 duplicate_safe=true salvage_gold=true recruit_once=true reset_restores=true")


func _test_world_pickup_and_boss() -> void:
	director.reset_run(3434)
	hero.global_position = Vector2.ZERO
	var item: Dictionary = director.on_enemy_defeated(Vector2(75, 0), true, false, "elite_test")
	_assert(not item.is_empty(), "elite physical drop was empty")
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(get_tree().get_nodes_in_group("equipment_drops").size() == 1, "physical loot did not spawn")
	await get_tree().create_timer(0.9).timeout
	_assert(director.collected_count == 1 and get_tree().get_nodes_in_group("equipment_drops").is_empty(), "physical loot did not magnetize and equip")
	director.on_enemy_defeated(Vector2(1000, 0), true, false, "far_elite")
	await get_tree().process_frame
	var boss: Dictionary = director.on_enemy_defeated(Vector2(1100, 0), false, true, "boss_test")
	_assert(int(boss.rarity) == 3, "boss reward is not legendary")
	_assert(director.collected_count == 3, "boss clear stranded existing gear or did not claim legendary")
	await get_tree().process_frame
	_assert(get_tree().get_nodes_in_group("equipment_drops").is_empty(), "boss clear left invisible unclaimable world gear")
	print("R32_LOOT_PHYSICAL visible_drop=1 magnetic_collection=1 boss_claimed=3 world_remaining=0")


func _test_live_upgrade_preview() -> void:
	var weapon := TestWeapon.new()
	weapon.data = load("res://resources/weapons/riftline_emitter.tres").make_runtime_copy()
	hero.add_child(weapon)
	hero.weapons["riftline_emitter"] = weapon
	var option := {"id": "upgrade_hero_weapon", "hero_id": "test", "weapon_id": "riftline_emitter", "upgrade_kind": "weapon_damage", "max_level": 5, "name": "增幅", "description": "+4 傷害"}
	var before := float(weapon.data.damage)
	var projectiles_before := int(weapon.data.projectile_count)
	var text := PREVIEW.describe(option)
	_assert(text.contains("基礎傷害") and text.contains("→") and text.contains("進化："), "upgrade card lacks stat/evolution progress")
	_assert(is_equal_approx(float(weapon.data.damage), before) and weapon.data.modifier_levels.is_empty(), "preview changed the live weapon")
	option["upgrade_kind"] = "weapon_projectiles"
	text = PREVIEW.describe(option)
	_assert(text.contains("數量") and text.contains("穿透"), "projectile card does not show count/pierce change")
	_assert(int(weapon.data.projectile_count) == projectiles_before and weapon.data.modifier_levels.is_empty(), "projectile preview mutated data")
	_assert(PREVIEW.benefit_text({"id": "move_speed"}).contains("200 → 220") or PREVIEW.benefit_text({"id": "move_speed"}).contains("→"), "personal upgrade does not read current stats")
	print("R32_UPGRADE_PREVIEW readonly=true numeric_before_after=true evolution_requirements=true projectile_pierce=true")


func _test_mobile_readability() -> void:
	for viewport_size in [Vector2i(1280, 720), Vector2i(844, 390), Vector2i(390, 844)]:
		MOBILE_TUNING.set_device_hints_override_for_tests({"mobile_os": false, "ua_mobile": viewport_size.x < 1000, "ua_phone": viewport_size.x < 1000, "ua_tablet": false, "touch_available": viewport_size.x < 1000, "primary_coarse": viewport_size.x < 1000, "mouse_available": viewport_size.x >= 1000})
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var screen := LEVEL_SCREEN.new()
		viewport.add_child(screen)
		await get_tree().process_frame
		screen.show_options([{"id": "move_speed", "name": "疾步校準", "description": "+20 移動速度", "max_level": 6}, {"id": "max_hp", "name": "裂隙護甲", "description": "+20 最大 HP，並回復 20 HP", "max_level": 5}, {"id": "pickup_radius", "name": "回收磁場", "description": "+24 拾取範圍", "max_level": 5}])
		await get_tree().process_frame
		await get_tree().process_frame
		var top: Rect2 = screen.progress_label.get_global_rect()
		var scroll: Rect2 = screen.card_scroll.get_global_rect()
		_assert(top.end.y <= scroll.position.y + 0.75, "run progress overlaps cards at %s" % str(viewport_size))
		_assert(scroll.position.x >= -0.75 and scroll.end.x <= viewport_size.x + 0.75 and scroll.position.y >= -0.75 and scroll.end.y <= viewport_size.y + 0.75, "level scroll escapes viewport at %s" % str(viewport_size))
		for button in screen.option_buttons:
			var label: Label = button.get_node("CardDescription")
			var available := button.custom_minimum_size.y - label.offset_top - 14.0
			_assert(float(label.get_line_count()) * float(label.get_line_height()) <= available + 3.0, "stat preview is clipped at %s: need=%d available=%.1f" % [str(viewport_size), label.get_line_count() * label.get_line_height(), available])
		var recruits: Array = []
		for hero_id in ["orbit_guard", "echo_singer", "ember_grenadier"]:
			var hero_data: Resource = load("res://resources/heroes/%s.tres" % hero_id)
			recruits.append({"id": "recruit_hero", "hero_id": hero_id, "name": "招募：" + str(hero_data.get("display_name")), "description": "「%s」\n%s" % [str(hero_data.get("quote")), str(hero_data.get("description"))]})
		screen.show_options(recruits)
		for frame in range(4):
			await get_tree().process_frame
		for button in screen.option_buttons:
			var description: Label = button.get_node("CardDescription")
			_assert(description.get_global_rect().end.y + 12.0 <= button.get_global_rect().end.y + 1.0, "recruit text extends beyond visible card at %s" % str(viewport_size))
			_assert(not description.text.begins_with("「") and description.text.contains("隊伍人數") and description.text.contains("同場："), "recruit lost gameplay role/bond while compressing flavor")
		var equipment := PANEL.new()
		viewport.add_child(equipment)
		equipment.configure(director)
		equipment.position = Vector2(20, viewport_size.y - 50)
		equipment.size = Vector2(340, 36)
		equipment.update_from_stats(director.get_stats())
		equipment._inspect_slot(0)
		await get_tree().process_frame
		_assert(equipment.details.position.y < 0, "bottom equipment panel expanded outside viewport")
		_assert(equipment.buttons.size() == 3, "equipment slots are not reachable")
		var current_style: StyleBox = equipment.buttons[0].get_theme_stylebox("normal")
		equipment.update_from_stats(director.get_stats())
		_assert(equipment.buttons[0].get_theme_stylebox("normal") == current_style, "unchanged 10 Hz stats rebuild equipment styles")
		equipment.update_from_stats({"game_running": true, "manual_pause_visible": true})
		_assert(not equipment.visible and not equipment.details.visible, "equipment intercepts manual pause modal")
		print("R32_LOOT_UI viewport=%s progress=%s scroll=%s" % [str(viewport_size), str(top), str(scroll)])
		viewport.queue_free()
		await get_tree().process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
