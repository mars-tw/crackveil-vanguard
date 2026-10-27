extends NinePatchRect

# Crackveil's own frame: original vector nine-slices (assets/ui/r8_vector,
# made with MUSE) drawn over the parent's existing StyleBox. The centre of each
# frame is transparent; the overlay ignores input and never changes layout.
const TITLE_SAFE_LEFT := 46.0
const FRAMES := {
	"panel": {"texture": preload("res://assets/ui/r8_vector/panel_frame.svg"), "margin": 48},
	"card": {"texture": preload("res://assets/ui/r8_vector/card_frame.svg"), "margin": 24},
	"button": {"texture": preload("res://assets/ui/r8_vector/button_frame.svg"), "margin": 16},
}

@export var kind := "button"

# Kept signature: with_seal marks a large panel; a corner of 14 marks a card.
static func attach(parent: Control, with_seal: bool = true, accent_color: Color = Color.WHITE, corner_size: float = 18.0) -> Control:
	var existing := parent.get_node_or_null("RiftFrameOrnament") as Control
	if existing != null:
		return existing
	var ornament: NinePatchRect = load("res://scripts/ui/rift_frame_ornament.gd").new()
	ornament.name = "RiftFrameOrnament"
	ornament.kind = "panel" if with_seal else "card" if is_equal_approx(corner_size, 14.0) else "button"
	if ornament.kind == "card":
		ornament.self_modulate = Color.WHITE.lerp(accent_color, 0.25)
	parent.add_child(ornament)
	return ornament

static func title_safe_left() -> float:
	return TITLE_SAFE_LEFT

static func frame_kind_for(with_seal: bool, corner_size: float) -> String:
	return "panel" if with_seal else "card" if is_equal_approx(corner_size, 14.0) else "button"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	var frame: Dictionary = FRAMES.get(kind, FRAMES.button)
	texture = frame.texture
	var margin: int = int(frame.margin)
	patch_margin_left = margin
	patch_margin_top = margin
	patch_margin_right = margin
	patch_margin_bottom = margin
	draw_center = false
	axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
