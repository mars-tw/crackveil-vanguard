extends Control

const CATALOG := preload("res://scripts/services/equipment_catalog.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")

var service: Node = null
var buttons: Array[Button] = []
var slot_row: HBoxContainer = null
var details: PanelContainer = null
var details_label: Label = null
var cached_stats: Dictionary = {}
var compact: bool = false
var inspected_slot: int = -1
var appearance_signature: String = ""
var counter_signature: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300, 36)
	_build_ui()
	if not GameManager.stats_changed.is_connected(update_from_stats):
		GameManager.stats_changed.connect(update_from_stats)
	update_from_stats(GameManager.get_stats())


func configure(loot_service: Node) -> void:
	if service != null and is_instance_valid(service) and service.equipment_changed.is_connected(update_from_stats):
		service.equipment_changed.disconnect(update_from_stats)
	service = loot_service
	if service != null and is_instance_valid(service):
		service.equipment_changed.connect(update_from_stats)
		if is_node_ready():
			update_from_stats(service.get_stats())


func _build_ui() -> void:
	slot_row = HBoxContainer.new()
	slot_row.name = "EquipmentSlots"
	slot_row.add_theme_constant_override("separation", 5)
	slot_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(slot_row)
	for index in range(CATALOG.SLOTS.size()):
		var button := Button.new()
		button.name = "Slot_" + CATALOG.SLOTS[index]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(92, 36)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_inspect_slot.bind(index))
		slot_row.add_child(button)
		buttons.append(button)
	details = PanelContainer.new()
	details.name = "EquipmentDetails"
	details.position = Vector2(0, 44)
	details.custom_minimum_size = Vector2(300, 0)
	details.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.09, 0.97)
	style.border_color = Color(0.25, 0.48, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	details.add_theme_stylebox_override("panel", style)
	add_child(details)
	details_label = Label.new()
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.custom_minimum_size = Vector2(270, 0)
	details_label.add_theme_font_size_override("font_size", 13)
	details_label.add_theme_color_override("font_color", Color(0.87, 0.93, 0.98))
	details.add_child(details_label)
	details.hide()


func set_compact(enabled: bool) -> void:
	compact = enabled
	if is_node_ready():
		update_from_stats(cached_stats)


func update_from_stats(stats: Dictionary) -> void:
	if stats.has("game_running"):
		visible = bool(stats.get("game_running", false)) and not bool(stats.get("is_game_over", false)) and not bool(stats.get("manual_pause_visible", false)) and not bool(stats.get("system_paused", false))
		if not visible and details != null:
			details.hide()
			inspected_slot = -1
	if not stats.has("equipment_slots"):
		return
	cached_stats.merge(stats, true)
	if buttons.is_empty():
		return
	var equipped: Array = cached_stats.get("equipment_slots", [])
	var current_signature := str(compact)
	for item_value in equipped:
		current_signature += "|%s:%s:%s" % [str(item_value.get("uid", 0)), str(item_value.get("rarity", -1)), str(item_value.get("name", ""))]
	var current_counter_signature := "%d:%d" % [int(cached_stats.get("equipment_collected", 0)), int(cached_stats.get("equipment_salvaged", 0))]
	if current_signature == appearance_signature:
		if current_counter_signature != counter_signature:
			for index in range(buttons.size()):
				buttons[index].tooltip_text = _describe_slot(index)
			if inspected_slot >= 0:
				details_label.text = _describe_slot(inspected_slot)
		counter_signature = current_counter_signature
		return
	appearance_signature = current_signature
	counter_signature = current_counter_signature
	for index in range(buttons.size()):
		var item: Dictionary = equipped[index] if index < equipped.size() else {}
		var slot_name := str(CATALOG.SLOT_NAMES[CATALOG.SLOTS[index]])
		if compact and CATALOG.SLOTS[index] == "core":
			slot_name = "核心"
		var tier := int(item.get("rarity", -1))
		var accent := CATALOG.RARITY_COLORS[tier] if tier >= 0 else Color(0.42, 0.52, 0.6)
		buttons[index].text = "%s · %s" % [slot_name, str(item.get("rarity_name", "空"))] if compact else str(item.get("name", slot_name + " · 空"))
		if tier < 0:
			buttons[index].text = slot_name + " · 空"
		buttons[index].tooltip_text = _describe_slot(index)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025, 0.05, 0.075, 0.92)
		style.border_color = Color(accent, 0.86)
		style.set_border_width_all(1 if tier < 2 else 2)
		style.set_corner_radius_all(5)
		style.content_margin_left = 7
		style.content_margin_right = 7
		buttons[index].add_theme_stylebox_override("normal", style)
		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = style.bg_color.lightened(0.1)
		buttons[index].add_theme_stylebox_override("hover", hover)
		buttons[index].add_theme_stylebox_override("pressed", hover)
		buttons[index].add_theme_color_override("font_color", accent.lightened(0.25))
	if inspected_slot >= 0:
		details_label.text = _describe_slot(inspected_slot)
		call_deferred("_position_details")


func _inspect_slot(index: int) -> void:
	if inspected_slot == index:
		inspected_slot = -1
		details.hide()
		return
	inspected_slot = index
	details_label.text = _describe_slot(index)
	# Expand leftward if the caller anchors the equipment row near screen-right.
	details.size.x = maxf(300, size.x)
	details.position.x = minf(0, size.x - details.size.x)
	details.show()
	call_deferred("_position_details")


func _position_details() -> void:
	if details == null:
		return
	# The HUD uses CSS/logical coordinates even when the Web canvas has a
	# larger DPR backing buffer. Compare positions in that same coordinate space.
	var screen_height := MOBILE_TUNING.ui_layout_size(get_viewport().get_visible_rect().size).y
	var up := get_global_rect().position.y > screen_height * 0.5
	details.position.y = -details.get_combined_minimum_size().y - 8.0 if up else size.y + 8.0


func _describe_slot(index: int) -> String:
	var equipped: Array = cached_stats.get("equipment_slots", [])
	var item: Dictionary = equipped[index] if index < equipped.size() else {}
	var slot_name := str(CATALOG.SLOT_NAMES[CATALOG.SLOTS[index]])
	var text := slot_name + " · 尚未裝備\n菁英必掉稀有以上，Boss 必掉傳說。"
	if int(item.get("rarity", -1)) >= 0:
		text = "%s %s · 裝備等級 %d\n%s" % [str(item.get("rarity_name", "")), str(item.get("name", "")), int(item.get("item_level", 1)), str(item.get("description", ""))]
	return text + "\n\n較強的同槽裝備自動換上；較弱的拆成金幣。\n本局已拾取 %d 件 · 拆解 %d 件\n再點此槽關閉" % [int(cached_stats.get("equipment_collected", 0)), int(cached_stats.get("equipment_salvaged", 0))]
