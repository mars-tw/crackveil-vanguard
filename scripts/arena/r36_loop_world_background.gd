extends Node2D

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const RUN_THEME := preload("res://scripts/arena/run_theme.gd")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const SHADER := preload("res://scripts/arena/r36_loop_world_ground.gdshader")
const PERIOD := Vector2(4096.0, 3072.0)
const RADII := Vector2(1400.0, 1000.0)
const MATERIAL_SPAN := Vector2(512.0, 512.0)
const ROOT := "res://assets/art/r36/"
const ATLAS_PATH := ROOT + "landmarks.png"
const TILE_PATHS := {"stone": ROOT + "tile_stone.png", "grass": ROOT + "tile_grass.png", "basalt": ROOT + "tile_basalt.png", "frost": ROOT + "tile_frost.png"}
const THEMES := {
	"rift_void": {"tile": "stone", "field": Color(0.80, 0.90, 1.0), "road": Color(1.10, 1.02, 0.87)},
	"wasteland_farm": {"tile": "grass", "field": Color(0.89, 1.0, 0.86), "road": Color(0.88, 0.92, 0.80)},
	"ember_rift": {"tile": "basalt", "field": Color(1.0, 0.84, 0.87), "road": Color(0.67, 0.57, 0.61)},
	"storm_isles": {"tile": "stone", "field": Color(0.65, 0.80, 0.95), "road": Color(0.95, 1.0, 1.06)},
	"star_frost": {"tile": "frost", "field": Color(0.92, 0.97, 1.0), "road": Color(0.75, 0.84, 0.98)},
	"veil_court": {"tile": "stone", "field": Color(0.93, 0.82, 1.0), "road": Color(1.0, 0.91, 0.86)}
}
const LANDMARK_IDS: Array[String] = ["moon_gate", "garden_fountain", "south_waypost", "ember_altar", "frost_obelisk", "storm_pylon", "veil_throne", "crystal_heart"]
const LANDMARK_NAMES: Array[String] = ["月門遺館", "翠泉花庭", "南行驛門", "緋焰祭台", "星霜石碑", "風潮晶塔", "帷幕王座", "晶心原"]
const LANDMARK_COLORS: Array[Color] = [Color("95bcf4"), Color("8ccdad"), Color("d9c08d"), Color("db947f"), Color("c5ddf3"), Color("83cdda"), Color("c6a0e0"), Color("ada3eb")]
const LANDMARK_SPANS: Array[float] = [370.0, 350.0, 290.0, 320.0, 355.0, 340.0, 375.0, 305.0]
const LANDMARK_CLEARANCE := 325.0

var run_seed: int = 1
var current_theme_id := "rift_void"
var floor: Sprite2D
var ground_material: ShaderMaterial
var landmark_sprites: Array[Sprite2D] = []
var landmark_entries: Array[Dictionary] = []
var landmark_regions: Array[Texture2D] = []
var texture_cache: Dictionary = {}
var texture_load_count: int = 0
var fallback: Texture2D
var last_view_span := Vector2.ZERO
var bitmap_ready := false
var seed_offset := Vector2.ZERO
var debug_camera_override: Variant = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var pixels := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	fallback = ImageTexture.create_from_image(pixels)
	floor = Sprite2D.new()
	floor.name = "R36PeriodicPaintedTerrain"
	floor.centered = false
	ground_material = ShaderMaterial.new()
	ground_material.shader = SHADER
	floor.material = ground_material
	floor.texture = fallback
	add_child(floor)
	for index in range(8):
		var sprite := Sprite2D.new()
		sprite.name = "R36Landmark_%s" % LANDMARK_IDS[index]
		sprite.centered = false
		sprite.z_index = 4
		sprite.visible = false
		add_child(sprite)
		landmark_sprites.append(sprite)
	configure_run_theme(run_seed, current_theme_id)
	_update_view()


func configure_run_theme(seed: int, theme: String = "") -> void:
	run_seed = maxi(1, absi(seed))
	current_theme_id = theme if THEMES.has(theme) else RUN_THEME.select_theme_id(run_seed)
	if not THEMES.has(current_theme_id):
		current_theme_id = "rift_void"
	if ground_material == null:
		return
	var style: Dictionary = THEMES[current_theme_id]
	var field := _load_bitmap(str(TILE_PATHS[style["tile"]]))
	var road := _load_bitmap(str(TILE_PATHS["stone"]))
	ground_material.set_shader_parameter("field_tex", field if field != null else fallback)
	ground_material.set_shader_parameter("road_tex", road if road != null else fallback)
	ground_material.set_shader_parameter("field_tint", style["field"])
	ground_material.set_shader_parameter("road_tint", style["road"])
	ground_material.set_shader_parameter("loop_period", PERIOD)
	ground_material.set_shader_parameter("texture_world_span", MATERIAL_SPAN)
	ground_material.set_shader_parameter("ring_radii", RADII)
	seed_offset = Vector2(float(run_seed % 233), float((run_seed * 37) % 251))
	ground_material.set_shader_parameter("seed_offset", seed_offset)
	_load_landmarks()
	bitmap_ready = field != null and road != null and landmark_regions.size() == 8
	if get_parent() != null and get_parent().has_method("set_theme_grade"):
		get_parent().set_theme_grade(Color.WHITE)


func _load_bitmap(path: String) -> Texture2D:
	if texture_cache.has(path):
		return texture_cache[path]
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return null
	var texture := SPRITE_LOADER.get_texture(path)
	if texture != null:
		texture_cache[path] = texture
		texture_load_count += 1
	return texture


func _load_landmarks() -> void:
	landmark_entries = get_landmarks()
	var atlas := _load_bitmap(ATLAS_PATH)
	if atlas != null and landmark_regions.is_empty():
		var size := atlas.get_size()
		for index in range(8):
			var col := index % 4
			var row := index / 4
			var x0 := roundi(float(col) * size.x / 4.0)
			var y0 := roundi(float(row) * size.y / 2.0)
			var x1 := roundi(float(col + 1) * size.x / 4.0)
			var y1 := roundi(float(row + 1) * size.y / 2.0)
			var region := AtlasTexture.new()
			region.atlas = atlas
			region.region = Rect2(x0, y0, x1 - x0, y1 - y0)
			region.filter_clip = true
			landmark_regions.append(region)
	for index in range(landmark_sprites.size()):
		var sprite := landmark_sprites[index]
		if landmark_regions.size() != 8:
			sprite.visible = false
			continue
		sprite.texture = landmark_regions[index]
		var size := sprite.texture.get_size()
		var scale_value := LANDMARK_SPANS[index] / maxf(size.x, size.y)
		sprite.scale = Vector2.ONE * scale_value
		sprite.offset = Vector2(-size.x * 0.5, -size.y * 0.82)
		sprite.modulate = Color.WHITE


func _process(_delta: float) -> void:
	_update_view()


func _update_view() -> void:
	var camera := get_viewport().get_camera_2d()
	var center: Vector2 = camera.get_screen_center_position() if camera != null else Vector2.ZERO
	if debug_camera_override is Vector2:
		center = debug_camera_override
	global_position = center
	var viewport := get_viewport_rect().size
	var view := viewport / camera.zoom if camera != null else viewport
	var cover := view + Vector2(192, 192)
	floor.position = -cover * 0.5
	floor.scale = cover * 0.5
	ground_material.set_shader_parameter("world_origin", center - cover * 0.5)
	if cover != last_view_span:
		last_view_span = cover
		ground_material.set_shader_parameter("view_span", cover)
	var show_bounds := view * 0.5 + Vector2(390, 390)
	for index in range(landmark_sprites.size()):
		if landmark_regions.size() != 8:
			continue
		var sprite := landmark_sprites[index]
		var base: Vector2 = landmark_entries[index]["visual_position"]
		var image := _nearest_image(base, center)
		var relative := image - center
		sprite.position = relative
		sprite.visible = absf(relative.x) < show_bounds.x and absf(relative.y) < show_bounds.y


func _nearest_image(position: Vector2, reference: Vector2) -> Vector2:
	return position + Vector2(roundf((reference.x - position.x) / PERIOD.x) * PERIOD.x, roundf((reference.y - position.y) / PERIOD.y) * PERIOD.y)


func get_landmarks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(8):
		var angle := float(index) * TAU / 8.0
		var position := Vector2(cos(angle) * RADII.x, sin(angle) * RADII.y)
		var outward := Vector2(cos(angle), sin(angle)).normalized()
		# The map point stays on the road; the painted structure sits beyond its
		# shoulder, leaving the travel lane readable even for the largest gate.
		result.append({"id": LANDMARK_IDS[index], "name": LANDMARK_NAMES[index], "position": position, "visual_position": position + outward * LANDMARK_CLEARANCE, "color": LANDMARK_COLORS[index], "road_index": index, "obstacle_radius": 55.0, "visual_span": LANDMARK_SPANS[index]})
	return result


func get_ring_waypoints() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for landmark in get_landmarks():
		result.append(landmark["position"])
	return result


func get_paths() -> Array[Dictionary]:
	return [{"id": "main_ring", "kind": "ellipse", "center": Vector2.ZERO, "radii": RADII, "width": 240.0, "closed": true}, {"id": "east_west_spoke", "kind": "ground_path", "from": Vector2(-1400, 0), "to": Vector2(1400, 0), "width": 170.0}, {"id": "north_south_spoke", "kind": "ground_path", "from": Vector2(0, -1000), "to": Vector2(0, 1000), "width": 170.0}, {"id": "central_hub", "kind": "plaza", "center": Vector2.ZERO, "radius": 270.0}]


func get_loop_period() -> Vector2:
	return PERIOD


func get_map_world_rect() -> Rect2:
	return Rect2(-PERIOD * 0.5, PERIOD)


func get_playable_rect() -> Rect2:
	return get_map_world_rect()


func get_theme_id() -> String:
	return current_theme_id


func get_theme_name() -> String:
	return RUN_THEME.get_theme_name(current_theme_id)


func get_r36_debug_state() -> Dictionary:
	var uids: Array[int] = []
	var visible_ids: Array[String] = []
	for index in range(landmark_sprites.size()):
		uids.append(landmark_sprites[index].get_instance_id())
		if landmark_sprites[index].visible:
			visible_ids.append(LANDMARK_IDS[index])
	return {"renderer": "r37_periodic_material_layers", "theme": current_theme_id, "loop_period": PERIOD, "texture_world_span": MATERIAL_SPAN, "ring_radii": RADII, "ring_width": 240, "field_full_period_walkable": true, "floor_quads": 1, "floor_texture_samples": 2, "floor_trigonometric_calls": 0, "landmark_clearance": LANDMARK_CLEARANCE, "bitmap_ready": bitmap_ready, "texture_load_count": texture_load_count, "cached_texture_paths": texture_cache.keys(), "landmark_node_uids": uids, "visible_landmarks": visible_ids, "render_center": global_position, "world_view_span": last_view_span, "mirror": false, "platform_image": false, "mobile_lod": MOBILE.mobile_lod_enabled(get_viewport_rect().size)}


func get_mobile_lod_debug_state() -> Dictionary:
	return get_r36_debug_state()
