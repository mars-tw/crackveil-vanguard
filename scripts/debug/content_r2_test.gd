extends Node

var failures: Array[String] = []
var checks := 0
var rows: Array = []
var arena: Node

class CreditSource extends Node2D:
	var hero_id := "r2_credit_probe"
	var display_name := "Credit Probe"

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		printerr("CONTENT_R2_FAIL: "+description)

func _run() -> void:
	AudioManager.set_muted(true)
	GameManager.campaign_save_path = "user://content_r2_test_campaign.cfg"
	MetaProgress.debug_use_save_path("user://content_r2_test_meta.cfg",true)
	PlayerSettings.debug_use_save_path("user://content_r2_test_settings.cfg",true)
	AchievementProgress.debug_use_save_path("user://content_r2_test_achievements.cfg",true)
	GameManager.tactical_launch = false
	GameManager.forced_run_seed = 55210
	for stage in ["moon","garden","ember"]:
		GameManager.selected_stage_id = stage
		arena = preload("res://scenes/arena/Arena.tscn").instantiate()
		add_child(arena)
		await get_tree().process_frame
		GameManager.set_process(false)
		arena.get_node("EnemySpawner").set_process(false)
		var relay: Node = GameManager.tactical_director.relay
		relay.set_process(false)
		relay.pressure.set_process(false)
		GameManager.tactical_director.set_process(false)
		var squad: Node = GameManager.squad_manager
		var captain: Node = GameManager.player
		for member in squad.get_members():
			member.set_physics_process(false)
			for weapon in member.weapons.values():
				weapon.set_process(false)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			EntityFactory.release_enemy(enemy)
		check(relay.OPEN_TIMES[2]+relay.HOLD_SECONDS>=90,"main objective can finish before 90s")
		GameManager.elapsed_time = 8
		captain.global_position = relay.anchor
		_settle(squad,captain)
		relay.advance(20)
		check(relay.step==0 and relay.hold==0,"8 second objective completed")
		GameManager.elapsed_time = 12
		relay.advance(0)
		var pressure: Node = relay.pressure
		check(pressure.kind=={"moon":"front","garden":"pincer","ember":"artillery"}[stage],"stage pressure is cosmetic")
		check(pressure.enemies.size()>0,"pressure has no real enemies")
		for ref in pressure.enemies:
			var enemy: Node = ref.get_ref()
			enemy.set_physics_process(false)
			check(enemy.tactical_min_cycles==2,"guard can skip attack cycles")
		var wrong: String = "ring" if relay.required_formation()!="ring" else "wedge"
		relay.wrong_timer = 0
		relay.wrong_penalties = 0
		relay.hold = 3.0 # Wrong choice must destroy already earned progress.
		squad.set_formation(wrong,true)
		_settle(squad,captain)
		captain.invulnerability_timer = 0
		captain.temporary_shield_hp = 0
		var hp: float = captain.current_hp
		relay.advance(0.1)
		check(relay.hold==0 and relay.wrong_penalties==1,"wrong formation has no visible cost")
		check(captain.current_hp<hp,"wrong formation penalty is only text")
		check(relay.next_action().contains("反噬"),"wrong formation message absent")
		squad.set_formation(relay.required_formation(),true)
		_settle(squad,captain)
		relay.advance(3)
		check(relay.hold==0,"warning allowed capture")
		# Warning has no damage; active applies through the normal Hero method.
		if stage=="moon": captain.global_position = pressure.anchor+Vector2(70,0)
		elif stage=="garden": captain.global_position = pressure.anchor+Vector2(60,0)
		else: pressure.targets.assign([captain.global_position])
		captain.invulnerability_timer = 0
		captain.temporary_shield_hp = 0
		hp = captain.current_hp
		pressure.advance(1.99)
		check(captain.current_hp==hp and pressure.phase=="warning","damage before impact frame")
		pressure.advance(0.02)
		check(captain.current_hp<hp and pressure.phase=="active","active hazard not applied")
		var active_hp: float = captain.current_hp
		pressure.advance(0.1)
		check(captain.current_hp==active_hp,"active hitbox hits twice in one cycle")
		pressure.advance(0.55)
		check(pressure.phase=="recovery" and pressure.cycles==1,"missing recovery")
		captain.global_position = relay.anchor
		_settle(squad,captain)
		relay.advance(3.0)
		check(relay.hold==3 and relay.step==0,"right formation did not earn hold")
		# Full two-cycle contract, without bypassing the real active geometry.
		pressure.advance(5.0)
		captain.global_position = relay.anchor+Vector2(0,115)
		pressure.advance(2.6)
		check(pressure.cycles>=2,"second attack cycle absent")
		captain.global_position = relay.anchor
		_settle(squad,captain)
		relay.advance(3.01)
		check(relay.step==1 and relay.counter_timer>0,"counter formation has no reward")
		check(relay.history[0].cycles>=2,"capture skipped two attacks")
		check(relay.hint().contains("封隙 1/3") and not relay.marker_text().contains("/3"),"conflicting progress counts")
		check(not GameManager.tactical_director.progress_text().contains("陣形 "),"old alternate formation count remains")
		GameManager.elapsed_time=20
		captain.global_position=relay.anchor
		_settle(squad,captain)
		relay.advance(100)
		check(relay.step==1,"second seal ignored schedule")
		relay.step=2
		relay.pressure.configure(relay.anchor,2)
		relay.pressure.started=true
		relay.pressure.phase="recovery"
		relay.pressure.clock=4
		GameManager.elapsed_time=89
		squad.set_formation(relay.required_formation(),true)
		captain.global_position=relay.anchor
		_settle(squad,captain)
		relay.advance(6.01)
		check(not relay.completed,"third seal completed before hard 90s floor")
		GameManager.elapsed_time=90
		relay.advance(0.01)
		check(relay.completed and relay.history[-1].time>=90,"third seal failed after all conditions")
		GameManager.is_game_over=true
		GameManager.game_running=false
		GameManager.boss_killed=true
		GameManager.try_complete_campaign_victory()
		check(not GameManager.stage_victory_pending,"late boss/escort death replaced defeat with victory")
		GameManager.is_game_over=false
		GameManager.game_running=true
		rows.append({"stage":stage,"kind":pressure.kind,"history":relay.history.duplicate(true),"wrong":relay.wrong_penalties,"events":pressure.events.duplicate(true)})
		# An idle boss kill cannot unlock the next stage or award victory.
		GameManager.campaign_clears.clear()
		relay.completed=false
		GameManager.boss_killed=false
		GameManager.record_boss_kill()
		check(not GameManager.stage_victory_pending and not GameManager.campaign_clears.has(stage),"zero-movement kill unlocked campaign")
		GameManager.boss_killed=false
		if stage=="moon":
			await _guard_cycle_test(captain)
			_combo_test()
			await _contribution_test(captain)
		GameManager.game_running=false
		get_tree().paused=false
		arena.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	await _layout_test()
	var evidence_dir := OS.get_environment("CV_TEST_EVIDENCE_DIR")
	if evidence_dir.is_empty(): evidence_dir = "res://docs/content/r2/tests"
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	var file := FileAccess.open(evidence_dir.path_join("mechanics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"VERIFIED" if failures.is_empty() else "BLOCKED","checks":checks,"failures":failures,"scenarios":rows},"\t"))
	print("CONTENT_R2_%s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _settle(squad: Node,captain: Node) -> void:
	for member in squad.get_members():
		if member!=captain:
			member.global_position=squad.get_formation_world_position(member.formation_index)

func _guard_cycle_test(captain: Node) -> void:
	var guard: Node = arena.get_node("EnemySpawner").spawn_tactical_guard("shield")
	guard.xp_value=0
	guard.gold_value=0
	guard.elite_bonus_xp=0
	guard.set_physics_process(false)
	guard.global_position=captain.global_position+Vector2(45,0)
	guard.take_damage(99999,captain.global_position)
	check(guard.hp>0 and not guard.is_dying,"guard died before its first attack")
	# Actual shared animation clock reaches impact and recovery twice.
	for cycle in range(2):
		for frame in range(50):
			await get_tree().process_frame
		check(guard._start_attack(captain,1.0,&"elite"),"guard could not begin anticipation")
		check(guard.tactical_recoveries==cycle,"anticipation counted as completed recovery")
		var impacts: int = guard.attack_impact_count
		check(not guard.attack_hitbox_active and guard.attack_impact_count==impacts,"input caused immediate damage")
		for frame in range(35):
			await get_tree().process_frame
		check(guard.attack_impact_count==impacts,"guard warning shorter than readable anticipation")
		for frame in range(65):
			await get_tree().process_frame
		check(guard.attack_impact_count==impacts+1 and guard.tactical_recoveries==cycle+1,"guard skipped impact/recovery")
	guard.take_damage(99999,captain.global_position)
	check(guard.is_dying and guard.current_animation_name==&"death","guard has no true death reaction")
	rows.append({"guard_impacts":guard.attack_impact_count,"guard_recoveries":guard.tactical_recoveries})
	var director: Node=GameManager.tactical_director
	check(director._spawn_guard("r2_death_fixture"),"death-wait guard missing")
	var final_guard: Node=director.guard_refs[-1].ref.get_ref()
	final_guard.set_physics_process(false)
	final_guard.xp_value=0
	final_guard.elite_bonus_xp=0
	final_guard.gold_value=0
	final_guard.tactical_recoveries=2
	final_guard.take_damage(99999,captain.global_position)
	check(not director.guards_resolved(),"victory interrupted escort death animation")
	await get_tree().create_timer(0.8,true).timeout
	check(director.guards_resolved() and director.guard_history[-1].has("death_finalized_at"),"escort death completion was not recorded")

func _combo_test() -> void:
	GameManager.combo_count=12
	GameManager.last_combo_milestone_count=0
	GameManager.combo_fire_rate_timer=0
	check(GameManager.combo_status_text().contains("25") and GameManager.combo_status_text().contains("13"),"next combo condition wrong")
	GameManager._record_combo_kill(25)
	check(GameManager.combo_fire_rate_timer>0 and GameManager.combo_status_text().contains("已啟動"),"active burst missing countdown")
	GameManager.combo_fire_rate_timer=0
	GameManager.combo_count=28
	GameManager.last_combo_milestone_count=25
	check(GameManager.combo_status_text().contains("50") and not GameManager.combo_status_text().contains("25 連斬"),"stale combo threshold")
	GameManager.combo_count=881
	GameManager.last_combo_milestone_count=100
	check(GameManager.combo_status_text().contains("斷連") and not GameManager.combo_status_text().contains("25"),"881 combo has stale condition")
	GameManager.elapsed_time+=GameManager.COMBO_WINDOW+1
	GameManager._tick_combo_break()
	check(GameManager.combo_count==0 and GameManager.combo_status_text().contains("25"),"break did not reset milestones")

func _contribution_test(captain: Node) -> void:
	var credit_source:=CreditSource.new()
	arena.add_child(credit_source)
	var target: Node=EntityFactory.spawn_enemy("normal",{"max_hp":10,"speed":0,"damage":0,"xp":0,"gold":0,"radius":12},captain.global_position+Vector2(90,0))
	target.set_physics_process(false)
	GameManager.contribution.clear()
	var total_at_clear: int=GameManager.kills
	var unknown_before: float=GameManager.contribution_row("unattributed").damage
	var damage: float=target.take_damage(12,captain.global_position)
	check(is_equal_approx(GameManager.contribution_row("unattributed").damage,unknown_before+damage),"unowned HP damage disappeared from contributions")
	GameManager.record_weapon_damage(credit_source,"captain_blade",damage,"test",target)
	check(is_equal_approx(GameManager.contribution_row("unattributed").damage,unknown_before),"known source damage was counted twice")
	check(is_equal_approx(damage,10.0),"contributions include overkill instead of applied HP damage")
	check(GameManager.contribution_row(credit_source.hero_id).kills==0,"role credited kill before real death completed")
	var before_kills: int=GameManager.kills
	await get_tree().create_timer(0.8,true).timeout
	check(GameManager.contribution_row(credit_source.hero_id).kills==1 and GameManager.kills>before_kills,"finalized death lost source attribution")
	check(GameManager.contribution_row(credit_source.hero_id).damage>0,"damage contribution absent")
	check(GameManager.contribution_text().contains(captain.display_name) and GameManager.contribution_text().contains("羈絆收益"),"summary lacks contributions")
	var area_target: Node=EntityFactory.spawn_enemy("normal",{"max_hp":10,"speed":0,"damage":0,"xp":0,"gold":0,"radius":12},captain.global_position+Vector2(290,120))
	area_target.set_physics_process(false)
	var kills_before_area: int=GameManager.contribution_row(credit_source.hero_id).kills
	EntityFactory.apply_explosion_damage(area_target.global_position,{"area_radius":20,"damage":20,"source_weapon_id":"r2_area_credit"},credit_source)
	await get_tree().create_timer(0.8,true).timeout
	check(GameManager.contribution_row(credit_source.hero_id).kills==kills_before_area+1,"area explosion omitted killer attribution")
	var late_target: Node=EntityFactory.spawn_enemy("normal",{"max_hp":10,"speed":0,"damage":0,"xp":0,"gold":0,"radius":12},captain.global_position+Vector2(390,120))
	late_target.set_physics_process(false)
	var late_damage: float=late_target.take_damage(20,captain.global_position)
	late_target._finalize_death() # exercise the immediate-finalization callback order
	var total_before_transfer: int=GameManager.kills
	var known_before_transfer: int=GameManager.contribution_row(credit_source.hero_id).kills
	GameManager.record_weapon_damage(credit_source,"r2_late_credit",late_damage,"",late_target)
	check(GameManager.kills==total_before_transfer and GameManager.contribution_row(credit_source.hero_id).kills==known_before_transfer+1,"late source transfer duplicated/lost global kill")
	var credited_total:=0
	for row in GameManager.contribution.values():credited_total+=int(row.kills)
	check(credited_total==GameManager.kills-total_at_clear,"contribution kills disagree with finalized global kills")
	var squad: Node=GameManager.squad_manager
	squad.recruit_hero("echo_singer")
	squad.set_formation("ring",true)
	var previous: float=GameManager.bond_benefits.prevented
	captain.invulnerability_timer=0
	captain.take_damage(10,captain.global_position+Vector2(40,0))
	check(is_equal_approx(GameManager.bond_benefits.prevented,previous),"bond claims prevention already swallowed by global soft cap")
	squad.set_formation("wedge",true)
	captain.invulnerability_timer=0
	captain.take_damage(10,captain.global_position+Vector2(40,0))
	check(GameManager.bond_benefits.prevented>previous,"actual bond reduction not counted")
	# Real Area2D overlap crosses half HP during physics query flushing.
	var config: Dictionary=preload("res://scripts/services/stage_catalog.gd").get_boss_config("moon")
	config["tactical_min_cycles"]=2
	var boss: Node=EntityFactory.spawn_enemy("r2_physics_half_hp",config,captain.global_position+Vector2(180,0))
	boss.set_physics_process(false)
	var projectile: Node=EntityFactory.spawn_projectile(boss.global_position,Vector2.RIGHT,{"damage":1500.0,"projectile_speed":0.0,"range":100,"target_group":"enemies","source_weapon_id":"r2_physics"},captain)
	check(projectile!=null,"physics half-HP projectile missing")
	for frame in range(8):
		await get_tree().physics_frame
	check(boss.boss_phase_two_triggered and GameManager.tactical_director.boss_guard_at>GameManager.elapsed_time,"physics impact skipped half-HP warning")
	var burst_boss: Node=EntityFactory.spawn_enemy("r2_overkill_phase",config,captain.global_position+Vector2(300,0))
	burst_boss.set_physics_process(false)
	burst_boss.tactical_recoveries=2 # The two base cycles may predate its first hit.
	burst_boss.take_damage(99999,captain.global_position)
	check(burst_boss.boss_phase_two_triggered and not burst_boss.is_dying and burst_boss.hp<=burst_boss.max_hp*0.5,"overkill after base cycles skipped half HP")
	burst_boss.take_damage(99999,captain.global_position)
	check(not burst_boss.is_dying,"half-HP arrival warning could be skipped by next hit")
	GameManager.elapsed_time+=10
	GameManager.tactical_director.boss_guard_spawned=false
	burst_boss.take_damage(99999,captain.global_position)
	check(not burst_boss.is_dying,"full pool/pending escort allowed boss to disappear")
	GameManager.tactical_director.boss_guard_spawned=true
	burst_boss.take_damage(99999,captain.global_position)
	check(burst_boss.is_dying and burst_boss.current_animation_name==&"death","released half-HP gate does not permit real death")

func _layout_test() -> void:
	for size in [Vector2i(844,390),Vector2i(390,844),Vector2i(1366,600)]:
		MobileTuning.set_device_hints_override_for_tests({"ua_phone":size.x!=1366,"ua_mobile":size.x!=1366,"touch_available":size.x!=1366,"mouse_available":size.x==1366})
		var view:=SubViewport.new()
		view.size=size
		view.render_target_update_mode=SubViewport.UPDATE_DISABLED
		add_child(view)
		GameManager.selected_stage_id="moon"
		arena=preload("res://scenes/arena/Arena.tscn").instantiate()
		view.add_child(arena)
		await get_tree().process_frame
		var relay: Node=GameManager.tactical_director.relay
		var hud: Node=arena.get_node("HUD")
		GameManager.set_process(false)
		hud._apply_responsive_layout()
		await get_tree().process_frame
		for step in range(3):
			relay.step=step
			relay._update_label()
			hud._update_tactical_hint()
			var text: String="封隙 %d/3"%step
			check(hud.tactical_hint.text.contains(text) and GameManager.tactical_director.progress_text().contains(text),"HUD/pause do not share seal truth")
			check(not relay.marker_label.text.contains("/3"),"ordinal looks like completion count")
			check(Rect2(Vector2.ZERO,Vector2(size)).encloses(relay.marker_label.get_global_rect()),"marker outside viewport")
			for region in BattleLayout.regions(Vector2(size),size.x!=1366).values():
				check(not relay.marker_label.get_global_rect().intersects(region),"marker overlaps HUD/notice")
			var transform:=view.get_canvas_transform()
			for member in GameManager.squad_manager.get_members():
				var screen: Vector2=transform*member.global_position
				check(not relay.marker_label.get_global_rect().intersects(Rect2(screen-Vector2(26,55),Vector2(52,76))),"character covers marker label %s label=%s actor=%s"%[size,relay.marker_label.get_global_rect(),screen])
		GameManager.set_manual_pause(true)
		relay._update_label()
		check(not relay.marker_label.visible,"marker shines through pause")
		GameManager.set_manual_pause(false)
		if size==Vector2i(844,390):
			var squad: Node=GameManager.squad_manager
			for id in ["echo_singer","ember_grenadier","void_weaver","rift_sniper","rift_shepherd","pulse_artificer"]:
				squad.recruit_hero(id)
			var victory: Node=arena.get_node("StageVictoryScreen")
			GameManager.contribution_row("unattributed").kills=5
			GameManager.contribution_row("unattributed")["name"]="其他來源"
			victory.show_summary({"stage_name":"蒼月空庭","boss_name":"蒼月石鬼","contribution_text":GameManager.contribution_text()})
			await get_tree().process_frame
			check(victory.summary_label.size.y<=victory.summary_scroll.size.y+1,"nine-member contribution table requires scrolling in landscape %s/%s"%[victory.summary_label.size,victory.summary_scroll.size])
			check(victory.summary_label.text.contains("羈絆收益"),"bond gains absent from summary")
			check(victory.summary_label.get_theme_font_size("font_size")>=14,"summary font below readable CSS minimum")
			victory.hide_screen()
		GameManager.game_running=false
		view.queue_free()
		await get_tree().process_frame
	MobileTuning.set_device_hints_override_for_tests({})
