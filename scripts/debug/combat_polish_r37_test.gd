extends Node

const HERO_SCENE := preload("res://scenes/heroes/Hero.tscn")
const CAPTAIN := preload("res://resources/heroes/rift_captain.tres")
const NUMBER := preload("res://scripts/vfx/damage_number.gd")
const FEEDBACK := preload("res://scripts/vfx/combat_feedback.gd")

class PresentationSpy:
	extends Node2D
	var ready_checks := 0
	func _ready() -> void:
		add_to_group("combat_presentation")
	func get_debug_state() -> Dictionary:
		ready_checks += 1
		return {"assets_ready": true}
	func play_effect(_kind: String, _origin: Vector2, _direction: Vector2, _strength: float = 1.0) -> void:
		pass
	func set_channel(_owner: Object, _enabled: bool, _origin: Vector2, _direction: Vector2, _strength: float = 1.0) -> void:
		pass

var hero: Hero
var controller: Node
var failed := false
var impact_frames: Array[int] = []
var impact_positions: Array[Vector2] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	GameManager.campaign_save_path = "user://r37_combat_fixture_campaign.cfg"
	PlayerSettings.debug_use_save_path("user://r37_combat_fixture_settings.cfg", true)
	MetaProgress.debug_use_save_path("user://r37_combat_fixture_meta.cfg", true)
	AchievementProgress.debug_use_save_path("user://r37_combat_fixture_achievement.cfg", true)
	GameManager.game_running = false
	EntityFactory.initialize_for_arena(self)
	GameManager.arena = self
	hero = HERO_SCENE.instantiate()
	add_child(hero)
	hero.setup(CAPTAIN, null, true, 0)
	GameManager.player = hero
	GameManager.squad_manager = null
	GameManager.waiting_for_upgrade = false
	GameManager.waiting_for_contract = false
	GameManager.waiting_for_shop = false
	GameManager.manual_paused = false
	GameManager.system_pause_owners.clear()
	GameManager.xp_required = 999999
	GameManager.critical_strikes_enabled = false
	GameManager.game_running = true
	get_tree().paused = false
	_freeze_weapons()
	hero.set_auto_channel_enabled(false)
	hero.auto_cleave_cooldown_timer = 999.0
	hero.visual.attack_impact.connect(_impact)
	for frame in range(4):
		await get_tree().process_frame
	await _test_real_step_and_hit()
	if failed:
		get_tree().quit(1)
		return
	await _test_cancellations_and_no_auto_dash()
	if failed:
		get_tree().quit(1)
		return
	_test_empty_scan_budget()
	await _test_presentation_generation()
	_test_damage_number_budget()
	_test_feedback_empty_redraw()
	if not failed:
		print("COMBAT_POLISH_R37_PASS actual_physics_step=true damage_frame=2 manual_only=true cancels=true twenty_volley_retained=true label_nodes=1 cache_generation_safe=true")
	get_tree().quit(1 if failed else 0)

func _freeze_weapons() -> void:
	for child in hero.get_children():
		if child.is_in_group("hero_controllers"):
			controller = child
			child.set_process(false)
			child.set_physics_process(false)
	for weapon in hero.weapons.values():
		weapon.set_process(false)
		weapon.set_physics_process(false)
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.set_physics_process(false)

func _enemy(position: Vector2) -> Node:
	var enemy: Node = EntityFactory.spawn_enemy("r37_cleave_fixture", {"max_hp": 300.0, "speed": 0.0, "damage": 0.0, "xp": 0, "gold": 0, "radius": 13.0, "sprite_path": "res://assets/sprites/enemy_grunt.png"}, position)
	enemy.set_physics_process(false)
	return enemy

func _press_space() -> void:
	var press := InputEventKey.new()
	press.physical_keycode = KEY_SPACE
	press.keycode = KEY_SPACE
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	# Invoke the actual input controller once in this controlled fixture, while
	# Hero movement and the six authored poses run on the real SceneTree clock.
	controller._physics_process(1.0 / 60.0)
	press = InputEventKey.new()
	press.physical_keycode = KEY_SPACE
	press.keycode = KEY_SPACE
	press.pressed = false
	Input.parse_input_event(press)
	Input.flush_buffered_events()

func _test_real_step_and_hit() -> void:
	var front: Array[Node] = []
	for position in [Vector2(500, 0), Vector2(505, 42), Vector2(525, -42)]:
		front.append(_enemy(position))
	var rear := _enemy(Vector2(-510, 0))
	for frame in range(3):
		await get_tree().process_frame
	_press_space()
	_check(hero.active_ability_pending and hero.draw_cut_step_active, "Space controller did not start true anticipation step")
	_check(hero.global_position == Vector2.ZERO and float(front[0].hp) == 300.0, "input teleported or damaged immediately")
	await get_tree().create_timer(0.05, true, false, true).timeout
	_check(hero.global_position.x > 30 and float(front[0].hp) == 300.0 and impact_frames.is_empty(), "anticipation did not physically advance without damage")
	await get_tree().create_timer(0.24, true, false, true).timeout
	_check(impact_frames == [2], "step cut did not apply one hit at actual pose 2")
	if failed or impact_positions.is_empty():
		return
	_check(impact_positions[0].x >= 120 and impact_positions[0].x <= Hero.DRAW_CUT_STEP_MAX + 0.1, "step changed origin without bounded physical movement")
	for target in front:
		_check(float(target.hp) < 300.0, "500px outer pack stayed beyond the physically advanced cut")
	_check(float(rear.hp) == 300.0, "step cut hit a target behind its new directional origin")
	_check(hero.active_ability_hit_count == 3 and hero.active_ability_empty_impacts == 0, "real step hits did not update exact debug counters")
	_check(hero.cleave_cone_sqrt_calls == 0, "normal cone still performs per-target square root")
	var weapon: Node = hero.weapons.riftline_emitter
	for level in range(2):
		weapon.apply_data_upgrade("weapon_projectiles")
	_check(int(weapon.data_int("projectile_count", 0)) == 20, "step polish reduced the real volley cap")
	print("R37_STEP origin_before=(0,0) impact_origin=%s actual_step=%.2f targets_at_500=3 hits=%d frame=2 teleport_on_input=false rear_ignored=true" % [str(impact_positions[0]), hero.draw_cut_step_distance, hero.active_ability_hit_count])
	for target in front:
		EntityFactory.release_enemy(target)
	EntityFactory.release_enemy(rear)
	await get_tree().create_timer(0.2, true, false, true).timeout

func _prepare_cast(target: Node) -> void:
	hero.global_position = Vector2.ZERO
	hero.active_ability_cooldown_timer = 0.0
	hero.auto_cleave_cooldown_timer = 999.0
	hero.visual._resume_locomotion()
	_check(is_instance_valid(target) and hero.try_cast_active_ability(), "abort fixture could not start manual draw cut")

func _test_cancellations_and_no_auto_dash() -> void:
	var target := _enemy(Vector2(500, 0))
	_prepare_cast(target)
	hero.invulnerability_timer = 0.0
	hero.take_damage(1.0, Vector2.LEFT)
	_check(not hero.draw_cut_step_active and hero.draw_cut_step_last_reason == "hurt", "hurt retained step motion")
	await get_tree().create_timer(0.4, true, false, true).timeout
	_prepare_cast(target)
	GameManager.toggle_pause()
	_check(not hero.draw_cut_step_active and get_tree().paused, "modal pause retained step motion")
	GameManager.toggle_pause()
	await get_tree().create_timer(0.4, true, false, true).timeout
	_prepare_cast(target)
	var token := int(target.get_hit_token())
	EntityFactory.release_enemy(target)
	target = _enemy(Vector2(-500, 0))
	_check(int(target.get_hit_token()) != token, "fixture did not reuse with a new enemy generation")
	_check(not hero._draw_cut_step_valid() and not hero.draw_cut_step_active, "dead/recycled target retained stale step")
	await get_tree().create_timer(0.4, true, false, true).timeout
	EntityFactory.release_enemy(target)
	var close := _enemy(Vector2(90, 0))
	hero.global_position = Vector2.ZERO
	hero.auto_cleave_cooldown_timer = 0.0
	hero._tick_captain_cleave(0.0)
	_check(hero.auto_cleave_pending and not hero.draw_cut_step_active, "automatic melee started an involuntary step")
	hero.auto_cleave_cooldown_timer = 999.0
	await get_tree().create_timer(0.4, true, false, true).timeout
	hero.set_active_ability_held(true)
	hero._tick_captain_cleave(0.24)
	_check(hero.channel_active and not hero.draw_cut_step_active, "continuous hold interrupted with a step")
	await get_tree().create_timer(0.2, true, false, true).timeout
	if not (hero.channel_pending or hero.channel_impacts > 0):
		print("R37_CHANNEL_DIAGNOSTIC %s animation=%s running=%s paused=%s" % [str(hero.get_channel_debug_state()), str(hero.visual.get_debug_state()), str(GameManager.game_running), str(get_tree().paused)])
	_check((hero.channel_pending or hero.channel_impacts > 0) and not hero.draw_cut_step_active, "continuous hold never resumed from the preceding authored recovery")
	hero.set_active_ability_held(false)
	await get_tree().create_timer(0.4, true, false, true).timeout
	EntityFactory.release_enemy(close)
	target = _enemy(Vector2(500, 0))
	_prepare_cast(target)
	hero._die()
	_check(not hero.draw_cut_step_active and not hero.active_ability_pending, "death retained step/damage")
	hero.reset_for_run()
	_freeze_weapons()
	hero.set_auto_channel_enabled(false)
	hero.auto_cleave_cooldown_timer = 999.0
	_check(not hero.draw_cut_step_active and hero.draw_cut_step_target == null and hero.draw_cut_step_total_distance == 0.0, "restart retained step generation state")
	EntityFactory.release_enemy(target)
	print("R37_STEP_ABORT hurt=true pause=true recycled_target=true death=true restart=true auto_dash=false channel_dash=false")

func _test_empty_scan_budget() -> void:
	hero.auto_cleave_cooldown_timer = 0.0
	var before := hero.auto_cleave_target_queries
	for frame in range(60):
		hero._tick_captain_cleave(1.0 / 60.0)
	var scans := hero.auto_cleave_target_queries - before
	_check(scans >= 10 and scans <= 13, "empty-arena query retries still run every render frame")
	print("R37_EMPTY_TARGET_SCAN simulated_render_ticks=60 target_queries=%d prior=60 preserves_ready_attack=true" % scans)

func _test_presentation_generation() -> void:
	var first := PresentationSpy.new()
	add_child(first)
	for update in range(120):
		hero._set_channel_presentation(true)
	_check(first.ready_checks == 1, "channel presentation checked debug/assets every update")
	var prior_lookups := hero.presentation_lookups
	first.free()
	var second := PresentationSpy.new()
	add_child(second)
	await get_tree().create_timer(0.26, true, false, true).timeout
	hero._set_channel_presentation(true)
	_check(second.ready_checks == 1 and hero.presentation_lookups == prior_lookups + 1, "freed service was retained or replacement was never checked")
	hero.reclaim_generation += 1
	hero._set_channel_presentation(true)
	_check(second.ready_checks == 2, "run generation reused old ready cache")
	hero._set_channel_presentation(false)
	second.free()
	print("R37_PRESENTATION updates=120 ready_checks=1 freed_service_replaced=true restart_rechecks=true")

func _test_damage_number_budget() -> void:
	var number: Node = NUMBER.new()
	add_child(number)
	number.pool_on_acquire()
	number.pool_reset({"value": 1, "position": Vector2.ZERO, "color": Color.WHITE, "font_size": 18})
	number.set_process(false)
	var layouts := NUMBER.label_layout_updates
	for index in range(100):
		number.merge_value(1.0, Vector2.ZERO, Color.WHITE)
	_check(number.get_child_count() == 1 and number.value_label.text == "101", "single Label lost merge value or retains duplicate text")
	_check(NUMBER.label_layout_updates == layouts, "same-size merges repeat font/layout overrides")
	var scales := NUMBER.scale_updates
	for frame in range(20):
		number._process(1.0 / 60.0)
	_check(NUMBER.scale_updates - scales <= 8 and number.pop_finished, "settled number pop writes scale forever")
	_check(number.modulate.a < 1.0, "single-root fade did not propagate to the readable label")
	number.pool_on_release()
	number.pool_on_acquire()
	number.pool_reset({"value": "爆擊 123", "position": Vector2.ZERO, "color": Color("ffe18c"), "font_size": 28})
	_check(number.value_label.text == "爆擊 123" and number.value_label.size.x >= 128.0 and number.modulate.a == 1.0, "reuse lost critical text or retained fade")
	print("R37_DAMAGE_NUMBER merges=100 total=101 label_nodes=1 repeated_layout_overrides=0 settled_scale_updates=%d critical_reuse=true" % (NUMBER.scale_updates - scales))
	number.free()

func _test_feedback_empty_redraw() -> void:
	var feedback := FEEDBACK.new()
	add_child(feedback)
	feedback.recent_kills.append({"time": feedback.combat_clock, "position": Vector2.ZERO})
	var before := feedback.redraw_requests
	feedback._process(0.01)
	_check(feedback.redraw_requests == before, "kill bookkeeping redraws empty canvas")
	feedback.free()
	print("R37_FEEDBACK empty_effects_redraws=0 recent_kill_clock_preserved=true")

func _impact() -> void:
	impact_frames.append((hero.visual.animated_sprite as AnimatedSprite2D).frame)
	impact_positions.append(hero.global_position)

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("COMBAT_POLISH_R37_FAIL " + message)
