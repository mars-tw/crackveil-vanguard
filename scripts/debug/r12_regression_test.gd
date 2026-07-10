extends Node

const BACKGROUND_SCRIPT := preload("res://scripts/arena/arena_background.gd")
const PLAYER_VISUAL_SCRIPT := preload("res://scripts/player/player_visual.gd")
const RUN_THEME := preload("res://scripts/arena/run_theme.gd")

var current_phase: String = "boot"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(12012)
	call_deferred("_watchdog")
	call_deferred("_run_tests")


func _watchdog() -> void:
	await get_tree().create_timer(12.0, true).timeout
	if current_phase != "done":
		_fail("watchdog timeout at phase: " + current_phase)


func _run_tests() -> void:
	current_phase = "theme"
	if not _test_theme_selection():
		return
	current_phase = "decor"
	if not await _test_decor_determinism():
		return
	current_phase = "steps"
	if not await _test_step_visual_pool():
		return

	current_phase = "done"
	print("R12_REGRESSION_PASS")
	get_tree().quit(0)


func _test_theme_selection() -> bool:
	var ids := RUN_THEME.get_theme_ids()
	if ids.size() != 3:
		_fail("expected three map themes")
		return false
	var seen: Dictionary = {}
	for run_seed in [1, 2, 3, 12001, 12002, 12003]:
		var first := RUN_THEME.select_theme_id(run_seed)
		var second := RUN_THEME.select_theme_id(run_seed)
		if first != second:
			_fail("theme selection not deterministic for seed %d" % run_seed)
			return false
		seen[first] = true
	for theme_id in ids:
		if not seen.has(theme_id):
			_fail("theme id not covered by deterministic seeds: " + str(theme_id))
			return false
	print("R12_THEME_SELECTION ids=" + ",".join(ids))
	return true


func _test_decor_determinism() -> bool:
	var center := Vector2(512.0, -384.0)
	var seed_a := 12001
	var seed_b := 12002
	var bg_a := BACKGROUND_SCRIPT.new()
	var bg_b := BACKGROUND_SCRIPT.new()
	var bg_c := BACKGROUND_SCRIPT.new()
	add_child(bg_a)
	add_child(bg_b)
	add_child(bg_c)
	await get_tree().process_frame

	bg_a.configure_run_theme(seed_a, RUN_THEME.select_theme_id(seed_a))
	bg_b.configure_run_theme(seed_a, RUN_THEME.select_theme_id(seed_a))
	bg_c.configure_run_theme(seed_b, RUN_THEME.select_theme_id(seed_b))
	var sig_a := bg_a.get_decor_signature_for_center(center, 18)
	var sig_b := bg_b.get_decor_signature_for_center(center, 18)
	var sig_c := bg_c.get_decor_signature_for_center(center, 18)
	if sig_a == "" or sig_b == "":
		_fail("decor signature empty")
		return false
	if sig_a != sig_b:
		_fail("decor signature not reproducible for same seed")
		return false
	if sig_a == sig_c:
		_fail("decor signature did not change across seeds")
		return false
	print("R12_DECOR_DETERMINISTIC theme=%s signature_len=%d" % [
		bg_a.get_theme_name(),
		sig_a.length()
	])
	return true


func _test_step_visual_pool() -> bool:
	GameManager.set_current_run_theme("wasteland_farm", RUN_THEME.get_theme_name("wasteland_farm"))
	var host := CharacterBody2D.new()
	host.name = "R12StepHost"
	host.add_to_group("heroes")
	add_child(host)

	var visual := PLAYER_VISUAL_SCRIPT.new()
	visual.name = "Visual"
	host.add_child(visual)
	await get_tree().process_frame
	visual.configure_visual("res://assets/sprites/hero_captain.png", 1.0, 15.0)
	if int(visual.get_step_dust_pool_size()) != 8:
		_fail("step dust pool size mismatch")
		return false

	var sprite: Sprite2D = visual.get("sprite")
	if sprite == null:
		_fail("step visual sprite missing")
		return false
	host.velocity = Vector2(190.0, 0.0)
	var min_y := 9999.0
	var max_y := -9999.0
	var max_rotation := 0.0
	for _index in range(18):
		visual._process(0.05)
		min_y = minf(min_y, sprite.position.y)
		max_y = maxf(max_y, sprite.position.y)
		max_rotation = maxf(max_rotation, abs(sprite.rotation))
	host.velocity = Vector2.ZERO

	if max_y - min_y < 3.0:
		_fail("step hop did not move sprite enough")
		return false
	if max_rotation < 0.035:
		_fail("alternating step tilt too small")
		return false
	if int(visual.get_step_dust_emit_count()) < 2:
		_fail("step dust did not emit from pool")
		return false
	if int(visual.get_footstep_tick_count()) < 2:
		_fail("footstep ticks not synchronized with steps")
		return false

	visual.set_facing_direction(Vector2.LEFT)
	if float(visual.get_turn_squash_timer()) <= 0.0:
		_fail("turn squash was not triggered")
		return false
	print("R12_STEPS dust_pool=%d dust_emits=%d ticks=%d hop_delta=%.2f tilt=%.3f" % [
		int(visual.get_step_dust_pool_size()),
		int(visual.get_step_dust_emit_count()),
		int(visual.get_footstep_tick_count()),
		max_y - min_y,
		max_rotation
	])
	return true


func _fail(message: String) -> void:
	printerr("R12_REGRESSION_FAIL: " + message)
	get_tree().quit(1)
