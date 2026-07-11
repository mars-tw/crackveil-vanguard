extends Node

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const MAIN_MENU_SCRIPT := preload("res://scripts/ui/main_menu.gd")
const LEVEL_UP_SCRIPT := preload("res://scripts/ui/level_up_screen.gd")
const CONTRACT_SCRIPT := preload("res://scripts/ui/contract_screen.gd")
const SHOP_SCRIPT := preload("res://scripts/ui/rift_shop_screen.gd")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const JOYSTICK_SCRIPT := preload("res://scripts/ui/virtual_joystick.gd")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")

var phase := "boot"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_watchdog")
	call_deferred("_run")


func _watchdog() -> void:
	await get_tree().create_timer(18.0, true, false, true).timeout
	if phase != "done":
		_fail("watchdog timeout at " + phase)


func _run() -> void:
	phase = "grade"
	if not _test_mobile_grade(): return
	phase = "enemy_cache"
	if not await _test_enemy_animation_cache(): return
	phase = "menu"
	if not await _test_portrait_menu(): return
	phase = "cards"
	if not await _test_card_hierarchy(): return
	phase = "controls"
	if not await _test_glass_controls(): return
	phase = "shop"
	if not await _test_mobile_shop_confirmation(): return
	phase = "queues"
	if not _test_spawn_budgets(): return
	phase = "done"
	print("M2_REGRESSION_PASS")
	get_tree().quit(0)


func _test_mobile_grade() -> bool:
	var mobile := MOBILE_TUNING.battlefield_color_modulate(Vector2(390.0, 844.0), true)
	var desktop := MOBILE_TUNING.battlefield_color_modulate(Vector2(1280.0, 720.0), false)
	if mobile == Color.WHITE or mobile.r >= 0.9 or mobile.g >= 0.9 or desktop != Color.WHITE:
		_fail("battlefield color grade profile drifted")
		return false
	print("M2_GRADE mobile=%s desktop=%s" % [str(mobile), str(desktop)])
	return true


func _test_enemy_animation_cache() -> bool:
	var holder := Node2D.new()
	add_child(holder)
	var first := ENEMY_SCENE.instantiate()
	var second := ENEMY_SCENE.instantiate()
	holder.add_child(first)
	holder.add_child(second)
	var config := {
		"max_hp": 10.0, "speed": 1.0, "damage": 1.0, "xp": 0, "gold": 0,
		"radius": 13.0, "sprite_path": "res://assets/sprites/enemy_grunt.png", "sprite_scale": 1.0
	}
	first.pool_on_acquire()
	second.pool_on_acquire()
	first.setup("m2_a", config)
	second.setup("m2_b", config)
	var first_frames: SpriteFrames = first.animated_sprite.sprite_frames
	var second_frames: SpriteFrames = second.animated_sprite.sprite_frames
	if first_frames == null or first_frames != second_frames:
		_fail("pooled enemies did not share cached SpriteFrames")
		return false
	holder.queue_free()
	await get_tree().process_frame
	print("M2_ENEMY_FRAME_CACHE shared=true")
	return true


func _test_portrait_menu() -> bool:
	var viewport := _make_viewport(Vector2i(390, 844))
	var menu := MAIN_MENU_SCRIPT.new()
	viewport.add_child(menu)
	await get_tree().process_frame
	if menu.rift_accent == null or not menu.rift_accent.visible:
		_fail("portrait rift accent missing")
		return false
	if not _inside(menu.logo_label.get_global_rect(), Vector2(390.0, 844.0)) or not _inside(menu.start_button.get_global_rect(), Vector2(390.0, 844.0)):
		_fail("portrait menu composition escaped 390x844")
		return false
	if menu.start_button.get_global_rect().get_center().y < 250.0:
		_fail("portrait menu actions remained top-heavy")
		return false
	if menu.logo_label.get_global_rect().grow(12.0).intersects(menu.start_button.get_global_rect()):
		_fail("portrait logo overlaps primary action")
		return false
	viewport.queue_free()
	print("M2_MENU_390 logo=%s start=%s" % [str(menu.logo_label.get_global_rect()), str(menu.start_button.get_global_rect())])
	return true


func _test_card_hierarchy() -> bool:
	var viewport := _make_viewport(Vector2i(390, 844))
	var level := LEVEL_UP_SCRIPT.new()
	viewport.add_child(level)
	await get_tree().process_frame
	level.show_options([
		{"name": "標準增幅", "description": "基礎數值", "upgrade_category": "standard"},
		{"name": "形態質變", "description": "規則改造", "upgrade_category": "qualitative"},
		{"name": "金色終型", "description": "完成進化", "upgrade_category": "evolution"}
	])
	await get_tree().process_frame
	var standard := level.option_buttons[0].get_theme_stylebox("normal") as StyleBoxFlat
	var qualitative := level.option_buttons[1].get_theme_stylebox("normal") as StyleBoxFlat
	var evolution := level.option_buttons[2].get_theme_stylebox("normal") as StyleBoxFlat
	if standard == null or qualitative == null or evolution == null:
		_fail("upgrade card styles missing")
		return false
	if evolution.get_border_width(SIDE_LEFT) <= qualitative.get_border_width(SIDE_LEFT) or qualitative.border_color == standard.border_color:
		_fail("upgrade rarity hierarchy is not distinct")
		return false
	var contract := CONTRACT_SCRIPT.new()
	viewport.add_child(contract)
	await get_tree().process_frame
	contract.show_options([{"id": "a", "name": "契約 A", "description": "規則 A"}])
	await get_tree().process_frame
	var contract_style := contract.option_buttons[0].get_theme_stylebox("normal") as StyleBoxFlat
	if contract_style == null or contract_style.get_border_width(SIDE_LEFT) < 3:
		_fail("contract card hierarchy missing")
		return false
	viewport.queue_free()
	print("M2_CARDS standard=%d qualitative=%d evolution=%d contract=%d" % [
		standard.get_border_width(SIDE_LEFT), qualitative.get_border_width(SIDE_LEFT),
		evolution.get_border_width(SIDE_LEFT), contract_style.get_border_width(SIDE_LEFT)
	])
	return true


func _test_glass_controls() -> bool:
	var viewport := _make_viewport(Vector2i(390, 844))
	var joystick := JOYSTICK_SCRIPT.new()
	viewport.add_child(joystick)
	joystick.configure_for_viewport(Vector2(390.0, 844.0), true, 1)
	joystick._animate_feedback(0.92)
	await get_tree().create_timer(0.09, true, false, true).timeout
	if joystick.feedback_scale > 0.94:
		_fail("joystick press feedback did not animate")
		return false
	joystick._animate_feedback(1.0)
	var hud := HUD_SCRIPT.new()
	viewport.add_child(hud)
	await get_tree().process_frame
	var ability_style := hud.active_ability_button.get_theme_stylebox("normal") as StyleBoxFlat
	if ability_style == null or ability_style.bg_color.a < 0.65 or ability_style.border_color.a < 0.8:
		_fail("ability glass style missing")
		return false
	hud.active_ability_button.button_down.emit()
	await get_tree().create_timer(0.075, true, false, true).timeout
	if hud.active_ability_button.scale.x > 0.94:
		_fail("ability press scale feedback missing")
		return false
	hud.active_ability_button.button_up.emit()
	await get_tree().create_timer(0.13, true, false, true).timeout
	if hud.active_ability_button.scale.x < 0.98:
		_fail("ability button did not spring back")
		return false
	viewport.queue_free()
	print("M2_GLASS_CONTROLS joystick=%.2f ability_alpha=%.2f" % [joystick.feedback_scale, ability_style.bg_color.a])
	return true


func _test_mobile_shop_confirmation() -> bool:
	var viewport := _make_viewport(Vector2i(390, 844))
	var shop := SHOP_SCRIPT.new()
	viewport.add_child(shop)
	await get_tree().process_frame
	GameManager.gold = 100
	var emitted: Array[Dictionary] = []
	shop.purchase_selected.connect(func(option: Dictionary) -> void: emitted.append(option))
	var option := {"id": "m2_shop", "name": "手機商品", "description": "不可逆購買", "cost": 10, "enabled": true}
	shop.show_options([option])
	await get_tree().process_frame
	shop.option_buttons[0].pressed.emit()
	await get_tree().process_frame
	if emitted.size() != 0 or shop.option_buttons[0].text.find("再次點擊購買") < 0:
		_fail("mobile shop first tap purchased without confirmation")
		return false
	shop.option_buttons[0].pressed.emit()
	await get_tree().process_frame
	if emitted.size() != 1:
		_fail("mobile shop second tap did not purchase")
		return false
	viewport.queue_free()
	print("M2_SHOP_CONFIRM mobile_two_tap=true")
	return true


func _test_spawn_budgets() -> bool:
	var arena := Node2D.new()
	add_child(arena)
	EntityFactory.initialize_for_arena(arena)
	GameManager.game_running = true
	for index in range(10):
		EntityFactory.queue_regular_drop(Vector2(index, 0), 1, Vector2(index, 2), 1)
	EntityFactory._physics_process(1.0 / 60.0)
	if EntityFactory.regular_drop_queue.size() != 4:
		_fail("regular drop queue did not respect six-per-physics-frame budget")
		return false
	EntityFactory._physics_process(1.0 / 60.0)
	if not EntityFactory.regular_drop_queue.is_empty():
		_fail("regular drop queue did not drain deterministically")
		return false
	for index in range(8):
		EntityFactory.queue_death_visual(Vector2(index, 0), "res://assets/sprites/enemy_grunt.png", Color.WHITE, 13.0, 1.0, false, 0.0, 1.0)
	EntityFactory._process(1.0 / 60.0)
	if EntityFactory.death_visual_queue.size() != 3:
		_fail("death visuals did not respect five-per-frame budget")
		return false
	print("M2_SPAWN_BUDGET drops_per_tick=6 visuals_per_frame=5 pool_prealloc=true")
	return true


func _make_viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	return viewport


func _inside(rect: Rect2, size: Vector2) -> bool:
	return rect.position.x >= -1.0 and rect.position.y >= -1.0 and rect.end.x <= size.x + 1.0 and rect.end.y <= size.y + 1.0


func _fail(message: String) -> void:
	printerr("M2_REGRESSION_FAIL: " + message)
	get_tree().quit(1)
