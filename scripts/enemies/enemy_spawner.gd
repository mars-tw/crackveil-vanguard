extends Node2D

const ENEMY_CONFIGS: Dictionary = {
	"normal": {
		"max_hp": 20.0,
		"speed": 88.0,
		"damage": 8.0,
		"xp": 2,
		"gold": 1,
		"radius": 13.0,
		"color": Color(0.92, 0.28, 0.34),
		"sprite_path": "res://assets/sprites/enemy_grunt.png",
		"sprite_scale": 1.0,
		"weight": 1.0,
		"min_time": 0.0
	},
	"fast": {
		"max_hp": 13.0,
		"speed": 142.0,
		"damage": 6.0,
		"xp": 2,
		"gold": 1,
		"radius": 10.0,
		"color": Color(1.0, 0.68, 0.18),
		"sprite_path": "res://assets/sprites/enemy_fast.png",
		"sprite_scale": 1.0,
		"weight": 0.42,
		"min_time": 18.0
	},
	"tank": {
		"max_hp": 58.0,
		"speed": 54.0,
		"damage": 14.0,
		"xp": 6,
		"gold": 3,
		"radius": 20.0,
		"color": Color(0.55, 0.36, 0.9),
		"sprite_path": "res://assets/sprites/enemy_tank.png",
		"sprite_scale": 1.0,
		"weight": 0.24,
		"min_time": 42.0,
		"attack_cooldown": 1.0
	}
}

@export var max_enemies: int = 150
@export var spawn_margin: float = 110.0

var spawn_timer: float = 0.4


func _process(delta: float) -> void:
	if not GameManager.game_running:
		return

	spawn_timer -= delta
	if spawn_timer > 0.0:
		return

	var elapsed := GameManager.elapsed_time
	var spawn_count := 1 + int(elapsed / 45.0)
	for _index in range(spawn_count):
		_spawn_one()

	spawn_timer = max(0.22, 1.05 - elapsed * 0.006)


func _spawn_one() -> void:
	if EntityFactory.get_enemy_live_count() >= max_enemies:
		return

	var enemy_id := _choose_enemy_type()
	var config: Dictionary = ENEMY_CONFIGS[enemy_id]
	EntityFactory.spawn_enemy(enemy_id, config, _get_spawn_position())


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
