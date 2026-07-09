extends Node

@export var arrival_distance: float = 8.0
@export var catchup_distance: float = 120.0

var hero: Node2D = null
var squad_manager: Node = null
var formation_index: int = 1


func _ready() -> void:
	add_to_group("hero_controllers")


func setup(hero_node: Node2D, manager: Node, slot_index: int) -> void:
	hero = hero_node
	squad_manager = manager
	formation_index = slot_index


func _physics_process(_delta: float) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	if squad_manager == null or not is_instance_valid(squad_manager):
		return
	if not squad_manager.has_method("get_formation_world_position"):
		return

	var target_position: Vector2 = squad_manager.get_formation_world_position(formation_index)
	var to_target: Vector2 = target_position - hero.global_position
	var distance: float = to_target.length()

	if distance <= arrival_distance:
		hero.set_desired_velocity(Vector2.ZERO)
		return

	var max_speed: float = float(hero.get("move_speed")) * (1.0 + clamp(distance / catchup_distance, 0.0, 0.35))
	hero.set_desired_velocity(to_target.normalized() * max_speed)
