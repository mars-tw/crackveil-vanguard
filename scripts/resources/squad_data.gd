class_name SquadData
extends Resource

@export var max_members: int = 5
@export var starting_heroes: Array[Resource] = []
@export var available_heroes: Array[Resource] = []


func get_hero_data(hero_id: String) -> Resource:
	for hero_data in available_heroes:
		if hero_data != null and str(hero_data.get("id")) == hero_id:
			return hero_data
	return null
