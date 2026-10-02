extends Node

const ARENA := preload("res://scenes/arena/Arena.tscn")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const SIZES: Array[Vector2i] = [Vector2i(844,390),Vector2i(390,844),Vector2i(1024,768),Vector2i(768,1024)]
var failures: Array[String] = []


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	GameManager.campaign_save_path = "user://r36_touch_clearance_campaign.cfg"
	GameManager.wallet_gold = 0
	MetaProgress.debug_use_save_path("user://r36_touch_clearance_meta.cfg",true)
	PlayerSettings.debug_use_save_path("user://r36_touch_clearance_settings.cfg",true)
	AchievementProgress.debug_use_save_path("user://r36_touch_clearance_achievements.cfg",true)
	GameManager.set_process(false)
	for dimensions in SIZES:
		MOBILE.set_device_hints_override_for_tests({"ua_mobile":true,"ua_phone":mini(dimensions.x,dimensions.y)<600,"ua_tablet":mini(dimensions.x,dimensions.y)>=600,"touch_available":true,"primary_coarse":true,"mouse_available":false})
		var viewport := SubViewport.new()
		viewport.size = dimensions
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var arena := ARENA.instantiate()
		viewport.add_child(arena)
		await get_tree().process_frame
		arena.get_node("EnemySpawner").set_process(false)
		GameManager.waiting_for_upgrade = false
		GameManager.waiting_for_contract = false
		GameManager.system_pause_owners.clear()
		get_tree().paused = false
		GameManager.xp_required = 9999999
		for frame in range(10):
			await get_tree().process_frame
		GameManager.emit_stats()
		for frame in range(4):
			await get_tree().process_frame
		var hud: Node = arena.get_node("HUD")
		var controls := {"joystick":hud.virtual_joystick,"summon":hud.summon_button,"auto":hud.auto_button,"ability":hud.active_ability_button,"equipment":hud.equipment_panel}
		var visible: Array[String] = []
		var screen := Rect2(Vector2.ZERO,Vector2(dimensions))
		for key in controls:
			var control: Control = controls[key]
			if not control.is_visible_in_tree():
				continue
			visible.append(key)
			var rect := control.get_global_rect()
			_check(screen.encloses(rect), "%s outside %s: %s" % [key,dimensions,rect])
			print("R36_TOUCH_RECT size=%s control=%s rect=%s" % [dimensions,key,rect])
		for first in range(visible.size()):
			for second in range(first+1,visible.size()):
				var left: Control = controls[visible[first]]
				var right: Control = controls[visible[second]]
				_check(not left.get_global_rect().intersects(right.get_global_rect()),"touch overlap %s %s/%s" % [dimensions,visible[first],visible[second]])
		_check(visible.has("joystick") and visible.has("summon") and visible.has("auto"),"touch core controls hidden")
		var stable_updates: int = hud.ability_layout_updates
		for frame in range(30):
			await get_tree().process_frame
		_check(hud.ability_layout_updates == stable_updates, "unchanged HUD rewrites static layout every frame")
		GameManager.auto_upgrade_enabled = not GameManager.auto_upgrade_enabled
		await get_tree().process_frame
		_check(hud.ability_layout_updates > stable_updates, "auto toggle did not invalidate HUD layout")
		_check(hud.auto_button.text.ends_with("開" if GameManager.auto_upgrade_enabled else "關"), "auto label remained stale")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://docs/evidence/r36/touch")
			viewport.get_texture().get_image().save_png("res://docs/evidence/r36/touch/%dx%d.png" % [dimensions.x,dimensions.y])
		GameManager.game_running = false
		viewport.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	MOBILE.set_device_hints_override_for_tests({})
	if failures.is_empty():
		print("R36_TOUCH_CLEARANCE_PASS sizes=4 actual_controls=joystick,summon,auto,ability,equipment bounds=true pairwise_overlap=0")
		get_tree().quit(0)
	else:
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("R36_TOUCH_CLEARANCE_FAIL: "+message)
