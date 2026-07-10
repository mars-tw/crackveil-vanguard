class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = "未命名武器"
@export_multiline var description: String = ""
@export_enum("linear", "orbit", "explosion", "chain_lightning") var behavior_id: String = "linear"
@export var weapon_scene: PackedScene

@export_group("共同數值")
@export var damage: float = 10.0
@export var cooldown: float = 1.0
@export var range: float = 520.0
@export var color: Color = Color(0.7, 0.95, 1.0)
@export var effect_lifetime: float = 0.32

@export_group("視覺")
@export_file("*.png") var projectile_sprite_path: String = ""
@export_file("*.png") var orbit_sprite_path: String = ""
@export_file("*.png") var explosion_sprite_path: String = ""
@export_file("*.png") var lightning_sprite_path: String = ""
@export var sprite_scale: float = 1.0

@export_group("投射物")
@export var projectile_count: int = 1
@export var projectile_speed: float = 560.0
@export var projectile_radius: float = 4.5
@export var pierce: int = 0
@export var spread_degrees: float = 24.0

@export_group("環繞")
@export var orbit_radius: float = 58.0
@export var orbit_angular_speed: float = 4.2
@export var hit_interval: float = 0.42

@export_group("範圍")
@export var area_radius: float = 82.0

@export_group("連鎖")
@export var chain_count: int = 4
@export var chain_radius: float = 170.0
@export var chain_damage_falloff: float = 0.86

@export_group("升級")
@export var damage_upgrade: float = 4.0
@export var cooldown_upgrade_multiplier: float = 0.88
@export var range_upgrade: float = 34.0
@export var projectile_count_upgrade: int = 1
@export var pierce_upgrade: int = 1
@export var area_radius_upgrade: float = 18.0
@export var chain_count_upgrade: int = 1

var modifier_levels: Dictionary = {}

const QUALITATIVE_MAX_LEVELS: Dictionary = {
	"riftline_fork": 2,
	"orbit_resonance": 1,
	"pulse_embers": 1,
	"chain_overload": 1,
	"magnetic_reclaim": 1
}


func make_runtime_copy() -> Resource:
	var copy: Resource = duplicate(true)
	copy.set("modifier_levels", {})
	return copy


func apply_upgrade(upgrade_kind: String) -> void:
	match upgrade_kind:
		"weapon_damage":
			damage += damage_upgrade
		"weapon_cooldown":
			cooldown = max(0.08, cooldown * cooldown_upgrade_multiplier)
		"weapon_projectiles":
			_apply_count_upgrade()
		"weapon_upgrade":
			damage += damage_upgrade
			cooldown = max(0.08, cooldown * cooldown_upgrade_multiplier)
			range += range_upgrade
			_apply_count_upgrade()
		"riftline_fork", "orbit_resonance", "pulse_embers", "chain_overload", "magnetic_reclaim":
			_increment_modifier(upgrade_kind)
		_:
			damage += damage_upgrade


func can_apply_upgrade(upgrade_kind: String) -> bool:
	if not QUALITATIVE_MAX_LEVELS.has(upgrade_kind):
		return true
	return get_modifier_level(upgrade_kind) < get_modifier_max_level(upgrade_kind)


func get_modifier_level(modifier_id: String) -> int:
	return int(modifier_levels.get(modifier_id, 0))


func get_modifier_max_level(modifier_id: String) -> int:
	return int(QUALITATIVE_MAX_LEVELS.get(modifier_id, 1))


func has_modifier(modifier_id: String) -> bool:
	return get_modifier_level(modifier_id) > 0


func _increment_modifier(modifier_id: String) -> void:
	var next_level: int = min(get_modifier_level(modifier_id) + 1, get_modifier_max_level(modifier_id))
	modifier_levels[modifier_id] = next_level


func _apply_count_upgrade() -> void:
	match behavior_id:
		"linear":
			projectile_count += projectile_count_upgrade
			pierce += pierce_upgrade
		"orbit":
			projectile_count += projectile_count_upgrade
			pierce += pierce_upgrade
		"explosion":
			area_radius += area_radius_upgrade
		"chain_lightning":
			chain_count += chain_count_upgrade
			chain_radius += range_upgrade


func to_projectile_stats() -> Dictionary:
	return {
		"damage": damage,
		"range": range,
		"projectile_speed": projectile_speed,
		"projectile_radius": projectile_radius,
		"projectile_count": projectile_count,
		"pierce": pierce,
		"color": color,
		"projectile_sprite_path": projectile_sprite_path,
		"sprite_scale": sprite_scale,
		"target_group": "enemies",
		"riftline_fork_level": get_modifier_level("riftline_fork"),
		"fork_depth": 0
	}


func to_effect_stats() -> Dictionary:
	return {
		"damage": damage,
		"range": range,
		"projectile_count": projectile_count,
		"projectile_radius": projectile_radius,
		"pierce": pierce,
		"orbit_radius": orbit_radius,
		"orbit_angular_speed": orbit_angular_speed,
		"hit_interval": hit_interval,
		"area_radius": area_radius,
		"chain_count": chain_count,
		"chain_radius": chain_radius,
		"chain_damage_falloff": chain_damage_falloff,
		"color": color,
		"effect_lifetime": effect_lifetime,
		"projectile_sprite_path": projectile_sprite_path,
		"orbit_sprite_path": orbit_sprite_path,
		"explosion_sprite_path": explosion_sprite_path,
		"lightning_sprite_path": lightning_sprite_path,
		"sprite_scale": sprite_scale,
		"orbit_resonance_level": get_modifier_level("orbit_resonance"),
		"pulse_embers_level": get_modifier_level("pulse_embers"),
		"chain_overload_level": get_modifier_level("chain_overload"),
		"magnetic_reclaim_level": get_modifier_level("magnetic_reclaim")
	}
