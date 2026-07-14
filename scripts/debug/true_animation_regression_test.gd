extends Node

const PLAYER_VISUAL_SCRIPT := preload("res://scripts/player/player_visual.gd")
const TRUE_ANIMATION_LIBRARY := preload("res://scripts/animation/true_animation_library.gd")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")

class DamageTarget:
	extends Node2D
	var hp: float = 100.0
	var hit_radius: float = 13.0
	var is_alive: bool = true

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
	await _test_enemy_impact_whiff_hurt_and_death()
	if failed:
		return
	print("TRUE_ANIMATION_REGRESSION_PASS")
	get_tree().quit(0)


func _test_shared_atlas_and_player_events() -> void:
	var captain_frames := TRUE_ANIMATION_LIBRARY.get_sprite_frames("res://assets/sprites/hero_captain.png")
	var enemy_frames := TRUE_ANIMATION_LIBRARY.get_sprite_frames("res://assets/sprites/enemy_grunt.png")
	_assert(captain_frames != null and enemy_frames != null, "shared atlas frames failed to load")
	if failed:
		return
	_assert(captain_frames.get_frame_count(&"idle") == 4, "idle must have four articulated poses")
	_assert(captain_frames.get_frame_count(&"walk") == 8, "walk must have eight articulated poses")
	_assert(captain_frames.get_frame_count(&"attack") == 6, "attack must have anticipation/impact/recovery poses")
	_assert(captain_frames.get_frame_count(&"hurt") == 3, "hurt must have three reaction poses")
	_assert(captain_frames.get_frame_count(&"death") == 6, "death must have six fall poses")
	var hero_atlas: Texture2D = (captain_frames.get_frame_texture(&"walk", 0) as AtlasTexture).atlas
	var enemy_atlas: Texture2D = (enemy_frames.get_frame_texture(&"walk", 0) as AtlasTexture).atlas
	_assert(hero_atlas == enemy_atlas, "hero and enemy frames do not share one atlas texture")

	var host := CharacterBody2D.new()
	host.add_to_group("heroes")
	add_child(host)
	var visual := PLAYER_VISUAL_SCRIPT.new()
	host.add_child(visual)
	visual.configure_visual("res://assets/sprites/hero_captain.png", 1.0, 15.0)
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
	print("TRUE_ANIMATION_PLAYER impact_frame=2 duplicate_hits=0 shared_atlas=%d" % TRUE_ANIMATION_LIBRARY.get_shared_atlas_instance_id())


func _test_enemy_impact_whiff_hurt_and_death() -> void:
	var config := {
		"max_hp": 80.0,
		"speed": 0.0,
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
	print("TRUE_ANIMATION_ENEMY impact_delayed=true whiff_damage=0 hurt_knockback=true death_delayed=true")


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
