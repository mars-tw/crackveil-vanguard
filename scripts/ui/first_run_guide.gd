extends CanvasLayer

const SAVE_PATH := "user://crackveil_guide.cfg"

var root: Control
var panel: Panel
var title_label: Label
var body_label: Label
var dont_show_check: CheckBox
var start_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 45
	_build_ui()
	if not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)
	root.visible = not _is_disabled()


func _build_ui() -> void:
	root = Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.54)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	panel = Panel.new()
	panel.name = "Panel"
	root.add_child(panel)

	title_label = Label.new()
	title_label.text = "裂隙先鋒簡報"
	title_label.anchor_left = 0.0
	title_label.anchor_right = 1.0
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	panel.add_child(title_label)

	body_label = Label.new()
	body_label.text = "移動：WASD / 方向鍵 / 左下搖桿\n武器會自動攻擊最近敵人\n收集藍色寶石升級，從三張卡選一張"
	body_label.anchor_left = 0.0
	body_label.anchor_right = 1.0
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 20)
	panel.add_child(body_label)

	dont_show_check = CheckBox.new()
	dont_show_check.text = "不再顯示"
	panel.add_child(dont_show_check)

	start_button = Button.new()
	start_button.text = "開始行動"
	start_button.pressed.connect(_on_start_pressed)
	panel.add_child(start_button)
	_apply_responsive_layout()


func _on_start_pressed() -> void:
	if AudioManager != null and AudioManager.has_method("unlock_audio"):
		AudioManager.unlock_audio()
	if dont_show_check.button_pressed:
		_save_disabled()
	root.visible = false


func force_show() -> void:
	if root == null:
		return
	if dont_show_check != null:
		dont_show_check.button_pressed = false
	root.visible = true


func _is_disabled() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false
	return bool(config.get_value("guide", "disabled", false))


func _save_disabled() -> void:
	var config := ConfigFile.new()
	config.set_value("guide", "disabled", true)
	config.save(SAVE_PATH)


func _apply_responsive_layout() -> void:
	if panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var portrait := viewport_size.y > viewport_size.x
	var panel_width: float = min(viewport_size.x - 32.0, 560.0 if not portrait else 420.0)
	var panel_height: float = 284.0 if not portrait else 332.0

	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5

	title_label.offset_top = 22.0
	title_label.offset_bottom = 62.0
	title_label.add_theme_font_size_override("font_size", 26 if portrait else 28)

	body_label.offset_left = 30.0
	body_label.offset_right = -30.0
	body_label.offset_top = 76.0
	body_label.offset_bottom = panel_height - 116.0
	body_label.add_theme_font_size_override("font_size", 18 if portrait else 20)

	dont_show_check.anchor_left = 0.5
	dont_show_check.anchor_right = 0.5
	dont_show_check.offset_left = -82.0
	dont_show_check.offset_right = 82.0
	dont_show_check.offset_top = panel_height - 96.0
	dont_show_check.offset_bottom = panel_height - 58.0

	start_button.anchor_left = 0.5
	start_button.anchor_right = 0.5
	start_button.offset_left = -92.0
	start_button.offset_right = 92.0
	start_button.offset_top = panel_height - 54.0
	start_button.offset_bottom = panel_height - 14.0
