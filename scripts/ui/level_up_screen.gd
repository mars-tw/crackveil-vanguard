extends CanvasLayer

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const MOBILE_CONFIRM_WINDOW_MSEC := 350

signal upgrade_selected(upgrade: Dictionary)

var root: Control
var panel: Panel
var title_label: Label
var card_scroll: ScrollContainer
var card_grid: GridContainer
var option_buttons: Array[Button] = []
var pending_mobile_confirm_button: Button = null
var pending_mobile_confirm_started_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_ui()
	if not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)
	root.visible = false


func _build_ui() -> void:
	root = Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	panel = Panel.new()
	panel.name = "Panel"
	root.add_child(panel)

	title_label = Label.new()
	title_label.text = "選擇升級"
	title_label.anchor_left = 0.0
	title_label.anchor_right = 1.0
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(0.74, 0.97, 1.0, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.36, 0.55, 0.85))
	title_label.add_theme_constant_override("outline_size", 2)
	panel.add_child(title_label)

	card_scroll = ScrollContainer.new()
	card_scroll.name = "CardScroll"
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.anchor_left = 0.0
	card_scroll.anchor_right = 1.0
	card_scroll.anchor_top = 0.0
	card_scroll.anchor_bottom = 1.0
	panel.add_child(card_scroll)

	card_grid = GridContainer.new()
	card_grid.name = "CardGrid"
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_grid.add_theme_constant_override("h_separation", 18)
	card_grid.add_theme_constant_override("v_separation", 14)
	card_scroll.add_child(card_grid)
	_apply_responsive_layout()


func show_options(options: Array) -> void:
	for child in card_grid.get_children():
		child.queue_free()
	option_buttons.clear()
	pending_mobile_confirm_button = null
	pending_mobile_confirm_started_msec = 0

	for option in options:
		var button := Button.new()
		var title := str(option.get("name", "升級"))
		if _is_evolution_option(option):
			title = "【武器進化】\n" + title
		button.text = "%s\n\n%s" % [title, str(option.get("description", ""))]
		button.set_meta("base_text", button.text)
		button.set_meta("option_key", _option_key(option))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 20)
		_apply_card_style(button, option)
		button.pressed.connect(_on_upgrade_pressed.bind(option))
		card_grid.add_child(button)
		option_buttons.append(button)

	_apply_responsive_layout()
	root.visible = true


func _on_upgrade_pressed(upgrade: Dictionary) -> void:
	if MOBILE_TUNING.use_mobile_ui(get_viewport().get_visible_rect().size):
		var pressed_button := _button_for_option(upgrade)
		var now_msec := Time.get_ticks_msec()
		if pressed_button != null and pressed_button == pending_mobile_confirm_button and now_msec - pending_mobile_confirm_started_msec <= MOBILE_CONFIRM_WINDOW_MSEC:
			_reset_pending_mobile_confirm()
		else:
			_set_pending_mobile_confirm(pressed_button, now_msec)
			return
	root.visible = false
	upgrade_selected.emit(upgrade)


func hide_screen() -> void:
	if root != null:
		root.visible = false
	_reset_pending_mobile_confirm()


func _button_for_option(upgrade: Dictionary) -> Button:
	var key := _option_key(upgrade)
	for button in option_buttons:
		if button == null or not is_instance_valid(button):
			continue
		if str(button.get_meta("option_key", "")) == key:
			return button
	return null


func _option_key(option: Dictionary) -> String:
	return "%s|%s|%s" % [
		str(option.get("name", "")),
		str(option.get("description", "")),
		str(option.get("upgrade_category", ""))
	]


func _reset_pending_mobile_confirm() -> void:
	if pending_mobile_confirm_button != null and is_instance_valid(pending_mobile_confirm_button):
		if bool(pending_mobile_confirm_button.get_meta("confirm_had_normal_override", false)):
			var base_style := pending_mobile_confirm_button.get_meta("confirm_base_normal_style") as StyleBox
			pending_mobile_confirm_button.add_theme_stylebox_override("normal", base_style)
		else:
			pending_mobile_confirm_button.remove_theme_stylebox_override("normal")
		pending_mobile_confirm_button.remove_meta("confirm_had_normal_override")
		pending_mobile_confirm_button.remove_meta("confirm_base_normal_style")
	pending_mobile_confirm_button = null
	pending_mobile_confirm_started_msec = 0
	if title_label != null:
		title_label.text = "選擇升級"


func _set_pending_mobile_confirm(button: Button, now_msec: int) -> void:
	_reset_pending_mobile_confirm()
	if button == null:
		return
	pending_mobile_confirm_button = button
	pending_mobile_confirm_started_msec = now_msec
	button.set_meta("confirm_had_normal_override", button.has_theme_stylebox_override("normal"))
	button.set_meta("confirm_base_normal_style", button.get_theme_stylebox("normal").duplicate())
	var highlight := StyleBoxFlat.new()
	highlight.bg_color = Color(0.08, 0.18, 0.24, 0.98)
	highlight.border_color = Color(0.42, 0.96, 1.0, 1.0)
	highlight.set_border_width_all(4)
	highlight.set_corner_radius_all(8)
	highlight.shadow_color = Color(0.2, 0.88, 1.0, 0.35)
	highlight.shadow_size = 8
	highlight.content_margin_left = 12.0
	highlight.content_margin_right = 12.0
	highlight.content_margin_top = 12.0
	highlight.content_margin_bottom = 12.0
	button.add_theme_stylebox_override("normal", highlight)
	if title_label != null:
		title_label.text = "再點高亮卡確認 · 點別張切換"


func _is_evolution_option(option: Dictionary) -> bool:
	return str(option.get("upgrade_category", "")) == "evolution"


func _apply_card_style(button: Button, option: Dictionary) -> void:
	if not _is_evolution_option(option):
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.07, 0.16, 0.96)
	normal.border_color = Color(1.0, 0.68, 0.24, 1.0)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(8)
	normal.shadow_color = Color(1.0, 0.46, 0.18, 0.22)
	normal.shadow_size = 8
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 12.0
	normal.content_margin_bottom = 12.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.1, 0.24, 0.98)
	hover.border_color = Color(1.0, 0.88, 0.46, 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.08, 0.05, 0.12, 0.98)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(1.0, 0.91, 0.62))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.72))


func _apply_responsive_layout() -> void:
	if panel == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var portrait := viewport_size.y > viewport_size.x
	var mobile := MOBILE_TUNING.use_mobile_ui(viewport_size)
	var outer_margin := 12.0 if mobile else 28.0
	var panel_width: float = min(viewport_size.x - outer_margin * 2.0, 920.0 if not portrait else 620.0)
	var panel_height: float = min(viewport_size.y - (outer_margin * 2.0 if mobile else 54.0), 420.0 if not portrait else 790.0)
	if mobile:
		panel_height = viewport_size.y - outer_margin * 2.0

	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5

	title_label.offset_top = 16.0 if mobile else 18.0
	title_label.offset_bottom = title_label.offset_top + (52.0 if mobile else 40.0)
	title_label.add_theme_font_size_override("font_size", (24 if portrait else 28) if mobile else (28 if portrait else 30))

	card_grid.columns = 1 if portrait else 3
	card_grid.add_theme_constant_override("h_separation", 26 if mobile else 18)
	card_grid.add_theme_constant_override("v_separation", 22 if mobile else 14)
	if card_scroll != null:
		card_scroll.offset_left = 20.0 if mobile else 26.0
		card_scroll.offset_right = -card_scroll.offset_left
		card_scroll.offset_top = title_label.offset_bottom + (14.0 if mobile else 18.0)
		card_scroll.offset_bottom = -20.0 if mobile else -26.0
		card_grid.custom_minimum_size = Vector2(max(1.0, panel_width - card_scroll.offset_left * 2.0), 0.0)

	var side_padding := 40.0 if mobile else 52.0
	var card_width: float = panel_width - side_padding if portrait else max(190.0, (panel_width - side_padding - 36.0) / 3.0)
	var card_scroll_top := card_scroll.offset_top if card_scroll != null else title_label.offset_bottom + 14.0
	var available_card_height := panel_height - card_scroll_top - (20.0 if mobile else 26.0)
	var card_height: float = 252.0 if mobile and portrait else 165.0 if portrait else max(214.0 if mobile else 190.0, available_card_height)
	for button in option_buttons:
		button.custom_minimum_size = Vector2(card_width, card_height)
		button.add_theme_font_size_override("font_size", 18 if portrait else 20)
	MOBILE_TUNING.apply_control_tree(root, viewport_size)
