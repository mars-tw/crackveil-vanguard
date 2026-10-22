"""Silent native CI in a copied evidence tree and isolated Windows profiles.

Runtime/assets are read through junctions; docs are independent copies so the
unchanged legacy test writers cannot overwrite historical receipts.
"""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,time,uuid
import content_r4_boundary as boundary

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/content/r4'
TMP=ROOT/'.audit-tmp/content-r4'
SANDBOX=TMP/'regression-project'
GODOT=Path.home()/'.codex/tools/godot-4.7-stable/Godot_v4.7-stable_win64_console.exe'

def write(path,value):
    boundary.write_json(path,value)

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def frozen_mismatches():
    return boundary.snapshot()['failures']

def source_state():
    paths=[p for folder in ['scripts','scenes','resources','assets','web','native'] for p in (ROOT/folder).rglob('*') if p.is_file() and '.import' not in p.suffixes and '__pycache__' not in p.parts]
    paths += [ROOT/name for name in ['project.godot','export_presets.cfg','.github/workflows/deploy-web.yml','tools/content_r4_native.py','tools/content_r4_boundary.py','tools/test_r32_loading_recovery.mjs','tools/test_r36_webgl_state_cache.cjs','tools/test_r41_mobile_startup.cjs']]
    return {p.relative_to(ROOT).as_posix():{'sha256':sha(p),'mtime_ns':p.stat().st_mtime_ns,'bytes':p.stat().st_size} for p in sorted(paths)}

def junction(link,target):
    boundary.assert_output(link.parent)
    assert target.resolve() in {(ROOT/name).resolve() for name in ['scripts','scenes','resources','assets','web','native','tools','.godot']},'unlisted junction target'
    assert link.name==target.name and link.parent.resolve().is_relative_to(TMP.resolve()),'unlisted junction entry'
    if link.exists():
        assert link.resolve()==target.resolve(),str(link)
        return
    escaped=lambda p:str(p).replace("'","''")
    command=f"New-Item -ItemType Junction -Path '{escaped(link)}' -Target '{escaped(target)}' | Out-Null"
    subprocess.run(['powershell','-NoProfile','-NonInteractive','-Command',command],check=True,capture_output=True,creationflags=subprocess.CREATE_NO_WINDOW)

def prepare():
    boundary.assert_output(SANDBOX)
    SANDBOX.mkdir(parents=True,exist_ok=True)
    for folder in ['scripts','scenes','resources','assets','web','native','tools','.godot']:
        junction(SANDBOX/folder,ROOT/folder)
    for name in ['project.godot','export_presets.cfg']:
        shutil.copyfile(ROOT/name,boundary.assert_output(SANDBOX/name))
    target=SANDBOX/'docs'
    if not target.exists():
        print('copying independent historical docs for unchanged CI writers',flush=True)
        shutil.copytree(ROOT/'docs',boundary.assert_output(target))
    boundary.sandbox_docs(SANDBOX)
    print('sandbox ready',flush=True)

def execute(scene,job='suite',project=SANDBOX,extra=None,timeout=180):
    assert re.fullmatch(r'[A-Za-z0-9]+',scene) and re.fullmatch(r'[A-Za-z0-9_-]+',job),'unsafe native scene/job output component'
    boundary.sandbox_docs(project)
    protection_before=boundary.snapshot()
    frozen_before=protection_before['failures']
    assert not frozen_before,'refuse to start with changed historical evidence: '+str(frozen_before)
    if scene=='ContentR4Run':
        for name in ['content_r4_run.gd','content_r4_pilot.gd']:
            assert not re.search(r'res://docs/content/r[123](?:/|-)',(ROOT/'scripts/debug'/name).read_text(encoding='utf8')),'legacy evidence output path in R4 driver '+name
    attempt_id=uuid.uuid4().hex
    expected_source=None
    team=None
    expected_seed=None
    extra=list(extra or [])
    if scene=='ContentR4Run':
        team=next(value.split('=',1)[1] for value in extra if value.startswith('team='))
        expected_seed=int(next(value.split('=',1)[1] for value in extra if value.startswith('seed=')))
        assert team in {'assault','escort'}
        expected_source=boundary.assert_output(SANDBOX/'docs/content/r4/tests/paired'/(team+'-'+attempt_id+'.json'))
        assert not expected_source.exists(),'unique attempt output already exists'
        if '--' not in extra:extra.append('--')
        extra.append('evidence_token='+attempt_id)
    elif scene=='ContentR4Test':
        expected_source=boundary.assert_output(SANDBOX/'docs/content/r4/tests/mechanics.json')
        # This is only an owned COPY in the sandbox, never the real receipt.
        if expected_source.is_file():expected_source.unlink()
    attempt=OUT/'tests/attempts'/('native-'+time.strftime('%Y%m%dT%H%M%SZ',time.gmtime()))
    old=OUT/'tests'/('gates' if job=='suite' else job)
    for source in [old/(scene+'.txt'),old/(scene+'-source.json'),OUT/'tests/mechanics.json',OUT/'tests/unit-run.json']:
        if source.is_file():
            boundary.assert_output(attempt);attempt.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,boundary.assert_output(attempt/source.name))
    profile=boundary.assert_output(TMP/'native-profiles'/job/scene/attempt_id)
    env=os.environ.copy()
    workflow_profile=re.search(r'export CV_QA_PROFILE=([A-Za-z0-9_-]+)',(ROOT/'.github/workflows/deploy-web.yml').read_text(encoding='utf8'))[1]
    env['CV_QA_PROFILE']=workflow_profile if job=='suite' else 'content_r3_r4_'+job
    for name,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local')]:
        path=profile/folder
        path.mkdir(parents=True,exist_ok=True)
        env[name]=str(path)
    command=[str(GODOT),'--headless','--audio-driver','Dummy','--fixed-fps','60','--path',str(project),f'res://scenes/debug/{scene}.tscn']+extra
    before=source_state()
    start=time.monotonic();start_ns=time.time_ns()
    try:
        result=subprocess.run(command,cwd=project,env=env,capture_output=True,timeout=timeout,creationflags=subprocess.CREATE_NO_WINDOW)
        code=result.returncode;raw=result.stdout+result.stderr
    except subprocess.TimeoutExpired as error:
        code=124;raw=(error.stdout or b'')+(error.stderr or b'')+b'\nRUNNER_TIMEOUT\n'
    log=raw.decode('utf8',errors='replace').replace('\r\n','\n').replace('\r','\n').rstrip()+'\n'
    folder=boundary.assert_output(OUT/'tests'/('gates' if job=='suite' else job))
    folder.mkdir(parents=True,exist_ok=True)
    path=folder/(scene+'.txt')
    boundary.write_text(path,log)
    after=source_state()
    protection_after=boundary.snapshot();frozen_after=protection_after['failures']
    execution_ok=code==0 and 'SCRIPT ERROR:' not in log and 'ERROR:' not in log and ('PASS' in log or 'CONTENT_R4_VERIFIED' in log or 'CONTENT_R3_VERIFIED' in log or 'CONTENT_R21_VERIFIED' in log) and before==after and not frozen_after
    stamp=folder/(scene+'-source.json')
    write(stamp,{'before':before,'after':after,'unchanged':before==after})
    output_valid=True
    expected_output=None;copyback=None;freshness=None
    if scene=='ContentR4Run':
        expected_output=OUT/'tests/paired'/(team+'.json')
        value=json.loads(expected_source.read_text(encoding='utf8')) if expected_source.is_file() else {}
        mtime=expected_source.stat().st_mtime_ns if expected_source.is_file() else 0
        freshness={'attempt_id':attempt_id,'expected_seed':expected_seed,'mtime_ns':mtime,'started_ns':start_ns,'finished_ns':time.time_ns(),'starting_run_id':value.get('starting_run_id'),'source_sha256':sha(expected_source) if expected_source.is_file() else None}
        output_valid=value.get('team')==team and value.get('seed')==expected_seed and value.get('version')=='0.33.0-content-r4' and value.get('status')=='VERIFIED' and value.get('evidence_token')==attempt_id and bool(value.get('starting_run_id')) and start_ns-2_000_000_000<=mtime<=freshness['finished_ns']+2_000_000_000
        if output_valid and execution_ok:copyback=boundary.collect(expected_source,expected_output)
        elif expected_source.is_file():
            rejected=boundary.assert_output(OUT/'tests/attempts'/('rejected-native-'+attempt_id)/'result.json')
            rejected.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(expected_source,rejected)
            freshness['rejected_result_copy']=rejected.relative_to(OUT).as_posix()
    elif scene=='ContentR4Test':
        output_valid=expected_source.is_file() and expected_source.stat().st_mtime_ns>=start_ns-2_000_000_000
        if output_valid and job=='unit' and execution_ok:copyback=boundary.collect(expected_source,OUT/'tests/mechanics.json')
    good=execution_ok and output_valid
    record={'scene':scene,'command':command,'exit_code':code,'status':'VERIFIED' if good else 'BLOCKED','log_sha256':sha(path),'source_receipt':stamp.relative_to(OUT).as_posix(),'source_receipt_sha256':sha(stamp),'runner_timeout_seconds':timeout,'wall_seconds':round(time.monotonic()-start,3),'environment_override':{key:env[key]for key in ['CV_QA_PROFILE','APPDATA','LOCALAPPDATA']},'project':str(project)}
    record.update({'frozen_history_manifest_sha256':sha(OUT/'tests/historical.json'),'frozen_history_before_failures':frozen_before,'frozen_history_after_failures':frozen_after,'expected_output':str(expected_output) if expected_output else None,'expected_output_valid':output_valid,'isolated_expected_source':str(expected_source) if expected_source else None,'freshness':freshness,'copyback':copyback,'protection_before':protection_before,'protection_after':protection_after})
    print(scene,record['status'],flush=True)
    return record

def ci():
    prepare()
    workflow=(ROOT/'.github/workflows/deploy-web.yml').read_text(encoding='utf8')
    block=re.search(r'scenes=\((.*?)\n\s*\)',workflow,re.S)[1]
    scenes=re.findall(r'^\s+([A-Za-z0-9]+)\s*$',block,re.M)+['R31EndgameGate']
    scripts=re.findall(r'^\s+node (tools/test_r(?:32_loading_recovery|36_webgl_state_cache|41_mobile_startup)\.[a-z]+)\s*$',workflow,re.M)
    results=[]
    write(OUT/'tests/ci-source-before.json',source_state())
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
        boundary.write_text(path,(result.stdout+result.stderr).decode('utf8',errors='replace').replace('\r\n','\n').rstrip()+'\n')
        results.append({'script':script,'status':'VERIFIED' if result.returncode==0 else 'BLOCKED','exit_code':result.returncode,'log_sha256':sha(path),'wall_seconds':round(time.monotonic()-start,3)})
        write(OUT/'tests/gates/summary.json',results)
        print(script,results[-1]['status'],flush=True)
    write(OUT/'tests/ci-source-after.json',source_state())
    # Preserve the actual new receipts from the isolated copies, never copy
    # them over their historical counterparts in the real project.
    if all(row['status']=='VERIFIED' for row in results):
        for source,target in [('content/r4/tests/mechanics.json','mechanics.json'),('content/r3/tests/mechanics.json','r3-mechanics.json'),('content/r2/tests/mechanics.json','r2-mechanics.json'),('content/r1/tests/mechanics.json','r1-mechanics.json'),('content/r1/tests/navigation.json','r1-navigation.json'),('content/r2-1/tests/ui-regression.json','r2-1-ui-regression.json')]:
            boundary.collect(SANDBOX/'docs'/source,OUT/'tests'/target)
    write(OUT/'tests/ci-contract.json',{'native_scenes':scenes,'node_scripts':scripts,'base_commit':'0b764c10287124c3fc78b0691dd70e4035d32624','base_gate_count':49,'new_gate_count':len(results),'profile_isolation':'per-child APPDATA/LOCALAPPDATA plus pre-ready CV_QA_PROFILE; all transactions remain real','legacy_evidence_writes':'independent copied docs in isolated regression project'})
    raise SystemExit(0 if all(row['status']=='VERIFIED' for row in results) else 1)

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('mode',choices=['prepare','unit','ci'])
    args=parser.parse_args()
    if args.mode=='prepare': prepare()
    elif args.mode=='ci': ci()
    else:
        prepare()
        record=execute('ContentR4Test','unit',SANDBOX)
        write(OUT/'tests/unit-run.json',record)
        raise SystemExit(0 if record['status']=='VERIFIED' else 1)
