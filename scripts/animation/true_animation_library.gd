class_name TrueAnimationLibrary
extends RefCounted

const ATLAS_PATH := "res://assets/sprites/true_character_atlas.png"
const CELL_SIZE := 64
const STATE_ORDER: Array[StringName] = [&"idle", &"walk", &"attack", &"hurt", &"death"]
const FRAME_COUNTS := {
	&"idle": 4,
	&"walk": 8,
	&"attack": 6,
	&"hurt": 3,
	&"death": 6,
}
const STATE_FPS := {
	&"idle": 4.0,
	&"walk": 10.0,
	&"attack": 12.0,
	&"hurt": 12.0,
	&"death": 10.0,
}
const CHARACTER_INDEX := {
	"hero_captain": 0,
	"hero_guardian": 1,
	"hero_scout": 2,
	"hero_shepherd": 3,
	"enemy_grunt": 4,
	"enemy_fast": 5,
	"enemy_tank": 6,
	"enemy_elite_field": 7,
	"enemy_elite_split": 8,
	"enemy_elite_swift": 9,
	"enemy_boss": 10,
}

static var _atlas: Texture2D = null
static var _frames_cache: Dictionary = {}


static func character_id_from_sprite_path(sprite_path: String) -> String:
	return sprite_path.get_file().get_basename()


static func has_character(sprite_path: String) -> bool:
	return CHARACTER_INDEX.has(character_id_from_sprite_path(sprite_path))


static func get_sprite_frames(sprite_path: String) -> SpriteFrames:
	var character_id := character_id_from_sprite_path(sprite_path)
	if not CHARACTER_INDEX.has(character_id):
		push_error("True animation atlas has no character '%s'" % character_id)
		return null
	if _frames_cache.has(character_id):
		return _frames_cache[character_id] as SpriteFrames
	if _atlas == null:
		_atlas = load(ATLAS_PATH) as Texture2D
	if _atlas == null:
		push_error("Missing true animation atlas: %s" % ATLAS_PATH)
		return null

	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	var base_row: int = int(CHARACTER_INDEX[character_id]) * STATE_ORDER.size()
	for state_index in range(STATE_ORDER.size()):
		var state: StringName = STATE_ORDER[state_index]
		frames.add_animation(state)
		frames.set_animation_loop(state, state == &"idle" or state == &"walk")
		frames.set_animation_speed(state, float(STATE_FPS[state]))
		for frame_index in range(int(FRAME_COUNTS[state])):
			var frame_texture := AtlasTexture.new()
			frame_texture.atlas = _atlas
			frame_texture.region = Rect2(frame_index * CELL_SIZE, (base_row + state_index) * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			frames.add_frame(state, frame_texture)
	_frames_cache[character_id] = frames
	return frames


static func get_shared_atlas_instance_id() -> int:
	if _atlas == null:
		_atlas = load(ATLAS_PATH) as Texture2D
	return 0 if _atlas == null else int(_atlas.get_instance_id())


static func clear_cache_for_tests() -> void:
	_frames_cache.clear()
	_atlas = null
