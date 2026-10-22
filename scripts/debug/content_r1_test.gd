extends Node

const ARENA := preload("res://scenes/arena/Arena.tscn")
const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const LAYOUT := preload("res://scripts/ui/battle_layout.gd")
const FONT := preload("res://assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf")
var checks := 0
var failures: Array[String] = []
var evidence: Array = []

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("CONTENT_R1_FAIL: " + message)

func fits(label: Label, tag: String) -> void:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var lines := label.text.split("\n")
	var padding := label.get_theme_stylebox("normal").get_minimum_size()
	for line in lines:
		check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x + padding.x <= label.size.x + 1,tag + " text width: " + line + " actual=" + str(label.size) + " font=" + str(font_size))
	check(font.get_height(font_size) * lines.size() + padding.y <= label.size.y + 1,tag + " text height")
	for character in label.text:
		if character not in ["\n", "\t"]:
			check(FONT.has_char(character.unicode_at(0)),tag + " missing glyph: " + character)

func _run() -> void:
	var detached := preload("res://scripts/heroes/hero.gd").new()
	detached._on_combat_pause_changed(true)
	check(detached._presentation_service() == null,"detached hero found scene presentation")
	detached.free()
	var detached_enemy := preload("res://scripts/enemies/enemy.gd").new()
	var kills_before := GameManager.kills
	detached_enemy._finalize_death()
	check(GameManager.kills == kills_before and not detached_enemy.death_finalized,"detached enemy awarded a late kill")
	detached_enemy.free()
	GameManager.campaign_save_path = "user://content_r1_campaign.cfg"
	MetaProgress.debug_use_save_path("user://content_r1_meta.cfg",true)
	PlayerSettings.debug_use_save_path("user://content_r1_settings.cfg",true)
	AchievementProgress.debug_use_save_path("user://content_r1_achievements.cfg",true)
	GameManager.forced_run_seed = 55210
	GameManager.tactical_launch = false
	for view in [Vector2i(390,844),Vector2i(430,932),Vector2i(844,390),Vector2i(1366,600),Vector2i(768,1024),Vector2i(1024,768)]:
		var phone: bool = view.x < 700 or view.y < 500
		var desktop: bool = view.x == 1366
		MOBILE.set_device_hints_override_for_tests({"ua_phone":phone,"ua_mobile":phone,"ua_tablet":not phone and not desktop,"touch_available":not desktop,"primary_coarse":not desktop,"mouse_available":desktop})
		var viewport := SubViewport.new()
		viewport.size = view
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(viewport)
		var arena := ARENA.instantiate()
		viewport.add_child(arena)
		await get_tree().process_frame
		GameManager.set_process(false)
		arena.get_node("EnemySpawner").set_process(false)
		GameManager.tactical_director.set_process(false)
		GameManager.tactical_director.relay.set_process(false)
		var squad: Node = GameManager.squad_manager
		var hud: Node = arena.get_node("HUD")
		for member in squad.get_members():
			member.set_physics_process(false)
			for weapon in member.weapons.values():
				weapon.set_process(false)
		hud._apply_responsive_layout()
		await get_tree().process_frame
		var zones := LAYOUT.regions(Vector2(view),phone)
		var keys := zones.keys()
		for i in keys.size():
			var rect: Rect2 = zones[keys[i]]
			check(Rect2(Vector2.ZERO,Vector2(view)).encloses(rect),"region outside viewport: %s %s" % [view,keys[i]])
			for j in range(i + 1,keys.size()):
				check(not rect.intersects(zones[keys[j]]),"regions overlap %s: %s/%s" % [view,keys[i],keys[j]])
		check(not hud.score_panel.get_global_rect().intersects(hud.hp_label.get_global_rect()),"blank score panel covered HP")
		check(not hud.hp_label.get_global_rect().intersects(hud.level_label.get_global_rect()),"HP and level overlap")
		for label in [hud.hp_label,hud.level_label,hud.time_label,hud.score_label]:
			fits(label,"%s %s" % [view,label.name])
		check(hud.score_label.get_theme_font_size("font_size") >= (12 if phone else 15),"score text shrank below readable baseline")
		for step in range(3):
			GameManager.tactical_director.relay.step = step
			hud._update_tactical_hint()
			fits(hud.tactical_hint,"mission %s step%d" % [view,step])
			check(hud.tactical_hint.text.contains("封隙 %d/3" % step),"completed seals count is ambiguous")
		GameManager.tactical_director.relay.completed = true
		hud._update_tactical_hint()
		fits(hud.tactical_hint,"post-seal next operation %s" % view)
		check(not desktop or hud.tactical_hint.text.contains("WASD"),"desktop next operation names a missing joystick")
		GameManager.tactical_director.relay.completed = false
		check(hud.active_ability_button.text == "旋斬","button naming changed across channel state")
		var guide := preload("res://scripts/ui/first_run_guide.gd").new()
		viewport.add_child(guide)
		check(guide._controls_page_text().contains("旋斬"),"tutorial missing actual action name")
		check(desktop or not guide._controls_page_text().contains("空白鍵"),"touch tutorial contains keyboard instruction")
		hud._open_formation_picker()
		await get_tree().process_frame
		if view == Vector2i(768,1024):
			hud._on_combo_break_requested(12)
			await get_tree().create_timer(0.9,true).timeout
			check(hud.formation_picker.visible,"combo fade reset layout and closed formation picker")
		check(not hud.formation_picker.get_global_rect().intersects(hud.tactical_hint.get_global_rect()),"picker covers mission")
		check(Rect2(Vector2.ZERO,Vector2(view)).encloses(hud.formation_picker.get_global_rect()),"picker outside viewport")
		for id in squad.FORMATION_ORDER:
			var button: Button = hud.formation_picker.buttons[id]
			check(button.text.contains("效果："),"formation has no visible action description")
			for line in button.text.split("\n"):
				check(button.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x + 10 <= button.size.x,"formation text overflows")
			check(button.size.x >= 44 and button.size.y >= 44,"formation touch target too small")
			check(button.get_theme_font_size("font_size") >= 14,"formation menu shrank below baseline font")
		var banner: Node = hud.root.get_node("LootBanner")
		banner.active = true
		banner._process(0.1)
		check(not banner.visible,"loot notification shows partially behind formation picker")
		hud._close_formation_picker()
		banner._process(0.1)
		check(banner.visible,"loot notification did not return after picker closed")
		banner.active = false
		banner.hide()
		GameManager.set_manual_pause(true)
		await get_tree().process_frame
		check(hud.pause_backdrop.visible and hud.pause_overlay.visible,"pause has no explicit backdrop")
		check(is_equal_approx(hud.pause_overlay.get_theme_stylebox("panel").bg_color.a,1.0),"pause page is transparent")
		check(not hud.time_label.visible and not hud.toast_panel.visible,"battle text shines through pause")
		check(not hud.pause_title_label.get_global_rect().intersects(hud.pause_scroll.get_global_rect()),"pause header covers body")
		check(not hud.pause_resume_button.get_global_rect().intersects(hud.pause_scroll.get_global_rect()),"pause footer covers body")
		GameManager.set_manual_pause(false)
		if view == Vector2i(844,390):
			_test_tactics(arena,squad)
			var number := preload("res://scripts/vfx/damage_number.gd").new()
			arena.add_child(number)
			number.pool_on_acquire()
			var transform := viewport.get_canvas_transform().affine_inverse()
			number.setup("爆擊 12345",transform * Vector2(70,30),Color.WHITE)
			number._process(0.016)
			check(not number.value_label.visible,"damage number entered HUD lane")
			number.setup(123,transform * Vector2(400,210),Color.WHITE)
			number._process(0.016)
			check(number.value_label.visible,"damage number hidden in clear battlefield")
			number.setup(123,transform * Vector2(150,365),Color.WHITE)
			number._process(0.016)
			check(not number.value_label.visible,"damage number entered lower touch controls")
			number.free()
		evidence.append({"width":view.x,"height":view.y,"regions":str(zones)})
		GameManager.game_running = false
		var menu := preload("res://scenes/ui/MainMenu.tscn").instantiate()
		viewport.add_child(menu)
		menu._show_panel("guide")
		await get_tree().process_frame
		check(menu.side_scroll.position.y >= menu.side_close_button.position.y + menu.side_close_button.size.y + 8,"guide body crosses fixed close/header")
		check(not menu.side_title.get_global_rect().intersects(menu.side_close_button.get_global_rect()),"guide close covers title")
		for label in menu.side_content.get_children():
			if label is Label and not desktop:
				check(not label.text.contains("空白鍵"),"touch gameplay guide mentions keyboard")
		viewport.queue_free()
		await get_tree().process_frame
	MOBILE.set_device_hints_override_for_tests({})
	get_tree().paused = false
	DirAccess.make_dir_recursive_absolute("res://docs/content/r1/tests")
	var file := FileAccess.open("res://docs/content/r1/tests/mechanics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"VERIFIED" if failures.is_empty() else "BLOCKED","checks":checks,"failures":failures,"viewports":evidence},"\t"))
	print("CONTENT_R1_%s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_tactics(arena: Node,squad: Node) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_active:
			EntityFactory.release_enemy(enemy)
	var captain: Node2D = GameManager.player
	var origin := captain.global_position
	var forward: Vector2 = captain.get_locomotion_facing_direction()
	var rear := EntityFactory.spawn_enemy("normal",{"max_hp":100,"speed":0,"damage":0,"xp":0,"gold":0,"radius":12},origin-forward*45)
	var front := EntityFactory.spawn_enemy("normal",{"max_hp":100,"speed":0,"damage":0,"xp":0,"gold":0,"radius":12},origin+forward*180)
	squad.formation_id = "wedge"
	check(squad.select_formation_target(captain,250) == front,"wedge failed to prefer frontal threat")
	squad.formation_id = "scatter"
	check(squad.select_formation_target(captain,250) == rear,"scatter lost nearest target selection")
	var pickup_base: float = captain.pickup_radius
	check(captain.get_pickup_radius() >= pickup_base * 1.6,"scatter displayed pickup radius without actual effect")
	squad.formation_id = "ring"
	var follower: Node = squad.get_members()[1]
	follower.global_position = origin + Vector2(95,0)
	check(is_equal_approx(squad.get_spatial_cover_multiplier(follower),0.92),"ring cover does not apply inside boundary")
	follower.global_position = origin + Vector2(97,0)
	check(is_equal_approx(squad.get_spatial_cover_multiplier(follower),1.0),"ring cover applies beyond displayed boundary")
	check(squad.recruit_hero("echo_singer"),"bond participant could not be recruited")
	check(squad.has_active_bond("bond_guard_echo"),"live participants failed to enable bond")
	check(squad.bond_reveal_text.contains("星盾") and squad.bond_reveal_text.contains("5%"),"bond banner omits effect")
	var hud: Node = arena.get_node("HUD")
	hud._process(0.0)
	check(hud.toast_panel.visible and hud.toast_label.text == squad.bond_reveal_text,"bond event does not own the notice lane")
	fits(hud.toast_label,"bond participants and effect")
	check(squad.get_formation_regen_per_second() >= 1.5,"ring resonance regen is only visual")
	var echo: Node = squad.get_member_by_id("echo_singer")
	echo.is_alive = false
	squad.recompute_bonds()
	check(not squad.has_active_bond("bond_guard_echo"),"dead participant retained bond")
	EntityFactory.release_enemy(rear)
	EntityFactory.release_enemy(front)
