extends Node2D

const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")
const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const RUN_THEME := preload("res://scripts/arena/run_theme.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const GROUND_SHADER := preload("res://scripts/arena/r33_ground.gdshader")
const ART_PREFIX := "res://assets/art/r33/"
const DECOR_POOL_SIZE := 48
const DECOR_CELL_SIZE := 248.0
const LANDMARK_CELL_SIZE := 1080.0
const PROP_IDS: Array[String] = ["rubble", "column", "ward", "brazier", "seal"]
const PROP_SCALES: Dictionary = {"rubble": 0.59, "column": 0.64, "ward": 0.62, "brazier": 0.58, "seal": 0.78}
const THEME_PROFILES: Dictionary = {
	"rift_void": {"background_color": Color("36435c"), "rift_color": Color("897bcd"), "dust_color": Color(0.50, 0.60, 0.82, 0.22), "boss_flash_color": Color("bf9bde"), "canvas_tone": Color(0.99, 0.99, 1.0), "decor_density": 0.28},
	"wasteland_farm": {"background_color": Color("414957"), "rift_color": Color("72c3bd"), "dust_color": Color(0.43, 0.78, 0.75, 0.20), "boss_flash_color": Color("add6c5"), "canvas_tone": Color(1.0, 1.0, 1.0), "decor_density": 0.29},
	"ember_rift": {"background_color": Color("4b4250"), "rift_color": Color("d28fc5"), "dust_color": Color(0.78, 0.55, 0.73, 0.22), "boss_flash_color": Color("dda6cc"), "canvas_tone": Color(1.0, 0.99, 1.0), "decor_density": 0.27}
}

@export var background_color: Color = Color("36435c")
@export var rift_color: Color = Color("897bcd")
@export var nebula_color: Color = Color.TRANSPARENT
@export var dust_amount: int = 24

var run_seed: int = 1
var current_theme_id: String = "rift_void"
var current_theme: Dictionary = {}
var time_accum: float = 0.0
var evolution_interval: float = 75.0
var boss_flash_timer: float = 0.0
var boss_flash_duration: float = 0.42
var boss_phase_wave_timer: float = 0.0
var boss_phase_wave_duration: float = 0.92
var dust_particles: CPUParticles2D = null
var applied_mobile_lod: bool = false
var forced_parallax_quality: String = "auto"
var ground_sprite: Sprite2D = null
var ground_material: ShaderMaterial = null
var decor_sprites: Array[Sprite2D] = []
var decor_states: Array[Dictionary] = []
var decor_textures: Dictionary = {}
var floor_texture: Texture2D = null
var last_decor_cell := Vector2i(999999, 999999)
var last_view_span := Vector2.ZERO
var last_ground_origin := Vector2.ZERO
var last_coverage := Vector2i.ZERO
var floor_quad_count: int = 1
var texture_reload_count: int = 0
var decor_rebuild_count: int = 0
var debug_center_override: Variant = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	current_theme = _profile_for_id(current_theme_id)
	_ensure_ground()
	_ensure_decor_pool()
	_load_theme_textures()
	_ensure_dust_particles()
	_apply_theme_exports()
	_apply_visual_lod_state(_mobile_lod_active(), true)
	if GameManager.has_signal("boss_intro_requested") and not GameManager.boss_intro_requested.is_connected(_on_boss_intro_requested):
		GameManager.boss_intro_requested.connect(_on_boss_intro_requested)
	if GameManager.has_signal("boss_phase_transition_requested") and not GameManager.boss_phase_transition_requested.is_connected(_on_boss_phase_transition_requested):
		GameManager.boss_phase_transition_requested.connect(_on_boss_phase_transition_requested)
	_update_world(_get_center())


func configure_run_theme(new_run_seed: int, theme_id: String = "") -> void:
	run_seed = maxi(1, absi(new_run_seed))
	var next_theme := theme_id if theme_id != "" else RUN_THEME.select_theme_id(run_seed)
	if not THEME_PROFILES.has(next_theme):
		next_theme = "rift_void"
	var theme_changed := current_theme_id != next_theme or floor_texture == null
	current_theme_id = next_theme
	current_theme = _profile_for_id(current_theme_id)
	_apply_theme_exports()
	if theme_changed:
		_load_theme_textures()
	time_accum = 0.0
	evolution_interval = 60.0 + _hash01(run_seed, 0, 503) * 30.0
	boss_flash_timer = 0.0
	boss_phase_wave_timer = 0.0
	last_decor_cell = Vector2i(999999, 999999)
	if dust_particles != null:
		dust_particles.color = current_theme.get("dust_color", Color.WHITE)
	_update_world(_get_center())


func _process(delta: float) -> void:
	time_accum += delta
	boss_flash_timer = maxf(boss_flash_timer - delta, 0.0)
	boss_phase_wave_timer = maxf(boss_phase_wave_timer - delta, 0.0)
	_apply_visual_lod_state(_mobile_lod_active())
	_update_world(_get_center())
	# No continuously redrawn paths, giant crack overlays, or screen edge props.
	if boss_phase_wave_timer > 0.0:
		queue_redraw()
	elif has_meta("boss_wave_visible"):
		remove_meta("boss_wave_visible")
		queue_redraw()


func _ensure_ground() -> void:
	ground_sprite = Sprite2D.new()
	ground_sprite.name = "R33WorldStoneFloor"
	ground_sprite.centered = false
	ground_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	ground_sprite.material = ground_material
	add_child(ground_sprite)


func _update_world(center: Vector2) -> void:
	global_position = center
	var view_span := _world_view_span() + Vector2(192.0, 192.0)
	var floor_origin := center - view_span * 0.5
	ground_sprite.position = -view_span * 0.5
	ground_sprite.scale = view_span / Vector2(960.0, 768.0)
	ground_material.set_shader_parameter("world_origin", floor_origin)
	if view_span != last_view_span:
		ground_material.set_shader_parameter("world_span", view_span)
		last_view_span = view_span
	var coverage := Vector2i(ceili(view_span.x / (DECOR_CELL_SIZE * 2.0)), ceili(view_span.y / (DECOR_CELL_SIZE * 2.0)))
	# Smooth camera zoom changes the one floor quad every frame, but only a
	# coverage-cell change needs a prop rebuild / particle bound refresh.
	if coverage != last_coverage:
		last_coverage = coverage
		last_decor_cell = Vector2i(999999, 999999)
		_update_dust_bounds()
	last_ground_origin = floor_origin
	var center_cell := Vector2i(floori(center.x / DECOR_CELL_SIZE), floori(center.y / DECOR_CELL_SIZE))
	if center_cell != last_decor_cell:
		_rebuild_decor(center)
	for index in range(decor_states.size()):
		var entry := decor_states[index]
		decor_sprites[index].position = (entry["world_position"] as Vector2) - center


func _ensure_decor_pool() -> void:
	for index in range(DECOR_POOL_SIZE):
		var sprite := Sprite2D.new()
		sprite.name = "R33RuinsProp%02d" % index
		sprite.z_index = 2
		sprite.visible = false
		add_child(sprite)
		decor_sprites.append(sprite)


func _rebuild_decor(center: Vector2) -> void:
	last_decor_cell = Vector2i(floori(center.x / DECOR_CELL_SIZE), floori(center.y / DECOR_CELL_SIZE))
	decor_rebuild_count += 1
	decor_states = _build_decor_entries(last_decor_cell, _decor_pool_target_size())
	for index in range(decor_sprites.size()):
		var sprite := decor_sprites[index]
		sprite.visible = index < decor_states.size()
		if not sprite.visible:
			continue
		var entry := decor_states[index]
		sprite.texture = decor_textures.get(str(entry["decor_id"]))
		sprite.position = (entry["world_position"] as Vector2) - center
		sprite.scale = Vector2.ONE * float(entry["scale"])
		sprite.flip_h = bool(entry.get("flip_h", false))
		sprite.z_index = 1 if str(entry["decor_id"]) == "seal" else 2
		sprite.modulate = Color(0.96, 0.96, 0.96, 1.0)


func _build_decor_entries(base_cell: Vector2i, max_count: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var view := _world_view_span()
	var radius_x := ceili(view.x / (DECOR_CELL_SIZE * 2.0)) + 2
	var radius_y := ceili(view.y / (DECOR_CELL_SIZE * 2.0)) + 2
	var center := Vector2(base_cell) * DECOR_CELL_SIZE
	var zone := Vector2i(floori(center.x / LANDMARK_CELL_SIZE), floori(center.y / LANDMARK_CELL_SIZE))
	for zx in range(zone.x - 1, zone.x + 2):
		for zy in range(zone.y - 1, zone.y + 2):
			if (zx != 0 or zy != 0) and _hash01(zx, zy, 310) > 0.5:
				continue
			var landmark := Vector2(zx, zy) * LANDMARK_CELL_SIZE
			if absf(landmark.x - center.x) > view.x * 0.5 + 400.0 or absf(landmark.y - center.y) > view.y * 0.5 + 300.0:
				continue
			entries.append({"decor_id": "seal", "world_position": landmark, "scale": 0.78})
	for x in range(base_cell.x - radius_x, base_cell.x + radius_x + 1):
		for y in range(base_cell.y - radius_y, base_cell.y + radius_y + 1):
			if _hash01(x, y, 221) > float(current_theme.get("decor_density", 0.28)):
				continue
			var world := Vector2((float(x) + 0.15 + _hash01(x, y, 222) * 0.7) * DECOR_CELL_SIZE, (float(y) + 0.15 + _hash01(x, y, 223) * 0.7) * DECOR_CELL_SIZE)
			if world.length() < 235.0:
				continue
			if absf(world.x - center.x) > view.x * 0.5 + 180.0 or absf(world.y - center.y) > view.y * 0.5 + 180.0:
				continue
			var kind := _hash01(x, y, 224)
			var decor_id := "rubble" if kind < 0.44 else ("column" if kind < 0.68 else ("ward" if kind < 0.88 else "brazier"))
			# LOD omits tiny debris only; landmarks keep their world coordinates.
			if _mobile_lod_active() and decor_id == "rubble" and _hash01(x, y, 225) > 0.65:
				continue
			entries.append({"decor_id": decor_id, "world_position": world, "scale": float(PROP_SCALES[decor_id]) * lerpf(0.87, 1.10, _hash01(x, y, 226)), "flip_h": _hash01(x, y, 227) < 0.5})
	if entries.size() > max_count:
		entries.resize(max_count)
	return entries


func _load_theme_textures() -> void:
	texture_reload_count += 1
	floor_texture = SPRITE_LOADER.get_texture(ART_PREFIX + current_theme_id + "_floor.svg")
	if ground_sprite != null:
		ground_sprite.texture = floor_texture
		ground_material.set_shader_parameter("ground_tex", floor_texture)
	decor_textures.clear()
	for decor_id in PROP_IDS:
		decor_textures[decor_id] = SPRITE_LOADER.get_texture(ART_PREFIX + current_theme_id + "_" + decor_id + ".svg")
	last_decor_cell = Vector2i(999999, 999999)


func _ensure_dust_particles() -> void:
	dust_particles = CPUParticles2D.new()
	dust_particles.name = "R33QuietAtmosphere"
	dust_particles.texture = ART_RESOURCES.get_particle_core()
	dust_particles.material = ART_RESOURCES.get_additive_material()
	dust_particles.lifetime = 8.0
	dust_particles.preprocess = 8.0
	dust_particles.randomness = 0.6
	dust_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust_particles.direction = Vector2(0.3, -0.2)
	dust_particles.spread = 130.0
	dust_particles.gravity = Vector2.ZERO
	dust_particles.initial_velocity_min = 2.0
	dust_particles.initial_velocity_max = 7.0
	dust_particles.scale_amount_min = 0.12
	dust_particles.scale_amount_max = 0.25
	dust_particles.color = current_theme.get("dust_color", Color.WHITE)
	dust_particles.z_index = 3
	add_child(dust_particles)


func _update_dust_bounds() -> void:
	if dust_particles != null:
		dust_particles.emission_rect_extents = _world_view_span() * 0.55


func _apply_visual_lod_state(mobile_lod: bool, force_refresh: bool = false) -> void:
	if not force_refresh and applied_mobile_lod == mobile_lod:
		return
	applied_mobile_lod = mobile_lod
	if dust_particles != null:
		dust_particles.amount = maxi(1, int(round(float(dust_amount) * (0.5 if mobile_lod else 1.0))))
	last_decor_cell = Vector2i(999999, 999999)


func _decor_pool_target_size() -> int:
	return 32 if _mobile_lod_active() else DECOR_POOL_SIZE


func _apply_theme_exports() -> void:
	background_color = current_theme.get("background_color", background_color)
	rift_color = current_theme.get("rift_color", rift_color)
	# Grade belongs to Arena, once. Floor palette already lives in its material.
	if get_parent() != null and get_parent().has_method("set_theme_grade"):
		get_parent().set_theme_grade(current_theme.get("canvas_tone", Color.WHITE))


func _draw() -> void:
	if boss_phase_wave_timer <= 0.0:
		return
	set_meta("boss_wave_visible", true)
	var t := 1.0 - boss_phase_wave_timer / boss_phase_wave_duration
	var color: Color = current_theme.get("boss_flash_color", Color.WHITE)
	draw_arc(Vector2.ZERO, lerpf(20.0, _world_view_span().length() * 0.55, t), 0.0, TAU, 48, Color(color.r, color.g, color.b, (1.0 - t) * 0.26), lerpf(4.0, 1.0, t))


func get_theme_id() -> String:
	return current_theme_id


func get_theme_name() -> String:
	return RUN_THEME.get_theme_name(current_theme_id)


func get_decor_signature_for_center(center: Vector2 = Vector2.ZERO, max_entries: int = 24) -> String:
	var cell := Vector2i(floori(center.x / DECOR_CELL_SIZE), floori(center.y / DECOR_CELL_SIZE))
	var parts: Array[String] = []
	for entry in _build_decor_entries(cell, max_entries):
		var pos: Vector2 = entry["world_position"]
		parts.append("%s@%d,%d:%.2f" % [entry["decor_id"], roundi(pos.x), roundi(pos.y), float(entry["scale"])])
	return "|".join(parts)


func get_background_evolution_signature(center: Vector2 = Vector2.ZERO, elapsed: float = 0.0) -> String:
	return "%s:%d:%d,%d:%.3f" % [current_theme_id, _evolution_step_for_time(elapsed), floori(center.x / DECOR_CELL_SIZE), floori(center.y / DECOR_CELL_SIZE), _hash01(run_seed, floori(center.x / DECOR_CELL_SIZE), 504)]


func _evolution_step_for_time(elapsed: float) -> int:
	return floori(maxf(0.0, elapsed) / maxf(1.0, evolution_interval))


func _on_boss_intro_requested(_boss_name: String) -> void:
	boss_flash_timer = boss_flash_duration


func _on_boss_phase_transition_requested() -> void:
	boss_flash_timer = boss_flash_duration
	boss_phase_wave_timer = boss_phase_wave_duration


func trigger_boss_flash_for_test() -> void:
	_on_boss_intro_requested("test")


func _boss_flash_ratio() -> float:
	return sin(clampf(boss_flash_timer / boss_flash_duration, 0.0, 1.0) * PI)


func debug_set_parallax_quality(quality: String) -> void:
	# Compatibility input: quality controls LOD only; legacy framing is retired.
	forced_parallax_quality = quality if quality in ["auto", "low", "medium", "high"] else "auto"
	_apply_visual_lod_state(_mobile_lod_active(), true)


func _resolved_parallax_quality() -> String:
	return forced_parallax_quality if forced_parallax_quality != "auto" else ("low" if _mobile_lod_active() else "high")


func get_mobile_lod_debug_state() -> Dictionary:
	return {"mobile_lod": _mobile_lod_active(), "applied_mobile_lod": applied_mobile_lod, "dust_amount": dust_particles.amount if dust_particles != null else 0, "decor_target": _decor_pool_target_size(), "dynamic_multiplier": 0.5 if _mobile_lod_active() else 1.0, "parallax_quality": _resolved_parallax_quality(), "parallax_layers": [], "parallax_runtime_refs": {}, "renderer": "r33_world_ruins", "floor_quads": floor_quad_count, "active_props": decor_states.size()}


func get_r33_debug_state() -> Dictionary:
	return {"theme": current_theme_id, "floor_path": ART_PREFIX + current_theme_id + "_floor.svg", "world_center": _get_center(), "floor_origin": last_ground_origin, "world_span": last_view_span, "floor_quads": floor_quad_count, "prop_pool": decor_sprites.size(), "active_props": decor_states.size(), "texture_reload_count": texture_reload_count, "decor_rebuild_count": decor_rebuild_count, "legacy_parallax_nodes": 0, "legacy_crack_nodes": 0, "mobile": _mobile_lod_active()}


func _profile_for_id(theme_id: String) -> Dictionary:
	return (THEME_PROFILES.get(theme_id, THEME_PROFILES["rift_void"]) as Dictionary).duplicate(true)


func _mobile_lod_active() -> bool:
	return forced_parallax_quality == "low" or MOBILE_TUNING.mobile_lod_enabled(_viewport_size())


func _viewport_size() -> Vector2:
	return get_viewport_rect().size if get_viewport_rect().size != Vector2.ZERO else Vector2(1280.0, 720.0)


func _world_view_span() -> Vector2:
	var camera := get_viewport().get_camera_2d()
	return _viewport_size() / camera.zoom if camera != null else _viewport_size()


func _get_center() -> Vector2:
	if debug_center_override is Vector2:
		return debug_center_override
	if GameManager.player != null and is_instance_valid(GameManager.player):
		return GameManager.player.global_position
	return Vector2.ZERO


func _hash01(x: int, y: int, salt: int) -> float:
	var value := x * 374761393 + y * 668265263 + run_seed * 1442695041 + salt * 982451653
	value = (value ^ (value >> 13)) * 1274126177
	value = value ^ (value >> 16)
	return float(absi(value) % 100000) / 100000.0
