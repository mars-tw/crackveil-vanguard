extends CanvasLayer

signal restart_requested

var root: Control
var panel: Panel
var restart_button: Button
var summary_label: Label


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
	restart_button.text = "再來一局"
	restart_button.pressed.connect(_on_restart_pressed)
	panel.add_child(restart_button)
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
	root.visible = true


func _on_restart_pressed() -> void:
	root.visible = false
	restart_requested.emit()


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


func _apply_responsive_layout() -> void:
	if panel == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var portrait := viewport_size.y > viewport_size.x
	var panel_width: float = min(viewport_size.x - 32.0, 600.0)
	var panel_height: float = 500.0 if portrait else 430.0

	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5

	if summary_label != null:
		summary_label.offset_left = 32.0
		summary_label.offset_right = -32.0
		summary_label.offset_top = 88.0
		summary_label.offset_bottom = panel_height - 118.0
		summary_label.add_theme_font_size_override("font_size", 17 if not portrait else 16)

	if restart_button != null:
		restart_button.anchor_left = 0.5
		restart_button.anchor_right = 0.5
		restart_button.offset_left = -118.0
		restart_button.offset_right = 118.0
		restart_button.offset_top = panel_height - 92.0
		restart_button.offset_bottom = panel_height - 38.0
