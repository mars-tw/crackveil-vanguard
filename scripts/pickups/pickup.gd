extends Area2D

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")

@export var value: int = 1
@export_enum("xp", "coin") var pickup_kind: String = "xp"
@export var collect_distance: float = 14.0
@export var magnet_speed: float = 280.0
@export_file("*.png") var sprite_path: String = ""
@export var sprite_scale: float = 1.0

var drift_velocity: Vector2 = Vector2.ZERO
var magnetized: bool = false
var forced_collector: Node2D = null
var forced_magnet_timer: float = 0.0
var bob_phase: float = 0.0
var scatter_timer: float = 0.0
var arc_height: float = 0.0
var arc_velocity: float = 0.0
var magnet_time: float = 0.0
var is_active: bool = false
var sprite: Sprite2D = null
var shadow: Sprite2D = null
var glow: Sprite2D = null

static var pickup_streak_count: int = 0
static var pickup_streak_last_msec: int = -1000000


func _ready() -> void:
	if sprite_path == "":
		sprite_path = "res://assets/sprites/coin.png" if pickup_kind == "coin" else "res://assets/sprites/gem_xp.png"
	_ensure_sprite()
	_apply_sprite()


func pool_on_acquire() -> void:
	is_active = true
	visible = true
	set_process(true)
	set_physics_process(true)
	if not is_in_group("pickups"):
		add_to_group("pickups")


func pool_on_release() -> void:
	is_active = false
	visible = false
	set_process(false)
	set_physics_process(false)
	remove_from_group("pickups")
	value = 0
	drift_velocity = Vector2.ZERO
	magnetized = false
	forced_collector = null
	forced_magnet_timer = 0.0
	bob_phase = 0.0
	scatter_timer = 0.0
	arc_height = 0.0
	arc_velocity = 0.0
	magnet_time = 0.0
	rotation = 0.0
	if sprite != null:
		sprite.rotation = 0.0
	if shadow != null:
		shadow.visible = false
	if glow != null:
		glow.visible = false


func pool_reset(args: Dictionary) -> void:
	global_position = args.get("position", Vector2.ZERO)
	setup(int(args.get("amount", 1)), args.get("velocity", Vector2.ZERO), float(args.get("scatter_time", 0.24)))


func setup(amount: int, start_velocity: Vector2 = Vector2.ZERO, start_scatter_time: float = 0.24) -> void:
	value = amount
	drift_velocity = start_velocity
	magnetized = false
	forced_collector = null
	forced_magnet_timer = 0.0
	scatter_timer = max(0.0, start_scatter_time)
	arc_height = 0.0
	arc_velocity = randf_range(126.0, 190.0)
	magnet_time = 0.0
	rotation = 0.0
	_apply_sprite()


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	bob_phase += delta * 5.0

	var moved := false
	if drift_velocity.length_squared() > 1.0:
		global_position += drift_velocity * delta
		drift_velocity = drift_velocity.move_toward(Vector2.ZERO, 265.0 * delta)
		moved = true

	if scatter_timer > 0.0:
		scatter_timer = max(scatter_timer - delta, 0.0)
		arc_height = max(0.0, arc_height + arc_velocity * delta)
		arc_velocity -= 520.0 * delta
		if scatter_timer > 0.0:
			_update_sprite_bob()
			return
	elif arc_height > 0.0:
		arc_height = max(0.0, move_toward(arc_height, 0.0, 420.0 * delta))
		moved = true

	if forced_magnet_timer > 0.0:
		forced_magnet_timer = max(forced_magnet_timer - delta, 0.0)
		if forced_magnet_timer <= 0.0:
			forced_collector = null

	var collector := forced_collector if _is_forced_collector_valid() else _find_collector()
	if collector == null:
		if moved or magnetized:
			_update_sprite_bob()
		return

	var pickup_radius: float = 90.0
	if collector.has_method("get_pickup_radius"):
		pickup_radius = float(collector.get_pickup_radius())

	var to_collector: Vector2 = collector.global_position - global_position
	var distance := to_collector.length()
	if forced_collector != null or distance <= pickup_radius:
		magnetized = true

	if magnetized and distance > 0.001:
		magnet_time += delta
		arc_height = max(0.0, move_toward(arc_height, 0.0, 420.0 * delta))
		var acceleration: float = 1.0 + clamp(magnet_time * 2.8, 0.0, 2.4)
		var pull_speed: float = (magnet_speed * 1.25 + max(0.0, pickup_radius - distance) * 4.2) * acceleration
		var pull_step: float = min(distance, pull_speed * delta)
		global_position += to_collector.normalized() * pull_step
		moved = true

	if global_position.distance_squared_to(collector.global_position) <= collect_distance * collect_distance:
		collect(collector)

	if moved or magnetized:
		_update_sprite_bob()


func collect(_player: Node) -> void:
	match pickup_kind:
		"coin":
			GameManager.add_gold(value)
			_play_pickup_sfx()
			EntityFactory.release_gold_coin(self)
		_:
			GameManager.add_xp(value)
			_play_pickup_sfx()
			EntityFactory.release_xp_gem(self)


func force_magnet_to(collector: Node2D) -> void:
	if pickup_kind != "xp" or collector == null or not is_instance_valid(collector):
		return
	forced_collector = collector
	forced_magnet_timer = 1.45
	magnetized = true
	scatter_timer = 0.0
	drift_velocity = Vector2.ZERO
	arc_velocity = 0.0


func add_value(amount: int) -> void:
	value += amount
	_apply_sprite()


func _is_forced_collector_valid() -> bool:
	if forced_collector == null or not is_instance_valid(forced_collector):
		return false
	var collector_alive: Variant = forced_collector.get("is_alive")
	if collector_alive != null and bool(collector_alive) == false:
		return false
	return forced_magnet_timer > 0.0


func _find_collector() -> Node2D:
	var nearest: Node2D = null
	var best_distance_squared := INF
	var members: Array = []
	if GameManager.squad_manager != null and is_instance_valid(GameManager.squad_manager) and GameManager.squad_manager.has_method("get_members"):
		members = GameManager.squad_manager.get_members()
	elif GameManager.player != null and is_instance_valid(GameManager.player):
		members = [GameManager.player]

	for member in members:
		if member == null or not is_instance_valid(member):
			continue
		var member_alive: Variant = member.get("is_alive")
		if member_alive != null and bool(member_alive) == false:
			continue
		var pickup_radius: float = 90.0
		if member.has_method("get_pickup_radius"):
			pickup_radius = float(member.get_pickup_radius())
		var distance_squared: float = global_position.distance_squared_to(member.global_position)
		if distance_squared <= pickup_radius * pickup_radius and distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			nearest = member

	return nearest


func _ensure_sprite() -> void:
	if sprite != null and is_instance_valid(sprite):
		return
	shadow = get_node_or_null("Shadow") as Sprite2D
	if shadow == null:
		shadow = Sprite2D.new()
		shadow.name = "Shadow"
		add_child(shadow)
	shadow.texture = ART_RESOURCES.get_ellipse_shadow()
	shadow.centered = true
	shadow.z_index = -3
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.46)

	glow = get_node_or_null("Glow") as Sprite2D
	if glow == null:
		glow = Sprite2D.new()
		glow.name = "Glow"
		add_child(glow)
	glow.texture = ART_RESOURCES.get_radial_glow()
	glow.centered = true
	glow.material = ART_RESOURCES.get_additive_material()
	glow.z_index = -2

	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	sprite.centered = true


func _apply_sprite() -> void:
	_ensure_sprite()
	var texture: Texture2D = SPRITE_LOADER.get_texture(sprite_path)
	if texture == null:
		sprite.visible = false
		return
	sprite.visible = true
	var target_size: float = 20.0 + clamp(float(value) * 0.8, 0.0, 8.0)
	SPRITE_LOADER.fit_sprite(sprite, texture, target_size, sprite_scale)
	if shadow != null:
		shadow.visible = true
		shadow.position = Vector2(0.0, target_size * 0.34)
		ART_RESOURCES.fit_sprite(shadow, ART_RESOURCES.get_ellipse_shadow(), target_size * 1.45)
	if glow != null:
		glow.visible = true
		var glow_color := Color(0.34, 0.94, 1.0, 0.34)
		if pickup_kind == "coin":
			glow_color = Color(1.0, 0.64, 0.22, 0.34)
		glow.modulate = glow_color
		ART_RESOURCES.fit_sprite(glow, ART_RESOURCES.get_radial_glow(), target_size * 2.55)
	_update_sprite_bob()


func _update_sprite_bob() -> void:
	if sprite == null:
		return
	var bob := sin(bob_phase) * 1.5
	sprite.position.y = bob - arc_height
	if glow != null:
		glow.position.y = bob * 0.55 - arc_height * 0.52


func _play_pickup_sfx() -> void:
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		var pitch := _next_pickup_pitch() if pickup_kind == "xp" else 0.96
		AudioManager.play_sfx("pickup", false, 0.0, pitch)


func _next_pickup_pitch() -> float:
	var now := Time.get_ticks_msec()
	if now - pickup_streak_last_msec <= 520:
		pickup_streak_count += 1
	else:
		pickup_streak_count = 1
	pickup_streak_last_msec = now
	return clamp(0.94 + float(min(pickup_streak_count - 1, 12)) * 0.045, 0.86, 1.48)
