extends "res://scripts/weapons/base_weapon.gd"


func _process(delta: float) -> void:
	if owner_player == null or data == null or not GameManager.game_running:
		return

	cooldown_timer -= delta
	if cooldown_timer > 0.0:
		return

	var target := find_nearest_enemy(data_float("range", 520.0))
	var detonation_position: Vector2 = owner_player.global_position
	if target != null:
		detonation_position = target.global_position

	EntityFactory.spawn_explosion(detonation_position, data_effect_stats(), owner_player)
	register_trigger()
	cooldown_timer = data_float("cooldown", 1.0)
