"""Silent native CI in a copied evidence tree and isolated Windows profiles.

Runtime/assets are read through junctions; docs are independent copies so the
unchanged legacy test writers cannot overwrite historical receipts.
"""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys,time,uuid
import content_r8_boundary as boundary

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/content/r8'
TMP=ROOT/'.audit-tmp/content-r8'
SANDBOX=TMP/'regression-project'
GODOT=Path.home()/'.codex/tools/godot-4.7-stable/Godot_v4.7-stable_win64_console.exe'

def write(path,value):
    boundary.write_json(path,value)

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def frozen_mismatches():
    return boundary.snapshot()['failures']

def source_state():
    paths=[p for folder in ['scripts','scenes','resources','assets','web','native'] for p in (ROOT/folder).rglob('*') if p.is_file() and '.import' not in p.suffixes and '__pycache__' not in p.parts]
    paths += [ROOT/name for name in ['project.godot','README.md','native/build-config.json','export_presets.cfg','.github/workflows/deploy-web.yml','tools/content_r8_native.py','tools/content_r8_boundary.py','tools/content_r8_pipeline.py','tools/content_r8_capture.cjs','tools/verify_content_r8.py','tools/content_r7_native.py','tools/content_r7_boundary.py','tools/content_r7_pipeline.py','tools/content_r7_capture.cjs','tools/verify_content_r7.py','tools/content_r6_native.py','tools/content_r6_boundary.py','tools/content_r6_pipeline.py','tools/content_r6_capture.cjs','tools/verify_content_r6.py','tools/content_r5_native.py','tools/content_r5_boundary.py','tools/content_r5_pipeline.py','tools/content_r5_capture.cjs','tools/verify_content_r5.py','tools/content_r4_native.py','tools/content_r4_boundary.py','tools/content_r4_pipeline.py','tools/content_r4_capture.cjs','tools/verify_content_r4.py','tools/test_r32_loading_recovery.mjs','tools/test_r36_webgl_state_cache.cjs','tools/test_r41_mobile_startup.cjs']]
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
    if scene=='ContentR8Run':
        for name in ['content_r8_run.gd','content_r8_pilot.gd']:
            assert not re.search(r'res://docs/content/r[123](?:/|-)',(ROOT/'scripts/debug'/name).read_text(encoding='utf8')),'legacy evidence output path in R4 driver '+name
    attempt_id=uuid.uuid4().hex
    expected_source=None
    team=None
    expected_seed=None
    extra=list(extra or [])
    if scene=='ContentR8Run':
        team=next(value.split('=',1)[1] for value in extra if value.startswith('team='))
        expected_seed=int(next(value.split('=',1)[1] for value in extra if value.startswith('seed=')))
        assert team in {'assault','escort'}
        expected_source=boundary.assert_output(SANDBOX/'docs/content/r8/tests/paired'/(team+'-'+attempt_id+'.json'))
        assert not expected_source.exists(),'unique attempt output already exists'
        if '--' not in extra:extra.append('--')
        extra.append('evidence_token='+attempt_id)
    elif scene=='ContentR4Test':
        expected_source=boundary.assert_output(SANDBOX/'docs/content/r4/tests/mechanics.json')
        # This is only an owned COPY in the sandbox, never the real receipt.
        if expected_source.is_file():expected_source.unlink()
    profile=boundary.assert_output(TMP/'native-profiles'/job/scene/attempt_id)
    env=os.environ.copy()
    workflow_profile=re.search(r'export CV_QA_PROFILE=([A-Za-z0-9_-]+)',(ROOT/'.github/workflows/deploy-web.yml').read_text(encoding='utf8'))[1]
    env['CV_QA_PROFILE']=workflow_profile if job=='suite' else 'content_r8_'+job
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
    if scene=='ContentR8Run':
        expected_output=OUT/'tests/paired'/(team+'.json')
        value=json.loads(expected_source.read_text(encoding='utf8')) if expected_source.is_file() else {}
        mtime=expected_source.stat().st_mtime_ns if expected_source.is_file() else 0
        freshness={'attempt_id':attempt_id,'expected_seed':expected_seed,'mtime_ns':mtime,'started_ns':start_ns,'finished_ns':time.time_ns(),'starting_run_id':value.get('starting_run_id'),'source_sha256':sha(expected_source) if expected_source.is_file() else None}
        output_valid=value.get('team')==team and value.get('seed')==expected_seed and value.get('version')=='0.37.0-content-r8' and value.get('status')=='VERIFIED' and value.get('evidence_token')==attempt_id and bool(value.get('starting_run_id')) and start_ns-2_000_000_000<=mtime<=freshness['finished_ns']+2_000_000_000
        if output_valid and execution_ok:copyback=boundary.collect(expected_source,expected_output)
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
    unit_start=time.monotonic()
    unit_env=os.environ.copy();unit_env.update({'CV_QA_PROFILE':'content_r5_unit','APPDATA':str(TMP/'profiles'/'unit-r5'/'roaming'),'LOCALAPPDATA':str(TMP/'profiles'/'unit-r5'/'local')})
    for folder in [unit_env['APPDATA'],unit_env['LOCALAPPDATA']]:boundary.assert_output(Path(folder)).mkdir(parents=True,exist_ok=True)
    unit=subprocess.run([str(GODOT),'--headless','--fixed-fps','60','--path',str(ROOT),'--script','res://scripts/debug/content_r5_test.gd'],cwd=ROOT,env=unit_env,capture_output=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
    unit_log=boundary.assert_output(OUT/'tests/gates/content_r5_test.txt');boundary.write_text(unit_log,(unit.stdout+unit.stderr).decode('utf8',errors='replace').replace('\r\n','\n').rstrip()+'\n')
    results.append({'script':'scripts/debug/content_r5_test.gd','status':'VERIFIED' if unit.returncode==0 else 'BLOCKED','exit_code':unit.returncode,'checks':int(re.search(rb'R5_REGRESSION status=PASS checks=(\d+)',unit.stdout)[1]) if re.search(rb'R5_REGRESSION status=PASS checks=(\d+)',unit.stdout) else 0,'log_sha256':sha(unit_log),'wall_seconds':round(time.monotonic()-unit_start,3)})
    write(OUT/'tests/gates/summary.json',results)
    print('R5 pure UI/economy ledger test',results[-1]['status'],flush=True)
    unit_start=time.monotonic()
    unit_env=os.environ.copy();unit_env.update({'CV_QA_PROFILE':'content_r6_unit','APPDATA':str(TMP/'profiles'/'unit-r6'/'roaming'),'LOCALAPPDATA':str(TMP/'profiles'/'unit-r6'/'local')})
    for folder in [unit_env['APPDATA'],unit_env['LOCALAPPDATA']]:boundary.assert_output(Path(folder)).mkdir(parents=True,exist_ok=True)
    unit=subprocess.run([str(GODOT),'--headless','--fixed-fps','60','--path',str(ROOT),'--script','res://scripts/debug/content_r6_test.gd'],cwd=ROOT,env=unit_env,capture_output=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
    unit_log=boundary.assert_output(OUT/'tests/gates/content_r6_test.txt');boundary.write_text(unit_log,(unit.stdout+unit.stderr).decode('utf8',errors='replace').replace('\r\n','\n').rstrip()+'\n')
    results.append({'script':'scripts/debug/content_r6_test.gd','status':'VERIFIED' if unit.returncode==0 else 'BLOCKED','exit_code':unit.returncode,'checks':int(re.search(rb'R6_REGRESSION status=PASS checks=(\d+)',unit.stdout)[1]) if re.search(rb'R6_REGRESSION status=PASS checks=(\d+)',unit.stdout) else 0,'log_sha256':sha(unit_log),'wall_seconds':round(time.monotonic()-unit_start,3)})
    write(OUT/'tests/gates/summary.json',results)
    print('R6 formation/readability test',results[-1]['status'],flush=True)
    unit_start=time.monotonic()
    unit_env=os.environ.copy();unit_env.update({'CV_QA_PROFILE':'content_r7_unit','APPDATA':str(TMP/'profiles'/'unit-r6'/'roaming'),'LOCALAPPDATA':str(TMP/'profiles'/'unit-r6'/'local')})
    for folder in [unit_env['APPDATA'],unit_env['LOCALAPPDATA']]:boundary.assert_output(Path(folder)).mkdir(parents=True,exist_ok=True)
    unit=subprocess.run([str(GODOT),'--headless','--fixed-fps','60','--path',str(ROOT),'--script','res://scripts/debug/content_r7_test.gd'],cwd=ROOT,env=unit_env,capture_output=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
    unit_log=boundary.assert_output(OUT/'tests/gates/content_r7_test.txt');boundary.write_text(unit_log,(unit.stdout+unit.stderr).decode('utf8',errors='replace').replace('\r\n','\n').rstrip()+'\n')
    results.append({'script':'scripts/debug/content_r7_test.gd','status':'VERIFIED' if unit.returncode==0 else 'BLOCKED','exit_code':unit.returncode,'checks':int(re.search(rb'R7_REGRESSION status=PASS checks=(\d+)',unit.stdout)[1]) if re.search(rb'R7_REGRESSION status=PASS checks=(\d+)',unit.stdout) else 0,'log_sha256':sha(unit_log),'wall_seconds':round(time.monotonic()-unit_start,3)})
    write(OUT/'tests/gates/summary.json',results)
    print('R7 unit test',results[-1]['status'],flush=True)
    unit_start=time.monotonic()
    unit_env=os.environ.copy();unit_env.update({'CV_QA_PROFILE':'content_r8_unit','APPDATA':str(TMP/'profiles'/'unit-r6'/'roaming'),'LOCALAPPDATA':str(TMP/'profiles'/'unit-r6'/'local')})
    for folder in [unit_env['APPDATA'],unit_env['LOCALAPPDATA']]:boundary.assert_output(Path(folder)).mkdir(parents=True,exist_ok=True)
    unit=subprocess.run([str(GODOT),'--headless','--fixed-fps','60','--path',str(ROOT),'--script','res://scripts/debug/content_r8_test.gd'],cwd=ROOT,env=unit_env,capture_output=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
    unit_log=boundary.assert_output(OUT/'tests/gates/content_r8_test.txt');boundary.write_text(unit_log,(unit.stdout+unit.stderr).decode('utf8',errors='replace').replace('\r\n','\n').rstrip()+'\n')
    results.append({'script':'scripts/debug/content_r8_test.gd','status':'VERIFIED' if unit.returncode==0 else 'BLOCKED','exit_code':unit.returncode,'checks':int(re.search(rb'R8_REGRESSION status=PASS checks=(\d+)',unit.stdout)[1]) if re.search(rb'R8_REGRESSION status=PASS checks=(\d+)',unit.stdout) else 0,'log_sha256':sha(unit_log),'wall_seconds':round(time.monotonic()-unit_start,3)})
    write(OUT/'tests/gates/summary.json',results)
    print('R8 unit test',results[-1]['status'],flush=True)
    write(OUT/'tests/ci-source-after.json',source_state())
    # Preserve the actual new receipts from the isolated copies, never copy
    # them over their historical counterparts in the real project.
    if all(row['status']=='VERIFIED' for row in results):
        for source,target in [('content/r4/tests/mechanics.json','mechanics.json'),('content/r3/tests/mechanics.json','r3-mechanics.json'),('content/r2/tests/mechanics.json','r2-mechanics.json'),('content/r1/tests/mechanics.json','r1-mechanics.json'),('content/r1/tests/navigation.json','r1-navigation.json'),('content/r2-1/tests/ui-regression.json','r2-1-ui-regression.json')]:
            boundary.collect(SANDBOX/'docs'/source,OUT/'tests'/target)
    write(OUT/'tests/ci-contract.json',{'native_scenes':scenes,'node_scripts':scripts,'base_commit':'c8db615ab946cfce0191340f351a44da2676aad0','base_gate_count':53,'new_gate_count':len(results),'profile_isolation':'per-child APPDATA/LOCALAPPDATA plus pre-ready CV_QA_PROFILE; all transactions remain real','legacy_evidence_writes':'independent copied docs in isolated regression project'})
    verify=subprocess.run([sys.executable,'tools/verify_content_r8.py','ci'],cwd=ROOT,capture_output=True,timeout=90,creationflags=subprocess.CREATE_NO_WINDOW)
    verify_log=boundary.assert_output(OUT/'tests/gates/verify_content_r8.txt');boundary.write_text(verify_log,(verify.stdout+verify.stderr).decode('utf8',errors='replace').replace('\r\n','\n').rstrip()+'\n')
    write(OUT/'tests/gates/verify_content_r8.json',{'status':'VERIFIED' if verify.returncode==0 else 'BLOCKED','exit_code':verify.returncode,'log_sha256':sha(verify_log),'source_inputs':len(source_state())})
    if verify.returncode!=0:raise SystemExit(verify_log.read_text(encoding='utf8'))
    raise SystemExit(0 if all(row['status']=='VERIFIED' for row in results) else 1)

def pilot():
    prepare()
    results=[]
    for team,seed in [('assault',55210),('escort',55210)]:
        row=execute('ContentR8Run','pilot',SANDBOX,extra=['--','team='+team,'seed='+str(seed)],timeout=240)
        results.append(row)
        if row.get('copyback') is not None:row['copyback_sha256']=row['copyback']['sha256']
        write(OUT/'tests/pilot.json',results)
    raise SystemExit(0 if all(row['status']=='VERIFIED' for row in results) else 1)

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('mode',choices=['prepare','unit','ci','pilot'])
    args=parser.parse_args()
    if args.mode=='prepare': prepare()
    elif args.mode=='ci': ci()
    elif args.mode=='pilot': pilot()
    else:
        prepare()
        record=execute('ContentR4Test','unit',SANDBOX)
        write(OUT/'tests/unit-run.json',record)
        raise SystemExit(0 if record['status']=='VERIFIED' else 1)
