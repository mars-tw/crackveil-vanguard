extends CanvasLayer

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")

const SAVE_PATH := "user://crackveil_guide.cfg"

var root: Control
var panel: Panel
var title_label: Label
var body_label: Label
var actions_box: VBoxContainer
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
	title_label.add_theme_color_override("font_color", Color(0.74, 0.97, 1.0, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.36, 0.55, 0.85))
	title_label.add_theme_constant_override("outline_size", 2)
	panel.add_child(title_label)

	body_label = Label.new()
	body_label.text = "移動：WASD / 方向鍵 / 左下搖桿\n隊長技：空白鍵 / 右下按鈕釋放裂隙脈衝\n武器會自動攻擊最近敵人\n收集藍色寶石升級，從三張卡選一張"
	body_label.anchor_left = 0.0
	body_label.anchor_right = 1.0
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 20)
	panel.add_child(body_label)

	actions_box = VBoxContainer.new()
	actions_box.name = "GuideActions"
	actions_box.add_theme_constant_override("separation", 14)
	panel.add_child(actions_box)

	dont_show_check = CheckBox.new()
	dont_show_check.text = "不再顯示"
	dont_show_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_box.add_child(dont_show_check)

	start_button = Button.new()
	start_button.text = "開始行動"
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.pressed.connect(_on_start_pressed)
	actions_box.add_child(start_button)
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
	viewport_size = MOBILE_TUNING.apply_web_canvas_scale(self, viewport_size, root)
	var portrait := viewport_size.y > viewport_size.x
	var mobile := MOBILE_TUNING.use_mobile_ui(viewport_size)
	var touch_height := MOBILE_TUNING.touch_target(viewport_size)
	var panel_width: float = min(viewport_size.x - (24.0 if mobile else 32.0), 600.0 if not portrait else 430.0)
	var panel_height: float = 360.0 if not portrait else 440.0
	if mobile:
		panel_height = min(viewport_size.y - 24.0, 520.0 if portrait else 366.0)

	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5

	for control in [title_label, body_label, actions_box]:
		control.anchor_top = 0.0
		control.anchor_bottom = 0.0

	title_label.offset_top = 20.0 if mobile and portrait else 14.0 if mobile else 22.0
	title_label.offset_bottom = title_label.offset_top + (52.0 if mobile and portrait else 38.0 if mobile else 40.0)
	title_label.add_theme_font_size_override("font_size", (24 if portrait else 20) if mobile else (26 if portrait else 28))

	body_label.offset_left = 22.0 if mobile else 30.0
	body_label.offset_right = -body_label.offset_left
	body_label.offset_top = title_label.offset_bottom + (12.0 if mobile else 14.0)
	var control_height := touch_height if mobile else 44.0
	var action_gap := 16.0 if mobile else 12.0
	var action_height := control_height * 2.0 + action_gap
	var action_width: float = min(panel_width - (48.0 if mobile else 72.0), 300.0 if mobile else 220.0)
	var action_bottom_margin := 18.0 if mobile else 20.0
	var actions_top := panel_height - action_height - action_bottom_margin
	actions_box.add_theme_constant_override("separation", int(action_gap))
	actions_box.anchor_left = 0.5
	actions_box.anchor_right = 0.5
	actions_box.offset_left = -action_width * 0.5
	actions_box.offset_right = action_width * 0.5
	actions_box.offset_top = actions_top
	actions_box.offset_bottom = actions_top + action_height
	dont_show_check.custom_minimum_size = Vector2(action_width, control_height)
	start_button.custom_minimum_size = Vector2(action_width, control_height)
	body_label.offset_bottom = actions_top - (14.0 if mobile else 16.0)
	body_label.add_theme_font_size_override("font_size", 12 if mobile and not portrait else 16 if mobile else (18 if portrait else 20))
	MOBILE_TUNING.apply_control_tree(root, viewport_size)
	if mobile and OS.has_feature("web"):
		title_label.add_theme_font_size_override("font_size", 24 if portrait else 20)
		body_label.add_theme_font_size_override("font_size", 16 if portrait else 12)
		dont_show_check.add_theme_font_size_override("font_size", 16 if portrait else 13)
		start_button.add_theme_font_size_override("font_size", 18 if portrait else 14)
