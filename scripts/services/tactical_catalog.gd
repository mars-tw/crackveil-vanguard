extends RefCounted

const STAGES := preload("res://scripts/services/stage_catalog.gd")
const MEDALS: Array[Dictionary] = [
	{"id": "maneuver", "bit": 1, "reward": 3, "name": "三陣演練"},
	{"id": "hunt", "bit": 2, "reward": 5, "name": "雙菁追獵"},
	{"id": "clear", "bit": 4, "reward": 8, "name": "守關突破"}
]
const GUARDS := {"moon":"shield", "garden":"charge", "ember":"flame", "storm":"charge", "frost":"frost", "veil":"summoner", "dunes":"shield", "tide":"frost", "bloom":"summoner", "forge":"flame"}
const RECORDS := {
	"moon":"空庭石碑亮起三道紋路，先鋒第一次留下自己的陣線。",
	"garden":"狼群退去，晶枝上多了一片沒有裂痕的新葉。",
	"ember":"熔庭的餘燼中，一枚仍然溫熱的隊徽被帶了回來。",
	"storm":"雷聲停下後，斷橋另一端傳來了回應的號角。",
	"frost":"冰層下的足跡重見天光，先行者曾走過這條路。",
	"veil":"君主的帷幕落地，王座後方卻還有一道未開的門。",
	"dunes":"砂甲崩落，王陵深處的日晷終於開始轉動。",
	"tide":"歌聲散去，遺都的鐘聲第一次傳出了水面。",
	"bloom":"靈火熄滅的地方，新花替回不來的人記住了名字。",
	"forge":"最後一枚齒輪停下。裂隙之外，時間仍在前進。"
}

static func medal(id: String) -> Dictionary:
	for row in MEDALS:
		if str(row.id) == id:
			return row
	return {}

static func guard_id(stage: String) -> String:
	return str(GUARDS.get(stage, "shield"))
