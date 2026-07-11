extends CanvasLayer

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")

signal restart_requested
signal main_menu_requested

var root: Control
var panel: Panel
var title_label: Label
var body_scroll: ScrollContainer
var body_content: VBoxContainer
var restart_button: Button
var main_menu_button: Button
var copy_seed_button: Button
var summary_label: Label
var achievements_label: RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
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
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	panel = Panel.new()
	panel.name = "Panel"
	root.add_child(panel)

	title_label = Label.new()
	var title := title_label
	title.text = "任務失敗"
	title_label.anchor_left = 0.0
	title_label.anchor_right = 1.0
	title_label.offset_top = 24.0
	title_label.offset_bottom = 60.0
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.54, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.35, 0.06, 0.04, 0.9))
	title_label.add_theme_constant_override("outline_size", 2)
	panel.add_child(title_label)

	body_scroll = ScrollContainer.new()
	body_scroll.name = "BodyScroll"
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.anchor_left = 0.0
	body_scroll.anchor_right = 1.0
	body_scroll.anchor_top = 0.0
	body_scroll.anchor_bottom = 1.0
	panel.add_child(body_scroll)

	body_content = VBoxContainer.new()
	body_content.name = "BodyContent"
	body_content.add_theme_constant_override("separation", 10)
	body_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.add_child(body_content)

	summary_label = Label.new()
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 20)
	body_content.add_child(summary_label)

	achievements_label = RichTextLabel.new()
	achievements_label.name = "AchievementsLabel"
	achievements_label.bbcode_enabled = true
	achievements_label.fit_content = true
	achievements_label.scroll_active = false
	achievements_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_content.add_child(achievements_label)

	copy_seed_button = Button.new()
	copy_seed_button.text = "複製本局種子"
	copy_seed_button.pressed.connect(_on_copy_seed_pressed)
	panel.add_child(copy_seed_button)

	restart_button = Button.new()
	restart_button.text = "再來一局"
	restart_button.pressed.connect(_on_restart_pressed)
	panel.add_child(restart_button)

	main_menu_button = Button.new()
	main_menu_button.text = "回主選單"
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	panel.add_child(main_menu_button)
	_apply_responsive_layout()


func show_summary(summary: Dictionary) -> void:
	var progress: Dictionary = summary.get("echo_progress", {})
	var elapsed := float(summary.get("elapsed_time", 0.0))
	summary_label.text = "%s\n存活 %s　等級 %d　金幣 %d\n%s\n%s\n契約：%s\n%s" % [
		_survival_rating(elapsed),
		GameManager.format_time(elapsed),
		int(summary.get("level", 1)),
		int(summary.get("gold", 0)),
		_kill_stage_summary(summary),
		_boss_stage_summary(summary),
		str(summary.get("contract_name", "無契約")),
		_echo_destination_text(summary, progress)
	]
	if achievements_label != null:
		achievements_label.text = _achievement_text(summary)
	root.visible = true


func _on_restart_pressed() -> void:
	root.visible = false
	restart_requested.emit()


func _on_main_menu_pressed() -> void:
	root.visible = false
	main_menu_requested.emit()


func _on_copy_seed_pressed() -> void:
	GameManager.copy_current_run_seed_to_clipboard()


func hide_screen() -> void:
	if root != null:
		root.visible = false


func _survival_rating(elapsed: float) -> String:
	if elapsed < 30.0:
		return "評價：裂縫入口失守。"
	if elapsed < 90.0:
		return "評價：摸到節奏，火力尚未成形。"
	if elapsed < 180.0:
		return "評價：撐過中段壓力。"
	if elapsed < 300.0:
		return "評價：已逼近守門者節點。"
	return "評價：長線遠征，隊伍已有 Demo 強度。"


func _kill_stage_summary(summary: Dictionary) -> String:
	var elites_seen := int(summary.get("elites_spawned", summary.get("elites_killed", 0)))
	if elites_seen <= 0:
		return "戰況：擊殺 %d，尚未遭遇精英。" % int(summary.get("kills", 0))
	return "戰況：擊殺 %d，精英 %d/%d。" % [
		int(summary.get("kills", 0)),
		int(summary.get("elites_killed", 0)),
		elites_seen
	]


func _boss_stage_summary(summary: Dictionary) -> String:
	if bool(summary.get("boss_killed", false)):
		return "Boss：守門者已擊破。"
	if bool(summary.get("boss_phase_two_reached", false)):
		return "Boss：已逼出二階，差最後壓制。"
	if bool(summary.get("boss_spawned", false)) or bool(summary.get("boss_active", false)):
		return "Boss：已接敵，隊伍倒在守門者前。"
	return "Boss：尚未現身。"


func _echo_destination_text(summary: Dictionary, progress: Dictionary) -> String:
	var earned := int(summary.get("echo_shards_earned", 0))
	var held := int(progress.get("shards", 0))
	if earned <= 0:
		return "殘響：本局未取得碎片；撐過 30 秒即可帶回資源。"
	var next_track := _next_meta_track()
	if next_track.is_empty():
		return "殘響：+%d 碎片；三條殘響已滿，先保留給後續解鎖。" % earned
	var track_id := str(next_track.get("id", ""))
	var track_name := str(next_track.get("name", "殘響升級"))
	var cost := int(MetaProgress.get_upgrade_cost(track_id)) if MetaProgress.has_method("get_upgrade_cost") else 0
	if held >= cost:
		return "殘響：+%d 碎片；下局開局可購買「%s」。" % [earned, track_name]
	return "殘響：+%d 碎片；累積到 %d 可購買「%s」（目前 %d）。" % [
		earned,
		cost,
		track_name,
		held
	]


func _next_meta_track() -> Dictionary:
	if not MetaProgress.has_method("get_track_definitions"):
		return {}
	for track in MetaProgress.get_track_definitions():
		var track_id := str(track.get("id", ""))
		var level := int(MetaProgress.get_upgrade_level(track_id)) if MetaProgress.has_method("get_upgrade_level") else 0
		if level < int(track.get("max_level", 1)):
			return track
	return {}


func _achievement_text(summary: Dictionary) -> String:
	if AchievementProgress == null or not AchievementProgress.has_method("get_display_rows"):
		return ""
	var new_unlocks: Array = summary.get("achievement_unlocks", [])
	var names: Array[String] = []
	for achievement in new_unlocks:
		names.append(str(achievement.get("name", "")))
	var lines: Array[String] = []
	lines.append("[color=#f4e8a0]本局新解鎖：%s[/color]" % ("、".join(names) if not names.is_empty() else "無"))
	for row in AchievementProgress.get_display_rows():
		var unlocked := bool(row.get("unlocked", false))
		var color := "#f1f5f0" if unlocked else "#777f86"
		var mark := "已" if unlocked else "未"
		lines.append("[color=%s]%s %s[/color]" % [color, mark, str(row.get("name", ""))])
	return "\n".join(lines)


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
	var panel_width: float = min(viewport_size.x - (24.0 if mobile else 32.0), 820.0 if compact_landscape else 640.0 if mobile else 600.0)
	var panel_height: float = min(viewport_size.y - (24.0 if mobile else 32.0), 760.0 if mobile and portrait else 620.0 if mobile else 660.0 if portrait else 560.0)

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
		title_label.offset_bottom = title_label.offset_top + (56.0 if compact_landscape else 56.0 if mobile else 36.0)
		title_label.add_theme_font_size_override("font_size", (24 if portrait else 22) if mobile else 28)

	var button_width: float = 246.0 if compact_landscape else 272.0 if mobile else 236.0
	var button_left: float = panel_width - button_width - 24.0 if compact_landscape else (panel_width - button_width) * 0.5
	var button_gap: float = 12.0
	var button_height: float = touch_height if mobile else 40.0
	var button_stack_height: float = button_height * 3.0 + button_gap * 2.0
	var button_top: float = max((title_label.offset_bottom + 14.0) if title_label != null else 72.0, (panel_height - button_stack_height) * 0.5) if compact_landscape else panel_height - ((touch_height + 12.0) * 3.0 + 12.0 if mobile else 150.0)

	if copy_seed_button != null:
		copy_seed_button.anchor_left = 0.0
		copy_seed_button.anchor_right = 0.0
		copy_seed_button.offset_left = button_left
		copy_seed_button.offset_right = button_left + button_width
		copy_seed_button.offset_top = button_top
		copy_seed_button.offset_bottom = copy_seed_button.offset_top + button_height

	if restart_button != null:
		restart_button.anchor_left = 0.0
		restart_button.anchor_right = 0.0
		restart_button.offset_left = button_left
		restart_button.offset_right = button_left + button_width
		restart_button.offset_top = copy_seed_button.offset_bottom + button_gap if copy_seed_button != null else button_top + button_height + button_gap
		restart_button.offset_bottom = restart_button.offset_top + button_height

	if main_menu_button != null:
		main_menu_button.anchor_left = 0.0
		main_menu_button.anchor_right = 0.0
		main_menu_button.offset_left = button_left
		main_menu_button.offset_right = button_left + button_width
		main_menu_button.offset_top = restart_button.offset_bottom + button_gap if restart_button != null else button_top + (button_height + button_gap) * 2.0
		main_menu_button.offset_bottom = main_menu_button.offset_top + button_height

	var body_left: float = 24.0 if mobile else 32.0
	var body_right: float = -(panel_width - button_left + 18.0) if compact_landscape else -body_left
	var body_top: float = (title_label.offset_bottom + 10.0) if title_label != null else 84.0
	var body_bottom: float = -20.0 if compact_landscape else -(panel_height - button_top + 12.0)
	if body_scroll != null:
		body_scroll.offset_left = body_left
		body_scroll.offset_right = body_right
		body_scroll.offset_top = body_top
		body_scroll.offset_bottom = body_bottom
	if body_content != null:
		var body_width: float = max(1.0, panel_width + body_right - body_left)
		body_content.custom_minimum_size = Vector2(body_width, 0.0)

	if summary_label != null:
		summary_label.add_theme_font_size_override("font_size", (15 if portrait else 16) if mobile else (17 if not portrait else 16))
		summary_label.custom_minimum_size = Vector2(0.0, 108.0 if not compact_landscape else 96.0)

	if achievements_label != null:
		achievements_label.add_theme_font_size_override("normal_font_size", (13 if portrait else 14) if mobile else (15 if not portrait else 14))
		achievements_label.custom_minimum_size = Vector2(0.0, 138.0 if compact_landscape else 180.0 if mobile else 160.0)
	MOBILE_TUNING.apply_control_tree(root, viewport_size)
