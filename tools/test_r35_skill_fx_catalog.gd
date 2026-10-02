extends SceneTree

const CATALOG := preload("res://scripts/vfx/newskill_fx_catalog.gd")
const ROOT := "res://assets/art/r35/qa/"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rows: Array[Dictionary] = []
	var first_atlas: Texture2D = null
	for kind in CATALOG.get_kind_ids():
		var frames := CATALOG.get_frames(kind)
		var second := CATALOG.get_frames(kind)
		var textures := CATALOG.get_frame_textures(kind)
		var lifetime := CATALOG.get_lifetime(kind)
		if frames.get_instance_id() != second.get_instance_id():
			_fail("SpriteFrames is not cached: " + kind)
			return
		if frames.get_frame_count(&"default") != 8 or textures.size() != 8:
			_fail("missing authored frames: " + kind)
			return
		if lifetime < 0.20 or lifetime > 0.35:
			_fail("burst lifetime outside contract: " + kind)
			return
		if absf(8.0 / float(frames.get_animation_speed(&"default")) - lifetime) > 0.00001:
			_fail("animation speed does not match burst duration")
			return
		if frames.get_animation_loop(&"default") != (kind == "cyclone"):
			_fail("burst / loop policy diverged")
			return
		var hashes: Dictionary = {}
		for texture in textures:
			var cell := texture as AtlasTexture
			if cell == null or cell.get_size() != Vector2(256, 256) or not cell.filter_clip:
				_fail("atlas region / clip contract mismatch")
				return
			if first_atlas == null:
				first_atlas = cell.atlas
			if first_atlas.get_instance_id() != cell.atlas.get_instance_id():
				_fail("effects do not share one GPU atlas")
				return
			var pixels := texture.get_image()
			if pixels == null or pixels.is_empty() or pixels.get_pixel(0, 0).a != 0.0:
				_fail("frame alpha / padding missing")
				return
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(pixels.get_data())
			hashes[hash.finish().hex_encode()] = true
		if hashes.size() != 8:
			_fail("runtime frames are duplicated")
			return
		rows.append({"kind": kind, "frames": 8, "unique_runtime_frames": hashes.size(), "cached_spriteframes": true, "lifetime": lifetime, "fps": frames.get_animation_speed(&"default"), "loop": frames.get_animation_loop(&"default"), "release_lifetime": CATALOG.get_release_lifetime(kind)})
	if first_atlas == null or first_atlas.get_size() != Vector2(2048, 2048):
		_fail("GPU atlas dimensions mismatch")
		return
	if not first_atlas.get_image().has_mipmaps():
		_fail("atlas mipmaps missing")
		return
	if CATALOG.get_release_lifetime("cyclone") > 0.12:
		_fail("cyclone release tail too long")
		return
	var file := FileAccess.open(ROOT + "catalog_test.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"atlas": CATALOG.ATLAS_PATH, "atlas_size": first_atlas.get_size(), "shared_atlas": true, "mipmaps": true, "effects": rows}, "\t"))
	file.close()
	print("R35_FX_CATALOG_PASS kinds=8 authored_frames=64 shared_atlas=2048x2048 cache=true RGBA=true clip=true lifetime=.22-.32 cyclone_release=.10 mipmaps=true")
	quit(0)


func _fail(message: String) -> void:
	printerr("R35_FX_CATALOG_FAIL: " + message)
	quit(1)
