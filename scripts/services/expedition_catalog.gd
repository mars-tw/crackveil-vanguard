extends RefCounted

## Finite biome commissions. Progress is the best result of one formal sortie,
## never a sum of repeated settlement snapshots or a wall-clock daily grind.
const STAGES := preload("res://scripts/services/stage_catalog.gd")
const MISSIONS: Array[Dictionary] = [
	{"id":"moon_field","stage_id":"moon","name":"空庭重連","description":"單次出擊封合兩道裂隙。","metric":"seals","target":2,"reward":4,"lore":"石碑重新接上巡防路線，失散的小隊有了集合點。"},
	{"id":"moon_mastery","stage_id":"moon","name":"不破的陣線","description":"沒有錯陣反噬，完成蒼月空庭封隙通關。","metric":"clean_seals","target":1,"reward":6,"lore":"先鋒的陣線成了空庭的新界標。"},
	{"id":"garden_field","stage_id":"garden","name":"識破荊棘","description":"單次出擊避過至少兩次藤蔓纏繞，全隊無人被纏。","metric":"clean_vines","target":2,"reward":4,"lore":"斥候把藤蔓收束的節奏記進了巡防筆記。"},
	{"id":"garden_mastery","stage_id":"garden","name":"花園通行線","description":"遭遇至少兩次藤蔓後無人被纏，完成花園通關。","metric":"garden_clear","target":1,"reward":6,"lore":"新的步道繞開狼群巢穴，採集隊終於能通行。"},
	{"id":"ember_field","stage_id":"ember","name":"穿過火環","description":"單次出擊讓全隊完整避過兩道火環。","metric":"ember_clean","target":2,"reward":4,"lore":"熔庭的避火路線第一次被完整標記。"},
	{"id":"ember_mastery","stage_id":"ember","name":"熔庭救援線","description":"遭遇至少兩道火環且全隊未被火環命中，完成通關。","metric":"ember_clear","target":1,"reward":6,"lore":"先鋒帶回了受困工匠留下的工具。"},
	{"id":"storm_field","stage_id":"storm","name":"導走雷流","description":"單次出擊成功接地兩次雷柱。","metric":"storm_grounded","target":2,"reward":4,"lore":"斷橋旁的避雷設施恢復運作。"},
	{"id":"storm_mastery","stage_id":"storm","name":"浮島復航","description":"單次出擊接地三次雷柱，並完成浮島通關。","metric":"storm_clear","target":1,"reward":6,"lore":"浮島之間再次亮起航標。"},
	{"id":"frost_field","stage_id":"frost","name":"辨出冰隙","description":"單次出擊讓全隊完整避過兩道冰牆。","metric":"frost_clean","target":2,"reward":4,"lore":"冰層上的安全路口被標上了暖色旗幟。"},
	{"id":"frost_mastery","stage_id":"frost","name":"聖域暖路","description":"遭遇至少兩道冰牆且無人被命中，完成聖域通關。","metric":"frost_clear","target":1,"reward":6,"lore":"避難者循著旗幟走出了冰封區。"},
	{"id":"veil_field","stage_id":"veil","name":"替隊友擋槍","description":"單次出擊由隊長護住兩次影槍。","metric":"veil_blocked","target":2,"reward":4,"lore":"隊員開始相信，隊長會擋在暗槍之前。"},
	{"id":"veil_mastery","stage_id":"veil","name":"王庭護送","description":"護住至少兩次影槍且隊員未被影槍刺中，完成王庭通關。","metric":"veil_clear","target":1,"reward":6,"lore":"王庭的倖存者沿著先鋒陣線撤離。"},
	{"id":"dunes_field","stage_id":"dunes","name":"讀懂砂紋","description":"單次出擊解開兩次砂紋。","metric":"sand_solved","target":2,"reward":4,"lore":"王陵的砂紋不再只是無法理解的警告。"},
	{"id":"dunes_mastery","stage_id":"dunes","name":"王陵測繪","description":"單次出擊解開三次砂紋，並完成王陵通關。","metric":"dunes_clear","target":1,"reward":6,"lore":"測繪圖上多了一條通往日晷的路。"},
	{"id":"tide_field","stage_id":"tide","name":"回應潮印","description":"單次出擊對上兩次潮印。","metric":"tide_matched","target":2,"reward":4,"lore":"潮印的節拍被編進了小隊的口令。"},
	{"id":"tide_mastery","stage_id":"tide","name":"遺都回聲","description":"單次出擊對上三次潮印，並完成遺都通關。","metric":"tide_clear","target":1,"reward":6,"lore":"沉沒的鐘樓終於傳回清楚的鐘聲。"},
	{"id":"bloom_field","stage_id":"bloom","name":"先斷花蕾","description":"單次出擊斬斷兩朵月華花蕾。","metric":"bloom_cut","target":2,"reward":4,"lore":"小隊找到了阻止群怪回復的源頭。"},
	{"id":"bloom_mastery","stage_id":"bloom","name":"靈森休養","description":"斬斷至少兩朵花蕾且未讓花蕾治療敵人，完成靈森通關。","metric":"bloom_clear","target":1,"reward":6,"lore":"新的花開在空地，而非傷兵腳下。"},
	{"id":"forge_field","stage_id":"forge","name":"工坊集結","description":"單次出擊讓至少五名英雄加入小隊。","metric":"squad_total","target":5,"reward":4,"lore":"不同專長的英雄在工坊會合，準備最後的修復。"},
	{"id":"forge_mastery","stage_id":"forge","name":"一起回來","description":"至少五名英雄加入，通關時所有本局隊員仍存活。","metric":"forge_clear","target":1,"reward":6,"lore":"這一次，集合點沒有空下的位置。"}
]

static func definitions() -> Array[Dictionary]:
	return MISSIONS.duplicate(true)

static func value_for(mission: Dictionary, summary: Dictionary) -> int:
	if str(summary.get("stage_id", "")) != str(mission.get("stage_id", "")):
		return 0
	var seal_value: Variant = summary.get("seal_state", {})
	var seal: Dictionary = seal_value if seal_value is Dictionary else {}
	var clear := _flag(summary, "campaign_clear") and str(summary.get("settlement_reason", "")) == "victory"
	var metric := str(mission.get("metric", ""))
	var amount := 0
	match metric:
		"seals": amount = _count(seal, "step")
		"clean_seals": amount = int(clear and _flag(seal, "completed") and _zero(seal, "wrong"))
		"clean_vines": amount = _count(seal, "vine_clean") if _zero(seal, "vine_hits") else 0
		"squad_total": amount = _count(summary, "squad_total")
		"garden_clear": amount = int(clear and _count(seal, "vine_clean") >= 2 and _zero(seal, "vine_hits"))
		"ember_clear": amount = int(clear and _count(seal, "ember_clean") >= 2 and _zero(seal, "ember_hits"))
		"storm_clear": amount = int(clear and _count(seal, "storm_grounded") >= 3)
		"frost_clear": amount = int(clear and _count(seal, "frost_clean") >= 2 and _zero(seal, "frost_hits"))
		"veil_clear": amount = int(clear and _count(seal, "veil_blocked") >= 2 and _zero(seal, "veil_hits"))
		"dunes_clear": amount = int(clear and _count(seal, "sand_solved") >= 3)
		"tide_clear": amount = int(clear and _count(seal, "tide_matched") >= 3)
		"bloom_clear": amount = int(clear and _count(seal, "bloom_cut") >= 2 and _zero(seal, "bloom_heals"))
		"forge_clear": amount = int(clear and _count(summary, "squad_total") >= 5 and _count(summary, "squad_alive") == _count(summary, "squad_total"))
		_: amount = _count(seal, metric)
	return clampi(amount, 0, int(mission.get("target", 1)))

static func _count(source: Dictionary, key: String) -> int:
	var value: Variant = source.get(key)
	if not value is int and not value is float:
		return -1
	var numeric := float(value)
	if not is_finite(numeric) or numeric < 0.0 or numeric > 2147483647.0 or floor(numeric) != numeric:
		return -1
	return int(value)

static func _zero(source: Dictionary, key: String) -> bool:
	return _count(source, key) == 0

static func _flag(source: Dictionary, key: String) -> bool:
	var value: Variant = source.get(key, false)
	return value is bool and value
