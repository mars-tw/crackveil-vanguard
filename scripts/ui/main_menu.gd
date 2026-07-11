extends Node

const ARENA_SCENE_PATH := "res://scenes/arena/Arena.tscn"
const BACKGROUND_SCRIPT := preload("res://scripts/arena/arena_background.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")

var background: Node2D
var ui_layer: CanvasLayer
var root: Control
var logo_glow_label: Label
var logo_label: Label
var menu_box: VBoxContainer
var start_button: Button
var meta_button: Button
var achievements_button: Button
var settings_button: Button
var seed_row: HBoxContainer
var seed_input: LineEdit
var seed_start_button: Button
var side_panel: Panel
var side_title: Label
var side_close_button: Button
var side_scroll: ScrollContainer
var side_content: VBoxContainer
var version_label: Label
var meta_buttons: Dictionary = {}
var volume_slider: HSlider
var mute_check: CheckBox
var damage_numbers_check: CheckBox
var screen_shake_check: CheckBox
var syncing_settings: bool = false
var syncing_audio: bool = false
var active_panel_id: String = "meta"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	GameManager.game_running = false
	GameManager.is_game_over = false
	GameManager.system_pause_owners.clear()
	_build_background()
	_build_ui()
	if not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)
	if MetaProgress.has_signal("progress_changed") and not MetaProgress.progress_changed.is_connected(_refresh_active_panel):
		MetaProgress.progress_changed.connect(_refresh_active_panel)
	if AchievementProgress.has_signal("achievement_unlocked") and not AchievementProgress.achievement_unlocked.is_connected(_on_achievement_changed):
		AchievementProgress.achievement_unlocked.connect(_on_achievement_changed)
	if PlayerSettings.has_signal("settings_changed") and not PlayerSettings.settings_changed.is_connected(_sync_settings_controls):
		PlayerSettings.settings_changed.connect(_sync_settings_controls)
	if AudioManager.has_signal("settings_changed") and not AudioManager.settings_changed.is_connected(_sync_audio_controls):
		AudioManager.settings_changed.connect(_sync_audio_controls)


func _build_background() -> void:
	background = Node2D.new()
	background.name = "MenuBackground"
	background.z_index = -100
	background.set_script(BACKGROUND_SCRIPT)
	add_child(background)


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "MenuUI"
	ui_layer.layer = 10
	add_child(ui_layer)

	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root)

	logo_glow_label = Label.new()
	logo_glow_label.text = "CRACKVEIL VANGUARD"
	logo_glow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_glow_label.add_theme_color_override("font_color", Color(0.18, 0.94, 1.0, 0.2))
	logo_glow_label.add_theme_color_override("font_outline_color", Color(0.08, 0.68, 0.98, 0.24))
	logo_glow_label.add_theme_constant_override("outline_size", 10)
	root.add_child(logo_glow_label)

	logo_label = Label.new()
	logo_label.text = "CRACKVEIL VANGUARD"
	logo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_label.add_theme_color_override("font_color", Color(0.88, 0.98, 1.0, 1.0))
	logo_label.add_theme_color_override("font_outline_color", Color(0.06, 0.42, 0.58, 0.92))
	logo_label.add_theme_constant_override("outline_size", 2)
	root.add_child(logo_label)

	menu_box = VBoxContainer.new()
	menu_box.name = "MenuBox"
	menu_box.add_theme_constant_override("separation", 10)
	root.add_child(menu_box)

	start_button = _make_menu_button("開始出擊")
	start_button.pressed.connect(_on_start_pressed)
	menu_box.add_child(start_button)

	meta_button = _make_menu_button("殘響升級")
	meta_button.pressed.connect(_show_panel.bind("meta"))
	menu_box.add_child(meta_button)

	achievements_button = _make_menu_button("成就")
	achievements_button.pressed.connect(_show_panel.bind("achievements"))
	menu_box.add_child(achievements_button)

	settings_button = _make_menu_button("設定")
	settings_button.pressed.connect(_show_panel.bind("settings"))
	menu_box.add_child(settings_button)

	seed_row = HBoxContainer.new()
	seed_row.name = "SeedRow"
	seed_row.add_theme_constant_override("separation", 8)
	root.add_child(seed_row)

	seed_input = LineEdit.new()
	seed_input.placeholder_text = "輸入種子"
	seed_input.text_submitted.connect(_on_seed_submitted)
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(seed_input)

	seed_start_button = Button.new()
	seed_start_button.text = "種子出擊"
	seed_start_button.pressed.connect(_on_seed_start_pressed)
	seed_row.add_child(seed_start_button)

	side_panel = Panel.new()
	side_panel.name = "SidePanel"
	side_panel.visible = false
	root.add_child(side_panel)

	side_title = Label.new()
	side_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side_title.add_theme_font_size_override("font_size", 24)
	side_panel.add_child(side_title)

	side_close_button = Button.new()
	side_close_button.text = "關閉"
	side_close_button.pressed.connect(_on_close_panel_pressed)
	side_panel.add_child(side_close_button)

	side_scroll = ScrollContainer.new()
	side_scroll.name = "SideScroll"
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_panel.add_child(side_scroll)

	side_content = VBoxContainer.new()
	side_content.name = "SideContent"
	side_content.add_theme_constant_override("separation", 10)
	side_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(side_content)

	version_label = Label.new()
	version_label.text = _build_version_text()
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.add_theme_font_size_override("font_size", 12)
	root.add_child(version_label)
	_apply_responsive_layout()


func _make_menu_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(220.0, 48.0)
	button.add_theme_font_size_override("font_size", 20)
	return button


func _show_panel(panel_id: String) -> void:
	active_panel_id = panel_id
	side_panel.visible = true
	for child in side_content.get_children():
		child.queue_free()
	meta_buttons.clear()
	match panel_id:
		"achievements":
			side_title.text = "成就"
			_build_achievements_panel()
		"settings":
			side_title.text = "設定"
			_build_settings_panel()
		_:
			active_panel_id = "meta"
			side_title.text = "殘響升級"
			_build_meta_panel()
	_apply_responsive_layout()


func _build_meta_panel() -> void:
	var summary := MetaProgress.get_progress_summary() if MetaProgress.has_method("get_progress_summary") else {}
	var summary_label := Label.new()
	summary_label.text = "碎片 %d    累積 %d" % [int(summary.get("shards", 0)), int(summary.get("lifetime_shards", 0))]
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side_content.add_child(summary_label)

	for track in MetaProgress.get_track_definitions():
		var track_id := str(track.get("id", ""))
		var button := Button.new()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_meta_upgrade_pressed.bind(track_id))
		side_content.add_child(button)
		meta_buttons[track_id] = button

	var unlock_label := Label.new()
	unlock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unlock_label.text = _unlock_text()
	side_content.add_child(unlock_label)
	_refresh_meta_buttons()


func _refresh_meta_buttons() -> void:
	if not MetaProgress.has_method("get_track_definitions"):
		return
	var summary := MetaProgress.get_progress_summary()
	for track in MetaProgress.get_track_definitions():
		var track_id := str(track.get("id", ""))
		var button: Button = meta_buttons.get(track_id)
		if button == null:
			continue
		var level := int(MetaProgress.get_upgrade_level(track_id))
		var max_level := int(track.get("max_level", 1))
		var cost := int(MetaProgress.get_upgrade_cost(track_id))
		button.text = "%s  %d/%d\n%s\n%s" % [
			str(track.get("name", "")),
			level,
			max_level,
			str(track.get("description", "")),
			"已滿" if level >= max_level else "消耗 %d" % cost
		]
		button.disabled = level >= max_level or int(summary.get("shards", 0)) < cost


func _unlock_text() -> String:
	if not MetaProgress.has_method("get_unlock_definitions"):
		return ""
	var lines: Array[String] = ["解鎖入口"]
	for unlock in MetaProgress.get_unlock_definitions():
		var unlock_id := str(unlock.get("id", ""))
		var unlocked := MetaProgress.has_unlock(unlock_id)
		lines.append("%s %s（累積 %d）" % [
			"已解鎖" if unlocked else "未解鎖",
			str(unlock.get("name", "")),
			int(unlock.get("required_lifetime_shards", 0))
		])
	return "\n".join(lines)


func _build_achievements_panel() -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = true
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.text = _achievement_text()
	side_content.add_child(label)


func _achievement_text() -> String:
	if AchievementProgress == null or not AchievementProgress.has_method("get_display_rows"):
		return ""
	var lines: Array[String] = []
	for row in AchievementProgress.get_display_rows():
		var unlocked := bool(row.get("unlocked", false))
		var color := "#f1f5f0" if unlocked else "#777f86"
		var mark := "已" if unlocked else "未"
		lines.append("[color=%s]%s %s[/color]\n%s" % [
			color,
			mark,
			str(row.get("name", "")),
			str(row.get("description", ""))
		])
	return "\n\n".join(lines)


func _build_settings_panel() -> void:
	var volume_label := Label.new()
	volume_label.text = "音量"
	side_content.add_child(volume_label)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value_changed.connect(_on_volume_slider_changed)
	side_content.add_child(volume_slider)

	mute_check = CheckBox.new()
	mute_check.text = "靜音"
	mute_check.toggled.connect(_on_mute_toggled)
	side_content.add_child(mute_check)

	damage_numbers_check = CheckBox.new()
	damage_numbers_check.text = "顯示傷害數字"
	damage_numbers_check.toggled.connect(_on_damage_numbers_toggled)
	side_content.add_child(damage_numbers_check)

	screen_shake_check = CheckBox.new()
	screen_shake_check.text = "螢幕震動"
	screen_shake_check.toggled.connect(_on_screen_shake_toggled)
	side_content.add_child(screen_shake_check)
	_sync_audio_controls()
	_sync_settings_controls()


func _on_start_pressed() -> void:
	_start_run("")


func _on_seed_submitted(text_value: String) -> void:
	_start_run(text_value)


func _on_seed_start_pressed() -> void:
	_start_run(seed_input.text if seed_input != null else "")


func _start_run(seed_text: String) -> void:
	var selected_seed := GameManager.seed_from_text(seed_text) if seed_text.strip_edges() != "" else 0
	GameManager.forced_run_seed = selected_seed
	get_tree().paused = false
	get_tree().change_scene_to_file(ARENA_SCENE_PATH)


func _on_close_panel_pressed() -> void:
	side_panel.visible = false


func _on_meta_upgrade_pressed(track_id: String) -> void:
	if MetaProgress.has_method("buy_upgrade") and MetaProgress.buy_upgrade(track_id):
		if AudioManager != null and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("contract")
	_show_panel("meta")


func _refresh_active_panel() -> void:
	if side_panel != null and side_panel.visible:
		_show_panel(active_panel_id)


func _on_achievement_changed(_achievement: Dictionary) -> void:
	if active_panel_id == "achievements":
		_refresh_active_panel()


func _sync_audio_controls() -> void:
	if volume_slider == null or mute_check == null or AudioManager == null:
		return
	syncing_audio = true
	volume_slider.value = float(AudioManager.get("master_volume"))
	mute_check.button_pressed = bool(AudioManager.get("muted"))
	syncing_audio = false


func _sync_settings_controls() -> void:
	if PlayerSettings == null:
		return
	syncing_settings = true
	if damage_numbers_check != null:
		damage_numbers_check.button_pressed = bool(PlayerSettings.get("damage_numbers_enabled"))
	if screen_shake_check != null:
		screen_shake_check.button_pressed = bool(PlayerSettings.get("screen_shake_enabled"))
	syncing_settings = false


func _on_volume_slider_changed(value: float) -> void:
	if syncing_audio or AudioManager == null:
		return
	AudioManager.set_master_volume(value)


func _on_mute_toggled(value: bool) -> void:
	if syncing_audio or AudioManager == null:
		return
	AudioManager.set_muted(value)


func _on_damage_numbers_toggled(value: bool) -> void:
	if syncing_settings or PlayerSettings == null:
		return
	PlayerSettings.set_damage_numbers_enabled(value)


func _on_screen_shake_toggled(value: bool) -> void:
	if syncing_settings or PlayerSettings == null:
		return
	PlayerSettings.set_screen_shake_enabled(value)


func _apply_responsive_layout() -> void:
	if root == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var portrait := viewport_size.y > viewport_size.x
	var mobile := MOBILE_TUNING.use_mobile_ui(viewport_size)
	var margin := 28.0 if not portrait else 18.0
	if mobile:
		margin = 18.0 if portrait else 16.0
	var touch_height := MOBILE_TUNING.touch_target(viewport_size)
	var button_height := touch_height if mobile else 48.0
	var button_gap := 12.0 if mobile and portrait else 4.0 if mobile else 10.0

	logo_glow_label.anchor_left = 0.0
	logo_glow_label.anchor_right = 1.0
	logo_label.anchor_left = 0.0
	logo_label.anchor_right = 1.0
	var mobile_logo_text := "CRACKVEIL\nVANGUARD" if portrait else "CRACKVEIL VANGUARD"
	logo_label.text = mobile_logo_text if mobile else "CRACKVEIL VANGUARD"
	logo_glow_label.text = logo_label.text
	var logo_top := 18.0 if mobile and portrait else 4.0 if mobile else (44.0 if not portrait else 29.0)
	var logo_height := 168.0 if mobile and portrait else 46.0 if mobile else 66.0
	logo_label.offset_top = logo_top
	logo_label.offset_bottom = logo_top + logo_height
	logo_label.add_theme_font_size_override("font_size", (34 if portrait else 20) if mobile else (48 if not portrait else 32))

	logo_glow_label.offset_top = logo_label.offset_top
	logo_glow_label.offset_bottom = logo_label.offset_bottom
	logo_glow_label.add_theme_font_size_override("font_size", (34 if portrait else 20) if mobile else (48 if not portrait else 32))

	menu_box.add_theme_constant_override("separation", button_gap)
	var menu_width: float = min(max(320.0, viewport_size.x * 0.9), viewport_size.x - margin * 2.0) if mobile and portrait else min(320.0, viewport_size.x * 0.42) if mobile else 270.0
	var menu_x := (viewport_size.x - menu_width) * 0.5 if mobile and portrait else margin
	var menu_y := logo_label.offset_bottom + 18.0 if mobile and portrait else logo_label.offset_bottom + 4.0 if mobile else 164.0 if not portrait else 108.0
	menu_box.size = Vector2(menu_width, button_height * 4.0 + button_gap * 3.0)
	menu_box.position = Vector2(menu_x, menu_y)
	for child in menu_box.get_children():
		if child is Button:
			(child as Button).custom_minimum_size = Vector2(menu_width, button_height)
			(child as Button).add_theme_font_size_override("font_size", 22 if mobile and portrait else 16 if mobile else 20)

	var seed_height := touch_height if mobile else 42.0
	if mobile and not portrait:
		var seed_width: float = max(280.0, viewport_size.x - menu_width - margin * 3.0)
		seed_row.position = Vector2(menu_box.position.x + menu_width + margin, menu_y)
		seed_row.size = Vector2(seed_width, seed_height)
		seed_input.custom_minimum_size = Vector2(max(150.0, seed_width - 144.0), seed_height)
		seed_start_button.custom_minimum_size = Vector2(132.0, seed_height)
	else:
		seed_row.position = menu_box.position + Vector2(0.0, menu_box.size.y + (16.0 if mobile else 16.0))
		seed_row.size = Vector2(menu_width, seed_height)
		seed_input.custom_minimum_size = Vector2(max(140.0, menu_width - (140.0 if mobile else 116.0)), seed_height)
		seed_start_button.custom_minimum_size = Vector2(132.0 if mobile else 108.0, seed_height)

	var panel_width: float = min(viewport_size.x - margin * 2.0, 520.0 if not portrait else viewport_size.x - margin * 2.0)
	var panel_height: float = min(viewport_size.y - margin * 2.0, 520.0 if not portrait else viewport_size.y - 430.0)
	var panel_y := 154.0 if not portrait else 398.0
	var panel_x := viewport_size.x - panel_width - margin
	if mobile:
		if portrait:
			panel_width = viewport_size.x - margin * 2.0
			panel_x = margin
			panel_y = max(126.0, logo_label.offset_top + 112.0)
			panel_height = max(360.0, viewport_size.y - panel_y - margin)
		else:
			panel_width = max(300.0, viewport_size.x - menu_width - margin * 3.0)
			panel_x = menu_box.position.x + menu_width + margin
			panel_y = seed_row.position.y + seed_height + 10.0
			panel_height = max(190.0, viewport_size.y - panel_y - margin)
	panel_height = max(panel_height, 260.0 if not mobile else 164.0)
	side_panel.position = Vector2(panel_x, panel_y)
	side_panel.size = Vector2(panel_width, panel_height)

	side_title.position = Vector2(22.0, 18.0)
	side_title.size = Vector2(panel_width - (154.0 if mobile else 132.0), 52.0 if mobile else 34.0)
	side_title.add_theme_font_size_override("font_size", 22 if mobile else 24)
	side_close_button.position = Vector2(panel_width - (126.0 if mobile else 92.0), 14.0)
	side_close_button.size = Vector2(104.0 if mobile else 70.0, touch_height if mobile else 36.0)
	if side_scroll != null:
		side_scroll.position = Vector2(24.0 if mobile else 28.0, 86.0 if mobile else 70.0)
		side_scroll.size = Vector2(panel_width - (48.0 if mobile else 56.0), panel_height - (104.0 if mobile else 92.0))
	if side_content != null:
		side_content.custom_minimum_size = Vector2(max(240.0, panel_width - (48.0 if mobile else 56.0)), 0.0)

	version_label.anchor_left = 1.0
	version_label.anchor_right = 1.0
	version_label.anchor_top = 1.0
	version_label.anchor_bottom = 1.0
	version_label.offset_left = -320.0
	version_label.offset_right = -margin
	version_label.offset_top = -32.0
	version_label.offset_bottom = -10.0
	MOBILE_TUNING.apply_control_tree(root, viewport_size)


func _build_version_text() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", "dev"))
	var build_date := str(ProjectSettings.get_setting("application/config/build_date", "local"))
	return "v%s  %s" % [version, build_date]
