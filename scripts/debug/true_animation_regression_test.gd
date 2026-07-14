extends Node

const PLAYER_VISUAL_SCRIPT := preload("res://scripts/player/player_visual.gd")
const TRUE_ANIMATION_LIBRARY := preload("res://scripts/animation/true_animation_library.gd")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const HERO_SCENE := preload("res://scenes/heroes/Hero.tscn")
const SHEPHERD_DATA := preload("res://resources/heroes/rift_shepherd.tres")

class DamageTarget:
	extends Node2D
	var hp: float = 100.0
	var hit_radius: float = 13.0
	var is_alive: bool = true
	var is_active: bool = true

	func take_damage(amount: float, _source_position: Vector2 = Vector2.ZERO) -> bool:
		hp = maxf(hp - amount, 0.0)
		return true

	func get_hit_radius() -> float:
		return hit_radius

var failed: bool = false
var player_impact_count: int = 0
var player_active_frame_observed: bool = false
var observed_player_visual: Node = null


func _ready() -> void:
	# Enemy hurt/death feedback uses the normal pooled damage-number and burst
	# routes.  Give this isolated scene the same pools as an arena so a passing
	# animation contract is also a warning-free headless run.
	EntityFactory.initialize_for_arena(self)
	await get_tree().process_frame
	await _test_shared_atlas_and_player_events()
	if failed:
		return
	await _test_shepherd_weapon_impact_and_whiff()
	if failed:
		return
	await _test_enemy_impact_whiff_hurt_and_death()
	if failed:
		return
	print("TRUE_ANIMATION_REGRESSION_PASS")
	get_tree().quit(0)


func _test_shared_atlas_and_player_events() -> void:
	var captain_frames := TRUE_ANIMATION_LIBRARY.get_sprite_frames("res://assets/sprites/hero_captain.png")
	var shepherd_frames := TRUE_ANIMATION_LIBRARY.get_sprite_frames("res://assets/sprites/hero_shepherd.png")
	var enemy_frames := TRUE_ANIMATION_LIBRARY.get_sprite_frames("res://assets/sprites/enemy_grunt.png")
	_assert(captain_frames != null and shepherd_frames != null and enemy_frames != null, "shared atlas frames failed to load")
	if failed:
		return
	_assert(captain_frames.get_frame_count(&"idle") == 4, "idle must have four articulated poses")
	_assert(captain_frames.get_frame_count(&"walk") == 8, "walk must have eight articulated poses")
	_assert(captain_frames.get_frame_count(&"attack") == 6, "attack must have anticipation/impact/recovery poses")
	_assert(captain_frames.get_frame_count(&"hurt") == 3, "hurt must have three reaction poses")
	_assert(captain_frames.get_frame_count(&"death") == 6, "death must have six fall poses")
	for state in TRUE_ANIMATION_LIBRARY.STATE_ORDER:
		_assert(shepherd_frames.get_frame_count(state) == int(TRUE_ANIMATION_LIBRARY.FRAME_COUNTS[state]), "rift_shepherd %s pose count drifted" % state)
	var hero_atlas: Texture2D = (captain_frames.get_frame_texture(&"walk", 0) as AtlasTexture).atlas
	var shepherd_atlas: Texture2D = (shepherd_frames.get_frame_texture(&"attack", 2) as AtlasTexture).atlas
	var enemy_atlas: Texture2D = (enemy_frames.get_frame_texture(&"walk", 0) as AtlasTexture).atlas
	_assert(hero_atlas == shepherd_atlas and hero_atlas == enemy_atlas, "captain, shepherd, and enemy frames do not share one atlas texture")

	var host := CharacterBody2D.new()
	host.add_to_group("heroes")
	add_child(host)
	var visual := PLAYER_VISUAL_SCRIPT.new()
	host.add_child(visual)
	visual.configure_visual("res://assets/sprites/hero_shepherd.png", 1.0, 14.0)
	observed_player_visual = visual
	visual.attack_impact.connect(_on_player_attack_impact)
	_assert(visual.play_attack(), "player attack animation did not start")
	await get_tree().create_timer(0.11).timeout
	_assert(player_impact_count == 0, "player damage event fired during anticipation")
	await get_tree().create_timer(0.12).timeout
	_assert(player_impact_count == 1, "player impact event did not fire on frame 2")
	_assert(player_active_frame_observed, "player hitbox was not active during impact event")
	await get_tree().create_timer(0.34).timeout
	_assert(player_impact_count == 1, "player attack emitted duplicate impacts")
	_assert(visual.get_animation_state() == &"idle", "player attack did not recover to idle")
	visual.play_hurt(Vector2.LEFT)
	_assert(visual.get_animation_state() == &"hurt", "player hurt state did not play")
	_assert((visual.get("animated_sprite") as AnimatedSprite2D).position == Vector2.ZERO, "visual root moved during hurt")
	host.queue_free()
	print("TRUE_ANIMATION_PLAYER hero=rift_shepherd poses=4/8/6/3/6 impact_frame=2 duplicate_hits=0 shared_atlas=%d" % TRUE_ANIMATION_LIBRARY.get_shared_atlas_instance_id())


func _test_shepherd_weapon_impact_and_whiff() -> void:
	GameManager.game_running = true
	var shepherd := HERO_SCENE.instantiate()
	add_child(shepherd)
	shepherd.setup(SHEPHERD_DATA, null, false, 0)
	shepherd.set_physics_process(false)
	var controller := shepherd.get_node_or_null("FollowerController")
	if controller != null:
		controller.set_process(false)
		controller.set_physics_process(false)
	var weapon: Node = (shepherd.get("weapons") as Dictionary).get("rift_constructs")
	_assert(weapon != null, "rift_shepherd did not equip rift_constructs")
	if failed:
		return
	var target := DamageTarget.new()
	target.global_position = Vector2(120.0, 0.0)
	add_child(target)

	var live_before := EntityFactory.get_rift_construct_count_for_owner(shepherd)
	_assert(bool(weapon.call("_begin_cast", target)), "rift_constructs attack did not enter anticipation")
	await get_tree().create_timer(0.11).timeout
	_assert(EntityFactory.get_rift_construct_count_for_owner(shepherd) == live_before, "rift construct spawned during anticipation")
	await get_tree().create_timer(0.12).timeout
	_assert(EntityFactory.get_rift_construct_count_for_owner(shepherd) == live_before + 1, "rift construct did not spawn on frame 2")
	await get_tree().create_timer(0.34).timeout
	var visual: Node = shepherd.get_node("Visual")
	_assert(visual.get_animation_state() == &"idle", "rift_shepherd attack did not finish recovery")
	EntityFactory.release_rift_constructs_for_owner(shepherd, false)
	var construct_stats: Dictionary = weapon.call("_construct_stats")
	for index in range(7):
		EntityFactory.spawn_rift_construct(Vector2(float(index) * 24.0, 80.0), construct_stats, shepherd, weapon, 6)
	_assert(EntityFactory.get_rift_construct_count_for_owner(shepherd) == 6, "rift construct global hard cap exceeded or underfilled")
	var pool_stats: Dictionary = EntityFactory.get_pool_stats().get("rift_construct", {})
	_assert(int(pool_stats.get("exhausted", 0)) == 0 and int(pool_stats.get("duplicate_releases", 0)) == 0 and int(pool_stats.get("foreign_releases", 0)) == 0, "rift construct pool contract failed")
	EntityFactory.release_rift_constructs_for_owner(shepherd, false)

	var trigger_before := int(weapon.get("trigger_count"))
	var hp_before := target.hp
	target.global_position = Vector2(120.0, 0.0)
	_assert(bool(weapon.call("_begin_cast", target)), "rift_constructs whiff did not enter anticipation")
	await get_tree().create_timer(0.10).timeout
	target.global_position = Vector2(900.0, 0.0)
	await get_tree().create_timer(0.15).timeout
	_assert(EntityFactory.get_rift_construct_count_for_owner(shepherd) == 0, "rift_constructs whiff spawned a construct")
	_assert(is_equal_approx(target.hp, hp_before), "rift_constructs whiff dealt damage")
	_assert(int(weapon.get("trigger_count")) == trigger_before, "rift_constructs whiff registered a trigger")
	await get_tree().create_timer(0.32).timeout
	_assert(visual.get_animation_state() == &"idle", "rift_constructs whiff skipped recovery")
	weapon.release_owned_nodes()
	shepherd.queue_free()
	target.queue_free()
	print("TRUE_ANIMATION_SHEPHERD impact_spawn=frame2 anticipation_spawn=0 whiff_damage=0 whiff_spawn=0 recovery=full cap=6 pool_errors=0")


func _test_enemy_impact_whiff_hurt_and_death() -> void:
	var config := {
		"max_hp": 80.0,
		"speed": 88.0,
		"damage": 12.0,
		"xp": 0,
		"gold": 0,
		"radius": 13.0,
		"sprite_path": "res://assets/sprites/enemy_grunt.png",
		"attack_cooldown": 0.1,
	}
	var enemy := ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.set_meta("_node_pool_name", "enemy")
	enemy.pool_on_acquire()
	enemy.pool_reset({"enemy_id": "true_animation_test", "config": config, "position": Vector2.ZERO, "spawn_token": 9001})
	enemy.set_physics_process(false)
	var animated_sprite: AnimatedSprite2D = enemy.get("animated_sprite")
	var art_state: Dictionary = enemy.get_enemy_art_lod_debug_state()
	_assert(bool(art_state.get("shared_ticker", false)) and not animated_sprite.is_playing(), "enemy kept a per-instance AnimatedSprite clock")
	enemy.velocity = Vector2.RIGHT * 88.0
	enemy.tick_shared_enemy_animation(0.0, enemy.global_position, true)
	art_state = enemy.get_enemy_art_lod_debug_state()
	_assert(str(art_state.get("lod_tier", "")) == "near" and is_equal_approx(float(art_state.get("effective_fps", 0.0)), 6.0), "near regular locomotion LOD must use four poses at 6fps")
	_assert(int(art_state.get("sequence_frames", 0)) == 4, "regular walk LOD did not retain four articulated limb poses")
	enemy.tick_shared_enemy_animation(0.0, enemy.global_position + Vector2(220.0, 0.0), true)
	art_state = enemy.get_enemy_art_lod_debug_state()
	_assert(str(art_state.get("lod_tier", "")) == "mid" and is_equal_approx(float(art_state.get("effective_fps", 0.0)), 3.0), "mid animation LOD is not half-rate")
	enemy.tick_shared_enemy_animation(0.0, enemy.global_position + Vector2(420.0, 0.0), true)
	art_state = enemy.get_enemy_art_lod_debug_state()
	_assert(str(art_state.get("lod_tier", "")) == "far" and is_equal_approx(float(art_state.get("effective_fps", 0.0)), 1.5), "far animation LOD is not quarter-rate")
	var held_pose := animated_sprite.frame
	enemy.tick_shared_enemy_animation(1.0, enemy.global_position + Vector2(620.0, 0.0), true)
	art_state = enemy.get_enemy_art_lod_debug_state()
	_assert(bool(art_state.get("frozen_on_current_pose", false)) and animated_sprite.frame == held_pose, "offscreen LOD did not hold the current articulated pose")
	enemy.velocity = Vector2.ZERO
	enemy.tick_shared_enemy_animation(0.0, Vector2.ZERO, false)
	var simplified_profile: StringName = EntityFactory.acquire_enemy_death_animation_profile(false, true)
	var feature_profile: StringName = EntityFactory.acquire_enemy_death_animation_profile(true, true)
	_assert(simplified_profile == &"simplified", "crowded regular death did not select the shortened pose sequence")
	_assert(feature_profile == &"full", "elite/boss death did not preserve its full pose sequence")
	EntityFactory.release_enemy_death_animation_profile(simplified_profile)
	EntityFactory.release_enemy_death_animation_profile(feature_profile)
	var target := DamageTarget.new()
	target.global_position = Vector2(24.0, 0.0)
	add_child(target)

	var hp_before := target.hp
	_assert(bool(enemy.call("_start_attack", target, 1.0, &"contact")), "enemy attack did not start")
	await get_tree().create_timer(0.11).timeout
	_assert(is_equal_approx(target.hp, hp_before), "enemy damaged on input/anticipation instead of impact")
	await get_tree().create_timer(0.12).timeout
	_assert(target.hp < hp_before, "enemy impact frame did not damage in-range target")
	_assert(int(enemy.get("attack_impact_count")) == 1, "enemy attack impact count drifted")
	_assert((enemy.get("attack_hit_registry") as Dictionary).size() == 1, "enemy active hitbox did not prevent duplicate target damage")
	await get_tree().create_timer(0.34).timeout

	var whiff_hp := target.hp
	target.global_position = Vector2(24.0, 0.0)
	_assert(bool(enemy.call("_start_attack", target, 1.0, &"contact")), "enemy whiff attack did not start")
	await get_tree().create_timer(0.10).timeout
	target.global_position = Vector2(240.0, 0.0)
	await get_tree().create_timer(0.15).timeout
	_assert(is_equal_approx(target.hp, whiff_hp), "enemy whiff dealt damage outside active hitbox")
	await get_tree().create_timer(0.32).timeout

	enemy.set_physics_process(true)
	var position_before: Vector2 = enemy.global_position
	enemy.take_damage(1.0, Vector2(-20.0, 0.0))
	enemy.apply_knockback(Vector2(-20.0, 0.0), 40.0)
	enemy.call("_physics_process", 0.05)
	_assert(StringName(enemy.get("current_animation_name")) == &"hurt", "enemy hurt pose did not play")
	_assert(enemy.global_position.x > position_before.x, "enemy hurt reaction did not knock back physics root")
	await get_tree().create_timer(0.28).timeout

	enemy.take_damage(9999.0, Vector2.LEFT * 20.0)
	_assert(bool(enemy.get("is_dying")) and not bool(enemy.get("is_active")), "enemy did not enter protected death state")
	_assert(StringName(enemy.get("current_animation_name")) == &"death", "enemy death animation did not start")
	await get_tree().create_timer(0.45).timeout
	_assert(enemy.visible, "enemy was recycled before death animation completed")
	await get_tree().create_timer(0.22).timeout
	_assert(not is_instance_valid(enemy) or not enemy.visible, "enemy was not recycled after death animation completed")
	target.queue_free()
	print("TRUE_ANIMATION_ENEMY impact_delayed=true whiff_damage=0 hurt_knockback=true death_delayed=true lod=6/3/1.5/freeze shared_ticker=true")


func _on_player_attack_impact() -> void:
	player_impact_count += 1
	if observed_player_visual != null and is_instance_valid(observed_player_visual):
		player_active_frame_observed = bool(observed_player_visual.call("is_attack_hitbox_active"))


func _assert(condition: bool, message: String) -> void:
	if condition or failed:
		return
	failed = true
	printerr("TRUE_ANIMATION_REGRESSION_FAIL: " + message)
	get_tree().quit(1)
