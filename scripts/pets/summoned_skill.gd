extends Node2D

const CATALOG := preload("res://scripts/services/skill_catalog.gd")
var skill_id := ""
var level := 1
var casts := 0
var projectiles_spawned := 0
var last_cast_frame := -1
var last_cast_time := -999.0
var actor_ref: WeakRef
var visual_ref: WeakRef


func setup(id: String, skill_level: int = 1) -> void:
	skill_id = id
	level = clampi(skill_level, 1, CATALOG.MAX_LEVEL)
	_bind_actor()


func set_level(value: int) -> void:
	level = clampi(value, 1, CATALOG.MAX_LEVEL)


func _process(_delta: float) -> void:
	if not GameManager.game_running:
		return
	var actor: Object = actor_ref.get_ref() if actor_ref != null else null
	if actor == null or actor != GameManager.player:
		_bind_actor()


func _bind_actor() -> void:
	var previous: Object = visual_ref.get_ref() if visual_ref != null else null
	if is_instance_valid(previous) and previous.is_connected("attack_impact", Callable(self, "_on_attack_impact")):
		previous.disconnect("attack_impact", Callable(self, "_on_attack_impact"))
	actor_ref = null
	visual_ref = null
	if not is_instance_valid(GameManager.player):
		return
	var visual: Node = GameManager.player.get("visual") as Node
	if visual != null and visual.has_signal("attack_impact"):
		actor_ref = weakref(GameManager.player)
		visual_ref = weakref(visual)
		visual.connect("attack_impact", Callable(self, "_on_attack_impact"))


func _on_attack_impact() -> void:
	if not GameManager.game_running or get_tree().paused:
		return
	var actor: Node2D = actor_ref.get_ref() as Node2D if actor_ref != null else null
	var visual: Node = visual_ref.get_ref() as Node if visual_ref != null else null
	if not is_instance_valid(actor) or not bool(actor.get("is_alive")) or visual == null:
		return
	var sprite: AnimatedSprite2D = visual.get("animated_sprite") as AnimatedSprite2D
	if sprite == null or sprite.frame != 2:
		return
	var data: Dictionary = CATALOG.get_skill(skill_id)
	var interval := float(data.cooldown) * CATALOG.level_cooldown_multiplier(level)
	if GameManager.elapsed_time - last_cast_time < interval:
		return
	var targets: Array = EntityFactory.get_enemies_in_radius(actor.global_position, 620.0)
	if targets.is_empty():
		return
	last_cast_time = GameManager.elapsed_time
	last_cast_frame = sprite.frame
	casts += 1
	var damage := float(data.damage) * CATALOG.level_damage_multiplier(level) * GameManager.get_outgoing_damage_multiplier(actor)
	var facing: Vector2 = actor.call("get_facing_direction")
	var lock_value: Variant = actor.get("attack_direction_lock")
	if lock_value is Vector2 and lock_value.length_squared() > 0.001:
		facing = lock_value.normalized()
	var origin: Vector2 = actor.global_position
	var count := int(data.count)
	var presentation := get_tree().get_first_node_in_group("combat_presentation")
	if presentation != null:
		presentation.call("play_effect", str(data.fx), origin + facing * 45.0, facing, 0.8)
	for index in range(count):
		var target: Node2D = targets[index % targets.size()] as Node2D
		if not is_instance_valid(target):
			continue
		var direction := (target.global_position - origin).normalized()
		var stats := {"damage":damage, "source_weapon_id":"summon_" + skill_id, "range":760.0, "projectile_speed":360.0, "projectile_radius":5.0, "color":data.color, "sprite_scale":0.62, "pierce":0}
		var spawn_origin := origin
		match skill_id:
			"meteor_rain":
				spawn_origin += Vector2(float(index % 4 - 2) * 18.0, -32.0)
				stats.merge({"motion_mode":"lob", "lob_target_position":target.global_position + Vector2.from_angle(float(index) * TAU / count) * 22.0, "lob_arc_height":85.0, "projectile_sprite_path":"res://assets/sprites/proj_bullet.png", "lob_explosion_stats":{"damage":damage, "area_radius":58.0, "source_weapon_id":"summon_meteor_rain", "color":data.color, "effect_lifetime":0.22, "sprite_scale":0.70, "explosion_sprite_path":"res://assets/vfx/kenney_particle/burst_fire_ember.png"}}, true)
			"star_orbs":
				direction = Vector2.from_angle(TAU * float(index) / count)
				stats.merge({"homing_turn_rate":7.0, "homing_retarget_radius":620.0, "homing_target":target, "projectile_sprite_path":"res://assets/sprites/proj_bullet.png"}, true)
			"frost_lances":
				direction = facing.rotated(deg_to_rad((float(index) - float(count - 1) * 0.5) * 3.0))
				stats.merge({"pierce":3, "projectile_speed":490.0, "projectile_sprite_path":"res://assets/sprites/proj_lightning.png", "sprite_scale":0.48}, true)
			"shadow_blades":
				direction = direction.rotated((float(index) - 4.5) * 0.05)
				stats.merge({"motion_mode":"boomerang", "pierce":2, "boomerang_return_ratio":0.56, "boomerang_catch_radius":30.0, "projectile_sprite_path":"res://assets/sprites/proj_blade.png"}, true)
		if EntityFactory.spawn_projectile(spawn_origin, direction, stats, actor) != null:
			projectiles_spawned += 1


func get_debug_state() -> Dictionary:
	return {"id":skill_id, "level":level, "casts":casts, "actual_projectiles":projectiles_spawned, "last_cast_frame":last_cast_frame, "cooldown":float(CATALOG.get_skill(skill_id).cooldown) * CATALOG.level_cooldown_multiplier(level)}
