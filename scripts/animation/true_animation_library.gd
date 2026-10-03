class_name TrueAnimationLibrary
extends RefCounted

const ATLAS_PATH := "res://assets/sprites/r35_character_atlas.png"
const CELL_SIZE := 128
const ATLAS_COLUMNS := 16
const STATE_ORDER: Array[StringName] = [&"idle", &"walk", &"attack", &"hurt", &"death"]
const FRAME_COUNTS := {
	&"idle": 4,
	&"walk": 8,
	&"attack": 6,
	&"hurt": 3,
	&"death": 6,
}
const STATE_FRAME_OFFSETS := {
	&"idle": 0,
	&"walk": 4,
	&"attack": 12,
	&"hurt": 18,
	&"death": 21,
}
const FRAMES_PER_CHARACTER := 27
const CAPTAIN_COMBO_CELL_SIZE := 160
const CAPTAIN_COMBO_COLUMNS := 12
const CAPTAIN_COMBO_ORIGIN_Y := 3712
const CAPTAIN_COMBO_NAMES: Array[StringName] = [&"attack_combo_a", &"attack_combo_b", &"attack_combo_finisher"]
const STATE_FPS := {
	&"idle": 4.0,
	&"walk": 10.0,
	&"attack": 12.0,
	&"hurt": 12.0,
	&"death": 10.0,
}
const CHARACTER_INDEX := {
	"hero_captain": 0,
	"hero_rift_sniper": 1,
	"hero_void_weaver": 2,
	"hero_arc_scout": 3,
	"hero_echo_singer": 4,
	"hero_ember_grenadier": 5,
	"hero_line_mender": 6,
	"hero_orbit_guard": 7,
	"hero_pulse_artificer": 8,
	"hero_shepherd": 9,
	"enemy_grunt": 10,
	"enemy_fast": 11,
	"enemy_tank": 12,
	"enemy_elite_field": 13,
	"enemy_elite_split": 14,
	"enemy_elite_swift": 15,
	"enemy_boss": 16,
}
const EXTERNAL_ATLAS_PATH := "res://assets/sprites/r38_character_atlas.png"
const EXTERNAL_CHARACTER_INDEX := {
	"hero_solar_lancer": 0,
	"hero_tide_oracle": 1,
	"hero_shadow_ronin": 2,
	"enemy_dune_scarab": 3,
	"enemy_sand_stalker": 4,
	"enemy_tide_siren": 5,
	"enemy_coral_colossus": 6,
	"enemy_bloom_wisp": 7,
	"enemy_clockwork_reaper": 8,
}

static var _atlas: Texture2D = null
static var _external_atlas: Texture2D = null
static var _frames_cache: Dictionary = {}


static func character_id_from_sprite_path(sprite_path: String) -> String:
	return sprite_path.get_file().get_basename()


static func has_character(sprite_path: String) -> bool:
	var character_id := character_id_from_sprite_path(sprite_path)
	return CHARACTER_INDEX.has(character_id) or EXTERNAL_CHARACTER_INDEX.has(character_id)


static func get_sprite_frames(sprite_path: String) -> SpriteFrames:
	var character_id := character_id_from_sprite_path(sprite_path)
	var external: bool = EXTERNAL_CHARACTER_INDEX.has(character_id)
	if not CHARACTER_INDEX.has(character_id) and not external:
		push_error("True animation atlas has no character '%s'" % character_id)
		return null
	if _frames_cache.has(character_id):
		return _frames_cache[character_id] as SpriteFrames
	if external and _external_atlas == null:
		_external_atlas = load(EXTERNAL_ATLAS_PATH) as Texture2D
	elif not external and _atlas == null:
		_atlas = load(ATLAS_PATH) as Texture2D
	var character_atlas := _external_atlas if external else _atlas
	if character_atlas == null:
		push_error("Missing true animation atlas: %s" % (EXTERNAL_ATLAS_PATH if external else ATLAS_PATH))
		return null
	var character_index: int = int(EXTERNAL_CHARACTER_INDEX[character_id] if external else CHARACTER_INDEX[character_id])

	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	for state_index in range(STATE_ORDER.size()):
		var state: StringName = STATE_ORDER[state_index]
		frames.add_animation(state)
		frames.set_animation_loop(state, state == &"idle" or state == &"walk")
		frames.set_animation_speed(state, 18.0 if character_id == "hero_captain" and state == &"attack" else float(STATE_FPS[state]))
		for frame_index in range(int(FRAME_COUNTS[state])):
			var atlas_cell: int = character_index * FRAMES_PER_CHARACTER + int(STATE_FRAME_OFFSETS[state]) + frame_index
			var frame_texture := AtlasTexture.new()
			frame_texture.atlas = character_atlas
			frame_texture.region = Rect2((atlas_cell % ATLAS_COLUMNS) * CELL_SIZE, (atlas_cell / ATLAS_COLUMNS) * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			frames.add_frame(state, frame_texture)
	if character_id == "hero_captain":
		for combo_index in range(CAPTAIN_COMBO_NAMES.size()):
			var combo_name := CAPTAIN_COMBO_NAMES[combo_index]
			frames.add_animation(combo_name)
			frames.set_animation_loop(combo_name, false)
			frames.set_animation_speed(combo_name, 18.0)
			for frame_index in range(6):
				var cell := combo_index * 6 + frame_index
				var frame_texture := AtlasTexture.new()
				frame_texture.atlas = _atlas
				frame_texture.region = Rect2((cell % CAPTAIN_COMBO_COLUMNS) * CAPTAIN_COMBO_CELL_SIZE, CAPTAIN_COMBO_ORIGIN_Y + (cell / CAPTAIN_COMBO_COLUMNS) * CAPTAIN_COMBO_CELL_SIZE, CAPTAIN_COMBO_CELL_SIZE, CAPTAIN_COMBO_CELL_SIZE)
				frames.add_frame(combo_name, frame_texture)
	_frames_cache[character_id] = frames
	return frames


static func get_shared_atlas_instance_id() -> int:
	if _atlas == null:
		_atlas = load(ATLAS_PATH) as Texture2D
	return 0 if _atlas == null else int(_atlas.get_instance_id())


static func get_external_atlas_instance_id() -> int:
	if _external_atlas == null:
		_external_atlas = load(EXTERNAL_ATLAS_PATH) as Texture2D
	return 0 if _external_atlas == null else int(_external_atlas.get_instance_id())


static func clear_cache_for_tests() -> void:
	_frames_cache.clear()
	_atlas = null
	_external_atlas = null
