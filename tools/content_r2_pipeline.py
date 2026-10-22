"""Local-only, silent build/evidence helper. No credentials or deployment."""
from pathlib import Path
import argparse, hashlib, json, os, subprocess, shutil, sys, threading
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/content/r2'
TMP = ROOT / '.audit-tmp/content-r2'
BUILD = ROOT / 'export/content-r2'
GODOT = Path.home()/'.codex/tools/godot-4.7-stable/Godot_v4.7-stable_win64_console.exe'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(v,ensure_ascii=False,indent=2),encoding='utf-8')
def run(cmd,log):
    with log.open('w',encoding='utf-8') as f:
        r=subprocess.run(list(map(str,cmd)),cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    print(log.name, r.returncode,flush=True)
    if r.returncode: raise SystemExit(r.returncode)
def init():
    (OUT/'tests').mkdir(parents=True,exist_ok=True);TMP.mkdir(parents=True,exist_ok=True)
    entries=subprocess.check_output(['git','status','--porcelain=v1','-z','--untracked-files=all'],cwd=ROOT).decode('utf-8').split('\0')
    files={}
    for e in entries:
        if not e: continue
        name=e[3:]
        if name.startswith(('docs/content/r2/','tools/content_r2','docs/OPTIM_PLAN_CONTENT_R2')):continue
        p=ROOT/name
        if p.is_file(): files[name]={'sha256':sha(p),'size':p.stat().st_size,'status':e[:2]}
    write(OUT/'tests/initial-files.json',files)
    shutil.copyfile(ROOT/'docs/content/r1/tests/delivery-check.json',OUT/'tests/r1-baseline-verification.json')
    print('protected',len(files))
def export(kind):
    TMP.mkdir(parents=True,exist_ok=True);BUILD.mkdir(parents=True,exist_ok=True)
    project=ROOT/'project.godot';preset=ROOT/'export_presets.cfg'
    orig=project.read_bytes();op=preset.read_bytes()
    allowed_debug={'content_r2_review.gd','content_r2_run.gd','ContentR2Review.tscn'}
    names=[p for folder in ['scripts','scenes','resources'] for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix in {'.gd','.gdshader','.tscn','.tres'} and ('debug' not in p.parts or p.name in allowed_debug)]
    names += [project,preset,ROOT/'assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf']
    sources={p.relative_to(ROOT).as_posix():sha(p) for p in names}
    write(OUT/'tests/source-hashes.json',{'files':sources})
    source_sha=sha(OUT/'tests/source-hashes.json')
    target=BUILD/kind;target.mkdir(exist_ok=True)
    try:
        if kind=='review':
            project.write_bytes(orig.replace(b'res://scenes/ui/MainMenu.tscn',b'res://scenes/debug/ContentR2Review.tscn'))
            text=op.decode('utf-8').replace('scripts/debug/**,scenes/debug/**,','')
            import re
            excluded=[p.relative_to(ROOT).as_posix() for folder in ['scripts/debug','scenes/debug'] for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix in {'.gd','.tscn'} and p.name not in allowed_debug]
            text=re.sub(r'exclude_filter="([^"]*)"',lambda m:'exclude_filter="'+m[1]+','+','.join(excluded)+'"',text,count=1)
            preset.write_text(text,encoding='utf-8')
        run([GODOT,'--headless','--audio-driver','Dummy','--path',ROOT,'--export-debug' if kind=='review' else '--export-release','Web',target/'index.html'],TMP/(kind+'-export.txt'))
    finally:
        project.write_bytes(orig);preset.write_bytes(op)
    assert all(sha(ROOT/name)==value for name,value in sources.items()), 'source changed during export'
    run([sys.executable,'tools/finalize_r25_web_export.py','--dir',target,'--evidence',TMP/(kind+'-shell.json')],TMP/(kind+'-shell.txt'))
    print('pack',kind,sha(target/'index.pck'),flush=True)
    metadata=OUT/'tests/builds.json'
    existing=json.loads(metadata.read_text(encoding='utf-8')) if metadata.exists() else {}
    existing[kind]={'pack_sha256':sha(target/'index.pck'),'source_manifest_sha256':source_sha,'release_entry_restored':b'res://scenes/ui/MainMenu.tscn' in project.read_bytes()}
    write(metadata,existing)
def browser(script,extra):
    class Quiet(SimpleHTTPRequestHandler):
        def log_message(self,*args):pass
    server=ThreadingHTTPServer(('127.0.0.1',8152),partial(Quiet,directory=str(BUILD)))
    threading.Thread(target=server.serve_forever,daemon=True).start()
    env=os.environ.copy();env['UI_CAPTURE_PLAYWRIGHT']=str(TMP/'node_modules');env['UI_CAPTURE_URL']='http://127.0.0.1:8152/release/'
    env.setdefault('UI_CAPTURE_CHROME','C:/Program Files/Google/Chrome/Application/chrome.exe')
    env.setdefault('R33_WEB_SMOKE_OUT',str(OUT/'tests/web-smoke.json'))
    try:
        r=subprocess.run(['node',script]+extra,cwd=ROOT,env=env,capture_output=True,creationflags=subprocess.CREATE_NO_WINDOW)
        log=(r.stdout+r.stderr).decode('utf-8',errors='replace')
        (OUT/'tests'/(Path(script).stem+('-'+extra[0] if extra else '')+'.txt')).write_text(log,encoding='utf-8')
        ledger=OUT/'tests/browser-ledger.json'
        records=json.loads(ledger.read_text(encoding='utf-8')) if ledger.exists() else []
        key=script+' '+' '.join(extra)
        records=[record for record in records if record['key']!=key]
        kind='review' if Path(script).name=='content_r2_samples.cjs' else 'release'
        records.append({'key':key,'script':script,'arguments':extra,'exit_code':r.returncode,'pack_sha256':sha(BUILD/kind/'index.pck'),'source_manifest_sha256':sha(OUT/'tests/source-hashes.json')})
        write(ledger,records)
        print(log,flush=True)
    finally:server.shutdown();server.server_close()
    raise SystemExit(r.returncode)
def cleanup():
    initial=json.loads((OUT/'tests/initial-files.json').read_text(encoding='utf-8'))
    rows=[];pruned=[];auxiliary=[]
    keep={'844x390-battle.png','844x390-formation.png','844x390-guide.png','390x844-battle.png','390x844-formation.png','1366x600-pause.png'}
    candidates=[p for folder in ['baseline','matrix'] for p in (OUT/folder).glob('*.png') if p.name not in keep]
    candidates += list((OUT/'tests/reviewer').glob('*.png'))
    candidates += list((OUT/'tests/controls').glob('*.png'))
    for p in candidates:
        assert p.resolve().is_relative_to(OUT.resolve()) and p.relative_to(ROOT).as_posix() not in initial
        pruned.append({'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size})
        p.unlink()
    cache=ROOT/'tools/__pycache__'
    for p in cache.glob('content_r2_*.pyc'):
        auxiliary.append({'path':str(p.resolve()),'bytes':p.stat().st_size})
        p.unlink()
    save_root=Path.home()/'AppData/Roaming/Godot/app_userdata/Crackveil Vanguard'
    save_names=[f'content_r2_{kind}_{name}.cfg' for kind in ['run','test'] for name in ['campaign','campaign_pets','meta','settings','achievements']]
    for name in save_names:
        p=save_root/name
        assert p.resolve().parent==save_root.resolve() and p.name.startswith('content_r2_')
        if p.is_file():
            auxiliary.append({'path':str(p.resolve()),'bytes':p.stat().st_size})
            p.unlink()
    for target in [BUILD,TMP]:
        assert target.resolve() in [ROOT/'export/content-r2',ROOT/'.audit-tmp/content-r2']
        files=[p for p in target.rglob('*') if p.is_file()]
        assert not any(p.relative_to(ROOT).as_posix() in initial for p in files)
        rows.append({'target':str(target.resolve()),'files':len(files),'bytes':sum(p.stat().st_size for p in files)})
        shutil.rmtree(target)
    missing=[p for p in initial if not (ROOT/p).is_file()]
    changed=[p for p,v in initial.items() if (ROOT/p).is_file() and sha(ROOT/p)!=v['sha256']]
    write(OUT/'tests/cleanup.json',{'status':'VERIFIED' if not missing else 'BLOCKED','targets':rows,'pruned_evidence':pruned,'auxiliary':auxiliary,'missing_initial':missing,'changed_initial':changed,'deleted_files':sum(r['files'] for r in rows)+len(pruned)+len(auxiliary),'freed_bytes':sum(r['bytes'] for r in rows)+sum(r['bytes'] for r in pruned)+sum(r['bytes'] for r in auxiliary)})
if __name__=='__main__':
    a=sys.argv[1:]
    if a[0]=='init':init()
    elif a[0]=='export':export(a[1])
    elif a[0]=='browser':browser(a[1],a[2:])
    elif a[0]=='cleanup':cleanup()
