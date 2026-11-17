extends Node

# R48 natural run on 時輪工坊 (the forge): real spawner, elites, seals and the
# reaper at a fixed seed. No HP, damage or time is touched; the bot only moves
# the captain with the touch stick (the input a phone sends), picks formations
# like the R44 long run, and skips shops. What it does with a gear core is the
# strategy under test:
# - far / near: walk onto the core, carry it to that socket;
# - ignore: never touch a core.
# route=direct walks straight (R47's bot); route=careful also steps away from
# enemies and enemy shots close to the captain, the way a player threads a crowd.
# Usage: --headless --fixed-fps 60 --path . res://scenes/debug/ForgeCoreNaturalRun.tscn -- seed=48101 strategy=far route=direct
var arena: Node
var finished := false
var seed_value := 48101
var strategy := "far"
var route := "direct"
var decision_timer := 0.0
var frames := 0
var started := 0
var min_hp := 1.0
var cores: Dictionary = {}

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		var pair := argument.split("=", true, 1)
		if pair.size() != 2:
			continue
		match pair[0]:
			"seed": seed_value = int(pair[1])
			"strategy": strategy = pair[1]
			"route": route = pair[1]
	GameManager.campaign_save_path = "user://r48_forge_sim_campaign.cfg"
	GameManager.campaign_clears.clear()
	GameManager.wallet_gold = 0
	GameManager.forced_run_seed = seed_value
	GameManager.selected_stage_id = "forge"
	GameManager.tactical_launch = false
	MetaProgress.debug_use_save_path("user://r48_forge_sim_meta.cfg", true)
	PlayerSettings.debug_use_save_path("user://r48_forge_sim_settings.cfg", true)
	AchievementProgress.debug_use_save_path("user://r48_forge_sim_achievements.cfg", true)
	AudioManager.set_muted(true)
	seed(seed_value)
	call_deferred("_start")

func _start() -> void:
	arena = preload("res://scenes/arena/Arena.tscn").instantiate()
	add_child(arena)
	GameManager.auto_upgrade_enabled = true
	GameManager.player.set_auto_channel_enabled(true)
	started = Time.get_ticks_msec()

func _track_cores() -> void:
	for core in get_tree().get_nodes_in_group("forge_cores"):
		var id := core.get_instance_id()
		if not cores.has(id):
			cores[id] = {"node": core, "drop_t": GameManager.elapsed_time, "pick_t": -1.0, "end_t": -1.0, "result": "open", "socket": "", "drops": 0, "boss": false}
	for id in cores:
		var row: Dictionary = cores[id]
		if row.result != "open":
			continue
		var core: Variant = row.node
		if not is_instance_valid(core):
			row.result = "removed"
			continue
		if bool(core.get("carried")) and float(row.pick_t) < 0.0:
			row.pick_t = GameManager.elapsed_time
		var drops: Variant = core.get("drops")
		row.drops = int(drops) if drops != null else 0
		if bool(core.get("done")):
			row.end_t = GameManager.elapsed_time
			row.result = "set" if bool(core.get("solved")) else "overload"
			row.socket = str(core.get("socket_used"))
			row.boss = bool(core.get("boss_delayed"))

func _open_core() -> Node2D:
	for core in get_tree().get_nodes_in_group("forge_cores"):
		if core is Node2D and not bool(core.get("done")):
			return core
	return null

func _repel(captain: Node2D, reach: float) -> Vector2:
	var repel := Vector2.ZERO
	for enemy in EntityFactory.get_enemies_in_radius(captain.global_position, reach):
		if not is_instance_valid(enemy) or not enemy.is_active:
			continue
		var offset: Vector2 = captain.global_position - enemy.global_position
		if offset.length_squared() < reach * reach and offset.length_squared() > 1:
			repel += offset.normalized() * (1.0 - offset.length() / reach)
	return repel

func _shot_repel(captain: Node2D, reach: float) -> Vector2:
	var repel := Vector2.ZERO
	for shot in EntityFactory.active_enemy_projectiles:
		if not is_instance_valid(shot) or shot.get("is_active") != true or not shot is Node2D:
			continue
		var offset: Vector2 = captain.global_position - (shot as Node2D).global_position
		if offset.length_squared() < reach * reach and offset.length_squared() > 1:
			repel += offset.normalized() * (1.0 - offset.length() / reach)
	return repel

func _process(delta: float) -> void:
	if finished or not is_instance_valid(arena):
		return
	frames += 1
	_track_cores()
	if Time.get_ticks_msec() - started > 900000 or frames > 27000:
		_finish("timeout")
		return
	if GameManager.boss_killed:
		_finish("win")
		return
	if GameManager.is_game_over:
		_finish("death")
		return
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
	var direction := Vector2.ZERO
	var core := _open_core() if strategy != "ignore" else null
	if core != null:
		var target: Vector2 = core.socket_global(strategy) if bool(core.get("carried")) else core.to_global(core.core_at)
		direction = captain.global_position.direction_to(target)
		if route == "careful":
			# Most hits on a carry are enemy shots: step aside from those close by too.
			var repel := _repel(captain, 90.0) + _shot_repel(captain, 120.0)
			if repel.length() > 0.3:
				direction = (direction * 1.4 + repel.limit_length(1.0)).normalized()
	else:
		# The R44 orbit: circle within pickup range, turn away from nearby threats.
		var center := Vector2(0, 1000)
		var target := center + Vector2.from_angle(time * 0.36 + float(seed_value % 8)) * 175.0
		direction = captain.global_position.direction_to(target)
		var repel := _repel(captain, 125.0)
		if repel.length() > 0.3:
			direction = (direction + repel.limit_length(1.3)).normalized()
	var desired := "ring" if captain.current_hp < captain.max_hp * 0.5 else "wedge" if GameManager.boss_active else "scatter"
	GameManager.squad_manager.set_formation(desired)
	GameManager.set_touch_move_vector(direction)
	if time >= 330:
		_finish("time_limit")

func _finish(outcome: String) -> void:
	finished = true
	_track_cores()
	var rows: Array = []
	var tally := {"dropped": 0, "set_far": 0, "set_near": 0, "overload": 0, "removed": 0, "hit_drops": 0, "boss_delays": 0}
	for id in cores:
		var row: Dictionary = cores[id]
		row.erase("node")
		rows.append(row)
		tally.dropped += 1
		tally.hit_drops += int(row.drops)
		match str(row.result):
			"set":
				tally["set_" + str(row.socket)] += 1
				if bool(row.boss): tally.boss_delays += 1
			"overload": tally.overload += 1
			_: tally.removed += 1
	var result := {"seed": seed_value, "strategy": strategy, "route": route, "outcome": outcome, "seconds": snappedf(GameManager.elapsed_time, 0.1), "boss_kill": GameManager.boss_killed, "min_hp_ratio": snappedf(min_hp, 0.01), "kills": GameManager.kills, "level": GameManager.level, "tally": tally, "gm": {"cast": GameManager.forge_cores_cast, "set": GameManager.forge_cores_set, "far": GameManager.forge_cores_far, "hits": GameManager.forge_core_hits}, "cores": rows, "wall_seconds": float(Time.get_ticks_msec() - started) / 1000.0, "note": "並發載量測，時間僅供參考"}
	print("R48_FORGE_RUN " + JSON.stringify(result))
	# Remove only this runner's isolated save files.
	var directory := DirAccess.open("user://")
	if directory != null:
		for filename in directory.get_files():
			if filename.begins_with("r48_forge_sim_"):
				directory.remove(filename)
	get_tree().quit(1 if outcome == "timeout" else 0)
