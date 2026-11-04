extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	# The 第N道 marker keeps off the right HUD column and every HUD button.
	var relay: GDScript = load("res://scripts/services/formation_relay.gd")
	var column: Rect2 = relay.minimap_column(Rect2(764, 78, 68, 68))
	_check(column.position.x <= 642.0 and column.end.x == 832.0 and column.end.y >= 170.0, "the minimap area includes the stage name drawn under it and to its left")
	var hud_rects: Array[Rect2] = [column, Rect2(732, 210, 100, 44)]
	_check(relay.covers_hud(Rect2(560, 220, 214, 30), hud_rects) and relay.covers_hud(Rect2(560, 150, 214, 30), hud_rects) and not relay.covers_hud(Rect2(300, 220, 214, 30), hud_rects), "a marker over the stage name or the 戰報 button is rejected")
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(relay_src.contains("if covers_hud(candidate_rect, hud_rects):clear=false") and relay_src.contains("hud_root.find_children(\"*\", \"Button\", true, false)") and relay_src.contains("const HUD_PANELS := [\"ScorePanel\", \"ToastPanel\", \"HUDPanel\"]"), "marker spots are tested against the HUD buttons and panels")
	# A marker that had to sit away from its seal gets a line to it.
	_check(relay.link_points(Rect2(400, 300, 214, 30), Vector2(500, 350)).is_empty(), "a marker beside its seal draws no line")
	var link: PackedVector2Array = relay.link_points(Rect2(100, 300, 214, 30), Vector2(600, 330))
	_check(link.size() == 2 and link[0] == Vector2(314, 330) and link[1].x < 600.0 and link[1].x > 314.0, "a far marker draws a line from its nearest edge toward the seal")
	_check(relay_src.contains("\t_draw_marker_link()\n\t_draw_synergy()\n\tvar color") and relay_src.contains("var link_target: Vector2 = pointer_layout if pointer_layout.x >= 0.0 and pointer_needed() else point\n\tvar link := link_points(Rect2(x,y,width,30), link_target)"), "the line is drawn with the seal and leads to the edge pointer while one stands in for the seal")
	# Phone landscape: an urgent notice goes into the top bar instead of a second banner.
	var hud_script: GDScript = load("res://scripts/ui/hud.gd")
	_check(hud_script.merges_urgent_notice(Vector2(844, 390), true, true) and not hud_script.merges_urgent_notice(Vector2(390, 844), true, true) and not hud_script.merges_urgent_notice(Vector2(1366, 600), false, true) and not hud_script.merges_urgent_notice(Vector2(844, 390), true, false), "only a phone held sideways merges, and only urgent notices")
	var hud_src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(hud_src.contains("tactical_hint.text = \"%s\\n%s\" % [toast_current_text.strip_edges(), tactical_hint.text.get_slice(\"\\n\", 1)]"), "the merged notice takes the bar's first line and keeps the stage instruction on the second, so the banner hides as a duplicate")
	_check(hud_src.contains("has_urgent_toast()) and not notices_duplicate(tactical_hint.text, toast_current_text):") and hud_script.notices_duplicate("楔形｜封隙 1/3\n錯陣反噬：進度歸零", "錯陣反噬：進度歸零"), "a notice the bar already shows is not written twice")
	_check(hud_src.contains("toast_panel.visible = not get_tree().paused and not formation_picker.visible and not into_bar\n\tif into_bar:\n\t\t_update_tactical_hint()"), "an urgent notice bound for the phone bar never flashes the banner for a frame")
	_check(hud_src.contains("if toast_showing and (toast_panel.visible or merged_notice) and (urgent or not bond_active):"), "a merged notice still counts down and leaves the bar")
	# Stray numbers: off-screen enemies and the top HUD band.
	var number: GDScript = load("res://scripts/vfx/damage_number.gd")
	var view := Vector2(844, 390)
	_check(number.on_screen(Vector2(400, 4), view) and not number.on_screen(Vector2(400, -6), view) and not number.on_screen(Vector2(850, 200), view), "a number whose enemy is off screen is hidden, not pulled in")
	var zones: Dictionary = load("res://scripts/ui/battle_layout.gd").regions(view, true)
	_check(number.in_top_band(Rect2(790, 2, 40, 20), zones) and not number.in_top_band(Rect2(400, 200, 40, 20), zones), "small numbers stay out of the top HUD band above the pause button")
	var number_src := FileAccess.get_file_as_string("res://scripts/vfx/damage_number.gd")
	_check(number_src.contains("if not on_screen(screen, get_viewport_rect().size):") and number_src.contains("if font_size < PLATE_YIELD_FONT_SIZE and in_top_band(text_rect, zones):"), "both number rules run every frame")
	# Verdict lines keep clear of the bottom buttons on a 3x phone too.
	var low: Vector2 = relay.clamp_screen_point(Vector2(500, 1150), Vector2(2532, 1170), 840.0, 3.0)
	_check(is_equal_approx(low.y, 1170.0 - relay.VERDICT_BOTTOM_BAND * 3.0) and relay.clamp_screen_point(Vector2(500, 700), Vector2(1280, 720), 280.0) == relay.clamp_screen_point(Vector2(500, 700), Vector2(1280, 720), 280.0, 1.0), "the verdict bands scale with the phone's pixel ratio and stay the same on desktop")
	_check(relay_src.contains("clamp_screen_point(xf * local_at, view, width * xf.x.length(), unit)"), "verdict lines are clamped in screen pixels with the zoomed width")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.72.0-content-r43", "project version is 0.72.0-content-r43")
	if failures.is_empty():
		print("R43_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R43_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
