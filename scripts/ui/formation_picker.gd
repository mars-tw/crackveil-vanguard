extends PanelContainer

signal selected(formation: String)
var buttons: Dictionary = {}
var cancel_button: Button
var title: Label
var column: VBoxContainer
var touch_index := -1
var touch_button: Button
var touch_id := ""

func _ready() -> void:
	name = "FormationPicker"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 10)
	add_child(margin)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	title = Label.new()
	title.text = "選擇陣形"
	title.add_theme_font_size_override("font_size", 16)
	column.add_child(title)
	for id in ["wedge", "ring", "scatter"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(260, 48)
		button.add_theme_font_size_override("font_size", 14)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: selected.emit(id))
		column.add_child(button)
		buttons[id] = button
	cancel_button = Button.new()
	cancel_button.text = "取消"
	cancel_button.custom_minimum_size.y = 44
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(hide)
	column.add_child(cancel_button)
	hide()

func refresh(squad: Node) -> void:
	# HUD's general accessibility pass enlarges all descendants. This compact
	# thumb menu uses explicit CSS-equivalent sizes, like the phone battle HUD.
	title.add_theme_font_size_override("font_size", 16)
	column.add_theme_constant_override("separation", 4)
	cancel_button.add_theme_font_size_override("font_size", 14)
	cancel_button.custom_minimum_size = Vector2(260,44)
	cancel_button.reset_size()
	var cooldown: float = squad.get_formation_cooldown_remaining()
	title.text = "選擇陣形" if cooldown <= 0.0 else "換陣冷卻 %.1f 秒" % cooldown
	for id in buttons:
		var definition: Dictionary = squad.get_formation_definition(id)
		var current: bool = squad.get_formation_id() == id
		buttons[id].text = ("[目前] " if current else "") + str(definition.short) + "｜" + str(definition.effect).replace(" ", "")
		buttons[id].add_theme_font_size_override("font_size",14)
		buttons[id].custom_minimum_size = Vector2(260,48)
		buttons[id].reset_size()
		buttons[id].disabled = current or cooldown > 0.0
		buttons[id].add_theme_color_override("font_color", definition.color.lightened(0.3))

func _input(event: InputEvent) -> void:
	if not visible:
		_clear_touch()
		return
	var point := Vector2.ZERO
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		point = get_canvas_transform().affine_inverse() * event.position
	if event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed:
			if not get_global_rect().has_point(point):
				hide()
				return
			for id in ["wedge", "ring", "scatter", "cancel"]:
				var button: Button = cancel_button if id == "cancel" else buttons[id]
				if button.get_global_rect().has_point(point) and not button.disabled and touch_index == -1:
					touch_index = event.index
					touch_button = button
					touch_id = id
					button.set_pressed_no_signal(true)
					get_viewport().set_input_as_handled()
		elif event.index == touch_index:
			var commit: bool = is_instance_valid(touch_button) and touch_button.get_global_rect().has_point(point) and not touch_button.disabled
			var id := touch_id
			_clear_touch()
			if commit:
				if id == "cancel":
					hide()
				else:
					selected.emit(id)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not get_global_rect().has_point(point):
		# Native ScreenTouch owns a touch gesture. Its emulated mouse must not
		# cancel a second finger's picker interaction at the joystick position.
		if event.device != -1:
			hide()

func _clear_touch() -> void:
	if is_instance_valid(touch_button):
		touch_button.set_pressed_no_signal(false)
	touch_index = -1
	touch_button = null
