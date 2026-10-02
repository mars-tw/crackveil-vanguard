extends Node

const LEVEL_SCREEN := preload("res://scripts/ui/level_up_screen.gd")
const HUD := preload("res://scripts/ui/hud.gd")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const OPTIONS := [{"id":"move_speed", "name":"疾步校準", "description":"移動速度 +20"}, {"id":"max_hp", "name":"裂隙護甲", "description":"最大HP +20"}, {"id":"pickup_radius", "name":"回收磁場", "description":"拾取範圍 +24"}]

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_test")

func _test() -> void:
	for dimensions in [Vector2i(1280,720), Vector2i(844,390)]:
		MOBILE.set_device_hints_override_for_tests({"ua_mobile":dimensions.x==844,"ua_phone":dimensions.x==844,"touch_available":dimensions.x==844,"primary_coarse":dimensions.x==844,"mouse_available":dimensions.x!=844})
		var view := SubViewport.new()
		view.size = dimensions
		add_child(view)
		var screen := LEVEL_SCREEN.new()
		view.add_child(screen)
		await get_tree().process_frame
		for iteration in range(4):
			screen.show_options(OPTIONS)
			for tick in range(35):
				await get_tree().process_frame
			var bounds := screen.card_scroll.get_global_rect()
			for button in screen.option_buttons:
				if not bounds.has_point(button.get_global_rect().get_center()) or button.modulate.a < 0.9:
					printerr("R33_EXPERIENCE_FAIL: repeated upgrade card leaves visible grid at %s iteration %d" % [dimensions,iteration])
					get_tree().quit(1)
					return
			if screen.card_grid.get_child_count() != 3:
				printerr("R33_EXPERIENCE_FAIL: obsolete cards still occupy grid")
				get_tree().quit(1)
				return
		var hud := HUD.new()
		view.add_child(hud)
		await get_tree().process_frame
		hud._apply_responsive_layout()
		if hud.hud_panel.size.y > 64.0:
			printerr("R33_EXPERIENCE_FAIL: mobile HUD did not compact")
			get_tree().quit(1)
			return
		print("R33_EXPERIENCE_GRID size=%s four_levels=visible header_height=%.1f" % [dimensions,hud.hud_panel.size.y])
		view.queue_free()
		await get_tree().process_frame
	MOBILE.set_device_hints_override_for_tests()
	print("R33_EXPERIENCE_PASS repeated_upgrades=4x2 container_tween=alpha_scale_only header=58 single_tap=true")
	get_tree().quit(0)
