extends Node

const WORLD := preload("res://scripts/ui/world_map.gd")
const BACKGROUND := preload("res://scripts/arena/r36_loop_world_background.gd")
const CATALOG := preload("res://scripts/services/stage_catalog.gd")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
var failures: Array[String] = []

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("R38_MAP_FAIL " + message)

func _run() -> void:
	GameManager.campaign_save_path = "user://r38_map_expansion.cfg"
	GameManager.campaign_clears.clear()
	_check(CATALOG.get_stages().size() == 10, "ten real stages missing")
	for dimensions in [Vector2i(1280,720), Vector2i(844,390), Vector2i(390,844), Vector2i(1024,768), Vector2i(768,1024)]:
		MOBILE.set_device_hints_override_for_tests({"ua_mobile":dimensions.x<1100,"ua_tablet":mini(dimensions.x,dimensions.y)>=600 and dimensions.x<1100,"touch_available":dimensions.x<1100,"mouse_available":dimensions.x>=1100})
		var viewport := SubViewport.new()
		viewport.size = dimensions
		add_child(viewport)
		var world := WORLD.new()
		viewport.add_child(world)
		await get_tree().process_frame
		await get_tree().process_frame
		for chapter in range(2):
			world._on_chapter_pressed(chapter)
			for frame in range(4):
				await get_tree().process_frame
			var state: Dictionary = world.get_debug_state()
			_check(state.nodes.size()==10 and state.chapters.size()==2, "chapter controls missing")
			var visible: Array[Rect2] = []
			for entry in state.nodes:
				if not entry.visible:
					continue
				var rect := Rect2(entry.x,entry.y,entry.width,entry.height)
				_check(rect.size.x>=44 and rect.size.y>=44, "stage touch target too small")
				_check(rect.position.x>=0 and rect.end.x<=dimensions.x+1, "stage horizontal overflow")
				if not world.portrait:
					for previous in visible:
						_check(not rect.intersects(previous), "chapter nodes overlap")
				visible.append(rect)
			_check(visible.size()==(6 if chapter==0 else 4), "chapter visible count incorrect")
			for entry in state.chapters:
				_check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(Rect2(entry.x,entry.y,entry.width,entry.height)), "chapter tab outside viewport")
			for index in range(chapter*6, mini(chapter*6+6,10)):
				world.node_buttons[index].pressed.emit()
				_check(world.selected_id==str(CATALOG.get_stages()[index].id), "real stage selection failed")
		print("R38_CHAPTER_UI size=%s all10=true two_pages=true" % dimensions)
		viewport.queue_free()
		await get_tree().process_frame
	MOBILE.set_device_hints_override_for_tests({})
	var field := BACKGROUND.new()
	add_child(field)
	await get_tree().process_frame
	var uids: Array = field.get_r36_debug_state().landmark_node_uids
	for stage in CATALOG.get_stages():
		field.configure_run_theme(38123,str(stage.theme_id))
		var state: Dictionary = field.get_r36_debug_state()
		_check(bool(state.bitmap_ready), "missing real biome art " + str(stage.id))
		_check(state.landmark_node_uids==uids, "biome switch reallocated landmarks")
		_check(field.get_loop_period()==Vector2(4096,3072), "world topology changed")
		print("R38_BIOME id=%s real_bitmap=true nodes=8" % stage.id)
	if failures.is_empty():
		print("R38_MAP_EXPANSION_PASS stages10=true chapters2=true touch5=true bitmaps10=true stable_landmarks=true")
	get_tree().quit(0 if failures.is_empty() else 1)
