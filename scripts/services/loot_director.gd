extends Node

signal equipment_changed(stats: Dictionary)
signal loot_collected(item: Dictionary, replaced: Dictionary, equipped: bool)
signal loot_dropped(item: Dictionary, position: Vector2)

const CATALOG := preload("res://scripts/services/equipment_catalog.gd")
const PICKUP := preload("res://scripts/pickups/equipment_pickup.gd")
const FIRST_DROP_PITY := 12
const REGULAR_DROP_PITY := 28
const MAX_WORLD_DROPS := 10
const RNG_SALT := 32452843

var run_rng := RandomNumberGenerator.new()
var arena: Node2D = null
var slots: Dictionary = {}
var bonuses: Dictionary = CATALOG.empty_bonuses()
var kills_since_drop: int = 0
var regular_kills: int = 0
var common_streak: int = 0
var drop_count: int = 0
var collected_count: int = 0
var salvaged_count: int = 0
var serial: int = 0
var run_generation: int = 0
var claimed_items: Dictionary = {}
var drop_history: Array[Dictionary] = []
var pending_items: Dictionary = {}
var world_drops: Array[Node2D] = []
var last_message: String = "擊殺敵人可取得裝備；菁英必掉稀有以上。"


func _ready() -> void:
	add_to_group("loot_director")


func setup(run_arena: Node2D, run_seed: int) -> void:
	arena = run_arena
	reset_run(run_seed)


func reset_run(run_seed: int) -> void:
	# This stream must never consume the globally seeded encounter RNG.
	run_rng.seed = run_seed ^ RNG_SALT
	for drop in world_drops:
		if is_instance_valid(drop):
			drop.queue_free()
	world_drops.clear()
	slots.clear()
	bonuses = CATALOG.empty_bonuses()
	kills_since_drop = 0
	regular_kills = 0
	common_streak = 0
	drop_count = 0
	collected_count = 0
	salvaged_count = 0
	serial = 0
	run_generation += 1
	claimed_items.clear()
	drop_history.clear()
	pending_items.clear()
	last_message = "擊殺敵人可取得裝備；菁英必掉稀有以上。"
	apply_squad_bonuses()
	_emit_changed()


func on_enemy_defeated(position: Vector2, is_elite: bool = false, is_boss: bool = false, type_id: String = "") -> Dictionary:
	var item := roll_drop(is_elite, is_boss)
	if item.is_empty():
		return {}
	item["source"] = "boss" if is_boss else "elite" if is_elite else type_id
	if is_boss:
		# The stage-clear modal immediately pauses the world. Claim the reward now
		# and retain a visible burst, rather than strand it beneath that modal.
		collect_all_loot()
		collect_item(item)
		if EntityFactory.has_method("spawn_death_burst"):
			EntityFactory.call_deferred("spawn_death_burst", position, item["color"], 1.6, "elite_death")
	else:
		call_deferred("_spawn_world_drop", item, position, run_generation)
	loot_dropped.emit(item.duplicate(true), position)
	return item


func roll_drop(is_elite: bool = false, is_boss: bool = false, run_level: int = -1) -> Dictionary:
	if not is_elite and not is_boss:
		regular_kills += 1
		kills_since_drop += 1
		var pity := FIRST_DROP_PITY if drop_count == 0 else REGULAR_DROP_PITY
		var chance := 0.035 + minf(float(kills_since_drop) * 0.0025, 0.09)
		if kills_since_drop < pity and run_rng.randf() >= chance:
			return {}
	var rarity := _roll_rarity(is_elite, is_boss)
	var slot := _roll_slot()
	serial += 1
	var level := maxi(1, int(GameManager.level) if run_level < 0 else run_level)
	var item := CATALOG.make_item(slot, rarity, level, serial)
	item["generation"] = run_generation
	kills_since_drop = 0
	drop_count += 1
	common_streak = common_streak + 1 if rarity == 0 else 0
	drop_history.append(item.duplicate(true))
	if drop_history.size() > 64:
		drop_history.pop_front()
	pending_items[serial] = item.duplicate(true)
	return item


func _roll_rarity(is_elite: bool, is_boss: bool) -> int:
	if is_boss:
		return 3
	var roll := run_rng.randf()
	if is_elite:
		return 3 if roll < 0.06 else 2 if roll < 0.40 else 1
	if common_streak >= 3:
		return 1
	return 3 if roll < 0.015 else 2 if roll < 0.09 else 1 if roll < 0.34 else 0


func _roll_slot() -> String:
	var missing: Array[String] = []
	for slot in CATALOG.SLOTS:
		if not slots.has(slot):
			missing.append(slot)
	if not missing.is_empty():
		# Reserve slots of world drops too, so the opening burst can fill all three.
		for item in pending_items.values():
			missing.erase(str(item.get("slot", "")))
		if not missing.is_empty():
			return missing[run_rng.randi_range(0, missing.size() - 1)]
	return CATALOG.SLOTS[run_rng.randi_range(0, CATALOG.SLOTS.size() - 1)]


func _spawn_world_drop(item: Dictionary, position: Vector2, generation: int) -> void:
	if generation != run_generation or claimed_items.has(int(item.get("uid", 0))):
		return
	if arena == null or not is_instance_valid(arena):
		return
	_clean_world_drops()
	if world_drops.size() >= MAX_WORLD_DROPS:
		var oldest := world_drops.pop_front() as Node2D
		if is_instance_valid(oldest):
			oldest.collect_now()
	var drop := Node2D.new()
	drop.set_script(PICKUP)
	drop.name = "EquipmentDrop%d" % int(item.get("uid", 0))
	arena.add_child(drop)
	drop.global_position = position
	# Visual scatter must not advance the loot stream when deferred spawns run.
	drop.setup(self, item, fmod(float(int(item.get("uid", 0))) * 2.39996323, TAU))
	world_drops.append(drop)


func collect_item(item: Dictionary) -> bool:
	var uid := int(item.get("uid", 0))
	if uid <= 0 or claimed_items.has(uid) or int(item.get("generation", -1)) != run_generation:
		return false
	claimed_items[uid] = true
	pending_items.erase(uid)
	collected_count += 1
	var slot := str(item.get("slot", ""))
	var old: Dictionary = slots.get(slot, {})
	var equipped := old.is_empty() or float(item.get("power", 0.0)) > float(old.get("power", 0.0)) + 0.001
	if equipped:
		slots[slot] = item.duplicate(true)
		_recompute_bonuses()
		apply_squad_bonuses()
		last_message = "%s裝備：%s · %s" % ["換上更強" if not old.is_empty() else "取得", str(item.get("rarity_name", "")), str(item.get("name", ""))]
		# R33 uses a brief rarity banner; complete benefits remain in the inspector.
	else:
		salvaged_count += 1
		var gold := int(item.get("salvage_gold", 2))
		GameManager.add_gold(gold)
		last_message = "較弱裝備已拆解：%s · +%d 金幣" % [str(item.get("name", "")), gold]
	if AudioManager != null:
		AudioManager.play_sfx("upgrade" if equipped else "pickup", false, -1.0, 0.88 + float(int(item.get("rarity", 0))) * 0.1)
	loot_collected.emit(item.duplicate(true), old.duplicate(true), equipped)
	_emit_changed()
	return equipped


func collect_all_loot() -> void:
	# Include deferred world spawns as well as live pickups.
	for item in pending_items.values():
		if not claimed_items.has(int(item.get("uid", 0))):
			collect_item(item)
	for drop in world_drops:
		if is_instance_valid(drop):
			drop.queue_free()
	world_drops.clear()


func _clean_world_drops() -> void:
	for index in range(world_drops.size() - 1, -1, -1):
		if not is_instance_valid(world_drops[index]) or world_drops[index].is_queued_for_deletion():
			world_drops.remove_at(index)


func _recompute_bonuses() -> void:
	bonuses = CATALOG.empty_bonuses()
	for item in slots.values():
		var item_bonuses: Dictionary = item.get("bonuses", {})
		for key in bonuses:
			bonuses[key] = float(bonuses[key]) + float(item_bonuses.get(key, 0.0))


func apply_squad_bonuses() -> void:
	if GameManager.squad_manager != null and is_instance_valid(GameManager.squad_manager):
		for member in GameManager.squad_manager.get_members():
			apply_member_bonuses(member)
	elif GameManager.player != null and is_instance_valid(GameManager.player):
		apply_member_bonuses(GameManager.player)


func apply_member_bonuses(member: Node) -> void:
	if member == null or not is_instance_valid(member) or member.get("is_alive") == false:
		return
	var previous: Dictionary = member.get_meta("run_equipment_bonuses", CATALOG.empty_bonuses())
	for key in ["max_hp", "move_speed", "pickup_radius"]:
		if member.get(key) == null:
			continue
		var delta := float(bonuses.get(key, 0.0)) - float(previous.get(key, 0.0))
		member.set(key, float(member.get(key)) + delta)
		if key == "max_hp" and member.get("current_hp") != null:
			member.set("current_hp", clampf(float(member.get("current_hp")) + maxf(delta, 0.0), 0.0, float(member.get("max_hp"))))
	member.set_meta("run_equipment_bonuses", bonuses.duplicate(true))


func get_outgoing_damage_multiplier() -> float:
	return 1.0 + float(bonuses.get("damage", 0.0))


func get_incoming_damage_multiplier() -> float:
	# GM must combine this with contracts/bonds before its global soft cap.
	return 1.0 - minf(0.15, float(bonuses.get("damage_reduction", 0.0)))


func get_fire_rate_multiplier() -> float:
	return 1.0 + float(bonuses.get("fire_rate", 0.0))


func get_stats() -> Dictionary:
	var equipment_slots: Array[Dictionary] = []
	for slot in CATALOG.SLOTS:
		var item: Dictionary = slots.get(slot, {})
		equipment_slots.append(item.duplicate(true) if not item.is_empty() else {"slot": slot, "slot_name": CATALOG.SLOT_NAMES[slot], "name": "空槽", "rarity": -1})
	return {
		"equipment_slots": equipment_slots,
		"equipment_bonuses": bonuses.duplicate(true),
		"equipment_drop_count": drop_count,
		"equipment_collected": collected_count,
		"equipment_salvaged": salvaged_count,
		"loot_pity_remaining": maxi(0, (FIRST_DROP_PITY if drop_count == 0 else REGULAR_DROP_PITY) - kills_since_drop),
		"loot_last_message": last_message
	}


func _emit_changed() -> void:
	equipment_changed.emit(get_stats())
	if GameManager != null:
		GameManager.queue_stats_emit()
