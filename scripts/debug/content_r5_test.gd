extends SceneTree

const ECHO=preload("res://scripts/services/echo_shard_breakdown.gd")
const SUPPORT=preload("res://scripts/services/support_report_model.gd")
var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	_test_shard_breakdown()
	_test_support_display_rows()
	_test_formation_verdicts()
	if failures.is_empty():
		print("R5_REGRESSION status=PASS checks=%d" % checks)
	else:
		printerr("R5_REGRESSION status=FAIL checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:failures.append(label)

func _test_shard_breakdown() -> void:
	_check_shard_case("calculated sources",{"elapsed_time":120.0,"gold":100,"kills":41,"level":9,"elites_killed":2,"boss_killed":true},42)
	_check_shard_case("under-minimum battle",{"elapsed_time":29.0,"gold":0,"kills":0,"level":1,"elites_killed":0,"boss_killed":false},0)
	_check_shard_case("30-second safety minimum",{"elapsed_time":30.0,"gold":0,"kills":0,"level":1,"elites_killed":0,"boss_killed":false},1)
	_check_shard_case("fixed QA increment",{"_fixed_echo_delta":3},3)

func _check_shard_case(label: String,summary: Dictionary,expected: int) -> void:
	var breakdown: Dictionary=ECHO.calculate(summary)
	var sum:=0
	for amount in breakdown.values():sum+=int(amount)
	_check(ECHO.total(summary)==expected,label+" formula total")
	_check(sum==expected,label+" itemized sources sum to award")

func _test_support_display_rows() -> void:
	var source: Array=[
		{"id":"captain","name":"隊長","healing":0,"prevented":0},
		{"id":"song","name":"歌者","healing":16,"prevented":0},
		{"id":"guard","name":"護衛","healing":0,"prevented":4},
		{"id":"scout","name":"斥候","healing":0,"prevented":0}
	]
	var visible: Array=SUPPORT.build(source)
	_check(visible.size()==3,"keep measured support cards and group zero rows")
	_check(visible[0].id=="song" and visible[1].id=="guard","rank actual healing/prevention above zeros")
	_check(visible[2].id=="support_zero_group","present zero-support members in one explicit row")
	_check(visible[2].member_ids==["captain","scout"],"zero-support member IDs remain inspectable")
	_check(visible[2].member_names==["隊長","斥候"],"zero-support names remain readable")

func _test_formation_verdicts() -> void:
	# The in-world verdict is a readout of the resolved impact receipt; each
	# wording must follow the measured hit/protection fields, never invent one.
	var relay: Node2D=load("res://scripts/services/formation_relay.gd").new()
	_check(relay.result_text({"formation":"ring","members":6,"hit":5,"protected":5,"reduced":50,"correct":true})=="圓陣護住 5 人・減傷 50","ring protection reports measured reduction")
	_check(relay.result_text({"formation":"wedge","members":3,"hit":0,"protected":0,"reduced":0,"correct":true})=="楔形對陣・全員避開","correct formation with no hits")
	_check(relay.result_text({"formation":"wedge","members":4,"hit":2,"protected":0,"reduced":0,"correct":false})=="錯陣・2/4 人中招","wrong formation reports measured hits")
	_check(relay.result_text({"formation":"scatter","members":5,"hit":1,"protected":0,"reduced":0,"correct":true})=="散兵對陣・1/5 人中招","correct formation still reports real hits")
	_check(relay.result_text({"formation":"ring","members":4,"hit":0,"protected":0,"reduced":0,"correct":false})=="全員避開・圓陣無法封合","avoided but wrong formation cannot seal")
	relay.free()
