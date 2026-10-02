extends Control

const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
var age := 0.0
var title: Label
var benefit: Label
var accent := Color("8ebaff")
var active := false
var panel_style: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.045, 0.085, 0.95)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 17)
	title.position = Vector2(49, 8)
	title.size = Vector2(244, 25)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	benefit = Label.new()
	benefit.add_theme_font_size_override("font_size", 12)
	benefit.position = Vector2(49, 33)
	benefit.size = Vector2(244, 19)
	benefit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(benefit)
	visible = false

func show_item(item: Dictionary, _replaced: Dictionary, equipped: bool) -> void:
	if not equipped:
		return
	age = 0.0
	active = true
	accent = item.get("color", Color("8ebaff"))
	panel_style.border_color = Color(accent, 0.85)
	title.text = "%s！ %s" % [str(item.get("rarity_name", "裝備")), str(item.get("name", ""))]
	title.add_theme_color_override("font_color", accent.lightened(0.45))
	benefit.text = str(item.get("description", "")).split("\n")[0]
	benefit.add_theme_color_override("font_color", Color("d3ddf2"))
	queue_redraw()

func _process(delta: float) -> void:
	if not active:
		return
	age += delta
	if age > 1.7:
		active = false
		visible = false
		return
	var view := MOBILE.ui_layout_size(get_viewport().get_visible_rect().size)
	var phone := MOBILE.use_mobile_ui(view)
	var portrait := view.y > view.x
	# The generic touch-control pass can enlarge labels; restore this compact
	# notification's measured typography after every viewport/layout update.
	title.add_theme_font_size_override("font_size", 17)
	benefit.add_theme_font_size_override("font_size", 12)
	title.clip_text = true
	benefit.clip_text = true
	size = Vector2(minf(318.0, view.x - 24), 60)
	title.size.x = maxf(1.0, size.x - 57.0)
	benefit.size.x = title.size.x
	position = Vector2((view.x - size.x) * 0.5, view.y - (258.0 if phone and portrait else 122.0))
	visible = not GameManager.is_system_pause_active() and not GameManager.manual_paused and GameManager.game_running
	modulate.a = minf(1.0, age / 0.08) * minf(1.0, (1.7 - age) / 0.24)
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	draw_style_box(panel_style, Rect2(Vector2.ZERO, size))
	var center := Vector2(26, 29)
	var halo := 17.0 + sin(age * 8) * 1.5
	draw_circle(center, halo, Color(accent, 0.13))
	var diamond := PackedVector2Array([center + Vector2(0, -12), center + Vector2(9, 0), center + Vector2(0, 12), center + Vector2(-9, 0)])
	draw_colored_polygon(diamond, accent)
	draw_line(center + Vector2(0, -9), center + Vector2(0, 8), Color.WHITE, 1.4, true)
	var sweep := clampf(age / 0.28, 0, 1) * size.x
	draw_line(Vector2(0, 0), Vector2(sweep, 0), accent.lightened(0.5), 2.0, true)
