extends RefCounted

const THEME_IDS := [
	"rift_void",
	"wasteland_farm",
	"ember_rift"
]

const THEME_NAMES: Dictionary = {
	"rift_void": "裂隙虛空",
	"wasteland_farm": "廢土農野",
	"ember_rift": "餘燼裂原"
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
