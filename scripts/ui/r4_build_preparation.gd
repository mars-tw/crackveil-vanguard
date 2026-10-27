extends CanvasLayer

signal launch_requested
const CATALOG:=preload("res://scripts/services/starting_build_catalog.gd")
const ANIMATION:=preload("res://scripts/animation/true_animation_library.gd")
const FONT:=preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
const PROBE:=preload("res://scripts/services/qa_bridge.gd")
var root: Control
var panel: Panel
var heading: Label
var wallet: Label
var rule_label: Label
var progress_label: Label
var title: Label
var detail: Label
var state_label: Label
var final_label: Label
var preview_label: Label
var swap_label: Label
var portraits: Array[TextureRect]=[]
var portrait_names: Array[Label]=[]
var preview_portraits: Array[TextureRect]=[]
# Lineup diagram fills the detail column with the real candidate starters.
var lineup: Control
var lineup_textures: Array[Texture2D]=[]
var lineup_names: PackedStringArray=[]
var preview_names: Array[Label]=[]
var controls: Dictionary={}
var tabs: Array[Button]=[]
var overview_buttons: Array[Button]=[]
var tab:=0
var index:=0
var notice:=""
var current_ids: Array=[]
var candidate_ids: Array=[]
var replaced_ids: Array=[]
var incoming_ids: Array=[]

func _ready() -> void:
	process_mode=PROCESS_MODE_ALWAYS
	layer=24
	root=Control.new()
	root.add_theme_font_override("font",FONT)
	add_child(root)
	var backdrop:=ColorRect.new()
	backdrop.color=Color(0.015,0.025,0.045,0.90)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	panel=Panel.new()
	panel.add_theme_stylebox_override("panel",_style(Color("101e30"),Color("77cdda"),2))
	root.add_child(panel)
	preload("res://scripts/ui/rift_frame_ornament.gd").attach(panel,true,Color("6fc4cf"),22.0)
	heading=_label("出擊整備",20)
	rule_label=_label("三線共用一個起始節點",12)
	wallet=_label("",12)
	progress_label=_label("",12)
	title=_label("",17)
	detail=_label("",13)
	detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	state_label=_label("",12)
	final_label=_label("現役",12)
	preview_label=_label("選後",12)
	swap_label=_label("",12)
	for id in ["close","previous","next","action","clear","launch"]:controls[id]=_button(id)
	controls.close.text="返回"
	controls.close.pressed.connect(_close)
	controls.previous.text="上一項"
	controls.next.text="下一項"
	controls.previous.pressed.connect(func():index=posmod(index-1,3 if tab==0 else 5);notice="";_refresh())
	controls.next.pressed.connect(func():index=posmod(index+1,3 if tab==0 else 5);notice="";_refresh())
	controls.action.pressed.connect(_act)
	controls.clear.pressed.connect(_clear_or_retry)
	controls.launch.text="依此出擊"
	controls.launch.pressed.connect(func():launch_requested.emit())
	for number in range(4):
		var button:=_button("tab_"+str(number))
		button.text=["編成","隊員","羈絆","專精"][number]
		button.pressed.connect(func():tab=number;index=0;notice="";_refresh())
		tabs.append(button)
		controls["tab_"+str(number)]=button
	for number in range(5):
		var button:=_button("node_"+str(number))
		button.add_theme_font_size_override("font_size",12)
		button.pressed.connect(func():index=number;notice="";_refresh())
		overview_buttons.append(button)
	for number in range(3):
		portraits.append(_portrait())
		portrait_names.append(_label("",12))
		preview_portraits.append(_portrait())
		preview_names.append(_label("",12))
	lineup=Control.new()
	lineup.name="LineupDiagram"
	lineup.mouse_filter=Control.MOUSE_FILTER_IGNORE
	lineup.draw.connect(_draw_lineup)
	panel.add_child(lineup)
	MetaProgress.progress_changed.connect(_refresh)
	PlayerSettings.settings_changed.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_refresh()
	root.hide()

func _style(background: Color,border: Color,width: int=1) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=background
	style.border_color=border
	style.set_border_width_all(width)
	style.set_corner_radius_all(7)
	style.content_margin_left=4
	style.content_margin_right=4
	style.content_margin_top=2
	style.content_margin_bottom=2
	return style

func _button(id: String) -> Button:
	var button:=Button.new()
	button.name=id
	button.focus_mode=Control.FOCUS_ALL
	button.custom_minimum_size=Vector2(44,44)
	button.add_theme_font_size_override("font_size",14)
	button.add_theme_stylebox_override("normal",_style(Color("14283b"),Color("77cdda")))
	button.add_theme_stylebox_override("hover",_style(Color("203a4b"),Color("eaf2f3"),2))
	button.add_theme_stylebox_override("focus",_style(Color("203a4b"),Color("ffdc82"),2))
	button.add_theme_stylebox_override("pressed",_style(Color("203a4b"),Color("ffdc82"),2))
	button.add_theme_stylebox_override("disabled",_style(Color("101c29"),Color("56697d")))
	panel.add_child(button)
	return button

func _label(text: String,font_size: int) -> Label:
	var label:=Label.new()
	label.text=text
	label.add_theme_font_size_override("font_size",font_size)
	label.clip_text=true
	panel.add_child(label)
	return label

func _portrait() -> TextureRect:
	var image:=TextureRect.new()
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(image)
	return image

func _fill_roster(ids: Array,images: Array[TextureRect],names: Array[Label],preview: bool) -> void:
	for number in range(3):
		var hero: Resource=load("res://resources/heroes/%s.tres" % ids[number])
		var frames:=ANIMATION.get_sprite_frames(str(hero.get("sprite_path")))
		images[number].texture=frames.get_frame_texture(&"idle",0) if frames!=null else null
		var changed: bool=not current_ids.has(ids[number]) if preview else not candidate_ids.has(ids[number])
		names[number].text=("先發 " if preview and changed else "換下 " if changed else "留隊 ")+str(hero.get("display_name"))
		names[number].add_theme_color_override("font_color",Color("ffdc82") if preview and changed else Color("f8a3a1") if changed else Color("eaf2f3"))

func open() -> void:
	if not MetaProgress.starting_ready:MetaProgress.load_progress()
	if not GameManager.pending_starting_settlements.is_empty():notice="結算進度已保存" if GameManager.retry_starting_settlements() else "結算尚未保存，請按重試保存"
	root.show()
	_refresh()

func _close() -> void:
	root.hide()
	_publish()

func _clear_or_retry() -> void:
	if not GameManager.pending_starting_settlements.is_empty():notice="結算進度已保存" if GameManager.retry_starting_settlements() else "無法保存，請稍後重試"
	else:notice="" if MetaProgress.equip_starting_node("") else "無法保存，請稍後重試"
	_refresh()

func _current() -> Dictionary:
	if tab==0:
		var id: String=["assault","escort","legacy"][index]
		var row: Dictionary=CATALOG.TEAMS[id].duplicate(true)
		row["id"]=id
		return row
	return CATALOG.NODES[(tab-1)*5+index].duplicate(true)

func _act() -> void:
	var row:=_current()
	var success:=false
	if tab==0:success=MetaProgress.select_starting_team(row.id)
	elif not MetaProgress.starting_owned.has(row.id):success=MetaProgress.purchase_starting_node(row.id)
	else:success=MetaProgress.equip_starting_node(row.id)
	notice="已保存" if success else "無法保存或殘響不足，請確認後重試"
	_refresh()

func _progress_hint() -> String:
	var free_text: String
	if not MetaProgress.starting_second_granted:
		free_text="第二次免費 %d/4" % mini(4,MetaProgress.starting_settlements.size())
	elif MetaProgress.starting_vouchers>0:
		free_text="免費選擇 %d 張可用" % MetaProgress.starting_vouchers
	else:
		free_text="第二次免費已使用"
	var goal: Dictionary=MetaProgress.get_next_progress_goal()
	if goal.get("kind","")=="complete":return free_text+"・局外強化已滿級"
	return free_text+"・%s差%d 殘響" % [str(goal.get("name","下一強化")).replace(" ",""),goal.get("remaining",0)]

func _refresh() -> void:
	if not is_instance_valid(root):return
	var row:=_current()
	var equipped: Dictionary=CATALOG.node(MetaProgress.starting_equipped)
	wallet.text="殘響%d 免費%d" % [MetaProgress.shards,MetaProgress.starting_vouchers]
	progress_label.text=_progress_hint()
	controls.clear.text="重試保存" if not GameManager.pending_starting_settlements.is_empty() else "卸下節點"
	current_ids=CATALOG.roster(MetaProgress.starting_team,MetaProgress.starting_equipped)
	candidate_ids=CATALOG.roster(row.id,MetaProgress.starting_equipped) if tab==0 else CATALOG.roster(MetaProgress.starting_team,row.id)
	_fill_roster(current_ids,portraits,portrait_names,false)
	_fill_roster(candidate_ids,preview_portraits,preview_names,true)
	lineup_textures.clear()
	lineup_names.clear()
	for id in candidate_ids:
		var hero: Resource=load("res://resources/heroes/%s.tres" % id)
		var frames:=ANIMATION.get_sprite_frames(str(hero.get("sprite_path")))
		lineup_textures.append(frames.get_frame_texture(&"idle",0) if frames!=null else null)
		lineup_names.append(str(hero.get("display_name")))
	final_label.text="現役・"+str(CATALOG.TEAMS[MetaProgress.starting_team].name)
	preview_label.text="選後・"+str(row.name)
	replaced_ids=[]
	incoming_ids=[]
	for id in current_ids:
		if not candidate_ids.has(id):replaced_ids.append(id)
	for id in candidate_ids:
		if not current_ids.has(id):incoming_ids.append(id)
	var selected_node: String=str(equipped.get("name","未裝節點")) if tab==0 else str(row.name)
	swap_label.text="起始節點：%s → %s" % [equipped.get("name","未裝節點"),selected_node]
	if tab==0:
		title.text=str(row.name)
		detail.text=str(row.trade)+("\n已裝節點指定先發，實際名單如上" if equipped.has("roster") else "\n可搭配任一個起始節點")
		controls.action.text="目前編成" if MetaProgress.starting_team==row.id else "選用編成"
		controls.action.disabled=MetaProgress.starting_team==row.id
		state_label.text=notice if notice!="" else "預覽不改編成，請確認選用"
	else:
		var owned: bool=MetaProgress.starting_owned.has(row.id)
		var active: bool=MetaProgress.starting_equipped==row.id
		title.text=("%s・首次免費・之後 %d 殘響" % [row.name,row.cost]) if not MetaProgress.starting_owned.has(row.id) and MetaProgress.starting_vouchers>0 else ("%s・已解鎖" % row.name) if MetaProgress.starting_owned.has(row.id) else "%s・成本 %d 殘響" % [row.name,row.cost]
		var cost: String=str(row.cost_text).replace("和聲回復僅限護圈 96 內","只回復淡藍護圈內隊友").replace("改 390 範圍槍","改用中距離直線貫槍")
		detail.text="收益：%s\n代價：%s" % ["護盾＋星焰直線貫槍" if row.id=="crew_guard" else row.benefit,"少電弧連鎖，換中距離貫槍" if row.id=="crew_guard" else cost]
		controls.action.text="已裝備" if active else "裝備此節點" if owned else "免費解鎖" if MetaProgress.starting_vouchers>0 else "解鎖 %d 殘響" % row.cost
		controls.action.disabled=active or (not owned and MetaProgress.starting_vouchers<=0 and MetaProgress.shards<int(row.cost))
		state_label.text=notice if notice!="" else "已裝備・本局生效" if active else "已解鎖・尚未裝備" if owned else "未解鎖・首次免費（之後 %d 殘響）" % row.cost if MetaProgress.starting_vouchers>0 else "未解鎖・殘響不足" if MetaProgress.shards<int(row.cost) else "未解鎖・可購買"
		if bool(row.get("campaign_only",false)):state_label.text+="・封隙專用（無盡停用）"
	for number in range(5):
		var button:=overview_buttons[number]
		var available: bool=number<(3 if tab==0 else 5)
		button.visible=available
		controls.erase("node_"+str(number))
		if not available:continue
		controls["node_"+str(number)]=button
		var option: Dictionary=CATALOG.TEAMS[["assault","escort","legacy"][number]] if tab==0 else CATALOG.NODES[(tab-1)*5+number]
		var name: String=str(option.name)
		var id: String=["assault","escort","legacy"][number] if tab==0 else str(option.id)
		var badge:="用" if (tab==0 and MetaProgress.starting_team==id) or (tab>0 and MetaProgress.starting_equipped==id) else "備" if tab>0 and MetaProgress.starting_owned.has(id) else "鎖" if tab>0 else "選"
		button.text=(name.substr(0,2)+str(option.cost)+"\n"+("已裝備" if badge=="用" else "未裝備" if badge=="備" else "未解鎖")) if tab>0 else name+"\n"+("目前編成" if badge=="用" else "可選編成")
		button.add_theme_stylebox_override("normal",_style(Color("253b4d") if index==number else Color("102235"),Color("ffdc82") if index==number else Color("77cdda") if badge in ["用","備"] else Color("56697d"),2 if index==number else 1))
	for number in range(4):tabs[number].modulate=Color("ffdc82") if tab==number else Color.WHITE
	if not MetaProgress.starting_ready:
		state_label.text="無法保存，請稍後重開整備"
		controls.action.disabled=true
	_layout()

func _layout() -> void:
	if not is_instance_valid(panel):return
	var view:=MobileTuning.apply_web_canvas_scale(self,get_viewport().get_visible_rect().size,root)
	var size:=Vector2(minf(view.x-16,920),minf(view.y-16,640))
	panel.position=(view-size)*0.5
	panel.size=size
	var w:=size.x-24
	var portrait: bool=view.y>view.x
	var scale:=PlayerSettings.get_ui_scale_multiplier()
	for label in [rule_label,wallet,progress_label,state_label,final_label,preview_label,swap_label]:label.add_theme_font_size_override("font_size",roundi(12*scale))
	detail.add_theme_font_size_override("font_size",roundi(13*scale))
	title.add_theme_font_size_override("font_size",roundi(17*scale))
	for id in controls:controls[id].add_theme_font_size_override("font_size",roundi((12 if str(id).begins_with("node_") else 14)*scale))
	var heading_w: float=FONT.get_string_size(heading.text,HORIZONTAL_ALIGNMENT_LEFT,-1,heading.get_theme_font_size("font_size")).x+4.0
	_place(heading,54,8,heading_w,26)
	var wallet_x: float=maxf(124.0 if portrait else 240.0,54.0+heading_w+8.0)
	_place(controls.close,size.x-68,8,56,44)
	_place(rule_label,12,35,w-68 if portrait else 220,18)
	_place(wallet,wallet_x,12,w-60-wallet_x if portrait else w-60-wallet_x,18)
	_place(progress_label,12 if portrait else 240,58 if portrait else 32,w if portrait else w-300,18)
	var tabs_y:=80.0 if portrait else 52.0
	for number in range(4):_place(tabs[number],12+number*(w+4)/4,tabs_y,(w-12)/4,44)
	var overview_y:=tabs_y+50
	var count:=3 if tab==0 else 5
	for number in range(count):_place(overview_buttons[number],12+number*(w+4)/count,overview_y,(w-4*(count-1))/count,50)
	var bottom:=size.y-12
	_place(controls.clear,12,bottom-44,w*0.36,44)
	_place(controls.launch,20+w*0.36,bottom-44,w*0.64-8,44)
	_place(controls.previous,12,bottom-94,w*0.24,44)
	_place(controls.action,20+w*0.24,bottom-94,w*0.5-16,44)
	_place(controls.next,12+w*0.76,bottom-94,w*0.24,44)
	var body_y:=overview_y+54
	var roster_w:=w if portrait else w*0.52
	var col: float=(roster_w-8)*0.5
	var roster_y:=body_y+32 if portrait else body_y
	_place(title,12 if portrait else 24+roster_w,body_y,w if portrait else w-roster_w-12,28)
	var title_size: int = roundi(17*scale)
	while title_size > 10 and FONT.get_string_size(title.text,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x > title.size.x - 4:
		title_size -= 1
	title.add_theme_font_size_override("font_size",title_size)
	_place(final_label,12,roster_y,col,17)
	_place(preview_label,20+col,roster_y,col,17)
	var row_h:=minf(72,maxf(22,(bottom-137-roster_y)/3))
	if portrait:
		# Larger portraits only use space the full benefit/cost text does not need.
		var text_need:=FONT.get_multiline_string_size(detail.text,HORIZONTAL_ALIGNMENT_LEFT,w-4,roundi(13*scale)).y+8
		row_h=clampf((bottom-120-text_need-(roster_y+19)-25)/3.0,26.0,40.0)
	# Portraits grow only into width the longest roster name does not need.
	var name_need:=0.0
	for label in portrait_names+preview_names:
		name_need=maxf(name_need,FONT.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(12*scale)).x)
	var image_cap:=clampf(col-name_need-9,18.0,64.0)
	for number in range(3):
		var y:=roster_y+19+number*row_h
		var image_size:=minf(minf(64,row_h-2),image_cap)
		_place(portraits[number],12,y,image_size,image_size)
		_place(portrait_names[number],16+image_size,y,col-image_size-5,image_size)
		_place(preview_portraits[number],20+col,y,image_size,image_size)
		_place(preview_names[number],24+col+image_size,y,col-image_size-5,image_size)
		for label in [portrait_names[number],preview_names[number]]:label.add_theme_font_size_override("font_size",roundi(12*scale))
	var swap_y:=roster_y+19+3*row_h
	_place(swap_label,12,swap_y,w if portrait else roster_w,22)
	var detail_y:=swap_y+25 if portrait else body_y+32
	var detail_w:=w if portrait else w-roster_w-12
	var detail_room:=maxf(28,bottom-120-detail_y)
	var detail_h:=minf(detail_room,FONT.get_multiline_string_size(detail.text,HORIZONTAL_ALIGNMENT_LEFT,detail_w-4,roundi(13*scale)).y+8)
	_place(detail,12 if portrait else 24+roster_w,detail_y,detail_w,detail_room if detail_room-detail_h<110 else detail_h)
	var lineup_y:=detail_y+detail_h+6
	var lineup_h:=bottom-124-lineup_y
	lineup.visible=lineup_h>=110
	_place(lineup,12 if portrait else 24+roster_w,lineup_y,detail_w,minf(lineup_h,220))
	lineup.queue_redraw()
	_place(state_label,12 if portrait else 24+roster_w,bottom-118,w if portrait else w-roster_w-12,20)
	var state_size: int = roundi(12*scale)
	while state_size > 9 and FONT.get_string_size(state_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,state_size).x > state_label.size.x - 4:
		state_size -= 1
	state_label.add_theme_font_size_override("font_size",state_size)
	_publish()

func _draw_lineup() -> void:
	var box:=Rect2(Vector2.ZERO,lineup.size)
	lineup.draw_rect(box,Color("0b1626"),true)
	lineup.draw_rect(box,Color("355a6e"),false,1.0)
	var scale:=PlayerSettings.get_ui_scale_multiplier()
	var font_size:=roundi(12*scale)
	lineup.draw_string(FONT,Vector2(10,8+font_size),"選後站位（隊長在前，下一場實際先發）",HORIZONTAL_ALIGNMENT_LEFT,box.size.x-20,font_size,Color("9fc6d4"))
	var top:=16.0+font_size
	var cell:=minf((box.size.y-top-8-font_size)*0.62,box.size.x*0.24)
	var centers:=[Vector2(box.size.x*0.5,top+cell*0.5),Vector2(box.size.x*0.5-cell*1.15,top+cell*0.95),Vector2(box.size.x*0.5+cell*1.15,top+cell*0.95)]
	for number in range(mini(3,lineup_textures.size())):
		var center: Vector2=centers[number]
		var incoming:=not current_ids.has(candidate_ids[number])
		var frame:=Rect2(center-Vector2(cell,cell)*0.5,Vector2(cell,cell))
		lineup.draw_rect(frame,Color("14283b"),true)
		lineup.draw_rect(frame,Color("ffdc82") if incoming else Color("77cdda"),false,2.0 if incoming else 1.0)
		if lineup_textures[number]!=null:
			lineup.draw_texture_rect(lineup_textures[number],frame.grow(-3),false)
		var tag:=("先發 " if incoming else "")+lineup_names[number]
		lineup.draw_string(FONT,Vector2(frame.position.x-20,frame.end.y+font_size+2),tag,HORIZONTAL_ALIGNMENT_CENTER,cell+40,font_size,Color("ffdc82") if incoming else Color("eaf2f3"))

func _place(control: Control,x: float,y: float,w: float,h: float) -> void:
	control.position=Vector2(x,y)
	control.size=Vector2(maxf(1,w),maxf(1,h))

func _process(_delta: float) -> void:
	if is_instance_valid(root) and root.visible:_publish()

func _publish() -> void:
	PROBE.publish("build_preparation",MobileTuning.ui_layout_size(get_viewport().get_visible_rect().size),controls,{"visible":root.visible,"tab":tab,"index":index,"node":_current().id,"equipped":MetaProgress.starting_equipped,"team":MetaProgress.starting_team,"owned":MetaProgress.starting_owned,"vouchers":MetaProgress.starting_vouchers,"roster":current_ids,"candidate_roster":candidate_ids,"replaced":replaced_ids,"incoming":incoming_ids,"title":title.text,"detail":detail.text,"state":state_label.text,"final":final_label.text,"comparison":swap_label.text,"shared_slot_rule":rule_label.text,"progress":progress_label.text,"detail_lines":detail.get_line_count(),"detail_visible_lines":detail.get_visible_line_count(),"overview_visible":3 if tab==0 else 5,"ui_scale_index":PlayerSettings.ui_scale_index})

func _unhandled_input(event: InputEvent) -> void:
	if root.visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
