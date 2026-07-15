class_name WebReachabilityProbe
extends RefCounted


static func publish(scope: String, viewport_size: Vector2, controls: Dictionary, flags: Dictionary = {}) -> void:
	if not OS.has_feature("web"):
		return
	var control_rows: Dictionary = {}
	for control_name in controls:
		var control := controls[control_name] as Control
		if control == null or not is_instance_valid(control):
			control_rows[control_name] = {"exists": false, "visible": false}
			continue
		var rect := control.get_global_rect()
		control_rows[control_name] = {
			"exists": true,
			"visible": control.is_visible_in_tree(),
			"x": rect.position.x,
			"y": rect.position.y,
			"width": rect.size.x,
			"height": rect.size.y,
			"center_x": rect.get_center().x,
			"center_y": rect.get_center().y
		}
	var payload := {
		"scope": scope,
		"viewport_width": viewport_size.x,
		"viewport_height": viewport_size.y,
		"controls": control_rows,
		"flags": flags,
		"timestamp_msec": Time.get_ticks_msec()
	}
	var script := "if(new URLSearchParams(window.location.search).get('cv_r19_test')==='1'){window.__cvR19Controls=window.__cvR19Controls||{};window.__cvR19Controls[%s]=%s;}" % [JSON.stringify(scope), JSON.stringify(payload)]
	JavaScriptBridge.eval(script, true)
