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
	var target := target_text(option)
	if target != "":
		lines.append(target)
	if benefit != "":
		lines.append(benefit)
	if description != "" and description != benefit and str(option.get("upgrade_kind", "")) not in ["weapon_damage", "weapon_cooldown", "weapon_projectiles"]:
		lines.append(description)
	if progress != "":
		lines.append(progress)
	var link := synergy_text(option)
	if link != "":
		lines.append(link)
	return "\n".join(lines)


const FORMATION_NAMES := {"wedge": "楔形", "ring": "圓陣", "scatter": "散兵"}

# Who the card applies to, read from the live roster.
static func target_text(option: Dictionary) -> String:
	var id := str(option.get("id", ""))
	if id in ["move_speed", "max_hp", "pickup_radius"]:
		return "適用：隊長"
	if id == "upgrade_hero_weapon":
		return "適用：%s" % _hero_name(str(option.get("hero_id", "")))
	return ""


# Links to the real bond and bond × formation resonance tables; read only.
static func synergy_text(option: Dictionary) -> String:
	if str(option.get("id", "")) != "upgrade_hero_weapon":
		return ""
	var squad: Node = GameManager.squad_manager
	if squad == null or not is_instance_valid(squad):
		return ""
	var hero_id := str(option.get("hero_id", ""))
	# Tables come from the squad script itself, so stand-in squads stay safe.
	var tables: GDScript = load("res://scripts/heroes/squad_manager.gd")
	for definition in tables.BOND_DEFINITIONS:
		var ids: Array = definition.get("hero_ids", [])
		if not ids.has(hero_id):
			continue
		var bond_id := str(definition.get("id", ""))
		var bond_name := str(definition.get("name", ""))
		var resonance: Dictionary = tables.BOND_FORMATION_RESONANCE.get(bond_id, {})
		var formation := str(resonance.get("formation", ""))
		if squad.has_method("has_active_bond") and squad.has_active_bond(bond_id):
			if formation == "":
				return "連動：羈絆「%s」已成立" % bond_name
			var current: String = squad.get_formation_id() if squad.has_method("get_formation_id") else ""
			return "連動：「%s」已成立・%s時%s%s" % [bond_name, FORMATION_NAMES.get(formation, formation), str(resonance.get("short", "")).get_slice(" ", 1), "（目前）" if current == formation else ""]
		var partner := ""
		for other in ids:
			if str(other) != hero_id:
				partner = str(other)
		# Only name a partner this run can still bring in; otherwise stay quiet.
		if not _partner_obtainable(squad, partner):
			return ""
		return "連動：招募%s可成立「%s」" % [_hero_name(partner), bond_name]
	return ""


static func _partner_obtainable(squad: Node, partner: String) -> bool:
	if partner == "":
		return false
	var dead = squad.get("dead_ids")
	if typeof(dead) == TYPE_DICTIONARY and (dead as Dictionary).has(partner):
		return false
	var once = squad.get("recruited_once")
	if typeof(once) == TYPE_DICTIONARY and (once as Dictionary).has(partner):
		return false
	var data = squad.get("squad_data")
	if data == null or not (data is Resource):
		return false
	if squad.has_method("get_member_count") and squad.get_member_count() >= int(data.get("max_members")):
		return false
	var found := false
	for hero_data in data.get("available_heroes"):
		if hero_data != null and str(hero_data.get("id")) == partner:
			found = true
	if found and squad.has_method("_starting_recruit_allowed"):
		found = squad._starting_recruit_allowed(partner)
	return found


static func _hero_name(hero_id: String) -> String:
	var path := "res://resources/heroes/%s.tres" % hero_id
	if hero_id != "" and ResourceLoader.exists(path):
		var data: Resource = load(path)
		return str(data.get("display_name"))
	return hero_id


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

const QUALITATIVE_ICON_WORDS := [
	["projectiles", ["分叉", "分裂"]],
	["pickup", ["回收"]],
	["damage", ["雷鏈", "過載", "脈衝", "校準"]],
	["cooldown", ["共鳴", "共振", "和聲"]],
]

static func icon_key(option: Dictionary) -> String:
	if str(option.get("id", "")) == "recruit_hero":
		return "recruit"
	if str(option.get("upgrade_category", "")) == "evolution":
		return "evolution"
	if str(option.get("upgrade_category", "")) == "qualitative":
		# Each qualitative change gets the icon of what it actually does, so two
		# qualitative cards on one screen no longer share the same star.
		var qualitative_name := str(option.get("name", ""))
		for rule in QUALITATIVE_ICON_WORDS:
			for word in rule[1]:
				if qualitative_name.contains(word):
					return rule[0]
		return "qualitative"
	match str(option.get("upgrade_kind", "")):
		"weapon_damage":
			return "damage"
		"weapon_cooldown":
			return "cooldown"
		"weapon_projectiles":
			return "projectiles"
	match str(option.get("id", "")):
		"move_speed":
			return "speed"
		"max_hp":
			return "hp"
		"pickup_radius":
			return "pickup"
		"recruit_hero":
			return "recruit"
	if str(option.get("upgrade_category", "")) == "fallback":
		return "supply"
	var option_id := str(option.get("id", ""))
	if "heal" in option_id or "health" in option_id or "hp" in option_id or "armor" in option_id:
		return "hp"
	if "gold" in option_id:
		return "supply"
	return "supply"


static func fix_orphan_punctuation(text: String) -> String:
	const CLOSERS := "」』）】〕〉》、。！？；："
	var lines := text.split("\n")
	var fixed: Array[String] = []
	for raw in lines:
		var line := raw
		while line.length() > 0 and CLOSERS.contains(line.substr(0, 1)) and not fixed.is_empty():
			fixed[fixed.size() - 1] += line.substr(0, 1)
			line = line.substr(1)
		if line != "" or fixed.is_empty():
			fixed.append(line)
	return "\n".join(fixed)


static func card_main_text(option: Dictionary) -> String:
	var parts := PackedStringArray()
	var target := target_text(option)
	if target != "":
		parts.append(target)
	var benefit := benefit_text(option).replace("\n", " ")
	if benefit != "":
		parts.append(benefit)
	elif str(option.get("id", "")) == "recruit_hero":
		pass
	if str(option.get("id", "")) == "recruit_hero":
		var description := str(option.get("description", ""))
		# Recruitment role text stays in the main card; the quote is secondary.
		var hero_id := str(option.get("hero_id", ""))
		var hero_path := "res://resources/heroes/%s.tres" % hero_id
		if ResourceLoader.exists(hero_path):
			description = str(load(hero_path).get("description"))
		elif description.contains("\n"):
			description = description.substr(description.find("\n") + 1)
		if description != "" and description != benefit:
			parts.append(description)
	var progress := progress_text(option).replace("\n", " ")
	if progress != "" and parts.size() < 3:
		parts.append(progress)
	while parts.size() > 3:
		parts.remove_at(parts.size() - 1)
	return fix_orphan_punctuation("\n".join(parts))


static func card_secondary_text(option: Dictionary) -> String:
	var parts := PackedStringArray()
	if str(option.get("id", "")) == "upgrade_hero_weapon":
		var description := str(option.get("description", ""))
		var benefit := benefit_text(option)
		if description != "" and description != benefit and str(option.get("upgrade_kind", "")) not in ["weapon_damage", "weapon_cooldown", "weapon_projectiles"]:
			parts.append(description)
		var progress := progress_text(option).replace("\n", " ")
		var main := card_main_text(option)
		if progress != "" and not main.contains(progress):
			parts.append(progress)
	var link := synergy_text(option)
	if link != "":
		parts.append(link)
	if str(option.get("id", "")) == "recruit_hero":
		var description := str(option.get("description", ""))
		if description.begins_with("「") and description.contains("\n"):
			parts.append(description.substr(0, description.find("\n") + 1).strip_edges())
	return fix_orphan_punctuation(" ".join(parts))

