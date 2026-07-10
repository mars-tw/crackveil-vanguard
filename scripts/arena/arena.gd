extends Node2D

const FIRST_RUN_GUIDE_SCRIPT := preload("res://scripts/ui/first_run_guide.gd")

@export var run_seed: int = 0

@onready var squad_manager: Node = $SquadManager
@onready var level_up_screen: CanvasLayer = $LevelUpScreen
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var rift_shop_screen: CanvasLayer = $RiftShopScreen
@onready var stage_victory_screen: CanvasLayer = $StageVictoryScreen
@onready var contract_screen: CanvasLayer = $ContractScreen

var first_run_guide: CanvasLayer = null


func _ready() -> void:
	_apply_run_seed()

	var level_up_callable := Callable(level_up_screen, "show_options")
	var game_over_callable := Callable(self, "_on_game_over_requested")
	var shop_callable := Callable(rift_shop_screen, "show_options")
	var stage_victory_callable := Callable(self, "_on_stage_victory_requested")
	var contract_callable := Callable(contract_screen, "show_options")
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

	if level_up_screen.has_signal("upgrade_selected"):
		level_up_screen.upgrade_selected.connect(Callable(GameManager, "apply_upgrade"))
	if game_over_screen.has_signal("restart_requested"):
		game_over_screen.restart_requested.connect(_on_restart_requested)
	if rift_shop_screen.has_signal("purchase_selected"):
		rift_shop_screen.purchase_selected.connect(Callable(GameManager, "apply_shop_purchase"))
	if stage_victory_screen.has_signal("continue_requested"):
		stage_victory_screen.continue_requested.connect(Callable(GameManager, "continue_after_stage_victory"))
	if contract_screen.has_signal("contract_selected"):
		contract_screen.contract_selected.connect(Callable(GameManager, "apply_contract"))

	GameManager.arena = self
	EntityFactory.initialize_for_arena(self)
	var leader: Node = null
	if squad_manager != null and squad_manager.has_method("start_squad"):
		leader = squad_manager.start_squad()
	GameManager.start_run(self, leader, squad_manager, false)
	_attach_first_run_guide()


func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


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
			selected_seed = int(argument.get_slice("=", 1))
	if selected_seed == 0 and int(GameManager.get("forced_run_seed")) != 0:
		selected_seed = int(GameManager.get("forced_run_seed"))
	if selected_seed != 0:
		seed(selected_seed)
	else:
		randomize()
	GameManager.current_run_seed = selected_seed
