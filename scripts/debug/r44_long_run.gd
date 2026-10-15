extends Node

# Real fixed-step Arena simulation. No direct HP/DPS/time manipulation.
# The controller only chooses movement, formation and available shop actions.
var arena: Node
var finished := false
var seed_value := 44101
var stage := "moon"
var guard_enabled := true
var policy := "orbit"
var min_hp := 1.0
var decision_timer := 0.0
var frames := 0
var started := 0
var sample_history: Array[Dictionary] = []

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		var pair := argument.split("=", true, 1)
		if pair.size() != 2:
			continue
		match pair[0]:
			"seed": seed_value = int(pair[1])
			"stage": stage = pair[1]
			"guard": guard_enabled = pair[1] == "1"
			"policy": policy = pair[1]
	GameManager.campaign_save_path = "user://r44_sim_campaign.cfg"
	GameManager.campaign_clears.clear()
	GameManager.wallet_gold = 0
	GameManager.forced_run_seed = seed_value
	GameManager.selected_stage_id = stage
	GameManager.tactical_launch = false
	MetaProgress.debug_use_save_path("user://r44_sim_meta.cfg", true)
	PlayerSettings.debug_use_save_path("user://r44_sim_settings.cfg", true)
	AchievementProgress.debug_use_save_path("user://r44_sim_achievements.cfg", true)
	seed(seed_value)
	call_deferred("_start")

func _start() -> void:
	arena = preload("res://scenes/arena/Arena.tscn").instantiate()
	add_child(arena)
	GameManager.auto_upgrade_enabled = true
	GameManager.player.set_auto_channel_enabled(true)
	started = Time.get_ticks_msec()

func _process(delta: float) -> void:
	if finished or not is_instance_valid(arena):
		return
	frames += 1
	if Time.get_ticks_msec() - started > 480000 or frames > 27000:
		_finish("timeout")
		return
	if GameManager.boss_killed:
		_finish("win")
		return
	if GameManager.is_game_over:
		_finish("death")
		return
	var director: Node = GameManager.tactical_director
	# Paired control isolates only the new half-HP escort, keeping hunt elites.
	if not guard_enabled and is_instance_valid(director) and director.boss_guard_at >= 0:
		director.boss_guard_spawned = true
	if GameManager.waiting_for_shop:
		GameManager.apply_shop_purchase({"id":"skip"})
	if get_tree().paused:
		return
	var captain: Node2D = GameManager.player
	if not is_instance_valid(captain):
		return
	min_hp = minf(min_hp, captain.current_hp / captain.max_hp)
	decision_timer -= delta
	if decision_timer > 0:
		return
	decision_timer = 0.12
	var time: float = GameManager.elapsed_time
	if int(time) % 30 == 0 and (sample_history.is_empty() or time - float(sample_history[-1].time) > 1):
		sample_history.append({"time":time,"hp":captain.current_hp,"level":GameManager.level,"kills":GameManager.kills,"members":GameManager.squad_manager.get_member_count()})
	var direction := Vector2.ZERO
	if policy != "idle":
		# Circle within pickup range, turn outward away from nearby threats.
		var center := Vector2(0, 1000)
		var radius := 175.0
		var target := center + Vector2.from_angle(time * 0.36 + float(seed_value % 8)) * radius
		direction = captain.global_position.direction_to(target)
		var repel := Vector2.ZERO
		for enemy in EntityFactory.get_enemies_in_radius(captain.global_position, 125.0):
			if not is_instance_valid(enemy) or not enemy.is_active:
				continue
			var offset: Vector2 = captain.global_position - enemy.global_position
			if offset.length_squared() < 125.0 * 125.0 and offset.length_squared() > 1:
				repel += offset.normalized() * (1.0 - offset.length() / 125.0)
		if repel.length() > 0.3:
			direction = (direction + repel.limit_length(1.3)).normalized()
		var squad: Node = GameManager.squad_manager
		var desired := "ring" if captain.current_hp < captain.max_hp * 0.5 else "wedge" if GameManager.boss_active else "scatter"
		squad.set_formation(desired)
	GameManager.set_touch_move_vector(direction)
	if time >= 330:
		_finish("time_limit")

func _finish(outcome: String) -> void:
	finished = true
	var director: Node = GameManager.tactical_director
	var result := {"stage":stage,"seed":seed_value,"guard_enabled":guard_enabled,"policy":policy,"outcome":outcome,"seconds":GameManager.elapsed_time,"boss_spawn":GameManager.boss_spawn_time,"phase_two":GameManager.boss_phase_two_time,"boss_kill":GameManager.boss_kill_time,"guard_history":director.guard_history if is_instance_valid(director) else [],"min_hp_ratio":min_hp,"kills":GameManager.kills,"level":GameManager.level,"samples":sample_history,"wall_seconds":float(Time.get_ticks_msec()-started)/1000.0,"performance_note":"並發載量測，僅供參考"}
	var output := "res://docs/evidence/r44-store/long-run/%s-%d-%s-%s.json" % [stage,seed_value,"guard" if guard_enabled else "control",policy]
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("R44_LONG_RUN " + JSON.stringify(result))
	get_tree().quit(1 if outcome == "timeout" else 0)
