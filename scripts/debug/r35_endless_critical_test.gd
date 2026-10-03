extends Node

# Controlled integration fixture. This is intentionally separate from natural
# keyboard/touch playtests, and redirects all four persistence routes.
const CATALOG := preload("res://scripts/services/stage_catalog.gd")
const CRITICAL := preload("res://scripts/services/critical_strike_resolver.gd")
const WORLD_MAP := "res://scenes/ui/WorldMap.tscn"
const ARENA := "res://scenes/arena/Arena.tscn"
const SAVE_PREFIX := "user://r35_endless_critical_"

var failed := false
var finished := false
var phase := "boot"
var deadline := 0
var impact_events := 0
var impact_frame := -1
var observed_visual: Node


func _ready() -> void:
	if not bool(get_meta("persistent_runner", false)):
		call_deferred("_install_runner")
		return
	process_mode = PROCESS_MODE_ALWAYS
	deadline = Time.get_ticks_msec() + 35000
	call_deferred("_run")


func _install_runner() -> void:
	var runner: Node = get_script().new()
	runner.name = "R35EndlessCriticalPersistentRunner"
	runner.set_meta("persistent_runner", true)
	get_tree().root.add_child(runner)


func _process(_delta: float) -> void:
	if bool(get_meta("persistent_runner", false)) and not finished and not failed and Time.get_ticks_msec() >= deadline:
		_fail("35s watchdog expired")


func _run() -> void:
	phase = "isolate_saves_and_rng"
	GameManager.campaign_save_path = SAVE_PREFIX + "campaign.cfg"
	GameManager.campaign_clears.clear()
	GameManager.endless_best.clear()
	GameManager.run_mode = "campaign"
	GameManager.selected_stage_id = "moon"
	var blank := ConfigFile.new()
	blank.set_value("campaign", "clears", [])
	blank.set_value("campaign", "endless_best", {})
	if not _check(blank.save(GameManager.campaign_save_path) == OK, "isolated campaign save failed"):
		return
	MetaProgress.debug_use_save_path(SAVE_PREFIX + "meta.cfg", true)
	PlayerSettings.debug_use_save_path(SAVE_PREFIX + "settings.cfg", true)
	AchievementProgress.debug_use_save_path(SAVE_PREFIX + "achievements.cfg", true)
	if not _test_resolver():
		return
	GameManager.return_to_world_map()
	var stages: Array[Dictionary] = CATALOG.get_stages()
	for index in range(stages.size()):
		phase = "locked_map_and_campaign_" + str(stages[index].id)
		var world: Node = await _wait_scene(WORLD_MAP)
		if world == null:
			return
		var buttons: Array = world.get("node_buttons")
		if not _check(buttons.size() == stages.size(), "six stage nodes missing"):
			return
		for node_index in range(stages.size()):
			(buttons[node_index] as Button).pressed.emit()
			var unlocked := node_index < index
			if not _check((world.get("endless_button") as Button).disabled != unlocked, "endless unlock does not match persisted boss clears"):
				return
			if not unlocked:
				var old_selection: String = GameManager.selected_stage_id
				var old_mode: String = GameManager.run_mode
				if not _check(not GameManager.start_endless_stage(str(stages[node_index].id)) and GameManager.selected_stage_id == old_selection and GameManager.run_mode == old_mode and get_tree().current_scene == world, "locked endless request mutated scene/mode/selection"):
					return
		(buttons[index] as Button).pressed.emit()
		(world.get("start_button") as Button).pressed.emit()
		var arena: Node = await _wait_scene(ARENA)
		if arena == null:
			return
		_freeze(arena)
		var spawner: Node = arena.get_node("EnemySpawner")
		var boss: Node = _scheduled_boss(spawner, float(stages[index].boss_time))
		if boss == null or not await _kill_boss(boss, true):
			return
		if not _check(GameManager.campaign_clears.size() == index + 1 and GameManager.campaign_clears.has(str(stages[index].id)), "real boss death did not award exact clear"):
			return
		if index == 0:
			phase = "continue_preserves_run"
			GameManager.level = 7
			var old_seed: int = GameManager.current_run_seed
			var old_time: float = GameManager.elapsed_time
			var old_kills: int = GameManager.kills
			var loot: Node = arena.get_node("LootDirector")
			var old_slots: Dictionary = (loot.get("slots") as Dictionary).duplicate(true)
			var victory: Node = arena.get_node("StageVictoryScreen")
			(victory.get("continue_button") as Button).pressed.emit()
			if not _check(GameManager.run_mode == "endless" and GameManager.level == 7 and GameManager.current_run_seed == old_seed and loot.get("slots") == old_slots and not GameManager.stage_victory_pending and not get_tree().paused and GameManager.game_running and is_equal_approx(float(spawner.get("next_endless_boss_time")), GameManager.elapsed_time + 120.0), "continue button reset level/equipment/seed or retained victory pause"):
				return
			if not _check(GameManager.get_endless_wave() == 1 and is_equal_approx(GameManager.endless_start_time, old_time) and GameManager.endless_start_kills == old_kills and is_zero_approx(float(GameManager.get_stats().endless_seconds)) and int(GameManager.get_stats().endless_kills) == 0, "continue included campaign time/kills in endless wave/best baseline"):
				return
			GameManager.elapsed_time = old_time + 30.0
			if not _check(GameManager.get_endless_wave() == 2 and is_equal_approx(float(GameManager.get_stats().endless_seconds), 30.0) and int(GameManager.get_stats().endless_kills) == 0, "continued endless did not measure wave from its own start clock"):
				return
			print("R35_CONTINUE_RUN preserved_level=7 preserved_seed=true preserved_equipment=true own_clock_starts=0 own_kills_starts=0 next_boss_after=120s")
		print("R35_ENDLESS_UNLOCK true_boss_death=%s cleared=%d/6" % [str(stages[index].id), GameManager.campaign_clears.size()])
		GameManager.return_to_world_map()
	phase = "true_endless_button_scene_transition"
	var world: Node = await _wait_scene(WORLD_MAP)
	if world == null:
		return
	for button in world.get("node_buttons"):
		(button as Button).pressed.emit()
		if not _check(not (world.get("endless_button") as Button).disabled, "cleared stage endless remains disabled"):
			return
	(world.get("node_buttons")[0] as Button).pressed.emit()
	(world.get("endless_button") as Button).pressed.emit()
	var arena: Node = await _wait_scene(ARENA)
	if arena == null:
		return
	_freeze(arena)
	var spawner: Node = arena.get_node("EnemySpawner")
	if not _check(GameManager.run_mode == "endless" and GameManager.selected_stage_id == "moon" and GameManager.level == 1 and is_equal_approx(float(spawner.get("boss_time")), 120.0), "real endless button did not start a fresh selected Arena with 120s boss timer"):
		return
	if not _test_wave_scaling(spawner):
		return
	phase = "actual_critical_damage_and_pool_generation"
	if not await _test_enemy_critical_and_impact(arena):
		return
	phase = "scheduled_endless_bosses_120_240"
	GameManager.elapsed_time = 119.99
	spawner.call("_process", 0.001)
	if not _check(not GameManager.boss_active and not bool(spawner.get("boss_spawned")), "first endless boss spawned before 120s"):
		return
	for boss_time in [120.0, 240.0]:
		phase = "scheduled_endless_boss_%.0f" % boss_time
		var boss: Node = _scheduled_boss(spawner, boss_time)
		if boss == null:
			return
		var expected_hp := 1800.0 * (1.0 + 0.12 * float(GameManager.get_endless_wave() - 1))
		if not _check(is_equal_approx(float(boss.get("max_hp")), expected_hp), "endless boss HP did not scale by its true wave"):
			return
		if not await _kill_boss(boss, false):
			return
		if not _check(GameManager.game_running and not get_tree().paused and not GameManager.stage_victory_pending and GameManager.boss_kills_total == int(boss_time / 120.0), "endless boss death paused/ended the run or count did not increment"):
			return
		print("R35_ENDLESS_BOSS elapsed=%.0f wave=%d hp=%.0f true_death=true stage_victory=false game_running=true" % [boss_time, GameManager.get_endless_wave(), expected_hp])
	phase = "actual_defeat_and_best_save"
	if not await _defeat_and_check_save(arena, 9, GameManager.kills):
		return
	var best: Dictionary = GameManager.endless_best.moon.duplicate(true)
	GameManager.return_to_world_map()
	world = await _wait_scene(WORLD_MAP)
	(world.get("node_buttons")[0] as Button).pressed.emit()
	(world.get("endless_button") as Button).pressed.emit()
	arena = await _wait_scene(ARENA)
	if arena == null:
		return
	_freeze(arena)
	GameManager.elapsed_time = 30.0
	if not await _defeat_and_check_save(arena, int(best.wave), int(best.kills)):
		return
	print("R35_ENDLESS_BEST persisted=true lower_run_preserves_best=true saves_isolated=4")
	GameManager.return_to_world_map()
	world = await _wait_scene(WORLD_MAP)
	(world.get("node_buttons")[0] as Button).pressed.emit()
	(world.get("endless_button") as Button).pressed.emit()
	arena = await _wait_scene(ARENA)
	if arena == null:
		return
	_freeze(arena)
	phase = "final_fx_assets_and_release"
	if not await _test_fx_assets(arena):
		return
	finished = true
	print("R35_ENDLESS_CRITICAL_PASS controlled_fixture=true clears=6/6 true_endless_button=true bosses=120,240 continue_preserves_run=true wave_scaling=30s crit_rate=18% crit_damage=1.75 impact_frame=2 pool_hitserial_reset=true fx_assets_ready=true fx_release_clean=true saves_isolated=4")
	get_tree().quit(0)


func _test_resolver() -> bool:
	seed(781234)
	var expected_random := randi()
	seed(781234)
	var count := 0
	for generation in range(1, 257):
		for hit in range(1, 257):
			var first: Dictionary = CRITICAL.resolve(20.0, 922337, generation, hit)
			if not _check(first == CRITICAL.resolve(20.0, 922337, generation, hit), "critical resolver is not reproducible"):
				return false
			if first.critical:
				count += 1
			if not _check(is_equal_approx(float(first.damage), 35.0 if first.critical else 20.0), "resolver did not return exact 1.75x damage"):
				return false
	if not _check(randi() == expected_random, "resolver consumed the global random stream"):
		return false
	var rate := float(count) / 65536.0
	if not _check(absf(rate - 0.18) < 0.007, "critical observed rate is outside 18% sampling tolerance"):
		return false
	print("R35_CRIT_RESOLVER samples=65536 rate=%.5f multiplier=1.75 reproducible=true global_rng_unchanged=true minimum_damage=8" % rate)
	return true


func _test_wave_scaling(spawner: Node) -> bool:
	var last_hp := 0.0
	for time_value in [0.0, 29.99, 30.0, 59.99, 60.0, 90.0]:
		GameManager.elapsed_time = time_value
		var expected_wave := 1 + int(time_value / 30.0)
		var config: Dictionary = spawner.call("_config_for_spawn", "normal")
		var hp_value := float(config.max_hp)
		if not _check(GameManager.get_endless_wave() == expected_wave, "wave boundary did not advance every 30 seconds"):
			return false
		if time_value in [30.0, 60.0, 90.0] and not _check(hp_value > last_hp, "normal enemy HP did not increase at the 30s wave boundary"):
			return false
		last_hp = hp_value
		print("R35_ENDLESS_WAVE elapsed=%.2f wave=%d actual_config_hp=%.3f" % [time_value, expected_wave, hp_value])
	return true


func _test_enemy_critical_and_impact(arena: Node) -> bool:
	for existing in get_tree().get_nodes_in_group("enemies"):
		EntityFactory.release_enemy(existing)
	var config := {"max_hp": 10000.0, "damage": 0.0, "speed": 0.0, "xp": 0, "gold": 0, "radius": 13.0, "sprite_path": "res://assets/sprites/enemy_grunt.png"}
	var leader: Node = GameManager.player
	var enemy: Node = EntityFactory.spawn_enemy("r35_critical_target", config, leader.global_position + Vector2.RIGHT * 80.0)
	enemy.set_physics_process(false)
	var loot: Node = arena.get_node("LootDirector")
	var loot_rng: RandomNumberGenerator = loot.get("run_rng")
	var old_rng_state: int = loot_rng.state
	var observed_crits := 0
	var start_crits: int = GameManager.critical_hits
	for hit in range(1, 65):
		var expected: Dictionary = CRITICAL.resolve(20.0, GameManager.current_run_seed, int(enemy.get("spawn_token")), hit)
		var hp_before := float(enemy.get("hp"))
		var actual := float(enemy.call("take_damage", 20.0, leader.global_position))
		if not _check(is_equal_approx(actual, float(expected.damage)) and is_equal_approx(hp_before - float(enemy.get("hp")), actual) and bool(enemy.get("last_hit_critical")) == bool(expected.critical), "real enemy damage/returned amount/crit marker disagreed with resolver"):
			return false
		observed_crits += 1 if expected.critical else 0
	if not _check(observed_crits > 0 and GameManager.critical_hits == start_crits + observed_crits and loot_rng.state == old_rng_state, "real crit count mismatch or loot RNG consumed"):
		return false
	GameManager.game_running = false
	var count_before: int = GameManager.critical_hits
	if not _check(is_equal_approx(float(enemy.call("take_damage", 20.0, leader.global_position)), 20.0) and not bool(enemy.get("last_hit_critical")) and GameManager.critical_hits == count_before, "stopped run registered a critical hit"):
		return false
	GameManager.game_running = true
	var old_instance: int = enemy.get_instance_id()
	var old_token := int(enemy.get("spawn_token"))
	EntityFactory.release_enemy(enemy)
	enemy = EntityFactory.spawn_enemy("r35_critical_target", config, leader.global_position + Vector2.RIGHT * 80.0)
	enemy.set_physics_process(false)
	if not _check(enemy.get_instance_id() == old_instance and int(enemy.get("spawn_token")) != old_token and int(enemy.get("damage_hit_index")) == 0 and not bool(enemy.get("last_hit_critical")), "pooled same enemy retained hitserial/crit marker or generation"):
		return false
	var pulse_amount := 72.0 * GameManager.get_outgoing_damage_multiplier(leader)
	# Prepare the next actual hit to be critical, without bypassing take_damage.
	while not bool(CRITICAL.resolve(pulse_amount, GameManager.current_run_seed, int(enemy.get("spawn_token")), int(enemy.get("damage_hit_index")) + 1).critical):
		enemy.call("take_damage", 8.0, leader.global_position)
	var target_hp := float(enemy.get("hp"))
	observed_visual = leader.get("visual") as Node
	impact_events = 0
	impact_frame = -1
	observed_visual.connect("attack_impact", Callable(self, "_observe_impact"))
	if not _check(bool(leader.call("try_cast_active_ability")), "real articulated active attack did not start"):
		return false
	if not _check(is_equal_approx(float(enemy.get("hp")), target_hp) and impact_events == 0, "active attack damaged before its authored impact frame"):
		return false
	while impact_events == 0 and not failed:
		if int((observed_visual.get("animated_sprite") as AnimatedSprite2D).frame) < 2 and not _check(is_equal_approx(float(enemy.get("hp")), target_hp), "damage happened during anticipation"):
			return false
		await get_tree().process_frame
	if not _check(impact_events == 1 and impact_frame == 2 and bool(enemy.get("last_hit_critical")) and is_equal_approx(target_hp - float(enemy.get("hp")), pulse_amount * 1.75), "actual hero frame2 hit did not apply the critical multiplier"):
		return false
	print("R35_CRIT_REAL_DAMAGE hits=64 crits=%d exact_hp=true returned_damage=true loot_rng_unchanged=true pool_same_instance=true serial_reset=true true_hero_impact_frame=2" % observed_crits)
	EntityFactory.release_enemy(enemy)
	return true


func _observe_impact() -> void:
	impact_events += 1
	impact_frame = int((observed_visual.get("animated_sprite") as AnimatedSprite2D).frame)


func _scheduled_boss(spawner: Node, time_value: float) -> Node:
	GameManager.elapsed_time = time_value
	spawner.call("_process", 0.001)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		if enemy.get("is_boss") == true and enemy.get("is_dying") == false and enemy.get("is_active") == true:
			print("R35_SCHEDULED_BOSS elapsed=%.0f instance=%d token=%d hp=%.0f active=%s" % [time_value, enemy.get_instance_id(), int(enemy.get("spawn_token")), float(enemy.get("hp")), enemy.get("is_active")])
			return enemy
	_fail("real scheduled spawner did not create a boss at %.2f" % time_value)
	return null


func _kill_boss(boss: Node, campaign: bool) -> bool:
	var clears_before := GameManager.campaign_clears.size()
	boss.call("take_damage", 1000000.0, GameManager.player.global_position)
	if not _check(bool(boss.get("is_dying")) and str(boss.get("current_animation_name")) == "death" and GameManager.campaign_clears.size() == clears_before and not GameManager.boss_killed, "boss skipped true death animation or awarded clear before finalization"):
		return false
	var death_start := Time.get_ticks_msec()
	var debug_printed := false
	while not GameManager.boss_killed and not failed:
		# Boss XP may naturally reach the next level while its successor falls.
		# Accept through the real card button instead of suppressing XP/pause.
		_accept_pending_upgrade()
		if not debug_printed and Time.get_ticks_msec() - death_start > 2000:
			debug_printed = true
			print("R35_DEATH_WAIT active=%s dying=%s frame=%s sequence=%s hp=%s time_scale=%s game_running=%s paused=%s visible=%s registered=%s ef_processing=%s" % [boss.get("is_active"), boss.get("is_dying"), (boss.get("animated_sprite") as AnimatedSprite2D).frame, boss.get("animation_sequence_index"), boss.get("hp"), Engine.time_scale, GameManager.game_running, get_tree().paused, boss.get("visible"), EntityFactory.enemy_animation_client_slots.has(boss.get_instance_id()), EntityFactory.is_processing()])
		await get_tree().process_frame
	await get_tree().process_frame
	if not _check(GameManager.stage_victory_pending == campaign and get_tree().paused == campaign, "boss completion used the wrong campaign/endless pause path"):
		return false
	return true


func _defeat_and_check_save(arena: Node, expected_wave: int, expected_kills: int) -> bool:
	var leader: Node = GameManager.player
	leader.set("current_hp", 1.0)
	leader.set("temporary_shield_hp", 0.0)
	leader.set("invulnerability_timer", 0.0)
	if not _check(bool(leader.call("take_damage", 10000.0, leader.global_position + Vector2.RIGHT * 60.0)), "real lethal leader impact rejected"):
		return false
	while not GameManager.is_game_over and not failed:
		_accept_pending_upgrade()
		await get_tree().process_frame
	var saved := ConfigFile.new()
	if not _check(saved.load(GameManager.campaign_save_path) == OK, "endless defeat did not write isolated campaign save"):
		return false
	var best: Dictionary = saved.get_value("campaign", "endless_best", {})
	if not _check(best.has("moon") and int(best.moon.wave) == expected_wave and int(best.moon.kills) == expected_kills and not GameManager.game_running, "defeat failed to persist highest endless wave/kills"):
		return false
	if not _check((arena.get_node("GameOverScreen").get("root") as Control).visible, "true leader death did not show defeat screen"):
		return false
	return true


func _test_fx_assets(arena: Node) -> bool:
	var presentation: Node = get_tree().get_first_node_in_group("combat_presentation")
	if not _check(presentation != null, "new combat presentation service missing"):
		return false
	var state: Dictionary = presentation.call("get_debug_state")
	if not _check(bool(state.get("assets_ready", false)), "FX assets_ready=false; prototype/null fallback is not PASS"):
		return false
	var catalog: Variant = presentation.get("catalog")
	for kind in catalog.get_kind_ids():
		var frames: SpriteFrames = catalog.get_frames(kind)
		if not _check(frames != null and frames.get_frame_count(&"default") == 8, "FX kind does not contain eight actual frames: " + str(kind)):
			return false
		for index in range(8):
			var texture: AtlasTexture = frames.get_frame_texture(&"default", index) as AtlasTexture
			if not _check(texture != null and texture.atlas != null and texture.region.size == Vector2(256, 256), "FX frame is null/placeholder rather than authored atlas pixels"):
				return false
		if not _check(frames.get_animation_loop(&"default") == (kind == "cyclone"), "FX loop contract incorrect: " + str(kind)):
			return false
	var effect: Node = presentation.call("play_effect", "critical_impact", Vector2.ZERO, Vector2.RIGHT, 1.0)
	if not _check(effect != null and (effect.get("sprite") as AnimatedSprite2D).sprite_frames != null, "critical asset animation did not produce real SpriteFrames"):
		return false
	var channel_owner: Node = GameManager.player
	presentation.call("set_channel", channel_owner, true, channel_owner.global_position, Vector2.RIGHT, 1.0)
	if not _check(int(presentation.call("get_debug_state").channels) == 1, "real cyclone channel asset did not start"):
		return false
	var live_ids: Array[int] = []
	for slot in presentation.get("active"):
		live_ids.append(slot.get_instance_id())
	await get_tree().create_timer(0.11, true).timeout
	if not _check((effect.get("sprite") as AnimatedSprite2D).frame > 0, "actual critical animation never advanced from frame zero"):
		return false
	presentation.call("set_channel", channel_owner, false, channel_owner.global_position, Vector2.RIGHT, 1.0)
	await get_tree().create_timer(0.8, true).timeout
	state = presentation.call("get_debug_state")
	if not _check(int(state.channels) == 0 and int(state.active) == 0 and int(state.free) > 0, "released channel/crit VFX retained live objects"):
		return false
	var recycled: Node = presentation.call("play_effect", "critical_impact", Vector2.ZERO, Vector2.RIGHT, 1.0)
	if not _check(recycled != null and live_ids.has(recycled.get_instance_id()) and (recycled.get("sprite") as AnimatedSprite2D).frame == 0 and is_equal_approx((recycled as Node2D).modulate.a, 1.0), "VFX reuse instantiated new slot or retained frame/alpha"):
		return false
	await get_tree().create_timer(0.8, true).timeout
	state = presentation.call("get_debug_state")
	if not _check(int(state.active) == 0 and int(state.channels) == 0, "reused critical VFX leaked"):
		return false
	print("R35_FX_ASSETS assets_ready=true kinds=8 actual_frames=64 real_frame_progress=true cyclone_loop=true released_channel=0 live_effects=0 pool_reuse_same_instance=true")
	return true


func _freeze(arena: Node) -> void:
	GameManager.set_process(false)
	arena.get_node("EnemySpawner").set_process(false)
	for actor in get_tree().get_nodes_in_group("heroes"):
		actor.set_process(false)
		actor.set_physics_process(false)
		for child in actor.get_children():
			if child.is_in_group("hero_controllers"):
				child.set_process(false)
				child.set_physics_process(false)
		for weapon in (actor.get("weapons") as Dictionary).values():
			weapon.set_process(false)
			weapon.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.set_process(false)
		projectile.set_physics_process(false)


func _accept_pending_upgrade() -> void:
	if GameManager.waiting_for_upgrade and get_tree().paused:
		var level_screen: Node = GameManager.arena.get_node("LevelUpScreen")
		var cards: Array = level_screen.get("option_buttons")
		if not cards.is_empty():
			(cards[0] as Button).pressed.emit()


func _wait_scene(scene_path: String) -> Node:
	while not failed:
		var scene: Node = get_tree().current_scene
		if scene != null and scene.scene_file_path == scene_path:
			await get_tree().process_frame
			await get_tree().process_frame
			return scene
		await get_tree().process_frame
	return null


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
	return condition


func _fail(message: String) -> void:
	if failed or finished:
		return
	failed = true
	printerr("R35_ENDLESS_CRITICAL_FAIL phase=%s: %s" % [phase, message])
	get_tree().quit(1)
