class_name Enemy
extends CharacterBody2D

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")

@export var type_id: String = "normal"
@export var max_hp: float = 18.0
@export var speed: float = 88.0
@export var damage: float = 8.0
@export var xp_value: int = 2
@export var gold_value: int = 1
@export var radius: float = 13.0
@export var body_color: Color = Color(0.92, 0.28, 0.32)
@export var attack_cooldown: float = 0.75

var hp: float = 18.0
var attack_timer: float = 0.0
var is_active: bool = false
var spawn_token: int = 0
var sprite_path: String = ""
var sprite_scale: float = 1.0
var hp_bar_timer: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var sprite: Sprite2D = null
var hp_bar_bg: Line2D = null
var hp_bar_fg: Line2D = null


func _ready() -> void:
	_ensure_visual_nodes()
	_apply_shape()


func pool_on_acquire() -> void:
	is_active = true
	visible = true
	set_process(true)
	set_physics_process(true)
	if not is_in_group("enemies"):
		add_to_group("enemies")
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		shape_node.disabled = false


func pool_on_release() -> void:
	is_active = false
	visible = false
	set_process(false)
	set_physics_process(false)
	remove_from_group("enemies")
	velocity = Vector2.ZERO
	hp = 0.0
	attack_timer = 0.0
	hp_bar_timer = 0.0
	rotation = 0.0
	if sprite != null:
		sprite.rotation = 0.0
	_set_hp_bar_visible(false)
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		shape_node.disabled = true


func pool_reset(args: Dictionary) -> void:
	global_position = args.get("position", Vector2.ZERO)
	spawn_token = int(args.get("spawn_token", spawn_token + 1))
	setup(str(args.get("enemy_id", "normal")), args.get("config", {}))


func setup(enemy_type: String, config: Dictionary) -> void:
	type_id = enemy_type
	max_hp = float(config.get("max_hp", max_hp))
	hp = max_hp
	speed = float(config.get("speed", speed))
	damage = float(config.get("damage", damage))
	xp_value = int(config.get("xp", xp_value))
	gold_value = int(config.get("gold", gold_value))
	radius = float(config.get("radius", radius))
	body_color = config.get("color", body_color)
	sprite_path = str(config.get("sprite_path", _default_sprite_path_for_type(type_id)))
	sprite_scale = float(config.get("sprite_scale", 1.0))
	attack_cooldown = float(config.get("attack_cooldown", attack_cooldown))
	velocity = Vector2.ZERO
	attack_timer = 0.0
	hp_bar_timer = 0.0
	rotation = 0.0
	_apply_shape()
	_apply_sprite()
	_update_hp_bar()
	_set_hp_bar_visible(false)


func get_hit_token() -> int:
	return spawn_token


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	var target := _find_nearest_hero()
	if target == null or not is_instance_valid(target):
		return

	attack_timer = max(attack_timer - delta, 0.0)

	var to_target: Vector2 = target.global_position - global_position
	var distance_squared: float = to_target.length_squared()
	if distance_squared > 1.0:
		velocity = to_target.normalized() * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if velocity.length_squared() > 1.0 and sprite != null:
		sprite.rotation = velocity.angle()

	var target_hit_radius: float = _get_target_hit_radius(target)
	var attack_distance: float = radius + target_hit_radius + 4.0
	if distance_squared <= attack_distance * attack_distance and attack_timer <= 0.0:
		attack_timer = attack_cooldown
		if target.has_method("take_damage"):
			target.take_damage(damage, global_position)

	if hp_bar_timer > 0.0:
		hp_bar_timer = max(hp_bar_timer - delta, 0.0)
		if hp_bar_timer <= 0.0:
			_set_hp_bar_visible(false)


func _find_nearest_hero() -> Node2D:
	var nearest: Node2D = null
	var best_distance_squared := INF

	var heroes: Array = []
	if GameManager.squad_manager != null and is_instance_valid(GameManager.squad_manager) and GameManager.squad_manager.has_method("get_members"):
		heroes = GameManager.squad_manager.get_members()
	else:
		heroes = get_tree().get_nodes_in_group("heroes")

	for hero in heroes:
		if hero == null or not is_instance_valid(hero):
			continue
		if bool(hero.get("is_alive")) == false:
			continue
		var distance_squared: float = global_position.distance_squared_to(hero.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			nearest = hero

	return nearest


func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO) -> void:
	if hp <= 0.0 or not is_active:
		return

	hp = max(hp - amount, 0.0)
	var number_position := global_position + Vector2(randf_range(-8.0, 8.0), -radius - 10.0)
	EntityFactory.spawn_damage_number(amount, number_position, Color(1.0, 0.96, 0.72))
	hp_bar_timer = 0.55
	_update_hp_bar()
	_set_hp_bar_visible(true)

	if hp <= 0.0:
		_die(source_position)


func _die(_source_position: Vector2 = Vector2.ZERO) -> void:
	if not is_active:
		return
	is_active = false
	GameManager.add_kill()
	EntityFactory.call_deferred("spawn_death_burst", global_position, body_color)

	if xp_value > 0:
		EntityFactory.call_deferred("spawn_xp_gem", global_position, xp_value)
	if gold_value > 0:
		var coin_position := global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		EntityFactory.call_deferred("spawn_gold_coin", coin_position, gold_value)

	EntityFactory.release_enemy_deferred(self)


func _apply_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return

	var circle := shape_node.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		shape_node.shape = circle
	circle.radius = radius


func _get_target_hit_radius(target: Node) -> float:
	if target != null and target.has_method("get_hit_radius"):
		return float(target.get_hit_radius())
	var value: Variant = target.get("hit_radius") if target != null else null
	if value == null:
		return 12.0
	return float(value)


func _ensure_visual_nodes() -> void:
	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	sprite.centered = true
	sprite.z_index = 0

	hp_bar_bg = get_node_or_null("HPBarBG") as Line2D
	if hp_bar_bg == null:
		hp_bar_bg = Line2D.new()
		hp_bar_bg.name = "HPBarBG"
		add_child(hp_bar_bg)
	hp_bar_bg.width = 4.0
	hp_bar_bg.default_color = Color(0.08, 0.04, 0.04, 0.95)
	hp_bar_bg.z_index = 4

	hp_bar_fg = get_node_or_null("HPBarFG") as Line2D
	if hp_bar_fg == null:
		hp_bar_fg = Line2D.new()
		hp_bar_fg.name = "HPBarFG"
		add_child(hp_bar_fg)
	hp_bar_fg.width = 3.0
	hp_bar_fg.default_color = Color(0.9, 0.16, 0.16, 0.96)
	hp_bar_fg.z_index = 5
	_set_hp_bar_visible(false)


func _apply_sprite() -> void:
	_ensure_visual_nodes()
	var texture: Texture2D = SPRITE_LOADER.get_texture(sprite_path)
	if texture == null:
		sprite.visible = false
		return
	sprite.visible = true
	sprite.modulate = body_color
	sprite.rotation = 0.0
	SPRITE_LOADER.fit_sprite(sprite, texture, radius * 3.0, sprite_scale)


func _update_hp_bar() -> void:
	_ensure_visual_nodes()
	var bar_width: float = radius * 2.1
	var y: float = -radius - 11.0
	var ratio: float = clamp(hp / max(1.0, max_hp), 0.0, 1.0)
	hp_bar_bg.points = PackedVector2Array([Vector2(-bar_width * 0.5, y), Vector2(bar_width * 0.5, y)])
	hp_bar_fg.points = PackedVector2Array([Vector2(-bar_width * 0.5, y), Vector2(-bar_width * 0.5 + bar_width * ratio, y)])


func _set_hp_bar_visible(value: bool) -> void:
	if hp_bar_bg != null:
		hp_bar_bg.visible = value
	if hp_bar_fg != null:
		hp_bar_fg.visible = value


func _default_sprite_path_for_type(enemy_type: String) -> String:
	match enemy_type:
		"fast", "stress_fast":
			return "res://assets/sprites/enemy_fast.png"
		"tank", "stress_tank":
			return "res://assets/sprites/enemy_tank.png"
		_:
			return "res://assets/sprites/enemy_grunt.png"
