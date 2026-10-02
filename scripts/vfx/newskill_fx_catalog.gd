class_name NewSkillFxCatalog
extends RefCounted

const ATLAS_PATH := "res://assets/art/r35/r35_skill_fx_atlas.png"
const CELL_SIZE := 256
const FRAME_COUNT := 8
const ANIMATION := &"default"
const KINDS: Array[String] = ["slash_a", "slash_b", "cyclone", "critical_impact", "monster_fire", "monster_frost", "monster_shadow", "monster_bite"]
const LIFETIMES := {"slash_a": 0.24, "slash_b": 0.24, "cyclone": 0.32, "critical_impact": 0.28, "monster_fire": 0.28, "monster_frost": 0.28, "monster_shadow": 0.26, "monster_bite": 0.22}
const ALIASES := {"gold_slash_a": "slash_a", "gold_slash_b": "slash_b", "gold_cyclone": "cyclone", "goldwhite_critical_impact": "critical_impact", "critical": "critical_impact", "fire": "monster_fire", "frost": "monster_frost", "shadow": "monster_shadow", "bite": "monster_bite", "physical": "monster_bite"}

static var _atlas: Texture2D = null
static var _texture_frames: Dictionary = {}
static var _sprite_frames: Dictionary = {}


static func get_kind_ids() -> Array[String]:
	return KINDS.duplicate()


static func get_frame_textures(kind: String) -> Array[Texture2D]:
	var id := _resolve_kind(kind)
	if _texture_frames.has(id):
		return _texture_frames[id]
	var atlas := _get_atlas()
	var result: Array[Texture2D] = []
	if atlas == null:
		return result
	var row := KINDS.find(id)
	for frame in range(FRAME_COUNT):
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(frame * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		texture.filter_clip = true
		result.append(texture)
	_texture_frames[id] = result
	return result


static func get_frames(kind: String) -> SpriteFrames:
	var id := _resolve_kind(kind)
	if _sprite_frames.has(id):
		return _sprite_frames[id]
	var textures := get_frame_textures(id)
	var frames := SpriteFrames.new()
	frames.set_animation_loop(ANIMATION, get_loop(id))
	frames.set_animation_speed(ANIMATION, float(FRAME_COUNT) / get_lifetime(id))
	for texture in textures:
		frames.add_frame(ANIMATION, texture)
	# Do not cache an empty placeholder during editor import / asset preparation.
	if textures.size() == FRAME_COUNT:
		_sprite_frames[id] = frames
	return frames


static func get_lifetime(kind: String) -> float:
	return float(LIFETIMES[_resolve_kind(kind)])


static func get_loop(kind: String) -> bool:
	return _resolve_kind(kind) == "cyclone"


static func get_release_lifetime(kind: String) -> float:
	return 0.10 if get_loop(kind) else 0.0


static func get_frame_count(_kind: String = "") -> int:
	return FRAME_COUNT


static func _resolve_kind(kind: String) -> String:
	var id := str(ALIASES.get(kind, kind))
	return id if id in KINDS else "critical_impact"


static func _get_atlas() -> Texture2D:
	if _atlas != null:
		return _atlas
	if ResourceLoader.exists(ATLAS_PATH):
		_atlas = load(ATLAS_PATH) as Texture2D
	elif FileAccess.file_exists(ATLAS_PATH):
		var pixels := Image.load_from_file(ATLAS_PATH)
		if pixels != null and not pixels.is_empty():
			_atlas = ImageTexture.create_from_image(pixels)
	return _atlas
