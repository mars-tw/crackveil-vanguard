extends VBoxContainer

signal stage_requested(stage_id: String)
signal content_refreshed
const STAGES := preload("res://scripts/services/stage_catalog.gd")
var stage_index := 0

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	var stages := STAGES.get_stages()
	for index in range(stages.size()):
		if str(stages[index].id) == GameManager.selected_stage_id:
			stage_index = index
	refresh()

func _text(value: String, font_size: int = 15) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button

func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var rows: Array = MetaProgress.get_expedition_rows()
	var complete := 0
	for row in rows:
		if row.status == "completed": complete += 1
	add_child(_text("遠征紀錄 %d／%d\n正式出擊・單局最佳・獎勵限領一次" % [complete, rows.size()], 14))
	if not GameManager.pending_expedition_settlements.is_empty():
		add_child(_text("上次任務進度尚未存妥，獎勵還未入帳。", 14))
		var retry := _button("重試保存任務進度")
		retry.pressed.connect(func(): GameManager.retry_expedition_settlements(); refresh())
		add_child(retry)
	var stage: Dictionary = STAGES.get_stages()[stage_index]
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 8)
	var previous := _button("上一關")
	var next := _button("下一關")
	previous.pressed.connect(func(): stage_index = posmod(stage_index - 1, STAGES.get_stages().size()); refresh())
	next.pressed.connect(func(): stage_index = posmod(stage_index + 1, STAGES.get_stages().size()); refresh())
	navigation.add_child(previous)
	navigation.add_child(next)
	add_child(navigation)
	add_child(_text("%02d／%02d　%s" % [stage_index + 1, STAGES.get_stages().size(), stage.name], 19))
	for row in rows:
		if str(row.stage_id) != str(stage.id): continue
		var card := PanelContainer.new()
		card.name = str(row.id)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("102438")
		style.border_color = Color("8ae0b2") if row.status == "completed" else Color("668fae")
		style.set_border_width_all(1)
		style.set_content_margin_all(12)
		card.add_theme_stylebox_override("panel", style)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 7)
		card.add_child(body)
		body.add_child(_text(str(row.name), 17))
		var reward_text := "已完成・殘響 %d 已領取" % int(row.reward) if row.status == "completed" else "最佳 %d／%d・殘響 +%d" % [int(row.progress), int(row.target), int(row.reward)]
		body.add_child(_text(reward_text, 14))
		body.add_child(_text(str(row.description), 15))
		var progress := ProgressBar.new()
		progress.custom_minimum_size.y = 14
		progress.max_value = maxf(1.0, float(row.target))
		progress.value = float(row.progress)
		progress.show_percentage = false
		body.add_child(progress)
		if row.status == "completed": body.add_child(_text(str(row.get("lore", "")), 13))
		add_child(card)
	add_child(_text("結算時自動保存並領獎。種子練習與無盡不列入。", 13))
	var travel := _button("在地圖查看此戰場")
	travel.pressed.connect(func(): stage_requested.emit(str(stage.id)))
	add_child(travel)
	content_refreshed.emit()
