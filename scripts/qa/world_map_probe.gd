extends RefCounted

# Web-only QA world-map receipt (cv_r22_test). Not exported to phone builds.
static func enabled() -> bool:
	return bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('cv_r22_test') === '1'", true))

static func publish(state: Dictionary) -> void:
	JavaScriptBridge.eval("window.__cvR34WorldMap = %s" % JSON.stringify(state), true)
