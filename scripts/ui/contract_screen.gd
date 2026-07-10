extends CanvasLayer

signal contract_selected(contract: Dictionary)

var root: Control
var panel: Panel
var title_label: Label
var subtitle_label: Label
var meta_label: Label
var meta_grid: GridContainer
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

	title_label = Label.new()
	title_label.text = "選擇裂隙契約"
	title_label.anchor_left = 0.0
	title_label.anchor_right = 1.0
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
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
	var panel_height: float = min(viewport_size.y - 54.0, 520.0 if not portrait else 860.0)

	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5

	title_label.offset_top = 18.0
	title_label.offset_bottom = 58.0
	title_label.add_theme_font_size_override("font_size", 28 if portrait else 30)

	subtitle_label.offset_top = 56.0
	subtitle_label.offset_bottom = 82.0
	subtitle_label.add_theme_font_size_override("font_size", 14 if portrait else 16)

	meta_label.offset_top = 82.0
	meta_label.offset_bottom = 108.0
	meta_label.add_theme_font_size_override("font_size", 14 if portrait else 16)

	meta_grid.columns = 1 if portrait else 3
	meta_grid.offset_left = 26.0
	meta_grid.offset_right = -26.0
	meta_grid.offset_top = 114.0
	meta_grid.offset_bottom = 174.0 if not portrait else 294.0

	var meta_button_width: float = panel_width - 52.0 if portrait else max(180.0, (panel_width - 52.0 - 20.0) / 3.0)
	var meta_button_height := 52.0
	for button in meta_buttons.values():
		button.custom_minimum_size = Vector2(meta_button_width, meta_button_height)
		button.add_theme_font_size_override("font_size", 13 if portrait else 14)

	card_grid.columns = 1 if portrait else min(4, max(1, option_buttons.size()))
	card_grid.offset_left = 26.0
	card_grid.offset_right = -26.0
	card_grid.offset_top = 310.0 if portrait else 186.0
	card_grid.offset_bottom = -26.0

	var column_count: int = max(1, card_grid.columns)
	var card_width: float = panel_width - 52.0 if portrait else max(170.0, (panel_width - 52.0 - 18.0 * float(column_count - 1)) / float(column_count))
	var card_height: float = 160.0 if portrait else max(190.0, panel_height - 230.0)
	for button in option_buttons:
		button.custom_minimum_size = Vector2(card_width, card_height)
		button.add_theme_font_size_override("font_size", 18 if portrait else 20)
