extends Node

var hero: Node = null


func _ready() -> void:
	add_to_group("hero_controllers")
	_ensure_input_actions()


func setup(hero_node: Node) -> void:
	hero = hero_node


func _physics_process(_delta: float) -> void:
	if hero == null or not is_instance_valid(hero):
		return

	if Input.is_action_just_pressed("active_ability") and hero.has_method("try_cast_active_ability"):
		hero.try_cast_active_ability()

	var keyboard_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var touch_direction := GameManager.get_touch_move_vector()
	var input_direction: Vector2 = (keyboard_direction + touch_direction).limit_length(1.0)

	if hero.has_method("set_move_direction"):
		hero.set_move_direction(input_direction)


func _ensure_input_actions() -> void:
	_add_action_with_keys("move_left", [KEY_A, KEY_LEFT])
	_add_action_with_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_action_with_keys("move_up", [KEY_W, KEY_UP])
	_add_action_with_keys("move_down", [KEY_S, KEY_DOWN])
	_add_action_with_keys("active_ability", [KEY_SPACE])


func _add_action_with_keys(action_name: String, keys: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for key in keys:
		var exists := false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey and event.physical_keycode == key:
				exists = true
				break
		if exists:
			continue
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action_name, event)
