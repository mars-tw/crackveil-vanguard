extends Node

# R42 證據截圖：實際算圖（非 headless）拍下三種陣形與換陣光環。
const ARENA := preload("res://scenes/arena/Arena.tscn")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")

var arena: Node


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	var phone := "--phone" in OS.get_cmdline_user_args()
	if phone:
		MOBILE.set_device_hints_override_for_tests({"ua_mobile": true, "ua_phone": true, "ua_tablet": false, "touch_available": true, "primary_coarse": true, "mouse_available": false})
	GameManager.campaign_save_path = "user://r42_capture_campaign.cfg"
	PlayerSettings.debug_use_save_path("user://r42_capture_settings.cfg", true)
	MetaProgress.debug_use_save_path("user://r42_capture_meta.cfg", true)
	AchievementProgress.debug_use_save_path("user://r42_capture_achievements.cfg", true)
	arena = ARENA.instantiate()
	add_child(arena)
	for _frame in range(30):
		await get_tree().process_frame
	var squad: Node = GameManager.squad_manager
	for hero_id in ["pulse_artificer", "ember_grenadier", "line_mender", "echo_singer", "void_weaver", "rift_sniper"]:
		squad.recruit_hero(hero_id)
	arena.get_node("EnemySpawner").set_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	DirAccess.make_dir_recursive_absolute("res://docs/evidence/r42/capture")
	var tag := "phone" if phone else "desktop"
	for formation in ["wedge", "ring", "scatter"]:
		squad.formation_cooldown = 0.0
		if squad.get_formation_id() != formation:
			squad.set_formation(formation, true)
		for _frame in range(20):
			await get_tree().process_frame
		await _shot("res://docs/evidence/r42/capture/%s_%s_switch.png" % [tag, formation])
		for _frame in range(100):
			await get_tree().process_frame
		await _shot("res://docs/evidence/r42/capture/%s_%s_settled.png" % [tag, formation])
	print("R42_CAPTURE_DONE " + tag)
	get_tree().quit(0)


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
