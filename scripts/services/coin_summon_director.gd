extends Node

signal changed(state: Dictionary)
signal draw_prepared(result: Dictionary)
signal draw_committed(result: Dictionary)
const SKILL := preload("res://scripts/services/skill_catalog.gd")
const PET := preload("res://scripts/services/pet_catalog.gd")
const PET_SCENE := preload("res://scenes/pets/CompanionPet.tscn")
const SKILL_SCRIPT := preload("res://scripts/pets/summoned_skill.gd")
const COSTS := {"skill":80, "pet":120}
const RNG_SALT := 49979687
var save_path := "user://coin_summon_pets.cfg"
var arena: Node2D
var private_rng := RandomNumberGenerator.new()
var collection: Dictionary = {}
var pet_nodes: Dictionary = {}
var skill_levels: Dictionary = {}
var skill_nodes: Dictionary = {}
var pending: Dictionary = {}
var pet_draws := 0
var pet_pity := 0
var skill_draws := 0
var skill_pity := 0
var serial := 0
var generation := 0


func _ready() -> void:
	add_to_group("coin_summon_director")


func setup(run_arena: Node2D, seed_value: int) -> void:
	arena = run_arena
	private_rng.seed = seed_value ^ RNG_SALT
	generation += 1
	pending.clear()
	skill_levels.clear()
	skill_nodes.clear()
	skill_draws = 0
	skill_pity = 0
	_load_collection()
	for id in PET.IDS:
		if int(collection.get(id, 0)) > 0:
			_spawn_pet(id)
	_emit()


func preview_cost(kind: String) -> int:
	return int(COSTS.get(kind, 0))


func can_draw(kind: String) -> Dictionary:
	if not COSTS.has(kind):
		return {"ok":false, "reason":"未知的抽取類型。"}
	if not GameManager.game_running or GameManager.is_game_over:
		return {"ok":false, "reason":"出擊後才能抽取。"}
	if not pending.is_empty():
		return {"ok":false, "reason":"先選完已抽到的技能。"}
	if GameManager.gold < preview_cost(kind):
		return {"ok":false, "reason":"還差 %d 金幣。" % (preview_cost(kind) - GameManager.gold)}
	if kind == "pet" and _pet_candidates().is_empty():
		return {"ok":false, "reason":"三隻寵物都已五星，無須再抽。"}
	if kind == "skill" and _summon_candidates().is_empty() and SKILL.get_live_legal_pool().is_empty():
		return {"ok":false, "reason":"目前沒有可提升的技能；不會扣款。"}
	return {"ok":true, "reason":""}


func request_draw(kind: String) -> Dictionary:
	var allowed := can_draw(kind)
	if not bool(allowed.ok):
		return {"ok":false, "cost":0, "reason":str(allowed.reason)}
	var rng_before: int = private_rng.state
	var options: Array[Dictionary] = []
	var pet: Dictionary = {}
	if kind == "skill":
		options = _roll_skill_options()
		if options.is_empty():
			private_rng.state = rng_before
			return {"ok":false, "cost":0, "reason":"沒有合法選項；不會扣款。"}
	else:
		var candidates := _pet_candidates()
		var unowned: Array[String] = []
		for id in candidates:
			if int(collection.get(id, 0)) == 0:
				unowned.append(id)
		var forced := pet_draws % 3 == 2 and not unowned.is_empty()
		var pool: Array[String] = unowned if forced else candidates
		var id: String = pool[private_rng.randi_range(0, pool.size() - 1)]
		pet = PET.get_pet(id)
		pet["previous_stars"] = int(collection.get(id, 0))
		pet["stars"] = int(collection.get(id, 0)) + 1
		pet["new"] = int(collection.get(id, 0)) == 0
		pet["guaranteed"] = forced
	serial += 1
	var token := "summon:%d:%d" % [generation, serial]
	pending = {"ok":true, "kind":kind, "draw_id":token, "cost":preview_cost(kind), "choice_options":options, "pet":pet, "reason":"", "paid":false, "rng_before":rng_before}
	var result := _public_pending()
	draw_prepared.emit(result)
	_emit()
	return result


func mark_paid(draw_id: String) -> bool:
	if pending.is_empty() or str(pending.draw_id) != draw_id:
		return false
	pending.paid = true
	return true


func cancel_draw(draw_id: String) -> bool:
	if pending.is_empty() or str(pending.draw_id) != draw_id or bool(pending.paid):
		return false
	private_rng.state = int(pending.rng_before)
	pending.clear()
	_emit()
	return true


func commit_draw(draw_id: String, choice_index: int = 0) -> Dictionary:
	if pending.is_empty() or str(pending.draw_id) != draw_id:
		return {"ok":false, "reason":"這次抽取已處理，沒有重複扣款或獎勵。"}
	if not bool(pending.get("paid",false)):
		return {"ok":false, "reason":"這次抽取尚未完成付款，沒有發放獎勵。"}
	var result := _public_pending()
	if str(pending.kind) == "skill":
		var choices: Array = pending.choice_options
		if choice_index < 0 or choice_index >= choices.size():
			return {"ok":false, "reason":"請選擇有效的技能卡。"}
		result["option"] = (choices[choice_index] as Dictionary).duplicate(true)
		result["message"] = "取得技能：" + str(result.option.get("name", "技能"))
		skill_draws += 1
		var had_qualitative := false
		for option in choices:
			if _is_qualitative(option):
				had_qualitative = true
		skill_pity = 0 if had_qualitative else mini(4, skill_pity + 1)
	else:
		var pet: Dictionary = pending.pet
		var prior_draws := pet_draws
		var prior_pity := pet_pity
		collection[str(pet.id)] = int(pet.stars)
		pet_draws += 1
		pet_pity = pet_draws % 3
		if not _save_collection():
			if int(pet.previous_stars) > 0:
				collection[str(pet.id)] = int(pet.previous_stars)
			else:
				collection.erase(str(pet.id))
			pet_draws = prior_draws
			pet_pity = prior_pity
			private_rng.state = int(pending.rng_before)
			pending.clear()
			return {"ok":false, "reason":"寵物收藏未能存檔，請退回本次金幣。"}
		_spawn_pet(str(pet.id))
		result["message"] = "%s%s · %d 星" % ["新夥伴：" if bool(pet.new) else "重複升星：", str(pet.name), int(pet.stars)]
	pending.clear()
	draw_committed.emit(result)
	_emit()
	return result


func grant_skill(skill_id: String) -> Dictionary:
	if not SKILL.IDS.has(skill_id) or not is_instance_valid(arena):
		return {"ok":false, "reason":"法術資料不存在。"}
	var current := int(skill_levels.get(skill_id, 0))
	if current >= SKILL.MAX_LEVEL:
		return {"ok":false, "reason":"這個法術已達五級。"}
	skill_levels[skill_id] = current + 1
	if is_instance_valid(skill_nodes.get(skill_id)):
		skill_nodes[skill_id].set_level(current + 1)
	else:
		var node: Node = SKILL_SCRIPT.new()
		node.name = "SummonedSkill_" + skill_id
		arena.add_child(node)
		node.setup(skill_id, current + 1)
		skill_nodes[skill_id] = node
	_emit()
	return {"ok":true, "id":skill_id, "name":str(SKILL.get_skill(skill_id).name), "level":current + 1}


func _summon_candidates() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for id in SKILL.IDS:
		var current := int(skill_levels.get(id, 0))
		if current < SKILL.MAX_LEVEL:
			options.append(SKILL.make_option(id, current))
	return options


func _roll_skill_options() -> Array[Dictionary]:
	var chosen: Array[Dictionary] = []
	var spells := _summon_candidates()
	if not spells.is_empty():
		chosen.append(_take_random(spells))
	var regular: Array[Dictionary] = []
	var qualitative: Array[Dictionary] = []
	for option in SKILL.get_live_legal_pool():
		(qualitative if _is_qualitative(option) else regular).append(option)
	var force_qualitative := skill_pity >= 4 and not qualitative.is_empty()
	while chosen.size() < 3:
		var use_qualitative := force_qualitative or (not qualitative.is_empty() and private_rng.randf() < 0.25)
		var pool: Array[Dictionary] = qualitative if use_qualitative else regular
		if pool.is_empty():
			pool = regular if use_qualitative else qualitative
		if pool.is_empty():
			if spells.is_empty():
				break
			chosen.append(_take_random(spells))
		else:
			chosen.append(_take_random(pool))
		force_qualitative = false
	return chosen


func _take_random(pool: Array[Dictionary]) -> Dictionary:
	var index := private_rng.randi_range(0, pool.size() - 1)
	var result: Dictionary = pool[index].duplicate(true)
	pool.remove_at(index)
	return result


func _is_qualitative(option: Dictionary) -> bool:
	return str(option.get("upgrade_category", "")) in ["qualitative", "evolution"]


func _pet_candidates() -> Array[String]:
	var options: Array[String] = []
	for id in PET.IDS:
		if int(collection.get(id, 0)) < PET.MAX_STARS:
			options.append(id)
	return options


func _spawn_pet(id: String) -> void:
	if is_instance_valid(pet_nodes.get(id)):
		pet_nodes[id].apply_stars(int(collection[id]))
		return
	if not is_instance_valid(arena):
		return
	var index := pet_nodes.size()
	var node: Node = PET_SCENE.instantiate()
	node.name = "Companion_" + id
	arena.add_child(node)
	node.setup(id, int(collection[id]), index)
	pet_nodes[id] = node


func _load_collection() -> void:
	collection.clear()
	pet_nodes.clear()
	pet_draws = 0
	pet_pity = 0
	var save := ConfigFile.new()
	if save.load(save_path) != OK:
		return
	var stored: Variant = save.get_value("pets", "collection", {})
	if stored is Dictionary:
		for id in PET.IDS:
			var count := clampi(int(stored.get(id, 0)), 0, PET.MAX_STARS)
			if count > 0:
				collection[id] = count
	pet_draws = maxi(0, int(save.get_value("pets", "draws", 0)))
	pet_pity = clampi(int(save.get_value("pets", "pity", 0)), 0, 2)


func _save_collection() -> bool:
	var save := ConfigFile.new()
	save.set_value("pets", "collection", collection)
	save.set_value("pets", "draws", pet_draws)
	save.set_value("pets", "pity", pet_pity)
	var destination := ProjectSettings.globalize_path(save_path)
	var temporary := destination + ".tmp"
	if save.save(temporary) != OK:
		return false
	# Godot's same-volume rename replaces atomically. A failed temp write or
	# failed replacement leaves the prior complete collection untouched.
	var replaced := DirAccess.rename_absolute(temporary,destination)
	if replaced != OK:
		DirAccess.remove_absolute(temporary)
		return false
	return true


func _public_pending() -> Dictionary:
	var result := pending.duplicate(true)
	result.erase("rng_before")
	return result


func get_pending_result() -> Dictionary:
	return _public_pending() if not pending.is_empty() else {}


func get_debug_state() -> Dictionary:
	var pets: Array[Dictionary] = []
	var skills: Array[Dictionary] = []
	for id in pet_nodes:
		if is_instance_valid(pet_nodes[id]):
			pets.append(pet_nodes[id].get_debug_state())
	for id in skill_nodes:
		if is_instance_valid(skill_nodes[id]):
			skills.append(skill_nodes[id].get_debug_state())
	var candidates := _pet_candidates()
	var odds: Array[Dictionary] = []
	var unowned: Array[String] = []
	for id in candidates:
		if int(collection.get(id, 0)) == 0:
			unowned.append(id)
	var pool: Array[String] = unowned if pet_draws % 3 == 2 and not unowned.is_empty() else candidates
	for id in PET.IDS:
		odds.append({"id":id, "name":str(PET.get_pet(id).name), "percent":100.0 / pool.size() if pool.has(id) else 0.0})
	var spell_odds: Array[Dictionary] = []
	var spells := _summon_candidates()
	for spell in spells:
		spell_odds.append({"id":str(spell.skill_id), "name":str(spell.name), "percent":100.0/spells.size()})
	var regular_count := 0
	var qualitative_count := 0
	for option in SKILL.get_live_legal_pool():
		if _is_qualitative(option):
			qualitative_count += 1
		else:
			regular_count += 1
	var qualitative_percent := 25 if regular_count > 0 else 100
	if qualitative_count == 0:
		qualitative_percent = 0
	return {"skill_cost":80, "pet_cost":120, "skill_draws":skill_draws, "pet_draws":pet_draws, "skill_pity_remaining":5-skill_pity, "skill_qualitative_percent":qualitative_percent, "skill_qualitative_available":qualitative_count > 0, "skill_pity_active":skill_pity >= 4 and qualitative_count > 0, "pet_pity_remaining":3-pet_pity, "collection":collection.duplicate(true), "skill_levels":skill_levels.duplicate(true), "skills":skills, "pets":pets, "pet_odds":odds, "spell_odds":spell_odds, "pending":not pending.is_empty(), "pending_id":str(pending.get("draw_id", "")), "save_path":save_path}


func _emit() -> void:
	changed.emit(get_debug_state())
