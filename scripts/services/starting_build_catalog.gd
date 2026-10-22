extends RefCounted

# Horizontal choices: exactly one node is active. Roster overrides are shown
# before purchase/launch and use the existing hero resources and real bonds.
const TEAMS := {
	"legacy":{"name":"先鋒標準","ids":["rift_captain","orbit_guard","arc_scout"],"trade":"護衛＋遠攻，依敵況換陣"},
	"assault":{"name":"裂線突擊","ids":["rift_captain","arc_scout","pulse_artificer"],"trade":"遠攻爆發；沒有起始和聲回復"},
	"escort":{"name":"星盾護送","ids":["rift_captain","orbit_guard","echo_singer"],"trade":"護圈回復與減傷；正面輸出較慢"}
}
const NODES: Array[Dictionary] = [
	{"id":"crew_guard","line":"隊員","name":"護衛先發","cost":4,"benefit":"護衛＋星焰槍騎先發，護盾與直線貫槍","cost_text":"少一電弧連鎖遠攻席，改 390 範圍槍","roster":["rift_captain","orbit_guard","solar_lancer"]},
	{"id":"crew_singer","line":"隊員","name":"歌者先發","cost":6,"benefit":"星盾和聲先發，歌者療唱冷卻 -25%","cost_text":"全隊傷害 -10%","roster":["rift_captain","orbit_guard","echo_singer"]},
	{"id":"crew_scout","line":"隊員","name":"偵察先發","cost":8,"benefit":"偵察＋縫隙師先發，移速 +12%","cost_text":"承傷 +10%","roster":["rift_captain","arc_scout","void_weaver"]},
	{"id":"crew_gunner","line":"隊員","name":"炮手先發","cost":10,"benefit":"炮手＋工匠先發，燼脈聯爆","cost_text":"隊長回能 -25%","roster":["rift_captain","ember_grenadier","pulse_artificer"]},
	{"id":"crew_shepherd","line":"隊員","name":"牧者先發","cost":12,"benefit":"牧者＋護衛先發，真裂傀協戰","cost_text":"每名牧者最多 2 具裂傀","roster":["rift_captain","rift_shepherd","orbit_guard"]},
	{"id":"bond_harmony","line":"羈絆","name":"和聲救援","cost":4,"benefit":"星盾和聲圓陣每秒回復再 +1 HP","cost_text":"和聲回復僅限護圈 96 內","roster":["rift_captain","orbit_guard","echo_singer"]},
	{"id":"bond_rail","line":"羈絆","name":"裂線標記","cost":6,"benefit":"縫獵成絆且隊長移動時傷害 +12%","cost_text":"停步傷害 -15%","roster":["rift_captain","void_weaver","rift_sniper"]},
	{"id":"bond_relay","line":"羈絆","name":"爆裂接力","cost":8,"benefit":"燼脈工匠爆炸範圍 +25%","cost_text":"工匠爆炸延後 0.45 秒","roster":["rift_captain","ember_grenadier","pulse_artificer"]},
	{"id":"bond_construct","line":"羈絆","name":"裂傀護送","cost":10,"benefit":"牧長裂約裂傀壽命 +40%","cost_text":"裂傀占 1 席，編隊上限 8 人","roster":["rift_captain","rift_shepherd","orbit_guard"]},
	{"id":"bond_reserve","line":"羈絆","name":"混編候補","cost":12,"benefit":"不同系候補提前 1 級可招募","cost_text":"同系不能重複招募","roster":["rift_captain","arc_scout","line_mender"]},
	{"id":"spec_shield","line":"專精","name":"楔形破盾","cost":4,"benefit":"楔形對正面封隙盾衛傷害 +25%","cost_text":"包抄預警／生效期間承傷 +20%","campaign_only":true},
	{"id":"spec_escort","line":"專精","name":"圓陣護送","cost":6,"benefit":"圓陣也能處理正面封隙","cost_text":"移速 -12%；圓陣正面封合慢 15%","campaign_only":true},
	{"id":"spec_collect","line":"專精","name":"散兵回收","cost":8,"benefit":"散兵拾取再 +35%；可處理包抄","cost_text":"隊長近戰傷害 -20%"},
	{"id":"spec_step","line":"專精","name":"換陣借步","cost":10,"benefit":"換陣後 2 秒移速 +25%","cost_text":"換陣冷卻 +75%"},
	{"id":"spec_prepare","line":"專精","name":"封隙整備","cost":12,"benefit":"每次封隙反擊延長 5 秒","cost_text":"放棄該次即時全隊治療","campaign_only":true}
]
const FAMILIES := {"rift_captain":"rift","rift_shepherd":"rift","arc_scout":"scout","shadow_ronin":"scout","line_mender":"support","tide_oracle":"support","orbit_guard":"star","echo_singer":"star","ember_grenadier":"blast","pulse_artificer":"blast","void_weaver":"veil","rift_sniper":"veil","solar_lancer":"sun"}

static func node(id: String) -> Dictionary:
	for row in NODES:
		if row.id==id: return row.duplicate(true)
	return {}

static func roster(team: String, id: String) -> Array:
	var row := node(id)
	return row.roster.duplicate() if row.has("roster") else TEAMS.get(team,TEAMS.legacy).ids.duplicate()

static func family(id: String) -> String:
	return str(FAMILIES.get(id,id))

static func accepts(id: String, kind: String, formation: String) -> bool:
	if id=="spec_escort" and kind=="front" and formation=="ring": return true
	if id=="spec_collect" and kind=="pincer" and formation=="scatter": return true
	return formation==str({"front":"wedge","pincer":"ring","artillery":"scatter"}.get(kind,"wedge"))
