extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	# The open-bloom tip names the real reason the bud was missed.
	var bloom: GDScript = load("res://scripts/vfx/moon_bloom.gd")
	_check(bloom.fail_reason(false, false) == "walk" and bloom.fail_reason(true, false) == "spin" and bloom.fail_reason(true, true) == "energy" and bloom.fail_reason(false, true) == "energy", "low energy first, then whether the captain ever reached the bud")
	_check(bloom.status_text(1, false, true, false, 4, "walk") == "月華盛放・長出 4 隻靈花・下次先走到花蕾旁" and bloom.status_text(1, false, true, false, 4, "spin") == "月華盛放・長出 4 隻靈花・下次在花蕾旁按住旋斬" and bloom.status_text(1, false, true, false, 4, "energy") == "月華盛放・長出 4 隻靈花・下次留能量旋斬", "each failure reason has its own tip")
	_check(bloom.status_text(1, false, true, false, 4) == "月華盛放・長出 4 隻靈花・下次留能量旋斬" and bloom.status_text(1, false, true, true, 0, "walk") == "花蕾斬開・群怪不回血", "a cut bud carries no tip; the old call form still reads")
	_check(not bloom.low_energy(null), "no captain, no energy verdict")
	var bsrc := FileAccess.get_file_as_string("res://scripts/vfx/moon_bloom.gd")
	_check(bsrc.contains("reason = fail_reason(ever_near, low_energy(GameManager.player))") and bsrc.contains("\t\tif captain_near():\n\t\t\tever_near = true") and bsrc.contains("return status_text(seconds_left(), captain_near(), done, solved, sprouted, reason)"), "the bloom records whether the captain came near and why it failed, and the top bar uses it")
	_check(bsrc.contains("\tif not solved:\n\t\t_draw_aftermath()") and bsrc.contains("sprouts.append(sprout)") and bsrc.contains("hero.get(\"is_alive\") != false") and bsrc.contains("if done_age < ROOT_SECONDS:"), "an open bloom draws vines under the slowed heroes and marks its new spirit flowers")
	# Artillery: the answer badge never vanishes because the first target is near the top bar.
	var pressure_script: GDScript = load("res://scripts/services/encounter_pressure.gd")
	var pressure: Node2D = pressure_script.new()
	_check(pressure.answer_spot([Vector2(100, 200), Vector2(400, 500)]) == Vector2(100, 104), "outside a viewport the first target's spot above is used")
	pressure.free()
	var psrc := FileAccess.get_file_as_string("res://scripts/services/encounter_pressure.gd")
	_check(psrc.contains("_draw_answer(answer_spot(targets))") and psrc.contains("for dy in [-96.0, 120.0]:") and psrc.contains("if not _answer_under_hud(center) and not _under_equipment_bar(tags_area(center, 2, false)):"), "the artillery answer tries every target, above then below, clear of the HUD and the equipment bar")
	# A seal under the left/bottom controls counts as hidden.
	var relay: GDScript = load("res://scripts/services/formation_relay.gd")
	var covers: Array[Rect2] = [Rect2(20, 430, 220, 40)]
	_check(relay.covered_by(Vector2(200, 450), covers) and relay.covered_by(Vector2(250, 450), covers) and not relay.covered_by(Vector2(400, 450), covers), "a seal under a control (or at its edge) is covered; one beside it is not")
	var rsrc := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(rsrc.contains("(view.grow(-30.0).has_point(anchor) and not seal_under_controls())") and rsrc.contains("x = clampf(pointer_layout.x + 56.0, 12.0, view.x - width - 90)") and rsrc.contains("\"FormationButton\", \"SummonButton\", \"CaptainEnergyReadout\""), "a covered seal gets the edge pointer and the 第N道 marker starts beside it")
	# Large event words carry a thick outline.
	_check(FileAccess.get_file_as_string("res://scripts/vfx/damage_number.gd").contains("\"outline_size\", 9 if font_size >= 32 else (3 if font_size > 20 else 2)"), "擊破・name has a thick outline")
	var font: FontFile = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var missing := ""
	for s in [bloom.status_text(1, false, true, false, 4, "walk"), bloom.status_text(1, false, true, false, 4, "spin")]:
		for i in range(str(s).length()):
			var c: int = str(s).unicode_at(i)
			if c > 0x7f and not font.has_char(c):
				missing += char(c)
	_check(missing == "", "every new string is covered by the CJK subset font (missing: %s)" % missing)
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.70.0-content-r41", "project version is 0.70.0-content-r41")
	if failures.is_empty():
		print("R41_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R41_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
