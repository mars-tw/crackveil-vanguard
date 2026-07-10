extends CanvasLayer

signal contract_selected(contract: Dictionary)

var root: Control
var panel: Panel
var title_label: Label
var card_grid: GridContainer
var option_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	if not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)
	root.visible = false


func _build_ui() -> void:
	root = Control.new()
	root.name = "Root"
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

	card_grid = GridContainer.new()
	card_grid.name = "CardGrid"
	card_grid.anchor_left = 0.0
	card_grid.anchor_right = 1.0
	card_grid.anchor_top = 0.0
	card_grid.anchor_bottom = 1.0
	card_grid.add_theme_constant_override("h_separation", 18)
	card_grid.add_theme_constant_override("v_separation", 14)
	panel.add_child(card_grid)
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

	_apply_responsive_layout()
	root.visible = true


func _on_contract_pressed(contract: Dictionary) -> void:
	root.visible = false
	contract_selected.emit(contract)


func _apply_responsive_layout() -> void:
	if panel == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var portrait := viewport_size.y > viewport_size.x
	var panel_width: float = min(viewport_size.x - 28.0, 920.0 if not portrait else 620.0)
	var panel_height: float = min(viewport_size.y - 54.0, 430.0 if not portrait else 800.0)

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

	card_grid.columns = 1 if portrait else 3
	card_grid.offset_left = 26.0
	card_grid.offset_right = -26.0
	card_grid.offset_top = 78.0
	card_grid.offset_bottom = -26.0

	var card_width: float = panel_width - 52.0 if portrait else max(190.0, (panel_width - 52.0 - 36.0) / 3.0)
	var card_height: float = 170.0 if portrait else max(210.0, panel_height - 122.0)
	for button in option_buttons:
		button.custom_minimum_size = Vector2(card_width, card_height)
		button.add_theme_font_size_override("font_size", 18 if portrait else 20)
