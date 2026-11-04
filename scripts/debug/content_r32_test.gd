extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	# Every stage hazard keeps off an open seal.
	var ring: GDScript = load("res://scripts/vfx/ember_ring.gd")
	var ring_src := FileAccess.get_file_as_string("res://scripts/vfx/ember_ring.gd")
	var snare_src := FileAccess.get_file_as_string("res://scripts/vfx/vine_snare.gd")
	_check(ring_src.contains("ring.global_position = VINE_SNARE.off_seal(at, OUTER)"), "an ember ring is pushed off an open seal by its outer radius")
	_check(snare_src.contains("static func off_seal(at: Vector2, reach: float = RADIUS) -> Vector2:") and snare_src.contains("return seal + away.normalized() * (SEAL_CLEARANCE + reach)"), "the seal clearance grows with the hazard's reach")
	# Burned heroes wear a top-layer mark; a fully dodged ring is counted.
	_check(ring.MARK_SECONDS >= 1.0 and ring_src.contains("mark_layer.z_index = 120") and ring_src.contains("\"燒\""), "heroes caught by the burst wear a 燒 mark on the top layer")
	_check(ring_src.contains("if hits == 0:\n\t\tGameManager.ember_rings_clean += 1"), "a ring the whole squad dodged counts as clean")
	_check(ring_src.contains("_flames(OUTER - 4.0, 28, 16.0, 0.75)"), "the warned band shows flame tongues")
	var node: Node2D = ring.new()
	get_root().add_child(node)
	node._process(ring.WARN_SECONDS + ring.BURST_SECONDS + 0.1)
	_check(is_instance_valid(node) and not node.is_queued_for_deletion(), "the ring stays for the mark after the band fades")
	node.queue_free()
	# Squad share: members settle near a third of the damage.
	var gm: GDScript = load("res://scripts/autoload/game_manager.gd")
	# R32 tried x3.0 / fourth power / x4.0 and a late-opening x5.0: in five bot
	# runs every stronger-member build took the first stage 4:15-6:42 against
	# 1:50-2:21 for the R31 values, so the R31 balance stays until the cause is found.
	_check(gm.SQUAD_SHARE_MEMBER == 2.5 and gm.SQUAD_TARGET_CAPTAIN_SHARE == 0.55 and gm.SQUAD_CATCH_UP_MAX == 2.4, "the squad share keeps the R31 values")
	_check(absf(gm.squad_catch_up(7000.0, 3000.0) - pow(0.7 / 0.55, 2.0)) < 0.001, "the catch-up keeps the R31 square curve")
	_check(gm.SQUAD_CATCH_UP_START == 1500.0 and gm.SQUAD_CATCH_UP_RAMP == 8000.0, "the catch-up keeps the R31 ramp")
	# Verdict wording and layering.
	var relay: Node2D = load("res://scripts/services/formation_relay.gd").new()
	_check(relay.result_text({"formation":"ring","members":4,"hit":0,"protected":0,"reduced":0,"correct":true}) == "圓陣正確・無人中招", "a dodged correct verdict no longer says 避開 next to 站進封隙")
	_check(relay.TEXT_LAYER_Z > 97 and relay.TEXT_LAYER_Z < 120, "verdict plates sit above squad halos and pace tags, below hazard marks")
	relay.free()
	_check(FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd").contains("text_layer.z_as_relative = false"), "the verdict layer is absolute")
	# Punctuation: no full-width bracket followed by more punctuation.
	var result: GDScript = load("res://scripts/ui/r4_result_screen.gd")
	var result_src := FileAccess.get_file_as_string("res://scripts/ui/r4_result_screen.gd")
	var relay_src := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(not result_src.contains("），") and not relay_src.contains("（需 2）・"), "no stray gap from a full-width bracket before punctuation")
	# Victory badges.
	var badges: String = result.victory_badges({"squad_total": 8, "squad_alive": 8, "seal_state": {"wrong": 0, "fast_seals": 3, "slow_seals": 0, "ember_rings": 5, "ember_clean": 3}})
	_check(badges == "戰績：零錯陣・三道全快封・全員生還・躲過熔火環 3/5", "a clean victory lists its feats")
	_check(result.victory_badges({"squad_total": 8, "squad_alive": 6, "seal_state": {"wrong": 2, "fast_seals": 1, "slow_seals": 2}}) == "", "no badge line without a feat")
	_check(result.vine_line({"ember_rings": 3, "ember_clean": 1, "ember_hits": 4}) == "熔火環爆 3 次・全員躲過 1 次・被燒 4 人次", "the result reports dodged rings")
	# HUD touch buttons stay opaque, the menu version hides under preparation.
	var hud_src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(hud_src.contains("panel.bg_color = Color(0.025,0.06,0.10,0.90)") and hud_src.contains("for state in [\"hover\", \"pressed\", \"disabled\"]:"), "touch buttons keep a near-opaque plate in every state")
	_check(FileAccess.get_file_as_string("res://scripts/ui/main_menu.gd").contains("version_label.visible = not preparation.root.visible"), "the menu version string hides under the preparation page")
	var font: FontFile = load("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
	var missing := ""
	for s in ["燒", badges, "圓陣正確・無人中招", "無人中招・圓陣無法封合", "熔火環爆 3 次・全員躲過 1 次・被燒 4 人次", "下次：倒在第 1 道・封隙 0/3，攻勢間隙帶兩名隊友站進封隙"]:
		for i in range(str(s).length()):
			var c: int = str(s).unicode_at(i)
			if c > 0x7f and not font.has_char(c):
				missing += char(c)
	_check(missing == "", "every new string is covered by the CJK subset font (missing: %s)" % missing)
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.73.0-content-r44", "project version is 0.73.0-content-r44")
	if failures.is_empty():
		print("R32_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R32_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
