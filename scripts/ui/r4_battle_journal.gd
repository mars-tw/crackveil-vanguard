extends Control

const FONT:=preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
const PROBE:=preload("res://scripts/services/qa_bridge.gd")
var entries: Array[Dictionary]=[]
var total:=0
var page:=0
var button: Button
var overlay: CanvasLayer
var backdrop: Control
var panel: Panel
var heading: Label
var facts: Array[Label]=[]
var controls: Dictionary={}

func _ready() -> void:
	process_mode=PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_theme_font_override("font",FONT)
	button=Button.new()
	button.text="戰報 0"
	button.add_theme_font_size_override("font_size",12)
	button.custom_minimum_size=Vector2(100,44)
	_compact_style(button)
	button.pressed.connect(open)
	add_child(button)
	controls["open"]=button
	overlay=CanvasLayer.new()
	overlay.layer=28
	add_child(overlay)
	backdrop=Control.new()
	backdrop.add_theme_font_override("font",FONT)
	overlay.add_child(backdrop)
	var dim:=ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color=Color(0.01,0.02,0.04,0.94)
	backdrop.add_child(dim)
	panel=Panel.new()
	backdrop.add_child(panel)
	heading=Label.new()
	heading.add_theme_font_size_override("font_size",20)
	panel.add_child(heading)
	for number in range(3):
		var label:=Label.new()
		label.add_theme_font_size_override("font_size",13)
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(label)
		facts.append(label)
	for id in ["previous","next","close"]:
		var control:=Button.new()
		control.text={"previous":"上一頁","next":"下一頁","close":"返回戰場"}[id]
		control.add_theme_font_size_override("font_size",14)
		control.custom_minimum_size=Vector2(44,44)
		_compact_style(control)
		panel.add_child(control)
		controls[id]=control
	controls.close.pressed.connect(close)
	controls.previous.pressed.connect(func():page=posmod(page-1,_pages());_refresh())
	controls.next.pressed.connect(func():page=posmod(page+1,_pages());_refresh())
	backdrop.hide()
	get_viewport().size_changed.connect(_layout)
	PlayerSettings.settings_changed.connect(_layout)
	_layout()

func _compact_style(button: Button) -> void:
	for state in ["normal","hover","focus","pressed","disabled"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("102235")
		style.border_color=Color("ffdc82") if state in ["focus","pressed"] else Color("77cdda")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left=4;style.content_margin_right=4
		style.content_margin_top=2;style.content_margin_bottom=2
		button.add_theme_stylebox_override(state,style)

func record(message: String,kind: String="general",urgent: bool=false) -> void:
	if message.is_empty():return
	total+=1
	var found:=-1
	for number in range(entries.size()):
		if entries[number].text==message and entries[number].kind==kind:found=number;break
	if found>=0:
		entries[found].count+=1
		entries[found].last=GameManager.elapsed_time
	else:entries.append({"text":message,"kind":kind,"urgent":urgent,"count":1,"first":GameManager.elapsed_time,"last":GameManager.elapsed_time})
	button.text="戰報 %d" % total
	_refresh()

func _pages() -> int:
	return maxi(1,ceili(entries.size()/3.0))

func open() -> void:
	page=0
	GameManager._request_system_pause("battle_journal")
	backdrop.show()
	_refresh()

func close() -> void:
	backdrop.hide()
	GameManager._release_system_pause("battle_journal")

func _exit_tree() -> void:
	if GameManager.system_pause_owners.has("battle_journal"):GameManager._release_system_pause("battle_journal")

func _refresh() -> void:
	heading.text="本局戰報・%d / %d 頁" % [page+1,_pages()]
	for number in range(3):
		var index:=entries.size()-1-(page*3+number)
		facts[number].text="尚無戰報" if entries.is_empty() and number==0 else ""
		if index<0:continue
		var row: Dictionary=entries[index]
		facts[number].text="%s%s\n%s" % [GameManager.format_time(row.last),"・共 %d 次" % row.count if row.count>1 else "",str(row.text).replace("\n","・")]
	_layout()

func _layout() -> void:
	if not is_instance_valid(panel):return
	var view:=MobileTuning.ui_layout_size(get_viewport().get_visible_rect().size)
	var portrait:=view.y>view.x
	var scale:=PlayerSettings.get_ui_scale_multiplier()
	button.add_theme_font_size_override("font_size",roundi(12*scale))
	heading.add_theme_font_size_override("font_size",roundi(20*scale))
	for label in facts:label.add_theme_font_size_override("font_size",roundi(13*scale))
	for id in ["previous","next","close"]:controls[id].add_theme_font_size_override("font_size",roundi(14*scale))
	button.position=Vector2(view.x-114,232 if portrait else 170)
	button.size=Vector2(104,44)
	MobileTuning.apply_web_canvas_scale(overlay,get_viewport().get_visible_rect().size,backdrop)
	var size:=Vector2(minf(view.x-20,720),minf(view.y-20,560))
	panel.position=(view-size)*0.5
	panel.size=size
	heading.position=Vector2(14,10)
	heading.size=Vector2(size.x-28,32)
	var h:=(size.y-112)/3
	for number in range(3):
		facts[number].position=Vector2(14,48+number*h)
		facts[number].size=Vector2(size.x-28,h-6)
	for number in range(3):
		var control: Button=controls[["previous","next","close"][number]]
		control.position=Vector2(14+number*(size.x-24)/3,size.y-54)
		control.size=Vector2((size.x-36)/3,44)
	_publish()

func _process(_delta: float) -> void:
	button.visible=GameManager.game_running and not get_tree().paused
	if backdrop.visible:_publish()

func _publish() -> void:
	var active: Dictionary={"open":button} if not backdrop.visible else {"previous":controls.previous,"next":controls.next,"close":controls.close}
	PROBE.publish("battle_journal",MobileTuning.ui_layout_size(get_viewport().get_visible_rect().size),active,{"visible":backdrop.visible,"total":total,"entries":entries,"page":page,"pages":_pages()})

func _unhandled_input(event: InputEvent) -> void:
	if backdrop.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
