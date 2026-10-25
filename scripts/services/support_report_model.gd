class_name SupportReportModel
extends RefCounted

## Sort actual nonzero support first. Keep every zero in a readable grouped row.
static func build(rows: Array) -> Array:
	var active: Array=[]
	var inactive: Array=[]
	for source in rows:
		var row: Dictionary=source
		if float(row.get("healing",0.0))+float(row.get("prevented",0.0))>0.001:
			active.append(row)
		else:
			inactive.append(row)
	active.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var a_value:=float(a.get("healing",0.0))+float(a.get("prevented",0.0))
		var b_value:=float(b.get("healing",0.0))+float(b.get("prevented",0.0))
		if not is_equal_approx(a_value,b_value):return a_value>b_value
		return str(a.get("id",""))<str(b.get("id","")))
	if not inactive.is_empty():
		var ids: Array[String]=[]
		var names: Array[String]=[]
		for row in inactive:
			ids.append(str(row.get("id","")))
			names.append(str(row.get("name",row.get("id","隊員"))))
		active.append({"id":"support_zero_group","name":"未觸發隊員","member_ids":ids,"member_names":names,"healing":0,"prevented":0})
	return active
