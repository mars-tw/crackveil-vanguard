extends CanvasLayer

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
var card_grid: GridContainer
var option_buttons: Array[Button] = []
var meta_buttons: Dictionary = {}


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
	seed_start_button.text = "用種子開局"
	seed_start_button.pressed.connect(_on_seed_start_pressed)
	seed_row.add_child(seed_start_button)

	card_grid = GridContainer.new()
	card_grid.name = "CardGrid"
	card_grid.anchor_left = 0.0
	card_grid.anchor_right = 1.0
	card_grid.anchor_top = 0.0
	card_grid.anchor_bottom = 1.0
	card_grid.add_theme_constant_override("h_separation", 18)
	card_grid.add_theme_constant_override("v_separation", 14)
	panel.add_child(card_grid)
	_refresh_meta_panel()
	_apply_responsive_layout()


func show_options(options: Array) -> void:
	for child in card_grid.get_children():
		child.queue_free()
	option_buttons.clear()

	for option in options:
		var button := Button.new()
		button.text = "%s\n\n%s" % [str(option.get("name", "契約")), str(option.get("description", ""))]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_on_contract_pressed.bind(option))
		card_grid.add_child(button)
		option_buttons.append(button)

	_refresh_meta_panel()
	_apply_responsive_layout()
	root.visible = true


func _on_contract_pressed(contract: Dictionary) -> void:
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
	var portrait := viewport_size.y > viewport_size.x
	var panel_width: float = min(viewport_size.x - 28.0, 920.0 if not portrait else 620.0)
	var panel_height: float = min(viewport_size.y - 54.0, 570.0 if not portrait else 900.0)

	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5

	if logo_glow_label != null:
		logo_glow_label.offset_top = 10.0
		logo_glow_label.offset_bottom = 50.0
		logo_glow_label.add_theme_font_size_override("font_size", 30 if portrait else 34)
	if logo_label != null:
		logo_label.offset_top = 12.0
		logo_label.offset_bottom = 50.0
		logo_label.add_theme_font_size_override("font_size", 28 if portrait else 31)

	title_label.offset_top = 56.0
	title_label.offset_bottom = 90.0
	title_label.add_theme_font_size_override("font_size", 28 if portrait else 30)

	subtitle_label.offset_top = 88.0
	subtitle_label.offset_bottom = 114.0
	subtitle_label.add_theme_font_size_override("font_size", 14 if portrait else 16)

	meta_label.offset_top = 114.0
	meta_label.offset_bottom = 140.0
	meta_label.add_theme_font_size_override("font_size", 14 if portrait else 16)

	meta_grid.columns = 1 if portrait else 3
	meta_grid.offset_left = 26.0
	meta_grid.offset_right = -26.0
	meta_grid.offset_top = 146.0
	meta_grid.offset_bottom = 206.0 if not portrait else 326.0

	var meta_button_width: float = panel_width - 52.0 if portrait else max(180.0, (panel_width - 52.0 - 20.0) / 3.0)
	var meta_button_height := 52.0
	for button in meta_buttons.values():
		button.custom_minimum_size = Vector2(meta_button_width, meta_button_height)
		button.add_theme_font_size_override("font_size", 13 if portrait else 14)

	if seed_row != null:
		seed_row.offset_left = 26.0
		seed_row.offset_right = -26.0
		seed_row.offset_top = 334.0 if portrait else 214.0
		seed_row.offset_bottom = seed_row.offset_top + 42.0
	if seed_input != null:
		seed_input.custom_minimum_size = Vector2(180.0 if portrait else 280.0, 38.0)
	if seed_paste_button != null:
		seed_paste_button.custom_minimum_size = Vector2(58.0, 38.0)
	if seed_start_button != null:
		seed_start_button.custom_minimum_size = Vector2(116.0, 38.0)

	card_grid.columns = 1 if portrait else min(4, max(1, option_buttons.size()))
	card_grid.offset_left = 26.0
	card_grid.offset_right = -26.0
	card_grid.offset_top = 386.0 if portrait else 266.0
	card_grid.offset_bottom = -26.0

	var column_count: int = max(1, card_grid.columns)
	var card_width: float = panel_width - 52.0 if portrait else max(170.0, (panel_width - 52.0 - 18.0 * float(column_count - 1)) / float(column_count))
	var card_height: float = 160.0 if portrait else max(190.0, panel_height - 318.0)
	for button in option_buttons:
		button.custom_minimum_size = Vector2(card_width, card_height)
		button.add_theme_font_size_override("font_size", 18 if portrait else 20)
