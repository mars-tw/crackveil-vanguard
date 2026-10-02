extends Control

const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")

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


func _refresh() -> void:
	var viewport_size := MOBILE_TUNING.ui_layout_size(get_viewport().get_visible_rect().size)
	var mobile := MOBILE_TUNING.use_mobile_ui(viewport_size)
	var portrait := viewport_size.y > viewport_size.x
	var width := minf(144.0 if mobile and not portrait else 230.0, viewport_size.x - 32.0)
	panel.position = Vector2((viewport_size.x - width) * 0.5, MOBILE_TUNING.safe_top_padding(viewport_size) + (108.0 if mobile and portrait else 58.0))
	panel.size = Vector2(width, 42.0)
	headline.add_theme_font_size_override("font_size", 13 if mobile and not portrait else 15)
	detail.add_theme_font_size_override("font_size", 11)
	rows.add_theme_constant_override("separation", 2)
	visible = GameManager.game_running and not GameManager.is_game_over and not GameManager.stage_victory_pending and not GameManager.manual_paused and (GameManager.combo_count >= 3 or GameManager.boss_active)
	detail.visible = GameManager.combo_fire_rate_timer > 0.0 or GameManager.boss_active
	if not visible:
		return
	var boss: Node = null
	if GameManager.boss_active:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if bool(enemy.get("is_boss")) and float(enemy.get("hp")) > 0.0:
				boss = enemy
				break
	if boss != null:
		headline.text = "裂隙守門者"
		meter.value = clampf(float(boss.get("hp")) / maxf(1.0, float(boss.get("max_hp"))), 0.0, 1.0)
		detail.text = "擊破掉落傳說裝備"
	elif GameManager.combo_count >= 3:
		headline.text = "%d 連斬" % GameManager.combo_count
		meter.value = clampf(1.0 - (GameManager.elapsed_time - GameManager.combo_last_kill_time) / GameManager.COMBO_WINDOW, 0.0, 1.0)
		detail.text = "火力爆發 %.1f 秒" % GameManager.combo_fire_rate_timer if GameManager.combo_fire_rate_timer > 0.0 else "25 連斬啟動火力爆發"
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
		detail.text = "移動回收裝備與經驗" if mobile else "空白鍵：裂隙脈衝　P：暫停"
