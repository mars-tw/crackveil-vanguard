extends Node

const CATALOG := preload("res://scripts/services/starting_build_catalog.gd")
var checks:=0
var failures: Array[String]=[]
var evidence: Array[Dictionary]=[]
var arena: Node
var meta_path: String
var toasts: Array[String]=[]
var atomic_cases: Array[Dictionary]=[]

func _ready() -> void:
	process_mode=PROCESS_MODE_ALWAYS
	get_tree().current_scene=null # Keep this supervisor through real menu replacements.
	GameManager.toast_requested.connect(func(message: String):toasts.append(message))
	call_deferred("_run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("CONTENT_R3_FAIL "+message)

func _run() -> void:
	AudioManager.set_muted(true)
	meta_path=MetaProgress.save_path
	check("qa_content_r3" in meta_path and "qa_content_r3" in AudioManager.save_path and "qa_content_r3" in GameManager.campaign_save_path,"QA profile was not selected before autoload ready")
	_transaction_test()
	_atomic_transaction_test()
	for row in CATALOG.NODES:
		await _setup(row.id)
		var finished: Variant=await _effect_test(row.id)
		check(finished==true,"node test aborted before completing "+str(row.id))
		evidence.append({"id":row.id,"roster":_ids(),"failures":failures.size()})
		await _cleanup()
	await _early_defeat_guarantee()
	await _restart_choice_test()
	var navigation_finished: Variant=await _settlement_navigation_test()
	check(navigation_finished==true,"settlement navigation test aborted")
	for id in ["spec_shield","spec_escort","spec_prepare"]:
		await _setup(id,"escort","endless")
		check(GameManager.get_incoming_damage_multiplier(GameManager.player)>0,"direct endless specialization has invalid relay")
		check(is_equal_approx(GameManager.squad_manager.get_formation_speed_multiplier(),1.0),"campaign-only escort cost remained in direct endless")
		check(GameManager.starting_build_text().contains("本模式不再觸發") and MetaProgress.starting_equipped==id,"mode restriction hides/unequips saved choice")
		GameManager.tactical_director.relay._update_label()
		check(not GameManager.tactical_director.relay.marker_label.visible,"campaign marker leaked into direct endless")
		await _cleanup()
	await _geometry_test()
	var result:={"status":"VERIFIED" if failures.is_empty() else "BLOCKED","checks":checks,"failures":failures,"nodes":evidence,"atomic_cases":atomic_cases,"user_data_dir":OS.get_user_data_dir(),"qa_paths":{"meta":meta_path,"audio":AudioManager.save_path,"campaign":GameManager.campaign_save_path},"fixture":"controlled real Arena mechanics, transactional files and UI geometry; not a natural gameplay win"}
	DirAccess.make_dir_recursive_absolute("res://docs/content/r3/tests")
	var file:=FileAccess.open("res://docs/content/r3/tests/mechanics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("CONTENT_R3_%s checks=%d failures=%d" % [result.status,checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

# The read-only fixture must really refuse the save on every CI platform.
# Windows: the file's read-only attribute blocks Godot's replace-by-rename.
# Linux/macOS: a read-only file can still be replaced by rename, so the
# containing directory is made non-writable as well, and a probe write must
# actually fail before the fixture counts as created (never assumed).
func _set_save_read_only(path: String, on: bool) -> bool:
	if OS.get_name() == "Windows":
		return FileAccess.set_read_only_attribute(path, on) == OK
	var file := ProjectSettings.globalize_path(path)
	var dir := file.get_base_dir()
	if on:
		if FileAccess.set_unix_permissions(file, 292) != OK or FileAccess.set_unix_permissions(dir, 365) != OK: # 0444 / 0555
			return false
		var probe := FileAccess.open(dir.path_join("r3_read_only_probe.tmp"), FileAccess.WRITE)
		if probe != null:
			probe.close()
			DirAccess.remove_absolute(dir.path_join("r3_read_only_probe.tmp"))
			return false
		return true
	var restored := FileAccess.set_unix_permissions(dir, 493) == OK # 0755
	return FileAccess.set_unix_permissions(file, 420) == OK and restored # 0644

func _transaction_test() -> void:
	var config:=ConfigFile.new()
	config.set_value("echo","shards",187)
	config.set_value("echo","lifetime_shards",240)
	config.set_value("upgrades","echo_vitality",2)
	config.set_value("tactical","moon",3)
	config.set_value("formation_seals","moon",true)
	config.set_value("future_owner_setting","keep_me","unaltered")
	config.save(meta_path)
	check(_set_save_read_only(meta_path,true),"cannot create real read-only migration fixture")
	MetaProgress.load_progress()
	check(not MetaProgress.starting_ready and MetaProgress.shards==187,"failed migration did not preserve economy/block unavailable choices")
	check(not MetaProgress.purchase_starting_node("crew_guard"),"failed migration allowed unpersisted voucher spending")
	_set_save_read_only(meta_path,false)
	MetaProgress.load_progress()
	check(MetaProgress.shards==187 and MetaProgress.lifetime_shards==240 and MetaProgress.get_upgrade_level("echo_vitality")==2,"migration lost nonzero economy/upgrades")
	check(MetaProgress.tactical_medals.moon==3 and MetaProgress.formation_seals.moon,"migration lost collections")
	config.load(meta_path)
	check(config.get_value("future_owner_setting","keep_me","")=="unaltered","migration erased unknown setting")
	check(MetaProgress.starting_vouchers==1 and MetaProgress.starting_owned.is_empty(),"first-run free choice missing")
	MetaProgress.load_progress()
	check(MetaProgress.starting_vouchers==1,"reload duplicated first voucher")
	var invalid:="user://qa_content_r3_missing_%d/not_writable.cfg" % Time.get_ticks_usec()
	MetaProgress.save_path=invalid
	check(not MetaProgress.purchase_starting_node("crew_guard") and MetaProgress.starting_vouchers==1 and MetaProgress.starting_owned.is_empty() and MetaProgress.shards==187,"failed first ticket purchase mutated economy")
	MetaProgress.save_path=meta_path
	check(MetaProgress.purchase_starting_node("crew_guard") and MetaProgress.starting_vouchers==0 and MetaProgress.shards==187,"first free choice charged shards")
	check(not MetaProgress.purchase_starting_node("crew_guard"),"duplicate purchase allowed")
	for number in range(1,CATALOG.NODES.size()):
		var before: int=MetaProgress.shards
		var row: Dictionary=CATALOG.NODES[number]
		check(MetaProgress.purchase_starting_node(row.id),"node cannot be purchased "+str(row.id))
		check(before-MetaProgress.shards==4+2*(number%5),"node cost differs from 4/6/8/10/12")
		check(MetaProgress.equip_starting_node(row.id) and MetaProgress.starting_equipped==row.id,"exclusive equip failed")
	var balance: int=MetaProgress.shards
	for id in ["spec_escort","spec_shield","spec_escort",""]:
		MetaProgress.equip_starting_node(id)
	check(MetaProgress.shards==balance and MetaProgress.starting_vouchers==0,"equip switching minted resources")
	MetaProgress.load_progress()
	check(MetaProgress.starting_owned.size()==15 and MetaProgress.starting_equipped=="","ownership/equip reload failed")
	MetaProgress.save_path=invalid
	check(not MetaProgress.equip_starting_node("spec_escort") and MetaProgress.starting_equipped=="","failed equip changed saved selection")
	MetaProgress.save_path=meta_path
	for number in range(3): check(MetaProgress.record_starting_settlement("r3-valid-%d" % number,{"elapsed_time":10,"kills":0,"settlement_reason":"defeat","captain_dead":true},true),"early novice defeat was excluded from fifth-run guarantee")
	check(not MetaProgress.record_starting_settlement("menu-exit",{"elapsed_time":200,"kills":100},true),"menu exit earned credit")
	check(not MetaProgress.record_starting_settlement("alive",{"settlement_reason":"defeat","captain_dead":false},true),"live player pretend defeat earned credit")
	check(not MetaProgress.record_starting_settlement("not-formal",{"settlement_reason":"defeat","captain_dead":true},false),"debug/nonformal run earned credit")
	MetaProgress.save_path=invalid
	check(not MetaProgress.record_starting_settlement("r3-fourth",{"settlement_reason":"defeat","captain_dead":true},true) and MetaProgress.starting_settlements.size()==3 and not MetaProgress.starting_second_granted,"failed fourth settlement awarded voucher")
	MetaProgress.save_path=meta_path
	MetaProgress.load_progress()
	check(MetaProgress.starting_settlements.size()==3 and MetaProgress.starting_vouchers==0,"failed fourth settlement leaked to disk")
	check(MetaProgress.record_starting_settlement("r3-fourth",{"settlement_reason":"defeat","captain_dead":true},true),"fourth settlement retry failed")
	MetaProgress.load_progress()
	check(MetaProgress.starting_settlements.size()==4 and MetaProgress.starting_vouchers==1 and MetaProgress.starting_second_granted,"second choice not available before fifth run")
	check(not MetaProgress.record_starting_settlement("r3-fourth",{"elapsed_time":200,"kills":100},true) and MetaProgress.starting_vouchers==1,"same settlement duplicated voucher")

func _setup(id: String,team: String="assault",mode: String="campaign") -> void:
	MetaProgress.save_path=meta_path
	MetaProgress.starting_team=team
	MetaProgress.starting_equipped=id
	if id!="" and not MetaProgress.starting_owned.has(id): MetaProgress.starting_owned.append(id)
	GameManager.prepare_starting_build()
	GameManager.selected_stage_id="moon"
	GameManager.run_mode=mode
	GameManager.tactical_launch=false
	GameManager.forced_run_seed=55210
	arena=preload("res://scenes/arena/Arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	get_tree().current_scene=arena
	await get_tree().process_frame
	GameManager.set_process(false)
	arena.get_node("EnemySpawner").set_process(false)
	GameManager.tactical_director.set_process(false)
	GameManager.tactical_director.relay.set_process(false)
	GameManager.tactical_director.relay.pressure.set_process(false)
	GameManager.squad_manager.set_process(false)
	for member in GameManager.squad_manager.get_members():
		member.set_physics_process(false)
		for weapon in member.weapons.values(): weapon.set_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"): EntityFactory.release_enemy(enemy)
	check(GameManager.active_starting_node==id and GameManager.active_starting_formal,"formal selection did not reach Arena")
	check(_ids().size()==3 and _ids()[0]=="rift_captain","invalid initial squad")

func _ids() -> Array:
	var result:=[]
	for member in GameManager.squad_manager.get_members(): result.append(member.hero_id)
	return result

func _member(id: String) -> Node:
	for member in GameManager.squad_manager.get_members():
		if member.hero_id==id:return member
	return null

func _effect_test(id: String) -> bool:
	var squad: Node=GameManager.squad_manager
	var captain: Node=GameManager.player
	var relay: Node=GameManager.tactical_director.relay
	match id:
		"crew_guard":
			check(_ids().has("orbit_guard") and _ids().has("solar_lancer") and not _ids().has("arc_scout"),"guard roster did not exchange chain-lightning seat")
			squad.set_formation("ring",true)
			check(captain.temporary_shield_hp>0 and squad.get_formation_switch_cooldown_duration()<4,"guard passive is not real")
		"crew_singer":
			check(squad.has_active_bond("bond_guard_echo"),"singer bond unavailable")
			var singer: Node=_member("echo_singer")
			var hymn: Node=singer.weapons.values()[0]
			hymn.cooldown_timer=0
			hymn._process(0)
			check(is_equal_approx(hymn.cooldown_timer,hymn.scaled_cooldown(hymn.data_float("cooldown",1))*0.75),"singer has no distinct support benefit over free escort")
			var damage: float=GameManager.get_outgoing_damage_multiplier(captain)
			GameManager.active_starting_node=""
			check(is_equal_approx(damage/GameManager.get_outgoing_damage_multiplier(captain),0.9),"singer burst cost missing")
		"crew_scout":
			var speed: float=squad.get_formation_speed_multiplier()
			var incoming: float=GameManager.get_incoming_damage_multiplier(captain)
			GameManager.active_starting_node=""
			check(speed>squad.get_formation_speed_multiplier()*1.1 and incoming>GameManager.get_incoming_damage_multiplier(captain),"scout benefit/armor cost missing")
		"crew_gunner":
			check(squad.has_active_bond("bond_ember_pulse"),"gunner bond unavailable")
			captain.channel_energy=0
			captain._tick_channel(1.0)
			check(captain.channel_energy>0 and captain.channel_energy<captain.CHANNEL_ENERGY_REGEN,"gunner recharge cost missing")
		"crew_shepherd":
			var weapon: Node=_member("rift_shepherd").weapons.values()[0]
			check(weapon._owner_active_cap(weapon._construct_stats())==2,"shepherd cap not enforced")
		"bond_harmony":
			squad.set_formation("ring",true)
			var singer: Node=_member("echo_singer")
			singer.global_position=captain.global_position+Vector2(20,0)
			var guard: Node=_member("orbit_guard")
			guard.global_position=captain.global_position+Vector2(200,0)
			captain.current_hp-=10
			guard.current_hp-=10
			var guard_hp: float=guard.current_hp
			var before: float=captain.current_hp
			squad._tick_formation_resonance(1.01)
			check(captain.current_hp>before and guard.current_hp==guard_hp,"harmony circle boundary not real")
			check(GameManager.contribution_row("echo_singer").healing>0,"healing not credited to singer")
			squad.set_formation("wedge",true)
			captain.temporary_shield_hp=0
			captain.invulnerability_timer=0
			captain.take_damage(10,captain.global_position+Vector2.RIGHT)
			check(GameManager.contribution_row("orbit_guard").prevented>0,"actual HP reduction not credited to living guard")
			squad.set_formation("ring",true)
			singer.is_alive=false
			squad.recompute_bonds()
			check(squad.get_formation_regen_per_second()==0,"dead singer still grants rescue")
		"bond_rail":
			check(squad.has_active_bond("bond_void_rail"),"rail bond unavailable")
			captain.velocity=Vector2(100,0)
			var moving: float=GameManager.get_outgoing_damage_multiplier(captain)
			captain.velocity=Vector2.ZERO
			var stopped: float=GameManager.get_outgoing_damage_multiplier(captain)
			GameManager.active_starting_node=""
			var base: float=GameManager.get_outgoing_damage_multiplier(captain)
			check(moving>base and stopped<base,"rail movement tradeoff missing")
		"bond_relay":
			var weapon: Node=_member("pulse_artificer").weapons.values()[0]
			var enlarged: float=weapon._effect_stats_for_fire().area_radius
			GameManager.active_starting_node=""
			var base: float=weapon._effect_stats_for_fire().area_radius
			GameManager.active_starting_node=id
			check(enlarged>base*1.2,"relay radius benefit missing")
			var target: Node=EntityFactory.spawn_enemy("r3_delay",{"max_hp":1000,"speed":0,"damage":0,"xp":0,"gold":0,"radius":10},captain.global_position+Vector2(20,0))
			target.set_physics_process(false)
			weapon.cooldown_timer=0
			weapon._process(0)
			var hp: float=target.hp
			for frame in range(12): await get_tree().process_frame
			check(target.hp==hp,"relay damage occurred before delayed blast")
			for frame in range(30): await get_tree().process_frame
			check(target.hp<hp,"relay delayed blast never applied damage")
		"bond_construct":
			var weapon: Node=_member("rift_shepherd").weapons.values()[0]
			var duration: float=weapon._construct_stats().effect_lifetime
			GameManager.active_starting_node=""
			check(duration>weapon._construct_stats().effect_lifetime*1.3 and squad.squad_data.max_members==8,"construct duration/slot cost missing")
		"bond_reserve":
			GameManager.level=1
			check(squad._can_offer_recruit_for_slot(4),"reserve did not advance recruit gate")
			check(not squad.recruit_hero("rift_shepherd") and squad.recruit_hero("orbit_guard"),"reserve family restriction not enforced")
		"spec_shield":
			relay.pressure.begin()
			var guard: Node=relay.pressure.enemies[0].get_ref()
			guard.set_physics_process(false)
			guard.set_meta("seal_guard",true)
			GameManager.critical_strikes_enabled=false
			relay.pressure.kind="front"
			var boosted: float=guard.take_damage(4,captain.global_position)
			GameManager.active_starting_node=""
			var ordinary: float=guard.take_damage(4,captain.global_position)
			check(boosted>ordinary*1.2,"shield specialization did not affect actual shield HP")
			GameManager.active_starting_node=id
			relay.pressure.configure(relay.anchor,1)
			var waiting: float=GameManager.get_incoming_damage_multiplier(captain)
			GameManager.active_starting_node=""
			check(is_equal_approx(waiting,GameManager.get_incoming_damage_multiplier(captain)),"unopened pincer applies flank penalty")
			GameManager.active_starting_node=id
			relay.pressure.begin()
			var exposed: float=GameManager.get_incoming_damage_multiplier(captain)
			GameManager.active_starting_node=""
			check(exposed>GameManager.get_incoming_damage_multiplier(captain)*1.15,"shield flank vulnerability missing")
			GameManager.active_starting_node=id
			relay.pressure.advance(relay.pressure.WARNING+relay.pressure.ACTIVE)
			var recovered: float=GameManager.get_incoming_damage_multiplier(captain)
			GameManager.active_starting_node=""
			check(is_equal_approx(recovered,GameManager.get_incoming_damage_multiplier(captain)),"pincer recovery kept flank penalty")
			GameManager.active_starting_node=id
			relay.pressure.phase="active"
			relay.pressure.enabled=false
			var disabled: float=GameManager.get_incoming_damage_multiplier(captain)
			GameManager.active_starting_node=""
			check(is_equal_approx(disabled,GameManager.get_incoming_damage_multiplier(captain)),"completed/disabled pincer kept flank penalty")
		"spec_escort":
			check(CATALOG.accepts(id,"front","ring") and CATALOG.accepts(id,"front","wedge"),"escort removed original formation option")
			check(squad.get_formation_speed_multiplier()<1,"escort mobility cost missing")
			GameManager.elapsed_time=12
			squad.set_formation("ring",true)
			captain.global_position=relay.anchor
			for member in squad.get_members(): member.global_position=squad.get_formation_world_position(member.formation_index)
			relay.pressure.started=true
			relay.pressure.phase="recovery"
			relay.advance(1)
			check(relay.wrong_penalties==0 and relay.hold>0 and relay.hold<1,"escort alternate seal path/capture cost missing")
		"spec_collect":
			squad.set_formation("scatter",true)
			check(squad.get_formation_pickup_multiplier()>2 and CATALOG.accepts(id,"pincer","scatter"),"scatter recovery alternative missing")
			var melee: float=GameManager.get_melee_damage_multiplier(captain)
			var ranged: float=GameManager.get_outgoing_damage_multiplier(captain)
			check(is_equal_approx(melee/ranged,0.8),"scatter cost is not limited to actual captain melee")
			GameManager.active_starting_node=""
			check(is_equal_approx(ranged,GameManager.get_outgoing_damage_multiplier(captain)),"scatter incorrectly penalizes captain ranged source")
		"spec_step":
			squad.set_formation("ring",true)
			var boosted: float=squad.get_formation_speed_multiplier()
			var cooldown: float=squad.get_formation_switch_cooldown_duration()
			GameManager.starting_step_timer=0
			check(boosted>squad.get_formation_speed_multiplier()*1.2,"step mobility window missing")
			GameManager.active_starting_node=""
			check(cooldown>squad.get_formation_switch_cooldown_duration()*1.7,"step cooldown cost missing")
		"spec_prepare":
			GameManager.elapsed_time=20
			captain.global_position=relay.anchor
			squad.set_formation("wedge",true)
			for member in squad.get_members(): member.global_position=squad.get_formation_world_position(member.formation_index)
			captain.current_hp-=10
			var hp: float=captain.current_hp
			relay.pressure.started=true
			relay.pressure.phase="recovery"
			relay.pressure.cycles=2
			relay.hold=relay.HOLD_SECONDS-0.1
			relay.advance(0.2)
			check(relay.step==1 and captain.current_hp==hp and relay.counter_timer==10,"prepare did not exchange immediate heal for counter time")
			check(toasts[-1].contains("10 秒") and not toasts[-1].contains("整補"),"first seal toast promises unearned healing/wrong counter duration")
			relay.step=2
			relay.pressure.configure(relay.anchor,2)
			relay.pressure.started=true
			relay.pressure.phase="recovery"
			relay.pressure.cycles=2
			GameManager.elapsed_time=100
			captain.global_position=relay.anchor
			squad.set_formation("scatter",true)
			for member in squad.get_members():member.global_position=squad.get_formation_world_position(member.formation_index)
			relay.hold=relay.HOLD_SECONDS-0.1
			relay.advance(0.2)
			check(relay.completed and captain.current_hp==hp and relay.counter_timer==10,"third seal prepare rule differs from first")
			check(toasts[-1].contains("10 秒") and not toasts[-1].contains("整補"),"third seal toast promises unearned healing/wrong counter duration")
	GameManager.active_starting_node=id
	GameManager.critical_strikes_enabled=true
	return true

func _early_defeat_guarantee() -> void:
	MetaProgress.reset_progress()
	check(MetaProgress.purchase_starting_node("spec_escort") and MetaProgress.equip_starting_node("spec_escort"),"new first-run free official choice failed")
	for number in range(4):
		await _setup("spec_escort","escort")
		if number==3:
			MetaProgress.debug_save_fault="valid_prefix"
			MetaProgress.debug_save_fault_remaining=1
			GameManager.add_gold(8) # Controlled loot case: echo payment after milestone failure.
		GameManager.player.invulnerability_timer=0
		GameManager.player.take_damage(99999,GameManager.player.global_position+Vector2.RIGHT)
		for frame in range(80): await get_tree().process_frame
		check(GameManager.is_game_over and arena.get_node("GameOverScreen").root.visible,"early real death did not reach summary")
		if number<3:
			check(MetaProgress.starting_settlements.size()==number+1,"zero-kill early defeat excluded from valid run count")
			MetaProgress.load_progress()
			check(MetaProgress.starting_settlements.size()==number+1,"early defeat not persistent")
		else:
			check(MetaProgress.starting_settlements.size()==3 and GameManager.pending_starting_settlements.size()==1,"failed fourth milestone was lost or prematurely counted")
			check(arena.get_node("GameOverScreen").restart_button.text=="重試保存","pending fourth result hides its short retry control")
			var echo: int=MetaProgress.shards
			check(echo>0,"later legitimate echo save did not succeed after one failed milestone")
			MetaProgress.load_progress()
			check(MetaProgress.starting_settlements.size()==3 and MetaProgress.shards==echo,"echo payment falsely saved pending milestone")
			arena.get_node("GameOverScreen").main_menu_button.pressed.emit()
			for frame in range(6): await get_tree().process_frame
			var menu: Node=get_tree().current_scene
			check(menu!=null and menu.name=="MainMenu","actual defeat return did not reach menu")
			var prep: Node=menu.get_node_or_null("BuildPreparation")
			check(prep!=null and prep.root.visible and MetaProgress.starting_settlements.size()==4 and MetaProgress.starting_vouchers==1,"normal next-run preparation did not retry fourth milestone")
			check(GameManager.pending_starting_settlements.is_empty() and MetaProgress.shards==echo,"milestone retry duplicated echo payment")
			prep.controls.close.pressed.emit()
			menu._open_build_preparation()
			check(MetaProgress.starting_vouchers==1 and MetaProgress.shards==echo,"reopening preparation duplicated retry resources")
		await _cleanup()
	check(MetaProgress.starting_vouchers==1 and MetaProgress.starting_second_granted,"fifth-run choice not guaranteed after four real early defeats")

func _restart_choice_test() -> void:
	MetaProgress.reset_progress()
	check(MetaProgress.purchase_starting_node("spec_escort") and MetaProgress.equip_starting_node("spec_escort"),"restart choice fixture first selection failed")
	for number in range(4):
		await _setup("spec_escort","escort")
		GameManager.player.invulnerability_timer=0
		GameManager.player.take_damage(99999,GameManager.player.global_position+Vector2.RIGHT)
		for frame in range(80): await get_tree().process_frame
		check(MetaProgress.starting_settlements.size()==number+1,"real restart path defeat not counted")
		if number==3:
			var screen: Node=arena.get_node("GameOverScreen")
			check(screen.restart_button.text=="免費整備" and screen.displayed_summary.starting_build_text.contains("免費選擇 1 次"),"fourth result hides second choice")
			screen.restart_button.pressed.emit()
			for frame in range(7): await get_tree().process_frame
			var menu: Node=get_tree().current_scene
			var prep: Node=menu.get_node_or_null("BuildPreparation") if menu!=null else null
			check(prep!=null and prep.root.visible and MetaProgress.starting_vouchers==1 and not GameManager.game_running,"restart skipped fifth-run free preparation")
			check(menu.meta_button.text.contains("免費整備"),"menu free-choice entry is invisible")
			prep.controls.close.pressed.emit()
			menu._show_panel("settings")
			for frame in range(3): await get_tree().process_frame
			menu.side_scroll.scroll_vertical=200
			menu._show_panel("meta")
			for frame in range(3): await get_tree().process_frame
			check(menu.side_scroll.scroll_vertical==0,"switching settings to echoes retained hidden preparation entry")
			menu._open_build_preparation()
			prep.controls.launch.pressed.emit()
			for frame in range(7): await get_tree().process_frame
			arena=GameManager.arena
			check(GameManager.game_running and GameManager.active_starting_formal and MetaProgress.starting_vouchers==1 and GameManager.active_starting_node=="spec_escort","confirming current build with an unspent voucher loops/charges/changes loadout")
		await _cleanup()

func _settlement_navigation_test() -> bool:
	for id in ["","spec_prepare","spec_escort"]:
		await _setup(id,"escort")
		var count: int=MetaProgress.starting_settlements.size()
		var relay: Node=GameManager.tactical_director.relay
		GameManager.elapsed_time=130
		GameManager.kills=100
		relay.completed=true # Controlled lifecycle fixture, not natural-win evidence.
		relay.reward_saved=true
		relay.counter_timer=10 if id=="spec_prepare" else 5
		GameManager.record_boss_kill()
		check(GameManager.stage_victory_pending and arena.get_node("StageVictoryScreen").root.visible,"formal victory summary was not reached")
		var after_victory: int=MetaProgress.starting_settlements.size()
		var shards: int=MetaProgress.shards
		check(after_victory==count+1,"victory did not award exactly one eligible settlement")
		GameManager.continue_after_stage_victory()
		check(GameManager.run_mode=="endless" and not GameManager.stage_victory_pending,"continue endless did not resume same run")
		check(is_equal_approx(GameManager.squad_manager.get_formation_speed_multiplier(),1.0),"escort movement cost survived campaign completion")
		var boosted: float=GameManager.get_outgoing_damage_multiplier(GameManager.player)
		GameManager.set_process(true)
		relay.set_process(true)
		await get_tree().create_timer(11.1,false).timeout
		GameManager.set_process(false)
		relay.set_process(false)
		check(relay.counter_timer==0,"counter window froze while continuing endless")
		check(is_equal_approx(boosted/GameManager.get_outgoing_damage_multiplier(GameManager.player),1.2),"counter damage did not return to ordinary endless value")
		var hits: int=GameManager.starting_benefits.counter_hits
		var target: Node=EntityFactory.spawn_enemy("r3_after_window",{"max_hp":1000,"speed":0,"damage":0,"xp":0,"gold":0,"radius":10},GameManager.player.global_position+Vector2(20,0))
		target.set_physics_process(false)
		var applied: float=target.take_damage(5,GameManager.player.global_position)
		GameManager.record_weapon_damage(GameManager.player,"after_window",applied,"",target)
		check(GameManager.starting_benefits.counter_hits==hits,"expired extra-window hit counter kept growing")
		GameManager.elapsed_time=190
		GameManager.kills=180
		GameManager.player.current_hp=0
		GameManager.player.is_alive=false
		GameManager.player_died()
		check(arena.get_node("GameOverScreen").root.visible and MetaProgress.starting_settlements.size()==after_victory,"same-run endless death duplicated settlement")
		check(MetaProgress.shards>shards,"same-run legitimate additional echo delta was swallowed")
		await _cleanup()
	return true

func _geometry_test() -> void:
	PlayerSettings.ui_scale_index=2
	for size in [Vector2i(844,390),Vector2i(390,844),Vector2i(320,568),Vector2i(1366,600)]:
		var viewport:=SubViewport.new()
		viewport.size=size
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		add_child(viewport)
		var ui:=preload("res://scripts/ui/build_preparation.gd").new()
		viewport.add_child(ui)
		ui.open()
		for tab in range(4):
			ui.tab=tab
			for index in range(3 if tab==0 else 5):
				ui.index=index
				ui._refresh()
				await get_tree().process_frame
				var buttons:=ui.controls.values()
				for button in buttons:
					check(button.size.x>=44 and button.size.y>=44,"new prep target below 44px")
					check(Rect2(Vector2.ZERO,Vector2(size)).encloses(button.get_global_rect()),"new prep control outside viewport")
				for first in range(buttons.size()):
					for second in range(first+1,buttons.size()): check(not buttons[first].get_global_rect().intersects(buttons[second].get_global_rect()),"prep controls overlap")
				check(not ui.detail.get_global_rect().intersects(ui.state_label.get_global_rect()),"prep description overlaps state %s/%d/%d detail=%s state=%s" % [size,tab,index,ui.detail.get_global_rect(),ui.state_label.get_global_rect()])
		viewport.queue_free()
		await get_tree().process_frame
	PlayerSettings.ui_scale_index=1

func _cleanup() -> void:
	GameManager.game_running=false
	get_tree().paused=false
	GameManager.pending_starting_formal=false
	GameManager.active_starting_node=""
	if is_instance_valid(arena):arena.queue_free()
	var current: Node=get_tree().current_scene
	get_tree().current_scene=null
	if is_instance_valid(current) and not current.is_queued_for_deletion():current.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _atomic_transaction_test() -> void:
	var saved_path:=MetaProgress.save_path
	var modes:=["valid_prefix","replace_after_remove","interrupt_before_replace","interrupt_during_journal","interrupt_after_remove","interrupt_after_install"]
	for existed in [false,true]:
		for mode in modes:
			MetaProgress.save_path=saved_path+"_atomic_%s_%s_%d" % [str(existed),str(mode),Time.get_ticks_usec()]
			MetaProgress._reset_runtime_defaults()
			MetaProgress.debug_save_fault=""
			MetaProgress.debug_save_fault_remaining=-1
			if existed:
				MetaProgress.shards=17
				MetaProgress.lifetime_shards=25
				MetaProgress.starting_vouchers=0
				MetaProgress.starting_owned.assign(["crew_guard"])
				check(MetaProgress.save_progress(),"atomic fixture initial committed file failed")
				var source:=ConfigFile.new()
				source.load(MetaProgress.save_path)
				source.set_value("future_setting","tail","preserve entire unknown section")
				source.save(MetaProgress.save_path)
			var before: PackedByteArray=FileAccess.get_file_as_bytes(MetaProgress.save_path) if existed else PackedByteArray()
			MetaProgress.debug_save_fault=mode
			var success: bool=MetaProgress.purchase_starting_node("spec_prepare" if existed else "crew_guard")
			check(success==(mode=="interrupt_after_install"),"atomic commit result mismatch "+mode)
			if mode=="valid_prefix":
				var prefix:=ConfigFile.new()
				check(prefix.parse("[echo]\nshards=1\n")==OK,"partial fixture was not a legal config prefix")
			MetaProgress.debug_save_fault=""
			if existed and mode=="interrupt_after_remove":
				MetaProgress.debug_save_fault="recovery_failure"
				MetaProgress.load_progress()
				check(not MetaProgress.starting_ready and FileAccess.get_file_as_bytes(MetaProgress.save_path+".r3-backup")==before and FileAccess.file_exists(MetaProgress.save_path+".r3-journal"),"failed recovery erased verified original or pretended saved")
				check(not FileAccess.file_exists(MetaProgress.save_path),"failed recovery incorrectly claimed original path intact")
				MetaProgress.debug_save_fault=""
			MetaProgress.load_progress() # Recovery must precede migration/first-choice grant.
			var after: PackedByteArray=FileAccess.get_file_as_bytes(MetaProgress.save_path) if FileAccess.file_exists(MetaProgress.save_path) else PackedByteArray()
			if mode=="interrupt_after_install":
				check(MetaProgress.starting_owned.has("spec_prepare" if existed else "crew_guard"),"committed install was rolled back on recovery")
				check(MetaProgress.shards==(5 if existed else 0) and MetaProgress.starting_vouchers==0,"committed install duplicated/deleted money or ticket")
			else:
				check(before==after,"failed/interrupted save changed prior file bytes "+mode)
				check(MetaProgress.shards==(17 if existed else 0) and MetaProgress.starting_vouchers==(0 if existed else 1),"failed/interrupted save mutated money/ticket "+mode)
				check(not MetaProgress.starting_owned.has("spec_prepare" if existed else "crew_guard"),"failed/interrupted save left unlocked ownership")
			if existed:
				var restored:=ConfigFile.new()
				restored.load(MetaProgress.save_path)
				check(restored.get_value("future_setting","tail","")=="preserve entire unknown section","atomic transaction lost unknown tail")
			check(not FileAccess.file_exists(MetaProgress.save_path+".r3-backup") and not FileAccess.file_exists(MetaProgress.save_path+".r3-journal"),"resolved atomic transaction retained sidecars")
			atomic_cases.append({"existing":existed,"fault":mode,"committed":success,"before_sha256":MetaProgress._digest(before),"after_sha256":MetaProgress._digest(after),"recovered":MetaProgress.starting_ready})
	MetaProgress.save_path=saved_path
	MetaProgress.debug_save_fault=""
	MetaProgress.debug_save_fault_remaining=-1
	MetaProgress.load_progress()
