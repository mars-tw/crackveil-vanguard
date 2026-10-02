extends RefCounted

# Items are run-bound. Each slot has a monotonic stat curve, so auto-equipping a
# higher power item never trades away a different useful stat without consent.
const SLOTS: Array[String] = ["core", "guard", "boots"]
const SLOT_NAMES := {"core": "武裝核心", "guard": "護甲", "boots": "戰靴"}
const RARITY_NAMES: Array[String] = ["精良", "稀有", "史詩", "傳說"]
const RARITY_COLORS: Array[Color] = [Color(0.48, 0.94, 0.62), Color(0.32, 0.72, 1.0), Color(0.78, 0.48, 1.0), Color(1.0, 0.72, 0.22)]
const ITEM_NAMES := {
	"core": ["裂刃晶核", "雷鑄晶核", "虛界晶核", "弒帷之心"],
	"guard": ["裂隙護甲", "雷鑄護甲", "虛界護甲", "守門者甲冑"],
	"boots": ["拾荒戰靴", "雷步戰靴", "虛空行者", "踏界之靴"]
}
const DAMAGE: Array[float] = [0.06, 0.12, 0.18, 0.24]
const FIRE_RATE: Array[float] = [0.02, 0.04, 0.06, 0.08]
const HEALTH: Array[float] = [12.0, 24.0, 36.0, 48.0]
const MITIGATION: Array[float] = [0.015, 0.03, 0.045, 0.06]
const SPEED: Array[float] = [10.0, 20.0, 30.0, 40.0]
const PICKUP: Array[float] = [12.0, 24.0, 36.0, 48.0]


static func make_item(slot: String, rarity: int, item_level: int, serial: int) -> Dictionary:
	var safe_slot := slot if SLOTS.has(slot) else "core"
	var tier := clampi(rarity, 0, RARITY_NAMES.size() - 1)
	var rank := clampi(item_level, 1, 20)
	var scale := 1.0 + float(rank - 1) * 0.035
	var bonuses := empty_bonuses()
	match safe_slot:
		"core":
			bonuses["damage"] = DAMAGE[tier] * scale
			bonuses["fire_rate"] = FIRE_RATE[tier] * scale
		"guard":
			bonuses["max_hp"] = roundf(HEALTH[tier] * scale)
			bonuses["damage_reduction"] = MITIGATION[tier] * scale
		"boots":
			bonuses["move_speed"] = roundf(SPEED[tier] * scale)
			bonuses["pickup_radius"] = roundf(PICKUP[tier] * scale)
	return {
		"uid": serial,
		"slot": safe_slot,
		"slot_name": str(SLOT_NAMES[safe_slot]),
		"name": str(ITEM_NAMES[safe_slot][tier]),
		"rarity": tier,
		"rarity_name": RARITY_NAMES[tier],
		"color": RARITY_COLORS[tier],
		"item_level": rank,
		"power": (100.0 + float(tier) * 100.0) * scale,
		"salvage_gold": 2 + tier * 2 + int(rank / 4),
		"bonuses": bonuses,
		"description": describe_bonuses(bonuses)
	}


static func empty_bonuses() -> Dictionary:
	return {"damage": 0.0, "fire_rate": 0.0, "max_hp": 0.0, "damage_reduction": 0.0, "move_speed": 0.0, "pickup_radius": 0.0}


static func describe_bonuses(bonuses: Dictionary) -> String:
	var lines := PackedStringArray()
	if float(bonuses.get("damage", 0.0)) > 0.0:
		lines.append("全隊傷害 +%s%%" % number(float(bonuses["damage"]) * 100.0))
	if float(bonuses.get("fire_rate", 0.0)) > 0.0:
		lines.append("全隊攻速 +%s%%" % number(float(bonuses["fire_rate"]) * 100.0))
	if float(bonuses.get("max_hp", 0.0)) > 0.0:
		lines.append("全隊最大 HP +%d" % int(bonuses["max_hp"]))
	if float(bonuses.get("damage_reduction", 0.0)) > 0.0:
		lines.append("受傷減少 %s%%（總減傷上限 15%%）" % number(float(bonuses["damage_reduction"]) * 100.0))
	if float(bonuses.get("move_speed", 0.0)) > 0.0:
		lines.append("全隊移速 +%d" % int(bonuses["move_speed"]))
	if float(bonuses.get("pickup_radius", 0.0)) > 0.0:
		lines.append("全隊拾取範圍 +%d" % int(bonuses["pickup_radius"]))
	return "\n".join(lines)


static func number(value: float) -> String:
	return str(int(roundf(value))) if is_equal_approx(value, roundf(value)) else "%.1f" % value
