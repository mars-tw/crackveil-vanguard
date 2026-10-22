extends Node

func _ready() -> void:
	call_deferred("_probe")

func _probe() -> void:
	PlayerSettings.set_ui_scale_index(2)
	var view:=SubViewport.new()
	view.size=Vector2i(844,390)
	add_child(view)
	var journal:=preload("res://scripts/ui/r4_battle_journal.gd").new()
	view.add_child(journal)
	var catalog:=preload("res://scripts/services/equipment_catalog.gd")
	for slot in ["core","guard","boots"]:
		var item:=catalog.make_item(slot,3,20,1)
		journal.record("已裝備・%s\n%s" % [item.name,item.description],"loot")
	journal.open()
	await get_tree().process_frame
	var rows:=[]
	var okay:=true
	for i in range(3):
		var label: Label=journal.facts[i]
		rows.append({"lines":label.get_line_count(),"visible_lines":label.get_visible_line_count(),"height":label.size.y,"allocated_height":(journal.panel.size.y-112)/3-6})
		if label.get_line_count()>label.get_visible_line_count():okay=false
		if i<2 and label.get_global_rect().intersects(journal.facts[i+1].get_global_rect()):okay=false
	print("R4_JOURNAL_EQUIPMENT="+JSON.stringify({"status":"VERIFIED" if okay else "BLOCKED","rows":rows,"profile":MetaProgress.save_path}))
	journal.close()
	get_tree().quit(0 if okay else 1)
