extends Area2D

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")

var owner_player: Node2D = null
var weapon_node: Node = null
var orbit_index: int = 0
var orbit_total: int = 1
var orbit_angle: float = 0.0
var stats: Dictionary = {}
var hit_cooldowns: Dictionary = {}
var is_active: bool = false
var hit_flash_timer: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var sprite: Sprite2D = null
var glow: Sprite2D = null
var trail: Line2D = null


func _ready() -> void:
	_ensure_sprite()
	monitoring = false


func pool_on_acquire() -> void:
	is_active = true
	visible = true
	set_process(true)
	set_physics_process(true)
	monitoring = false
	if not is_in_group("projectiles"):
		add_to_group("projectiles")
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		shape_node.disabled = true


func pool_on_release() -> void:
	is_active = false
	visible = false
	set_process(false)
	set_physics_process(false)
	monitoring = false
	remove_from_group("projectiles")
	owner_player = null
	weapon_node = null
	stats = {}
	hit_cooldowns.clear()
	rotation = 0.0
	if sprite != null:
		sprite.rotation = 0.0
	if glow != null:
		glow.visible = false
	if trail != null:
		trail.visible = false
	hit_flash_timer = 0.0
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		shape_node.disabled = true


func pool_reset(args: Dictionary) -> void:
	setup(args.get("player", null), args.get("weapon", null), args.get("stats", {}), int(args.get("index", 0)), int(args.get("total", 1)))


func setup(player_node: Node2D, source_weapon: Node, effect_stats: Dictionary, index: int, total: int) -> void:
	owner_player = player_node
	weapon_node = source_weapon
	configure_orbit(index, total, effect_stats)


func configure_orbit(index: int, total: int, effect_stats: Dictionary) -> void:
	var index_changed: bool = orbit_index != index or orbit_total != max(1, total)
	orbit_index = index
	orbit_total = max(1, total)
	stats = effect_stats
	if index_changed:
		orbit_angle = TAU * float(orbit_index) / float(orbit_total)
	rotation = orbit_angle + PI * 0.5
	_apply_shape()
	_apply_sprite()


func _physics_process(delta: float) -> void:
	if not is_active:
		return
	if owner_player == null or not is_instance_valid(owner_player):
		is_active = false
		EntityFactory.release_orbit_projectile(self)
		return

	var angular_speed: float = float(stats.get("orbit_angular_speed", 4.0))
	var orbit_radius: float = float(stats.get("orbit_radius", 58.0))
	orbit_angle += angular_speed * delta
	if int(stats.get("evo_shear_halo_level", 0)) > 0:
		orbit_radius += sin(orbit_angle * 2.0 + float(orbit_index)) * 9.0
	global_position = owner_player.global_position + Vector2.RIGHT.rotated(orbit_angle) * orbit_radius
	rotation = orbit_angle + PI * 0.5

	_tick_hit_cooldowns(delta)
	_damage_overlapping_enemies()
	_tick_hit_flash(delta)


func _tick_hit_cooldowns(delta: float) -> void:
	var expired: Array[int] = []
	for instance_id in hit_cooldowns.keys():
		hit_cooldowns[instance_id] = float(hit_cooldowns[instance_id]) - delta
		if float(hit_cooldowns[instance_id]) <= 0.0:
			expired.append(int(instance_id))

	for instance_id in expired:
		hit_cooldowns.erase(instance_id)


func _damage_overlapping_enemies() -> void:
	var max_targets: int = max(1, int(stats.get("pierce", 0)) + 1)
	var damaged_count: int = 0

	var projectile_radius: float = float(stats.get("projectile_radius", 8.0))
	var enemies: Array[Node2D] = EntityFactory.get_enemies_in_radius(global_position, projectile_radius + 24.0)
	for body in enemies:
		if damaged_count >= max_targets:
			return
		if body == null or not is_instance_valid(body) or not body.is_in_group("enemies"):
			continue
		var active_value: Variant = body.get("is_active")
		if active_value != null and not bool(active_value):
			continue
		var enemy_radius: float = float(body.get("radius"))
		var hit_distance: float = projectile_radius + enemy_radius
		if global_position.distance_squared_to(body.global_position) > hit_distance * hit_distance:
			continue

		var hit_key := _hit_key_for(body)
		if hit_cooldowns.has(hit_key):
			continue

		if int(stats.get("orbit_resonance_level", 0)) > 0 and body.has_method("apply_status_effect"):
			body.apply_status_effect("vulnerable", 1.35, 0.2)
		if int(stats.get("evo_shear_halo_level", 0)) > 0 and body.has_method("apply_status_effect"):
			body.apply_status_effect("slow", 0.9, 0.22)

		if body.has_method("take_damage"):
			body.take_damage(float(stats.get("damage", 8.0)) * GameManager.get_outgoing_damage_multiplier(owner_player), global_position)
			hit_cooldowns[hit_key] = float(stats.get("hit_interval", 0.42))
			damaged_count += 1
			hit_flash_timer = 0.09
			if weapon_node != null and is_instance_valid(weapon_node) and weapon_node.has_method("register_orbit_hit"):
				weapon_node.register_orbit_hit()


func _tick_hit_flash(delta: float) -> void:
	if hit_flash_timer > 0.0:
		hit_flash_timer = max(hit_flash_timer - delta, 0.0)
	var color: Color = stats.get("color", Color(0.8, 0.9, 1.0))
	var ratio := hit_flash_timer / 0.09 if hit_flash_timer > 0.0 else 0.0
	var display_color := color
	if ratio > 0.0:
		display_color = color.lerp(Color.WHITE, ratio)
	if sprite != null:
		sprite.modulate = display_color
	if glow != null:
		glow.modulate = Color(display_color.r, display_color.g, display_color.b, 0.34 + ratio * 0.34)


func _hit_key_for(body: Node) -> int:
	if body != null and body.has_method("get_hit_token"):
		return int(body.get_hit_token())
	return int(body.get_instance_id())


func _apply_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return

	var circle := shape_node.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		shape_node.shape = circle
	circle.radius = float(stats.get("projectile_radius", 8.0))


func _ensure_sprite() -> void:
	if sprite != null and is_instance_valid(sprite):
		return
	glow = get_node_or_null("Glow") as Sprite2D
	if glow == null:
		glow = Sprite2D.new()
		glow.name = "Glow"
		add_child(glow)
	glow.texture = ART_RESOURCES.get_radial_glow()
	glow.centered = true
	glow.material = ART_RESOURCES.get_additive_material()
	glow.z_index = -2

	trail = get_node_or_null("Trail") as Line2D
	if trail == null:
		trail = Line2D.new()
		trail.name = "Trail"
		add_child(trail)
	trail.material = ART_RESOURCES.get_additive_material()
	trail.z_index = -3
	trail.width = 5.0

	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	sprite.centered = true


func _apply_sprite() -> void:
	_ensure_sprite()
	var sprite_path: String = str(stats.get("orbit_sprite_path", "res://assets/sprites/proj_blade.png"))
	var texture: Texture2D = SPRITE_LOADER.get_texture(sprite_path)
	if texture == null:
		sprite.visible = false
		return
	sprite.visible = true
	sprite.modulate = stats.get("color", Color(0.8, 0.9, 1.0))
	var projectile_radius: float = float(stats.get("projectile_radius", 8.0))
	SPRITE_LOADER.fit_sprite(sprite, texture, projectile_radius * 4.2, float(stats.get("sprite_scale", 1.0)))
	var color: Color = stats.get("color", Color(0.8, 0.9, 1.0))
	if glow != null:
		glow.visible = true
		glow.modulate = Color(color.r, color.g, color.b, 0.34)
		ART_RESOURCES.fit_sprite(glow, ART_RESOURCES.get_radial_glow(), projectile_radius * 8.8)
	if trail != null:
		trail.visible = true
		trail.width = clamp(projectile_radius * 1.45, 4.0, 12.0)
		trail.default_color = Color(color.r, color.g, color.b, 0.48)
		var length := projectile_radius * 7.2
		trail.points = PackedVector2Array([Vector2(-length, 0.0), Vector2(-length * 0.32, 0.0), Vector2.ZERO])
