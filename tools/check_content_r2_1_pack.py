"""Decode a release pack in an isolated folder and prove QA fixtures excluded."""
import hashlib,json,subprocess
from content_r2_pipeline import ROOT,TMP,BUILD,OUT,GODOT
assert OUT==ROOT/'docs/content/r2-1', 'set CONTENT_ROUND=r2-1'
work=TMP/'pack-isolation'
work.mkdir(parents=True,exist_ok=True)
paths=['res://scenes/debug/'+p for p in ['ContentR2Review.tscn','ContentR2Run.tscn','ContentR2Test.tscn','ContentR21Review.tscn','ContentR21Test.tscn']]
paths+=['res://scripts/debug/'+p for p in ['content_r2_review.gd','content_r2_run.gd','content_r2_test.gd','content_r2_1_review.gd']]
script=work/'probe.gd'
script.write_text('''extends SceneTree
func _initialize() -> void:
 var leaked: Array[String] = []
 for path in %s:
  if ResourceLoader.exists(path): leaked.append(path)
 var hud = load("res://scripts/ui/hud.gd")
 var banner = load("res://scripts/ui/r33_loot_banner.gd")
 var relay = load("res://scripts/services/formation_relay.gd")
 var valid = leaked.is_empty() and hud != null and banner != null and relay != null
 print("R21_PACK="+JSON.stringify({"status":"VERIFIED" if valid else "BLOCKED","leaked":leaked,"checks":12,"version":ProjectSettings.get_setting("application/config/version"),"physical_project_fallback":false}))
 quit(0 if valid else 1)
'''%json.dumps(paths),encoding='utf-8')
pack=BUILD/'release/index.pck'
command=[str(GODOT),'--headless','--audio-driver','Dummy','--path',str(work),'--main-pack',str(pack),'--script',str(script)]
r=subprocess.run(command,cwd=work,capture_output=True,timeout=45,creationflags=subprocess.CREATE_NO_WINDOW)
log=(r.stdout+r.stderr).decode('utf-8',errors='replace').replace('\r\n','\n').replace('\r','\n').rstrip()+'\n'
(OUT/'tests/pack-isolation.txt').write_text(log,encoding='utf-8',newline='\n')
assert r.returncode==0 and 'ERROR:' not in log,log[-2000:]
result=json.loads(next(line.split('=',1)[1] for line in log.splitlines() if line.startswith('R21_PACK=')))
result.update({'command':command,'pack_sha256':hashlib.sha256(pack.read_bytes()).hexdigest(),'source_manifest_sha256':hashlib.sha256((OUT/'tests/source-hashes.json').read_bytes()).hexdigest()})
(OUT/'tests/pack-isolation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
