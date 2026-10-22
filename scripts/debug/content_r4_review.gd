extends "res://scripts/debug/content_r4_run.gd"

# Debug export only. Battle samples follow the same uninterrupted normal-input
# pilot as the native comparison. Freeze changes only observation timing. The
# fourth-defeat sequence is explicitly a lethal-damage UI fixture, not a play win.
var scenario := "battle"
var frozen := false
var review_index := 0
var captured: Array[String] = []
var factory_mode := Node.PROCESS_MODE_INHERIT
var guard_ref: WeakRef
var fixture_running := false
var milestone_progress: Array[Dictionary]=[]

func _ready() -> void:
	if not OS.has_feature("web") or not OS.is_debug_build():
		get_tree().quit(1)
		return
	team=str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('team') || 'assault'",true))
	scenario=str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('scenario') || 'battle'",true))
	if scenario=="milestone":
		fixture_running=true
		await _milestone_fixture()
		return
	await super._ready()
	booting=true
	factory_mode=EntityFactory.process_mode
	_set_frozen(true)
	await _official_gate()
	_set_frozen(false)
	booting=false

func _official_gate() -> void:
	var hud: Node=arena.get_node("HUD")
	while not AudioManager.is_audio_unlocked():
		JavaScriptBridge.eval("window.__cvContentR4Gate="+JSON.stringify({"rect":_rect(hud.audio_prompt_button.get_global_rect())}),true)
		await get_tree().process_frame
	JavaScriptBridge.eval("window.__cvContentR4Gate=null",true)
	for frame in range(3): await get_tree().process_frame
	assert(not hud.audio_prompt_button.visible and not GameManager.summon_screen.get_debug_state().visible and not get_tree().paused,"official start gesture clicked through")

func _process(delta: float) -> void:
	if fixture_running or booting or not is_instance_valid(arena):return
	if frozen:
		if bool(JavaScriptBridge.eval("window.__cvContentR4Next===true",true)):
			JavaScriptBridge.eval("window.__cvContentR4Next=false;window.__cvContentR4Sample=null",true)
			_set_frozen(false)
		return
	if finished:return
	super._process(delta)
	if finished or frozen:return
	var relay: Node=GameManager.tactical_director.relay
	var pressure: Node=relay.pressure
	for kind in ["front","pincer","artillery"]:
		if pressure.kind==kind and pressure.phase=="active" and pressure.clock>=0.70 and not captured.has(kind):
			captured.append(kind)
			_capture(kind+"-active","continuous normal-input battle; no time/HP/DPS/completion assignment")
			return
	if team!="assault":return
	if guard_ref==null and GameManager.tactical_director.boss_guard_spawned:
		var refs: Array=GameManager.tactical_director.guard_refs
		if not refs.is_empty():guard_ref=refs[-1].ref
	var guard: Object=guard_ref.get_ref() if guard_ref!=null else null
	if not is_instance_valid(guard):return
	if not captured.has("guard-warning") and guard.current_animation_name==&"attack" and guard.tactical_telegraph_timer>0.2:
		captured.append("guard-warning")
		_capture("guard-warning","continuous boss guard visible anticipation; no encounter injection")
	elif captured.has("guard-warning") and not captured.has("guard-impact") and guard.attack_impact_count>0:
		captured.append("guard-impact")
		_capture("guard-impact","same guard actual attack impact")
	elif captured.has("guard-impact") and not captured.has("guard-recovery") and guard.tactical_recoveries>0 and guard.current_animation_name!=&"attack":
		captured.append("guard-recovery")
		_capture("guard-recovery","same guard actual animation recovery")

func _set_frozen(value: bool) -> void:
	frozen=value
	arena.process_mode=PROCESS_MODE_DISABLED if value else PROCESS_MODE_INHERIT
	EntityFactory.process_mode=PROCESS_MODE_DISABLED if value else factory_mode
	GameManager.set_process(not value)

func _capture(label: String, provenance: String) -> void:
	var relay: Node=GameManager.tactical_director.relay
	GameManager.emit_stats()
	var hud: Node=arena.get_node("HUD")
	hud._update_tactical_hint()
	hud.root.get_node("CombatReadout")._refresh()
	var guards:=[]
	for entry in GameManager.tactical_director.guard_refs:
		var enemy: Object=entry.ref.get_ref()
		if is_instance_valid(enemy):
			guards.append({"token":enemy.spawn_token,"id":enemy.type_id,"hp":enemy.hp,"position":[enemy.global_position.x,enemy.global_position.y],"frame":enemy.animated_sprite.frame,"animation":str(enemy.current_animation_name),"telegraph":enemy.tactical_telegraph_timer,"impacts":enemy.attack_impact_count,"recoveries":enemy.tactical_recoveries})
	var payload:={"sample":review_index,"label":label,"team":team,"node":chosen_node,"scenario":scenario,"version":ProjectSettings.get_setting("application/config/version"),"seed":GameManager.current_run_seed,"time":GameManager.elapsed_time,"initial":initial,"snapshot":_snapshot(),"relay":relay.probe(),"history":relay.history,"guards":guards,"benefits":GameManager.starting_benefits,"contributions":GameManager.contribution,"settlements":MetaProgress.starting_settlements.size(),"vouchers":MetaProgress.starting_vouchers,"audio_gate_visible":hud.audio_prompt_button.visible,"provenance":provenance}
	payload["journal"]=hud.battle_journal.entries
	payload["landmarks"]={"composition":arena.get_node("EncounterLandmarks").composition,"indices":arena.get_node("EncounterLandmarks").atlas_indices}
	payload["identity"]={"captain":arena.get_node("BattleIdentity").captain_markers,"allies":arena.get_node("BattleIdentity").ally_markers,"attack_origins":arena.get_node("BattleIdentity").attack_origins}
	if label=="victory":payload["summary_text"]=arena.get_node("StageVictoryScreen").summary_label.text
	_set_frozen(true)
	JavaScriptBridge.eval("window.__cvContentR4Sample="+JSON.stringify(payload),true)
	review_index+=1

func _finish(outcome: String) -> void:
	finished=true
	if outcome!="win":
		JavaScriptBridge.eval("window.__cvContentR4Failure="+JSON.stringify({"outcome":outcome,"time":GameManager.elapsed_time}),true)
		return
	arena.get_node("StageVictoryScreen")._update_summary_count(1.0)
	_capture("victory","actual continuous formal victory and real individual support attribution")

func _milestone_fixture() -> void:
	process_mode=PROCESS_MODE_ALWAYS
	get_tree().current_scene=null
	AudioManager.set_muted(true)
	if bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('max_ui')==='1'",true)): PlayerSettings.set_ui_scale_index(2)
	assert(MetaProgress.starting_settlements.is_empty() and MetaProgress.starting_vouchers==1)
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	for frame in range(3): await get_tree().process_frame
	var menu: Node=get_tree().current_scene
	menu._open_build_preparation()
	var prep: Node=menu.get_node("BuildPreparation")
	prep.tab=0;prep.index=1;prep._refresh();prep.controls.action.pressed.emit()
	prep.tab=3;prep.index=1;prep._refresh();prep.controls.action.pressed.emit();prep.controls.action.pressed.emit()
	prep.controls.close.pressed.emit()
	for number in range(4):
		if number==0: menu.start_button.pressed.emit()
		else: arena.get_node("GameOverScreen").restart_button.pressed.emit()
		for frame in range(5): await get_tree().process_frame
		arena=GameManager.arena
		if number==0: await _official_gate()
		GameManager.player.invulnerability_timer=0
		GameManager.player.take_damage(99999,GameManager.player.global_position+Vector2.RIGHT)
		for frame in range(90): await get_tree().process_frame
		assert(GameManager.is_game_over and MetaProgress.starting_settlements.size()==number+1)
		milestone_progress.append({"settlements":MetaProgress.starting_settlements.size(),"text":arena.get_node("GameOverScreen").progress_label.text,"vouchers":MetaProgress.starting_vouchers})
	var screen: Node=arena.get_node("GameOverScreen")
	screen._update_summary_count(1.0)
	JavaScriptBridge.eval("window.__cvContentR4ProgressHistory="+JSON.stringify(milestone_progress),true)
	JavaScriptBridge.eval("window.__cvContentR4Milestone="+JSON.stringify({"label":"fourth-defeat","version":ProjectSettings.get_setting("application/config/version"),"settlements":MetaProgress.starting_settlements.size(),"vouchers":MetaProgress.starting_vouchers,"elapsed":GameManager.elapsed_time,"kills":GameManager.kills,"captain_dead":bool(screen.displayed_summary.get("captain_dead",false)),"restart_text":screen.restart_button.text,"ui_scale_index":PlayerSettings.ui_scale_index,"footer_buttons":{"copy":_rect(screen.copy_seed_button.get_global_rect()),"restart":_rect(screen.restart_button.get_global_rect()),"menu":_rect(screen.main_menu_button.get_global_rect())},"menu_rect":_rect(screen.restart_button.get_global_rect()),"provenance":"controlled real Hero.take_damage lethal fixture; four formal early defeat callbacks; normal restart UI signals; not a natural battle result; QA max UI setting via real PlayerSettings setter"}),true)
	while not bool(JavaScriptBridge.eval("window.__cvR19Controls?.build_preparation?.flags.visible===true",true)):await get_tree().process_frame

func _rect(value: Rect2) -> Array:
	return [value.position.x,value.position.y,value.size.x,value.size.y]
