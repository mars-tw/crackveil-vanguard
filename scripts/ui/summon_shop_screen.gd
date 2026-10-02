extends CanvasLayer

signal draw_requested(kind: String)
signal choice_selected(draw_id: String, index: int)
signal closed
const PET := preload("res://scripts/services/pet_catalog.gd")
const SKILL := preload("res://scripts/services/skill_catalog.gd")
const PREVIEW := preload("res://scripts/services/upgrade_preview.gd")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
var root: Control
var panel: PanelContainer
var column: VBoxContainer
var title: Label
var gold_label: Label
var message: Label
var scroll: ScrollContainer
var content: VBoxContainer
var draw_grid: GridContainer
var skill_button: Button
var pet_button: Button
var skill_reason: Label
var pet_reason: Label
var skill_odds: Label
var pet_odds: Label
var pet_grid: GridContainer
var choice_grid: GridContainer
var choice_buttons: Array[Button] = []
var close_button: Button
var director_ref: WeakRef
var current_draw_id := ""
var result_pet_name := ""
var layout_token := 0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	layer = 28
	_build()
	get_viewport().size_changed.connect(_layout)
	GameManager.stats_changed.connect(_on_stats)
	root.visible = false


func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.025,0.045,0.08,0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("101e32"), Color("c5a56f")))
	root.add_child(panel)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	title = _label("星紋召喚", 25, Color("f2d5a0"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	gold_label = _label("金幣 0", 19, Color("f4dc91"))
	head.add_child(gold_label)
	message = _label("只使用遊戲金幣。技能選一張立即提升；寵物收藏跨局保留。", 14)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	draw_grid = GridContainer.new()
	draw_grid.columns = 2
	draw_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draw_grid.add_theme_constant_override("h_separation", 12)
	draw_grid.add_theme_constant_override("v_separation", 10)
	content.add_child(draw_grid)
	var skill_box := VBoxContainer.new()
	skill_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draw_grid.add_child(skill_box)
	skill_button = _button("抽技能 · 80 金幣", Color("427da5"))
	skill_button.pressed.connect(func(): draw_requested.emit("skill"))
	skill_box.add_child(skill_button)
	skill_reason = _label("", 13, Color("f5b795"))
	skill_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_box.add_child(skill_reason)
	skill_odds = _label("", 13)
	skill_odds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_box.add_child(skill_odds)
	var pet_box := VBoxContainer.new()
	pet_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draw_grid.add_child(pet_box)
	pet_button = _button("抽寵物 · 120 金幣", Color("9a7652"))
	pet_button.pressed.connect(func(): draw_requested.emit("pet"))
	pet_box.add_child(pet_button)
	pet_reason = _label("", 13, Color("f5b795"))
	pet_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pet_box.add_child(pet_reason)
	pet_odds = _label("", 13)
	pet_odds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pet_box.add_child(pet_odds)
	choice_grid = GridContainer.new()
	choice_grid.columns = 3
	choice_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_grid.add_theme_constant_override("h_separation", 10)
	choice_grid.add_theme_constant_override("v_separation", 10)
	content.add_child(choice_grid)
	content.add_child(_label("寵物圖鑑 · 自動出戰，重複升星", 17, Color("b9e1e4")))
	pet_grid = GridContainer.new()
	pet_grid.columns = 3
	pet_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pet_grid.add_theme_constant_override("h_separation", 10)
	pet_grid.add_theme_constant_override("v_separation", 10)
	content.add_child(pet_grid)
	close_button = _button("返回戰場", Color("294359"))
	close_button.pressed.connect(func(): closed.emit())
	column.add_child(close_button)
	_layout()


func show_shop(director: Node) -> void:
	var old: Object = director_ref.get_ref() if director_ref != null else null
	if is_instance_valid(old) and old.is_connected("changed", Callable(self,"_refresh")):
		old.disconnect("changed", Callable(self,"_refresh"))
	if is_instance_valid(old) and old.is_connected("draw_committed", Callable(self,"_on_committed")):
		old.disconnect("draw_committed", Callable(self,"_on_committed"))
	director_ref = weakref(director)
	director.connect("changed", Callable(self,"_refresh"))
	director.connect("draw_committed", Callable(self,"_on_committed"))
	root.visible = true
	current_draw_id = ""
	draw_grid.visible = true
	_clear_choices()
	_refresh()
	_layout()
	var prepared: Dictionary = director.get_pending_result()
	if not prepared.is_empty() and str(prepared.get("kind","")) == "skill":
		show_result(prepared)


func hide_shop() -> void:
	root.visible = false
	current_draw_id = ""
	_clear_choices()


func show_result(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		message.text = str(result.get("reason", "抽取未完成，沒有扣款。"))
		_refresh()
		return
	if str(result.get("kind", "")) == "pet":
		var pet: Dictionary = result.pet
		result_pet_name = str(pet.name)
		message.text = "%s%s · %d 星 · 傷害與回復倍率 %.2f" % ["獲得新夥伴：" if bool(pet.new) else "重複寵物升星：", str(pet.name), int(pet.stars), PET.star_multiplier(int(pet.stars))]
	else:
		current_draw_id = str(result.draw_id)
		draw_grid.visible = false
		message.text = "已付 80 金幣，請選一張。離開時自動取得第一張，不會再扣一次。"
		_show_choices(result.get("choice_options", []))
	_refresh()
	_layout()


func clear_result() -> void:
	current_draw_id = ""
	_clear_choices()
	_refresh()


func _on_committed(result: Dictionary) -> void:
	message.text = str(result.get("message", "召喚完成。"))
	if str(result.get("kind", "")) == "pet":
		result_pet_name = str(result.pet.name)


func _director() -> Node:
	return director_ref.get_ref() as Node if director_ref != null else null


func _refresh(_unused: Dictionary = {}) -> void:
	var director := _director()
	if not is_instance_valid(director):
		return
	var state: Dictionary = _unused if not _unused.is_empty() else director.get_debug_state()
	gold_label.text = "金幣 %d" % GameManager.gold
	var can_skill: Dictionary = director.can_draw("skill")
	var can_pet: Dictionary = director.can_draw("pet")
	skill_button.disabled = not bool(can_skill.ok)
	pet_button.disabled = not bool(can_pet.ok)
	skill_reason.text = str(can_skill.reason)
	pet_reason.text = str(can_pet.reason)
	var qualitative_percent := int(state.skill_qualitative_percent)
	skill_odds.text = "每抽 1 張法術卡，未滿級法術等機率；另 2 張戰術 %d%%／質變 %d%%。\n已抽 %d 次 · 再 %d 抽保底質變卡（需有合法質變）。" % [100-qualitative_percent, qualitative_percent, int(state.skill_draws), int(state.skill_pity_remaining)]
	if bool(state.skill_pity_active):
		skill_odds.text += "\n本抽保底位：質變 100%。"
	if not bool(state.skill_qualitative_available):
		skill_odds.text += "\n目前無合法質變，保底進度保留。"
	skill_odds.text += "\n同類候選等機率；耗盡的一類由剩餘合法候選補足。"
	var spell_lines := PackedStringArray()
	for chance in state.spell_odds:
		spell_lines.append("%s %.2f%%" % [str(chance.name), float(chance.percent)])
	if not spell_lines.is_empty():
		skill_odds.text += "\n法術位：" + " · ".join(spell_lines)
	var lines := PackedStringArray()
	for chance in state.pet_odds:
		lines.append("%s %.2f%%" % [str(chance.name), float(chance.percent)])
	pet_odds.text = "本次機率：%s\n已抽 %d 次 · 再 %d 抽保底未擁有寵物。\n每星傷害／回復 +35%%、施放速度 +8%%，最高 5 星。" % [" · ".join(lines), int(state.pet_draws), int(state.pet_pity_remaining)]
	if (state.collection as Dictionary).size() == 3:
		pet_odds.text = pet_odds.text.replace("再 %d 抽保底未擁有寵物。" % int(state.pet_pity_remaining), "三種已集滿，重複會升星。")
	_refresh_pet_cards(state.collection)


func _refresh_pet_cards(collection: Dictionary) -> void:
	for child in pet_grid.get_children():
		pet_grid.remove_child(child)
		child.queue_free()
	for id in PET.IDS:
		var data := PET.get_pet(id)
		var box := PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_stylebox_override("panel", _style(Color("14283b"), data.color))
		var stack := VBoxContainer.new()
		box.add_child(stack)
		var portrait := TextureRect.new()
		var frames: SpriteFrames = PET.get_frames(id)
		portrait.texture = frames.get_frame_texture(&"idle",0) if frames != null else null
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(82,82)
		stack.add_child(portrait)
		var stars := int(collection.get(id,0))
		stack.add_child(_label("%s · %s" % [str(data.name), "%d 星" % stars if stars > 0 else "未取得"],15,data.color))
		var description := _label(str(data.description),12)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(description)
		if stars > 0:
			var benefit := _label("當前基礎傷害 %.1f／間隔 %.2f 秒" % [float(data.damage)*PET.star_multiplier(stars),float(data.cooldown)*PET.cooldown_multiplier(stars)],12,data.color)
			benefit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stack.add_child(benefit)
		pet_grid.add_child(box)


func _show_choices(options: Array) -> void:
	_clear_choices()
	for index in range(options.size()):
		var option: Dictionary = options[index]
		var button := _button("", Color("657eaf"))
		button.custom_minimum_size.y = 190
		button.pressed.connect(func(): choice_selected.emit(current_draw_id,index))
		var stack := VBoxContainer.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_theme_constant_override("separation",8)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left","right","top","bottom"]:
			margin.add_theme_constant_override("margin_"+side,12)
		button.add_child(margin)
		margin.add_child(stack)
		if str(option.get("id","")) == "summon_skill":
			var icon := TextureRect.new()
			icon.texture = SKILL.get_icon(str(option.skill_id))
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size.y = 52
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stack.add_child(icon)
		var name_label := _label(str(option.get("name","技能")),18,Color("f1dfac"))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(name_label)
		var text := str(option.get("description","")) if str(option.get("id","")) == "summon_skill" else PREVIEW.describe(option)
		var description := _label(text,13)
		description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(description)
		choice_grid.add_child(button)
		choice_buttons.append(button)
	scroll.scroll_vertical = 0


func _clear_choices() -> void:
	for child in choice_grid.get_children():
		choice_grid.remove_child(child)
		child.queue_free()
	choice_buttons.clear()


func _label(value: String, size: int, color: Color = Color("d9e9ee")) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	return label


func _button(value: String, border: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0,48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",18)
	button.add_theme_stylebox_override("normal",_style(Color("20354b"),border))
	button.add_theme_stylebox_override("hover",_style(Color("2b4963"),Color("f3d4a1")))
	button.add_theme_stylebox_override("pressed",_style(Color("3a5264"),Color("ffd98c")))
	button.add_theme_stylebox_override("disabled",_style(Color("172638"),Color("43566b")))
	return button


func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _layout() -> void:
	if panel == null:
		return
	var raw_size := get_viewport().get_visible_rect().size
	var size := MOBILE.apply_web_canvas_scale(self,raw_size,root)
	var portrait := size.x < 600
	var margin := 10.0 if size.x < 900 else 28.0
	var width := minf(size.x-margin*2,1100.0)
	panel.position = Vector2((size.x-width)*0.5,margin)
	panel.size = Vector2(width,size.y-margin*2)
	draw_grid.columns = 1 if portrait else 2
	choice_grid.columns = 1 if portrait else 3
	pet_grid.columns = 1 if portrait else 3
	title.add_theme_font_size_override("font_size",20 if size.y < 450 else 25)
	column.add_theme_constant_override("separation",7 if size.y < 450 else 10)
	layout_token += 1
	_settle_layout(layout_token)


func _settle_layout(token: int) -> void:
	# Fresh wrapped labels initially report their height at width zero. Let
	# Container layout allocate widths before clamping the outer panel again.
	await get_tree().process_frame
	await get_tree().process_frame
	if token != layout_token or not is_inside_tree() or get_viewport() == null:
		return
	var size := MOBILE.ui_layout_size(get_viewport().get_visible_rect().size)
	var margin := 10.0 if size.x < 900 else 28.0
	panel.size = Vector2(minf(size.x-margin*2,1100.0),size.y-margin*2)
	for button in choice_buttons:
		var margin_box: MarginContainer = button.get_child(0) as MarginContainer
		var stack: VBoxContainer = margin_box.get_child(0) as VBoxContainer
		button.custom_minimum_size.y = maxf(190.0,stack.get_combined_minimum_size().y+24.0)
	await get_tree().process_frame
	await get_tree().process_frame
	if token == layout_token and is_inside_tree() and root.visible:
		# Opening pauses the game. Publish settled CSS coordinates instead of
		# leaving the HUD read-only snapshot at the pre-Container geometry.
		GameManager.emit_stats()


func _on_stats(_stats: Dictionary) -> void:
	if root.visible:
		gold_label.text = "金幣 %d" % GameManager.gold


func get_debug_state() -> Dictionary:
	var choices: Array[Dictionary] = []
	for button in choice_buttons:
		choices.append(_control_state(button))
	return {"visible":root.visible, "draw_id":current_draw_id, "skill_disabled":skill_button.disabled, "pet_disabled":pet_button.disabled, "skill_reason":skill_reason.text, "pet_reason":pet_reason.text, "choice_count":choice_buttons.size(), "panel_rect":panel.get_global_rect(), "scroll_rect":scroll.get_global_rect(), "close_rect":close_button.get_global_rect(), "viewport":MOBILE.ui_layout_size(get_viewport().get_visible_rect().size), "last_pet":result_pet_name, "controls":{"skill_draw":_control_state(skill_button), "pet_draw":_control_state(pet_button), "close":_control_state(close_button), "choices":choices, "scroll":_control_state(scroll)}}


func _control_state(control: Control) -> Dictionary:
	var rect := control.get_global_rect()
	return {"visible":control.is_visible_in_tree(), "disabled":control.disabled if control is Button else false, "x":rect.position.x, "y":rect.position.y, "width":rect.size.x, "height":rect.size.y, "center_x":rect.get_center().x, "center_y":rect.get_center().y}
