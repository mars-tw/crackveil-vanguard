"""Run only the CI regressions relevant to the R2.1 notification/modal patch."""
from pathlib import Path
import hashlib, json, os, subprocess, sys
from content_r2_pipeline import ROOT, OUT, GODOT

assert OUT == ROOT/'docs/content/r2-1', 'set CONTENT_ROUND=r2-1'
folder=OUT/'tests/gates'
folder.mkdir(parents=True,exist_ok=True)
scenes=['ContentR21Test','ContentR1Test','ContentR2Test','R14RegressionTest','R29MenuModalTest','R39MobileHUDTest','R42FormationTest','R43MobileTacticsTest']
results=json.loads((folder/'summary.json').read_text(encoding='utf-8')) if len(sys.argv)>1 else []
if len(sys.argv)>1:
    assert all(scene in scenes for scene in sys.argv[1:]), 'unknown CI scene'
    scenes=[scene for scene in scenes if scene in sys.argv[1:]]
env=os.environ.copy()
env['CV_TEST_EVIDENCE_DIR']='res://docs/content/r2-1/tests'
for scene in scenes:
    env['CV_TEST_EVIDENCE_DIR']='res://docs/content/r2-1/tests/r1' if scene=='ContentR1Test' else 'res://docs/content/r2-1/tests'
    command=[str(GODOT),'--headless','--audio-driver','Dummy','--fixed-fps','60','--path',str(ROOT),f'res://scenes/debug/{scene}.tscn']
    result=subprocess.run(command,cwd=ROOT,env=env,capture_output=True,creationflags=subprocess.CREATE_NO_WINDOW,timeout=300)
    log=(result.stdout+result.stderr).decode('utf-8',errors='replace').replace('\r\n','\n').replace('\r','\n').rstrip()+'\n'
    (folder/(scene+'.txt')).write_text(log,encoding='utf-8',newline='\n')
    success=result.returncode==0 and 'SCRIPT ERROR:' not in log and 'ERROR:' not in log and ('PASS' in log or 'CONTENT_R21_VERIFIED' in log)
    results=[row for row in results if row['scene']!=scene]
    results.append({'scene':scene,'command':command,'exit_code':result.returncode,'status':'VERIFIED' if success else 'BLOCKED','log_sha256':hashlib.sha256((folder/(scene+'.txt')).read_bytes()).hexdigest()})
    (folder/'summary.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    print(scene,results[-1]['status'],flush=True)
    if not success: raise SystemExit(1)
