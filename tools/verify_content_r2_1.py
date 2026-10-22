"""Verify the bounded R2.1 patch and preserve the complete historical R2 record.

This gate proves UI regressions, not a new full-content/47-gate certification.
"""
from pathlib import Path
import hashlib,json,os,re,subprocess
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/content/r2-1'
BASE='f384969'
VERSION='0.31.1-content-r2.1'
failures=[]
checks=0
def check(value,message):
    global checks
    checks+=1
    if not value: failures.append(message)
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads((OUT/path).read_text(encoding='utf-8'))
def prior(path): return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT).decode('utf-8')
def normalize(text): return text.replace('\r\n','\n')

version=re.search(r'^config/version="([^"]+)"',(ROOT/'project.godot').read_text(encoding='utf-8'),re.M)[1]
# R3_EXACT_ROUTE_START
# Exact version only: separate current evidence; all archived assertions remain.
if version=='0.32.0-content-r3':
    raise SystemExit(subprocess.run([__import__('sys').executable,str(ROOT/'tools/verify_content_r3.py')],cwd=ROOT).returncode)
# R3_EXACT_ROUTE_END
check(version==VERSION,'wrong patch version')
check(VERSION in (ROOT/'README.md').read_text(encoding='utf-8'),'README version mismatch')
check(subprocess.check_output(['git','branch','--show-current'],cwd=ROOT).strip()==b'main','wrong branch')
native=json.loads((ROOT/'native/build-config.json').read_text(encoding='utf-8'))
old_native=json.loads(prior('native/build-config.json'))
check(native['sourceVersion']==VERSION and {k:v for k,v in native.items() if k!='sourceVersion'}=={k:v for k,v in old_native.items() if k!='sourceVersion'},'native counters/config drift')
check(normalize((ROOT/'export_presets.cfg').read_text(encoding='utf-8'))==normalize(prior('export_presets.cfg')),'export presets changed')
check('res://scenes/ui/MainMenu.tscn' in (ROOT/'project.godot').read_text(encoding='utf-8'),'debug entry leaked')

history=read('tests/historical-r2.json')
check(history['commit']==BASE,'wrong historical R2 reference')
for name,value in history['files'].items():
    check((ROOT/name).is_file() and sha(ROOT/name)==value,'historical R2 evidence modified: '+name)
check(subprocess.run(['git','diff','--quiet',BASE,'--','docs/content/r2'],cwd=ROOT).returncode==0,'historical tracked R2 differs from commit')
old_samples=json.loads((ROOT/'docs/content/r2/tests/samples.json').read_text(encoding='utf-8'))
check(len(old_samples)==15 and all(row['version']=='0.31.0-content-r2' for row in old_samples),'historical images relabelled')

# The legacy verifiers retain every assertion. Only exact version dispatch is
# new. Compare their complete historical bodies, not assertion counts.
r1=(ROOT/'tools/verify_content_r1.py').read_text(encoding='utf-8').replace("if version in {'0.31.0-content-r2', '0.31.1-content-r2.1'}:","if version=='0.31.0-content-r2':")
check(normalize(r1)==normalize(prior('tools/verify_content_r1.py')),'R1 historical assertions changed')
r2=(ROOT/'tools/verify_content_r2.py').read_text(encoding='utf-8').replace('import hashlib,json,os,re,subprocess,sys','import hashlib,json,os,re,subprocess')
route='''# R2 remains frozen at f384969. The patch has separate source/build/screenshots
# and a narrower, explicitly reported gate scope; never rewrite R2's receipts.
if version=='0.31.1-content-r2.1':
 raise SystemExit(subprocess.run([sys.executable,str(ROOT/'tools/verify_content_r2_1.py')],cwd=ROOT).returncode)
'''
check(normalize(r2.replace(route,''))==normalize(prior('tools/verify_content_r2.py')),'R2 historical assertions changed')
for path in ['scripts/debug/content_r1_test.gd','scripts/debug/content_r2_test.gd','scripts/debug/r39_mobile_hud_test.gd','scripts/debug/r42_formation_test.gd','scripts/debug/r43_mobile_tactics_test.gd']:
    def assertion_body(text):
        return '\n'.join(line for line in normalize(text).splitlines() if 'evidence_dir' not in line and not ('DirAccess.make_dir_recursive_absolute(' in line or 'var file := FileAccess.open(' in line))
    check(assertion_body((ROOT/path).read_text(encoding='utf-8'))==assertion_body(prior(path)),'original test changed beyond evidence output routing: '+path)
r14=(ROOT/'scripts/debug/r14_regression_test.gd').read_text(encoding='utf-8').replace(VERSION,'0.31.0-content-r2')
check(normalize(r14)==normalize(prior('scripts/debug/r14_regression_test.gd')),'R14 changed beyond exact current-version expectation')

sources=read('tests/source-hashes.json')['files']
manifest_sha=sha(OUT/'tests/source-hashes.json')
for name,value in sources.items(): check((ROOT/name).is_file() and sha(ROOT/name)==value,'source changed after build: '+name)
runtime_delta=[]
for name,value in sources.items():
    if name.startswith('scripts/debug/') or name.startswith('scenes/debug/'): continue
    blob=subprocess.run(['git','show',BASE+':'+name],cwd=ROOT,capture_output=True)
    same=blob.stdout==(ROOT/name).read_bytes() if (ROOT/name).suffix=='.otf' else normalize(blob.stdout.decode('utf-8',errors='replace'))==normalize((ROOT/name).read_text(encoding='utf-8',errors='replace'))
    if blob.returncode!=0 or not same:
        runtime_delta.append(name)
check(set(runtime_delta)=={'project.godot','scripts/autoload/audio_manager.gd','scripts/services/formation_relay.gd','scripts/ui/hud.gd','scripts/ui/r33_loot_banner.gd'},'patch changes gameplay outside bounded UI/version scope: '+str(runtime_delta))
old_runtime=[]
for directory in ['scripts','resources','web','native']:
    for path in (ROOT/directory).rglob('*'):
        if path.is_file() and path.suffix in {'.gd','.gdshader','.tres','.tscn','.json','.js','.html'} and '0.31.0-content-r2' in path.read_text(encoding='utf-8',errors='replace'):
            old_runtime.append(path.relative_to(ROOT).as_posix())
check(not old_runtime,'old runtime version '+str(old_runtime))
builds=read('tests/builds.json')
for kind in ['review','release']:
    check(builds[kind]['source_manifest_sha256']==manifest_sha and builds[kind]['release_entry_restored'],'build/source binding mismatch '+kind)

scenes={'ContentR21Test','ContentR1Test','ContentR2Test','R14RegressionTest','R29MenuModalTest','R39MobileHUDTest','R42FormationTest','R43MobileTacticsTest'}
gates=read('tests/gates/summary.json')
check(len(gates)==8 and {row['scene'] for row in gates}==scenes,'bounded CI scope incomplete')
for row in gates:
    log=OUT/'tests/gates'/(row['scene']+'.txt')
    check(row['status']=='VERIFIED' and row['exit_code']==0 and sha(log)==row['log_sha256'],'gate failed/log changed '+row['scene'])
    check('--headless' in row['command'] and row['command'][row['command'].index('--audio-driver')+1]=='Dummy','gate not headless/silent')
    check('ERROR:' not in log.read_text(encoding='utf-8'),'runtime gate diagnostic '+row['scene'])
mechanics=read('tests/mechanics.json')
check(mechanics['status']=='VERIFIED' and mechanics['checks']>=244 and not mechanics['failures'],'original R2 mechanics failed')
r1_mechanics=read('tests/r1/mechanics.json')
check(r1_mechanics['status']=='VERIFIED' and r1_mechanics['checks']>=1355 and not r1_mechanics['failures'],'original R1 UI/bond mechanics failed')
ui=read('tests/ui-regression.json')
check(ui['status']=='VERIFIED' and ui['checks']>=120 and not ui['failures'],'new UI/gesture-tail regression failed')
check({tuple(row['viewport']) for row in ui['records']}=={(844,390),(390,844),(1366,600)},'native UI viewport coverage')
workflow=(ROOT/'.github/workflows/deploy-web.yml').read_text(encoding='utf-8')
check(all('            '+scene in workflow for scene in scenes),'UI regressions absent from CI')

runs=read('tests/runtime-runs.json')
check(len(runs)==5 and {(row['width'],row['height'],row['input'],row['gate_only']) for row in runs}=={(844,390,'mouse',False),(390,844,'mouse',False),(1366,600,'mouse',False),(844,390,'touch',True),(390,844,'touch',True)},'Web runtime viewport/gesture coverage')
for run in runs:
    check(run['result']['status']=='VERIFIED' and run['result']['checks']>=(3 if run['gate_only'] else 33) and not run['result']['failures'] and not run['errors'] and not run['external_requests'],'Web runtime failed')
    check(run['start_input']['method']=='Playwright centre '+run['input']+' on Godot official audio_prompt_button' and run['start_input']['normal_pause_resume_verified'],'official start/next input not exercised')
    state=run['start_input']['after_start']
    check(not any(state[key] for key in ['paused','manual_paused','system_paused','summon_visible','gate_visible']),'start gesture clicked through')
    check(run['pack_sha256']==builds['review']['pack_sha256'] and run['source_manifest_sha256']==manifest_sha,'Web run/build mismatch')
    for warning in run['known_uid_warnings']:
        check(bool(re.fullmatch(r"WARNING: 'res://[^']+': In external resource #\d+, invalid UID: 'uid://[^']+' - using text path instead: 'res://[^']+'\.",warning) or re.fullmatch(r'\s+at: open \(core/io/resource_format_binary\.cpp:1028\)',warning)),'unclassified runtime warning')
samples=read('tests/samples.json')
check(len(samples)==45,'Web checkpoint count')
images=[]
for viewport in [(844,390),(390,844),(1366,600)]:
    group=[row for row in samples if tuple(row['viewport'])==viewport]
    check(len(group)==15 and len({row['label'] for row in group})==15,'checkpoint coverage '+str(viewport))
    by_label={row['label']:row for row in group}
    check(by_label['picker-open']['picker_visible'] and not by_label['picker-open']['marker_visible'] and not by_label['picker-open']['toast_visible'],'marker/notice visible through picker')
    check(not by_label['picker-closed']['picker_visible'] and by_label['picker-closed']['marker_visible'],'marker not restored on cancel')
    for kind in ['front','pincer','artillery']:
        for phase in ['warning','active']:
            state=by_label[kind+'-'+phase]
            check(state['kind']==kind and state['phase']==phase and state['loot_active'] and not state['loot_visible'] and state['loot_age']==0,'loot covers/ages during '+kind+' '+phase)
            check(state['toast_visible'] and '預警' in state['toast_text'],'warning swallowed during '+kind+' '+phase)
        state=by_label[kind+'-recovery']
        check(state['loot_visible'] and 0<state['loot_age']<1.0,'deferred loot did not resume')
    for keyword in ['預警','反噬','封隙','護衛']:
        state=by_label['urgent-'+keyword]
        check(state['toast_visible'] and state['toast_text']==keyword+'重要訊息' and not state['loot_visible'],'urgent feedback lost '+keyword)
for row in samples:
    check(row['version']==VERSION and row['pack_sha256']==builds['review']['pack_sha256'] and row['source_manifest_sha256']==manifest_sha and not row['audio_gate_visible'] and not row['errors'] and not row['failures_so_far'] and not row['external_requests'],'sample/source/runtime binding')
    if row['screenshot']:
        image=OUT/row['file']
        check(sha(image)==row['sha256'] and not row['postprocessed'],'screenshot altered')
        with Image.open(image) as im: check(list(im.size)==row['dimensions']==row['viewport'],'screenshot dimensions changed')
        images.append(row['file'])
check(len(images)==21 and set(images)=={p.relative_to(OUT).as_posix() for p in (OUT/'review-set').glob('*.png')},'screenshot set incomplete/extra')
controls=read('tests/controls/playwright_results.json')
check(len(controls)==8 and all(row['status']=='pass' and not row['consoleErrors'] and not row['requestFailures'] for row in controls),'controls matrix failed')
ledger=read('tests/browser-ledger.json')
for script,kind in [('content_r2_1_capture.cjs','review'),('test_controls_reachability.mjs','release')]:
    # Debug arguments are separate historical attempts. Bind the actual full
    # default gate, rather than accidentally selecting an older failing trace.
    record=next((row for row in ledger if Path(row['script']).name==script and row['arguments']==[]),{})
    check(record.get('exit_code')==0 and record.get('pack_sha256')==builds[kind]['pack_sha256'] and record.get('source_manifest_sha256')==manifest_sha,'browser gate/build binding '+script)
check(all(row['exit_code']==0 for row in ledger if row['source_manifest_sha256']==manifest_sha),'current-source browser failure unresolved')
pack=read('tests/pack-isolation.json')
check(pack['status']=='VERIFIED' and pack['checks']==12 and not pack['leaked'] and not pack['physical_project_fallback'] and pack['version']==VERSION,'QA fixture release leak')
check(pack['pack_sha256']==builds['release']['pack_sha256'] and pack['source_manifest_sha256']==manifest_sha,'isolation/build binding')

cleanup=read('tests/cleanup.json')
check(cleanup['status']=='VERIFIED' and not cleanup['missing_initial'],'preexisting files removed')
check(all(not Path(row['target']).exists() for row in cleanup['targets']),'temporary build remains')
allowed_initial_changes={'README.md','native/build-config.json','project.godot','scripts/debug/content_r2_test.gd','scripts/debug/r39_mobile_hud_test.gd','scripts/debug/r42_formation_test.gd','scripts/debug/r43_mobile_tactics_test.gd','scripts/services/formation_relay.gd','scripts/ui/hud.gd','scripts/ui/r33_loot_banner.gd','tools/content_r2_pipeline.py'}
check(set(cleanup['changed_initial'])<=allowed_initial_changes,'unrelated existing dirty files changed: '+str(cleanup['changed_initial']))
secret=re.compile(rb'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}')
hits=[];scanned=0
for directory,dirs,files in os.walk(ROOT):
    dirs[:]=[name for name in dirs if name not in {'.git','node_modules'}]
    for name in files:
        path=Path(directory)/name
        check(not path.is_symlink(),'symlink scan scope '+str(path))
        tail=b''
        with path.open('rb') as stream:
            while block:=stream.read(1024*1024):
                part=tail+block
                if secret.search(part.lower()): hits.append(path.relative_to(ROOT).as_posix());break
                tail=part[-128:]
        scanned+=1
check(not hits,'secret scan hit (paths only)')
result={'status':'VERIFIED' if not failures else 'BLOCKED','checks':checks,'failures':failures,'version':VERSION,'historical_reference':BASE,'runtime_delta':runtime_delta,'gate_scope':'8 relevant Godot CI scenes plus 8 viewport controls, 3 viewport UI checkpoints and 5 real centre gesture/next-input checks; full historical 47-gate suite NOT rerun','screenshot_count':len(images),'secret_scan_files':scanned,'secret_scan_hit_paths':hits,'performance':'not measured; SwiftShader screenshots are not device p95 evidence','overall_quality_score':'not established; no claim of >=9/10'}
(OUT/'tests/delivery-check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
raise SystemExit(0 if not failures else 1)
