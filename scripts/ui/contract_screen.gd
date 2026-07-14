extends CanvasLayer

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")

signal contract_selected(contract: Dictionary)
signal seed_restart_requested(seed_text: String)

var root: Control
var panel: Panel
var logo_glow_label: Label
var logo_label: Label
var title_label: Label
var subtitle_label: Label
var meta_label: Label
var meta_grid: GridContainer
var seed_row: HBoxContainer
var seed_input: LineEdit
var seed_paste_button: Button
var seed_start_button: Button
var card_scroll: ScrollContainer
var card_grid: GridContainer
var option_buttons: Array[Button] = []
var meta_buttons: Dictionary = {}
var pending_mobile_confirm_button: Button = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	_build_ui()
	if not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)
	if MetaProgress.has_signal("progress_changed") and not MetaProgress.progress_changed.is_connected(_refresh_meta_panel):
		MetaProgress.progress_changed.connect(_refresh_meta_panel)
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

	logo_glow_label = Label.new()
	logo_glow_label.text = "CRACKVEIL VANGUARD"
	logo_glow_label.anchor_left = 0.0
	logo_glow_label.anchor_right = 1.0
	logo_glow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_glow_label.add_theme_font_size_override("font_size", 34)
	logo_glow_label.add_theme_color_override("font_color", Color(0.25, 0.92, 1.0, 0.42))
	panel.add_child(logo_glow_label)

	logo_label = Label.new()
	logo_label.text = "CRACKVEIL VANGUARD"
	logo_label.anchor_left = 0.0
	logo_label.anchor_right = 1.0
	logo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_label.add_theme_font_size_override("font_size", 31)
	logo_label.add_theme_color_override("font_color", Color(0.88, 0.98, 1.0, 1.0))
	logo_label.add_theme_color_override("font_outline_color", Color(0.16, 0.72, 1.0, 0.82))
	logo_label.add_theme_constant_override("outline_size", 2)
	panel.add_child(logo_label)

	title_label = Label.new()
	title_label.text = "選擇裂隙契約"
	title_label.anchor_left = 0.0
	title_label.anchor_right = 1.0
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(0.74, 0.97, 1.0, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.36, 0.55, 0.85))
	title_label.add_theme_constant_override("outline_size", 2)
	panel.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "選一條本局規則——它會改變這一局的玩法"
	subtitle_label.anchor_left = 0.0
	subtitle_label.anchor_right = 1.0
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(subtitle_label)

	meta_label = Label.new()
	meta_label.name = "MetaLabel"
	meta_label.anchor_left = 0.0
	meta_label.anchor_right = 1.0
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(meta_label)

	meta_grid = GridContainer.new()
	meta_grid.name = "MetaGrid"
	meta_grid.anchor_left = 0.0
	meta_grid.anchor_right = 1.0
	meta_grid.add_theme_constant_override("h_separation", 10)
	meta_grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(meta_grid)
	_build_meta_buttons()

	seed_row = HBoxContainer.new()
	seed_row.name = "SeedRow"
	seed_row.add_theme_constant_override("separation", 8)
	panel.add_child(seed_row)

	seed_input = LineEdit.new()
	seed_input.name = "SeedInput"
	seed_input.placeholder_text = "輸入種子，空白隨機"
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_input.text_submitted.connect(_on_seed_submitted)
	seed_row.add_child(seed_input)

	seed_paste_button = Button.new()
	seed_paste_button.text = "貼上"
	seed_paste_button.pressed.connect(_on_seed_paste_pressed)
	seed_row.add_child(seed_paste_button)

	seed_start_button = Button.new()
	seed_start_button.text = "種子開局"
	seed_start_button.pressed.connect(_on_seed_start_pressed)
	seed_row.add_child(seed_start_button)

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
	_refresh_meta_panel()
	_apply_responsive_layout()


func show_options(options: Array) -> void:
	for child in card_grid.get_children():
		child.queue_free()
	option_buttons.clear()
	pending_mobile_confirm_button = null

	for index in range(options.size()):
		var option: Dictionary = options[index]
		var button := Button.new()
		button.text = "裂隙契約 · %s\n%s\n\n%s" % [
			["I", "II", "III", "IV"][index % 4],
			str(option.get("name", "契約")),
			str(option.get("description", ""))
		]
		button.set_meta("base_text", button.text)
		button.set_meta("option_key", _option_key(option))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 20)
		_apply_contract_card_style(button, index)
		button.pressed.connect(_on_contract_pressed.bind(option))
		card_grid.add_child(button)
		option_buttons.append(button)

	_refresh_meta_panel()
	_apply_responsive_layout()
	root.visible = true


func _apply_contract_card_style(button: Button, index: int) -> void:
	var accents: Array[Color] = [
		Color(0.34, 0.9, 1.0),
		Color(0.72, 0.5, 1.0),
		Color(1.0, 0.58, 0.38),
		Color(0.38, 1.0, 0.72)
	]
	var accent: Color = accents[index % accents.size()]
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.04, 0.065, 0.13, 0.98).lerp(Color(accent.r, accent.g, accent.b, 1.0), 0.055)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.92)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(12)
	normal.shadow_color = Color(accent.r, accent.g, accent.b, 0.25)
	normal.shadow_size = 9
	normal.content_margin_left = 14.0
	normal.content_margin_right = 14.0
	normal.content_margin_top = 14.0
	normal.content_margin_bottom = 14.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.08)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = normal.bg_color.darkened(0.14)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))


func _on_contract_pressed(contract: Dictionary) -> void:
	if MOBILE_TUNING.use_mobile_ui(get_viewport().get_visible_rect().size):
		var pressed_button := _button_for_option(contract)
		if pressed_button != null and pressed_button != pending_mobile_confirm_button:
			_reset_pending_mobile_confirm()
			pending_mobile_confirm_button = pressed_button
			pressed_button.text = "再次點擊確認\n\n" + str(pressed_button.get_meta("base_text", pressed_button.text))
			return
		if pressed_button != null:
			_reset_pending_mobile_confirm()
	root.visible = false
	contract_selected.emit(contract)


func _on_seed_submitted(text: String) -> void:
	root.visible = false
	seed_restart_requested.emit(text)


func _on_seed_start_pressed() -> void:
	root.visible = false
	seed_restart_requested.emit(seed_input.text if seed_input != null else "")


func _on_seed_paste_pressed() -> void:
	if seed_input == null:
		return
	seed_input.text = DisplayServer.clipboard_get()


func hide_screen() -> void:
	if root != null:
		root.visible = false
	_reset_pending_mobile_confirm()


func _button_for_option(contract: Dictionary) -> Button:
	var key := _option_key(contract)
	for button in option_buttons:
		if button == null or not is_instance_valid(button):
			continue
		if str(button.get_meta("option_key", "")) == key:
			return button
	return null


func _option_key(option: Dictionary) -> String:
	return "%s|%s|%s" % [
		str(option.get("id", "")),
		str(option.get("name", "")),
		str(option.get("description", ""))
	]


func _reset_pending_mobile_confirm() -> void:
	if pending_mobile_confirm_button != null and is_instance_valid(pending_mobile_confirm_button):
		pending_mobile_confirm_button.text = str(pending_mobile_confirm_button.get_meta("base_text", pending_mobile_confirm_button.text))
	pending_mobile_confirm_button = null


func _build_meta_buttons() -> void:
	for child in meta_grid.get_children():
		child.queue_free()
	meta_buttons.clear()
	if not MetaProgress.has_method("get_track_definitions"):
		return
	for track in MetaProgress.get_track_definitions():
		var track_id := str(track.get("id", ""))
		var button := Button.new()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_meta_upgrade_pressed.bind(track_id))
		meta_grid.add_child(button)
		meta_buttons[track_id] = button


func _refresh_meta_panel() -> void:
	if meta_label == null or not MetaProgress.has_method("get_progress_summary"):
		return
	var progress: Dictionary = MetaProgress.get_progress_summary()
	var unlocks: Array[String] = []
	if bool(progress.get("contract_slot_unlocked", false)):
		unlocks.append("契約槽+1")
	if bool(progress.get("opening_choice_unlocked", false)):
		unlocks.append("起始選擇+1")
	var unlock_text := "解鎖 " + ("、".join(unlocks) if not unlocks.is_empty() else "未解鎖")
	meta_label.text = "殘響碎片 %d    累積 %d    %s" % [
		int(progress.get("shards", 0)),
		int(progress.get("lifetime_shards", 0)),
		unlock_text
	]
	for track in MetaProgress.get_track_definitions():
		var track_id := str(track.get("id", ""))
		var button: Button = meta_buttons.get(track_id)
		if button == null:
			continue
		var level := int(MetaProgress.get_upgrade_level(track_id))
		var max_level := int(track.get("max_level", 1))
		var cost := int(MetaProgress.get_upgrade_cost(track_id))
		button.text = "%s  %d/%d\n%s" % [
			str(track.get("name", "")),
			level,
			max_level,
			"已滿" if level >= max_level else "消耗 %d" % cost
		]
		button.disabled = level >= max_level or int(progress.get("shards", 0)) < cost


func _on_meta_upgrade_pressed(track_id: String) -> void:
	if MetaProgress.has_method("buy_upgrade") and MetaProgress.buy_upgrade(track_id):
		if GameManager.has_method("apply_current_meta_progress_to_squad"):
			GameManager.apply_current_meta_progress_to_squad()
		if AudioManager != null and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("contract")
		GameManager.emit_stats()
	_refresh_meta_panel()


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
	var touch_height := MOBILE_TUNING.touch_target(viewport_size)
	var outer_margin := 12.0 if mobile else 28.0
	var panel_width: float = min(viewport_size.x - outer_margin * 2.0, 920.0 if not portrait else 620.0)
	var panel_height: float = min(viewport_size.y - (outer_margin * 2.0 if mobile else 54.0), 570.0 if not portrait else 900.0)
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

	if logo_glow_label != null:
		logo_glow_label.text = "CRACKVEIL\nVANGUARD" if mobile and portrait else "CRACKVEIL VANGUARD"
		logo_glow_label.offset_top = 8.0 if not compact_landscape else 4.0
		logo_glow_label.offset_bottom = 96.0 if mobile and portrait else 34.0 if compact_landscape else 50.0
		logo_glow_label.add_theme_font_size_override("font_size", (30 if portrait else 18) if mobile else (30 if portrait else 34))
	if logo_label != null:
		logo_label.text = logo_glow_label.text if logo_glow_label != null else "CRACKVEIL VANGUARD"
		logo_label.offset_top = 10.0 if not compact_landscape else 5.0
		logo_label.offset_bottom = 98.0 if mobile and portrait else 34.0 if compact_landscape else 50.0
		logo_label.add_theme_font_size_override("font_size", (30 if portrait else 18) if mobile else (28 if portrait else 31))

	var title_top := 104.0 if mobile and portrait else 36.0 if compact_landscape else 56.0
	title_label.offset_top = title_top
	title_label.offset_bottom = title_top + (48.0 if mobile and portrait else 32.0 if compact_landscape else 46.0 if mobile else 34.0)
	title_label.add_theme_font_size_override("font_size", (22 if portrait else 20) if mobile else (28 if portrait else 30))

	subtitle_label.offset_top = title_label.offset_bottom + 2.0
	subtitle_label.offset_bottom = subtitle_label.offset_top + (42.0 if mobile and portrait else 24.0 if compact_landscape else 36.0 if mobile else 26.0)
	subtitle_label.add_theme_font_size_override("font_size", (13 if portrait else 10) if mobile else (14 if portrait else 16))

	meta_label.offset_top = subtitle_label.offset_bottom + 2.0
	meta_label.offset_bottom = meta_label.offset_top + (38.0 if mobile and portrait else 24.0 if compact_landscape else 34.0 if mobile else 26.0)
	meta_label.add_theme_font_size_override("font_size", (13 if portrait else 10) if mobile else (14 if portrait else 16))

	meta_grid.visible = not compact_landscape
	meta_grid.columns = 1 if portrait else 3
	meta_grid.offset_left = 20.0 if mobile else 26.0
	meta_grid.offset_right = -meta_grid.offset_left
	meta_grid.offset_top = meta_label.offset_bottom + 8.0
	meta_grid.offset_bottom = meta_grid.offset_top + ((touch_height + 8.0) * 3.0 if portrait else touch_height + 8.0)

	var side_padding := 40.0 if mobile else 52.0
	var meta_button_width: float = panel_width - side_padding if portrait else max(180.0, (panel_width - side_padding - 20.0) / 3.0)
	var meta_button_height := touch_height if mobile else 52.0
	for button in meta_buttons.values():
		button.custom_minimum_size = Vector2(meta_button_width, meta_button_height)
		button.add_theme_font_size_override("font_size", 13 if portrait else 12)

	if seed_row != null:
		seed_row.visible = not compact_landscape
		var seed_row_width: float = min(MOBILE_TUNING.SEED_ROW_MAX_WIDTH - 4.0, panel_width - (40.0 if mobile else 52.0))
		seed_row.anchor_left = 0.5
		seed_row.anchor_right = 0.5
		seed_row.offset_left = -seed_row_width * 0.5
		seed_row.offset_right = seed_row_width * 0.5
		seed_row.offset_top = meta_grid.offset_bottom + 10.0
		seed_row.offset_bottom = seed_row.offset_top + (touch_height if mobile else 42.0)
	if seed_input != null:
		var row_width: float = min(MOBILE_TUNING.SEED_ROW_MAX_WIDTH - 4.0, panel_width - (40.0 if mobile else 52.0))
		var seed_gap: float = float(ceil(MOBILE_TUNING.BASE_CONTAINER_SEPARATION * MOBILE_TUNING.spacing_scale(viewport_size)))
		var button_widths: float = (72.0 if mobile else 58.0) + (128.0 if mobile else 116.0) + seed_gap * 2.0
		seed_input.custom_minimum_size = Vector2(max(84.0, row_width - button_widths), touch_height if mobile else 38.0)
	if seed_paste_button != null:
		seed_paste_button.custom_minimum_size = Vector2(72.0 if mobile else 58.0, touch_height if mobile else 38.0)
	if seed_start_button != null:
		seed_start_button.custom_minimum_size = Vector2(128.0 if mobile else 116.0, touch_height if mobile else 38.0)

	card_grid.columns = 1 if portrait else min(4, max(1, option_buttons.size()))
	card_grid.add_theme_constant_override("h_separation", 26 if mobile else 18)
	card_grid.add_theme_constant_override("v_separation", 22 if mobile else 14)
	if card_scroll != null:
		card_scroll.offset_left = 20.0 if mobile else 26.0
		card_scroll.offset_right = -card_scroll.offset_left
		card_scroll.offset_top = meta_label.offset_bottom + 10.0 if compact_landscape else seed_row.offset_bottom + 12.0 if seed_row != null else 386.0
		card_scroll.offset_bottom = -12.0 if compact_landscape else -20.0 if mobile else -26.0
		card_grid.custom_minimum_size = Vector2(max(1.0, panel_width - card_scroll.offset_left * 2.0), 0.0)

	var column_count: int = max(1, card_grid.columns)
	var card_width: float = panel_width - (40.0 if mobile else 52.0) if portrait else max(170.0, (panel_width - (40.0 if mobile else 52.0) - 18.0 * float(column_count - 1)) / float(column_count))
	var available_card_height := panel_height - (card_scroll.offset_top if card_scroll != null else 0.0) - (12.0 if compact_landscape else 20.0)
	var card_height: float = 240.0 if mobile and portrait else 160.0 if portrait else max(190.0, available_card_height)
	for button in option_buttons:
		button.custom_minimum_size = Vector2(card_width, card_height)
		button.add_theme_font_size_override("font_size", 18 if portrait else 18 if mobile else 20)
	if seed_input != null:
		seed_input.add_theme_font_size_override("font_size", 13)
	if seed_paste_button != null:
		seed_paste_button.add_theme_font_size_override("font_size", 13)
	if seed_start_button != null:
		seed_start_button.add_theme_font_size_override("font_size", 13)
	MOBILE_TUNING.apply_control_tree(root, viewport_size)
	if mobile and OS.has_feature("web"):
		logo_glow_label.add_theme_font_size_override("font_size", 30 if portrait else 18)
		logo_label.add_theme_font_size_override("font_size", 30 if portrait else 18)
		title_label.add_theme_font_size_override("font_size", 22 if portrait else 20)
		subtitle_label.add_theme_font_size_override("font_size", 13 if portrait else 11)
		meta_label.add_theme_font_size_override("font_size", 13 if portrait else 11)
		for button in meta_buttons.values():
			button.add_theme_font_size_override("font_size", 13 if portrait else 11)
		seed_input.add_theme_font_size_override("font_size", 15 if portrait else 13)
		seed_paste_button.add_theme_font_size_override("font_size", 15 if portrait else 13)
		seed_start_button.add_theme_font_size_override("font_size", 15 if portrait else 13)
		for button in option_buttons:
			button.add_theme_font_size_override("font_size", 18 if portrait else 16)
