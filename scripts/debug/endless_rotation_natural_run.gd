extends Node

# Fixed setup only. During combat the bot steers the touch stick, uses the
# normal auto-upgrade/channel settings and presses the shop's Leave button.
var arena: Node
var observations: Dictionary = {}
var forecasts: Dictionary = {}
var frames := 0
var finished := false

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	if not "qa_" in MetaProgress.save_path:
		printerr("R49_ENDLESS_NATURAL requires an isolated CV_QA_PROFILE")
		get_tree().quit(2)
		return
	GameManager.forced_run_seed = 49107
	GameManager.selected_stage_id = "garden"
	GameManager.run_mode = "endless"
	GameManager.tactical_launch = false
	AudioManager.set_muted(true)
	call_deferred("_start")

func _start() -> void:
	arena = preload("res://scenes/arena/Arena.tscn").instantiate()
	add_child(arena)
	GameManager.auto_upgrade_enabled = true
	GameManager.player.set_auto_channel_enabled(true)

func _process(_delta: float) -> void:
	if not is_instance_valid(arena) or finished:
		return
	frames += 1
	if GameManager.is_game_over or (observations.size() >= 2 and forecasts.size() >= 4) or GameManager.elapsed_time >= 151.0 or frames >= 12000:
		_finish()
		return
	if GameManager.waiting_for_shop:
		arena.get_node("RiftShopScreen").skip_button.pressed.emit()
	if get_tree().paused:
		return
	var wave := GameManager.get_endless_wave()
	var rule := GameManager.endless_rule()
	if not observations.has(rule):
		var hazard := get_tree().get_first_node_in_group(GameManager.ENDLESS_ROTATION.GROUPS[rule])
		if is_instance_valid(hazard):
			observations[rule] = {"wave": wave, "seconds": snappedf(GameManager.elapsed_time, 0.1), "resource": hazard.get_script().resource_path}
	var hud: Node = arena.get_node("HUD")
	var expected := GameManager.ENDLESS_ROTATION.top_line(rule, GameManager.endless_rule(1), GameManager.ENDLESS_ROTATION.waves_left(wave))
	if not forecasts.has(wave) and hud.tactical_hint.visible and hud.tactical_hint.text.begins_with(expected):
		forecasts[wave] = {"text": expected, "font": hud.mission_fit.get("size", 0), "width": hud.mission_fit.get("widest", 0), "room": hud.mission_fit.get("room", 0)}
		print("R49_ENDLESS_WAVE %d %s" % [wave, expected])
	if frames % 7 != 0:
		return
	var captain: Node2D = GameManager.player
	var target := Vector2(0, 1000) + Vector2.from_angle(GameManager.elapsed_time * 0.36) * 175.0
	var direction := captain.global_position.direction_to(target)
	for enemy in EntityFactory.get_enemies_in_radius(captain.global_position, 125.0):
		if is_instance_valid(enemy) and enemy.is_active:
			var offset: Vector2 = captain.global_position - enemy.global_position
			direction += offset.normalized() * (1.0 - minf(1.0, offset.length() / 125.0))
	GameManager.set_touch_move_vector(direction.normalized())

func _finish() -> void:
	finished = true
	var fit := forecasts.size() >= 4
	for row in forecasts.values():
		fit = fit and row.font > 0 and row.width <= row.room + 1
	var summary: Dictionary = arena.get_node("GameOverScreen").displayed_summary.get("endless_rotation", {})
	var result := {"seed": GameManager.current_run_seed, "view": get_viewport().get_visible_rect().size, "seconds": snappedf(GameManager.elapsed_time, 0.1), "kills": GameManager.kills, "outcome": "defeat" if GameManager.is_game_over else "observation_end", "observations": observations, "forecasts": forecasts, "settlement": summary, "best": GameManager.endless_best.get("garden", {}), "fit": fit}
	print("R49_ENDLESS_NATURAL " + JSON.stringify(result))
	GameManager.set_touch_move_vector(Vector2.ZERO)
	get_tree().quit(0 if observations.size() >= 2 and fit and frames < 12000 else 1)
