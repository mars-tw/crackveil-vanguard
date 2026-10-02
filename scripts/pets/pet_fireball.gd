extends Node2D

const FX := preload("res://scripts/vfx/newskill_fx_catalog.gd")
var active := false
var sprite: AnimatedSprite2D
var target_ref: WeakRef
var source_ref: WeakRef
var target_token := -1
var destination := Vector2.ZERO
var damage := 0.0
var age := 0.0
var uses := 0


func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FX.get_frames("monster_fire")
	sprite.scale = Vector2.ONE * 0.18
	add_child(sprite)
	_deactivate()


func activate(origin: Vector2, target: Node2D, amount: float, companion: Node) -> void:
	global_position = origin
	target_ref = weakref(target)
	source_ref = weakref(companion)
	target_token = int(target.get("spawn_token"))
	destination = target.global_position
	damage = amount
	age = 0.0
	uses += 1
	active = true
	visible = true
	sprite.play(&"default")
	sprite.set_frame_and_progress(0, 0.0)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not GameManager.game_running:
		_deactivate()
		return
	age += delta
	var target: Node = target_ref.get_ref() as Node if target_ref != null else null
	if is_instance_valid(target) and bool(target.get("is_active")) and int(target.get("spawn_token")) == target_token:
		destination = target.global_position
	global_position = global_position.move_toward(destination, 380.0 * delta)
	rotation = (destination-global_position).angle()
	if global_position.distance_squared_to(destination) <= 10.0 * 10.0 or age >= 2.0:
		var source_actor: Node = source_ref.get_ref() as Node if source_ref != null else null
		for enemy in EntityFactory.get_enemies_in_radius(global_position, 98.0):
			if not is_instance_valid(enemy) or not bool(enemy.get("is_active")):
				continue
			if global_position.distance_to(enemy.global_position) <= 72.0 + float(enemy.get("radius")):
				var actual := float(enemy.call("take_damage", damage, global_position))
				if is_instance_valid(source_actor):
					source_actor.call("report_fire_damage", actual)
					GameManager.record_weapon_damage(source_actor, "pet_fire_fox", actual)
		var presentation := get_tree().get_first_node_in_group("combat_presentation")
		if presentation != null:
			presentation.call("play_effect", "monster_fire", global_position, Vector2.UP, 0.64)
		_deactivate()


func _deactivate() -> void:
	active = false
	visible = false
	set_physics_process(false)
	if sprite != null:
		sprite.stop()
	target_ref = null
	source_ref = null
