extends CanvasLayer

signal launch_requested
const CATALOG := preload("res://scripts/services/starting_build_catalog.gd")
const ANIMATION := preload("res://scripts/animation/true_animation_library.gd")
const FONT := preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
const PROBE := preload("res://scripts/services/web_reachability_probe.gd")
var root: Control
var panel: Panel
var heading: Label
var wallet: Label
var title: Label
var detail: Label
var state_label: Label
var final_label: Label
var portraits: Array[TextureRect] = []
var portrait_names: Array[Label] = []
var controls: Dictionary = {}
var tab := 0
var index := 0
var notice := ""
var tabs: Array[Button] = []

func _ready() -> void:
	process_mode=PROCESS_MODE_ALWAYS
	layer=24
	root=Control.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.add_theme_font_override("font",FONT)
	add_child(root)
	var backdrop:=ColorRect.new()
	backdrop.color=Color(0.015,0.025,0.045,0.88)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	panel=Panel.new()
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("101e30")
	style.border_color=Color("75b5ca")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel",style)
	root.add_child(panel)
	heading=_label("出擊整備",21)
	wallet=_label("",13)
	final_label=_label("",13)
	title=_label("",19)
	detail=_label("",14)
	state_label=_label("",13)
	for id in ["close","previous","next","action","clear","launch"]:
		var button:=Button.new()
		button.name=id
		button.focus_mode=Control.FOCUS_NONE
		button.custom_minimum_size=Vector2(44,44)
		button.add_theme_font_size_override("font_size",14)
		panel.add_child(button)
		controls[id]=button
	controls.close.text="返回"
	controls.close.pressed.connect(func():root.hide())
	controls.previous.text="上一項"
	controls.next.text="下一項"
	controls.previous.pressed.connect(func(): index=posmod(index-1,3 if tab==0 else 5);notice="";_refresh())
	controls.next.pressed.connect(func(): index=posmod(index+1,3 if tab==0 else 5);notice="";_refresh())
	controls.action.pressed.connect(_act)
	controls.clear.text="卸下節點"
	controls.clear.pressed.connect(_clear_or_retry)
	controls.launch.text="依此編成出擊"
	controls.launch.pressed.connect(func():launch_requested.emit())
	for number in range(4):
		var button:=Button.new()
		button.text=["編成","隊員","羈絆","專精"][number]
		button.custom_minimum_size.y=44
		button.add_theme_font_size_override("font_size",14)
		button.pressed.connect(func():tab=number;index=0;notice="";_refresh())
		panel.add_child(button)
		tabs.append(button)
		controls["tab_"+str(number)]=button
	for number in range(3):
		var image:=TextureRect.new()
		image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		panel.add_child(image)
		portraits.append(image)
		portrait_names.append(_label("",13))
	MetaProgress.progress_changed.connect(_refresh)
	get_viewport().size_changed.connect(_layout)
	_layout()
	root.hide()

func _label(text: String, font_size: int) -> Label:
	var label:=Label.new()
	label.text=text
	label.add_theme_font_size_override("font_size",font_size)
	label.autowrap_mode=TextServer.AUTOWRAP_OFF
	label.clip_text=true
	panel.add_child(label)
	return label

func open() -> void:
	if not MetaProgress.starting_ready: MetaProgress.load_progress()
	if not GameManager.pending_starting_settlements.is_empty():
		notice="選擇進度已保存" if GameManager.retry_starting_settlements() else "進度尚未保存，請點重試保存"
	root.show()
	_refresh()

func _clear_or_retry() -> void:
	if not GameManager.pending_starting_settlements.is_empty():
		notice="選擇進度已保存" if GameManager.retry_starting_settlements() else "仍無法保存，請稍後再試"
	else:
		notice="" if MetaProgress.equip_starting_node("") else "無法保存，請稍後再試"
	_refresh()

func _current() -> Dictionary:
	if tab==0:
		var id: String=["assault","escort","legacy"][index]
		var result: Dictionary=CATALOG.TEAMS[id].duplicate(true)
		result["id"]=id
		return result
	return CATALOG.NODES[(tab-1)*5+index].duplicate(true)

func _act() -> void:
	var row:=_current()
	var success:=false
	if tab==0: success=MetaProgress.select_starting_team(row.id)
	elif not MetaProgress.starting_owned.has(row.id): success=MetaProgress.purchase_starting_node(row.id)
	else: success=MetaProgress.equip_starting_node(row.id)
	notice="已保存" if success else "無法保存或殘響不足，請確認後再試"
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(root): return
	wallet.text="殘響 %d｜免費選擇 %d｜有效結算 %d 次" % [MetaProgress.shards,MetaProgress.starting_vouchers,MetaProgress.starting_settlements.size()]
	controls.clear.text="重試保存" if not GameManager.pending_starting_settlements.is_empty() else "卸下節點"
	var equipped: Dictionary=CATALOG.node(MetaProgress.starting_equipped)
	final_label.text="出擊名單｜%s・%s" % [CATALOG.TEAMS[MetaProgress.starting_team].name,equipped.get("name","未裝備節點")]
	var ids:=CATALOG.roster(MetaProgress.starting_team,MetaProgress.starting_equipped)
	for number in range(3):
		var hero: Resource=load("res://resources/heroes/%s.tres" % ids[number])
		var frames:=ANIMATION.get_sprite_frames(str(hero.get("sprite_path")))
		portraits[number].texture=frames.get_frame_texture(&"idle",0) if frames!=null else null
		portrait_names[number].text=str(hero.get("display_name"))
	var row:=_current()
	if tab==0:
		title.text="%d/3・%s" % [index+1,row.name]
		detail.text=str(row.trade)+("\n已裝節點固定隊員；上方為最終名單" if equipped.has("roster") else "\n可搭配任一個起始節點")
		controls.action.text="目前編成" if MetaProgress.starting_team==row.id else "選擇編成"
		controls.action.disabled=MetaProgress.starting_team==row.id
		state_label.text=notice if notice!="" else "三線節點總共只能裝備一個"
	else:
		var owned: bool=MetaProgress.starting_owned.has(row.id)
		var active: bool=MetaProgress.starting_equipped==row.id
		title.text="%d/5・%s" % [index+1,row.name]
		detail.text="收益：%s\n代價：%s" % [row.benefit,row.cost_text]
		controls.action.text="已裝備" if active else "裝備此節點" if owned else "免費解鎖" if MetaProgress.starting_vouchers>0 else "解鎖・%d 殘響" % row.cost
		controls.action.disabled=active or (not owned and MetaProgress.starting_vouchers<=0 and MetaProgress.shards<int(row.cost))
		state_label.text=notice if notice!="" else "已裝備・本局生效" if active else "已解鎖・尚未裝備" if owned else "尚未解鎖・可免費選擇" if MetaProgress.starting_vouchers>0 else "殘響不足" if MetaProgress.shards<int(row.cost) else "可解鎖・不會與其他節點疊加"
		if bool(row.get("campaign_only",false)):
			state_label.text+="・封隙專用"
			detail.text+="（無盡停用）"
		if row.has("roster") and not active: state_label.text+="｜替換名單"
	for number in range(tabs.size()):
		tabs[number].modulate=Color("ffdda8") if number==tab else Color.WHITE
	panel.modulate=Color.WHITE
	controls.action.add_theme_color_override("font_disabled_color",Color("ffe1aa") if controls.action.text=="已裝備" else Color("a8bac8"))
	var action_style:=StyleBoxFlat.new()
	action_style.bg_color=Color("203a4b") if not controls.action.disabled else Color("182b3c")
	action_style.border_color=Color("ffd69a") if controls.action.text in ["已裝備","目前編成","免費解鎖"] else Color("83d8ed") if tab>0 and MetaProgress.starting_owned.has(row.id) else Color("667889")
	action_style.set_border_width_all(3 if controls.action.text in ["已裝備","目前編成"] else 2)
	action_style.set_corner_radius_all(6)
	controls.action.add_theme_stylebox_override("normal",action_style)
	controls.action.add_theme_stylebox_override("disabled",action_style)
	if not MetaProgress.starting_ready:
		state_label.text="無法保存，請稍後重新開啟整備"
		controls.action.disabled=true
	_layout()

func _layout() -> void:
	if not is_instance_valid(panel): return
	var view:=MobileTuning.apply_web_canvas_scale(self,get_viewport().get_visible_rect().size,root)
	root.size=view
	var size:=Vector2(minf(view.x-16,860),minf(view.y-16,600))
	panel.position=(view-size)*0.5
	panel.size=size
	var w:=size.x-24
	title.add_theme_font_size_override("font_size",16 if view.y<500 else 17 if view.x<700 else 19)
	detail.add_theme_font_size_override("font_size",14 if view.y>=390 else 13)
	detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_place(heading,12,8,w-64,28)
	_place(controls.close,size.x-68,8,56,44)
	_place(wallet,12,38,w-64,20)
	for number in range(4): _place(tabs[number],12+number*(w+4)/4,58,(w-12)/4,44)
	_place(final_label,12,104,w,20)
	var portrait: bool=view.y>view.x
	var body_y:=220.0 if portrait else minf(168,size.y-206)
	for number in range(3):
		var column:=w/3
		if portrait:
			_place(portraits[number],12+number*column+(column-64)*0.5,126,64,64)
			_place(portrait_names[number],12+number*column,194,column-4,22)
		else:
			_place(portraits[number],12+number*column,126,40,minf(40,body_y-128))
			_place(portrait_names[number],54+number*column,128,column-44,minf(36,body_y-128))
	var bottom:=size.y-12
	_place(controls.clear,12,bottom-44,w*0.38,44)
	_place(controls.launch,20+w*0.38,bottom-44,w*0.62-8,44)
	_place(controls.previous,12,bottom-94,w*0.24,44)
	_place(controls.action,20+w*0.24,bottom-94,w*0.5-16,44)
	_place(controls.next,12+w*0.76,bottom-94,w*0.24,44)
	_place(title,12,body_y,w,24)
	_place(detail,12,body_y+26,w,maxf(38,bottom-118-(body_y+26)-2))
	_place(state_label,12,bottom-118,w,20)
	_publish()

func _place(control: Control,x: float,y: float,w: float,h: float) -> void:
	control.position=Vector2(x,y)
	control.size=Vector2(w,h)

func _process(_delta: float) -> void:
	if is_instance_valid(root) and root.visible: _publish()

func _publish() -> void:
	PROBE.publish("build_preparation",MobileTuning.ui_layout_size(get_viewport().get_visible_rect().size),controls,{"visible":root.visible,"tab":tab,"index":index,"node":_current().id,"equipped":MetaProgress.starting_equipped,"team":MetaProgress.starting_team,"owned":MetaProgress.starting_owned,"vouchers":MetaProgress.starting_vouchers,"roster":CATALOG.roster(MetaProgress.starting_team,MetaProgress.starting_equipped),"title":title.text,"detail":detail.text,"state":state_label.text,"final":final_label.text,"detail_lines":detail.get_line_count(),"detail_visible_lines":detail.get_visible_line_count(),"ui_scale_index":PlayerSettings.ui_scale_index})

func _unhandled_input(event: InputEvent) -> void:
	if root.visible and event.is_action_pressed("ui_cancel"):
		root.hide()
		get_viewport().set_input_as_handled()
