extends WeaponData

# These definitions travel with the resource, so the shared upgrade pool and
# paid shop operate on the same live WeaponData instance.
const DEFINITIONS := {
	"solar_piercer": {
		"modifier": "solar_brand", "name": "灼星烙印", "description": "槍刺命中附加 10% 易傷；第 2 級提高至 20%，持續 1.4 秒。",
		"evolution_id": "evo_solar_phalanx", "evolution_name": "日冕槍陣", "evolution_description": "新增 2 列貫槍，射程 +80；每列最後命中處引發 35% 傷害日冕爆裂。",
		"count_description": "新增 1 列槍刺、+1 貫通，射程 +30"
	},
	"tidal_covenant": {
		"modifier": "tide_rejuvenation", "name": "潮生祝禱", "description": "每次爆潮替附近隊友回復 2 點；第 2 級回復 4 點，緩速提升至 40%。",
		"evolution_id": "evo_ocean_sanctuary", "evolution_name": "滄海聖域", "evolution_description": "爆潮半徑 +42、傷害 +8；每次追加 6 發追蹤水晶，附近隊友回復再 +2。",
		"count_description": "爆潮半徑 +18、緩速時間 +0.2 秒"
	},
	"shadow_twinblades": {
		"modifier": "shadow_return", "name": "回影追斬", "description": "返場刀可再次命中原敵、傷害 +18%；第 2 級返場傷害 +36%、航程 +35。",
		"evolution_id": "evo_crimson_cross", "evolution_name": "緋影刃陣", "evolution_description": "新增 2 把返場刀，刀寬 +2、穿透 +2；返場保留二次命中。",
		"count_description": "新增 1 把返場刀、+1 穿透，航程 +35"
	}
}

func get_qualitative_upgrade_definitions() -> Array:
	var definition: Dictionary = DEFINITIONS.get(id, {})
	if definition.is_empty():
		return []
	return [{"upgrade_kind": definition.modifier, "name": definition.name, "description": definition.description}]

func get_count_upgrade_description() -> String:
	return str(DEFINITIONS.get(id, {}).get("count_description", ""))

func get_modifier_max_level(modifier_id: String) -> int:
	var definition: Dictionary = DEFINITIONS.get(id, {})
	if modifier_id == str(definition.get("modifier", "")):
		return 2
	if modifier_id == str(definition.get("evolution_id", "")):
		return 1
	return super.get_modifier_max_level(modifier_id)

func can_apply_upgrade(upgrade_kind: String) -> bool:
	var definition: Dictionary = DEFINITIONS.get(id, {})
	if upgrade_kind in [str(definition.get("modifier", "")), str(definition.get("evolution_id", ""))]:
		return get_modifier_level(upgrade_kind) < get_modifier_max_level(upgrade_kind)
	if upgrade_kind == "weapon_projectiles" and id != "tidal_covenant":
		return projectile_count < 8
	return super.can_apply_upgrade(upgrade_kind)

func get_evolution_definition() -> Dictionary:
	var definition: Dictionary = DEFINITIONS.get(id, {})
	if definition.is_empty():
		return {}
	return {
		"evolution_id": definition.evolution_id, "name": definition.evolution_name,
		"description": definition.evolution_description, "required_modifier": definition.modifier,
		"required_level": 2, "required_damage_level": 3, "run_level": 7
	}

func apply_upgrade(upgrade_kind: String) -> void:
	if not can_apply_upgrade(upgrade_kind):
		return
	var definition: Dictionary = DEFINITIONS.get(id, {})
	if upgrade_kind == str(definition.get("modifier", "")):
		_increment_modifier(upgrade_kind)
		return
	if upgrade_kind == str(definition.get("evolution_id", "")):
		modifier_levels[upgrade_kind] = 1
		display_name = str(definition.evolution_name)
		match id:
			"solar_piercer":
				projectile_count = mini(8, projectile_count + 2)
				range += 80.0
			"tidal_covenant":
				area_radius += 42.0
				damage += 8.0
			"shadow_twinblades":
				projectile_count = mini(8, projectile_count + 2)
				projectile_radius += 2.0
				pierce += 2
		return
	super.apply_upgrade(upgrade_kind)

func _apply_count_upgrade() -> void:
	match id:
		"solar_piercer":
			projectile_count = mini(8, projectile_count + projectile_count_upgrade)
			pierce += pierce_upgrade
			range += range_upgrade
		"tidal_covenant":
			area_radius += area_radius_upgrade
			effect_lifetime += 0.2
		"shadow_twinblades":
			projectile_count = mini(8, projectile_count + projectile_count_upgrade)
			pierce += pierce_upgrade
			range += range_upgrade
		_:
			super._apply_count_upgrade()
