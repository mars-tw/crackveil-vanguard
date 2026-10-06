extends Node

const MOBILE := preload("res://scripts/services/mobile_tuning.gd")
const LOADER := preload("res://scripts/services/sprite_loader.gd")
const MENU := preload("res://scenes/ui/MainMenu.tscn")
const TILES := [
	"res://assets/art/r36/tile_stone.png", "res://assets/art/r36/tile_grass.png",
	"res://assets/art/r36/tile_frost.png", "res://assets/art/r36/tile_basalt.png",
	"res://assets/art/r38/tile_desert.png", "res://assets/art/r38/tile_coral.png",
	"res://assets/art/r38/tile_clockwork.png", "res://assets/art/r36/landmarks.png",
	"res://assets/art/r38/landmarks.png"
]
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	LOADER.texture_cache.clear()
	LOADER.prewarm_gameplay_textures()
	_check(not LOADER.texture_cache.has("res://assets/sprites/true_character_atlas.png"), "historical atlas eagerly loaded")
	for path in TILES:
		var texture := load(path) as Texture2D
		_check(texture != null and maxi(texture.get_width(),texture.get_height()) <= 1024, "runtime map texture exceeded1024: " + path)
	var canvas := SubViewport.new()
	canvas.size = Vector2i(390,844)
	add_child(canvas)
	MOBILE.set_device_hints_override_for_tests({"ua_mobile":true,"ua_phone":true,"touch_available":true,"primary_coarse":true,"mouse_available":false})
	var menu := MENU.instantiate()
	canvas.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(menu.background.get_script() == null, "phone menu initialized occluded terrain background")
	_check(menu.key_art.texture != null and maxi(menu.key_art.texture.get_width(),menu.key_art.texture.get_height()) <= 1536, "menu keyart exceeded1536")
	menu.queue_free()
	await get_tree().process_frame
	MOBILE.set_device_hints_override_for_tests({})
	if failures.is_empty():
		print("R41_RUNTIME_BUDGET_PASS no_historical_prewarm=true map_textures<=1024 phone_menu_no_terrain=true menu_keyart<=1536")
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func _check(value: bool, reason: String) -> void:
	if not value:
		failures.append(reason)
		push_error("R41_RUNTIME_BUDGET_FAIL: " + reason)
