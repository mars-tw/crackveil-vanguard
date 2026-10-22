"""Paired real Arena runs. One Godot process at a time, Dummy audio."""
from pathlib import Path
import argparse,json,subprocess
from content_r2_pipeline import GODOT, ROOT, OUT
p=argparse.ArgumentParser();p.add_argument('--stage');p.add_argument('--policy');a=p.parse_args()
results=[]
for stage in ([a.stage] if a.stage else ['moon','garden','ember']):
 for policy in ([a.policy] if a.policy else ['active','idle']):
  cmd=[str(GODOT),'--headless','--audio-driver','Dummy','--fixed-fps','60','--path','.', 'res://scenes/debug/ContentR2Run.tscn','--','stage='+stage,'policy='+policy,'seed=55210']
  result=subprocess.run(cmd,cwd=ROOT,capture_output=True,timeout=390,creationflags=subprocess.CREATE_NO_WINDOW)
  log=(result.stdout+result.stderr).decode('utf-8',errors='replace')
  target=OUT/'tests/runs';target.mkdir(parents=True,exist_ok=True)
  (target/(stage+'-'+policy+'.txt')).write_text(log,encoding='utf-8')
  row=json.loads((target/(stage+'-55210-default-'+policy+'.json')).read_text(encoding='utf-8'))
  valid=result.returncode==0 and 'ERROR:' not in log
  valid=valid and (row['outcome']=='win' and row['seals']==3 and row['history'][-1]['time']>=90 and all(r['cycles']>=2 for r in row['history']) if policy=='active' else not row['campaign_clear'] and row['seals']==0 and row['outcome']!='win')
  valid=valid and sum(c['kills'] for c in row['contributions'].values())==row['kills']
  if policy=='active':valid=valid and row['boss_half']>=0 and any(h['reason']=='boss_guard' and h.get('recoveries',0)>=2 and h.get('impacts',0)>=2 and h['time']>=row['boss_half']+1.99 and h.get('death_finalized_at',-1)>=h.get('last_recovery_at',0) for h in row['guards'])
  row['status']='VERIFIED' if valid else 'BLOCKED';row['command']=cmd;row['exit_code']=result.returncode
  results.append(row)
  (target/(stage+'-55210-default-'+policy+'.json')).write_text(json.dumps(row,ensure_ascii=False,indent=2),encoding='utf-8')
  print(stage,policy,row['status'],row['outcome'],'seals='+str(row['seals']),'seconds='+str(round(row['time'],2)),flush=True)
all_results=[json.loads(p.read_text(encoding='utf-8')) for p in sorted((OUT/'tests/runs').glob('*-55210-default-*.json'))]
(OUT/'tests/paired-runs.json').write_text(json.dumps(all_results,ensure_ascii=False,indent=2),encoding='utf-8')
raise SystemExit(0 if all(r['status']=='VERIFIED' for r in results) else 1)
