extends RefCounted

## R31 終局 QA hook。
##
## 這個腳本只能在 debug executable 且帶有明確 user arg 時運作，並且
## Web release preset 會排除整個 scripts/debug 與 scenes/debug 目錄。
## Hook 只推進既有 runtime 狀態；Boss、英雄與 Boss 死亡仍走原本的
## spawner、take_damage、逐格死亡動畫與結算 signal。

const AUTH_ARGUMENT := "--qa-endgame=r31"
const EXPORT_ABSENCE_MARKER := "R31_ENDGAME_QA_HOOK_EXCLUDED"
const CONTRACT_ID := "contract_blood_tax"

var arena: Node


func _init(target_arena: Node) -> void:
	arena = target_arena


static func is_authorized_for(debug_build: bool, arguments: PackedStringArray) -> bool:
	return debug_build and arguments.has(AUTH_ARGUMENT)


func is_authorized() -> bool:
	return is_authorized_for(OS.is_debug_build(), OS.get_cmdline_user_args())


func advance_to(path_id: String) -> Dictionary:
	if not is_authorized():
		return _failure("QA hook 未授權；需要 debug build 與 %s" % AUTH_ARGUMENT)
	if arena == null or not is_instance_valid(arena):
		return _failure("Arena 不存在")
	_settle_opening_modals()
	match path_id:
		"near_boss":
			return _advance_to_boss()
		"near_death":
			return _advance_to_near_death()
		"victory":
			return _advance_to_victory()
		_:
			return _failure("未知 QA path：%s" % path_id)


func _settle_opening_modals() -> void:
	if bool(GameManager.get("waiting_for_contract")):
		GameManager.apply_contract({"id": CONTRACT_ID})
	var guide: Variant = arena.get("first_run_guide")
	if guide is CanvasLayer and is_instance_valid(guide):
		var guide_root: Variant = (guide as CanvasLayer).get("root")
		if guide_root is Control:
			(guide_root as Control).visible = false


func _advance_to_boss() -> Dictionary:
	var spawner := arena.get_node_or_null("EnemySpawner")
	if spawner == null:
		return _failure("EnemySpawner 不存在")
	var existing_boss := find_active_boss()
	if existing_boss != null:
		return {
			"ok": true,
			"path": "near_boss",
			"boss": existing_boss,
			"elapsed_time": float(GameManager.get("elapsed_time"))
		}
	var boss_time := float(spawner.get("boss_time"))
	GameManager.elapsed_time = max(float(GameManager.get("elapsed_time")), boss_time)
	spawner.call("_process", 0.0)
	var boss := find_active_boss()
	if boss == null:
		return _failure("Boss 時間門檻已推進，但 Boss 未生成")
	return {
		"ok": true,
		"path": "near_boss",
		"boss": boss,
		"elapsed_time": float(GameManager.get("elapsed_time"))
	}


func _advance_to_near_death() -> Dictionary:
	var leader: Node = GameManager.get("player") as Node
	if leader == null or not is_instance_valid(leader):
		return _failure("隊長不存在")
	leader.set("invulnerability_timer", 0.0)
	leader.set("temporary_shield_hp", 0.0)
	leader.set("current_hp", 1.0)
	GameManager.emit_stats()
	return {
		"ok": true,
		"path": "near_death",
		"leader": leader,
		"hp": float(leader.get("current_hp"))
	}


func _advance_to_victory() -> Dictionary:
	var boss_result := _advance_to_boss()
	if not bool(boss_result.get("ok", false)):
		return boss_result
	var boss: Node = boss_result.get("boss") as Node
	if boss == null or not is_instance_valid(boss) or not boss.has_method("take_damage"):
		return _failure("Boss 不可受傷")
	var leader: Node2D = GameManager.get("player") as Node2D
	var impact_origin := leader.global_position if leader != null and is_instance_valid(leader) else Vector2.ZERO
	var lethal_damage := float(boss.get("max_hp")) + 1.0
	var applied_damage := float(boss.call("take_damage", lethal_damage, impact_origin))
	if applied_damage <= 0.0:
		return _failure("Boss 致命 impact 未套用傷害")
	return {
		"ok": true,
		"path": "victory",
		"boss": boss,
		"applied_damage": applied_damage,
		"death_animation": str(boss.get("current_animation_name"))
	}


func find_active_boss() -> Node:
	if arena == null or not is_instance_valid(arena):
		return null
	for enemy in arena.get_tree().get_nodes_in_group("enemies"):
		if enemy != null and is_instance_valid(enemy) and bool(enemy.get("is_boss")) and bool(enemy.get("is_active")):
			return enemy
	return null


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
