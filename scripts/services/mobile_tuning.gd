class_name MobileTuning
extends RefCounted

const DESKTOP_CAMERA_ZOOM := Vector2(1.28, 1.28)
const DESKTOP_THREAT_CAMERA_ZOOM := Vector2(1.12, 1.12)
const MOBILE_CAMERA_ZOOM := Vector2(1.56, 1.56)
const MOBILE_THREAT_CAMERA_ZOOM := Vector2(1.36, 1.36)
const MOBILE_VIEWPORT_WIDTH_TRIGGER := 700.0

const META_FONT_BASE_PREFIX := "r14_font_base_"
const META_FONT_HAD_PREFIX := "r14_font_had_"
const META_FONT_APPLIED_PREFIX := "r14_font_applied_"


static func use_mobile_ui(viewport_size: Vector2, force_mobile: bool = false) -> bool:
	if force_mobile:
		return true
	var size := _safe_viewport_size(viewport_size)
	var short_side: float = min(size.x, size.y)
	var long_side: float = max(size.x, size.y)
	var portrait := size.y > size.x
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	if DisplayServer.has_method("is_touchscreen_available") and DisplayServer.call("is_touchscreen_available") == true:
		return true
	if size.x < MOBILE_VIEWPORT_WIDTH_TRIGGER:
		return true
	if short_side <= 520.0 and long_side <= 980.0:
		return true
	if portrait and size.x <= 760.0 and size.y <= 1400.0:
		return true
	return false


static func ui_scale(viewport_size: Vector2, force_mobile: bool = false) -> float:
	if not use_mobile_ui(viewport_size, force_mobile):
		return 1.0
	var size := _safe_viewport_size(viewport_size)
	var short_side: float = min(size.x, size.y)
	var portrait := size.y > size.x
	if short_side <= 430.0:
		return 1.96 if portrait else 1.86
	if size.x < MOBILE_VIEWPORT_WIDTH_TRIGGER:
		return 1.84
	if portrait:
		return 1.86
	return 1.8


static func spacing_scale(viewport_size: Vector2, force_mobile: bool = false) -> float:
	return 1.32 if use_mobile_ui(viewport_size, force_mobile) else 1.0


static func font_size(base_size: int, viewport_size: Vector2, force_mobile: bool = false) -> int:
	return maxi(base_size, int(round(float(base_size) * ui_scale(viewport_size, force_mobile))))


static func touch_target(viewport_size: Vector2, force_mobile: bool = false) -> float:
	if not use_mobile_ui(viewport_size, force_mobile):
		return 48.0
	var safe_size := _safe_viewport_size(viewport_size)
	var short_side: float = min(safe_size.x, safe_size.y)
	var portrait := safe_size.y > safe_size.x
	if short_side <= 430.0:
		return 76.0 if portrait else 68.0
	return 72.0


static func leader_camera_zoom(viewport_size: Vector2, force_mobile: bool = false) -> Vector2:
	return MOBILE_CAMERA_ZOOM if use_mobile_ui(viewport_size, force_mobile) else DESKTOP_CAMERA_ZOOM


static func leader_threat_camera_zoom(viewport_size: Vector2, force_mobile: bool = false) -> Vector2:
	return MOBILE_THREAT_CAMERA_ZOOM if use_mobile_ui(viewport_size, force_mobile) else DESKTOP_THREAT_CAMERA_ZOOM


static func apply_control_tree(root: Control, viewport_size: Vector2, force_mobile: bool = false) -> void:
	if root == null:
		return
	var mobile := use_mobile_ui(viewport_size, force_mobile)
	var scale := ui_scale(viewport_size, force_mobile)
	var min_touch := touch_target(viewport_size, force_mobile)
	_apply_control(root, scale, min_touch, mobile)


static func _apply_control(control: Control, scale: float, min_touch: float, mobile: bool) -> void:
	if control == null:
		return
	if control is RichTextLabel:
		_scale_font_key(control, "normal_font_size", 16, scale, mobile)
	elif control is Label or control is BaseButton or control is LineEdit:
		_scale_font_key(control, "font_size", 16, scale, mobile)

	if mobile:
		if control is BaseButton or control is LineEdit:
			control.custom_minimum_size.y = max(control.custom_minimum_size.y, min_touch)
		elif control is HSlider:
			control.custom_minimum_size.y = max(control.custom_minimum_size.y, min_touch * 0.72)

	for child in control.get_children():
		if child is Control:
			_apply_control(child as Control, scale, min_touch, mobile)


static func _scale_font_key(control: Control, key: String, fallback_size: int, scale: float, mobile: bool) -> void:
	var base_meta := META_FONT_BASE_PREFIX + key
	var had_meta := META_FONT_HAD_PREFIX + key
	var applied_meta := META_FONT_APPLIED_PREFIX + key
	var has_override := control.has_theme_font_size_override(key)
	var current_size := fallback_size
	if has_override:
		current_size = max(1, control.get_theme_font_size(key))

	if mobile:
		var should_capture := true
		if control.has_meta(applied_meta) and has_override:
			should_capture = int(control.get_meta(applied_meta)) != current_size
		if not control.has_meta(base_meta) or should_capture:
			control.set_meta(base_meta, current_size)
			control.set_meta(had_meta, has_override)
		var base_size := int(control.get_meta(base_meta))
		var scaled_size: int = max(base_size, int(round(float(base_size) * scale)))
		control.add_theme_font_size_override(key, scaled_size)
		control.set_meta(applied_meta, scaled_size)
		return

	if not control.has_meta(base_meta):
		return
	var restored_size := int(control.get_meta(base_meta))
	if bool(control.get_meta(had_meta)):
		control.add_theme_font_size_override(key, restored_size)
	else:
		control.remove_theme_font_size_override(key)
	control.remove_meta(base_meta)
	control.remove_meta(had_meta)
	if control.has_meta(applied_meta):
		control.remove_meta(applied_meta)


static func _safe_viewport_size(viewport_size: Vector2) -> Vector2:
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		return viewport_size
	var window_size := DisplayServer.window_get_size()
	if window_size.x > 0 and window_size.y > 0:
		return Vector2(window_size)
	return Vector2(1280.0, 720.0)
