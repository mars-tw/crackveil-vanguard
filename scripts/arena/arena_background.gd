extends Node2D

const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")
const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const DEEP_SPACE_TEXTURE_PATH := "res://assets/art/deep_space_gradient.png"
const NEBULA_TEXTURE_PATH := "res://assets/art/nebula_layer.png"
const RIFT_CRACK_TEXTURE_PATH := "res://assets/art/rift_cracks.png"
const VIGNETTE_TEXTURE_PATH := "res://assets/art/vignette.png"

@export var background_color: Color = Color(0.018, 0.026, 0.06)
@export var rift_color: Color = Color(0.31, 0.92, 1.0, 0.46)
@export var nebula_color: Color = Color(0.62, 0.42, 1.0, 0.36)
@export var dust_amount: int = 90

var last_center_cell: Vector2i = Vector2i(999999, 999999)
var time_accum: float = 0.0
var redraw_timer: float = 0.0
var rift_glow: Sprite2D = null
var rift_cracks: Sprite2D = null
var dust_particles: CPUParticles2D = null
var vignette_rect: TextureRect = null
var deep_space_texture: Texture2D = null
var nebula_texture: Texture2D = null
var rift_crack_texture: Texture2D = null
var vignette_texture: Texture2D = null


func _ready() -> void:
	deep_space_texture = SPRITE_LOADER.get_texture(DEEP_SPACE_TEXTURE_PATH)
	nebula_texture = SPRITE_LOADER.get_texture(NEBULA_TEXTURE_PATH)
	rift_crack_texture = SPRITE_LOADER.get_texture(RIFT_CRACK_TEXTURE_PATH)
	vignette_texture = SPRITE_LOADER.get_texture(VIGNETTE_TEXTURE_PATH)
	_ensure_canvas_tone()
	_ensure_rift_sprites()
	_ensure_dust_particles()
	_ensure_vignette()
	queue_redraw()


func _process(delta: float) -> void:
	time_accum += delta
	var center := _get_center()
	global_position = center
	var center_cell := Vector2i(floori(center.x / 48.0), floori(center.y / 48.0))
	_update_rift_sprites(center)
	_update_dust_bounds()
	redraw_timer -= delta
	if center_cell != last_center_cell or redraw_timer <= 0.0:
		last_center_cell = center_cell
		redraw_timer = 0.05
		queue_redraw()


func _draw() -> void:
	var center := _get_center()
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)

	var draw_size := viewport_size * 2.4
	var rect := Rect2(-draw_size * 0.5, draw_size)
	draw_rect(rect, background_color, true)
	_draw_tiled(deep_space_texture, center, draw_size, 0.035, 1.45, Color(0.82, 0.9, 1.0, 0.95))
	_draw_tiled(nebula_texture, center + Vector2(time_accum * 12.0, -time_accum * 7.0), draw_size, 0.11, 1.25, nebula_color)
	_draw_tiled(nebula_texture, center + Vector2(-time_accum * 6.0, time_accum * 9.0), draw_size, 0.18, 0.86, Color(0.18, 0.82, 1.0, 0.18))
	_draw_tiled(rift_crack_texture, center, draw_size, 0.24, 1.15, Color(rift_color.r, rift_color.g, rift_color.b, 0.16))

	for index in range(18):
		var seed := center * 0.013 + Vector2(float(index) * 31.7, float(index) * -17.2)
		var x := fposmod(sin(seed.x + time_accum * 0.12) * 927.0 + float(index) * 131.0, draw_size.x) - draw_size.x * 0.5
		var y := fposmod(cos(seed.y - time_accum * 0.09) * 719.0 + float(index) * 89.0, draw_size.y) - draw_size.y * 0.5
		var length := 34.0 + float(index % 5) * 11.0
		var alpha := 0.08 + float(index % 4) * 0.025
		var from := Vector2(x, y)
		var to := from + Vector2(length, 0.0).rotated(0.62 + float(index) * 0.73)
		draw_line(from, to, Color(0.46, 0.94, 1.0, alpha), 1.0)


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
	var existing: CanvasModulate = null
	if get_parent() != null:
		existing = get_parent().get_node_or_null("R10CanvasTone") as CanvasModulate
	if existing != null:
		existing.color = Color(0.86, 0.94, 1.0, 1.0)
		return
	var tone := CanvasModulate.new()
	tone.name = "R10CanvasTone"
	tone.color = Color(0.86, 0.94, 1.0, 1.0)
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
	rift_glow.z_index = 4

	rift_cracks = get_node_or_null("RiftCracks") as Sprite2D
	if rift_cracks == null:
		rift_cracks = Sprite2D.new()
		rift_cracks.name = "RiftCracks"
		add_child(rift_cracks)
	rift_cracks.texture = rift_crack_texture
	rift_cracks.centered = true
	rift_cracks.material = ART_RESOURCES.get_additive_material()
	rift_cracks.z_index = 5


func _update_rift_sprites(center: Vector2) -> void:
	if rift_glow == null or rift_cracks == null:
		return
	var seam_offset := Vector2(sin(time_accum * 0.17 + center.x * 0.001), cos(time_accum * 0.13 + center.y * 0.001)) * 92.0
	rift_glow.position = seam_offset
	rift_glow.scale = Vector2.ONE * (4.9 + sin(time_accum * 1.2) * 0.14)
	rift_glow.modulate = Color(0.2, 0.92, 1.0, 0.28)
	rift_cracks.position = seam_offset + Vector2(24.0, -16.0)
	rift_cracks.rotation = 0.2 + sin(time_accum * 0.08) * 0.08
	rift_cracks.scale = Vector2.ONE * 1.35
	rift_cracks.modulate = Color(0.52, 0.94, 1.0, 0.48 + sin(time_accum * 1.7) * 0.06)


func _ensure_dust_particles() -> void:
	dust_particles = get_node_or_null("VoidDust") as CPUParticles2D
	if dust_particles == null:
		dust_particles = CPUParticles2D.new()
		dust_particles.name = "VoidDust"
		add_child(dust_particles)
	dust_particles.texture = ART_RESOURCES.get_particle_core()
	dust_particles.material = ART_RESOURCES.get_additive_material()
	dust_particles.amount = max(0, dust_amount)
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
	dust_particles.color = Color(0.57, 0.96, 1.0, 0.38)
	dust_particles.z_index = 8
	dust_particles.emitting = true
	_update_dust_bounds()


func _update_dust_bounds() -> void:
	if dust_particles == null:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	dust_particles.emission_rect_extents = viewport_size * 0.68


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
	vignette_rect.modulate = Color(1.0, 1.0, 1.0, 0.62)
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(vignette_rect)


func _get_center() -> Vector2:
	if GameManager.player != null and is_instance_valid(GameManager.player):
		return GameManager.player.global_position
	return Vector2.ZERO
