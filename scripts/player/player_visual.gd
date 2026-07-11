extends Node2D

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")
const STEP_INTERVAL := 0.25
const STEP_DUST_POOL_SIZE := 8

@export var body_radius: float = 15.0
@export var body_color: Color = Color(0.35, 0.78, 1.0)
@export var core_color: Color = Color(0.88, 0.98, 1.0)
@export_file("*.png") var sprite_path: String = ""
@export var sprite_scale: float = 1.0

var sprite: Sprite2D = null
var animated_sprite: AnimatedSprite2D = null
var shadow: Sprite2D = null
var aura: Sprite2D = null
var facing_direction: Vector2 = Vector2.RIGHT
var walk_phase: float = 0.0
var idle_phase: float = 0.0
var step_timer: float = 0.0
var step_index: int = 0
var hit_squash_timer: float = 0.0
var turn_squash_timer: float = 0.0
var last_facing_sign: int = 1
var sprite_base_scale: Vector2 = Vector2.ONE
var animated_sprite_base_scale: Vector2 = Vector2.ONE
var shadow_base_scale: Vector2 = Vector2.ONE
var aura_base_scale: Vector2 = Vector2.ONE
var step_dust_pool: Array[CPUParticles2D] = []
var next_step_dust_index: int = 0
var step_dust_emit_count: int = 0
var footstep_tick_count: int = 0
var animation_frames_ready: bool = false
var current_animation_name: String = ""


func _ready() -> void:
	_ensure_sprite()
	_ensure_step_dust_pool()
	_apply_sprite()
	set_process(true)


func _process(delta: float) -> void:
	if shadow != null:
		shadow.global_rotation = 0.0
	_update_procedural_motion(delta)


func configure_visual(new_sprite_path: String, new_scale: float, new_radius: float) -> void:
	sprite_path = new_sprite_path
	sprite_scale = new_scale
	body_radius = new_radius
	_apply_sprite()


func set_facing_direction(direction: Vector2) -> void:
	if direction.length_squared() > 0.001:
		var previous_sign := _facing_sign()
		facing_direction = direction.normalized()
		var next_sign := _facing_sign()
		if previous_sign != 0 and next_sign != 0 and previous_sign != next_sign:
			turn_squash_timer = 0.1


func trigger_hit_squash() -> void:
	hit_squash_timer = 0.12


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
	shadow.z_index = -4
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.62)

	aura = get_node_or_null("Aura") as Sprite2D
	if aura == null:
		aura = Sprite2D.new()
		aura.name = "Aura"
		add_child(aura)
	aura.texture = ART_RESOURCES.get_radial_glow()
	aura.centered = true
	aura.material = ART_RESOURCES.get_additive_material()
	aura.z_index = -2

	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	sprite.centered = true
	sprite.z_index = 1
	animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null:
		animated_sprite = AnimatedSprite2D.new()
		animated_sprite.name = "AnimatedSprite2D"
		add_child(animated_sprite)
	animated_sprite.centered = true
	animated_sprite.z_index = 1
	_ensure_step_dust_pool()


func _apply_sprite() -> void:
	_ensure_sprite()
	var texture: Texture2D = SPRITE_LOADER.get_texture(sprite_path)
	if texture == null:
		sprite.visible = false
		return
	sprite.visible = true
	SPRITE_LOADER.fit_sprite(sprite, texture, body_radius * 3.1, sprite_scale)
	sprite_base_scale = sprite.scale
	_setup_animation_frames(body_radius * 3.1, sprite_scale)
	if shadow != null:
		ART_RESOURCES.fit_sprite(shadow, ART_RESOURCES.get_ellipse_shadow(), body_radius * 3.2)
		shadow_base_scale = shadow.scale
		shadow.position = Vector2(0.0, body_radius * 0.82)
	if aura != null:
		ART_RESOURCES.fit_sprite(aura, ART_RESOURCES.get_radial_glow(), body_radius * 5.2)
		aura_base_scale = aura.scale
		aura.modulate = Color(body_color.r * 0.45 + 0.2, body_color.g * 0.72 + 0.25, 1.0, 0.38)


func _update_procedural_motion(delta: float) -> void:
	if sprite == null:
		return
	var motion := _current_motion_velocity()
	var moving := motion.length_squared() > 9.0
	_update_animation_state(moving, motion)
	idle_phase += delta * 2.4
	if moving:
		step_timer += delta
		while step_timer >= STEP_INTERVAL:
			step_timer -= STEP_INTERVAL
			step_index += 1
			_trigger_footstep(motion.normalized())
		walk_phase = (step_timer / STEP_INTERVAL) * TAU
	else:
		step_timer = 0.0
		walk_phase += delta * 3.0
	if hit_squash_timer > 0.0:
		hit_squash_timer = max(hit_squash_timer - delta, 0.0)
	if turn_squash_timer > 0.0:
		turn_squash_timer = max(turn_squash_timer - delta, 0.0)

	var foot_sign: float = -1.0 if step_index % 2 == 0 else 1.0
	var step_lift: float = maxf(0.0, sin(walk_phase))
	var step_land: float = pow(maxf(0.0, cos(walk_phase)), 8.0) if moving else 0.0
	var bob: float = (-step_lift * 5.0 + step_land * 1.15) if moving else sin(walk_phase) * 0.7
	var lateral_offset: float = foot_sign * sin(walk_phase) * 1.15 if moving else 0.0
	var breath := 1.0 + sin(idle_phase) * (0.012 if moving else 0.026)
	var hit_squash := hit_squash_timer / 0.12 if hit_squash_timer > 0.0 else 0.0
	var turn_squash := turn_squash_timer / 0.1 if turn_squash_timer > 0.0 else 0.0
	var squash_x := 1.0 + hit_squash * 0.16 + turn_squash * 0.12 + step_land * 0.045
	var squash_y := 1.0 - hit_squash * 0.12 - turn_squash * 0.09 - step_land * 0.028
	var tilt := 0.0
	if moving:
		var direction := motion.normalized()
		set_facing_direction(direction)
		tilt = foot_sign * step_lift * 0.13 + clamp(direction.x, -1.0, 1.0) * 0.045
	if abs(facing_direction.x) > 0.05:
		var sign := _facing_sign()
		if last_facing_sign != 0 and sign != 0 and sign != last_facing_sign:
			turn_squash_timer = max(turn_squash_timer, 0.1)
		if sign != 0:
			last_facing_sign = sign
		sprite.flip_h = sign < 0
		if animated_sprite != null:
			animated_sprite.flip_h = sign < 0

	_apply_visual_transform(
		Vector2(lateral_offset, bob),
		tilt,
		Vector2(sprite_base_scale.x * breath * squash_x, sprite_base_scale.y * breath * squash_y)
	)
	if shadow != null:
		shadow.scale = shadow_base_scale * (1.0 - abs(bob) * 0.012)
	if aura != null:
		aura.scale = aura_base_scale * (1.0 + sin(idle_phase + 0.4) * 0.018)


func _setup_animation_frames(target_diameter: float, scale_multiplier: float) -> void:
	animation_frames_ready = false
	current_animation_name = ""
	if animated_sprite == null:
		return
	var frames := SpriteFrames.new()
	var idle_frames := _load_generated_frames("idle", 2)
	var walk_frames := _load_generated_frames("walk", 4)
	if idle_frames.is_empty() or walk_frames.size() < 3:
		animated_sprite.visible = false
		sprite.visible = true
		return
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 3.2)
	for texture in idle_frames:
		frames.add_frame("idle", texture)
	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 10.0)
	for texture in walk_frames:
		frames.add_frame("walk", texture)
	animated_sprite.sprite_frames = frames
	animated_sprite.animation = "idle"
	animated_sprite.play()
	animation_frames_ready = true
	animated_sprite.visible = true
	sprite.visible = false
	var max_size: float = max(float(idle_frames[0].get_width()), float(idle_frames[0].get_height()))
	var scale_value := 1.0 if max_size <= 0.0 else target_diameter / max_size * scale_multiplier
	animated_sprite_base_scale = Vector2.ONE * scale_value
	sprite_base_scale = animated_sprite_base_scale


func _load_generated_frames(animation_name: String, frame_count: int) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var base_name := sprite_path.get_file().get_basename()
	if base_name == "":
		return frames
	for index in range(frame_count):
		var path := "res://assets/sprites/generated/%s_%s_%d.png" % [base_name, animation_name, index]
		var texture := SPRITE_LOADER.get_texture(path)
		if texture == null:
			break
		frames.append(texture)
	return frames


func _update_animation_state(moving: bool, motion: Vector2) -> void:
	if not animation_frames_ready or animated_sprite == null:
		return
	var next_animation := "walk" if moving else "idle"
	if current_animation_name != next_animation:
		current_animation_name = next_animation
		animated_sprite.animation = next_animation
		animated_sprite.play(next_animation)
	if moving:
		var speed_ratio: float = motion.length() / max(1.0, _movement_speed_for_animation())
		animated_sprite.speed_scale = clamp(speed_ratio * 1.18, 0.72, 1.85)
	else:
		animated_sprite.speed_scale = 1.0


func _movement_speed_for_animation() -> float:
	var parent := get_parent()
	if parent == null:
		return 220.0
	var move_speed_value: Variant = parent.get("move_speed")
	if typeof(move_speed_value) == TYPE_FLOAT or typeof(move_speed_value) == TYPE_INT:
		return float(move_speed_value)
	return 220.0


func _apply_visual_transform(new_position: Vector2, new_rotation: float, new_scale: Vector2) -> void:
	if sprite != null:
		sprite.position = new_position
		sprite.rotation = new_rotation
		sprite.scale = new_scale
	if animated_sprite != null:
		animated_sprite.position = new_position
		animated_sprite.rotation = new_rotation
		animated_sprite.scale = new_scale


func _current_motion_velocity() -> Vector2:
	var parent := get_parent()
	if parent == null:
		return Vector2.ZERO
	var desired_value: Variant = parent.get("desired_velocity")
	if desired_value is Vector2:
		return desired_value
	var velocity_value: Variant = parent.get("velocity")
	if velocity_value is Vector2:
		return velocity_value
	return Vector2.ZERO


func _ensure_step_dust_pool() -> void:
	if step_dust_pool.size() >= STEP_DUST_POOL_SIZE:
		return
	for index in range(step_dust_pool.size(), STEP_DUST_POOL_SIZE):
		var dust := CPUParticles2D.new()
		dust.name = "StepDust%02d" % index
		dust.texture = ART_RESOURCES.get_particle_core()
		dust.one_shot = true
		dust.emitting = false
		dust.local_coords = false
		dust.amount = 8
		dust.lifetime = 0.28
		dust.explosiveness = 0.92
		dust.randomness = 0.52
		dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		dust.emission_sphere_radius = 4.0
		dust.direction = Vector2.UP
		dust.spread = 72.0
		dust.gravity = Vector2(0.0, 18.0)
		dust.initial_velocity_min = 18.0
		dust.initial_velocity_max = 58.0
		dust.scale_amount_min = 0.08
		dust.scale_amount_max = 0.22
		dust.color = Color(0.62, 0.55, 0.42, 0.42)
		dust.z_index = -1
		add_child(dust)
		step_dust_pool.append(dust)


func _trigger_footstep(direction: Vector2) -> void:
	_emit_step_dust(direction)
	if _can_play_footstep_audio() and AudioManager != null and AudioManager.has_method("play_sfx"):
		var pitch := 0.92 if step_index % 2 == 0 else 1.04
		AudioManager.play_sfx("footstep", false, -23.0, pitch)
		footstep_tick_count += 1


func _emit_step_dust(direction: Vector2) -> void:
	if step_dust_pool.is_empty():
		return
	var dust := step_dust_pool[next_step_dust_index % step_dust_pool.size()]
	next_step_dust_index += 1
	var foot_sign := -1.0 if step_index % 2 == 0 else 1.0
	dust.global_position = global_position + Vector2(foot_sign * body_radius * 0.42, body_radius * 0.82)
	dust.direction = -direction if direction.length_squared() > 0.01 else Vector2.UP
	dust.color = _dust_color_for_theme()
	dust.restart()
	dust.emitting = true
	step_dust_emit_count += 1


func _dust_color_for_theme() -> Color:
	if GameManager != null:
		match str(GameManager.get("current_run_theme_id")):
			"ember_rift":
				return Color(0.9, 0.42, 0.18, 0.42)
			"rift_void":
				return Color(0.45, 0.88, 1.0, 0.36)
			_:
				return Color(0.64, 0.55, 0.38, 0.44)
	return Color(0.62, 0.55, 0.42, 0.42)


func _can_play_footstep_audio() -> bool:
	var parent := get_parent()
	return parent != null and parent.is_in_group("heroes")


func _facing_sign() -> int:
	if facing_direction.x > 0.05:
		return 1
	if facing_direction.x < -0.05:
		return -1
	return 0


func get_step_dust_pool_size() -> int:
	return step_dust_pool.size()


func get_step_dust_emit_count() -> int:
	return step_dust_emit_count


func get_footstep_tick_count() -> int:
	return footstep_tick_count


func get_turn_squash_timer() -> float:
	return turn_squash_timer
