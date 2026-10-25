extends Control

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const LAYOUT := preload("res://scripts/ui/battle_layout.gd")

var panel: PanelContainer
var headline: Label
var detail: Label
var meter: ProgressBar
var rows: VBoxContainer
var refresh_timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.035, 0.065, 0.89)
	style.border_color = Color(0.32, 0.74, 0.88, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	rows = VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 2)
	panel.add_child(rows)
	headline = Label.new()
	headline.add_theme_font_size_override("font_size", 15)
	headline.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0))
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(headline)
	meter = ProgressBar.new()
	meter.show_percentage = false
	meter.custom_minimum_size.y = 5.0
	meter.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.75, 0.28)
	fill.set_corner_radius_all(2)
	meter.add_theme_stylebox_override("fill", fill)
	rows.add_child(meter)
	detail = Label.new()
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", Color(0.62, 0.79, 0.85))
	rows.add_child(detail)


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return
	refresh_timer = 0.1
	_refresh()


func _current_tactical_guard() -> Node:
	if not is_instance_valid(GameManager.tactical_director):return null
	var refs: Array=GameManager.tactical_director.guard_refs
	for index in range(refs.size()-1,-1,-1):
		var entry: Dictionary=refs[index]
		var ref: WeakRef=entry.get("ref")
		var enemy: Object=ref.get_ref() if is_instance_valid(ref) else null
		if not is_instance_valid(enemy):continue
		if int(enemy.get("spawn_token"))!=int(entry.get("token",-1)):continue
		if enemy.get("is_active")!=true or enemy.get("is_dying")==true or int(enemy.get("tactical_recoveries"))>=2:continue
		return enemy as Node
	return null


func _refresh() -> void:
	var viewport_size := MOBILE_TUNING.ui_layout_size(get_viewport().get_visible_rect().size)
	var mobile := MOBILE_TUNING.use_mobile_ui(viewport_size)
	var portrait := viewport_size.y > viewport_size.x
	LAYOUT.place(panel, LAYOUT.regions(viewport_size, mobile).combo)
	headline.add_theme_font_size_override("font_size", 14)
	detail.add_theme_font_size_override("font_size", 11)
	rows.add_theme_constant_override("separation", 2)
	var guard: Node = _current_tactical_guard()
	var nearest := 500.0
	if is_instance_valid(guard) and is_instance_valid(GameManager.player):nearest=guard.global_position.distance_to(GameManager.player.global_position)
	if is_instance_valid(GameManager.player):
		for candidate in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(guard):break
			if candidate.get("is_active") == true and candidate.get("is_dying") != true and int(candidate.get("tactical_min_cycles")) > 0:
				var distance: float = candidate.global_position.distance_to(GameManager.player.global_position)
				if distance < nearest:
					nearest = distance
					guard = candidate
	visible = GameManager.game_running and not GameManager.is_game_over and not GameManager.stage_victory_pending and not GameManager.manual_paused and (GameManager.combo_count >= 3 or GameManager.boss_active or guard != null)
	detail.visible = true
	if not visible:
		return
	var boss: Node = null
	if GameManager.boss_active:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if bool(enemy.get("is_boss")) and float(enemy.get("hp")) > 0.0:
				boss = enemy
				break
	var guard_cycle_active: bool=guard!=null and int(guard.get("tactical_recoveries"))<2
	if guard_cycle_active:
		headline.text = "%s・攻防已完成 %d/2 輪" % [str(guard.get("special_elite_name")),mini(2,guard.tactical_recoveries)]
		meter.value = float(guard.get("hp"))/maxf(1.0,float(guard.get("max_hp")))
		detail.text = "護甲已破・反擊" if guard.tactical_recoveries>=2 else "預警出招・閃開刻線" if guard.current_animation_name==&"attack" else "躲避後・等待下一輪"
	elif boss != null:
		var stage: Dictionary=GameManager.STAGE_CATALOG.get_stage(GameManager.selected_stage_id)
		headline.text = str(stage.get("boss_name","守關者"))
		meter.value = clampf(float(boss.get("hp")) / maxf(1.0, float(boss.get("max_hp"))), 0.0, 1.0)
		detail.text = "已完成攻防 %d/2 輪・%s" % [mini(2,boss.attack_impact_count), "半血增援" if boss.boss_phase_two_triggered else "躲預警再反擊"]
		if is_instance_valid(GameManager.tactical_director):
			var pending_at: float=GameManager.tactical_director.boss_guard_at
			if pending_at>GameManager.elapsed_time:
				detail.text="增援 %.1f 秒・護甲維持" % (pending_at-GameManager.elapsed_time)
	elif guard != null:
		headline.text = "%s・攻防已完成 %d/2 輪" % [str(guard.get("special_elite_name")),mini(2,guard.tactical_recoveries)]
		meter.value = float(guard.get("hp"))/maxf(1.0,float(guard.get("max_hp")))
		detail.text = "護甲已破・反擊" if guard.tactical_recoveries>=2 else "預警出招・閃開刻線" if guard.current_animation_name==&"attack" else "躲避後・等待下一輪"
	elif GameManager.combo_count >= 3:
		headline.text = "%d 連斬" % GameManager.combo_count
		meter.value = clampf(1.0 - (GameManager.elapsed_time - GameManager.combo_last_kill_time) / GameManager.COMBO_WINDOW, 0.0, 1.0)
		detail.text = GameManager.combo_status_text()
	else:
		var spawner := GameManager.arena.get_node_or_null("EnemySpawner") if is_instance_valid(GameManager.arena) else null
		var encounter_time := 180.0
		var encounter_name := "Boss"
		if spawner != null and float(spawner.get("next_elite_time")) < encounter_time and GameManager.elapsed_time < 180.0:
			encounter_time = float(spawner.get("next_elite_time"))
			encounter_name = "菁英"
		var seconds := maxi(0, ceili(encounter_time - GameManager.elapsed_time))
		headline.text = "無盡作戰" if GameManager.boss_killed else "%s來襲 %d 秒" % [encounter_name, seconds]
		meter.value = clampf(GameManager.elapsed_time / maxf(1.0, encounter_time), 0.0, 1.0)
		detail.text = "移動回收裝備與經驗" if MOBILE_TUNING.has_confirmed_touch() else "空白鍵：旋斬　P：暫停"
