"""Prove that the actual release pack excludes all R2 QA entry points."""
from pathlib import Path
import json,subprocess
from content_r2_pipeline import ROOT, TMP, BUILD, OUT, GODOT
work=TMP/'r2-isolation';work.mkdir(parents=True,exist_ok=True)
script=work/'probe.gd'
paths=['res://scenes/debug/ContentR2Review.tscn','res://scenes/debug/ContentR2Run.tscn','res://scenes/debug/ContentR2Test.tscn','res://scripts/debug/content_r2_review.gd','res://scripts/debug/content_r2_run.gd','res://scripts/debug/content_r2_test.gd']
script.write_text('''extends SceneTree
func _initialize() -> void:
 var leaked: Array[String] = []
 for path in %s:
  if ResourceLoader.exists(path): leaked.append(path)
 print("R2_PACK="+JSON.stringify({"status":"VERIFIED" if leaked.is_empty() else "BLOCKED","leaked":leaked,"checks":6}))
 quit(0 if leaked.is_empty() else 1)
'''%json.dumps(paths),encoding='utf-8')
cmd=[str(GODOT),'--headless','--audio-driver','Dummy','--path',str(work),'--main-pack',str(BUILD/'release/index.pck'),'--script',str(script)]
r=subprocess.run(cmd,cwd=work,capture_output=True,timeout=45,creationflags=subprocess.CREATE_NO_WINDOW)
log=(r.stdout+r.stderr).decode('utf-8',errors='replace')
(OUT/'tests/r2-pack-isolation.txt').write_text(log,encoding='utf-8')
assert r.returncode==0 and 'ERROR:' not in log,log[-2000:]
result=json.loads(next(line.split('=',1)[1] for line in log.splitlines() if line.startswith('R2_PACK=')))
(OUT/'tests/r2-pack-isolation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
