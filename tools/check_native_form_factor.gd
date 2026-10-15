extends SceneTree

const Tuning = preload("res://scripts/services/mobile_tuning.gd")

func _initialize() -> void:
	var cases := [
		[Vector2(1280, 720), {"mobile_os": true, "native_form_factor": "phone"}, Tuning.LayoutTier.PHONE],
		[Vector2(2560, 1440), {"mobile_os": true, "native_form_factor": "phone"}, Tuning.LayoutTier.PHONE],
		[Vector2(1280, 720), {"mobile_os": true, "native_form_factor": "tablet"}, Tuning.LayoutTier.TABLET],
		[Vector2(1280, 720), {"mobile_os": false, "touch_available": true, "mouse_available": true}, Tuning.LayoutTier.DESKTOP],
	]
	for sample in cases:
		if Tuning.layout_tier(sample[0], false, sample[1]) != sample[2]:
			push_error("Native form factor selected the wrong control layout")
			quit(1)
			return
	print("NATIVE_FORM_FACTOR_CHECKS=4 FAILURES=0")
	quit(0)
