extends "res://scripts/debug/content_r2_run.gd"

# Explicit debug encounter checkpoints. Production excludes this entire tree.
# Checkpoints set start time/placement only; damage, animations, hazards, hold,
# rewards and contribution values below are produced by the real running game.
var scenario := "front"
var frozen := false
var sample_index := 0
var frozen_kills := 0
var factory_mode := Node.PROCESS_MODE_INHERIT
var guard_ref: WeakRef
var start_at := 0.0

func _ready() -> void:
	if not OS.has_feature("web") or not OS.is_debug_build():
		get_tree().quit(1)
		return
	scenario = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('scenario') || 'front'",true))
	stage = {"front":"moon","pincer":"garden","artillery":"ember"}.get(scenario,"moon")
	if scenario=="summary":roster="harmony"
	super._ready()
	factory_mode = EntityFactory.process_mode
	if scenario in ["front","pincer","artillery","decision"]:
		GameManager.elapsed_time=12.0
		start_at=12.0
		if scenario=="decision":
			GameManager.player.global_position=GameManager.tactical_director.relay.anchor
			GameManager.squad_manager.set_formation("ring",true)
	elif scenario=="guard":
		GameManager.elapsed_time=90.0
		start_at=90.0
		var relay: Node=GameManager.tactical_director.relay
		relay.completed=true
		relay.reward_saved=true
		arena.get_node("EnemySpawner")._spawn_boss()
	elif scenario in ["summary","combo"]:
		Engine.time_scale=4.0
	GameManager.emit_stats()

func _process(delta: float) -> void:
	if not is_instance_valid(arena):return
	if frozen:
		assert(GameManager.kills==frozen_kills,"frozen capture advanced")
		if bool(JavaScriptBridge.eval("window.__cvContentR2Next === true",true)):
			JavaScriptBridge.eval("window.__cvContentR2Next=false;window.__cvContentR2Sample=null",true)
			sample_index+=1
			frozen=false
			arena.process_mode=PROCESS_MODE_INHERIT
			EntityFactory.process_mode=factory_mode
			GameManager.set_process(true)
		return
	if scenario=="decision" and sample_index==0:
		GameManager.set_touch_move_vector(Vector2.ZERO)
	else:
		super._process(delta)
	if finished:return
	var relay: Node=GameManager.tactical_director.relay
	var pressure: Node=relay.pressure
	if scenario in ["front","pincer","artillery"]:
		if sample_index==0 and pressure.phase=="warning" and pressure.clock>=0.65:
			_freeze("warning")
		elif sample_index==1 and pressure.phase=="active" and pressure.clock>=2.10:
			_freeze("active")
		elif sample_index==2 and pressure.phase=="recovery" and relay.hold>=1.2:
			_freeze("handled")
	elif scenario=="decision":
		if sample_index==0 and relay.wrong_penalties>0 and GameManager.elapsed_time>=12.4:
			_freeze("wrong_cost")
		elif sample_index==1 and relay.step==1:
			_freeze("counter_reward")
	elif scenario=="guard":
		if guard_ref==null and GameManager.tactical_director.boss_guard_spawned:
			var refs: Array=GameManager.tactical_director.guard_refs
			if not refs.is_empty():guard_ref=refs[-1].ref
		var guard: Object=guard_ref.get_ref() if guard_ref!=null else null
		if is_instance_valid(guard):
			if sample_index==0 and guard.current_animation_name==&"attack" and guard.tactical_recoveries==0:
				_freeze("guard_anticipation")
			elif sample_index==1 and guard.tactical_recoveries>=2:
				_freeze("guard_two_cycles")
	elif scenario=="combo" and GameManager.combo_count>=100 and GameManager.combo_fire_rate_timer<=0:
		var hud: Node=arena.get_node("HUD")
		var readout: Node=hud.root.get_node("CombatReadout")
		readout._refresh()
		if readout.headline.text.contains("連斬"):
			hud._open_formation_picker()
			_freeze("combo_condition")

func _finish(outcome: String) -> void:
	if outcome=="win" and scenario=="summary":
		Engine.time_scale=1
		arena.get_node("StageVictoryScreen")._update_summary_count(1.0)
		_freeze("summary")
	else:
		JavaScriptBridge.eval("window.__cvContentR2Failure="+JSON.stringify({"outcome":outcome,"time":GameManager.elapsed_time}),true)
		finished=true

func _freeze(label: String) -> void:
	frozen=true
	frozen_kills=GameManager.kills
	GameManager.emit_stats()
	var relay: Node=GameManager.tactical_director.relay
	relay._update_label()
	var hud: Node=arena.get_node("HUD")
	hud._update_tactical_hint()
	hud.root.get_node("CombatReadout")._refresh()
	var guards: Array=[]
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_active and enemy.tactical_min_cycles>0:
			guards.append({"id":enemy.type_id,"hp":enemy.hp,"impacts":enemy.attack_impact_count,"recoveries":enemy.tactical_recoveries,"animation":str(enemy.current_animation_name),"phase_two":enemy.boss_phase_two_triggered,"position":[enemy.global_position.x,enemy.global_position.y]})
	var payload: Dictionary={"scenario":scenario,"sample":sample_index,"label":label,"time":GameManager.elapsed_time,"checkpoint_start":start_at,"seed":GameManager.current_run_seed,"stage":stage,"version":ProjectSettings.get_setting("application/config/version"),"kills":GameManager.kills,"hp":GameManager.player.current_hp,"max_hp":GameManager.player.max_hp,"combo":GameManager.combo_count,"combo_status":GameManager.combo_status_text(),"relay":relay.probe(),"history":relay.history,"guards":guards,"contributions":GameManager.contribution,"bond":GameManager.bond_benefits,"pressure_events":relay.pressure.events}
	arena.process_mode=PROCESS_MODE_DISABLED
	EntityFactory.process_mode=PROCESS_MODE_DISABLED
	GameManager.set_process(false)
	JavaScriptBridge.eval("window.__cvContentR2Sample="+JSON.stringify(payload),true)
