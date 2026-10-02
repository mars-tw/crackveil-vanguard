extends Node

const PAINTER := preload("res://scripts/services/r33_sprite_painter.gd")
const STATES := {"idle": 4, "walk": 8, "attack": 6, "hurt": 3, "death": 6}


func _ready() -> void:
	call_deferred("_bake")


func _bake() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var painter := PAINTER.new()
	painter.scale = Vector2.ONE * 2.0
	viewport.add_child(painter)
	var atlas := Image.create(512, 3712, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var cell := 0
	for id in PAINTER.IDS:
		for animation in STATES:
			for frame in range(int(STATES[animation])):
				painter.set_pose(id, animation, frame)
				await RenderingServer.frame_post_draw
				var rendered := viewport.get_texture().get_image()
				rendered.resize(64, 64, Image.INTERPOLATE_LANCZOS)
				atlas.blit_rect(rendered, Rect2i(0, 0, 64, 64), Vector2i((cell % 8) * 64, (cell / 8) * 64))
				cell += 1
		print("R33_CEL_BAKE character=%s frames=27" % id)
	var error := atlas.save_png("res://assets/sprites/r33_character_atlas.png")
	print("R33_CEL_BAKE_DONE cells=%d size=512x3712 error=%d" % [cell, error])
	get_tree().quit(0 if error == OK else 1)
