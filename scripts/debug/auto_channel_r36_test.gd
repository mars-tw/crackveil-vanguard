extends Node

const HERO_SCENE := preload("res://scenes/heroes/Hero.tscn")
const CAPTAIN := preload("res://resources/heroes/rift_captain.tres")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const PHONE := {"ua_mobile": true, "ua_phone": true, "touch_available": true, "mouse_available": false}

var hero: Node
var failed := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	MetaProgress.debug_use_save_path("user://r36_auto_meta.cfg", true)
	GameManager.game_running = false
	EntityFactory.initialize_for_arena(self)
	MOBILE.set_device_hints_override_for_tests(PHONE)
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
	hero.set("auto_cleave_cooldown_timer", 999.0)
	GameManager.player = hero
	GameManager.squad_manager = null
	GameManager.game_running = true
	get_tree().paused = false
	_assert(bool(hero.get_channel_debug_state()["auto_channel_enabled"]), "phone did not start with its single-finger auto strategy enabled")
	var target: Node = EntityFactory.spawn_enemy("r36_auto_fixture", {"max_hp": 1000000.0, "speed": 0.0, "damage": 0.0, "xp": 0, "gold": 0, "radius": 13.0, "sprite_path": "res://assets/sprites/enemy_grunt.png"}, Vector2(240.0, 0.0))
	target.set_physics_process(false)
	hero.set("channel_energy", 80.0)
	await get_tree().create_timer(2.1, true, false, true).timeout
	var state: Dictionary = hero.get_channel_debug_state()
	_assert(int(state["impacts"]) == 5 and not bool(state["auto_channel_active"]) and not bool(state["held"]) and float(state["energy"]) < 80.0 and float(target.get("hp")) < 1000000.0, "auto strategy did not commit five real strikes then stop near 40 energy without fake input")
	var actions_before := int(state["auto_channel_actions"])
	await get_tree().create_timer(1.5, true, false, true).timeout
	state = hero.get_channel_debug_state()
	_assert(int(state["auto_channel_actions"]) > actions_before and bool(state["auto_channel_active"]) and not bool(state["held"]), "automatic recharge did not restart at its independent 80-energy threshold")
	hero.set_active_ability_held(true)
	await get_tree().create_timer(0.05, true, false, true).timeout
	state = hero.get_channel_debug_state()
	_assert(str(state["mode"]) == "manual" and not bool(state["auto_channel_active"]), "manual hold failed to take priority over the automatic strategy")
	hero.set_auto_channel_enabled(false)
	_assert(bool(hero.get_channel_debug_state()["active"]), "auto toggle incorrectly cancelled a manual hold")
	hero.set_active_ability_held(false)
	await get_tree().create_timer(0.4, true, false, true).timeout
	var impacts_before := int(hero.get_channel_debug_state()["impacts"])
	await get_tree().create_timer(0.8, true, false, true).timeout
	_assert(int(hero.get_channel_debug_state()["impacts"]) == impacts_before and not bool(hero.get_channel_debug_state()["active"]), "disabled auto mode restarted channel damage after release")
	hero.set_auto_channel_enabled(true)
	hero.set("channel_energy", 100.0)
	await get_tree().create_timer(0.4, true, false, true).timeout
	_assert(bool(hero.get_channel_debug_state()["auto_channel_active"]), "reenabled auto mode failed to start near a valid enemy")
	_assert(bool(hero.try_cast_active_ability()), "manual single tap could not override an automatic channel")
	_assert(not bool(hero.get_channel_debug_state()["auto_channel_active"]), "manual tap left auto owner active")
	EntityFactory.release_enemy(target)
	hero.set_auto_channel_enabled(false)
	MOBILE.set_device_hints_override_for_tests()
	if failed:
		return
	print("AUTO_CHANNEL_R36_PASS phone_default=on radius=360 start_energy=80 committed_stop=40 automatic_recharge=true fake_input=false manual_hold_priority=true manual_tap_override=true toggle_off_stops=true")
	get_tree().quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition or failed:
		return
	failed = true
	printerr("AUTO_CHANNEL_R36_FAIL: " + message)
	get_tree().quit(1)
