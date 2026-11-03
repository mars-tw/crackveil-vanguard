extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	await process_frame
	var catalog: GDScript = load("res://scripts/services/special_elite_catalog.gd")
	var garden: Dictionary = catalog.apply_stage_variant(catalog.make_config("charge", 40), "garden")
	var moon: Dictionary = catalog.apply_stage_variant(catalog.make_config("charge", 40), "moon")
	_check(str(garden.get("stage_skill", "")) == "vine_snare" and str(moon.get("stage_skill", "")) == "", "only the garden elites carry the vine snare")
	var snare_script: GDScript = load("res://scripts/vfx/vine_snare.gd")
	_check(snare_script.WARN_SECONDS >= 0.8 and snare_script.ACTIVE_SECONDS > 1.0 and snare_script.RADIUS >= 80.0, "the snare is warned before it roots and covers a squad-sized area")
	var snare: Node2D = snare_script.new()
	get_root().add_child(snare)
	snare.global_position = Vector2(100, 100)
	snare._process(0.5)
	_check(snare.age > 0.0 and snare.hits == 0, "nothing is hit during the warning")
	snare.queue_free()
	var enemy_src := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	_check(enemy_src.contains("if stage_skill == \"vine_snare\" and is_instance_valid(target) and is_inside_tree():\n\t\tVINE_SNARE.spawn(get_parent(), target.global_position)"), "a garden elite roots the ground under its target on every cast")
	var spawner_src := FileAccess.get_file_as_string("res://scripts/enemies/enemy_spawner.gd")
	_check(spawner_src.contains("出招時腳下纏藤，散開站位"), "the elite toast teaches the new rule")
	var number: GDScript = load("res://scripts/vfx/damage_number.gd")
	number.hud_blockers = [Rect2(400, 540, 400, 50)] as Array[Rect2]
	_check(number.lift_above_hud(Rect2(500, 530, 200, 40)) > 40.0 and number.lift_above_hud(Rect2(500, 100, 200, 40)) == 0.0, "an event word over the item row lifts above it")
	number.hud_blockers = [] as Array[Rect2]
	var hud_src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(hud_src.contains("\tblockers.append(Rect2(equipment_panel.position, equipment_panel.size))\n\tDAMAGE_NUMBER.hud_blockers = blockers") and not hud_src.contains("\tif not mobile:\n\t\tblockers.append"), "the item row blocks world text on every layout")
	_check(str(ProjectSettings.get_setting("application/config/version")) == "0.67.0-content-r38", "project version is 0.67.0-content-r38")
	if failures.is_empty():
		print("R29_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R29_REGRESSION status=FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
