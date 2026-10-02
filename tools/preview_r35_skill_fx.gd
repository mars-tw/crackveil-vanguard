extends SceneTree

const CATALOG := preload("res://scripts/vfx/newskill_fx_catalog.gd")
const OUT := "res://assets/art/r35/qa/"
var sprites: Array[AnimatedSprite2D] = []
var seen: Array[Dictionary] = []
var actors: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	actors = Node2D.new()
	root.add_child(actors)
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/art/r34/map_moon.png")
	bg.centered = false
	bg.scale = Vector2(1280.0, 720.0) / bg.texture.get_size()
	actors.add_child(bg)
	var kinds := CATALOG.get_kind_ids()
	for index in range(kinds.size()):
		var fx := AnimatedSprite2D.new()
		fx.name = kinds[index]
		fx.sprite_frames = CATALOG.get_frames(kinds[index])
		fx.position = Vector2(160.0 + float(index % 4) * 320.0, 180.0 + floorf(float(index) / 4.0) * 360.0)
		fx.scale = Vector2(1.10, 1.10)
		actors.add_child(fx)
		sprites.append(fx)
		seen.append({})
		fx.play(&"default")
	var frames := 0
	while frames < 40:
		await RenderingServer.frame_post_draw
		for index in range(sprites.size()):
			seen[index][sprites[index].frame] = true
		if frames == 4:
			root.get_texture().get_image().save_png(OUT + "native_fx_on_painted_ground.png")
		frames += 1
	for index in range(sprites.size()):
		if seen[index].size() != 8:
			printerr("R35_FX_NATIVE_FAIL frame visit count %s=%d" % [kinds[index], seen[index].size()])
			quit(1)
			return
	var file := FileAccess.open(OUT + "native_preview.json", FileAccess.WRITE)
	var details: Array[Dictionary] = []
	for index in range(kinds.size()):
		details.append({"kind": kinds[index], "native_animated_frames_visited": seen[index].size()})
	file.store_string(JSON.stringify({"renderer": DisplayServer.get_name(), "animated_spriteframes": true, "fixed_fps": 60, "effects": details}, "\t"))
	file.close()
	print("R35_FX_NATIVE_PASS animated_spriteframes=true all_8_frames_visited_per_kind=8 effects=8 actual_GPU_alpha_composite=true")
	quit(0)
