extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	# The HUD reserves its buttons and panels as label areas every frame.
	var enemy_script: GDScript = load("res://scripts/enemies/enemy.gd")
	var owner := Node.new()
	enemy_script.hud_owner_id = owner.get_instance_id()
	enemy_script.clear_label_areas(owner)
	enemy_script.reserve_label_area(Rect2(700, 600, 120, 60), owner)
	var areas: Array[Rect2] = enemy_script.hud_areas()
	_check(areas.size() == 1 and areas[0] == Rect2(700, 600, 120, 60) and enemy_script.active_label_areas().has(Rect2(700, 600, 120, 60)), "HUD rects are readable on their own and also block ground plates")
	enemy_script.clear_label_areas(owner)
	_check(enemy_script.hud_areas().is_empty(), "the HUD clears its rects before reserving them again")
	owner.free()
	var hud_src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(hud_src.contains("\t_update_tactical_hint()\n\t_reserve_hud_areas()\n") and hud_src.contains("Enemy.hud_owner_id = root.get_instance_id()\n\tEnemy.clear_label_areas(root)") and hud_src.contains("root.find_children(\"*\", \"Button\", true, false)"), "every visible HUD button is reserved each frame")
	_check(hud_src.contains("const PLATE_BLOCKING_PANELS := [\"HUDPanel\", \"ScorePanel\", \"CombatReadout\", \"TacticalHint\", \"LoopMinimap\", \"ToastPanel\"]") and hud_src.contains("rect = FORMATION_RELAY_SCRIPT.minimap_column(rect)"), "the 連斬 box, top bar, kill box, minimap with the stage name and the banner (bond reveals) are reserved too")
	# A live HUD registers the 連斬 box itself, not its full-screen holder.
	var gm := root.get_node("/root/GameManager")
	var saved_running: bool = gm.game_running
	gm.game_running = true
	var hud: CanvasLayer = load("res://scripts/ui/hud.gd").new()
	root.add_child(hud)
	await process_frame
	await process_frame
	await process_frame
	var readout = hud.root.find_child("CombatReadout", true, false)
	readout.visible = true
	readout.panel.visible = true
	await process_frame
	await process_frame
	var live: Array[Rect2] = enemy_script.hud_areas()
	var view: Vector2 = root.get_visible_rect().size
	var combo_box: Rect2 = hud.root.get_canvas_transform() * (readout.panel as Control).get_global_rect()
	var oversized := false
	for rect in live:
		if rect.size.x * rect.size.y > view.x * view.y * 0.25:
			oversized = true
	_check(not live.is_empty() and not oversized, "no HUD rect covers a quarter of the screen")
	_check(readout.get_global_rect().size == Vector2.ZERO and combo_box.size.x > 100.0 and live.has(combo_box), "the 連斬 box is registered with its own rect")
	_check(FileAccess.get_file_as_string("res://scripts/ui/combat_readout.gd").contains("style.bg_color = Color(0.015, 0.035, 0.065, 0.94)"), "the 連斬 box is as opaque as the kill box")
	gm.game_running = saved_running
	hud.queue_free()
	await process_frame
	# Answer badges never sit half under a HUD button.
	var pressure: GDScript = load("res://scripts/services/encounter_pressure.gd")
	var button: Array[Rect2] = [Rect2(760, 260, 80, 40)]
	_check(pressure.answer_hits(Rect2(600, 300, 120, 50), Rect2(560, 240, 220, 60), Rect2(560, 350, 220, 60), 2, button) == false, "tags above on the button but below clear: the badge stays and flips its tags")
	_check(pressure.answer_hits(Rect2(600, 300, 120, 50), Rect2(560, 240, 220, 60), Rect2(560, 250, 220, 60), 2, button), "both tag rows on the button: the badge waits")
	_check(pressure.answer_hits(Rect2(740, 250, 120, 50), Rect2(0, 0, 1, 1), Rect2(0, 0, 1, 1), 1, button), "a badge on the button waits")
	var psrc := FileAccess.get_file_as_string("res://scripts/services/encounter_pressure.gd")
	_check(psrc.contains("and not _answer_hits_hud(center, 2):\n\t\t\t\treturn center") and psrc.contains("if _answer_hits_hud(center, accepted.size()):\n\t\treturn"), "the artillery spot and every badge check the HUD rects")
	# Verdict lines slide off the stage name and buttons on the right column.
	var relay: GDScript = load("res://scripts/services/formation_relay.gd")
	var column: Array[Rect2] = [Rect2(642, 78, 190, 92), Rect2(732, 180, 100, 44)]
	var verdict_box := Rect2(560, 150, 260, 54)
	var shift: float = relay.slide_off_hud(verdict_box, column, 844.0)
	var moved := Rect2(verdict_box.position + Vector2(shift, 0), verdict_box.size)
	_check(shift < 0.0 and moved.end.x <= 636.0 and moved.position.x >= 0.0 and not relay.covers_hud(moved, column), "a verdict running under the stage name moves left of it")
	_check(relay.slide_off_hud(Rect2(300, 250, 260, 54), column, 844.0) == 0.0, "a verdict clear of the HUD stays put")
	var left_panels: Array[Rect2] = [Rect2(8, 80, 210, 56)]
	var right_shift: float = relay.slide_off_hud(Rect2(150, 90, 240, 54), left_panels, 844.0)
	_check(right_shift > 0.0, "a verdict over the left 連斬 box moves right when the left side has no room")
	var rsrc := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(rsrc.contains("at = _verdict_off_hud(at, maxf(text_width, sub_width) + 20.0)
		_reserve_for_plates(") and rsrc.contains("slide_off_hud(box, Enemy.hud_areas(), get_viewport().get_visible_rect().size.x)"), "the verdict is moved before it is reserved and drawn, against the HUD rects")
	# Ground plates keep the same HUD clearance on a 3x phone.
	for path in ["res://scripts/vfx/tide_sigil.gd", "res://scripts/vfx/moon_bloom.gd", "res://scripts/vfx/frost_wall.gd", "res://scripts/vfx/sand_glyphs.gd"]:
		var src := FileAccess.get_file_as_string(path)
		_check(src.contains("var unit := view.x / maxf(1.0, MobileTuning.ui_layout_size(view).x)") and src.contains("clampf(screen.position.y, 120.0 * unit,"), "%s margins scale with the pixel ratio" % path.get_file())
	# The kill/gold box is near-opaque; the phone top bar keeps a gap to it.
	_check(hud_src.contains("style.bg_color = Color(0.045, 0.055, 0.105, 0.93)"), "the kill/gold and status boxes no longer show enemy bars through them")
	var layout: GDScript = load("res://scripts/ui/battle_layout.gd")
	var zones: Dictionary = layout.regions(Vector2(844, 390), true)
	_check(zones.score.position.x - zones.mission.end.x >= 18.0, "the phone top bar ends well before the kill box")
	var desktop: Dictionary = layout.regions(Vector2(1366, 600), false)
	_check(desktop.mission.size.x == 1366.0 - 360.0 - 214.0, "the desktop top bar is unchanged")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.73.0-content-r44", "project version is 0.73.0-content-r44")
	if failures.is_empty():
		print("R44_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R44_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
