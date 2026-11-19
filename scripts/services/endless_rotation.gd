extends RefCounted

# R49: endless no longer only adds numbers. Every WAVES_PER_RULE waves (30 s
# each) the special elites switch to another stage's signature rule. Nothing
# is copied: a rule is the existing stage_skill an elite carries (the same
# value special_elite_catalog gives that stage's elites), and enemy.gd's
# _apply_special_elite_impact spawns that stage's own hazard script. The first
# segment is the endless stage's own rule; after it the order comes from the
# run seed, so the same seed always meets the same rules in the same order.
# The rotation adds no penalty of its own: each hazard keeps its stage rules.
const SPECIAL_ELITES := preload("res://scripts/services/special_elite_catalog.gd")
const WAVES_PER_RULE := 3
const GROUPS := {"vine_snare":"vine_snares", "ember_ring":"ember_rings", "storm_pylon":"storm_pylons", "frost_wall":"frost_walls", "veil_lance":"veil_lances", "sand_glyphs":"sand_glyphs", "tide_sigil":"tide_sigils", "moon_bloom":"moon_blooms", "forge_core":"forge_cores"}
const POOL: Array[String] = ["vine_snare", "ember_ring", "storm_pylon", "frost_wall", "veil_lance", "sand_glyphs", "tide_sigil", "moon_bloom", "forge_core"]
# What to do, for the top bar's second line while no hazard of the rule is up
# (a live tide, bloom or core replaces it with its own countdown).
const HOW := {
	"vine_snare": "腳下冒藤時散開站位",
	"ember_ring": "火環包圍時往中心集合",
	"storm_pylon": "隊長踩隊長柱、散兵接隊員柱",
	"frost_wall": "霜牆推來時圓陣對準缺口穿過",
	"veil_lance": "影槍鎖定隊員時，隊長走過去護住",
	"sand_glyphs": "隊長先踩「先」再踩「後」",
	"tide_sigil": "浪到前換成潮紋上的陣形",
	"moon_bloom": "花蕾出現就走過去旋斬斬開",
	"forge_core": "撿起齒核送進基座，遠座更強",
}
# The existing per-run counters of each rule (GameManager fields): how often
# it was cast and how often the squad handled it.
const COUNTERS := {
	"vine_snare": ["vine_snares_cast", "vine_snares_clean"],
	"ember_ring": ["ember_rings_cast", "ember_rings_clean"],
	"storm_pylon": ["storm_pylons_cast", "storm_pylons_grounded"],
	"frost_wall": ["frost_walls_cast", "frost_walls_clean"],
	"veil_lance": ["veil_lances_cast", "veil_lances_blocked"],
	"sand_glyphs": ["sand_glyphs_cast", "sand_glyphs_solved"],
	"tide_sigil": ["tide_sigils_cast", "tide_sigils_matched"],
	"moon_bloom": ["moon_blooms_cast", "moon_blooms_cut"],
	"forge_core": ["forge_cores_cast", "forge_cores_set"],
}
# The verb for a handled cast, as each stage's result line already says it.
const DONE := {
	"vine_snare": "沒人被纏", "ember_ring": "全員躲過", "storm_pylon": "成功分流", "frost_wall": "全員穿過",
	"veil_lance": "隊長護住", "sand_glyphs": "解開", "tide_sigil": "換對", "moon_bloom": "斬開", "forge_core": "送進基座",
}
# One thing to do next time, per rule.
const TIPS := {
	"vine_snare": "下次藤圈一冒出就換散兵，隊員別擠在圈裡",
	"ember_ring": "下次火環圍上來就帶隊往中心走",
	"storm_pylon": "下次隊長踩隊長柱，換散兵讓隊員接另一根",
	"frost_wall": "下次霜牆推來前換圓陣，對準缺口穿過",
	"veil_lance": "下次影槍鎖定誰，隊長就走到他身邊",
	"sand_glyphs": "下次先踩亮著「先」的印記，再踩「後」",
	"tide_sigil": "下次看潮紋上的陣形，浪到前換過去",
	"moon_bloom": "下次留著能量，走到花蕾旁按住旋斬",
	"forge_core": "下次齒核一掉下就去撿，直接送進基座",
}

static func home_rule(stage_id: String) -> String:
	var skill := str(SPECIAL_ELITES.stage_variant(stage_id).get("skill", ""))
	return skill if POOL.has(skill) else ""

# The rule's name is the stage pressure its own elites already announce.
static func rule_name(rule: String) -> String:
	for stage_id in SPECIAL_ELITES.STAGE_VARIANTS:
		var variant: Dictionary = SPECIAL_ELITES.STAGE_VARIANTS[stage_id]
		if str(variant.get("skill", "")) == rule:
			return str(variant.get("pressure", ""))
	return ""

# One pass through the pool, shuffled by the run seed alone (a fixed integer
# mix, not hash(), so the order is the same on every platform). The first
# pass opens with the stage's own rule; a later pass never starts with the
# rule the previous one ended on.
static func cycle(seed_value: int, index: int, home: String, previous_last: String) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed_value) * 1000003 + index * 7919 + 49
	var rest: Array[String] = []
	for rule in POOL:
		if index == 0 and rule == home:
			continue
		rest.append(rule)
	for i in range(rest.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := rest[i]
		rest[i] = rest[j]
		rest[j] = swap
	if index == 0 and home != "":
		rest.push_front(home)
	elif rest.size() > 1 and rest[0] == previous_last:
		var swap := rest[0]
		rest[0] = rest[1]
		rest[1] = swap
	return rest

# The first `count` rules of a run (segment 0, 1, 2 ...).
static func order(seed_value: int, stage_id: String, count: int) -> Array[String]:
	var out: Array[String] = []
	var home := home_rule(stage_id)
	var index := 0
	while out.size() < count:
		out.append_array(cycle(seed_value, index, home, out.back() if not out.is_empty() else ""))
		index += 1
	return out.slice(0, count)

static func segment_of(wave: int) -> int:
	return maxi(0, wave - 1) / WAVES_PER_RULE

# Waves left in the current segment, this one included (3, 2, 1).
static func waves_left(wave: int) -> int:
	return WAVES_PER_RULE - (maxi(0, wave - 1) % WAVES_PER_RULE)

static func first_wave(segment: int) -> int:
	return segment * WAVES_PER_RULE + 1

# The forecast stays on line one even while line two carries an urgent notice.
static func top_line(rule: String, next_rule: String, left: int) -> String:
	return "%s｜%d 波後換%s" % [rule_name(rule), left, rule_name(next_rule)]

static func how_line(rule: String) -> String:
	return str(HOW.get(rule, ""))

# Counter values at one moment ({field: value}) from any object with the fields.
static func read_counts(source: Object) -> Dictionary:
	var out := {}
	for rule in COUNTERS:
		for field in COUNTERS[rule]:
			out[field] = int(source.get(field))
	return out

# How one rule went between two counter snapshots.
static func tally(rule: String, start: Dictionary, now: Dictionary) -> Dictionary:
	var fields: Array = COUNTERS.get(rule, [])
	if fields.is_empty():
		return {"cast": 0, "ok": 0}
	var cast := maxi(0, int(now.get(fields[0], 0)) - int(start.get(fields[0], 0)))
	var handled := int(now.get(fields[1], 0)) - int(start.get(fields[1], 0))
	return {"cast": cast, "ok": clampi(handled, 0, cast)}

static func tally_text(rule: String, row: Dictionary) -> String:
	if int(row.get("cast", 0)) <= 0:
		return "菁英沒出招"
	return "%s %d/%d" % [str(DONE.get(rule, "處理")), int(row.get("ok", 0)), int(row.get("cast", 0))]

# The settlement: the rules the run reached in order (with their waves), how
# each went, and one thing to change. `rules` is the run's rule order.
static func summary(rules: Array, final_wave: int, start: Dictionary, now: Dictionary) -> Dictionary:
	var reached := segment_of(final_wave) + 1
	var segments: Array = []
	var seen: Array[String] = []
	for segment in range(mini(reached, rules.size())):
		var rule := str(rules[segment])
		segments.append({"rule": rule, "name": rule_name(rule), "from": first_wave(segment), "to": mini(final_wave, first_wave(segment) + WAVES_PER_RULE - 1)})
		if not seen.has(rule):
			seen.append(rule)
	var rows: Array = []
	var cast := 0
	var handled := 0
	for rule in seen:
		var row := tally(rule, start, now)
		row["rule"] = rule
		row["name"] = rule_name(rule)
		var waves := PackedStringArray()
		for segment in segments:
			if segment.rule == rule:
				waves.append(("%d" % segment.from) if segment.from == segment.to else ("%d–%d" % [segment.from, segment.to]))
		row["waves"] = "、".join(waves)
		cast += int(row.cast)
		handled += int(row.ok)
		rows.append(row)
	var last_rule := str(segments.back().rule) if not segments.is_empty() else ""
	var next_rule := str(rules[reached]) if rules.size() > reached else ""
	return {"final_wave": final_wave, "waves_per_rule": WAVES_PER_RULE, "segments": segments, "rules": rows, "cast": cast, "handled": handled, "last_rule": last_rule, "next_rule": next_rule, "tip": tip(rows, last_rule, next_rule, final_wave)}

# One concrete change: the rule the run ended in when it went wrong there,
# else the rule handled worst, else what comes next.
static func missed_rule(rows: Array, last_rule: String) -> Dictionary:
	var worst: Dictionary = {}
	var worst_share := 2.0
	for row in rows:
		var cast := int(row.get("cast", 0))
		if cast <= 0 or int(row.get("ok", 0)) >= cast:
			continue
		var share := float(row.get("ok", 0)) / float(cast)
		if str(row.get("rule", "")) == last_rule:
			share -= 1.0
		if share < worst_share:
			worst_share = share
			worst = row
	return worst

static func tip(rows: Array, last_rule: String, next_rule: String, final_wave: int) -> String:
	var worst := missed_rule(rows, last_rule)
	if not worst.is_empty():
		return str(TIPS.get(str(worst.rule), ""))
	if next_rule != "":
		return "下次打完第 %d 波會換成「%s」，%s" % [first_wave(segment_of(final_wave) + 1) - 1, rule_name(next_rule), how_line(next_rule)]
	return str(TIPS.get(last_rule, ""))

# Keep one actual rule per stage. Forecast rules never count as encounters.
static func practice_record(data: Dictionary) -> Dictionary:
	var total := int(data.cast)
	if total == 0:
		return {"total": 0}
	var rows: Array = data.rules
	var focus := missed_rule(rows, str(data.last_rule))
	if focus.is_empty():
		# Everything was handled. Show the rule the squad handled most often.
		for row in rows:
			if int(row.cast) > int(focus.get("cast", 0)):
				focus = row
	return {"total": total, "rule": focus.rule, "cast": focus.cast, "ok": focus.ok}

static func practice_text(record: Variant) -> String:
	if not record is Dictionary or not record.get("total") is int:
		return ""
	if record.total == 0:
		return "上次無盡結束前，菁英還沒出招。" if record.get("cast", 0) == 0 and record.get("ok", 0) == 0 else ""
	var rule := str(record.get("rule", ""))
	if not POOL.has(rule) or not record.get("cast") is int or not record.get("ok") is int:
		return ""
	var cast := int(record.cast)
	var ok := int(record.ok)
	if cast <= 0 or cast > int(record.total) or ok < 0 or ok > cast:
		return ""
	if ok < cast:
		return "上次無盡處理了 %d/%d 次%s。%s。" % [ok, cast, rule_name(rule), TIPS[rule]]
	return "上次無盡 %d 招全數處理，包含 %d 次%s。下次也記得%s。" % [record.total, ok, rule_name(rule), HOW[rule]]

# The summary page's two lines.
static func summary_lines(data: Dictionary) -> String:
	if data.is_empty():
		return ""
	var rows: Array = data.get("rules", [])
	return "遇到 %d 種規則・處理成功 %d/%d 次\n%s" % [rows.size(), int(data.get("handled", 0)), int(data.get("cast", 0)), str(data.get("tip", ""))]
