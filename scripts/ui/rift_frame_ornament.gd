extends Control

# Crackveil's own frame language: carved rift-stone corners, a gold seal on the
# top edge and short fissure notches. It only draws over the parent's existing
# StyleBox, ignores input and never changes the parent's layout or hit area.
const GOLD := Color("d9b46a")
const TEAL := Color("6fc4cf")
const INK := Color("07101c")

@export var seal := true
@export var accent := TEAL
@export var corner := 18.0

static func attach(parent: Control, with_seal: bool = true, accent_color: Color = TEAL, corner_size: float = 18.0) -> Control:
	var existing := parent.get_node_or_null("RiftFrameOrnament") as Control
	if existing != null:
		return existing
	var ornament: Control = load("res://scripts/ui/rift_frame_ornament.gd").new()
	ornament.name = "RiftFrameOrnament"
	ornament.seal = with_seal
	ornament.accent = accent_color
	ornament.corner = corner_size
	parent.add_child(ornament)
	return ornament

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	resized.connect(queue_redraw)

func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	if box.size.x < corner * 3 or box.size.y < corner * 2:
		return
	var c := minf(corner, minf(box.size.x, box.size.y) * 0.3)
	# Carved corner brackets with a rune diamond at each corner.
	for point in [box.position, Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), box.end]:
		var sx: float = 1.0 if point.x == box.position.x else -1.0
		var sy: float = 1.0 if point.y == box.position.y else -1.0
		var inset: Vector2 = point + Vector2(sx * 3, sy * 3)
		var bracket := PackedVector2Array([inset + Vector2(sx * c, 0), inset, inset + Vector2(0, sy * c)])
		draw_polyline(bracket, INK, 5, true)
		draw_polyline(bracket, GOLD, 2, true)
		var rune: Vector2 = inset + Vector2(sx * 6, sy * 6)
		draw_colored_polygon(PackedVector2Array([rune + Vector2(0, -4), rune + Vector2(3, 0), rune + Vector2(0, 4), rune + Vector2(-3, 0)]), accent)
	# Fissure notches along the long edges.
	if box.size.x > 220:
		for f in [0.28, 0.72]:
			var x: float = box.size.x * f
			draw_polyline(PackedVector2Array([Vector2(x - 6, box.end.y - 1), Vector2(x - 1, box.end.y - 6), Vector2(x + 3, box.end.y - 2), Vector2(x + 7, box.end.y - 7)]), Color(accent, 0.75), 1.5, true)
	# Gold seal on the top edge: the same diamond as the battlefield seals.
	if seal and box.size.x > 160:
		var center := Vector2(box.size.x * 0.5, 1)
		var r := 7.0
		var diamond := PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0), center + Vector2(0, -r)])
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)]), INK)
		draw_polyline(diamond, GOLD, 2, true)
		draw_line(center + Vector2(-r - 22, 0), center + Vector2(-r - 4, 0), GOLD, 1.5, true)
		draw_line(center + Vector2(r + 4, 0), center + Vector2(r + 22, 0), GOLD, 1.5, true)
