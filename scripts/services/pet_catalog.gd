extends RefCounted

const ATLAS_PATH := "res://assets/pets/r36/pet_atlas.png"
const IDS: Array[String] = ["fire_fox", "thunder_bird", "spirit_rabbit"]
const MAX_STARS := 5
const STATES := {"idle": [0, 1], "walk": [2, 3, 4, 5], "attack": [6, 7, 8, 9], "hurt": [10], "death": [11]}
const PETS := {
	"fire_fox": {"id":"fire_fox", "name":"焰尾靈狐", "description":"每 2.4 秒吐出火球，命中時在 72 範圍內造成 28 傷害。", "role":"範圍火球", "cooldown":2.4, "damage":28.0, "range":470.0, "visual_scale":0.65, "color":Color("ffac62")},
	"thunder_bird": {"id":"thunder_bird", "name":"星雷羽鷹", "description":"每 2 秒連鎖 3 個目標，首擊 19 傷害、後續各保留 85%。", "role":"連鎖雷擊", "cooldown":2.0, "damage":19.0, "range":480.0, "visual_scale":0.65, "color":Color("79dfff")},
	"spirit_rabbit": {"id":"spirit_rabbit", "name":"翠玉靈兔", "description":"每 3 秒回復最低血量隊員 7 HP，吸引 210 範圍經驗；同時發出 16 傷害靈光。", "role":"回復與磁吸", "cooldown":3.0, "damage":16.0, "heal":7.0, "range":360.0, "visual_scale":0.46, "color":Color("90efcc")}
}
static var cached_frames: Dictionary = {}


static func get_pet(id: String) -> Dictionary:
	return PETS.get(id, {}).duplicate(true)


static func star_multiplier(stars: int) -> float:
	return 1.0 + 0.35 * float(clampi(stars, 1, MAX_STARS) - 1)


static func cooldown_multiplier(stars: int) -> float:
	return 1.0 / (1.0 + 0.08 * float(clampi(stars, 1, MAX_STARS) - 1))


static func get_frames(id: String) -> SpriteFrames:
	if cached_frames.has(id):
		return cached_frames[id]
	var family := IDS.find(id)
	if family < 0 or not ResourceLoader.exists(ATLAS_PATH):
		return null
	var atlas: Texture2D = load(ATLAS_PATH)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for state in STATES:
		frames.add_animation(state)
		frames.set_animation_loop(state, state in ["idle", "walk"])
		frames.set_animation_speed(state, 3.0 if state == "idle" else 10.0)
		for pose in STATES[state]:
			var cell := family * 12 + int(pose)
			var texture := AtlasTexture.new()
			texture.atlas = atlas
			texture.region = Rect2((cell % 6) * 128, (cell / 6) * 128, 128, 128)
			texture.filter_clip = true
			frames.add_frame(state, texture)
	cached_frames[id] = frames
	return frames


static func describe_stars(id: String, stars: int) -> String:
	var data := get_pet(id)
	if data.is_empty():
		return ""
	return "%d 星 · 傷害倍率 %.2f · 間隔 %.2f 秒" % [stars, star_multiplier(stars), float(data.cooldown) * cooldown_multiplier(stars)]
