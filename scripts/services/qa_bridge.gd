extends RefCounted

# Store builds for phones are exported without res://scripts/qa/ (see
# export_presets.cfg), so every call here is a no-op on iOS and Android and the
# QA probe code is not in those binaries at all. Web QA builds keep the folder.
const QA_DIR := "res://scripts/qa/"
static var _scripts: Dictionary = {}

static func _qa(name: String) -> Script:
	if _scripts.has(name):
		return _scripts[name]
	var path := QA_DIR + name + ".gd"
	var script: Script = load(path) if ResourceLoader.exists(path) else null
	_scripts[name] = script
	return script

static func publish(scope: String, viewport_size: Vector2, controls: Dictionary, flags: Dictionary = {}) -> void:
	if not OS.has_feature("web"):
		return
	var probe := _qa("web_reachability_probe")
	if probe != null:
		probe.publish(scope, viewport_size, controls, flags)

static func save_path(default_path: String) -> String:
	var profile := _qa("qa_profile")
	return str(profile.path(default_path)) if profile != null else default_path

static func qa_active() -> bool:
	var profile := _qa("qa_profile")
	return profile != null and bool(profile.active())

static func runtime(hud: Node, stats: Dictionary) -> void:
	if not OS.has_feature("web"):
		return
	var probe := _qa("hud_runtime_probe")
	if probe != null:
		probe.publish(hud, stats)

static func world_map_enabled() -> bool:
	if not OS.has_feature("web"):
		return false
	var probe := _qa("world_map_probe")
	return probe != null and bool(probe.enabled())

static func world_map_publish(state: Dictionary) -> void:
	var probe := _qa("world_map_probe")
	if probe != null:
		probe.publish(state)
