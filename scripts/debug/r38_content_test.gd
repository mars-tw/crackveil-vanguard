extends Node

const STAGES := preload("res://scripts/services/stage_catalog.gd")
const ENEMIES := preload("res://scripts/services/r38_enemy_catalog.gd")
const ANIMATION := preload("res://scripts/animation/true_animation_library.gd")
const SPAWNER := preload("res://scripts/enemies/enemy_spawner.gd")
const LOOT := preload("res://scripts/services/loot_director.gd")
const HERO_SCENE := preload("res://scenes/heroes/Hero.tscn")
const CAPTAIN := preload("res://resources/heroes/rift_captain.tres")
const BASE_COUNTS := [12,7,9,10,12,15,15,12,12,16]
const PHASE_COUNTS := [12,11,16,20,18,19,21,18,24,24]
const PREFIX := "user://r38_content_fixture_"

var failed := false
var finished := false
var deadline := 0
var hero: Hero
var arena: Node2D
var spawner: Node
var loot: Node
var boss_intro := ""
var last_drop: Dictionary = {}
var phase := "bootstrap"

func _ready() -> void:
	if not get_meta("persistent", false):
		call_deferred("_install")
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	deadline = Time.get_ticks_msec() + 20000
	call_deferred("_run")

func _install() -> void:
	var runner: Node = get_script().new()
	runner.set_meta("persistent", true)
	get_tree().root.add_child(runner)

func _process(_delta: float) -> void:
	if get_meta("persistent", false) and not finished and Time.get_ticks_msec() >= deadline:
		_check(false, "20s watchdog " + phase)
		get_tree().quit(1)

func _run() -> void:
	GameManager.campaign_save_path = PREFIX + "campaign.cfg"
	GameManager.campaign_clears.clear()
	MetaProgress.debug_use_save_path(PREFIX + "meta.cfg", true)
	PlayerSettings.debug_use_save_path(PREFIX + "settings.cfg", true)
	AchievementProgress.debug_use_save_path(PREFIX + "achievements.cfg", true)
	for id in ENEMIES.get_enemy_ids():
		var config := ENEMIES.get_config(str(id))
		if not _check(ResourceLoader.exists(str(config.sprite_path)) and ANIMATION.has_character(str(config.sprite_path)), "new authored sprite not registered: " + str(id)):
			get_tree().quit(1)
			return
	GameManager.game_running = false
	arena = Node2D.new()
	add_child(arena)
	GameManager.arena = arena
	EntityFactory.initialize_for_arena(arena)
	loot = LOOT.new()
	arena.add_child(loot)
	loot.setup(arena, 380038)
	GameManager.loot_director = loot
	loot.loot_dropped.connect(func(item: Dictionary, _position: Vector2): last_drop = item.duplicate(true))
	GameManager.boss_intro_requested.connect(func(value: String): boss_intro = value)
	spawner = SPAWNER.new()
	arena.add_child(spawner)
	spawner.set_process(false)
	hero = HERO_SCENE.instantiate()
	arena.add_child(hero)
	hero.setup(CAPTAIN, null, true, 0)
	hero.set_process(false)
	hero.set_physics_process(false)
	for child in hero.get_children():
		if child.is_in_group("hero_controllers"):
			child.set_process(false)
			child.set_physics_process(false)
	for weapon in hero.weapons.values():
		weapon.set_process(false)
		weapon.set_physics_process(false)
	_clear_shots()
	GameManager.player = hero
	GameManager.squad_manager = null
	GameManager.xp_required = 999999
	GameManager.critical_strikes_enabled = false
	GameManager.game_running = true
	GameManager.manual_paused = false
	GameManager.system_pause_owners.clear()
	get_tree().paused = false
	for frame in range(4):
		await get_tree().process_frame
	await _test_new_rosters()
	await _test_new_skills()
	if failed:
		get_tree().quit(1)
		return
	await _test_ten_bosses_and_rewards()
	if failed:
		get_tree().quit(1)
		return
	phase = "endless_unlock"
	GameManager.game_running = false
	GameManager.system_pause_owners.clear()
	get_tree().paused = false
	arena.queue_free()
	await get_tree().process_frame
	_check(GameManager.start_endless_stage("forge"), "final new clear did not unlock real Endless launch")
	for frame in range(4):
		await get_tree().process_frame
	_check(GameManager.run_mode == "endless" and GameManager.selected_stage_id == "forge" and get_tree().current_scene.scene_file_path == "res://scenes/arena/Arena.tscn", "Endless did not enter the real new-stage Arena")
	finished = true
	if not failed:
		print("R38_CONTENT_PASS stages=10 new_regular_species=6 distinct_boss_patterns=10 frame2=true all_real_legendary_rewards=true persisted_clears=10 endless_forge=true isolated_saves=true watchdog=20s")
	get_tree().quit(1 if failed else 0)

func _test_new_rosters() -> void:
	phase = "weighted_rosters"
	var roster_keys: Dictionary = {}
	GameManager.elapsed_time = 65.0
	for id in ["dunes","tide","bloom","forge"]:
		GameManager.select_stage(id)
		var weights := ENEMIES.get_roster(id)
		roster_keys[JSON.stringify(weights)] = true
		var actual: Dictionary = {}
		seed(380038)
		for attempt in range(160):
			var chosen: String = spawner._choose_enemy_type()
			_check(weights.has(chosen), "weighted chooser escaped biome roster: " + id)
			actual[chosen] = int(actual.get(chosen, 0)) + 1
		spawner.regular_spawn_counts.clear()
		spawner._spawn_opening_pack()
		spawner._spawn_harvest_pack()
		spawner._spawn_one()
		_check(not (spawner.regular_spawn_counts as Dictionary).is_empty(), "biome did not really spawn any species")
		for spawned_id in spawner.regular_spawn_counts:
			_check(weights.has(spawned_id), "opening/harvest bypassed real biome roster")
		print("R38_ROSTER stage=%s weighted_draws=%s actual_spawns=%s" % [id, str(actual), str(spawner.regular_spawn_counts)])
		_clear_enemies()
		await get_tree().process_frame
	_check(roster_keys.size() == 4, "four new stages share the same weighted roster")

func _test_new_skills() -> void:
	phase = "regular_frame2_skills"
	for id in ["coral_colossus","bloom_wisp","tide_siren","clockwork_reaper"]:
		var creature: Node = EntityFactory.spawn_enemy(id, ENEMIES.get_config(id), Vector2.ZERO)
		creature.set_physics_process(false)
		hero.global_position = Vector2(90,0)
		hero.current_hp = hero.max_hp
		hero.invulnerability_timer = 0.0
		var ally: Node = null
		if id == "bloom_wisp":
			ally = EntityFactory.spawn_enemy("support_fixture", ENEMIES.get_config("dune_scarab"), Vector2(80,80))
			ally.set_physics_process(false)
			ally.hp = 10.0
		for frame in range(3):
			await get_tree().process_frame
		var hero_hp := hero.current_hp
		var impact_frames: Array[int] = []
		var impact_callback := _capture_impact_frames(creature, impact_frames)
		_check(creature._start_attack(hero, 1.0, &"biome"), "biome anticipation rejected: " + id)
		await get_tree().create_timer(0.075, true, false, true).timeout
		_check(int(creature.biome_casts) == 0 and hero.current_hp == hero_hp and EntityFactory.get_pool_live_count("projectile") == 0 and (ally == null or float(ally.hp) == 10.0), "new creature applied skill before frame2: " + id)
		await get_tree().create_timer(0.16, true, false, true).timeout
		_check(int(creature.biome_casts) == 1 and int(creature.attack_impact_count) == 1, "new creature never reached actual impact: " + id)
		_check(impact_frames == [2], "new creature real impact frame drifted: " + id)
		if id == "coral_colossus":
			_check(hero.current_hp < hero_hp and int(creature.biome_damage_hits) == 1, "coral slam did not damage its real nearby hero")
		elif id == "bloom_wisp":
			_check(float(ally.hp) == 22.0 and is_equal_approx(float(creature.biome_support_healing),12.0), "wisp visual did not heal real ally HP")
		else:
			_check(int(creature.biome_projectiles_fired) == (4 if id == "tide_siren" else 5), "new creature fan did not emit expected actual shots")
		print("R38_REGULAR skill=%s frame2=true actual=%s" % [id,str(creature.get_biome_debug_state())])
		(creature.animated_sprite as AnimatedSprite2D).frame_changed.disconnect(impact_callback)
		_clear_shots()
		EntityFactory.release_enemy(creature)
		var reused: Node = EntityFactory.spawn_enemy("plain_reuse", SPAWNER.ENEMY_CONFIGS.normal, Vector2(800,0))
		_check(reused.biome_skill == "" and reused.biome_casts == 0 and reused.biome_support_healing == 0.0 and reused.biome_projectiles_fired == 0, "pool inherited biome skill/counters")
		EntityFactory.release_enemy(reused)
		if ally != null:
			EntityFactory.release_enemy(ally)
		await get_tree().process_frame

func _test_ten_bosses_and_rewards() -> void:
	var all_stages := STAGES.get_stages()
	_check(all_stages.size() == 10 and STAGES.get_next_stage_id("veil") == "dunes" and STAGES.get_next_stage_id("forge") == "", "ten-stage campaign order is incomplete")
	var plans: Dictionary = {}
	for index in range(all_stages.size()):
		var stage: Dictionary = all_stages[index]
		var id := str(stage.id)
		phase = "boss_" + id
		GameManager.select_stage(id)
		GameManager.run_mode = "campaign"
		GameManager.boss_killed = false
		GameManager.stage_victory_pending = false
		GameManager.system_pause_owners.clear()
		get_tree().paused = false
		spawner.boss_spawned = false
		spawner.boss_time = float(stage.boss_time)
		spawner.opening_pack_spawned = true
		spawner.first_elite_time_applied = true
		spawner.next_elite_time = 1000000.0
		spawner.next_harvest_pack_time = 1000000.0
		spawner.spawn_timer = 1000000.0
		spawner.remote_reclaim_timer = 1000000.0
		GameManager.elapsed_time = float(stage.boss_time) - 0.01
		boss_intro = ""
		spawner._process(0.0)
		_check(not spawner.boss_spawned and boss_intro == "", "boss spawned before its actual stage timer: " + id)
		GameManager.elapsed_time = float(stage.boss_time)
		spawner._process(0.0)
		var boss: Node = null
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.get("is_boss") == true:
				boss = enemy
		_check(boss != null and boss_intro == str(stage.boss_name), "scheduled boss spawn did not use actual new identity/name: " + id)
		if boss == null:
			return
		boss.global_position = Vector2.ZERO
		boss.set_physics_process(false)
		hero.global_position = Vector2(240,0)
		for frame in range(3):
			await get_tree().process_frame
		plans[JSON.stringify(boss._boss_shot_plan())] = true
		var impact_frames: Array[int] = []
		var impact_callback := _capture_impact_frames(boss, impact_frames)
		var source_fps: float = (boss.animated_sprite as AnimatedSprite2D).sprite_frames.get_animation_speed(&"attack")
		_check(is_equal_approx(source_fps,12.0), "boss source FPS was modified instead of preserving authored timing: " + id)
		_check(boss._start_attack(hero,0.82,&"ring"), "boss did not begin anticipation: " + id)
		await get_tree().create_timer(0.075,true,false,true).timeout
		_check(int(boss.boss_projectiles_fired)==0 and EntityFactory.get_pool_live_count("projectile")==0,"boss fired before frame2: " + id)
		await get_tree().create_timer(0.16,true,false,true).timeout
		_check(int(boss.boss_projectiles_fired)==BASE_COUNTS[index] and int(boss.attack_impact_count)==1,"boss base pattern actual count wrong: " + id)
		_clear_shots()
		await get_tree().create_timer(0.36,true,false,true).timeout
		boss._trigger_boss_phase_two()
		_check(EntityFactory.get_pool_live_count("projectile")==0,"half-HP trigger fired without frame2: " + id)
		await get_tree().create_timer(0.075,true,false,true).timeout
		_check(EntityFactory.get_pool_live_count("projectile")==0,"phase pattern skipped anticipation: " + id)
		await get_tree().create_timer(0.16,true,false,true).timeout
		_check(int(boss.boss_projectiles_fired)==BASE_COUNTS[index]+PHASE_COUNTS[index],"boss phase pattern actual count wrong: " + id)
		_check(impact_frames == [2,2], "boss base/phase real impacts escaped frame2: " + id)
		(boss.animated_sprite as AnimatedSprite2D).frame_changed.disconnect(impact_callback)
		_clear_shots()
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy != boss:
				EntityFactory.release_enemy(enemy)
		last_drop.clear()
		boss.take_damage(float(boss.hp)+100.0,hero.global_position)
		_check(boss.is_dying and str(boss.current_animation_name)=="death" and last_drop.is_empty(),"boss bypassed real death sequence/drop timing: " + id)
		await get_tree().create_timer(0.8,true,false,true).timeout
		var uid := int(last_drop.get("uid",-1))
		_check(str(last_drop.get("source",""))=="boss" and int(last_drop.get("rarity",-1))==3 and (loot.claimed_items as Dictionary).has(uid),"real new boss failed guaranteed legendary claim: " + id)
		_check(GameManager.campaign_clears.has(id) and GameManager.campaign_clears.size()==index+1,"boss clear/unlock was not awarded once: " + id)
		var saved := ConfigFile.new()
		_check(saved.load(GameManager.campaign_save_path)==OK and (saved.get_value("campaign","clears",[]) as Array).size()==index+1,"new clear was not persisted: " + id)
		print("R38_BOSS stage=%s name=%s pattern=%s time=%.0f base=%d phase2=%d actual_frames=%s source_fps=%.0f death_poses=true legendary_claimed=true persisted_clears=%d" % [id,str(stage.boss_name),str(stage.pattern),float(stage.boss_time),BASE_COUNTS[index],PHASE_COUNTS[index],str(impact_frames),source_fps,index+1])
		GameManager.system_pause_owners.clear()
		GameManager.stage_victory_pending=false
		get_tree().paused=false
		await get_tree().process_frame
		if failed:
			return
	_check(plans.size()==10,"ten stage bosses reuse one projectile geometry")

func _clear_shots() -> void:
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		if projectile.has_method("configure_orbit"):
			EntityFactory.release_orbit_projectile(projectile)
		else:
			EntityFactory.release_projectile(projectile)

func _capture_impact_frames(creature: Node, frames: Array[int]) -> Callable:
	var sprite: AnimatedSprite2D = creature.animated_sprite
	var callback: Callable = func():
		var frame_at_change: int = sprite.frame
		var impacts_before: int = creature.attack_impact_count
		var token: int = creature.get_hit_token()
		# Shared animation assigns the Sprite frame, then applies its impact hook.
		# Read the count after that hook while retaining the observed exact frame.
		var verify: Callable = func():
			if is_instance_valid(creature) and creature.get_hit_token() == token and int(creature.attack_impact_count) == impacts_before + 1:
				frames.append(frame_at_change)
		verify.call_deferred()
	sprite.frame_changed.connect(callback)
	return callback

func _clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		EntityFactory.release_enemy(enemy)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		failed=true
		push_error("R38_CONTENT_FAIL " + message)
	return condition
