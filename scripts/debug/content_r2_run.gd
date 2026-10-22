extends Node

# Same game/seed/roster and automatic upgrades on both policies. The active
# policy changes ONLY movement/formation, never HP, elapsed time, enemies or DPS.
var arena: Node
var policy := "active"
var stage := "moon"
var roster := "default"
var seed_value := 55210
var minimum_hp := 1.0
var decisions := 0.0
var finished := false
var samples: Array = []
var wall_start := 0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=",true,1)
		if pair.size()!=2: continue
		match pair[0]:
			"policy": policy=pair[1]
			"stage": stage=pair[1]
			"seed": seed_value=int(pair[1])
			"roster": roster=pair[1]
	AudioManager.set_muted(true)
	AudioManager.unlock_audio()
	GameManager.campaign_save_path="user://content_r2_run_campaign.cfg"
	GameManager.campaign_clears.clear()
	MetaProgress.debug_use_save_path("user://content_r2_run_meta.cfg",true)
	PlayerSettings.debug_use_save_path("user://content_r2_run_settings.cfg",true)
	AchievementProgress.debug_use_save_path("user://content_r2_run_achievements.cfg",true)
	GameManager.forced_run_seed=seed_value
	GameManager.selected_stage_id=stage
	GameManager.tactical_launch=false
	seed(seed_value)
	arena=preload("res://scenes/arena/Arena.tscn").instantiate()
	if roster=="harmony":
		var squad: Node=arena.get_node("SquadManager")
		squad.squad_data=squad.squad_data.duplicate(true)
		squad.squad_data.starting_heroes.assign([load("res://resources/heroes/rift_captain.tres"),load("res://resources/heroes/orbit_guard.tres"),load("res://resources/heroes/echo_singer.tres")])
	add_child(arena)
	GameManager.auto_upgrade_enabled=true
	GameManager.player.set_auto_channel_enabled(true)
	wall_start=Time.get_ticks_msec()

func _process(delta: float) -> void:
	if finished or not is_instance_valid(arena): return
	if GameManager.stage_victory_pending:
		_finish("win")
		return
	if GameManager.is_game_over:
		_finish("death")
		return
	if GameManager.elapsed_time>=180 or Time.get_ticks_msec()-wall_start>360000:
		_finish("no_clear")
		return
	if GameManager.waiting_for_shop: GameManager.apply_shop_purchase({"id":"skip"})
	if get_tree().paused: return
	var captain: Node=GameManager.player
	minimum_hp=minf(minimum_hp,captain.current_hp/captain.max_hp)
	decisions-=delta
	if decisions>0:return
	decisions=0.10
	var relay: Node=GameManager.tactical_director.relay
	var squad: Node=GameManager.squad_manager
	if samples.is_empty() or GameManager.elapsed_time-float(samples[-1].time)>10:
		samples.append({"time":GameManager.elapsed_time,"hp":captain.current_hp,"seals":relay.step,"hold":relay.hold,"kills":GameManager.kills,"level":GameManager.level})
		print("CONTENT_R2_PROGRESS stage=%s policy=%s t=%.1f seals=%d hold=%.1f" % [stage,policy,GameManager.elapsed_time,relay.step,relay.hold])
	var direction:=Vector2.ZERO
	if policy=="active":
		var target: Vector2=relay.anchor
		if not relay.completed:
			squad.set_formation(relay.required_formation())
			if not relay.is_open():
				target+=Vector2.from_angle(GameManager.elapsed_time*0.8)*90
			elif relay.pressure.phase in ["warning","active"]:
				if relay.pressure.kind=="front":target+=Vector2(-46,0)
				elif relay.pressure.kind=="artillery":
					var best := -1.0
					for i in range(16):
						var candidate: Vector2=relay.anchor+Vector2.from_angle(i*TAU/16)*50
						var clearance := 1000.0
						for mark in relay.pressure.targets:
							clearance=minf(clearance,candidate.distance_to(mark))
						if clearance>best:
							best=clearance
							target=candidate
			else:
				# Already inside the rune: stop so followers settle naturally.
				if captain.global_position.distance_to(target)<28:target=captain.global_position
		else:
			squad.set_formation("ring" if captain.current_hp<captain.max_hp*0.5 else "wedge")
			var nearest: Node=EntityFactory.find_nearest_enemy(captain.global_position,1600)
			if is_instance_valid(nearest):
				target=nearest.global_position+Vector2.from_angle(GameManager.elapsed_time)*80
		if captain.global_position.distance_to(target)>10:direction=captain.global_position.direction_to(target)
	GameManager.set_touch_move_vector(direction)

func _finish(outcome: String) -> void:
	finished=true
	var relay: Node=GameManager.tactical_director.relay
	var result: Dictionary={"status":"EXECUTED","stage":stage,"policy":policy,"seed":seed_value,"roster":roster,"outcome":outcome,"time":GameManager.elapsed_time,"boss_spawn":GameManager.boss_spawn_time,"boss_half":GameManager.boss_phase_two_time,"boss_death":GameManager.boss_kill_time,"seals":relay.step,"history":relay.history,"wrong":relay.wrong_penalties,"minimum_hp_ratio":minimum_hp,"kills":GameManager.kills,"level":GameManager.level,"contributions":GameManager.contribution,"bond":GameManager.bond_benefits,"samples":samples,"guards":GameManager.tactical_director.guard_history,"campaign_clear":GameManager.campaign_clears.has(stage),"wall_seconds":(Time.get_ticks_msec()-wall_start)/1000.0}
	DirAccess.make_dir_recursive_absolute("res://docs/content/r2/tests/runs")
	var file:=FileAccess.open("res://docs/content/r2/tests/runs/%s-%d-%s-%s.json"%[stage,seed_value,roster,policy],FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("CONTENT_R2_RUN "+JSON.stringify(result))
	get_tree().quit(0)
