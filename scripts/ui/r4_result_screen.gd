extends CanvasLayer

signal restart_requested
signal continue_requested
signal main_menu_requested
const FONT:=preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
const CATALOG:=preload("res://scripts/services/starting_build_catalog.gd")
const PROBE:=preload("res://scripts/services/web_reachability_probe.gd")
var victory:=false
var root: Control
var panel: Panel
var title_label: Label
var summary_scroll: ScrollContainer
var body_scroll: ScrollContainer
var body_content: VBoxContainer
var summary_label: Label
var achievements_label: RichTextLabel
var gain_label: Label
var progress_label: Label
var page_label: Label
var restart_button: Button
var continue_button: Button
var main_menu_button: Button
var copy_seed_button: Button
var summary_tween: Tween
var displayed_summary: Dictionary={}
var controls: Dictionary={}
var tabs: Array[Button]=[]
var cards: Array[Label]=[]
var tab:=0
var page:=0
var rows: Array=[]
var page_capacity:=2

func _ready() -> void:
	process_mode=PROCESS_MODE_ALWAYS
	layer=25 if victory else 30
	root=Control.new()
	root.add_theme_font_override("font",FONT)
	add_child(root)
	var dim:=ColorRect.new()
	dim.color=Color(0.01,0.02,0.04,0.90)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	panel=Panel.new()
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("101e30")
	style.border_color=Color("77cdda") if victory else Color("f8a3a1")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel",style)
	root.add_child(panel)
	title_label=_label(23)
	summary_scroll=ScrollContainer.new()
	summary_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	summary_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(summary_scroll)
	body_scroll=summary_scroll
	summary_label=Label.new()
	summary_label.add_theme_font_size_override("font_size",14)
	summary_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	summary_scroll.add_child(summary_label)
	gain_label=_label(14)
	gain_label.add_theme_color_override("font_color",Color("ffdc82"))
	progress_label=_label(12)
	page_label=_label(12)
	for number in range(3):
		var button:=_button("tab_"+str(number),["輸出","支援","紀錄"][number])
		button.pressed.connect(func():tab=number;page=0;_refresh())
		tabs.append(button)
	for number in range(2):cards.append(_label(14))
	_button("previous","上一頁").pressed.connect(func():page=posmod(page-1,_page_count());_refresh())
	_button("next","下一頁").pressed.connect(func():page=posmod(page+1,_page_count());_refresh())
	copy_seed_button=_button("copy","下一關" if victory else "複製種子")
	copy_seed_button.pressed.connect(func():
		if victory:GameManager.start_next_stage()
		else:GameManager.copy_current_run_seed_to_clipboard())
	main_menu_button=_button("menu","下局整備")
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	var primary:=_button("primary","繼續無盡" if victory else "再來一局")
	primary.pressed.connect(_on_primary_pressed)
	if victory:continue_button=primary
	else:restart_button=primary
	get_viewport().size_changed.connect(_apply_responsive_layout)
	PlayerSettings.settings_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	root.hide()

func _label(font_size: int) -> Label:
	var label:=Label.new()
	label.add_theme_font_size_override("font_size",font_size)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	return label

func _button(id: String,text: String) -> Button:
	var button:=Button.new()
	button.text=text
	button.custom_minimum_size=Vector2(44,44)
	button.add_theme_font_size_override("font_size",14)
	for state in ["normal","hover","focus","pressed","disabled"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("1a3144")
		style.border_color=Color("ffdc82") if state in ["focus","pressed"] else Color("77cdda")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left=6;style.content_margin_right=6
		style.content_margin_top=3;style.content_margin_bottom=3
		button.add_theme_stylebox_override(state,style)
	panel.add_child(button)
	controls[id]=button
	return button

func show_summary(summary: Dictionary) -> void:
	displayed_summary=summary.duplicate(true)
	rows=summary.get("contribution_rows",[]).duplicate(true)
	# Legacy callers may construct a summary themselves. The live ledger remains
	# the authoritative fallback; no values are manufactured by the view.
	if rows.is_empty():
		for id in GameManager.contribution:
			var row: Dictionary=GameManager.contribution[id].duplicate(true)
			row["id"]=id
			rows.append(row)
	tab=0
	page=0
	title_label.text=(str(summary.get("stage_name","封隙出擊"))+"・通關") if victory else "任務失敗"
	controls.primary.text="繼續無盡" if victory else "免費整備" if GameManager.active_starting_formal and MetaProgress.starting_vouchers>0 else "重試保存" if not GameManager.pending_starting_settlements.is_empty() else "再來一局"
	copy_seed_button.text=("下一關" if str(summary.get("next_stage_id",""))!="" else "世界地圖") if victory else "複製種子"
	main_menu_button.text="下局整備" if GameManager.active_starting_formal else "世界地圖" if victory else "回主選單"
	_refresh()
	root.show()
	_apply_responsive_layout()

func _page_count() -> int:
	return maxi(1,ceili(float(_records().size() if tab==2 else rows.size())/_per_page()))

func _per_page() -> int:
	var view:=MobileTuning.ui_layout_size(get_viewport().get_visible_rect().size)
	return 1 if view.y>view.x and view.y<640 else 2

func _records() -> Array[String]:
	var data:=displayed_summary
	var result: Array[String]=[
		"戰利與成長\n金幣 %d・等級 %d\n殘響 +%d・裝備 %d 件" % [data.get("gold",0),data.get("level",1),data.get("echo_shards_earned",0),data.get("equipment_collected",0)],
		"關卡紀錄\n擊殺 %d・菁英 %d\n守門者：%s" % [data.get("kills",0),data.get("elites_killed",0),"已擊破" if data.get("boss_killed",false) else "尚未擊破"]]
	for achievement in data.get("achievement_unlocks",[]):result.append("本局新解鎖\n"+str(achievement.get("name","")))
	return result

func _refresh() -> void:
	page_capacity=_per_page()
	var build: Dictionary=displayed_summary.get("starting_build",{})
	var team: String=str(build.get("team",GameManager.active_starting_team))
	var node: Dictionary=CATALOG.node(str(build.get("node",GameManager.active_starting_node)))
	var bond: Dictionary=displayed_summary.get("bond_benefits",GameManager.bond_benefits)
	var outcome: String="擊破"+str(displayed_summary.get("boss_name",GameManager.STAGE_CATALOG.get_stage(GameManager.selected_stage_id).get("boss_name","守門者"))) if victory else "先鋒的殘響"
	summary_label.text="%s｜%s\n%s %s\n擊殺 %d・存活 %d/%d 人\n羈絆收益 回復%d／減傷%d HP" % [CATALOG.TEAMS.get(team,CATALOG.TEAMS.legacy).name,node.get("name","未裝節點"),outcome,GameManager.format_time(float(displayed_summary.get("elapsed_time",0))),displayed_summary.get("kills",0),displayed_summary.get("squad_alive",0),displayed_summary.get("squad_total",rows.size()),bond.get("healing",0),bond.get("prevented",0)]
	gain_label.text=_measured_gain(node,build.get("benefits",{}))
	progress_label.text=MetaProgress.starting_choice_progress_text()
	if not GameManager.pending_starting_settlements.is_empty():progress_label.text="進度未保存・整備可重試"
	page=clampi(page,0,_page_count()-1)
	page_label.text="%d / %d 頁" % [page+1,_page_count()]
	var records:=_records()
	for number in range(2):
		var i:=page*page_capacity+number
		cards[number].text=""
		cards[number].visible=number<page_capacity
		if number>=page_capacity:continue
		if tab==2:
			if i<records.size():cards[number].text=records[i]
		elif i<rows.size():
			var row: Dictionary=rows[i]
			cards[number].text=str(row.get("name",row.get("id","隊員")))+"\n"
			if tab==0:cards[number].text+="傷害 %d HP・擊殺 %d\n承傷 %d HP" % [row.get("damage",0),row.get("kills",0),row.get("taken",0)]
			else:cards[number].text+="回復 %d HP・減傷 %d HP\n個人支援（含其羈絆貢獻）" % [row.get("healing",0),row.get("prevented",0)]
	for number in range(3):tabs[number].modulate=Color("ffdc82") if tab==number else Color.WHITE
	_apply_responsive_layout()

func _measured_gain(node: Dictionary,measured: Dictionary) -> String:
	if node.is_empty():return "未裝起始節點・本局無節點增益"
	if bool(node.get("campaign_only",false)) and str(displayed_summary.get("starting_mode",GameManager.run_mode))=="endless":return "封隙專用・無盡不再觸發，適用代價已停用"
	var key: String={"crew_singer":"hymn_casts","bond_harmony":"healing","bond_rail":"moving_hits","bond_relay":"relay_blasts","spec_shield":"shield_damage","spec_escort":"alternative_hold","spec_step":"step_seconds","spec_prepare":"counter_hits"}.get(node.id,"")
	if key!="":
		var amount: float=float(measured.get(key,0))
		if amount<=0:return "%s：本局未觸發額外增益" % node.name
		return {"crew_singer":"療唱施放 %d 次","bond_harmony":"護圈額外回復 %d HP","bond_rail":"機動命中 %d 次","bond_relay":"延後範圍爆炸 %d 次","spec_shield":"實際破盾增傷 %d HP","spec_escort":"圓陣正面實際封合 %.1f 秒","spec_step":"借步實際移動 %.1f 秒","spec_prepare":"延長反擊命中 %d 次"}[node.id] % amount
	if node.id=="spec_collect":return "散兵拾取 +35%%（選散兵時生效）\n替代封合 %.1f 秒" % float(measured.get("alternative_hold",0))
	if node.id=="bond_construct":return "裂傀壽命 +40% 已生效・編隊上限 8 人"
	if node.id=="bond_reserve":return "候補提前 1 級可招募・同系不重複"
	if node.id in ["crew_guard","crew_scout","crew_gunner","crew_shepherd"]:
		var ids: Array=node.get("roster",[])
		var damage:=0.0
		var healing:=0.0
		var prevented:=0.0
		for row in rows:
			if str(row.get("id","")) in ids and str(row.get("id",""))!="rift_captain":
				damage+=float(row.get("damage",0));healing+=float(row.get("healing",0));prevented+=float(row.get("prevented",0))
		return "節點先發實績：傷害 %d HP\n回復 %d HP／減傷 %d HP（含羈絆）" % [damage,healing,prevented]
	return "節點已裝備・隊員表現見輸出／支援分頁"

func _apply_responsive_layout() -> void:
	if not is_instance_valid(panel):return
	if root.visible and page_capacity!=_per_page():
		_refresh()
		return
	var view:=MobileTuning.apply_web_canvas_scale(self,get_viewport().get_visible_rect().size,root)
	var size:=Vector2(minf(920,view.x-16),minf(620,view.y-16))
	panel.position=(view-size)*0.5
	panel.size=size
	var w:=size.x-24
	var portrait:=view.y>view.x
	var scale:=PlayerSettings.get_ui_scale_multiplier()
	title_label.add_theme_font_size_override("font_size",roundi(23*scale))
	for label in [summary_label,gain_label]:label.add_theme_font_size_override("font_size",roundi(14*scale))
	for label in [progress_label,page_label]:label.add_theme_font_size_override("font_size",roundi(12*scale))
	for id in controls:controls[id].add_theme_font_size_override("font_size",roundi(14*scale))
	_place(title_label,12,8,w,30)
	var left_w:=w if portrait else w*0.46-8
	_place(summary_scroll,12,50,left_w,104 if portrait else 114)
	summary_label.custom_minimum_size=Vector2(left_w,0)
	_place(gain_label,12,158 if portrait else 168,left_w,48)
	_place(progress_label,12,208 if portrait else 220,left_w,28 if portrait else 36)
	var tab_y:=240.0 if portrait else 44.0
	var right_x:=12.0 if portrait else 24+left_w
	var right_w:=w if portrait else w-left_w-12
	for number in range(3):_place(tabs[number],right_x+number*(right_w+4)/3,tab_y,(right_w-8)/3,44)
	var pager_y:=size.y-108
	var card_y:=tab_y+50
	var card_h: float=(pager_y-card_y-4)/page_capacity
	for number in range(2):_place(cards[number],right_x,card_y+number*card_h,right_w,card_h-2)
	_place(controls.previous,right_x,pager_y,right_w*0.34,44)
	_place(page_label,right_x+right_w*0.34+4,pager_y+12,right_w*0.32-8,22)
	_place(controls.next,right_x+right_w*0.66,pager_y,right_w*0.34,44)
	for number in range(3):_place([copy_seed_button,main_menu_button,controls.primary][number],12+number*(w+4)/3,size.y-56,(w-8)/3,44)
	for label in cards:label.add_theme_font_size_override("font_size",roundi(14*scale))
	_publish()

func _place(control: Control,x: float,y: float,w: float,h: float) -> void:
	control.position=Vector2(x,y)
	control.size=Vector2(w,h)

func _publish() -> void:
	PROBE.publish("result",MobileTuning.ui_layout_size(get_viewport().get_visible_rect().size),controls,{"visible":root.visible,"victory":victory,"tab":tab,"page":page,"pages":_page_count(),"summary":summary_label.text,"gain":gain_label.text,"progress":progress_label.text,"rows":rows,"cards":[cards[0].text,cards[1].text]})

func _process(_delta: float) -> void:
	if is_instance_valid(root) and root.visible:_publish()

func _on_main_menu_pressed() -> void:
	root.hide()
	if GameManager.active_starting_formal:GameManager.open_preparation_on_menu=true
	if victory and GameManager.active_starting_formal:
		GameManager.game_running=false
		get_tree().paused=false
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	else:main_menu_requested.emit()

func _on_primary_pressed() -> void:
	root.hide()
	if victory:continue_requested.emit()
	else:restart_requested.emit()

func hide_screen() -> void:
	root.hide()

func _update_summary_count(_progress_ratio: float) -> void:
	_refresh()
