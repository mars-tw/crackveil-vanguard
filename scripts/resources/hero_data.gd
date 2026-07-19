class_name HeroData
extends Resource

@export var id: String = ""
@export var display_name: String = "未命名英雄"
@export var epithet: String = ""
@export_multiline var quote: String = ""
@export_multiline var description: String = ""
@export var body_color: Color = Color(0.35, 0.78, 1.0)
@export var core_color: Color = Color(0.88, 0.98, 1.0)
@export_file("*.png") var sprite_path: String = ""
@export var sprite_scale: float = 1.0
@export var max_hp: float = 100.0
@export var move_speed: float = 230.0
@export var hit_radius: float = 13.0
@export var pickup_radius: float = 92.0
@export var starting_weapon_ids: PackedStringArray = PackedStringArray()

@export_group("預留角色特性")
@export var passive_id: String = ""
@export var passive_value: float = 0.0
@export_multiline var passive_description: String = ""
