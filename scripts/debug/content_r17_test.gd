extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var catalog: GDScript = load("res://scripts/services/starting_build_catalog.gd")
	_check(catalog.seal_seconds("", "front", "wedge") == 6 and catalog.seal_seconds("", "front", "ring") == 9, "seal times are the real 6 s hold over the seal rate (fast 6 s, slow 9 s)")
	_check(catalog.seal_seconds("spec_escort", "front", "ring") == 7, "the escort ring seal shows the real 7 s (6 / 0.85, rounded)")
	var pressure_script: GDScript = load("res://scripts/services/encounter_pressure.gd")
	_check(pressure_script.choice_text("front", "") == "楔形快封6秒整補8／圓陣慢封9秒整補16・反擊10秒", "the warning compares both seal times")
	var pressure_src := FileAccess.get_file_as_string("res://scripts/services/encounter_pressure.gd")
	_check(pressure_src.contains("tag_layer.draw_rect(tag, Color(\"08121f\", 0.92), true)") and pressure_src.contains("const PACE_TAG_Z := 97") and pressure_src.contains("tag_layer.z_as_relative = false"), "fast/slow ground tags have a solid backing and distinct colours")
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(relay_src.contains("alternative_hold+=maxf(0.0, delta)"), "the escort result counts real seconds, matching the top bar's 7 s, not seal progress")
	var hud_src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(hud_src.contains("minf(560.0 if view_width < 1200.0 else 680.0,"), "wide screens fit the seal choice notice on one line")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.47.0-content-r18", "project version is 0.47.0-content-r18")
	if failures.is_empty():
		print("R17_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R17_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
