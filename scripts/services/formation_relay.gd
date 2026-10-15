extends Node2D

# A world-space objective: a formation button alone cannot close a seal.
# The captain must reach the anchor and two living followers must settle into
# their real formation slots. All combat, collision and animation keep running.
const ORDER := ["wedge", "ring", "scatter"]
const NAMES := ["楔形", "圓陣", "散兵"]
const COLORS := [Color("ffae78"), Color("91dafa"), Color("b2ec9b")]
const HOLD_SECONDS := 1.2
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

func _ready() -> void:
	anchor = GameManager.player.global_position + Vector2(140, 0) if is_instance_valid(GameManager.player) else Vector2.ZERO
	z_index = 1

func _process(delta: float) -> void:
	visible = GameManager.run_mode == "campaign" and GameManager.game_running and not completed
	if get_tree().paused or not GameManager.game_running or GameManager.run_mode != "campaign":
		return
	advance(delta)
	queue_redraw()

func advance(delta: float) -> void:
	if completed:
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
	var correct: bool = squad.get_formation_id() == ORDER[step]
	if correct:
		for member in squad.get_members():
			if not is_instance_valid(member) or member == captain or not member.is_alive:
				continue
			if member.global_position.distance_to(squad.get_formation_world_position(member.formation_index)) <= FOLLOWER_TOLERANCE:
				settled += 1
	if not correct or captain.global_position.distance_to(anchor) > CAPTAIN_RADIUS or settled < 2:
		hold = 0.0
		return
	hold += maxf(0.0, delta)
	if hold < HOLD_SECONDS:
		return
	history.append({"formation": ORDER[step], "time": GameManager.elapsed_time, "followers": settled})
	squad.heal_members(8.0)
	step += 1
	hold = 0.0
	if step == ORDER.size():
		completed = true
		var reward := MetaProgress.award_formation_seal(GameManager.selected_stage_id)
		reward_saved = reward >= 0
		retry_timer = 2.0
		var record := "首次封隙殘響 +4。" if reward > 0 else "本關封隙已收藏。" if reward == 0 else "紀錄尚未存好，稍後重試。"
		GameManager.show_toast("三陣封隙完成！全隊整補；" + record)
	else:
		anchor += Vector2(0, -130) if step == 1 else Vector2(-130, 0)
		GameManager.show_toast("%s陣位封合。下一處：%s，帶隊靠近地面陣記。" % [NAMES[step - 1], NAMES[step]])
	if AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("level_up")

func hint() -> String:
	if completed:
		return "三陣封隙完成"
	return "三陣封隙 %d/3｜%s・%s" % [step + 1, NAMES[step], "隊友就位 %d/2" % mini(2, settled) if hold > 0 else "走位到陣記"]

func probe() -> Dictionary:
	var screen := get_viewport().get_canvas_transform() * anchor
	var captain_screen: Vector2 = get_viewport().get_canvas_transform() * GameManager.player.global_position if is_instance_valid(GameManager.player) else Vector2.ZERO
	return {"step": step, "completed": completed, "hold": hold, "settled": settled, "distance": GameManager.player.global_position.distance_to(anchor) if is_instance_valid(GameManager.player) else -1.0, "anchor_x": screen.x, "anchor_y": screen.y, "captain_x":captain_screen.x, "captain_y":captain_screen.y, "saved": reward_saved}

func _draw() -> void:
	if completed or not is_instance_valid(GameManager.player):
		return
	var color: Color = COLORS[step]
	# Geometric targeting marks are gameplay UI, not substitute character art.
	draw_circle(anchor, CAPTAIN_RADIUS, Color(0.02, 0.05, 0.08, 0.65))
	draw_arc(anchor, CAPTAIN_RADIUS, 0, TAU, 48, color, 3.0, true)
	draw_arc(anchor, CAPTAIN_RADIUS + 7, -PI / 2, -PI / 2 + TAU * hold / HOLD_SECONDS, 48, Color.WHITE, 4.0, true)
	match step:
		0:
			draw_polyline(PackedVector2Array([anchor + Vector2(-21, 18), anchor + Vector2(0, -22), anchor + Vector2(21, 18)]), color, 4, true)
		1:
			draw_arc(anchor, 21, 0, TAU, 32, color, 4, true)
		2:
			for angle in [0.0, TAU / 3, TAU * 2 / 3]:
				draw_circle(anchor + Vector2.from_angle(angle) * 20, 5, color)
	var font := FONT
	if font != null:
		draw_string(font, anchor + Vector2(-65, -68), "%s封隙 %d/3" % [NAMES[step], step + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, color)
	var captain: Node2D = GameManager.player
	var direction := captain.global_position.direction_to(anchor)
	if captain.global_position.distance_to(anchor) > CAPTAIN_RADIUS:
		var tip := captain.global_position + direction * 62
		draw_line(tip - direction * 18, tip, color, 3, true)
		draw_line(tip, tip - direction.rotated(0.65) * 12, color, 3, true)
		draw_line(tip, tip - direction.rotated(-0.65) * 12, color, 3, true)
