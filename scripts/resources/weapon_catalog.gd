class_name WeaponCatalog
extends Resource

@export var starting_weapons: Array[Resource] = []
@export var available_weapons: Array[Resource] = []


func get_weapon_data(weapon_id: String) -> Resource:
	for weapon_data in available_weapons:
		if weapon_data != null and str(weapon_data.get("id")) == weapon_id:
			return weapon_data
	return null
