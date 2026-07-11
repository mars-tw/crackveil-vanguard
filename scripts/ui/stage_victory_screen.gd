extends CanvasLayer

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")

signal continue_requested
signal main_menu_requested

var root: Control
var panel: Panel
var title_label: Label
var summary_scroll: ScrollContainer
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

	title_label = Label.new()
	var title := title_label
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

	summary_scroll = ScrollContainer.new()
	summary_scroll.name = "SummaryScroll"
	summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	summary_scroll.anchor_left = 0.0
	summary_scroll.anchor_right = 1.0
	summary_scroll.anchor_top = 0.0
	summary_scroll.anchor_bottom = 1.0
	panel.add_child(summary_scroll)

	summary_label = Label.new()
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 20)
	summary_scroll.add_child(summary_label)

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
	var portrait := viewport_size.y > viewport_size.x
	var mobile := MOBILE_TUNING.use_mobile_ui(viewport_size)
	var compact_landscape := mobile and not portrait
	var touch_height := MOBILE_TUNING.touch_target(viewport_size)
	var panel_width: float = min(viewport_size.x - (24.0 if mobile else 32.0), 820.0 if compact_landscape else 520.0 if mobile else 460.0)
	var panel_height: float = min(viewport_size.y - (24.0 if mobile else 32.0), 520.0 if mobile else 402.0)

	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5

	if title_label != null:
		title_label.offset_top = 14.0 if compact_landscape else 20.0
		title_label.offset_bottom = title_label.offset_top + (56.0 if mobile else 38.0)
		title_label.add_theme_font_size_override("font_size", (24 if portrait else 22) if mobile else 30)

	var button_width: float = 246.0 if compact_landscape else 260.0 if mobile else 196.0
	var button_left: float = panel_width - button_width - 24.0 if compact_landscape else (panel_width - button_width) * 0.5
	var button_gap: float = 12.0
	var button_height: float = touch_height if mobile else 42.0
	var button_stack_height: float = button_height * 3.0 + button_gap * 2.0
	var button_top: float = max((title_label.offset_bottom + 14.0) if title_label != null else 72.0, (panel_height - button_stack_height) * 0.5) if compact_landscape else panel_height - ((touch_height + 12.0) * 3.0 + 12.0 if mobile else 178.0)
	var copy_top: float = button_top
	var secondary_top: float = copy_top + button_height + button_gap
	var primary_top: float = secondary_top + button_height + button_gap

	if summary_scroll != null:
		var summary_left: float = 24.0 if mobile else 28.0
		var summary_right: float = -(panel_width - button_left + 18.0) if compact_landscape else -summary_left
		summary_scroll.offset_left = summary_left
		summary_scroll.offset_right = summary_right
		summary_scroll.offset_top = (title_label.offset_bottom + 10.0) if title_label != null else 92.0
		summary_scroll.offset_bottom = -20.0 if compact_landscape else -(panel_height - button_top + 16.0)
		summary_label.custom_minimum_size = Vector2(max(1.0, panel_width + summary_right - summary_left), 156.0 if compact_landscape else 208.0 if mobile else 160.0)
	summary_label.add_theme_font_size_override("font_size", (15 if portrait else 17) if mobile else 20)

	copy_seed_button.anchor_left = 0.5
	copy_seed_button.anchor_right = 0.5
	copy_seed_button.anchor_left = 0.0
	copy_seed_button.anchor_right = 0.0
	copy_seed_button.offset_left = button_left
	copy_seed_button.offset_right = button_left + button_width
	copy_seed_button.offset_top = copy_top
	copy_seed_button.offset_bottom = copy_seed_button.offset_top + button_height

	continue_button.anchor_left = 0.0
	continue_button.anchor_right = 0.0
	continue_button.offset_left = button_left
	continue_button.offset_right = button_left + button_width
	continue_button.offset_top = primary_top if mobile and portrait else secondary_top
	continue_button.offset_bottom = continue_button.offset_top + button_height

	if main_menu_button != null:
		main_menu_button.anchor_left = 0.0
		main_menu_button.anchor_right = 0.0
		main_menu_button.offset_left = button_left
		main_menu_button.offset_right = button_left + button_width
		main_menu_button.offset_top = secondary_top if mobile and portrait else primary_top
		main_menu_button.offset_bottom = main_menu_button.offset_top + button_height
	MOBILE_TUNING.apply_control_tree(root, viewport_size)


func _new_achievement_text(summary: Dictionary) -> String:
	var unlocks: Array = summary.get("achievement_unlocks", [])
	if unlocks.is_empty():
		return "無"
	var names: Array[String] = []
	for achievement in unlocks:
		names.append(str(achievement.get("name", "")))
	return "、".join(names)
