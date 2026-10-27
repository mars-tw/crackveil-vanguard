extends Node

const BACKGROUND_SCRIPT := preload("res://scripts/arena/arena_background.gd")
const ARENA_SCENE := preload("res://scenes/arena/Arena.tscn")
const RUN_THEME := preload("res://scripts/arena/run_theme.gd")
const OUT := "res://docs/evidence/r34/art/"
var capture_images := true
var camera: Camera2D
var background: Node2D


func _ready() -> void:
	capture_images = DisplayServer.get_name() != "headless"
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	background = BACKGROUND_SCRIPT.new()
	background.z_index = -100
	add_child(background)
	await get_tree().process_frame
	var results: Array[Dictionary] = []
	for theme in RUN_THEME.get_theme_ids():
		background.configure_run_theme(34017, theme)
		background.debug_center_override = Vector2.ZERO
		camera.position = Vector2.ZERO
		camera.zoom = Vector2(0.60, 0.60)
		await get_tree().process_frame
		await get_tree().process_frame
		if background.floor_texture == null or background.floor_texture.get_width() < 1200 or background.floor_texture.get_height() < 1200:
			_fail("raster map did not load at native resolution")
			return
		if background.get_child_count() != 2:
			_fail("grid / geometric prop nodes remain")
			return
		var overview: Dictionary = background.get_r34_debug_state()
		if not (overview["map_world_span"] as Vector2).is_equal_approx(Vector2(1240.0, 790.0)) or int(overview["prop_pool"]) != 0:
			_fail("map span / no-geometry contract diverged")
			return
		await _capture(theme + "_overview.png")
		camera.zoom = Vector2(1.20, 1.20)
		await get_tree().process_frame
		await get_tree().process_frame
		await _capture(theme + "_battle_origin.png")
		var first: Dictionary = background.get_r34_debug_state()
		var moved := Vector2(420.0, -170.0)
		camera.position = moved
		background.debug_center_override = moved
		await get_tree().process_frame
		await get_tree().process_frame
		var second: Dictionary = background.get_r34_debug_state()
		var a: Vector2 = first["floor_origin"]
		var b: Vector2 = second["floor_origin"]
		var rendered_a: Vector2 = first["render_center"]
		var rendered_b: Vector2 = second["render_center"]
		if not (b - a).is_equal_approx(rendered_b - rendered_a) or int(first["texture_reload_count"]) != int(second["texture_reload_count"]):
			_fail("map is screen-locked or reloads while moving")
			return
		await _capture(theme + "_battle_move.png")
		background.debug_set_parallax_quality("low")
		camera.zoom = Vector2(1.56, 1.56)
		await get_tree().process_frame
		await get_tree().process_frame
		var lod: Dictionary = background.get_mobile_lod_debug_state()
		if int(lod["dust_amount"]) != 6 or int(lod["active_props"]) != 0 or int(lod["floor_quads"]) != 1:
			_fail("raster mobile LOD contract diverged")
			return
		var imported_image: Image = background.floor_texture.get_image()
		if not imported_image.has_mipmaps():
			_fail("mobile floor texture mipmaps were not imported")
			return
		await _capture(theme + "_mobile_lod.png")
		results.append({"theme": theme, "raster": overview, "world_anchor_exact": true, "zero_geometry_props": true, "no_movement_reload": true, "mipmaps": true, "mobile_lod": lod})
		background.debug_set_parallax_quality("high")
	background.queue_free()
	camera.queue_free()
	await get_tree().process_frame
	# Real Arena roots, hero colliders, weapons and spawner run on the painted
	# plane. This is an integration smoke run, not a screenshot of source art.
	GameManager.forced_run_seed = 34020
	var arena := ARENA_SCENE.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	if arena.first_run_guide != null:
		arena.first_run_guide.hide()
	GameManager.system_pause_owners.clear()
	get_tree().paused = false
	var leader: Node2D = GameManager.player
	if leader == null or not is_instance_valid(leader):
		_fail("actual arena leader did not start on raster plane")
		return
	var start := leader.global_position
	GameManager.set_touch_move_vector(Vector2(0.9, 0.25))
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline and leader.global_position.distance_to(start) < 200.0:
		await get_tree().process_frame
		if GameManager.waiting_for_upgrade:
			get_tree().paused = false
	GameManager.set_touch_move_vector(Vector2.ZERO)
	var distance := leader.global_position.distance_to(start)
	if distance < 200.0:
		_fail("actual hero could not move on raster plane: %.2f" % distance)
		return
	var live_background := arena.get_node("Background")
	var live: Dictionary = live_background.get_r34_debug_state()
	if live_background.ground_sprite.texture == null or int(live["prop_pool"]) != 0:
		_fail("live Arena did not use R34 raster runtime")
		return
	await _capture("actual_arena_hero_move.png")
	var evidence := {"renderer": DisplayServer.get_name(), "capture_images": capture_images, "themes": results, "actual_arena": {"hero_moved_world_units": distance, "background": live}}
	var name := "r34_native_probe.json" if capture_images else "r34_headless_probe.json"
	var file := FileAccess.open(OUT + name, FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	print("R34_ART_PROBE_PASS themes=%d raster=1254x1254 map_span=1240x790 world_anchor=exact floor_quads=1 props=0 mipmaps=true mobile_dust=6 actual_hero_moved=%.2f capture=%s" % [results.size(), distance, capture_images])
	get_tree().quit(0)


func _capture(filename: String) -> void:
	if not capture_images:
		return
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	if pixels.save_png(OUT + filename) != OK:
		_fail("could not save actual runtime PNG")


func _fail(message: String) -> void:
	printerr("R34_ART_PROBE_FAIL: " + message)
	get_tree().quit(1)
