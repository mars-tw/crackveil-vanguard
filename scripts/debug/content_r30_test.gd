extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var snare_script: GDScript = load("res://scripts/vfx/vine_snare.gd")
	_check(snare_script.HAZARD.r > 0.8 and snare_script.HAZARD.g < 0.5, "the snare edge is a hazard red, not the squad's green")
	var src := FileAccess.get_file_as_string("res://scripts/vfx/vine_snare.gd")
	_check(src.contains("func _thorn_vine(") and src.contains("draw_string(FONT, plate.position") and src.contains("\"緩\"") and src.contains("mark_layer.z_index = 120"), "the snare draws thorny vines, a name plate and a slow mark over heroes inside")
	# every new string must render with the shipped CJK subset (no tofu boxes)
	var font: FontFile = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var strings := [str(snare_script.LABEL), "緩", "荊藤纏地 3 次・隊員被纏 5 下", "出招時腳下纏藤，散開站位", "隊員追擊最高 ×2.4・多打 2310 HP"]
	var missing := ""
	for s in strings:
		for i in range(str(s).length()):
			var c: int = str(s).unicode_at(i)
			if c > 0x7f and not font.has_char(c):
				missing += char(c)
	_check(missing == "", "every new on-screen string is covered by the CJK subset font (missing: %s)" % missing)
	var result: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	_check(result.vine_line({"vine_snares": 4, "vine_hits": 7}) == "荊藤纏地 4 次・隊員被纏 7 下" and result.vine_line({}) == "", "the result reports the garden snares and how often the squad was caught")
	var gm_src := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")
	_check(gm_src.contains("\"vine_snares\": vine_snares_cast, \"vine_hits\": vine_snare_hits,") and gm_src.contains("\tvine_snares_cast = 0\n\tvine_snare_hits = 0"), "snare counts are carried to the result and reset each run")
	_check(src.contains("plate_slot(FONT.get_string_size(LABEL") and src.contains("for y in [RADIUS + 10.0, -RADIUS - 36.0]:") and src.contains("Enemy.active_label_areas() + Enemy.elite_plate_rects()") and src.contains("snare.add_to_group(\"vine_snares\")"), "overlapping snares share one name plate that steps around rule text and elite plates")
	_check(snare_script.MAX_ACTIVE == 2 and src.contains("get_nodes_in_group(\"vine_snares\").size() >= MAX_ACTIVE"), "at most two snares are active at once")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.61.0-content-r32", "project version is 0.61.0-content-r32")
	if failures.is_empty():
		print("R30_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R30_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
