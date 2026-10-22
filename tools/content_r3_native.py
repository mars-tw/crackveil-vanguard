"""Silent native CI in a copied evidence tree and isolated Windows profiles.

Runtime/assets are read through junctions; docs are independent copies so the
unchanged legacy test writers cannot overwrite historical receipts.
"""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,time

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/content/r3'
TMP=ROOT/'.audit-tmp/content-r3'
SANDBOX=TMP/'regression-project'
GODOT=Path.home()/'.codex/tools/godot-4.7-stable/Godot_v4.7-stable_win64_console.exe'

def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf8',newline='\n')

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def source_state():
    paths=[p for folder in ['scripts','scenes','resources','assets/fonts'] for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix in {'.gd','.gdshader','.tscn','.tres','.otf'}]
    paths += [ROOT/name for name in ['project.godot','export_presets.cfg','.github/workflows/deploy-web.yml']]
    return {p.relative_to(ROOT).as_posix():{'sha256':sha(p),'mtime_ns':p.stat().st_mtime_ns,'bytes':p.stat().st_size} for p in sorted(paths)}

def junction(link,target):
    if link.exists():
        assert link.resolve()==target.resolve(),str(link)
        return
    escaped=lambda p:str(p).replace("'","''")
    command=f"New-Item -ItemType Junction -Path '{escaped(link)}' -Target '{escaped(target)}' | Out-Null"
    subprocess.run(['powershell','-NoProfile','-NonInteractive','-Command',command],check=True,capture_output=True,creationflags=subprocess.CREATE_NO_WINDOW)

def prepare():
    SANDBOX.mkdir(parents=True,exist_ok=True)
    for folder in ['scripts','scenes','resources','assets','web','native','tools','.godot']:
        junction(SANDBOX/folder,ROOT/folder)
    for path in ROOT.iterdir():
        if path.is_file(): shutil.copyfile(path,SANDBOX/path.name)
    target=SANDBOX/'docs'
    if not target.exists():
        print('copying independent historical docs for unchanged CI writers',flush=True)
        shutil.copytree(ROOT/'docs',target)
    print('sandbox ready',flush=True)

def execute(scene,job='suite',project=SANDBOX,extra=None,timeout=180):
    profile=TMP/'native-profiles'/job/scene
    env=os.environ.copy()
    env['CV_QA_PROFILE']='content_r3_'+job
    for name,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local')]:
        path=profile/folder
        path.mkdir(parents=True,exist_ok=True)
        env[name]=str(path)
    command=[str(GODOT),'--headless','--audio-driver','Dummy','--fixed-fps','60','--path',str(project),f'res://scenes/debug/{scene}.tscn']+(extra or [])
    before=source_state()
    start=time.monotonic()
    try:
        result=subprocess.run(command,cwd=project,env=env,capture_output=True,timeout=timeout,creationflags=subprocess.CREATE_NO_WINDOW)
        code=result.returncode;raw=result.stdout+result.stderr
    except subprocess.TimeoutExpired as error:
        code=124;raw=(error.stdout or b'')+(error.stderr or b'')+b'\nRUNNER_TIMEOUT\n'
    log=raw.decode('utf8',errors='replace').replace('\r\n','\n').replace('\r','\n').rstrip()+'\n'
    folder=OUT/'tests'/('gates' if job=='suite' else job)
    folder.mkdir(parents=True,exist_ok=True)
    path=folder/(scene+'.txt')
    path.write_text(log,encoding='utf8',newline='\n')
    after=source_state()
    stamp=folder/(scene+'-source.json')
    write(stamp,{'before':before,'after':after,'unchanged':before==after})
    good=code==0 and 'SCRIPT ERROR:' not in log and 'ERROR:' not in log and ('PASS' in log or 'CONTENT_R3_VERIFIED' in log or 'CONTENT_R21_VERIFIED' in log) and before==after
    record={'scene':scene,'command':command,'exit_code':code,'status':'VERIFIED' if good else 'BLOCKED','log_sha256':sha(path),'source_receipt':stamp.relative_to(OUT).as_posix(),'source_receipt_sha256':sha(stamp),'runner_timeout_seconds':timeout,'wall_seconds':round(time.monotonic()-start,3),'environment_override':{key:env[key]for key in ['CV_QA_PROFILE','APPDATA','LOCALAPPDATA']},'project':str(project)}
    print(scene,record['status'],flush=True)
    return record

def ci():
    prepare()
    workflow=(ROOT/'.github/workflows/deploy-web.yml').read_text(encoding='utf8')
    block=re.search(r'scenes=\((.*?)\n\s*\)',workflow,re.S)[1]
    scenes=re.findall(r'^\s+([A-Za-z0-9]+)\s*$',block,re.M)+['R31EndgameGate']
    scripts=re.findall(r'^\s+node (tools/test_r(?:32_loading_recovery|36_webgl_state_cache|41_mobile_startup)\.[a-z]+)\s*$',workflow,re.M)
    results=[]
    for scene in scenes:
        record=execute(scene,extra=['--','--qa-endgame=r31'] if scene=='R31EndgameGate' else [])
        results.append(record)
        write(OUT/'tests/gates/summary.json',results)
        # Keep running independent original gates after a failure; all results
        # remain visible and the final command fails if any required one fails.
    for script in scripts:
        start=time.monotonic()
        result=subprocess.run(['node',script],cwd=ROOT,capture_output=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
        path=OUT/'tests/gates'/(Path(script).name+'.txt')
        path.write_text((result.stdout+result.stderr).decode('utf8',errors='replace').replace('\r\n','\n').rstrip()+'\n',encoding='utf8',newline='\n')
        results.append({'script':script,'status':'VERIFIED' if result.returncode==0 else 'BLOCKED','exit_code':result.returncode,'log_sha256':sha(path),'wall_seconds':round(time.monotonic()-start,3)})
        write(OUT/'tests/gates/summary.json',results)
        print(script,results[-1]['status'],flush=True)
    # Preserve the actual new receipts from the isolated copies, never copy
    # them over their historical counterparts in the real project.
    for source,target in [('content/r3/tests/mechanics.json','mechanics.json'),('content/r2/tests/mechanics.json','r2-mechanics.json'),('content/r1/tests/mechanics.json','r1-mechanics.json'),('content/r1/tests/navigation.json','r1-navigation.json'),('content/r2-1/tests/ui-regression.json','r2-1-ui-regression.json')]:
        shutil.copyfile(SANDBOX/'docs'/source,OUT/'tests'/target)
    write(OUT/'tests/ci-contract.json',{'native_scenes':scenes,'node_scripts':scripts,'base_commit':'ce94e02','base_gate_count':48,'new_gate_count':len(results),'profile_isolation':'per-child APPDATA/LOCALAPPDATA plus pre-ready CV_QA_PROFILE; all transactions remain real','legacy_evidence_writes':'independent copied docs in isolated regression project'})
    raise SystemExit(0 if all(row['status']=='VERIFIED' for row in results) else 1)

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('mode',choices=['prepare','unit','ci'])
    args=parser.parse_args()
    if args.mode=='prepare': prepare()
    elif args.mode=='ci': ci()
    else:
        record=execute('ContentR3Test','unit',ROOT)
        write(OUT/'tests/unit-run.json',record)
        raise SystemExit(0 if record['status']=='VERIFIED' else 1)
