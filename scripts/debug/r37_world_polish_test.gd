extends Node

const BACKGROUND := preload("res://scripts/arena/r36_loop_world_background.gd")
const TELEGRAPH := preload("res://scripts/vfx/monster_attack_telegraph.gd")
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("R37_WORLD_POLISH_FAIL: " + message)


func _run() -> void:
	var background := BACKGROUND.new()
	add_child(background)
	await get_tree().process_frame
	background.set_process(false)
	var first: Dictionary = background.get_r36_debug_state()
	var uids: Array = first["landmark_node_uids"]
	var loads: int = first["texture_load_count"]
	_check(bool(first["bitmap_ready"]), "painted terrain assets missing")
	_check(uids.size() == 8, "landmark count changed")
	var period: Vector2 = background.get_loop_period()
	var span: Vector2 = first["texture_world_span"]
	_check(is_zero_approx(fmod(period.x, span.x)) and is_zero_approx(fmod(period.y, span.y)), "texture phase does not close at world seam")
	var landmarks: Array = background.get_landmarks()
	var anchor := Vector2(1100.0, -780.0)
	background.debug_camera_override = anchor
	background._update_view()
	var reference_positions: Array[Vector2] = []
	for sprite in background.landmark_sprites:
		reference_positions.append(sprite.position)
	for sample in range(32):
		var offset := Vector2(float(sample % 8 - 4) * period.x, float(sample / 8 - 2) * period.y)
		background.debug_camera_override = anchor + offset
		background._update_view()
		var state: Dictionary = background.get_r36_debug_state()
		_check(state["landmark_node_uids"] == uids, "landmark reallocated at periodic viewpoint %d" % sample)
		_check(int(state["texture_load_count"]) == loads, "terrain texture reloaded while walking")
		for index in range(8):
			_check(background.landmark_sprites[index].position.is_equal_approx(reference_positions[index]), "landmark seam discontinuity at sample %d index %d" % [sample, index])
	for landmark in landmarks:
		var outward_distance: float = landmark["visual_position"].distance_to(landmark["position"])
		var footprint_half: float = float(landmark["visual_span"]) * 0.5
		_check(outward_distance - footprint_half >= 135.0, "painted landmark crowds 240-unit travel lane")
	var shader_source: String = background.ground_material.shader.code
	_check(shader_source.count("texture(") == 2, "terrain added texture fetches")
	_check(not shader_source.contains("sin(") and not shader_source.contains("cos("), "terrain contains per-pixel trigonometry")
	print("R37_TERRAIN stable_landmarks=8 periodic_viewpoints=32 extra_texture_loads=0 texture_fetches=2 per_pixel_trig=0 clear_lane=true")

	var cue := TELEGRAPH.new()
	add_child(cue)
	cue.show_cue(&"ring", Vector2.DOWN, 50.0, true, Color("e79965"), 145.0)
	_check(is_equal_approx(cue.reach, 145.0) and cue.scale == Vector2.ONE, "shield warning no longer matches exact 145-world-unit damage circle")
	_check(cue.cone.is_empty(), "ring cue contains misleading arrow")
	cue.show_cue(&"dash", Vector2(0.6, -0.8), 50.0, true, Color("8adcef"))
	var direction: Vector2 = cue.forward
	var tip: Vector2 = cue.arrow[1]
	_check(cue.scale == Vector2.ONE and tip.normalized().is_equal_approx(direction), "direction arrow differs from locked attack direction")
	_check(cue.cone.size() == 14, "direction geometry was not cached")
	var redraws: int = cue.redraw_requests
	for step in range(120):
		cue._process(1.0 / 120.0)
	var requests: int = cue.redraw_requests - redraws
	_check(requests >= 29 and requests <= 31, "cue redraw frequency is not bounded to 30 Hz")
	cue.hide_cue()
	_check(not cue.active and not cue.visible and not cue.is_processing(), "hidden cue remained alive")
	print("R37_TELEGRAPH shield_radius=145 direction_world_space=true cached_geometry=true redraws_1s=%d hidden_cleanup=true" % requests)
	if failures.is_empty():
		print("R37_WORLD_POLISH_PASS periodic_terrain=true eight_stable_landmarks=true clear_lane=true exact_shield_warning=true bounded_redraw=true")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
