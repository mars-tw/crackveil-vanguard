extends Node

const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
var failures: Array[String] = []
var results: Array = []

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	# Keep this supervisor alive across actual current_scene replacements.
	get_tree().current_scene = null
	call_deferred("_run")

func _run() -> void:
	GameManager.campaign_save_path = "user://content_r1_navigation_campaign.cfg"
	MetaProgress.debug_use_save_path("user://content_r1_navigation_meta.cfg",true)
	PlayerSettings.debug_use_save_path("user://content_r1_navigation_settings.cfg",true)
	AchievementProgress.debug_use_save_path("user://content_r1_navigation_achievement.cfg",true)
	MOBILE.set_device_hints_override_for_tests({"ua_phone":true,"ua_mobile":true,"touch_available":true,"primary_coarse":true,"mouse_available":false})
	for iteration in range(4):
		GameManager.forced_run_seed = 55210 + iteration
		GameManager.selected_stage_id = "moon"
		GameManager.tactical_launch = false
		get_tree().change_scene_to_file("res://scenes/arena/Arena.tscn")
		await get_tree().process_frame
		await get_tree().process_frame
		GameManager.auto_upgrade_enabled = true
		GameManager.player.set_auto_channel_enabled(true)
		for frame in range(900):
			if not GameManager.game_running:
				break
			var relay: Node = GameManager.tactical_director.relay
			if not relay.completed:
				var required: String = relay.ORDER[relay.step]
				if GameManager.squad_manager.formation_id != required:
					GameManager.squad_manager.set_formation(required)
				var delta: Vector2 = relay.anchor - GameManager.player.global_position
				GameManager.set_touch_move_vector(delta.normalized() if delta.length() > 45 else Vector2.ZERO)
			else:
				GameManager.set_touch_move_vector(Vector2.ZERO)
			await get_tree().physics_frame
			await get_tree().process_frame
		GameManager.set_touch_move_vector(Vector2.ZERO)
		var elapsed: float = GameManager.elapsed_time
		var hud: Node = GameManager.arena.get_node("HUD")
		hud._on_pause_button_pressed()
		await get_tree().process_frame
		var kills_before: int = GameManager.kills
		hud._on_pause_menu_pressed()
		for frame in range(5):
			await get_tree().process_frame
		var returned: bool = get_tree().current_scene != null and get_tree().current_scene.name == "MainMenu"
		if not returned:
			failures.append("retreat did not return to actual MainMenu")
		if GameManager.kills != kills_before:
			failures.append("detached animation awarded a kill after retreat")
		if not EntityFactory.enemy_animation_client_slots.is_empty():
			failures.append("old animation clients survived arena removal")
		if EntityFactory.enemy_full_death_animation_live != 0 or EntityFactory.enemy_simplified_death_animation_live != 0:
			failures.append("death animation budget was not released")
		results.append({"iteration":iteration,"elapsed":elapsed,"returned":returned,"late_kills":GameManager.kills-kills_before,"remaining_animation_clients":EntityFactory.enemy_animation_client_slots.size()})
		print("CONTENT_R1_NAVIGATION_RETURN iteration=%d elapsed=%.3f returned=%s" % [iteration,elapsed,returned])
	MOBILE.set_device_hints_override_for_tests({})
	DirAccess.make_dir_recursive_absolute("res://docs/content/r1/tests")
	var file := FileAccess.open("res://docs/content/r1/tests/navigation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"VERIFIED" if failures.is_empty() else "BLOCKED","runs":results,"failures":failures},"\t"))
	print("CONTENT_R1_NAVIGATION_%s" % ["PASS" if failures.is_empty() else "FAIL"])
	get_tree().quit(0 if failures.is_empty() else 1)
