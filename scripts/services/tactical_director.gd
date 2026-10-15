extends Node

# Per-sortie goals use real movement, successful formation changes and combat events.
const CATALOG := preload("res://scripts/services/tactical_catalog.gd")
var formations: Dictionary = {"wedge": true}
var distance_walked := 0.0
var last_position := Vector2.ZERO
var claimed: Dictionary = {}
var hunt_announced := false
var hunt_spawned := false
var boss_guard_at := -1.0
var boss_guard_spawned := false
var tick_timer := 0.0
var guard_history: Array[Dictionary] = []

func _ready() -> void:
	if is_instance_valid(GameManager.player):
		last_position = GameManager.player.global_position
	GameManager.boss_phase_transition_requested.connect(_on_boss_phase)

func _process(delta: float) -> void:
	if not GameManager.game_running or get_tree().paused:
		return
	if is_instance_valid(GameManager.player):
		var current: Vector2 = GameManager.player.global_position
		# Ignore wrap/teleport discontinuities; an idle player earns no distance.
		var step := last_position.distance_to(current)
		if step < 100.0:
			distance_walked += step
		last_position = current
	if is_instance_valid(GameManager.squad_manager):
		formations[GameManager.squad_manager.get_formation_id()] = true
	tick_timer -= delta
	if tick_timer > 0.0:
		return
	tick_timer = 0.15
	check_objectives()
	if GameManager.run_mode != "campaign":
		return
	if GameManager.elapsed_time >= 32.0 and not hunt_announced:
		hunt_announced = true
		GameManager.show_toast("追獵預告：6 秒後菁英抵達。圓陣護衛，楔形反擊。")
	if GameManager.elapsed_time >= 38.0 and not hunt_spawned and not GameManager.boss_active:
		hunt_spawned = _spawn_guard("hunt")
	if boss_guard_at >= 0.0 and GameManager.elapsed_time >= boss_guard_at and GameManager.boss_active and not boss_guard_spawned:
		boss_guard_spawned = _spawn_guard("boss_guard")

func check_objectives() -> void:
	if GameManager.run_mode != "campaign":
		return
	if distance_walked >= 160.0 and formations.size() == 3:
		_claim("maneuver")
	if GameManager.elites_killed >= 2:
		_claim("hunt")
	if GameManager.boss_killed:
		_claim("clear")

func _claim(id: String) -> void:
	if claimed.has(id):
		return
	var result: int = MetaProgress.award_tactical_medal(GameManager.selected_stage_id, id)
	if result < 0:
		return # A failed disk write remains retryable.
	claimed[id] = true
	var definition := CATALOG.medal(id)
	GameManager.show_toast("%s完成%s" % [definition.name, "：殘響 +%d" % result if result > 0 else "（已收藏）"])
	if id == "clear":
		GameManager.show_toast(str(CATALOG.RECORDS.get(GameManager.selected_stage_id, "")))

func _on_boss_phase() -> void:
	if boss_guard_at >= 0.0 or GameManager.run_mode != "campaign":
		return
	boss_guard_at = GameManager.elapsed_time + 2.0
	GameManager.show_toast("守關者呼叫護衛！2 秒後抵達，留出退路。")

func _spawn_guard(reason: String) -> bool:
	var spawner := get_parent().get_node_or_null("EnemySpawner")
	if spawner == null:
		return false
	var enemy: Node = spawner.spawn_tactical_guard(CATALOG.guard_id(GameManager.selected_stage_id))
	if enemy == null:
		return false
	guard_history.append({"reason":reason, "stage":GameManager.selected_stage_id, "time":GameManager.elapsed_time, "profile":CATALOG.guard_id(GameManager.selected_stage_id)})
	return true

func current_hint() -> String:
	if not claimed.has("maneuver"):
		if distance_walked < 160.0:
			return "拖左下移動・自動攻擊｜走位 %d/160" % mini(160, int(distance_walked))
		return "點按換陣／長按直選｜陣形 %d/3" % formations.size()
	if not claimed.has("hunt"):
		return "雙菁追獵 %d/2｜首取殘響 +5" % mini(2, GameManager.elites_killed)
	if not claimed.has("clear"):
		return "守關突破｜Boss %s｜首取 +8" % GameManager.format_time(float(CATALOG.STAGES.get_stage(GameManager.selected_stage_id).get("boss_time",90)))
	return "本關目標完成！回主選單查看收藏"

func progress_text() -> String:
	return "三陣演練：走位 %d/160・陣形 %d/3\n雙菁追獵：%d/2　守關突破：%s\n徽記 %d/3（首取 +3／+5／+8 殘響）" % [mini(160,int(distance_walked)), formations.size(), mini(2,GameManager.elites_killed), "完成" if claimed.has("clear") else "未完成", MetaProgress.get_tactical_medal_count(GameManager.selected_stage_id)]
