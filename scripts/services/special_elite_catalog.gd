extends RefCounted

const PROFILES: Array[Dictionary] = [
	{"id":"flame", "name":"焰爆術士", "skill":"flame_nova", "description":"八向火焰彈，先看地面預告再閃開。", "sprite":"enemy_elite_field", "hp":220.0, "speed":66.0, "color":Color("ffa06c"), "gold":24},
	{"id":"frost", "name":"霜環守望者", "skill":"frost_ring", "description":"霜晶彈環與近身緩速力場。", "sprite":"enemy_elite_field", "hp":250.0, "speed":58.0, "color":Color("8bd8ff"), "gold":24},
	{"id":"shield", "name":"星盾重衛", "skill":"shield_slam", "description":"護盾減傷，蓄力前會露出破綻。", "sprite":"enemy_tank", "hp":310.0, "speed":62.0, "color":Color("b8c9f5"), "gold":28},
	{"id":"summoner", "name":"裂群召喚師", "skill":"summoner", "description":"施法召來五隻小魔物。", "sprite":"enemy_elite_split", "hp":230.0, "speed":57.0, "color":Color("d6a0fa"), "gold":28},
	{"id":"charge", "name":"雷爪獵將", "skill":"storm_charge", "description":"明顯蓄勢後衝鋒，帶著雷彈切入。", "sprite":"enemy_elite_swift", "hp":210.0, "speed":110.0, "color":Color("7fdbff"), "gold":26},
	{"id":"treasure", "name":"逐金魔靈", "skill":"treasure", "description":"會逃跑並灑金幣，擊敗可拿大量金幣。", "sprite":"enemy_fast", "hp":190.0, "speed":124.0, "color":Color("ffe18b"), "gold":65}
]

# R27: each stage fields its own elite roster. The skill stays (so the attack
# pattern and its formation answer are unchanged), but the name, tint and a
# stage pressure (faster, tougher or harder-hitting) change, so a later stage
# does not read as the first stage repainted.
const STAGE_VARIANTS := {
	"garden": {"tint": Color("8fe39a"), "speed": 1.15, "hp": 0.92, "projectile": 1.0, "pressure": "荊藤纏地", "skill": "vine_snare",
		"names": {"shield": "荊盾重衛", "charge": "藤爪獵將", "frost": "花露守望者", "flame": "花火術士", "summoner": "苗群召喚師"}},
	"ember": {"tint": Color("ff9a6a"), "speed": 1.0, "hp": 1.0, "projectile": 1.25, "pressure": "熔火環爆", "skill": "ember_ring",
		"names": {"shield": "熔盾重衛", "charge": "焰爪獵將", "frost": "灰燼守望者", "flame": "緋焰術士", "summoner": "焰群召喚師"}},
	"storm": {"tint": Color("9fb7ff"), "speed": 1.2, "hp": 0.9, "projectile": 1.0, "pressure": "雷柱分流", "skill": "storm_pylon",
		"names": {"shield": "雷盾重衛", "charge": "霆爪獵將", "frost": "雲霧守望者", "flame": "電弧術士", "summoner": "雷群召喚師"}},
	"frost": {"tint": Color("cfefff"), "speed": 0.9, "hp": 1.2, "projectile": 1.0, "pressure": "霜牆穿縫", "skill": "frost_wall",
		"names": {"shield": "冰盾重衛", "charge": "霜爪獵將", "frost": "極霜守望者", "flame": "寒焰術士", "summoner": "冰群召喚師"}},
	"veil": {"tint": Color("e0a8ff"), "speed": 1.1, "hp": 1.1, "projectile": 1.1, "pressure": "影槍鎖定", "skill": "veil_lance",
		"names": {"shield": "幕盾重衛", "charge": "影爪獵將", "frost": "幽帷守望者", "flame": "冥焰術士", "summoner": "影群召喚師"}},
	"dunes": {"tint": Color("f0c97a"), "speed": 1.05, "hp": 1.15, "projectile": 1.1, "pressure": "王陵雙印", "skill": "sand_glyphs",
		"names": {"shield": "砂盾重衛", "charge": "砂爪獵將", "frost": "砂霧守望者", "flame": "曜焰術士", "summoner": "砂群召喚師"}},
	"tide": {"tint": Color("7fd8ee"), "speed": 1.0, "hp": 1.2, "projectile": 1.1, "pressure": "潮紋換陣", "skill": "tide_sigil",
		"names": {"shield": "潮盾重衛", "charge": "浪爪獵將", "frost": "珊霧守望者", "flame": "海焰術士", "summoner": "珊群召喚師"}},
	"bloom": {"tint": Color("d8b8ff"), "speed": 1.05, "hp": 1.25, "projectile": 1.1, "pressure": "月華花蕾", "skill": "moon_bloom",
		"names": {"shield": "月盾重衛", "charge": "花爪獵將", "frost": "靈霧守望者", "flame": "月焰術士", "summoner": "花群召喚師"}}
}

static func stage_variant(stage_id: String) -> Dictionary:
	return STAGE_VARIANTS.get(stage_id, {})

static func apply_stage_variant(config: Dictionary, stage_id: String) -> Dictionary:
	var variant := stage_variant(stage_id)
	if variant.is_empty() or config.is_empty():
		return config
	var id := str(config.get("special_elite_id", ""))
	var names: Dictionary = variant.get("names", {})
	if names.has(id):
		config["special_elite_name"] = str(names[id])
	config["color"] = Color(variant.tint)
	config["speed"] = float(config.get("speed", 0.0)) * float(variant.speed)
	config["max_hp"] = float(config.get("max_hp", 0.0)) * float(variant.hp)
	config["projectile_damage"] = float(config.get("projectile_damage", 0.0)) * float(variant.projectile)
	config["stage_pressure"] = str(variant.pressure)
	config["stage_skill"] = str(variant.get("skill", ""))
	return config

static func get_profiles() -> Array[Dictionary]:
	return PROFILES.duplicate(true)

static func get_profile(id: String) -> Dictionary:
	for profile in PROFILES:
		if str(profile.id) == id:
			return profile.duplicate(true)
	return {}

static func make_config(id: String, cap: int) -> Dictionary:
	var profile := get_profile(id)
	if profile.is_empty():
		return {}
	return {"max_hp":profile.hp, "speed":profile.speed, "damage":9.0, "xp":8, "gold":profile.gold, "radius":28.0, "sprite_scale":1.56, "color":profile.color, "sprite_path":"res://assets/sprites/%s.png" % profile.sprite, "is_elite":true, "elite_bonus_xp":24, "behavior_id":"elite_special", "special_elite_id":id, "special_elite_name":profile.name, "special_skill":profile.skill, "special_cooldown":3.0, "attack_cooldown":1.15, "projectile_damage":4.5, "projectile_speed":230.0, "projectile_range":700.0, "projectile_radius":6.0, "dash_trigger_range":240.0, "dash_windup":0.50, "dash_duration":0.28, "dash_recover":0.65, "dash_speed":510.0, "death_spawn_cap":cap, "affix_id":"affix_field" if id=="frost" else "", "affix_field_radius":150.0 if id=="frost" else 0.0, "affix_field_slow_strength":0.25 if id=="frost" else 0.0}
