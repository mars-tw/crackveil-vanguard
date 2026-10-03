extends RefCounted

# Every R38 creature has its own authored sprite identity and real behavior.
const CONFIGS: Dictionary = {
	"dune_scarab": {"name":"曜砂甲蟲", "max_hp":38.0, "speed":76.0, "damage":9.0, "xp":3, "gold":2, "radius":17.0, "color":Color("ebc783"), "sprite_path":"res://assets/sprites/enemy_dune_scarab.png", "sprite_scale":1.36, "weight":1.0, "min_time":0.0, "attack_cooldown":1.15},
	"sand_stalker": {"name":"砂影獵手", "max_hp":23.0, "speed":124.0, "damage":7.0, "xp":3, "gold":1, "radius":12.0, "color":Color("e8ad72"), "sprite_path":"res://assets/sprites/enemy_sand_stalker.png", "sprite_scale":1.32, "weight":0.7, "min_time":0.0, "behavior_id":"dasher", "attack_cooldown":1.4, "dash_trigger_range":190.0, "dash_windup":0.42, "dash_duration":0.22, "dash_recover":0.7, "dash_speed":390.0},
	"tide_siren": {"name":"深潮歌妖", "max_hp":30.0, "speed":61.0, "damage":6.0, "xp":3, "gold":2, "radius":13.0, "color":Color("8ad9eb"), "sprite_path":"res://assets/sprites/enemy_tide_siren.png", "sprite_scale":1.32, "weight":0.8, "min_time":0.0, "behavior_id":"biome_skill", "biome_skill":"tide_bolts", "biome_cooldown":3.1, "preferred_distance":230.0, "projectile_damage":4.5, "projectile_speed":235.0, "projectile_range":760.0, "projectile_radius":5.0},
	"coral_colossus": {"name":"珊瑚巨衛", "max_hp":88.0, "speed":48.0, "damage":11.0, "xp":6, "gold":3, "radius":24.0, "color":Color("f1adad"), "sprite_path":"res://assets/sprites/enemy_coral_colossus.png", "sprite_scale":1.48, "weight":0.5, "min_time":8.0, "behavior_id":"biome_skill", "biome_skill":"coral_slam", "biome_cooldown":3.8, "biome_radius":145.0},
	"bloom_wisp": {"name":"月華靈火", "max_hp":27.0, "speed":55.0, "damage":5.0, "xp":4, "gold":2, "radius":12.0, "color":Color("b8eac5"), "sprite_path":"res://assets/sprites/enemy_bloom_wisp.png", "sprite_scale":1.28, "weight":0.9, "min_time":0.0, "behavior_id":"biome_skill", "biome_skill":"bloom_support", "biome_cooldown":4.5, "preferred_distance":230.0, "biome_radius":260.0, "biome_heal":12.0},
	"clockwork_reaper": {"name":"時輪刃衛", "max_hp":43.0, "speed":84.0, "damage":8.0, "xp":4, "gold":2, "radius":16.0, "color":Color("cfbadf"), "sprite_path":"res://assets/sprites/enemy_clockwork_reaper.png", "sprite_scale":1.4, "weight":1.0, "min_time":0.0, "behavior_id":"biome_skill", "biome_skill":"gear_fan", "biome_cooldown":3.2, "preferred_distance":195.0, "projectile_damage":5.0, "projectile_speed":265.0, "projectile_range":730.0, "projectile_radius":5.0}
}

const ROSTERS: Dictionary = {
	"dunes": {"dune_scarab":1.0, "sand_stalker":0.85, "normal":0.18, "tank":0.12},
	"tide": {"tide_siren":1.0, "coral_colossus":0.75, "normal":0.18, "fast":0.12},
	"bloom": {"bloom_wisp":1.0, "sand_stalker":0.32, "fast":0.48, "normal":0.15},
	"forge": {"clockwork_reaper":1.0, "dune_scarab":0.3, "tank":0.4, "normal":0.15}
}

static func get_config(id: String) -> Dictionary:
	return (CONFIGS.get(id, {}) as Dictionary).duplicate(true)

static func get_roster(stage_id: String) -> Dictionary:
	return (ROSTERS.get(stage_id, {}) as Dictionary).duplicate(true)

static func has_enemy(id: String) -> bool:
	return CONFIGS.has(id)

static func get_enemy_ids() -> Array:
	return CONFIGS.keys()
