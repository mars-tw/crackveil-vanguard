extends RefCounted

const PROFILES: Array[Dictionary] = [
	{"id":"flame", "name":"焰爆術士", "skill":"flame_nova", "description":"八向火焰彈，先看地面預告再閃開。", "sprite":"enemy_elite_field", "hp":220.0, "speed":66.0, "color":Color("ffa06c"), "gold":24},
	{"id":"frost", "name":"霜環守望者", "skill":"frost_ring", "description":"霜晶彈環與近身緩速力場。", "sprite":"enemy_elite_field", "hp":250.0, "speed":58.0, "color":Color("8bd8ff"), "gold":24},
	{"id":"shield", "name":"星盾重衛", "skill":"shield_slam", "description":"護盾減傷，蓄力前會露出破綻。", "sprite":"enemy_tank", "hp":310.0, "speed":62.0, "color":Color("b8c9f5"), "gold":28},
	{"id":"summoner", "name":"裂群召喚師", "skill":"summoner", "description":"施法召來五隻小魔物。", "sprite":"enemy_elite_split", "hp":230.0, "speed":57.0, "color":Color("d6a0fa"), "gold":28},
	{"id":"charge", "name":"雷爪獵將", "skill":"storm_charge", "description":"明顯蓄勢後衝鋒，帶著雷彈切入。", "sprite":"enemy_elite_swift", "hp":210.0, "speed":110.0, "color":Color("7fdbff"), "gold":26},
	{"id":"treasure", "name":"逐金魔靈", "skill":"treasure", "description":"會逃跑並灑金幣，擊敗可拿大量金幣。", "sprite":"enemy_fast", "hp":190.0, "speed":124.0, "color":Color("ffe18b"), "gold":65}
]

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
