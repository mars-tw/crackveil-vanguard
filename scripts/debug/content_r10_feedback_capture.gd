extends SceneTree

# Controlled native fixture: loads the real battle scene and triggers each
# feedback through the existing take_damage paths. Not a natural battle.
const PROVENANCE := "controlled native fixture via real take_damage; not a natural battle"
var out_dir := ""
var saved := 0
var failed := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	if out_dir == "":
		for arg in OS.get_cmdline_args():
			if arg.begins_with("--out="):
				out_dir = arg.trim_prefix("--out=")
	if out_dir == "":
		printerr("R10_CAPTURE missing --out=<folder>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var arena: Node = load("res://scenes/arena/Arena.tscn").instantiate()
	root.add_child(arena)
	for i in range(30):
		await process_frame
	var gm: Node = root.get_node("GameManager")
	var factory: Node = root.get_node("EntityFactory")
	if not gm.game_running or gm.player == null:
		printerr("R10_CAPTURE battle did not start")
		quit(1)
		return
	var spawner: Node = arena.get_node_or_null("EnemySpawner")
	if spawner != null:
		spawner.set_process(false)
	var captain: Node2D = gm.player
	# 1) Normal enemy hit flash, through the real enemy damage path.
	var spawner_script: GDScript = load("res://scripts/enemies/enemy_spawner.gd")
	var normal_config: Dictionary = spawner_script.ENEMY_CONFIGS.get("normal", {}).duplicate(true)
	normal_config["max_hp"] = 240.0
	var enemy: Node = factory.spawn_enemy("normal", normal_config, captain.global_position + Vector2(-290, -130))
	if enemy == null:
		failed = true
	else:
		enemy.take_damage(6.0, captain.global_position)
		pass # flash state is verified in content_r10_test
		await process_frame
		pass
		_save_shot("feedback-hit-flash", "enemy.take_damage(6) on a normal enemy next to the captain; captured in the flash frames")
	# 2) Elite armour break: repeated real hits bring the guard under half HP.
	var elite: Node = spawner.spawn_tactical_guard("shield") if spawner != null else null
	if elite == null:
		failed = true
	else:
		elite.global_position = captain.global_position + Vector2(-170, 10)
		for hit in range(10):
			if elite.hp <= elite.max_hp * 0.5:
				break
			elite.take_damage(elite.max_hp * 0.2, captain.global_position)
		await process_frame
		_save_shot("feedback-elite-break", "elite.take_damage repeated until hp <= 50 percent, spawning the real armour-break announcement")
	# 3) Captain hurt direction arrow, through the real hero damage path.
	captain.take_damage(4.0, captain.global_position + Vector2(-90, 0))
	await process_frame
	_save_shot("feedback-hurt-arrow", "captain hero.take_damage(4) from the left; HUD captain_hurt_requested shows the direction arrow")
	# 4) Low HP red frame: one large real hit leaves the captain under 30 percent.
	for wait_frame in range(45):
		await process_frame
	var needed: float = captain.current_hp - captain.max_hp * 0.24
	if needed > 0.0:
		captain.take_damage(needed, captain.global_position + Vector2(90, 0))
	await process_frame
	_save_shot("feedback-low-hp", "captain hero.take_damage until hp ratio is under 30 percent; HUD low-hp edges show")
	print("R10_CAPTURE saved=%d failed=%s" % [saved, str(failed)])
	quit(0 if saved == 4 and not failed else 1)

func _save_shot(shot_name: String, trigger: String) -> void:
	var image := root.get_texture().get_image()
	var png_path := out_dir.path_join(shot_name + ".png")
	var error := image.save_png(png_path)
	if error != OK or not FileAccess.file_exists(png_path) or image.get_width() < 64:
		printerr("R10_CAPTURE failed to save " + png_path)
		failed = true
		return
	saved += 1
	var meta := {
		"shot": shot_name,
		"trigger": trigger,
		"time": Time.get_datetime_string_from_system(),
		"version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"provenance": PROVENANCE,
	}
	var file := FileAccess.open(out_dir.path_join(shot_name + ".json"), FileAccess.WRITE)
	if file == null:
		failed = true
		return
	file.store_string(JSON.stringify(meta, "\t"))
	file.close()
