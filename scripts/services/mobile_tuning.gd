class_name MobileTuning
extends RefCounted

const DESKTOP_CAMERA_ZOOM := Vector2(1.28, 1.28)
const DESKTOP_THREAT_CAMERA_ZOOM := Vector2(1.12, 1.12)
const MOBILE_CAMERA_ZOOM := Vector2(1.56, 1.56)
const MOBILE_THREAT_CAMERA_ZOOM := Vector2(1.36, 1.36)
const MOBILE_VIEWPORT_WIDTH_TRIGGER := 700.0
const TABLET_SHORT_SIDE_MAX := 1100.0
const DESKTOP_VIEWPORT_WIDTH_TRIGGER := 1100.0
const TABLET_UI_SCALE := 1.25
const TABLET_SPACING_SCALE := 1.12
const TABLET_TOUCH_TARGET := 44.0
const SEED_ROW_MAX_WIDTH := 400.0
const BASE_CONTAINER_SEPARATION := 12.0
const BASE_CHECKBOX_TEXT_SEPARATION := 10.0
const FORCE_MOBILE_LOD_SETTING := "crackveil/debug/force_mobile_lod"
const MOBILE_LOD_PARTICLE_MULTIPLIER := 0.6
const MOBILE_BACKGROUND_DYNAMIC_MULTIPLIER := 0.6
const MOBILE_BACKGROUND_DECOR_MULTIPLIER := 0.72
const MOBILE_DAMAGE_NUMBER_MERGE_RADIUS := 82.0
const MOBILE_DAMAGE_NUMBER_MERGE_AGE := 0.34
const MOBILE_DAMAGE_NUMBER_CAP := 30
const MOBILE_HAZARD_VISUAL_REDRAW_MULTIPLIER := 1.55
const MOBILE_CORPSE_GHOST_CAP := 12
const MOBILE_DEATH_BURST_CAP := 8
const MOBILE_VFX_COMPOSITE_LAYERS := 2
const DESKTOP_VFX_COMPOSITE_LAYERS := 3
const DESKTOP_VFX_FEATURE_LAYERS := 4
const VFX_HIGH_CROWD_THRESHOLD := 120
const VFX_HIGH_BURST_THRESHOLD := 12
const MOBILE_JOYSTICK_HEAT_ZONE_MULTIPLIER := 1.24

const META_FONT_BASE_PREFIX := "r14_font_base_"
const META_FONT_HAD_PREFIX := "r14_font_had_"
const META_FONT_APPLIED_PREFIX := "r14_font_applied_"
const META_MIN_HEIGHT_BASE := "formfactor_min_height_base"
const META_MIN_HEIGHT_APPLIED := "formfactor_min_height_applied"

enum LayoutTier {
	PHONE,
	TABLET,
	DESKTOP
}

static var _device_hints_override: Dictionary = {}


static func set_device_hints_override_for_tests(device_hints: Dictionary = {}) -> void:
	_device_hints_override = device_hints.duplicate(true)


static func layout_tier(viewport_size: Vector2, force_phone: bool = false, device_hints: Dictionary = {}) -> int:
	if force_phone:
		return LayoutTier.PHONE
	var size := ui_layout_size(viewport_size)
	var short_side: float = min(size.x, size.y)
	var hints := device_hints if not device_hints.is_empty() else _runtime_device_hints()
	var handset_ua := bool(hints.get("ua_phone", false)) or (bool(hints.get("ua_mobile", false)) and not bool(hints.get("ua_tablet", false)))
	if short_side < MOBILE_VIEWPORT_WIDTH_TRIGGER or handset_ua:
		return LayoutTier.PHONE
	if short_side >= TABLET_SHORT_SIDE_MAX or (size.x >= DESKTOP_VIEWPORT_WIDTH_TRIGGER and not bool(hints.get("ua_tablet", false))):
		return LayoutTier.DESKTOP
	var touch_available := bool(hints.get("touch_available", false)) or bool(hints.get("mobile_os", false))
	return LayoutTier.TABLET if touch_available else LayoutTier.DESKTOP


static func layout_tier_name(viewport_size: Vector2, force_phone: bool = false, device_hints: Dictionary = {}) -> String:
	match layout_tier(viewport_size, force_phone, device_hints):
		LayoutTier.PHONE:
			return "phone"
		LayoutTier.TABLET:
			return "tablet"
		_:
			return "desktop"


static func use_mobile_ui(viewport_size: Vector2, force_mobile: bool = false, device_hints: Dictionary = {}) -> bool:
	return layout_tier(viewport_size, force_mobile, device_hints) == LayoutTier.PHONE


static func use_tablet_ui(viewport_size: Vector2, device_hints: Dictionary = {}) -> bool:
	return layout_tier(viewport_size, false, device_hints) == LayoutTier.TABLET


static func ui_layout_size(viewport_size: Vector2) -> Vector2:
	var size := _safe_viewport_size(viewport_size)
	if OS.has_feature("web"):
		var window_size := DisplayServer.window_get_size()
		if window_size.x > 0 and window_size.y > 0:
			return Vector2(window_size)
	return size


static func apply_web_canvas_scale(layer: CanvasLayer, viewport_size: Vector2, root: Control = null) -> Vector2:
	var layout_size := ui_layout_size(viewport_size)
	if layer == null or not OS.has_feature("web"):
		return layout_size
	var safe_viewport := _safe_viewport_size(viewport_size)
	var scale_factor: float = safe_viewport.x / maxf(1.0, layout_size.x)
	layer.scale = Vector2.ONE * scale_factor
	layer.offset = Vector2.ZERO
	if root != null:
		root.set_anchors_preset(Control.PRESET_TOP_LEFT)
		root.position = Vector2.ZERO
		root.size = layout_size
	return layout_size


static func ui_scale(viewport_size: Vector2, force_mobile: bool = false, device_hints: Dictionary = {}) -> float:
	var tier := layout_tier(viewport_size, force_mobile, device_hints)
	if tier == LayoutTier.DESKTOP:
		return 1.0
	if tier == LayoutTier.TABLET:
		return TABLET_UI_SCALE
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


static func spacing_scale(viewport_size: Vector2, force_mobile: bool = false, device_hints: Dictionary = {}) -> float:
	match layout_tier(viewport_size, force_mobile, device_hints):
		LayoutTier.PHONE:
			return 1.32
		LayoutTier.TABLET:
			return TABLET_SPACING_SCALE
		_:
			return 1.0


static func font_size(base_size: int, viewport_size: Vector2, force_mobile: bool = false, device_hints: Dictionary = {}) -> int:
	return maxi(base_size, int(round(float(base_size) * ui_scale(viewport_size, force_mobile, device_hints))))


static func touch_target(viewport_size: Vector2, force_mobile: bool = false, device_hints: Dictionary = {}) -> float:
	var tier := layout_tier(viewport_size, force_mobile, device_hints)
	if tier == LayoutTier.DESKTOP:
		return 48.0
	if tier == LayoutTier.TABLET:
		return TABLET_TOUCH_TARGET
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


static func should_show_virtual_joystick(viewport_size: Vector2, force_visible: bool = false, device_hints: Dictionary = {}) -> bool:
	if force_visible:
		return true
	var hints := device_hints if not device_hints.is_empty() else _runtime_device_hints()
	var touch_available := bool(hints.get("touch_available", false)) or bool(hints.get("mobile_os", false))
	if not touch_available:
		return false
	var tier := layout_tier(viewport_size, false, hints)
	if tier != LayoutTier.DESKTOP:
		return true
	return not _has_explicit_desktop_input(hints)


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


static func battlefield_color_modulate(viewport_size: Vector2, force_mobile: bool = false) -> Color:
	return Color(0.82, 0.86, 0.98, 1.0) if use_mobile_ui(viewport_size, force_mobile) else Color.WHITE


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


static func vfx_composite_layer_count(viewport_size: Vector2, force_mobile: bool = false, live_enemy_count: int = 0, live_burst_count: int = 0, preserve_feature_layers: bool = false) -> int:
	# Mobile keeps only silhouette + impact ring. Desktop feature deaths may retain
	# debris, while routine effects shed additive layers as the arena fills.
	if mobile_lod_enabled(viewport_size, force_mobile):
		return MOBILE_VFX_COMPOSITE_LAYERS
	if preserve_feature_layers:
		return DESKTOP_VFX_FEATURE_LAYERS
	if live_enemy_count >= VFX_HIGH_CROWD_THRESHOLD or live_burst_count >= VFX_HIGH_BURST_THRESHOLD:
		return MOBILE_VFX_COMPOSITE_LAYERS
	return DESKTOP_VFX_COMPOSITE_LAYERS


static func leader_camera_zoom(viewport_size: Vector2, force_mobile: bool = false) -> Vector2:
	return MOBILE_CAMERA_ZOOM if use_mobile_ui(viewport_size, force_mobile) else DESKTOP_CAMERA_ZOOM


static func leader_threat_camera_zoom(viewport_size: Vector2, force_mobile: bool = false) -> Vector2:
	return MOBILE_THREAT_CAMERA_ZOOM if use_mobile_ui(viewport_size, force_mobile) else DESKTOP_THREAT_CAMERA_ZOOM


static func apply_control_tree(root: Control, viewport_size: Vector2, force_mobile: bool = false, device_hints: Dictionary = {}) -> void:
	if root == null:
		return
	var tier := layout_tier(viewport_size, force_mobile, device_hints)
	var scaled_layout := tier != LayoutTier.DESKTOP
	var scale := ui_scale(viewport_size, force_mobile, device_hints)
	var min_touch := touch_target(viewport_size, force_mobile, device_hints)
	var layout_spacing := spacing_scale(viewport_size, force_mobile, device_hints)
	_apply_control(root, scale, min_touch, layout_spacing, scaled_layout)


static func _apply_control(control: Control, scale: float, min_touch: float, layout_spacing: float, scaled_layout: bool) -> void:
	if control == null:
		return
	if control is RichTextLabel:
		_scale_font_key(control, "normal_font_size", 16, scale, scaled_layout)
	elif control is Label or control is BaseButton or control is LineEdit:
		_scale_font_key(control, "font_size", 16, scale, scaled_layout)

	if control is BoxContainer:
		var box_gap := maxi(control.get_theme_constant("separation"), int(ceil(BASE_CONTAINER_SEPARATION * layout_spacing)))
		control.add_theme_constant_override("separation", box_gap)
	elif control is GridContainer:
		var grid_gap := maxi(int(ceil(BASE_CONTAINER_SEPARATION * layout_spacing)), control.get_theme_constant("h_separation"))
		control.add_theme_constant_override("h_separation", grid_gap)
		control.add_theme_constant_override("v_separation", maxi(grid_gap, control.get_theme_constant("v_separation")))

	if control is CheckBox:
		var checkbox_gap := maxi(control.get_theme_constant("h_separation"), int(ceil(BASE_CHECKBOX_TEXT_SEPARATION * layout_spacing)))
		control.add_theme_constant_override("h_separation", checkbox_gap)

	if control is BaseButton or control is LineEdit:
		_apply_minimum_height(control, min_touch, scaled_layout)
	elif control is HSlider:
		_apply_minimum_height(control, min_touch * 0.72, scaled_layout)

	for child in control.get_children():
		if child is Control:
			_apply_control(child as Control, scale, min_touch, layout_spacing, scaled_layout)


static func _apply_minimum_height(control: Control, minimum_height: float, scaled_layout: bool) -> void:
	var current_height := control.custom_minimum_size.y
	if scaled_layout:
		var should_capture := not control.has_meta(META_MIN_HEIGHT_BASE)
		if control.has_meta(META_MIN_HEIGHT_APPLIED):
			should_capture = absf(float(control.get_meta(META_MIN_HEIGHT_APPLIED)) - current_height) > 0.01
		if should_capture:
			control.set_meta(META_MIN_HEIGHT_BASE, current_height)
		var applied_height := maxf(float(control.get_meta(META_MIN_HEIGHT_BASE)), minimum_height)
		control.custom_minimum_size.y = applied_height
		control.set_meta(META_MIN_HEIGHT_APPLIED, applied_height)
		return
	if control.has_meta(META_MIN_HEIGHT_BASE):
		var restored_height := float(control.get_meta(META_MIN_HEIGHT_BASE))
		if control.has_meta(META_MIN_HEIGHT_APPLIED) and absf(float(control.get_meta(META_MIN_HEIGHT_APPLIED)) - current_height) > 0.01:
			restored_height = current_height
		control.custom_minimum_size.y = restored_height
		control.remove_meta(META_MIN_HEIGHT_BASE)
	if control.has_meta(META_MIN_HEIGHT_APPLIED):
		control.remove_meta(META_MIN_HEIGHT_APPLIED)


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
	var responsive_override_supplied := control.has_meta(applied_meta) and has_override and int(control.get_meta(applied_meta)) != current_size
	if responsive_override_supplied:
		control.add_theme_font_size_override(key, current_size)
	elif bool(control.get_meta(had_meta)):
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


static func _has_explicit_desktop_input(hints: Dictionary) -> bool:
	return not bool(hints.get("touch_available", false)) and not bool(hints.get("mobile_os", false)) and not bool(hints.get("ua_mobile", false)) and bool(hints.get("mouse_available", true))


static func _runtime_device_hints() -> Dictionary:
	if not _device_hints_override.is_empty():
		return _device_hints_override
	var mobile_os := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	var touch_available := false
	if DisplayServer.has_method("is_touchscreen_available"):
		touch_available = DisplayServer.call("is_touchscreen_available") == true
	var ua_mobile := false
	var ua_phone := false
	var ua_tablet := false
	var mouse_available := not mobile_os
	if OS.has_feature("web"):
		var web_hints: Variant = JavaScriptBridge.eval("(()=>{const ua=navigator.userAgent||'';return {uaMobile:/Android|webOS|iPhone|iPad|iPod|IEMobile|Opera Mini|Mobile/i.test(ua),uaPhone:/iPhone|iPod|IEMobile|Opera Mini|Android.+Mobile|webOS.+Mobile/i.test(ua),uaTablet:/iPad|Tablet|Android(?!.*Mobile)/i.test(ua),touch:(navigator.maxTouchPoints||0)>0,mouse:!!(window.matchMedia&&window.matchMedia('(any-pointer: fine)').matches)}})()", true)
		if web_hints is JavaScriptObject:
			var web_object := web_hints as JavaScriptObject
			ua_mobile = bool(web_object.uaMobile)
			ua_phone = bool(web_object.uaPhone)
			ua_tablet = bool(web_object.uaTablet)
			touch_available = touch_available or bool(web_object.touch)
			mouse_available = bool(web_object.mouse)
	return {
		"mobile_os": mobile_os,
		"ua_mobile": ua_mobile,
		"ua_phone": ua_phone,
		"ua_tablet": ua_tablet,
		"touch_available": touch_available,
		"mouse_available": mouse_available
	}
