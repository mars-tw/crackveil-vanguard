extends Node

signal settings_changed
signal audio_unlocked

const SAVE_PATH := "user://crackveil_audio.cfg"
const BUS_NAME := "Master"
const PLAYER_POOL_SIZE := 12
const SFX_PATHS: Dictionary = {
	"fire": "res://assets/audio/fire.wav",
	"hit": "res://assets/audio/hit.wav",
	"upgrade": "res://assets/audio/upgrade.wav",
	"contract": "res://assets/audio/contract.wav",
	"elite": "res://assets/audio/elite.wav",
	"death": "res://assets/audio/death.wav",
	"pulse": "res://assets/audio/pulse.wav",
	"pickup": "res://assets/audio/pickup.wav",
	"kill_thump": "res://assets/audio/kill_thump.wav",
	"combo": "res://assets/audio/combo.wav",
	"footstep": "res://assets/audio/footstep.wav",
	"boss_roar": "res://assets/audio/boss_roar.wav",
	"combo_milestone": "res://assets/audio/combo_milestone.wav",
	"boomerang_catch": "res://assets/audio/boomerang_catch.wav",
	"explosion": "res://assets/audio/explosion.wav",
	"ui_click": "res://assets/audio/ui_click.wav"
}
const SFX_ALIASES: Dictionary = {
	"attack_hit": "hit",
	"level_up": "upgrade",
	"recruit": "contract",
	"hurt": "hit",
	"boss": "boss_roar",
	"ui": "ui_click"
}
const SFX_COOLDOWNS: Dictionary = {
	"fire": 0.07,
	"hit": 0.045,
	"upgrade": 0.08,
	"contract": 0.12,
	"elite": 0.8,
	"death": 1.0,
	"pulse": 0.18,
	"pickup": 0.025,
	"kill_thump": 0.055,
	"combo": 0.18,
	"footstep": 0.045,
	"boss_roar": 1.2,
	"combo_milestone": 0.8,
	"boomerang_catch": 0.12,
	"explosion": 0.11,
	"ui_click": 0.035
}

var master_volume: float = 0.75
var muted: bool = false
var unlocked: bool = false
var players: Array[AudioStreamPlayer] = []
var next_player_index: int = 0
var last_play_msec: Dictionary = {}
var sfx_streams: Dictionary = {}
var audio_runtime_enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	audio_runtime_enabled = not _is_headless_runtime()
	if not audio_runtime_enabled:
		_apply_bus_settings()
		return
	_load_streams()
	_build_player_pool()
	_apply_bus_settings()
	get_tree().node_added.connect(_on_scene_node_added)
	call_deferred("_bind_existing_ui_buttons")


func _input(event: InputEvent) -> void:
	if unlocked:
		return
	if _is_unlock_event(event):
		unlock_audio()


func _exit_tree() -> void:
	for player in players:
		if player != null and is_instance_valid(player):
			player.stop()
			player.stream = null
	players.clear()
	sfx_streams.clear()


func unlock_audio() -> void:
	if unlocked:
		return
	unlocked = true
	audio_unlocked.emit()
	play_sfx("upgrade", true, -18.0)


func is_audio_unlocked() -> bool:
	return unlocked


func play_sfx(sfx_id: String, bypass_lock: bool = false, gain_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not audio_runtime_enabled:
		return
	var resolved_id := _resolve_sfx_id(sfx_id)
	if not sfx_streams.has(resolved_id):
		return
	if OS.has_feature("web") and not unlocked and not bypass_lock:
		return
	if muted or master_volume <= 0.001:
		return
	if not _cooldown_ready(resolved_id):
		return
	var player := _acquire_player()
	if player == null:
		return
	player.stream = sfx_streams[resolved_id] as AudioStream
	if player.stream == null:
		return
	player.volume_db = gain_db
	player.pitch_scale = clamp(pitch_scale, 0.4, 2.2)
	player.play()


func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	_apply_bus_settings()
	_save_settings()
	settings_changed.emit()


func set_muted(value: bool) -> void:
	muted = value
	_apply_bus_settings()
	_save_settings()
	settings_changed.emit()


func _build_player_pool() -> void:
	for child in get_children():
		child.queue_free()
	players.clear()
	for index in range(PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % index
		player.bus = BUS_NAME
		add_child(player)
		players.append(player)


func _load_streams() -> void:
	sfx_streams.clear()
	for sfx_id in SFX_PATHS.keys():
		var path := str(SFX_PATHS[sfx_id])
		var stream := load(path) as AudioStream
		if stream == null:
			stream = AudioStreamWAV.load_from_file(path)
		if stream == null:
			stream = _make_procedural_stream(str(sfx_id))
		if stream != null:
			sfx_streams[str(sfx_id)] = stream
	for alias_id in SFX_ALIASES.keys():
		var target_id := str(SFX_ALIASES[alias_id])
		if not sfx_streams.has(alias_id) and sfx_streams.has(target_id):
			sfx_streams[str(alias_id)] = sfx_streams[target_id]


func _resolve_sfx_id(sfx_id: String) -> String:
	if sfx_streams.has(sfx_id):
		return sfx_id
	return str(SFX_ALIASES.get(sfx_id, sfx_id))


func _make_procedural_stream(sfx_id: String) -> AudioStream:
	var sample_rate := 22050
	var duration := 0.16
	var base_freq := 520.0
	match sfx_id:
		"hit", "attack_hit", "hurt":
			duration = 0.09
			base_freq = 190.0
		"upgrade", "level_up":
			duration = 0.24
			base_freq = 660.0
		"contract", "recruit":
			duration = 0.18
			base_freq = 440.0
		"boss_roar", "boss":
			duration = 0.34
			base_freq = 96.0
		"ui_click", "ui":
			duration = 0.045
			base_freq = 880.0
	var sample_count := int(float(sample_rate) * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for index in range(sample_count):
		var t := float(index) / float(sample_rate)
		var decay := pow(1.0 - float(index) / maxf(1.0, float(sample_count)), 2.2)
		var wave := sin(TAU * base_freq * t) * 0.52 + sin(TAU * base_freq * 1.51 * t) * 0.22
		var value := int(clamp(wave * decay * 24000.0, -32768.0, 32767.0))
		if value < 0:
			value = 65536 + value
		data[index * 2] = value & 0xFF
		data[index * 2 + 1] = (value >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _acquire_player() -> AudioStreamPlayer:
	for player in players:
		if player != null and not player.playing:
			return player
	if players.is_empty():
		return null
	var player := players[next_player_index % players.size()]
	next_player_index += 1
	player.stop()
	return player


func _cooldown_ready(sfx_id: String) -> bool:
	var now := Time.get_ticks_msec()
	var cooldown_msec := int(round(float(SFX_COOLDOWNS.get(sfx_id, 0.0)) * 1000.0))
	var last := int(last_play_msec.get(sfx_id, -1000000))
	if now - last < cooldown_msec:
		return false
	last_play_msec[sfx_id] = now
	return true


func _apply_bus_settings() -> void:
	var bus_index := AudioServer.get_bus_index(BUS_NAME)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, muted)
	var safe_volume: float = max(master_volume, 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(safe_volume))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	master_volume = clamp(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	muted = bool(config.get_value("audio", "muted", muted))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "muted", muted)
	var error := config.save(SAVE_PATH)
	if error != OK:
		printerr("AUDIO_SETTINGS_SAVE_FAIL: %s" % error)
		if GameManager != null and GameManager.has_method("queue_toast"):
			GameManager.queue_toast("音量設定無法保存，請檢查瀏覽器儲存權限。")


func _is_headless_runtime() -> bool:
	return DisplayServer.get_name().to_lower() == "headless"


func _is_unlock_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventJoypadButton:
		return event.pressed
	return false


func _on_scene_node_added(node: Node) -> void:
	_bind_ui_button(node)


func _bind_existing_ui_buttons() -> void:
	var root := get_tree().root
	if root == null:
		return
	_bind_ui_buttons_recursive(root)


func _bind_ui_buttons_recursive(node: Node) -> void:
	_bind_ui_button(node)
	for child in node.get_children():
		_bind_ui_buttons_recursive(child)


func _bind_ui_button(node: Node) -> void:
	if not node is BaseButton:
		return
	var button := node as BaseButton
	if not button.pressed.is_connected(_on_ui_button_pressed):
		button.pressed.connect(_on_ui_button_pressed)


func _on_ui_button_pressed() -> void:
	play_sfx("ui_click", false, -8.0)
