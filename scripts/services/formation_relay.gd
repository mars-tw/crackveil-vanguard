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
const BADGES := {"wedge": preload("res://assets/ui/r8_vector/badge_wedge.svg"), "ring": preload("res://assets/ui/r8_vector/badge_ring.svg"), "scatter": preload("res://assets/ui/r8_vector/badge_scatter.svg")}
const SEAL_EMBLEM := preload("res://assets/ui/r8_vector/seal_emblem.svg")
const SEAL_STAGE_MARK := preload("res://assets/ui/r10_vector/seal_stage_mark.svg")
const GUIDE_ARROW := preload("res://assets/ui/r10_vector/guide_arrow.svg")
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
# Seal-success presentation at the closed anchor; never feeds combat.
var seal_flash_time := 99.0
var seal_flash_at := Vector2.ZERO
var seal_flash_text := ""
const SEAL_FLASH_SECONDS := 2.6
var label_layer: CanvasLayer
var marker_label: Label
var equipment_details: Control

func required_formation() -> String:
	if is_instance_valid(pressure):
		if GameManager.active_starting_node=="spec_escort" and pressure.kind=="front": return "ring"
		if GameManager.active_starting_node=="spec_collect" and pressure.kind=="pincer": return "scatter"
	return str(pressure.COUNTERS[pressure.kind]) if is_instance_valid(pressure) else ORDER[mini(step,2)]

func accepted_formations() -> Array[String]:
	var accepted: Array[String] = []
	if not is_instance_valid(pressure):
		return accepted
	for id in ORDER:
		if GameManager.STARTING_BUILD.accepts(GameManager.active_starting_node,pressure.kind,id):
			accepted.append(id)
	return accepted

func accepted_text() -> String:
	var names := PackedStringArray()
	for id in accepted_formations():
		names.append(NAMES[ORDER.find(id)])
	return "可用：%s" % "／".join(names) if names.size() > 1 else "需%s" % (names[0] if names.size() == 1 else NAMES[ORDER.find(required_formation())])

func seal_stage_tint(stage_index: int) -> Color:
	match clampi(stage_index, 0, 2):
		0: return Color.from_hsv(185.0 / 360.0, 0.68, 0.88)
		1: return Color.from_hsv(45.0 / 360.0, 0.72, 0.92)
		_: return Color.from_hsv(280.0 / 360.0, 0.58, 0.90)

func seal_stage_edge(stage_index: int) -> Color:
	match clampi(stage_index, 0, 2):
		0: return Color.from_hsv(185.0 / 360.0, 0.55, 1.0)
		1: return Color.from_hsv(45.0 / 360.0, 0.65, 1.0)
		_: return Color.from_hsv(280.0 / 360.0, 0.52, 1.0)

const SEAL_STAGE_HUES := [185.0, 45.0, 280.0]
const SEAL_FLASH_MAX_ALPHA := 0.80
var formation_link_timer := 0.0
var _last_formation_id := ""
static func seal_stage_hue(stage_index: int) -> float:
	return SEAL_STAGE_HUES[clampi(stage_index, 0, 2)]
static func seal_stage_mark_count(stage_index: int) -> int:
	return clampi(stage_index, 0, 2) + 1
func formation_link_alpha() -> float:
	return 1.0 if formation_link_timer > 0.0 else 0.22 # timer is set to exactly 1.0s on switch
func seal_ground_fill_alpha() -> float:
	return 0.20

func member_zone_state(member_position: Vector2) -> String:
	var local := member_position - anchor
	return "inside" if absf(local.x) + absf(local.y) <= CAPTAIN_RADIUS else "outside"

# Beyond this range the off-screen pointer leads instead of a fan of lines.
const GUIDE_LINE_RANGE := 360.0
const GUIDE_ARROW_LENGTH := 24.0
static func guide_arrow_length() -> float:
	return GUIDE_ARROW_LENGTH

func guide_line_points(member_position: Vector2) -> PackedVector2Array:
	var direction := member_position.direction_to(anchor)
	var start := member_position + Vector2(0, 14)
	var tip := start + direction * GUIDE_ARROW_LENGTH
	return PackedVector2Array([start, tip])

func clear_wrong_if_correct() -> bool:
	if wrong_timer <= 0.0:
		return false
	if not is_instance_valid(pressure) or not is_instance_valid(GameManager.squad_manager):
		return false
	if GameManager.STARTING_BUILD.accepts(GameManager.active_starting_node, pressure.kind, GameManager.squad_manager.get_formation_id()):
		wrong_timer = 0.0
		return true
	return false

func clear_wrong_notice() -> void:
	if is_instance_valid(GameManager.arena):
		var hud: Node = GameManager.arena.get_node_or_null("HUD")
		if hud != null and hud.has_method("clear_wrong_formation_notice"):
			hud.clear_wrong_formation_notice()
		elif hud != null:
			var inner: Node = hud.get_node_or_null("HUD")
			if inner != null and inner.has_method("clear_wrong_formation_notice"):
				inner.clear_wrong_formation_notice()

func switch_hint() -> String:
	return "點陣形鈕" if MobileTuning.has_confirmed_touch() else "按 Q 切換"

func consequence_text(result: Dictionary) -> String:
	if bool(result.get("correct",false)):
		return "陣形正確・站進封隙累積封合"
	# The wave was lost to the wrong formation, but the squad may already have
	# switched; never tell the player to switch to what they already hold.
	var current: String = GameManager.squad_manager.get_formation_id() if is_instance_valid(GameManager.squad_manager) else ""
	if current != "" and accepted_formations().has(current):
		return "已換%s・站進封隙重新封合" % NAMES[ORDER.find(current)]
	return "%s才能封合・%s" % [accepted_text(),switch_hint()]

func is_open() -> bool:
	return not completed and GameManager.elapsed_time >= OPEN_TIMES[mini(step,2)]

func marker_text() -> String:
	return "第 %d 道・%s" % [mini(step+1,3), "封合" if completed else "反噬" if wrong_timer > 0 else "到位 %d 人・需 2" % settled]

func next_action() -> String:
	if not is_open():
		return "陣記穩定中・%d 秒" % ceili(OPEN_TIMES[mini(step,2)]-GameManager.elapsed_time)
	if wrong_timer > 0:
		var needed_id:=str(pressure.COUNTERS[pressure.kind]) if is_instance_valid(pressure) else "wedge"
		var current: String=GameManager.squad_manager.get_formation_id() if is_instance_valid(GameManager.squad_manager) else ""
		if is_instance_valid(pressure) and GameManager.STARTING_BUILD.accepts(GameManager.active_starting_node,pressure.kind,current):
			return "錯陣反噬・進度歸零・已換%s，重新封合" % NAMES[maxi(0,ORDER.find(current))]
		return "錯陣反噬・進度歸零・需%s・%s" % [NAMES[ORDER.find(needed_id)],switch_hint()]
	if is_instance_valid(pressure) and pressure.started and pressure.phase in ["warning","active"]:
		var needed:=required_formation()
		var selected: String=GameManager.squad_manager.get_formation_id() if is_instance_valid(GameManager.squad_manager) else "wedge"
		if GameManager.STARTING_BUILD.accepts(GameManager.active_starting_node,pressure.kind,selected):
			var label: String = accepted_text() if accepted_formations().size() > 1 else "建議%s" % NAMES[ORDER.find(needed)]
			return "%s・%s・陣形正確" % [pressure.status_text(),label]
		return "%s・%s・%s" % [pressure.status_text(),accepted_text(),switch_hint()]
	if hold > 0:
		return "到位 %d 人（需 2）・封合 %d%%" % [settled,int(hold/HOLD_SECONDS*100)]
	if counter_timer>0:
		var label: String="放棄治療・反擊增傷" if GameManager.active_starting_node=="spec_prepare" else "對陣反擊增傷"
		return "%s +20%%・剩 %d 秒" % [label,ceili(counter_timer)]
	if is_instance_valid(pressure) and pressure.started and is_instance_valid(GameManager.squad_manager) and not GameManager.STARTING_BUILD.accepts(GameManager.active_starting_node,pressure.kind,GameManager.squad_manager.get_formation_id()):
		return "%s・%s・%s" % [pressure.status_text(),accepted_text(),switch_hint()]
	return pressure.status_text()

func _update_label() -> void:
	if not is_instance_valid(marker_label) or not is_instance_valid(GameManager.player):
		return
	var picker := marker_label.get_parent().get_node_or_null("FormationPicker")
	var choosing: bool = is_instance_valid(picker) and picker.visible
	# The world verdict and seal-success lines take the marker's place while shown.
	var readout: bool = seal_flash_time < SEAL_FLASH_SECONDS or (is_instance_valid(pressure) and pressure.result_age < 2.4 and not pressure.last_result.is_empty())
	# An open equipment detail panel owns that screen area; the marker yields.
	if not is_instance_valid(equipment_details):
		equipment_details = marker_label.get_parent().find_child("EquipmentDetails", true, false) as Control
	if is_instance_valid(equipment_details) and equipment_details.is_visible_in_tree():
		readout = true
	marker_label.visible = GameManager.game_running and GameManager.run_mode=="campaign" and not completed and not get_tree().paused and not choosing and not readout
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
	var width := 214.0
	var y := clampf(point.y+65,150.0,view.y-158)
	var x := clampf(point.x-width/2,12.0,view.x-width-90)
	# Label is independent of world depth, outside notices and character bounds.
	var reserved := BattleLayout.regions(view,MobileTuning.use_mobile_ui(view))
	var rect := Rect2(x,y,width,30)
	for key in ["notice","combo","minimap"]:
		if rect.intersects(reserved[key]):
			y = maxf(y,reserved[key].end.y+5)
	var formation_button_rect := Rect2()
	var formation_button := marker_label.get_parent().get_node_or_null("FormationButton") as Control
	if is_instance_valid(formation_button) and formation_button.is_visible_in_tree():
		formation_button_rect = formation_button.get_global_rect().grow(8.0)
	var candidates: Array[Vector2] = [Vector2(x,y)]
	for row in range(4):
		for column in range(4):
			candidates.append(Vector2(12+column*(view.x-width-112)/3,maxf(140,y-36+row*32)))
	for candidate in candidates:
		var candidate_rect := Rect2(candidate,Vector2(width,30))
		var clear := Rect2(8,136,view.x-96,view.y-284).encloses(candidate_rect) if view.x>view.y else Rect2(8,268,view.x-24,view.y-440).encloses(candidate_rect)
		for region in reserved.values():
			if candidate_rect.intersects(region):clear=false
		if formation_button_rect.size.x > 0.0 and candidate_rect.intersects(formation_button_rect):clear=false
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
	visible = GameManager.run_mode == "campaign" and GameManager.game_running and (not completed or seal_flash_time < SEAL_FLASH_SECONDS)
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
	formation_link_timer = maxf(0.0, formation_link_timer - delta)
	if is_instance_valid(GameManager.squad_manager):
		var current_formation: String = GameManager.squad_manager.get_formation_id()
		if _last_formation_id != "" and current_formation != _last_formation_id:
			formation_link_timer = 1.0
		_last_formation_id = current_formation
	seal_flash_time += maxf(0,delta)

func advance(delta: float) -> void:
	_tick_feedback(delta)
	if clear_wrong_if_correct():
		clear_wrong_notice()
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
		GameManager.show_toast("錯陣反噬：進度歸零・%s・%s" % [accepted_text(), switch_hint()], "battle", true)
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
	seal_flash_time = 0.0
	seal_flash_at = anchor
	seal_flash_text = seal_text(step+1)
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
		GameManager.show_toast(("三陣封隙完成！放棄治療・反擊 +20%，10 秒；" if GameManager.active_starting_node=="spec_prepare" else "三陣封隙完成！全隊整補；") + record, "battle", true)
	else:
		anchor += Vector2(0, -170) if step == 1 else Vector2(-210, 0)
		pressure.configure(anchor,step)
		GameManager.show_toast("封隙 %d/3｜放棄治療・反擊傷害 +20%%，10 秒" % step if GameManager.active_starting_node=="spec_prepare" else "封隙 %d/3｜對陣整補 +8・反擊傷害 +20%%，5 秒" % step, "battle", true)
	if AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("level_up")

func seal_text(count: int) -> String:
	if GameManager.active_starting_node=="spec_prepare":
		return "封合 %d/3・放棄治療・反擊 +20%% 10 秒" % count
	return "封合 %d/3・整補 +8・反擊 +20%% 5 秒" % count

# R10 (Claude): verdict lines sit between the top HUD band and the bottom
# equipment/notice band, so a seal near the screen edge never hides them.
const VERDICT_TOP_BAND := 112.0
const VERDICT_BOTTOM_BAND := 104.0
static func clamp_screen_point(screen: Vector2, view: Vector2, width: float) -> Vector2:
	screen.x = clampf(screen.x, 8.0, maxf(8.0, view.x - width - 8.0))
	screen.y = clampf(screen.y, VERDICT_TOP_BAND, maxf(VERDICT_TOP_BAND, view.y - VERDICT_BOTTOM_BAND))
	return screen
func _keep_on_screen(local_at: Vector2, width: float) -> Vector2:
	if not is_inside_tree():
		return local_at
	var xf := get_viewport().get_canvas_transform() * get_global_transform()
	var view := get_viewport().get_visible_rect().size
	return xf.affine_inverse() * clamp_screen_point(xf * local_at, view, width)

func result_text(result: Dictionary) -> String:
	var name: String = NAMES[maxi(0,ORDER.find(str(result.formation)))]
	var members: int = int(result.members)
	var hit: int = int(result.hit)
	if int(result.protected) > 0:
		return "%s護住 %d 人・減傷 %d" % [name,int(result.protected),int(result.reduced)]
	if hit == 0:
		return "%s對陣・全員避開" % name if bool(result.correct) else "全員避開・%s無法封合" % name
	return "%s對陣・%d/%d 人中招" % [name,hit,members] if bool(result.correct) else "錯陣・%d/%d 人中招" % [hit,members]

# Vector badge of a formation (assets/ui/r8_vector); size is the badge radius.
func _draw_badge(center: Vector2, id: String, radius: float) -> void:
	var texture: Texture2D = BADGES.get(id, BADGES.wedge)
	draw_texture_rect(texture, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false)

func _draw_glyph(center: Vector2, id: String, color: Color, size: float) -> void:
	var ink := Color("08121f",0.9)
	match id:
		"wedge":
			var tri := PackedVector2Array([center+Vector2(size,0),center+Vector2(-size*0.7,-size*0.8),center+Vector2(-size*0.7,size*0.8),center+Vector2(size,0)])
			draw_polyline(tri,ink,7,true)
			draw_polyline(tri,color,3.5,true)
		"ring":
			draw_arc(center,size*0.8,0,TAU,28,ink,7,true)
			draw_arc(center,size*0.8,0,TAU,28,color,3.5,true)
			draw_circle(center,4,color)
		_:
			for offset in [Vector2(-size*0.75,-size*0.45),Vector2(size*0.75,-size*0.45),Vector2(0,size*0.6)]:
				draw_circle(center+offset,6.5,ink)
				draw_circle(center+offset,4.5,color)

func hint() -> String:
	return "封隙 3/3・完成" if completed else "封隙 %d/3｜第 %d 道・%s" % [step,step+1,next_action()]

func probe() -> Dictionary:
	var screen := get_viewport().get_canvas_transform() * anchor
	var captain_screen: Vector2 = get_viewport().get_canvas_transform() * GameManager.player.global_position if is_instance_valid(GameManager.player) else Vector2.ZERO
	return {"step": step,"pressure":pressure.kind,"phase":pressure.phase,"cycles":pressure.cycles,"wrong":wrong_penalties,"required":required_formation(),"marker":marker_text(),"open":is_open(), "completed": completed, "hold": hold, "settled": settled, "distance": GameManager.player.global_position.distance_to(anchor) if is_instance_valid(GameManager.player) else -1.0, "anchor_x": screen.x, "anchor_y": screen.y, "captain_x":captain_screen.x, "captain_y":captain_screen.y, "saved": reward_saved}

# Flip world-space readouts below the seal when the seal sits under the top HUD.
func _label_below(point: Vector2) -> bool:
	# Top of the two-line readout above the seal, against the top HUD band.
	var screen: Vector2 = get_viewport().get_canvas_transform() * (point - Vector2(0, CAPTAIN_RADIUS + 64))
	return screen.y < get_viewport_rect().size.y * 0.27

# When the seal is outside the view, an edge pointer shows where it is and
# which formation it needs; it disappears once the seal is on screen.
func _draw_offscreen_pointer() -> void:
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var size := get_viewport_rect().size
	var top_left: Vector2 = inverse * Vector2.ZERO
	var bottom_right: Vector2 = inverse * size
	var view := Rect2(top_left, bottom_right - top_left)
	# Keep the pointer clear of the HUD bands: top panels, bottom controls, sides.
	var unit: float = view.size.x / maxf(1.0, size.x)
	var inner := Rect2(view.position + Vector2(300, 150) * unit, view.size - Vector2(600, 300) * unit)
	if inner.size.x <= 0 or inner.size.y <= 0 or view.grow(-30.0).has_point(anchor):
		return
	var center := view.get_center()
	var direction := center.direction_to(anchor)
	var point := Vector2(clampf(anchor.x, inner.position.x, inner.end.x), clampf(anchor.y, inner.position.y, inner.end.y))
	var tip := point + direction * 30
	_draw_badge(point, required_formation(), 28.0)
	draw_colored_polygon(PackedVector2Array([tip + direction * 14, tip + direction.orthogonal() * 9, tip - direction.orthogonal() * 9]), Color("ffdcac"))
	var label := "第 %d 道" % mini(step + 1, 3)
	draw_string_outline(FONT, point + Vector2(-50, 50), label, HORIZONTAL_ALIGNMENT_CENTER, 100, 15, 6, Color("08121f", 0.9))
	draw_string(FONT, point + Vector2(-50, 50), label, HORIZONTAL_ALIGNMENT_CENTER, 100, 15, Color("ffdcac"))

func _draw_seal_flash() -> void:
	if seal_flash_time >= SEAL_FLASH_SECONDS or seal_flash_text == "":
		return
	var gold := Color("ffd98a")
	var fade := minf(clampf((SEAL_FLASH_SECONDS - seal_flash_time) / 0.6, 0.0, 1.0), SEAL_FLASH_MAX_ALPHA)
	var grow := 1.0 + 1.1 * smoothstep(0.0, 0.7, seal_flash_time)
	var edge := CAPTAIN_RADIUS * grow
	var ring := PackedVector2Array([seal_flash_at+Vector2(0,-edge),seal_flash_at+Vector2(edge,0),seal_flash_at+Vector2(0,edge),seal_flash_at+Vector2(-edge,0),seal_flash_at+Vector2(0,-edge)])
	draw_polyline(ring,Color("08121f",0.8*fade),9,true)
	draw_polyline(ring,Color(gold,fade),4,true)
	var emblem := CAPTAIN_RADIUS * (0.9 + 0.25 * smoothstep(0.0, 0.5, seal_flash_time))
	draw_texture_rect(SEAL_EMBLEM, Rect2(seal_flash_at - Vector2.ONE * emblem, Vector2.ONE * emblem * 2.0), false, Color(1, 1, 1, fade))
	var rise := 10.0 * minf(1.0, seal_flash_time / 0.4)
	var at := seal_flash_at + (Vector2(-230, CAPTAIN_RADIUS + 70 - rise) if _label_below(seal_flash_at) else Vector2(-230, -CAPTAIN_RADIUS - 52 - rise))
	var width: float = FONT.get_string_size(seal_flash_text,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x
	draw_rect(Rect2(at+Vector2(230-width/2-12,-25),Vector2(width+24,34)),Color(0.05,0.04,0.02,0.82*fade),true)
	draw_rect(Rect2(at+Vector2(230-width/2-12,-25),Vector2(width+24,34)),Color(gold,0.9*fade),false,2,true)
	draw_string_outline(FONT,at,seal_flash_text,HORIZONTAL_ALIGNMENT_CENTER,460,22,7,Color(0.03,0.03,0.02,0.9*fade))
	draw_string(FONT,at,seal_flash_text,HORIZONTAL_ALIGNMENT_CENTER,460,22,Color(gold,fade))

func _draw() -> void:
	if not is_instance_valid(GameManager.player):
		return
	if completed:
		_draw_seal_flash()
		return
	var color: Color = COLORS[step]
	# Four etched corners: task marker, never a defensive circle.
	var edge := CAPTAIN_RADIUS
	var diamond := PackedVector2Array([anchor+Vector2(0,-edge),anchor+Vector2(edge,0),anchor+Vector2(0,edge),anchor+Vector2(-edge,0),anchor+Vector2(0,-edge)])
	var stage_tint := seal_stage_tint(step)
	var stage_edge := seal_stage_edge(step)
	draw_colored_polygon(PackedVector2Array([anchor+Vector2(0,-edge),anchor+Vector2(edge,0),anchor+Vector2(0,edge),anchor+Vector2(-edge,0)]),Color(stage_tint, seal_ground_fill_alpha() if is_open() else 0.08))
	draw_polyline(diamond,Color("08121f",0.55),6,true)
	draw_polyline(diamond,stage_edge if is_open() else Color("758495"),2.4,true)
	for ring_index in range(clampi(step,0,2)):
		var inset := float(ring_index + 1) * 13.0
		var inner := PackedVector2Array([anchor+Vector2(0,-edge+inset),anchor+Vector2(edge-inset,0),anchor+Vector2(0,edge-inset),anchor+Vector2(-edge+inset,0),anchor+Vector2(0,-edge+inset)])
		draw_polyline(inner,Color(stage_edge,0.55),1.6,true)
	for i in range(4):
		var point := anchor+Vector2.from_angle(i*PI/2)*edge
		draw_circle(point,4,color)
	for mark in range(seal_stage_mark_count(step)):
		var mark_at := anchor + Vector2((float(mark) - float(seal_stage_mark_count(step) - 1) * 0.5) * 22.0, edge * 0.52)
		draw_texture_rect(SEAL_STAGE_MARK, Rect2(mark_at - Vector2(9, 9), Vector2(18, 18)), false, Color(stage_edge, 0.95))
		draw_polyline(PackedVector2Array([mark_at + Vector2(0, -7), mark_at + Vector2(7, 0), mark_at + Vector2(0, 7), mark_at + Vector2(-7, 0), mark_at + Vector2(0, -7)]), Color("08121f", 0.85), 1.5, true)
	if hold > 0:
		draw_line(anchor+Vector2(-44,66),anchor+Vector2(44,66),Color("253446"),5,true)
		draw_line(anchor+Vector2(-44,66),anchor+Vector2(-44+88*hold/HOLD_SECONDS,66),Color.WHITE,5,true)
	var squad: Node = GameManager.squad_manager
	var selected: String = squad.get_formation_id() if is_instance_valid(squad) else "wedge"
	var needed := required_formation()
	var matches: bool = is_instance_valid(pressure) and GameManager.STARTING_BUILD.accepts(GameManager.active_starting_node,pressure.kind,selected)
	# The anchor shows which real formation this seal accepts; the rim turns
	# green or red from the same accepts() check that gates seal progress.
	_draw_badge(anchor,needed,30.0)
	if is_open():
		draw_arc(anchor,edge+9,0,TAU,48,Color("08121f",0.8),6,true)
		draw_arc(anchor,edge+9,0,TAU,48,Color("8ff0a4") if matches else Color("ff7a8a"),3,true)
		if is_instance_valid(squad) and matches and GameManager.player.global_position.distance_to(anchor) <= 160:
			for member in squad.get_members():
				if not is_instance_valid(member) or member == GameManager.player or not member.is_alive:
					continue
				var slot: Vector2 = squad.get_formation_world_position(member.formation_index)
				var in_slot: bool = member.global_position.distance_to(slot) <= FOLLOWER_TOLERANCE
				draw_arc(slot+Vector2(0,14),13,0,TAU,20,Color("08121f",0.75),5,true)
				draw_arc(slot+Vector2(0,14),13,0,TAU,20,Color(COLORS[ORDER.find(selected)],1.0 if in_slot else 0.45),2.5,true)
				if in_slot:
					draw_circle(slot+Vector2(0,14),5,COLORS[ORDER.find(selected)])
	# Foot rings always; guide lines only while the seal can be held, so a closed
	# seal never fans lines across the fight.
	if is_instance_valid(squad):
		for member in squad.get_members():
			if not is_instance_valid(member) or not member.is_alive:
				continue
			var foot: Vector2 = member.global_position + Vector2(0, 14)
			if member_zone_state(member.global_position) == "inside":
				draw_circle(foot, 13.0, Color(stage_edge, 0.20))
				draw_arc(foot, 13.0, 0, TAU, 24, Color(stage_edge, 0.9), 2.0, true)
			elif is_open() and member.global_position.distance_to(anchor) <= GUIDE_LINE_RANGE:
				var guide: PackedVector2Array = guide_line_points(member.global_position)
				if guide.size() == 2:
					draw_line(guide[0], guide[1], Color("08121f", 0.65), 4.0, true)
					draw_line(guide[0], guide[1], Color(stage_edge, 0.55), 1.5, true)
					var guide_dir: Vector2 = guide[0].direction_to(guide[1])
					draw_line(guide[1], guide[1] - guide_dir.rotated(0.6) * 11.0, Color(stage_edge, 0.95), 2.0, true)
					draw_line(guide[1], guide[1] - guide_dir.rotated(-0.6) * 11.0, Color(stage_edge, 0.95), 2.0, true)
					draw_set_transform(guide[1], guide_dir.angle(), Vector2(0.25, 0.25))
					draw_texture_rect(GUIDE_ARROW, Rect2(-12, -12, 24, 24), false, Color(stage_edge, 0.95))
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if wrong_timer > 0:
		draw_line(anchor-Vector2(23,23),anchor+Vector2(23,23),Color("ff637c"),5,true)
		draw_line(anchor+Vector2(23,-23),anchor+Vector2(-23,23),Color("ff637c"),5,true)
	if is_instance_valid(pressure) and pressure.result_age < 2.4 and not pressure.last_result.is_empty() and seal_flash_time >= SEAL_FLASH_SECONDS:
		var verdict := result_text(pressure.last_result)
		var good: bool = bool(pressure.last_result.correct) and (int(pressure.last_result.hit) == 0 or int(pressure.last_result.protected) > 0)
		var fade := clampf((2.4 - pressure.result_age) / 0.5, 0.0, 1.0)
		var lift := 14.0 * minf(1.0, pressure.result_age / 0.4)
		var at := anchor + (Vector2(-140, edge + 44 - lift) if _label_below(anchor) else Vector2(-140, -edge - 34 - lift))
		at = _keep_on_screen(at, 280.0)
		var text_width: float = FONT.get_string_size(verdict,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
		draw_rect(Rect2(at+Vector2(140-text_width/2-10,-22),Vector2(text_width+20,30)),Color(0.03,0.05,0.09,0.72*fade),true)
		draw_string_outline(FONT,at,verdict,HORIZONTAL_ALIGNMENT_CENTER,280,20,7,Color(0.03,0.05,0.09,0.9*fade))
		draw_string(FONT,at,verdict,HORIZONTAL_ALIGNMENT_CENTER,280,20,Color(Color("bdf5a8") if good else Color("ffa0a8"),fade))
		# Second line: what this verdict means for the seal under the same rule.
		var consequence := consequence_text(pressure.last_result)
		var sub_at := at + Vector2(0, 26)
		var sub_width: float = FONT.get_string_size(consequence,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		draw_rect(Rect2(sub_at+Vector2(140-sub_width/2-8,-17),Vector2(sub_width+16,23)),Color(0.03,0.05,0.09,0.66*fade),true)
		draw_string_outline(FONT,sub_at,consequence,HORIZONTAL_ALIGNMENT_CENTER,280,16,6,Color(0.03,0.05,0.09,0.9*fade))
		draw_string(FONT,sub_at,consequence,HORIZONTAL_ALIGNMENT_CENTER,280,16,Color(Color("e8f7d8") if bool(pressure.last_result.correct) else Color("ffd0a0"),fade))
	var captain: Node2D = GameManager.player
	var direction := captain.global_position.direction_to(anchor)
	if captain.global_position.distance_to(anchor) > CAPTAIN_RADIUS:
		var tip := captain.global_position + direction * 62
		draw_line(tip - direction * 18, tip, color, 3, true)
		draw_line(tip, tip - direction.rotated(0.65) * 12, color, 3, true)
		draw_line(tip, tip - direction.rotated(-0.65) * 12, color, 3, true)
	_draw_offscreen_pointer()
	# Drawn last so the next seal's marker never covers the success line.
	_draw_seal_flash()
