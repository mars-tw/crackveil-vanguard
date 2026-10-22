extends "res://scripts/debug/content_r2_run.gd"

# Continuous real-game comparison. The driver uses the normal menu controls,
# seed submit, auto-battle handler and virtual movement/formation input. It never
# assigns HP, damage, elapsed time, seal progress, boss state or completion flags.
var team:="assault"
var chosen_node:="spec_shield"
var booting:=true
var initial: Dictionary={}
var phase_rows: Dictionary={}
var phase_refs: Dictionary={}
var capacity: Dictionary={}
var entry_steps: Array[String]=[]

func _ready() -> void:
	process_mode=PROCESS_MODE_ALWAYS
	get_tree().current_scene=null
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.split("=",true,1)
		if pair.size()!=2:continue
		match pair[0]:
			"team":team=pair[1]
			"seed":seed_value=int(pair[1])
	chosen_node="spec_escort" if team=="escort" else "spec_shield"
	AudioManager.set_muted(true)
	assert(MetaProgress.starting_owned.is_empty() and MetaProgress.shards==0 and MetaProgress.starting_vouchers==1,"comparison requires a fresh isolated initial profile")
	stage="moon"
	GameManager.tactical_launch=false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	var menu: Node=get_tree().current_scene
	menu._open_build_preparation()
	var preparation: Node=menu.get_node("BuildPreparation")
	preparation.tab=0
	preparation.index=1 if team=="escort" else 0
	preparation._refresh()
	preparation.controls.action.pressed.emit()
	entry_steps.append("normal preparation team selection")
	preparation.tab=3
	preparation.index=1 if team=="escort" else 0
	preparation._refresh()
	preparation.controls.action.pressed.emit() # Initial free unlock.
	preparation.controls.action.pressed.emit() # Equip the actually owned node.
	assert(MetaProgress.starting_equipped==chosen_node and MetaProgress.starting_vouchers==0 and MetaProgress.shards==0,"formal unlock/equip failed")
	entry_steps.append("normal initial-choice unlock then exclusive equip")
	initial={"shards":MetaProgress.shards,"lifetime":MetaProgress.lifetime_shards,"upgrades":MetaProgress.upgrades.duplicate(true),"vouchers":MetaProgress.starting_vouchers,"valid_settlements":MetaProgress.starting_settlements.size(),"wallet_gold":GameManager.wallet_gold,"campaign_clears":GameManager.campaign_clears.duplicate(),"team":MetaProgress.starting_team,"node":MetaProgress.starting_equipped}
	preparation.controls.close.pressed.emit()
	menu.seed_input.text=str(seed_value)
	menu.seed_input.text_submitted.emit(str(seed_value))
	entry_steps.append("normal seed field submit")
	while not GameManager.game_running or not is_instance_valid(GameManager.arena): await get_tree().process_frame
	arena=GameManager.arena
	if not GameManager.auto_upgrade_enabled:
		arena.get_node("HUD")._toggle_auto_battle()
		entry_steps.append("normal auto-battle button handler enabled battle")
	else:
		entry_steps.append("normal mobile Arena auto-battle default already enabled")
	initial["roster"]=[]
	initial["total_hp"]=0.0
	initial["total_max_hp"]=0.0
	for member in GameManager.squad_manager.get_members():
		initial.roster.append({"id":member.hero_id,"hp":member.current_hp,"max_hp":member.max_hp})
		initial.total_hp+=member.current_hp
		initial.total_max_hp+=member.max_hp
	wall_start=Time.get_ticks_msec()
	booting=false

func _process(delta: float) -> void:
	if booting or finished or not is_instance_valid(arena):return
	_update_phase_records()
	super._process(delta)

func _snapshot() -> Dictionary:
	var hp:=0.0
	var maximum:=0.0
	var living:=0
	var ids:=[]
	for member in GameManager.squad_manager.get_members():
		capacity[member.hero_id]=maxf(float(capacity.get(member.hero_id,0)),member.max_hp)
		hp+=maxf(0,member.current_hp)
		maximum+=member.max_hp
		if member.is_alive:living+=1
		ids.append(member.hero_id)
	var taken:=0.0
	var healing:=0.0
	var prevented:=0.0
	for row in GameManager.contribution.values():
		taken+=float(row.taken)
		healing+=float(row.get("healing",0))
		prevented+=float(row.get("prevented",0))
	var all_capacity:=0.0
	for value in capacity.values():all_capacity+=float(value)
	return {"time":GameManager.elapsed_time,"hp":hp,"current_max_hp":maximum,"all_recruited_max_hp":all_capacity,"hp_retention":hp/maxf(1,all_capacity),"taken":taken,"healing":healing,"prevented":prevented,"living":living,"roster":ids,"kills":GameManager.kills}

func _update_phase_records() -> void:
	var relay: Node=GameManager.tactical_director.relay
	var pressure: Node=relay.pressure
	var now:=_snapshot()
	for key in phase_rows:
		var row: Dictionary=phase_rows[key]
		if not row.has("end") and relay.step>int(key):
			row["end"]=now.duplicate(true)
			row["seal_seconds"]=float(now.time)-float(row.start.time)
			row["taken_delta"]=float(now.taken)-float(row.start.taken)
			row["taken_per_start_capacity"]=float(row.taken_delta)/maxf(1,float(row.start.current_max_hp))
			row["healing_delta"]=float(now.healing)-float(row.start.healing)
			row["prevented_delta"]=float(now.prevented)-float(row.start.prevented)
			row["actual_formation"]=relay.history[int(key)].formation
	if relay.completed or not pressure.started:return
	var key:=str(relay.step)
	if not phase_rows.has(key):
		phase_rows[key]={"kind":pressure.kind,"start":now.duplicate(true)}
		phase_refs[key]=pressure.enemies.duplicate()
	var row: Dictionary=phase_rows[key]
	if not row.has("first_second_guards") and GameManager.elapsed_time-float(row.start.time)>=0.8:
		var guards:=[]
		for ref in phase_refs[key]:
			var enemy: Object=ref.get_ref()
			if is_instance_valid(enemy):guards.append({"hp":enemy.hp,"max_hp":enemy.max_hp,"fraction":enemy.hp/maxf(1,enemy.max_hp),"animation":str(enemy.current_animation_name)})
		row["first_second_guards"]=guards
		row["probe_time"]=GameManager.elapsed_time

func _finish(outcome: String) -> void:
	finished=true
	_update_phase_records()
	var relay: Node=GameManager.tactical_director.relay
	var result:={"status":"VERIFIED" if outcome=="win" else "BLOCKED","version":ProjectSettings.get_setting("application/config/version"),"stage":stage,"team":team,"node":chosen_node,"seed":seed_value,"outcome":outcome,"time":GameManager.elapsed_time,"initial":initial,"ending":_snapshot(),"phases":phase_rows,"history":relay.history,"seals":relay.step,"wrong":relay.wrong_penalties,"contributions":GameManager.contribution,"benefits":GameManager.starting_benefits,"guards":GameManager.tactical_director.guard_history,"campaign_clear":GameManager.campaign_clears.has(stage),"entry_steps":entry_steps,"wall_seconds":(Time.get_ticks_msec()-wall_start)/1000.0,"input_policy":"normal menu pressed/text_submitted signals, auto-battle handler and virtual movement/formation; no HP/DPS/time/completion injection"}
	DirAccess.make_dir_recursive_absolute("res://docs/content/r3/tests/paired")
	var file:=FileAccess.open("res://docs/content/r3/tests/paired/%s.json" % team,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("CONTENT_R3_RUN_%s team=%s t=%.2f seals=%d" % ["PASS" if outcome=="win" else "FAIL",team,GameManager.elapsed_time,relay.step])
	get_tree().quit(0 if outcome=="win" else 1)
