extends CanvasLayer

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const WEB_REACHABILITY_PROBE := preload("res://scripts/services/web_reachability_probe.gd")

const SAVE_PATH := "user://crackveil_guide.cfg"

var root: Control
var panel: Panel
var title_label: Label
var body_label: Label
var actions_box: VBoxContainer
var dont_show_check: CheckBox
var previous_button: Button
var start_button: Button
var page_index: int = 0

const DECISION_PAGES: Array[Dictionary] = [
	{
		"title": "契約",
		"body": "開局先選契約。契約會改變本局風險、獎勵與升級節奏；先看紅字代價，再決定要穩定或高報酬。"
	},
	{
		"title": "招募與隊長",
		"body": "升級時可能出現招募。隊伍最多 9 人，10 名英雄無法全上；隊長死亡時全隊撤退，所以站位要保護隊長。"
	},
	{
		"title": "羈絆",
		"body": "特定英雄同隊會啟用羈絆。羈絆會改變武器、治療或防禦；成員死亡後效果會失效。"
	},
	{
		"title": "進化",
		"body": "武器進化需要本局等級 7、指定質變等級與武器傷害等級。先把核心武器升滿，再等進化卡進池。"
	},
	{
		"title": "商亭與 Boss",
		"body": "商亭會在 Boss 前後出現，可花金幣補血、改裝或刷新。三種戰場每局隨機抽選其一；擊敗 Boss 後可繼續無盡作戰。"
	}
]


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

	previous_button = Button.new()
	previous_button.text = "上一頁"
	previous_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	previous_button.pressed.connect(_on_previous_pressed)
	actions_box.add_child(previous_button)

	start_button = Button.new()
	start_button.text = "開始行動"
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.pressed.connect(_on_start_pressed)
	actions_box.add_child(start_button)
	_refresh_page()
	_apply_responsive_layout()


func _on_start_pressed() -> void:
	if page_index < DECISION_PAGES.size():
		page_index += 1
		_refresh_page()
		_apply_responsive_layout()
		return
	if AudioManager != null and AudioManager.has_method("unlock_audio"):
		AudioManager.unlock_audio()
	if dont_show_check.button_pressed:
		_save_disabled()
	root.visible = false
	_publish_reachability_probe(get_viewport().get_visible_rect().size)


func _on_previous_pressed() -> void:
	page_index = max(0, page_index - 1)
	_refresh_page()
	_apply_responsive_layout()


func force_show() -> void:
	if root == null:
		return
	page_index = 0
	if dont_show_check != null:
		dont_show_check.button_pressed = false
	_refresh_page()
	root.visible = true


func _refresh_page() -> void:
	if title_label == null or body_label == null or start_button == null:
		return
	if page_index <= 0:
		title_label.text = "裂隙先鋒簡報 1/%d" % (DECISION_PAGES.size() + 1)
		body_label.text = _controls_page_text()
	else:
		var page := DECISION_PAGES[page_index - 1]
		title_label.text = "%s %d/%d" % [str(page.get("title", "")), page_index + 1, DECISION_PAGES.size() + 1]
		body_label.text = str(page.get("body", ""))
	start_button.text = "開始行動" if page_index >= DECISION_PAGES.size() else "下一頁"
	if previous_button != null:
		previous_button.visible = page_index > 0


func _controls_page_text() -> String:
	if MOBILE_TUNING.has_confirmed_touch():
		return "移動：左下搖桿\n隊長技：右下按鈕釋放裂隙脈衝\n武器會自動攻擊最近敵人\n收集藍色寶石升級，從三張卡選一張"
	return "移動：WASD / 方向鍵\n隊長技：空白鍵釋放裂隙脈衝\n武器會自動攻擊最近敵人\n收集藍色寶石升級，從三張卡選一張"


func _is_disabled() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false
	return bool(config.get_value("guide", "disabled", false))


func _save_disabled() -> void:
	var config := ConfigFile.new()
	config.set_value("guide", "disabled", true)
	var error := config.save(SAVE_PATH)
	if error != OK:
		printerr("GUIDE_SETTINGS_SAVE_FAIL: %s" % error)
		if GameManager != null and GameManager.has_method("queue_toast"):
			GameManager.queue_toast("教學偏好無法保存，請檢查瀏覽器儲存權限。")


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
	_refresh_page()
	var panel_width: float = min(viewport_size.x - (24.0 if mobile else 32.0), 600.0 if not portrait else 430.0)
	var panel_height: float = 360.0 if not portrait else 440.0
	if mobile:
		panel_height = min(viewport_size.y - 24.0, 560.0 if portrait else 384.0)

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
	var control_height := touch_height
	var action_gap := 16.0 if mobile else 12.0
	var action_rows := 2.0 + (1.0 if previous_button != null and previous_button.visible else 0.0)
	var action_height := control_height * action_rows + action_gap * (action_rows - 1.0)
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
	if previous_button != null:
		previous_button.custom_minimum_size = Vector2(action_width, control_height)
	start_button.custom_minimum_size = Vector2(action_width, control_height)
	body_label.offset_bottom = actions_top - (14.0 if mobile else 16.0)
	var ui_multiplier := _ui_scale_multiplier()
	body_label.add_theme_font_size_override("font_size", int(round(float(16 if mobile else (18 if portrait else 20)) * ui_multiplier)))
	MOBILE_TUNING.apply_control_tree(root, viewport_size)
	if mobile and OS.has_feature("web"):
		title_label.add_theme_font_size_override("font_size", 24 if portrait else 20)
		body_label.add_theme_font_size_override("font_size", int(round(float(16 if portrait else 15) * ui_multiplier)))
		dont_show_check.add_theme_font_size_override("font_size", int(round(float(16 if portrait else 15) * ui_multiplier)))
		if previous_button != null:
			previous_button.add_theme_font_size_override("font_size", int(round(float(17 if portrait else 15) * ui_multiplier)))
		start_button.add_theme_font_size_override("font_size", int(round(float(18 if portrait else 16) * ui_multiplier)))
	_apply_accessibility_palette()
	call_deferred("_publish_reachability_probe", viewport_size)


func _publish_reachability_probe(viewport_size: Vector2) -> void:
	WEB_REACHABILITY_PROBE.publish("guide", viewport_size, {
		"start": start_button,
		"dont_show": dont_show_check,
		"previous": previous_button
	}, {
		"visible": root != null and root.visible
	})


func _ui_scale_multiplier() -> float:
	if PlayerSettings != null and PlayerSettings.has_method("get_ui_scale_multiplier"):
		return float(PlayerSettings.get_ui_scale_multiplier())
	return 1.0


func _apply_accessibility_palette() -> void:
	var high_contrast := PlayerSettings != null and bool(PlayerSettings.get("high_contrast_enabled"))
	panel.modulate = Color(1.0, 1.0, 1.0, 0.98 if high_contrast else 0.9)
	for label in [title_label, body_label]:
		if label == null:
			continue
		if high_contrast:
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 3)
		else:
			label.remove_theme_constant_override("outline_size")
