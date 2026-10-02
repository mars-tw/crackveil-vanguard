extends Node

const ARENA := preload("res://scenes/arena/Arena.tscn")
const OUT := "res://docs/evidence/r35/native_integration/"
var arena: Node
var leader: Node2D
var presentation: Node
var stage_id := "moon"
var captures: Dictionary = {}
var poses: Dictionary = {}
var pose_frames: Dictionary = {}
var fx_frames: Dictionary = {}
var fx_births: Dictionary = {}
var last_slot_ages: Dictionary = {}
var texture_metrics: Dictionary = {}
var selected_cards: int = 0
var last_ui_press: int = 0
var key_down_msec: int = -1
var key_up_msec: int = -1
var held_sample: Dictionary = {}
var release_sample: Dictionary = {}
var channel_slot: Node = null
var channel_faded_msec: int = -1
var channel_anchor_max: float = 0.0
var cue_peak: int = 0
var cue_frame_observations: int = 0
var monster_frame2_observations: int = 0
var stale_burst_observations: int = 0
var maximum_fx: int = 0
var source_hashes: Dictionary = {}
var contact_mode := false
var file_prefix := "moon"
var postdraw_ready := false
var release_ack_msec: int = -1
var legacy_column_observations: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	stage_id = str(args[0]) if not args.is_empty() else "moon"
	contact_mode = "contact" in args
	file_prefix = stage_id + ("_contact" if contact_mode else "")
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for path in ["scripts/heroes/hero.gd", "scripts/enemies/enemy.gd", "scripts/player/player_visual.gd", "scripts/vfx/combat_presentation.gd", "scripts/autoload/entity_factory.gd"]:
		source_hashes[path] = FileAccess.get_sha256("res://" + path)
	if not GameManager.select_stage(stage_id):
		_fail("unknown real stage")
		return
	arena = ARENA.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	leader = GameManager.player
	presentation = get_tree().get_first_node_in_group("combat_presentation")
	if leader == null or presentation == null:
		_fail("actual captain / FX service unavailable")
		return
	await _capture("start")
	var deadline := Time.get_ticks_msec() + 120000
	while GameManager.elapsed_time < 15.0:
		if not is_instance_valid(leader) or not bool(leader.get("is_alive")):
			await _capture("natural_defeat")
			_fail("normal player died before 15s")
			return
		if Time.get_ticks_msec() > deadline:
			_fail("normal game / modal timed out")
			return
		_press_offered_card()
		var elapsed: float = GameManager.elapsed_time
		var bg: Node = arena.get_node("Background")
		var bounds: Rect2 = bg.get_playable_rect()
		var target := bounds.get_center() + Vector2(cos(elapsed * 0.70) * 90.0, sin(elapsed * 0.70) * 55.0)
		if contact_mode:
			var toughest: Node2D = _contact_target()
			if toughest != null:
				target = toughest.global_position
		GameManager.set_touch_move_vector((target - leader.global_position).limit_length(1.0))
		if key_down_msec < 0 and elapsed >= 4.0:
			_send_space(true)
			key_down_msec = Time.get_ticks_msec()
		if key_down_msec >= 0 and key_up_msec < 0 and Time.get_ticks_msec() - key_down_msec >= 2000:
			_send_space(false)
			key_up_msec = Time.get_ticks_msec()
		await RenderingServer.frame_post_draw
		postdraw_ready = true
		_audit_runtime()
		await _capture_events()
		postdraw_ready = false
		await get_tree().process_frame
	_send_space(false)
	GameManager.set_touch_move_vector(Vector2.ZERO)
	await _capture("natural_15s")
	var final_fx: Dictionary = presentation.get_debug_state()
	var summary := {"stage": stage_id, "contact_movement_towards_naturally_spawned_toughest_enemy": contact_mode, "actual_Arena": true, "game_seconds": GameManager.elapsed_time, "hp": leader.get("current_hp"), "max_hp": leader.get("max_hp"), "level": GameManager.level, "natural_kills": GameManager.kills, "actual_upgrade_ui_presses": selected_cards, "space_physical_key_input": true, "space_hold_real_ms": key_up_msec - key_down_msec, "held_state": held_sample, "release_state": release_sample, "input_release_ack_ms": release_ack_msec - key_up_msec if release_ack_msec >= 0 else -1, "channel_original_slot_fade_after_release_ms": channel_faded_msec - key_up_msec if channel_faded_msec >= 0 else -1, "channel_anchor_rendered_error_world_units_expected_offset_0_28": channel_anchor_max, "combo_poses_observed": poses.keys(), "pose_frames_observed": pose_frames, "visible_texture_metrics_include_weapons": texture_metrics, "fx_frame_visits": fx_frames, "fx_births": fx_births, "maximum_active_fx": maximum_fx, "fx_service_final": final_fx, "ground_cue_peak": cue_peak, "ground_cue_frame_observations": cue_frame_observations, "enemy_attack_frame2_observations": monster_frame2_observations, "legacy_visible_white_column_frame_observations": legacy_column_observations, "stale_nonheld_burst_observations": stale_burst_observations, "captures": captures, "source_hashes_at_start": source_hashes, "godmode_beauty_HP_XP_or_kill_state_injections": 0, "mode": "native_desktop_actual_game_not_mobile_hardware"}
	var file := FileAccess.open(OUT + file_prefix + "_review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "\t"))
	file.close()
	print("R35_NATIVE_REVIEW_COMPLETE stage=%s actual_game_seconds=%.2f kills=%d poses=%s fxKinds=%s cuePeak=%d monsterFrame2=%d channelReleaseMs=%d staleBursts=%d" % [stage_id, GameManager.elapsed_time, GameManager.kills, poses.keys(), fx_frames.keys(), cue_peak, monster_frame2_observations, channel_faded_msec - key_up_msec if channel_faded_msec >= 0 else -1, stale_burst_observations])
	get_tree().quit(0)


func _audit_runtime() -> void:
	var visual: Node = leader.get("visual")
	if visual != null:
		var animation: String = str(visual.get_animation_state())
		var sprite: AnimatedSprite2D = visual.get("animated_sprite")
		if sprite != null and sprite.sprite_frames.has_animation(sprite.animation):
			if not pose_frames.has(animation):
				pose_frames[animation] = {}
			pose_frames[animation][str(sprite.frame)] = true
			if animation.begins_with("attack_combo_"):
				poses[animation] = true
			var key := "%s:%d" % [animation, sprite.frame]
			if not texture_metrics.has(key):
				var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
				texture_metrics[key] = _visible_art_metric(tex.get_image(), sprite.scale)
	var channel: Dictionary = leader.get_channel_debug_state()
	if key_down_msec >= 0 and key_up_msec < 0 and bool(channel.get("effect_active", false)):
		held_sample = channel
		var slot: Node = presentation.channels.get(leader.get_instance_id())
		if slot != null:
			channel_slot = slot
			channel_anchor_max = maxf(channel_anchor_max, slot.global_position.distance_to(leader.global_position + Vector2(0, 28)))
	if key_up_msec >= 0 and release_ack_msec < 0 and not Input.is_action_pressed("active_ability") and not bool(channel.get("active", false)):
		release_ack_msec = Time.get_ticks_msec()
		release_sample = channel
	if release_ack_msec >= 0 and channel_faded_msec < 0 and channel_slot != null:
		if not channel_slot.visible or channel_slot.get("owner_ref") == null:
			channel_faded_msec = Time.get_ticks_msec()
	maximum_fx = maxi(maximum_fx, presentation.active.size())
	for slot in presentation.active:
		var kind := str(slot.kind)
		if not fx_frames.has(kind):
			fx_frames[kind] = {}
		fx_frames[kind][str(slot.sprite.frame)] = true
		var id: int = slot.get_instance_id()
		var age: float = slot.age
		if not last_slot_ages.has(id) or age < float(last_slot_ages[id]):
			fx_births[kind] = int(fx_births.get(kind, 0)) + 1
		last_slot_ages[id] = age
		if not slot.held and slot.release_age < 0.0 and slot.age > slot.life + 0.04:
			stale_burst_observations += 1
	var cues := 0
	for cue in get_tree().get_nodes_in_group("attack_telegraphs"):
		if cue.get("active") == true and cue.visible:
			cues += 1
			cue_frame_observations += 1
	cue_peak = maxi(cue_peak, cues)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.get("is_active") == true and enemy.get("current_animation_name") == &"attack":
			var sprite: AnimatedSprite2D = enemy.get("animated_sprite")
			if sprite != null and sprite.frame == 2:
				monster_frame2_observations += 1
	for column in arena.find_children("Column", "Line2D", true, false):
		if column.is_visible_in_tree():
			legacy_column_observations += 1


func _capture_events() -> void:
	var visual: Node = leader.get("visual")
	var state: Dictionary = visual.get_debug_state()
	var name := str(state["animation"])
	if name.begins_with("attack_combo_") and int(state["frame"]) == 2 and not captures.has(name):
		await _capture(name)
	if key_down_msec >= 0 and key_up_msec < 0 and not captures.has("space_held") and not held_sample.is_empty():
		await _capture("space_held")
	if key_up_msec >= 0 and not captures.has("after_release_150ms") and Time.get_ticks_msec() - key_up_msec >= 150:
		await _capture("after_release_150ms")
	if not captures.has("natural_critical"):
		for slot in presentation.active:
			if slot.kind == "critical_impact" and slot.sprite.frame in [1, 2, 3]:
				await _capture("natural_critical")
				break
	if cue_peak > 0 and not captures.has("monster_groundcue"):
		await _capture("monster_groundcue")
	if not captures.has("monster_attack_fx"):
		for slot in presentation.active:
			if str(slot.kind).begins_with("monster_") and slot.sprite.frame in [1, 2, 3]:
				await _capture("monster_attack_fx")
				break


func _visible_art_metric(pixels: Image, scale: Vector2) -> Dictionary:
	var min_p := Vector2i(pixels.get_width(), pixels.get_height())
	var max_p := Vector2i.ZERO
	var count := 0
	for y in range(pixels.get_height()):
		for x in range(pixels.get_width()):
			if pixels.get_pixel(x, y).a >= 0.35:
				min_p = Vector2i(mini(min_p.x, x), mini(min_p.y, y))
				max_p = Vector2i(maxi(max_p.x, x), maxi(max_p.y, y))
				count += 1
	return {"canvas": pixels.get_size(), "opaque_bounds_including_sword": Rect2i(min_p, max_p - min_p + Vector2i.ONE), "total_art_height_world": float(max_p.y - min_p.y + 1) * scale.y, "sprite_scale": scale, "opaque_pixels": count}


func _press_offered_card() -> void:
	if not GameManager.waiting_for_upgrade or Time.get_ticks_msec() - last_ui_press < 300:
		return
	var screen: Node = arena.level_up_screen
	if screen.root.visible and not screen.option_buttons.is_empty():
		var button: Button = screen.option_buttons[0]
		if not button.disabled:
			button.pressed.emit()
			selected_cards += 1
			last_ui_press = Time.get_ticks_msec()


func _send_space(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = pressed
	event.echo = false
	Input.parse_input_event(event)


func _capture(label: String) -> void:
	if not postdraw_ready:
		await RenderingServer.frame_post_draw
	var path := OUT + file_prefix + "_" + label + ".png"
	if get_viewport().get_texture().get_image().save_png(path) != OK:
		_fail("actual game capture failed")
		return
	captures[label] = {"path": path, "game_seconds": GameManager.elapsed_time, "kills": GameManager.kills}


func _contact_target() -> Node2D:
	var result: Node2D = null
	var score := -1.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.get("is_active") != true or float(enemy.get("hp")) <= 0.0:
			continue
		var distance: float = enemy.global_position.distance_to(leader.global_position)
		var weight := float(enemy.get("hp")) / maxf(1.0, distance * 0.04)
		if weight > score:
			score = weight
			result = enemy
	return result


func _fail(message: String) -> void:
	printerr("R35_NATIVE_REVIEW_FAIL: " + message)
	get_tree().quit(1)
