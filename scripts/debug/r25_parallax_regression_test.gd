extends Node

const BACKGROUND_SCRIPT := preload("res://scripts/arena/arena_background.gd")
const THEMES: Array[String] = ["rift_void", "wasteland_farm", "ember_rift"]
const EXPECTED_SIZE := Vector2i(1536, 768)

var failed: bool = false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var background := BACKGROUND_SCRIPT.new()
	add_child(background)
	await get_tree().process_frame
	await get_tree().process_frame
	for theme in THEMES:
		background.configure_run_theme(25025, theme)
		await get_tree().process_frame
		background.debug_set_parallax_quality("high")
		if not _assert_quality(background, theme, "high", ["far", "mid", "near"]):
			return
		background.debug_set_parallax_quality("medium")
		if not _assert_quality(background, theme, "medium", ["far", "mid", "near"]):
			return
		background.debug_set_parallax_quality("low")
		if not _assert_quality(background, theme, "low", ["far", "mid"]):
			return

	var stack := background.get_node_or_null("R25ParallaxStack") as Node2D
	if stack == null or stack.get_child_count() != 3:
		_fail("visual parallax stack must contain exactly three independent layer roots")
		return
	for child in stack.get_children():
		if child is CollisionObject2D:
			_fail("parallax visual layer leaked into the physics/collider root")
			return
	background.debug_set_parallax_quality("high")
	background.call("_update_parallax_layers", Vector2(1200.0, 640.0))
	var far_position: Vector2 = (stack.get_node("Far") as Sprite2D).position
	var mid_position: Vector2 = (stack.get_node("Mid") as Sprite2D).position
	var near_position: Vector2 = (stack.get_node("Near") as Sprite2D).position
	if far_position == mid_position or mid_position == near_position or far_position == near_position:
		_fail("independent layers did not receive distinct parallax offsets")
		return
	print("R25_PARALLAX_REGRESSION themes=3 layers=9 quality=3/3/2 texture=1536x768 physics_root=separate")
	print("R25_PARALLAX_REGRESSION_PASS")
	get_tree().quit(0)


func _assert_quality(background: Node, theme: String, quality: String, expected_layers: Array[String]) -> bool:
	var state: Dictionary = background.get_mobile_lod_debug_state()
	if str(state.get("parallax_quality", "")) != quality:
		_fail("quality state mismatch for %s/%s" % [theme, quality])
		return false
	var visible_layers: Array = state.get("parallax_layers", [])
	if visible_layers != expected_layers:
		_fail("visible layer policy mismatch for %s/%s: %s" % [theme, quality, str(visible_layers)])
		return false
	var refs: Dictionary = state.get("parallax_runtime_refs", {})
	for layer_name in expected_layers:
		var runtime_ref := str(refs.get(layer_name, ""))
		if not runtime_ref.contains("?v=") or runtime_ref.length() < 12:
			_fail("content-hash query missing for %s/%s" % [theme, layer_name])
			return false
		var clean_path := runtime_ref.split("?", true, 1)[0]
		if not ResourceLoader.exists(clean_path):
			_fail("runtime asset missing for %s/%s" % [theme, layer_name])
			return false
		var sprite: Sprite2D = background.get_node("R25ParallaxStack/%s" % layer_name.capitalize())
		if sprite.texture == null or Vector2i(sprite.texture.get_width(), sprite.texture.get_height()) != EXPECTED_SIZE:
			_fail("runtime texture dimensions drifted for %s/%s" % [theme, layer_name])
			return false
	return true


func _fail(message: String) -> void:
	if failed:
		return
	failed = true
	printerr("R25_PARALLAX_REGRESSION_FAIL: " + message)
	get_tree().quit(1)
