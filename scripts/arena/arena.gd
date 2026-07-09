extends Node2D

@onready var squad_manager: Node = $SquadManager
@onready var level_up_screen: CanvasLayer = $LevelUpScreen
@onready var game_over_screen: CanvasLayer = $GameOverScreen


func _ready() -> void:
	randomize()

	var level_up_callable := Callable(level_up_screen, "show_options")
	var game_over_callable := Callable(game_over_screen, "show_summary")
	if not GameManager.level_up_requested.is_connected(level_up_callable):
		GameManager.level_up_requested.connect(level_up_callable)
	if not GameManager.game_over_requested.is_connected(game_over_callable):
		GameManager.game_over_requested.connect(game_over_callable)

	if level_up_screen.has_signal("upgrade_selected"):
		level_up_screen.upgrade_selected.connect(Callable(GameManager, "apply_upgrade"))
	if game_over_screen.has_signal("restart_requested"):
		game_over_screen.restart_requested.connect(_on_restart_requested)

	GameManager.arena = self
	EntityFactory.initialize_for_arena(self)
	var leader: Node = null
	if squad_manager != null and squad_manager.has_method("start_squad"):
		leader = squad_manager.start_squad()
	GameManager.start_run(self, leader, squad_manager, false)


func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
