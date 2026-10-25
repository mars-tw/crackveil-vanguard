extends Node

const CATALOG:=preload("res://scripts/services/starting_build_catalog.gd")
var checks:=0
var failures: Array[String]=[]
var evidence: Array[Dictionary]=[]

func _ready() -> void:
	process_mode=PROCESS_MODE_ALWAYS
	call_deferred("_run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("CONTENT_R4_FAIL "+message)

func _geometry(controls: Dictionary,view: Vector2) -> void:
	for id in controls:
		var button: Control=controls[id]
		var rect:=button.get_global_rect()
		check(Rect2(Vector2.ZERO,view).encloses(rect),"control outside viewport: "+str(id)+str(rect)+str(view))
		check(rect.size.x>=43.9 and rect.size.y>=43.9,"small control "+str(id))
		if button is Button:
			var font:=button.get_theme_font("font")
			var font_size:=button.get_theme_font_size("font_size")
			var text_size:=font.get_multiline_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
			for state in ["normal","hover","focus","pressed","disabled"]:
				var required: Vector2=text_size+button.get_theme_stylebox(state).get_minimum_size()
				check(required.x<=rect.size.x+1 and required.y<=rect.size.y+1,"button text/style clips "+str(id)+"/"+state+str(required)+str(rect.size))
		for other in controls:
			if str(other)>str(id):check(not rect.intersects(controls[other].get_global_rect()),"overlapping controls: "+str(id)+"/"+str(other))

func _fits(label: Label,context: String) -> void:
	check(label.get_line_count()<=label.get_visible_line_count(),"clipped lines "+context+" "+label.text+" "+str(label.size))
	if label.autowrap_mode==TextServer.AUTOWRAP_OFF:
		check(label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x+1,"clipped width "+context+" "+label.text)

func _separate(labels: Array,context: String) -> void:
	for i in range(labels.size()-1):
		if labels[i].text!="" and labels[i+1].text!="":
			var first_rect: Rect2=labels[i].get_global_rect()
			var second_rect: Rect2=labels[i+1].get_global_rect()
			check(not first_rect.intersects(second_rect),"text cards overlap "+context+" first="+str(first_rect)+" second="+str(second_rect))

func _run() -> void:
	AudioManager.set_muted(true)
	check("r4" in MetaProgress.save_path and "r4" in AudioManager.save_path,"profile isolation missing before ready")
	for view_size in [Vector2i(320,568),Vector2i(844,390),Vector2i(1366,600)]:
		var view:=SubViewport.new()
		view.size=view_size
		view.disable_3d=true
		add_child(view)
		var prep:=preload("res://scripts/ui/build_preparation.gd").new()
		view.add_child(prep)
		var font_records: Array=[]
		for scale in [0,1,2]:
			PlayerSettings.set_ui_scale_index(scale)
			prep.open()
			for tab in range(1,4):
				prep.tab=tab
				for i in range(5):
					prep.index=i
					prep._refresh()
					await get_tree().process_frame
					_geometry(prep.controls,Vector2(view_size))
					check(prep.current_ids.size()==3 and prep.candidate_ids==CATALOG.roster(MetaProgress.starting_team,CATALOG.NODES[(tab-1)*5+i].id),"preview is not actual final roster")
					check(prep.overview_buttons.all(func(button):return button.visible),"five choices are not simultaneous")
					for label in [prep.heading,prep.rule_label,prep.progress_label,prep.wallet,prep.final_label,prep.preview_label,prep.title,prep.detail,prep.state_label,prep.swap_label]:_fits(label,"prep %s scale %d" % [view_size,scale])
					for label in prep.portrait_names+prep.preview_names:_fits(label,"actual roster")
				prep.index=0
			font_records.append({"index":scale,"multiplier":PlayerSettings.get_ui_scale_multiplier(),"detail_font":prep.detail.get_theme_font_size("font_size"),"roster_font":prep.portrait_names[0].get_theme_font_size("font_size"),"button_font":prep.controls.action.get_theme_font_size("font_size"),"overview_font":prep.overview_buttons[0].get_theme_font_size("font_size")})
			prep._close()
		var screen:=preload("res://scripts/ui/stage_victory_screen.gd").new()
		view.add_child(screen)
		var rows: Array=[]
		var party_ids: Array[String]=["rift_captain","orbit_guard","arc_scout","echo_singer","ember_grenadier","void_weaver","rift_sniper","rift_shepherd","pulse_artificer"]
		for id in party_ids:
			var hero: Resource=load("res://resources/heroes/%s.tres" % id)
			rows.append({"id":id,"name":str(hero.get("display_name")),"damage":1200,"taken":42,"kills":18,"healing":45,"prevented":19})
		screen.show_summary({"elapsed_time":112,"kills":100,"squad_alive":8,"squad_total":9,"contribution_rows":rows,"starting_build":{"team":"escort","node":"bond_harmony","benefits":{"healing":22}},"starting_build_text":"星盾護送｜和聲救援\n護圈額外回復 22"})
		await get_tree().process_frame
		_geometry(screen.controls,Vector2(view_size))
		for stage in preload("res://scripts/services/stage_catalog.gd").STAGES:
			screen.title_label.text=stage.name+"・通關"
			_fits(screen.title_label,"real stage title")
		for label in [screen.summary_label,screen.gain_label,screen.progress_label,screen.page_label]:_fits(label,"result core")
		check(not screen.summary_scroll.get_global_rect().intersects(screen.gain_label.get_global_rect()),"result summary viewport overlaps actual gain %s" % view_size)
		check(not screen.gain_label.get_global_rect().intersects(screen.progress_label.get_global_rect()),"result gain overlaps progress %s" % view_size)
		check(screen.summary_label.text.contains("存活 8/9") and screen.gain_label.text.contains("22"),"result core omitted outcome or actual benefit")
		screen.rows=[{"id":"solar_lancer","damage":123,"healing":0,"prevented":0}]
		for id in ["crew_guard","crew_scout","crew_gunner","crew_shepherd","bond_construct","bond_reserve","spec_collect"]:
			var gain: String=screen._measured_gain(CATALOG.node(id),{"shield_damage":0,"alternative_hold":0,"hymn_casts":0})
			check(not gain.contains("未觸發"),"missing event counters mislabel actual roster/passive as untriggered "+id)
		check(screen._measured_gain(CATALOG.node("crew_guard"),{}).contains("123"),"actual roster output missing from gain")
		check(screen._measured_gain(CATALOG.node("spec_shield"),{"shield_damage":0}).contains("未觸發"),"zero actual event was invented")
		check(screen._measured_gain(CATALOG.node("spec_shield"),{"shield_damage":42}).contains("42"),"real event count missing")
		screen.displayed_summary["starting_mode"]="endless"
		check(screen._measured_gain(CATALOG.node("spec_escort"),{"alternative_hold":12}).contains("無盡不再觸發"),"endless inactive specialization claims active benefit")
		screen.displayed_summary.erase("starting_mode")
		screen.rows=rows
		var seen_ids: Array[String]=[]
		for tab in range(3):
			screen.tab=tab
			for page in range(screen._page_count()):
				screen.page=page;screen._refresh()
				await get_tree().process_frame
				for label in screen.cards:_fits(label,"role cards %s" % view_size)
				_separate(screen.cards,"result max font")
				if tab==0:
					for card in screen.cards:
						if not card.visible or card.text.is_empty():continue
						var displayed: String=card.text.split("\n")[0]
						for row in rows:
							if row.name==displayed:seen_ids.append(row.id)
		check(seen_ids==party_ids,"actual nine hero cards omitted/duplicated IDs on pagination")
		var journal:=preload("res://scripts/ui/r4_battle_journal.gd").new()
		view.add_child(journal)
		for i in range(20):journal.record("自動強化：招募星環護衛","recruit")
		for i in range(7):journal.record("裝備回收 %d" % i,"loot")
		check(journal.total==27 and journal.entries.size()==8 and journal.entries[0].count==20,"journal lost facts or aggregates")
		for slot in ["core","guard","boots"]:
			for rarity in range(4):
				var item: Dictionary=preload("res://scripts/services/equipment_catalog.gd").make_item(slot,rarity,20,1)
				journal.record("已裝備・%s\n%s" % [item.name,item.description],"loot")
		# Explicit text-format fixture for a long clock/count, not gameplay data.
		journal.entries[-1]["count"]=99999
		journal.entries[-1]["last"]=599999
		journal.open()
		check(GameManager.system_pause_owners.has("battle_journal"),"journal did not pause safely")
		for page in range(journal._pages()):
			journal.page=page;journal._refresh()
			await get_tree().process_frame
			for label in journal.facts:_fits(label,"journal")
			_separate(journal.facts,"all 12 actual equipment descriptions at max font")
		journal.close()
		check(not GameManager.system_pause_owners.has("battle_journal"),"journal retained pause")
		evidence.append({"viewport":[view_size.x,view_size.y],"node_previews":45,"scale_fonts":font_records,"max_result_font":screen.summary_label.get_theme_font_size("font_size"),"max_journal_font":journal.facts[0].get_theme_font_size("font_size"),"result_rows":9,"paged_ids":seen_ids,"roles_per_page":screen.page_capacity,"journal_facts":journal.total,"actual_equipment_descriptions":12,"text_format_fixture":{"count":99999,"seconds":599999},"failures":failures.size()})
		view.queue_free()
		await get_tree().process_frame
	await _battle_event_chains()
	await _actual_roster_result()
	var result:={"status":"VERIFIED" if failures.is_empty() else "BLOCKED","checks":checks,"failures":failures,"viewports":evidence,"event_chains":["set_formation","recruit_hero/recompute_bonds","actual pressure warning","actual loot signal"],"fixture":"runtime UI, real ledger snapshots and isolated real persistent QA profile; no natural-play claim"}
	DirAccess.make_dir_recursive_absolute("res://docs/content/r4/tests")
	var file:=FileAccess.open("res://docs/content/r4/tests/mechanics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("CONTENT_R4_%s checks=%d failures=%d" % [result.status,checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _battle_event_chains() -> void:
	GameManager.run_mode="campaign"
	GameManager.selected_stage_id="moon"
	GameManager.pending_starting_formal=false
	var view:=SubViewport.new()
	view.size=Vector2i(844,390)
	add_child(view)
	var arena:=preload("res://scenes/arena/Arena.tscn").instantiate()
	view.add_child(arena)
	await get_tree().process_frame
	GameManager.set_process(false)
	arena.get_node("EnemySpawner").set_process(false)
	var hud: Node=arena.get_node("HUD")
	var squad: Node=GameManager.squad_manager
	var journal: Node=hud.battle_journal
	var count: int=journal.total
	check(squad.set_formation("ring",true),"real formation did not switch")
	check(journal.total==count+1 and journal.entries[-1].kind=="formation","real formation direct source lost or duplicated notice")
	count=journal.total
	GameManager.show_toast("自動強化：招募星環護衛")
	check(journal.total==count+1 and not hud.has_urgent_toast(),"ordinary recruit misclassified by hero name")
	count=journal.total
	check(squad.recruit_hero("echo_singer"),"actual singer recruit failed")
	check(journal.total==count+1 and journal.entries[-1].kind=="bond","real recompute_bonds did not record exactly once")
	hud._process(0)
	check(journal.total==count+1,"frame poll duplicated actual bond event")
	count=journal.total
	GameManager.loot_director.loot_collected.emit({"name":"裂隙護符","description":"最大生命 +5"},{},true)
	check(journal.total==count+1 and journal.entries[-1].kind=="loot" and not hud.root.get_node("LootBanner").active,"real loot still used battle-covering banner or lost fact")
	var relay: Node=GameManager.tactical_director.relay
	for i in range(3):
		relay.pressure.configure(relay.anchor,i)
		relay.pressure.begin()
		hud._process(0)
		check(hud.has_urgent_toast() and hud.toast_panel.visible,"real pressure warning swallowed")
		arena.get_node("EncounterLandmarks")._process(0)
		check(arena.get_node("EncounterLandmarks").composition==["front","pincer","artillery"][i],"actual encounter has wrong landmark composition")
	for enemy in get_tree().get_nodes_in_group("enemies"):enemy.set_physics_process(false)
	for member in squad.get_members():member.set_physics_process(false)
	squad.set_process(false)
	var total_before: int=squad.recruited_once.size()
	var fallen: Node=squad.get_member_by_id("orbit_guard")
	fallen.invulnerability_timer=0
	fallen.take_damage(99999,fallen.global_position+Vector2.RIGHT)
	for frame in range(90):await get_tree().process_frame
	check(not squad.member_ids.has("orbit_guard"),"actual death did not remove fallen follower")
	var actual: Dictionary=GameManager._summary_with_echo({"elapsed_time":0,"kills":0})
	check(actual.squad_total==total_before and actual.squad_alive==total_before-1,"result denominator dropped fallen party hero")
	check(actual.contribution_rows.any(func(row):return row.id=="orbit_guard"),"fallen hero vanished from paginated result")
	GameManager.game_running=false
	view.queue_free()
	await get_tree().process_frame


func _actual_roster_result() -> void:
	if not MetaProgress.starting_owned.has("crew_guard"):check(MetaProgress.purchase_starting_node("crew_guard"),"real free roster unlock failed")
	check(MetaProgress.equip_starting_node("crew_guard"),"real roster equip failed")
	GameManager.prepare_starting_build()
	var view:=SubViewport.new()
	view.size=Vector2i(844,390)
	add_child(view)
	var arena:=preload("res://scenes/arena/Arena.tscn").instantiate()
	view.add_child(arena)
	await get_tree().process_frame
	GameManager.set_process(false)
	arena.get_node("EnemySpawner").set_process(false)
	var lancer: Node=GameManager.squad_manager.get_member_by_id("solar_lancer")
	check(is_instance_valid(lancer),"actual crew_guard roster omitted solar lancer")
	var enemy: Node=EntityFactory.spawn_enemy("r4_roster_result",{"max_hp":1000,"speed":0,"damage":0,"xp":0,"gold":0,"radius":10},lancer.global_position+Vector2(20,0))
	var applied: float=enemy.take_damage(23,lancer.global_position)
	GameManager.record_weapon_damage(lancer,"solar_piercer",applied,"",enemy)
	check(applied>0 and GameManager.contribution_row("solar_lancer").damage>0,"actual target damage did not reach weapon ledger")
	check(GameManager.starting_benefits.values().all(func(value):return float(value)==0),"roster fixture did not exercise zero event counters")
	var summary: Dictionary=GameManager._summary_with_echo({"elapsed_time":0,"kills":0})
	var screen: Node=arena.get_node("StageVictoryScreen")
	screen.show_summary(summary)
	check(screen.gain_label.text.contains(str(int(applied))) and not screen.gain_label.text.contains("未觸發"),"formal summary overwrote real roster first-screen gain")
	GameManager.game_running=false
	view.queue_free()
	await get_tree().process_frame
