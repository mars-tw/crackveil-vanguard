class_name Hero
extends CharacterBody2D

@export var weapon_catalog: Resource = preload("res://resources/weapons/weapon_catalog.tres")
@export var invulnerability_time: float = 0.65

var hero_data: Resource = null
var squad_manager: Node = null
var is_leader: bool = false
var formation_index: int = 0
var hero_id: String = ""
var display_name: String = "未命名英雄"
var max_hp: float = 100.0
var current_hp: float = 100.0
var temporary_shield_hp: float = 0.0
var temporary_shield_timer: float = 0.0
var move_speed: float = 220.0
var pickup_radius: float = 80.0
var hit_radius: float = 13.0
var invulnerability_timer: float = 0.0
var last_move_direction: Vector2 = Vector2.RIGHT
var desired_velocity: Vector2 = Vector2.ZERO
var movement_slow_timer: float = 0.0
var movement_slow_strength: float = 0.0
var weapons: Dictionary = {}
var weapon_order: Array[String] = []
var is_alive: bool = true
var facing_refresh_timer: float = 0.0
var cached_facing_enemy: Node2D = null
var cached_facing_token: int = 0
var screen_shake_timer: float = 0.0
var screen_shake_duration: float = 0.0
var screen_shake_strength: float = 0.0

@onready var visual: Node2D = $Visual
@onready var weapons_root: Node2D = $Weapons
@onready var camera: Camera2D = $Camera2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("heroes")


func setup(new_hero_data: Resource, new_squad_manager: Node, leader_flag: bool, slot_index: int) -> void:
	hero_data = new_hero_data.duplicate(true) if new_hero_data != null else null
	squad_manager = new_squad_manager
	is_leader = leader_flag
	formation_index = slot_index
	_apply_hero_data()
	reset_for_run()
	_configure_controller()


func _apply_hero_data() -> void:
	if hero_data == null:
		return

	hero_id = str(hero_data.get("id"))
	display_name = str(hero_data.get("display_name"))
	max_hp = float(hero_data.get("max_hp"))
	move_speed = float(hero_data.get("move_speed"))
	pickup_radius = float(hero_data.get("pickup_radius"))
	hit_radius = float(hero_data.get("hit_radius"))
	name = hero_id

	if visual != null:
		if visual.has_method("configure_visual"):
			visual.configure_visual(str(hero_data.get("sprite_path")), float(hero_data.get("sprite_scale")), hit_radius + 2.0)
		else:
			visual.set("body_color", hero_data.get("body_color"))
			visual.set("core_color", hero_data.get("core_color"))

	var shape_node := collision_shape
	if shape_node != null:
		var circle := CircleShape2D.new()
		circle.radius = hit_radius
		shape_node.shape = circle

	if camera != null:
		camera.enabled = is_leader
		if is_leader:
			camera.make_current()


func reset_for_run() -> void:
	current_hp = max_hp
	temporary_shield_hp = 0.0
	temporary_shield_timer = 0.0
	invulnerability_timer = 0.0
	last_move_direction = Vector2.RIGHT
	desired_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	screen_shake_timer = 0.0
	screen_shake_duration = 0.0
	screen_shake_strength = 0.0
	movement_slow_timer = 0.0
	movement_slow_strength = 0.0
	is_alive = true
	if not is_in_group("heroes"):
		add_to_group("heroes")
	if is_leader and not is_in_group("players"):
		add_to_group("players")
	if visual != null:
		visual.visible = true
		visual.modulate = Color.WHITE
	if camera != null:
		camera.offset = Vector2.ZERO
	_clear_weapons()
	_equip_starting_weapons()
	set_physics_process(true)
	set_process(true)


func _clear_weapons() -> void:
	weapons.clear()
	weapon_order.clear()
	if weapons_root == null:
		return

	for child in weapons_root.get_children():
		child.set_process(false)
		child.set_physics_process(false)
		if child.has_method("release_owned_nodes"):
			child.release_owned_nodes()
		child.free()


func _equip_starting_weapons() -> void:
	if hero_data == null:
		return

	var starting_weapon_ids: PackedStringArray = hero_data.get("starting_weapon_ids")
	for weapon_id in starting_weapon_ids:
		unlock_weapon(str(weapon_id))


func _configure_controller() -> void:
	for child in get_children():
		if child.is_in_group("hero_controllers"):
			child.queue_free()

	if is_leader:
		var controller := preload("res://scripts/heroes/player_controller.gd").new()
		controller.name = "PlayerController"
		add_child(controller)
		controller.setup(self)
	else:
		var follower := preload("res://scripts/heroes/follower_controller.gd").new()
		follower.name = "FollowerController"
		add_child(follower)
		follower.setup(self, squad_manager, formation_index)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if desired_velocity.length_squared() > 1.0:
		last_move_direction = desired_velocity.normalized()

	_tick_movement_slow(delta)
	velocity = desired_velocity.limit_length(move_speed * 1.35) * _movement_multiplier()
	move_and_slide()
	_update_facing(delta)

	if invulnerability_timer > 0.0:
		invulnerability_timer = max(invulnerability_timer - delta, 0.0)
	if temporary_shield_timer > 0.0:
		temporary_shield_timer = max(temporary_shield_timer - delta, 0.0)
		if temporary_shield_timer <= 0.0:
			temporary_shield_hp = 0.0


func _process(delta: float) -> void:
	_update_flash()
	_update_camera_shake(delta)


func set_move_direction(direction: Vector2) -> void:
	desired_velocity = direction.normalized() * move_speed


func set_desired_velocity(new_velocity: Vector2) -> void:
	desired_velocity = new_velocity


func apply_movement_slow(duration: float, strength: float) -> void:
	if not is_alive:
		return
	movement_slow_timer = max(movement_slow_timer, duration)
	movement_slow_strength = max(movement_slow_strength, clamp(strength, 0.0, 0.65))


func _tick_movement_slow(delta: float) -> void:
	if movement_slow_timer <= 0.0:
		movement_slow_strength = 0.0
		return
	movement_slow_timer = max(movement_slow_timer - delta, 0.0)
	if movement_slow_timer <= 0.0:
		movement_slow_strength = 0.0


func _movement_multiplier() -> float:
	return 1.0 - clamp(movement_slow_strength, 0.0, 0.65)


func get_facing_direction() -> Vector2:
	if last_move_direction == Vector2.ZERO:
		return Vector2.RIGHT
	return last_move_direction.normalized()


func _update_facing(delta: float) -> void:
	var facing_direction := get_facing_direction()
	facing_refresh_timer -= delta
	if not _is_cached_facing_enemy_valid():
		cached_facing_enemy = null
		cached_facing_token = 0
	if facing_refresh_timer <= 0.0:
		cached_facing_enemy = get_nearest_enemy(620.0)
		cached_facing_token = _hit_key_for(cached_facing_enemy)
		facing_refresh_timer = 0.1
	if _is_cached_facing_enemy_valid():
		facing_direction = (cached_facing_enemy.global_position - global_position).normalized()

	if facing_direction != Vector2.ZERO and visual != null:
		visual.rotation = facing_direction.angle()


func _is_cached_facing_enemy_valid() -> bool:
	if cached_facing_enemy == null or not is_instance_valid(cached_facing_enemy):
		return false
	var active_value: Variant = cached_facing_enemy.get("is_active")
	if active_value != null and not bool(active_value):
		return false
	if cached_facing_enemy.has_method("get_hit_token") and int(cached_facing_enemy.get_hit_token()) != cached_facing_token:
		return false
	return true


func _hit_key_for(body: Node) -> int:
	if body == null or not is_instance_valid(body):
		return 0
	if body.has_method("get_hit_token"):
		return int(body.get_hit_token())
	return int(body.get_instance_id())


func _update_flash() -> void:
	if visual == null:
		return

	if invulnerability_timer > 0.0:
		var flash_on := int(invulnerability_timer * 22.0) % 2 == 0
		visual.modulate = Color(1.0, 0.35, 0.32, 0.55) if flash_on else Color.WHITE
	else:
		visual.modulate = Color.WHITE


func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO) -> bool:
	if invulnerability_timer > 0.0 or current_hp <= 0.0 or not is_alive:
		return false

	var final_incoming := amount * (GameManager.get_incoming_damage_multiplier() if GameManager.has_method("get_incoming_damage_multiplier") else 1.0)
	var remaining_damage := final_incoming
	if temporary_shield_hp > 0.0:
		var absorbed: float = min(temporary_shield_hp, remaining_damage)
		temporary_shield_hp -= absorbed
		remaining_damage -= absorbed
	current_hp = max(current_hp - remaining_damage, 0.0)
	invulnerability_timer = invulnerability_time

	var number_position := global_position + Vector2(0.0, -30.0)
	if source_position != Vector2.ZERO:
		number_position += (global_position - source_position).normalized() * 8.0
	EntityFactory.spawn_damage_number(final_incoming, number_position, Color(1.0, 0.28, 0.22))

	GameManager.emit_stats()
	if current_hp <= 0.0:
		_die()
	return true


func request_screen_shake(strength: float, duration: float) -> void:
	if not is_leader or camera == null:
		return
	if PlayerSettings != null and not bool(PlayerSettings.get("screen_shake_enabled")):
		return
	screen_shake_strength = max(screen_shake_strength, strength)
	screen_shake_duration = max(screen_shake_duration, duration)
	screen_shake_timer = max(screen_shake_timer, duration)


func _update_camera_shake(delta: float) -> void:
	if camera == null or not is_leader:
		return
	if screen_shake_timer <= 0.0:
		camera.offset = Vector2.ZERO
		return
	screen_shake_timer = max(screen_shake_timer - delta, 0.0)
	var ratio: float = screen_shake_timer / max(0.001, screen_shake_duration)
	var amount: float = screen_shake_strength * ratio * ratio
	camera.offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
	if screen_shake_timer <= 0.0:
		camera.offset = Vector2.ZERO


func heal(amount: float) -> bool:
	if not is_alive or amount <= 0.0:
		return false
	var before := current_hp
	current_hp = min(max_hp, current_hp + amount)
	GameManager.emit_stats()
	return current_hp > before


func add_temporary_shield(amount: float, duration: float) -> void:
	if not is_alive:
		return
	temporary_shield_hp = max(temporary_shield_hp, amount)
	temporary_shield_timer = max(temporary_shield_timer, duration)


func _die() -> void:
	is_alive = false
	remove_from_group("heroes")
	if is_leader:
		set_process(false)
		set_physics_process(false)
		if camera != null:
			camera.enabled = false
		GameManager.player_died()
	else:
		EntityFactory.call_deferred("spawn_death_burst", global_position, Color(0.7, 0.82, 1.0))
		if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("member_died"):
			squad_manager.member_died(self)
		queue_free()


func build_upgrade_pool(base_pool: Array) -> Array:
	if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("build_upgrade_pool"):
		return squad_manager.build_upgrade_pool(base_pool)
	return base_pool


func apply_upgrade(upgrade: Dictionary) -> void:
	if squad_manager != null and is_instance_valid(squad_manager) and squad_manager.has_method("apply_upgrade"):
		squad_manager.apply_upgrade(upgrade)
	else:
		apply_personal_upgrade(upgrade)


func apply_personal_upgrade(upgrade: Dictionary) -> void:
	var upgrade_id: String = upgrade.get("id", "")

	match upgrade_id:
		"move_speed":
			move_speed += 20.0
		"max_hp":
			max_hp += 20.0
			current_hp = min(current_hp + 20.0, max_hp)
		"pickup_radius":
			pickup_radius += 24.0

	GameManager.emit_stats()


func unlock_weapon(weapon_id: String) -> bool:
	if weapon_id == "" or weapons.has(weapon_id) or weapon_catalog == null:
		return false

	var source_data: Resource = weapon_catalog.get_weapon_data(weapon_id)
	if source_data == null:
		return false

	var weapon_scene: PackedScene = source_data.get("weapon_scene")
	if weapon_scene == null:
		return false

	var weapon_node: Node = weapon_scene.instantiate()
	weapons_root.add_child(weapon_node)
	if weapon_node.has_method("setup"):
		weapon_node.setup(self, source_data)

	weapons[weapon_id] = weapon_node
	weapon_order.append(weapon_id)
	return true


func upgrade_weapon(weapon_id: String, upgrade_kind: String) -> bool:
	var weapon: Node = weapons.get(weapon_id)
	if weapon == null or not is_instance_valid(weapon):
		return false

	if weapon.has_method("apply_data_upgrade"):
		return bool(weapon.apply_data_upgrade(upgrade_kind))
	return false


func get_weapon_trigger_counts() -> Dictionary:
	var counts: Dictionary = {}
	for weapon_id in weapon_order:
		var weapon: Node = weapons.get(weapon_id)
		if weapon != null and is_instance_valid(weapon):
			counts[weapon_id] = int(weapon.get("trigger_count"))
	return counts


func get_nearest_enemy(max_range: float = 1000000.0) -> Node2D:
	return EntityFactory.find_nearest_enemy(global_position, max_range)


func get_current_hp() -> float:
	return current_hp


func get_max_hp() -> float:
	return max_hp


func get_pickup_radius() -> float:
	return pickup_radius


func get_hit_radius() -> float:
	return hit_radius
