extends SceneTree

var checks:=0
var failures: Array[String]=[]
const VECTOR_DIR:="res://assets/ui/r8_vector/"
const ASSETS:=["panel_frame","card_frame","button_frame","seal_emblem","badge_wedge","badge_ring","badge_scatter","badge_wrong_ring"]

func _initialize() -> void:
	await process_frame
	_test_vector_sources()
	_test_frame_overlay()
	_test_badges_loaded()
	if failures.is_empty():
		print("R8_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R8_REGRESSION status=FAIL checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:failures.append(label)

func _test_vector_sources() -> void:
	# Pure original vectors: no embedded bitmap, text, external link or filter.
	for name in ASSETS:
		var source:=FileAccess.get_file_as_string(VECTOR_DIR+name+".svg")
		_check(source.begins_with("<svg") or source.contains("<svg"),name+" is an SVG document")
		var clean:=not (source.contains("<image") or source.contains("base64") or source.contains("<text") or source.contains("href=\"http") or source.contains("filter") or source.contains("<style"))
		_check(clean,name+" has no bitmap, text, external link, filter or CSS")
		_check(source.length()<=12288,name+" stays under 12 KB")

func _test_frame_overlay() -> void:
	var script: GDScript=load("res://scripts/ui/rift_frame_ornament.gd")
	for case in [[true,22.0,"panel",48],[false,14.0,"card",24],[false,12.0,"button",16]]:
		var host:=Control.new()
		host.size=Vector2(400,300)
		root.add_child(host)
		var frame: NinePatchRect=script.attach(host,case[0],Color.WHITE,case[1])
		_check(frame.kind==case[2] and frame.texture!=null and frame.patch_margin_left==case[3],"frame "+str(case[2])+" uses its vector nine-slice")
		_check(not frame.draw_center and frame.mouse_filter==Control.MOUSE_FILTER_IGNORE,"frame "+str(case[2])+" keeps centre clear and ignores input")
		host.free()

func _test_badges_loaded() -> void:
	var pressure: Node2D=load("res://scripts/services/encounter_pressure.gd").new()
	for id in ["wedge","ring","scatter"]:
		var texture: Texture2D=pressure.BADGES.get(id)
		_check(texture!=null and texture.get_width()>=64,"danger badge texture for "+id)
	_check(pressure.WRONG_RING!=null and pressure.BADGE_SIZE>=56.0,"wrong ring overlay and large badge size")
	pressure.free()
	var relay: Node2D=load("res://scripts/services/formation_relay.gd").new()
	_check(relay.SEAL_EMBLEM!=null and relay.BADGES.size()==3,"seal and pointer use vector emblems")
	relay.free()
