extends RefCounted

# Reads the live runtime copy; never mutates weapon data or the candidate dict.
static func describe(option: Dictionary) -> String:
	var description := str(option.get("description", ""))
	if str(option.get("id", "")) == "recruit_hero":
		# Keep the recruitment decision readable; its full quote remains on the
		# card tooltip. The gameplay role and named bond remain in the card.
		var hero_id := str(option.get("hero_id", ""))
		var hero_path := "res://resources/heroes/%s.tres" % hero_id
		if ResourceLoader.exists(hero_path):
			var hero_data: Resource = load(hero_path)
			description = str(hero_data.get("description"))
		elif description.begins_with("「") and description.contains("\n"):
			description = description.substr(description.find("\n") + 1)
	var benefit := benefit_text(option)
	var progress := progress_text(option)
	var lines := PackedStringArray()
	if benefit != "":
		lines.append(benefit)
	if description != "" and description != benefit and str(option.get("upgrade_kind", "")) not in ["weapon_damage", "weapon_cooldown", "weapon_projectiles"]:
		lines.append(description)
	if progress != "":
		lines.append(progress)
	return "\n".join(lines)


static func benefit_text(option: Dictionary) -> String:
	var id := str(option.get("id", ""))
	var player: Node = GameManager.player
	if id == "upgrade_hero_weapon":
		return _weapon_benefit(option)
	if id == "recruit_hero":
		var squad: Node = GameManager.squad_manager
		if squad != null and is_instance_valid(squad) and squad.has_method("get_member_count"):
			return "隊伍人數 %d → %d" % [squad.get_member_count(), squad.get_member_count() + 1]
		return "招募新隊員"
	if player == null or not is_instance_valid(player):
		return ""
	match id:
		"move_speed":
			return "隊長移速 %s → %s" % [_number(float(player.get("move_speed"))), _number(float(player.get("move_speed")) + 20.0)]
		"max_hp":
			return "隊長最大 HP %s → %s" % [_number(float(player.get("max_hp"))), _number(float(player.get("max_hp")) + 20.0)]
		"pickup_radius":
			return "隊長拾取範圍 %s → %s" % [_number(float(player.get("pickup_radius"))), _number(float(player.get("pickup_radius")) + 24.0)]
	return ""


static func progress_text(option: Dictionary) -> String:
	var max_level := int(option.get("max_level", 0))
	var data := _weapon_data(option)
	var kind := str(option.get("upgrade_kind", ""))
	var category := str(option.get("upgrade_category", ""))
	var lines := PackedStringArray()
	if max_level > 0:
		var current := int(GameManager.upgrade_counts.get(GameManager._upgrade_level_key(option), 0))
		if data != null and kind != "" and data.has_method("get_modifier_level"):
			current = int(data.get_modifier_level(kind))
		lines.append("%s %d → %d／%d" % ["質變階段" if category == "qualitative" else "強化階段", current, mini(current + 1, max_level), max_level])
	if data != null and data.has_method("get_evolution_definition") and category != "evolution":
		var evolution: Dictionary = data.get_evolution_definition()
		if not evolution.is_empty() and not data.is_evolved():
			var required_kind := str(evolution.get("required_modifier", ""))
			var damage_level := int(data.get_modifier_level("weapon_damage")) + (1 if kind == "weapon_damage" else 0)
			var modifier_level := int(data.get_modifier_level(required_kind)) + (1 if kind == required_kind else 0)
			lines.append("選後進化：增幅 %d／%d · 質變 %d／%d · Lv.%d" % [mini(damage_level, int(evolution.get("required_damage_level", 3))), int(evolution.get("required_damage_level", 3)), mini(modifier_level, int(evolution.get("required_level", 1))), int(evolution.get("required_level", 1)), int(evolution.get("run_level", 7))])
	return "\n".join(lines)


static func _weapon_benefit(option: Dictionary) -> String:
	var data := _weapon_data(option)
	if data == null:
		return ""
	var kind := str(option.get("upgrade_kind", ""))
	match kind:
		"weapon_damage":
			var before := float(data.get("damage"))
			var after := before + float(data.get("damage_upgrade"))
			return "基礎傷害 %s → %s（+%s%%）" % [_number(before), _number(after), _number((after / maxf(before, 0.001) - 1.0) * 100.0)]
		"weapon_cooldown":
			var before := float(data.get("cooldown"))
			var after := maxf(0.08, before * float(data.get("cooldown_upgrade_multiplier")))
			return "施放間隔 %.2f → %.2f 秒\n攻速 +%s%%" % [before, after, _number((before / after - 1.0) * 100.0)]
		"weapon_projectiles":
			var preview: Resource = data.duplicate(true)
			preview.apply_upgrade(kind)
			var changes := PackedStringArray()
			for field in ["projectile_count", "pierce", "area_radius", "chain_count", "chain_radius", "range"]:
				var before := float(data.get(field))
				var after := float(preview.get(field))
				if not is_equal_approx(before, after):
					var name := str({"projectile_count": "數量", "pierce": "穿透", "area_radius": "範圍半徑", "chain_count": "連鎖數", "chain_radius": "連鎖距離", "range": "射程"}.get(field, field))
					changes.append("%s %s → %s" % [name, _number(before), _number(after)])
			return " · ".join(changes)
	if str(option.get("upgrade_category", "")) == "evolution":
		return "武器進化已就緒\n取得新攻擊形態。"
	return ""


static func _weapon_data(option: Dictionary) -> Resource:
	if str(option.get("id", "")) != "upgrade_hero_weapon":
		return null
	var squad: Node = GameManager.squad_manager
	if squad == null or not is_instance_valid(squad) or not squad.has_method("get_member_by_id"):
		return null
	var member: Node = squad.get_member_by_id(str(option.get("hero_id", "")))
	if member == null or not is_instance_valid(member):
		return null
	var weapons: Dictionary = member.get("weapons")
	var weapon: Node = weapons.get(str(option.get("weapon_id", "")))
	if weapon == null or not is_instance_valid(weapon):
		return null
	return weapon.get("data") as Resource


static func _number(value: float) -> String:
	return str(int(roundf(value))) if absf(value - roundf(value)) < 0.05 else "%.1f" % value
