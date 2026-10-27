extends Node

const ARENA_SCENE := preload("res://scenes/arena/Arena.tscn")
const RUN_THEME := preload("res://scripts/arena/run_theme.gd")
const OUT := "res://docs/evidence/r34/art/composition/"
var arena: Node
var leader: Node2D


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var args := OS.get_cmdline_user_args()
	var theme := str(args[0]) if not args.is_empty() else "rift_void"
	if theme not in RUN_THEME.get_theme_ids():
		_fail("unknown theme")
		return
	GameManager.forced_run_seed = 34020
	GameManager.level_up_requested.connect(_on_upgrade_requested)
	arena = ARENA_SCENE.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	if arena.first_run_guide != null:
		arena.first_run_guide.hide()
	GameManager._clear_system_pauses()
	get_tree().paused = false
	leader = GameManager.player
	if leader == null or not is_instance_valid(leader):
		_fail("actual arena leader unavailable")
		return
	var bg: Node = arena.get_node("Background")
	bg.configure_run_theme(34020, theme)
	GameManager.set_current_run_theme(theme, RUN_THEME.get_theme_name(theme))
	GameManager.set_touch_move_vector(Vector2.ZERO)
	var until := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
	var state: Dictionary = bg.get_r34_debug_state()
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null or bg.ground_sprite.texture == null:
		_fail("actual camera / raster absent")
		return
	if not (state["map_world_span"] as Vector2).is_equal_approx(Vector2(1240.0, 790.0)):
		_fail("composition span was not applied")
		return
	if bool(state["mirror_repeat"]) or bg.ground_sprite.texture_repeat != CanvasItem.TEXTURE_REPEAT_DISABLED:
		_fail("whole-map mirror / repeat remains")
		return
	var playable: Rect2 = bg.get_playable_rect()
	if not playable.has_point(leader.global_position):
		_fail("hero starts beyond safe ground bounds")
		return
	var center_before: Vector2 = leader.global_position
	var origin_before: Vector2 = state["floor_origin"]
	var reloads: int = state["texture_reload_count"]
	await _capture(theme + "_actual_arena.png")
	GameManager.set_touch_move_vector(Vector2(0.45, 0.14))
	var deadline := Time.get_ticks_msec() + 5000
	while leader.global_position.distance_to(center_before) < 70.0 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	GameManager.set_touch_move_vector(Vector2.ZERO)
	await get_tree().process_frame
	await get_tree().process_frame
	var moved_state: Dictionary = bg.get_r34_debug_state()
	var origin_after: Vector2 = moved_state["floor_origin"]
	var movement := leader.global_position - center_before
	# View-size changes from threat zoom are accounted for separately from
	# world movement. The map source never changes while either occurs.
	var span_before: Vector2 = state["world_span"]
	var span_after: Vector2 = moved_state["world_span"]
	var render_before: Vector2 = state["render_center"]
	var render_after: Vector2 = moved_state["render_center"]
	if not (origin_after - origin_before + (span_after - span_before) * 0.5).is_equal_approx(render_after - render_before):
		_fail("movement lost world anchoring")
		return
	if int(moved_state["texture_reload_count"]) != reloads or movement.length() < 70.0:
		_fail("movement reloaded texture / did not execute")
		return
	await _capture(theme + "_actual_move.png")
	var world_view: Vector2 = get_viewport().get_visible_rect().size / camera.zoom
	var fraction: Vector2 = world_view / Vector2(1240.0, 790.0)
	var record := {"theme": theme, "background": state, "camera_zoom": camera.zoom, "normal_battle_view_fraction": fraction, "actual_hero_movement": movement, "world_anchored": true, "texture_reloads_on_move": 0, "mirror_repeat": false, "single_map_sample": true, "capture_mode": "actual_Arena_default_camera"}
	var json := FileAccess.open(OUT + theme + "_actual_arena.json", FileAccess.WRITE)
	json.store_string(JSON.stringify(record, "\t"))
	json.close()
	print("R34_COMPOSITION_PASS theme=%s actual_Arena=true default_camera=%s map_span=1240x790 view_fraction=%s mirror_repeat=false world_anchor=true moved=%.2f" % [theme, camera.zoom, fraction, movement.length()])
	get_tree().quit(0)


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	if pixels.save_png(OUT + filename) != OK:
		_fail("native capture failed")


func _fail(message: String) -> void:
	printerr("R34_COMPOSITION_FAIL: " + message)
	get_tree().quit(1)


func _on_upgrade_requested(choices: Array) -> void:
	if not choices.is_empty():
		call_deferred("_apply_upgrade", choices[0])


func _apply_upgrade(choice: Dictionary) -> void:
	if GameManager.waiting_for_upgrade:
		GameManager.apply_upgrade(choice)
