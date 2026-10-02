extends Node

const ARENA := preload("res://scenes/arena/Arena.tscn")
const OUT := "res://docs/evidence/r36/native_latest/"
var arena: Node
var hero: Node2D
var background: Node
var held_msec := -1
var released_msec := -1
var cards := 0
var next_card_msec := 0
var captures: Dictionary = {}
var max_fx_scale := 0.0
var peak_fx := 0
var first_uids: Array
var first_loads: int

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	GameManager.select_stage("moon")
	arena = ARENA.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	hero = GameManager.player
	background = arena.get_node("Background")
	var first: Dictionary = background.get_r36_debug_state()
	first_uids = first["landmark_node_uids"]
	first_loads = first["texture_load_count"]
	var start: Vector2 = hero.global_position
	await _capture("south_spawn")
	var deadline := Time.get_ticks_msec() + 120000
	while GameManager.elapsed_time < 20.0:
		if not is_instance_valid(hero) or not bool(hero.get("is_alive")) or Time.get_ticks_msec() > deadline:
			await _capture("natural_stop")
			_fail("normal play stopped before 20s")
			return
		_select_offered_card()
		var elapsed: float = GameManager.elapsed_time
		var goal: Vector2 = Vector2.ZERO if elapsed < 6.0 else Vector2(1400,0) if elapsed < 13.0 else Vector2(990,707)
		GameManager.set_touch_move_vector((goal-hero.global_position).limit_length(1.0))
		if held_msec < 0 and elapsed >= 5.0:
			_key_space(true)
			held_msec = Time.get_ticks_msec()
		if held_msec >= 0 and released_msec < 0 and Time.get_ticks_msec()-held_msec >= 2000:
			_key_space(false)
			released_msec = Time.get_ticks_msec()
		await RenderingServer.frame_post_draw
		var fx: Node = get_tree().get_first_node_in_group("combat_presentation")
		if fx != null:
			peak_fx = maxi(peak_fx,fx.active.size())
			for effect in fx.active:
				max_fx_scale = maxf(max_fx_scale,effect.scale.x)
				if effect.kind == "cyclone" and effect.held and not captures.has("space_large_cyclone"):
					await _capture("space_large_cyclone",true)
		if elapsed >= 4.2 and not captures.has("central_crossing"):
			await _capture("central_crossing",true)
		if elapsed >= 11.5 and not captures.has("east_landmark"):
			await _capture("east_landmark",true)
		if released_msec >= 0 and Time.get_ticks_msec()-released_msec >= 180 and not captures.has("release_180ms"):
			await _capture("release_180ms",true)
		await get_tree().process_frame
	_key_space(false)
	GameManager.set_touch_move_vector(Vector2.ZERO)
	await _capture("final_loop_scene")
	var final: Dictionary = background.get_r36_debug_state()
	var camera: Camera2D = get_viewport().get_camera_2d()
	var visual: Node = hero.get("visual")
	var state := {"actual_Arena":true,"seconds":GameManager.elapsed_time,"natural_kills":GameManager.kills,"normal_ui_cards":cards,"normal_space_hold_ms":released_msec-held_msec,"godmode_or_gold_HP_XP_kill_injections":0,"start_world":start,"final_world":hero.global_position,"captured_landmarks":final["visible_landmarks"],"same_landmark_uids":first_uids==final["landmark_node_uids"],"terrain_reloads":int(final["texture_load_count"])-first_loads,"bitmap_ready":final["bitmap_ready"],"camera_zoom":camera.zoom,"max_observed_fx_scale":max_fx_scale,"peak_active_fx":peak_fx,"hero_sprite_scale":visual.animated_sprite.scale,"latest_background":final,"captures":captures,"mode":"native_PC_actual_play_not_real_tablet_or_phone"}
	var file := FileAccess.open(OUT+"latest_review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(state,"\t"))
	file.close()
	print("R36_LATEST_REVIEW_COMPLETE seconds=%.2f kills=%d fxScale=%.2f fxPeak=%d camera=%s stableUIDs=%s terrainReloads=%d" % [GameManager.elapsed_time,GameManager.kills,max_fx_scale,peak_fx,camera.zoom,state["same_landmark_uids"],state["terrain_reloads"]])
	get_tree().quit(0)

func _select_offered_card() -> void:
	if not GameManager.waiting_for_upgrade or Time.get_ticks_msec()<next_card_msec:
		return
	var screen: Node = arena.level_up_screen
	if screen.root.visible and not screen.option_buttons.is_empty():
		screen.option_buttons[0].pressed.emit()
		cards += 1
		next_card_msec = Time.get_ticks_msec()+300

func _key_space(value: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = value
	Input.parse_input_event(event)

func _capture(label: String, already_drawn: bool = false) -> void:
	if not already_drawn:
		await RenderingServer.frame_post_draw
	var path := OUT+label+".png"
	get_viewport().get_texture().get_image().save_png(path)
	captures[label] = {"path":path,"game_seconds":GameManager.elapsed_time,"hero_world":hero.global_position}

func _fail(message: String) -> void:
	printerr("R36_LATEST_REVIEW_FAIL "+message)
	get_tree().quit(1)
