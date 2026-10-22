extends Node

# A debug-only UI regression fixture. It uses the real arena, modal callbacks,
# pressure transitions and notification widgets. Native Dummy checks state;
# Web exposes the same checkpoints for untouched renderer screenshots.
var arena: Node
var checks := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var sample := 0
var capture_web := false
var gate_only := false
var start_state: Dictionary = {}
var start_input_trace: Array[Dictionary] = []

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	capture_web = OS.has_feature("web")
	if capture_web: gate_only = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('gate_only') === '1'",true))
	AudioManager.set_muted(true)
	GameManager.campaign_save_path = "user://content_r21_test_campaign.cfg"
	MetaProgress.debug_use_save_path("user://content_r21_test_meta.cfg", true)
	PlayerSettings.debug_use_save_path("user://content_r21_test_settings.cfg", true)
	AchievementProgress.debug_use_save_path("user://content_r21_test_achievements.cfg", true)
	call_deferred("_run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		printerr("CONTENT_R21_FAIL: " + description)

func _run() -> void:
	if not capture_web: _audio_tail_contract()
	var sizes: Array[Vector2i] = [Vector2i(844,390), Vector2i(390,844), Vector2i(1366,600)]
	if capture_web:
		sizes.assign([Vector2i(MobileTuning.ui_layout_size(get_viewport().get_visible_rect().size))])
	for size in sizes:
		var host: Node = self
		if not capture_web:
			var view := SubViewport.new()
			view.size = size
			view.render_target_update_mode = SubViewport.UPDATE_DISABLED
			add_child(view)
			host = view
		MobileTuning.set_device_hints_override_for_tests({"ua_phone":size.x!=1366,"ua_mobile":size.x!=1366,"touch_available":size.x!=1366,"mouse_available":size.x==1366})
		GameManager.selected_stage_id = "moon"
		GameManager.forced_run_seed = 55210
		GameManager.tactical_launch = false
		arena = preload("res://scenes/arena/Arena.tscn").instantiate()
		host.add_child(arena)
		await get_tree().process_frame
		GameManager.set_process(false)
		arena.get_node("EnemySpawner").set_process(false)
		var relay: Node = GameManager.tactical_director.relay
		relay.set_process(false)
		relay.pressure.set_process(false)
		GameManager.tactical_director.set_process(false)
		for member in GameManager.squad_manager.get_members():
			member.set_physics_process(false)
			for weapon in member.weapons.values(): weapon.set_process(false)
		var hud: Node = arena.get_node("HUD")
		var loot: Node = hud.root.get_node("LootBanner")
		GameManager.elapsed_time = 12
		GameManager.squad_manager.bond_reveal_timer = 0
		hud.toast_queue.clear()
		hud.toast_showing = false
		hud._apply_responsive_layout()
		relay._update_label()
		await get_tree().process_frame
		if capture_web and not AudioManager.is_audio_unlocked():
			JavaScriptBridge.eval("window.__cvContentR21Start=" + JSON.stringify({"rect":rect(hud.audio_prompt_button.get_global_rect())}),true)
			while not AudioManager.is_audio_unlocked():
				await get_tree().process_frame
			JavaScriptBridge.eval("window.__cvContentR21Start=null",true)
			for frame in range(3): await get_tree().process_frame
			start_state = {"paused":get_tree().paused,"manual_paused":GameManager.manual_paused,"system_paused":GameManager.is_system_pause_active(),"summon_visible":GameManager.summon_screen.get_debug_state().visible,"gate_visible":hud.audio_prompt_button.visible,"pause_rect":rect(hud.pause_button.get_global_rect()),"input_trace":start_input_trace.duplicate()}
			check(not start_state.paused and not start_state.manual_paused and not start_state.system_paused and not start_state.summon_visible,"%s start gesture activated underlying summon/equipment/pause" % size)
			JavaScriptBridge.eval("window.__cvContentR21AfterStart="+JSON.stringify(start_state),true)
			while not bool(JavaScriptBridge.eval("window.__cvContentR21VerifyNextInput === true",true)):
				await get_tree().process_frame
			check(not get_tree().paused,"%s normal input after start did not resume" % size)
		check(not hud.audio_prompt_button.visible, "%s official start gate still covers playfield" % size)
		if gate_only:
			GameManager.game_running = false
			arena.queue_free()
			await get_tree().process_frame
			break
		check(relay.marker_label.visible, "%s marker missing before picker" % size)
		hud._open_formation_picker()
		check(not relay.marker_label.visible, "%s picker did not immediately hide marker" % size)
		GameManager.emit_stats()
		hud._on_pause_changed(false)
		relay._update_label()
		check(not relay.marker_label.visible, "%s stats/pause callback re-showed marker through picker" % size)
		for button in hud.formation_picker.buttons.values():
			check(button.size.y >= 44, "%s picker target under 44px" % size)
		check(Rect2(Vector2.ZERO,Vector2(size)).encloses(hud.formation_picker.get_global_rect()), "%s picker outside viewport" % size)
		await _capture("picker-open", true)
		hud.formation_picker.cancel_button.pressed.emit()
		check(relay.marker_label.visible, "%s cancel did not restore marker" % size)
		await _capture("picker-closed", true)
		GameManager.set_manual_pause(true)
		GameManager.emit_stats()
		check(not relay.marker_label.visible, "%s marker through manual pause" % size)
		GameManager.set_manual_pause(false)
		check(relay.marker_label.visible, "%s unpause lost marker" % size)
		var pressure: Node = relay.pressure
		for index in range(3):
			hud.toast_queue.clear()
			hud.toast_showing = false
			pressure.configure(relay.anchor,index)
			pressure.begin()
			for ref in pressure.enemies:
				var enemy: Object = ref.get_ref()
				if is_instance_valid(enemy): enemy.set_physics_process(false)
			loot.show_item({"rarity_name":"裝備","name":"UI 回歸裝備","description":"攻勢結束後顯示"},{},true)
			for frame in range(8): await get_tree().process_frame
			check(not loot.visible and is_zero_approx(loot.age), "%s/%s warning consumed/covered loot" % [size,pressure.kind])
			check(hud.toast_panel.visible and hud.toast_label.text.contains("預警"), "%s/%s warning hidden behind loot" % [size,pressure.kind])
			await _capture(pressure.kind + "-warning", false)
			pressure.advance(pressure.WARNING)
			for frame in range(8): await get_tree().process_frame
			check(pressure.phase=="active" and not loot.visible and is_zero_approx(loot.age), "%s/%s active consumed/covered loot" % [size,pressure.kind])
			await _capture(pressure.kind + "-active", true)
			# Expire the important warning through the real UI timer before asking
			# the equipment banner to resume; recovery alone does not outrank it.
			hud._process(1.51)
			pressure.advance(pressure.ACTIVE)
			for frame in range(8): await get_tree().process_frame
			check(pressure.phase=="recovery" and loot.visible and loot.age>0 and loot.age<1.0, "%s/%s delayed loot did not resume" % [size,pressure.kind])
			await _capture(pressure.kind + "-recovery", index==2)
			loot.active = false
			loot.hide()
		pressure.enabled = false
		hud.toast_showing = false
		hud.toast_queue.clear()
		GameManager.squad_manager.bond_reveal_timer = 10.0
		GameManager.squad_manager.bond_reveal_text = "羈絆共鳴"
		hud._on_toast_requested("取得裝備：一般通知")
		for keyword in ["預警","反噬","封隙","護衛"]:
			hud._on_toast_requested(keyword + "重要訊息")
		loot.show_item({"name":"等候重要戰況","description":"重要訊息後顯示"},{},true)
		for keyword in ["預警","反噬","封隙","護衛"]:
			hud._process(0)
			loot._process(0.1)
			check(hud.toast_panel.visible and hud.toast_label.text==keyword+"重要訊息", "%s urgent %s lost to bond/loot/queue" % [size,keyword])
			check(not loot.visible and is_zero_approx(loot.age), "%s urgent %s consumed loot lifetime" % [size,keyword])
			await _capture("urgent-" + keyword, keyword=="預警")
			hud._process(1.51)
		GameManager.squad_manager.bond_reveal_timer = 0
		GameManager.game_running = false
		if host == self: arena.queue_free()
		else: host.queue_free()
		await get_tree().process_frame
	MobileTuning.set_device_hints_override_for_tests({})
	var result := {"version":ProjectSettings.get_setting("application/config/version"),"status":"VERIFIED" if failures.is_empty() else "BLOCKED","checks":checks,"failures":failures,"records":records,"start_state":start_state,"gate_only":gate_only,"fixture":"real arena UI; deterministic debug checkpoints; combat physics disabled for UI isolation; no gameplay balance claims"}
	if capture_web:
		JavaScriptBridge.eval("window.__cvContentR21Result="+JSON.stringify(result),true)
	else:
		var output := "res://docs/content/r2-1/tests/ui-regression.json"
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"\t"))
		print("CONTENT_R21_%s checks=%d failures=%d" % [result.status,checks,failures.size()])
		get_tree().quit(0 if failures.is_empty() else 1)

func _capture(label: String, screenshot: bool) -> void:
	await get_tree().process_frame
	var hud: Node = arena.get_node("HUD")
	var relay: Node = GameManager.tactical_director.relay
	var loot: Node = hud.root.get_node("LootBanner")
	var view := MobileTuning.ui_layout_size(get_viewport().get_visible_rect().size) if capture_web else Vector2(arena.get_viewport().size)
	var row := {"sample":sample,"label":label,"screenshot":screenshot,"viewport":[int(view.x),int(view.y)],"version":ProjectSettings.get_setting("application/config/version"),"audio_gate_visible":hud.audio_prompt_button.visible,"picker_visible":hud.formation_picker.visible,"marker_visible":relay.marker_label.visible,"marker_rect":rect(relay.marker_label.get_global_rect()),"picker_rect":rect(hud.formation_picker.get_global_rect()),"loot_visible":loot.visible,"loot_active":loot.active,"loot_age":loot.age,"phase":relay.pressure.phase,"kind":relay.pressure.kind,"toast_visible":hud.toast_panel.visible,"toast_text":hud.toast_label.text,"toast_remaining":hud.toast_remaining,"failures_so_far":failures.duplicate()}
	records.append(row)
	if capture_web:
		arena.process_mode = PROCESS_MODE_DISABLED
		JavaScriptBridge.eval("window.__cvContentR21Sample="+JSON.stringify(row),true)
		while not bool(JavaScriptBridge.eval("window.__cvContentR21Next === true",true)):
			await get_tree().process_frame
		JavaScriptBridge.eval("window.__cvContentR21Next=false;window.__cvContentR21Sample=null",true)
		arena.process_mode = PROCESS_MODE_INHERIT
	sample += 1

func rect(value: Rect2) -> Array:
	return [value.position.x,value.position.y,value.size.x,value.size.y]

func _input(event: InputEvent) -> void:
	if not capture_web or not start_state.is_empty() or start_input_trace.size()>=24: return
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		start_input_trace.append({"type":event.get_class(),"device":event.device,"pressed":event.pressed,"position":[event.position.x,event.position.y],"button":event.button_index if event is InputEventMouseButton else event.index,"unlocked_before_audio_handler":AudioManager.unlocked})

func _audio_tail_contract() -> void:
	AudioManager._notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	for button in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_LEFT,MOUSE_BUTTON_WHEEL_RIGHT]:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = button
		wheel.pressed = true
		AudioManager._arm_unlock_tail(wheel)
		check(AudioManager.unlock_mouse_button==0,"wheel without release armed a permanent mouse guard")
		check(not AudioManager._consume_unlock_tail(InputEventMouseMotion.new()),"wheel swallowed later pointer motion")
		var next_click := InputEventMouseButton.new()
		next_click.button_index = MOUSE_BUTTON_LEFT
		next_click.pressed = true
		check(not AudioManager._consume_unlock_tail(next_click),"wheel swallowed later real click")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	AudioManager._arm_unlock_tail(mouse)
	check(AudioManager._consume_unlock_tail(InputEventMouseMotion.new()),"unlock drag tail reached underlying UI")
	mouse.pressed = false
	check(AudioManager._consume_unlock_tail(mouse),"unlock mouse release reached underlying UI")
	mouse.pressed = true
	check(not AudioManager._consume_unlock_tail(mouse),"next real mouse press swallowed")
	var touch := InputEventScreenTouch.new()
	touch.index = 4
	touch.pressed = true
	AudioManager._arm_unlock_tail(touch)
	check(not AudioManager._consume_unlock_tail(mouse),"touch guard swallowed an independent real mouse")
	var drag := InputEventScreenDrag.new()
	drag.index = 4
	check(AudioManager._consume_unlock_tail(drag),"unlock touch drag reached underlying UI")
	touch.pressed = false
	check(AudioManager._consume_unlock_tail(touch),"unlock touch release reached underlying UI")
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	check(AudioManager._consume_unlock_tail(emulated),"unlock emulated mouse press reached underlying UI")
	touch.pressed = true
	check(not AudioManager._consume_unlock_tail(touch),"next real touch swallowed")
	check(not AudioManager._consume_unlock_tail(emulated),"next touch's emulated pointer swallowed")
	# The real Web trace delivers emulated mouse press before raw touch press.
	AudioManager._arm_unlock_tail(emulated)
	check(AudioManager._consume_unlock_tail(touch),"mouse-first unlock let raw touch press through")
	emulated.pressed = false
	check(AudioManager._consume_unlock_tail(emulated),"mouse-first unlock let emulated release through")
	touch.pressed = false
	check(AudioManager._consume_unlock_tail(touch),"mouse-first unlock let raw touch release through")
	touch.pressed = true
	check(not AudioManager._consume_unlock_tail(touch),"mouse-first unlock swallowed next touch")
	check(not AudioManager._consume_unlock_tail(mouse),"mouse-first unlock swallowed next mouse")
	AudioManager._arm_unlock_tail(mouse)
	AudioManager._notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not AudioManager._consume_unlock_tail(InputEventMouseMotion.new()),"lost release across focus change left mouse locked")
