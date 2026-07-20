extends CanvasLayer

const VIRTUAL_JOYSTICK_SCENE := preload("res://scripts/ui/virtual_joystick.gd")
const WEB_REACHABILITY_PROBE := preload("res://scripts/services/web_reachability_probe.gd")
const COOLDOWN_RING_SCRIPT := preload("res://scripts/ui/cooldown_ring.gd")
const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")

var root: Control
var hud_panel: Panel
var score_panel: Panel
var hp_icon: TextureRect
var xp_icon: TextureRect
var gold_icon: TextureRect
var hp_label: Label
var level_label: Label
var xp_readout_label: Label
var xp_bar: ProgressBar
var theme_label: Label
var time_label: Label
var score_label: Label
var pause_button: Button
var quick_controls: Control
var quick_mute_button: Button
var quick_screen_shake_button: Button
var quick_joystick_size_button: Button
var version_label: Label
var audio_prompt_button: Button
var active_ability_button: Button
var active_ability_cooldown: TextureProgressBar
var active_ability_cooldown_ring: Control
var active_ability_label: Label
var toast_panel: Panel
var toast_label: Label
var level_flash_rect: ColorRect
var captain_hit_flash_rect: TextureRect
var combo_pulse_rect: TextureRect
var milestone_label: Label
var combo_break_label: Label
var boss_intro_rect: ColorRect
var boss_intro_label: Label
var pause_overlay: Panel
var pause_scroll: ScrollContainer
var pause_content: VBoxContainer
var pause_title_label: Label
var pause_tab_bar: HBoxContainer
var pause_settings_tab_button: Button
var pause_achievements_tab_button: Button
var pause_run_tab_button: Button
var pause_settings_page: VBoxContainer
var pause_achievements_page: VBoxContainer
var pause_run_page: VBoxContainer
var pause_volume_label: Label
var pause_volume_slider: HSlider
var pause_mute_check: CheckBox
var pause_damage_numbers_check: CheckBox
var pause_screen_shake_check: CheckBox
var pause_force_joystick_check: CheckBox
var pause_high_contrast_check: CheckBox
var pause_joystick_size_label: Label
var pause_joystick_size_slider: HSlider
var pause_ui_scale_label: Label
var pause_ui_scale_slider: HSlider
var pause_seed_button: Button
var pause_reset_meta_button: Button
var pause_guide_button: Button
var pause_run_stats_label: Label
var pause_achievements_label: RichTextLabel
var pause_achievements_grid: GridContainer
var pause_achievement_dialog: AcceptDialog
var pause_resume_button: Button
var virtual_joystick: Control
var pause_active_tab: String = "settings"
var force_touch_controls_visible: bool = false
var syncing_audio_controls: bool = false
var syncing_settings_controls: bool = false
var toast_token: int = 0
var toast_queue: Array[String] = []
var toast_showing: bool = false
var reset_meta_confirm_pending: bool = false
var level_flash_tween: Tween = null
var captain_hit_flash_tween: Tween = null
var combo_pulse_tween: Tween = null
var milestone_tween: Tween = null
var combo_break_tween: Tween = null
var boss_intro_tween: Tween = null
var screenshot_beauty_active: bool = false
var last_level_value: int = 1
var last_xp_value: int = 0
var last_xp_required_value: int = 1


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
	if GameManager.has_signal("captain_ability_hit_flash_requested") and not GameManager.captain_ability_hit_flash_requested.is_connected(_on_captain_ability_hit_flash_requested):
		GameManager.captain_ability_hit_flash_requested.connect(_on_captain_ability_hit_flash_requested)
	if GameManager.has_signal("combo_pulse_requested") and not GameManager.combo_pulse_requested.is_connected(_on_combo_pulse_requested):
		GameManager.combo_pulse_requested.connect(_on_combo_pulse_requested)
	if GameManager.has_signal("combo_milestone_requested") and not GameManager.combo_milestone_requested.is_connected(_on_combo_milestone_requested):
		GameManager.combo_milestone_requested.connect(_on_combo_milestone_requested)
	if GameManager.has_signal("combo_break_requested") and not GameManager.combo_break_requested.is_connected(_on_combo_break_requested):
		GameManager.combo_break_requested.connect(_on_combo_break_requested)
	if GameManager.has_signal("boss_intro_requested") and not GameManager.boss_intro_requested.is_connected(_on_boss_intro_requested):
		GameManager.boss_intro_requested.connect(_on_boss_intro_requested)
	if GameManager.has_signal("boss_phase_transition_requested") and not GameManager.boss_phase_transition_requested.is_connected(_on_boss_phase_transition_requested):
		GameManager.boss_phase_transition_requested.connect(_on_boss_phase_transition_requested)
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
	if OS.is_debug_build() and OS.get_cmdline_args().has("--screenshot-beauty"):
		set_screenshot_beauty_mode(true)


func _process(_delta: float) -> void:
	_refresh_active_ability_button()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12 and OS.is_debug_build():
			set_screenshot_beauty_mode(not screenshot_beauty_active)
			get_viewport().set_input_as_handled()
			return
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

	xp_readout_label = Label.new()
	xp_readout_label.name = "XPReadoutLabel"
	xp_readout_label.visible = false
	xp_readout_label.add_theme_font_size_override("font_size", 16)
	root.add_child(xp_readout_label)

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

	_build_quick_controls()

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
	active_ability_button.button_down.connect(_on_active_ability_button_down)
	active_ability_button.button_up.connect(_on_active_ability_button_up)
	_apply_active_ability_glass_style()
	root.add_child(active_ability_button)

	active_ability_cooldown_ring = COOLDOWN_RING_SCRIPT.new()
	active_ability_cooldown_ring.name = "ActiveAbilityCooldownRing"
	active_ability_cooldown_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(active_ability_cooldown_ring)

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

	captain_hit_flash_rect = TextureRect.new()
	captain_hit_flash_rect.name = "CaptainHitFlash"
	captain_hit_flash_rect.texture = ART_RESOURCES.get_vignette()
	captain_hit_flash_rect.material = ART_RESOURCES.get_additive_material()
	captain_hit_flash_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	captain_hit_flash_rect.stretch_mode = TextureRect.STRETCH_SCALE
	captain_hit_flash_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	captain_hit_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	captain_hit_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(captain_hit_flash_rect)

	combo_pulse_rect = TextureRect.new()
	combo_pulse_rect.name = "ComboPulse"
	combo_pulse_rect.texture = ART_RESOURCES.get_radial_glow()
	combo_pulse_rect.material = ART_RESOURCES.get_additive_material()
	combo_pulse_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	combo_pulse_rect.stretch_mode = TextureRect.STRETCH_SCALE
	combo_pulse_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_pulse_rect.visible = false
	root.add_child(combo_pulse_rect)

	boss_intro_rect = ColorRect.new()
	boss_intro_rect.name = "BossIntroDim"
	boss_intro_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	boss_intro_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_intro_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(boss_intro_rect)

	boss_intro_label = Label.new()
	boss_intro_label.name = "BossIntroLabel"
	boss_intro_label.visible = false
	boss_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_intro_label.add_theme_font_size_override("font_size", 46)
	boss_intro_label.modulate = Color(1.0, 0.78, 0.42, 0.0)
	root.add_child(boss_intro_label)

	milestone_label = Label.new()
	milestone_label.name = "ComboMilestoneLabel"
	milestone_label.visible = false
	milestone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	milestone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	milestone_label.add_theme_font_size_override("font_size", 34)
	milestone_label.modulate = Color(1.0, 0.78, 0.24, 0.0)
	root.add_child(milestone_label)

	combo_break_label = Label.new()
	combo_break_label.name = "ComboBreakLabel"
	combo_break_label.visible = false
	combo_break_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_break_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_break_label.add_theme_font_size_override("font_size", 22)
	combo_break_label.modulate = Color(0.86, 0.92, 0.96, 0.0)
	root.add_child(combo_break_label)

	_build_virtual_joystick()
	_build_pause_overlay()
	_apply_responsive_layout()


func _build_quick_controls() -> void:
	quick_controls = Control.new()
	quick_controls.name = "QuickControls"
	root.add_child(quick_controls)

	quick_mute_button = _make_quick_icon_button("M", "靜音", true)
	quick_mute_button.toggled.connect(_on_mute_toggled)
	quick_controls.add_child(quick_mute_button)

	quick_screen_shake_button = _make_quick_icon_button("S", "螢幕震動", true)
	quick_screen_shake_button.toggled.connect(_on_screen_shake_toggled)
	quick_controls.add_child(quick_screen_shake_button)

	quick_joystick_size_button = _make_quick_icon_button("J", "搖桿大小", false)
	quick_joystick_size_button.pressed.connect(_on_quick_joystick_size_pressed)
	quick_controls.add_child(quick_joystick_size_button)


func _make_quick_icon_button(text_value: String, tooltip_value: String, toggle: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.tooltip_text = tooltip_value
	button.toggle_mode = toggle
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(38.0, 38.0)
	button.add_theme_font_size_override("font_size", 14)
	_apply_quick_button_style(button, false)
	return button


func _build_pause_overlay() -> void:
	pause_overlay = Panel.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.visible = false
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.anchor_left = 0.5
	pause_overlay.anchor_right = 0.5
	pause_overlay.anchor_top = 0.5
	pause_overlay.anchor_bottom = 0.5
	root.add_child(pause_overlay)

	pause_title_label = Label.new()
	pause_title_label.text = "暫停"
	pause_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_title_label.add_theme_font_size_override("font_size", 24)
	pause_overlay.add_child(pause_title_label)

	var tab_group := ButtonGroup.new()
	pause_tab_bar = HBoxContainer.new()
	pause_tab_bar.name = "PauseTabs"
	pause_tab_bar.add_theme_constant_override("separation", 6)
	pause_overlay.add_child(pause_tab_bar)

	pause_settings_tab_button = _make_pause_tab_button("設定", "settings", tab_group)
	pause_achievements_tab_button = _make_pause_tab_button("成就", "achievements", tab_group)
	pause_run_tab_button = _make_pause_tab_button("本局", "run", tab_group)
	pause_tab_bar.add_child(pause_settings_tab_button)
	pause_tab_bar.add_child(pause_achievements_tab_button)
	pause_tab_bar.add_child(pause_run_tab_button)

	pause_scroll = ScrollContainer.new()
	pause_scroll.name = "PausePageScroll"
	pause_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pause_overlay.add_child(pause_scroll)

	pause_content = VBoxContainer.new()
	pause_content.name = "PausePages"
	pause_content.add_theme_constant_override("separation", 10)
	pause_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_scroll.add_child(pause_content)

	_build_pause_settings_page()
	_build_pause_achievements_page()
	_build_pause_run_page()

	pause_resume_button = Button.new()
	pause_resume_button.text = "繼續"
	pause_resume_button.custom_minimum_size = Vector2(160.0, 42.0)
	pause_resume_button.pressed.connect(_on_resume_button_pressed)
	pause_overlay.add_child(pause_resume_button)

	pause_achievement_dialog = AcceptDialog.new()
	pause_achievement_dialog.title = "成就"
	pause_achievement_dialog.ok_button_text = "關閉"
	root.add_child(pause_achievement_dialog)
	pause_achievement_dialog.get_ok_button().custom_minimum_size.y = 44.0

	_show_pause_tab("settings")
	_sync_audio_controls()
	_sync_settings_controls()
	_refresh_achievement_list()


func _make_pause_tab_button(text_value: String, tab_id: String, tab_group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = text_value
	button.toggle_mode = true
	button.button_group = tab_group
	button.custom_minimum_size = Vector2(96.0, 36.0)
	button.pressed.connect(_show_pause_tab.bind(tab_id))
	return button


func _build_pause_settings_page() -> void:
	pause_settings_page = VBoxContainer.new()
	pause_settings_page.name = "SettingsPage"
	pause_settings_page.add_theme_constant_override("separation", 10)
	pause_settings_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_content.add_child(pause_settings_page)

	pause_volume_label = Label.new()
	pause_volume_label.text = "音量"
	pause_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_settings_page.add_child(pause_volume_label)

	pause_volume_slider = HSlider.new()
	pause_volume_slider.min_value = 0.0
	pause_volume_slider.max_value = 1.0
	pause_volume_slider.step = 0.05
	pause_volume_slider.custom_minimum_size = Vector2(240.0, 28.0)
	pause_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_volume_slider.value_changed.connect(_on_volume_slider_changed)
	pause_settings_page.add_child(pause_volume_slider)

	var toggle_grid := GridContainer.new()
	toggle_grid.columns = 2
	toggle_grid.add_theme_constant_override("h_separation", 12)
	toggle_grid.add_theme_constant_override("v_separation", 8)
	toggle_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_settings_page.add_child(toggle_grid)

	pause_mute_check = CheckBox.new()
	pause_mute_check.text = "靜音"
	pause_mute_check.toggled.connect(_on_mute_toggled)
	toggle_grid.add_child(pause_mute_check)

	pause_damage_numbers_check = CheckBox.new()
	pause_damage_numbers_check.text = "傷害數字"
	pause_damage_numbers_check.toggled.connect(_on_damage_numbers_toggled)
	toggle_grid.add_child(pause_damage_numbers_check)

	pause_screen_shake_check = CheckBox.new()
	pause_screen_shake_check.text = "螢幕震動"
	pause_screen_shake_check.toggled.connect(_on_screen_shake_toggled)
	toggle_grid.add_child(pause_screen_shake_check)

	pause_force_joystick_check = CheckBox.new()
	pause_force_joystick_check.text = "強制搖桿"
	pause_force_joystick_check.toggled.connect(_on_force_joystick_toggled)
	toggle_grid.add_child(pause_force_joystick_check)

	pause_high_contrast_check = CheckBox.new()
	pause_high_contrast_check.text = "高對比"
	pause_high_contrast_check.toggled.connect(_on_high_contrast_toggled)
	toggle_grid.add_child(pause_high_contrast_check)

	pause_ui_scale_label = Label.new()
	pause_ui_scale_label.text = "介面大小"
	pause_ui_scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_settings_page.add_child(pause_ui_scale_label)

	pause_ui_scale_slider = HSlider.new()
	pause_ui_scale_slider.min_value = 0.0
	pause_ui_scale_slider.max_value = 2.0
	pause_ui_scale_slider.step = 1.0
	pause_ui_scale_slider.tick_count = 3
	pause_ui_scale_slider.ticks_on_borders = true
	pause_ui_scale_slider.custom_minimum_size = Vector2(240.0, 28.0)
	pause_ui_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_ui_scale_slider.value_changed.connect(_on_ui_scale_slider_changed)
	pause_settings_page.add_child(pause_ui_scale_slider)

	pause_joystick_size_label = Label.new()
	pause_joystick_size_label.text = "搖桿大小"
	pause_joystick_size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_settings_page.add_child(pause_joystick_size_label)

	pause_joystick_size_slider = HSlider.new()
	pause_joystick_size_slider.min_value = 0.0
	pause_joystick_size_slider.max_value = 2.0
	pause_joystick_size_slider.step = 1.0
	pause_joystick_size_slider.tick_count = 3
	pause_joystick_size_slider.ticks_on_borders = true
	pause_joystick_size_slider.custom_minimum_size = Vector2(240.0, 28.0)
	pause_joystick_size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_joystick_size_slider.value_changed.connect(_on_joystick_size_slider_changed)
	pause_settings_page.add_child(pause_joystick_size_slider)

	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 8)
	tool_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_settings_page.add_child(tool_row)

	pause_seed_button = Button.new()
	pause_seed_button.text = "複製種子"
	pause_seed_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_seed_button.pressed.connect(_on_copy_seed_pressed)
	tool_row.add_child(pause_seed_button)

	pause_guide_button = Button.new()
	pause_guide_button.text = "重看教學"
	pause_guide_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_guide_button.pressed.connect(_on_rewatch_guide_pressed)
	tool_row.add_child(pause_guide_button)


func _build_pause_achievements_page() -> void:
	pause_achievements_page = VBoxContainer.new()
	pause_achievements_page.name = "AchievementsPage"
	pause_achievements_page.add_theme_constant_override("separation", 10)
	pause_achievements_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_content.add_child(pause_achievements_page)

	pause_achievements_grid = GridContainer.new()
	pause_achievements_grid.name = "PauseAchievementGrid"
	pause_achievements_grid.columns = 3
	pause_achievements_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_achievements_grid.add_theme_constant_override("h_separation", 8)
	pause_achievements_grid.add_theme_constant_override("v_separation", 8)
	pause_achievements_page.add_child(pause_achievements_grid)


func _build_pause_run_page() -> void:
	pause_run_page = VBoxContainer.new()
	pause_run_page.name = "RunPage"
	pause_run_page.add_theme_constant_override("separation", 14)
	pause_run_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_content.add_child(pause_run_page)

	pause_run_stats_label = Label.new()
	pause_run_stats_label.name = "PauseRunStatsLabel"
	pause_run_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_run_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_run_stats_label.add_theme_font_size_override("font_size", 15)
	pause_run_page.add_child(pause_run_stats_label)

	pause_reset_meta_button = Button.new()
	pause_reset_meta_button.text = "重置殘響"
	pause_reset_meta_button.custom_minimum_size = Vector2(180.0, 44.0)
	pause_reset_meta_button.pressed.connect(_on_reset_meta_pressed)
	pause_run_page.add_child(pause_reset_meta_button)


func _show_pause_tab(tab_id: String) -> void:
	pause_active_tab = tab_id
	if pause_settings_page != null:
		pause_settings_page.visible = tab_id == "settings"
	if pause_achievements_page != null:
		pause_achievements_page.visible = tab_id == "achievements"
	if pause_run_page != null:
		pause_run_page.visible = tab_id == "run"
	if pause_settings_tab_button != null:
		pause_settings_tab_button.button_pressed = tab_id == "settings"
	if pause_achievements_tab_button != null:
		pause_achievements_tab_button.button_pressed = tab_id == "achievements"
	if pause_run_tab_button != null:
		pause_run_tab_button.button_pressed = tab_id == "run"
	if pause_scroll != null:
		pause_scroll.scroll_vertical = 0


func _build_pause_overlay_legacy_unused() -> void:
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
	pause_content.add_theme_constant_override("separation", 12)
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

	pause_force_joystick_check = CheckBox.new()
	pause_force_joystick_check.text = "強制顯示搖桿"
	pause_force_joystick_check.toggled.connect(_on_force_joystick_toggled)
	pause_content.add_child(pause_force_joystick_check)

	pause_joystick_size_label = Label.new()
	pause_joystick_size_label.text = "搖桿大小：中"
	pause_joystick_size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_content.add_child(pause_joystick_size_label)

	pause_joystick_size_slider = HSlider.new()
	pause_joystick_size_slider.min_value = 0.0
	pause_joystick_size_slider.max_value = 2.0
	pause_joystick_size_slider.step = 1.0
	pause_joystick_size_slider.tick_count = 3
	pause_joystick_size_slider.ticks_on_borders = true
	pause_joystick_size_slider.custom_minimum_size = Vector2(240.0, 28.0)
	pause_joystick_size_slider.value_changed.connect(_on_joystick_size_slider_changed)
	pause_content.add_child(pause_joystick_size_slider)

	pause_seed_button = Button.new()
	pause_seed_button.text = "複製本局種子"
	pause_seed_button.pressed.connect(_on_copy_seed_pressed)
	pause_content.add_child(pause_seed_button)

	pause_guide_button = Button.new()
	pause_guide_button.text = "重看教學"
	pause_guide_button.pressed.connect(_on_rewatch_guide_pressed)
	pause_content.add_child(pause_guide_button)

	pause_run_stats_label = Label.new()
	pause_run_stats_label.name = "PauseRunStatsLabel"
	pause_run_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_run_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_run_stats_label.add_theme_font_size_override("font_size", 14)
	pause_content.add_child(pause_run_stats_label)

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
	viewport_size = MOBILE_TUNING.apply_web_canvas_scale(self, viewport_size, root)
	var portrait := viewport_size.y > viewport_size.x
	var mobile := MOBILE_TUNING.use_mobile_ui(viewport_size)
	var layout_tier := MOBILE_TUNING.layout_tier(viewport_size)
	var tablet := layout_tier == MOBILE_TUNING.LayoutTier.TABLET
	var show_touch_controls := _should_show_touch_controls()
	var margin := 16.0 if mobile else 14.0
	var touch_height := MOBILE_TUNING.touch_target(viewport_size)
	var safe_top := MOBILE_TUNING.safe_top_padding(viewport_size)
	var compact_landscape := mobile and not portrait
	_refresh_primary_stat_labels(compact_landscape)

	if hud_panel != null:
		hud_panel.position = Vector2(8.0, safe_top + 58.0) if mobile and portrait else Vector2(8.0, safe_top + 8.0 if mobile else 8.0)
		if mobile and portrait:
			hud_panel.size = Vector2(min(viewport_size.x - 16.0, 382.0), 126.0)
		elif compact_landscape:
			# R30 R1-01：844x390 的 HP／等級＋經驗／XP bar 各有獨立垂直節奏。
			hud_panel.size = Vector2(min(viewport_size.x * 0.38, 390.0), 118.0)
		else:
			hud_panel.size = Vector2(min(viewport_size.x * (0.72 if portrait else 0.38), 340.0), 108.0)
	if score_panel != null:
		if mobile and portrait:
			score_panel.anchor_left = 0.5
			score_panel.anchor_right = 0.5
			score_panel.position = Vector2.ZERO
			score_panel.offset_left = 2.0
			score_panel.offset_right = 72.0
			score_panel.offset_top = safe_top + 6.0
			score_panel.offset_bottom = score_panel.offset_top + 44.0
		else:
			score_panel.anchor_left = 1.0
			score_panel.anchor_right = 1.0
			score_panel.position = Vector2.ZERO
			score_panel.offset_left = -358.0 if not portrait else -276.0
			score_panel.offset_right = -150.0 if mobile and not portrait else -margin
			score_panel.offset_top = safe_top + 76.0 if mobile and not portrait else 8.0 if not portrait else 48.0
			score_panel.offset_bottom = score_panel.offset_top + (52.0 if mobile else 46.0)
	if hp_icon != null:
		hp_icon.anchor_left = 0.0
		hp_icon.anchor_right = 0.0
		hp_icon.position = Vector2(margin + 2.0, safe_top + 72.0) if mobile and portrait else Vector2(margin + 2.0, safe_top + 14.0 if mobile else 14.0)
		hp_icon.size = Vector2(36.0, 36.0) if mobile and portrait else Vector2(32.0, 32.0) if mobile else Vector2(26.0, 26.0)
	if xp_icon != null:
		xp_icon.anchor_left = 0.0
		xp_icon.anchor_right = 0.0
		xp_icon.position = Vector2(margin + 2.0, safe_top + 114.0) if mobile and portrait else Vector2(margin + 2.0, safe_top + 52.0 if compact_landscape else 44.0)
		xp_icon.size = Vector2(34.0, 34.0) if mobile and portrait else Vector2(26.0, 26.0) if compact_landscape else Vector2(24.0, 24.0)
	if gold_icon != null:
		gold_icon.visible = not mobile
		if mobile and portrait:
			gold_icon.anchor_left = 0.0
			gold_icon.anchor_right = 0.0
			gold_icon.offset_left = margin + 2.0
			gold_icon.offset_right = gold_icon.offset_left + 30.0
			gold_icon.offset_top = safe_top + 188.0
			gold_icon.offset_bottom = gold_icon.offset_top + 30.0
		else:
			gold_icon.anchor_left = 1.0
			gold_icon.anchor_right = 1.0
			gold_icon.offset_left = -336.0 if not portrait else -258.0
			gold_icon.offset_right = gold_icon.offset_left + (30.0 if mobile else 26.0)
			gold_icon.offset_top = safe_top + 86.0 if mobile and not portrait else 20.0 if not portrait else 60.0
			gold_icon.offset_bottom = gold_icon.offset_top + (30.0 if mobile else 26.0)

	hp_label.position = Vector2(margin + 48.0, safe_top + 68.0) if mobile and portrait else Vector2(margin + 36.0, safe_top + 12.0 if compact_landscape else 10.0)
	hp_label.add_theme_font_size_override("font_size", (18 if portrait else 18) if mobile else (18 if portrait else 20))
	level_label.position = Vector2(margin + 48.0, safe_top + 110.0) if mobile and portrait else Vector2(margin + 36.0, safe_top + 50.0 if compact_landscape else 38.0)
	level_label.add_theme_font_size_override("font_size", (16 if portrait else 15) if mobile else (14 if portrait else 16))
	if xp_readout_label != null:
		xp_readout_label.visible = compact_landscape
		xp_readout_label.position = Vector2(margin + 36.0, safe_top + 80.0)
		xp_readout_label.size = Vector2(min(viewport_size.x * 0.28, 286.0), 24.0)
		xp_readout_label.add_theme_font_size_override("font_size", 16)
	xp_bar.position = Vector2(margin + 48.0, safe_top + 150.0) if mobile and portrait else Vector2(margin + 36.0, safe_top + 108.0 if compact_landscape else 66.0)
	xp_bar.size = Vector2(min(viewport_size.x - margin * 2.0 - 58.0, 306.0), 20.0) if mobile and portrait else Vector2(min(viewport_size.x * (0.5 if portrait else 0.28), 286.0 if mobile else 260.0), 14.0 if compact_landscape else 14.0)
	if theme_label != null:
		theme_label.visible = not mobile and theme_label.text != ""
		theme_label.position = Vector2(margin + 48.0, safe_top + 174.0) if mobile and portrait else Vector2(margin + 36.0, safe_top + 82.0 if mobile else 82.0)
		theme_label.size = Vector2(min(viewport_size.x - margin * 2.0 - 58.0, 306.0), 26.0) if mobile and portrait else Vector2(min(viewport_size.x * (0.55 if portrait else 0.3), 286.0 if mobile else 276.0), 26.0 if mobile else 22.0)
		theme_label.add_theme_font_size_override("font_size", (13 if portrait else 12) if mobile else (12 if portrait else 13))

	time_label.anchor_left = 0.0 if mobile and portrait else 0.5
	time_label.anchor_right = 0.0 if mobile and portrait else 0.5
	time_label.offset_left = margin if mobile and portrait else -92.0 if mobile else -78.0
	time_label.offset_right = margin + 150.0 if mobile and portrait else 92.0 if mobile else 78.0
	time_label.offset_top = safe_top if mobile else 10.0
	time_label.offset_bottom = time_label.offset_top + (46.0 if mobile else 32.0)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if mobile and portrait else HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", (22 if portrait else 23) if mobile else (22 if portrait else 24))

	score_label.anchor_left = 1.0
	score_label.anchor_right = 1.0
	if mobile and portrait:
		score_label.anchor_left = 0.5
		score_label.anchor_right = 0.5
		score_label.offset_left = 6.0
		score_label.offset_right = 68.0
		score_label.offset_top = safe_top + 8.0
		score_label.offset_bottom = score_label.offset_top + 38.0
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		score_label.offset_left = -338.0 if not portrait else -258.0
		score_label.offset_right = -150.0 if mobile and not portrait else -104.0 if not portrait else -14.0
		score_label.offset_top = safe_top + 84.0 if mobile and not portrait else 17.0 if not portrait else 54.0
		score_label.offset_bottom = score_label.offset_top + (34.0 if mobile else 30.0)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_size_override("font_size", (14 if portrait else 16) if mobile else (16 if portrait else 18))

	version_label.visible = not mobile
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
	var pause_width: float = max(touch_height, 104.0) if mobile and portrait else max(touch_height, 116.0) if mobile else 74.0
	pause_button.offset_left = -(pause_width + margin) if mobile else -88.0
	pause_button.offset_right = -margin
	pause_button.offset_top = safe_top if mobile else 10.0
	pause_button.offset_bottom = pause_button.offset_top + (touch_height if mobile else 40.0)
	pause_button.visible = not (pause_overlay != null and pause_overlay.visible)
	pause_button.disabled = pause_overlay != null and pause_overlay.visible

	if pause_overlay != null:
		var overlay_width: float = min(viewport_size.x - (24.0 if mobile else 40.0), 520.0 if mobile else 540.0)
		var overlay_height: float = min(viewport_size.y - (24.0 if mobile else 44.0), 680.0 if mobile else 610.0)
		pause_overlay.anchor_left = 0.5
		pause_overlay.anchor_right = 0.5
		pause_overlay.anchor_top = 0.5
		pause_overlay.anchor_bottom = 0.5
		pause_overlay.offset_left = -overlay_width * 0.5
		pause_overlay.offset_right = overlay_width * 0.5
		pause_overlay.offset_top = -overlay_height * 0.5
		pause_overlay.offset_bottom = overlay_height * 0.5

		if pause_title_label != null:
			pause_title_label.position = Vector2(18.0, 10.0)
			pause_title_label.size = Vector2(max(1.0, overlay_width - 36.0), 34.0)
			pause_title_label.add_theme_font_size_override("font_size", 24 if not mobile else 22)
		if pause_tab_bar != null:
			pause_tab_bar.position = Vector2(18.0, 50.0)
			pause_tab_bar.size = Vector2(max(1.0, overlay_width - 36.0), 50.0 if mobile else 48.0)
			var tab_width: float = max(78.0, (overlay_width - 48.0) / 3.0)
			for child in pause_tab_bar.get_children():
				if child is Button:
					(child as Button).custom_minimum_size = Vector2(tab_width, 50.0 if mobile else 44.0)
		if pause_resume_button != null:
			var resume_height: float = maxf(44.0, min(touch_height, 54.0)) if mobile else touch_height
			var resume_width: float = min(overlay_width - 48.0, 190.0 if mobile else 160.0)
			pause_resume_button.position = Vector2((overlay_width - resume_width) * 0.5, overlay_height - resume_height - 16.0)
			pause_resume_button.size = Vector2(resume_width, resume_height)
			pause_resume_button.custom_minimum_size = Vector2(resume_width, resume_height)

	if pause_scroll != null:
		var overlay_size: Vector2 = pause_overlay.size if pause_overlay != null else Vector2(430.0, 610.0)
		var scroll_margin: float = 18.0 if mobile else 22.0
		var scroll_top: float = 116.0 if mobile else 104.0
		var scroll_bottom: float = 78.0 if mobile else 70.0
		pause_scroll.position = Vector2(scroll_margin, scroll_top)
		pause_scroll.size = Vector2(max(1.0, overlay_size.x - scroll_margin * 2.0), max(1.0, overlay_size.y - scroll_top - scroll_bottom))

	if pause_content != null:
		var content_width: float = max(260.0, (pause_scroll.size.x if pause_scroll != null else min(viewport_size.x - 60.0, 420.0)))
		pause_content.custom_minimum_size = Vector2(content_width, 0.0)
		_layout_pause_achievement_grid(content_width, mobile)

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
		var ability_size := MOBILE_TUNING.ability_button_size(viewport_size)
		var ability_position := MOBILE_TUNING.ability_button_position(viewport_size)
		active_ability_button.anchor_left = 0.0
		active_ability_button.anchor_right = 0.0
		active_ability_button.anchor_top = 0.0
		active_ability_button.anchor_bottom = 0.0
		active_ability_button.position = ability_position
		active_ability_button.size = Vector2(ability_size, ability_size)
		active_ability_button.custom_minimum_size = Vector2(ability_size, ability_size)
		active_ability_button.add_theme_font_size_override("font_size", (24 if portrait else 22) if mobile else 22 if portrait else 20)
		if not show_touch_controls:
			active_ability_button.visible = false
	if active_ability_cooldown_ring != null and active_ability_button != null:
		active_ability_cooldown_ring.position = active_ability_button.position
		active_ability_cooldown_ring.size = active_ability_button.size
		if active_ability_cooldown_ring.has_method("set_ring_width"):
			active_ability_cooldown_ring.call("set_ring_width", 7.0 if mobile else 5.0)
		if not show_touch_controls:
			active_ability_cooldown_ring.visible = false
	if active_ability_cooldown != null and active_ability_button != null:
		active_ability_cooldown.position = active_ability_button.position
		active_ability_cooldown.size = active_ability_button.size
		if not show_touch_controls:
			active_ability_cooldown.visible = false
	if active_ability_label != null and active_ability_button != null:
		active_ability_label.position = active_ability_button.position
		active_ability_label.size = active_ability_button.size
		if not show_touch_controls:
			active_ability_label.visible = false

	if toast_panel != null:
		var toast_width: float = min(viewport_size.x - 32.0, 520.0)
		toast_panel.anchor_left = 0.5
		toast_panel.anchor_right = 0.5
		toast_panel.anchor_top = 0.0
		toast_panel.anchor_bottom = 0.0
		toast_panel.offset_left = -toast_width * 0.5
		toast_panel.offset_right = toast_width * 0.5
		toast_panel.offset_top = safe_top + 186.0 if mobile and portrait else safe_top + 64.0 if mobile else 56.0 if not portrait else 94.0
		toast_panel.offset_bottom = toast_panel.offset_top + (58.0 if mobile else 48.0)

	if captain_hit_flash_rect != null:
		captain_hit_flash_rect.offset_left = 0.0
		captain_hit_flash_rect.offset_top = 0.0
		captain_hit_flash_rect.offset_right = 0.0
		captain_hit_flash_rect.offset_bottom = 0.0

	if combo_pulse_rect != null and not combo_pulse_rect.visible:
		var pulse_size: float = min(viewport_size.x, viewport_size.y) * 0.28
		combo_pulse_rect.position = viewport_size * 0.5 - Vector2.ONE * pulse_size * 0.5
		combo_pulse_rect.size = Vector2.ONE * pulse_size

	if boss_intro_rect != null:
		boss_intro_rect.offset_left = 0.0
		boss_intro_rect.offset_top = 0.0
		boss_intro_rect.offset_right = 0.0
		boss_intro_rect.offset_bottom = 0.0
	if boss_intro_label != null:
		boss_intro_label.position = Vector2(24.0, viewport_size.y * 0.31)
		boss_intro_label.size = Vector2(max(1.0, viewport_size.x - 48.0), 118.0 if mobile else 82.0)
		boss_intro_label.add_theme_font_size_override("font_size", (32 if portrait else 42) if mobile else (36 if portrait else 48))
	if milestone_label != null:
		milestone_label.position = Vector2(24.0, max(safe_top + 116.0, viewport_size.y * (0.29 if mobile and portrait else 0.22)))
		milestone_label.size = Vector2(max(1.0, viewport_size.x - 48.0), 108.0 if mobile else 78.0)
		milestone_label.add_theme_font_size_override("font_size", (25 if portrait else 32) if mobile else (28 if portrait else 36))
	if combo_break_label != null:
		combo_break_label.position = Vector2(24.0, viewport_size.y * (0.40 if mobile and portrait else 0.32))
		combo_break_label.size = Vector2(max(1.0, viewport_size.x - 48.0), 58.0 if mobile else 44.0)
		combo_break_label.add_theme_font_size_override("font_size", (16 if portrait else 20) if mobile else (18 if portrait else 22))

	if virtual_joystick != null:
		var joystick_size_index: int = int(PlayerSettings.get("joystick_size_index")) if PlayerSettings != null else 1
		var joystick_size: Vector2 = Vector2(188.0, 188.0)
		if virtual_joystick.has_method("configure_for_viewport"):
			joystick_size = virtual_joystick.configure_for_viewport(viewport_size, mobile, joystick_size_index, tablet)
		else:
			var fallback_size: float = 188.0 if mobile and portrait else 170.0 if mobile else 164.0 if portrait else 150.0
			joystick_size = Vector2(fallback_size, fallback_size)
		virtual_joystick.size = joystick_size
		var joystick_target := MOBILE_TUNING.joystick_rect(viewport_size, joystick_size)
		virtual_joystick.position = joystick_target.position
		virtual_joystick.visible = show_touch_controls
		if not virtual_joystick.visible:
			GameManager.set_touch_move_vector(Vector2.ZERO)
	MOBILE_TUNING.apply_control_tree(root, viewport_size)
	if compact_landscape:
		# 通用手機倍率會把 18px 放大到約 33px；橫向矮視口在此鎖回可讀且不互壓的 CSS 字級。
		hp_label.add_theme_font_size_override("font_size", 24)
		level_label.add_theme_font_size_override("font_size", 18)
		if xp_readout_label != null:
			xp_readout_label.add_theme_font_size_override("font_size", 16)
	_compact_pause_controls(mobile)
	var compact_pause_landscape := mobile and not portrait
	if pause_settings_page != null:
		pause_settings_page.add_theme_constant_override("separation", 4 if compact_pause_landscape else 10)
	if pause_volume_label != null:
		pause_volume_label.visible = not compact_pause_landscape
	if pause_volume_slider != null:
		pause_volume_slider.visible = not compact_pause_landscape
	if pause_force_joystick_check != null:
		pause_force_joystick_check.visible = show_touch_controls and not compact_pause_landscape
	if pause_high_contrast_check != null:
		pause_high_contrast_check.visible = true
	if pause_ui_scale_label != null:
		pause_ui_scale_label.visible = true
	if pause_ui_scale_slider != null:
		pause_ui_scale_slider.visible = true
	if pause_joystick_size_label != null:
		pause_joystick_size_label.visible = show_touch_controls and not compact_pause_landscape
	if pause_joystick_size_slider != null:
		pause_joystick_size_slider.visible = show_touch_controls and not compact_pause_landscape
	_layout_quick_controls(viewport_size, mobile, portrait, margin, safe_top, touch_height, pause_width, show_touch_controls)
	_apply_accessibility_palette()
	call_deferred("_publish_reachability_probe", viewport_size)


func _publish_reachability_probe(viewport_size: Vector2 = Vector2.ZERO) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = MOBILE_TUNING.ui_layout_size(get_viewport().get_visible_rect().size)
	WEB_REACHABILITY_PROBE.publish("hud", viewport_size, {
		"hud_panel": hud_panel,
		"hp_label": hp_label,
		"level_label": level_label,
		"xp_readout": xp_readout_label,
		"xp_bar": xp_bar,
		"pause": pause_button,
		"pause_overlay": pause_overlay,
		"pause_settings_tab": pause_settings_tab_button,
		"pause_achievements_tab": pause_achievements_tab_button,
		"pause_run_tab": pause_run_tab_button,
		"pause_resume": pause_resume_button,
		"quick_controls": quick_controls,
		"quick_mute": quick_mute_button,
		"quick_screen_shake": quick_screen_shake_button,
		"quick_joystick_size": quick_joystick_size_button,
		"pause_high_contrast": pause_high_contrast_check,
		"pause_ui_scale": pause_ui_scale_slider,
		"virtual_joystick": virtual_joystick,
		"active_ability": active_ability_button
	}, {
		"paused": pause_overlay != null and pause_overlay.visible,
		"confirmed_touch": MOBILE_TUNING.has_confirmed_touch(),
		"touch_controls_visible": virtual_joystick != null and virtual_joystick.visible
	})


func _layout_quick_controls(viewport_size: Vector2, mobile: bool, portrait: bool, margin: float, safe_top: float, touch_height: float, pause_width: float, show_touch_controls: bool) -> void:
	if quick_controls == null:
		return
	var icon_size: float = maxf(46.0, touch_height) if mobile else 36.0
	var gap: float = 6.0
	var buttons: Array[Button] = [quick_mute_button, quick_screen_shake_button]
	if quick_joystick_size_button != null:
		quick_joystick_size_button.visible = show_touch_controls
		if show_touch_controls:
			buttons.append(quick_joystick_size_button)
	var vertical := mobile and portrait
	var button_count := buttons.size()
	var total_width: float = icon_size if vertical else icon_size * float(button_count) + gap * float(max(0, button_count - 1))
	var total_height: float = icon_size * float(button_count) + gap * float(max(0, button_count - 1)) if vertical else icon_size
	var x: float = viewport_size.x - margin - total_width
	var y: float = min(viewport_size.y - total_height - 132.0, safe_top + 190.0) if vertical else safe_top + (2.0 if mobile else 12.0)
	if not vertical:
		x = viewport_size.x - margin - pause_width - gap - total_width if mobile else viewport_size.x - margin - total_width
		y = safe_top + touch_height + 80.0 if mobile else safe_top + touch_height + 22.0 if show_touch_controls else safe_top + 58.0
	quick_controls.position = Vector2(max(margin, x), y)
	quick_controls.size = Vector2(total_width, total_height)
	quick_controls.visible = not (pause_overlay != null and pause_overlay.visible)
	for index in range(buttons.size()):
		var button := buttons[index] as Button
		if button == null:
			continue
		button.position = Vector2(0.0, float(index) * (icon_size + gap)) if vertical else Vector2(float(index) * (icon_size + gap), 0.0)
		button.size = Vector2(icon_size, icon_size)
		button.custom_minimum_size = Vector2(icon_size, icon_size)
		button.add_theme_font_size_override("font_size", 14 if mobile else 13)


func _compact_pause_controls(mobile: bool) -> void:
	var ui_multiplier := _ui_scale_multiplier()
	var viewport_size := MOBILE_TUNING.ui_layout_size(get_viewport().get_visible_rect().size)
	var compact_landscape := mobile and viewport_size.x > viewport_size.y
	var check_font_size: int = int(round(float(15 if compact_landscape else 20 if mobile else 15) * ui_multiplier))
	var check_height: float = 44.0 if compact_landscape else 54.0 if mobile else 44.0
	for control in [pause_mute_check, pause_damage_numbers_check, pause_screen_shake_check, pause_force_joystick_check, pause_high_contrast_check]:
		var check := control as CheckBox
		if check == null:
			continue
		check.add_theme_font_size_override("font_size", check_font_size)
		check.custom_minimum_size = Vector2(0.0, check_height)
	if pause_ui_scale_label != null:
		pause_ui_scale_label.add_theme_font_size_override("font_size", int(round(float(14 if compact_landscape else 18 if mobile else 15) * ui_multiplier)))
	if pause_ui_scale_slider != null:
		pause_ui_scale_slider.custom_minimum_size = Vector2(240.0, 44.0 if compact_landscape else 46.0 if mobile else 44.0)
	if pause_seed_button != null:
		pause_seed_button.add_theme_font_size_override("font_size", int(round(float(19 if mobile else 15) * ui_multiplier)))
	if pause_guide_button != null:
		pause_guide_button.add_theme_font_size_override("font_size", int(round(float(19 if mobile else 15) * ui_multiplier)))
	for control in [pause_settings_tab_button, pause_achievements_tab_button, pause_run_tab_button]:
		var tab := control as Button
		if tab == null:
			continue
		tab.add_theme_font_size_override("font_size", int(round(float(20 if mobile else 15) * ui_multiplier)))
		tab.custom_minimum_size.y = 50.0 if mobile else 44.0


func _layout_pause_achievement_grid(content_width: float, mobile: bool) -> void:
	if pause_achievements_grid == null:
		return
	var columns: int = 4 if content_width >= 430.0 else 3 if content_width >= 310.0 else 2
	pause_achievements_grid.columns = columns
	var gap: float = 8.0
	var badge_width: float = max(86.0, floor((content_width - gap * float(columns - 1)) / float(columns)))
	var badge_height: float = 70.0 if mobile else 62.0
	for child in pause_achievements_grid.get_children():
		if child is Button:
			(child as Button).custom_minimum_size = Vector2(badge_width, badge_height)


func _apply_quick_button_style(button: Button, active: bool) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.09, 0.12, 0.82) if active else Color(0.035, 0.055, 0.07, 0.76)
	normal.border_color = Color(0.48, 0.95, 1.0, 0.86) if active else Color(0.28, 0.39, 0.45, 0.78)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.07, 0.17, 0.21, 0.94)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.01, 0.045, 0.06, 0.96)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_color_override("font_color", Color(0.86, 0.98, 1.0, 1.0) if active else Color(0.56, 0.65, 0.7, 1.0))


func _ui_scale_multiplier() -> float:
	if PlayerSettings != null and PlayerSettings.has_method("get_ui_scale_multiplier"):
		return float(PlayerSettings.get_ui_scale_multiplier())
	return 1.0


func _apply_accessibility_palette() -> void:
	var high_contrast := PlayerSettings != null and bool(PlayerSettings.get("high_contrast_enabled"))
	var panel_alpha := 0.94 if high_contrast else 0.78
	for panel_control in [hud_panel, score_panel, pause_overlay, toast_panel]:
		var panel := panel_control as Panel
		if panel == null:
			continue
		panel.modulate = Color(1.0, 1.0, 1.0, panel_alpha)
	var labels: Array = [
		hp_label, level_label, theme_label, time_label, score_label,
		pause_title_label, pause_volume_label, pause_joystick_size_label,
		pause_ui_scale_label, pause_run_stats_label, toast_label
	]
	for control in labels:
		var label := control as Label
		if label == null:
			continue
		if high_contrast:
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 3)
		else:
			label.remove_theme_constant_override("outline_size")


func _make_achievement_badge(row: Dictionary) -> Button:
	var unlocked := bool(row.get("unlocked", false))
	var button := Button.new()
	button.text = "%s\n%s" % ["✓" if unlocked else "□", str(row.get("name", ""))]
	button.tooltip_text = str(row.get("description", ""))
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(98.0, 62.0)
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
	if pause_achievement_dialog == null:
		return
	var status := "已解鎖" if bool(row.get("unlocked", false)) else "未解鎖"
	pause_achievement_dialog.title = "%s  %s" % [status, str(row.get("name", ""))]
	pause_achievement_dialog.dialog_text = str(row.get("description", ""))
	var viewport_size := MOBILE_TUNING.ui_layout_size(get_viewport().get_visible_rect().size)
	var dialog_size := Vector2i(
		int(min(360.0, max(220.0, viewport_size.x - 24.0))),
		int(min(180.0, max(132.0, viewport_size.y - 24.0)))
	)
	pause_achievement_dialog.get_ok_button().custom_minimum_size.y = maxf(44.0, MOBILE_TUNING.touch_target(viewport_size))
	pause_achievement_dialog.popup_centered(dialog_size)


func _on_quick_joystick_size_pressed() -> void:
	if PlayerSettings == null:
		return
	var next_index := (int(PlayerSettings.get("joystick_size_index")) + 1) % 3
	_on_joystick_size_slider_changed(float(next_index))
	_sync_settings_controls()


func _refresh_quick_control_labels() -> void:
	if quick_mute_button != null and AudioManager != null:
		var muted := bool(AudioManager.get("muted"))
		quick_mute_button.text = "M!" if muted else "M"
		quick_mute_button.button_pressed = muted
		_apply_quick_button_style(quick_mute_button, not muted)
	if quick_screen_shake_button != null and PlayerSettings != null:
		var shake_enabled := bool(PlayerSettings.get("screen_shake_enabled"))
		quick_screen_shake_button.text = "S" if shake_enabled else "S!"
		quick_screen_shake_button.button_pressed = shake_enabled
		_apply_quick_button_style(quick_screen_shake_button, shake_enabled)
	if quick_joystick_size_button != null and PlayerSettings != null:
		quick_joystick_size_button.text = "J%d" % (int(PlayerSettings.get("joystick_size_index")) + 1)
		_apply_quick_button_style(quick_joystick_size_button, true)


func _should_show_touch_controls() -> bool:
	var forced := force_touch_controls_visible
	if PlayerSettings != null:
		forced = forced or bool(PlayerSettings.get("force_joystick_visible"))
	return MOBILE_TUNING.should_show_virtual_joystick(get_viewport().get_visible_rect().size, forced)


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
	last_level_value = current_level
	last_xp_value = xp
	last_xp_required_value = xp_required
	var layout_size := MOBILE_TUNING.ui_layout_size(get_viewport().get_visible_rect().size)
	_refresh_primary_stat_labels(MOBILE_TUNING.use_mobile_ui(layout_size) and layout_size.x >= layout_size.y)
	xp_bar.value = clamp(float(xp) / float(xp_required), 0.0, 1.0)
	var theme_name := str(stats.get("run_theme_name", ""))
	var bond_names: PackedStringArray = stats.get("active_bond_names", PackedStringArray())
	if theme_label != null:
		var bond_text := "　羈絆 %d/4　%s" % [bond_names.size(), " · ".join(bond_names)] if not bond_names.is_empty() else "　羈絆 0/4"
		theme_label.text = ("地圖：%s" % theme_name if theme_name != "" else "") + bond_text
		theme_label.visible = not MOBILE_TUNING.use_mobile_ui(get_viewport().get_visible_rect().size)
	time_label.text = GameManager.format_time(float(stats.get("elapsed_time", 0.0)))
	var mobile := MOBILE_TUNING.use_mobile_ui(get_viewport().get_visible_rect().size)
	var kills := int(stats.get("kills", 0))
	var gold := int(stats.get("gold", 0))
	var echo_shards := int(stats.get("echo_shards", 0))
	score_label.text = "K%d" % kills if mobile else "擊殺 %d   金幣 %d   殘響 %d" % [
		kills,
		gold,
		echo_shards
	]
	if pause_run_stats_label != null:
		var pause_bond_text := "\n羈絆 %d/4：%s" % [bond_names.size(), " · ".join(bond_names)] if not bond_names.is_empty() else "\n羈絆 0/4"
		pause_run_stats_label.text = "本局：擊殺 %d   金幣 %d   殘響 %d%s" % [kills, gold, echo_shards, pause_bond_text]
	_on_pause_changed(bool(stats.get("manual_pause_visible", bool(stats.get("manual_paused", false)))))


func _refresh_primary_stat_labels(compact_landscape: bool) -> void:
	if level_label != null:
		level_label.text = "等級 %d" % last_level_value if compact_landscape else "等級 %d   經驗 %d/%d" % [last_level_value, last_xp_value, last_xp_required_value]
	if xp_readout_label != null:
		xp_readout_label.text = "經驗 %d/%d" % [last_xp_value, last_xp_required_value]


func _on_pause_changed(is_paused: bool) -> void:
	if pause_overlay != null:
		pause_overlay.visible = is_paused
	if pause_button != null:
		pause_button.text = "繼續" if is_paused else "暫停"
		pause_button.visible = not is_paused
		pause_button.disabled = is_paused
	if quick_controls != null:
		quick_controls.visible = not is_paused
		quick_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE if is_paused else Control.MOUSE_FILTER_PASS
	if is_paused:
		_sync_audio_controls()
		_sync_settings_controls()
		_refresh_achievement_list()
		_show_pause_tab(pause_active_tab)
		reset_meta_confirm_pending = false
		if pause_reset_meta_button != null:
			pause_reset_meta_button.text = "重置殘響"
	call_deferred("_publish_reachability_probe")


func _on_pause_changed_legacy_unused(is_paused: bool) -> void:
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


func _apply_active_ability_glass_style() -> void:
	if active_ability_button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.09, 0.14, 0.72)
	normal.border_color = Color(0.42, 0.9, 1.0, 0.9)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(46)
	normal.shadow_color = Color(0.12, 0.78, 1.0, 0.3)
	normal.shadow_size = 9
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.06, 0.18, 0.24, 0.86)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.02, 0.055, 0.09, 0.94)
	pressed.border_color = Color(0.78, 1.0, 1.0, 1.0)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.02, 0.045, 0.07, 0.54)
	disabled.border_color = Color(0.3, 0.55, 0.64, 0.55)
	active_ability_button.add_theme_stylebox_override("normal", normal)
	active_ability_button.add_theme_stylebox_override("hover", hover)
	active_ability_button.add_theme_stylebox_override("pressed", pressed)
	active_ability_button.add_theme_stylebox_override("disabled", disabled)
	active_ability_button.add_theme_color_override("font_color", Color(0.86, 0.98, 1.0))
	active_ability_button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _on_active_ability_button_down() -> void:
	_animate_active_ability_press(Vector2.ONE * 0.9, 0.055)


func _on_active_ability_button_up() -> void:
	_animate_active_ability_press(Vector2.ONE, 0.1)


func _animate_active_ability_press(target_scale: Vector2, duration: float) -> void:
	for control in [active_ability_button, active_ability_cooldown, active_ability_cooldown_ring, active_ability_label]:
		if control == null:
			continue
		control.pivot_offset = control.size * 0.5
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(control, "scale", target_scale, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_active_ability_button() -> void:
	if active_ability_button == null:
		return
	var active_player := GameManager.player
	var visible_for_player := _should_show_touch_controls() and active_player != null and is_instance_valid(active_player) and active_player.has_method("get_active_ability_cooldown_remaining")
	active_ability_button.visible = visible_for_player
	if active_ability_cooldown != null:
		active_ability_cooldown.visible = visible_for_player
	if active_ability_cooldown_ring != null:
		active_ability_cooldown_ring.visible = visible_for_player
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
		active_ability_cooldown.modulate = Color(1.0, 1.0, 1.0, 0.30 if ratio > 0.0 else 0.0)
	if active_ability_cooldown_ring != null and active_ability_cooldown_ring.has_method("set_cooldown_ratio"):
		active_ability_cooldown_ring.call("set_cooldown_ratio", ratio)
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


func _on_captain_ability_hit_flash_requested() -> void:
	if captain_hit_flash_rect == null:
		return
	if captain_hit_flash_tween != null and captain_hit_flash_tween.is_valid():
		captain_hit_flash_tween.kill()
	captain_hit_flash_rect.visible = true
	captain_hit_flash_rect.modulate = Color(1.0, 1.0, 1.0, 0.58)
	captain_hit_flash_tween = create_tween()
	captain_hit_flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	captain_hit_flash_tween.tween_property(captain_hit_flash_rect, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.05)


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


func _on_combo_milestone_requested(combo_count: int) -> void:
	if milestone_label == null:
		return
	if milestone_tween != null and milestone_tween.is_valid():
		milestone_tween.kill()
	if combo_pulse_tween != null and combo_pulse_tween.is_valid():
		combo_pulse_tween.kill()
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	milestone_label.text = "COMBO x%d  OVERDRIVE +10%%" % combo_count
	milestone_label.visible = true
	milestone_label.modulate = Color(1.0, 0.78, 0.24, 0.0)
	milestone_label.scale = Vector2.ONE * 0.82
	if combo_pulse_rect != null:
		var start_size: float = min(viewport_size.x, viewport_size.y) * 0.34
		var end_size: float = max(viewport_size.x, viewport_size.y) * 1.95
		var center := viewport_size * 0.5
		var pulse_color := Color(1.0, 0.74, 0.18, 0.62)
		combo_pulse_rect.visible = true
		combo_pulse_rect.modulate = pulse_color
		combo_pulse_rect.position = center - Vector2.ONE * start_size * 0.5
		combo_pulse_rect.size = Vector2.ONE * start_size
		combo_pulse_tween = create_tween()
		combo_pulse_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		combo_pulse_tween.set_parallel(true)
		combo_pulse_tween.tween_property(combo_pulse_rect, "position", center - Vector2.ONE * end_size * 0.5, 0.46)
		combo_pulse_tween.tween_property(combo_pulse_rect, "size", Vector2.ONE * end_size, 0.46)
		combo_pulse_tween.tween_property(combo_pulse_rect, "modulate", Color(pulse_color.r, pulse_color.g, pulse_color.b, 0.0), 0.46)
		combo_pulse_tween.chain().tween_callback(func() -> void:
			if combo_pulse_rect != null:
				combo_pulse_rect.visible = false
		)
	milestone_tween = create_tween()
	milestone_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	milestone_tween.set_parallel(true)
	milestone_tween.tween_property(milestone_label, "modulate", Color(1.0, 0.78, 0.24, 1.0), 0.08)
	milestone_tween.tween_property(milestone_label, "scale", Vector2.ONE, 0.12)
	milestone_tween.chain().tween_interval(0.76)
	milestone_tween.chain().tween_property(milestone_label, "modulate", Color(1.0, 0.78, 0.24, 0.0), 0.32)
	milestone_tween.chain().tween_callback(func() -> void:
		if milestone_label != null:
			milestone_label.visible = false
			milestone_label.scale = Vector2.ONE
	)


func _on_combo_break_requested(combo_count: int) -> void:
	if combo_break_label == null or combo_count < 3:
		return
	if combo_break_tween != null and combo_break_tween.is_valid():
		combo_break_tween.kill()
	combo_break_label.text = "COMBO LOST x%d" % combo_count
	combo_break_label.visible = true
	combo_break_label.modulate = Color(0.86, 0.92, 0.96, 0.88)
	combo_break_label.position.y += 4.0
	combo_break_tween = create_tween()
	combo_break_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	combo_break_tween.set_parallel(true)
	combo_break_tween.tween_property(combo_break_label, "modulate", Color(0.86, 0.92, 0.96, 0.0), 0.72)
	combo_break_tween.tween_property(combo_break_label, "position:y", combo_break_label.position.y - 14.0, 0.72)
	combo_break_tween.chain().tween_callback(func() -> void:
		if combo_break_label != null:
			combo_break_label.visible = false
			_apply_responsive_layout()
	)


func _on_boss_intro_requested(boss_name: String) -> void:
	_play_boss_banner(boss_name, false)


func _on_boss_phase_transition_requested() -> void:
	_play_boss_banner("裂隙過熱  |  BOSS PHASE II", true)


func _play_boss_banner(message: String, phase_two: bool) -> void:
	if boss_intro_rect == null or boss_intro_label == null:
		return
	if boss_intro_tween != null and boss_intro_tween.is_valid():
		boss_intro_tween.kill()
	boss_intro_label.text = message
	boss_intro_label.visible = true
	boss_intro_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	var label_color := Color(1.0, 0.28, 0.36, 0.0) if phase_two else Color(1.0, 0.72, 0.34, 0.0)
	var dim_color := Color(0.24, 0.0, 0.045, 0.34) if phase_two else Color(0.0, 0.0, 0.0, 0.44)
	boss_intro_label.modulate = label_color
	boss_intro_label.scale = Vector2.ONE * 0.9
	boss_intro_tween = create_tween()
	boss_intro_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	boss_intro_tween.set_parallel(true)
	boss_intro_tween.tween_property(boss_intro_rect, "color", dim_color, 0.16)
	boss_intro_tween.tween_property(boss_intro_label, "modulate", Color(label_color.r, label_color.g, label_color.b, 1.0), 0.16)
	boss_intro_tween.tween_property(boss_intro_label, "scale", Vector2.ONE, 0.18)
	boss_intro_tween.chain().tween_interval(0.78 if phase_two else 0.56)
	boss_intro_tween.chain().tween_property(boss_intro_rect, "color", Color(0.0, 0.0, 0.0, 0.0), 0.28)
	boss_intro_tween.parallel().tween_property(boss_intro_label, "modulate", Color(label_color.r, label_color.g, label_color.b, 0.0), 0.28)
	boss_intro_tween.chain().tween_callback(func() -> void:
		if boss_intro_label != null:
			boss_intro_label.visible = false
	)


func set_screenshot_beauty_mode(enabled: bool) -> void:
	if enabled and not OS.is_debug_build():
		return
	screenshot_beauty_active = enabled
	GameManager.screenshot_beauty_mode = enabled
	if root != null:
		root.visible = not enabled
	print("SCREENSHOT_BEAUTY_%s hud_hidden=%s vfx_layers=%s" % [
		"ON" if enabled else "OFF",
		str(enabled),
		"4" if enabled else "adaptive"
	])


func _refresh_audio_prompt() -> void:
	if audio_prompt_button == null:
		return
	audio_prompt_button.visible = OS.has_feature("web") and AudioManager != null and not AudioManager.is_audio_unlocked()


func _sync_audio_controls() -> void:
	if AudioManager == null:
		return
	syncing_audio_controls = true
	if pause_volume_slider != null:
		pause_volume_slider.value = float(AudioManager.get("master_volume"))
	if pause_mute_check != null:
		pause_mute_check.button_pressed = bool(AudioManager.get("muted"))
	_refresh_quick_control_labels()
	syncing_audio_controls = false


func _sync_audio_controls_legacy_unused() -> void:
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
	if pause_force_joystick_check != null:
		pause_force_joystick_check.button_pressed = bool(PlayerSettings.get("force_joystick_visible"))
	if pause_joystick_size_slider != null:
		pause_joystick_size_slider.value = float(PlayerSettings.get("joystick_size_index"))
	if pause_joystick_size_label != null:
		pause_joystick_size_label.text = "搖桿大小：%s" % _joystick_size_label(int(PlayerSettings.get("joystick_size_index")))
	_refresh_quick_control_labels()
	syncing_settings_controls = false


func _sync_settings_controls_legacy_unused() -> void:
	if PlayerSettings == null:
		return
	syncing_settings_controls = true
	if pause_damage_numbers_check != null:
		pause_damage_numbers_check.button_pressed = bool(PlayerSettings.get("damage_numbers_enabled"))
	if pause_screen_shake_check != null:
		pause_screen_shake_check.button_pressed = bool(PlayerSettings.get("screen_shake_enabled"))
	if pause_force_joystick_check != null:
		pause_force_joystick_check.button_pressed = bool(PlayerSettings.get("force_joystick_visible"))
	if pause_high_contrast_check != null:
		pause_high_contrast_check.button_pressed = bool(PlayerSettings.get("high_contrast_enabled"))
	if pause_ui_scale_slider != null:
		pause_ui_scale_slider.value = float(PlayerSettings.get("ui_scale_index"))
	if pause_ui_scale_label != null:
		pause_ui_scale_label.text = "介面大小：%s" % _ui_scale_label(int(PlayerSettings.get("ui_scale_index")))
	if pause_joystick_size_slider != null:
		pause_joystick_size_slider.value = float(PlayerSettings.get("joystick_size_index"))
	if pause_joystick_size_label != null:
		pause_joystick_size_label.text = "搖桿大小：%s" % _joystick_size_label(int(PlayerSettings.get("joystick_size_index")))
	syncing_settings_controls = false
	_apply_accessibility_palette()


func _on_damage_numbers_toggled(value: bool) -> void:
	if syncing_settings_controls or PlayerSettings == null:
		return
	PlayerSettings.set_damage_numbers_enabled(value)


func _on_screen_shake_toggled(value: bool) -> void:
	if syncing_settings_controls or PlayerSettings == null:
		return
	PlayerSettings.set_screen_shake_enabled(value)


func _on_force_joystick_toggled(value: bool) -> void:
	if syncing_settings_controls or PlayerSettings == null:
		return
	PlayerSettings.set_force_joystick_visible(value)
	_apply_responsive_layout()


func _on_high_contrast_toggled(value: bool) -> void:
	if syncing_settings_controls or PlayerSettings == null:
		return
	PlayerSettings.set_high_contrast_enabled(value)
	_apply_responsive_layout()


func _on_ui_scale_slider_changed(value: float) -> void:
	if syncing_settings_controls or PlayerSettings == null:
		return
	var index := int(round(value))
	PlayerSettings.set_ui_scale_index(index)
	if pause_ui_scale_label != null:
		pause_ui_scale_label.text = "介面大小：%s" % _ui_scale_label(index)
	_apply_responsive_layout()


func _on_joystick_size_slider_changed(value: float) -> void:
	if syncing_settings_controls or PlayerSettings == null:
		return
	PlayerSettings.set_joystick_size_index(int(round(value)))
	if pause_joystick_size_label != null:
		pause_joystick_size_label.text = "搖桿大小：%s" % _joystick_size_label(int(round(value)))
	_refresh_quick_control_labels()
	_apply_responsive_layout()


func _on_joystick_size_slider_changed_legacy_unused(value: float) -> void:
	if syncing_settings_controls or PlayerSettings == null:
		return
	PlayerSettings.set_joystick_size_index(int(round(value)))
	if pause_joystick_size_label != null:
		pause_joystick_size_label.text = "搖桿大小：%s" % _joystick_size_label(int(round(value)))
	_apply_responsive_layout()


func _joystick_size_label(index: int) -> String:
	match clamp(index, 0, 2):
		0:
			return "小"
		2:
			return "大"
		_:
			return "中"


func _ui_scale_label(index: int) -> String:
	match clamp(index, 0, 2):
		0:
			return "精簡"
		2:
			return "大"
		_:
			return "標準"


func _joystick_size_label_legacy_unused(index: int) -> String:
	match clamp(index, 0, 2):
		0:
			return "小"
		2:
			return "大"
		_:
			return "中"


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
			pause_reset_meta_button.text = "再按一次確認重置"
		GameManager.show_toast("再按一次會清空殘響進度")
		return
	reset_meta_confirm_pending = false
	MetaProgress.reset_progress()
	if GameManager.has_method("apply_current_meta_progress_to_squad"):
		GameManager.apply_current_meta_progress_to_squad()
	if pause_reset_meta_button != null:
		pause_reset_meta_button.text = "重置殘響"
	GameManager.show_toast("殘響進度已重置")
	GameManager.emit_stats()


func _on_reset_meta_pressed_legacy_unused() -> void:
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
	if pause_achievements_grid == null or AchievementProgress == null or not AchievementProgress.has_method("get_display_rows"):
		return
	for child in pause_achievements_grid.get_children():
		pause_achievements_grid.remove_child(child)
		child.queue_free()
	for row in AchievementProgress.get_display_rows():
		pause_achievements_grid.add_child(_make_achievement_badge(row))
	if pause_content != null:
		_layout_pause_achievement_grid(pause_content.custom_minimum_size.x, MOBILE_TUNING.use_mobile_ui(get_viewport().get_visible_rect().size))


func _refresh_achievement_list_legacy_unused() -> void:
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
