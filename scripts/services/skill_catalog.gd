extends RefCounted

const IDS: Array[String] = ["meteor_rain", "star_orbs", "frost_lances", "shadow_blades"]
const MAX_LEVEL := 5
const FX := preload("res://scripts/vfx/newskill_fx_catalog.gd")
const SKILLS := {
	"meteor_rain":{"name":"流星雨", "description":"真攻擊命中格降下 8 枚流星，每枚爆破 58 範圍、28 傷害。", "cooldown":4.0, "damage":28.0, "count":8, "fx":"monster_fire", "color":Color("ffb17b")},
	"star_orbs":{"name":"星雷珠", "description":"真攻擊命中格放出 8 顆追蹤雷珠，每顆 18 傷害。", "cooldown":2.8, "damage":18.0, "count":8, "fx":"critical_impact", "color":Color("8deaff")},
	"frost_lances":{"name":"霜晶槍", "description":"真攻擊命中格射出 12 支霜槍，每支 20 傷害並穿透 3 個敵人。", "cooldown":3.4, "damage":20.0, "count":12, "fx":"monster_frost", "color":Color("abedff")},
	"shadow_blades":{"name":"追影刃", "description":"真攻擊命中格拋出 10 把回旋追影刃，每把 22 傷害、可穿透 2 次。", "cooldown":3.2, "damage":22.0, "count":10, "fx":"monster_shadow", "color":Color("c69aff")}
}


static func get_skill(id: String) -> Dictionary:
	var data: Dictionary = SKILLS.get(id, {}).duplicate(true)
	if not data.is_empty():
		data["id"] = id
	return data


static func level_damage_multiplier(level: int) -> float:
	return 1.0 + 0.30 * float(clampi(level, 1, MAX_LEVEL) - 1)


static func level_cooldown_multiplier(level: int) -> float:
	return 1.0 / (1.0 + 0.06 * float(clampi(level, 1, MAX_LEVEL) - 1))


static func make_option(id: String, current_level: int) -> Dictionary:
	var data := get_skill(id)
	var next_damage := float(data.damage) * level_damage_multiplier(current_level + 1)
	var next_interval := float(data.cooldown) * level_cooldown_multiplier(current_level + 1)
	var benefit := "取得新法術：%.1f 傷害／%.2f 秒。" % [next_damage,next_interval]
	if current_level > 0:
		benefit = "傷害 %.1f → %.1f；間隔 %.2f → %.2f 秒。" % [float(data.damage)*level_damage_multiplier(current_level),next_damage,float(data.cooldown)*level_cooldown_multiplier(current_level),next_interval]
	return {"id":"summon_skill", "skill_id":id, "name":str(data.name), "description":str(data.description) + "\n" + benefit + "\n法術等級 %d → %d／5。" % [current_level, current_level + 1], "upgrade_category":"summon", "summon_level":current_level + 1, "weight":1.0}


static func get_icon(id: String) -> Texture2D:
	var data := get_skill(id)
	if data.is_empty():
		return null
	var frames: SpriteFrames = FX.get_frames(str(data.fx))
	return frames.get_frame_texture(&"default", 2) if frames != null and frames.get_frame_count(&"default") > 2 else null


static func get_live_legal_pool() -> Array[Dictionary]:
	var base: Array = GameManager.PLAYER_UPGRADE_POOL.duplicate(true)
	if is_instance_valid(GameManager.squad_manager):
		base = GameManager.squad_manager.build_upgrade_pool(base)
	var result: Array[Dictionary] = []
	var keys := {}
	for value in base:
		var option: Dictionary = value
		if not GameManager._is_upgrade_available(option):
			continue
		var key: String = GameManager._upgrade_level_key(option)
		if not keys.has(key):
			keys[key] = true
			result.append(option.duplicate(true))
	return result
