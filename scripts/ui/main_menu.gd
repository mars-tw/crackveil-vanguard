extends Node

const ARENA_SCENE_PATH := "res://scenes/arena/Arena.tscn"
const BACKGROUND_SCRIPT := preload("res://scripts/arena/arena_background.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const WEB_REACHABILITY_PROBE := preload("res://scripts/services/web_reachability_probe.gd")
const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")

var background: Node2D
var ui_layer: CanvasLayer
var root: Control
var key_art: TextureRect
var rift_accent: TextureRect
var logo_glow_label: Label
var logo_label: Label
var menu_box: VBoxContainer
var start_button: Button
var guide_button: Button
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
var achievements_grid: GridContainer
var achievement_dialog: AcceptDialog
var version_label: Label
var meta_buttons: Dictionary = {}
var volume_label: Label
var volume_slider: HSlider
var mute_check: CheckBox
var damage_numbers_check: CheckBox
var screen_shake_check: CheckBox
var force_joystick_check: CheckBox
var high_contrast_check: CheckBox
var ui_scale_label: Label
var ui_scale_slider: HSlider
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

	key_art = TextureRect.new()
	key_art.name = "R24KeyArt"
	key_art.texture = SPRITE_LOADER.get_texture("res://assets/art/r24/keyart/menu_keyart_desktop.png")
	key_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	key_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	key_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	key_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(key_art)

	rift_accent = TextureRect.new()
	rift_accent.name = "PortraitRiftAccent"
	rift_accent.texture = SPRITE_LOADER.get_texture("res://assets/art/rift_cracks.png")
	rift_accent.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rift_accent.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rift_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rift_accent)

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

	guide_button = _make_menu_button("玩法")
	guide_button.pressed.connect(_show_panel.bind("guide"))
	menu_box.add_child(guide_button)

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
	side_content.add_theme_constant_override("separation", 12)
	side_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(side_content)

	version_label = Label.new()
	version_label.text = _build_version_text()
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.add_theme_font_size_override("font_size", 12)
	root.add_child(version_label)

	achievement_dialog = AcceptDialog.new()
	achievement_dialog.title = "成就"
	achievement_dialog.ok_button_text = "關閉"
	ui_layer.add_child(achievement_dialog)
	achievement_dialog.get_ok_button().custom_minimum_size.y = 44.0
	_apply_responsive_layout()


func _make_menu_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(220.0, 48.0)
	button.add_theme_font_size_override("font_size", 20)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.045, 0.105, 0.15, 0.78)
	normal.border_color = Color(0.34, 0.82, 0.94, 0.72)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.shadow_color = Color(0.05, 0.72, 0.9, 0.18)
	normal.shadow_size = 7
	normal.content_margin_left = 16.0
	normal.content_margin_right = 16.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.07, 0.18, 0.24, 0.92)
	hover.border_color = Color(0.56, 0.96, 1.0, 0.96)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.025, 0.075, 0.11, 0.96)
	pressed.border_color = Color(0.78, 1.0, 1.0, 1.0)
	pressed.content_margin_top = 4.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.86, 0.97, 1.0))
	return button


func _show_panel(panel_id: String) -> void:
	active_panel_id = panel_id
	side_panel.visible = true
	volume_slider = null
	volume_label = null
	mute_check = null
	damage_numbers_check = null
	screen_shake_check = null
	force_joystick_check = null
	high_contrast_check = null
	ui_scale_label = null
	ui_scale_slider = null
	for child in side_content.get_children():
		child.queue_free()
	meta_buttons.clear()
	achievements_grid = null
	match panel_id:
		"achievements":
			side_title.text = "成就"
			_build_achievements_panel()
		"settings":
			side_title.text = "設定"
			_build_settings_panel()
		"guide":
			side_title.text = "玩法"
			_build_guide_panel()
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
	achievements_grid = GridContainer.new()
	achievements_grid.name = "AchievementsGrid"
	achievements_grid.columns = 3
	achievements_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievements_grid.add_theme_constant_override("h_separation", 8)
	achievements_grid.add_theme_constant_override("v_separation", 8)
	side_content.add_child(achievements_grid)
	_refresh_achievement_grid()


func _build_achievements_panel_legacy_unused() -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = true
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.text = _achievement_text()
	side_content.add_child(label)


func _refresh_achievement_grid() -> void:
	if achievements_grid == null or AchievementProgress == null or not AchievementProgress.has_method("get_display_rows"):
		return
	for child in achievements_grid.get_children():
		achievements_grid.remove_child(child)
		child.queue_free()
	for row in AchievementProgress.get_display_rows():
		achievements_grid.add_child(_make_achievement_badge(row))


func _make_achievement_badge(row: Dictionary) -> Button:
	var unlocked := bool(row.get("unlocked", false))
	var button := Button.new()
	button.text = "%s\n%s" % ["✓" if unlocked else "□", str(row.get("name", ""))]
	button.tooltip_text = str(row.get("description", ""))
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(104.0, 64.0)
	button.pressed.connect(_on_achievement_badge_pressed.bind(row))
	_apply_achievement_badge_style(button, unlocked)
	return button


func _apply_achievement_badge_style(button: Button, unlocked: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.16, 0.14, 0.9) if unlocked else Color(0.035, 0.04, 0.052, 0.82)
	normal.border_color = Color(0.52, 1.0, 0.74, 0.88) if unlocked else Color(0.24, 0.29, 0.34, 0.88)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.07, 0.22, 0.2, 0.96) if unlocked else Color(0.06, 0.07, 0.09, 0.92)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.025, 0.1, 0.095, 1.0) if unlocked else Color(0.025, 0.03, 0.04, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.9, 1.0, 0.92, 1.0) if unlocked else Color(0.5, 0.56, 0.62, 1.0))
	button.add_theme_font_size_override("font_size", 13)


func _on_achievement_badge_pressed(row: Dictionary) -> void:
	if achievement_dialog == null:
		return
	var status := "已解鎖" if bool(row.get("unlocked", false)) else "未解鎖"
	achievement_dialog.title = "%s  %s" % [status, str(row.get("name", ""))]
	achievement_dialog.dialog_text = str(row.get("description", ""))
	var viewport_size := MOBILE_TUNING.ui_layout_size(get_viewport().get_visible_rect().size)
	var dialog_size := Vector2i(
		int(min(360.0, max(220.0, viewport_size.x - 24.0))),
		int(min(180.0, max(132.0, viewport_size.y - 24.0)))
	)
	achievement_dialog.get_ok_button().custom_minimum_size.y = maxf(44.0, MOBILE_TUNING.touch_target(viewport_size))
	achievement_dialog.popup_centered(dialog_size)


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
	volume_label = Label.new()
	volume_label.text = "音量"
	side_content.add_child(volume_label)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.custom_minimum_size = Vector2(240.0, 44.0)
	volume_slider.value_changed.connect(_on_volume_slider_changed)
	side_content.add_child(volume_slider)

	var toggle_grid := GridContainer.new()
	toggle_grid.columns = 2
	toggle_grid.add_theme_constant_override("h_separation", 10)
	toggle_grid.add_theme_constant_override("v_separation", 6)
	toggle_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_content.add_child(toggle_grid)

	mute_check = CheckBox.new()
	mute_check.text = "靜音"
	mute_check.toggled.connect(_on_mute_toggled)
	toggle_grid.add_child(mute_check)

	damage_numbers_check = CheckBox.new()
	damage_numbers_check.text = "顯示傷害數字"
	damage_numbers_check.toggled.connect(_on_damage_numbers_toggled)
	toggle_grid.add_child(damage_numbers_check)

	screen_shake_check = CheckBox.new()
	screen_shake_check.text = "螢幕震動"
	screen_shake_check.toggled.connect(_on_screen_shake_toggled)
	toggle_grid.add_child(screen_shake_check)

	force_joystick_check = CheckBox.new()
	force_joystick_check.text = "強制顯示搖桿"
	force_joystick_check.toggled.connect(_on_force_joystick_toggled)
	toggle_grid.add_child(force_joystick_check)

	high_contrast_check = CheckBox.new()
	high_contrast_check.text = "高對比"
	high_contrast_check.toggled.connect(_on_high_contrast_toggled)
	toggle_grid.add_child(high_contrast_check)

	ui_scale_label = Label.new()
	ui_scale_label.text = "介面大小"
	side_content.add_child(ui_scale_label)

	ui_scale_slider = HSlider.new()
	ui_scale_slider.min_value = 0.0
	ui_scale_slider.max_value = 2.0
	ui_scale_slider.step = 1.0
	ui_scale_slider.tick_count = 3
	ui_scale_slider.ticks_on_borders = true
	ui_scale_slider.custom_minimum_size = Vector2(240.0, 44.0)
	ui_scale_slider.value_changed.connect(_on_ui_scale_slider_changed)
	side_content.add_child(ui_scale_slider)
	_sync_audio_controls()
	_sync_settings_controls()


func _build_guide_panel() -> void:
	var guide_text := Label.new()
	guide_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_text.text = "\n".join([
		"每局會從裂隙虛空、廢土農野、餘燼裂原隨機抽選一個戰場；擊敗 Boss 後可繼續無盡作戰。",
		"開局先選契約：契約會改變本局風險與獎勵。",
		"招募會把隊伍擴到最多 9 人；隊長死亡時全隊撤退。",
		"羈絆由特定成員組合啟用，會改變武器、治療或防禦。",
		"武器進化需要本局等級 7、指定質變等級與武器傷害等級。",
		"商亭會在 Boss 前後出現，花金幣補血、改裝或刷新選項。",
	])
	side_content.add_child(guide_text)

	var tip_label := Label.new()
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.text = "進局後也可從暫停選單重看情境教學。"
	side_content.add_child(tip_label)


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
	if force_joystick_check != null:
		force_joystick_check.button_pressed = bool(PlayerSettings.get("force_joystick_visible"))
	if high_contrast_check != null:
		high_contrast_check.button_pressed = bool(PlayerSettings.get("high_contrast_enabled"))
	if ui_scale_slider != null:
		ui_scale_slider.value = float(PlayerSettings.get("ui_scale_index"))
	if ui_scale_label != null:
		ui_scale_label.text = "介面大小：%s" % _ui_scale_label(int(PlayerSettings.get("ui_scale_index")))
	syncing_settings = false
	_apply_accessibility_palette()


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


func _on_force_joystick_toggled(value: bool) -> void:
	if syncing_settings or PlayerSettings == null:
		return
	PlayerSettings.set_force_joystick_visible(value)
	_apply_responsive_layout()


func _on_high_contrast_toggled(value: bool) -> void:
	if syncing_settings or PlayerSettings == null:
		return
	PlayerSettings.set_high_contrast_enabled(value)
	_apply_responsive_layout()


func _on_ui_scale_slider_changed(value: float) -> void:
	if syncing_settings or PlayerSettings == null:
		return
	var index := int(round(value))
	PlayerSettings.set_ui_scale_index(index)
	if ui_scale_label != null:
		ui_scale_label.text = "介面大小：%s" % _ui_scale_label(index)
	_apply_responsive_layout()


func _ui_scale_label(index: int) -> String:
	match clamp(index, 0, 2):
		0:
			return "精簡"
		2:
			return "大"
		_:
			return "標準"


func _apply_responsive_layout() -> void:
	if root == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	viewport_size = MOBILE_TUNING.apply_web_canvas_scale(ui_layer, viewport_size, root)
	var portrait := viewport_size.y > viewport_size.x
	var mobile := MOBILE_TUNING.use_mobile_ui(viewport_size)
	var margin := 28.0 if not portrait else 18.0
	if mobile:
		margin = 18.0 if portrait else 16.0
	var touch_height := MOBILE_TUNING.touch_target(viewport_size)
	var button_height := (56.0 if mobile and not portrait else touch_height) if mobile else 48.0
	var button_gap := 12.0 if mobile and portrait else 8.0 if mobile else 10.0
	var ui_multiplier := _ui_scale_multiplier()
	if key_art != null:
		# Select the safe crop by aspect ratio as well as device class.  A narrow
		# desktop browser must not fall back to the 16:9 composition simply because
		# its pointer is fine-grained.
		var key_art_path := "res://assets/art/r24/keyart/menu_keyart_mobile_safe.png" if portrait else "res://assets/art/r24/keyart/menu_keyart_desktop.png"
		key_art.texture = SPRITE_LOADER.get_texture(key_art_path)
		key_art.set_offsets_preset(Control.PRESET_FULL_RECT)
		key_art.modulate = Color(1.0, 1.0, 1.0, 0.96 if mobile and portrait else 1.0)
	if rift_accent != null:
		# R24 key art contains its own identity-locked rift; the legacy procedural
		# accent stays hidden so it cannot double the focal point on portrait crop.
		rift_accent.visible = false
		rift_accent.position = Vector2(-22.0, 74.0)
		rift_accent.size = Vector2(viewport_size.x + 44.0, min(690.0, viewport_size.y - 96.0))
		rift_accent.modulate = Color(0.26, 0.84, 1.0, 0.24)

	logo_glow_label.anchor_left = 0.0
	logo_glow_label.anchor_right = 1.0
	logo_label.anchor_left = 0.0
	logo_label.anchor_right = 1.0
	var mobile_logo_text := "CRACKVEIL\nVANGUARD" if portrait else "CRACKVEIL VANGUARD"
	logo_label.text = mobile_logo_text if mobile else "CRACKVEIL VANGUARD"
	logo_glow_label.text = logo_label.text
	var logo_top := 34.0 if mobile and portrait else 4.0 if mobile else (44.0 if not portrait else 29.0)
	var logo_height := 142.0 if mobile and portrait else 46.0 if mobile else 66.0
	logo_label.offset_top = logo_top
	logo_label.offset_bottom = logo_top + logo_height
	logo_label.add_theme_font_size_override("font_size", (36 if portrait else 20) if mobile else (48 if not portrait else 32))

	logo_glow_label.offset_top = logo_label.offset_top
	logo_glow_label.offset_bottom = logo_label.offset_bottom
	logo_glow_label.add_theme_font_size_override("font_size", (36 if portrait else 20) if mobile else (48 if not portrait else 32))

	menu_box.add_theme_constant_override("separation", button_gap)
	var menu_width: float = min(max(320.0, viewport_size.x * 0.9), viewport_size.x - margin * 2.0) if mobile and portrait else min(320.0, viewport_size.x * 0.42) if mobile else 270.0
	var menu_x := (viewport_size.x - menu_width) * 0.5 if mobile and portrait else margin
	var menu_y := logo_label.offset_bottom + 102.0 if mobile and portrait else logo_label.offset_bottom + 4.0 if mobile else 164.0 if not portrait else 108.0
	var menu_button_count := menu_box.get_child_count()
	var menu_block_height := button_height * float(menu_button_count) + button_gap * float(max(0, menu_button_count - 1))
	if mobile and portrait:
		# 直式：選單＋種子列整塊垂直置中，底部保留安全區——行動瀏覽器動態工具列
		# 會吃掉視口下緣，固定 top 偏移會把種子列排進被遮蓋帶
		var seed_block_height := touch_height + 16.0
		var bottom_reserve := maxf(viewport_size.y * 0.085, 64.0)
		var top_min := logo_label.offset_bottom + 24.0
		var centered_y := (viewport_size.y - (menu_block_height + seed_block_height)) * 0.5
		menu_y = clampf(centered_y, top_min, maxf(top_min, viewport_size.y - menu_block_height - seed_block_height - bottom_reserve))
	menu_box.size = Vector2(menu_width, menu_block_height)
	menu_box.position = Vector2(menu_x, menu_y)
	for child in menu_box.get_children():
		if child is Button:
			(child as Button).custom_minimum_size = Vector2(menu_width, button_height)
			(child as Button).add_theme_font_size_override("font_size", int(round(float(22 if mobile and portrait else 16 if mobile else 20) * ui_multiplier)))

	var seed_height := 56.0 if mobile and not portrait else touch_height
	var seed_gap: float = float(ceil(MOBILE_TUNING.BASE_CONTAINER_SEPARATION * MOBILE_TUNING.spacing_scale(viewport_size)))
	if mobile and not portrait:
		var seed_width: float = min(MOBILE_TUNING.SEED_ROW_MAX_WIDTH, max(280.0, viewport_size.x - menu_width - margin * 3.0))
		seed_row.position = Vector2(menu_box.position.x + menu_width + margin, menu_y)
		seed_row.size = Vector2(seed_width, seed_height)
		seed_input.custom_minimum_size = Vector2(max(140.0, seed_width - 132.0 - seed_gap), seed_height)
		seed_start_button.custom_minimum_size = Vector2(132.0, seed_height)
	else:
		seed_row.position = menu_box.position + Vector2(0.0, menu_box.size.y + (16.0 if mobile else 16.0))
		var seed_width: float = min(MOBILE_TUNING.SEED_ROW_MAX_WIDTH, menu_width)
		seed_row.size = Vector2(seed_width, seed_height)
		var seed_button_width := 132.0 if mobile else 108.0
		seed_input.custom_minimum_size = Vector2(max(140.0, seed_width - seed_button_width - seed_gap), seed_height)
		seed_start_button.custom_minimum_size = Vector2(seed_button_width, seed_height)

	var panel_width: float = min(viewport_size.x - margin * 2.0, 520.0 if not portrait else viewport_size.x - margin * 2.0)
	var panel_height: float = min(viewport_size.y - margin * 2.0, 520.0 if not portrait else viewport_size.y - 430.0)
	var panel_y := 154.0 if not portrait else 398.0
	if not mobile and not portrait and viewport_size.y <= 640.0:
		panel_y = 96.0
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
			panel_y = menu_y
			panel_height = max(190.0, viewport_size.y - panel_y - margin)
	var available_panel_height: float = max(1.0, viewport_size.y - panel_y - margin)
	var minimum_panel_height: float = min(260.0 if not mobile else 164.0, available_panel_height)
	panel_height = clamp(panel_height, minimum_panel_height, available_panel_height)
	side_panel.position = Vector2(panel_x, panel_y)
	side_panel.size = Vector2(panel_width, panel_height)

	side_title.position = Vector2(22.0, 18.0)
	side_title.size = Vector2(panel_width - (154.0 if mobile else 132.0), 52.0 if mobile else 34.0)
	side_title.add_theme_font_size_override("font_size", 22 if mobile else 24)
	side_close_button.position = Vector2(panel_width - (126.0 if mobile else 92.0), 14.0)
	side_close_button.size = Vector2(104.0 if mobile else 82.0, touch_height)
	if side_scroll != null:
		var scroll_y := 64.0 if mobile and not portrait else 76.0 if mobile else 70.0
		var scroll_bottom := 0.0 if mobile and not portrait else 84.0 if mobile else 92.0
		side_scroll.position = Vector2(24.0 if mobile else 28.0, scroll_y)
		side_scroll.size = Vector2(panel_width - (48.0 if mobile else 56.0), panel_height - scroll_y - scroll_bottom)
	if side_content != null:
		side_content.custom_minimum_size = Vector2(max(240.0, panel_width - (48.0 if mobile else 56.0)), 0.0)
	if volume_label != null:
		volume_label.visible = not (mobile and not portrait)
	if volume_slider != null:
		volume_slider.visible = not (mobile and not portrait)
	if achievements_grid != null and is_instance_valid(achievements_grid):
		var grid_width: float = max(240.0, side_content.custom_minimum_size.x if side_content != null else panel_width - 56.0)
		var columns: int = 4 if grid_width >= 430.0 else 3 if grid_width >= 310.0 else 2
		achievements_grid.columns = columns
		var gap: float = 8.0
		var badge_width: float = max(86.0, floor((grid_width - gap * float(columns - 1)) / float(columns)))
		var badge_height: float = 72.0 if mobile else 64.0
		for child in achievements_grid.get_children():
			if child is Button:
				(child as Button).custom_minimum_size = Vector2(badge_width, badge_height)
	if force_joystick_check != null:
		force_joystick_check.visible = MOBILE_TUNING.has_confirmed_touch() and not (mobile and not portrait)

	version_label.anchor_left = 1.0
	version_label.anchor_right = 1.0
	version_label.anchor_top = 1.0
	version_label.anchor_bottom = 1.0
	version_label.offset_left = -320.0
	version_label.offset_right = -margin
	version_label.offset_top = -32.0
	version_label.offset_bottom = -10.0
	if mobile and portrait:
		# 直式抬離瀏覽器工具列遮蓋帶
		var version_reserve := maxf(viewport_size.y * 0.085, 64.0)
		version_label.offset_top = -version_reserve - 22.0
		version_label.offset_bottom = -version_reserve
	seed_input.add_theme_font_size_override("font_size", 14)
	seed_start_button.add_theme_font_size_override("font_size", 14)
	MOBILE_TUNING.apply_control_tree(root, viewport_size)
	if mobile and not portrait:
		menu_box.add_theme_constant_override("separation", int(button_gap))
		for child in menu_box.get_children():
			if child is Button:
				(child as Button).custom_minimum_size = Vector2(menu_width, button_height)
		seed_input.custom_minimum_size.y = seed_height
		seed_start_button.custom_minimum_size.y = seed_height
	_apply_accessibility_palette()
	# Web CanvasLayer 已換算為 CSS 像素；在此鎖視覺字級，避免通用可讀性倍率二次放大。
	if mobile and OS.has_feature("web"):
		logo_label.add_theme_font_size_override("font_size", 36 if portrait else 22)
		logo_glow_label.add_theme_font_size_override("font_size", 36 if portrait else 22)
		for child in menu_box.get_children():
			if child is Button:
				(child as Button).add_theme_font_size_override("font_size", int(round(float(25 if portrait else 18) * ui_multiplier)))
		seed_input.add_theme_font_size_override("font_size", int(round(float(18 if portrait else 16) * ui_multiplier)))
		seed_start_button.add_theme_font_size_override("font_size", int(round(float(18 if portrait else 16) * ui_multiplier)))
	_apply_accessibility_palette()
	_publish_reachability_probe(viewport_size)
	call_deferred("_publish_reachability_probe", viewport_size)


func _publish_reachability_probe(viewport_size: Vector2) -> void:
	WEB_REACHABILITY_PROBE.publish("main_menu", viewport_size, {
		"start": start_button,
		"guide": guide_button,
		"meta": meta_button,
		"achievements": achievements_button,
		"settings": settings_button,
		"seed_input": seed_input,
		"seed_start": seed_start_button,
		"side_panel": side_panel,
		"side_close": side_close_button
	}, {
		"side_panel_visible": side_panel != null and side_panel.visible,
		"confirmed_touch": MOBILE_TUNING.has_confirmed_touch()
	})


func _ui_scale_multiplier() -> float:
	if PlayerSettings != null and PlayerSettings.has_method("get_ui_scale_multiplier"):
		return float(PlayerSettings.get_ui_scale_multiplier())
	return 1.0


func _apply_accessibility_palette() -> void:
	var high_contrast := PlayerSettings != null and bool(PlayerSettings.get("high_contrast_enabled"))
	if side_panel != null:
		side_panel.modulate = Color(1.0, 1.0, 1.0, 0.98 if high_contrast else 0.88)
	var labels: Array = [logo_label, logo_glow_label, side_title, version_label, ui_scale_label]
	for control in labels:
		var label := control as Label
		if label == null:
			continue
		_apply_label_contrast(label, high_contrast)
	if side_content != null:
		_apply_label_contrast_recursive(side_content, high_contrast)


func _apply_label_contrast_recursive(node: Node, high_contrast: bool) -> void:
	for child in node.get_children():
		if child is Label:
			_apply_label_contrast(child as Label, high_contrast)
		_apply_label_contrast_recursive(child, high_contrast)


func _apply_label_contrast(label: Label, high_contrast: bool) -> void:
	if high_contrast:
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
	else:
		label.remove_theme_constant_override("outline_size")


func _build_version_text() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", "dev"))
	var build_date := str(ProjectSettings.get_setting("application/config/build_date", "local"))
	return "v%s  %s" % [version, build_date]
