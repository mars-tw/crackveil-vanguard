extends Node

const SQUAD := preload("res://scripts/heroes/squad_manager.gd")
const ROSTER := preload("res://resources/squads/default_squad.tres")
const CATALOG := preload("res://resources/weapons/weapon_catalog.tres")
const ANIMATION := preload("res://scripts/animation/true_animation_library.gd")
const SKILL_CATALOG := preload("res://scripts/services/skill_catalog.gd")
const HEROES := ["solar_lancer", "tide_oracle", "shadow_ronin"]
const WEAPONS := ["solar_piercer", "tidal_covenant", "shadow_twinblades"]
const MODIFIERS := ["solar_brand", "tide_rejuvenation", "shadow_return"]
var failures: Array[String] = []
var manager: Node
var observed_impact_frame := -1
var observed_visual: Node
var evidence: Dictionary = {"art_ready": false, "heroes": {}, "catalog": {}}

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	_test_catalog_data()
	if "--r38-catalog-only" in OS.get_cmdline_user_args():
		_finish("R38_CATALOG_ONLY")
		return
	for hero_id in HEROES:
		var path := "res://assets/sprites/hero_%s.png" % hero_id
		_check(ANIMATION.has_character(path), "missing authored animation registry: " + path)
		_check(ResourceLoader.exists(path), "missing authored hero icon: " + path)
	if not failures.is_empty():
		_finish("R38_HERO_WEAPON")
		return
	var first_poses := {}
	for hero_id in HEROES:
		var frames: SpriteFrames = ANIMATION.get_sprite_frames("res://assets/sprites/hero_%s.png" % hero_id)
		_check(frames != null and _unique_pose_count(frames, &"walk") >= 3, "new hero walk lacks changing articulated poses: " + hero_id)
		_check(frames != null and _unique_pose_count(frames, &"attack") >= 3, "new hero attack lacks anticipation/impact/recovery poses: " + hero_id)
		if frames != null:
			first_poses[_texture_key(frames.get_frame_texture(&"idle", 0))] = true
	_check(first_poses.size() == 3, "three new hero animations alias the same actor")
	evidence.art_ready = true
	GameManager.campaign_save_path = "user://r38_hero_weapon_campaign.cfg"
	GameManager.wallet_gold = 0
	GameManager.campaign_clears.clear()
	PlayerSettings.debug_use_save_path("user://r38_hero_weapon_settings.cfg", true)
	MetaProgress.debug_use_save_path("user://r38_hero_weapon_meta.cfg", true)
	AchievementProgress.debug_use_save_path("user://r38_hero_weapon_achievements.cfg", true)
	EntityFactory.initialize_for_arena(self)
	await get_tree().process_frame
	manager = SQUAD.new()
	add_child(manager)
	GameManager.player = manager.start_squad()
	GameManager.squad_manager = manager
	GameManager.arena = self
	GameManager.game_running = true
	GameManager.level = 8
	GameManager.critical_strikes_enabled = false
	GameManager.xp_required = 99999999
	_freeze_members()
	var recruit_options: Array = manager.build_upgrade_pool([])
	var paid_pool: Array[Dictionary] = SKILL_CATALOG.get_live_legal_pool()
	for hero_id in HEROES:
		var recruit: Dictionary = {}
		for option in recruit_options:
			if option.get("id") == "recruit_hero" and option.get("hero_id") == hero_id:
				recruit = option
		_check(not recruit.is_empty(), "new hero absent from real upgrade recruit pool: " + hero_id)
		var paid_recruit := false
		for option in paid_pool:
			paid_recruit = paid_recruit or (option.get("id") == "recruit_hero" and option.get("hero_id") == hero_id)
		_check(paid_recruit, "new hero absent from live paid skill card pool: " + hero_id)
		manager.apply_upgrade(recruit)
		_check(manager.get_member_by_id(hero_id) != null, "canonical recruit option did not spawn: " + hero_id)
		_check(not manager.recruit_hero(hero_id), "duplicate hero recruitment allowed: " + hero_id)
	_freeze_members()
	for index in range(3):
		await _test_actual_hero(index)
	_test_party_cap()
	await _test_reentry()
	_finish("R38_HERO_WEAPON")

func _test_catalog_data() -> void:
	_check(ROSTER.available_heroes.size() == 13, "roster must contain 13 real hero resources")
	_check(ROSTER.max_members == 9 and ROSTER.starting_heroes.size() == 3, "existing party/start cap drifted")
	var ids: Dictionary = {}
	for hero_data in ROSTER.available_heroes:
		_check(not ids.has(hero_data.id), "duplicate roster ID: " + hero_data.id)
		ids[hero_data.id] = true
	for index in range(3):
		var hero: Resource = ROSTER.get_hero_data(HEROES[index])
		var source: Resource = CATALOG.get_weapon_data(WEAPONS[index])
		_check(hero != null and source != null, "new hero or weapon resource missing")
		if hero == null or source == null:
			continue
		_check(hero.starting_weapon_ids.has(WEAPONS[index]), "new hero did not equip own actual weapon")
		var data: Resource = source.make_runtime_copy()
		var original_damage := float(source.damage)
		_check(data.weapon_scene != null and not data.get_qualitative_upgrade_definitions().is_empty(), "new weapon scene/quality defs missing")
		_check(not data.can_offer_evolution(20), "unearned evolution offered")
		data.apply_upgrade("weapon_damage")
		_check(data.damage > original_damage and is_equal_approx(source.damage, original_damage), "runtime upgrade mutated source or had no benefit")
		data.apply_upgrade("weapon_damage")
		data.apply_upgrade("weapon_damage")
		data.apply_upgrade(MODIFIERS[index])
		data.apply_upgrade(MODIFIERS[index])
		_check(not data.can_apply_upgrade(MODIFIERS[index]), "quality cap2 bypassed")
		_check(not data.can_offer_evolution(6) and data.can_offer_evolution(7), "evolution requires run7/damage3/quality2")
		var evolution: Dictionary = data.get_evolution_definition()
		data.apply_upgrade(evolution.evolution_id)
		_check(data.is_evolved() and not data.can_apply_upgrade(evolution.evolution_id), "evolution not applied/capped once")
		evidence.catalog[WEAPONS[index]] = {"source_damage": original_damage, "upgraded_damage": data.damage,
			"quality_max": data.get_modifier_max_level(MODIFIERS[index]), "evolution": evolution.evolution_id,
			"count_description": data.get_count_upgrade_description()}
	print("R38_CATALOG roster=13 unique=13 cap=9 old_start3=true new_weapons=3 quality2/evolution7/source_immutable=true")

func _freeze_members() -> void:
	for member in manager.get_members():
		member.set_process(false)
		member.set_physics_process(false)
		member.velocity = Vector2.ZERO
		for child in member.get_children():
			if child.is_in_group("hero_controllers"):
				child.set_process(false)
				child.set_physics_process(false)
		for weapon in member.weapons.values():
			weapon.set_process(false)

func _spawn_target(position: Vector2) -> Node2D:
	var enemy: Node2D = EntityFactory.spawn_enemy("grunt", {"max_hp": 9999.0, "speed": 0.0, "damage": 0.0,
		"xp": 0, "gold": 0, "radius": 14.0, "attack_cooldown": 999.0}, position)
	enemy.set_physics_process(false)
	return enemy

func _test_actual_hero(index: int) -> void:
	var hero: Node2D = manager.get_member_by_id(HEROES[index])
	if hero == null:
		return
	var weapon: Node = hero.weapons[WEAPONS[index]]
	var visual: Node = hero.get_node("Visual")
	_check(visual.animation_frames_ready, "new hero has no real articulated animation: " + HEROES[index])
	hero.global_position = Vector2(900.0 + index * 1000.0, 0.0)
	var target := _spawn_target(hero.global_position + Vector2(100.0, 0.0))
	var second := _spawn_target(hero.global_position + Vector2(170.0, 6.0))
	var outside := _spawn_target(hero.global_position + Vector2(140.0, 145.0))
	var before: float = target.hp
	var outside_hp: float = outside.hp
	observed_visual = visual
	observed_impact_frame = -1
	visual.attack_impact.connect(_observe_impact, CONNECT_ONE_SHOT)
	_check(weapon._begin_cast(target), "actual authored attack would not start: " + HEROES[index])
	_check(is_equal_approx(target.hp, before) and weapon.trigger_count == 0, "weapon damaged before impact frame")
	for _frame in range(150):
		await get_tree().physics_frame
		if weapon.impact_events > 0:
			break
		_check(is_equal_approx(target.hp, before) and weapon.projectiles_fired == 0, "anticipation frame spawned damage/projectiles")
	_check(observed_impact_frame == 2 and weapon.impact_events == 1 and weapon.trigger_count == 1,
		"actual hit not tied to one visual frame2: " + HEROES[index])
	await get_tree().create_timer(0.6).timeout
	_check(target.hp < before, "actual enemy hit/collision did no damage: " + WEAPONS[index])
	if index != 2:
		_check(is_equal_approx(outside.hp, outside_hp), "off-axis/outside enemy received weapon damage")
	if index == 0:
		_check(second.hp < 9999.0, "spear did not pierce second collider")
	elif index == 1:
		_check(target.has_status_effect("slow") and second.has_status_effect("slow"), "tide did not apply real slow to nearby enemy")
	elif index == 2:
		_check(weapon.projectiles_fired == 2, "shadow did not emit paired pooled returning blades")
	var baseline: Dictionary = weapon.get_firepower_debug_state().duplicate(true)
	var baseline_damage := before - float(target.hp)
	for projectile in EntityFactory.pools.projectile.get_live_nodes():
		EntityFactory.release_projectile(projectile)
	# Upgrades use the same canonical path used by level cards and the coin shop.
	var pool: Array = manager.build_upgrade_pool([])
	var quality: Dictionary = {}
	for option in pool:
		if option.get("hero_id") == HEROES[index] and option.get("upgrade_kind") == MODIFIERS[index]:
			quality = option
	_check(not quality.is_empty(), "resource-provided quality option absent from live pool")
	manager.apply_upgrade(quality)
	manager.apply_upgrade(quality)
	for _count in range(3):
		manager.apply_upgrade({"id": "upgrade_hero_weapon", "hero_id": HEROES[index], "weapon_id": WEAPONS[index], "upgrade_kind": "weapon_damage"})
	var evolution: Dictionary = {}
	for option in manager.build_upgrade_pool([]):
		if option.get("hero_id") == HEROES[index] and option.get("upgrade_category") == "evolution":
			evolution = option
	_check(not evolution.is_empty(), "earned evolution absent from live pool")
	manager.apply_upgrade(evolution)
	_check(weapon.data.is_evolved(), "canonical evolution did not apply")
	var original_count := int(baseline.volley_size)
	var hp_before_heal := float(hero.max_hp) - 20.0
	hero.current_hp = hp_before_heal
	await _wait_recovery(visual)
	var evolved_target := _spawn_target(hero.global_position + Vector2(105.0, 0.0))
	var evolved_hp: float = evolved_target.hp
	_check(weapon._begin_cast(evolved_target), "evolved actual attack rejected")
	var return_damage := 0.0
	if index == 2:
		await get_tree().create_timer(0.32).timeout
		var outbound_hit: Node = null
		var hit_token := int(evolved_target.get_hit_token())
		for projectile in EntityFactory.pools.projectile.get_live_nodes():
			if projectile.source_weapon_id == WEAPONS[index] and projectile.hit_bodies.has(hit_token):
				outbound_hit = projectile
				break
		_check(outbound_hit != null, "shadow fixture did not observe actual outbound collider hit")
		await get_tree().create_timer(0.6).timeout
		if is_instance_valid(outbound_hit):
			_check(outbound_hit.is_active and outbound_hit.boomerang_returning and not outbound_hit.hit_bodies.has(hit_token),
				"upgraded returning blade did not reset outbound hit registry")
			var return_hp: float = evolved_target.hp
			# Place the SAME enemy on the observed return path; Area2D physics must
			# re-enter its collider. Do not call either damage or collision handlers.
			evolved_target.global_position = outbound_hit.global_position + outbound_hit.direction * 16.0
			for _frame in range(5):
				await get_tree().physics_frame
			return_damage = return_hp - float(evolved_target.hp)
			_check(return_damage > 0.0 and outbound_hit.hit_bodies.has(hit_token), "same enemy failed true return collision / second hit")
	else:
		await get_tree().create_timer(0.85).timeout
	_check(evolved_target.hp < evolved_hp, "evolved weapon lost actual damage")
	if index == 0:
		_check(weapon.data.projectile_count == original_count + 2 and evolved_target.has_status_effect("vulnerable"), "solar evo lanes/brand had no actual benefit")
	elif index == 1:
		_check(hero.current_hp > hp_before_heal and weapon.projectiles_fired == 6, "tide evo did not heal and emit6 actual homing crystals")
	else:
		_check(weapon.data.projectile_count == original_count + 2 and weapon.projectiles_fired == 6, "shadow evo did not fire four new returning blades")
	var evolved_damage := evolved_hp - float(evolved_target.hp)
	var evolved_state: Dictionary = weapon.get_firepower_debug_state().duplicate(true)
	var healing_received := float(hero.current_hp) - hp_before_heal
	# A pooled target identity may change while the weapon anticipates. Reusing
	# the same node is never permission to hit its new generation.
	await _wait_recovery(visual)
	for projectile in EntityFactory.pools.projectile.get_live_nodes():
		EntityFactory.release_projectile(projectile)
	var stale := _spawn_target(hero.global_position + Vector2(110.0, 0.0))
	_check(weapon._begin_cast(stale), "pool identity test failed to start")
	var old_token := int(stale.spawn_token)
	EntityFactory.release_enemy(stale)
	var reused := _spawn_target(hero.global_position + Vector2(110.0, 0.0))
	_check(reused == stale and reused.spawn_token != old_token, "pool fixture did not reuse node with new token")
	var reused_hp: float = reused.hp
	var triggers_before := int(weapon.trigger_count)
	await get_tree().create_timer(0.35).timeout
	_check(is_equal_approx(reused.hp, reused_hp) and weapon.trigger_count == triggers_before and weapon.whiffs >= 1,
		"pending cast hit recycled target generation")
	# Reset/re-entry destroys pending state and old visual subscriptions.
	await _wait_recovery(visual)
	_check(weapon._begin_cast(reused), "reset test failed to start")
	weapon.reset_weapon()
	await get_tree().create_timer(0.35).timeout
	_check(weapon.trigger_count == 0 and not weapon.attack_pending, "reset cast emitted a late ghost hit")
	var after_reset: Dictionary = weapon.get_firepower_debug_state().duplicate(true)
	await _wait_recovery(visual)
	weapon.cooldown_timer = 0.0
	weapon.set_process(true)
	for _frame in range(180):
		await get_tree().physics_frame
		if weapon.trigger_count > 0:
			break
	weapon.set_process(false)
	_check(weapon.trigger_count > 0 and weapon.cast_starts > 0 and weapon.impact_events > 0,
		"automatic live weapon process did not acquire/animate/fire: " + WEAPONS[index])
	var automatic: Dictionary = weapon.get_firepower_debug_state().duplicate(true)
	evidence.heroes[HEROES[index]] = {"baseline": baseline, "evolved": evolved_state,
		"authored_frame2": observed_impact_frame, "pool_generation_safe": true, "reset_safe": true,
		"baseline_damage": baseline_damage, "evolved_damage": evolved_damage, "healed": healing_received,
		"after_reset": after_reset, "automatic_process": automatic, "same_enemy_return_damage": return_damage}
	print("R38_HERO hero=%s weapon=%s real_frame2=true baseline_damage=%.2f evolved_damage=%.2f collision=true pooled_identity_safe=true" %
		[HEROES[index], WEAPONS[index], baseline_damage, evolved_damage])
	for enemy in EntityFactory.get_enemies_in_radius(hero.global_position, 700.0):
		EntityFactory.release_enemy(enemy)
	for projectile in EntityFactory.pools.projectile.get_live_nodes():
		EntityFactory.release_projectile(projectile)

func _observe_impact() -> void:
	observed_impact_frame = int(observed_visual.animated_sprite.frame)

func _texture_key(texture: Texture2D) -> String:
	if texture is AtlasTexture:
		return "%s|%s" % [texture.atlas.resource_path, str(texture.region)]
	return texture.resource_path

func _unique_pose_count(frames: SpriteFrames, animation: StringName) -> int:
	if frames == null or not frames.has_animation(animation):
		return 0
	var keys := {}
	for index in range(frames.get_frame_count(animation)):
		keys[_texture_key(frames.get_frame_texture(animation, index))] = true
	return keys.size()

func _wait_recovery(visual: Node) -> void:
	for _frame in range(90):
		if visual.get_animation_state() != &"attack":
			return
		await get_tree().physics_frame

func _test_party_cap() -> void:
	for hero_id in ["pulse_artificer", "ember_grenadier", "void_weaver"]:
		_check(manager.recruit_hero(hero_id), "failed to fill real 9-party cap")
	_check(manager.get_member_count() == 9 and not manager.recruit_hero("rift_sniper"), "9-party cap bypassed")
	for option in manager.build_upgrade_pool([]):
		_check(option.get("id") != "recruit_hero", "full squad still offered recruit")
	_freeze_members()

func _test_reentry() -> void:
	GameManager.player = manager.start_squad()
	await get_tree().process_frame
	_freeze_members()
	_check(manager.get_member_count() == 3, "fresh squad did not clear previous new members")
	for index in range(3):
		_check(manager.recruit_hero(HEROES[index]), "new hero could not recruit on next run")
		var member: Node = manager.get_member_by_id(HEROES[index])
		var weapon: Node = member.weapons[WEAPONS[index]]
		_check(not weapon.data.is_evolved() and weapon.data.modifier_levels.is_empty() and weapon.trigger_count == 0,
			"new run inherited previous weapon state")
	_freeze_members()
	print("R38_REENTRY old10_preserved=true roster13=true cap9=true next_run_recruit3=true runtime_state_clean=true")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("R38_HERO_WEAPON_FAIL " + message)

func _finish(label: String) -> void:
	evidence["failures"] = failures
	var output := FileAccess.open("res://docs/evidence/r38-hero-weapon.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(evidence, "\t"))
	print(label + ("_PASS" if failures.is_empty() else "_FAIL"))
	GameManager.game_running = false
	GameManager.player = null
	GameManager.squad_manager = null
	GameManager.arena = null
	get_tree().quit(0 if failures.is_empty() else 1)
