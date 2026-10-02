extends Node2D

const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const CATALOG_PATH := "res://scripts/vfx/newskill_fx_catalog.gd"
const ATLAS_PATH := "res://assets/art/r35/r35_skill_fx_atlas.png"
const DESKTOP_CAP := 32
const MOBILE_CAP := 16

class Effect extends Node2D:
	var sprite: AnimatedSprite2D
	var kind := ""
	var age := 0.0
	var life := 0.25
	var release_age := -1.0
	var held := false
	var owner_ref: WeakRef
	func _ready() -> void:
		sprite = AnimatedSprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(sprite)
		visible = false

var catalog: Variant
var active: Array[Effect] = []
var free_slots: Array[Effect] = []
var channels: Dictionary = {}
var emitted := 0
var rejected := 0
var peak := 0

func _ready() -> void:
	add_to_group("combat_presentation")
	z_index = 38
	if ResourceLoader.exists(CATALOG_PATH):
		catalog = load(CATALOG_PATH)
	set_process(false)

func _cap() -> int:
	return MOBILE_CAP if MOBILE.mobile_lod_enabled(get_viewport_rect().size) else DESKTOP_CAP

func _effect_origin(kind: String, origin: Vector2, direction: Vector2) -> Vector2:
	if kind in ["slash_a", "slash_b"]:
		return origin + direction.normalized() * 70.0 + Vector2(0, 22)
	if kind == "cyclone":
		return origin + Vector2(0, 28)
	return origin

func play_effect(kind: String, origin: Vector2, direction: Vector2, strength: float = 1.0) -> Effect:
	if kind == "critical":
		kind = "critical_impact"
	if catalog == null or active.size() >= _cap():
		rejected += 1
		return null
	var frames: SpriteFrames = catalog.get_frames(kind)
	if frames == null or frames.get_frame_count("default") <= 0:
		return null
	var slot: Effect
	if free_slots.is_empty():
		slot = Effect.new()
		add_child(slot)
	else:
		slot = free_slots.pop_back()
	slot.kind = kind
	slot.age = 0.0
	slot.release_age = -1.0
	slot.life = float(catalog.get_lifetime(kind))
	slot.held = false
	slot.owner_ref = null
	slot.global_position = _effect_origin(kind, origin, direction)
	# Ground sweeps stay below the articulated body, keeping the face and
	# shoulder/weapon poses readable during the bright active frame.
	slot.z_index = -44 if kind in ["slash_a", "slash_b", "cyclone"] else 0
	slot.rotation = direction.angle() if kind in ["slash_a", "slash_b", "monster_bite", "monster_fire", "monster_shadow"] else 0.0
	var size_scale := clampf(strength, 0.35, 4.4 if kind in ["slash_a", "slash_b", "cyclone"] else 2.5)
	slot.scale = Vector2.ONE * size_scale
	slot.modulate = Color.WHITE
	slot.sprite.sprite_frames = frames
	slot.sprite.stop()
	slot.sprite.set_frame_and_progress(0, 0.0)
	slot.sprite.play("default")
	slot.visible = true
	active.append(slot)
	emitted += 1
	peak = maxi(peak, active.size())
	set_process(true)
	return slot

func set_channel(owner: Object, enabled: bool, origin: Vector2, direction: Vector2, strength: float = 1.0) -> void:
	if owner == null:
		return
	var key := owner.get_instance_id()
	var slot: Effect = channels.get(key)
	if not enabled:
		if is_instance_valid(slot):
			slot.held = false
			slot.release_age = 0.0
		channels.erase(key)
		return
	if not is_instance_valid(slot):
		slot = play_effect("cyclone", origin, direction, strength)
		if slot == null:
			return
		slot.held = true
		slot.owner_ref = weakref(owner)
		channels[key] = slot
	slot.global_position = _effect_origin("cyclone", origin, direction)

func _process(delta: float) -> void:
	for slot in active.duplicate():
		slot.age += delta
		if slot.held:
			var actor: Object = slot.owner_ref.get_ref() if slot.owner_ref != null else null
			if actor == null or not is_instance_valid(actor) or not GameManager.game_running or actor.get("is_alive") == false:
				slot.held = false
				slot.release_age = 0.0
		if not slot.held:
			if slot.release_age >= 0.0:
				slot.release_age += delta
				slot.modulate.a = maxf(0.0, 1.0 - slot.release_age / 0.10)
				if slot.release_age >= 0.10:
					_release(slot)
			elif slot.age >= slot.life:
				_release(slot)
			else:
				slot.modulate.a = minf(1.0, (slot.life - slot.age) / 0.07)
	if active.is_empty():
		set_process(false)

func _release(slot: Effect) -> void:
	active.erase(slot)
	for key in channels.keys():
		if channels[key] == slot:
			channels.erase(key)
	slot.sprite.stop()
	slot.sprite.set_frame_and_progress(0, 0.0)
	slot.sprite.sprite_frames = null
	slot.visible = false
	slot.modulate = Color.WHITE
	slot.scale = Vector2.ONE
	slot.rotation = 0.0
	slot.z_index = 0
	slot.kind = ""
	slot.held = false
	slot.owner_ref = null
	slot.age = 0.0
	slot.release_age = -1.0
	free_slots.append(slot)

func get_debug_state() -> Dictionary:
	return {"active": active.size(), "free": free_slots.size(), "channels": channels.size(), "emitted": emitted, "rejected": rejected, "peak": peak, "cap": _cap(), "assets_ready": catalog != null and ResourceLoader.exists(ATLAS_PATH)}
