extends Node

# Deterministic review fixture, excluded from the production Web preset with
# all scripts/debug and scenes/debug. Never a production gameplay route.
var arena: Node
var scenario := "wedge"
var times: Array[float] = [3.0]
var index := 0
var frozen := false
var recruited := false
var factory_process_mode := Node.PROCESS_MODE_INHERIT
var frozen_kills := 0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	if not OS.is_debug_build() or not OS.has_feature("web"):
		get_tree().quit(1)
		return
	scenario = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('scenario') || 'wedge'",true))
	if scenario not in ["wedge","ring","scatter","bond","dense"]:
		get_tree().quit(1)
		return
	GameManager.campaign_save_path = "user://content_r1_review_campaign.cfg"
	MetaProgress.debug_use_save_path("user://content_r1_review_meta.cfg",true)
	PlayerSettings.debug_use_save_path("user://content_r1_review_settings.cfg",true)
	AchievementProgress.debug_use_save_path("user://content_r1_review_achievement.cfg",true)
	GameManager.wallet_gold = 0
	GameManager.forced_run_seed = 55210
	GameManager.selected_stage_id = "moon"
	GameManager.tactical_launch = false
	factory_process_mode = EntityFactory.process_mode
	AudioManager.set_muted(true)
	AudioManager.unlock_audio()
	if scenario == "bond":
		times = [2.1,2.6,3.1]
	elif scenario == "dense":
		times = [34.0,34.2]
	arena = preload("res://scenes/arena/Arena.tscn").instantiate()
	add_child(arena)
	var squad: Node = GameManager.squad_manager
	squad.formation_id = "ring" if scenario == "bond" else scenario if scenario != "dense" else "wedge"
	GameManager.auto_upgrade_enabled = true
	GameManager.player.set_auto_channel_enabled(true)
	GameManager.emit_stats()

func _process(_delta: float) -> void:
	if not is_instance_valid(arena):
		return
	if scenario in ["wedge","ring","scatter"]:
		# Identical no-equipment growth condition for the three comparisons.
		# Normal capture/reviewer paths exercise real pickup and progression.
		for drop in get_tree().get_nodes_in_group("equipment_drops"):
			drop.set_physics_process(false)
	if scenario == "bond" and not recruited and GameManager.elapsed_time >= 2.0:
		recruited = true
		GameManager.squad_manager.recruit_hero("echo_singer")
	if frozen:
		assert(GameManager.kills == frozen_kills,"review sample changed while frozen")
		if bool(JavaScriptBridge.eval("window.__cvContentR1Next === true",true)) and index + 1 < times.size():
			JavaScriptBridge.eval("window.__cvContentR1Next = false; window.__cvContentR1Sample = null;",true)
			index += 1
			frozen = false
			arena.process_mode = PROCESS_MODE_INHERIT
			EntityFactory.process_mode = factory_process_mode
			GameManager.set_process(true)
		return
	if GameManager.elapsed_time < times[index]:
		return
	frozen = true
	arena.process_mode = PROCESS_MODE_DISABLED
	EntityFactory.process_mode = PROCESS_MODE_DISABLED
	GameManager.set_process(false)
	frozen_kills = GameManager.kills
	# Stats normally refresh periodically. Publish this exact frozen timestep
	# so the visible clock and HP agree with the comparison metadata.
	GameManager.emit_stats()
	var squad: Node = GameManager.squad_manager
	var roster: Array = []
	for member in squad.get_members():
		roster.append({"id":member.hero_id,"hp":member.current_hp,"max_hp":member.max_hp,"position":[member.global_position.x,member.global_position.y]})
	var payload := {"scenario":scenario,"sample":index,"time":GameManager.elapsed_time,"seed":GameManager.current_run_seed,"stage":GameManager.selected_stage_id,"level":GameManager.level,"roster":roster,"equipment":GameManager.loot_director.slots,"formation":squad.formation_id,"bond":squad.bond_reveal_text,"kills":GameManager.kills,"enemy_count":EntityFactory.get_enemy_active_count(),"version":ProjectSettings.get_setting("application/config/version")}
	JavaScriptBridge.eval("window.__cvContentR1Sample = " + JSON.stringify(payload),true)
