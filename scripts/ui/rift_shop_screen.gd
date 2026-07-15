extends CanvasLayer

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")

signal purchase_selected(option: Dictionary)

var root: Control
var panel: Panel
var title_label: Label
var gold_label: Label
var card_scroll: ScrollContainer
var card_grid: GridContainer
var skip_button: Button
var option_buttons: Array[Button] = []
var pending_mobile_purchase_button: Button = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	_build_ui()
	if not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)
	if not GameManager.stats_changed.is_connected(_on_stats_changed):
		GameManager.stats_changed.connect(_on_stats_changed)
	root.visible = false


func _build_ui() -> void:
	root = Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	panel = Panel.new()
	panel.name = "Panel"
	root.add_child(panel)

	title_label = Label.new()
	title_label.text = "裂隙商亭"
	title_label.anchor_left = 0.0
	title_label.anchor_right = 1.0
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.56, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.32, 0.12, 0.04, 0.88))
	title_label.add_theme_constant_override("outline_size", 2)
	panel.add_child(title_label)

	gold_label = Label.new()
	gold_label.anchor_left = 0.0
	gold_label.anchor_right = 1.0
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(gold_label)

	card_scroll = ScrollContainer.new()
	card_scroll.name = "CardScroll"
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
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

	skip_button = Button.new()
	skip_button.text = "離開"
	skip_button.pressed.connect(_on_skip_pressed)
	panel.add_child(skip_button)
	_apply_responsive_layout()


func show_options(options: Array) -> void:
	for child in card_grid.get_children():
		child.queue_free()
	option_buttons.clear()
	pending_mobile_purchase_button = null
	gold_label.text = "金幣 %d" % GameManager.gold

	for option in options:
		var button := Button.new()
		button.text = _option_text(option, GameManager.gold)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = _option_disabled(option, GameManager.gold)
		button.set_meta("shop_option", option)
		button.add_theme_font_size_override("font_size", 19)
		button.pressed.connect(_on_purchase_pressed.bind(option))
		card_grid.add_child(button)
		option_buttons.append(button)

	_apply_responsive_layout()
	root.visible = true


func _on_purchase_pressed(option: Dictionary) -> void:
	if MOBILE_TUNING.use_mobile_ui(get_viewport().get_visible_rect().size):
		var pressed_button := _button_for_option(option)
		if pressed_button != null and pressed_button != pending_mobile_purchase_button:
			_reset_pending_mobile_purchase()
			pending_mobile_purchase_button = pressed_button
			pressed_button.set_meta("shop_base_text", pressed_button.text)
			pressed_button.text = "再次點擊購買\n\n" + pressed_button.text
			return
		_reset_pending_mobile_purchase()
	purchase_selected.emit(option)


func _on_skip_pressed() -> void:
	purchase_selected.emit({"id": "skip"})


func hide_screen() -> void:
	if root != null:
		root.visible = false
	_reset_pending_mobile_purchase()


func _button_for_option(option: Dictionary) -> Button:
	for button in option_buttons:
		if button != null and button.get_meta("shop_option", {}) == option:
			return button
	return null


func _reset_pending_mobile_purchase() -> void:
	if pending_mobile_purchase_button != null and is_instance_valid(pending_mobile_purchase_button):
		pending_mobile_purchase_button.text = str(pending_mobile_purchase_button.get_meta("shop_base_text", pending_mobile_purchase_button.text))
	pending_mobile_purchase_button = null


func _on_stats_changed(stats: Dictionary) -> void:
	if root == null:
		return
	if not bool(stats.get("waiting_for_shop", false)):
		root.visible = false
		return

	var current_gold := int(stats.get("gold", GameManager.gold))
	if gold_label != null:
		gold_label.text = "金幣 %d" % current_gold
	for button in option_buttons:
		var option: Dictionary = button.get_meta("shop_option", {})
		if button != pending_mobile_purchase_button:
			button.text = _option_text(option, current_gold)
		button.disabled = _option_disabled(option, current_gold)


func _apply_responsive_layout() -> void:
	if panel == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	viewport_size = MOBILE_TUNING.apply_web_canvas_scale(self, viewport_size, root)
	var portrait := viewport_size.y > viewport_size.x
	var mobile := MOBILE_TUNING.use_mobile_ui(viewport_size)
	var compact_landscape := mobile and not portrait
	var outer_margin := 12.0 if mobile else 28.0
	var touch_height := MOBILE_TUNING.touch_target(viewport_size)
	var panel_width: float = min(viewport_size.x - outer_margin * 2.0, 900.0 if not portrait else 620.0)
	var panel_height: float = min(viewport_size.y - (outer_margin * 2.0 if mobile else 54.0), 460.0 if not portrait else 620.0)
	if mobile and not portrait:
		panel_height = viewport_size.y - outer_margin * 2.0

	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.position = Vector2((viewport_size.x - panel_width) * 0.5, (viewport_size.y - panel_height) * 0.5)
	panel.size = Vector2(panel_width, panel_height)

	title_label.offset_top = 12.0 if compact_landscape else 16.0 if mobile else 18.0
	title_label.offset_bottom = title_label.offset_top + (40.0 if compact_landscape else 48.0 if mobile else 36.0)
	title_label.add_theme_font_size_override("font_size", (24 if portrait else 22) if mobile else 30)
	gold_label.offset_top = title_label.offset_bottom
	gold_label.offset_bottom = gold_label.offset_top + (26.0 if compact_landscape else 34.0 if mobile else 24.0)
	gold_label.add_theme_font_size_override("font_size", (15 if portrait else 17) if mobile else 18)

	var card_columns: int = 2 if portrait else 3
	card_grid.columns = card_columns
	if card_scroll != null:
		var scroll_left: float = 20.0 if mobile else 26.0
		var scroll_top: float = gold_label.offset_bottom + (12.0 if mobile else 14.0)
		var scroll_bottom: float = touch_height + 30.0 if mobile else 82.0
		card_scroll.anchor_left = 0.0
		card_scroll.anchor_right = 0.0
		card_scroll.anchor_top = 0.0
		card_scroll.anchor_bottom = 0.0
		card_scroll.position = Vector2(scroll_left, scroll_top)
		card_scroll.size = Vector2(max(1.0, panel_width - scroll_left * 2.0), max(1.0, panel_height - scroll_top - scroll_bottom))
		card_grid.custom_minimum_size = Vector2(max(1.0, card_scroll.size.x), 0.0)

	var side_padding: float = 40.0 if mobile else 52.0
	var card_gap: float = 12.0 if mobile else 18.0
	card_grid.add_theme_constant_override("h_separation", int(card_gap))
	card_grid.add_theme_constant_override("v_separation", int(card_gap))
	var card_width: float = max(130.0 if mobile else 160.0, (panel_width - side_padding - card_gap * float(card_columns - 1)) / float(card_columns))
	var available_card_height: float = card_scroll.size.y if card_scroll != null else panel_height - gold_label.offset_bottom - touch_height - 42.0
	var card_rows: int = int(ceil(float(max(1, option_buttons.size())) / float(card_columns)))
	var row_gap_total: float = card_gap * float(max(0, card_rows - 1))
	var compact_portrait_height: float = floor((available_card_height - row_gap_total) / float(max(1, card_rows)))
	var card_height: float = clamp(compact_portrait_height, 132.0, 172.0) if portrait else clamp(available_card_height, 132.0 if compact_landscape else 174.0, 206.0 if mobile else 240.0)
	for button in option_buttons:
		button.custom_minimum_size = Vector2(card_width, card_height)
		button.add_theme_font_size_override("font_size", 15 if mobile and portrait else 18 if portrait else 19)

	var skip_width: float = 216.0 if mobile else 172.0
	var skip_height: float = touch_height if mobile else 40.0
	skip_button.anchor_left = 0.0
	skip_button.anchor_right = 0.0
	skip_button.anchor_top = 0.0
	skip_button.anchor_bottom = 0.0
	skip_button.position = Vector2((panel_width - skip_width) * 0.5, panel_height - skip_height - (18.0 if mobile else 24.0))
	skip_button.size = Vector2(skip_width, skip_height)
	MOBILE_TUNING.apply_control_tree(root, viewport_size)
	for button in option_buttons:
		button.custom_minimum_size = Vector2(card_width, card_height)
		button.add_theme_font_size_override("font_size", 15 if mobile and portrait else 16 if mobile else 18 if portrait else 19)
	if mobile and OS.has_feature("web"):
		title_label.add_theme_font_size_override("font_size", 24 if portrait else 22)
		gold_label.add_theme_font_size_override("font_size", 16 if portrait else 15)
		for button in option_buttons:
			button.add_theme_font_size_override("font_size", 15 if portrait else 16)
		skip_button.add_theme_font_size_override("font_size", 18 if portrait else 16)


func _option_disabled(option: Dictionary, current_gold: int) -> bool:
	if not bool(option.get("enabled", true)):
		return true
	return current_gold < int(option.get("cost", 0))


func _option_text(option: Dictionary, current_gold: int) -> String:
	var cost := int(option.get("cost", 0))
	var suffix := ""
	var disabled_reason := _disabled_reason(option, current_gold)
	if disabled_reason != "":
		suffix = "\n\n%s" % disabled_reason
	return "%s\n%d 金幣\n\n%s%s" % [
		str(option.get("name", "商品")),
		cost,
		str(option.get("description", "")),
		suffix
	]


func _disabled_reason(option: Dictionary, current_gold: int) -> String:
	if not bool(option.get("enabled", true)):
		return str(option.get("disabled_reason", "暫時無法購買"))
	if current_gold < int(option.get("cost", 0)):
		return "金幣不足"
	return ""
