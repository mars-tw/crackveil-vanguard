extends Node

const HERO_SCENE := preload("res://scenes/heroes/Hero.tscn")
const CAPTAIN := preload("res://resources/heroes/rift_captain.tres")
const LIBRARY := preload("res://scripts/animation/true_animation_library.gd")

class PresentationSpy:
	extends Node2D
	var effect_events: Array[Dictionary] = []
	var channel_on := false
	var updates := 0
	var owner_id := 0
	func _ready() -> void:
		add_to_group("combat_presentation")
	func play_effect(kind: String, origin: Vector2, direction: Vector2, strength: float = 1.0) -> void:
		effect_events.append({"kind": kind, "origin": origin, "direction": direction, "strength": strength})
	func set_channel(owner: Object, value: bool, _origin: Vector2, _direction: Vector2, _strength: float = 1.0) -> void:
		channel_on = value
		owner_id = owner.get_instance_id() if value else 0
		updates += 1
	func get_debug_state() -> Dictionary:
		return {"assets_ready": true, "channels": 1 if channel_on else 0}

var hero: Node2D
var spy: PresentationSpy
var failed := false
var impact_frames: Array[int] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	MetaProgress.debug_use_save_path("user://r35_combo_channel_meta.cfg", true)
	AchievementProgress.debug_use_save_path("user://r35_combo_channel_achievements.cfg", true)
	GameManager.game_running = false
	spy = PresentationSpy.new()
	add_child(spy)
	EntityFactory.initialize_for_arena(self)
	hero = HERO_SCENE.instantiate()
	add_child(hero)
	hero.setup(CAPTAIN, null, true, 0)
	hero.set_physics_process(false)
	for child in hero.get_children():
		if child.is_in_group("hero_controllers"):
			child.set_process(false)
			child.set_physics_process(false)
	for weapon in (hero.get("weapons") as Dictionary).values():
		weapon.set_process(false)
		weapon.set_physics_process(false)
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.set_physics_process(false)
	GameManager.player = hero
	GameManager.squad_manager = null
	GameManager.system_pause_owners.clear()
	GameManager.game_running = true
	get_tree().paused = false
	hero.get_node("Visual").attack_impact.connect(_on_impact)
	hero.set("auto_cleave_cooldown_timer", 999.0)
	for frame in range(3):
		await get_tree().process_frame
	_test_authored_frames()
	await _test_three_combo_impacts()
	await _test_buffered_tap_becomes_hold()
	await _test_release_before_impact()
	await _test_pause_cancels_pending()
	await _test_sustained_energy()
	await _test_light_and_heavy_hurt()
	await _test_keyboard_and_death_cleanup()
	if failed:
		return
	for frame in impact_frames:
		_assert(frame == 2, "an attack emitted damage away from its actual frame 2")
	print("CAPTAIN_COMBO_CHANNEL_R35_PASS authored_poses=18 shared_atlas=true damage_frame=2 combo=0/1/2 finisher=360 hold=sustained finite_energy=true release_recovery=true owner_cleanup=true")
	get_tree().quit(0)


func _test_authored_frames() -> void:
	var frames: SpriteFrames = LIBRARY.get_sprite_frames("res://assets/sprites/hero_captain.png")
	var regions: Dictionary = {}
	var atlas_id := LIBRARY.get_shared_atlas_instance_id()
	for name in LIBRARY.CAPTAIN_COMBO_NAMES:
		_assert(frames.has_animation(name) and frames.get_frame_count(name) == 6, "combo does not contain six authored poses")
		for index in range(6):
			var texture: AtlasTexture = frames.get_frame_texture(name, index)
			_assert(texture.atlas.get_instance_id() == atlas_id and texture.region.size == Vector2(160.0, 160.0), "new pose escaped the shared atlas or lost its body-scale region")
			regions[texture.region] = true
	_assert(regions.size() == 18 and int(hero.get_node("Visual").get_debug_state()["authored_combo"]) == 1, "combo frames duplicate regions or visual fell back to old attack")
	for state in LIBRARY.STATE_ORDER:
		_assert(frames.get_frame_count(state) == int(LIBRARY.FRAME_COUNTS[state]), "original 27-frame captain contract changed")
	print("CAPTAIN_R35_FRAMES unique_regions=18 region=160 foot_offset=54 original_timing_frames=27 same_texture=true")


func _test_three_combo_impacts() -> void:
	var front := _enemy(Vector2(90.0, 0.0))
	var rear := _enemy(Vector2(-110.0, 0.0))
	for step in range(3):
		hero.set("auto_cleave_cooldown_timer", 0.0)
		hero.call("_tick_captain_cleave", 0.0)
		hero.set("auto_cleave_cooldown_timer", 999.0)
		var hp_before := float(front.get("hp"))
		var rear_before := float(rear.get("hp"))
		_assert(str(hero.get_node("Visual").get_animation_state()) == str(LIBRARY.CAPTAIN_COMBO_NAMES[step]), "automatic combo selected the wrong body clip")
		await get_tree().create_timer(0.055, true, false, true).timeout
		_assert(float(front.get("hp")) == hp_before, "combo damaged during anticipation")
		await get_tree().create_timer(0.18, true, false, true).timeout
		_assert(float(front.get("hp")) < hp_before, "combo missed its real active-frame damage")
		_assert(float(rear.get("hp")) < rear_before if step == 2 else is_equal_approx(float(rear.get("hp")), rear_before), "finisher was not a distinct 360-degree hit or a normal slash hit behind")
		await get_tree().create_timer(0.18, true, false, true).timeout
	_assert(hero.get_channel_debug_state()["combo_impacts"] == [1, 1, 1], "combo index advanced by input rather than one impact each")
	EntityFactory.release_enemy(front)
	EntityFactory.release_enemy(rear)
	print("CAPTAIN_R35_COMBO phases=0/1/2 anticipation_damage=0 active_damage=true third_hits_behind=true sequence_rng_free=true")


func _test_release_before_impact() -> void:
	hero.set("auto_cleave_cooldown_timer", 999.0)
	hero.set_active_ability_held(true)
	hero.call("_tick_captain_cleave", 0.24)
	_assert(bool(hero.get_channel_debug_state()["pending"]) and float(hero.get_channel_debug_state()["energy"]) == Hero.CHANNEL_MAX_ENERGY - Hero.CHANNEL_ENERGY_COST and not spy.channel_on, "hold did not reserve its cost or started visual before impact")
	var impacts_before := int(hero.get_channel_debug_state()["impacts"])
	hero.set_active_ability_held(false)
	_assert(not bool(hero.get_channel_debug_state()["pending"]) and float(hero.get_channel_debug_state()["energy"]) == Hero.CHANNEL_MAX_ENERGY, "pre-impact release did not cancel and refund the reserved channel hit")
	_assert((hero.get_node("Visual").get("animated_sprite") as AnimatedSprite2D).frame >= 3, "released channel jumped to idle rather than authored recovery")
	await get_tree().create_timer(0.24, true, false, true).timeout
	_assert(int(hero.get_channel_debug_state()["impacts"]) == impacts_before and not spy.channel_on, "released channel emitted a late impact or left a held effect")
	print("CAPTAIN_R35_CANCEL reserved_cost=%.0f refund=%.0f release=authored_recovery late_channel_damage=0" % [Hero.CHANNEL_ENERGY_COST, Hero.CHANNEL_ENERGY_COST])


func _test_buffered_tap_becomes_hold() -> void:
	var target := _enemy(Vector2(90.0, 0.0))
	hero.set("auto_cleave_cooldown_timer", 0.0)
	hero.call("_tick_captain_cleave", 0.0)
	hero.set("auto_cleave_cooldown_timer", 999.0)
	var casts_before := int(hero.get_active_ability_cast_count())
	_assert(bool(hero.try_cast_active_ability()) and hero.get("active_ability_queued") == true, "hold takeover fixture did not seed a buffered tap")
	hero.set_active_ability_held(true)
	hero.call("_tick_captain_cleave", 0.24)
	_assert(hero.get("active_ability_queued") == false, "long hold retained an old buffered tap for after its channel")
	hero.set_active_ability_held(false)
	await get_tree().create_timer(0.45, true, false, true).timeout
	_assert(int(hero.get_active_ability_cast_count()) == casts_before, "release cast an old tap that should have been absorbed by hold")
	EntityFactory.release_enemy(target)
	print("CAPTAIN_R35_GESTURE tap_buffer_to_long_hold=consumed extra_cast_after_release=0")


func _test_sustained_energy() -> void:
	hero.set("auto_cleave_cooldown_timer", 999.0)
	var targets: Array[Node] = []
	for offset in [Vector2(80.0, 0.0), Vector2(-80.0, 0.0), Vector2(0.0, 80.0), Vector2(0.0, -80.0)]:
		targets.append(_enemy(offset))
	hero.set_active_ability_held(true)
	await get_tree().create_timer(10.0, true, false, true).timeout
	var state: Dictionary = hero.get_channel_debug_state()
	var expected_impacts := int(Hero.CHANNEL_MAX_ENERGY / Hero.CHANNEL_ENERGY_COST)
	var remainder := Hero.CHANNEL_MAX_ENERGY - float(expected_impacts) * Hero.CHANNEL_ENERGY_COST
	_assert(int(state["impacts"]) == expected_impacts and float(state["energy"]) == remainder and float(state["energy_spent"]) == float(expected_impacts) * Hero.CHANNEL_ENERGY_COST and bool(state["exhausted"]), "full-energy hold did not spend exactly its finite strike budget")
	_assert(not bool(state["active"]) and not spy.channel_on, "exhausted channel remained a perpetual loop")
	for target in targets:
		_assert(float(target.get("hp")) < 100000.0, "channel's 360 active hitbox missed a cardinal direction")
	var impacts_before := int(state["impacts"])
	await get_tree().create_timer(0.5, true, false, true).timeout
	_assert(int(hero.get_channel_debug_state()["impacts"]) == impacts_before and float(hero.get_channel_debug_state()["energy"]) == remainder, "held depleted channel secretly refilled or continued to damage")
	hero.set_active_ability_held(false)
	await get_tree().create_timer(0.55, true, false, true).timeout
	_assert(float(hero.get_channel_debug_state()["energy"]) >= remainder + Hero.CHANNEL_ENERGY_REGEN * 0.5 and not spy.channel_on, "energy failed to recover after release")
	for target in targets:
		EntityFactory.release_enemy(target)
	print("CAPTAIN_R35_CHANNEL full_bar_impacts=%d cost=%.0f cardinal_hits=4 held_depleted_stops=true released_regen=%.0f_per_second loop_owners=0" % [expected_impacts, float(expected_impacts) * Hero.CHANNEL_ENERGY_COST, Hero.CHANNEL_ENERGY_REGEN])


func _test_pause_cancels_pending() -> void:
	hero.set("auto_cleave_cooldown_timer", 999.0)
	hero.set_active_ability_held(true)
	hero.call("_tick_captain_cleave", 0.24)
	_assert(bool(hero.get_channel_debug_state()["pending"]), "pause fixture did not begin a real channel windup")
	GameManager.toggle_pause()
	_assert(get_tree().paused and not bool(hero.get_channel_debug_state()["active"]) and not bool(hero.get_channel_debug_state()["pending"]) and not spy.channel_on and float(hero.get_channel_debug_state()["energy"]) == Hero.CHANNEL_MAX_ENERGY, "pause retained channel pending damage, held FX, or its uncommitted cost")
	GameManager.toggle_pause()
	await get_tree().create_timer(0.25, true, false, true).timeout
	_assert(int(hero.get_channel_debug_state()["impacts"]) == 0, "paused channel later fired from recovery after resume")
	print("CAPTAIN_R35_PAUSE pending_cancelled=true reservation_refunded=true late_damage_after_resume=0")


func _test_keyboard_and_death_cleanup() -> void:
	hero.set("channel_energy", Hero.CHANNEL_MAX_ENERGY)
	hero.set("auto_cleave_cooldown_timer", 999.0)
	var press := InputEventAction.new()
	press.action = "active_ability"
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().create_timer(0.55, true, false, true).timeout
	_assert(bool(hero.get_channel_debug_state()["held"]) and int(hero.get_channel_debug_state()["impacts"]) > int(Hero.CHANNEL_MAX_ENERGY / Hero.CHANNEL_ENERGY_COST) and spy.channel_on, "held keyboard input did not channel through the same active-frame route")
	var release := InputEventAction.new()
	release.action = "active_ability"
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(not bool(hero.get_channel_debug_state()["held"]) and not bool(hero.get_channel_debug_state()["active"]) and not spy.channel_on, "keyboard release left a channel input or owner loop")
	await get_tree().create_timer(0.4, true, false, true).timeout
	hero.set("channel_energy", Hero.CHANNEL_MAX_ENERGY)
	hero.set_active_ability_held(true)
	await get_tree().create_timer(0.55, true, false, true).timeout
	_assert(spy.channel_on, "death cleanup fixture did not create a held loop")
	hero.call("_die")
	_assert(not spy.channel_on and not bool(hero.get_channel_debug_state()["pending"]), "dead owner retained a loop or pending damage")
	hero.reset_for_run()
	_assert(hero.get_channel_debug_state()["combo_impacts"] == [0, 0, 0] and float(hero.get_channel_debug_state()["energy"]) == Hero.CHANNEL_MAX_ENERGY and not bool(hero.get_channel_debug_state()["held"]), "new run reused a previous combo/channel generation")
	print("CAPTAIN_R35_INPUT keyboard_held=true keyboard_up_clears=true death_clears_owner=true reset_energy=%.0f reset_combo=0" % Hero.CHANNEL_MAX_ENERGY)


func _test_light_and_heavy_hurt() -> void:
	var visual: Node = hero.get_node("Visual")
	hero.set("auto_cleave_cooldown_timer", 999.0)
	_assert(bool(visual.call("play_attack", &"attack_combo_a")), "hurt fixture could not start its authored swing")
	hero.set("invulnerability_timer", 0.0)
	hero.call("take_damage", 5.2, Vector2.LEFT * 80.0)
	_assert(visual.get("pending_heavy_hurt") == false and bool(visual.call("is_attack_animation")), "light contact interrupted the sustained body animation")
	hero.set("invulnerability_timer", 0.0)
	hero.call("take_damage", 20.0, Vector2.LEFT * 80.0)
	_assert(visual.get("pending_heavy_hurt") == true and bool(visual.call("is_attack_animation")), "heavy hit did not queue one real reaction after the active swing")
	await get_tree().create_timer(0.40, true, false, true).timeout
	_assert(str(visual.call("get_animation_state")) == "hurt", "queued heavy reaction was overwritten by channel restart or locomotion")
	await get_tree().create_timer(0.30, true, false, true).timeout
	_assert(str(visual.call("get_animation_state")) == "idle" and visual.get("pending_heavy_hurt") == false, "heavy hurt did not finish its three authored timing frames")
	print("CAPTAIN_R35_HURT light_5.2_keeps_attack=true heavy_20_queues_once=true queued_hurt=real_3_frames resumes_clean=true")


func _enemy(offset: Vector2) -> Node:
	var enemy: Node = EntityFactory.spawn_enemy("r35_combo_fixture", {"max_hp": 100000.0, "speed": 0.0, "damage": 0.0, "xp": 0, "gold": 0, "radius": 13.0, "sprite_path": "res://assets/sprites/enemy_grunt.png"}, offset)
	enemy.set_physics_process(false)
	return enemy


func _on_impact() -> void:
	impact_frames.append((hero.get_node("Visual").get("animated_sprite") as AnimatedSprite2D).frame)


func _assert(condition: bool, message: String) -> void:
	if condition or failed:
		return
	failed = true
	printerr("CAPTAIN_COMBO_CHANNEL_R35_FAIL: " + message)
	get_tree().quit(1)
