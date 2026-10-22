"""R3 local export/capture with immutable source receipts and silent software UI.

Uses an isolated project header; it never edits root project.godot/presets or
historical evidence. Export environments retain the installed Godot templates.
"""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys,threading,time,shutil
from functools import partial
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from content_r4_native import ROOT,OUT,TMP,GODOT,junction,write,sha,boundary

BUILD=ROOT/'export/content-r4'
PROJECT=TMP/'export-project'
ALLOWED={'content_r4_pilot.gd','content_r4_run.gd','content_r4_review.gd','ContentR4Review.tscn'}

def sources():
    paths=[p for folder in ['scripts','scenes','resources','assets','web','native'] for p in (ROOT/folder).rglob('*') if p.is_file() and '.import' not in p.suffixes and ('debug' not in p.parts or p.name in ALLOWED)]
    paths += [ROOT/p for p in ['project.godot','export_presets.cfg']]
    return {p.relative_to(ROOT).as_posix():sha(p) for p in sorted(paths)}

def archive(label):
    assert re.fullmatch(r'[a-z0-9-]+',label)
    target=boundary.assert_output(OUT/'tests/attempts'/label)
    target.mkdir(parents=True,exist_ok=False)
    for name in ['source-hashes.json','builds.json','samples.json','browser-ledger.json','controls.json','release-export.txt','review-export.txt','release-shell.json','review-shell.json','captures']+[f'browser-{mode}.txt' for mode in ['controls','preparation','assault','escort','milestone']]:
        path=OUT/'tests'/name
        if path.exists():boundary.assert_output(path).rename(boundary.assert_output(target/name))
    if (OUT/'review-set').exists():boundary.assert_output(OUT/'review-set').rename(boundary.assert_output(target/'review-set'))
    write(target/'attempt.json',{'captured_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'reason':label,'status':'SUPERSEDED; raw receipts retained; no historical evidence overwritten'})

def export(kind):
    assert kind in {'release','review'}
    protection_before=boundary.snapshot();boundary.assert_snapshot(protection_before)
    driver_sha=sha(Path(__file__))
    boundary.assert_output(BUILD).mkdir(parents=True,exist_ok=True);boundary.assert_output(PROJECT).mkdir(parents=True,exist_ok=True)
    for folder in ['scripts','scenes','resources','assets','web','native','.godot']:
        junction(PROJECT/folder,ROOT/folder)
    for name in ['project.godot','export_presets.cfg']:
        boundary.assert_output(PROJECT/name).write_bytes((ROOT/name).read_bytes())
    manifest=OUT/'tests/source-hashes.json'
    state=sources()
    if manifest.exists():assert json.loads(manifest.read_text(encoding='utf8'))['files']==state,'source changed between R3 exports; retain attempt and rebuild both'
    else:write(manifest,{'files':state,'version':'0.33.0-content-r4','scope':'all runtime scripts/scenes/resources/assets/web/native plus exact debug review dependency allowlist','captured_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())})
    project=PROJECT/'project.godot';preset=PROJECT/'export_presets.cfg'
    if kind=='review':
        boundary.assert_output(project).write_bytes(project.read_bytes().replace(b'res://scenes/ui/MainMenu.tscn',b'res://scenes/debug/ContentR4Review.tscn'))
        text=preset.read_text(encoding='utf8').replace('scripts/debug/**,scenes/debug/**,','')
        excluded=[p.relative_to(ROOT).as_posix() for folder in ['scripts/debug','scenes/debug'] for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix in {'.gd','.tscn'} and p.name not in ALLOWED]
        text=re.sub(r'exclude_filter="([^"]*)"',lambda m:'exclude_filter="'+m[1]+','+','.join(excluded)+'"',text,count=1)
        boundary.write_text(preset,text)
    target=boundary.assert_output(BUILD/kind);target.mkdir(exist_ok=True)
    boundary.assert_output(target/'index.html')
    command=[str(GODOT),'--headless','--audio-driver','Dummy','--path',str(PROJECT),'--export-debug' if kind=='review' else '--export-release','Web',str(target/'index.html')]
    result=subprocess.run(command,cwd=PROJECT,capture_output=True,timeout=180,creationflags=subprocess.CREATE_NO_WINDOW)
    log=(result.stdout+result.stderr).decode('utf8',errors='replace').replace('\r\n','\n').rstrip()+'\n'
    boundary.write_text(OUT/'tests'/(kind+'-export.txt'),log)
    assert result.returncode==0 and 'SCRIPT ERROR:' not in log,log[-2500:]
    assert sources()==state and sha(Path(__file__))==driver_sha,'source/export driver changed while exporting'
    shell_receipt=boundary.assert_output(OUT/'tests'/(kind+'-shell.json'))
    shell=subprocess.run([sys.executable,'tools/finalize_r25_web_export.py','--dir',str(target),'--evidence',str(shell_receipt)],cwd=ROOT,capture_output=True,creationflags=subprocess.CREATE_NO_WINDOW)
    assert shell.returncode==0,(shell.stdout+shell.stderr).decode(errors='replace')
    metadata=OUT/'tests/builds.json';builds=json.loads(metadata.read_text(encoding='utf8')) if metadata.exists() else {}
    builds[kind]={'pack_sha256':sha(target/'index.pck'),'source_manifest_sha256':sha(manifest),'export_driver_sha256':driver_sha,'root_headers_unchanged':sources()==state,'release_entry_restored':'res://scenes/ui/MainMenu.tscn' in (ROOT/'project.godot').read_text(encoding='utf8'),'isolated_header_entry':'review fixture' if kind=='review' else 'official MainMenu','command':command,'files':{p.name:sha(p) for p in target.iterdir() if p.is_file()}}
    protection_after=boundary.snapshot();boundary.assert_snapshot(protection_after)
    builds[kind]['protection_before']=protection_before;builds[kind]['protection_after']=protection_after
    write(metadata,builds);print(kind,builds[kind]['pack_sha256'],flush=True)

def browser(mode):
    assert mode in {'controls','preparation','milestone','assault','escort'}
    protection_before=boundary.snapshot();boundary.assert_snapshot(protection_before)
    driver=ROOT/'tools/content_r4_capture.cjs'
    driver_before=sha(driver)
    class Quiet(SimpleHTTPRequestHandler):
        def log_message(self,*args):pass
    port=int(os.environ.get('CONTENT_BROWSER_PORT','8153'))
    server=ThreadingHTTPServer(('127.0.0.1',port),partial(Quiet,directory=str(BUILD)))
    threading.Thread(target=server.serve_forever,daemon=True).start()
    env=os.environ.copy();env.update({'UI_CAPTURE_PLAYWRIGHT':str(ROOT.parent/'apocalypse-anthology/node_modules'),'CONTENT_BUILD_URL':f'http://127.0.0.1:{port}','CONTENT_EVIDENCE_DIR':str(OUT),'CONTENT_DRIVER_SHA256':driver_before})
    try:
        path=boundary.assert_output(OUT/'tests'/('browser-'+mode+'.txt'))
        with path.open('w',encoding='utf8',newline='\n') as stream:
            result=subprocess.run(['node','tools/content_r4_capture.cjs',mode],cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        log=path.read_text(encoding='utf8').replace('\r\n','\n').rstrip()+'\n'
        boundary.write_text(path,log)
        ledger=OUT/'tests/browser-ledger.json';rows=json.loads(ledger.read_text(encoding='utf8')) if ledger.exists() else []
        rows=[r for r in rows if r['mode']!=mode]
        protection_after=boundary.snapshot()
        rows.append({'mode':mode,'exit_code':result.returncode,'log_sha256':sha(OUT/'tests'/('browser-'+mode+'.txt')),'source_manifest_sha256':sha(OUT/'tests/source-hashes.json'),'capture_driver_before_sha256':driver_before,'capture_driver_after_sha256':sha(driver),'protection_before':protection_before,'protection_after':protection_after,'builds':json.loads((OUT/'tests/builds.json').read_text(encoding='utf8'))})
        write(ledger,rows);print(log,flush=True)
        assert sha(driver)==driver_before,'browser driver changed during capture'
        boundary.assert_snapshot(protection_after)
    finally:server.shutdown();server.server_close()
    raise SystemExit(result.returncode)

def pack():
    protection_before=boundary.snapshot();boundary.assert_snapshot(protection_before)
    work=boundary.assert_output(TMP/'pack-isolation');work.mkdir(parents=True,exist_ok=True)
    paths=[p.relative_to(ROOT).as_posix() for folder in ['scripts/debug','scenes/debug'] for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix in {'.gd','.tscn'}]
    script=boundary.assert_output(work/'probe.gd')
    boundary.write_text(script,'''extends SceneTree
func _initialize() -> void:
 var leaked: Array[String]=[]
 for path in %s:
  if ResourceLoader.exists("res://"+path):leaked.append(path)
 var valid=leaked.is_empty() and load("res://scripts/ui/build_preparation.gd")!=null and load("res://scripts/services/starting_build_catalog.gd")!=null
 print("R3_PACK="+JSON.stringify({"status":"VERIFIED" if valid else "BLOCKED","leaked":leaked,"excluded_debug_paths":%d,"version":ProjectSettings.get_setting("application/config/version"),"physical_project_fallback":false}))
 quit(0 if valid else 1)
'''%(json.dumps(paths),len(paths)))
    env=os.environ.copy();env['CV_QA_PROFILE']='content_r4_pack'
    for key,name in [('APPDATA','roaming'),('LOCALAPPDATA','local')]:
        folder=work/name;folder.mkdir(exist_ok=True);env[key]=str(folder)
    command=[str(GODOT),'--headless','--audio-driver','Dummy','--path',str(work),'--main-pack',str(BUILD/'release/index.pck'),'--script',str(script)]
    result=subprocess.run(command,cwd=work,env=env,capture_output=True,timeout=45,creationflags=subprocess.CREATE_NO_WINDOW)
    log=(result.stdout+result.stderr).decode('utf8',errors='replace').replace('\r\n','\n').rstrip()+'\n'
    boundary.write_text(OUT/'tests/pack-isolation.txt',log)
    assert result.returncode==0 and 'ERROR:' not in log,log[-2500:]
    row=json.loads(next(line.split('=',1)[1] for line in log.splitlines() if line.startswith('R3_PACK=')))
    row.update({'command':command,'pack_sha256':sha(BUILD/'release/index.pck'),'source_manifest_sha256':sha(OUT/'tests/source-hashes.json'),'log_sha256':sha(OUT/'tests/pack-isolation.txt')})
    protection_after=boundary.snapshot();boundary.assert_snapshot(protection_after)
    row.update({'protection_before':protection_before,'protection_after':protection_after})
    write(OUT/'tests/pack-isolation.json',row);print(row,flush=True)

def secrets():
    paths={ROOT/name for name in json.loads((OUT/'tests/source-hashes.json').read_text(encoding='utf8'))['files']}
    paths|={p for p in BUILD.rglob('*') if p.is_file()}
    pattern=re.compile(rb'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}')
    hits=[];total=0
    for path in sorted(paths):
        with path.open('rb') as handle:
            tail=b''
            while chunk:=handle.read(1048576):
                value=tail+chunk
                if pattern.search(value.lower()):hits.append(path.relative_to(ROOT).as_posix());break
                tail=value[-128:]
        total+=path.stat().st_size
    builds=json.loads((OUT/'tests/builds.json').read_text(encoding='utf8'))
    row={'status':'VERIFIED' if not hits else 'BLOCKED','hit_paths':hits,'files':len(paths),'bytes':total,'source_manifest_sha256':sha(OUT/'tests/source-hashes.json'),'pack_sha256':{k:v['pack_sha256'] for k,v in builds.items()},'scope':'all bound runtime sources/assets plus actual local release/review export bytes; no credential locations read; paths only if hit'}
    write(OUT/'tests/secret-scan.json',row);print(row,flush=True)
    assert not hits

def cleanup():
    protection_before=boundary.snapshot();boundary.assert_snapshot(protection_before)
    initial=json.loads((OUT/'tests/initial-files.json').read_text(encoding='utf8'))['files']
    changes={r['path']:r for r in json.loads((OUT/'tests/external-changes.json').read_text(encoding='utf8'))}
    links=[];rows=[];auxiliary=[];pruned=[]
    keep={'first-ui-before-focus-fix/review-set/01-crew-overview-max-portrait.png','first-ui-before-focus-fix/review-set/02-bond-equipped-versus-preview.png','draft-font-roster-accepted/review-set/01-crew-overview-max-portrait.png'}
    attempt_root=OUT/'tests/attempts'
    for path in attempt_root.rglob('*.png'):
        if path.relative_to(attempt_root).as_posix() in keep:continue
        assert path.resolve().is_relative_to(attempt_root.resolve()) and path.relative_to(ROOT).as_posix() not in initial
        pruned.append({'path':path.relative_to(ROOT).as_posix(),'bytes':path.stat().st_size,'sha256':sha(path),'reason':'own superseded duplicate PNG; raw JSON/log retained; current 15 and the explicit necessary before PNG allowlist retained'})
        boundary.assert_output(path).unlink()
    # Remove only the explicitly created links before any recursive operation;
    # never inventory or delete through the junction's real runtime target.
    for name in ['regression-project','export-project']:
        base=TMP/name
        for folder in ['scripts','scenes','resources','assets','web','native','tools','.godot']:
            link=base/folder
            if link.exists():
                assert link.resolve()==(ROOT/folder).resolve() and link.parent.resolve()==base.resolve(),str(link)
                links.append({'link':str(link),'target':str(link.resolve()),'operation':'os.rmdir junction only; target preserved'})
                os.rmdir(link)
    for target in [TMP,BUILD]:
        boundary.assert_output(target)
        assert target.absolute()==ROOT/('.audit-tmp/content-r4' if target==TMP else 'export/content-r4')
        assert target.resolve().is_relative_to(ROOT.resolve()) and target.name=='content-r4',str(target)
        files=[]
        if target.exists():
            for directory,folders,names in os.walk(target,followlinks=False):
                for entry in [Path(directory)/name for name in folders+names]:
                    assert not (entry.lstat().st_file_attributes & 1024),'unexpected reparse point '+str(entry)
                files.extend(Path(directory)/name for name in names)
            assert not any(p.relative_to(ROOT).as_posix() in initial for p in files)
            rows.append({'target':str(target.resolve()),'files':len(files),'bytes':sum(p.stat().st_size for p in files)})
            shutil.rmtree(target)
    save_root=Path.home()/'AppData/Roaming/Godot/app_userdata/Crackveil Vanguard'
    for name in ['qa_content_r4_unit_campaign.cfg','qa_content_r4_unit_crackveil_achievements.cfg','qa_content_r4_unit_crackveil_audio.cfg','qa_content_r4_unit_veil_echo.cfg']:
        path=save_root/name
        assert path.resolve().parent==save_root.resolve() and name.startswith('qa_content_r4_unit_')
        if path.is_file():
            raise AssertionError('unexpected QA file outside isolated R4 subprocess user roots: '+str(path))
    for path in (ROOT/'tools/__pycache__').glob('content_r4_*.pyc'):
        assert path.resolve().parent==(ROOT/'tools/__pycache__').resolve()
        auxiliary.append({'path':str(path),'bytes':path.stat().st_size});boundary.assert_own_cache(path).unlink()
    missing=[name for name in initial if not (ROOT/name).is_file()]
    changed=[name for name,row in initial.items() if (ROOT/name).is_file() and sha(ROOT/name)!=row['sha256']]
    unexpected=[name for name in changed if name not in changes or sha(ROOT/name)!=changes[name]['after_sha256']]
    result={'status':'VERIFIED' if not missing and not unexpected else 'BLOCKED','junctions_removed':links,'targets':rows,'auxiliary':auxiliary,'pruned_own_duplicate_evidence':pruned,'missing_initial':missing,'changed_initial':changed,'authorized_external_changes':list(changes),'unexpected_changed_initial':unexpected,'deleted_files':sum(r['files'] for r in rows)+len(auxiliary)+len(pruned),'freed_bytes':sum(r['bytes'] for r in rows)+sum(r['bytes'] for r in auxiliary)+sum(r['bytes'] for r in pruned)}
    protection_after=boundary.snapshot();boundary.assert_snapshot(protection_after)
    result.update({'protection_before':protection_before,'protection_after':protection_after})
    write(OUT/'tests/cleanup.json',result);print(json.dumps(result,ensure_ascii=False),flush=True)
    assert result['status']=='VERIFIED'

if __name__=='__main__':
    sys.stdout.reconfigure(encoding='utf8')
    if sys.argv[1]=='export':export(sys.argv[2])
    elif sys.argv[1]=='browser':browser(sys.argv[2])
    elif sys.argv[1]=='pack':pack()
    elif sys.argv[1]=='secrets':secrets()
    elif sys.argv[1]=='cleanup':cleanup()
    elif sys.argv[1]=='archive':archive(sys.argv[2])
