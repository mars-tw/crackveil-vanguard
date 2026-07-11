class_name MobileTuning
extends RefCounted

const DESKTOP_CAMERA_ZOOM := Vector2(1.28, 1.28)
const DESKTOP_THREAT_CAMERA_ZOOM := Vector2(1.12, 1.12)
const MOBILE_CAMERA_ZOOM := Vector2(1.56, 1.56)
const MOBILE_THREAT_CAMERA_ZOOM := Vector2(1.36, 1.36)
const MOBILE_VIEWPORT_WIDTH_TRIGGER := 700.0
const FORCE_MOBILE_LOD_SETTING := "crackveil/debug/force_mobile_lod"
const MOBILE_LOD_PARTICLE_MULTIPLIER := 0.6
const MOBILE_BACKGROUND_DYNAMIC_MULTIPLIER := 0.6
const MOBILE_BACKGROUND_DECOR_MULTIPLIER := 0.72
const MOBILE_DAMAGE_NUMBER_MERGE_RADIUS := 82.0
const MOBILE_DAMAGE_NUMBER_MERGE_AGE := 0.34
const MOBILE_DAMAGE_NUMBER_CAP := 30
const MOBILE_HAZARD_VISUAL_REDRAW_MULTIPLIER := 1.55
const MOBILE_CORPSE_GHOST_CAP := 12
const MOBILE_DEATH_BURST_CAP := 12
const MOBILE_JOYSTICK_HEAT_ZONE_MULTIPLIER := 1.24

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


static func safe_top_padding(viewport_size: Vector2, force_mobile: bool = false) -> float:
	if not use_mobile_ui(viewport_size, force_mobile):
		return 0.0
	var size := _safe_viewport_size(viewport_size)
	var portrait := size.y > size.x
	if portrait and size.x <= 430.0:
		return 26.0
	return 16.0 if portrait else 10.0


static func safe_bottom_padding(viewport_size: Vector2, force_mobile: bool = false) -> float:
	if not use_mobile_ui(viewport_size, force_mobile):
		return 0.0
	var size := _safe_viewport_size(viewport_size)
	return 10.0 if size.y > size.x else 6.0


static func ability_button_size(viewport_size: Vector2, force_mobile: bool = false) -> float:
	if not use_mobile_ui(viewport_size, force_mobile):
		return 68.0 if _safe_viewport_size(viewport_size).y > _safe_viewport_size(viewport_size).x else 62.0
	var size := _safe_viewport_size(viewport_size)
	return 92.0 if size.y > size.x else 84.0


static func ability_button_position(viewport_size: Vector2, force_mobile: bool = false) -> Vector2:
	var size := _safe_viewport_size(viewport_size)
	var button_size := ability_button_size(size, force_mobile)
	if not use_mobile_ui(size, force_mobile):
		var desktop_bottom := 34.0 if size.y > size.x else 28.0
		return Vector2(size.x - button_size - 24.0, size.y - button_size - desktop_bottom)
	var portrait := size.y > size.x
	var right_margin := 22.0 if portrait else 20.0
	var bottom_margin := safe_bottom_padding(size, force_mobile) + (24.0 if portrait else 18.0)
	return Vector2(size.x - button_size - right_margin, size.y - button_size - bottom_margin)


static func joystick_margin(viewport_size: Vector2, joystick_size: Vector2, force_mobile: bool = false) -> Vector2:
	var size := _safe_viewport_size(viewport_size)
	if not use_mobile_ui(size, force_mobile):
		var desktop_margin: float = max(14.0, joystick_size.x * 0.08)
		return Vector2(desktop_margin, desktop_margin)
	var portrait := size.y > size.x
	return Vector2(18.0 if portrait else 16.0, safe_bottom_padding(size, force_mobile) + (18.0 if portrait else 14.0))


static func joystick_rect(viewport_size: Vector2, joystick_size: Vector2, force_mobile: bool = false) -> Rect2:
	var size := _safe_viewport_size(viewport_size)
	var margin := joystick_margin(size, joystick_size, force_mobile)
	return Rect2(Vector2(margin.x, size.y - joystick_size.y - margin.y), joystick_size)


static func ability_button_rect(viewport_size: Vector2, force_mobile: bool = false) -> Rect2:
	var size := _safe_viewport_size(viewport_size)
	var button_size := ability_button_size(size, force_mobile)
	return Rect2(ability_button_position(size, force_mobile), Vector2.ONE * button_size)


static func mobile_lod_enabled(viewport_size: Vector2, force_mobile: bool = false, device_hints: Dictionary = {}) -> bool:
	if bool(ProjectSettings.get_setting(FORCE_MOBILE_LOD_SETTING, false)):
		return true
	if force_mobile:
		return true
	return mobile_device_detected(device_hints)


static func mobile_device_detected(device_hints: Dictionary = {}) -> bool:
	var hints := device_hints if not device_hints.is_empty() else _runtime_device_hints()
	if bool(hints.get("mobile_os", false)) or bool(hints.get("ua_mobile", false)):
		return true
	return bool(hints.get("touch_available", false)) and not bool(hints.get("mouse_available", true))


static func set_force_mobile_lod_for_tests(enabled: bool) -> void:
	ProjectSettings.set_setting(FORCE_MOBILE_LOD_SETTING, enabled)


static func lod_particle_multiplier(viewport_size: Vector2, force_mobile: bool = false) -> float:
	return MOBILE_LOD_PARTICLE_MULTIPLIER if mobile_lod_enabled(viewport_size, force_mobile) else 1.0


static func background_dynamic_multiplier(viewport_size: Vector2, force_mobile: bool = false) -> float:
	return MOBILE_BACKGROUND_DYNAMIC_MULTIPLIER if mobile_lod_enabled(viewport_size, force_mobile) else 1.0


static func background_decor_multiplier(viewport_size: Vector2, force_mobile: bool = false) -> float:
	return MOBILE_BACKGROUND_DECOR_MULTIPLIER if mobile_lod_enabled(viewport_size, force_mobile) else 1.0


static func damage_number_merge_radius(viewport_size: Vector2, base_radius: float, active_count: int, cap: int, force_mobile: bool = false) -> float:
	var radius := base_radius
	if active_count >= cap:
		radius *= 2.4
	if mobile_lod_enabled(viewport_size, force_mobile):
		radius = max(radius, MOBILE_DAMAGE_NUMBER_MERGE_RADIUS)
		if active_count >= MOBILE_DAMAGE_NUMBER_CAP:
			radius *= 1.45
	return radius


static func damage_number_merge_age(viewport_size: Vector2, base_age: float, force_mobile: bool = false) -> float:
	return max(base_age, MOBILE_DAMAGE_NUMBER_MERGE_AGE) if mobile_lod_enabled(viewport_size, force_mobile) else base_age


static func damage_number_cap(viewport_size: Vector2, base_cap: int, force_mobile: bool = false) -> int:
	return min(base_cap, MOBILE_DAMAGE_NUMBER_CAP) if mobile_lod_enabled(viewport_size, force_mobile) else base_cap


static func damage_number_font_size(viewport_size: Vector2, requested_size: int = 0, force_mobile: bool = false) -> int:
	if not mobile_lod_enabled(viewport_size, force_mobile):
		return requested_size
	if requested_size > 0:
		return min(requested_size, 20)
	return 14


static func hazard_tick_interval(viewport_size: Vector2, base_interval: float, force_mobile: bool = false) -> float:
	# Gameplay cadence must be platform invariant. LOD may only change presentation.
	return max(0.01, base_interval)


static func hazard_visual_redraw_interval(viewport_size: Vector2, base_interval: float, force_mobile: bool = false) -> float:
	var safe_interval: float = max(0.01, base_interval)
	return safe_interval * MOBILE_HAZARD_VISUAL_REDRAW_MULTIPLIER if mobile_lod_enabled(viewport_size, force_mobile) else safe_interval


static func corpse_ghost_cap(viewport_size: Vector2, base_cap: int, force_mobile: bool = false) -> int:
	return min(base_cap, MOBILE_CORPSE_GHOST_CAP) if mobile_lod_enabled(viewport_size, force_mobile) else base_cap


static func death_burst_cap(viewport_size: Vector2, base_cap: int, force_mobile: bool = false) -> int:
	return min(base_cap, MOBILE_DEATH_BURST_CAP) if mobile_lod_enabled(viewport_size, force_mobile) else base_cap


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


static func _runtime_device_hints() -> Dictionary:
	var mobile_os := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	var touch_available := false
	if DisplayServer.has_method("is_touchscreen_available"):
		touch_available = DisplayServer.call("is_touchscreen_available") == true
	var ua_mobile := false
	var mouse_available := not mobile_os
	if OS.has_feature("web"):
		var web_hints: Variant = JavaScriptBridge.eval("({uaMobile:/Android|webOS|iPhone|iPad|iPod|IEMobile|Opera Mini|Mobile/i.test(navigator.userAgent||''),touch:(navigator.maxTouchPoints||0)>0,mouse:!!(window.matchMedia&&window.matchMedia('(any-pointer: fine)').matches)})", true)
		if web_hints is JavaScriptObject:
			var web_object := web_hints as JavaScriptObject
			ua_mobile = bool(web_object.uaMobile)
			touch_available = touch_available or bool(web_object.touch)
			mouse_available = bool(web_object.mouse)
	return {
		"mobile_os": mobile_os,
		"ua_mobile": ua_mobile,
		"touch_available": touch_available,
		"mouse_available": mouse_available
	}
