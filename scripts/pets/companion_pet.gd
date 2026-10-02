extends Node2D

const CATALOG := preload("res://scripts/services/pet_catalog.gd")
const FIREBALL := preload("res://scripts/pets/pet_fireball.gd")
var pet_id := ""
var hero_id := ""
var is_leader := false
var is_alive := true
var stars := 1
var slot_index := 0
var sprite: AnimatedSprite2D
var cooldown := 0.3
var attack_pending := false
var attacking := false
var attack_transition := false
var fireballs: Array[Node] = []
var attack_target_ref: WeakRef
var attack_token := -1
var impact_events := 0
var last_hit_frame := -1
var damage_dealt := 0.0
var healing_done := 0.0
var magnetic_gems := 0
var shots := 0
var data: Dictionary = {}


func _ready() -> void:
	add_to_group("companion_pets")
	z_index = 3
	sprite = AnimatedSprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.position = Vector2(0, -34)
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)
	add_child(sprite)
	queue_redraw()


func setup(id: String, star_count: int, index: int) -> void:
	pet_id = id
	hero_id = "pet_" + id
	stars = clampi(star_count, 1, CATALOG.MAX_STARS)
	slot_index = index
	data = CATALOG.get_pet(id)
	sprite.sprite_frames = CATALOG.get_frames(id)
	sprite.scale = Vector2.ONE * float(data.visual_scale)
	sprite.position = Vector2(0, -54.0 * float(data.visual_scale))
	sprite.play(&"idle")
	if id == "fire_fox":
		for warm_index in range(2):
			var ball: Node = FIREBALL.new()
			add_child(ball)
			fireballs.append(ball)
	if is_instance_valid(GameManager.player):
		global_position = GameManager.player.global_position + _follow_offset()


func apply_stars(value: int) -> void:
	stars = clampi(value, 1, CATALOG.MAX_STARS)
	cooldown = minf(cooldown, float(data.cooldown) * CATALOG.cooldown_multiplier(stars))


func _draw() -> void:
	draw_set_transform(Vector2(0, 4))
	_draw_shadow_ellipse()


func _draw_shadow_ellipse() -> void:
	var points := PackedVector2Array()
	for index in range(24):
		points.append(Vector2(cos(TAU * index / 24.0) * 20.0, sin(TAU * index / 24.0) * 7.0))
	draw_colored_polygon(points, Color(0.025, 0.04, 0.065, 0.25))


func _follow_offset() -> Vector2:
	return [Vector2(-52, 38), Vector2(48, 32), Vector2(0, 64)][clampi(slot_index, 0, 2)]


func _physics_process(delta: float) -> void:
	if not GameManager.game_running or not is_instance_valid(GameManager.player):
		return
	var actor: Node2D = GameManager.player
	var desired := actor.global_position + _follow_offset()
	var before := global_position
	global_position = global_position.move_toward(desired, 260.0 * delta)
	if global_position.distance_squared_to(desired) > 400.0 * 400.0:
		global_position = desired
	var background: Node = get_parent().get_node_or_null("Background")
	if get_parent().get_node_or_null("LoopWorldTopology") == null and background != null and background.has_method("get_playable_rect"):
		var bounds: Rect2 = background.call("get_playable_rect")
		global_position = global_position.clamp(bounds.position + Vector2.ONE * 12.0, bounds.end - Vector2.ONE * 12.0)
	if not attacking:
		var moving := global_position.distance_squared_to(before) > 0.04
		_play(&"walk" if moving else &"idle")
		sprite.flip_h = desired.x < global_position.x - 1.0
	cooldown -= delta
	if cooldown > 0.0 or attacking:
		return
	var target: Node = _nearest_target(global_position, float(data.range), {})
	if target == null and pet_id != "spirit_rabbit":
		return
	attack_pending = true
	attacking = true
	attack_target_ref = weakref(target) if target != null else null
	attack_token = int(target.get("spawn_token")) if target != null else -1
	if target != null:
		sprite.flip_h = target.global_position.x < global_position.x
	attack_transition = true
	sprite.play(&"attack")
	sprite.set_frame_and_progress(0, 0.0)
	attack_transition = false
	cooldown = float(data.cooldown) * CATALOG.cooldown_multiplier(stars)


func _play(state: StringName) -> void:
	if sprite.animation != state:
		sprite.play(state)


func _nearest_target(origin: Vector2, radius: float, used: Dictionary) -> Node:
	var nearest: Node = null
	var best := radius * radius
	for candidate in EntityFactory.get_enemies_in_radius(origin, radius):
		if candidate == null or not is_instance_valid(candidate) or not bool(candidate.get("is_active")) or used.has(candidate.get_instance_id()):
			continue
		var distance: float = origin.distance_squared_to(candidate.global_position)
		if distance < best:
			best = distance
			nearest = candidate
	return nearest


func _on_frame_changed() -> void:
	if attack_transition or not attack_pending or sprite.animation != &"attack" or sprite.frame != 2 or not GameManager.game_running:
		return
	attack_pending = false
	last_hit_frame = sprite.frame
	impact_events += 1
	var actor: Node2D = GameManager.player
	if not is_instance_valid(actor):
		return
	var multiplier := CATALOG.star_multiplier(stars)
	var damage := float(data.damage) * multiplier * GameManager.get_outgoing_damage_multiplier(actor)
	var target: Node = attack_target_ref.get_ref() as Node if attack_target_ref != null else null
	if not is_instance_valid(target) or not bool(target.get("is_active")) or int(target.get("spawn_token")) != attack_token:
		target = _nearest_target(global_position, float(data.range), {})
	match pet_id:
		"fire_fox":
			if target != null:
				var position: Vector2 = target.global_position
				for ball in fireballs:
					if not bool(ball.get("active")):
						ball.call("activate", global_position + Vector2(0,-12), target, damage, self)
						shots += 1
						break
				_fx("monster_fire", global_position + Vector2(0,-12), (position-global_position).normalized())
		"thunder_bird":
			var points: Array[Vector2] = [global_position + Vector2(0,-20)]
			var used := {}
			var cursor: Node = target
			var falloff := 1.0
			while cursor != null and points.size() <= 3:
				used[cursor.get_instance_id()] = true
				points.append(cursor.global_position)
				var actual := float(cursor.call("take_damage", damage * falloff, global_position))
				damage_dealt += actual
				GameManager.record_weapon_damage(self, "pet_thunder_bird", actual)
				falloff *= 0.85
				cursor = _nearest_target(cursor.global_position, 190.0, used)
			if points.size() > 1:
				EntityFactory.spawn_lightning_arc(points, data.color, 0.16, "res://assets/sprites/proj_lightning.png", 22.0)
				shots += points.size() - 1
		"spirit_rabbit":
			var members: Array = GameManager.squad_manager.get_members() if is_instance_valid(GameManager.squad_manager) else [actor]
			var patient: Node = null
			var lowest_ratio := 1.0
			for member in members:
				if not is_instance_valid(member) or not bool(member.get("is_alive")):
					continue
				var ratio := float(member.get("current_hp")) / maxf(1.0, float(member.get("max_hp")))
				if ratio < lowest_ratio:
					lowest_ratio = ratio
					patient = member
			if patient != null:
				var before := float(patient.get("current_hp"))
				patient.call("heal", float(data.heal) * multiplier)
				healing_done += float(patient.get("current_hp")) - before
				_fx("critical_impact", patient.global_position + Vector2(0,-12), Vector2.UP)
			magnetic_gems += EntityFactory.magnetize_xp_near(global_position, 210.0 + 10.0 * (stars - 1))
			if target != null:
				var actual := float(target.call("take_damage", damage, global_position))
				damage_dealt += actual
				GameManager.record_weapon_damage(self, "pet_spirit_rabbit", actual)
				var ray_points: Array[Vector2] = [global_position, target.global_position]
				EntityFactory.spawn_lightning_arc(ray_points, data.color, 0.15, "res://assets/sprites/proj_lightning.png", 15.0)


func _fx(kind: String, position: Vector2, direction: Vector2) -> void:
	var service := get_tree().get_first_node_in_group("combat_presentation")
	if service != null:
		service.call("play_effect", kind, position, direction, 0.48)


func _on_animation_finished() -> void:
	if sprite.animation == &"attack":
		attack_pending = false
		attacking = false
		_play(&"idle")


func report_fire_damage(value: float) -> void:
	damage_dealt += value


func get_debug_state() -> Dictionary:
	return {"id":pet_id, "name":str(data.get("name", "")), "stars":stars, "slot":slot_index, "impact_events":impact_events, "last_hit_frame":last_hit_frame, "shots":shots, "damage_dealt":damage_dealt, "healing_done":healing_done, "magnetic_gems":magnetic_gems, "animation":str(sprite.animation), "frame":sprite.frame, "damage_multiplier":CATALOG.star_multiplier(stars), "cooldown":float(data.cooldown) * CATALOG.cooldown_multiplier(stars)}
