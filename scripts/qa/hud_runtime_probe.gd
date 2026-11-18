extends RefCounted

# Web-only QA runtime payload (cv_r32_test). Not exported to phone builds.
static var checked := false
static var enabled := false

static func publish(hud: Node, stats: Dictionary) -> void:
	if not OS.has_feature("web"):
		return
	if not checked:
		checked = true
		var probe_json: Variant = JavaScriptBridge.eval("JSON.stringify({enabled:new URLSearchParams(window.location.search).get('cv_r32_test') === '1'})", true)
		var probe_flags: Variant = JSON.parse_string(str(probe_json))
		enabled = probe_flags is Dictionary and probe_flags.get("enabled", false) == true
	if not enabled:
		return
	var payload := stats.duplicate(true)
	payload["fps"] = Engine.get_frames_per_second()
	payload["performance"] = {
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"hud_static_layout_updates": hud.ability_layout_updates
	}
	payload["version"] = str(ProjectSettings.get_setting("application/config/version", ""))
	payload["stage_id"] = GameManager.selected_stage_id
	payload["campaign_clears"] = GameManager.campaign_clears
	if is_instance_valid(GameManager.player):
		payload["player_x"] = GameManager.player.global_position.x
		payload["player_y"] = GameManager.player.global_position.y
		if GameManager.player.has_method("get_cleave_debug_state"):
			payload["cleave"] = GameManager.player.get_cleave_debug_state()
		var player_visual := GameManager.player.get_node_or_null("Visual")
		if player_visual != null and player_visual.has_method("get_debug_state"):
			payload["animation"] = player_visual.get_debug_state()
		if GameManager.player.has_method("get_firepower_debug_state"):
			payload["firepower"] = GameManager.player.get_firepower_debug_state()
		if GameManager.player.has_method("get_channel_debug_state"):
			payload["channel"] = GameManager.player.get_channel_debug_state()
	if is_instance_valid(GameManager.arena):
		var spawner := GameManager.arena.get_node_or_null("EnemySpawner")
		if spawner != null and spawner.has_method("get_harvest_debug_state"):
			payload["horde"] = spawner.get_harvest_debug_state()
		var boss_states: Array = []
		var topology := GameManager.arena.get_node_or_null("LoopWorldTopology")
		if topology != null:
			payload["loop_world"] = topology.get_debug_state()
		if is_instance_valid(GameManager.summon_director):
			payload["summons"] = GameManager.summon_director.get_debug_state()
		if is_instance_valid(GameManager.summon_screen) and GameManager.summon_screen.has_method("get_debug_state"):
			payload["summon_ui"] = GameManager.summon_screen.get_debug_state()
		var specials: Array = []
		for enemy in hud.get_tree().get_nodes_in_group("enemies"):
			if enemy.get("is_active") == true and str(enemy.get("special_elite_id")) != "":
				specials.append(enemy.get_special_elite_debug_state())
		payload["special_elites"] = specials
		var layout := {}
		var scale_factor := hud.get_viewport().get_visible_rect().size.x / maxf(1.0, MobileTuning.ui_layout_size(hud.get_viewport().get_visible_rect().size).x)
		for enemy in hud.get_tree().get_nodes_in_group("enemies"):
			if enemy is Enemy and is_instance_valid(enemy.special_label) and enemy.special_label.is_visible_in_tree():
				var plate: Control = enemy.special_label
				layout["elite_%d" % enemy.get_instance_id()] = _layout_box(plate.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, plate.size), scale_factor)
		if is_instance_valid(GameManager.tactical_director) and is_instance_valid(GameManager.tactical_director.relay):
			var relay: Node = GameManager.tactical_director.relay
			if relay.verdict_bounds.has_area():
				layout["seal_verdict"] = _layout_box(relay.verdict_bounds, scale_factor)
		payload["battle_text_rects"] = layout
		payload["forge_layout"] = hud._forge_marks()
		payload["hud_areas"] = hud._hud_area_rows()
		payload["mission_text"] = hud.tactical_hint.text
		var presentation := GameManager.arena.get_node_or_null("CombatPresentation")
		if presentation != null:
			payload["presentation"] = presentation.get_debug_state()
		for enemy in hud.get_tree().get_nodes_in_group("enemies"):
			if enemy.get("is_active") == true and enemy.get("is_boss") == true:
				boss_states.append(enemy.get_boss_debug_state())
		payload["bosses"] = boss_states
	JavaScriptBridge.eval("window.__cvR32Runtime = %s" % JSON.stringify(payload), true)

static func _layout_box(rect: Rect2, units: float) -> Array:
	return [rect.position.x / units, rect.position.y / units, rect.size.x / units, rect.size.y / units]
