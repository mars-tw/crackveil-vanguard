extends Node2D

# A world-space objective: a formation button alone cannot close a seal.
# The captain must reach the anchor and two living followers must settle into
# their real formation slots. All combat, collision and animation keep running.
const ORDER := ["wedge", "ring", "scatter"]
const NAMES := ["楔形", "圓陣", "散兵"]
const COLORS := [Color("ffae78"), Color("91dafa"), Color("b2ec9b")]
const HOLD_SECONDS := 6.0
const OPEN_TIMES := [12.0, 46.0, 84.0]
const CAPTAIN_RADIUS := 54.0
const FOLLOWER_TOLERANCE := 66.0
const FONT := preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
var anchor := Vector2.ZERO
var step := 0
var hold := 0.0
var settled := 0
var completed := false
var reward_saved := false
var retry_timer := 0.0
var history: Array[Dictionary] = []
var pressure: Node2D
var wrong_timer := 0.0
var wrong_penalties := 0
var counter_timer := 0.0
var feedback_timer := 0.0
var label_layer: CanvasLayer
var marker_label: Label

func required_formation() -> String:
	if is_instance_valid(pressure):
		if GameManager.active_starting_node=="spec_escort" and pressure.kind=="front": return "ring"
		if GameManager.active_starting_node=="spec_collect" and pressure.kind=="pincer": return "scatter"
	return str(pressure.COUNTERS[pressure.kind]) if is_instance_valid(pressure) else ORDER[mini(step,2)]

func is_open() -> bool:
	return not completed and GameManager.elapsed_time >= OPEN_TIMES[mini(step,2)]

func marker_text() -> String:
	return "第 %d 道・%s" % [mini(step+1,3), "封合" if completed else "反噬" if wrong_timer > 0 else "就位 %d/2" % mini(2,settled)]

func next_action() -> String:
	if not is_open():
		return "陣記穩定中・%d 秒" % ceili(OPEN_TIMES[mini(step,2)]-GameManager.elapsed_time)
	if wrong_timer > 0:
		return "錯陣反噬・進度歸零"
	if hold > 0:
		return "就位 %d/2・封合 %d%%" % [mini(2,settled),int(hold/HOLD_SECONDS*100)]
	return pressure.status_text()

func _update_label() -> void:
	if not is_instance_valid(marker_label) or not is_instance_valid(GameManager.player):
		return
	var picker := marker_label.get_parent().get_node_or_null("FormationPicker")
	var choosing: bool = is_instance_valid(picker) and picker.visible
	marker_label.visible = GameManager.game_running and GameManager.run_mode=="campaign" and not completed and not get_tree().paused and not choosing
	if not marker_label.visible:
		return
	# Reassert the CSS font after the HUD's general accessibility pass.
	marker_label.add_theme_font_size_override("font_size",14)
	marker_label.text = marker_text()
	marker_label.reset_size()
	var view := MobileTuning.ui_layout_size(get_viewport_rect().size)
	var canvas := get_viewport().get_canvas_transform()
	var point: Vector2 = canvas * anchor
	var captain: Vector2 = canvas * GameManager.player.global_position
	var scale_factor: float = get_viewport_rect().size.x/maxf(1,view.x)
	point /= scale_factor
	captain /= scale_factor
	var width := 174.0
	var y := clampf(point.y+65,150.0,view.y-158)
	var x := clampf(point.x-width/2,12.0,view.x-width-90)
	# Label is independent of world depth, outside notices and character bounds.
	var reserved := BattleLayout.regions(view,MobileTuning.use_mobile_ui(view))
	var rect := Rect2(x,y,width,30)
	for key in ["notice","combo","minimap"]:
		if rect.intersects(reserved[key]):
			y = maxf(y,reserved[key].end.y+5)
	var candidates: Array[Vector2] = [Vector2(x,y)]
	for row in range(4):
		for column in range(4):
			candidates.append(Vector2(12+column*(view.x-width-112)/3,maxf(140,y-36+row*32)))
	for candidate in candidates:
		var candidate_rect := Rect2(candidate,Vector2(width,30))
		var clear := Rect2(8,136,view.x-96,view.y-284).encloses(candidate_rect) if view.x>view.y else Rect2(8,268,view.x-24,view.y-440).encloses(candidate_rect)
		for region in reserved.values():
			if candidate_rect.intersects(region):clear=false
		for member in GameManager.squad_manager.get_members():
			var member_screen: Vector2=canvas*member.global_position/scale_factor
			if candidate_rect.intersects(Rect2(member_screen-Vector2(26,55),Vector2(52,76))):clear=false
		if clear:
			x=candidate.x
			y=candidate.y
			break
	marker_label.position = Vector2(x,y)
	marker_label.size = Vector2(width,30)
	marker_label.text = marker_text()


func _ready() -> void:
	anchor = GameManager.player.global_position + Vector2(140, 0) if is_instance_valid(GameManager.player) else Vector2.ZERO
	z_index = 1
	pressure = preload("res://scripts/services/encounter_pressure.gd").new()
	add_child(pressure)
	pressure.configure(anchor,step)
	marker_label = Label.new()
	marker_label.add_theme_font_size_override("font_size",14)
	marker_label.add_theme_color_override("font_color",Color("ffdcac"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111b2b")
	style.border_color = Color("c5a980")
	style.set_border_width_all(1)
	style.set_content_margin_all(4)
	marker_label.add_theme_stylebox_override("normal",style)
	marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Share the HUD's CSS-space canvas, above notices but below modal pages.
	marker_label.z_index = 28
	GameManager.arena.get_node("HUD").root.add_child(marker_label)

func _process(delta: float) -> void:
	_update_label()
	visible = GameManager.run_mode == "campaign" and GameManager.game_running and not completed
	if get_tree().paused or not GameManager.game_running:
		return
	if GameManager.run_mode!="campaign":
		_tick_feedback(delta)
		return
	advance(delta)
	queue_redraw()

func _tick_feedback(delta: float) -> void:
	wrong_timer = maxf(0,wrong_timer-delta)
	counter_timer = maxf(0,counter_timer-delta)
	feedback_timer = maxf(0,feedback_timer-delta)

func advance(delta: float) -> void:
	_tick_feedback(delta)
	if completed:
		if GameManager.boss_killed:
			GameManager.try_complete_campaign_victory()
		if not reward_saved:
			retry_timer = maxf(0.0, retry_timer - maxf(0.0, delta))
			if retry_timer <= 0.0:
				reward_saved = MetaProgress.award_formation_seal(GameManager.selected_stage_id) >= 0
				retry_timer = 2.0
		return
	var squad: Node = GameManager.squad_manager
	var captain: Node2D = GameManager.player
	if not is_instance_valid(squad) or not is_instance_valid(captain) or not captain.is_alive:
		hold = 0.0
		return
	settled = 0
	if not is_open():
		hold = 0
		return
	pressure.begin()
	var correct: bool = GameManager.STARTING_BUILD.accepts(GameManager.active_starting_node,pressure.kind,squad.get_formation_id())
	if not correct and captain.global_position.distance_to(anchor) <= CAPTAIN_RADIUS and wrong_timer <= 0:
		wrong_timer = 2.5
		wrong_penalties += 1
		captain.take_damage(8.0,anchor+Vector2(1,0))
		GameManager.show_toast("錯陣反噬：封合中斷，觀察敵軍攻勢再換陣")
	if correct:
		for member in squad.get_members():
			if not is_instance_valid(member) or member == captain or not member.is_alive:
				continue
			if member.global_position.distance_to(squad.get_formation_world_position(member.formation_index)) <= FOLLOWER_TOLERANCE:
				settled += 1
	if not correct or captain.global_position.distance_to(anchor) > 160:
		hold = 0.0
		return
	# Warning and active geometry must be handled before the seal advances.
	if pressure.phase != "recovery":
		return
	if captain.global_position.distance_to(anchor) > CAPTAIN_RADIUS or settled < 2:
		# Dodge, then regroup: a short return window preserves banked hold.
		if pressure.clock > pressure.WARNING + pressure.ACTIVE + 1.1:
			hold = 0
		return
	var gained: float=maxf(0.0, delta) * (0.85 if GameManager.active_starting_node=="spec_escort" and pressure.kind=="front" and squad.get_formation_id()=="ring" else 1.0)
	hold += gained
	if squad.get_formation_id()!=str(pressure.COUNTERS[pressure.kind]): GameManager.starting_benefits.alternative_hold+=gained
	if hold < HOLD_SECONDS:
		return
	if step==2 and GameManager.elapsed_time<90.0:
		return
	history.append({"formation": squad.get_formation_id(), "pressure":pressure.kind,"cycles":pressure.cycles,"time": GameManager.elapsed_time, "followers": settled})
	counter_timer = 5.0
	if GameManager.active_starting_node=="spec_prepare": counter_timer=10.0
	feedback_timer = 1.4
	GameManager.request_combat_impact(5.0,0.035)
	EntityFactory.spawn_death_burst(anchor,Color("ffdcac"),3.4,"gold_rain")
	if GameManager.active_starting_node=="spec_prepare":
		for member in squad.get_members(): GameManager.starting_benefits.healing_forgone+=minf(8,member.max_hp-member.current_hp)
	else:
		squad.heal_members(8.0)
	step += 1
	hold = 0.0
	if step == ORDER.size():
		completed = true
		pressure.enabled = false
		GameManager.try_complete_campaign_victory()
		var reward := MetaProgress.award_formation_seal(GameManager.selected_stage_id)
		reward_saved = reward >= 0
		retry_timer = 2.0
		var record := "首次封隙殘響 +4。" if reward > 0 else "本關封隙已收藏。" if reward == 0 else "紀錄尚未存好，稍後重試。"
		GameManager.show_toast(("三陣封隙完成！放棄治療・反擊 +20%，10 秒；" if GameManager.active_starting_node=="spec_prepare" else "三陣封隙完成！全隊整補；") + record)
	else:
		anchor += Vector2(0, -170) if step == 1 else Vector2(-210, 0)
		pressure.configure(anchor,step)
		GameManager.show_toast("封隙 %d/3｜放棄治療・反擊傷害 +20%%，10 秒" % step if GameManager.active_starting_node=="spec_prepare" else "封隙 %d/3｜對陣整補 +8・反擊傷害 +20%%，5 秒" % step)
	if AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("level_up")

func hint() -> String:
	return "封隙 3/3・完成" if completed else "封隙 %d/3｜第 %d 道・%s" % [step,step+1,next_action()]

func probe() -> Dictionary:
	var screen := get_viewport().get_canvas_transform() * anchor
	var captain_screen: Vector2 = get_viewport().get_canvas_transform() * GameManager.player.global_position if is_instance_valid(GameManager.player) else Vector2.ZERO
	return {"step": step,"pressure":pressure.kind,"phase":pressure.phase,"cycles":pressure.cycles,"wrong":wrong_penalties,"required":required_formation(),"marker":marker_text(),"open":is_open(), "completed": completed, "hold": hold, "settled": settled, "distance": GameManager.player.global_position.distance_to(anchor) if is_instance_valid(GameManager.player) else -1.0, "anchor_x": screen.x, "anchor_y": screen.y, "captain_x":captain_screen.x, "captain_y":captain_screen.y, "saved": reward_saved}

func _draw() -> void:
	if completed or not is_instance_valid(GameManager.player):
		return
	var color: Color = COLORS[step]
	# Four etched corners: task marker, never a defensive circle.
	var edge := CAPTAIN_RADIUS
	var diamond := PackedVector2Array([anchor+Vector2(0,-edge),anchor+Vector2(edge,0),anchor+Vector2(0,edge),anchor+Vector2(-edge,0),anchor+Vector2(0,-edge)])
	draw_colored_polygon(PackedVector2Array([anchor+Vector2(0,-edge),anchor+Vector2(edge,0),anchor+Vector2(0,edge),anchor+Vector2(-edge,0)]),Color(0.025,0.04,0.06,0.65))
	draw_polyline(diamond,Color("ffdcac") if is_open() else Color("758495"),3,true)
	for i in range(4):
		var point := anchor+Vector2.from_angle(i*PI/2)*edge
		draw_circle(point,4,color)
	if hold > 0:
		draw_line(anchor+Vector2(-44,66),anchor+Vector2(44,66),Color("253446"),5,true)
		draw_line(anchor+Vector2(-44,66),anchor+Vector2(-44+88*hold/HOLD_SECONDS,66),Color.WHITE,5,true)
	if wrong_timer > 0:
		draw_line(anchor-Vector2(23,23),anchor+Vector2(23,23),Color("ff637c"),5,true)
		draw_line(anchor+Vector2(23,-23),anchor+Vector2(-23,23),Color("ff637c"),5,true)
	var captain: Node2D = GameManager.player
	var direction := captain.global_position.direction_to(anchor)
	if captain.global_position.distance_to(anchor) > CAPTAIN_RADIUS:
		var tip := captain.global_position + direction * 62
		draw_line(tip - direction * 18, tip, color, 3, true)
		draw_line(tip, tip - direction.rotated(0.65) * 12, color, 3, true)
		draw_line(tip, tip - direction.rotated(-0.65) * 12, color, 3, true)
