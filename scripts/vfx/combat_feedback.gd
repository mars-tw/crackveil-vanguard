extends Node2D

# One bounded canvas batch serves every damage route. Character poses remain
# driven by TrueAnimationLibrary; these are impact marks, never fake animation.
const MOBILE_TUNING := preload("res://scripts/services/mobile_tuning.gd")
const HIT_CAP := 28
const MOBILE_HIT_CAP := 12
const KILL_WINDOW := 0.45
const ANNOUNCE_COOLDOWN := 0.28
const MOBILE_SLASH_FOOTPRINT_SCALE := 0.84
const MOBILE_SLASH_FLOOR_PERSPECTIVE := 0.60
static var active_instance: WeakRef = null

var feedback_enabled: bool = true
var effects: Array[Dictionary] = []
var recent_kills: Array[Dictionary] = []
var combat_clock: float = 0.0
var announce_timer: float = 0.0
var announced_tier: int = 0
var hits_recorded: int = 0
var kills_recorded: int = 0
var harvest_announcements: int = 0
var dropped_hit_effects: int = 0
var peak_effects: int = 0
var slashes_recorded: int = 0
var redraw_requests: int = 0


func _ready() -> void:
	add_to_group("combat_feedback")
	active_instance = weakref(self)
	z_index = 36
	set_process(false)


func _exit_tree() -> void:
	if active_instance != null and active_instance.get_ref() == self:
		active_instance = null


static func report_hit(world_position: Vector2, source_position: Vector2, severity: float, lethal: bool, feature_enemy: bool) -> void:
	var host: Node = active_instance.get_ref() if active_instance != null else null
	if host != null and is_instance_valid(host):
		host.register_hit(world_position, source_position, severity, lethal, feature_enemy)


static func report_slash(world_position: Vector2, direction: Vector2, radius: float, half_angle: float, empowered: bool) -> void:
	var host: Node = active_instance.get_ref() if active_instance != null else null
	if host != null and is_instance_valid(host):
		host.register_slash(world_position, direction, radius, half_angle, empowered)


func register_slash(world_position: Vector2, direction: Vector2, radius: float, half_angle: float, empowered: bool) -> void:
	if not feedback_enabled:
		return
	slashes_recorded += 1
	var presentation := get_tree().get_first_node_in_group("combat_presentation")
	if presentation != null and bool(presentation.get_debug_state().get("assets_ready", false)):
		return
	_queue_effect({"kind": "slash", "position": world_position, "direction": direction.normalized(), "size": radius,
		"half_angle": half_angle, "empowered": empowered, "age": 0.0, "lifetime": 0.18 if empowered else 0.12})
	set_process(true)
	_request_redraw()


func register_hit(world_position: Vector2, source_position: Vector2, severity: float, lethal: bool, feature_enemy: bool) -> void:
	hits_recorded += 1
	if lethal:
		kills_recorded += 1
	if not feedback_enabled:
		return
	if lethal:
		_prune_kills()
		recent_kills.append({"time": combat_clock, "position": world_position})
		if recent_kills.size() > 64:
			recent_kills.pop_front()
	set_process(true)
	var direction := (world_position - source_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	if _is_visible_impact(world_position):
		_queue_effect({
			"kind": "hit", "position": world_position, "direction": direction,
			"age": 0.0, "lifetime": 0.11 if lethal else 0.09,
			"size": 5.8 if lethal else lerpf(3.5, 4.8, clampf(severity, 0.0, 1.0)),
			"lethal": lethal, "feature": feature_enemy,
		})
	if lethal:
		_try_announce_harvest()
	if not effects.is_empty():
		_request_redraw()


func set_feedback_enabled(value: bool) -> void:
	feedback_enabled = value
	if not value:
		effects.clear()
		recent_kills.clear()
		announced_tier = 0
		set_process(false)
		_request_redraw()


func _process(delta: float) -> void:
	var had_effects := not effects.is_empty()
	combat_clock += delta
	announce_timer = maxf(0.0, announce_timer - delta)
	_prune_kills()
	for index in range(effects.size() - 1, -1, -1):
		effects[index]["age"] = float(effects[index]["age"]) + delta
		if float(effects[index]["age"]) >= float(effects[index]["lifetime"]):
			effects.remove_at(index)
	_try_announce_harvest()
	if had_effects:
		_request_redraw()
	if effects.is_empty() and recent_kills.is_empty():
		set_process(false)


func _request_redraw() -> void:
	redraw_requests += 1
	queue_redraw()


func _prune_kills() -> void:
	while not recent_kills.is_empty() and combat_clock - float(recent_kills[0]["time"]) > KILL_WINDOW:
		recent_kills.pop_front()
	if recent_kills.is_empty():
		announced_tier = 0


func _try_announce_harvest() -> void:
	if not feedback_enabled or announce_timer > 0.0:
		return
	var count := recent_kills.size()
	var tier := 8 if count >= 8 else (5 if count >= 5 else (3 if count >= 3 else 0))
	if tier <= announced_tier:
		return
	announced_tier = tier
	announce_timer = ANNOUNCE_COOLDOWN
	harvest_announcements += 1
	# Hurt/death poses and the main blade carry the event. Do not add another
	# pair of centroid circles that looks like a leftover aim/debug overlay.
	# A brief directional camera kick preserves impact without stacking global
	# time-scale owners or extending every hit into a permanent slow motion.
	if GameManager.has_method("request_combat_impact"):
		GameManager.request_combat_impact(2.0 + float(tier) * 0.26, 0.0)
	if AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("combo", false, -6.0, 1.0 + float(tier) * 0.035)


func _queue_effect(effect: Dictionary) -> void:
	var cap := get_effect_cap()
	while effects.size() > cap:
		effects.pop_front()
	if effects.size() >= cap:
		dropped_hit_effects += 1
		if str(effect["kind"]) == "hit":
			return
		effects.pop_front()
	effects.append(effect)
	peak_effects = maxi(peak_effects, effects.size())


func get_effect_cap() -> int:
	return MOBILE_HIT_CAP if MOBILE_TUNING.mobile_lod_enabled(get_viewport_rect().size) else HIT_CAP


func _is_visible_impact(world_position: Vector2) -> bool:
	if GameManager.player == null or not is_instance_valid(GameManager.player):
		return true
	var offset: Vector2 = world_position - GameManager.player.global_position
	var half_size := get_viewport_rect().size * 0.6 + Vector2(80.0, 80.0)
	return absf(offset.x) <= half_size.x and absf(offset.y) <= half_size.y


func _draw() -> void:
	for effect in effects:
		var t := clampf(float(effect["age"]) / float(effect["lifetime"]), 0.0, 1.0)
		var origin := to_local(effect["position"] as Vector2)
		var size := float(effect["size"])
		if str(effect["kind"]) == "slash":
			_draw_slash(effect, origin, t)
			continue
		if str(effect["kind"]) == "harvest":
			var tint: Color = effect["color"]
			tint.a = (1.0 - t) * 0.72
			var ring_radius := size * (0.48 + 0.65 * (1.0 - pow(1.0 - t, 2.0)))
			# Two open cuts leave the enemy silhouette and hazard floor visible.
			draw_arc(origin, ring_radius, -0.45, 1.9, 15, tint, 2.5 * (1.0 - t) + 0.5, true)
			draw_arc(origin, ring_radius * 0.8, 2.8, 4.7, 12, tint, 1.5, true)
			continue
		var direction: Vector2 = effect["direction"]
		var lethal := bool(effect["lethal"])
		var tint := Color(1.0, 0.84, 0.42) if lethal else Color(0.84, 1.0, 0.96)
		tint.a = pow(1.0 - t, 1.35)
		var spread := size * (0.35 + t * 1.3)
		for shard in range(2):
			var ray := direction.rotated((float(shard) - 0.5) * 0.8)
			var start := origin + ray * spread
			var finish := origin + ray * (spread + size * (1.0 - t) * 0.7)
			draw_line(start, finish, Color(0.02, 0.035, 0.05, tint.a), 2.0, true)
			draw_line(start, finish, tint, 1.2, true)
		if lethal:
			var cross := direction.orthogonal() * size * 0.5
			draw_line(origin - cross, origin + cross, Color(1.0, 0.97, 0.84, tint.a * 0.8), 1.2, true)


func _draw_slash(effect: Dictionary, anchor: Vector2, t: float) -> void:
	var visual_scale := get_slash_visual_scale()
	# Project the whole cut around its cast-time world origin. Damage geometry
	# stays in Hero; neither the character nor any hitbox is scaled here.
	draw_set_transform(anchor, 0.0, visual_scale)
	var origin := Vector2.ZERO
	var direction: Vector2 = effect["direction"]
	var radius := float(effect["size"])
	var half_angle := float(effect["half_angle"])
	var heavy := bool(effect["empowered"])
	var alpha := pow(1.0 - t, 1.65)
	var reach := radius * lerpf(0.8, 1.04, 1.0 - pow(1.0 - minf(1.0, t * 4.5), 3.0))
	var center_angle := direction.angle()
	# The white leading edge and warm trailing blade form one coherent cut.
	# No bloom, texture billboard or radial fill covers the entire arena.
	var swept_start := center_angle - half_angle + half_angle * 0.4 * t
	var swept_end := center_angle + half_angle
	var body_width := (16.0 if heavy else 7.0) * (1.0 - t * 0.7)
	var blade := _blade_polygon(origin, reach, body_width, swept_start, swept_end, 28)
	draw_colored_polygon(blade, Color(1.0, 0.76, 0.32, alpha * 0.83))
	var core := _blade_polygon(origin, reach - 1.0, body_width * 0.45, swept_start + 0.04, swept_end - 0.04, 28)
	draw_colored_polygon(core, Color(1.0, 0.98, 0.76, alpha))
	draw_arc(origin, reach, swept_start, swept_end, 32, Color(1.0, 1.0, 0.92, alpha), 1.8 if heavy else 1.2, true)
	# Restore the shared canvas before the next independent hit/death mark.
	draw_set_transform(Vector2.ZERO)


func get_slash_visual_scale() -> Vector2:
	if MOBILE_TUNING.mobile_lod_enabled(get_viewport_rect().size):
		return Vector2(MOBILE_SLASH_FOOTPRINT_SCALE, MOBILE_SLASH_FOOTPRINT_SCALE * MOBILE_SLASH_FLOOR_PERSPECTIVE)
	return Vector2.ONE


func _blade_polygon(origin: Vector2, outer_radius: float, width: float, start_angle: float, end_angle: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments + 1):
		var fraction := float(index) / float(segments)
		var angle := lerpf(start_angle, end_angle, fraction)
		points.append(origin + Vector2.RIGHT.rotated(angle) * outer_radius)
	for index in range(segments, -1, -1):
		var fraction := float(index) / float(segments)
		var angle := lerpf(start_angle, end_angle, fraction)
		var tapered_width := width * (0.35 + sin(fraction * PI) * 0.65)
		points.append(origin + Vector2.RIGHT.rotated(angle) * (outer_radius - tapered_width))
	return points


func get_debug_state() -> Dictionary:
	var slash_scale := get_slash_visual_scale()
	return {"hits": hits_recorded, "kills": kills_recorded, "harvest_announcements": harvest_announcements, "slashes": slashes_recorded, "slash_visual_scale": [slash_scale.x, slash_scale.y], "live_effects": effects.size(), "peak_effects": peak_effects, "effect_cap": get_effect_cap(), "dropped_hit_effects": dropped_hit_effects, "recent_kills": recent_kills.size(), "feedback_enabled": feedback_enabled, "redraw_requests": redraw_requests}
