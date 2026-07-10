extends Node

signal settings_changed

const SAVE_PATH := "user://crackveil_settings.cfg"

var damage_numbers_enabled: bool = true
var screen_shake_enabled: bool = true
var save_path: String = SAVE_PATH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func load_settings() -> void:
	_reset_runtime_defaults()
	var config := ConfigFile.new()
	var error := config.load(save_path)
	if error != OK:
		if FileAccess.file_exists(save_path):
			save_settings()
			_queue_load_failure_toast()
		return
	damage_numbers_enabled = bool(config.get_value("settings", "damage_numbers_enabled", damage_numbers_enabled))
	screen_shake_enabled = bool(config.get_value("settings", "screen_shake_enabled", screen_shake_enabled))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "damage_numbers_enabled", damage_numbers_enabled)
	config.set_value("settings", "screen_shake_enabled", screen_shake_enabled)
	config.save(save_path)


func set_damage_numbers_enabled(value: bool) -> void:
	if damage_numbers_enabled == value:
		return
	damage_numbers_enabled = value
	save_settings()
	settings_changed.emit()


func set_screen_shake_enabled(value: bool) -> void:
	if screen_shake_enabled == value:
		return
	screen_shake_enabled = value
	save_settings()
	settings_changed.emit()


func debug_use_save_path(path: String, reset: bool = true) -> void:
	save_path = path if path != "" else SAVE_PATH
	if reset:
		_reset_runtime_defaults()
		save_settings()
	else:
		load_settings()
	settings_changed.emit()


func _reset_runtime_defaults() -> void:
	damage_numbers_enabled = true
	screen_shake_enabled = true


func _queue_load_failure_toast() -> void:
	if GameManager != null and GameManager.has_method("queue_toast"):
		GameManager.queue_toast("設定檔載入失敗，已使用安全預設。")
