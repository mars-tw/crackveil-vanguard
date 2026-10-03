extends Node2D

const COMBAT_FEEDBACK := preload("res://scripts/vfx/combat_feedback.gd")
const STAGE_CATALOG := preload("res://scripts/services/stage_catalog.gd")
const SPECIAL_ELITES := preload("res://scripts/services/special_elite_catalog.gd")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const R38_ENEMIES := preload("res://scripts/services/r38_enemy_catalog.gd")
const HARVEST_PACK_INTERVAL := 9.0
const HARVEST_PACK_FIRST_TIME := 7.0
const REMOTE_RECLAIM_INTERVAL := 1.0
const REMOTE_RECLAIM_BUDGET := 10

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
var next_elite_time: float = 18.0
var boss_spawned: bool = false
var first_elite_time_applied: bool = false
var opening_pack_spawned: bool = false
var debug_forced_elite_affix_id: String = ""
var next_harvest_pack_time: float = HARVEST_PACK_FIRST_TIME
var harvest_packs_spawned: int = 0
var harvest_enemies_spawned: int = 0
var remote_reclaim_timer: float = REMOTE_RECLAIM_INTERVAL
var remote_regular_reclaims: int = 0
var next_endless_boss_time: float = 120.0
var special_elite_index := 0
var special_elite_history: Array[Dictionary] = []
var debug_forced_special_elite_id := ""
var cached_spawn_stage_id := ""
var cached_spawn_stage: Dictionary = {}
var cached_stage_roster: Dictionary = {}
var cached_roster_ids: Array = []
var regular_spawn_counts: Dictionary = {}


func begin_endless() -> void:
	next_endless_boss_time = GameManager.elapsed_time + 120.0


func _ready() -> void:
	var arena := get_parent()
	var tier := MOBILE.layout_tier(MOBILE.ui_layout_size(get_viewport_rect().size))
	max_enemies = 150 if tier == MOBILE.LayoutTier.PHONE else 220 if tier == MOBILE.LayoutTier.TABLET else 240
	if arena != null and get_tree().get_first_node_in_group("combat_feedback") == null:
		var feedback := COMBAT_FEEDBACK.new()
		feedback.name = "CombatFeedback"
		arena.call_deferred("add_child", feedback)


func _process(delta: float) -> void:
	if not GameManager.game_running:
		return
	if not opening_pack_spawned:
		opening_pack_spawned = true
		_spawn_opening_pack()

	var elapsed := GameManager.elapsed_time
	if GameManager.run_mode == "endless" and boss_spawned and not GameManager.boss_active and elapsed >= next_endless_boss_time:
		boss_spawned = false
		boss_time = elapsed
	remote_reclaim_timer -= delta
	if remote_reclaim_timer <= 0.0:
		remote_reclaim_timer = REMOTE_RECLAIM_INTERVAL
		_reclaim_remote_regular_enemies()
	if not first_elite_time_applied:
		first_elite_time_applied = true
		if GameManager.has_method("get_first_elite_time"):
			next_elite_time = GameManager.get_first_elite_time(next_elite_time)

	if not boss_spawned and elapsed >= boss_time:
		_spawn_boss()

	if elapsed >= next_elite_time:
		if _spawn_elite():
			next_elite_time = elapsed + 28.0
		else:
			next_elite_time = elapsed + 1.0

	if elapsed >= next_harvest_pack_time:
		next_harvest_pack_time = elapsed + HARVEST_PACK_INTERVAL
		if not bool(GameManager.get("boss_active")):
			_spawn_harvest_pack()

	spawn_timer -= delta
	if spawn_timer > 0.0:
		return

	var cadence := _spawn_cadence(elapsed, bool(GameManager.get("boss_active")))
	var spawn_count := int(cadence["count"])
	for _index in range(spawn_count):
		_spawn_one()

	spawn_timer = float(cadence["interval"])
	if GameManager.has_method("get_spawn_timer_multiplier"):
		spawn_timer *= GameManager.get_spawn_timer_multiplier()


func _spawn_cadence(elapsed: float, boss_pressure: bool = false) -> Dictionary:
	# Keep the opening's 3/0.30 cadence at the 30s seam. The old second branch
	# reset that to 1/0.856, draining encounters by 8.5x just as builds grew.
	var count := 5 if elapsed < 10.0 else 6 + mini(2, int(maxf(0.0, elapsed - 30.0) / 90.0))
	var interval := maxf(0.16, 0.22 - elapsed * 0.0006)
	if boss_pressure:
		count = maxi(1, ceili(float(count) * 0.45))
		interval *= 1.35
	return {"count": count, "interval": interval}


func _spawn_opening_pack() -> void:
	var center := _elite_reclaim_reference_position()
	_refresh_stage_roster()
	for index in range(12):
		if EntityFactory.get_enemy_live_count() >= max_enemies:
			break
		var enemy_id := _choose_enemy_type() if not cached_stage_roster.is_empty() else "normal"
		var config := _config_for_spawn(enemy_id)
		config["max_hp"] = 16.0
		config["xp"] = 1
		config["damage"] = 4.0
		var offset := Vector2(175.0 + float(index % 3) * 27.0, float(index / 3) * 30.0 - 45.0)
		if EntityFactory.spawn_enemy(enemy_id, config, center + offset) != null:
			_record_regular_spawn(enemy_id)


func _spawn_one() -> void:
	if EntityFactory.get_enemy_live_count() >= max_enemies:
		return

	var enemy_id := _choose_enemy_type()
	var config: Dictionary = _config_for_spawn(enemy_id)
	if EntityFactory.spawn_enemy(enemy_id, config, _get_spawn_position()) != null:
		_record_regular_spawn(enemy_id)


func _spawn_harvest_pack() -> int:
	var remaining := maxi(0, max_enemies - EntityFactory.get_enemy_live_count())
	var pack_size := mini(remaining, 12 + mini(6, int(GameManager.elapsed_time / 30.0)))
	if pack_size <= 0:
		return 0
	var anchor := _get_spawn_position()
	var toward_player := (_elite_reclaim_reference_position() - anchor).normalized()
	if toward_player == Vector2.ZERO:
		toward_player = Vector2.LEFT
	var tangent := toward_player.orthogonal()
	_refresh_stage_roster()
	var enemy_id := _choose_enemy_type() if not cached_stage_roster.is_empty() else "normal"
	var config := _config_for_spawn(enemy_id)
	config["max_hp"] = float(config["max_hp"]) * 0.78
	config["damage"] = float(config["damage"]) * 0.8
	config["speed"] = float(config["speed"]) * 1.07
	config["xp"] = 1
	config["radius"] = 11.5
	var spawned := 0
	for index in range(pack_size):
		# Two staggered rows arrive together inside a normal area weapon's reach.
		# Their cheap HP rewards lining up a rail shot, orbit sweep, or grenade.
		var column := float(index % 5) - float(mini(pack_size, 5) - 1) * 0.5
		var position := anchor + tangent * column * 27.0 - toward_player * float(index / 5) * 29.0
		var spawn_id := "harvest_grunt" if cached_stage_roster.is_empty() else "harvest_%s" % enemy_id
		if EntityFactory.spawn_enemy(spawn_id, config, position) != null:
			spawned += 1
			_record_regular_spawn(enemy_id)
	if spawned > 0:
		harvest_packs_spawned += 1
		harvest_enemies_spawned += spawned
	return spawned


func get_harvest_debug_state() -> Dictionary:
	_refresh_stage_roster()
	return {"special_elites":special_elite_history.duplicate(true), "packs_spawned": harvest_packs_spawned, "enemies_spawned": harvest_enemies_spawned, "next_pack_time": next_harvest_pack_time, "enemy_cap": max_enemies, "remote_regular_reclaims": remote_regular_reclaims, "cadence": _spawn_cadence(GameManager.elapsed_time, bool(GameManager.get("boss_active"))), "world_view": _get_world_view_rect(), "biome_roster":cached_stage_roster.duplicate(), "regular_spawn_counts":regular_spawn_counts.duplicate()}


func _record_regular_spawn(enemy_id: String) -> void:
	regular_spawn_counts[enemy_id] = int(regular_spawn_counts.get(enemy_id, 0)) + 1


func _refresh_stage_roster() -> void:
	if cached_spawn_stage_id == GameManager.selected_stage_id and not cached_spawn_stage.is_empty():
		return
	cached_spawn_stage_id = GameManager.selected_stage_id
	cached_spawn_stage = STAGE_CATALOG.get_stage(cached_spawn_stage_id)
	cached_stage_roster = R38_ENEMIES.get_roster(cached_spawn_stage_id)
	cached_roster_ids = ENEMY_CONFIGS.keys() if cached_stage_roster.is_empty() else cached_stage_roster.keys()


func _enemy_base_config(enemy_id: String) -> Dictionary:
	return R38_ENEMIES.get_config(enemy_id) if R38_ENEMIES.has_enemy(enemy_id) else (ENEMY_CONFIGS.get(enemy_id, ENEMY_CONFIGS["normal"]) as Dictionary).duplicate(true)


func _spawn_elite() -> bool:
	if EntityFactory.get_enemy_live_count() >= max_enemies:
		if not EntityFactory.reclaim_regular_enemy_for_elite(_elite_reclaim_reference_position()):
			return false
	if debug_forced_elite_affix_id == "":
		return _spawn_special_elite()
	var config := _config_for_spawn("tank")
	config["max_hp"] = float(config.get("max_hp", 58.0)) * 3.0
	config["damage"] = float(config.get("damage", 14.0)) * 1.3
	config["radius"] = 28.0
	config["color"] = Color(0.85, 0.28, 1.0)
	config["sprite_scale"] = 1.56
	config["xp"] = 8
	config["gold"] = 6 + (GameManager.get_elite_bonus_gold() if GameManager.has_method("get_elite_bonus_gold") else 0)
	config["is_elite"] = true
	config["elite_bonus_xp"] = 24 + GameManager.next_elite_bonus_xp
	var affix_id := _roll_elite_affix_id()
	_apply_elite_affix(config, affix_id)
	var elite := EntityFactory.spawn_enemy("elite_distortion", config, _get_spawn_position())
	if elite == null:
		return false
	GameManager.consume_next_elite_bonus_xp()
	if GameManager.has_method("record_elite_spawn"):
		GameManager.record_elite_spawn()
	if GameManager.has_method("notify_affix_encounter"):
		GameManager.notify_affix_encounter(affix_id)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("elite")
	return true


func _spawn_special_elite() -> bool:
	var profiles := SPECIAL_ELITES.get_profiles()
	var profile: Dictionary = profiles[special_elite_index % profiles.size()]
	if debug_forced_special_elite_id != "":
		profile = SPECIAL_ELITES.get_profile(debug_forced_special_elite_id)
	if profile.is_empty():
		return false
	var config := SPECIAL_ELITES.make_config(str(profile.id), max_enemies)
	config["gold"] = int(config.get("gold", 0)) + GameManager.get_elite_bonus_gold()
	config["elite_bonus_xp"] = int(config.get("elite_bonus_xp", 0)) + GameManager.next_elite_bonus_xp
	_apply_time_scaling(config)
	var enemy := EntityFactory.spawn_enemy("special_elite_%s" % str(profile.id), config, _get_spawn_position())
	if enemy == null:
		return false
	# Consume the purchased reward only once a real enemy owns it. A full
	# pool or rejected spawn must leave the next-elite reward pending.
	GameManager.consume_next_elite_bonus_xp()
	special_elite_index += 1
	special_elite_history.append({"id":profile.id, "name":profile.name, "time":GameManager.elapsed_time})
	GameManager.record_elite_spawn()
	GameManager.show_toast("特殊菁英：%s　%s" % [profile.name, profile.description])
	AudioManager.play_sfx("elite")
	return true


func _spawn_boss() -> void:
	if EntityFactory.get_enemy_live_count() >= max_enemies:
		if not EntityFactory.reclaim_regular_enemy_for_elite(_elite_reclaim_reference_position()):
			return
	var stage := STAGE_CATALOG.get_stage(GameManager.selected_stage_id)
	var config := STAGE_CATALOG.get_boss_config(GameManager.selected_stage_id)
	config["death_spawn_cap"] = max_enemies
	if GameManager.run_mode == "endless":
		var wave := GameManager.get_endless_wave()
		config["max_hp"] = float(config["max_hp"]) * (1.0 + 0.12 * float(wave - 1))
		config["boss_ability_cooldown"] = maxf(2.0, float(config["boss_ability_cooldown"]) - float(wave - 1) * 0.08)
	var boss := EntityFactory.spawn_enemy("stage_boss_%s" % GameManager.selected_stage_id, config, _get_spawn_position())
	if boss == null:
		return
	boss_spawned = true
	if GameManager.run_mode == "endless":
		next_endless_boss_time = GameManager.elapsed_time + 120.0
	if GameManager.has_method("record_boss_spawn"):
		GameManager.record_boss_spawn(str(stage.get("boss_name", "帷幕君主")))
	if GameManager.has_method("set_boss_active"):
		GameManager.set_boss_active(true)


func _choose_enemy_type() -> String:
	_refresh_stage_roster()
	var elapsed := GameManager.elapsed_time
	var total_weight := 0.0

	for enemy_id in cached_roster_ids:
		var config: Dictionary = R38_ENEMIES.CONFIGS[enemy_id] if R38_ENEMIES.has_enemy(enemy_id) else ENEMY_CONFIGS[enemy_id]
		if elapsed >= float(config.get("min_time", 0.0)):
			total_weight += _stage_enemy_weight(enemy_id, config)

	var roll := randf() * total_weight
	var cursor := 0.0
	for enemy_id in cached_roster_ids:
		var config: Dictionary = R38_ENEMIES.CONFIGS[enemy_id] if R38_ENEMIES.has_enemy(enemy_id) else ENEMY_CONFIGS[enemy_id]
		if elapsed < float(config.get("min_time", 0.0)):
			continue
		cursor += _stage_enemy_weight(enemy_id, config)
		if roll <= cursor:
			return enemy_id

	return "normal"


func _stage_enemy_weight(enemy_id: String, config: Dictionary) -> float:
	_refresh_stage_roster()
	if not cached_stage_roster.is_empty():
		return float(cached_stage_roster.get(enemy_id, 0.0))
	return float(config.get("weight", 1.0)) * (2.5 if enemy_id == str(cached_spawn_stage.get("enemy_bias", "")) else 1.0)


func _config_for_spawn(enemy_id: String) -> Dictionary:
	_refresh_stage_roster()
	var config := _enemy_base_config(enemy_id)
	# Stronger late regions still leave ordinary monsters cheap to mow down.
	config["max_hp"] = float(config["max_hp"]) * (1.0 + 0.06 * (float(cached_spawn_stage.get("difficulty", 1)) - 1.0))
	if GameManager.selected_stage_id == "moon":
		config["damage"] = float(config["damage"]) * 0.65
		config["speed"] = float(config["speed"]) * 0.90
		if config.has("projectile_damage"):
			config["projectile_damage"] = float(config["projectile_damage"]) * 0.65
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
	if elapsed < 60.0 and GameManager.run_mode != "endless":
		return
	var minutes_after := maxf(0.0, (elapsed - 60.0) / 60.0)
	var multiplier := 1.0 + 0.075 * minutes_after
	if GameManager.run_mode == "endless":
		multiplier += 0.06 * float(GameManager.get_endless_wave() - 1)
	config["max_hp"] = float(config.get("max_hp", 1.0)) * multiplier
	config["damage"] = float(config.get("damage", 1.0)) * multiplier
	if config.has("projectile_damage"):
		config["projectile_damage"] = float(config.get("projectile_damage", 1.0)) * multiplier


func _get_spawn_position() -> Vector2:
	var world_view := _get_world_view_rect()
	var center := world_view.get_center()
	var half_size := world_view.size * 0.5
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


func _get_world_view_rect() -> Rect2:
	var center := Vector2.ZERO
	if GameManager.player != null and is_instance_valid(GameManager.player):
		center = GameManager.player.global_position

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)

	# Inverting the actual canvas transform covers camera zoom, smoothing,
	# offsets and viewport stretching; UI pixels are not world-space pixels.
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		var inverse_canvas := get_viewport().get_canvas_transform().affine_inverse()
		var first := inverse_canvas * Vector2.ZERO
		var second := inverse_canvas * Vector2(viewport_size.x, 0.0)
		var third := inverse_canvas * viewport_size
		var fourth := inverse_canvas * Vector2(0.0, viewport_size.y)
		var minimum := first.min(second).min(third).min(fourth)
		var maximum := first.max(second).max(third).max(fourth)
		return Rect2(minimum, maximum - minimum)
	return Rect2(center - viewport_size * 0.5, viewport_size)


func _reclaim_remote_regular_enemies() -> int:
	if EntityFactory.enemy_spatial_index == null:
		return 0
	var safe_view := _get_world_view_rect().grow(maxf(330.0, spawn_margin * 3.0))
	var candidates: Array[Node] = []
	# Use the existing registry, in spawn order, once per second. Reclamation
	# does not award damage, XP, gold, equipment, or advance any RNG stream.
	for enemy in EntityFactory.enemy_spatial_index.live_enemies:
		if enemy == null or not is_instance_valid(enemy) or enemy.get("is_active") != true:
			continue
		if enemy.get("is_elite") == true or enemy.get("is_boss") == true or enemy.get("is_dying") == true:
			continue
		if safe_view.has_point(enemy.global_position):
			continue
		candidates.append(enemy)
		if candidates.size() >= REMOTE_RECLAIM_BUDGET:
			break
	for enemy in candidates:
		EntityFactory.release_enemy(enemy)
	remote_regular_reclaims += candidates.size()
	return candidates.size()


func _elite_reclaim_reference_position() -> Vector2:
	if GameManager.player != null and is_instance_valid(GameManager.player):
		return GameManager.player.global_position
	return Vector2.ZERO
