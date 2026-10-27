extends SceneTree

var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	await process_frame
	_test_defeat_advice()
	_test_partner_gate()
	_test_answer_tables()
	_test_frame_ornament()
	_test_release_hygiene()
	_test_guard_name()
	if failures.is_empty():
		print("R7_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R7_REGRESSION status=FAIL checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:failures.append(label)

func _test_defeat_advice() -> void:
	# Advice reads only the recorded seal state; empty state gives no line.
	var screen: CanvasLayer=load("res://scripts/ui/r4_result_screen.gd").new()
	_check(screen._defeat_advice({})=="","no seal state, no invented advice")
	var wrong: String=screen._defeat_advice({"step":1,"completed":false,"wrong":2,"required":"ring","formation":"wedge"})
	_check(wrong.contains("第 2 道") and wrong.contains("需圓陣") and wrong.contains("當時楔形") and wrong.contains("2 次"),"wrong-formation defeat names seal, need, held and count")
	var unsealed: String=screen._defeat_advice({"step":0,"completed":false,"wrong":0,"required":"wedge","formation":"wedge"})
	_check(unsealed.contains("第 1 道") and unsealed.contains("0/3") and unsealed.contains("兩名隊友"),"no-backlash defeat points at standing in the seal")
	_check(screen._defeat_advice({"step":3,"completed":true}).contains("守門者"),"all seals closed points at the gatekeeper")
	screen.free()

func _test_partner_gate() -> void:
	var preview: GDScript=load("res://scripts/services/upgrade_preview.gd")
	var stub:=Node.new()
	_check(not preview._partner_obtainable(stub,""),"empty partner is never offered")
	_check(not preview._partner_obtainable(stub,"rift_shepherd"),"a squad without roster data cannot promise a partner")
	stub.free()

func _test_answer_tables() -> void:
	var pressure: Node2D=load("res://scripts/services/encounter_pressure.gd").new()
	for id in pressure.FORMATION_ORDER:
		_check(pressure.FORMATION_NAMES.has(id) and pressure.FORMATION_COLORS.has(id),"danger badge has name and colour for "+id)
	_check(pressure.COUNTERS.front=="wedge" and pressure.COUNTERS.pincer=="ring" and pressure.COUNTERS.artillery=="scatter","badge uses the same counter table as the seal")
	pressure.free()

func _test_frame_ornament() -> void:
	# The frame overlay must never take input or duplicate on re-attach.
	var host:=Control.new()
	root.add_child(host)
	var script: GDScript=load("res://scripts/ui/rift_frame_ornament.gd")
	var first: Control=script.attach(host)
	var again: Control=script.attach(host)
	_check(first==again and host.get_child_count()==1,"ornament attaches once")
	_check(first.mouse_filter==Control.MOUSE_FILTER_IGNORE and first.focus_mode==Control.FOCUS_NONE,"ornament ignores input and focus")
	host.free()

func _scan(dir: String, hits: Array[String], needles: Array) -> void:
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".gd"):continue
		var text:=FileAccess.get_file_as_string(dir+"/"+file)
		for needle in needles:
			if text.contains(needle):hits.append(dir+"/"+file+" -> "+str(needle))
	for sub in DirAccess.get_directories_at(dir):
		if dir=="res://scripts" and sub in ["debug","qa"]:continue
		_scan(dir+"/"+sub,hits,needles)

func _test_release_hygiene() -> void:
	# Shipped scripts carry no QA switch names; phone presets drop scripts/qa.
	var hits: Array[String]=[]
	_scan("res://scripts",hits,["cv_r19_test","cv_r22_test","cv_r32_test","__cvR","CV_QA_PROFILE","_probe.gd\")"])
	_check(hits.is_empty(),"QA strings in shipped scripts: "+str(hits))
	var presets:=FileAccess.get_file_as_string("res://export_presets.cfg")
	var platform:=""
	var phone_presets:=0
	for line in presets.split("
"):
		if line.begins_with("platform="):platform=line.trim_prefix("platform=").replace('"',"")
		if line.begins_with("exclude_filter=") and platform in ["iOS","Android"]:
			phone_presets+=1
			_check(line.contains("scripts/qa/**") and line.contains("scripts/debug/**") and line.contains("release/**"),platform+" preset excludes QA, debug and release receipts")
	_check(phone_presets==3,"all three phone presets checked")

func _test_guard_name() -> void:
	var readout: Node=load("res://scripts/ui/combat_readout.gd").new()
	var nameless:=Node.new()
	_check(readout._guard_name(nameless)!="","nameless guard still gets an objective name")
	nameless.free()
	readout.free()
