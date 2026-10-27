extends RefCounted

# Test runners select an isolated profile before autoload _ready(). Ordinary
# players keep their exact existing filenames. Transactions are never disabled.
static func path(original: String) -> String:
	var profile:=OS.get_environment("CV_QA_PROFILE")
	if profile.is_empty(): return original
	for character in profile:
		if not (character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"): return original
	return "user://qa_%s_%s" % [profile,original.trim_prefix("user://")]

static func active() -> bool:
	return not OS.get_environment("CV_QA_PROFILE").is_empty()
