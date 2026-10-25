class_name EchoShardBreakdown
extends RefCounted

## The itemized, player-visible explanation for MetaProgress.calculate_run_shards.
static func calculate(summary: Dictionary) -> Dictionary:
	if summary.has("_fixed_echo_delta"):
		return {"驗證固定增量":max(0,int(summary.get("_fixed_echo_delta",0)))}
	var elapsed:=float(summary.get("elapsed_time",0.0))
	var gold:=int(summary.get("gold_earned",summary.get("gold",0)))
	var kills:=int(summary.get("kills",0))
	var level:=int(summary.get("level",1))
	var elites:=int(summary.get("elites_killed",0))
	var boss_killed:=bool(summary.get("boss_killed",false))
	var result: Dictionary={
		"金幣":int(floor(float(gold)*0.25)),
		"擊殺":int(floor(float(kills)/20.0)),
		"等級":int(floor(float(level)/3.0)),
		"菁英":elites*2,
		"Boss":8 if boss_killed else 0
	}
	var raw_total:=0
	for amount in result.values():raw_total+=int(amount)
	if elapsed>=30.0 and raw_total==0:result["出擊保底"]=1
	return result


static func total(summary: Dictionary) -> int:
	var amount:=0
	for value in calculate(summary).values():amount+=int(value)
	return amount
