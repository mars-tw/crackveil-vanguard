extends Node2D

const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")
const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const RUN_THEME := preload("res://scripts/arena/run_theme.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const GROUND_SHADER := preload("res://scripts/arena/r34_raster_ground.gdshader")
const DECOR_POOL_SIZE := 0
# One complete painted stage. Standard battle cameras see the outer scenery,
# rather than magnifying only the quiet middle of a 2200-unit source plane.
const MAP_WORLD_SPAN := Vector2(1240.0, 790.0)
const MAP_PATHS: Dictionary = {
	"rift_void": "res://assets/art/r34/map_moon.png",
	"wasteland_farm": "res://assets/art/r34/map_garden.png",
	"ember_rift": "res://assets/art/r34/map_ember.png",
	"storm_isles": "res://assets/art/r34/map_storm.png",
	"star_frost": "res://assets/art/r34/map_ice.png",
	"veil_court": "res://assets/art/r34/map_veil.png"
}
const THEME_PROFILES: Dictionary = {
	"rift_void": {"background_color": Color("9faebd"), "rift_color": Color("9aa9d9"), "dust_color": Color(0.58, 0.67, 0.85, 0.14), "boss_flash_color": Color("9291c8")},
	"wasteland_farm": {"background_color": Color("728657"), "rift_color": Color("7fcbb6"), "dust_color": Color(0.66, 0.76, 0.55, 0.13), "boss_flash_color": Color("76bea4")},
	"ember_rift": {"background_color": Color("504854"), "rift_color": Color("bd83b3"), "dust_color": Color(0.80, 0.51, 0.45, 0.15), "boss_flash_color": Color("d09d74")},
	"storm_isles": {"background_color": Color("8c9ab2"), "rift_color": Color("70bed6"), "dust_color": Color(0.49, 0.71, 0.88, 0.14), "boss_flash_color": Color("8aa8e3")},
	"star_frost": {"background_color": Color("adbcd3"), "rift_color": Color("9cbeec"), "dust_color": Color(0.67, 0.78, 0.96, 0.13), "boss_flash_color": Color("b9ceec")},
	"veil_court": {"background_color": Color("8f869d"), "rift_color": Color("bd9bdf"), "dust_color": Color(0.76, 0.59, 0.90, 0.14), "boss_flash_color": Color("d9badf")}
}

@export var background_color: Color = Color("9faebd")
@export var rift_color: Color = Color("9aa9d9")
@export var nebula_color: Color = Color.TRANSPARENT
@export var dust_amount: int = 14

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
var floor_texture: Texture2D = null
var last_view_span := Vector2.ZERO
var last_ground_origin := Vector2.ZERO
var seed_offset := Vector2.ZERO
var texture_reload_count: int = 0
var debug_center_override: Variant = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	current_theme = _profile_for_id(current_theme_id)
	ground_sprite = Sprite2D.new()
	ground_sprite.name = "R34WorldPaintedMap"
	ground_sprite.centered = false
	ground_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	ground_sprite.material = ground_material
	add_child(ground_sprite)
	_load_theme_texture()
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
	if not MAP_PATHS.has(next_theme):
		next_theme = "rift_void"
	var changed := current_theme_id != next_theme or floor_texture == null
	current_theme_id = next_theme
	current_theme = _profile_for_id(current_theme_id)
	_apply_theme_exports()
	if changed:
		_load_theme_texture()
	_apply_seed_offset()
	time_accum = 0.0
	evolution_interval = 60.0 + _hash01(run_seed, 0, 503) * 30.0
	boss_flash_timer = 0.0
	boss_phase_wave_timer = 0.0
	if dust_particles != null:
		dust_particles.color = current_theme.get("dust_color", Color.WHITE)
	_update_world(_get_center())


func _load_theme_texture() -> void:
	texture_reload_count += 1
	floor_texture = SPRITE_LOADER.get_texture(str(MAP_PATHS[current_theme_id]))
	ground_sprite.texture = floor_texture
	ground_material.set_shader_parameter("ground_tex", floor_texture)
	ground_material.set_shader_parameter("map_world_span", MAP_WORLD_SPAN)
	_apply_seed_offset()


func _apply_seed_offset() -> void:
	seed_offset = Vector2(lerpf(-48.0, 48.0, _hash01(run_seed, 0, 34)), lerpf(-48.0, 48.0, _hash01(run_seed, 1, 34)))
	ground_material.set_shader_parameter("seed_offset", seed_offset)


func _process(delta: float) -> void:
	time_accum += delta
	boss_flash_timer = maxf(boss_flash_timer - delta, 0.0)
	boss_phase_wave_timer = maxf(boss_phase_wave_timer - delta, 0.0)
	_apply_visual_lod_state(_mobile_lod_active())
	_update_world(_get_center())
	if boss_phase_wave_timer > 0.0:
		queue_redraw()
	elif has_meta("boss_wave_visible"):
		remove_meta("boss_wave_visible")
		queue_redraw()


func _update_world(center: Vector2) -> void:
	var camera := get_viewport().get_camera_2d()
	# Camera limits can stop the view while the hero still crosses the stage.
	# Center the cover quad on the real view, not the hero, and retain world UVs.
	var render_center: Vector2 = camera.get_screen_center_position() if camera != null else center
	global_position = render_center
	var view_span := _world_view_span() + Vector2(160.0, 160.0)
	var floor_origin := render_center - view_span * 0.5
	ground_sprite.position = -view_span * 0.5
	if floor_texture != null:
		ground_sprite.scale = view_span / floor_texture.get_size()
	ground_material.set_shader_parameter("world_origin", floor_origin)
	if view_span != last_view_span:
		ground_material.set_shader_parameter("world_span", view_span)
		last_view_span = view_span
		_update_dust_bounds()
	last_ground_origin = floor_origin


func _ensure_dust_particles() -> void:
	dust_particles = CPUParticles2D.new()
	dust_particles.name = "R34QuietAtmosphere"
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
	dust_particles.initial_velocity_max = 6.0
	dust_particles.scale_amount_min = 0.08
	dust_particles.scale_amount_max = 0.18
	dust_particles.color = current_theme.get("dust_color", Color.WHITE)
	dust_particles.z_index = 1
	add_child(dust_particles)


func _update_dust_bounds() -> void:
	if dust_particles != null:
		dust_particles.emission_rect_extents = _world_view_span() * 0.55


func _apply_visual_lod_state(mobile_lod: bool, force_refresh: bool = false) -> void:
	if not force_refresh and applied_mobile_lod == mobile_lod:
		return
	applied_mobile_lod = mobile_lod
	if dust_particles != null:
		dust_particles.amount = 6 if mobile_lod else dust_amount


func _apply_theme_exports() -> void:
	background_color = current_theme.get("background_color", background_color)
	rift_color = current_theme.get("rift_color", rift_color)
	if get_parent() != null and get_parent().has_method("set_theme_grade"):
		get_parent().set_theme_grade(Color.WHITE)


func _draw() -> void:
	if boss_phase_wave_timer <= 0.0:
		return
	set_meta("boss_wave_visible", true)
	var t := 1.0 - boss_phase_wave_timer / boss_phase_wave_duration
	var color: Color = current_theme.get("boss_flash_color", Color.WHITE)
	draw_arc(Vector2.ZERO, lerpf(20.0, _world_view_span().length() * 0.55, t), 0.0, TAU, 48, Color(color.r, color.g, color.b, (1.0 - t) * 0.20), lerpf(3.0, 1.0, t))


func get_theme_id() -> String:
	return current_theme_id


func get_theme_name() -> String:
	return RUN_THEME.get_theme_name(current_theme_id)


func get_decor_signature_for_center(center: Vector2 = Vector2.ZERO, _max_entries: int = 24) -> String:
	return "%s:painted_map@%.2f,%.2f:seed=%d:cell=%d,%d" % [current_theme_id, seed_offset.x, seed_offset.y, run_seed, floori(center.x / MAP_WORLD_SPAN.x), floori(center.y / MAP_WORLD_SPAN.y)]


func get_background_evolution_signature(center: Vector2 = Vector2.ZERO, elapsed: float = 0.0) -> String:
	return "%s:atmosphere=%d:world=%d,%d:seed=%d" % [current_theme_id, _evolution_step_for_time(elapsed), floori(center.x / 248.0), floori(center.y / 248.0), run_seed]


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
	forced_parallax_quality = quality if quality in ["auto", "low", "medium", "high"] else "auto"
	_apply_visual_lod_state(_mobile_lod_active(), true)


func _resolved_parallax_quality() -> String:
	return forced_parallax_quality if forced_parallax_quality != "auto" else ("low" if _mobile_lod_active() else "high")


func get_mobile_lod_debug_state() -> Dictionary:
	return {"mobile_lod": _mobile_lod_active(), "applied_mobile_lod": applied_mobile_lod, "dust_amount": dust_particles.amount if dust_particles != null else 0, "decor_target": 0, "dynamic_multiplier": 0.43 if _mobile_lod_active() else 1.0, "parallax_quality": _resolved_parallax_quality(), "parallax_layers": [], "parallax_runtime_refs": {}, "renderer": "r34_painted_raster_map", "floor_quads": 1, "active_props": 0, "map_world_span": MAP_WORLD_SPAN, "ground_filter": "linear_mipmap"}


func get_r34_debug_state() -> Dictionary:
	return {"theme": current_theme_id, "floor_path": MAP_PATHS[current_theme_id], "floor_resolution": floor_texture.get_size() if floor_texture != null else Vector2.ZERO, "world_center": _get_center(), "render_center": global_position, "floor_origin": last_ground_origin, "world_span": last_view_span, "map_world_span": MAP_WORLD_SPAN, "seed_offset": seed_offset, "map_world_rect": get_map_world_rect(), "playable_rect": get_playable_rect(), "mirror_repeat": false, "edge_sampling": "clamp", "floor_quads": 1, "prop_pool": 0, "active_props": 0, "texture_reload_count": texture_reload_count, "legacy_parallax_nodes": 0, "legacy_crack_nodes": 0, "legacy_grid_nodes": 0, "mobile": _mobile_lod_active()}


func get_map_world_rect() -> Rect2:
	return Rect2(-MAP_WORLD_SPAN * 0.50 - seed_offset, MAP_WORLD_SPAN)


func get_playable_rect() -> Rect2:
	# The central 50% rectangle lies inside the arena's ground even at its
	# corners, away from painted cliffs, ponds and lava. Root owns colliders.
	return Rect2(-MAP_WORLD_SPAN * 0.25 - seed_offset, MAP_WORLD_SPAN * 0.50)


func get_clear_battle_bounds() -> Rect2:
	# Data for Arena / hero owners that want a bounded stage. This background
	# never teleports a collider or secretly overrides the player's camera.
	return get_playable_rect()


func get_r33_debug_state() -> Dictionary:
	return get_r34_debug_state()


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
