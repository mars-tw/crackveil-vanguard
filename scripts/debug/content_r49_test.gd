extends SceneTree

var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _initialize() -> void:
	await process_frame
	var game := root.get_node("GameManager")
	var meta := root.get_node("MetaProgress")
	if not str(meta.save_path).get_file().begins_with("qa_"):
		printerr("R49 seal gate requires CV_QA_PROFILE")
		quit(2)
		return
	var rules: GDScript = load("res://scripts/services/starting_build_catalog.gd")
	var relay_type: GDScript = load("res://scripts/services/formation_relay.gd")
	check(relay_type.lesson_text("front", "") == "楔形快封補8，圓陣慢封補16，錯陣反噬歸零", "default first-wave comparison")
	check(relay_type.lesson_text("pincer", "spec_prepare") == "圓陣快封補0，散兵慢封補0，錯陣反噬歸零", "prepare forfeits both heals")
	check(rules.seal_time_source("spec_collect", "pincer", "scatter") == "專精-3秒", "collect shows actual change from base duration")
	check(rules.seal_time_source("spec_escort", "front", "ring") == "專精-2秒", "escort shows actual change from base duration")
	check(rules.seal_time_source("spec_escort", "front", "wedge").is_empty(), "unmodified answer has no modifier")
	game.active_starting_node = "spec_escort"
	check(relay_type.switch_card_for("front", "ring").contains("慢封 7 秒專精-2秒"), "switch card uses live build")
	game.active_starting_node = ""
	meta.reset_progress()
	game.selected_stage_id = "forge"
	game.run_mode = "campaign"
	game.pending_starting_formal = false
	var arena: Node = load("res://scenes/arena/Arena.tscn").instantiate()
	root.add_child(arena)
	for i in 4:
		await process_frame
	var relay: Node = game.tactical_director.relay
	var hud: Node = arena.get_node("HUD")
	game.elapsed_time = 13.0
	game.game_running = true
	paused = false
	relay.advance(0.01)
	hud._update_tactical_hint()
	check(str(hud.tactical_hint.text).contains("慢封補16") and meta.seal_lesson_seen, "tutorial appears through the real HUD")
	meta.load_progress()
	check(meta.seal_lesson_seen, "seen state survives reload")
	game.elapsed_time = 20.0
	check(relay.first_seal_lesson().is_empty(), "after the display interval the lesson stops")
	relay.lesson_until = -1.0
	check(relay.first_seal_lesson().is_empty(), "reopening a seal does not replay a persisted lesson")
	# Two simultaneous instructions: the tide owns the bar on the exact frame
	# the seal warning would otherwise have told the player to hold wedge.
	var tide: Node2D = load("res://scripts/vfx/tide_sigil.gd").new()
	tide.required = "ring"
	arena.add_child(tide)
	tide.add_to_group("tide_sigils")
	hud.toast_current_text = "重盾正推｜預警・快封楔形／慢封圓陣"
	hud.toast_showing = true
	hud._update_tactical_hint()
	check(str(hud.tactical_hint.text).contains("潮紋") and not str(hud.tactical_hint.text).contains("快封楔形"), "stage action outranks seal warning")
	tide.free()
	var forge: Node2D = load("res://scripts/vfx/forge_core.gd").new()
	arena.add_child(forge)
	forge.add_to_group("forge_cores")
	var xf: Transform2D = relay.get_viewport().get_canvas_transform() * relay.get_global_transform()
	var origin: Vector2 = xf.affine_inverse() * (relay.get_viewport_rect().size * 0.5)
	relay.anchor = origin - Vector2(500, 400)
	forge.global_position = origin + Vector2(140, 0)
	forge.sockets = {"near": Vector2.ZERO, "far": Vector2(105, 0)}
	var at: Vector2 = relay._verdict_off_hud(origin, 240.0)
	var box := xf * Rect2(at + Vector2(20, -22), Vector2(240, 54))
	check(at.is_finite() and root.get_visible_rect().encloses(box), "verdict stays visible")
	for socket in ["near", "far"]:
		var half := Vector2.ONE * float(forge.socket_half(socket))
		var bounds := forge.get_viewport().get_canvas_transform() * Rect2(forge.socket_global(socket) - half, half * 2)
		check(not box.intersects(bounds), "verdict clears %s socket" % socket)
	forge.free()
	game.game_running = false
	arena.queue_free()
	await process_frame
	print("CONTENT_R49 status=%s checks=%d failures=%s" % ["PASS" if failures.is_empty() else "FAIL", checks, failures])
	quit(0 if failures.is_empty() else 1)
