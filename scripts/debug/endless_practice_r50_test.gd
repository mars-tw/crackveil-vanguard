extends SceneTree

# Use isolated saves. Drive the production start, continuation and defeat paths
# with controlled counters, then read the saved file and the actual map labels.
var gm: Node
var failures: Array[String] = []
var checks := 0
const SIZES := [Vector2i(320, 568), Vector2i(844, 390), Vector2i(1280, 720)]
var capture_dir := OS.get_environment("CV_R50_CAPTURE_DIR").strip_edges()
var captures: Array[Dictionary] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func _initialize() -> void:
	await process_frame
	gm = root.get_node("GameManager")
	var meta := root.get_node("MetaProgress")
	if not "qa_" in str(meta.get("save_path")):
		printerr("R50_ENDLESS_PRACTICE requires an isolated CV_QA_PROFILE")
		quit(2)
		return
	if not capture_dir.is_empty():
		if DisplayServer.get_name() == "headless" or not capture_dir.is_absolute_path() or DirAccess.make_dir_recursive_absolute(capture_dir) != OK:
			printerr("CV_R50_CAPTURE_DIR requires an absolute writable directory and a rendering display")
			quit(2)
			return
	var file := "user://qa_r50_practice_%d.cfg" % Time.get_ticks_usec()
	gm.campaign_save_path = file
	var old_best := {"wave": 12, "kills": 985721, "seconds": 350.0}
	var legacy := ConfigFile.new()
	legacy.set_value("campaign", "clears", ["garden", "veil"])
	legacy.set_value("campaign", "endless_best", {"garden": old_best})
	legacy.set_value("campaign", "wallet_gold", 317)
	check(legacy.save(file) == OK, "old campaign fixture saved")
	gm.campaign_clears.clear()
	gm.endless_best.clear()
	gm.endless_last_practice.clear()
	gm._load_campaign()
	check(gm.endless_best.get("garden") == old_best and gm.endless_last_practice.is_empty(), "old saves retain the best run without inventing a last run")

	var rotation: GDScript = load("res://scripts/services/endless_rotation.gd")
	gm.tactical_launch = false
	gm.selected_stage_id = "garden"
	gm.current_run_seed = 49107
	gm.run_mode = "campaign"
	gm.start_run(null, null)
	gm.vine_snares_cast = 19
	gm.vine_snares_clean = 7
	gm.stage_victory_pending = true
	gm.continue_after_stage_victory()
	gm.vine_snares_cast += 4
	gm.vine_snares_clean += 4
	gm.elapsed_time = gm.endless_start_time + 91.0
	check(gm.endless_rule() == "veil_lance", "seed 49107 reaches the shadow lance in wave four")
	gm.veil_lances_cast = 3
	gm.veil_lances_blocked = 1
	gm.player_died()
	var missed := {"total": 7, "rule": "veil_lance", "cast": 3, "ok": 1}
	check(gm.endless_last_practice.get("garden") == missed and gm.endless_best.garden == old_best, "keep actual failed rule and exclude campaign casts while preserving the older record")

	gm.selected_stage_id = "veil"
	gm.run_mode = "endless"
	gm.start_run(null, null)
	gm.veil_lances_cast = 5
	gm.veil_lances_blocked = 5
	gm.player_died()
	var cleared := {"total": 5, "rule": "veil_lance", "cast": 5, "ok": 5}
	check(gm.endless_last_practice.garden == missed and gm.endless_last_practice.veil == cleared, "different battlefields retain different practice records")
	var reader: Node = gm.get_script().new()
	reader.campaign_save_path = file
	reader._load_campaign()
	check(reader.endless_last_practice == gm.endless_last_practice and reader.endless_best.garden == old_best, "fresh controller loads both recent runs and the independent best")
	legacy.save(file)
	reader._load_campaign()
	check(reader.endless_last_practice.is_empty(), "loading an older save in the same process clears previous practice")
	legacy.set_value("campaign", "endless_last_practice", "broken")
	legacy.save(file)
	reader._load_campaign()
	check(reader.endless_last_practice.is_empty(), "damaged practice field does not leak the previous profile")
	legacy.set_value("campaign", "endless_last_practice", {"garden": {"total": -1}, "veil": cleared})
	legacy.save(file)
	reader._load_campaign()
	check(reader.endless_last_practice == {"veil": cleared}, "a damaged stage record does not hide valid stages")
	var other_file := file.get_basename() + "_one.cfg"
	var single := ConfigFile.new()
	single.set_value("campaign", "clears", ["storm"])
	check(single.save(other_file) == OK, "one-stage save written")
	reader.campaign_save_path = other_file
	reader._load_campaign()
	check(reader.campaign_clears == ["storm"] and reader.wallet_gold == 0 and reader.endless_best.is_empty() and reader.endless_last_practice.is_empty(), "a one-stage save never inherits absent gold, best, practice or other unlocks")
	reader.campaign_save_path = file
	reader._load_campaign()
	check(reader.campaign_clears == ["garden", "veil"] and reader.wallet_gold == 317 and reader.endless_best.garden == old_best and reader.endless_last_practice.has("veil"), "switching back restores this profile's unlocks, balance and records")
	reader.wallet_dirty = true
	reader.wallet_timer = 1.8
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(other_file)) == OK, "remove this test's alternate save")
	reader.campaign_save_path = other_file
	reader._load_campaign()
	check(reader.campaign_clears.is_empty() and reader.wallet_gold == 0 and reader.endless_best.is_empty() and reader.endless_last_practice.is_empty(), "a missing file starts with no unlocks, gold or records")
	check(not reader.wallet_dirty and is_zero_approx(reader.wallet_timer), "the previous profile cannot trigger a delayed save into the new path")
	reader.free()
	check(rotation.practice_text({}).is_empty() and rotation.practice_text({"total": 1, "rule": "other", "ok": 0, "cast": 1}).is_empty(), "older or unknown records produce no false lesson")
	for size: Vector2i in SIZES:
		await _check_map(size)

	gm.selected_stage_id = "garden"
	gm.run_mode = "campaign"
	gm.start_run(null, null)
	gm.player_died()
	check(gm.endless_last_practice.garden == missed, "a campaign defeat does not replace endless practice")
	gm.run_mode = "endless"
	gm.start_run(null, null)
	gm.player_died()
	var no_cast: Dictionary = gm.endless_last_practice.garden
	check(no_cast == {"total": 0} and rotation.practice_text(no_cast).contains("還沒出招"), "even a short latest run replaces the old advice without inventing a failed encounter")
	check(gm.endless_best.garden == old_best and gm.endless_last_practice.veil == cleared, "short run preserves the best and other stages")
	var stored := ConfigFile.new()
	check(stored.load(file) == OK and stored.get_value("campaign", "endless_last_practice", {}) == gm.endless_last_practice, "latest replacement made it to disk")
	if not capture_dir.is_empty():
		for size: Vector2i in SIZES:
			await _check_map(size, true)
		check(captures.size() == 4 * SIZES.size(), "all four map states captured at every viewport")
		var manifest := FileAccess.open(capture_dir.path_join("captures.json"), FileAccess.WRITE)
		check(manifest != null, "capture manifest is writable")
		if manifest != null:
			manifest.store_string(JSON.stringify({"checks": checks, "failures": failures, "adapter": RenderingServer.get_video_adapter_name(), "method": RenderingServer.get_current_rendering_method(), "captures": captures}, "\t") + "\n")
			manifest.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	print("R50_ENDLESS_PRACTICE checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check_map(size: Vector2i, no_cast_only: bool = false) -> void:
	var tuning: GDScript = load("res://scripts/services/mobile_tuning.gd")
	var phone := size.x < 900
	tuning.set_device_hints_override_for_tests({"ua_phone": phone, "ua_mobile": phone, "touch_available": phone, "mouse_available": not phone})
	var view := SubViewport.new()
	view.size = size
	if not capture_dir.is_empty():
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# The map resumes when entered after the defeat screen in normal play.
	gm.system_pause_owners.clear()
	paused = false
	root.add_child(view)
	if not capture_dir.is_empty():
		view.notify_mouse_entered()
	var world: Node = load("res://scripts/ui/world_map.gd").new()
	view.add_child(world)
	await _select_map_stage(view, world, "garden")
	for i in range(3):
		await process_frame
	var note := str(world.detail_description.text)
	if no_cast_only:
		check(note.begins_with("上次無盡結束前，菁英還沒出招。") and note.contains("無盡最高 12 波"), "%s newest zero-cast run replaces the earlier advice on the map" % size)
		_check_advice_visible(world, size)
		await _capture_map(view, world, "no-cast")
		view.queue_free()
		await process_frame
		tuning.set_device_hints_override_for_tests({})
		return
	check(note.contains("1/3 次影槍鎖定") and note.contains("隊長就走到他身邊") and note.contains(world.CATALOG.get_stage("garden").description), "%s map shows result, action and original stage description" % size)
	check(note.contains("無盡最高 12 波／985721 擊殺") and not world.endless_button.disabled, "%s distinguishes highest run from last run" % size)
	var bounds := Rect2(Vector2.ZERO, Vector2(size))
	var details: Rect2 = world.detail_panel.get_global_rect()
	var body: Rect2 = world.detail_scroll.get_global_rect()
	check(bounds.encloses(details) and not details.intersects(world.footer.get_global_rect()) and details.encloses(body), "%s detail panel stays above the controls" % size)
	_check_advice_visible(world, size)
	for button in [world.back_button, world.start_button, world.endless_button]:
		check(bounds.encloses(button.get_global_rect()), "%s footer buttons remain reachable" % size)
	await _capture_map(view, world, "practice")
	await _select_map_stage(view, world, "veil")
	for i in range(3):
		await process_frame
	var success := str(world.detail_description.text)
	check(success.contains("5 招全數處理") and success.contains("5 次影槍鎖定") and success.contains("影槍鎖定隊員時，隊長走過去護住") and not success.contains("1/3"), "%s changing selection gives the successful action to repeat" % size)
	_check_advice_visible(world, size)
	await _capture_map(view, world, "all-handled")
	await _select_map_stage(view, world, "ember")
	check(not world.detail_description.text.contains("上次無盡") and world.endless_button.disabled, "%s uncleared stage never leaks another stage's record" % size)
	await _capture_map(view, world, "locked")
	view.queue_free()
	await process_frame
	tuning.set_device_hints_override_for_tests({})

func _check_advice_visible(world: Node, size: Vector2i) -> void:
	var label: Label = world.detail_description
	var text_width := label.size.x
	check(text_width > 0, "%s advice label has usable width" % size)
	if text_width <= 0:
		return
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var wrap := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var advice := label.text.get_slice("\n", 0)
	var height := font.get_multiline_string_size(advice, HORIZONTAL_ALIGNMENT_LEFT, text_width, font_size, -1, wrap).y
	var lines := ceili(height / maxf(1.0, font.get_height(font_size)))
	height += maxi(0, lines - 1) * label.get_theme_constant("line_spacing")
	var visible_body: Rect2 = world.detail_scroll.get_global_rect()
	var first_line_top := label.get_global_rect().position.y
	check(advice.begins_with("上次無盡") and world.detail_scroll.scroll_vertical == 0 and first_line_top >= visible_body.position.y - 1 and first_line_top + height <= visible_body.end.y + 1, "%s all wrapped lines of the practice action fit before scrolling" % size)

func _select_map_stage(view: SubViewport, world: Node, stage_id: String) -> void:
	for button: Button in world.node_buttons:
		if button.get_meta("stage_id") != stage_id:
			continue
		if capture_dir.is_empty():
			button.pressed.emit()
		else:
			await process_frame
			if world.portrait:
				world.portrait_scroll.ensure_control_visible(button)
			await process_frame
			var position := button.get_global_rect().get_center()
			_hover(view, position)
			for down: bool in [true, false]:
				var click := InputEventMouseButton.new()
				click.position = position
				click.global_position = position
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = down
				view.push_input(click, true)
				await process_frame
		check(world.selected_id == stage_id, "%s stage control selects %s" % [view.size, stage_id])
		return
	check(false, "missing map button for " + stage_id)

func _hover(view: SubViewport, position: Vector2) -> Control:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	view.push_input(motion, true)
	return view.gui_get_hovered_control()

func _box(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _capture_map(view: SubViewport, world: Node, state: String) -> void:
	if capture_dir.is_empty():
		return
	var footer_buttons := []
	for button: Button in [world.back_button, world.start_button, world.endless_button]:
		var bounds := button.get_global_rect()
		var hit := _hover(view, bounds.get_center())
		var uncovered := hit == button or (is_instance_valid(hit) and button.is_ancestor_of(hit))
		check(button.is_visible_in_tree() and view.get_visible_rect().encloses(bounds) and uncovered, "%s/%s footer center hits %s" % [view.size, state, button.text])
		footer_buttons.append({"text": button.text, "bounds": _box(bounds), "disabled": button.disabled, "uncovered": uncovered})
	_hover(view, Vector2(1, 1))
	await process_frame
	await RenderingServer.frame_post_draw
	var shot := view.get_texture().get_image()
	if shot == null or shot.is_empty() or shot.get_size() != view.size:
		check(false, "%s/%s renderer did not return the viewport" % [view.size, state])
		return
	var label: Label = world.detail_description
	var visible_body: Rect2 = world.detail_scroll.get_global_rect()
	# Confirm that the rendered description contains bright glyphs and dark
	# background. Exact words and line-fit checks use the live Label above.
	var ink := 0
	var background := 0
	var area := Rect2i(visible_body.intersection(label.get_global_rect()).intersection(view.get_visible_rect()))
	for y in range(area.position.y, area.end.y, 2):
		for x in range(area.position.x, area.end.x, 2):
			var light := shot.get_pixel(x, y).get_luminance()
			if light > 0.55:
				ink += 1
			elif light < 0.25:
				background += 1
	check(ink >= 12 and background >= 12, "%s/%s description has rendered ink on a contrasting surface" % [view.size, state])
	var filename := "%dx%d-%s.png" % [view.size.x, view.size.y, state]
	var path := capture_dir.path_join(filename)
	if shot.save_png(path) != OK:
		check(false, "cannot write " + filename)
		return
	captures.append({"file": filename, "sha256": FileAccess.get_sha256(path), "viewport": [view.size.x, view.size.y], "state": state, "stage": world.selected_id, "description": label.text, "font_px": label.get_theme_font_size("font_size"), "label": _box(label.get_global_rect()), "visible_body": _box(visible_body), "scroll_y": world.detail_scroll.scroll_vertical, "bright_samples": ink, "dark_samples": background, "footer": footer_buttons})
