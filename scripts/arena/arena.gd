extends Node2D

const FIRST_RUN_GUIDE_SCRIPT := preload("res://scripts/ui/first_run_guide.gd")
const RUN_THEME := preload("res://scripts/arena/run_theme.gd")
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")

@export var run_seed: int = 0

@onready var squad_manager: Node = $SquadManager
@onready var level_up_screen: CanvasLayer = $LevelUpScreen
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var rift_shop_screen: CanvasLayer = $RiftShopScreen
@onready var stage_victory_screen: CanvasLayer = $StageVictoryScreen
@onready var contract_screen: CanvasLayer = $ContractScreen

var first_run_guide: CanvasLayer = null
var mobile_color_grade: CanvasModulate = null
var leader_light: Sprite2D = null


func _ready() -> void:
	_apply_run_seed()
	_apply_mobile_color_grade()
	_apply_background_theme()
	if not get_viewport().size_changed.is_connected(_apply_mobile_color_grade):
		get_viewport().size_changed.connect(_apply_mobile_color_grade)

	var level_up_callable := Callable(level_up_screen, "show_options")
	var game_over_callable := Callable(self, "_on_game_over_requested")
	var shop_callable := Callable(rift_shop_screen, "show_options")
	var stage_victory_callable := Callable(self, "_on_stage_victory_requested")
	var contract_callable := Callable(contract_screen, "show_options")
	var guide_replay_callable := Callable(self, "_on_guide_replay_requested")
	if not GameManager.level_up_requested.is_connected(level_up_callable):
		GameManager.level_up_requested.connect(level_up_callable)
	if not GameManager.game_over_requested.is_connected(game_over_callable):
		GameManager.game_over_requested.connect(game_over_callable)
	if not GameManager.shop_requested.is_connected(shop_callable):
		GameManager.shop_requested.connect(shop_callable)
	if not GameManager.stage_victory_requested.is_connected(stage_victory_callable):
		GameManager.stage_victory_requested.connect(stage_victory_callable)
	if not GameManager.contract_requested.is_connected(contract_callable):
		GameManager.contract_requested.connect(contract_callable)
	if GameManager.has_signal("guide_replay_requested") and not GameManager.guide_replay_requested.is_connected(guide_replay_callable):
		GameManager.guide_replay_requested.connect(guide_replay_callable)

	if level_up_screen.has_signal("upgrade_selected"):
		level_up_screen.upgrade_selected.connect(Callable(GameManager, "apply_upgrade"))
	if game_over_screen.has_signal("restart_requested"):
		game_over_screen.restart_requested.connect(_on_restart_requested)
	if game_over_screen.has_signal("main_menu_requested"):
		game_over_screen.main_menu_requested.connect(_on_main_menu_requested)
	if rift_shop_screen.has_signal("purchase_selected"):
		rift_shop_screen.purchase_selected.connect(Callable(GameManager, "apply_shop_purchase"))
	if stage_victory_screen.has_signal("continue_requested"):
		stage_victory_screen.continue_requested.connect(Callable(GameManager, "continue_after_stage_victory"))
	if stage_victory_screen.has_signal("main_menu_requested"):
		stage_victory_screen.main_menu_requested.connect(_on_main_menu_requested)
	if contract_screen.has_signal("contract_selected"):
		contract_screen.contract_selected.connect(Callable(GameManager, "apply_contract"))
	if contract_screen.has_signal("seed_restart_requested"):
		contract_screen.seed_restart_requested.connect(_on_seed_restart_requested)

	GameManager.arena = self
	EntityFactory.initialize_for_arena(self)
	var leader: Node = null
	if squad_manager != null and squad_manager.has_method("start_squad"):
		leader = squad_manager.start_squad()
	_attach_leader_light(leader as Node2D)
	GameManager.start_run(self, leader, squad_manager, false)
	_attach_first_run_guide()


func _apply_mobile_color_grade() -> void:
	if mobile_color_grade == null:
		mobile_color_grade = CanvasModulate.new()
		mobile_color_grade.name = "MobileBattlefieldGrade"
		add_child(mobile_color_grade)
	var viewport_size := get_viewport().get_visible_rect().size
	var mobile := MOBILE_TUNING.use_mobile_ui(viewport_size)
	# 手機面板通常偏亮、偏豔：微壓亮度與紅色，留下冷青裂隙高光。
	mobile_color_grade.color = MOBILE_TUNING.battlefield_color_modulate(viewport_size, mobile)
	_update_leader_light()


func _attach_leader_light(leader: Node2D) -> void:
	if leader == null or not is_instance_valid(leader):
		return
	leader_light = Sprite2D.new()
	leader_light.name = "SquadSoftLight"
	leader_light.texture = ART_RESOURCES.get_radial_glow()
	leader_light.centered = true
	leader_light.show_behind_parent = true
	leader_light.z_index = -12
	leader_light.material = ART_RESOURCES.get_additive_material()
	leader.add_child(leader_light)
	_update_leader_light()


func _update_leader_light() -> void:
	if leader_light == null or not is_instance_valid(leader_light):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var mobile_lod := MOBILE_TUNING.mobile_lod_enabled(viewport_size)
	var diameter := 390.0 if mobile_lod else 620.0
	ART_RESOURCES.fit_sprite(leader_light, ART_RESOURCES.get_radial_glow(), diameter)
	leader_light.modulate = Color(0.22, 0.72, 1.0, 0.12 if mobile_lod else 0.16)


func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_seed_restart_requested(seed_text: String) -> void:
	GameManager.forced_run_seed = GameManager.seed_from_text(seed_text)
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu_requested() -> void:
	get_tree().paused = false
	GameManager.game_running = false
	GameManager.system_pause_owners.clear()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _on_game_over_requested(summary: Dictionary) -> void:
	_hide_modal_screens([game_over_screen])
	game_over_screen.show_summary(summary)


func _on_stage_victory_requested(summary: Dictionary) -> void:
	_hide_modal_screens([stage_victory_screen])
	stage_victory_screen.show_summary(summary)


func _attach_first_run_guide() -> void:
	if first_run_guide != null and is_instance_valid(first_run_guide):
		return
	first_run_guide = FIRST_RUN_GUIDE_SCRIPT.new()
	first_run_guide.name = "FirstRunGuide"
	add_child(first_run_guide)


func _on_guide_replay_requested() -> void:
	_attach_first_run_guide()
	if first_run_guide != null and first_run_guide.has_method("force_show"):
		first_run_guide.force_show()


func _hide_modal_screens(except_screens: Array = []) -> void:
	for screen in [level_up_screen, game_over_screen, rift_shop_screen, stage_victory_screen, contract_screen]:
		if screen == null or except_screens.has(screen):
			continue
		if screen.has_method("hide_screen"):
			screen.hide_screen()
			continue
		var screen_root: Variant = screen.get("root")
		if screen_root is Control:
			(screen_root as Control).visible = false


func _apply_run_seed() -> void:
	var selected_seed := run_seed
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--run-seed="):
			selected_seed = GameManager.seed_from_text(argument.get_slice("=", 1))
	if selected_seed == 0 and int(GameManager.get("forced_run_seed")) != 0:
		selected_seed = int(GameManager.get("forced_run_seed"))
	if selected_seed == 0:
		randomize()
		selected_seed = max(1, randi())
	seed(selected_seed)
	GameManager.current_run_seed = selected_seed
	var theme_id := RUN_THEME.select_theme_id(selected_seed)
	GameManager.set_current_run_theme(theme_id, RUN_THEME.get_theme_name(theme_id))


func _apply_background_theme() -> void:
	var background := get_node_or_null("Background")
	if background != null and background.has_method("configure_run_theme"):
		background.configure_run_theme(
			GameManager.current_run_seed,
			GameManager.current_run_theme_id
		)
