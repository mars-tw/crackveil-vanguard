extends RefCounted

const THEME_IDS := [
	"rift_void",
	"wasteland_farm",
	"ember_rift",
	"storm_isles",
	"star_frost",
	"veil_court",
	"sunken_dunes", "tidal_ruins", "moonbloom_grove", "clockwork_forge"
]

const THEME_NAMES: Dictionary = {
	"rift_void": "蒼月空庭",
	"wasteland_farm": "翠晶花園",
	"ember_rift": "緋星熔庭",
	"storm_isles": "風暴空島",
	"star_frost": "星霜冰庭",
	"veil_court": "帷幕王庭",
	"sunken_dunes": "曜砂王陵", "tidal_ruins": "珊潮遺都",
	"moonbloom_grove": "月華靈森", "clockwork_forge": "時輪工坊"
}


static func select_theme_id(run_seed: int) -> String:
	var count := THEME_IDS.size()
	if count <= 0:
		return ""
	var safe_seed: int = abs(run_seed)
	if safe_seed <= 0:
		safe_seed = 1
	return THEME_IDS[safe_seed % count]


static func get_theme_name(theme_id: String) -> String:
	return str(THEME_NAMES.get(theme_id, theme_id))


static func get_theme_name_for_seed(run_seed: int) -> String:
	return get_theme_name(select_theme_id(run_seed))


static func get_theme_ids() -> Array:
	return THEME_IDS.duplicate()
