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
	"magnetic_reclaim": 1,
	"evo_rift_fan": 1,
	"evo_shear_halo": 1,
	"evo_ember_well": 1,
	"evo_overload_nova": 1
}

const EVOLUTION_DEFINITIONS: Dictionary = {
	"riftline_emitter": {
		"evolution_id": "evo_rift_fan",
		"name": "裂隙扇編",
		"description": "裂線改為扇形編織；命中後裂片角度展開，受 fork cap 保護。",
		"required_modifier": "riftline_fork",
		"required_level": 2,
		"required_damage_level": 3,
		"run_level": 7
	},
	"orbit_blades": {
		"evolution_id": "evo_shear_halo",
		"name": "剪界星環",
		"description": "星環半徑脈動，命中時附加短暫 slow，迫使敵群被切開。",
		"required_modifier": "orbit_resonance",
		"required_level": 1,
		"required_damage_level": 3,
		"run_level": 7
	},
	"pulse_bloom": {
		"evolution_id": "evo_ember_well",
		"name": "餘燼井",
		"description": "爆花留下更久的餘燼井，尾端追加第二段小爆並緩速井內敵人。",
		"required_modifier": "pulse_embers",
		"required_level": 1,
		"required_damage_level": 3,
		"run_level": 7
	},
	"arc_chain": {
		"evolution_id": "evo_overload_nova",
		"name": "超載新星",
		"description": "雷鏈末端爆成新星，向附近目標補放短弧。",
		"required_modifier": "chain_overload",
		"required_level": 1,
		"required_damage_level": 3,
		"run_level": 7
	}
}


func make_runtime_copy() -> Resource:
	var copy: Resource = duplicate(true)
	copy.set("modifier_levels", {})
	return copy


func apply_upgrade(upgrade_kind: String) -> void:
	match upgrade_kind:
		"weapon_damage":
			damage += damage_upgrade
			_increment_runtime_modifier(upgrade_kind)
		"weapon_cooldown":
			cooldown = max(0.08, cooldown * cooldown_upgrade_multiplier)
			_increment_runtime_modifier(upgrade_kind)
		"weapon_projectiles":
			_apply_count_upgrade()
			_increment_runtime_modifier(upgrade_kind)
		"weapon_upgrade":
			damage += damage_upgrade
			cooldown = max(0.08, cooldown * cooldown_upgrade_multiplier)
			range += range_upgrade
			_apply_count_upgrade()
			_increment_runtime_modifier("weapon_damage")
			_increment_runtime_modifier("weapon_cooldown")
			_increment_runtime_modifier("weapon_projectiles")
		"evo_rift_fan", "evo_shear_halo", "evo_ember_well", "evo_overload_nova":
			_apply_evolution(upgrade_kind)
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


func get_evolution_definition() -> Dictionary:
	return EVOLUTION_DEFINITIONS.get(id, {})


func get_evolution_id() -> String:
	var definition := get_evolution_definition()
	return str(definition.get("evolution_id", ""))


func is_evolved() -> bool:
	var evolution_id := get_evolution_id()
	return evolution_id != "" and has_modifier(evolution_id)


func can_offer_evolution(run_level: int) -> bool:
	var definition := get_evolution_definition()
	if definition.is_empty():
		return false
	var evolution_id := str(definition.get("evolution_id", ""))
	if evolution_id == "" or has_modifier(evolution_id):
		return false
	if run_level < int(definition.get("run_level", 7)):
		return false
	var required_modifier := str(definition.get("required_modifier", ""))
	var required_level := int(definition.get("required_level", get_modifier_max_level(required_modifier)))
	var required_damage_level := int(definition.get("required_damage_level", 0))
	return required_modifier != "" and get_modifier_level(required_modifier) >= required_level and get_modifier_level("weapon_damage") >= required_damage_level


func _increment_modifier(modifier_id: String) -> void:
	var next_level: int = min(get_modifier_level(modifier_id) + 1, get_modifier_max_level(modifier_id))
	modifier_levels[modifier_id] = next_level


func _increment_runtime_modifier(modifier_id: String) -> void:
	modifier_levels[modifier_id] = get_modifier_level(modifier_id) + 1


func _apply_evolution(evolution_id: String) -> void:
	if get_modifier_level(evolution_id) > 0:
		return
	modifier_levels[evolution_id] = 1
	var definition := get_evolution_definition()
	if not definition.is_empty():
		display_name = str(definition.get("name", display_name))
	match evolution_id:
		"evo_rift_fan":
			projectile_count = clamp(projectile_count + 1, 3, 5)
			spread_degrees = max(spread_degrees, 48.0)
			color = Color(0.52, 1.0, 0.86)
		"evo_shear_halo":
			orbit_radius += 28.0
			projectile_radius += 1.5
			hit_interval = max(0.24, hit_interval * 0.84)
			color = Color(0.9, 0.94, 1.0)
		"evo_ember_well":
			cooldown = max(0.18, cooldown * 0.95)
			color = Color(1.0, 0.45, 0.18)
		"evo_overload_nova":
			chain_radius += 24.0
			effect_lifetime += 0.08
			color = Color(0.72, 1.0, 0.92)


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
		"evo_rift_fan_level": get_modifier_level("evo_rift_fan"),
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
		"magnetic_reclaim_level": get_modifier_level("magnetic_reclaim"),
		"evo_shear_halo_level": get_modifier_level("evo_shear_halo"),
		"evo_ember_well_level": get_modifier_level("evo_ember_well"),
		"evo_overload_nova_level": get_modifier_level("evo_overload_nova")
	}
