extends Node

const ARENA_SCENE := preload("res://scenes/arena/Arena.tscn")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const OUT := "res://docs/evidence/r34/art/composition/"
var arena: Node
var leader: Node2D
var background: Node
var portrait := false
var input_frames: int = 0
var upgrade_ui_presses: int = 0
var inspected_enemies: int = 0
var maximum_outside: int = 0
var next_ui_press_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	portrait = "portrait" in OS.get_cmdline_user_args()
	if portrait:
		# Presentation only: emulate the phone's internal viewport and touch UI.
		# Combat health, time, damage, spawn and kill state are never assigned.
		get_window().content_scale_size = Vector2i(720, 1558)
		MOBILE_TUNING.set_device_hints_override_for_tests({"ua_phone": true, "ua_mobile": true, "touch_available": true, "mouse_available": false})
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if not GameManager.select_stage("storm"):
		_fail("public storm selection failed")
		return
	arena = ARENA_SCENE.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	leader = GameManager.player
	background = arena.get_node("Background")
	var target_seconds := 6.0 if portrait else 20.0
	var real_deadline := Time.get_ticks_msec() + 90000
	while GameManager.elapsed_time < target_seconds:
		if leader == null or not is_instance_valid(leader) or not bool(leader.get("is_alive")):
			await _capture("final_arena_storm_natural_defeat.png")
			_fail("natural leader died before target at %.2fs" % GameManager.elapsed_time)
			return
		if Time.get_ticks_msec() > real_deadline:
			_fail("natural run / modal timed out")
			return
		_press_actual_upgrade_ui()
		var bounds: Rect2 = background.get_playable_rect()
		var t: float = GameManager.elapsed_time
		var target := bounds.get_center() + Vector2(cos(t * 0.65) * 145.0, sin(t * 0.65) * 93.0)
		var intent: Vector2 = (target - leader.global_position).limit_length(1.0)
		GameManager.set_touch_move_vector(intent)
		input_frames += 1
		_audit_live_positions(bounds)
		await get_tree().process_frame
	GameManager.set_touch_move_vector(Vector2.ZERO)
	await get_tree().process_frame
	await get_tree().process_frame
	var current_bounds: Rect2 = background.get_playable_rect()
	var final_outside := _audit_live_positions(current_bounds)
	var filename := "final_arena_storm_portrait.png" if portrait else "final_arena_storm.png"
	await _capture(filename)
	var camera: Camera2D = get_viewport().get_camera_2d()
	var state: Dictionary = background.get_r34_debug_state()
	var internal_size := get_viewport().get_visible_rect().size
	var world_view := internal_size / camera.zoom
	var map_rect: Rect2 = background.get_map_world_rect()
	var camera_center := camera.get_screen_center_position()
	var visible_world := Rect2(camera_center - world_view * 0.5, world_view)
	var map_contains_view := map_rect.grow(2.0).encloses(visible_world)
	var record := {"mode": "native_phone_geometry" if portrait else "native_natural_20_second_storm", "selected_stage": GameManager.selected_stage_id, "natural_game_seconds": GameManager.elapsed_time, "hero_hp": leader.get("current_hp"), "hero_max_hp": leader.get("max_hp"), "level": GameManager.level, "observed_kills": GameManager.kills, "normal_move_input_frames": input_frames, "actual_upgrade_ui_presses": upgrade_ui_presses, "godmode_or_kill_state_injections": 0, "beauty_mode": false, "live_enemy_count": EntityFactory.get_enemy_live_count(), "enemy_position_observations": inspected_enemies, "maximum_enemies_outside_playable_rect": maximum_outside, "final_enemies_outside_playable_rect": final_outside, "internal_viewport": internal_size, "camera_zoom": camera.zoom, "visible_world_rect": visible_world, "map_contains_camera_view": map_contains_view, "background": state}
	var json_name := "final_storm_portrait.json" if portrait else "final_storm_natural_20s.json"
	var file := FileAccess.open(OUT + json_name, FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
	if maximum_outside > 0 or final_outside > 0 or not map_contains_view:
		_fail("real runtime found a stage-boundary / camera violation; evidence saved")
		return
	print("R34_FINAL_STORM_PASS portrait=%s natural_seconds=%.2f hp=%.1f/%.1f kills=%d live=%d enemy_observations=%d outside=0 camera_inside=true viewport=%s zoom=%s no_godmode_or_kill_injections=true" % [portrait, GameManager.elapsed_time, leader.get("current_hp"), leader.get("max_hp"), GameManager.kills, EntityFactory.get_enemy_live_count(), inspected_enemies, internal_size, camera.zoom])
	get_tree().quit(0)


func _press_actual_upgrade_ui() -> void:
	if not GameManager.waiting_for_upgrade or Time.get_ticks_msec() < next_ui_press_msec:
		return
	var screen: Node = arena.level_up_screen
	if not screen.root.visible or screen.option_buttons.is_empty():
		return
	# Press an offered card through its real UI callback. Do not fabricate an
	# upgrade dictionary, assign combat stats, or clear the pause state.
	var button: Button = screen.option_buttons[0]
	if not button.disabled:
		button.pressed.emit()
		upgrade_ui_presses += 1
		next_ui_press_msec = Time.get_ticks_msec() + 300


func _audit_live_positions(bounds: Rect2) -> int:
	var outside := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not bool(enemy.get("is_active")) or float(enemy.get("hp")) <= 0.0:
			continue
		inspected_enemies += 1
		if not bounds.grow(0.5).has_point(enemy.global_position):
			outside += 1
	maximum_outside = maxi(maximum_outside, outside)
	return outside


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	if pixels.save_png(OUT + filename) != OK:
		_fail("native PNG save failed")


func _fail(message: String) -> void:
	printerr("R34_FINAL_STORM_FAIL: " + message)
	get_tree().quit(1)
