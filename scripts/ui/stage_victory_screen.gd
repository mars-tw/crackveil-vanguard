extends CanvasLayer

signal continue_requested
signal main_menu_requested

var root: Control
var panel: Panel
var summary_label: Label
var copy_seed_button: Button
var continue_button: Button
var main_menu_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
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
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	panel = Panel.new()
	panel.name = "Panel"
	root.add_child(panel)

	var title := Label.new()
	title.text = "階段勝利"
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 24.0
	title.offset_bottom = 62.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.78, 0.98, 1.0, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.07, 0.4, 0.55, 0.9))
	title.add_theme_constant_override("outline_size", 2)
	panel.add_child(title)

	summary_label = Label.new()
	summary_label.anchor_left = 0.0
	summary_label.anchor_right = 1.0
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.add_theme_font_size_override("font_size", 20)
	panel.add_child(summary_label)

	copy_seed_button = Button.new()
	copy_seed_button.text = "複製本局種子"
	copy_seed_button.pressed.connect(_on_copy_seed_pressed)
	panel.add_child(copy_seed_button)

	continue_button = Button.new()
	continue_button.text = "繼續無盡"
	continue_button.pressed.connect(_on_continue_pressed)
	panel.add_child(continue_button)

	main_menu_button = Button.new()
	main_menu_button.text = "回主選單"
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	panel.add_child(main_menu_button)
	_apply_responsive_layout()


func show_summary(summary: Dictionary) -> void:
	var progress: Dictionary = summary.get("echo_progress", {})
	summary_label.text = "擊破守門者·帷幕\n存活  %s\n擊殺  %d\n精英擊殺  %d\n金幣  %d\n契約  %s\n殘響  +%d（本局 %d / 持有 %d）\n新成就  %s" % [
		GameManager.format_time(float(summary.get("elapsed_time", 0.0))),
		int(summary.get("kills", 0)),
		int(summary.get("elites_killed", 0)),
		int(summary.get("gold", 0)),
		str(summary.get("contract_name", "無契約")),
		int(summary.get("echo_shards_earned", 0)),
		int(summary.get("echo_shards_run_total", 0)),
		int(progress.get("shards", 0)),
		_new_achievement_text(summary)
	]
	root.visible = true


func _on_continue_pressed() -> void:
	root.visible = false
	continue_requested.emit()


func _on_main_menu_pressed() -> void:
	root.visible = false
	main_menu_requested.emit()


func _on_copy_seed_pressed() -> void:
	GameManager.copy_current_run_seed_to_clipboard()


func hide_screen() -> void:
	if root != null:
		root.visible = false


func _apply_responsive_layout() -> void:
	if panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var panel_width: float = min(viewport_size.x - 32.0, 460.0)
	var panel_height: float = 402.0

	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5

	summary_label.offset_left = 28.0
	summary_label.offset_right = -28.0
	summary_label.offset_top = 92.0
	summary_label.offset_bottom = 254.0

	copy_seed_button.anchor_left = 0.5
	copy_seed_button.anchor_right = 0.5
	copy_seed_button.offset_left = -98.0
	copy_seed_button.offset_right = 98.0
	copy_seed_button.offset_top = panel_height - 178.0
	copy_seed_button.offset_bottom = panel_height - 136.0

	continue_button.anchor_left = 0.5
	continue_button.anchor_right = 0.5
	continue_button.offset_left = -98.0
	continue_button.offset_right = 98.0
	continue_button.offset_top = panel_height - 126.0
	continue_button.offset_bottom = panel_height - 84.0

	if main_menu_button != null:
		main_menu_button.anchor_left = 0.5
		main_menu_button.anchor_right = 0.5
		main_menu_button.offset_left = -98.0
		main_menu_button.offset_right = 98.0
		main_menu_button.offset_top = panel_height - 74.0
		main_menu_button.offset_bottom = panel_height - 32.0


func _new_achievement_text(summary: Dictionary) -> String:
	var unlocks: Array = summary.get("achievement_unlocks", [])
	if unlocks.is_empty():
		return "無"
	var names: Array[String] = []
	for achievement in unlocks:
		names.append(str(achievement.get("name", "")))
	return "、".join(names)
