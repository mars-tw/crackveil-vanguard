extends Node

const ARENA := preload("res://scenes/arena/Arena.tscn")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const CATALOG := preload("res://scripts/services/tactical_catalog.gd")
const SPECIAL := preload("res://scripts/services/special_elite_catalog.gd")
var failures: Array[String] = []
var checks := 0
var viewport: SubViewport
var arena: Node
var hud: Node
var squad: Node
var director: Node
var evidence: Dictionary = {"layouts":[]}

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	GameManager.campaign_save_path = "user://r43_campaign.cfg"
	GameManager.wallet_gold = 0
	GameManager.tactical_launch = false
	GameManager.set_process(false)
	MetaProgress.debug_use_save_path("user://r43_meta.cfg", true)
	PlayerSettings.debug_use_save_path("user://r43_settings.cfg", true)
	AchievementProgress.debug_use_save_path("user://r43_achievements.cfg", true)
	for size in [Vector2i(390,844), Vector2i(844,390), Vector2i(320,568), Vector2i(667,375), Vector2i(1366,600), Vector2i(1280,640)]:
		await _new_arena(size)
		await _test_picker(size)
		if size == Vector2i(390,844):
			await _test_simultaneous_touch()
		await _cleanup()
		if size in [Vector2i(390,844),Vector2i(844,390)]:
			await _test_collection(size)
	await _new_arena(Vector2i(390,844))
	await _test_progression()
	await _test_encounters()
	await _cleanup()
	_test_persistence()
	MOBILE.set_device_hints_override_for_tests({})
	get_tree().paused = false
	evidence["checks"] = checks
	evidence["failures"] = failures
	var file := FileAccess.open("res://docs/evidence/r43-mobile/mechanics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"))
	print("R43_MOBILE_TACTICS_%s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _new_arena(size: Vector2i) -> void:
	MOBILE.set_device_hints_override_for_tests({"ua_mobile":size.x<1000, "ua_phone":size.x<1000, "touch_available":size.x<1000, "primary_coarse":size.x<1000, "mouse_available":size.x>=1000})
	viewport = SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	arena = ARENA.instantiate()
	viewport.add_child(arena)
	await get_tree().process_frame
	arena.get_node("EnemySpawner").set_process(false)
	squad = GameManager.squad_manager
	for member in squad.get_members():
		for weapon in member.weapons.values():
			weapon.set_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	hud = arena.get_node("HUD")
	director = GameManager.tactical_director
	for frame in range(8):
		await get_tree().process_frame
	GameManager.emit_stats()
	await get_tree().process_frame

func _mouse(control: Control, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = control.get_global_rect().get_center()
	viewport.push_input(event,true)

func _click(control: Control) -> void:
	_mouse(control,true)
	await get_tree().process_frame
	_mouse(control,false)
	await get_tree().process_frame

func _test_picker(size: Vector2i) -> void:
	_check(hud.formation_button.get_global_rect().size.y>=44, "base target below44 %s"%size)
	_mouse(hud.formation_button,true)
	for frame in range(26):
		await get_tree().process_frame
	_mouse(hud.formation_button,false)
	await get_tree().process_frame
	_check(hud.formation_picker.visible,"long press did not open %s"%size)
	_check(squad.formation_switch_count==0,"long press also cycled %s"%size)
	var rects: Array[Rect2] = []
	for button in [hud.formation_picker.buttons.wedge,hud.formation_picker.buttons.ring,hud.formation_picker.buttons.scatter,hud.formation_picker.cancel_button]:
		var rect: Rect2 = button.get_global_rect()
		_check(Rect2(Vector2.ZERO,Vector2(size)).encloses(rect),"choice out of viewport %s %s"%[size,rect])
		_check(rect.size.x>=44 and rect.size.y>=44,"choice under44")
		_check(not rect.intersects(hud.pause_button.get_global_rect()),"choice obstructs pause")
		for before in rects:
			_check(not rect.intersects(before),"choice overlap")
		rects.append(rect)
	await _click(hud.formation_picker.buttons.scatter)
	_check(squad.get_formation_id()=="scatter" and squad.formation_switch_count==1,"direct selection not once")
	_check(not hud.formation_picker.visible,"successful selection remains open")
	await _click(hud.formation_button)
	_check(squad.formation_switch_count==1,"cooldown click consumed switch")
	_check("散兵" in hud.formation_button.text,"cooldown hides current formation")
	squad.formation_cooldown = 0
	hud._open_formation_picker()
	await _click(hud.formation_picker.cancel_button)
	_check(not hud.formation_picker.visible and squad.formation_switch_count==1,"cancel changed formation")
	hud._open_formation_picker()
	GameManager.set_manual_pause(true)
	await get_tree().process_frame
	_check(not hud.formation_picker.visible,"pause leaves picker open")
	GameManager.set_manual_pause(false)
	hud._open_formation_picker()
	hud._apply_responsive_layout()
	_check(not hud.formation_picker.visible,"rotation leaves stale picker")
	evidence.layouts.append({"viewport":str(size),"choice_rects":str(rects),"long_press":true,"selection":"scatter","cancel":true,"pause":true})

func _test_progression() -> void:
	director.relay.completed = true # medal fixture; R2 owns seal timing integration
	director.relay.reward_saved = true
	_check("走位" in director.current_hint(),"first minute movement hint missing")
	GameManager.set_touch_move_vector(Vector2.RIGHT)
	for frame in range(75):
		await get_tree().physics_frame
	GameManager.set_touch_move_vector(Vector2.ZERO)
	_check(director.distance_walked>=160,"real movement not tracked")
	_check(MetaProgress.shards==0,"idle / incomplete formations granted medal")
	for id in ["ring","scatter"]:
		squad.formation_cooldown=0
		squad.set_formation(id)
		for frame in range(12):
			await get_tree().process_frame
	_check(MetaProgress.get_tactical_medal_count("moon")==1 and MetaProgress.shards==3,"maneuver reward missing")
	for index in range(2):
		var enemy: Node = arena.get_node("EnemySpawner").spawn_tactical_guard("charge")
		_check(enemy!=null,"real hunt spawn failed")
		if enemy!=null:
			enemy.tactical_recoveries = 2
			if enemy.is_boss: enemy.boss_phase_two_triggered = true
			enemy.take_damage(99999,GameManager.player.global_position)
			for frame in range(50):
				await get_tree().process_frame
	_check(MetaProgress.shards==8 and MetaProgress.get_tactical_medal_count("moon")==2,"real elite kills did not claim hunt")
	GameManager.elapsed_time=90
	arena.get_node("EnemySpawner")._spawn_boss()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_boss:
			enemy.tactical_recoveries = 2
			if enemy.is_boss: enemy.boss_phase_two_triggered = true
			enemy.take_damage(99999,GameManager.player.global_position)
	for frame in range(55):
		await get_tree().process_frame
	_check(MetaProgress.shards==16+GameManager.echo_shards_awarded_this_run and MetaProgress.get_tactical_medal_count("moon")==3,"Boss death did not claim clear")
	_check(is_equal_approx(MetaProgress.get_tactical_damage_bonus(),0.01),"mastery bonus absent")
	_check(GameManager.get_outgoing_damage_multiplier()>1.0,"mastery has no game consumer")
	var before_recheck: int = MetaProgress.shards
	director.check_objectives()
	_check(MetaProgress.shards==before_recheck,"double claim")
	_check(MetaProgress.buy_upgrade("echo_magnetism"),"earned medals cannot buy real upgrade")
	_check(MetaProgress.get_pickup_radius_bonus()==6,"bought reward has no gameplay effect")
	evidence["earned_shards"] = 16
	evidence["distance_walked"] = director.distance_walked
	get_tree().paused=false
	GameManager.system_pause_owners.clear()
	GameManager.stage_victory_pending=false

func _touch(index: int, point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index=index
	event.position=point
	event.pressed=down
	viewport.push_input(event,true)

func _test_simultaneous_touch() -> void:
	for frame in range(4):
		await get_tree().process_frame
	var joy: Vector2 = hud.virtual_joystick.get_global_rect().get_center()
	_touch(7,joy,true)
	var drag := InputEventScreenDrag.new()
	drag.index=7
	drag.position=joy+Vector2(24,-8)
	drag.relative=Vector2(24,-8)
	viewport.push_input(drag,true)
	await get_tree().physics_frame
	print("R43_TOUCH_DIAGNOSTIC index=%s direction=%s visible=%s filter=%s paused=%s" % [hud.virtual_joystick.active_touch_index,GameManager.get_touch_move_vector(),hud.virtual_joystick.visible,hud.virtual_joystick.mouse_filter,get_tree().paused])
	_check(GameManager.get_touch_move_vector().length()>0.1,"first finger joystick missing")
	squad.formation_cooldown=0
	await get_tree().process_frame
	var point: Vector2= hud.formation_button.get_global_rect().get_center()
	_touch(9,point,true)
	for frame in range(26):
		await get_tree().process_frame
	_touch(9,point,false)
	_check(hud.formation_picker.visible,"second finger hold did not open picker")
	_check(GameManager.get_touch_move_vector().length()>0.1,"opening picker cleared joystick")
	var ring: Vector2=hud.formation_picker.buttons.ring.get_global_rect().get_center()
	_touch(9,ring,true)
	_touch(9,ring,false)
	_check(squad.get_formation_id()=="ring","second finger direct choice failed")
	_check(GameManager.get_touch_move_vector().length()>0.1,"selection cleared joystick")
	_touch(7,joy,false)
	_check(GameManager.get_touch_move_vector()==Vector2.ZERO,"joystick stuck after release")
	squad.formation_cooldown=0
	await get_tree().process_frame
	var count: int=squad.formation_switch_count
	_touch(9,point,true)
	drag=InputEventScreenDrag.new()
	drag.index=9
	drag.position=point-Vector2(100,100)
	viewport.push_input(drag,true)
	_touch(9,point,false)
	_check(squad.formation_switch_count==count and not hud.formation_picker.visible,"drag-off did not cancel")
	evidence["multi_touch"]={"joystick_finger":7,"formation_finger":9,"long_press":true,"selection":true,"drag_off_cancel":true}

func _test_encounters() -> void:
	GameManager.boss_active=false
	GameManager.boss_killed=false
	GameManager.game_running=true
	director.set_process(false)
	GameManager.elapsed_time=32
	director.tick_timer=0
	director._process(0.2)
	_check(director.hunt_announced and not director.hunt_spawned,"hunt telegraph absent")
	GameManager.elapsed_time=37.9
	director.tick_timer=0
	director._process(0.2)
	_check(not director.hunt_spawned,"hunt spawned early")
	GameManager.elapsed_time=38
	director.tick_timer=0
	director._process(0.2)
	_check(director.hunt_spawned and director.guard_history.size()==1,"hunt not spawned")
	director.tick_timer=0
	director._process(0.2)
	_check(director.guard_history.size()==1,"hunt double spawn")
	spawner_spawn_boss_for_phase_test()
	# Hurt reaction must finish before the boss can enter its phase behavior.
	for frame in range(35):
		await get_tree().physics_frame
	_check(GameManager.boss_phase_two_time>=0 and director.boss_guard_at>38,"real half-HP boss did not signal escort")
	GameManager.elapsed_time=39.9
	director.tick_timer=0
	director._process(0.2)
	_check(not director.boss_guard_spawned,"boss guard not telegraphed")
	GameManager.elapsed_time=40.1
	director.tick_timer=0
	director._process(0.2)
	_check(director.boss_guard_spawned and director.guard_history.size()==2,"half-HP escort absent")
	for stage in CATALOG.STAGES.get_stages():
		_check(not SPECIAL.get_profile(CATALOG.guard_id(str(stage.id))).is_empty(),"stage missing real guard")
	var spawner: Node=arena.get_node("EnemySpawner")
	var cap: int=spawner.max_enemies
	spawner.max_enemies=0
	_check(spawner.spawn_tactical_guard("shield")==null,"guard bypasses full elite-only pool")
	spawner.max_enemies=cap
	evidence["encounters"] = director.guard_history

func spawner_spawn_boss_for_phase_test() -> void:
	arena.get_node("EnemySpawner")._spawn_boss()
	var previous_critical: bool=GameManager.critical_strikes_enabled
	GameManager.critical_strikes_enabled=false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_active and enemy.is_boss:
			enemy.take_damage(enemy.max_hp*0.75,GameManager.player.global_position)
	GameManager.critical_strikes_enabled=previous_critical

func _test_persistence() -> void:
	MetaProgress.load_progress()
	_check(MetaProgress.get_tactical_medal_count("moon")==3,"medals not persisted")
	_check(MetaProgress.get_pickup_radius_bonus()==6,"upgrade not persisted")
	_check(MetaProgress.award_tactical_medal("moon","clear")==0,"restart permits duplicate reward")
	_check(MetaProgress.award_tactical_medal("invalid","clear")==-1,"invalid stage accepted")
	for stage in CATALOG.STAGES.get_stages():
		for medal in CATALOG.MEDALS:
			MetaProgress.award_tactical_medal(str(stage.id),str(medal.id))
	_check(MetaProgress.get_tactical_medal_count()==30,"collection not reachable")
	_check(is_equal_approx(MetaProgress.get_tactical_damage_bonus(),0.05),"mastery cap not5percent")
	var damage := MetaProgress.get_damage_multiplier()
	_check(is_equal_approx(damage,1.05),"damage multiplier missing mastery")
	MetaProgress.debug_use_save_path("user://r43_unwritable/missing/meta.cfg",true)
	_check(MetaProgress.award_tactical_medal("moon","clear")==-1 and MetaProgress.shards==0 and MetaProgress.get_tactical_medal_count()==0,"failed save granted medal")
	MetaProgress.debug_use_save_path("user://r43_meta.cfg",false)

func _test_collection(size: Vector2i) -> void:
	viewport=SubViewport.new()
	viewport.size=size
	add_child(viewport)
	var menu: Node=load("res://scenes/ui/MainMenu.tscn").instantiate()
	viewport.add_child(menu)
	menu._show_panel("meta")
	for frame in range(6):
		await get_tree().process_frame
	_check(Rect2(Vector2.ZERO,Vector2(size)).encloses(menu.tactical_collection_button.get_global_rect()),"collection entry needs scroll %s"%size)
	await _click(menu.tactical_collection_button)
	_check(menu.active_panel_id=="tactical","collection entry did not open")
	for frame in range(6):
		await get_tree().process_frame
	for button in [menu.tactical_previous_button,menu.tactical_next_button,menu.side_close_button]:
		var rect: Rect2=button.get_global_rect()
		_check(Rect2(Vector2.ZERO,Vector2(size)).encloses(rect) and rect.size.y>=44,"collection navigation unreachable %s"%size)
	await _click(menu.tactical_next_button)
	_check(menu.tactical_page==1,"collection next page did not change")
	await _click(menu.side_close_button)
	_check(not menu.side_panel.visible,"collection cannot close")
	viewport.queue_free()
	await get_tree().process_frame

func _cleanup() -> void:
	get_tree().paused=false
	GameManager.game_running=false
	GameManager.set_touch_move_vector(Vector2.ZERO)
	viewport.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures.append(message)
		printerr("R43_FAIL "+message)
