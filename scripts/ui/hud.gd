extends CanvasLayer

const VIRTUAL_JOYSTICK_SCENE := preload("res://scripts/ui/virtual_joystick.gd")

var root: Control
var hp_label: Label
var level_label: Label
var xp_bar: ProgressBar
var time_label: Label
var score_label: Label
var pause_button: Button
var version_label: Label
var audio_prompt_button: Button
var toast_panel: Panel
var toast_label: Label
var pause_overlay: Panel
var pause_volume_label: Label
var pause_volume_slider: HSlider
var pause_mute_check: CheckBox
var virtual_joystick: Control
var force_touch_controls_visible: bool = false
var syncing_audio_controls: bool = false
var toast_token: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	if not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)

	if not GameManager.stats_changed.is_connected(_on_stats_changed):
		GameManager.stats_changed.connect(_on_stats_changed)
	if not GameManager.pause_changed.is_connected(_on_pause_changed):
		GameManager.pause_changed.connect(_on_pause_changed)
	if GameManager.has_signal("toast_requested") and not GameManager.toast_requested.is_connected(_on_toast_requested):
		GameManager.toast_requested.connect(_on_toast_requested)
	if AudioManager != null and AudioManager.has_signal("settings_changed") and not AudioManager.settings_changed.is_connected(_sync_audio_controls):
		AudioManager.settings_changed.connect(_sync_audio_controls)
	if AudioManager != null and AudioManager.has_signal("audio_unlocked") and not AudioManager.audio_unlocked.is_connected(_refresh_audio_prompt):
		AudioManager.audio_unlocked.connect(_refresh_audio_prompt)

	_on_stats_changed(GameManager.get_stats())
	_refresh_audio_prompt()


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

	hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.position = Vector2(16.0, 12.0)
	hp_label.add_theme_font_size_override("font_size", 20)
	root.add_child(hp_label)

	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.position = Vector2(16.0, 42.0)
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

	toast_panel = Panel.new()
	toast_panel.name = "ToastPanel"
	toast_panel.visible = false
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
	toast_panel.add_child(toast_label)

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
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 18.0
	title.offset_bottom = 50.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	pause_overlay.add_child(title)

	pause_volume_label = Label.new()
	pause_volume_label.text = "音量"
	pause_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_overlay.add_child(pause_volume_label)

	pause_volume_slider = HSlider.new()
	pause_volume_slider.min_value = 0.0
	pause_volume_slider.max_value = 1.0
	pause_volume_slider.step = 0.05
	pause_volume_slider.value_changed.connect(_on_volume_slider_changed)
	pause_overlay.add_child(pause_volume_slider)

	pause_mute_check = CheckBox.new()
	pause_mute_check.text = "靜音"
	pause_mute_check.toggled.connect(_on_mute_toggled)
	pause_overlay.add_child(pause_mute_check)

	var resume_button := Button.new()
	resume_button.text = "繼續"
	resume_button.anchor_left = 0.5
	resume_button.anchor_right = 0.5
	resume_button.offset_left = -70.0
	resume_button.offset_right = 70.0
	resume_button.offset_top = 186.0
	resume_button.offset_bottom = 226.0
	resume_button.pressed.connect(_on_resume_button_pressed)
	pause_overlay.add_child(resume_button)
	_sync_audio_controls()


func _build_virtual_joystick() -> void:
	virtual_joystick = VIRTUAL_JOYSTICK_SCENE.new()
	virtual_joystick.name = "VirtualJoystick"
	virtual_joystick.connect("direction_changed", Callable(self, "_on_virtual_joystick_changed"))
	root.add_child(virtual_joystick)


func _apply_responsive_layout() -> void:
	if root == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var portrait := viewport_size.y > viewport_size.x
	var margin := 14.0

	hp_label.position = Vector2(margin, 10.0)
	hp_label.add_theme_font_size_override("font_size", 18 if portrait else 20)
	level_label.position = Vector2(margin, 38.0)
	level_label.add_theme_font_size_override("font_size", 14 if portrait else 16)
	xp_bar.position = Vector2(margin, 64.0)
	xp_bar.size = Vector2(min(viewport_size.x * (0.58 if portrait else 0.32), 300.0), 14.0)

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
		var overlay_width: float = min(viewport_size.x - 40.0, 330.0)
		var overlay_height := 262.0
		pause_overlay.anchor_left = 0.5
		pause_overlay.anchor_right = 0.5
		pause_overlay.anchor_top = 0.5
		pause_overlay.anchor_bottom = 0.5
		pause_overlay.offset_left = -overlay_width * 0.5
		pause_overlay.offset_right = overlay_width * 0.5
		pause_overlay.offset_top = -overlay_height * 0.5
		pause_overlay.offset_bottom = overlay_height * 0.5

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


func _on_toast_requested(message: String) -> void:
	if toast_panel == null or toast_label == null:
		return
	toast_token += 1
	var current_token := toast_token
	toast_label.text = message
	toast_panel.visible = true
	await get_tree().create_timer(1.5, true).timeout
	if current_token == toast_token and toast_panel != null:
		toast_panel.visible = false


func _build_version_text() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", "dev"))
	var build_date := str(ProjectSettings.get_setting("application/config/build_date", "local"))
	return "v%s  %s" % [version, build_date]
