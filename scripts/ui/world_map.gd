extends CanvasLayer

const CATALOG := preload("res://scripts/services/stage_catalog.gd")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const ANIMATION := preload("res://scripts/animation/true_animation_library.gd")
const MAP_PATH := "res://assets/art/r34/world_map.png"
const FALLBACK_MAP_PATH := "res://assets/art/r34/map_moon.png"
const INK := Color("101b30")
const GOLD := Color("e8c87e")
const TEXT := Color("eef2ff")

class RouteCanvas extends Control:
	var points: Array[Vector2] = []
	var cleared: Array[bool] = []
	var selected: int = -1
	func _draw() -> void:
		for index in range(points.size() - 1):
			var color := Color(0.86, 0.73, 0.44, 0.6)
			if index < cleared.size() and cleared[index]:
				color = Color(0.99, 0.86, 0.55, 0.95)
			draw_line(points[index], points[index + 1], Color(0.025, 0.035, 0.065, 0.8), 7.0, true)
			draw_line(points[index], points[index + 1], color, 2.2, true)
		for index in range(points.size()):
			if index == selected:
				draw_arc(points[index], 29.0, 0.0, TAU, 32, Color(1.0, 0.87, 0.52, 0.85), 2.0, true)

var root: Control
var map_texture: TextureRect
var map_source: String = ""
var header: Control
var title: Label
var subtitle: Label
var progress: Label
var graph: Control
var route: RouteCanvas
var portrait_scroll: ScrollContainer
var portrait_grid: GridContainer
var detail_panel: PanelContainer
var detail_title: Label
var detail_boss: Label
var detail_description: Label
var detail_status: Label
var footer: HBoxContainer
var back_button: Button
var start_button: Button
var endless_button: Button
var stages: Array[Dictionary] = []
var node_buttons: Array[Button] = []
var selected_id: String = ""
var portrait: bool = false
var compact: bool = false
var layout_size := Vector2(1280, 720)
var starting: bool = false
var probe_enabled: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	stages = CATALOG.get_stages()
	selected_id = str(GameManager.get("selected_stage_id"))
	if CATALOG.get_stage(selected_id).is_empty() and not stages.is_empty():
		selected_id = str(stages[0].get("id", "moon"))
	_build_ui()
	_apply_layout()
	_update_selection()
	get_viewport().size_changed.connect(_apply_layout)
	if OS.has_feature("web"):
		probe_enabled = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('cv_r22_test') === '1'", true))
	call_deferred("_publish_probe")


func _build_ui() -> void:
	root = Control.new()
	root.name = "WorldMapRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	map_texture = TextureRect.new()
	map_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_source = MAP_PATH if ResourceLoader.exists(MAP_PATH) else FALLBACK_MAP_PATH
	if ResourceLoader.exists(map_source):
		map_texture.texture = load(map_source)
	root.add_child(map_texture)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.04, 0.085, 0.36)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	header = Control.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)
	title = _label("世界地圖", 32, TEXT)
	subtitle = _label("選擇戰場，挑戰六位守關者", 14, Color("c7d3e8"))
	progress = _label("", 14, GOLD)
	header.add_child(title)
	header.add_child(subtitle)
	header.add_child(progress)

	graph = Control.new()
	graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(graph)
	route = RouteCanvas.new()
	route.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	route.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph.add_child(route)
	portrait_scroll = ScrollContainer.new()
	portrait_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	portrait_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	graph.add_child(portrait_scroll)
	portrait_grid = GridContainer.new()
	portrait_grid.columns = 2
	portrait_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_grid.add_theme_constant_override("h_separation", 12)
	portrait_grid.add_theme_constant_override("v_separation", 12)
	portrait_scroll.add_child(portrait_grid)
	for index in range(stages.size()):
		var button := Button.new()
		button.name = "Stage_" + str(stages[index].get("id", ""))
		button.text = ""
		button.clip_contents = true
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.set_meta("stage_id", str(stages[index].get("id", "")))
		button.tooltip_text = "%s\n守關者：%s\n難度 %s" % [str(stages[index].get("name", "")), str(stages[index].get("boss_name", "")), str(stages[index].get("difficulty", 1))]
		button.pressed.connect(_on_stage_pressed.bind(str(stages[index].get("id", ""))))
		_build_node_content(button, stages[index], index)
		graph.add_child(button)
		node_buttons.append(button)

	detail_panel = PanelContainer.new()
	detail_panel.name = "StageDetails"
	detail_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.06, 0.11, 0.94), Color(0.65, 0.55, 0.33, 0.65), 1))
	root.add_child(detail_panel)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 4)
	detail_panel.add_child(details)
	var detail_heading := HBoxContainer.new()
	details.add_child(detail_heading)
	detail_title = _label("", 23, TEXT)
	detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_heading.add_child(detail_title)
	detail_status = _label("", 13, GOLD)
	detail_heading.add_child(detail_status)
	detail_boss = _label("", 14, Color("cdd9ef"))
	details.add_child(detail_boss)
	detail_description = _label("", 15, Color("dbe2ef"))
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(detail_description)

	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)
	back_button = Button.new()
	back_button.text = "返回主選單"
	back_button.pressed.connect(_on_back_pressed)
	footer.add_child(back_button)
	start_button = Button.new()
	start_button.text = "正式出擊"
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.pressed.connect(_on_start_pressed)
	footer.add_child(start_button)
	endless_button = Button.new()
	endless_button.text = "無盡遠征"
	endless_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	endless_button.pressed.connect(_on_endless_pressed)
	footer.add_child(endless_button)
	endless_button.add_theme_stylebox_override("normal", _panel_style(Color("39316c"), Color("bba2ff"), 2))
	endless_button.add_theme_color_override("font_disabled_color", Color("b3bbca"))
	back_button.add_theme_stylebox_override("normal", _panel_style(Color(0.035, 0.06, 0.11, 0.88), Color(0.45, 0.55, 0.70), 1))
	start_button.add_theme_stylebox_override("normal", _panel_style(Color("b99546"), GOLD, 2))
	start_button.add_theme_color_override("font_color", INK)
	start_button.add_theme_color_override("font_hover_color", INK)
	start_button.add_theme_color_override("font_pressed_color", INK)
	for button in [back_button, start_button, endless_button]:
		button.add_theme_stylebox_override("focus", _panel_style(Color(0, 0, 0, 0), Color("fff0ba"), 3))
		button.add_theme_font_size_override("font_size", 19)


func _build_node_content(button: Button, stage: Dictionary, index: int) -> void:
	var icon := TextureRect.new()
	icon.name = "BossPortrait"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite_path := "res://assets/sprites/%s.png" % str(stage.get("boss_sprite", "enemy_boss"))
	var frames := ANIMATION.get_sprite_frames(sprite_path)
	if frames != null and frames.has_animation(&"idle"):
		icon.texture = frames.get_frame_texture(&"idle", 0)
	button.add_child(icon)
	var name_label := _label("%02d  %s" % [index + 1, str(stage.get("name", ""))], 16, TEXT)
	name_label.name = "StageName"
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_child(name_label)
	var boss_label := _label(str(stage.get("boss_name", "")), 13, Color("c7d3e8"))
	boss_label.name = "BossName"
	boss_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_child(boss_label)
	var difficulty := _label("", 12, GOLD)
	difficulty.name = "Difficulty"
	button.add_child(difficulty)


func _label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.035, 0.065, 0.9))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _panel_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 5
	return style


func _apply_layout() -> void:
	if root == null:
		return
	layout_size = MOBILE.apply_web_canvas_scale(self, get_viewport().get_visible_rect().size, root)
	portrait = layout_size.y > layout_size.x
	compact = layout_size.x < 1100 or layout_size.y < 580
	var compact_landscape := compact and not portrait
	var margin := 14.0 if compact else 28.0
	var header_height := 40.0 if compact_landscape else 58.0 if compact else 72.0
	var footer_height := 50.0 if compact else 56.0
	var detail_height := 150.0 if portrait else 104.0 if compact else 136.0
	var gap := 12.0 if compact else 18.0
	header.position = Vector2(margin, margin)
	header.size = Vector2(layout_size.x - margin * 2, header_height)
	title.position = Vector2.ZERO
	title.size = Vector2(header.size.x * 0.65, 36)
	title.add_theme_font_size_override("font_size", 25 if compact else 34)
	subtitle.position = Vector2(0, 37 if compact else 43)
	subtitle.visible = not compact_landscape
	subtitle.size = Vector2(header.size.x, 19)
	subtitle.add_theme_font_size_override("font_size", 12 if compact else 15)
	progress.position = Vector2(header.size.x - (122.0 if compact else 160.0), 10)
	progress.size = Vector2(122 if compact else 160, 24)
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress.add_theme_font_size_override("font_size", 13 if compact else 15)
	footer.position = Vector2(margin, layout_size.y - margin - footer_height)
	footer.size = Vector2(layout_size.x - margin * 2, footer_height)
	back_button.custom_minimum_size = Vector2(82 if layout_size.x < 800 else 142 if compact else 170, footer_height)
	back_button.text = "返回" if layout_size.x < 800 else "返回主選單"
	start_button.text = "出擊" if layout_size.x < 360 else "關卡出擊"
	start_button.custom_minimum_size = Vector2(80 if layout_size.x < 360 else 102, footer_height)
	endless_button.custom_minimum_size = Vector2(92 if layout_size.x < 360 else 102, footer_height)
	for button in [back_button, start_button, endless_button]:
		button.add_theme_font_size_override("font_size", 17 if compact else 20)
	detail_panel.position = Vector2(margin, footer.position.y - gap - detail_height)
	detail_panel.size = Vector2(layout_size.x - margin * 2, detail_height)
	detail_title.add_theme_font_size_override("font_size", 18 if compact else 25)
	detail_boss.add_theme_font_size_override("font_size", 12 if compact else 15)
	detail_description.add_theme_font_size_override("font_size", 13 if compact else 16)
	detail_status.add_theme_font_size_override("font_size", 11 if compact else 14)
	graph.position = Vector2(margin, header.position.y + header_height + gap)
	graph.size = Vector2(layout_size.x - margin * 2, maxf(80, detail_panel.position.y - gap - graph.position.y))
	portrait_scroll.visible = portrait
	route.visible = not portrait
	for button in node_buttons:
		var wanted_parent: Node = portrait_grid if portrait else graph
		if button.get_parent() != wanted_parent:
			button.reparent(wanted_parent, false)
	if portrait:
		portrait_grid.custom_minimum_size.x = graph.size.x - 12
		var width := (graph.size.x - 24) * 0.5
		var height := maxf(96, minf(142, (graph.size.y - 24) / 3.0))
		for button in node_buttons:
			button.custom_minimum_size = Vector2(width, height)
			_layout_node_content(button, Vector2(width, height))
	else:
		var node_size := Vector2(170, 98) if not compact else Vector2(146, 64)
		var positions: Array[Vector2] = []
		for stage in stages:
			var norm: Vector2 = stage.get("node_position", Vector2(0.5, 0.5))
			positions.append(Vector2(clampf(norm.x * graph.size.x, node_size.x * 0.5, graph.size.x - node_size.x * 0.5), clampf(norm.y * graph.size.y, node_size.y * 0.5, graph.size.y - node_size.y * 0.5)))
		if _positions_overlap(positions, node_size):
			positions.clear()
			for index in range(stages.size()):
				positions.append(Vector2(graph.size.x * (0.15 + float(index / 2) * 0.35), graph.size.y * (0.74 if index % 2 == 0 else 0.24)))
		route.points = positions
		for index in range(node_buttons.size()):
			var button := node_buttons[index]
			button.custom_minimum_size = node_size
			button.size = node_size
			button.position = positions[index] - node_size * 0.5
			_layout_node_content(button, node_size)
	_update_selection()
	call_deferred("_publish_probe")


func _positions_overlap(points: Array[Vector2], node_size: Vector2) -> bool:
	for first in range(points.size()):
		for second in range(first + 1, points.size()):
			if Rect2(points[first] - node_size * 0.5, node_size + Vector2(8, 8)).intersects(Rect2(points[second] - node_size * 0.5, node_size)):
				return true
	return false


func _layout_node_content(button: Button, box: Vector2) -> void:
	var icon := button.get_node("BossPortrait") as TextureRect
	var name_label := button.get_node("StageName") as Label
	var boss_label := button.get_node("BossName") as Label
	var difficulty := button.get_node("Difficulty") as Label
	var icon_size := 44.0 if compact else 60.0
	icon.position = Vector2(6, (box.y - icon_size) * 0.5)
	icon.size = Vector2(icon_size, icon_size)
	var text_x := icon_size + 9
	name_label.position = Vector2(text_x, maxf(5, box.y * 0.5 - 28))
	name_label.size = Vector2(box.x - text_x - 7, 20)
	name_label.add_theme_font_size_override("font_size", 13 if compact else 16)
	boss_label.position = name_label.position + Vector2(0, 23)
	boss_label.size = Vector2(name_label.size.x, 18)
	boss_label.add_theme_font_size_override("font_size", 11 if compact else 13)
	difficulty.position = boss_label.position + Vector2(0, 20)
	difficulty.size = Vector2(name_label.size.x, 16)
	difficulty.add_theme_font_size_override("font_size", 10 if compact else 12)


func _update_selection() -> void:
	if detail_title == null:
		return
	var cleared: Array = GameManager.get("campaign_clears")
	var clear_count := 0
	var selected_index := -1
	route.cleared.clear()
	for index in range(node_buttons.size()):
		var stage: Dictionary = stages[index]
		var is_clear := cleared.has(str(stage.get("id", "")))
		var chosen := str(stage.get("id", "")) == selected_id
		if is_clear:
			clear_count += 1
		if chosen:
			selected_index = index
		var accent: Color = stage.get("color", GOLD)
		var button := node_buttons[index]
		button.add_theme_stylebox_override("normal", _panel_style(Color(0.025, 0.045, 0.085, 0.87 if chosen else 0.69), GOLD if chosen else Color(accent, 0.70), 3 if chosen else 1))
		button.add_theme_stylebox_override("hover", _panel_style(Color(0.05, 0.08, 0.15, 0.92), accent.lightened(0.25), 2))
		button.add_theme_stylebox_override("pressed", _panel_style(Color(0.10, 0.13, 0.20, 0.98), GOLD, 3))
		button.add_theme_stylebox_override("focus", _panel_style(Color(0, 0, 0, 0), Color("fff0ba"), 3))
		var difficulty := button.get_node("Difficulty") as Label
		difficulty.text = "難度 %s%s" % [str(stage.get("difficulty", 1)), "　通關" if is_clear else ""]
		route.cleared.append(is_clear)
	progress.text = "已通關 %d／%d" % [clear_count, stages.size()]
	var selected := CATALOG.get_stage(selected_id)
	detail_title.text = str(selected.get("name", "選擇戰場"))
	detail_status.text = "已通關" if cleared.has(selected_id) else "可挑戰"
	endless_button.disabled = not cleared.has(selected_id) or starting
	endless_button.text = ("無盡" if layout_size.x < 360 else "無盡遠征") if cleared.has(selected_id) else "未解鎖"
	detail_boss.text = "守關者：%s  ·  難度 %s" % [str(selected.get("boss_name", "")), str(selected.get("difficulty", 1))]
	detail_description.text = str(selected.get("description", "選擇一個節點，準備出擊。"))
	if cleared.has(selected_id):
		var best: Dictionary = GameManager.endless_best.get(selected_id, {})
		detail_description.text += "\n無盡遠征已解鎖" + ("　紀錄：第 %d 波／%d 擊殺" % [int(best.get("wave", 0)), int(best.get("kills", 0))] if not best.is_empty() else "")
	else:
		detail_description.text += "\n擊敗此關守關者，解鎖對應無盡地圖。"
	start_button.disabled = selected.is_empty() or starting
	route.selected = selected_index
	route.queue_redraw()
	call_deferred("_publish_probe")


func _on_stage_pressed(stage_id: String) -> void:
	if starting or CATALOG.get_stage(stage_id).is_empty():
		return
	if not bool(GameManager.select_stage(stage_id)):
		return
	selected_id = stage_id
	_update_selection()
	AudioManager.play_sfx("pickup", false, -7.0, 1.04)


func _on_start_pressed() -> void:
	if start_button.disabled or starting:
		return
	starting = true
	_update_selection()
	GameManager.start_selected_stage()


func _on_endless_pressed() -> void:
	if endless_button.disabled or starting:
		return
	starting = true
	_update_selection()
	if not GameManager.start_endless_stage(selected_id):
		starting = false
		_update_selection()


func _on_back_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_on_back_pressed()
		get_viewport().set_input_as_handled()
	var index := int(event.keycode) - KEY_1
	if index >= 0 and index < stages.size():
		_on_stage_pressed(str(stages[index].get("id", "")))
		get_viewport().set_input_as_handled()


func _control_state(control: Control) -> Dictionary:
	var box := control.get_global_rect()
	return {"x": box.position.x, "y": box.position.y, "width": box.size.x, "height": box.size.y, "center_x": box.get_center().x, "center_y": box.get_center().y, "visible": control.is_visible_in_tree(), "disabled": control.disabled if control is BaseButton else false}


func get_debug_state() -> Dictionary:
	var nodes: Array[Dictionary] = []
	var cleared: Array = GameManager.get("campaign_clears")
	for button in node_buttons:
		var stage_id := str(button.get_meta("stage_id", ""))
		var entry := _control_state(button)
		entry.merge({"id": stage_id, "selected": stage_id == selected_id, "cleared": cleared.has(stage_id), "disabled": button.disabled})
		nodes.append(entry)
	return {"endless": _control_state(endless_button), "selected_stage_id": selected_id, "viewport_width": layout_size.x, "viewport_height": layout_size.y, "portrait": portrait, "compact": compact, "map_source": map_source, "nodes": nodes, "start": _control_state(start_button) if start_button != null else {}, "back": _control_state(back_button) if back_button != null else {}, "details": _control_state(detail_panel) if detail_panel != null else {}, "boss_name": detail_boss.text if detail_boss != null else "", "description": detail_description.text if detail_description != null else ""}


func _publish_probe() -> void:
	if OS.has_feature("web") and probe_enabled and root != null:
		JavaScriptBridge.eval("window.__cvR34WorldMap = %s" % JSON.stringify(get_debug_state()), true)
