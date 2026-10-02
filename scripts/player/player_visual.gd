extends Node2D

signal attack_impact
signal attack_finished
signal death_finished

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const ART_RESOURCES := preload("res://scripts/services/art_resources.gd")
const TRUE_ANIMATION_LIBRARY := preload("res://scripts/animation/true_animation_library.gd")
const STEP_DUST_POOL_SIZE := 8
const ATTACK_IMPACT_FRAME := 2
const WALK_CONTACT_FRAMES := [1, 5]
const SILHOUETTE_SHADER := preload("res://scripts/shaders/hero_silhouette.gdshader")

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
var current_animation_name: StringName = &"idle"
var animation_frames_ready: bool = false
var attack_impact_emitted: bool = false
var step_index: int = 0
var step_dust_pool: Array[CPUParticles2D] = []
var next_step_dust_index: int = 0
var step_dust_emit_count: int = 0
var footstep_tick_count: int = 0
var silhouette_material: ShaderMaterial = null
var marker_refresh_timer: float = 0.0
var pending_heavy_hurt: bool = false


func _ready() -> void:
	_ensure_sprite()
	_ensure_step_dust_pool()
	_apply_sprite()


func _process(_delta: float) -> void:
	_update_locomotion_state()
	marker_refresh_timer -= _delta
	if marker_refresh_timer <= 0.0:
		marker_refresh_timer = 0.1
		queue_redraw()


func _draw() -> void:
	var hero := get_parent()
	if hero == null or hero.get("is_alive") != true or current_animation_name == &"death":
		return
	var leader: bool = hero.get("is_leader") == true
	var marker := Color(1.0, 0.8, 0.34, 0.94) if leader else Color(0.38, 0.86, 1.0, 0.66)
	var feet := Vector2(0.0, body_radius * 0.82)
	if leader:
		draw_arc(feet, body_radius * 0.95, 0.1, TAU - 0.1, 24, marker, 1.6, true)
		var arrow := facing_direction.normalized()
		var tip := feet + arrow * (body_radius + 6.0)
		draw_line(tip, tip - arrow.rotated(0.6) * 5.0, marker, 1.6, true)
		draw_line(tip, tip - arrow.rotated(-0.6) * 5.0, marker, 1.6, true)
	else:
		draw_arc(feet, body_radius * 0.65, 0.2, PI - 0.2, 12, marker, 1.2, true)
	var health: float = float(hero.get("current_hp")) / maxf(1.0, float(hero.get("max_hp")))
	if health < 0.995:
		var bar := Rect2(Vector2(-15.0, -body_radius * 1.6), Vector2(30.0, 3.0))
		draw_rect(bar.grow(1.0), Color(0.01, 0.02, 0.03, 0.9))
		bar.size.x *= clampf(health, 0.0, 1.0)
		draw_rect(bar, Color(1.0, 0.35, 0.3) if health < 0.35 else marker)


func configure_visual(
	new_sprite_path: String,
	new_scale: float,
	new_radius: float,
	new_body_color: Color = Color(0.35, 0.78, 1.0),
	new_core_color: Color = Color(0.88, 0.98, 1.0)
) -> void:
	sprite_path = new_sprite_path
	sprite_scale = new_scale
	body_radius = new_radius
	body_color = new_body_color
	core_color = new_core_color
	_apply_sprite()


func set_facing_direction(direction: Vector2) -> void:
	if direction.length_squared() <= 0.001:
		return
	facing_direction = direction.normalized()
	var flip := facing_direction.x < -0.05
	if animated_sprite != null:
		animated_sprite.flip_h = flip
	if sprite != null:
		sprite.flip_h = flip


func play_attack(animation_name: StringName = &"attack") -> bool:
	if not animation_frames_ready or is_attack_animation() or current_animation_name in [&"hurt", &"death"]:
		return false
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		animation_name = &"attack"
	attack_impact_emitted = false
	_play_state(animation_name, true)
	return true


func play_hurt(_source_position: Vector2 = Vector2.ZERO, heavy: bool = true) -> bool:
	if not animation_frames_ready or current_animation_name == &"death":
		return false
	if is_attack_animation():
		if heavy:
			pending_heavy_hurt = true
		return heavy
	attack_impact_emitted = true
	_play_state(&"hurt", true)
	return true


func play_death() -> bool:
	if not animation_frames_ready:
		return false
	if current_animation_name == &"death":
		return true
	pending_heavy_hurt = false
	attack_impact_emitted = true
	_play_state(&"death", true)
	return true


func trigger_hit_squash() -> void:
	# Compatibility API: hurt is now a real three-pose reaction, never a scale squash.
	play_hurt()


func is_attack_hitbox_active() -> bool:
	return is_attack_animation() and animated_sprite != null and animated_sprite.frame == ATTACK_IMPACT_FRAME


func is_attack_animation() -> bool:
	return current_animation_name == &"attack" or str(current_animation_name).begins_with("attack_combo_")


func finish_attack_recovery() -> void:
	if not is_attack_animation() or animated_sprite == null:
		return
	# A released channel skips its uncommitted active frame and retains the
	# authored recovery poses. No idle/walk frame can become a damage event.
	attack_impact_emitted = true
	if animated_sprite.frame < ATTACK_IMPACT_FRAME + 1:
		animated_sprite.set_frame_and_progress(ATTACK_IMPACT_FRAME + 1, 0.0)


func get_animation_state() -> StringName:
	return current_animation_name


func _ensure_sprite() -> void:
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
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0

	animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null:
		animated_sprite = AnimatedSprite2D.new()
		animated_sprite.name = "AnimatedSprite2D"
		add_child(animated_sprite)
	animated_sprite.centered = true
	animated_sprite.z_index = 1
	animated_sprite.position = Vector2.ZERO
	animated_sprite.rotation = 0.0
	if silhouette_material == null:
		silhouette_material = ShaderMaterial.new()
		silhouette_material.shader = SILHOUETTE_SHADER
	var leader: bool = get_parent() != null and get_parent().get("is_leader") == true
	silhouette_material.set_shader_parameter("edge_color", Color(1.0, 0.79, 0.32, 0.88) if leader else Color(0.34, 0.85, 1.0, 0.76))
	# The cel atlas already contains its own ink edges. Avoid the selection-box
	# look of an additional bright outline surrounding the entire character.
	animated_sprite.material = null
	if not animated_sprite.frame_changed.is_connected(_on_animation_frame_changed):
		animated_sprite.frame_changed.connect(_on_animation_frame_changed)
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)


func _apply_sprite() -> void:
	_ensure_sprite()
	animation_frames_ready = false
	if sprite_path == "":
		sprite.visible = false
		animated_sprite.visible = false
		return
	var frames: SpriteFrames = TRUE_ANIMATION_LIBRARY.get_sprite_frames(sprite_path)
	if frames == null:
		# A static fallback is only an error marker; it is never procedurally animated.
		var texture: Texture2D = SPRITE_LOADER.get_texture(sprite_path)
		sprite.visible = texture != null
		if texture != null:
			SPRITE_LOADER.fit_sprite(sprite, texture, body_radius * 3.1, sprite_scale)
		animated_sprite.visible = false
		push_error("Missing articulated animation frames for %s" % sprite_path)
		return
	animated_sprite.sprite_frames = frames
	var art_size: float = 105.0 if get_parent() != null and get_parent().get("is_leader") == true else 80.0
	animated_sprite.scale = Vector2.ONE * (art_size / float(TRUE_ANIMATION_LIBRARY.CELL_SIZE)) * sprite_scale
	animated_sprite.modulate = Color.WHITE
	animated_sprite.visible = true
	sprite.visible = false
	animation_frames_ready = true
	current_animation_name = &"idle"
	animated_sprite.play(&"idle")

	if shadow != null:
		ART_RESOURCES.fit_sprite(shadow, ART_RESOURCES.get_ellipse_shadow(), body_radius * 3.2)
		shadow.position = Vector2(0.0, 54.0 * art_size / float(TRUE_ANIMATION_LIBRARY.CELL_SIZE))
	if aura != null:
		ART_RESOURCES.fit_sprite(aura, ART_RESOURCES.get_radial_glow(), body_radius * 5.2)
		aura.modulate = Color(core_color.r * 0.62 + body_color.r * 0.24, core_color.g * 0.62 + body_color.g * 0.24, core_color.b * 0.72 + 0.22, 0.22)


func _update_locomotion_state() -> void:
	if not animation_frames_ready or animated_sprite == null:
		return
	if is_attack_animation() or current_animation_name in [&"hurt", &"death"]:
		return
	var motion := _current_motion_velocity()
	var moving := motion.length_squared() > 9.0
	if moving:
		set_facing_direction(motion)
		_play_state(&"walk")
		var speed_ratio: float = motion.length() / max(1.0, _movement_speed_for_animation())
		animated_sprite.speed_scale = clamp(speed_ratio, 0.65, 1.8)
	else:
		_play_state(&"idle")
		animated_sprite.speed_scale = 1.0


func _play_state(next_state: StringName, restart: bool = false) -> void:
	if not animation_frames_ready or animated_sprite == null:
		return
	if current_animation_name == next_state and not restart:
		return
	# Guard frame_changed while Godot swaps animations; otherwise an old walk
	# frame index of 2 can masquerade as the new attack impact frame.
	current_animation_name = &"transition"
	animated_sprite.stop()
	animated_sprite.animation = next_state
	animated_sprite.set_frame_and_progress(0, 0.0)
	current_animation_name = next_state
	animated_sprite.speed_scale = 1.0
	animated_sprite.play()


func _on_animation_frame_changed() -> void:
	if animated_sprite == null:
		return
	if is_attack_animation() and animated_sprite.frame == ATTACK_IMPACT_FRAME and not attack_impact_emitted:
		attack_impact_emitted = true
		attack_impact.emit()
	elif current_animation_name == &"walk" and animated_sprite.frame in WALK_CONTACT_FRAMES:
		step_index += 1
		_trigger_footstep(_current_motion_velocity().normalized())


func _on_animation_finished() -> void:
	if is_attack_animation():
		attack_finished.emit()
		if pending_heavy_hurt:
			pending_heavy_hurt = false
			_play_state(&"hurt", true)
		else:
			_resume_locomotion()
		return
	match current_animation_name:
		&"hurt":
			_resume_locomotion()
		&"death":
			death_finished.emit()


func _resume_locomotion() -> void:
	pending_heavy_hurt = false
	var moving := _current_motion_velocity().length_squared() > 9.0
	_play_state(&"walk" if moving else &"idle", true)


func _movement_speed_for_animation() -> float:
	var parent := get_parent()
	if parent == null:
		return 220.0
	var move_speed_value: Variant = parent.get("move_speed")
	if typeof(move_speed_value) == TYPE_FLOAT or typeof(move_speed_value) == TYPE_INT:
		return float(move_speed_value)
	return 220.0


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


func get_step_dust_pool_size() -> int:
	return step_dust_pool.size()


func get_step_dust_emit_count() -> int:
	return step_dust_emit_count


func get_footstep_tick_count() -> int:
	return footstep_tick_count


func get_turn_squash_timer() -> float:
	return 0.0


func get_debug_state() -> Dictionary:
	return {"animation": str(current_animation_name), "frame": animated_sprite.frame if animated_sprite != null else -1, "attack": is_attack_animation(), "impact_active": is_attack_hitbox_active(), "impact_emitted": attack_impact_emitted, "pending_heavy_hurt": pending_heavy_hurt, "authored_combo": animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(&"attack_combo_finisher")}
