extends Node2D

# Presentation only: these markers follow actual actors and attack state.
# They never alter target selection, collisions, HP, timing or visibility.
const GOLD:=Color("ffdc82")
const ALLY:=Color("77cdda")
const HOSTILE:=Color("ff6c6b")
const INK:=Color("08121f")
var captain_markers:=0
var ally_markers:=0
var attack_origins:=0

func _ready() -> void:
	z_index=95

func _process(_delta: float) -> void:
	visible=GameManager.game_running and not GameManager.is_game_over and not GameManager.stage_victory_pending
	queue_redraw()

func _line(a: Vector2,b: Vector2,color: Color,width: float=2.0) -> void:
	draw_line(a,b,INK,width+3,true)
	draw_line(a,b,color,width,true)

func _draw() -> void:
	captain_markers=0
	ally_markers=0
	attack_origins=0
	if not is_instance_valid(GameManager.squad_manager):return
	for member in GameManager.squad_manager.get_members():
		if not member.is_alive:continue
		var at: Vector2=to_local(member.global_position)
		var above:=at+Vector2(0,-48)
		if member==GameManager.player:
			captain_markers+=1
			# Gold floor halo: the captain stays identifiable in a 64px thumbnail
			# without covering face, weapon or the real attack body.
			draw_set_transform(at+Vector2(0,16),0,Vector2(1,0.4))
			draw_arc(Vector2.ZERO,32,0,TAU,40,INK,8,true)
			draw_arc(Vector2.ZERO,32,0,TAU,40,GOLD,4,true)
			draw_set_transform(Vector2.ZERO)
			# A crown and four corner brackets remain distinct from all rings.
			draw_circle(above,10,INK)
			var crown:=PackedVector2Array([above+Vector2(-8,-3),above+Vector2(-5,5),above+Vector2(5,5),above+Vector2(8,-3),above+Vector2(2,0),above+Vector2(0,-7),above+Vector2(-2,0)])
			draw_colored_polygon(crown,GOLD)
			for side in [-1,1]:
				_line(at+Vector2(side*19,9),at+Vector2(side*26,9),GOLD)
				_line(at+Vector2(side*26,9),at+Vector2(side*26,2),GOLD)
		else:
			ally_markers+=1
			draw_circle(above,7,INK)
			var id: String=member.hero_id
			if id in ["echo_singer","line_mender","tide_oracle"]:
				_line(above+Vector2(-4,0),above+Vector2(4,0),ALLY)
				_line(above+Vector2(0,-4),above+Vector2(0,4),ALLY)
			elif id=="orbit_guard":
				var shield:=PackedVector2Array([above+Vector2(-5,-4),above+Vector2(5,-4),above+Vector2(4,2),above+Vector2(0,6),above+Vector2(-4,2),above+Vector2(-5,-4)])
				draw_polyline(shield,ALLY,2,true)
			else:
				_line(above+Vector2(-4,4),above+Vector2(0,-4),ALLY)
				_line(above+Vector2(0,-4),above+Vector2(4,4),ALLY)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.get("is_active")!=true or enemy.get("is_dying")==true:continue
		if enemy.get("current_animation_name")!=&"attack" and enemy.get("behavior_state")!="windup":continue
		if not bool(enemy.get("is_boss")) and not bool(enemy.get("is_elite")) and int(enemy.get("tactical_min_cycles"))<=0:continue
		attack_origins+=1
		var at: Vector2=to_local(enemy.global_position)
		var direction: Vector2=enemy.pending_attack_direction
		var radius: float=maxf(18,float(enemy.radius))
		var tip:=at+direction*(radius+18)
		_line(tip-direction.rotated(0.6)*9,tip,HOSTILE,2.6)
		_line(tip-direction.rotated(-0.6)*9,tip,HOSTILE,2.6)
		# Broken triangular outline identifies the actual attack's origin,
		# while its original animation and floor footprint stay unobscured.
		for side in [-1,1]:_line(at+direction.orthogonal()*radius*side,at+direction.orthogonal()*(radius+7)*side-direction*7,HOSTILE)
