extends SceneTree

# Run with --fixed-fps 60, an isolated CV_QA_PROFILE, a software renderer,
# --resolution 1280x720 (or 844x390) and -- out=<absolute path> [stage=moon] [seed=55210].
# Starts the normal Arena with default roster and chooses upgrades through the
# visible card controls. No encounter, member, HP, experience or timer injection.
var gm: Node
var arena: Node
var factory: Node
var hud: Node
var out := ""
var stage := "moon"
var run_seed := 55210
var phone := false
var elapsed_frames := 0
var key_state := {}
var captures := {}
var dense_samples := []
var dense_until := -1.0
var max_squad := 0
var largest_on_screen := 0
var longest_missing_seconds := 0.0
var missing_since := -1.0
var crowd_finished := false
var last_status := -1
var input_events := 0

func _initialize() -> void:
	await process_frame
	gm = root.get_node("GameManager")
	factory = root.get_node("EntityFactory")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="): out = arg.trim_prefix("out=")
		if arg.begins_with("stage="): stage = arg.trim_prefix("stage=")
		if arg.begins_with("seed="): run_seed = int(arg.trim_prefix("seed="))
	var renderer := RenderingServer.get_video_adapter_name()
	if not out.is_absolute_path() or not OS.get_environment("CV_QA_PROFILE").begins_with("cv_r49b_") or not "swiftshader" in renderer.to_lower():
		printerr("Expected absolute output, dedicated QA profile and SwiftShader, got ", renderer)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	phone = root.size.x == 844
	if phone:
		MobileTuning.set_device_hints_override_for_tests({"mobile_os": true, "native_form_factor": "phone", "native_ui_size": Vector2(root.size), "touch_available": true})
	root.content_scale_size = root.size
	RenderingServer.render_loop_enabled = false
	gm.select_stage(stage)
	gm.forced_run_seed = run_seed
	change_scene_to_file("res://scenes/arena/Arena.tscn")
	await scene_changed
	arena = current_scene
	hud = arena.get_node("HUD")
	for turn in range(26000):
		await process_frame
		elapsed_frames += 1
		if gm.is_game_over or gm.stage_victory_pending or gm.elapsed_time > 285:
			break
		if paused:
			if elapsed_frames % 4 == 0: _handle_dialog()
			continue
		if not gm.game_running: continue
		if elapsed_frames % 8 == 0: _steer()
		_observe()
		if int(gm.elapsed_time / 20) > last_status:
			last_status = int(gm.elapsed_time / 20)
			print("R49_CAPTURE_PROGRESS ", stage, " t=", int(gm.elapsed_time), " kills=", gm.kills, " roster=", max_squad, " shots=", captures.keys(), " dense=", dense_samples.size())
		if captures.size() == 4 and crowd_finished: break
	var record := {"viewport": [root.size.x,root.size.y], "renderer": renderer, "layout": MobileTuning.layout_tier_name(root.size), "input_events": input_events, "stage":stage, "seed":run_seed, "elapsed":gm.elapsed_time, "kills":gm.kills, "largest_roster":max_squad, "most_visible_enemies":largest_on_screen, "longest_missing_seconds":longest_missing_seconds, "attacks":captures, "crowded_frames":dense_samples}
	var stream := FileAccess.open(out.path_join("measurements.json"), FileAccess.WRITE)
	stream.store_string(JSON.stringify(record, "\t"))
	stream.close()
	print("R49_CAPTURE_RECORD ", out, " kinds=", captures.keys(), " dense=", dense_samples.size(), " max_roster=", max_squad)
	for code in key_state.keys(): _key(code, false)
	MobileTuning.set_device_hints_override_for_tests()
	paused = false
	unload_current_scene()
	for frame in range(4): await process_frame
	quit(0 if captures.size() == 4 and crowd_finished and longest_missing_seconds < 0.5 else 1)

func _key(code: int, pressed: bool) -> void:
	if key_state.get(code, false) == pressed: return
	key_state[code] = pressed
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	input_events += 1

func _tap(button: Button) -> void:
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled: return
	var xy := button.get_global_transform_with_canvas() * (button.size * 0.5)
	for down in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = xy
		touch.index = 1
		touch.pressed = down
		root.push_input(touch, true)
		input_events += 1

func _handle_dialog() -> void:
	if gm.waiting_for_upgrade:
		var cards: Array = arena.level_up_screen.option_buttons
		var choice := 0
		for i in range(cards.size()):
			if cards[i].get_meta("upgrade_option", {}).get("id") == "recruit_hero": choice = i; break
		_key(KEY_1 + choice, true)
		_key(KEY_1 + choice, false)
	elif gm.waiting_for_shop:
		_tap(arena.rift_shop_screen.skip_button)
	elif is_instance_valid(arena.first_run_guide):
		_tap(arena.first_run_guide.start_button)

func _steer() -> void:
	var player: Node2D = gm.player
	var relay: Node = gm.tactical_director.relay
	var target: Vector2 = relay.anchor
	if not relay.completed and relay.is_open():
		if gm.squad_manager.formation_id != relay.required_formation():
			_key(KEY_Q, true)
			_key(KEY_Q, false)
	else:
		target += Vector2.from_angle(gm.elapsed_time * 0.58) * 65.0
	if relay.completed:
		var foe: Node2D = factory.find_nearest_enemy(player.global_position, 1200)
		if foe != null: target = foe.global_position
	var dir := player.global_position.direction_to(target) if player.global_position.distance_to(target) > 18.0 else Vector2.ZERO
	_key(KEY_A, dir.x < -0.32)
	_key(KEY_D, dir.x > 0.32)
	_key(KEY_W, dir.y < -0.32)
	_key(KEY_S, dir.y > 0.32)
	_key(KEY_SPACE, fmod(gm.elapsed_time, 2.8) < 1.3)

func _observe() -> void:
	var roster: int = gm.squad_manager.get_members().filter(func(member): return member.is_alive).size()
	max_squad = maxi(max_squad, roster)
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	var xf := root.get_canvas_transform()
	for cue in get_nodes_in_group("attack_telegraphs"):
		if not cue.active or captures.has(str(cue.kind)) or cue.age <= 0.03: continue
		var center: Vector2 = xf * cue.global_position
		var extent: float = (cue.reach if cue.kind == &"ring" else cue.cue_length) * xf.get_scale().x
		var tip: Vector2 = center + cue.forward * extent
		var bounds := Rect2(center,Vector2.ZERO).expand(tip).grow(32.0)
		if cue.kind == &"ring": bounds = Rect2(center-Vector2.ONE*extent,Vector2.ONE*extent*2).grow(5.0)
		if not viewport.encloses(bounds) or bounds.get_center().y < root.size.y * 0.24: continue
		var kind := str(cue.kind)
		var frame := _frame()
		if frame.save_png(out.path_join(kind+".png")) != OK: continue
		var side := ceili(maxf(bounds.size.x, bounds.size.y))
		var origin := Vector2i(bounds.get_center()) - Vector2i.ONE * (side >> 1)
		origin = origin.clamp(Vector2i.ZERO, frame.get_size()-Vector2i.ONE*side)
		var crop := frame.get_region(Rect2i(origin, Vector2i.ONE*side))
		crop.resize(64,64,Image.INTERPOLATE_LANCZOS)
		crop.save_png(out.path_join(kind+"-64.png"))
		captures[kind] = {"time":gm.elapsed_time, "source":str(cue.get_parent().type_id), "high_threat":cue.feature, "cue_center":[center.x,center.y], "bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y], "roster":roster}
	if roster < 9 or crowd_finished: return
	var nearby := 0
	var sectors := [0,0,0,0]
	var player: Node2D = gm.player
	for enemy in get_nodes_in_group("enemies"):
		if not enemy.is_active or enemy.is_dying or not viewport.has_point(xf * enemy.global_position): continue
		var offset: Vector2 = enemy.global_position - player.global_position
		var sector := posmod(roundi(offset.angle()/(PI*0.5)),4)
		sectors[sector] += 1
		nearby += 1
	largest_on_screen = maxi(largest_on_screen, nearby)
	var groups: int = sectors.filter(func(count): return count >= 2).size()
	var bursts := 0
	for burst in factory.pools.explosion.live_list:
		if burst.is_active and burst.stats.get("area_radius",0) >= 50 and viewport.has_point(xf*burst.global_position): bursts += 1
	var in_crowd := groups >= 2 and bursts > 0
	if dense_until < 0 and not in_crowd: return
	if dense_until < 0: dense_until = gm.elapsed_time + 1.0
	var frame := _frame()
	var gold_pixels := _gold_rail_pixels(frame, player, xf)
	if gold_pixels == 0:
		if missing_since < 0: missing_since = gm.elapsed_time
		longest_missing_seconds = maxf(longest_missing_seconds, gm.elapsed_time - missing_since + 1.0/60.0)
	else:
		missing_since = -1.0
	dense_samples.append({"time":gm.elapsed_time, "rail_pixels":gold_pixels, "visible_enemies":nearby, "enemies_per_quadrant":sectors, "large_friendly_bursts":bursts})
	crowd_finished = gm.elapsed_time >= dense_until
	if dense_samples.size() == 1: frame.save_png(out.path_join("crowd.png"))

func _frame() -> Image:
	RenderingServer.force_draw(false)
	return root.get_texture().get_image()

func _gold_rail_pixels(frame: Image, player: Node2D, xf: Transform2D) -> int:
	# Sample on both gold side rails, away from the face, crown and floor ring.
	var count := 0
	for side in [-1, 1]:
		for point in [Vector2(27,-22),Vector2(29,-10),Vector2(26,5)]:
			var at := Vector2i(xf * (player.global_position+Vector2(point.x*side,point.y)))
			for dx in range(-2,3):
				for dy in range(-2,3):
					var pix := at+Vector2i(dx,dy)
					if not Rect2i(Vector2i.ZERO,frame.get_size()).has_point(pix): continue
					var rgb := frame.get_pixelv(pix)
					if rgb.r > 0.40 and rgb.g > rgb.b*1.24 and rgb.r > rgb.g*1.06: count += 1
	return count
