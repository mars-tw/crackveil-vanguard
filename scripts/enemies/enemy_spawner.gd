extends Node2D

const ENEMY_CONFIGS: Dictionary = {
	"normal": {
		"max_hp": 24.0,
		"speed": 88.0,
		"damage": 8.0,
		"xp": 2,
		"gold": 1,
		"radius": 13.0,
		"color": Color(0.92, 0.28, 0.34),
		"sprite_path": "res://assets/sprites/enemy_grunt.png",
		"sprite_scale": 1.3,
		"weight": 1.0,
		"min_time": 0.0
	},
	"fast": {
		"max_hp": 16.0,
		"speed": 142.0,
		"damage": 6.0,
		"xp": 2,
		"gold": 1,
		"radius": 10.0,
		"color": Color(1.0, 0.68, 0.18),
		"sprite_path": "res://assets/sprites/enemy_fast.png",
		"sprite_scale": 1.25,
		"weight": 0.42,
		"min_time": 12.0
	},
	"tank": {
		"max_hp": 68.0,
		"speed": 54.0,
		"damage": 14.0,
		"xp": 6,
		"gold": 3,
		"radius": 20.0,
		"color": Color(0.55, 0.36, 0.9),
		"sprite_path": "res://assets/sprites/enemy_tank.png",
		"sprite_scale": 1.36,
		"weight": 0.24,
		"min_time": 42.0,
		"attack_cooldown": 1.0
	},
	"ranged": {
		"max_hp": 29.0,
		"speed": 64.0,
		"damage": 5.0,
		"xp": 3,
		"gold": 1,
		"radius": 12.0,
		"color": Color(1.0, 0.36, 0.28),
		"sprite_path": "res://assets/sprites/enemy_grunt.png",
		"sprite_scale": 1.3,
		"weight": 0.22,
		"min_time": 30.0,
		"attack_cooldown": 2.35,
		"behavior_id": "ranged",
		"preferred_distance": 255.0,
		"windup": 0.3,
		"projectile_damage": 5.0,
		"projectile_speed": 240.0,
		"projectile_range": 880.0,
		"projectile_radius": 6.0
	},
	"spawner": {
		"max_hp": 49.0,
		"speed": 42.0,
		"damage": 7.0,
		"xp": 5,
		"gold": 2,
		"radius": 18.0,
		"color": Color(0.86, 0.26, 0.58),
		"sprite_path": "res://assets/sprites/enemy_tank.png",
		"sprite_scale": 1.22,
		"weight": 0.16,
		"min_time": 45.0,
		"attack_cooldown": 1.2,
		"behavior_id": "chaser",
		"spawns_on_death": true,
		"death_spawn_id": "spawnling",
		"death_spawn_count": 2,
		"death_spawn_cap": 150
	},
	"dasher": {
		"max_hp": 35.0,
		"speed": 112.0,
		"damage": 7.0,
		"xp": 3,
		"gold": 1,
		"radius": 11.0,
		"color": Color(1.0, 0.62, 0.24),
		"sprite_path": "res://assets/sprites/enemy_fast.png",
		"sprite_scale": 1.3,
		"weight": 0.2,
		"min_time": 55.0,
		"attack_cooldown": 1.05,
		"behavior_id": "dasher",
		"dash_trigger_range": 165.0,
		"dash_windup": 0.42,
		"dash_duration": 0.24,
		"dash_recover": 0.55,
		"dash_speed": 420.0
	}
}

const ELITE_AFFIX_IDS: Array[String] = [
	"affix_split",
	"affix_field",
	"affix_swift"
]
const ELITE_SPRITE_PATHS: Dictionary = {
	"affix_split": "res://assets/sprites/enemy_elite_split.png",
	"affix_field": "res://assets/sprites/enemy_elite_field.png",
	"affix_swift": "res://assets/sprites/enemy_elite_swift.png"
}
const BOSS_SPRITE_PATH := "res://assets/sprites/enemy_boss.png"

@export var max_enemies: int = 150
@export var spawn_margin: float = 110.0
@export var boss_time: float = 180.0

var spawn_timer: float = 0.06
var next_elite_time: float = 52.0
var boss_spawned: bool = false
var first_elite_time_applied: bool = false
var debug_forced_elite_affix_id: String = ""


func _process(delta: float) -> void:
	if not GameManager.game_running:
		return

	var elapsed := GameManager.elapsed_time
	if not first_elite_time_applied:
		first_elite_time_applied = true
		if GameManager.has_method("get_first_elite_time"):
			next_elite_time = GameManager.get_first_elite_time(next_elite_time)

	if not boss_spawned and elapsed >= boss_time:
		_spawn_boss()

	if elapsed >= next_elite_time:
		if _spawn_elite():
			next_elite_time = elapsed + randf_range(45.0, 60.0)
		else:
			next_elite_time = elapsed + 1.0

	spawn_timer -= delta
	if spawn_timer > 0.0:
		return

	var spawn_count := 1 + int(elapsed / 55.0)
	if elapsed < 10.0:
		spawn_count = 2
	elif elapsed < 30.0:
		spawn_count = 3
	if bool(GameManager.get("boss_active")):
		spawn_count = max(1, int(ceil(float(spawn_count) * 0.45)))
	for _index in range(spawn_count):
		_spawn_one()

	spawn_timer = max(0.28, 1.0 - elapsed * 0.0048)
	if elapsed < 30.0:
		spawn_timer = max(0.2, 0.42 - elapsed * 0.004)
	if bool(GameManager.get("boss_active")):
		spawn_timer *= 1.35
	if GameManager.has_method("get_spawn_timer_multiplier"):
		spawn_timer *= GameManager.get_spawn_timer_multiplier()


func _spawn_one() -> void:
	if EntityFactory.get_enemy_live_count() >= max_enemies:
		return

	var enemy_id := _choose_enemy_type()
	var config: Dictionary = _config_for_spawn(enemy_id)
	EntityFactory.spawn_enemy(enemy_id, config, _get_spawn_position())


func _spawn_elite() -> bool:
	if EntityFactory.get_enemy_live_count() >= max_enemies:
		if not EntityFactory.reclaim_regular_enemy_for_elite(_elite_reclaim_reference_position()):
			return false
	var config := _config_for_spawn("tank")
	config["max_hp"] = float(config.get("max_hp", 58.0)) * 3.0
	config["damage"] = float(config.get("damage", 14.0)) * 1.3
	config["radius"] = 28.0
	config["color"] = Color(0.85, 0.28, 1.0)
	config["sprite_scale"] = 1.56
	config["xp"] = 8
	config["gold"] = 6 + (GameManager.get_elite_bonus_gold() if GameManager.has_method("get_elite_bonus_gold") else 0)
	config["is_elite"] = true
	config["elite_bonus_xp"] = 24 + (GameManager.consume_next_elite_bonus_xp() if GameManager.has_method("consume_next_elite_bonus_xp") else 0)
	var affix_id := _roll_elite_affix_id()
	_apply_elite_affix(config, affix_id)
	var elite := EntityFactory.spawn_enemy("elite_distortion", config, _get_spawn_position())
	if elite == null:
		return false
	if GameManager.has_method("record_elite_spawn"):
		GameManager.record_elite_spawn()
	if GameManager.has_method("notify_affix_encounter"):
		GameManager.notify_affix_encounter(affix_id)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("elite")
	return true


func _spawn_boss() -> void:
	if EntityFactory.get_enemy_live_count() >= max_enemies:
		return
	boss_spawned = true
	var config := {
		"max_hp": 2600.0,
		"speed": 46.0,
		"damage": 18.0,
		"xp": 30,
		"gold": 16,
		"radius": 34.0,
		"color": Color(0.42, 0.18, 0.74),
		"sprite_path": BOSS_SPRITE_PATH,
		"sprite_scale": 2.08,
		"attack_cooldown": 1.15,
		"behavior_id": "boss",
		"is_boss": true,
		"projectile_damage": 7.0,
		"projectile_speed": 215.0,
		"projectile_range": 940.0,
		"projectile_radius": 7.0,
		"boss_ability_cooldown": 4.2,
		"death_spawn_cap": max_enemies
	}
	EntityFactory.spawn_enemy("veil_gatekeeper", config, _get_spawn_position())
	if GameManager.has_method("record_boss_spawn"):
		GameManager.record_boss_spawn("VEIL GATEKEEPER")
	if GameManager.has_method("set_boss_active"):
		GameManager.set_boss_active(true)


func _choose_enemy_type() -> String:
	var elapsed := GameManager.elapsed_time
	var total_weight := 0.0

	for enemy_id in ENEMY_CONFIGS.keys():
		var config: Dictionary = ENEMY_CONFIGS[enemy_id]
		if elapsed >= float(config.get("min_time", 0.0)):
			total_weight += float(config.get("weight", 1.0))

	var roll := randf() * total_weight
	var cursor := 0.0
	for enemy_id in ENEMY_CONFIGS.keys():
		var config: Dictionary = ENEMY_CONFIGS[enemy_id]
		if elapsed < float(config.get("min_time", 0.0)):
			continue
		cursor += float(config.get("weight", 1.0))
		if roll <= cursor:
			return enemy_id

	return "normal"


func _config_for_spawn(enemy_id: String) -> Dictionary:
	var config: Dictionary = ENEMY_CONFIGS[enemy_id].duplicate(true)
	_apply_time_scaling(config)
	return config


func _roll_elite_affix_id() -> String:
	if debug_forced_elite_affix_id != "":
		return debug_forced_elite_affix_id
	return ELITE_AFFIX_IDS[randi() % ELITE_AFFIX_IDS.size()]


func _apply_elite_affix(config: Dictionary, affix_id: String) -> void:
	config["affix_id"] = affix_id
	match affix_id:
		"affix_split":
			config["max_hp"] = float(config.get("max_hp", 174.0)) * 0.92
			config["color"] = Color(0.55, 1.0, 0.58)
			config["sprite_path"] = ELITE_SPRITE_PATHS["affix_split"]
			config["sprite_scale"] = 1.5
			config["spawns_on_death"] = true
			config["death_spawn_id"] = "affix_split_spawnling"
			config["death_spawn_count"] = 2
			config["death_spawn_cap"] = max_enemies
		"affix_field":
			config["speed"] = float(config.get("speed", 54.0)) * 0.86
			config["color"] = Color(0.34, 0.88, 1.0)
			config["sprite_path"] = ELITE_SPRITE_PATHS["affix_field"]
			config["sprite_scale"] = 1.58
			config["affix_field_radius"] = 128.0
			config["affix_field_slow_strength"] = 0.22
		"affix_swift":
			config["max_hp"] = float(config.get("max_hp", 174.0)) * 0.82
			config["speed"] = float(config.get("speed", 54.0)) * 1.45
			config["damage"] = float(config.get("damage", 18.2)) * 0.9
			config["radius"] = 25.0
			config["color"] = Color(1.0, 0.62, 0.22)
			config["sprite_path"] = ELITE_SPRITE_PATHS["affix_swift"]
			config["sprite_scale"] = 1.48
			config["attack_cooldown"] = 1.05
			config["behavior_id"] = "dasher"
			config["dash_trigger_range"] = 185.0
			config["dash_windup"] = 0.32
			config["dash_duration"] = 0.26
			config["dash_recover"] = 0.48
			config["dash_speed"] = 465.0


func _apply_time_scaling(config: Dictionary) -> void:
	var elapsed := GameManager.elapsed_time
	if elapsed < 60.0:
		return
	var minutes_after := (elapsed - 60.0) / 60.0
	var multiplier := 1.0 + 0.075 * minutes_after
	config["max_hp"] = float(config.get("max_hp", 1.0)) * multiplier
	config["damage"] = float(config.get("damage", 1.0)) * multiplier
	if config.has("projectile_damage"):
		config["projectile_damage"] = float(config.get("projectile_damage", 1.0)) * multiplier


func _get_spawn_position() -> Vector2:
	var center := Vector2.ZERO
	if GameManager.player != null and is_instance_valid(GameManager.player):
		center = GameManager.player.global_position

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)

	var half_size := viewport_size * 0.5
	var side := randi() % 4
	match side:
		0:
			return center + Vector2(randf_range(-half_size.x, half_size.x), -half_size.y - spawn_margin)
		1:
			return center + Vector2(half_size.x + spawn_margin, randf_range(-half_size.y, half_size.y))
		2:
			return center + Vector2(randf_range(-half_size.x, half_size.x), half_size.y + spawn_margin)
		_:
			return center + Vector2(-half_size.x - spawn_margin, randf_range(-half_size.y, half_size.y))


func _elite_reclaim_reference_position() -> Vector2:
	if GameManager.player != null and is_instance_valid(GameManager.player):
		return GameManager.player.global_position
	return Vector2.ZERO
