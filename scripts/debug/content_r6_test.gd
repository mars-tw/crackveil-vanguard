extends SceneTree

# Loaded after autoloads exist; preloading would compile them too early.
var NUMBER: GDScript
var PREVIEW: GDScript
var TUNING: GDScript
var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	await process_frame
	NUMBER=load("res://scripts/vfx/damage_number.gd")
	PREVIEW=load("res://scripts/services/upgrade_preview.gd")
	TUNING=load("res://scripts/services/mobile_tuning.gd")
	_test_formation_wording()
	_test_seal_feedback()
	_test_damage_number_prefix()
	await _test_readable_budget()
	_test_upgrade_target()
	if failures.is_empty():
		print("R6_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R6_REGRESSION status=FAIL checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func gm() -> Node:
	return root.get_node("GameManager")

func ef() -> Node:
	return root.get_node("EntityFactory")

func _check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:failures.append(label)

func _relay(kind: String,node: String) -> Node2D:
	gm().active_starting_node=node
	var relay: Node2D=load("res://scripts/services/formation_relay.gd").new()
	relay.pressure=load("res://scripts/services/encounter_pressure.gd").new()
	relay.pressure.kind=kind
	return relay

func _free(relay: Node2D) -> void:
	relay.pressure.free()
	relay.free()

func _test_formation_wording() -> void:
	# Accepted formations come from the same accepts() table that gates sealing.
	var escort:=_relay("front","spec_escort")
	_check(escort.accepted_formations()==["wedge","ring"],"escort front accepts wedge and ring")
	_check(escort.accepted_text()=="可用：楔形／圓陣","escort front shows both usable formations")
	_free(escort)
	var assault:=_relay("pincer","")
	_check(assault.accepted_text()=="需圓陣","single accepted formation names the requirement")
	var wrong: String=assault.consequence_text({"correct":false})
	_check(wrong.contains("需圓陣") and wrong.contains("才能封合"),"wrong verdict names the needed formation")
	_check(wrong.contains("按 Q") or wrong.contains("點陣形鈕"),"wrong verdict names the switch input")
	_check(assault.consequence_text({"correct":true}).contains("封合"),"correct verdict states the seal consequence")
	_free(assault)
	var pressure: Node2D=load("res://scripts/services/encounter_pressure.gd").new()
	pressure.started=true
	for phase in ["warning","active","recovery"]:
		pressure.phase=phase
		_check(not pressure.status_text().contains("反擊窗口"),"pre-seal status never claims a counter window (%s)" % phase)
	pressure.phase="recovery"
	_check(pressure.status_text().ends_with("攻勢間隙"),"recovery phase reads as an attack gap")
	pressure.last_result={"kind":"pincer","correct":false}
	pressure.result_age=0.5
	pressure.configure(Vector2.ZERO,1)
	_check(pressure.last_result.is_empty() and pressure.result_age>=2.4,"next seal starts without the previous verdict")
	pressure.free()
	gm().active_starting_node=""

func _test_seal_feedback() -> void:
	var relay:=_relay("front","")
	_check(relay.seal_text(2)=="封合 2/3・整補 +8・反擊 +20% 5 秒","seal text reports the existing +8 heal and 5 s counter")
	gm().active_starting_node="spec_prepare"
	_check(relay.seal_text(1)=="封合 1/3・放棄治療・反擊 +20% 10 秒","prepare seal text reports forgone heal and 10 s counter")
	gm().active_starting_node=""
	_check(relay.seal_flash_time>=relay.SEAL_FLASH_SECONDS,"seal flash idle until a real seal")
	_free(relay)

func _test_damage_number_prefix() -> void:
	var number: Node=NUMBER.new()
	root.add_child(number)
	number.pool_on_acquire()
	number.pool_reset({"value":17,"position":Vector2.ZERO,"color":Color.WHITE,"font_size":22,"prefix":"爆擊 "})
	_check(number.value_label.text=="爆擊 17","critical prefix shown on numeric value")
	number.merge_value(16.0,Vector2.ZERO,Color.WHITE)
	_check(number.value_label.text=="爆擊 33","critical merge keeps prefix and sums real damage")
	number.pool_on_release()
	number.pool_on_acquire()
	number.pool_reset({"value":5,"position":Vector2.ZERO,"color":Color.WHITE,"font_size":15})
	_check(number.value_label.text=="5","released number drops the old prefix")
	number.free()

func _test_readable_budget() -> void:
	_check(TUNING.readable_damage_number_cap(Vector2(1366,768),false)==8,"desktop readable budget is 8")
	_check(TUNING.readable_damage_number_cap(Vector2(390,844),true)==6,"mobile readable budget is 6")
	var arena:=Node2D.new()
	root.add_child(arena)
	ef().initialize_for_arena(arena)
	await process_frame
	for i in range(30):
		ef().spawn_damage_number(10.0+i,Vector2(i*400.0,0),Color.WHITE,13)
	var minor:=0
	for n in ef().active_damage_numbers:
		if is_instance_valid(n) and bool(n.get("is_active")):minor+=1
	_check(minor<=TUNING.readable_damage_number_cap(Vector2(1366,768),false),"minor numbers respect the readable budget (%d)" % minor)
	var priority: Node=ef().spawn_damage_number(14.0,Vector2(99999,0),Color(1,0.28,0.22),0,"",true)
	_check(priority!=null,"squad damage bypasses the readable budget")
	_check(ef().readable_number_skips>0,"skipped minor numbers are counted")
	arena.queue_free()
	await process_frame

func _test_upgrade_target() -> void:
	_check(PREVIEW.target_text({"id":"move_speed"})=="適用：隊長","captain stat cards name the captain")
	_check(PREVIEW.target_text({"id":"upgrade_hero_weapon","hero_id":"orbit_guard"}).begins_with("適用：") and not PREVIEW.target_text({"id":"upgrade_hero_weapon","hero_id":"orbit_guard"}).contains("orbit_guard"),"weapon cards name the hero by display name")
	_check(PREVIEW.synergy_text({"id":"move_speed"})=="","no invented link for captain stats")
