extends Node

# R42 陣形戰術回歸測試：站位、數值、羈絆共鳴、四名英雄被動、HUD 按鈕與 Q 鍵。
const ARENA := preload("res://scenes/arena/Arena.tscn")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const PHONE_HINTS := {"ua_mobile": true, "ua_phone": true, "ua_tablet": false, "touch_available": true, "primary_coarse": true, "mouse_available": false}
const DESKTOP_HINTS := {"ua_mobile": false, "ua_phone": false, "ua_tablet": false, "touch_available": false, "primary_coarse": false, "mouse_available": true}
const LAYOUTS: Array[Dictionary] = [
	{"size": Vector2i(390, 844), "hints": PHONE_HINTS, "phone": true},
	{"size": Vector2i(844, 390), "hints": PHONE_HINTS, "phone": true},
	{"size": Vector2i(320, 568), "hints": PHONE_HINTS, "phone": true},
	{"size": Vector2i(667, 375), "hints": PHONE_HINTS, "phone": true},
	{"size": Vector2i(1280, 720), "hints": DESKTOP_HINTS, "phone": false},
	{"size": Vector2i(1366, 600), "hints": DESKTOP_HINTS, "phone": false}
]

var failures: Array[String] = []
var evidence: Dictionary = {"layouts": [], "mechanics": {}}
var viewport: SubViewport
var arena: Node
var hud: Node
var squad: Node


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	GameManager.campaign_save_path = "user://r42_formation_campaign.cfg"
	GameManager.wallet_gold = 0
	PlayerSettings.debug_use_save_path("user://r42_formation_settings.cfg", true)
	MetaProgress.debug_use_save_path("user://r42_formation_meta.cfg", true)
	AchievementProgress.debug_use_save_path("user://r42_formation_achievements.cfg", true)
	GameManager.set_process(false)
	for layout in LAYOUTS:
		MOBILE.set_device_hints_override_for_tests(layout["hints"])
		await _new_arena(layout["size"])
		_check_button_geometry(layout["size"], bool(layout["phone"]))
		await _cleanup()
	MOBILE.set_device_hints_override_for_tests(PHONE_HINTS)
	await _new_arena(Vector2i(390, 844))
	await _check_mechanics()
	await _check_inputs()
	await _cleanup()
	_check_battle_music()
	MOBILE.set_device_hints_override_for_tests({})
	get_tree().paused = false
	evidence["failures"] = failures
	DirAccess.make_dir_recursive_absolute("res://docs/evidence/r42")
	var file := FileAccess.open("res://docs/evidence/r42/formation_test.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(evidence, "\t"))
	print("R42_FORMATION_" + ("PASS" if failures.is_empty() else "FAIL") + " layouts=%d failures=%d" % [LAYOUTS.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


func _new_arena(size: Vector2i) -> void:
	viewport = SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	arena = ARENA.instantiate()
	viewport.add_child(arena)
	await get_tree().process_frame
	arena.get_node("EnemySpawner").set_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	squad = GameManager.squad_manager
	for member in squad.get_members():
		for weapon in member.weapons.values():
			weapon.set_process(false)
	hud = arena.get_node("HUD")
	for _frame in range(10):
		await get_tree().process_frame
	GameManager.emit_stats()
	for _frame in range(4):
		await get_tree().process_frame


func _check_button_geometry(size: Vector2i, phone: bool) -> void:
	var button: Button = hud.get("formation_button")
	_check(button != null and button.is_visible_in_tree(), "formation button hidden at %s" % size)
	if button == null:
		return
	var screen := Rect2(Vector2.ZERO, Vector2(size))
	var rect := button.get_global_rect()
	_check(screen.encloses(rect), "formation button outside viewport %s %s" % [size, rect])
	_check(rect.size.x >= 44.0 and rect.size.y >= 44.0 if phone else rect.size.y >= 40.0, "formation button under touch target %s %s" % [size, rect])
	var others := {"joystick": hud.virtual_joystick, "ability": hud.active_ability_button, "summon": hud.summon_button, "gear": hud.get("phone_equipment_button"), "pause": hud.get("pause_button"), "auto": hud.get("auto_button")}
	for key in others:
		var control: Control = others[key]
		if control == null or not control.is_visible_in_tree():
			continue
		_check(not rect.intersects(control.get_global_rect()), "formation button overlaps %s at %s: %s vs %s" % [key, size, rect, control.get_global_rect()])
	if phone:
		var center := Rect2(Vector2(size.x * 0.25, size.y * 0.28), Vector2(size.x * 0.5, size.y * 0.36))
		_check(not center.intersects(rect), "formation button covers battle center %s %s" % [size, rect])
	evidence["layouts"].append({"size": [size.x, size.y], "phone": phone, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "text": button.text})


func _offsets() -> Array:
	var result := []
	for index in range(1, 9):
		result.append(squad.get_formation_local_offset(index))
	return result


func _check_mechanics() -> void:
	var m: Dictionary = evidence["mechanics"]
	_check(squad.get_formation_id() == "wedge", "run must start in wedge formation")
	_check(squad.has_living_passive("guard") and squad.has_living_passive("scout"), "starting roster must include orbit_guard and arc_scout passives")
	var wedge_offsets := _offsets()
	var ahead := 0
	for offset in wedge_offsets.slice(0, 6):
		if offset.y < 0.0:
			ahead += 1
	_check(ahead == 6, "wedge front slots must stand ahead of the captain (got %d)" % ahead)
	var leader: Node = squad.leader
	var base_pickup: float = float(leader.get("pickup_radius"))
	var wedge_damage: float = GameManager.get_outgoing_damage_multiplier(leader)
	var wedge_incoming: float = squad.get_formation_incoming_multiplier()
	_check(is_equal_approx(squad.get_formation_damage_multiplier(), 1.15), "wedge damage should be 1.15 without resonance")
	_check(is_equal_approx(wedge_incoming, 1.08), "wedge incoming should be 1.08")
	_check(is_equal_approx(squad.get_follower_speed_multiplier(), 1.1), "scout passive should give followers +10%")
	squad.formation_cooldown = 0.0
	var shield_before: float = float(squad.get_members()[1].get("temporary_shield_hp"))
	_check(squad.cycle_formation(), "cycle wedge->ring rejected")
	_check(squad.get_formation_id() == "ring", "cycle order wedge->ring broken")
	_check(not squad.cycle_formation(), "switch during cooldown must be rejected")
	_check(is_equal_approx(squad.get_formation_cooldown_remaining(), squad.FORMATION_SWITCH_COOLDOWN * squad.FORMATION_GUARD_COOLDOWN_MULTIPLIER), "guard passive must shorten cooldown to 60%")
	_check(float(squad.get_members()[1].get("temporary_shield_hp")) >= 14.0 and shield_before < 14.0, "guard passive shield not applied on switch")
	var ring_offsets := _offsets()
	for index in range(6):
		_check(absf(ring_offsets[index].length() - squad.RING_INNER_RADIUS) < 0.5, "ring slot %d not on inner circle" % (index + 1))
	var ring_damage: float = GameManager.get_outgoing_damage_multiplier(leader)
	_check(absf(wedge_damage / ring_damage - 1.15 / 0.92) < 0.001, "GameManager outgoing multiplier ignores formation (%.3f / %.3f)" % [wedge_damage, ring_damage])
	var ring_incoming_total: float = GameManager.get_incoming_damage_multiplier(leader)
	_check(ring_incoming_total <= 0.9001 and ring_incoming_total >= GameManager.DAMAGE_TAKEN_SOFT_CAP_MIN - 0.0001, "ring incoming not applied or soft cap broken: %.3f" % ring_incoming_total)
	squad.formation_cooldown = 0.0
	_check(squad.cycle_formation() and squad.get_formation_id() == "scatter", "cycle ring->scatter broken")
	for offset in _offsets():
		_check(offset.length() >= squad.SCATTER_RADIUS * 0.77, "scatter slot too close to captain: %s" % offset)
	_check(absf(leader.get_pickup_radius() - base_pickup * 1.6) < 0.01, "scatter pickup radius not applied to hero")
	_check(is_equal_approx(leader._movement_multiplier(), 1.08), "scatter move speed not applied")
	squad.formation_cooldown = 0.0
	_check(squad.cycle_formation() and squad.get_formation_id() == "wedge", "cycle scatter->wedge broken")
	_check(squad.formation_switch_count == 3, "switch counter wrong")
	m["base_states"] = {"wedge_damage": wedge_damage, "ring_damage": ring_damage, "ring_incoming_total": ring_incoming_total, "guard_cooldown": squad.FORMATION_SWITCH_COOLDOWN * squad.FORMATION_GUARD_COOLDOWN_MULTIPLIER}
	# 羈絆共鳴與被動。
	_check(squad.recruit_hero("ember_grenadier") and squad.recruit_hero("pulse_artificer"), "could not recruit ember/pulse pair")
	_check(squad.has_active_bond("bond_ember_pulse"), "ember/pulse bond inactive")
	_check("bond_ember_pulse" in squad.get_active_resonance_ids(), "ember/pulse resonance should be active in wedge")
	_check(absf(squad.get_formation_damage_multiplier() - 1.15 * 1.08 * 1.10) < 0.0001, "wedge + resonance + blast passive damage wrong: %.4f" % squad.get_formation_damage_multiplier())
	_check(squad.recruit_hero("line_mender"), "could not recruit line_mender")
	_check(absf(squad.get_formation_pickup_multiplier() - 1.2) < 0.0001, "support passive pickup bonus wrong in wedge")
	_check(squad.recruit_hero("echo_singer"), "could not recruit echo_singer")
	squad.formation_cooldown = 0.0
	squad.set_formation("ring")
	_check("bond_guard_echo" in squad.get_active_resonance_ids() and is_equal_approx(squad.get_formation_regen_per_second(), 1.5), "guard/echo ring regen resonance missing")
	_check(not ("bond_ember_pulse" in squad.get_active_resonance_ids()), "wedge resonance leaked into ring")
	var damaged: Node = squad.get_members()[1]
	damaged.current_hp = damaged.max_hp - 10.0
	GameManager.game_running = true
	var hp_before: float = damaged.current_hp
	for _frame in range(75):
		await get_tree().process_frame
	_check(damaged.current_hp > hp_before, "ring regen did not heal a damaged member")
	m["resonance"] = squad.get_formation_debug_state()
	m["passives"] = {"scout": "followers +10%", "support": "pickup x1.2", "guard": "cooldown x0.6 + shield 14", "blast": "wedge damage x1.10"}
	# 隊友實際移動到圓陣位置。
	for member in squad.get_members():
		member.set_physics_process(true)
		for child in member.get_children():
			if child.name == "FollowerController":
				child.set_physics_process(true)
	for _frame in range(120):
		await get_tree().physics_frame
	var max_error := 0.0
	for index in range(1, squad.get_members().size()):
		var member: Node2D = squad.get_members()[index]
		max_error = maxf(max_error, member.global_position.distance_to(squad.get_formation_world_position(index)))
	m["ring_arrival_max_error_px"] = max_error
	_check(max_error < 24.0, "followers did not settle into ring formation (max error %.1f px)" % max_error)


func _check_inputs() -> void:
	squad.formation_cooldown = 0.0
	var before: String = squad.get_formation_id()
	var press := InputEventAction.new()
	press.action = "formation_cycle"
	press.pressed = true
	Input.parse_input_event(press)
	for _frame in range(3):
		await get_tree().physics_frame
	var release := InputEventAction.new()
	release.action = "formation_cycle"
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().physics_frame
	_check(squad.get_formation_id() != before, "Q / formation_cycle action did not switch formation")
	_check(InputMap.has_action("formation_cycle"), "formation_cycle action missing")
	squad.formation_cooldown = 0.0
	var before_button: String = squad.get_formation_id()
	var button: Button = hud.get("formation_button")
	for _frame in range(3):
		await get_tree().process_frame
	button.pressed.emit()
	_check(squad.get_formation_id() != before_button, "HUD formation button did not switch formation")
	evidence["mechanics"]["inputs"] = {"action_switch": before + "->" + before_button, "button_switch": before_button + "->" + squad.get_formation_id()}


func _check_battle_music() -> void:
	var stream := load(AudioManager.BATTLE_MUSIC_PATH) as AudioStreamOggVorbis
	_check(stream != null, "R42 battle music is not an imported Ogg Vorbis stream")
	if stream == null:
		return
	var length := stream.get_length()
	_check(length > 20.0 and length < 30.0, "battle loop length unexpected: %.2f" % length)
	_check(AudioManager.has_method("is_battle_music_playing"), "AudioManager battle music API missing")
	evidence["music"] = {"path": AudioManager.BATTLE_MUSIC_PATH, "seconds": length, "headless_playback": "not executed (audio runtime disabled in headless)"}


func _cleanup() -> void:
	GameManager.set_manual_pause(false)
	GameManager.game_running = false
	GameManager.system_pause_owners.clear()
	get_tree().paused = false
	GameManager.set_touch_move_vector(Vector2.ZERO)
	GameManager.player = null
	GameManager.squad_manager = null
	GameManager.arena = null
	viewport.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("R42_FORMATION_FAIL " + message)
