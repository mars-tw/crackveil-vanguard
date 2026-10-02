extends Node

const WORLD := preload("res://scripts/ui/world_map.gd")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(844, 390), Vector2i(390, 844), Vector2i(320, 568)]

var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_test")


func _test() -> void:
	var previous_stage: String = GameManager.selected_stage_id
	var previous_clears: Array[String] = GameManager.campaign_clears.duplicate()
	var previous_path: String = GameManager.campaign_save_path
	GameManager.campaign_save_path = "user://r34_campaign_test.cfg"
	GameManager.campaign_clears = ["moon", "ember"]
	for dimensions in SIZES:
		var phone := dimensions.x < 900
		MOBILE.set_device_hints_override_for_tests({"ua_mobile": phone, "ua_phone": phone, "touch_available": phone, "primary_coarse": phone, "mouse_available": not phone})
		var viewport := SubViewport.new()
		viewport.size = dimensions
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var world := WORLD.new()
		viewport.add_child(world)
		for frame in range(4):
			await get_tree().process_frame
		var state: Dictionary = world.get_debug_state()
		_check(state.nodes.size() == 6, "not all six stages on %s" % str(dimensions))
		_check(world.progress.text == "已通關 2／6", "clear indicator missing")
		for node in state.nodes:
			_check(not bool(node.disabled), "stage was locked: " + str(node.id))
			_check(float(node.width) >= 44 and float(node.height) >= 44, "stage touch target too small")
			var box := Rect2(float(node.x), float(node.y), float(node.width), float(node.height))
			_check(box.position.x >= -1 and box.end.x <= dimensions.x + 1, "stage horizontal overflow on %s: %s" % [str(dimensions), str(box)])
		for key in ["start", "back", "details"]:
			var button: Dictionary = state.get(key, {})
			var box := Rect2(float(button.x), float(button.y), float(button.width), float(button.height))
			_check(box.position.x >= -1 and box.position.y >= -1 and box.end.x <= dimensions.x + 1 and box.end.y <= dimensions.y + 1, "%s outside viewport %s: %s" % [key, str(dimensions), str(box)])
		for node in world.node_buttons:
			node.pressed.emit()
			_check(world.selected_id == str(node.get_meta("stage_id")), "node input did not select real stage")
			_check(world.detail_boss.text.contains(str(world.CATALOG.get_stage(world.selected_id).boss_name)), "selected boss preview stale")
			_check(not world.start_button.disabled, "formal start unavailable")
		var before_id := world.selected_id
		world._on_stage_pressed("missing")
		_check(world.selected_id == before_id, "invalid node changed stage")
		if not world.portrait:
			for first in range(world.node_buttons.size()):
				for second in range(first + 1, world.node_buttons.size()):
					_check(not world.node_buttons[first].get_global_rect().intersects(world.node_buttons[second].get_global_rect()), "map nodes overlap on %s" % str(dimensions))
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://docs/evidence/r34/worldmap")
			viewport.get_texture().get_image().save_png("res://docs/evidence/r34/worldmap/%dx%d.png" % [dimensions.x, dimensions.y])
		print("R34_WORLD_MAP_UI size=%s selected=%s portrait=%s nodes=6 all_selectable=true" % [str(dimensions), world.selected_id, world.portrait])
		viewport.queue_free()
		await get_tree().process_frame
	GameManager.selected_stage_id = previous_stage
	GameManager.campaign_clears = previous_clears
	GameManager.campaign_save_path = previous_path
	MOBILE.set_device_hints_override_for_tests()
	if failures.is_empty():
		print("R34_WORLD_MAP_UI_PASS layouts=5 stage_selection=6 clear_indicators=2 formal_start=visible no_overflow=true")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
