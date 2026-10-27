extends CanvasLayer

signal restart_requested
signal continue_requested
signal main_menu_requested
const FONT:=preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
const CATALOG:=preload("res://scripts/services/starting_build_catalog.gd")
const PROBE:=preload("res://scripts/services/qa_bridge.gd")
const SUPPORT_MODEL:=preload("res://scripts/services/support_report_model.gd")
const ANIMATION:=preload("res://scripts/animation/true_animation_library.gd")
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
# Portrait + measured bars behind each card; values come from the same rows.
var card_art: Array[Control]=[]
var card_data: Array[Dictionary]=[{},{}]
var portrait_cache: Dictionary={}
var tab:=0
var page:=0
var rows: Array=[]
var page_capacity:=2
var support_rows: Array=[]

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
	preload("res://scripts/ui/rift_frame_ornament.gd").attach(panel,true,Color("6fc4cf") if victory else Color("f8a3a1"),22.0)
	title_label=_label(23)
	summary_scroll=ScrollContainer.new()
	summary_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	summary_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
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
	for number in range(2):
		var card_label := _label(14)
		card_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cards.append(card_label)
	for number in range(2):
		var art:=Control.new()
		art.name="CardArt%d" % number
		art.mouse_filter=Control.MOUSE_FILTER_IGNORE
		art.draw.connect(_draw_card_art.bind(number))
		panel.add_child(art)
		panel.move_child(art,cards[number].get_index())
		card_art.append(art)
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
	support_rows=SUPPORT_MODEL.build(rows)
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
	var count: int=_records().size() if tab==2 else support_rows.size() if tab==1 else rows.size()
	return maxi(1,ceili(float(count)/_per_page()))


func _per_page() -> int:
	var view:=MobileTuning.ui_layout_size(get_viewport().get_visible_rect().size)
	if view.y>view.x and view.y<640:return 1
	if view.x<=900 and view.y<=430 and int(PlayerSettings.get("ui_scale_index"))>=2:return 1
	return 2

func _records() -> Array[String]:
	var data:=displayed_summary
	var echo: Dictionary=data.get("echo_progress",MetaProgress.get_progress_summary())
	var goal: Dictionary=echo.get("next_goal",MetaProgress.get_next_progress_goal())
	var source_lines: Array[String]=[]
	var sources: Dictionary=data.get("echo_shard_sources",{})
	for source in ["金幣","擊殺","等級","菁英","Boss","出擊保底","驗證固定增量","其他已保存收益"]:
		var amount:=int(sources.get(source,0))
		if amount>0:source_lines.append("%s +%d" % [source,amount])
	var result: Array[String]=[
		"戰利與成長\n金幣 %d・等級 %d\n殘響 +%d・裝備 %d 件\n來源：%s" % [data.get("gold",0),data.get("level",1),data.get("echo_shards_earned",0),data.get("equipment_collected",0),"／".join(source_lines) if not source_lines.is_empty() else "本局沒有已保存收入"],
		"關卡紀錄\n擊殺 %d・菁英 %d\n守門者：%s" % [data.get("kills",0),data.get("elites_killed",0),"已擊破" if data.get("boss_killed",false) else "尚未擊破"]]
	if goal.get("kind","")=="lifetime":result.append("局外目標\n%s：永久殘響 %d/%d\n還差 %d" % [goal.get("name","下一解鎖"),goal.get("current",0),goal.get("target",0),goal.get("remaining",0)])
	elif goal.get("kind","")=="spendable":result.append("局外目標\n%s：可用殘響 %d/%d\n還差 %d" % [goal.get("name","下一強化"),goal.get("current",0),goal.get("target",0),goal.get("remaining",0)])
	else:result.append("局外目標\n"+str(goal.get("name","目前強化已完成")))
	for achievement in data.get("achievement_unlocks",[]):result.append("本局新解鎖\n"+str(achievement.get("name","")))
	return result

func _hero_display_name(hero_id: String) -> String:
	var path := "res://resources/heroes/%s.tres" % hero_id
	if hero_id != "" and ResourceLoader.exists(path):
		return str(load(path).get("display_name"))
	return hero_id
func bond_condition_for(present_ids: Array) -> String:
	var tables: GDScript = load("res://scripts/heroes/squad_manager.gd")
	var present := {}
	for id in present_ids:
		present[str(id)] = true
	var best_missing: Array = []
	var best_name := ""
	for definition in tables.BOND_DEFINITIONS:
		var missing: Array = []
		for hero_id in definition.get("hero_ids", []):
			if not present.has(str(hero_id)):
				missing.append(str(hero_id))
		if missing.is_empty():
			return "羈絆「%s」已成立" % str(definition.get("name", ""))
		if best_missing.is_empty() or missing.size() < best_missing.size():
			best_missing = missing
			best_name = str(definition.get("name", ""))
	if best_missing.is_empty():
		return "尚未成立羈絆"
	var names := PackedStringArray()
	for hero_id in best_missing:
		names.append(_hero_display_name(hero_id))
	return "再招募 %s 可成立「%s」" % ["、".join(names), best_name]
func _roster_ids() -> Array:
	var present: Array = []
	for row in rows:
		if str(row.get("id", "")) == "support_zero_group":
			present.append_array(row.get("member_ids", []))
		else:
			present.append(str(row.get("id", "")))
	return present
func bond_zero_reason_text() -> String:
	var condition := bond_condition_for(_roster_ids())
	# A bond that formed but never fired must not read as "not formed".
	if condition.ends_with("已成立"):
		return "%s・本局未觸發加成" % condition
	return "羈絆未成立：%s" % condition
# One summary line, as short as the 0/0 line it replaces, so portrait
# result cards keep their height; the support tab holds the full condition.
func summary_bond_line() -> String:
	var condition := bond_condition_for(_roster_ids())
	if condition.ends_with("已成立"):
		return "羈絆收益 0・已成立未觸發"
	if condition.begins_with("再招募 "):
		return "羈絆收益 0・再招募%s可成立" % condition.trim_prefix("再招募 ").get_slice(" ", 0).get_slice("、", 0)
	return "羈絆收益 0・尚未成立"
static func name_line_fits(name: String, font: Font, font_size: int, width: float) -> bool:
	if font == null:
		return true
	return font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width
func _refresh() -> void:
	page_capacity=_per_page()
	var build: Dictionary=displayed_summary.get("starting_build",{})
	var team: String=str(build.get("team",GameManager.active_starting_team))
	var node: Dictionary=CATALOG.node(str(build.get("node",GameManager.active_starting_node)))
	var bond: Dictionary=displayed_summary.get("bond_benefits",GameManager.bond_benefits)
	var outcome: String="擊破"+str(displayed_summary.get("boss_name",GameManager.STAGE_CATALOG.get_stage(GameManager.selected_stage_id).get("boss_name","守門者"))) if victory else "先鋒的殘響"
	var echo: Dictionary=displayed_summary.get("echo_progress",MetaProgress.get_progress_summary())
	var goal: Dictionary=echo.get("next_goal",MetaProgress.get_next_progress_goal())
	summary_label.text="%s｜%s\n%s・%s\n擊殺 %d・存活 %d/%d\n羈絆收益（全隊加成）回%d／減%d HP\n殘響 +%d・現有 %d\n下一步 %s・%s" % [CATALOG.TEAMS.get(team,CATALOG.TEAMS.legacy).name,node.get("name","未裝節點"),outcome,GameManager.format_time(float(displayed_summary.get("elapsed_time",0))),displayed_summary.get("kills",0),displayed_summary.get("squad_alive",0),displayed_summary.get("squad_total",rows.size()),bond.get("healing",0),bond.get("prevented",0),displayed_summary.get("echo_shards_earned",0),echo.get("shards",MetaProgress.shards),goal.get("name","強化完成"),("還差 %d" % int(goal.get("remaining",0))) if int(goal.get("remaining",0))>0 else ("可在整備兌換" if goal.get("kind","")=="spendable" else "已達成")]
	if int(bond.get("healing",0)) == 0 and int(bond.get("prevented",0)) == 0:
		summary_label.text = summary_label.text.replace("羈絆收益（全隊加成）回0／減0 HP", summary_bond_line())
	if not victory:
		var advice:=_defeat_advice(displayed_summary.get("seal_state",{}))
		if advice!="":summary_label.text+="\n"+advice
	gain_label.text=_measured_gain(node,build.get("benefits",{}))
	progress_label.text=MetaProgress.starting_choice_progress_text()
	if not GameManager.pending_starting_settlements.is_empty():progress_label.text="進度未保存・整備可重試"
	page=clampi(page,0,_page_count()-1)
	page_label.text="%d / %d 頁" % [page+1,_page_count()]
	var records:=_records()
	for number in range(2):
		var i:=page*page_capacity+number
		cards[number].text=""
		card_data[number]={}
		cards[number].visible=number<page_capacity
		if number>=page_capacity:continue
		if tab==2:
			if i<records.size():cards[number].text=records[i]
		else:
			var displayed_rows: Array=support_rows if tab==1 else rows
			if i>=displayed_rows.size():continue
			var row: Dictionary=displayed_rows[i]
			card_data[number]=_card_visual(row,displayed_rows)
			cards[number].text=str(row.get("name",row.get("id","隊員")))+"\n"
			if tab==0:cards[number].text+="傷害 %d HP・擊殺 %d\n承傷 %d HP" % [row.get("damage",0),row.get("kills",0),row.get("taken",0)]
			# One header line keeps the full zero-support roster inside its card.
			elif str(row.get("id",""))=="support_zero_group":cards[number].text=str(row.get("name","未觸發隊員"))+"\n"+bond_condition_for(_roster_ids())+"\n"+"、".join(row.get("member_names",[]))
			else:cards[number].text+="個人總計（含羈絆）\n回復 %d HP・減傷 %d HP" % [row.get("healing",0),row.get("prevented",0)]
	for number in range(3):tabs[number].modulate=Color("ffdc82") if tab==number else Color.WHITE
	_apply_responsive_layout()

func _portrait_size(card_h: float) -> float:
	return clampf(card_h-14.0,30.0,64.0)

func _portrait(hero_id: String) -> Texture2D:
	if portrait_cache.has(hero_id):return portrait_cache[hero_id]
	var path:="res://resources/heroes/%s.tres" % hero_id
	var texture: Texture2D=null
	if hero_id!="" and ResourceLoader.exists(path):
		var hero: Resource=load(path)
		var frames:=ANIMATION.get_sprite_frames(str(hero.get("sprite_path")))
		texture=frames.get_frame_texture(&"idle",0) if frames!=null else null
	portrait_cache[hero_id]=texture
	return texture

static func bar_fraction(value: float, top: float) -> float:
	return clampf(value / maxf(1.0, top), 0.0, 1.0)

func _card_visual(row: Dictionary,displayed_rows: Array) -> Dictionary:
	var ids: Array=row.get("member_ids",[]) if str(row.get("id",""))=="support_zero_group" else [str(row.get("id",""))]
	var bars: Array=[]
	if tab==0:
		var top_damage:=1.0
		var top_taken:=1.0
		for other in displayed_rows:
			top_damage=maxf(top_damage,float(other.get("damage",0)))
			top_taken=maxf(top_taken,float(other.get("taken",0)))
		# One shared scale: damage and damage taken stay comparable even on a
		# single-row page, where per-stat scales made every bar full length.
		var top_output:=maxf(top_damage,top_taken)
		bars=[[bar_fraction(float(row.get("damage",0)),top_output),Color("ffb36b"),"傷害"],[bar_fraction(float(row.get("taken",0)),top_output),Color("ff7a8a"),"承傷"]]
	elif str(row.get("id",""))!="support_zero_group":
		var top:=1.0
		for other in displayed_rows:top=maxf(top,float(other.get("healing",0))+float(other.get("prevented",0)))
		bars=[[bar_fraction(float(row.get("healing",0)),top),Color("8ff0a4"),"回復"],[bar_fraction(float(row.get("prevented",0)),top),Color("91dafa"),"減傷"]]
	return {"ids":ids,"bars":bars,"group":str(row.get("id",""))=="support_zero_group"}

func _draw_card_art(number: int) -> void:
	var art:=card_art[number]
	var data: Dictionary=card_data[number]
	if data.is_empty():return
	var box:=Rect2(Vector2.ZERO,art.size)
	art.draw_rect(box,Color("0d1a2a"),true)
	art.draw_rect(box,Color("2f5568"),false,1.0)
	var size:=_portrait_size(box.size.y)
	var ids: Array=data.get("ids",[])
	if bool(data.get("group",false)):
		# The grouped roster is already listed by name; keep the card text-only.
		return
	if ids.size()==1:
		var frame:=Rect2(6,(box.size.y-size)*0.5,size,size)
		art.draw_rect(frame,Color("14283b"),true)
		art.draw_rect(frame,Color("77cdda"),false,1.0)
		var texture:=_portrait(str(ids[0]))
		if texture!=null:art.draw_texture_rect(texture,frame.grow(-2),false)
	else:
		var small:=minf(size*0.55,(box.size.x*0.3)/maxf(1,ids.size()))
		for i in range(ids.size()):
			var texture:=_portrait(str(ids[i]))
			var frame:=Rect2(6+i*(small+3),(box.size.y-small)*0.5,small,small)
			art.draw_rect(frame,Color("14283b"),true)
			if texture!=null:art.draw_texture_rect(texture,frame.grow(-1),false,Color(1,1,1,0.55))
	var bars: Array=data.get("bars",[]) if bool(data.get("show_bars",false)) else []
	# Short legend before each bar; the scale is the top value on this screen.
	var bar_x:=size+48.0
	var bar_w:=box.size.x-bar_x-10
	for i in range(bars.size()):
		var y:=box.size.y-6-(bars.size()-i)*13.0
		art.draw_string(FONT,Vector2(size+12,y+8),str(bars[i][2]),HORIZONTAL_ALIGNMENT_LEFT,34,11,Color(bars[i][1],0.95))
		art.draw_rect(Rect2(bar_x,y,bar_w,5),Color("1d3244"),true)
		art.draw_rect(Rect2(bar_x,y,maxf(0,bar_w*clampf(float(bars[i][0]),0,1)),5),bars[i][1],true)

# One concrete next-run hint from the real seal state; nothing is invented.
func _defeat_advice(seal: Dictionary) -> String:
	if seal.is_empty():return ""
	var names:={"wedge":"楔形","ring":"圓陣","scatter":"散兵"}
	var step:=int(seal.get("step",0))
	if bool(seal.get("completed",false)):return "下次：三道已封，趁封合後的反擊增傷集火守門者"
	var need:=str(names.get(str(seal.get("required","")),""))
	var held:=str(names.get(str(seal.get("formation","")),""))
	if int(seal.get("wrong",0))>0:return "下次：倒在第 %d 道（需%s，當時%s），錯陣反噬 %d 次；先看危險區上的陣形圖示" % [mini(step+1,3),need,held,int(seal.get("wrong",0))]
	return "下次：倒在第 %d 道（封隙 %d/3），攻勢間隙帶兩名隊友站進封隙" % [mini(step+1,3),step]

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
	summary_label.add_theme_font_size_override("font_size",roundi((12 if portrait and view.x<=360 else 14)*scale))
	for label in [gain_label]:label.add_theme_font_size_override("font_size",roundi(14*scale))
	for label in [progress_label,page_label]:label.add_theme_font_size_override("font_size",roundi(12*scale))
	for id in controls:controls[id].add_theme_font_size_override("font_size",roundi(14*scale))
	_place(title_label,54,8,w-42,30)
	var left_w:=w if portrait else w*0.46-8
	summary_label.custom_minimum_size=Vector2(left_w,0)
	var tab_y:=44.0
	if portrait:
		# Stack the portrait summary from its real line count so the echo and
		# next-goal lines are never hidden behind the measured-gain line.
		var summary_h:=minf(size.y-300,_text_height(summary_label,left_w))
		var gain_h:=_text_height(gain_label,left_w) if gain_label.text!="" else 0.0
		_place(summary_scroll,12,50,left_w,summary_h)
		_place(gain_label,12,52+summary_h,left_w,gain_h)
		var progress_h:=_text_height(progress_label,left_w)
		_place(progress_label,12,54+summary_h+gain_h,left_w,progress_h)
		tab_y=minf(size.y-226,58+summary_h+gain_h+progress_h)
	else:
		# Same real-line stacking in landscape; maximum UI scale needs more
		# than the old fixed 150 px for six summary lines.
		var summary_h:=minf(size.y-210,maxf(150.0,_text_height(summary_label,left_w)))
		var gain_y:=maxf(206.0,54+summary_h)
		_place(summary_scroll,20,50,left_w-8,summary_h)
		_place(gain_label,20,gain_y,left_w-8,48)
		_place(progress_label,20,gain_y+50,left_w-8,36)
	var right_x:=12.0 if portrait else 24+left_w
	var right_w:=w if portrait else w-left_w-12
	for number in range(3):_place(tabs[number],right_x+number*(right_w+4)/3,tab_y,(right_w-8)/3,44)
	var pager_y:=size.y-108
	var card_y:=tab_y+50
	var card_h: float=(pager_y-card_y-4)/page_capacity
	for number in range(2):
		var card_rect:=Rect2(right_x,card_y+number*card_h,right_w,card_h-2)
		_place(card_art[number],card_rect.position.x,card_rect.position.y,card_rect.size.x,card_rect.size.y)
		card_art[number].visible=cards[number].visible and not card_data[number].is_empty()
		var group: bool=bool(card_data[number].get("group",false))
		var indent:=_portrait_size(card_rect.size.y)+12.0 if card_art[number].visible and not group else 0.0
		# Bars need a wide card; narrow portrait cards keep the full text instead.
		var bars_h:=float(card_data[number].get("bars",[]).size())*13.0+4.0 if card_art[number].visible else 0.0
		# Bars only where the real wrapped text still fits above them.
		if bars_h>0 and _text_height(cards[number],card_rect.size.x-indent-4)+bars_h>card_rect.size.y-2:bars_h=0.0
		card_data[number]["show_bars"]=bars_h>0
		var name_line: String = cards[number].text.split("\n")[0] if cards[number].text != "" else ""
		var card_font: Font = cards[number].get_theme_font("font")
		var fitted_size: int = roundi(14*scale)
		while fitted_size > 10 and not name_line_fits(name_line, card_font, fitted_size, card_rect.size.x-indent-8):
			fitted_size -= 1
		cards[number].add_theme_font_size_override("font_size", fitted_size)
		_place(cards[number],card_rect.position.x+indent,card_rect.position.y+2,card_rect.size.x-indent-4,card_rect.size.y-bars_h-2)
		card_art[number].queue_redraw()
	_place(controls.previous,right_x,pager_y,right_w*0.34,44)
	_place(page_label,right_x+right_w*0.34+4,pager_y+12,right_w*0.32-8,22)
	_place(controls.next,right_x+right_w*0.66,pager_y,right_w*0.34,44)
	for number in range(3):_place([copy_seed_button,main_menu_button,controls.primary][number],12+number*(w+4)/3,size.y-56,(w-8)/3,44)
	# Card font sizes are fitted per-card above so names never wrap.
	_publish()

func _text_height(label: Label,width: float) -> float:
	# Real wrapped line count x font line height (incl. theme line spacing),
	# so maximum UI scale and CJK glyph height are measured, not estimated.
	label.size=Vector2(width,label.size.y)
	var font: Font=label.get_theme_font("font")
	var font_size: int=label.get_theme_font_size("font_size")
	var spacing: float=float(label.get_theme_constant("line_spacing"))
	var lines:=maxi(label.get_line_count(),label.text.count("
")+1)
	return lines*(font.get_height(font_size)+spacing)+6.0

func _place(control: Control,x: float,y: float,w: float,h: float) -> void:
	control.position=Vector2(x,y)
	control.size=Vector2(w,h)

func _publish() -> void:
	var visible_support_members: Array=[]
	if tab==1:
		for slot in range(page_capacity):
			var index:=page*page_capacity+slot
			if index>=support_rows.size():continue
			var item: Dictionary=support_rows[index]
			if str(item.get("id",""))=="support_zero_group":
				for i in range(item.get("member_ids",[]).size()):visible_support_members.append({"id":item.member_ids[i],"name":item.member_names[i],"grouped":true})
			else:visible_support_members.append({"id":item.get("id",""),"name":item.get("name",item.get("id","隊員")),"grouped":false})
	PROBE.publish("result",MobileTuning.ui_layout_size(get_viewport().get_visible_rect().size),controls,{"visible":root.visible,"victory":victory,"tab":tab,"page":page,"pages":_page_count(),"summary":summary_label.text,"gain":gain_label.text,"progress":progress_label.text,"rows":rows,"support_rows":support_rows,"visible_support_members":visible_support_members,"cards":[cards[0].text,cards[1].text]})

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
