extends Node

const ARENA := preload("res://scenes/arena/Arena.tscn")
const HERO_SCENE := preload("res://scenes/heroes/Hero.tscn")
const AXES: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
const NEW_HEROES := ["solar_lancer", "tide_oracle", "shadow_ronin"]
const NEW_WEAPONS := ["solar_piercer", "tidal_covenant", "shadow_twinblades"]
var failures: Array[String] = []
var evidence: Dictionary = {"test_kind": "controlled actual physics/animation fixture; not natural DPS", "art_directions": "existing horizontal mirror and logical aim vectors; no claim of true eight-direction artwork", "axes": [], "follower_weapons": []}
var arena: Node
var captain: Node2D
var visual: Node
var presentation: Node
var impact_frame := -1
var impact_origin := Vector2.ZERO
var observed_direction := Vector2.ZERO
var observed_fx: Dictionary = {}

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	if "--r40-parse-only" in OS.get_cmdline_user_args():
		var stub := HERO_SCENE.instantiate()
		print("R40_PARSE_ONLY_PASS api_ready=%s (no physics/animation assertions executed)" % str(stub.has_method("begin_directional_attack") and stub.has_method("get_visual_facing_direction")))
		stub.free()
		get_tree().quit(0)
		return
	var stub := HERO_SCENE.instantiate()
	var ready := stub.has_method("begin_directional_attack") and stub.has_method("get_visual_facing_direction")
	stub.free()
	_check(ready, "required directional attack / visual facing API is not ready")
	if not ready:
		_finish()
		return
	GameManager.campaign_save_path = "user://r40_facing_attack_campaign.cfg"
	GameManager.wallet_gold = 0
	GameManager.paid_summon.clear()
	PlayerSettings.debug_use_save_path("user://r40_facing_attack_settings.cfg", true)
	MetaProgress.debug_use_save_path("user://r40_facing_attack_meta.cfg", true)
	AchievementProgress.debug_use_save_path("user://r40_facing_attack_achievements.cfg", true)
	var pets := ConfigFile.new()
	pets.save("user://r40_facing_attack_campaign_pets.cfg")
	GameManager.set_process(false)
	arena = ARENA.instantiate()
	add_child(arena)
	await get_tree().process_frame
	arena.get_node("EnemySpawner").set_process(false)
	captain = GameManager.player
	visual = captain.get_node("Visual")
	presentation = arena.get_node("CombatPresentation")
	_check(bool(presentation.get_debug_state().get("assets_ready", false)), "real authored presentation assets unavailable")
	_disable_controllers_and_other_combat()
	_clear_enemy_fixture()
	visual.attack_impact.connect(_on_captain_impact)
	await _test_locomotion()
	await _test_same_frame_controller()
	for axis in AXES:
		await _test_captain_cast(axis, false)
		await _test_captain_cast(axis, true)
	await _test_reactions_and_reset()
	await _test_follower_weapons()
	evidence["last_visual_debug"] = visual.get_debug_state()
	evidence["presentation_debug"] = presentation.get_debug_state()
	_finish()

func _disable_controllers_and_other_combat() -> void:
	for member in GameManager.squad_manager.get_members():
		member.set_process(false)
		if member != captain:
			member.set_physics_process(false)
		for child in member.get_children():
			if child.is_in_group("hero_controllers"):
				child.set_physics_process(false)
		for weapon in member.weapons.values():
			weapon.set_process(false)
	# OrbitProjectile shares the general projectiles group. Isolate its pool
	# directly so old 8-damage orbit contacts cannot masquerade as early cleave.
	for projectile in EntityFactory.pools.orbit_projectile.get_live_nodes():
		projectile.set_physics_process(false)

func _clear_enemy_fixture() -> void:
	for enemy in EntityFactory.pools.enemy.get_live_nodes():
		EntityFactory.release_enemy(enemy)
	for projectile in EntityFactory.pools.projectile.get_live_nodes():
		EntityFactory.release_projectile(projectile)
	for effect in presentation.active.duplicate():
		presentation._release(effect)

func _target(position: Vector2) -> Node2D:
	var enemy: Node2D = EntityFactory.spawn_enemy("grunt", {"max_hp":100000.0, "speed":0.0, "damage":0.0, "xp":0, "gold":0, "radius":14.0, "attack_cooldown":999.0}, position)
	enemy.set_physics_process(false)
	return enemy

func _snapshot(actor: Node) -> Dictionary:
	var actor_visual: Node = actor.get_node("Visual")
	return {"public_facing": str(actor.get_facing_direction()), "locomotion_facing": str(actor.get_locomotion_facing_direction()), "visual_facing": str(actor.get_visual_facing_direction()),
		"raw_facing": str(actor_visual.facing_direction), "flip_h": actor_visual.animated_sprite.flip_h,
		"sprite_rotation": actor_visual.animated_sprite.rotation, "root_rotation": actor_visual.rotation,
		"lock": str(actor.attack_direction_lock), "animation": actor_visual.get_debug_state()}

func _test_locomotion() -> void:
	captain.global_position = Vector2.ZERO
	captain.set_desired_velocity(Vector2.LEFT * captain.move_speed)
	_check(captain.get_facing_direction().is_equal_approx(Vector2.LEFT), "input facing did not use current-frame desired movement")
	_target(Vector2(95.0, 0.0))
	for _frame in range(8):
		await get_tree().physics_frame
		_check(captain.get_visual_facing_direction().is_equal_approx(Vector2.LEFT) and visual.facing_direction.is_equal_approx(Vector2.LEFT) and visual.animated_sprite.flip_h,
			"moving left with enemy right flopped visual to enemy")
	_check(visual.get_animation_state() == &"walk" and visual.animated_sprite.frame >= 0, "real walk animation was not used for moving hero")
	var vertical_rows: Array[Dictionary] = []
	for horizontal in [Vector2.LEFT, Vector2.RIGHT]:
		visual.set_facing_direction(horizontal)
		for vertical in [Vector2.UP, Vector2.DOWN]:
			captain.set_desired_velocity(vertical * captain.move_speed)
			for _frame in range(3):
				await get_tree().physics_frame
			_check(visual.facing_direction.is_equal_approx(vertical) and captain.get_visual_facing_direction().is_equal_approx(vertical), "north/south logical facing lost vertical input")
			_check(visual.animated_sprite.flip_h == (horizontal == Vector2.LEFT), "pure vertical input replaced prior horizontal mirror")
			_check(is_zero_approx(visual.rotation) and is_zero_approx(visual.animated_sprite.rotation), "vertical motion rotated whole body instead of using actual frames")
			vertical_rows.append(_snapshot(captain))
	var before: Vector2 = visual.facing_direction
	visual.set_facing_direction(Vector2.ZERO)
	_check(visual.facing_direction == before, "zero direction replaced visual facing")
	visual.set_facing_direction(Vector2(-3.0,4.0))
	_check(visual.facing_direction.is_equal_approx(Vector2(-0.6,0.8)), "visual direction did not normalize input")
	evidence["locomotion"] = {"left_with_enemy_right": true, "vertical_mirrors": vertical_rows, "zero_ignored": true, "normalized": true}
	print("R40_LOCOMOTION left_input_enemy_right=left vertical_vectors=up/down mirror_preserved=true sprite_rotation=0 zero_ignored=true")
	captain.set_desired_velocity(Vector2.ZERO)
	_clear_enemy_fixture()

func _test_captain_cast(axis: Vector2, automatic: bool) -> void:
	captain.reset_for_run()
	_disable_controllers_and_other_combat()
	captain.set_physics_process(true)
	captain.global_position = Vector2.ZERO
	_clear_enemy_fixture()
	var lure := _target(axis * 65.0)
	var front := _target(axis * 100.0)
	var rear := _target(-axis * 155.0)
	captain.set_desired_velocity(axis * captain.move_speed)
	captain.auto_cleave_cooldown_timer = 999.0
	impact_frame = -1
	observed_fx = {}
	if automatic:
		captain.auto_cleave_cooldown_timer = 0.0
		captain.call("_tick_captain_cleave", 0.0)
		captain.auto_cleave_cooldown_timer = 999.0
		_check(captain.auto_cleave_pending, "real automatic swing did not enter anticipation")
	else:
		_check(captain.try_cast_active_ability(), "manual active attack rejected")
		_check(captain.active_ability_pending, "manual active attack did not enter anticipation")
	_check(captain.attack_direction_lock.is_equal_approx(axis), "cast did not atomically lock selected aim")
	var busy_lock: Vector2 = captain.attack_direction_lock
	_check(not captain.begin_directional_attack(-axis), "busy begin_directional_attack incorrectly accepted replacement swing")
	_check(captain.attack_direction_lock == busy_lock, "rejected busy wrapper replaced current aim")
	var hp_front: float = front.hp
	var hp_rear: float = rear.hp
	var hp_lure: float = lure.hp
	_check(front.hp == hp_front and rear.hp == hp_rear, "cast dealt damage immediately on request")
	# A real target snapshot crosses behind the captain during anticipation;
	# movement input also reverses. The already-started active cone stays aimed.
	lure.global_position = -axis * 180.0
	EntityFactory.enemy_spatial_index.call("_update_enemy_cells")
	captain.set_desired_velocity(-axis * captain.move_speed)
	for _frame in range(100):
		await get_tree().physics_frame
		if impact_frame >= 0:
			break
		_check(captain.attack_direction_lock.is_equal_approx(axis) and visual.facing_direction.is_equal_approx(axis), "target cross or changed input rotated busy anticipation")
		_check(is_equal_approx(front.hp,hp_front) and is_equal_approx(rear.hp,hp_rear), "damage occurred before real animation frame2")
	_check(impact_frame == 2, "captain hit was not emitted at actual authored frame2")
	_check(front.hp < hp_front and is_equal_approx(rear.hp,hp_rear), "active cone did not distinguish front and opposite enemy")
	_check(is_equal_approx(lure.hp,hp_lure), "living target crossing behind was damaged by an uncommitted re-aim")
	_check(observed_direction.is_equal_approx(axis), "visual facing on actual hit did not match locked cone")
	_check(not observed_fx.is_empty(), "real slash animation not generated on impact")
	if not observed_fx.is_empty():
		_check(absf(angle_difference(float(observed_fx.rotation),axis.angle())) <= 0.001, "slash FX rotation disagrees with active cone")
		var expected := impact_origin + axis * 70.0 + Vector2(0,22)
		_check((observed_fx.position as Vector2).distance_to(expected) <= 0.05, "slash FX origin disagrees with locked aim / floor offset")
	var locked_state := _snapshot(captain)
	for _frame in range(100):
		if not visual.is_attack_animation():
			break
		await get_tree().physics_frame
		if visual.is_attack_animation():
			_check(captain.get_visual_facing_direction().is_equal_approx(axis), "busy recovery replaced committed facing")
	await get_tree().physics_frame
	_check(captain.get_visual_facing_direction().is_equal_approx(-axis), "completed recovery did not resume current movement facing")
	var result := {"axis": str(axis), "automatic": automatic, "frame": impact_frame, "front_damage": hp_front-float(front.hp),
		"rear_damage": hp_rear-float(rear.hp), "crossed_living_target_damage": hp_lure-float(lure.hp), "locked": locked_state, "after_recovery": _snapshot(captain), "fx": observed_fx}
	evidence.axes.append(result)
	print("R40_CAPTAIN axis=%s mode=%s impact_frame=%d front_damage=%.2f rear_damage=%.2f crossed_target_lock=true fx_direction=true" % [axis,"auto" if automatic else "manual",impact_frame,hp_front-float(front.hp),hp_rear-float(rear.hp)])
	captain.set_desired_velocity(Vector2.ZERO)
	_clear_enemy_fixture()

func _action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)

func _test_same_frame_controller() -> void:
	captain.reset_for_run()
	_disable_controllers_and_other_combat()
	_clear_enemy_fixture()
	var controller: Node = captain.get_node("PlayerController")
	controller.set_physics_process(true)
	impact_frame = -1
	# Both real action events enter before the next physics tick. With no target,
	# an old last-move value cannot hide a controller ordering error.
	_action(&"move_left",true)
	_action(&"active_ability",true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(captain.active_ability_pending and captain.attack_direction_lock.is_equal_approx(Vector2.LEFT), "same-frame LEFT+ability used stale last-move/right facing")
	_check(visual.facing_direction.is_equal_approx(Vector2.LEFT) and visual.animated_sprite.flip_h, "same-frame physical action route did not face authored attack left")
	var state := _snapshot(captain)
	controller.set_physics_process(false)
	_action(&"move_left",false)
	_action(&"active_ability",false)
	captain.set_desired_velocity(Vector2.ZERO)
	await get_tree().create_timer(0.4).timeout
	_check(impact_frame == 2, "same-frame controller cast skipped actual authored frame2")
	evidence["same_frame_controller"] = {"input":"InputEventAction move_left+active_ability before physics tick", "state":state, "impact_frame":impact_frame}
	print("R40_CONTROLLER same_frame_left_ability=true actual_controller=true locked_left=true authored_frame2=true")

func _on_captain_impact() -> void:
	impact_frame = visual.animated_sprite.frame
	observed_direction = visual.facing_direction
	impact_origin = captain.global_position
	for effect in presentation.active:
		if effect.kind == "slash_a" and effect.age <= 0.04:
			observed_fx = {"kind":effect.kind, "position":effect.global_position, "rotation":effect.rotation,
				"sprite_animation": str(effect.sprite.animation), "frame":effect.sprite.frame, "visible":effect.visible}

func _test_reactions_and_reset() -> void:
	captain.reset_for_run()
	_disable_controllers_and_other_combat()
	captain.set_desired_velocity(Vector2.ZERO)
	visual.set_facing_direction(Vector2.LEFT)
	_check(visual.play_hurt(), "real hurt pose did not start")
	captain.set_desired_velocity(Vector2.RIGHT * captain.move_speed)
	for _frame in range(3):
		await get_tree().physics_frame
		_check(visual.facing_direction.is_equal_approx(Vector2.LEFT) and visual.animated_sprite.flip_h, "hurt snapped to default/input right")
	await get_tree().create_timer(0.3).timeout
	visual.set_facing_direction(Vector2.LEFT)
	_check(visual.play_death(), "real death pose did not start")
	for _frame in range(3):
		await get_tree().physics_frame
		_check(captain.get_visual_facing_direction().is_equal_approx(Vector2.LEFT) and visual.animated_sprite.flip_h, "death snapped to default right")
	captain.reset_for_run()
	_disable_controllers_and_other_combat()
	for _frame in range(3):
		await get_tree().physics_frame
	_check(captain.attack_direction_lock == Vector2.RIGHT and captain.get_facing_direction() == Vector2.RIGHT and visual.facing_direction == Vector2.RIGHT and not visual.animated_sprite.flip_h,
		"run/reset inherited a prior death/attack facing")
	evidence["reactions"] = {"hurt_preserves_left":true,"death_preserves_left":true,"reset":_snapshot(captain)}
	print("R40_REACTIONS hurt_death_preserve_left=true reset_right=true sprite_rotation=0")

func _test_follower_weapons() -> void:
	var ids := ["rift_shepherd"] + NEW_HEROES
	var weapons := ["rift_constructs"] + NEW_WEAPONS
	for index in range(ids.size()):
		_check(GameManager.squad_manager.recruit_hero(ids[index]), "could not recruit actual follower " + str(ids[index]))
		var follower: Node2D = GameManager.squad_manager.get_member_by_id(ids[index])
		_disable_controllers_and_other_combat()
		follower.set_physics_process(true)
		follower.global_position = Vector2(1000+index*800,1000)
		follower.set_desired_velocity(Vector2.RIGHT * follower.move_speed)
		var target := _target(follower.global_position + Vector2(-110.0,0.0))
		var weapon: Node = follower.weapons[weapons[index]]
		var follower_visual: Node = follower.get_node("Visual")
		var events: Array[Dictionary] = []
		var on_impact := func() -> void: events.append({"frame":follower_visual.animated_sprite.frame,"state":_snapshot(follower)})
		follower_visual.attack_impact.connect(on_impact)
		var hp_before: float = target.hp
		var construct_before := EntityFactory.get_rift_construct_count_for_owner(follower)
		_check(weapon.call("_begin_cast",target), "follower weapon wrapper rejected legal left cast")
		_check(follower.attack_direction_lock.is_equal_approx(Vector2.LEFT), "follower cast kept default right attack lock")
		_check(not follower.begin_directional_attack(Vector2.RIGHT) and follower.attack_direction_lock.is_equal_approx(Vector2.LEFT), "busy follower wrapper replaced left aim")
		for _frame in range(100):
			await get_tree().physics_frame
			if not events.is_empty():
				break
			_check(follower_visual.facing_direction.is_equal_approx(Vector2.LEFT) and follower_visual.animated_sprite.flip_h, "follower physics replaced cast-facing with right movement")
			_check(is_equal_approx(target.hp,hp_before) and weapon.trigger_count == 0, "follower weapon fired in anticipation")
		_check(events.size() == 1 and events[0].frame == 2 and weapon.trigger_count == 1, "follower impact not committed once at real frame2")
		if index == 0:
			var constructs := EntityFactory.get_rift_constructs_for_owner(follower)
			_check(constructs.size() == construct_before+1 and constructs[-1].global_position.x < follower.global_position.x, "Shepherd actual construct placement does not match left locked target")
		else:
			await get_tree().create_timer(0.45).timeout
			_check(target.hp < hp_before, "new follower left cast did not produce actual damage/collision")
		follower_visual.attack_impact.disconnect(on_impact)
		evidence.follower_weapons.append({"hero":ids[index],"weapon":weapons[index],"events":events,"damage":hp_before-float(target.hp),"state":_snapshot(follower)})
		print("R40_FOLLOWER hero=%s weapon=%s actual_frame2=true locked_left=true" % [ids[index],weapons[index]])
		follower.set_physics_process(false)
		follower.set_desired_velocity(Vector2.ZERO)
		EntityFactory.release_rift_constructs_for_owner(follower,false)
		_clear_enemy_fixture()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("R40_FACING_ATTACK_FAIL "+message)

func _finish() -> void:
	evidence["failures"] = failures
	evidence["version"] = ProjectSettings.get_setting("application/config/version", "")
	DirAccess.make_dir_recursive_absolute("res://docs/evidence/r40")
	var file := FileAccess.open("res://docs/evidence/r40/facing_attack_test.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(evidence,"\t"))
	GameManager.game_running = false
	GameManager.player = null
	GameManager.squad_manager = null
	GameManager.arena = null
	get_tree().paused = false
	print("R40_FACING_ATTACK_" + ("PASS" if failures.is_empty() else "FAIL") + " physics=true authored_frame2=true art=horizontal_mirror_not8way")
	get_tree().quit(0 if failures.is_empty() else 1)
