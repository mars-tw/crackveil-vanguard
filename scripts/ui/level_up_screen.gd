extends CanvasLayer

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const MOBILE_CONFIRM_WINDOW_MSEC := 350
const ICON_XP := preload("res://assets/art/icon_xp.png")
const ICON_HEALTH := preload("res://assets/art/icon_health.png")
const ICON_GOLD := preload("res://assets/art/icon_gold.png")

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
		button.text = ""
		button.set_meta("option_key", _option_key(option))
		button.set_meta("upgrade_option", option)
		_build_card_content(button, title, str(option.get("description", "")), option)
		_apply_card_style(button, option)
		button.pressed.connect(_on_upgrade_pressed.bind(option))
		button.mouse_entered.connect(_on_card_focus.bind(button, true))
		button.mouse_exited.connect(_on_card_focus.bind(button, false))
		button.focus_entered.connect(_on_card_focus.bind(button, true))
		button.focus_exited.connect(_on_card_focus.bind(button, false))
		card_grid.add_child(button)
		option_buttons.append(button)

	_apply_responsive_layout()
	root.visible = true
	call_deferred("_animate_cards_in")


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
		_kill_card_tween(pending_mobile_confirm_button, "selection_tween")
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
	_start_selected_glow(button, highlight)
	if title_label != null:
		title_label.text = "再點高亮卡確認 · 點別張切換"


func _is_evolution_option(option: Dictionary) -> bool:
	return str(option.get("upgrade_category", "")) == "evolution"


func _build_card_content(button: Button, title: String, description: String, option: Dictionary) -> void:
	button.clip_contents = true
	var icon := TextureRect.new()
	icon.name = "UpgradeIcon"
	icon.texture = _upgrade_icon(option)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)

	var category := Label.new()
	category.name = "CategoryLabel"
	category.text = _upgrade_category_text(option)
	category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	category.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	category.mouse_filter = Control.MOUSE_FILTER_IGNORE
	category.add_theme_color_override("font_color", _upgrade_accent(option))
	button.add_child(category)

	var card_title := Label.new()
	card_title.name = "CardTitle"
	card_title.text = title
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_title.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0))
	button.add_child(card_title)

	var card_description := Label.new()
	card_description.name = "CardDescription"
	card_description.text = description
	card_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	card_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_description.add_theme_color_override("font_color", Color(0.78, 0.88, 0.94))
	button.add_child(card_description)


func _upgrade_icon(option: Dictionary) -> Texture2D:
	var option_id := str(option.get("id", ""))
	if "gold" in option_id:
		return ICON_GOLD
	if "heal" in option_id or "health" in option_id or "armor" in option_id or "hp" in option_id:
		return ICON_HEALTH
	return ICON_XP


func _upgrade_category_text(option: Dictionary) -> String:
	if _is_evolution_option(option):
		return "武器進化"
	match str(option.get("upgrade_category", "standard")):
		"qualitative":
			return "質變強化"
		"fallback":
			return "裂隙補給"
		_:
			return "戰術升級"


func _upgrade_accent(option: Dictionary) -> Color:
	if _is_evolution_option(option):
		return Color(1.0, 0.78, 0.3)
	if str(option.get("upgrade_category", "")) == "qualitative":
		return Color(0.76, 0.62, 1.0)
	return Color(0.42, 0.9, 1.0)


func _layout_card_content(button: Button, portrait: bool, mobile: bool) -> void:
	var icon := button.get_node_or_null("UpgradeIcon") as TextureRect
	var category := button.get_node_or_null("CategoryLabel") as Label
	var card_title := button.get_node_or_null("CardTitle") as Label
	var description := button.get_node_or_null("CardDescription") as Label
	if icon == null or category == null or card_title == null or description == null:
		return
	var icon_size := 58.0 if mobile and portrait else 48.0
	var icon_top := 16.0 if mobile else 14.0
	icon.anchor_left = 0.5
	icon.anchor_right = 0.5
	icon.offset_left = -icon_size * 0.5
	icon.offset_right = icon_size * 0.5
	icon.offset_top = icon_top
	icon.offset_bottom = icon_top + icon_size
	category.anchor_left = 0.0
	category.anchor_right = 1.0
	category.offset_left = 12.0
	category.offset_right = -12.0
	category.offset_top = icon.offset_bottom + 2.0
	category.offset_bottom = category.offset_top + 24.0
	category.add_theme_font_size_override("font_size", 14 if mobile and portrait else 12)
	card_title.anchor_left = 0.0
	card_title.anchor_right = 1.0
	card_title.offset_left = 14.0
	card_title.offset_right = -14.0
	card_title.offset_top = category.offset_bottom + 2.0
	card_title.offset_bottom = card_title.offset_top + (34.0 if mobile and portrait else 30.0)
	card_title.add_theme_font_size_override("font_size", 19 if mobile and portrait else 17)
	description.anchor_left = 0.0
	description.anchor_right = 1.0
	description.anchor_bottom = 1.0
	description.offset_left = 16.0
	description.offset_right = -16.0
	description.offset_top = card_title.offset_bottom + 5.0
	description.offset_bottom = -14.0
	description.add_theme_font_size_override("font_size", 15 if mobile and portrait else 13 if mobile else 14)


func _apply_card_style(button: Button, option: Dictionary) -> void:
	var normal := StyleBoxFlat.new()
	var category := str(option.get("upgrade_category", "standard"))
	normal.bg_color = Color(0.035, 0.085, 0.13, 0.97)
	normal.border_color = Color(0.28, 0.72, 0.88, 0.88)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(11)
	normal.shadow_color = Color(0.08, 0.66, 0.86, 0.18)
	normal.shadow_size = 7
	if category == "qualitative":
		normal.bg_color = Color(0.075, 0.055, 0.14, 0.98)
		normal.border_color = Color(0.66, 0.48, 1.0, 0.96)
		normal.shadow_color = Color(0.54, 0.3, 1.0, 0.25)
	elif _is_evolution_option(option):
		normal.bg_color = Color(0.12, 0.07, 0.025, 0.99)
		normal.border_color = Color(1.0, 0.72, 0.22, 1.0)
		normal.set_border_width_all(4)
		normal.shadow_color = Color(1.0, 0.5, 0.12, 0.34)
		normal.shadow_size = 11
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 12.0
	normal.content_margin_bottom = 12.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.08)
	hover.border_color = normal.border_color.lightened(0.12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = normal.bg_color.darkened(0.16)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	var font_color := Color(0.84, 0.96, 1.0)
	if category == "qualitative":
		font_color = Color(0.9, 0.84, 1.0)
	elif _is_evolution_option(option):
		font_color = Color(1.0, 0.91, 0.58)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color.lightened(0.12))


func _apply_responsive_layout() -> void:
	if panel == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	viewport_size = MOBILE_TUNING.apply_web_canvas_scale(self, viewport_size, root)
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
	var card_height: float = 224.0 if mobile and portrait else 180.0 if portrait else clamp(available_card_height, 190.0 if not mobile else 204.0, 244.0 if not mobile else 260.0)
	for button in option_buttons:
		button.custom_minimum_size = Vector2(card_width, card_height)
	MOBILE_TUNING.apply_control_tree(root, viewport_size)
	if mobile and OS.has_feature("web"):
		title_label.add_theme_font_size_override("font_size", 24 if portrait else 22)
	for button in option_buttons:
		_layout_card_content(button, portrait, mobile)


func _animate_cards_in() -> void:
	for index in range(option_buttons.size()):
		var button := option_buttons[index]
		if button == null or not is_instance_valid(button):
			continue
		button.pivot_offset = button.size * 0.5
		var target_position := button.position
		button.position = target_position + Vector2(0.0, 54.0)
		button.scale = Vector2.ONE * 0.9
		button.modulate.a = 0.0
		var tween := create_tween().set_parallel(true)
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "position", target_position, 0.42).set_delay(float(index) * 0.08)
		tween.tween_property(button, "scale", Vector2.ONE, 0.42).set_delay(float(index) * 0.08)
		tween.tween_property(button, "modulate:a", 1.0, 0.24).set_delay(float(index) * 0.08)


func _on_card_focus(button: Button, focused: bool) -> void:
	if button == null or not is_instance_valid(button) or button == pending_mobile_confirm_button:
		return
	_kill_card_tween(button, "focus_tween")
	button.pivot_offset = button.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE * (1.035 if focused else 1.0), 0.14)
	tween.tween_property(button, "modulate", Color(1.12, 1.12, 1.16, 1.0) if focused else Color.WHITE, 0.14)
	button.set_meta("focus_tween", tween)


func _start_selected_glow(button: Button, style: StyleBoxFlat) -> void:
	_kill_card_tween(button, "selection_tween")
	button.pivot_offset = button.size * 0.5
	var tween := create_tween().set_loops().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(style, "border_color", Color(0.86, 1.0, 1.0, 1.0), 0.46)
	tween.tween_property(style, "shadow_color", Color(0.28, 0.92, 1.0, 0.62), 0.46)
	tween.tween_property(button, "scale", Vector2.ONE * 1.035, 0.46)
	tween.chain().set_parallel(true)
	tween.tween_property(style, "border_color", Color(0.42, 0.96, 1.0, 1.0), 0.46)
	tween.tween_property(style, "shadow_color", Color(0.2, 0.88, 1.0, 0.35), 0.46)
	tween.tween_property(button, "scale", Vector2.ONE, 0.46)
	button.set_meta("selection_tween", tween)


func _kill_card_tween(button: Button, meta_key: String) -> void:
	if button == null or not button.has_meta(meta_key):
		return
	var tween: Variant = button.get_meta(meta_key)
	if tween is Tween and (tween as Tween).is_valid():
		(tween as Tween).kill()
	button.remove_meta(meta_key)
	button.scale = Vector2.ONE
	button.modulate = Color.WHITE
