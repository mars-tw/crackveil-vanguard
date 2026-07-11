extends Node

const SPRITE_LOADER := preload("res://scripts/services/sprite_loader.gd")
const VFX_PATHS: Array[String] = [
	"res://assets/vfx/kenney_particle/burst_arc_cyan.png",
	"res://assets/vfx/kenney_particle/burst_arc_ember.png",
	"res://assets/vfx/kenney_particle/burst_fire_cyan.png",
	"res://assets/vfx/kenney_particle/burst_fire_ember.png",
	"res://assets/vfx/kenney_particle/flare_cyan.png",
	"res://assets/vfx/kenney_particle/flare_ember.png",
	"res://assets/vfx/kenney_particle/level_column_cyan.png",
	"res://assets/vfx/kenney_particle/level_column_ember.png",
	"res://assets/vfx/kenney_particle/shockwave_cyan.png",
	"res://assets/vfx/kenney_particle/shockwave_ember.png",
	"res://assets/vfx/kenney_particle/smoke_ring_cyan.png",
	"res://assets/vfx/kenney_particle/smoke_ring_ember.png"
]
const AUDIO_PATHS: Array[String] = [
	"res://assets/audio/explosion.wav",
	"res://assets/audio/fire.wav",
	"res://assets/audio/hit.wav",
	"res://assets/audio/kill_thump.wav",
	"res://assets/audio/pickup.wav",
	"res://assets/audio/ui_click.wav",
	"res://assets/audio/upgrade.wav"
]


func _ready() -> void:
	for path in VFX_PATHS:
		var texture := load(path) as Texture2D
		if texture == null:
			_fail("missing VFX texture: " + path)
			return
		if texture.get_width() != 128 or texture.get_height() != 128:
			_fail("VFX texture exceeds compact 128px contract: " + path)
			return

	SPRITE_LOADER.prewarm_gameplay_textures()
	for path in VFX_PATHS:
		if not SPRITE_LOADER.texture_cache.has(path):
			_fail("VFX texture was not prewarmed: " + path)
			return

	for path in AUDIO_PATHS:
		var stream := load(path) as AudioStreamWAV
		if stream == null:
			_fail("missing WAV stream: " + path)
			return
		var file := FileAccess.open(path, FileAccess.READ)
		var header := file.get_buffer(44) if file != null else PackedByteArray()
		if header.size() < 44 or header.decode_u32(24) != 44100 or header.decode_u16(22) != 1 or header.decode_u16(34) != 16:
			_fail("WAV is not 44.1kHz 16-bit mono: " + path)
			return

	var audio_constants: Dictionary = AudioManager.get_script().get_script_constant_map()
	var sfx_paths: Dictionary = audio_constants.get("SFX_PATHS", {})
	for sfx_id in ["explosion", "ui_click"]:
		if not sfx_paths.has(sfx_id):
			_fail("AudioManager is missing M3 SFX id: " + sfx_id)
			return

	print("M3_VFX_TEXTURES=%d prewarmed=true size=128x128" % VFX_PATHS.size())
	print("M3_AUDIO_FILES=%d format=44100Hz/16bit/mono" % AUDIO_PATHS.size())
	print("M3_REGRESSION_PASS")
	get_tree().quit(0)


func _fail(message: String) -> void:
	printerr("M3_REGRESSION_FAIL: " + message)
	get_tree().quit(1)
