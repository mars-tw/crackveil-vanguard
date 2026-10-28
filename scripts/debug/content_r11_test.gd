extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	_test_scatter_rings()
	_test_elite_label_slots()
	_test_elite_label_wiring()
	_test_seal_toast()
	_test_version()
	if failures.is_empty():
		print("R11_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R11_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _test_scatter_rings() -> void:
	var squad_script: GDScript = load("res://scripts/heroes/squad_manager.gd")
	var squad: Node2D = squad_script.new()
	var duration: float = squad.FORMATION_INDICATOR_DURATION
	squad.formation_indicator_timer = duration
	_check(squad.scatter_ring_alpha() <= 0.7, "scatter ring is at most 0.7 right after switching")
	squad.formation_indicator_timer = duration - 1.5
	_check(squad.scatter_ring_alpha() <= 0.3, "scatter ring fades to 0.3 or less after the 1 s window")
	squad.formation_indicator_timer = 0.0
	_check(squad.scatter_ring_alpha() <= 0.3, "scatter ring stays faint when idle")
	squad.free()
	var source := FileAccess.get_file_as_string("res://scripts/heroes/squad_manager.gd")
	_check(source.contains("if formation_id == \"scatter\" and member == leader:"), "only the captain draws the scatter pickup ring")
	_check(not source.contains("Color(color,0.70),2.4,true)"), "old opaque per-member scatter rings are gone")
	_check(source.contains("Color(color, scatter_ring_alpha()), 1.8, true)"), "scatter ring uses the fading alpha and a thinner stroke")

func _test_elite_label_slots() -> void:
	var enemy_script: GDScript = load("res://scripts/enemies/enemy.gd")
	var view := Vector2(1558, 720)
	var size := Vector2(200, 30)
	var none: Array[Rect2] = []
	var top_band: float = enemy_script.ELITE_LABEL_TOP_BAND
	_check(top_band >= 170.0, "top band covers HUD bars, the notice toast and timer")
	var above := Rect2(Vector2(600, 300), size)
	var below := Rect2(Vector2(600, 420), size)
	_check(enemy_script.elite_label_slot(above, below, view, none) == above, "plate stays above the elite in open field")
	var high_above := Rect2(Vector2(600, 60), size)
	var high_below := Rect2(Vector2(600, 180), size)
	_check(enemy_script.elite_label_slot(high_above, high_below, view, none) == high_below, "plate flips below the elite under the top HUD band")
	var hidden: Rect2 = enemy_script.elite_label_slot(Rect2(Vector2(600, 10), size), Rect2(Vector2(600, 40), size), view, none)
	_check(hidden.size == Vector2.ZERO, "plate hides when the elite itself is under the HUD")
	var low: Rect2 = enemy_script.elite_label_slot(Rect2(Vector2(600, 640), size), Rect2(Vector2(600, 700), size), view, none)
	_check(low.size == Vector2.ZERO, "plate never enters the bottom equipment band")
	var taken: Array[Rect2] = [above]
	var second: Rect2 = enemy_script.elite_label_slot(Rect2(Vector2(640, 310), size), Rect2(Vector2(640, 430), size), view, taken)
	_check(second.size != Vector2.ZERO and not second.intersects(above), "a second elite plate never stacks on the first")
	var crowded: Array[Rect2] = [Rect2(Vector2(600, 300), size), Rect2(Vector2(600, 420), size), Rect2(Vector2(600, 454), size)]
	var third: Rect2 = enemy_script.elite_label_slot(above, below, view, crowded)
	_check(third.size == Vector2.ZERO, "plate hides instead of stacking when every slot is taken")
	for rect in [above, high_below, second]:
		_check(rect.position.y >= top_band, "chosen plate sits below the top band")

func _test_elite_label_wiring() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	_check(source.contains("_tick_hit_flash(delta)\r\n\t_place_special_label()") or source.contains("_tick_hit_flash(delta)\n\t_place_special_label()"), "plates are placed every physics frame")
	_check(source.contains("special_label_wanted = false"), "pool release clears the plate request")
	_check(source.contains("Engine.get_physics_frames()"), "plate occupancy resets each physics frame")
	_check(source.contains("taken.append_array(active_label_areas())"), "plates avoid reserved seal badge areas")
	var pressure := FileAccess.get_file_as_string("res://scripts/services/encounter_pressure.gd")
	_check(pressure.contains("Enemy.reserve_label_area("), "seal answer badges reserve their screen area")
	var enemy_script: GDScript = load("res://scripts/enemies/enemy.gd")
	var badge := Rect2(Vector2(600, 300), Vector2(180, 90))
	var taken: Array[Rect2] = [badge]
	var slot: Rect2 = enemy_script.elite_label_slot(Rect2(Vector2(620, 320), Vector2(200, 30)), Rect2(Vector2(620, 440), Vector2(200, 30)), Vector2(1558, 720), taken)
	_check(slot.size != Vector2.ZERO and not slot.intersects(badge), "plate moves off a reserved badge")
	var edge: Rect2 = enemy_script.elite_label_slot(Rect2(Vector2(1420, 300), Vector2(200, 30)), Rect2(Vector2(1420, 420), Vector2(200, 30)), Vector2(1558, 720), none_rects())
	_check(edge.size == Vector2.ZERO, "plates never enter the right HUD button column")
	var corner: Rect2 = enemy_script.elite_label_slot(Rect2(Vector2(40, 520), Vector2(200, 30)), Rect2(Vector2(40, 560), Vector2(200, 30)), Vector2(1558, 720), none_rects())
	_check(corner.size == Vector2.ZERO, "plates never enter the bottom-left control block")
	_check(source.contains("is_active = false\r\n\tspecial_label_wanted = false") or source.contains("is_active = false\n\tspecial_label_wanted = false"), "dying elites drop their plate immediately")
	var relay_source := FileAccess.get_file_as_string("res://scripts/services/formation_relay.gd")
	_check(relay_source.contains("_reserve_for_plates(Rect2(at + Vector2(0, -24), Vector2(280, 58)))"), "verdict lines reserve their area from plates")
	var pressure_src := FileAccess.get_file_as_string("res://scripts/services/encounter_pressure.gd")
	_check(pressure_src.contains("if seal_banner_showing():"), "next seal badge waits for the seal banner to fade")
	var identity := FileAccess.get_file_as_string("res://scripts/arena/r4_battle_identity.gd")
	_check(identity.contains("Enemy.label_area_reserved(_screen_xf()*above,12.0)") and identity.contains("if head_clear:") and identity.contains("if not head_clear:continue"), "captain crown and ally icons yield to verdict and badge text")
	enemy_script.reserve_label_area(Rect2(Vector2(300, 300), Vector2(200, 60)))
	_check(enemy_script.label_area_reserved(Vector2(400, 330), 12.0), "point inside a reserved text area is reported")
	_check(not enemy_script.label_area_reserved(Vector2(900, 330), 12.0), "point away from reserved text is clear")
	_check(relay_source.contains("Enemy.reserve_label_area(marker_label.get_global_rect(), marker_label)"), "seal marker reserves its area from plates")
	_check(relay_source.contains("_reserve_for_plates(Rect2(at+Vector2(230-width/2-12,-25),Vector2(width+24,34)))"), "seal reward banner reserves its area from plates")
	_check(relay_source.contains("text_layer.draw.connect(_draw_text_layer)") and relay_source.contains("text_layer.draw_string(FONT,at,verdict") and relay_source.contains("text_layer.draw_string(FONT,at,seal_flash_text"), "verdict and seal banner draw on a layer above seal frames")
	var relay_node: Node2D = load("res://scripts/services/formation_relay.gd").new()
	_check(relay_node.TEXT_LAYER_Z >= 20, "rule text layer sits above seal frames, halos and squad markers")
	relay_node.free()
	_check(pressure.contains("Enemy.clear_label_areas(self)") and relay_source.contains("Enemy.clear_label_areas(self)"), "reservations follow each redraw instead of expiring by frame count")
	var owner := Node2D.new()
	enemy_script.reserve_label_area(Rect2(Vector2(1000, 100), Vector2(50, 50)), owner)
	_check(enemy_script.label_area_reserved(Vector2(1020, 120), 0.0), "owned reservation persists without a time limit (drawing kept while paused)")
	enemy_script.clear_label_areas(owner)
	_check(not enemy_script.label_area_reserved(Vector2(1020, 120), 0.0), "owner clearing on redraw removes its reservation")
	enemy_script.reserve_label_area(Rect2(Vector2(1000, 100), Vector2(50, 50)), owner)
	owner.free()
	_check(not enemy_script.label_area_reserved(Vector2(1020, 120), 0.0), "freed owner reservation is dropped")

func none_rects() -> Array[Rect2]:
	var empty: Array[Rect2] = []
	return empty

func _test_seal_toast() -> void:
	var relay_script: GDScript = load("res://scripts/services/formation_relay.gd")
	var relay: Node2D = relay_script.new()
	for step in [1, 2]:
		var toast: String = relay.seal_toast_text(step)
		_check(toast.begins_with("封隙 %d/3｜" % step), "seal toast keeps the progress prefix")
		_check(toast.contains("第 %d 道" % (step + 1)), "seal toast names the next seal")
		_check(not toast.contains("整補") and not toast.contains("反擊"), "seal toast no longer repeats the world banner reward")
		_check(toast.contains("5 秒"), "seal toast keeps the default bonus duration")
		_check(relay.seal_text(step).contains("整補 +8"), "world banner still carries the reward")
	var wrong := {"formation":"wedge","members":7,"hit":7,"protected":0,"reduced":0,"correct":false}
	var correct_hit := {"formation":"scatter","members":9,"hit":9,"protected":0,"reduced":0,"correct":true}
	var clean := {"formation":"scatter","members":9,"hit":0,"protected":0,"reduced":0,"correct":true}
	_check(relay_script.verdict_color(correct_hit) != relay_script.verdict_color(wrong), "correct formation with hits is not drawn in the wrong-formation red")
	_check(relay_script.verdict_color(clean) != relay_script.verdict_color(correct_hit), "clean dodge keeps its own green")
	_check(relay.consequence_text(correct_hit).contains("封合照算") and relay.consequence_text(correct_hit).contains("落點"), "correct-with-hits verdict explains the seal still counts and to dodge")
	_check(relay.consequence_text(clean) == "陣形正確・站進封隙累積封合", "clean verdict keeps the seal instruction")
	relay.free()
	var enemy_source := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	_check(enemy_source.contains("special_label.z_index = ELITE_LABEL_Z") and enemy_source.contains("special_label.z_as_relative = false"), "elite plates draw above seal frames and auras")

func _test_version() -> void:
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.40.0-content-r11", "project version is 0.40.0-content-r11")
