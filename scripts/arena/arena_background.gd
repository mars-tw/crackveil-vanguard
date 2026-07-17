extends Node2D

const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")
const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const RUN_THEME := preload("res://scripts/arena/run_theme.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")

const DEEP_SPACE_TEXTURE_PATH := "res://assets/art/deep_space_gradient.png"
const NEBULA_TEXTURE_PATH := "res://assets/art/nebula_layer.png"
const RIFT_CRACK_TEXTURE_PATH := "res://assets/art/rift_cracks.png"
const VIGNETTE_TEXTURE_PATH := "res://assets/art/vignette.png"
const DECOR_PATH_PREFIX := "res://assets/art/decor/"

const R25_PARALLAX_PATHS: Dictionary = {
	"rift_void": {
		"far": "res://assets/art/r25/parallax/rift_void_far.webp?v=0c3a17d6",
		"mid": "res://assets/art/r25/parallax/rift_void_mid.webp?v=08025cd7",
		"near": "res://assets/art/r25/parallax/rift_void_near.webp?v=b86c781e"
	},
	"wasteland_farm": {
		"far": "res://assets/art/r25/parallax/wasteland_farm_far.webp?v=87654aee",
		"mid": "res://assets/art/r25/parallax/wasteland_farm_mid.webp?v=02680224",
		"near": "res://assets/art/r25/parallax/wasteland_farm_near.webp?v=1200906b"
	},
	"ember_rift": {
		"far": "res://assets/art/r25/parallax/ember_rift_far.webp?v=0076291d",
		"mid": "res://assets/art/r25/parallax/ember_rift_mid.webp?v=f73329c8",
		"near": "res://assets/art/r25/parallax/ember_rift_near.webp?v=cd54bfb8"
	}
}
const R25_PARALLAX_FACTORS: Dictionary = {"far": 0.025, "mid": 0.055, "near": 0.095}
const R25_PARALLAX_LAYERS: Array[String] = ["far", "mid", "near"]

const DECOR_POOL_SIZE := 96
const DECOR_CELL_SIZE := 245.0
const DECOR_GRID_RADIUS_X := 6
const DECOR_GRID_RADIUS_Y := 4
const METEOR_POOL_SIZE := 4

const THEME_PROFILES: Dictionary = {
	"rift_void": {
		"background_color": Color(0.011, 0.024, 0.078),
		"rift_color": Color(0.22, 0.98, 1.0, 0.64),
		"nebula_color": Color(0.54, 0.38, 1.0, 0.42),
		"canvas_tone": Color(0.82, 0.94, 1.0, 1.0),
		"dust_color": Color(0.35, 1.0, 0.96, 0.48),
		"ground_mode": "void",
		"ground_tint": Color(0.5, 0.83, 1.0, 0.32),
		"decor_density": 0.43,
		"decor_alpha": 0.72,
		"lightning_color": Color(0.32, 1.0, 0.98, 0.9),
		"meteor_color": Color(0.62, 0.98, 1.0, 0.78),
		"boss_flash_color": Color(1.0, 0.42, 0.9, 0.86),
		"evolution_hue_step": 0.035,
		"decor": [
			"void_rock_01", "void_rock_02", "void_stump", "void_debris_01",
			"void_bush_ghost", "void_crystal_01", "void_crystal_02", "void_crack_marker"
		]
	},
	"wasteland_farm": {
		"background_color": Color(0.032, 0.086, 0.042),
		"rift_color": Color(0.28, 1.0, 0.74, 0.54),
		"nebula_color": Color(0.2, 0.94, 0.54, 0.25),
		"canvas_tone": Color(0.82, 1.0, 0.78, 1.0),
		"dust_color": Color(0.5, 1.0, 0.36, 0.42),
		"ground_mode": "farm",
		"ground_tint": Color(0.72, 0.98, 0.42, 0.96),
		"decor_density": 0.49,
		"decor_alpha": 0.78,
		"lightning_color": Color(0.36, 1.0, 0.62, 0.82),
		"meteor_color": Color(0.88, 1.0, 0.48, 0.72),
		"boss_flash_color": Color(1.0, 0.2, 0.18, 0.84),
		"evolution_hue_step": 0.026,
		"decor": [
			"farm_rock", "farm_stump", "farm_bush", "farm_wood_stack", "farm_stone_stack",
			"farm_fence_gate", "farm_well", "farm_hay_bale", "farm_dead_oak",
			"farm_ruined_barn"
		]
	},
	"ember_rift": {
		"background_color": Color(0.118, 0.032, 0.018),
		"rift_color": Color(1.0, 0.3, 0.08, 0.66),
		"nebula_color": Color(1.0, 0.24, 0.08, 0.34),
		"canvas_tone": Color(1.0, 0.82, 0.62, 1.0),
		"dust_color": Color(1.0, 0.42, 0.08, 0.48),
		"ground_mode": "ember",
		"ground_tint": Color(1.0, 0.44, 0.15, 0.98),
		"decor_density": 0.47,
		"decor_alpha": 0.78,
		"lightning_color": Color(1.0, 0.43, 0.08, 0.9),
		"meteor_color": Color(1.0, 0.46, 0.1, 0.82),
		"boss_flash_color": Color(0.2, 0.92, 1.0, 0.88),
		"evolution_hue_step": 0.032,
		"decor": [
			"ember_rock_01", "ember_rock_02", "ember_charred_stump", "ember_ash_bush",
			"ember_cinder_stack", "ember_scorched_pine", "ember_ruin_barn",
			"ember_crystal_01", "ember_crystal_02", "ember_lava_crack"
		]
	}
}

const DECOR_DEFINITIONS: Dictionary = {
	"farm_rock": {"path": "farm_rock.png", "min": 0.34, "max": 0.54, "parallax": 0.985},
	"farm_stump": {"path": "farm_stump.png", "min": 0.36, "max": 0.58, "parallax": 0.988},
	"farm_bush": {"path": "farm_bush.png", "min": 0.34, "max": 0.56, "parallax": 0.982, "sway": true},
	"farm_wood_stack": {"path": "farm_wood_stack.png", "min": 0.34, "max": 0.52, "parallax": 0.988},
	"farm_stone_stack": {"path": "farm_stone_stack.png", "min": 0.34, "max": 0.52, "parallax": 0.988},
	"farm_fence_gate": {"path": "farm_fence_gate.png", "min": 0.38, "max": 0.56, "parallax": 0.984},
	"farm_well": {"path": "farm_well.png", "min": 0.34, "max": 0.48, "parallax": 0.99},
	"farm_compost_heap": {"path": "farm_compost_heap.png", "min": 0.32, "max": 0.50, "parallax": 0.986},
	"farm_hay_bale": {"path": "farm_hay_bale.png", "min": 0.28, "max": 0.42, "parallax": 0.987},
	"farm_dead_oak": {"path": "farm_dead_oak.png", "min": 0.24, "max": 0.36, "parallax": 0.975, "sway": true},
	"farm_ruined_barn": {"path": "farm_ruined_barn.png", "min": 0.20, "max": 0.29, "parallax": 0.972},
	"void_rock_01": {"path": "void_rock_01.png", "min": 0.36, "max": 0.56, "parallax": 0.984},
	"void_rock_02": {"path": "void_rock_02.png", "min": 0.34, "max": 0.55, "parallax": 0.986},
	"void_stump": {"path": "void_stump.png", "min": 0.38, "max": 0.60, "parallax": 0.985},
	"void_debris_01": {"path": "void_debris_01.png", "min": 0.34, "max": 0.52, "parallax": 0.987},
	"void_bush_ghost": {"path": "void_bush_ghost.png", "min": 0.32, "max": 0.52, "parallax": 0.981, "sway": true},
	"void_crystal_01": {"path": "void_crystal_01.png", "min": 0.68, "max": 1.1, "parallax": 0.989, "glow": true},
	"void_crystal_02": {"path": "void_crystal_02.png", "min": 0.72, "max": 1.18, "parallax": 0.989, "glow": true},
	"void_crack_marker": {"path": "void_crack_marker.png", "min": 0.78, "max": 1.34, "parallax": 0.994, "glow": true},
	"ember_rock_01": {"path": "ember_rock_01.png", "min": 0.36, "max": 0.58, "parallax": 0.984},
	"ember_rock_02": {"path": "ember_rock_02.png", "min": 0.34, "max": 0.55, "parallax": 0.986},
	"ember_charred_stump": {"path": "ember_charred_stump.png", "min": 0.38, "max": 0.62, "parallax": 0.985},
	"ember_ash_bush": {"path": "ember_ash_bush.png", "min": 0.34, "max": 0.56, "parallax": 0.981, "sway": true},
	"ember_cinder_stack": {"path": "ember_cinder_stack.png", "min": 0.35, "max": 0.55, "parallax": 0.987},
	"ember_scorched_pine": {"path": "ember_scorched_pine.png", "min": 0.28, "max": 0.42, "parallax": 0.976, "sway": true},
	"ember_ruin_barn": {"path": "ember_ruin_barn.png", "min": 0.20, "max": 0.29, "parallax": 0.972},
	"ember_crystal_01": {"path": "ember_crystal_01.png", "min": 0.70, "max": 1.14, "parallax": 0.989, "glow": true},
	"ember_crystal_02": {"path": "ember_crystal_02.png", "min": 0.76, "max": 1.2, "parallax": 0.989, "glow": true},
	"ember_lava_crack": {"path": "ember_lava_crack.png", "min": 0.82, "max": 1.36, "parallax": 0.994, "glow": true}
}

const GROUND_TILE_PATHS: Dictionary = {
	"ground_grass_center_01": "res://assets/art/decor/ground_grass_center_01.png",
	"ground_grass_center_02": "res://assets/art/decor/ground_grass_center_02.png",
	"ground_grass_center_03": "res://assets/art/decor/ground_grass_center_03.png",
	"ground_grass_flower_01": "res://assets/art/decor/ground_grass_flower_01.png",
	"ground_path_c": "res://assets/art/decor/ground_path_c.png",
	"ground_soil_dry_c": "res://assets/art/decor/ground_soil_dry_c.png",
	"ground_soil_wet_c": "res://assets/art/decor/ground_soil_wet_c.png",
	"ground_ember_soil": "res://assets/art/decor/ground_ember_soil.png",
	"ground_ember_path": "res://assets/art/decor/ground_ember_path.png",
	"ground_void_stone": "res://assets/art/decor/ground_void_stone.png"
}

@export var background_color: Color = Color(0.018, 0.026, 0.06)
@export var rift_color: Color = Color(0.31, 0.92, 1.0, 0.46)
@export var nebula_color: Color = Color(0.62, 0.42, 1.0, 0.36)
@export var dust_amount: int = 90

var run_seed: int = 1
var current_theme_id: String = "rift_void"
var current_theme: Dictionary = {}
var last_center_cell: Vector2i = Vector2i(999999, 999999)
var last_decor_cell: Vector2i = Vector2i(999999, 999999)
var time_accum: float = 0.0
var redraw_timer: float = 0.0
var evolution_interval: float = 75.0
var last_evolution_step: int = -1
var boss_flash_timer: float = 0.0
var boss_flash_duration: float = 0.42
var boss_phase_wave_timer: float = 0.0
var boss_phase_wave_duration: float = 0.92
var next_lightning_time: float = 28.0
var lightning_timer: float = 0.0
var lightning_token: int = 0
var next_meteor_time: float = 9.0
var meteor_token: int = 0
var rift_glow: Sprite2D = null
var rift_cracks: Sprite2D = null
var dust_particles: CPUParticles2D = null
var canvas_tone_node: CanvasModulate = null
var vignette_rect: TextureRect = null
var lightning_line: Line2D = null
var deep_space_texture: Texture2D = null
var nebula_texture: Texture2D = null
var rift_crack_texture: Texture2D = null
var vignette_texture: Texture2D = null
var ground_textures: Dictionary = {}
var decor_textures: Dictionary = {}
var decor_sprites: Array[Sprite2D] = []
var decor_states: Array[Dictionary] = []
var meteor_lines: Array[Line2D] = []
var meteor_states: Array[Dictionary] = []
var applied_mobile_lod: bool = false
var mobile_lod_initialized: bool = false
var parallax_sprites: Dictionary = {}
var parallax_runtime_refs: Dictionary = {}
var forced_parallax_quality: String = "auto"


func _ready() -> void:
	deep_space_texture = SPRITE_LOADER.get_texture(DEEP_SPACE_TEXTURE_PATH)
	nebula_texture = SPRITE_LOADER.get_texture(NEBULA_TEXTURE_PATH)
	rift_crack_texture = SPRITE_LOADER.get_texture(RIFT_CRACK_TEXTURE_PATH)
	vignette_texture = SPRITE_LOADER.get_texture(VIGNETTE_TEXTURE_PATH)
	current_theme = _profile_for_id(current_theme_id)
	_load_theme_textures()
	_ensure_parallax_layers()
	_load_parallax_theme()
	_apply_theme_exports()
	_reset_environment_timers()
	_ensure_canvas_tone()
	_ensure_rift_sprites()
	_ensure_dust_particles()
	_ensure_decor_pool()
	_ensure_lightning_pool()
	_ensure_meteor_pool()
	_ensure_vignette()
	_apply_visual_lod_state(_mobile_lod_active(), true)
	if GameManager.has_signal("boss_intro_requested") and not GameManager.boss_intro_requested.is_connected(_on_boss_intro_requested):
		GameManager.boss_intro_requested.connect(_on_boss_intro_requested)
	if GameManager.has_signal("boss_phase_transition_requested") and not GameManager.boss_phase_transition_requested.is_connected(_on_boss_phase_transition_requested):
		GameManager.boss_phase_transition_requested.connect(_on_boss_phase_transition_requested)
	queue_redraw()


func configure_run_theme(new_run_seed: int, theme_id: String = "") -> void:
	run_seed = max(1, abs(new_run_seed))
	current_theme_id = theme_id if theme_id != "" else RUN_THEME.select_theme_id(run_seed)
	current_theme = _profile_for_id(current_theme_id)
	_apply_theme_exports()
	_load_parallax_theme()
	_reset_environment_timers()
	_ensure_canvas_tone()
	_ensure_dust_particles()
	last_decor_cell = Vector2i(999999, 999999)
	last_center_cell = Vector2i(999999, 999999)
	_rebuild_decor(_get_center())
	queue_redraw()


func get_theme_id() -> String:
	return current_theme_id


func get_theme_name() -> String:
	return RUN_THEME.get_theme_name(current_theme_id)


func get_decor_signature_for_center(center: Vector2 = Vector2.ZERO, max_entries: int = 24) -> String:
	var base_cell := Vector2i(floori(center.x / DECOR_CELL_SIZE), floori(center.y / DECOR_CELL_SIZE))
	var entries := _build_decor_entries(base_cell, max_entries)
	var parts: Array[String] = []
	for entry in entries:
		var pos: Vector2 = entry.get("world_position", Vector2.ZERO)
		parts.append("%s@%d,%d:%.2f" % [
			str(entry.get("decor_id", "")),
			int(round(pos.x)),
			int(round(pos.y)),
			float(entry.get("scale", 1.0))
		])
	return "|".join(parts)


func _process(delta: float) -> void:
	time_accum += delta
	if boss_flash_timer > 0.0:
		boss_flash_timer = max(boss_flash_timer - delta, 0.0)
	if boss_phase_wave_timer > 0.0:
		boss_phase_wave_timer = max(boss_phase_wave_timer - delta, 0.0)
	var center := _get_center()
	global_position = center
	var center_cell := Vector2i(floori(center.x / 48.0), floori(center.y / 48.0))
	var evolution_step := _evolution_step_for_time(time_accum)
	var mobile_lod := _mobile_lod_active()
	_apply_visual_lod_state(mobile_lod)
	if evolution_step != last_evolution_step:
		last_evolution_step = evolution_step
		last_decor_cell = Vector2i(999999, 999999)
	_update_rift_sprites(center)
	_update_parallax_layers(center)
	_update_dust_bounds()
	_update_environment_colors()
	_update_decor_positions(center, mobile_lod)
	_update_lightning(delta, center)
	_update_meteors(delta, center)
	redraw_timer -= delta
	if center_cell != last_center_cell or redraw_timer <= 0.0:
		last_center_cell = center_cell
		redraw_timer = 0.14 if mobile_lod else 0.08
		queue_redraw()


func _draw() -> void:
	var center := _get_center()
	var viewport_size := _viewport_size()
	var draw_size := viewport_size * 2.4
	var rect := Rect2(-draw_size * 0.5, draw_size)
	var draw_background := _evolved_color(background_color, 0.85)
	var draw_rift := _evolved_color(rift_color, 1.0)
	var draw_nebula := _evolved_color(nebula_color, 0.85)
	var dynamic_multiplier := MOBILE_TUNING.background_dynamic_multiplier(viewport_size)
	draw_rect(rect, draw_background, true)

	_draw_theme_ground(center, draw_size)
	_draw_tiled(deep_space_texture, center, draw_size, 0.055, 1.45, _evolved_color(Color(0.82, 0.9, 1.0, _deep_space_alpha()), 0.35))
	_draw_tiled(nebula_texture, center + Vector2(time_accum * 12.0, -time_accum * 7.0) * dynamic_multiplier, draw_size, 0.14, 1.25, draw_nebula)
	_draw_tiled(nebula_texture, center + Vector2(-time_accum * 6.0, time_accum * 9.0) * dynamic_multiplier, draw_size, 0.18, 0.86, _secondary_nebula_color())
	_draw_tiled(rift_crack_texture, center, draw_size, 0.34, 1.15, Color(draw_rift.r, draw_rift.g, draw_rift.b, 0.22))

	var ambient_line_count := 8 if dynamic_multiplier < 1.0 else 18
	for index in range(ambient_line_count):
		var seed_vec := center * 0.013 + Vector2(float(index) * 31.7, float(index) * -17.2)
		var x := fposmod(sin(seed_vec.x + time_accum * 0.12 * dynamic_multiplier) * 927.0 + float(index) * 131.0, draw_size.x) - draw_size.x * 0.5
		var y := fposmod(cos(seed_vec.y - time_accum * 0.09 * dynamic_multiplier) * 719.0 + float(index) * 89.0, draw_size.y) - draw_size.y * 0.5
		var length := 34.0 + float(index % 5) * 11.0
		var alpha := 0.06 + float(index % 4) * 0.02
		var from := Vector2(x, y)
		var to := from + Vector2(length, 0.0).rotated(0.62 + float(index) * 0.73)
		draw_line(from, to, Color(draw_rift.r, draw_rift.g, draw_rift.b, alpha * 1.35), 1.0)
	_draw_theme_moment(viewport_size, draw_rift, dynamic_multiplier)
	_draw_boss_phase_wave(viewport_size)


func _draw_theme_moment(viewport_size: Vector2, draw_rift: Color, dynamic_multiplier: float) -> void:
	if dynamic_multiplier < 1.0:
		return
	var pulse := pow(maxf(0.0, sin(time_accum * 0.19 + float(run_seed % 17))), 10.0)
	if pulse <= 0.015:
		return
	if current_theme_id == "ember_rift":
		var spark_count := 6 if dynamic_multiplier < 1.0 else 14
		for index in range(spark_count):
			var x := lerpf(-viewport_size.x * 0.58, viewport_size.x * 0.58, _hash01(index, run_seed, 611))
			var travel := fposmod(time_accum * lerpf(90.0, 180.0, _hash01(index, run_seed, 612)) + _hash01(index, run_seed, 613) * viewport_size.y, viewport_size.y * 1.25)
			var from := Vector2(x, -viewport_size.y * 0.62 + travel)
			var length := lerpf(10.0, 34.0, _hash01(index, run_seed, 614))
			draw_line(from, from + Vector2(-length * 0.22, length), Color(1.0, 0.42, 0.08, pulse * 0.78), 2.0)
	elif current_theme_id == "rift_void":
		var ring_count := 2 if dynamic_multiplier < 1.0 else 4
		for index in range(ring_count):
			var center := Vector2(
				lerpf(-viewport_size.x * 0.46, viewport_size.x * 0.46, _hash01(index, run_seed, 621)),
				lerpf(-viewport_size.y * 0.4, viewport_size.y * 0.4, _hash01(index, run_seed, 622))
			)
			var radius := lerpf(18.0, 82.0, pulse) * (0.7 + float(index) * 0.16)
			draw_arc(center, radius, 0.0, TAU, 28, Color(draw_rift.r, draw_rift.g, draw_rift.b, pulse * 0.24), 2.0)


func _draw_boss_phase_wave(viewport_size: Vector2) -> void:
	if boss_phase_wave_timer <= 0.0:
		return
	var t := 1.0 - boss_phase_wave_timer / boss_phase_wave_duration
	var color: Color = current_theme.get("boss_flash_color", Color(0.82, 0.42, 1.0, 1.0))
	var radius := lerpf(24.0, viewport_size.length() * 0.62, t)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color.r, color.g, color.b, (1.0 - t) * 0.86), lerpf(10.0, 2.0, t))


func _draw_theme_ground(center: Vector2, draw_size: Vector2) -> void:
	var ground_mode := str(current_theme.get("ground_mode", "void"))
	if ground_mode == "void":
		_draw_void_stone_speckles(center, draw_size)
		return
	_draw_ground_tile_field(center, draw_size, ground_mode)


func _draw_void_stone_speckles(center: Vector2, draw_size: Vector2) -> void:
	var texture: Texture2D = ground_textures.get("ground_void_stone")
	if texture == null:
		return
	var tile_size := 128.0
	var min_x := floori((center.x - draw_size.x * 0.5) / tile_size) - 1
	var max_x := ceili((center.x + draw_size.x * 0.5) / tile_size) + 1
	var min_y := floori((center.y - draw_size.y * 0.5) / tile_size) - 1
	var max_y := ceili((center.y + draw_size.y * 0.5) / tile_size) + 1
	var tint: Color = current_theme.get("ground_tint", Color(0.5, 0.83, 1.0, 0.32))
	tint = _evolved_color(tint, 0.45)
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			if _hash01(x, y, 71) > 0.34:
				continue
			var world := Vector2(float(x) * tile_size, float(y) * tile_size)
			var local := world - center
			var size := tile_size * lerpf(0.46, 0.82, _hash01(x, y, 72))
			var alpha := 0.17 + _hash01(x, y, 73) * 0.14
			var color := Color(tint.r, tint.g, tint.b, alpha)
			draw_texture_rect(texture, Rect2(local - Vector2.ONE * size * 0.5, Vector2.ONE * size), false, color)


func _draw_ground_tile_field(center: Vector2, draw_size: Vector2, ground_mode: String) -> void:
	var tile_size := 96.0
	var min_x := floori((center.x - draw_size.x * 0.5) / tile_size) - 1
	var max_x := ceili((center.x + draw_size.x * 0.5) / tile_size) + 1
	var min_y := floori((center.y - draw_size.y * 0.5) / tile_size) - 1
	var max_y := ceili((center.y + draw_size.y * 0.5) / tile_size) + 1
	var tint: Color = _evolved_color(current_theme.get("ground_tint", Color.WHITE), 0.45)
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var texture := _ground_texture_for_cell(ground_mode, x, y)
			if texture == null:
				continue
			var local := Vector2(float(x) * tile_size, float(y) * tile_size) - center
			var cell_tint := _ground_cell_tint(tint, x, y)
			draw_texture_rect(texture, Rect2(local, Vector2.ONE * tile_size), false, cell_tint)
			if _hash01(x, y, 121) < 0.22:
				draw_rect(Rect2(local, Vector2.ONE * tile_size), Color(cell_tint.r, cell_tint.g, cell_tint.b, 0.075), false, 1.0)


func _ground_texture_for_cell(ground_mode: String, x: int, y: int) -> Texture2D:
	var roll := _hash01(x, y, 101)
	if ground_mode == "ember":
		if roll < 0.44:
			return ground_textures.get("ground_ember_soil")
		if roll < 0.70:
			return ground_textures.get("ground_ember_path")
		if roll < 0.88:
			return ground_textures.get("ground_soil_dry_c")
		return ground_textures.get("ground_void_stone")
	if roll < 0.58:
		var grass_index := int(_hash_int(x, y, 102) % 3) + 1
		return ground_textures.get("ground_grass_center_0%d" % grass_index)
	if roll < 0.68:
		return ground_textures.get("ground_grass_flower_01")
	if roll < 0.82:
		return ground_textures.get("ground_path_c")
	if roll < 0.94:
		return ground_textures.get("ground_soil_dry_c")
	return ground_textures.get("ground_soil_wet_c")


func _draw_tiled(texture: Texture2D, center: Vector2, draw_size: Vector2, parallax: float, tile_scale: float, color: Color) -> void:
	if texture == null:
		return
	var texture_size := Vector2(float(texture.get_width()), float(texture.get_height())) * tile_scale
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var offset := Vector2(
		fposmod(-center.x * parallax, texture_size.x),
		fposmod(-center.y * parallax, texture_size.y)
	)
	var start := -draw_size * 0.5 - offset - texture_size
	var columns := int(ceil(draw_size.x / texture_size.x)) + 3
	var rows := int(ceil(draw_size.y / texture_size.y)) + 3
	for x in range(columns):
		for y in range(rows):
			var position := start + Vector2(float(x) * texture_size.x, float(y) * texture_size.y)
			draw_texture_rect(texture, Rect2(position, texture_size), false, color)


func _ensure_canvas_tone() -> void:
	var tone_color: Color = _evolved_color(current_theme.get("canvas_tone", Color(0.86, 0.94, 1.0, 1.0)), 0.35)
	var existing: CanvasModulate = null
	if get_parent() != null:
		existing = get_parent().get_node_or_null("R10CanvasTone") as CanvasModulate
	if existing != null:
		existing.color = tone_color
		canvas_tone_node = existing
		return
	var tone := CanvasModulate.new()
	tone.name = "R10CanvasTone"
	tone.color = tone_color
	canvas_tone_node = tone
	if get_parent() != null:
		get_parent().call_deferred("add_child", tone)


func _ensure_rift_sprites() -> void:
	rift_glow = get_node_or_null("RiftGlow") as Sprite2D
	if rift_glow == null:
		rift_glow = Sprite2D.new()
		rift_glow.name = "RiftGlow"
		add_child(rift_glow)
	rift_glow.texture = ART_RESOURCES.get_radial_glow()
	rift_glow.centered = true
	rift_glow.material = ART_RESOURCES.get_additive_material()
	rift_glow.z_index = 40

	rift_cracks = get_node_or_null("RiftCracks") as Sprite2D
	if rift_cracks == null:
		rift_cracks = Sprite2D.new()
		rift_cracks.name = "RiftCracks"
		add_child(rift_cracks)
	rift_cracks.texture = rift_crack_texture
	rift_cracks.centered = true
	rift_cracks.material = ART_RESOURCES.get_additive_material()
	rift_cracks.z_index = 42


func _ensure_parallax_layers() -> void:
	var stack := get_node_or_null("R25ParallaxStack") as Node2D
	if stack == null:
		stack = Node2D.new()
		stack.name = "R25ParallaxStack"
		add_child(stack)
	for index in range(R25_PARALLAX_LAYERS.size()):
		var layer_name := R25_PARALLAX_LAYERS[index]
		var sprite := stack.get_node_or_null(layer_name.capitalize()) as Sprite2D
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.name = layer_name.capitalize()
			stack.add_child(sprite)
		sprite.centered = true
		sprite.z_index = index + 1
		parallax_sprites[layer_name] = sprite


func _load_parallax_theme() -> void:
	_ensure_parallax_layers()
	parallax_runtime_refs.clear()
	var theme_paths: Dictionary = R25_PARALLAX_PATHS.get(current_theme_id, R25_PARALLAX_PATHS["rift_void"])
	for layer_name in R25_PARALLAX_LAYERS:
		var runtime_ref := str(theme_paths.get(layer_name, ""))
		var sprite: Sprite2D = parallax_sprites.get(layer_name)
		if sprite != null:
			sprite.texture = SPRITE_LOADER.get_texture(runtime_ref)
		parallax_runtime_refs[layer_name] = runtime_ref
	_apply_parallax_quality()
	_update_parallax_layers(_get_center())


func _update_parallax_layers(center: Vector2) -> void:
	var viewport_size := _viewport_size()
	for layer_name in R25_PARALLAX_LAYERS:
		var sprite: Sprite2D = parallax_sprites.get(layer_name)
		if sprite == null or sprite.texture == null:
			continue
		var texture_size := Vector2(float(sprite.texture.get_width()), float(sprite.texture.get_height()))
		if texture_size.x <= 0.0 or texture_size.y <= 0.0:
			continue
		# Independent visual roots stay separate from the physics/camera root. A small
		# overscan keeps the full generated composition visible at every viewport.
		sprite.scale = Vector2(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y) * 1.08
		var factor := float(R25_PARALLAX_FACTORS.get(layer_name, 0.0))
		var max_offset := viewport_size * (0.022 + factor * 0.12)
		sprite.position = Vector2(
			clamp(-center.x * factor, -max_offset.x, max_offset.x),
			clamp(-center.y * factor, -max_offset.y, max_offset.y)
		)


func _resolved_parallax_quality() -> String:
	if forced_parallax_quality in ["low", "medium", "high"]:
		return forced_parallax_quality
	return "low" if _mobile_lod_active() else "high"


func _apply_parallax_quality() -> void:
	var quality := _resolved_parallax_quality()
	for layer_name in R25_PARALLAX_LAYERS:
		var sprite: Sprite2D = parallax_sprites.get(layer_name)
		if sprite == null:
			continue
		sprite.visible = layer_name != "near" or quality != "low"
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.72 if layer_name == "near" and quality == "medium" else 1.0)


func debug_set_parallax_quality(quality: String) -> void:
	forced_parallax_quality = quality if quality in ["auto", "low", "medium", "high"] else "auto"
	_apply_parallax_quality()


func _update_rift_sprites(center: Vector2) -> void:
	if rift_glow == null or rift_cracks == null:
		return
	var dynamic_multiplier := MOBILE_TUNING.background_dynamic_multiplier(_viewport_size())
	var seam_offset := Vector2(sin(time_accum * 0.17 * dynamic_multiplier + center.x * 0.001), cos(time_accum * 0.13 * dynamic_multiplier + center.y * 0.001)) * 92.0
	var pulse := 0.5 + 0.5 * sin(time_accum * 2.15 * dynamic_multiplier)
	var surge := pulse * pulse * pulse
	var glow_color := _evolved_color(rift_color, 1.0)
	rift_glow.position = seam_offset
	rift_glow.scale = Vector2.ONE * (4.78 + pulse * 0.34)
	rift_glow.modulate = Color(glow_color.r, glow_color.g, glow_color.b, 0.26 + surge * 0.18)
	rift_cracks.position = seam_offset + Vector2(24.0, -16.0)
	rift_cracks.rotation = 0.2 + sin(time_accum * 0.08) * 0.08
	rift_cracks.scale = Vector2.ONE * (1.31 + surge * 0.08)
	rift_cracks.modulate = Color(glow_color.r, glow_color.g, glow_color.b, 0.46 + surge * 0.26)


func _ensure_dust_particles() -> void:
	dust_particles = get_node_or_null("VoidDust") as CPUParticles2D
	if dust_particles == null:
		dust_particles = CPUParticles2D.new()
		dust_particles.name = "VoidDust"
		add_child(dust_particles)
	dust_particles.texture = ART_RESOURCES.get_particle_core()
	dust_particles.material = ART_RESOURCES.get_additive_material()
	dust_particles.amount = max(0, int(round(float(dust_amount) * float(current_theme.get("dust_amount_multiplier", 1.0)) * MOBILE_TUNING.lod_particle_multiplier(_viewport_size()))))
	dust_particles.lifetime = 7.5
	dust_particles.preprocess = 7.5
	dust_particles.randomness = 0.72
	dust_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust_particles.direction = Vector2(0.25, -0.08)
	dust_particles.spread = 180.0
	dust_particles.gravity = Vector2.ZERO
	dust_particles.initial_velocity_min = 2.0
	dust_particles.initial_velocity_max = 18.0
	dust_particles.scale_amount_min = 0.18
	dust_particles.scale_amount_max = 0.62
	dust_particles.color = _evolved_color(current_theme.get("dust_color", Color(0.57, 0.96, 1.0, 0.38)), 0.75)
	dust_particles.z_index = 80
	dust_particles.emitting = true
	_update_dust_bounds()


func _update_dust_bounds() -> void:
	if dust_particles == null:
		return
	var viewport_size := _viewport_size()
	dust_particles.emission_rect_extents = viewport_size * (0.56 if MOBILE_TUNING.mobile_lod_enabled(viewport_size) else 0.68)


func _apply_visual_lod_state(mobile_lod: bool, force_refresh: bool = false) -> void:
	if not force_refresh and mobile_lod_initialized and mobile_lod == applied_mobile_lod:
		return
	applied_mobile_lod = mobile_lod
	mobile_lod_initialized = true
	_apply_parallax_quality()
	if vignette_rect != null:
		vignette_rect.modulate = Color(1.0, 1.0, 1.0, 0.6 if mobile_lod else 0.72)
	if dust_particles != null:
		dust_particles.amount = max(0, int(round(float(dust_amount) * float(current_theme.get("dust_amount_multiplier", 1.0)) * MOBILE_TUNING.lod_particle_multiplier(_viewport_size()))))
		_update_dust_bounds()
	if not decor_sprites.is_empty():
		last_decor_cell = Vector2i(999999, 999999)
		_rebuild_decor(_get_center())
	redraw_timer = 0.0
	queue_redraw()


func _ensure_decor_pool() -> void:
	if decor_sprites.size() >= DECOR_POOL_SIZE:
		return
	for index in range(decor_sprites.size(), DECOR_POOL_SIZE):
		var sprite := Sprite2D.new()
		sprite.name = "SeedDecor%02d" % index
		sprite.centered = true
		sprite.visible = false
		sprite.z_index = 14
		add_child(sprite)
		decor_sprites.append(sprite)
		decor_states.append({})


func _rebuild_decor(center: Vector2) -> void:
	_ensure_decor_pool()
	var decor_cell := Vector2i(floori(center.x / DECOR_CELL_SIZE), floori(center.y / DECOR_CELL_SIZE))
	if decor_cell == last_decor_cell:
		return
	last_decor_cell = decor_cell
	var entries := _build_decor_entries(decor_cell, _decor_pool_target_size())
	for index in range(DECOR_POOL_SIZE):
		var sprite := decor_sprites[index]
		if index >= entries.size():
			sprite.visible = false
			decor_states[index] = {}
			continue
		var entry: Dictionary = entries[index]
		var decor_id := str(entry.get("decor_id", ""))
		var definition: Dictionary = DECOR_DEFINITIONS.get(decor_id, {})
		var texture: Texture2D = decor_textures.get(decor_id)
		if texture == null:
			sprite.visible = false
			decor_states[index] = {}
			continue
		sprite.texture = texture
		sprite.scale = Vector2.ONE * float(entry.get("scale", 1.0))
		sprite.rotation = float(entry.get("rotation", 0.0))
		sprite.modulate = _decor_modulate(entry, bool(definition.get("glow", false)))
		sprite.z_index = 16 if bool(definition.get("glow", false)) else 12
		sprite.material = ART_RESOURCES.get_additive_material() if bool(definition.get("glow", false)) else null
		sprite.visible = true
		decor_states[index] = entry
	_update_decor_positions(center, _mobile_lod_active())


func _update_decor_positions(center: Vector2, mobile_lod: bool = false) -> void:
	var decor_cell := Vector2i(floori(center.x / DECOR_CELL_SIZE), floori(center.y / DECOR_CELL_SIZE))
	if decor_cell != last_decor_cell:
		_rebuild_decor(center)
	for index in range(decor_sprites.size()):
		var state: Dictionary = decor_states[index]
		if state.is_empty():
			continue
		var sprite := decor_sprites[index]
		var world_position: Vector2 = state.get("world_position", Vector2.ZERO)
		var parallax := float(state.get("parallax", 0.985))
		if boss_flash_timer > 0.0:
			sprite.modulate = _decor_modulate(state, bool(state.get("glow", false)))
		var sway_offset := 0.0
		if bool(state.get("sway", false)) and not mobile_lod:
			var phase := float(state.get("phase", 0.0))
			var speed := float(state.get("sway_speed", 1.0))
			var amount := float(state.get("sway_amount", 0.018))
			sprite.rotation = float(state.get("rotation", 0.0)) + sin(time_accum * speed + phase) * amount
			sway_offset = sin(time_accum * speed * 0.82 + phase) * 2.2
		elif bool(state.get("glow", false)) and not mobile_lod:
			var pulse := 0.5 + 0.5 * sin(time_accum * 2.4 + float(state.get("phase", 0.0)))
			sprite.modulate.a = float(state.get("alpha", 0.58)) * (0.82 + pulse * 0.28)
		sprite.position = (world_position - center) * parallax + Vector2(sway_offset, 0.0)


func _build_decor_entries(base_cell: Vector2i, max_count: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var decor_ids: Array = current_theme.get("decor", [])
	if decor_ids.is_empty():
		return entries
	var base_density := float(current_theme.get("decor_density", 0.32)) * MOBILE_TUNING.background_decor_multiplier(_viewport_size())
	for y in range(-DECOR_GRID_RADIUS_Y, DECOR_GRID_RADIUS_Y + 1):
		for x in range(-DECOR_GRID_RADIUS_X, DECOR_GRID_RADIUS_X + 1):
			if entries.size() >= max_count:
				return entries
			var cell := Vector2i(base_cell.x + x, base_cell.y + y)
			var density := _decor_density_for_cell(cell, base_density)
			var roll := _hash01(cell.x, cell.y, 211)
			if roll > density:
				continue
			var decor_index := int(_hash_int(cell.x, cell.y, 212) % decor_ids.size())
			var decor_id := str(decor_ids[decor_index])
			var definition: Dictionary = DECOR_DEFINITIONS.get(decor_id, {})
			if definition.is_empty():
				continue
			var jitter := Vector2(
				(_hash01(cell.x, cell.y, 213) - 0.5) * DECOR_CELL_SIZE * 0.58,
				(_hash01(cell.x, cell.y, 214) - 0.5) * DECOR_CELL_SIZE * 0.58
			)
			var world_position := Vector2(
				(float(cell.x) + 0.5) * DECOR_CELL_SIZE,
				(float(cell.y) + 0.5) * DECOR_CELL_SIZE
			) + jitter
			var min_scale := float(definition.get("min", 0.4))
			var max_scale := float(definition.get("max", 0.7))
			var scale_value := lerpf(min_scale, max_scale, _hash01(cell.x, cell.y, 215))
			entries.append({
				"decor_id": decor_id,
				"world_position": world_position,
				"scale": scale_value,
				"rotation": lerpf(-0.045, 0.045, _hash01(cell.x, cell.y, 216)),
				"parallax": float(definition.get("parallax", 0.985)),
				"sway": bool(definition.get("sway", false)),
				"glow": bool(definition.get("glow", false)),
				"phase": _hash01(cell.x, cell.y, 217) * TAU,
				"sway_speed": lerpf(0.72, 1.34, _hash01(cell.x, cell.y, 218)),
				"sway_amount": lerpf(0.012, 0.028, _hash01(cell.x, cell.y, 219)),
				"alpha": lerpf(0.72, 1.0, _hash01(cell.x, cell.y, 220)) * float(current_theme.get("decor_alpha", 0.58))
			})
	return entries


func _decor_modulate(entry: Dictionary, glow: bool) -> Color:
	var alpha := float(entry.get("alpha", 0.58))
	if glow:
		var glow_color: Color = _evolved_color(current_theme.get("rift_color", Color.WHITE), 0.95)
		return Color(glow_color.r, glow_color.g, glow_color.b, alpha)
	if current_theme_id == "wasteland_farm":
		var farm_color := _evolved_color(Color(0.62, 0.96, 0.42, alpha), 0.3)
		return Color(farm_color.r, farm_color.g, farm_color.b, alpha)
	if current_theme_id == "ember_rift":
		var ember_color := _evolved_color(Color(1.0, 0.56, 0.32, alpha), 0.3)
		return Color(ember_color.r, ember_color.g, ember_color.b, alpha)
	var void_color := _evolved_color(Color(0.56, 0.9, 1.0, alpha), 0.3)
	return Color(void_color.r, void_color.g, void_color.b, alpha)


func _ensure_lightning_pool() -> void:
	lightning_line = get_node_or_null("RiftLightning") as Line2D
	if lightning_line == null:
		lightning_line = Line2D.new()
		lightning_line.name = "RiftLightning"
		add_child(lightning_line)
	lightning_line.visible = false
	lightning_line.width = 2.0
	lightning_line.z_index = 34
	lightning_line.material = ART_RESOURCES.get_additive_material()


func _update_lightning(_delta: float, _center: Vector2) -> void:
	if lightning_line == null:
		return
	if time_accum >= next_lightning_time:
		_trigger_lightning()
	if lightning_timer <= 0.0:
		lightning_line.visible = false
		return
	lightning_timer = max(lightning_timer - _delta, 0.0)
	var ratio := lightning_timer / 0.26
	var color: Color = _evolved_color(current_theme.get("lightning_color", Color(0.48, 0.96, 1.0, 0.82)), 0.85)
	lightning_line.default_color = Color(color.r, color.g, color.b, color.a * ratio)
	lightning_line.width = 1.0 + ratio * 2.5
	lightning_line.visible = lightning_timer > 0.0


func _trigger_lightning() -> void:
	lightning_token += 1
	var viewport_size := _viewport_size()
	var mobile_lod := MOBILE_TUNING.mobile_lod_enabled(viewport_size)
	var start := Vector2(
		-viewport_size.x * 0.58,
		lerpf(-viewport_size.y * 0.42, viewport_size.y * 0.18, _hash01(lightning_token, run_seed, 301))
	)
	var end := Vector2(
		viewport_size.x * 0.58,
		start.y + lerpf(-96.0, 96.0, _hash01(lightning_token, run_seed, 302))
	)
	var points := PackedVector2Array()
	var segments := 5 if mobile_lod else 7
	for index in range(segments + 1):
		var t := float(index) / float(segments)
		var point := start.lerp(end, t)
		point.y += lerpf(-58.0, 58.0, _hash01(lightning_token, index, 303))
		points.append(point)
	lightning_line.points = points
	lightning_timer = 0.26
	next_lightning_time = time_accum + (32.0 if mobile_lod else 20.0) + _hash01(lightning_token, run_seed, 304) * (32.0 if mobile_lod else 20.0)


func _ensure_meteor_pool() -> void:
	if meteor_lines.size() >= METEOR_POOL_SIZE:
		return
	for index in range(meteor_lines.size(), METEOR_POOL_SIZE):
		var line := Line2D.new()
		line.name = "MeteorTrail%02d" % index
		line.width = 2.0
		line.visible = false
		line.z_index = 30
		line.material = ART_RESOURCES.get_additive_material()
		add_child(line)
		meteor_lines.append(line)
		meteor_states.append({
			"active": false,
			"position": Vector2.ZERO,
			"velocity": Vector2.ZERO,
			"age": 0.0,
			"lifetime": 1.0,
			"color": Color.WHITE
		})


func _update_meteors(delta: float, _center: Vector2) -> void:
	if time_accum >= next_meteor_time:
		_trigger_meteor()
	for index in range(meteor_lines.size()):
		var state: Dictionary = meteor_states[index]
		if not bool(state.get("active", false)):
			meteor_lines[index].visible = false
			continue
		var age := float(state.get("age", 0.0)) + delta
		var lifetime := float(state.get("lifetime", 1.0))
		if age >= lifetime:
			state["active"] = false
			meteor_states[index] = state
			meteor_lines[index].visible = false
			continue
		var position: Vector2 = state.get("position", Vector2.ZERO)
		var velocity: Vector2 = state.get("velocity", Vector2.ZERO)
		position += velocity * delta
		state["age"] = age
		state["position"] = position
		meteor_states[index] = state
		var ratio: float = 1.0 - age / max(0.001, lifetime)
		var color: Color = state.get("color", Color.WHITE)
		var line := meteor_lines[index]
		line.position = position
		line.default_color = Color(color.r, color.g, color.b, color.a * ratio)
		line.width = 1.0 + ratio * 2.2
		line.visible = true


func _trigger_meteor() -> void:
	var slot := -1
	for index in range(meteor_states.size()):
		if not bool(meteor_states[index].get("active", false)):
			slot = index
			break
	if slot < 0:
		next_meteor_time = time_accum + 4.0
		return
	meteor_token += 1
	var viewport_size := _viewport_size()
	var mobile_lod := MOBILE_TUNING.mobile_lod_enabled(viewport_size)
	var start := Vector2(
		lerpf(-viewport_size.x * 0.48, viewport_size.x * 0.58, _hash01(meteor_token, run_seed, 401)),
		-viewport_size.y * 0.62
	)
	var direction := Vector2(lerpf(-0.42, 0.42, _hash01(meteor_token, run_seed, 402)), 1.0).normalized()
	var speed := lerpf(210.0, 340.0, _hash01(meteor_token, run_seed, 403))
	var tail_length := lerpf(46.0, 92.0, _hash01(meteor_token, run_seed, 404)) * (0.72 if mobile_lod else 1.0)
	var line := meteor_lines[slot]
	line.points = PackedVector2Array([Vector2.ZERO, -direction * tail_length])
	var color: Color = _evolved_color(current_theme.get("meteor_color", Color(0.76, 0.96, 1.0, 0.68)), 0.8)
	meteor_states[slot] = {
		"active": true,
		"position": start,
		"velocity": direction * speed,
		"age": 0.0,
		"lifetime": lerpf(1.1, 1.7, _hash01(meteor_token, run_seed, 405)),
		"color": color
	}
	next_meteor_time = time_accum + (16.0 if mobile_lod else 7.0) + _hash01(meteor_token, run_seed, 406) * (18.0 if mobile_lod else 12.0)


func _ensure_vignette() -> void:
	if vignette_rect != null and is_instance_valid(vignette_rect):
		return
	var layer := CanvasLayer.new()
	layer.name = "R10VignetteLayer"
	layer.layer = 0
	add_child(layer)
	vignette_rect = TextureRect.new()
	vignette_rect.name = "Vignette"
	vignette_rect.texture = vignette_texture
	vignette_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette_rect.stretch_mode = TextureRect.STRETCH_SCALE
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_rect.modulate = Color(1.0, 1.0, 1.0, 0.72)
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(vignette_rect)


func _profile_for_id(theme_id: String) -> Dictionary:
	if THEME_PROFILES.has(theme_id):
		return (THEME_PROFILES[theme_id] as Dictionary).duplicate(true)
	return (THEME_PROFILES["rift_void"] as Dictionary).duplicate(true)


func _load_theme_textures() -> void:
	ground_textures.clear()
	for key in GROUND_TILE_PATHS.keys():
		ground_textures[str(key)] = SPRITE_LOADER.get_texture(str(GROUND_TILE_PATHS[key]))
	decor_textures.clear()
	for decor_id in DECOR_DEFINITIONS.keys():
		var definition: Dictionary = DECOR_DEFINITIONS[decor_id]
		var path := DECOR_PATH_PREFIX + str(definition.get("path", ""))
		decor_textures[str(decor_id)] = SPRITE_LOADER.get_texture(path)


func _apply_theme_exports() -> void:
	background_color = current_theme.get("background_color", background_color)
	rift_color = current_theme.get("rift_color", rift_color)
	nebula_color = current_theme.get("nebula_color", nebula_color)


func _reset_environment_timers() -> void:
	evolution_interval = 60.0 + _hash01(run_seed, 0, 503) * 30.0
	last_evolution_step = -1
	boss_flash_timer = 0.0
	boss_phase_wave_timer = 0.0
	lightning_token = 0
	meteor_token = 0
	lightning_timer = 0.0
	next_lightning_time = 20.0 + _hash01(run_seed, 0, 501) * 20.0
	next_meteor_time = 7.0 + _hash01(run_seed, 0, 502) * 10.0
	if lightning_line != null:
		lightning_line.visible = false
	for index in range(meteor_states.size()):
		meteor_states[index]["active"] = false
		if index < meteor_lines.size():
			meteor_lines[index].visible = false


func _deep_space_alpha() -> float:
	match str(current_theme.get("ground_mode", "void")):
		"farm":
			return 0.1
		"ember":
			return 0.14
		_:
			return 0.95


func _secondary_nebula_color() -> Color:
	if current_theme_id == "ember_rift":
		return _evolved_color(Color(1.0, 0.62, 0.22, 0.18), 0.55)
	if current_theme_id == "wasteland_farm":
		return _evolved_color(Color(0.12, 0.9, 0.46, 0.17), 0.55)
	return _evolved_color(Color(0.14, 0.86, 1.0, 0.22), 0.55)


func _ground_cell_tint(base: Color, x: int, y: int) -> Color:
	var value_shift := lerpf(0.76, 1.18, _hash01(x, y, 122))
	var alpha_shift := lerpf(0.86, 1.15, _hash01(x, y, 123))
	return Color(
		clamp(base.r * value_shift, 0.0, 1.0),
		clamp(base.g * value_shift, 0.0, 1.0),
		clamp(base.b * value_shift, 0.0, 1.0),
		clamp(base.a * alpha_shift, 0.0, 1.0)
	)


func _decor_density_for_cell(cell: Vector2i, base_density: float) -> float:
	var zone := Vector2i(floori(float(cell.x) / 4.0), floori(float(cell.y) / 3.0))
	var zone_value := _hash01(zone.x, zone.y, 231)
	var wave := 0.5 + 0.5 * sin(float(_evolution_step_for_time(time_accum)) * 0.74 + float(zone.x - zone.y) * 0.37)
	var multiplier := lerpf(0.58, 1.38, zone_value) * lerpf(0.88, 1.12, wave)
	return clamp(base_density * multiplier, 0.16, 0.76)


func _update_environment_colors() -> void:
	if dust_particles != null:
		dust_particles.color = _evolved_color(current_theme.get("dust_color", Color(0.57, 0.96, 1.0, 0.38)), 0.75)
	if canvas_tone_node != null and is_instance_valid(canvas_tone_node):
		canvas_tone_node.color = _evolved_color(current_theme.get("canvas_tone", Color(0.86, 0.94, 1.0, 1.0)), 0.35)


func _mobile_lod_active() -> bool:
	return MOBILE_TUNING.mobile_lod_enabled(_viewport_size())


func _decor_pool_target_size() -> int:
	var multiplier := MOBILE_TUNING.background_decor_multiplier(_viewport_size())
	return clampi(int(round(float(DECOR_POOL_SIZE) * multiplier)), 48, DECOR_POOL_SIZE)


func get_mobile_lod_debug_state() -> Dictionary:
	var visible_layers: Array[String] = []
	for layer_name in R25_PARALLAX_LAYERS:
		var sprite: Sprite2D = parallax_sprites.get(layer_name)
		if sprite != null and sprite.visible and sprite.texture != null:
			visible_layers.append(layer_name)
	return {
		"mobile_lod": _mobile_lod_active(),
		"applied_mobile_lod": applied_mobile_lod,
		"dust_amount": dust_particles.amount if dust_particles != null else 0,
		"decor_target": _decor_pool_target_size(),
		"dynamic_multiplier": MOBILE_TUNING.background_dynamic_multiplier(_viewport_size()),
		"parallax_quality": _resolved_parallax_quality(),
		"parallax_layers": visible_layers,
		"parallax_runtime_refs": parallax_runtime_refs.duplicate(true)
	}


func _on_boss_intro_requested(_boss_name: String) -> void:
	boss_flash_timer = boss_flash_duration
	queue_redraw()


func _on_boss_phase_transition_requested() -> void:
	boss_flash_timer = boss_flash_duration * 1.75
	boss_phase_wave_timer = boss_phase_wave_duration
	queue_redraw()


func trigger_boss_flash_for_test() -> void:
	_on_boss_intro_requested("test")


func get_background_evolution_signature(center: Vector2 = Vector2.ZERO, elapsed: float = 0.0) -> String:
	var old_time := time_accum
	time_accum = elapsed
	var base_cell := Vector2i(floori(center.x / DECOR_CELL_SIZE), floori(center.y / DECOR_CELL_SIZE))
	var density := _decor_density_for_cell(base_cell, float(current_theme.get("decor_density", 0.32)))
	var shifted := _evolved_color_for_time(current_theme.get("background_color", background_color), 0.85, elapsed, false)
	var hue_shift := _hue_shift_for_time(elapsed)
	var step := _evolution_step_for_time(elapsed)
	time_accum = old_time
	return "%s:%d:%.3f:%.3f:%.3f,%.3f,%.3f" % [
		current_theme_id,
		step,
		hue_shift,
		density,
		shifted.r,
		shifted.g,
		shifted.b
	]


func _evolution_step_for_time(elapsed: float) -> int:
	return int(floor(max(0.0, elapsed) / max(1.0, evolution_interval)))


func _hue_shift_for_time(elapsed: float) -> float:
	var interval: float = max(1.0, evolution_interval)
	var phase: float = max(0.0, elapsed) / interval
	var step_float: float = floor(phase)
	var local_t: float = clamp(phase - step_float, 0.0, 1.0)
	var smooth_t: float = local_t * local_t * (3.0 - 2.0 * local_t)
	var direction: float = -1.0 if _hash01(run_seed, 0, 504) < 0.5 else 1.0
	var step_size := float(current_theme.get("evolution_hue_step", 0.03))
	return direction * step_size * (step_float + smooth_t)


func _evolved_color(base: Color, strength: float = 1.0) -> Color:
	return _evolved_color_for_time(base, strength, time_accum, true)


func _evolved_color_for_time(base: Color, strength: float, elapsed: float, include_flash: bool) -> Color:
	var hue_shift: float = _hue_shift_for_time(elapsed) * clamp(strength, 0.0, 1.5)
	var shifted: Color = Color.from_hsv(fposmod(base.h + hue_shift, 1.0), clamp(base.s * (1.0 + 0.08 * strength), 0.0, 1.0), clamp(base.v * (1.0 + 0.035 * strength), 0.0, 1.0), base.a)
	if include_flash:
		var flash: float = _boss_flash_ratio()
		if flash > 0.0:
			var flash_color: Color = current_theme.get("boss_flash_color", Color(1.0, 0.42, 0.9, base.a))
			var inverted: Color = Color(1.0 - shifted.r, 1.0 - shifted.g, 1.0 - shifted.b, shifted.a).lerp(flash_color, 0.46)
			shifted = shifted.lerp(inverted, flash * 0.9)
	return shifted


func _boss_flash_ratio() -> float:
	if boss_flash_timer <= 0.0 or boss_flash_duration <= 0.0:
		return 0.0
	var t: float = clamp(boss_flash_timer / boss_flash_duration, 0.0, 1.0)
	return sin(t * PI)


func _hash_int(x: int, y: int, salt: int) -> int:
	var value := int(x) * 374761393 + int(y) * 668265263 + int(run_seed) * 1442695041 + int(salt) * 982451653
	value = (value ^ (value >> 13)) * 1274126177
	value = value ^ (value >> 16)
	return abs(value)


func _hash01(x: int, y: int, salt: int) -> float:
	return float(_hash_int(x, y, salt) % 100000) / 100000.0


func _viewport_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	return viewport_size


func _get_center() -> Vector2:
	if GameManager.player != null and is_instance_valid(GameManager.player):
		return GameManager.player.global_position
	return Vector2.ZERO
