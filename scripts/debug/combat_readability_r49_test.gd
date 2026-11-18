extends SceneTree

# Deterministic gate for the gameplay presentation. Screenshots and pixel sampling
# run separately against moving actors in combat_readability_r49_capture.gd.
var errors: Array[String] = []

func verify(ok: bool, label: String) -> void:
	if not ok:
		errors.append(label)
		printerr(label)

func _initialize() -> void:
	await process_frame
	var cue = load("res://scripts/vfx/monster_attack_telegraph.gd").new()
	root.add_child(cue)
	for kind in [&"contact", &"dash", &"ranged", &"ring"]:
		cue.show_cue(kind, Vector2.DOWN, 24.0, true, Color.BLUE, 145.0 if kind == &"ring" else 0.0)
		verify(cue.active and cue.visible and cue.tint == cue.DANGER and cue.z_index > 38, "high threat %s" % kind)
		if kind == &"ring":
			verify(is_equal_approx(cue.reach, 145.0) and cue.cone.is_empty(), "ring radius must match impact")
		else:
			verify(cue.forward == Vector2.DOWN and cue.arrow[1].normalized() == Vector2.DOWN, "locked direction %s" % kind)
	cue.show_cue(&"contact", Vector2.ZERO, 12, false, Color.BLUE)
	verify(cue.tint == cue.ORDINARY and cue.z_index < 0, "reuse must restore ordinary palette and layer")
	cue.hide_cue()
	verify(not cue.active and not cue.is_processing() and not cue.visible, "hidden cue reset")
	var hero := Node2D.new()
	root.add_child(hero)
	hero.add_to_group("heroes")
	var burst = load("res://scripts/projectiles/explosion_area.gd").new()
	root.add_child(burst)
	var stats := {"area_radius": 96.0, "composite_layers": 3}
	burst.setup(Vector2.ZERO, stats, null)
	var original := Vector3(burst.sprite.modulate.a, burst.glow.modulate.a, burst.core_flash.modulate.a)
	burst.setup(Vector2.ZERO, stats, hero)
	verify(burst.friendly_burst, "real hero group selects friendly treatment")
	verify(burst.sprite.modulate.a < original.x and burst.glow.modulate.a < original.y and burst.core_flash.modulate.a < original.z, "only the friendly center is dimmed")
	verify(burst.shockwave_sprite.visible and burst.shockwave_sprite.modulate.a > 0.8, "shockwave edge retained")
	burst.pool_on_release()
	verify(not burst.friendly_burst, "no friendly flags leak through the pool")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("gallery="):
			await render_gallery(arg.trim_prefix("gallery="))
	print("COMBAT_READABILITY_R49_%s errors=%s" % ["PASS" if errors.is_empty() else "FAIL", errors])
	quit(0 if errors.is_empty() else 1)

func render_gallery(path: String) -> void:
	if not path.is_absolute_path() or not "swiftshader" in RenderingServer.get_video_adapter_name().to_lower():
		verify(false, "gallery needs an absolute PNG target and SwiftShader")
		return
	var gallery := Image.create_empty(256, 64, false, Image.FORMAT_RGBA8)
	var masks: Array[PackedByteArray] = []
	for kind in [&"contact", &"dash", &"ranged", &"ring"]:
		var view := SubViewport.new()
		view.size = Vector2i(64, 64)
		view.transparent_bg = true
		view.world_2d = World2D.new()
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var live = load("res://scripts/vfx/monster_attack_telegraph.gd").new()
		view.add_child(live)
		live.show_cue(kind, Vector2.RIGHT, 32, true, Color.RED, 145.0 if kind == &"ring" else 0.0)
		var fit: float = 27.0/145.0 if kind == &"ring" else 46.0/live.cue_length
		view.canvas_transform = Transform2D(0.0, Vector2.ONE*fit, 0.0, Vector2(32,32) if kind == &"ring" else Vector2(5,32))
		await process_frame
		await RenderingServer.frame_post_draw
		var thumb := view.get_texture().get_image()
		thumb.convert(Image.FORMAT_RGBA8)
		gallery.blit_rect(thumb,Rect2i(0,0,64,64),Vector2i(masks.size()*64,0))
		var mask := PackedByteArray()
		for y in 64:
			for x in 64: mask.append(int(thumb.get_pixel(x,y).a >= 0.4))
		for other in masks:
			var common := 0
			var combined := 0
			for cell in mask.size():
				common += int(mask[cell] != 0 and other[cell] != 0)
				combined += int(mask[cell] != 0 or other[cell] != 0)
			verify(combined > 0 and float(common)/maxi(combined,1) < 0.65, "64px silhouettes overlap: %s" % kind)
		verify(mask.count(1) > 80, "64px shape too faint: %s" % kind)
		masks.append(mask)
		view.queue_free()
	verify(gallery.save_png(path) == OK, "gallery write")
