class_name BattleLayout
extends RefCounted

# One CSS-space contract shared by HUD, combo, notices and minimap.
static func regions(view: Vector2, phone: bool) -> Dictionary:
	var top := MobileTuning.safe_top_padding(view) if phone else 0.0
	var portrait := view.y > view.x
	if portrait:
		var score_width := minf(100, maxf(64, view.x - 278)) if phone else 140.0
		return {
			"stats": Rect2(10, top + 8, minf(190, view.x - 148), 52),
			"score": Rect2(view.x - score_width - 64, top + 8, score_width, 44 if phone else 52),
			"pause": Rect2(view.x - 56, top + 8, 44, 44),
			"time": Rect2(10, top + 70, 80, 36),
			"mission": Rect2(100, top + 68, view.x - 110, 56),
			"combo": Rect2(10, top + 132, minf(260, view.x - 100), 56),
			"notice": Rect2(10, top + 190, view.x - 100, 72),
			"minimap": Rect2(view.x - 80, top + 132, 68, 88)
		}
	var status_width := 202.0 if view.x < 1000 else 250.0
	var mission_x := status_width + 110.0
	var tail_width := 100.0 if phone else 140.0
	return {
		"stats": Rect2(10, top + 8, status_width, 52),
		"score": Rect2(view.x - tail_width - 64, top + 8, tail_width, 44 if phone else 52),
		"pause": Rect2(view.x - 56, top + 8, 44, 44),
		"time": Rect2(status_width + 20, top + 10, 80, 36),
		"mission": Rect2(mission_x, top + 8, view.x - mission_x - (174 if phone else 214), 52),
		"combo": Rect2(10, top + 68, status_width, 56),
		"notice": Rect2(status_width + 20, top + 68, minf(460, view.x - status_width - 112), 64),
		"minimap": Rect2(view.x - 80, top + 70, 68, 88)
	}

static func place(control: Control, rect: Rect2) -> void:
	# Reset all anchors before assigning coordinates; portrait score anchors
	# previously survived into the compact layout and covered the HP number.
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size
