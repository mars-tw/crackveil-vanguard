extends Node

const HUD := preload("res://scenes/ui/HUD.tscn")
const LOOT := preload("res://scripts/services/loot_director.gd")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const PHONE := {"ua_mobile": true, "ua_phone": true, "touch_available": true, "primary_coarse": true, "mouse_available": false}
const ARENA := preload("res://scenes/arena/Arena.tscn")
const CATALOG := preload("res://scripts/services/equipment_catalog.gd")

var failures: Array[String] = []
var victory_snapshot: Dictionary = {}

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	GameManager.game_running = true
	GameManager.is_game_over = false
	GameManager.manual_paused = false
	GameManager.system_pause_owners.clear()
	GameManager.player = null
	GameManager.squad_manager = null
	get_tree().paused = false
	await _check_layout(Vector2i(1280, 720), {})
	await _check_layout(Vector2i(844, 390), PHONE)
	await _check_layout(Vector2i(390, 844), PHONE)
	MOBILE.set_device_hints_override_for_tests()
	await _check_runtime_equipment_and_boss()
	for failure in failures:
		printerr("R32_INDEPENDENT_REVIEW_FAIL: " + failure)
	print("R32_INDEPENDENT_REVIEW_%s failures=%d" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _check_layout(viewport_size: Vector2i, hints: Dictionary) -> void:
	MOBILE.set_device_hints_override_for_tests(hints)
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	add_child(viewport)
	var world := Node2D.new()
	viewport.add_child(world)
	var loot := LOOT.new()
	world.add_child(loot)
	GameManager.loot_director = loot
	loot.setup(world, 324)
	var hud := HUD.instantiate()
	viewport.add_child(hud)
	hud.attach_equipment_panel(loot)
	hud.set_touch_controls_forced_visible(true)
	await get_tree().process_frame

	await get_tree().process_frame
	hud._on_stats_changed(GameManager.get_stats())
	var equipment: Control = hud.equipment_panel
	equipment.visible = true
	var gear_rect := equipment.get_global_rect()
	var joystick_rect: Rect2 = hud.virtual_joystick.get_global_rect()
	var readout: Node = hud.root.get_node("CombatReadout")
	readout.call("_refresh")
	var readout_rect: Rect2 = readout.panel.get_global_rect()
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport_size))
	if not bounds.encloses(gear_rect):
		failures.append("equipment escaped viewport at %s: %s" % [viewport_size, gear_rect])
	if not bounds.encloses(readout_rect):
		failures.append("combat readout escaped viewport at %s: %s" % [viewport_size, readout_rect])
	if not hints.is_empty():
		if gear_rect.intersects(joystick_rect):
			failures.append("equipment overlaps joystick touch region at %s gear=%s joystick=%s" % [viewport_size, gear_rect, joystick_rect])
		if hud.quick_controls.visible:
			failures.append("mobile quick controls reappeared after stats_changed at %s" % viewport_size)
	var styles: Array[int] = []
	for button in equipment.buttons:
		styles.append(button.get_theme_stylebox("normal").get_instance_id())
	for index in range(20):
		equipment.update_from_stats(loot.get_stats())
	for index in range(equipment.buttons.size()):
		if equipment.buttons[index].get_theme_stylebox("normal").get_instance_id() != styles[index]:
			failures.append("unchanged equipment stats recreated button style at %s" % viewport_size)
	hud._on_toast_requested("取得裝備：史詩 · 虛界護甲\n全隊最大 HP +36\n受傷減少 4.5%（總減傷上限 15%）")
	await get_tree().process_frame
	await get_tree().process_frame
	var label: Label = hud.toast_label
	var text_height := float(label.get_line_count() * label.get_line_height())
	if text_height > label.size.y + 1.0:
		failures.append("equipment toast text clips at %s font=%d need=%.1f available=%.1f lines=%d" % [viewport_size, label.get_theme_font_size("font_size"), text_height, label.size.y, label.get_line_count()])
	print("R32_REVIEW_LAYOUT viewport=%s gear=%s joystick=%s combat=%s toast_font=%d toast_need=%.1f toast_height=%.1f cached_styles=true" % [viewport_size, gear_rect, joystick_rect, readout_rect, label.get_theme_font_size("font_size"), text_height, label.size.y])
	GameManager.loot_director = null
	viewport.queue_free()
	await get_tree().process_frame

func _check_runtime_equipment_and_boss() -> void:
	PlayerSettings.debug_use_save_path("user://r32_independent_player_test.cfg", true)
	MetaProgress.debug_use_save_path("user://r32_independent_meta_test.cfg", true)
	AchievementProgress.debug_use_save_path("user://r32_independent_achievement_test.cfg", true)
	MetaProgress.upgrades["echo_vitality"] = 5
	var starting_meta_multiplier := MetaProgress.get_max_hp_multiplier()
	GameManager.forced_run_seed = 32002
	var arena := ARENA.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.system_pause_owners.clear()
	GameManager.waiting_for_contract = false
	get_tree().paused = false
	arena.get_node("EnemySpawner").set_process(false)
	var hero: Node = GameManager.player
	hero.set_physics_process(false)
	var loot: Node = arena.get_node("LootDirector")
	var original_hp := float(hero.get("max_hp"))
	var original_speed := float(hero.get("move_speed"))
	var original_pickup := float(hero.get("pickup_radius"))
	for index in range(CATALOG.SLOTS.size()):
		var item := CATALOG.make_item(CATALOG.SLOTS[index], 2, 3, 9001 + index)
		item["generation"] = loot.run_generation
		loot.collect_item(item)
	var equipped_hp := float(hero.get("max_hp"))
	GameManager.apply_current_meta_progress_to_member(hero)
	GameManager.apply_current_meta_progress_to_member(hero)
	if not is_equal_approx(float(hero.get("max_hp")), equipped_hp):
		failures.append("repeated GM meta/equipment refresh stacked or lost armor bonus")
	var squad: Node = GameManager.squad_manager
	if not squad.recruit_hero("ember_grenadier"):
		failures.append("real recruit failed during equipment integration test")
	var recruit: Node = squad.get_member_by_id("ember_grenadier")
	var recruit_hp := float(recruit.get("max_hp"))
	var base_recruit_hp := float(recruit.get("hero_data").get("max_hp"))
	var expected_bonus := float(loot.bonuses["max_hp"])
	GameManager.apply_current_meta_progress_to_member(recruit)
	if not is_equal_approx(recruit_hp, base_recruit_hp * starting_meta_multiplier + expected_bonus) or not is_equal_approx(float(recruit.get("max_hp")), recruit_hp):
		failures.append("real recruit did not inherit exactly one armor bonus")
	var count := _grade_count(arena)
	if count != 1:
		failures.append("real arena has %d CanvasModulate owners" % count)
	var frames: SpriteFrames = hero.get("visual").get("animated_sprite").sprite_frames
	if frames.get_frame_count(&"attack") != 6 or frames.get_frame_count(&"walk") != 8:
		failures.append("silhouette material changed the articulated pose pipeline")
	GameManager.stage_victory_requested.connect(_capture_victory)
	loot.on_enemy_defeated(Vector2(1100.0, 0.0), true, false, "review_far_elite")
	var boss: Node = EntityFactory.spawn_enemy("review_boss", {"is_boss": true, "behavior_id": "boss", "sprite_path": "res://assets/sprites/enemy_boss.png", "max_hp": 1000.0, "xp": 0, "gold": 0}, Vector2(400.0, 0.0))
	boss.set_physics_process(false)
	GameManager.boss_active = true
	GameManager.record_boss_spawn()
	boss.take_damage(9999.0, Vector2.ZERO)
	await get_tree().create_timer(0.9, true, false, true).timeout
	var legendary_count := 0
	for item in victory_snapshot.get("equipment_slots", []):
		if int(item.get("rarity", -1)) == 3:
			legendary_count += 1
	if victory_snapshot.is_empty() or int(victory_snapshot.get("equipment_collected", 0)) != 5 or legendary_count < 1:
		failures.append("boss victory summary preceded guaranteed legendary and pending loot claim: collected=%s legendary=%d" % [victory_snapshot.get("equipment_collected", -1), legendary_count])
	if not loot.pending_items.is_empty():
		failures.append("boss victory left pending equipment beneath paused modal")
	var expected_reset_hp := original_hp / starting_meta_multiplier + float(loot.bonuses["max_hp"])
	MetaProgress.reset_progress()
	GameManager.apply_current_meta_progress_to_squad()
	var actual_reset_hp := float(hero.get("max_hp"))
	if not is_equal_approx(actual_reset_hp, expected_reset_hp):
		failures.append("pause meta reset scaled flat armor bonus: actual_hp=%.3f expected_hp=%.3f gear_bonus=%.3f" % [actual_reset_hp, expected_reset_hp, float(loot.bonuses["max_hp"])])
	print("R32_REVIEW_META_RESET actual_hp=%.3f expected_hp=%.3f starting_multiplier=%.2f flat_armor=%.3f" % [actual_reset_hp, expected_reset_hp, starting_meta_multiplier, float(loot.bonuses["max_hp"])])
	hero.set("move_speed", float(hero.get("move_speed")) + 20.0)
	loot.reset_run(321)
	if not is_equal_approx(float(hero.get("max_hp")), original_hp / starting_meta_multiplier) or not is_equal_approx(float(hero.get("move_speed")), original_speed + 20.0) or not is_equal_approx(float(hero.get("pickup_radius")), original_pickup):
		failures.append("equipment reset lost personal upgrade or retained gear bonus")
	print("R32_REVIEW_RUNTIME grade_owners=%d real_recruit=once meta_refresh=idempotent boss_summary_collected=%d legendary=%d pending=%d reset_preserves_upgrade=true articulated=8/6" % [count, int(victory_snapshot.get("equipment_collected", -1)), legendary_count, loot.pending_items.size()])
	GameManager.stage_victory_requested.disconnect(_capture_victory)
	get_tree().paused = false
	GameManager.system_pause_owners.clear()
	GameManager.game_running = false
	arena.queue_free()
	await get_tree().process_frame

func _capture_victory(summary: Dictionary) -> void:
	victory_snapshot = summary.duplicate(true)

func _grade_count(node: Node) -> int:
	var count := 1 if node is CanvasModulate else 0
	for child in node.get_children():
		count += _grade_count(child)
	return count
