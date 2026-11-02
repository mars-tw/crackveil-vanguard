extends RefCounted

# R33: with ?cv_r19_test=1&cv_start_stage=<id> the review bot opens a later
# stage directly. Without the test flag the parameter is ignored.
static func requested() -> String:
	var value: Variant = JavaScriptBridge.eval("(()=>{const q=new URLSearchParams(location.search);return q.get('cv_r19_test')==='1'?(q.get('cv_start_stage')||''):''})()", true)
	return value if value is String else ""
