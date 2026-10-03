extends RefCounted

# Stage rules live with their map and boss; selecting a node changes real play.
const STAGES: Array[Dictionary] = [
	{"id": "moon", "name": "蒼月空庭", "theme_id": "rift_void", "boss_name": "蒼月石鬼", "description": "石鬼鎮守空庭。穿過十字彈幕，斬開重甲。", "color": Color("a5caff"), "node_position": Vector2(0.15, 0.63), "difficulty": 1, "boss_time": 90.0, "enemy_bias": "tank", "boss_sprite": "enemy_tank", "pattern": "moon_cross", "boss_hp": 1800.0},
	{"id": "garden", "name": "翠晶花園", "theme_id": "wasteland_farm", "boss_name": "荊棘狼王", "description": "狼群湧進花園。閃過狼王突進與追蹤扇形彈。", "color": Color("90e8bb"), "node_position": Vector2(0.31, 0.43), "difficulty": 2, "boss_time": 105.0, "enemy_bias": "fast", "boss_sprite": "enemy_fast", "pattern": "garden_fan", "boss_hp": 2250.0},
	{"id": "ember", "name": "緋星熔庭", "theme_id": "ember_rift", "boss_name": "緋焰刃魔", "description": "刃魔召喚裂殖群。螺旋火雨留下逃生縫隙。", "color": Color("ffa181"), "node_position": Vector2(0.46, 0.66), "difficulty": 3, "boss_time": 120.0, "enemy_bias": "spawner", "boss_sprite": "enemy_elite_split", "pattern": "ember_spiral", "boss_hp": 2700.0},
	{"id": "storm", "name": "雷霆浮島", "theme_id": "storm_isles", "boss_name": "雷翼獸皇", "description": "迅捷獸群包圍浮島。雷翼獸皇連續突進，放出星形雷彈。", "color": Color("8ce0ff"), "node_position": Vector2(0.59, 0.31), "difficulty": 4, "boss_time": 135.0, "enemy_bias": "dasher", "boss_sprite": "enemy_elite_swift", "pattern": "storm_star", "boss_hp": 3150.0},
	{"id": "frost", "name": "星霜聖域", "theme_id": "star_frost", "boss_name": "霜晶咒王", "description": "咒王展開緩速力場。六向冰晶與快慢交錯彈幕封鎖戰場。", "color": Color("cadbff"), "node_position": Vector2(0.75, 0.50), "difficulty": 5, "boss_time": 150.0, "enemy_bias": "ranged", "boss_sprite": "enemy_elite_field", "pattern": "ice_frost", "boss_hp": 3650.0},
	{"id": "veil", "name": "帷幕王庭", "theme_id": "veil_court", "boss_name": "帷幕君主", "description": "君主交替施放環形彈幕與定向暗槍，半血召來近衛。", "color": Color("ddabff"), "node_position": Vector2(0.89, 0.27), "difficulty": 6, "boss_time": 165.0, "enemy_bias": "tank", "boss_sprite": "enemy_boss", "pattern": "veil_eclipse", "boss_hp": 4300.0},
	{"id":"dunes", "name":"曜砂王陵", "theme_id":"sunken_dunes", "boss_name":"曜砂巨甲", "description":"甲蟲與砂影伏兵守住王陵。三列瞄準砂彈留出錯位逃生縫隙。", "color":Color("edc687"), "node_position":Vector2(0.17,0.85), "difficulty":7, "boss_time":180.0, "enemy_bias":"dune_scarab", "boss_sprite":"enemy_dune_scarab", "pattern":"dune_barrage", "boss_hp":4800.0},
	{"id":"tide", "name":"珊潮遺都", "theme_id":"tidal_ruins", "boss_name":"深潮歌后", "description":"歌妖與珊瑚巨衛盤踞遺都。雙臂水彈螺旋逐輪轉向。", "color":Color("8ad9eb"), "node_position":Vector2(0.39,0.82), "difficulty":8, "boss_time":195.0, "enemy_bias":"tide_siren", "boss_sprite":"enemy_tide_siren", "pattern":"tidal_spiral", "boss_hp":5400.0},
	{"id":"bloom", "name":"月華靈森", "theme_id":"moonbloom_grove", "boss_name":"萬花靈主", "description":"靈火替群怪療傷。六瓣月華交錯成環，半血展開更多花瓣。", "color":Color("b8eac5"), "node_position":Vector2(0.64,0.85), "difficulty":9, "boss_time":210.0, "enemy_bias":"bloom_wisp", "boss_sprite":"enemy_bloom_wisp", "pattern":"bloom_petals", "boss_hp":6000.0},
	{"id":"forge", "name":"時輪工坊", "theme_id":"clockwork_forge", "boss_name":"時輪收割者", "description":"機械刃衛以扇形齒輪追獵。四軸交叉彈每輪旋轉，快慢層交錯。", "color":Color("cfbadf"), "node_position":Vector2(0.87,0.80), "difficulty":10, "boss_time":225.0, "enemy_bias":"clockwork_reaper", "boss_sprite":"enemy_clockwork_reaper", "pattern":"gear_cross", "boss_hp":6800.0}
]

static func get_stages() -> Array[Dictionary]:
	return STAGES.duplicate(true)

static func get_stage(stage_id: String) -> Dictionary:
	for stage in STAGES:
		if str(stage.id) == stage_id:
			return stage.duplicate(true)
	return {}

static func get_next_stage_id(stage_id: String) -> String:
	for index in range(STAGES.size() - 1):
		if str(STAGES[index].id) == stage_id:
			return str(STAGES[index + 1].id)
	return ""

static func get_boss_config(stage_id: String) -> Dictionary:
	var stage := get_stage(stage_id)
	if stage.is_empty():
		stage = get_stage("moon")
	var pattern := str(stage.pattern)
	var swift := pattern in ["garden_fan", "storm_star"]
	return {
		"max_hp": float(stage.boss_hp), "speed": 95.0 if swift else 49.0,
		"damage": 14.0 + float(stage.difficulty), "xp": 30, "gold": 16,
		"radius": 34.0, "color": stage.color,
		"sprite_path": "res://assets/sprites/%s.png" % str(stage.boss_sprite),
		"sprite_scale": 2.08, "attack_cooldown": 1.15, "behavior_id": "boss", "is_boss": true,
		"projectile_damage": 5.0 + float(stage.difficulty) * 0.6,
		"projectile_speed": 180.0 + float(stage.difficulty) * 8.0,
		"projectile_range": 940.0, "projectile_radius": 7.0,
		"boss_ability_cooldown": 3.3 if swift else 4.2,
		"boss_pattern": pattern, "boss_dash": swift,
		"biome_radius": 260.0 if pattern == "bloom_petals" else 145.0,
		"biome_heal": 12.0,
		"dash_trigger_range": 190.0 if pattern == "storm_star" else 165.0,
		"dash_windup": 0.38 if pattern == "storm_star" else 0.46,
		"dash_duration": 0.24, "dash_recover": 0.60,
		"dash_speed": 380.0 if pattern == "storm_star" else 320.0,
		"affix_id": "affix_field" if pattern == "ice_frost" else "",
		"affix_field_radius": 116.0 if pattern == "ice_frost" else 0.0,
		"affix_field_slow_strength": 0.22 if pattern == "ice_frost" else 0.0
	}
