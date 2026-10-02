extends Node

const ARENA := preload("res://scenes/arena/Arena.tscn")
const SHOP := preload("res://scripts/ui/summon_shop_screen.gd")
const PET := preload("res://scripts/services/pet_catalog.gd")
const SKILL := preload("res://scripts/services/skill_catalog.gd")
const PREFIX := "user://r36_summon_regression_"
var failures: Array[String] = []
var phase := "start"
var arena: Node


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	GameManager.campaign_save_path = PREFIX + "campaign.cfg"
	GameManager.wallet_gold = 0
	GameManager.campaign_clears.clear()
	PlayerSettings.debug_use_save_path(PREFIX + "settings.cfg",true)
	MetaProgress.debug_use_save_path(PREFIX + "meta.cfg",true)
	AchievementProgress.debug_use_save_path(PREFIX + "achievements.cfg",true)
	var blank := ConfigFile.new()
	blank.save(PREFIX + "campaign_pets.cfg")
	GameManager.forced_run_seed = 360036
	GameManager.run_mode = "campaign"
	arena = ARENA.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	_freeze()
	GameManager.critical_strikes_enabled = false
	GameManager.xp_required = 9999999
	var director: Node = arena.get_node("CoinSummonDirector")
	var screen: Node = arena.get_node("SummonShopScreen")
	phase = "unfunded_and_private_rng"
	GameManager.gold = 0
	GameManager.wallet_gold = 0
	var state_before: int = director.private_rng.state
	var rejected: Dictionary = director.request_draw("skill")
	_check(not rejected.ok and GameManager.gold == 0 and director.private_rng.state == state_before,"unfunded draw consumed money or RNG")
	seed(991133)
	var expected_random := randi()
	seed(991133)
	GameManager.add_gold(3000)
	var unpaid: Dictionary = director.request_draw("pet")
	_check(not bool(director.commit_draw(unpaid.draw_id,0).ok) and director.collection.is_empty() and GameManager.gold==3000,"unpaid pending token granted/saved a free pet")
	_check(director.cancel_draw(unpaid.draw_id),"unpaid rejected commit lost its cancellable pending")
	GameManager.open_summon_shop()
	(screen.skill_button as Button).pressed.emit()
	_check(randi() == expected_random,"draw touched the encounter/global RNG")
	_check(GameManager.gold == 2920 and not GameManager.paid_summon.is_empty() and screen.choice_buttons.size() == 3,"real draw button did not pay80 and show three legal cards")
	var token: String = GameManager.paid_summon.draw_id
	var option: Dictionary = director.pending.choice_options[0]
	_check(str(option.id) == "summon_skill", "first card did not guarantee a real proc spell")
	GameManager.purchase_summon("skill")
	_check(GameManager.gold == 2920,"pending double press charged twice")
	(screen.choice_buttons[0] as Button).pressed.emit()
	_check(GameManager.gold == 2920 and int(director.skill_levels.get(str(option.skill_id),0)) == 1 and director.pending.is_empty(),"real chosen card did not grant spell exactly once")
	GameManager.complete_summon(token,0)
	_check(GameManager.gold == 2920 and int(director.skill_levels[str(option.skill_id)]) == 1,"stale paid token duplicated grant or payment")
	_check(not bool(director.commit_draw(token,0).ok),"director accepted already committed token")
	(screen.skill_button as Button).pressed.emit()
	var guaranteed: Dictionary = director.pending.choice_options[0]
	(screen.close_button as Button).pressed.emit()
	_check(GameManager.gold == 2840 and director.pending.is_empty() and int(director.skill_levels.get(str(guaranteed.skill_id),0)) > 0 and not get_tree().paused,"paid close did not automatically deliver first card")
	print("R36_SUMMON_TRANSACTION unfunded_no_charge=true paid80_once=true stale_token_rejected=true close_paid_delivers=true private_rng=true")
	phase = "empty_pool_and_pity"
	var old_levels: Dictionary = director.skill_levels.duplicate(true)
	var old_counts: Dictionary = GameManager.upgrade_counts.duplicate(true)
	for id in SKILL.IDS:
		director.skill_levels[id] = 5
	for entry in SKILL.get_live_legal_pool():
		GameManager.upgrade_counts[GameManager._upgrade_level_key(entry)] = 999
	state_before = director.private_rng.state
	rejected = director.request_draw("skill")
	_check(not rejected.ok and director.private_rng.state == state_before and GameManager.gold == 2840,"empty/maxed skill pool consumed money/RNG")
	director.skill_levels = old_levels
	GameManager.upgrade_counts = old_counts
	director.skill_pity = 4
	var guarantee_result: Dictionary = director.request_draw("skill")
	var qualitative := false
	for entry in guarantee_result.choice_options:
		qualitative = qualitative or str(entry.get("upgrade_category","")) in ["qualitative","evolution"]
	var q_available: bool = director.get_debug_state().skill_qualitative_available
	_check(not q_available or qualitative,"fifth draw did not contain currently legal qualitative card")
	_check(director.cancel_draw(guarantee_result.draw_id),"unpaid prepared draw could not be cancelled")
	GameManager.open_summon_shop()
	phase = "permanent_pet_draws"
	var pet_count := 0
	while director.collection.size() < 3 and pet_count < 6:
		var balance: int = GameManager.gold
		(screen.pet_button as Button).pressed.emit()
		pet_count += 1
		_check(GameManager.gold == balance-120 and director.pending.is_empty(),"real pet draw did not spend120 and commit once")
	_check(director.collection.size() == 3 and director.pet_nodes.size() == 3,"third/sixth draw pity did not fill three unique pet slots")
	var has_duplicate := false
	for star_count in director.collection.values():
		has_duplicate = has_duplicate or int(star_count)>1
	if not has_duplicate:
		(screen.pet_button as Button).pressed.emit()
		pet_count += 1
		for star_count in director.collection.values():
			has_duplicate = has_duplicate or int(star_count)>1
	_check(has_duplicate,"duplicate pet did not increase stars")
	var collection: Dictionary = director.collection.duplicate(true)
	var pet_save := ConfigFile.new()
	_check(pet_save.load(director.save_path)==OK and pet_save.get_value("pets","collection",{})==collection,"pet collection/stars not persisted")
	(screen.close_button as Button).pressed.emit()
	for node in director.pet_nodes.values():
		node.set_physics_process(false)
	print("R36_PET_COLLECTION draws=%d slots=3 collection=%s duplicate_stars=true persisted=true" % [pet_count,collection])
	phase = "pet_true_frame2"
	for id in PET.IDS:
		await _test_pet(director.pet_nodes[id])
	phase = "four_true_proc_spells"
	for id in SKILL.IDS:
		if not director.skill_levels.has(id):
			director.grant_skill(id)
	var leader: Node = GameManager.player
	var visual: Node = leader.visual
	while visual.is_attack_animation():
		await get_tree().process_frame
	GameManager.elapsed_time = 30.0
	leader.active_ability_cooldown_timer = 0.0
	leader.momentum_charge = 0.0
	_check(leader.try_cast_active_ability(),"real hero active pose did not start")
	for skill_node in director.skill_nodes.values():
		_check(int(skill_node.casts)==0,"proc skill fired during anticipation")
	while visual.get("animated_sprite").frame < 2:
		await get_tree().process_frame
	await get_tree().process_frame
	for id in SKILL.IDS:
		var node: Node = director.skill_nodes[id]
		_check(node.casts==1 and node.last_cast_frame==2 and node.projectiles_spawned==int(SKILL.get_skill(id).count),"proc did not produce real8-12 projectiles onF2: "+id)
		print("R36_PROC_SKILL id=%s frame=%d casts=%d real_projectiles=%d" % [id,node.last_cast_frame,node.casts,node.projectiles_spawned])
	await get_tree().create_timer(1.2,true).timeout
	for id in SKILL.IDS:
		while visual.is_attack_animation():
			await get_tree().process_frame
		GameManager.elapsed_time += 5.0
		for other_id in SKILL.IDS:
			director.skill_nodes[other_id].last_cast_time = GameManager.elapsed_time if other_id != id else -999.0
		leader.active_ability_cooldown_timer = 0.0
		_check(leader.try_cast_active_ability(),"solo proc actual hero pose rejected")
		while visual.get("animated_sprite").frame < 2:
			await get_tree().process_frame
		await get_tree().process_frame
		var after_blade := _enemy_hp_sum()
		await get_tree().create_timer(1.2,true).timeout
		var projectile_damage := after_blade - _enemy_hp_sum()
		_check(projectile_damage>0.0,"proc spawned graphics but did no real delayed projectile damage: "+id)
		print("R36_PROC_REAL_DAMAGE id=%s delayed_damage=%.2f" % [id,projectile_damage])
	phase = "permanent_collection_next_run"
	GameManager.game_running = false
	GameManager.system_pause_owners.clear()
	GameManager.clear_time_scale_owners()
	get_tree().paused = false
	arena.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	arena = ARENA.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	_freeze()
	director = arena.get_node("CoinSummonDirector")
	_check(director.collection==collection and director.pet_nodes.size()==3 and director.skill_levels.is_empty(),"next run did not auto-spawn permanent pet stars or retained run-only spells")
	for node in director.pet_nodes.values():
		node.set_physics_process(false)
	print("R36_PET_NEXT_RUN collection_restored=true automatic_slots=3 run_skills_reset=true")
	phase = "responsive_native_ui"
	GameManager.gold = 500
	for dimensions in [Vector2i(1280,720),Vector2i(844,390),Vector2i(390,844),Vector2i(1024,768)]:
		var viewport := SubViewport.new()
		viewport.size = dimensions
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var shop: Node = SHOP.new()
		viewport.add_child(shop)
		shop.show_shop(director)
		for opening_frame in range(8):
			await get_tree().process_frame
		var prepared: Dictionary = director.request_draw("skill")
		shop.show_result(prepared)
		for frame in range(8):
			await get_tree().process_frame
		var ui: Dictionary = shop.get_debug_state()
		print("R36_SUMMON_UI_RECT viewport=%s panel=%s minimum=%s close=%s" % [dimensions,ui.panel_rect,shop.panel.get_combined_minimum_size(),ui.close_rect])
		var bounds := Rect2(Vector2.ZERO,Vector2(dimensions))
		_check(bounds.encloses(ui.panel_rect) and bounds.encloses(ui.close_rect) and ui.choice_count>0,"summon shop panel/close outside viewport: "+str(dimensions))
		_check(ui.skill_disabled and ui.pet_disabled,"pending paid choice did not disable more draws")
		for button in shop.choice_buttons:
			var margin_box: MarginContainer = button.get_child(0) as MarginContainer
			var stack: VBoxContainer = margin_box.get_child(0) as VBoxContainer
			for label in stack.get_children():
				if label is Label:
					_check(label.get_global_rect().end.y <= button.get_global_rect().end.y+1,"paid skill text clipped below card: "+str(dimensions))
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://docs/evidence/r36/ui")
			viewport.get_texture().get_image().save_png("res://docs/evidence/r36/ui/summon_%dx%d.png" % [dimensions.x,dimensions.y])
		director.cancel_draw(prepared.draw_id)
		viewport.queue_free()
		await get_tree().process_frame
		print("R36_SUMMON_UI size=%s scroll=true close_reachable=true paid_choice=%d" % [str(dimensions),int(ui.choice_count)])
	if failures.is_empty():
		print("R36_SUMMON_REGRESSION_PASS isolated_saves=5 real_paid_buttons=true no_double_spend=true guaranteed_spell=true pets_permanent=true pets_frame2=true four_proc_skills_frame2=true UI4sizes=true")
		get_tree().quit(0)
	else:
		get_tree().quit(1)


func _test_pet(pet: Node) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		EntityFactory.release_enemy(enemy)
	var targets: Array[Node] = []
	for index in range(3):
		var enemy: Node = EntityFactory.spawn_enemy("pet_fixture", {"max_hp":10000.0,"speed":0.0,"damage":0.0,"xp":0,"gold":0,"radius":13.0,"sprite_path":"res://assets/sprites/enemy_grunt.png"},pet.global_position+Vector2(70+index*18,0))
		enemy.set_physics_process(false)
		targets.append(enemy)
	GameManager.player.current_hp = maxf(1.0,GameManager.player.max_hp-40.0)
	var hp_before := float(GameManager.player.current_hp)
	var impacts_before := int(pet.impact_events)
	pet.cooldown = 0.0
	pet._physics_process(0.016)
	_check(pet.sprite.animation==&"attack" and pet.impact_events==impacts_before and float(targets[0].hp)==10000.0,"pet dealt damage before authored impact: "+str(pet.pet_id))
	while pet.impact_events==impacts_before:
		await get_tree().process_frame
	_check(pet.last_hit_frame==2,"pet hit outsideF2")
	await get_tree().create_timer(0.6,true).timeout
	_check(float(targets[0].hp)<10000.0 and pet.damage_dealt>0.0,"pet did no actual damage: "+str(pet.pet_id))
	if pet.pet_id=="spirit_rabbit":
		_check(GameManager.player.current_hp>hp_before and pet.healing_done>0.0,"rabbit did not heal lowestHP teammate")
	_check(PET.star_multiplier(2)>PET.star_multiplier(1) and PET.cooldown_multiplier(2)<PET.cooldown_multiplier(1),"duplicate star did not improve realDPS")
	print("R36_PET_FRAME id=%s impact_frame=%d real_damage=%.2f heal=%.2f shots=%d" % [pet.pet_id,pet.last_hit_frame,pet.damage_dealt,pet.healing_done,pet.shots])


func _freeze() -> void:
	GameManager.set_process(false)
	GameManager.auto_upgrade_enabled = false
	arena.get_node("EnemySpawner").set_process(false)
	for actor in get_tree().get_nodes_in_group("heroes"):
		actor.set_process(false)
		actor.set_physics_process(false)
		for child in actor.get_children():
			if child.is_in_group("hero_controllers"):
				child.set_process(false)
				child.set_physics_process(false)
		for weapon in actor.weapons.values():
			weapon.set_process(false)
			weapon.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		EntityFactory.release_enemy(enemy)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("R36_SUMMON_FAIL phase=%s: %s" % [phase,message])


func _enemy_hp_sum() -> float:
	var total := 0.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and bool(enemy.get("is_active")):
			total += float(enemy.get("hp"))
	return total
