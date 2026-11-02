extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var gm: GDScript = load("res://scripts/autoload/game_manager.gd")
	_check(gm.squad_catch_up(1000.0, 400.0) == 1.0, "no catch-up before the run has meaningful damage")
	_check(gm.squad_catch_up(5000.0, 5000.0) == 1.0, "no catch-up while the captain share is at or below the target")
	_check(absf(gm.squad_catch_up(7000.0, 3000.0) - pow(0.7 / 0.55, 2.0)) < 0.001, "members hit harder in proportion when the captain share is above the target")
	_check(gm.squad_catch_up(9900.0, 100.0) == gm.SQUAD_CATCH_UP_MAX, "the catch-up is capped")
	var src := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")
	_check(src.contains("multiplier *= SQUAD_SHARE_MEMBER * squad_catch_up(captain_damage_total, member_damage_total)") and src.contains("\tcontribution.clear()\n\tcaptain_damage_total = 0.0\n\tmember_damage_total = 0.0"), "the catch-up applies to member hits and resets each run")
	var icon := Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/app_icon/app_store_1024.png"))
	_check(icon != null and icon.get_width() == 1024 and not icon.detect_alpha(), "an opaque 1024 App Store icon ships with the project")
	_check(FileAccess.get_file_as_string("res://export_presets.cfg").contains("icons/app_store_1024x1024=\"res://assets/art/app_icon/app_store_1024.png\""), "the iOS preset uses the 1024 icon")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.61.0-content-r32", "project version is 0.60.0-content-r31")
	if failures.is_empty():
		print("R26_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R26_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
