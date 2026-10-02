extends SceneTree

const ROOT := "res://assets/art/r35/"
const CELL := 256
const CONTENT := 216
const PAD := 20
const KINDS: Array[String] = ["slash_a", "slash_b", "cyclone", "critical_impact", "monster_fire", "monster_frost", "monster_shadow", "monster_bite"]
const SHEETS: Array[String] = ["gold_slashes", "cyclone_critical", "fire_frost", "shadow_bite"]


func _initialize() -> void:
	call_deferred("_pack")


func _pack() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "qa"))
	var atlas := Image.create(CELL * 8, CELL * 8, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var dark := Image.create(CELL * 8, CELL * 8, false, Image.FORMAT_RGBA8)
	dark.fill(Color("182231"))
	var light := Image.create(CELL * 8, CELL * 8, false, Image.FORMAT_RGBA8)
	light.fill(Color("b1bbcb"))
	var effects: Array[Dictionary] = []
	var originals: Array[Dictionary] = []
	for sheet_index in range(SHEETS.size()):
		var source_path := ROOT + "sources/" + SHEETS[sheet_index] + ".png"
		var source := Image.load_from_file(source_path)
		if source == null or source.is_empty():
			_fail("missing ImageGen source: " + source_path)
			return
		if not source.detect_alpha():
			_fail("source has no actual transparency: " + source_path)
			return
		source.convert(Image.FORMAT_RGBA8)
		originals.append({"path": source_path, "size": source.get_size(), "sha256": FileAccess.get_sha256(source_path), "actual_alpha": true})
		for effect_in_sheet in range(2):
			var row := sheet_index * 2 + effect_in_sheet
			var metrics: Array[Dictionary] = []
			var visible_hashes: Dictionary = {}
			for frame in range(8):
				var source_cell := frame + effect_in_sheet * 8
				var col := source_cell % 4
				var source_row := source_cell / 4
				var x0 := roundi(float(col) * source.get_width() / 4.0)
				var y0 := roundi(float(source_row) * source.get_height() / 4.0)
				var x1 := roundi(float(col + 1) * source.get_width() / 4.0)
				var y1 := roundi(float(source_row + 1) * source.get_height() / 4.0)
				var cell := source.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))
				var strong_border := _border_count(cell, 0.08)
				if strong_border > 0:
					_fail("visible authored frame touches source boundary: %s/%d border=%d" % [KINDS[row], frame, strong_border])
					return
				# Mechanical packing only. Preserve cell pivot, complete crop and RGBA;
				# never redraw an effect, remove its particles or re-center its bbox.
				cell.resize(CONTENT, CONTENT, Image.INTERPOLATE_LANCZOS)
				var packed := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
				packed.fill(Color.TRANSPARENT)
				packed.blit_rect(cell, Rect2i(0, 0, CONTENT, CONTENT), Vector2i(PAD, PAD))
				var metric := _frame_metric(packed)
				if int(metric["visible_pixels"]) < 4:
					_fail("empty effect frame: %s/%d" % [KINDS[row], frame])
					return
				if int(metric["clear_margin"]) < PAD:
					_fail("atlas cell lacks transparent padding")
					return
				visible_hashes[metric["silhouette_sha256"]] = true
				metric["frame"] = frame
				metric["source_visible_border_pixels"] = strong_border
				metrics.append(metric)
				var destination := Vector2i(frame * CELL, row * CELL)
				atlas.blit_rect(packed, Rect2i(0, 0, CELL, CELL), destination)
				dark.blend_rect(packed, Rect2i(0, 0, CELL, CELL), destination)
				light.blend_rect(packed, Rect2i(0, 0, CELL, CELL), destination)
			if visible_hashes.size() != 8:
				_fail("not eight distinct authored silhouettes: " + KINDS[row])
				return
			effects.append({"kind": KINDS[row], "row": row, "distinct_authored_frames": visible_hashes.size(), "fixed_anchor": Vector2i(128, 128), "frames": metrics})
	if atlas.save_png(ROOT + "r35_skill_fx_atlas.png") != OK:
		_fail("atlas save failed")
		return
	dark.save_png(ROOT + "qa/fx_contact_dark.png")
	light.save_png(ROOT + "qa/fx_contact_light.png")
	var file := FileAccess.open(ROOT + "qa/packing_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"atlas": ROOT + "r35_skill_fx_atlas.png", "atlas_size": atlas.get_size(), "cell_size": CELL, "content_size": CONTENT, "transparent_padding": PAD, "rgba": true, "source_mode": "built-in ImageGen", "processing": "mechanical fixed-grid crop and resize only", "originals": originals, "effects": effects}, "\t"))
	file.close()
	print("R35_FX_PACK_PASS effects=8 distinct_authored_frames=64 atlas=2048x2048 cell=256 transparent_padding=20 fixed_anchor=128,128 source_visible_border=0")
	quit(0)


func _border_count(pixels: Image, threshold: float) -> int:
	var count := 0
	for x in range(pixels.get_width()):
		if pixels.get_pixel(x, 0).a > threshold:
			count += 1
		if pixels.get_pixel(x, pixels.get_height() - 1).a > threshold:
			count += 1
	for y in range(pixels.get_height()):
		if pixels.get_pixel(0, y).a > threshold:
			count += 1
		if pixels.get_pixel(pixels.get_width() - 1, y).a > threshold:
			count += 1
	return count


func _frame_metric(pixels: Image) -> Dictionary:
	var mask := PackedByteArray()
	mask.resize(CELL * CELL)
	var min_xy := Vector2i(CELL, CELL)
	var max_xy := Vector2i.ZERO
	var count := 0
	var fractional := 0
	for y in range(CELL):
		for x in range(CELL):
			var alpha := pixels.get_pixel(x, y).a
			if alpha > 0.0:
				min_xy = Vector2i(mini(min_xy.x, x), mini(min_xy.y, y))
				max_xy = Vector2i(maxi(max_xy.x, x), maxi(max_xy.y, y))
			if alpha >= 0.2:
				mask[y * CELL + x] = 255
				count += 1
			if alpha > 0.0 and alpha < 1.0:
				fractional += 1
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(mask)
	var margin := mini(mini(min_xy.x, min_xy.y), mini(CELL - 1 - max_xy.x, CELL - 1 - max_xy.y))
	return {"visible_pixels": count, "fractional_alpha_pixels": fractional, "clear_margin": margin, "nonzero_bounds": Rect2i(min_xy, max_xy - min_xy + Vector2i.ONE), "silhouette_sha256": hash.finish().hex_encode()}


func _fail(message: String) -> void:
	printerr("R35_FX_PACK_FAIL: " + message)
	quit(1)
