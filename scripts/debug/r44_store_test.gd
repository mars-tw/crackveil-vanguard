extends Node

const ARENA := preload("res://scenes/arena/Arena.tscn")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
var checks := 0
var failures: Array[String] = []

class ExitProbe extends Node:
	var calls := 0
	func _on_main_menu_requested() -> void:
		calls += 1

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("R44_FAIL: " + message)

func _run() -> void:
	var detached := preload("res://scripts/heroes/hero.gd").new()
	check(detached._presentation_service() == null, "detached actor looked up presentation tree")
	detached.free()
	GameManager.campaign_save_path = "user://r44_test_campaign.cfg"
	MetaProgress.debug_use_save_path("user://r44_test_meta.cfg", true)
	PlayerSettings.debug_use_save_path("user://r44_test_settings.cfg", true)
	AchievementProgress.debug_use_save_path("user://r44_test_achievements.cfg", true)
	var arena := ARENA.instantiate()
	add_child(arena)
	await get_tree().process_frame
	GameManager.set_process(false)
	arena.get_node("EnemySpawner").set_process(false)
	var squad: Node = GameManager.squad_manager
	var relay: Node = GameManager.tactical_director.relay
	check(relay.FONT.has_char(0x30fb), "formation text separator is missing from embedded font")
	relay.set_process(false)
	var captain: Node2D = GameManager.player
	check(squad.get_member_count() >= 3, "fresh sortie needs two followers")
	# Freeze movement solely for negative/positive occupancy boundaries; the
	# separate browser path and long-run simulator exercise real locomotion.
	for member in squad.get_members():
		member.set_physics_process(false)
		for weapon in member.weapons.values():
			weapon.set_process(false)
	# Persistent projectiles may outlive a fallen/freed squad member.
	var emitter := Node2D.new()
	arena.add_child(emitter)
	var zone := preload("res://scripts/projectiles/hazard_zone.gd").new()
	arena.add_child(zone)
	var target: Node = EntityFactory.spawn_enemy("normal", {"max_hp":100.0,"speed":0.0,"damage":0.0,"xp":0,"gold":0,"radius":12.0}, captain.global_position)
	target.set_physics_process(false)
	zone.setup(captain.global_position, {"area_radius":80.0,"damage_per_second":20.0,"source_weapon_id":"r44_persistent_hazard"}, emitter)
	emitter.free()
	await get_tree().process_frame
	GameManager.reset_combat_metrics(true)
	var target_hp: float = target.hp
	zone._apply_tick_damage()
	check(target.hp < target_hp, "hazard stopped damaging after emitter was freed")
	check(GameManager.get_combat_metrics().total_damage > 0.0, "freed emitter hazard failed to record damage safely")
	GameManager.reset_combat_metrics(false)
	zone.free()
	EntityFactory.release_enemy(target)
	var start: Vector2 = captain.global_position
	relay.advance(2.0)
	check(relay.step == 0, "remote button press closed a seal")
	captain.global_position = relay.anchor
	for member in squad.get_members():
		if member != captain:
			member.global_position = captain.global_position + Vector2(700, 700)
	relay.advance(2.0)
	check(relay.step == 0, "captain alone closed a seal")
	var followers: Array = []
	for member in squad.get_members():
		if member != captain:
			followers.append(member)
			member.global_position = squad.get_formation_world_position(member.formation_index)
	followers[0].is_alive = false
	relay.advance(2.0)
	check(relay.step == 0, "dead follower counted as occupied")
	followers[0].is_alive = true
	for phase in range(3):
		squad.set_formation(relay.ORDER[phase], true)
		captain.global_position = relay.anchor
		for member in squad.get_members():
			if member != captain:
				member.global_position = squad.get_formation_world_position(member.formation_index)
		relay.advance(0.6)
		check(relay.step == phase, "no anticipation/hold requirement")
		captain.global_position += Vector2(70, 0)
		relay.advance(0.2)
		check(relay.hold == 0.0, "leaving anchor did not reset hold")
		captain.global_position = relay.anchor
		for member in squad.get_members():
			if member != captain:
				member.global_position = squad.get_formation_world_position(member.formation_index)
		var wrong := "ring" if phase == 0 else "wedge"
		squad.set_formation(wrong, true)
		relay.advance(2.0)
		check(relay.step == phase, "wrong formation closed a seal")
		squad.set_formation(relay.ORDER[phase], true)
		relay.advance(1.21)
		check(relay.step == phase + 1, "occupied formation did not close")
	check(relay.completed and relay.history.size() == 3, "relay incomplete")
	check(MetaProgress.shards == 4 and MetaProgress.formation_seals.get("moon", false), "first reward not saved")
	MetaProgress.load_progress()
	check(MetaProgress.shards == 4 and MetaProgress.award_formation_seal("moon") == 0, "restart permits repeat reward")
	MetaProgress.debug_use_save_path("user://r44_unwritable/missing/meta.cfg", true)
	check(MetaProgress.award_formation_seal("moon") == -1 and MetaProgress.shards == 0 and not MetaProgress.formation_seals.get("moon", false), "failed save retained reward")
	relay.reward_saved = false
	relay.retry_timer = 0.0
	relay.advance(0.1)
	check(not relay.reward_saved and relay.retry_timer > 1.9, "failed relay save has no retry backoff")
	MetaProgress.debug_use_save_path("user://r44_test_meta.cfg", false)
	relay.advance(0.1)
	check(not relay.reward_saved, "relay retries disk writes every frame")
	relay.advance(2.1)
	check(relay.reward_saved and MetaProgress.shards == 4, "relay retry grants twice or fails to recover")
	check(MetaProgress.award_formation_seal("invalid") == -1, "invalid stage earned relay currency")
	var hud: Node = arena.get_node("HUD")
	squad.formation_cooldown = 0.0
	await get_tree().process_frame
	var switch_count: int = squad.formation_switch_count
	var emulated := InputEventMouseButton.new()
	emulated.device = -1
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.position = hud.formation_button.get_global_rect().get_center()
	emulated.pressed = true
	get_viewport().push_input(emulated, true)
	emulated = emulated.duplicate()
	emulated.pressed = false
	get_viewport().push_input(emulated, true)
	check(squad.formation_switch_count == switch_count, "synthetic mouse duplicated touch formation gesture")
	GameManager.set_touch_move_vector(Vector2.RIGHT)
	hud._notification(NOTIFICATION_APPLICATION_PAUSED)
	check(get_tree().paused and GameManager.get_touch_move_vector() == Vector2.ZERO, "background failed to pause/release touch")
	hud._notification(NOTIFICATION_APPLICATION_RESUMED)
	check(get_tree().paused, "resume must await player confirmation")
	GameManager.set_manual_pause(false)
	check(not get_tree().paused, "cannot explicitly resume")
	# Actual iPad / SE / large phone geometry, including iPad portrait & landscape.
	var layouts: Array = []
	for size in [Vector2i(320,568), Vector2i(667,375), Vector2i(430,932), Vector2i(460,1000), Vector2i(768,1024), Vector2i(1024,768), Vector2i(1032,1376), Vector2i(1376,1032), Vector2i(1366,600)]:
		var desktop: bool = size == Vector2i(1366,600)
		var handset: bool = mini(size.x,size.y) < 600 and not desktop
		MOBILE.set_device_hints_override_for_tests({"ua_mobile":not desktop,"ua_phone":handset,"ua_tablet":not desktop and not handset,"touch_available":not desktop,"primary_coarse":not desktop,"mouse_available":desktop})
		# Independent logical viewports avoid the root Window's 1280px stretch
		# minimum being mistaken for physical phone/tablet coordinates.
		var layout_view := SubViewport.new()
		layout_view.size = size
		layout_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(layout_view)
		var layout_hud := preload("res://scenes/ui/HUD.tscn").instantiate()
		layout_view.add_child(layout_hud)
		await get_tree().process_frame
		layout_hud._apply_responsive_layout()
		await get_tree().process_frame
		for button in [layout_hud.pause_button, layout_hud.formation_button]:
			var rect: Rect2 = button.get_global_rect()
			check(rect.size.x >= 44 and rect.size.y >= 44, "target below 44: %s" % size)
			var view: Vector2 = layout_view.get_visible_rect().size
			check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= view.x + 1 and rect.end.y <= view.y + 1, "button outside viewport: %s %s" % [size,rect])
		check(not layout_hud.pause_button.get_global_rect().intersects(layout_hud.formation_button.get_global_rect()), "formation obstructs pause: %s" % size)
		check(not layout_hud.pause_resume_button.get_global_rect().intersects(layout_hud.pause_menu_button.get_global_rect()), "pause exits overlap: %s" % size)
		check(layout_hud.pause_menu_button.size.x >= 44 and layout_hud.pause_menu_button.size.y >= 44, "retreat target below 44")
		layouts.append({"width":size.x,"height":size.y})
		layout_view.queue_free()
		await get_tree().process_frame
	MOBILE.set_device_hints_override_for_tests({})
	var exit_probe := ExitProbe.new()
	add_child(exit_probe)
	GameManager.arena = exit_probe
	hud._on_pause_menu_pressed()
	hud._on_pause_menu_pressed()
	await get_tree().process_frame
	check(exit_probe.calls == 1, "retreat queued duplicate scene removals")
	GameManager.arena = arena
	exit_probe.free()
	var result := {"checks": checks, "failures": failures, "layouts":layouts, "relay":relay.history, "status":"VERIFIED" if failures.is_empty() else "BLOCKED"}
	var file := FileAccess.open("res://docs/evidence/r44-store/mechanics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("R44_STORE_%s checks=%d" % ["PASS" if failures.is_empty() else "FAIL",checks])
	get_tree().quit(0 if failures.is_empty() else 1)
