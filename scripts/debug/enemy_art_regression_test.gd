extends Node

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const ENEMY_SPAWNER_SCRIPT := preload("res://scripts/enemies/enemy_spawner.gd")

const ENEMY_ART_IDS: Array[String] = [
	"enemy_grunt", "enemy_fast", "enemy_tank", "enemy_elite_split",
	"enemy_elite_field", "enemy_elite_swift", "enemy_boss"
]

var failed: bool = false


func _ready() -> void:
	_test_compact_assets_and_real_frames()
	_test_visual_only_config_mapping()
	_test_animation_lod_and_pool_contract()
	MOBILE_TUNING.set_force_mobile_lod_for_tests(false)
	MOBILE_TUNING.set_device_hints_override_for_tests()
	Enemy.reset_animation_lod_cache_for_tests()
	if failed:
		print("ENEMY_ART_REGRESSION_FAIL")
		get_tree().quit(1)
	else:
		print("ENEMY_ART_ASSETS=7 source_canvas=96x96 atlas=512x3200 states=4/8/6/3/6 shared=true")
		print("ENEMY_ART_REGRESSION_PASS")
		get_tree().quit(0)


func _test_compact_assets_and_real_frames() -> void:
	SPRITE_LOADER.prewarm_gameplay_textures()
	var atlas := load("res://assets/sprites/true_character_atlas.png") as Texture2D
	_assert(atlas != null and atlas.get_width() == 512 and atlas.get_height() == 3200, "true animation atlas dimensions drifted")
	_assert(SPRITE_LOADER.texture_cache.has("res://assets/sprites/true_character_atlas.png"), "true animation atlas was not prewarmed")
	for base_name in ENEMY_ART_IDS:
		var base_path := "res://assets/sprites/%s.png" % base_name
		var texture := load(base_path) as Texture2D
		_assert(texture != null, "missing base enemy art: " + base_path)
		if texture == null:
			continue
		_assert(texture.get_width() == 96 and texture.get_height() == 96, "enemy art escaped 96px budget: " + base_path)
		if base_name in ["enemy_grunt", "enemy_fast", "enemy_tank"]:
			_assert(SPRITE_LOADER.texture_cache.has(base_path), "crowd enemy art was not prewarmed: " + base_path)


func _test_visual_only_config_mapping() -> void:
	var spawner := ENEMY_SPAWNER_SCRIPT.new()
	var constants: Dictionary = spawner.get_script().get_script_constant_map()
	var configs: Dictionary = constants.get("ENEMY_CONFIGS", {})
	_assert(configs.size() == 6, "enemy gameplay config count drifted")
	_assert(float(configs["normal"].get("max_hp", 0.0)) == 24.0 and float(configs["normal"].get("speed", 0.0)) == 88.0, "normal gameplay stats changed with art")
	_assert(float(configs["fast"].get("max_hp", 0.0)) == 16.0 and float(configs["fast"].get("speed", 0.0)) == 142.0, "fast gameplay stats changed with art")
	_assert(float(configs["tank"].get("max_hp", 0.0)) == 68.0 and float(configs["tank"].get("speed", 0.0)) == 54.0, "tank gameplay stats changed with art")
	_assert(int(constants.get("BOSS_SPRITE_PATH", "").find("enemy_boss.png")) >= 0, "boss lacks dedicated creature silhouette")

	var elite_paths: Dictionary = constants.get("ELITE_SPRITE_PATHS", {})
	_assert(elite_paths.size() == 3, "elite art mapping is incomplete")
	add_child(spawner)
	for affix_id in ["affix_split", "affix_field", "affix_swift"]:
		var config: Dictionary = configs["tank"].duplicate(true)
		spawner.call("_apply_elite_affix", config, affix_id)
		_assert(str(config.get("sprite_path", "")) == str(elite_paths[affix_id]), "elite silhouette mismatch: " + affix_id)
	spawner.queue_free()


func _test_animation_lod_and_pool_contract() -> void:
	MOBILE_TUNING.set_device_hints_override_for_tests({
		"mobile_os": false,
		"ua_mobile": false,
		"touch_available": false,
		"mouse_available": true
	})
	MOBILE_TUNING.set_force_mobile_lod_for_tests(false)
	Enemy.reset_animation_lod_cache_for_tests()
	var desktop_enemy := _spawn_visual_test_enemy(77)
	var desktop_state: Dictionary = desktop_enemy.get_enemy_art_lod_debug_state()
	_assert(not bool(desktop_state.get("mobile_lod", true)), "desktop enemy unexpectedly used mobile art LOD")
	_assert(int(desktop_state.get("idle_frames", 0)) == 4, "desktop enemy lost four-pose idle")
	_assert(int(desktop_state.get("walk_frames", 0)) == 8, "desktop enemy lost eight-pose walk")
	_assert(int(desktop_state.get("attack_frames", 0)) == 6, "desktop enemy attack phases missing")
	_assert(int(desktop_state.get("hurt_frames", 0)) == 3, "desktop enemy hurt reaction missing")
	_assert(int(desktop_state.get("death_frames", 0)) == 6, "desktop enemy death reaction missing")
	_assert(abs(float(desktop_state.get("walk_fps", 0.0)) - 10.0) < 0.001, "desktop enemy walk fps drifted")
	_assert(int(desktop_enemy.spawn_token) == 77, "art setup changed spawn_token")
	_assert(abs(float((desktop_enemy.get_node("CollisionShape2D") as CollisionShape2D).shape.radius) - 13.0) < 0.001, "art setup changed collision radius")
	desktop_enemy.queue_free()

	var desktop_elite := _spawn_visual_test_enemy(79, "res://assets/sprites/enemy_elite_split.png")
	var elite_state: Dictionary = desktop_elite.get_enemy_art_lod_debug_state()
	_assert(int(elite_state.get("idle_frames", 0)) == 4, "desktop elite lost articulated idle")
	_assert(int(elite_state.get("walk_frames", 0)) == 8, "desktop elite lost eight-pose walk")
	_assert(int(elite_state.get("atlas_instance_id", 0)) == int(desktop_state.get("atlas_instance_id", -1)), "enemy types do not share one atlas texture")
	desktop_elite.queue_free()

	MOBILE_TUNING.set_force_mobile_lod_for_tests(true)
	Enemy.reset_animation_lod_cache_for_tests()
	var mobile_enemy := _spawn_visual_test_enemy(78, "res://assets/sprites/enemy_elite_split.png")
	var mobile_state: Dictionary = mobile_enemy.get_enemy_art_lod_debug_state()
	_assert(bool(mobile_state.get("mobile_lod", false)), "mobile enemy did not enter art LOD")
	_assert(int(mobile_state.get("idle_frames", 0)) == 4, "mobile enemy lost required idle poses")
	_assert(int(mobile_state.get("walk_frames", 0)) == 8, "mobile enemy lost required limb poses")
	_assert(int(mobile_state.get("attack_frames", 0)) == 6 and int(mobile_state.get("hurt_frames", 0)) == 3 and int(mobile_state.get("death_frames", 0)) == 6, "mobile LOD removed required combat reactions")
	_assert(abs(float(mobile_state.get("walk_fps", 0.0)) - 10.0) < 0.001, "mobile walk timing drifted")
	_assert(int(mobile_state.get("atlas_instance_id", 0)) == int(desktop_state.get("atlas_instance_id", -1)), "mobile enemy does not share atlas texture")
	_assert(int(mobile_enemy.spawn_token) == 78, "mobile art LOD changed spawn_token")
	mobile_enemy.queue_free()


func _spawn_visual_test_enemy(token: int, art_path: String = "res://assets/sprites/enemy_grunt.png") -> Node:
	var enemy := ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.pool_on_acquire()
	enemy.pool_reset({
		"position": Vector2.ZERO,
		"enemy_id": "normal",
		"spawn_token": token,
		"config": {
			"max_hp": 24.0,
			"speed": 88.0,
			"damage": 8.0,
			"radius": 13.0,
			"color": Color(0.92, 0.28, 0.34),
			"sprite_path": art_path,
			"sprite_scale": 1.3,
			"is_elite": art_path.contains("enemy_elite_")
		}
	})
	return enemy


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("ENEMY_ART_REGRESSION_FAIL: " + message)
