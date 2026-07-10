extends CanvasLayer

signal restart_requested

var root: Control
var panel: Panel
var restart_button: Button
var summary_label: Label


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
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	panel = Panel.new()
	panel.name = "Panel"
	root.add_child(panel)

	var title := Label.new()
	title.text = "任務失敗"
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 24.0
	title.offset_bottom = 60.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)

	summary_label = Label.new()
	summary_label.anchor_left = 0.0
	summary_label.anchor_right = 1.0
	summary_label.offset_left = 30.0
	summary_label.offset_right = -30.0
	summary_label.offset_top = 88.0
	summary_label.offset_bottom = 180.0
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.add_theme_font_size_override("font_size", 20)
	panel.add_child(summary_label)

	restart_button = Button.new()
	restart_button.text = "重新開始"
	restart_button.pressed.connect(_on_restart_pressed)
	panel.add_child(restart_button)
	_apply_responsive_layout()


func show_summary(summary: Dictionary) -> void:
	summary_label.text = "存活  %s\n擊殺  %d\n精英擊殺  %d\nBoss 擊破  %s\n金幣  %d\n等級  %d\n契約  %s" % [
		GameManager.format_time(float(summary.get("elapsed_time", 0.0))),
		int(summary.get("kills", 0)),
		int(summary.get("elites_killed", 0)),
		"是" if bool(summary.get("boss_killed", false)) else "否",
		int(summary.get("gold", 0)),
		int(summary.get("level", 1)),
		str(summary.get("contract_name", "無契約"))
	]
	root.visible = true


func _on_restart_pressed() -> void:
	root.visible = false
	restart_requested.emit()


func _apply_responsive_layout() -> void:
	if panel == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var portrait := viewport_size.y > viewport_size.x
	var panel_width: float = min(viewport_size.x - 32.0, 440.0)
	var panel_height: float = 380.0 if portrait else 360.0

	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5

	if summary_label != null:
		summary_label.offset_left = 28.0
		summary_label.offset_right = -28.0
		summary_label.offset_top = 88.0
		summary_label.offset_bottom = 248.0
		summary_label.add_theme_font_size_override("font_size", 18 if not portrait else 17)

	if restart_button != null:
		restart_button.anchor_left = 0.5
		restart_button.anchor_right = 0.5
		restart_button.offset_left = -92.0
		restart_button.offset_right = 92.0
		restart_button.offset_top = panel_height - 92.0
		restart_button.offset_bottom = panel_height - 46.0
