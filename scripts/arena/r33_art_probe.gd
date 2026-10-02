extends Node

const BACKGROUND_SCRIPT := preload("res://scripts/arena/arena_background.gd")
const OUT := "res://docs/evidence/r33/art/"
var background: Node2D
var camera: Camera2D
var capture_images := true


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
	for theme in ["rift_void", "wasteland_farm", "ember_rift"]:
		background.configure_run_theme(33017, theme)
		background.debug_center_override = Vector2.ZERO
		camera.position = Vector2.ZERO
		await get_tree().process_frame
		await get_tree().process_frame
		var first: Dictionary = background.get_r33_debug_state()
		if background.floor_texture == null or background.floor_texture.get_size() != Vector2(960.0, 768.0):
			_fail("missing / malformed theme floor: " + theme)
			return
		if background.get_node_or_null("R25ParallaxStack") != null or background.get_node_or_null("RiftCracks") != null:
			_fail("legacy framing still overlays runtime")
			return
		for kind in background.PROP_IDS:
			if background.decor_textures.get(kind) == null:
				_fail("missing prop: " + theme + "/" + kind)
				return
		var signature: String = background.get_decor_signature_for_center(Vector2.ZERO, 24)
		if signature.is_empty() or signature != background.get_decor_signature_for_center(Vector2.ZERO, 24):
			_fail("seed decor is not deterministic")
			return
		await _capture(theme + "_origin.png")
		first = background.get_r33_debug_state()
		var moved := Vector2(96.0, 48.0)
		background.debug_center_override = moved
		camera.position = moved
		await get_tree().process_frame
		await get_tree().process_frame
		var second: Dictionary = background.get_r33_debug_state()
		var origin_a: Vector2 = first["floor_origin"]
		var origin_b: Vector2 = second["floor_origin"]
		if not (origin_b - origin_a).is_equal_approx(moved):
			_fail("ground world anchoring diverged: a=%s b=%s span_a=%s span_b=%s" % [origin_a, origin_b, first["world_span"], second["world_span"]])
			return
		if first["texture_reload_count"] != second["texture_reload_count"] or first["decor_rebuild_count"] != second["decor_rebuild_count"]:
			_fail("subcell movement recreated textures or rebuilt static geometry")
			return
		for index in range(background.decor_states.size()):
			var entry: Dictionary = background.decor_states[index]
			var world: Vector2 = entry["world_position"]
			var observed: Vector2 = background.decor_sprites[index].global_position
			if not observed.is_equal_approx(world):
				_fail("prop follows screen / parallax instead of world")
				return
		var zoom_rebuild_count: int = background.decor_rebuild_count
		for zoom_frame in range(8):
			camera.zoom = Vector2.ONE * (1.0 + float(zoom_frame) * 0.006)
			await get_tree().process_frame
		if int(background.decor_rebuild_count) != zoom_rebuild_count:
			_fail("smooth camera zoom rebuilt the prop layout within the same coverage cells")
			return
		camera.zoom = Vector2.ONE
		await get_tree().process_frame
		await get_tree().process_frame
		await _capture(theme + "_move.png")
		background.debug_center_override = Vector2(1200.0, 640.0)
		camera.position = Vector2(1200.0, 640.0)
		background.debug_set_parallax_quality("low")
		camera.zoom = Vector2(1.56, 1.56)
		await get_tree().process_frame
		await get_tree().process_frame
		var mobile: Dictionary = background.get_mobile_lod_debug_state()
		if int(mobile["dust_amount"]) != 12 or int(mobile["decor_target"]) != 32 or int(mobile["floor_quads"]) != 1:
			_fail("mobile LOD cap mismatch")
			return
		await _capture(theme + "_mobile_lod.png")
		background.debug_set_parallax_quality("high")
		camera.zoom = Vector2.ONE
		await get_tree().process_frame
		results.append({"theme": theme, "deterministic_props": true, "world_anchor_exact": true, "no_subcell_rebuild": true, "smooth_zoom_no_rebuild": true, "desktop": first, "mobile": mobile})
	var evidence_name := "r33_art_probe.json" if capture_images else "r33_headless_probe.json"
	var file := FileAccess.open(OUT + evidence_name, FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": DisplayServer.get_name(), "image_capture": capture_images, "themes": results}, "\t"))
	file.close()
	print("R33_ART_PROBE_PASS themes=3 assets=18 floor_quads=1 prop_pool=48 mobile=32 dust=24/12 world_anchor=exact no_subcell_rebuild=true smooth_zoom_no_rebuild=true capture=" + str(capture_images))
	get_tree().quit(0)


func _capture(filename: String) -> void:
	if not capture_images:
		return
	await RenderingServer.frame_post_draw
	var rendered := get_viewport().get_texture().get_image()
	var error := rendered.save_png(OUT + filename)
	if error != OK:
		_fail("render PNG save failed: " + filename)


func _fail(message: String) -> void:
	printerr("R33_ART_PROBE_FAIL: " + message)
	get_tree().quit(1)
