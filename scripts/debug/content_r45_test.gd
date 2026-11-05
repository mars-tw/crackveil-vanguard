extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	# A bud is planted between the top bar and the buttons on a short phone.
	var bloom: GDScript = load("res://scripts/vfx/moon_bloom.gd")
	var phone: Rect2 = bloom.spawn_band(Vector2(844, 390))
	_check(phone.position.y >= 150.0 and phone.end.y <= 390.0 - 110.0 and phone.size.y > 0.0, "a phone bud stays below the top bar and above the buttons")
	_check(bloom.spawn_band(Vector2(1366, 600)) == Rect2(220, 200, 1366 - 240 - 220, 200), "the desktop band is unchanged (220/240, 200/200)")
	var bsrc := FileAccess.get_file_as_string("res://scripts/vfx/moon_bloom.gd")
	_check(bsrc.contains("var unit := view.x / maxf(1.0, layout.x)\n\tvar band := spawn_band(layout)") and bsrc.contains("clampf(screen.y, band.position.y * unit, band.end.y * unit)"), "the band is converted with the phone's pixel ratio")
	# The bud plate points at the bud when it had to move away.
	_check(bloom.bud_link(Rect2(-130, 118, 260, 28)).is_empty(), "a plate under its bud draws no line")
	var link: PackedVector2Array = bloom.bud_link(Rect2(300, -20, 260, 28))
	_check(link.size() == 2 and link[0] == Vector2(300, 0) and is_equal_approx(link[1].length(), 96.0 + 12.0), "a plate pushed aside draws a line from its nearest edge to the bud's ring")
	_check(bsrc.contains("var link := bud_link(placed)") and bsrc.contains("_plate(placed, LABEL, tone, 18)"), "the line is drawn before the plate, in the plate's color")
	# The bud's seconds dot leaves a corner held by an answer badge.
	var badge_on_corner: Array[Rect2] = [Rect2(50, -100, 60, 60)]
	_check(bloom.digit_spot(Transform2D.IDENTITY, []) == Vector2(96 * 0.72, -96 * 0.72) and bloom.digit_spot(Transform2D.IDENTITY, badge_on_corner) == Vector2(-96 * 0.72, -96 * 0.72), "the bud's seconds dot moves to a free corner of its ring")
	_check(bsrc.contains("digit_at = digit_spot(xf, taken)") and bsrc.contains("taken.append_array(Enemy.hud_areas())"), "the live dot checks badges, plates and the HUD")
	# Verdict lines slide off their own seal ring as well as the HUD.
	var relay: GDScript = load("res://scripts/services/formation_relay.gd")
	var ring := Rect2(300, 200, 72, 72)
	var blockers: Array[Rect2] = [Rect2(8, 80, 210, 56), relay.seal_ring_area(ring)]
	var verdict_box := Rect2(230, 180, 200, 54)
	var shift: float = relay.slide_off_hud(verdict_box, blockers, 844.0)
	var moved := Rect2(verdict_box.position + Vector2(shift, 0), verdict_box.size)
	_check(shift != 0.0 and not moved.intersects(ring) and not moved.intersects(blockers[0]), "a verdict pushed onto its seal ring moves off the ring and the 連斬 box")
	var ring_only: Array[Rect2] = [relay.seal_ring_area(Rect2(300, 200, 72, 72))]
	_check(relay.slide_off_hud(Rect2(236, 144, 200, 54), ring_only, 844.0) == 0.0, "a verdict resting just above its seal stays put")
	var rsrc := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(rsrc.contains("blockers.append(seal_ring_area(xf * Rect2(anchor - Vector2.ONE * CAPTAIN_RADIUS, Vector2.ONE * CAPTAIN_RADIUS * 2.0)))") and rsrc.contains("slide_off_hud(box, blockers, get_viewport().get_visible_rect().size.x)"), "the live verdict checks the HUD and its own seal ring")
	# 第N道 keeps its place (R12); a boss or elite plate it covers moves at once.
	var esrc := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	_check(rsrc.contains("Enemy.reserve_label_area(marker_label.get_global_rect(), marker_label)
	# R45: a boss or elite plate under the marker steps aside this frame.") and rsrc.contains("enemy.reseat_label_off(marker_area)") and not rsrc.contains("elite_plate_rects"), "the marker reserves its spot first, then plates under it are re-placed")
	_check(esrc.contains("func reseat_label_off(area: Rect2) -> void:") and esrc.contains("	_place_special_label()

func _place_special_label() -> void:"), "a covered plate drops its old slot and is placed again against the marker")
	_check(rsrc.contains("for avoid_members in [true, false]:") and rsrc.contains("			if avoid_members:
				for member in GameManager.squad_manager.get_members():"), "a crowded marker tries spots over members before falling back onto answer badges")
	# The tide sigil slides along its crest off an answer badge.
	var tide: GDScript = load("res://scripts/vfx/tide_sigil.gd")
	var badge_area: Array[Rect2] = [Rect2(560, 140, 170, 120)]
	var spots: Array[Vector2] = [Vector2(620, 220), Vector2(620, 330), Vector2(620, 110)]
	var spot: Vector2 = tide.least_covered(spots, Transform2D.IDENTITY, badge_area)
	_check(spot == Vector2(620, 330) and not tide.sigil_area(spot).intersects(badge_area[0]), "a tide sigil on an answer badge slides along the crest")
	var partial: Array[Vector2] = [Vector2(620, 220), Vector2(620, 420)]
	_check(tide.least_covered(partial, Transform2D.IDENTITY, [Rect2(560, 140, 170, 120), Rect2(560, 400, 170, 10)]) == Vector2(620, 420), "with no clear spot the sigil takes the least covered one")
	_check(tide.least_covered([Vector2(200, 600)], Transform2D.IDENTITY, badge_area) == Vector2(200, 600), "a clear tide sigil stays on the crest")
	var tsrc := FileAccess.get_file_as_string("res://scripts/vfx/tide_sigil.gd")
	_check(tsrc.contains("center = least_covered(spots, xf, Enemy.active_label_areas())") and tsrc.contains("Enemy.reserve_label_area(xf * sigil_area(center), mark_layer)"), "the live sigil checks the label registry and reserves itself")
	# HUD boxes are opaque; digits keep clear of the corner diamond; the timer has a plate.
	var hud_src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(hud_src.contains("style.bg_color = Color(0.045, 0.055, 0.105, 1.0)") and hud_src.contains("mission_surface.bg_color = Color(0.02,0.035,0.06,1.0)") and FileAccess.get_file_as_string("res://scripts/ui/combat_readout.gd").contains("style.bg_color = Color(0.015, 0.035, 0.065, 1.0)"), "status, kill, 連斬 boxes and the top bar are fully opaque")
	var gm := root.get_node("/root/GameManager")
	var saved_running: bool = gm.game_running
	gm.game_running = true
	var hud: CanvasLayer = load("res://scripts/ui/hud.gd").new()
	root.add_child(hud)
	await process_frame
	await process_frame
	var score_panel := hud.root.find_child("ScorePanel", true, false) as Control
	var score_label := hud.root.find_child("ScoreLabel", true, false) as Control
	var time_label := hud.root.find_child("TimeLabel", true, false) as Label
	_check(score_panel.get_global_rect().end.x - score_label.get_global_rect().end.x >= 18.0, "the kill/gold digits end at least 18 px inside the frame")
	var plate := time_label.get_theme_stylebox("normal") as StyleBoxFlat
	_check(plate != null and is_equal_approx(plate.bg_color.a, 1.0), "the timer has an opaque plate")
	var live: Array[Rect2] = load("res://scripts/enemies/enemy.gd").hud_areas()
	_check(not time_label.is_visible_in_tree() or live.has(hud.root.get_canvas_transform() * time_label.get_global_rect()), "ground text steps around the timer plate")
	gm.game_running = saved_running
	hud.queue_free()
	await process_frame
	# A fork queued by a shooter that is freed before the deferred call runs.
	var factory := root.get_node("/root/EntityFactory")
	var gone := Node2D.new()
	gone.free()
	var fork = factory.spawn_fork_projectile(Vector2(-9000, -9000), Vector2.RIGHT, {"damage": 1.0}, gone)
	_check(fork == null or fork.source == null, "a fork whose shooter is gone spawns without a source instead of erroring")
	if fork != null and fork.has_method("pool_release"):
		fork.pool_release()
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.74.0-content-r45", "project version is 0.74.0-content-r45")
	if failures.is_empty():
		print("R45_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R45_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
