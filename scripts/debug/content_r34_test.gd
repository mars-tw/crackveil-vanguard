extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var pylons: GDScript = load("res://scripts/vfx/storm_pylons.gd")
	var src := FileAccess.get_file_as_string("res://scripts/vfx/storm_pylons.gd")
	# The rule plate and the verdict draw on the top layer, never under a halo.
	_check(src.contains("func _draw_marks() -> void:\n\tif not struck:") and src.contains("\t\tvar plate := plate_slot(") and src.contains("mark_layer.draw_string(FONT, plate.position + Vector2(8, 19), LABEL"), "the pylon plate draws on the top mark layer")
	_check(not src.contains("\tdraw_string(FONT, plate.position + Vector2(8, 19), LABEL"), "the plate is no longer drawn under the squad halos")
	# Success and failure have their own moment and say why.
	var half := Vector2(pylons.SPREAD, 0)
	_check(pylons.fail_reason_for(Vector2.ZERO, -half, half) == "隊員柱沒有人", "captain on the captain pylon: the member pylon was empty (R35 roles)")
	_check(pylons.fail_reason_for(Vector2.ZERO, Vector2.ZERO, half) == "隊長沒有踩隊長柱" and pylons.fail_reason_for(Vector2.ZERO, half, half) == "隊長沒有踩隊長柱", "captain off the captain pylon: the captain did not step on it (R35 roles)")
	_check(src.contains("(\"分流成功・%s接住雷柱\" % catcher if catcher != \"\" else \"分流成功・無人受傷\") if grounded else \"分流失敗・\" + fail_reason"), "the strike shows a split or failure verdict")
	_check(src.contains("last_split_time = GameManager.elapsed_time"), "a split is time-stamped for capture")
	# The bolt hurts: more damage and a slow.
	_check(pylons.STRIKE_DAMAGE >= 20.0 and pylons.SHOCK_SLOW_SECONDS >= 1.0 and src.contains("hero.apply_movement_slow(SHOCK_SLOW_SECONDS, SHOCK_SLOW)"), "a shocked hero takes 20 and is slowed for a second")
	# The pair is laid where both pylons stay on screen, below the top bar.
	_check(src.contains("static func onscreen_half(captain: Node2D) -> Vector2:") and pylons.SAFE_TOP >= 140.0, "the pylon axis keeps both pylons clear of the top bar")
	_check(pylons.onscreen_half(null) == pylons.lateral_half(null), "without a captain in a tree the lateral axis is kept")
	_check(FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd").contains("STORM_PYLONS.onscreen_half(GameManager.player))"), "storm elites use the on-screen axis")
	# Result: feats only when beaten once; key contributions need real amounts.
	var result: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	_check(result.victory_badges({"squad_total": 7, "squad_alive": 7, "seal_state": {"wrong": 0, "storm_pylons": 7, "storm_grounded": 0, "ember_rings": 5, "ember_clean": 0}}) == "戰績：零錯陣・全員生還", "a hazard never beaten is not listed as a feat")
	var rows := [{"name": "甲", "role": "member", "seal": 20.0, "healing": 8.0}, {"name": "乙", "role": "member", "taken": 120.0, "healing": 290.0}]
	_check(result.key_contribution_line(rows) == "關鍵貢獻：乙 回復減傷 290・甲 封隙 20 秒", "the best healer is named for support and a token amount is dropped")
	_check(FileAccess.get_file_as_string("res://scripts/ui/hud.gd").contains("\"storm_split_at\":"), "the HUD probe exposes the last split for capture")
	var font: FontFile = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var missing := ""
	for s in ["分流成功・無人受傷", "分流失敗・隊員柱沒有人", "分流失敗・隊長沒有踩隊長柱"]:
		for i in range(s.length()):
			var c: int = s.unicode_at(i)
			if c > 0x7f and not font.has_char(c):
				missing += char(c)
	_check(missing == "", "every new string is covered by the CJK subset font (missing: %s)" % missing)
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.65.0-content-r36", "project version is 0.65.0-content-r36")
	if failures.is_empty():
		print("R34_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R34_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
