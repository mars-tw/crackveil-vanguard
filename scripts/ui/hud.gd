extends CanvasLayer

const VIRTUAL_JOYSTICK_SCENE := preload("res://scripts/ui/virtual_joystick.gd")
const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")

var root: Control
var hud_panel: Panel
var score_panel: Panel
var hp_icon: TextureRect
var xp_icon: TextureRect
var gold_icon: TextureRect
var hp_label: Label
var level_label: Label
var xp_bar: ProgressBar
var theme_label: Label
var time_label: Label
var score_label: Label
var pause_button: Button
var version_label: Label
var audio_prompt_button: Button
var active_ability_button: Button
var active_ability_cooldown: TextureProgressBar
var active_ability_label: Label
var toast_panel: Panel
var toast_label: Label
var level_flash_rect: ColorRect
var combo_pulse_rect: TextureRect
var pause_overlay: Panel
var pause_scroll: ScrollContainer
var pause_content: VBoxContainer
var pause_volume_label: Label
var pause_volume_slider: HSlider
var pause_mute_check: CheckBox
var pause_damage_numbers_check: CheckBox
var pause_screen_shake_check: CheckBox
var pause_seed_button: Button
var pause_reset_meta_button: Button
var pause_guide_button: Button
var pause_achievements_label: RichTextLabel
var pause_resume_button: Button
var virtual_joystick: Control
var force_touch_controls_visible: bool = false
var syncing_audio_controls: bool = false
var syncing_settings_controls: bool = false
var toast_token: int = 0
var toast_queue: Array[String] = []
var toast_showing: bool = false
var reset_meta_confirm_pending: bool = false
var level_flash_tween: Tween = null
var combo_pulse_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_build_ui()
	if not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)

	if not GameManager.stats_changed.is_connected(_on_stats_changed):
		GameManager.stats_changed.connect(_on_stats_changed)
	if not GameManager.pause_changed.is_connected(_on_pause_changed):
		GameManager.pause_changed.connect(_on_pause_changed)
	if GameManager.has_signal("toast_requested") and not GameManager.toast_requested.is_connected(_on_toast_requested):
		GameManager.toast_requested.connect(_on_toast_requested)
	if GameManager.has_signal("level_flash_requested") and not GameManager.level_flash_requested.is_connected(_on_level_flash_requested):
		GameManager.level_flash_requested.connect(_on_level_flash_requested)
	if GameManager.has_signal("combo_pulse_requested") and not GameManager.combo_pulse_requested.is_connected(_on_combo_pulse_requested):
		GameManager.combo_pulse_requested.connect(_on_combo_pulse_requested)
	if AudioManager != null and AudioManager.has_signal("settings_changed") and not AudioManager.settings_changed.is_connected(_sync_audio_controls):
		AudioManager.settings_changed.connect(_sync_audio_controls)
	if AudioManager != null and AudioManager.has_signal("audio_unlocked") and not AudioManager.audio_unlocked.is_connected(_refresh_audio_prompt):
		AudioManager.audio_unlocked.connect(_refresh_audio_prompt)
	if PlayerSettings != null and PlayerSettings.has_signal("settings_changed") and not PlayerSettings.settings_changed.is_connected(_sync_settings_controls):
		PlayerSettings.settings_changed.connect(_sync_settings_controls)
	if AchievementProgress != null and AchievementProgress.has_signal("achievement_unlocked") and not AchievementProgress.achievement_unlocked.is_connected(_on_achievement_unlocked):
		AchievementProgress.achievement_unlocked.connect(_on_achievement_unlocked)

	_on_stats_changed(GameManager.get_stats())
	_refresh_audio_prompt()
	_sync_settings_controls()
	_refresh_achievement_list()
	_drain_pending_toasts()


func _process(_delta: float) -> void:
	_refresh_active_ability_button()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			GameManager.toggle_pause()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	root = Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	hud_panel = Panel.new()
	hud_panel.name = "HUDPanel"
	hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_panel)

	score_panel = Panel.new()
	score_panel.name = "ScorePanel"
	score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(score_panel)

	hp_icon = _make_hud_icon("HealthIcon", ART_RESOURCES.get_health_icon())
	root.add_child(hp_icon)

	xp_icon = _make_hud_icon("XPIcon", ART_RESOURCES.get_xp_icon())
	root.add_child(xp_icon)

	gold_icon = _make_hud_icon("GoldIcon", ART_RESOURCES.get_gold_icon())
	root.add_child(gold_icon)

	hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.position = Vector2(50.0, 12.0)
	hp_label.add_theme_font_size_override("font_size", 20)
	root.add_child(hp_label)

	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.position = Vector2(50.0, 42.0)
	level_label.add_theme_font_size_override("font_size", 16)
	root.add_child(level_label)

	xp_bar = ProgressBar.new()
	xp_bar.name = "XPBar"
	xp_bar.position = Vector2(16.0, 68.0)
	xp_bar.size = Vector2(260.0, 14.0)
	xp_bar.min_value = 0.0
	xp_bar.max_value = 1.0
	xp_bar.show_percentage = false
	root.add_child(xp_bar)

	theme_label = Label.new()
	theme_label.name = "ThemeLabel"
	theme_label.position = Vector2(50.0, 84.0)
	theme_label.add_theme_font_size_override("font_size", 13)
	theme_label.modulate = Color(0.74, 0.92, 0.86, 0.9)
	root.add_child(theme_label)

	time_label = Label.new()
	time_label.name = "TimeLabel"
	time_label.anchor_left = 0.5
	time_label.anchor_right = 0.5
	time_label.offset_left = -78.0
	time_label.offset_right = 78.0
	time_label.offset_top = 12.0
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 24)
	root.add_child(time_label)

	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.anchor_left = 1.0
	score_label.anchor_right = 1.0
	score_label.offset_left = -320.0
	score_label.offset_right = -86.0
	score_label.offset_top = 14.0
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_size_override("font_size", 18)
	root.add_child(score_label)

	pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "暫停"
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.offset_left = -88.0
	pause_button.offset_right = -16.0
	pause_button.offset_top = 10.0
	pause_button.offset_bottom = 50.0
	pause_button.pressed.connect(_on_pause_button_pressed)
	root.add_child(pause_button)

	version_label = Label.new()
	version_label.name = "VersionLabel"
	version_label.text = _build_version_text()
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.add_theme_font_size_override("font_size", 12)
	root.add_child(version_label)

	audio_prompt_button = Button.new()
	audio_prompt_button.name = "AudioPromptButton"
	audio_prompt_button.text = "點擊開始"
	audio_prompt_button.pressed.connect(_on_audio_prompt_pressed)
	root.add_child(audio_prompt_button)

	active_ability_button = Button.new()
	active_ability_button.name = "ActiveAbilityButton"
	active_ability_button.text = "裂"
	active_ability_button.tooltip_text = "裂隙脈衝"
	active_ability_button.pressed.connect(_on_active_ability_pressed)
	root.add_child(active_ability_button)

	active_ability_cooldown = TextureProgressBar.new()
	active_ability_cooldown.name = "ActiveAbilityCooldown"
	active_ability_cooldown.min_value = 0.0
	active_ability_cooldown.max_value = 1.0
	active_ability_cooldown.value = 0.0
	active_ability_cooldown.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	active_ability_cooldown.texture_progress = ART_RESOURCES.get_radial_glow()
	active_ability_cooldown.tint_progress = Color(0.26, 0.88, 1.0, 0.48)
	active_ability_cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(active_ability_cooldown)

	active_ability_label = Label.new()
	active_ability_label.name = "ActiveAbilityLabel"
	active_ability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_ability_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	active_ability_label.add_theme_font_size_override("font_size", 16)
	active_ability_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(active_ability_label)

	toast_panel = Panel.new()
	toast_panel.name = "ToastPanel"
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_panel)

	toast_label = Label.new()
	toast_label.name = "ToastLabel"
	toast_label.anchor_left = 0.0
	toast_label.anchor_right = 1.0
	toast_label.anchor_top = 0.0
	toast_label.anchor_bottom = 1.0
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 18)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_child(toast_label)

	level_flash_rect = ColorRect.new()
	level_flash_rect.name = "LevelFlash"
	level_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	level_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(level_flash_rect)

	combo_pulse_rect = TextureRect.new()
	combo_pulse_rect.name = "ComboPulse"
	combo_pulse_rect.texture = ART_RESOURCES.get_radial_glow()
	combo_pulse_rect.material = ART_RESOURCES.get_additive_material()
	combo_pulse_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	combo_pulse_rect.stretch_mode = TextureRect.STRETCH_SCALE
	combo_pulse_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_pulse_rect.visible = false
	root.add_child(combo_pulse_rect)

	_build_virtual_joystick()
	_build_pause_overlay()
	_apply_responsive_layout()


func _build_pause_overlay() -> void:
	pause_overlay = Panel.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.visible = false
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.anchor_left = 0.5
	pause_overlay.anchor_right = 0.5
	pause_overlay.anchor_top = 0.5
	pause_overlay.anchor_bottom = 0.5
	pause_overlay.offset_left = -140.0
	pause_overlay.offset_right = 140.0
	pause_overlay.offset_top = -82.0
	pause_overlay.offset_bottom = 82.0
	root.add_child(pause_overlay)

	var title := Label.new()
	title.text = "暫停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.custom_minimum_size = Vector2(0.0, 38.0)

	pause_scroll = ScrollContainer.new()
	pause_scroll.name = "PauseScroll"
	pause_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pause_scroll.anchor_left = 0.0
	pause_scroll.anchor_right = 1.0
	pause_scroll.anchor_top = 0.0
	pause_scroll.anchor_bottom = 1.0
	pause_overlay.add_child(pause_scroll)

	pause_content = VBoxContainer.new()
	pause_content.name = "PauseContent"
	pause_content.add_theme_constant_override("separation", 8)
	pause_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_scroll.add_child(pause_content)
	pause_content.add_child(title)

	pause_volume_label = Label.new()
	pause_volume_label.text = "音量"
	pause_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_content.add_child(pause_volume_label)

	pause_volume_slider = HSlider.new()
	pause_volume_slider.min_value = 0.0
	pause_volume_slider.max_value = 1.0
	pause_volume_slider.step = 0.05
	pause_volume_slider.custom_minimum_size = Vector2(240.0, 28.0)
	pause_volume_slider.value_changed.connect(_on_volume_slider_changed)
	pause_content.add_child(pause_volume_slider)

	pause_mute_check = CheckBox.new()
	pause_mute_check.text = "靜音"
	pause_mute_check.toggled.connect(_on_mute_toggled)
	pause_content.add_child(pause_mute_check)

	pause_damage_numbers_check = CheckBox.new()
	pause_damage_numbers_check.text = "顯示傷害數字"
	pause_damage_numbers_check.toggled.connect(_on_damage_numbers_toggled)
	pause_content.add_child(pause_damage_numbers_check)

	pause_screen_shake_check = CheckBox.new()
	pause_screen_shake_check.text = "螢幕震動"
	pause_screen_shake_check.toggled.connect(_on_screen_shake_toggled)
	pause_content.add_child(pause_screen_shake_check)

	pause_seed_button = Button.new()
	pause_seed_button.text = "複製本局種子"
	pause_seed_button.pressed.connect(_on_copy_seed_pressed)
	pause_content.add_child(pause_seed_button)

	pause_guide_button = Button.new()
	pause_guide_button.text = "重看教學"
	pause_guide_button.pressed.connect(_on_rewatch_guide_pressed)
	pause_content.add_child(pause_guide_button)

	pause_reset_meta_button = Button.new()
	pause_reset_meta_button.text = "重置殘響"
	pause_reset_meta_button.pressed.connect(_on_reset_meta_pressed)
	pause_content.add_child(pause_reset_meta_button)

	var achievement_title := Label.new()
	achievement_title.text = "成就"
	achievement_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	achievement_title.add_theme_font_size_override("font_size", 18)
	pause_content.add_child(achievement_title)

	pause_achievements_label = RichTextLabel.new()
	pause_achievements_label.bbcode_enabled = true
	pause_achievements_label.fit_content = true
	pause_achievements_label.scroll_active = false
	pause_achievements_label.custom_minimum_size = Vector2(260.0, 228.0)
	pause_achievements_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_content.add_child(pause_achievements_label)

	pause_resume_button = Button.new()
	pause_resume_button.text = "繼續"
	pause_resume_button.custom_minimum_size = Vector2(160.0, 42.0)
	pause_resume_button.pressed.connect(_on_resume_button_pressed)
	pause_content.add_child(pause_resume_button)
	_sync_audio_controls()
	_sync_settings_controls()
	_refresh_achievement_list()


func _build_virtual_joystick() -> void:
	virtual_joystick = VIRTUAL_JOYSTICK_SCENE.new()
	virtual_joystick.name = "VirtualJoystick"
	virtual_joystick.connect("direction_changed", Callable(self, "_on_virtual_joystick_changed"))
	root.add_child(virtual_joystick)


func _make_hud_icon(icon_name: String, texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = icon_name
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2(28.0, 28.0)
	return icon


func _apply_responsive_layout() -> void:
	if root == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var portrait := viewport_size.y > viewport_size.x
	var margin := 14.0

	if hud_panel != null:
		hud_panel.position = Vector2(8.0, 8.0)
		hud_panel.size = Vector2(min(viewport_size.x * (0.72 if portrait else 0.36), 340.0), 108.0)
	if score_panel != null:
		score_panel.anchor_left = 1.0
		score_panel.anchor_right = 1.0
		score_panel.position = Vector2.ZERO
		score_panel.offset_left = -332.0 if not portrait else -258.0
		score_panel.offset_right = -margin
		score_panel.offset_top = 8.0 if not portrait else 48.0
		score_panel.offset_bottom = score_panel.offset_top + 46.0
	if hp_icon != null:
		hp_icon.position = Vector2(margin + 2.0, 14.0)
		hp_icon.size = Vector2(26.0, 26.0)
	if xp_icon != null:
		xp_icon.position = Vector2(margin + 2.0, 44.0)
		xp_icon.size = Vector2(24.0, 24.0)
	if gold_icon != null:
		gold_icon.anchor_left = 1.0
		gold_icon.anchor_right = 1.0
		gold_icon.offset_left = -318.0 if not portrait else -246.0
		gold_icon.offset_right = gold_icon.offset_left + 26.0
		gold_icon.offset_top = 18.0 if not portrait else 58.0
		gold_icon.offset_bottom = gold_icon.offset_top + 26.0

	hp_label.position = Vector2(margin + 36.0, 10.0)
	hp_label.add_theme_font_size_override("font_size", 18 if portrait else 20)
	level_label.position = Vector2(margin + 36.0, 38.0)
	level_label.add_theme_font_size_override("font_size", 14 if portrait else 16)
	xp_bar.position = Vector2(margin + 36.0, 66.0)
	xp_bar.size = Vector2(min(viewport_size.x * (0.5 if portrait else 0.27), 260.0), 14.0)
	if theme_label != null:
		theme_label.position = Vector2(margin + 36.0, 82.0)
		theme_label.size = Vector2(min(viewport_size.x * (0.55 if portrait else 0.28), 276.0), 22.0)
		theme_label.add_theme_font_size_override("font_size", 12 if portrait else 13)

	time_label.anchor_left = 0.5
	time_label.anchor_right = 0.5
	time_label.offset_left = -78.0
	time_label.offset_right = 78.0
	time_label.offset_top = 10.0
	time_label.offset_bottom = 42.0
	time_label.add_theme_font_size_override("font_size", 22 if portrait else 24)

	score_label.anchor_left = 1.0
	score_label.anchor_right = 1.0
	score_label.offset_left = -320.0 if not portrait else -244.0
	score_label.offset_right = -96.0 if not portrait else -14.0
	score_label.offset_top = 16.0 if not portrait else 52.0
	score_label.offset_bottom = score_label.offset_top + 30.0
	score_label.add_theme_font_size_override("font_size", 16 if portrait else 18)

	version_label.anchor_left = 1.0
	version_label.anchor_right = 1.0
	version_label.anchor_top = 1.0
	version_label.anchor_bottom = 1.0
	version_label.offset_left = -290.0
	version_label.offset_right = -margin
	version_label.offset_top = -30.0
	version_label.offset_bottom = -8.0
	version_label.add_theme_font_size_override("font_size", 11 if portrait else 12)

	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.offset_left = -88.0
	pause_button.offset_right = -margin
	pause_button.offset_top = 10.0
	pause_button.offset_bottom = 50.0

	if pause_overlay != null:
		var overlay_width: float = min(viewport_size.x - 40.0, 380.0)
		var overlay_height: float = min(viewport_size.y - 44.0, 610.0)
		pause_overlay.anchor_left = 0.5
		pause_overlay.anchor_right = 0.5
		pause_overlay.anchor_top = 0.5
		pause_overlay.anchor_bottom = 0.5
		pause_overlay.offset_left = -overlay_width * 0.5
		pause_overlay.offset_right = overlay_width * 0.5
		pause_overlay.offset_top = -overlay_height * 0.5
		pause_overlay.offset_bottom = overlay_height * 0.5

	if pause_scroll != null:
		pause_scroll.offset_left = 20.0
		pause_scroll.offset_right = -20.0
		pause_scroll.offset_top = 16.0
		pause_scroll.offset_bottom = -16.0

	if pause_content != null:
		pause_content.custom_minimum_size = Vector2(max(260.0, min(viewport_size.x - 80.0, 340.0)), 0.0)

	if pause_volume_label != null:
		pause_volume_label.anchor_left = 0.0
		pause_volume_label.anchor_right = 1.0
		pause_volume_label.offset_top = 66.0
		pause_volume_label.offset_bottom = 92.0
		pause_volume_label.add_theme_font_size_override("font_size", 15)

	if pause_volume_slider != null:
		pause_volume_slider.anchor_left = 0.5
		pause_volume_slider.anchor_right = 0.5
		pause_volume_slider.offset_left = -112.0
		pause_volume_slider.offset_right = 112.0
		pause_volume_slider.offset_top = 100.0
		pause_volume_slider.offset_bottom = 132.0

	if pause_mute_check != null:
		pause_mute_check.anchor_left = 0.5
		pause_mute_check.anchor_right = 0.5
		pause_mute_check.offset_left = -58.0
		pause_mute_check.offset_right = 58.0
		pause_mute_check.offset_top = 140.0
		pause_mute_check.offset_bottom = 178.0

	if audio_prompt_button != null:
		audio_prompt_button.anchor_left = 0.5
		audio_prompt_button.anchor_right = 0.5
		audio_prompt_button.anchor_top = 1.0
		audio_prompt_button.anchor_bottom = 1.0
		audio_prompt_button.offset_left = -78.0
		audio_prompt_button.offset_right = 78.0
		audio_prompt_button.offset_top = -74.0
		audio_prompt_button.offset_bottom = -34.0

	if active_ability_button != null:
		var ability_size := 68.0 if portrait else 62.0
		var bottom_margin := 34.0 if portrait else 28.0
		active_ability_button.anchor_left = 0.0
		active_ability_button.anchor_right = 0.0
		active_ability_button.anchor_top = 0.0
		active_ability_button.anchor_bottom = 0.0
		active_ability_button.position = Vector2(viewport_size.x - ability_size - 24.0, viewport_size.y - ability_size - bottom_margin)
		active_ability_button.size = Vector2(ability_size, ability_size)
		active_ability_button.custom_minimum_size = Vector2(ability_size, ability_size)
		active_ability_button.add_theme_font_size_override("font_size", 22 if portrait else 20)
	if active_ability_cooldown != null and active_ability_button != null:
		active_ability_cooldown.position = active_ability_button.position
		active_ability_cooldown.size = active_ability_button.size
	if active_ability_label != null and active_ability_button != null:
		active_ability_label.position = active_ability_button.position
		active_ability_label.size = active_ability_button.size

	if toast_panel != null:
		var toast_width: float = min(viewport_size.x - 32.0, 520.0)
		toast_panel.anchor_left = 0.5
		toast_panel.anchor_right = 0.5
		toast_panel.anchor_top = 0.0
		toast_panel.anchor_bottom = 0.0
		toast_panel.offset_left = -toast_width * 0.5
		toast_panel.offset_right = toast_width * 0.5
		toast_panel.offset_top = 56.0 if not portrait else 94.0
		toast_panel.offset_bottom = toast_panel.offset_top + 48.0

	if combo_pulse_rect != null and not combo_pulse_rect.visible:
		var pulse_size: float = min(viewport_size.x, viewport_size.y) * 0.28
		combo_pulse_rect.position = viewport_size * 0.5 - Vector2.ONE * pulse_size * 0.5
		combo_pulse_rect.size = Vector2.ONE * pulse_size

	if virtual_joystick != null:
		var joystick_size := 164.0 if portrait else 150.0
		virtual_joystick.size = Vector2(joystick_size, joystick_size)
		virtual_joystick.position = Vector2(22.0, viewport_size.y - joystick_size - 24.0)
		virtual_joystick.visible = _should_show_touch_controls()


func _should_show_touch_controls() -> bool:
	if force_touch_controls_visible:
		return true
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	if DisplayServer.has_method("is_touchscreen_available"):
		return DisplayServer.call("is_touchscreen_available") == true
	return false


func set_touch_controls_forced_visible(value: bool) -> void:
	force_touch_controls_visible = value
	_apply_responsive_layout()


func _on_stats_changed(stats: Dictionary) -> void:
	var hp := int(ceil(float(stats.get("hp", 0.0))))
	var max_hp := int(ceil(float(stats.get("max_hp", 0.0))))
	var current_level := int(stats.get("level", 1))
	var xp := int(stats.get("xp", 0))
	var xp_required: int = max(1, int(stats.get("xp_required", 1)))

	hp_label.text = "HP %d/%d" % [hp, max_hp]
	level_label.text = "等級 %d   經驗 %d/%d" % [current_level, xp, xp_required]
	xp_bar.value = clamp(float(xp) / float(xp_required), 0.0, 1.0)
	var theme_name := str(stats.get("run_theme_name", ""))
	if theme_label != null:
		theme_label.text = "地圖：%s" % theme_name if theme_name != "" else ""
		theme_label.visible = theme_name != ""
	time_label.text = GameManager.format_time(float(stats.get("elapsed_time", 0.0)))
	score_label.text = "擊殺 %d   金幣 %d   殘響 %d" % [
		int(stats.get("kills", 0)),
		int(stats.get("gold", 0)),
		int(stats.get("echo_shards", 0))
	]
	_on_pause_changed(bool(stats.get("manual_pause_visible", bool(stats.get("manual_paused", false)))))


func _on_pause_changed(is_paused: bool) -> void:
	pause_overlay.visible = is_paused
	pause_button.text = "繼續" if is_paused else "暫停"
	if is_paused:
		_sync_audio_controls()
		_sync_settings_controls()
		_refresh_achievement_list()
		reset_meta_confirm_pending = false
		if pause_reset_meta_button != null:
			pause_reset_meta_button.text = "重置殘響"


func _on_pause_button_pressed() -> void:
	GameManager.toggle_pause()


func _on_resume_button_pressed() -> void:
	GameManager.set_manual_pause(false)


func _on_virtual_joystick_changed(direction: Vector2) -> void:
	GameManager.set_touch_move_vector(direction)


func _on_audio_prompt_pressed() -> void:
	if AudioManager != null and AudioManager.has_method("unlock_audio"):
		AudioManager.unlock_audio()
	_refresh_audio_prompt()


func _on_active_ability_pressed() -> void:
	var active_player := GameManager.player
	if active_player != null and is_instance_valid(active_player) and active_player.has_method("try_cast_active_ability"):
		active_player.try_cast_active_ability()


func _refresh_active_ability_button() -> void:
	if active_ability_button == null:
		return
	var active_player := GameManager.player
	var visible_for_player := active_player != null and is_instance_valid(active_player) and active_player.has_method("get_active_ability_cooldown_remaining")
	active_ability_button.visible = visible_for_player
	if active_ability_cooldown != null:
		active_ability_cooldown.visible = visible_for_player
	if active_ability_label != null:
		active_ability_label.visible = visible_for_player
	if not visible_for_player:
		return
	var remaining: float = float(active_player.get_active_ability_cooldown_remaining())
	var duration: float = max(0.001, float(active_player.get_active_ability_cooldown_duration()))
	var ratio: float = clamp(remaining / duration, 0.0, 1.0)
	active_ability_button.disabled = remaining > 0.01 or get_tree().paused or not GameManager.game_running
	active_ability_button.text = "裂"
	if active_ability_cooldown != null:
		active_ability_cooldown.value = ratio
		active_ability_cooldown.modulate = Color(1.0, 1.0, 1.0, 0.86 if ratio > 0.0 else 0.0)
	if active_ability_label != null:
		active_ability_label.text = "%.1f" % remaining if remaining > 0.05 else ""


func _on_level_flash_requested() -> void:
	if level_flash_rect == null:
		return
	if level_flash_tween != null and level_flash_tween.is_valid():
		level_flash_tween.kill()
	level_flash_rect.color = Color(1.0, 1.0, 1.0, 0.22)
	level_flash_tween = create_tween()
	level_flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	level_flash_tween.tween_property(level_flash_rect, "color", Color(1.0, 1.0, 1.0, 0.0), 0.24)


func _on_combo_pulse_requested(combo_count: int) -> void:
	if combo_pulse_rect == null:
		return
	if combo_pulse_tween != null and combo_pulse_tween.is_valid():
		combo_pulse_tween.kill()
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var start_size: float = min(viewport_size.x, viewport_size.y) * 0.24
	var end_size: float = max(viewport_size.x, viewport_size.y) * 1.65
	var center := viewport_size * 0.5
	var pulse_color := Color(0.55, 1.0, 0.86, 0.44)
	if combo_count >= 30:
		pulse_color = Color(1.0, 0.78, 0.36, 0.46)
	combo_pulse_rect.visible = true
	combo_pulse_rect.modulate = pulse_color
	combo_pulse_rect.position = center - Vector2.ONE * start_size * 0.5
	combo_pulse_rect.size = Vector2.ONE * start_size
	combo_pulse_tween = create_tween()
	combo_pulse_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	combo_pulse_tween.set_parallel(true)
	combo_pulse_tween.tween_property(combo_pulse_rect, "position", center - Vector2.ONE * end_size * 0.5, 0.34)
	combo_pulse_tween.tween_property(combo_pulse_rect, "size", Vector2.ONE * end_size, 0.34)
	combo_pulse_tween.tween_property(combo_pulse_rect, "modulate", Color(pulse_color.r, pulse_color.g, pulse_color.b, 0.0), 0.34)
	combo_pulse_tween.chain().tween_callback(func() -> void:
		if combo_pulse_rect != null:
			combo_pulse_rect.visible = false
	)


func _refresh_audio_prompt() -> void:
	if audio_prompt_button == null:
		return
	audio_prompt_button.visible = OS.has_feature("web") and AudioManager != null and not AudioManager.is_audio_unlocked()


func _sync_audio_controls() -> void:
	if pause_volume_slider == null or pause_mute_check == null or AudioManager == null:
		return
	syncing_audio_controls = true
	pause_volume_slider.value = float(AudioManager.get("master_volume"))
	pause_mute_check.button_pressed = bool(AudioManager.get("muted"))
	syncing_audio_controls = false


func _on_volume_slider_changed(value: float) -> void:
	if syncing_audio_controls or AudioManager == null:
		return
	AudioManager.set_master_volume(float(value))


func _on_mute_toggled(value: bool) -> void:
	if syncing_audio_controls or AudioManager == null:
		return
	AudioManager.set_muted(value)


func _sync_settings_controls() -> void:
	if PlayerSettings == null:
		return
	syncing_settings_controls = true
	if pause_damage_numbers_check != null:
		pause_damage_numbers_check.button_pressed = bool(PlayerSettings.get("damage_numbers_enabled"))
	if pause_screen_shake_check != null:
		pause_screen_shake_check.button_pressed = bool(PlayerSettings.get("screen_shake_enabled"))
	syncing_settings_controls = false


func _on_damage_numbers_toggled(value: bool) -> void:
	if syncing_settings_controls or PlayerSettings == null:
		return
	PlayerSettings.set_damage_numbers_enabled(value)


func _on_screen_shake_toggled(value: bool) -> void:
	if syncing_settings_controls or PlayerSettings == null:
		return
	PlayerSettings.set_screen_shake_enabled(value)


func _on_copy_seed_pressed() -> void:
	GameManager.copy_current_run_seed_to_clipboard()


func _on_rewatch_guide_pressed() -> void:
	GameManager.request_guide_replay()


func _on_reset_meta_pressed() -> void:
	if MetaProgress == null or not MetaProgress.has_method("reset_progress"):
		return
	if not reset_meta_confirm_pending:
		reset_meta_confirm_pending = true
		if pause_reset_meta_button != null:
			pause_reset_meta_button.text = "再次按下確認重置"
		GameManager.show_toast("再次按下以重置殘響進度。")
		return
	reset_meta_confirm_pending = false
	MetaProgress.reset_progress()
	if GameManager.has_method("apply_current_meta_progress_to_squad"):
		GameManager.apply_current_meta_progress_to_squad()
	if pause_reset_meta_button != null:
		pause_reset_meta_button.text = "重置殘響"
	GameManager.show_toast("殘響進度已重置。")
	GameManager.emit_stats()


func _on_achievement_unlocked(_achievement: Dictionary) -> void:
	_refresh_achievement_list()


func _refresh_achievement_list() -> void:
	if pause_achievements_label == null or AchievementProgress == null or not AchievementProgress.has_method("get_display_rows"):
		return
	var lines: Array[String] = []
	for row in AchievementProgress.get_display_rows():
		var unlocked := bool(row.get("unlocked", false))
		var color := "#f1f5f0" if unlocked else "#777f86"
		var mark := "已" if unlocked else "未"
		lines.append("[color=%s]%s %s[/color]" % [color, mark, str(row.get("name", ""))])
	pause_achievements_label.text = "\n".join(lines)


func _drain_pending_toasts() -> void:
	if GameManager == null or not GameManager.has_method("consume_pending_toasts"):
		return
	var messages: Array[String] = GameManager.consume_pending_toasts()
	for message in messages:
		_on_toast_requested(message)
		await get_tree().create_timer(1.6, true).timeout


func _on_toast_requested(message: String) -> void:
	if toast_panel == null or toast_label == null:
		return
	if message == "":
		return
	toast_queue.append(message)
	if not toast_showing:
		_play_toast_queue()


func _play_toast_queue() -> void:
	toast_showing = true
	while not toast_queue.is_empty():
		toast_token += 1
		toast_label.text = toast_queue.pop_front()
		toast_panel.visible = true
		await get_tree().create_timer(1.5, true).timeout
	if toast_panel != null:
		toast_panel.visible = false
	toast_showing = false


func _build_version_text() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", "dev"))
	var build_date := str(ProjectSettings.get_setting("application/config/build_date", "local"))
	return "v%s  %s" % [version, build_date]
