"""Exact R4 gate: current executable evidence and byte-preserved older contracts."""
from pathlib import Path
import hashlib,json,re,subprocess,sys,difflib
from PIL import Image
sys.dont_write_bytecode=True
import content_r4_boundary as boundary
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/content/r4'
BASE='0b764c10287124c3fc78b0691dd70e4035d32624'
VERSION='0.33.0-content-r4'
checks=0;failures=[]
def check(value,message):
    global checks
    checks+=1
    if not value:failures.append(message)
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads((OUT/path).read_text(encoding='utf8'))
def old(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
def norm(value):return (value.decode('utf8') if isinstance(value,bytes) else value).replace('\r\n','\n')
def stamp(row):
    p=OUT/row['source_receipt'];value=read(row['source_receipt'])
    check(sha(p)==row['source_receipt_sha256'] and value['unchanged'] and value['before']==value['after'] and bool(value['before']),'source stamp changed/empty '+row.get('scene',''))
    return value['after']
def log(row):
    p=OUT/row['source_receipt'].replace('-source.json','.txt')
    text=p.read_text(encoding='utf8')
    check(row['status']=='VERIFIED' and row['exit_code']==0 and sha(p)==row['log_sha256'] and 'ERROR:' not in text,'runtime log failed '+row.get('scene',''))
    check('--headless' in row['command'] and 'Dummy' in row['command'] and 'content-r4/native-profiles' in row['environment_override']['APPDATA'].replace('\\','/'),'native not silent/isolated')
    check(Path(row['project'])==boundary.SANDBOX and row['protection_before']['status']==row['protection_after']['status']=='VERIFIED' and not row['protection_before']['failures'] and not row['protection_after']['failures'] and row['protection_after']['history_files']==669 and row['protection_after']['initial_files']==2675,'native sandbox/protected bytes guard missing')
    return text

drivers=read('tests/capture-drivers.json')
CAPTURE_OLD='c1d5a6f18b1a27e9b9fa1d3ba5ff5ac1f0648974a0d74da13701559744ead929'
# 769f (Codex) failed closed on stale slider rect; 1c87 adds one corrective endpoint click (Claude takeover).
CAPTURE_CURRENT='1c87ba03562740fe855fa7b3b33a0ea45b169e8c374d193aa8b76267f36bb4e0'
check(drivers['previous_sha256']==CAPTURE_OLD and drivers['current_sha256']==CAPTURE_CURRENT==sha(ROOT/'tools/content_r4_capture.cjs'),'unreviewed capture driver')
for key,digest in [('previous_copy',CAPTURE_OLD),('current_copy',CAPTURE_CURRENT)]:check(sha(OUT/drivers[key])==digest,'capture source archive drift')
old_capture=norm((OUT/drivers['previous_copy']).read_bytes());new_capture=norm((OUT/drivers['current_copy']).read_bytes())
outside=lambda text:text[:text.index('async function resultTraversal(')]+text[text.index('async function milestone('):]
check(outside(old_capture)==outside(new_capture),'capture writer/protection/other mode changed')
battle_tail=lambda text:text[text.index(' let index=0;const expected='):text.index('async function milestone(')]
check(battle_tail(old_capture)==battle_tail(new_capture),'continuous battle/checkpoint policy changed')
addition=" invariant(preparation.flags.ui_scale_index===2,'same natural run lost its live maximum font setting');settingProof.final_live_ui_scale_index=preparation.flags.ui_scale_index;\n"
result_body=lambda text:text[text.index('async function resultTraversal('):text.index('async function battle(')]
check(result_body(new_capture).replace(addition,'')==result_body(old_capture) and new_capture.count(addition)==1,'result traversal changed beyond live scale assertion')
diff=''.join(difflib.unified_diff(old_capture.splitlines(True),new_capture.splitlines(True),fromfile='verified-c1d5-capture.cjs',tofile='current-capture.cjs'))
check((OUT/drivers['diff']).read_text(encoding='utf8')==diff and sha(OUT/drivers['diff'])==drivers['diff_sha256'] and drivers['runtime_or_ci_inputs_changed'] is False,'driver exact delta receipt differs')
expected_driver=lambda mode:CAPTURE_CURRENT if mode=='escort' else CAPTURE_OLD

version=re.search(r'^config/version="([^"]+)"',(ROOT/'project.godot').read_text(encoding='utf8'),re.M)[1]
check(version==VERSION and VERSION in (ROOT/'README.md').read_text(encoding='utf8'),'version/README mismatch')
native=json.loads((ROOT/'native/build-config.json').read_text(encoding='utf8'));prior=json.loads(old('native/build-config.json'))
check(native['sourceVersion']==VERSION and {k:v for k,v in native.items() if k!='sourceVersion'}=={k:v for k,v in prior.items() if k!='sourceVersion'},'native build/store counters changed')
check(norm((ROOT/'export_presets.cfg').read_bytes())==norm(old('export_presets.cfg')),'export presets changed')
check('res://scenes/ui/MainMenu.tscn' in (ROOT/'project.godot').read_text(encoding='utf8'),'QA entry in release header')
check(subprocess.check_output(['git','branch','--show-current'],cwd=ROOT).strip()==b'main','wrong branch')
history=read('tests/historical.json');check(history['base']==BASE and len(history['files'])==669,'history baseline drift')
for name,digest in history['files'].items():check((ROOT/name).is_file() and sha(ROOT/name)==digest,'frozen evidence changed '+name)
initial=read('tests/initial-files.json')['files'];check(len(initial)==2675,'initial protection count')
external={row['path']:row for row in read('tests/external-changes.json')}
check(set(external).issubset({'docs/CONTENT_R4_BRIEF.md','docs/專案導航.md'}),'unbounded foreign exception')
for name,row in initial.items():
    check((ROOT/name).is_file() and sha(ROOT/name)==external.get(name,{}).get('after_sha256',row['sha256']),'foreign initial file changed '+name)
for name,row in external.items():check(row['owner']=='primary supervisor' and row['before_sha256']==initial[name]['sha256'] and row['authorization'] and sha(ROOT/name)==row['after_sha256'],'unauthorized foreign change')
for name in ['verify_content_r1.py','verify_content_r2.py','verify_content_r2_1.py','verify_content_r3.py']:
    current=norm((ROOT/'tools'/name).read_bytes())
    check(re.sub(r'# R4_EXACT_ROUTE_START\n.*?# R4_EXACT_ROUTE_END\n','',current,flags=re.S)==norm(old('tools/'+name)),'older verifier body changed '+name)
for name in subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'scripts/debug'],cwd=ROOT).decode().splitlines():
    if not name.endswith('.gd'):continue
    current=norm((ROOT/name).read_bytes())
    if name.endswith('r14_regression_test.gd'):current=current.replace(VERSION,'0.32.0-content-r3')
    check(current==norm(old(name)),'legacy assertion changed '+name)

sources=read('tests/source-hashes.json');manifest_sha=sha(OUT/'tests/source-hashes.json')
check(sources['version']==VERSION and len(sources['files'])>=630,'runtime source coverage missing')
for name,digest in sources['files'].items():check((ROOT/name).is_file() and sha(ROOT/name)==digest,'current build source changed '+name)
builds=read('tests/builds.json')
for kind in ['release','review']:
    check(builds[kind]['source_manifest_sha256']==manifest_sha and builds[kind]['root_headers_unchanged'] and builds[kind]['release_entry_restored'],'build source binding '+kind)
    check(builds[kind]['pack_sha256']==builds[kind]['files']['index.pck'],'actual PCK receipt '+kind)
    check(builds[kind]['export_driver_sha256']==sha(ROOT/'tools/content_r4_pipeline.py'),'export driver drift')
before=read('tests/ci-source-before.json');after=read('tests/ci-source-after.json')
check(before==after and bool(before) and set(sources['files']).issubset(before),'CI lacks full pre/post executable source binding')
for name,row in after.items():check(sha(ROOT/name)==row['sha256'],'CI current source drift '+name)
contract=read('tests/ci-contract.json');gates=read('tests/gates/summary.json')
check(len(gates)==50 and contract['base_gate_count']==49 and contract['new_gate_count']==50,'CI gate count')
workflow=(ROOT/'.github/workflows/deploy-web.yml').read_text(encoding='utf8')
def scenes(text):return re.findall(r'^\s+([A-Za-z0-9]+)\s*$',re.search(r'scenes=\((.*?)\n\s*\)',text,re.S)[1],re.M)+['R31EndgameGate']
check(scenes(workflow)==contract['native_scenes'] and [s for s in scenes(workflow) if s!='ContentR4Test']==scenes(norm(old('.github/workflows/deploy-web.yml'))),'49 existing CI scope changed')
check({r['scene'] for r in gates if 'scene'in r}==set(contract['native_scenes']) and {r['script'] for r in gates if 'script'in r}==set(contract['node_scripts']) and len(contract['node_scripts'])==3,'CI parsed gate list mismatch')
for row in gates:
    if 'scene'in row:
        log(row);current=stamp(row)
        check(current==after,'CI per-case source differs')
    else:
        p=OUT/'tests/gates'/(Path(row['script']).name+'.txt')
        check(row['status']=='VERIFIED' and row['exit_code']==0 and sha(p)==row['log_sha256'],'Node gate failed/changed')
for name,count in [('mechanics.json',1),('r3-mechanics.json',5000),('r2-mechanics.json',244),('r2-1-ui-regression.json',120)]:
    row=read('tests/'+name);check(row['status']=='VERIFIED' and row['checks']>=count and not row['failures'],'mechanics failed '+name)
r4=read('tests/mechanics.json')
check({tuple(r['viewport']) for r in r4['viewports']}=={(320,568),(844,390),(1366,600)} and len(r4['event_chains'])==4,'new UI/real event cases missing')
for row in r4['viewports']:
    fonts=row['scale_fonts']
    check([r['index'] for r in fonts]==[0,1,2] and [r['multiplier'] for r in fonts]==[.92,1,1.16] and fonts[2]['detail_font']>fonts[1]['detail_font'] and fonts[2]['roster_font']>fonts[1]['roster_font'] and fonts[2]['button_font']>fonts[1]['button_font'] and row['max_result_font']==16 and row['max_journal_font']==15,'maximum font silently clamped')
    check(len(row['paged_ids'])==9 and len(set(row['paged_ids']))==9 and row['roles_per_page']==(1 if row['viewport']==[320,568] else 2) and row['actual_equipment_descriptions']==12,'real hero pagination/equipment text cases missing')
r1=read('tests/r1-mechanics.json');raw=(OUT/'tests/gates/ContentR1Test.txt').read_text(encoding='utf8');count=re.search(r'CONTENT_R1_PASS checks=(\d+) failures=0',raw)
check(count and int(count[1])==r1['checks'] and r1['status']=='VERIFIED' and not r1['failures'],'R1 raw/JSON result differs')
check({(r['width'],r['height']) for r in r1['viewports']}=={(390,844),(430,932),(844,390),(1366,600),(768,1024),(1024,768)} and len(r1['viewports'])==6,'R1 required six viewport branches missing')

controls=read('tests/controls.json')
check(len(controls)==8 and {(r['width'],r['height'],r['scale']) for r in controls}=={(w,h,s) for w,h in [(844,390),(390,844),(320,568),(1366,600)] for s in [1,2]},'new UI actual input matrix')
for row in controls:check(len(row['pages'])==18 and row['normal_unlock_equip_clear_close_reopen_launch'] and not row['errors'] and not row['external_requests'] and row['source_manifest_sha256']==manifest_sha and row['pack_sha256']==builds['release']['pack_sha256'],'new UI real input failed/source drift')
result_ui=read('tests/result-controls.json')
check(result_ui['status']=='VERIFIED' and result_ui['width']==320 and result_ui['height']==568 and result_ui['scale']==2 and result_ui['input']=='touch' and result_ui['setting_saved_reload']['actual_reload_verified'] and result_ui['setting_saved_reload']['main_menu']['flags']['ui_scale_index']==2,'short-phone maximum-font real result control path missing')
check(len(result_ui['expected_ids'])==9 and len(set(result_ui['expected_ids']))==9 and result_ui['visited_ids']['0']==result_ui['expected_ids'] and result_ui['visited_ids']['1']==result_ui['expected_ids'] and result_ui['preparation_after']['flags']['visible'] and result_ui['controlled_hero_injection'] is False,'real nine hero cards omitted/duplicated or injected')
check(result_ui['preparation_after']['flags']['ui_scale_index']==result_ui['setting_saved_reload']['final_live_ui_scale_index']==2,'same-run live maximum font readback missing')
setting=result_ui['setting_saved_reload']['review_live_ui'];check(sha(OUT/setting['file'])==setting['sha256'] and setting['paused']['flags']['paused'] and setting['source_manifest_sha256']==manifest_sha and setting['pack_sha256']==builds['review']['pack_sha256'],'official pause setting screenshot/source missing')
check(result_ui['capture_driver_sha256']==sha(ROOT/'tools/content_r4_capture.cjs') and result_ui['source_manifest_sha256']==manifest_sha and result_ui['pack_sha256']==builds['review']['pack_sha256'],'result UI executable/source binding')
paired={team:read('tests/paired/'+team+'.json') for team in ['assault','escort']};runner=read('tests/paired/runner.json')
check(len(runner)==2,'native paired runner missing')
for row in runner:
    log(row);bound=stamp(row)
    check(bound==after,'paired execution source differs from CI/final')
    fresh=row['freshness'];data=next(value for value in paired.values() if value['evidence_token']==fresh['attempt_id'])
    check(row['expected_output_valid'] and row['copyback'] and row['copyback']['sha256']==fresh['source_sha256']==sha(OUT/row['copyback']['destination']) and fresh['expected_seed']==data['seed']==55210 and fresh['starting_run_id']==data['starting_run_id'] and fresh['started_ns']-2_000_000_000<=fresh['mtime_ns']<=fresh['finished_ns']+2_000_000_000,'fresh native result token/seed/run ID/mtime/copyback mismatch')
    check(re.fullmatch(r'[0-9a-f]{32}',fresh['attempt_id']) and fresh['attempt_id'] in row['isolated_expected_source'] and row['isolated_expected_source'].startswith(str(boundary.SANDBOX/'docs/content/r4/tests/paired')),'native unique isolated result path missing')
for row in paired.values():check(row['status']=='VERIFIED' and row['version']==VERSION and row['outcome']=='win' and row['seals']==3 and len(row['history'])==3 and row['campaign_clear'] and row['seed']==55210,'formal continuous run failed')
for key in ['shards','lifetime','upgrades','vouchers','valid_settlements','wallet_gold','campaign_clears']:check(paired['assault']['initial'][key]==paired['escort']['initial'][key],'unequal initial economy '+key)
phase=lambda row,kind:next(r for r in row['phases'].values() if r['kind']==kind)
a=phase(paired['assault'],'front');e=phase(paired['escort'],'front')
check(a['seal_seconds']<e['seal_seconds']*.97 and paired['assault']['benefits']['shield_damage']>0,'assault observed front advantage missing')
a=phase(paired['assault'],'pincer');e=phase(paired['escort'],'pincer')
check(e['taken_per_start_capacity']<a['taken_per_start_capacity']*.9,'escort observed normalized pincer advantage missing')
check(phase(paired['escort'],'front')['actual_formation']=='ring' and phase(paired['assault'],'front')['actual_formation']=='wedge','actual formation tradeoff missing')

samples=read('tests/samples.json');manifest=read('review-manifest.json')
check(len(samples)==15 and len(manifest)==15 and len(list((OUT/'review-set').glob('*.png')))==15,'review set not exactly 15 raw images')
for index,row in enumerate(samples,1):
    p=OUT/row['file']
    check(p.name.startswith('%02d-'%index) and sha(p)==row['sha256'] and row['version']==VERSION and not row['postprocessed'],'image hash/version/processing')
    with Image.open(p) as image:check(list(image.size)==row['dimensions'],'image dimensions')
    check(row['source_manifest_sha256']==manifest_sha and row['pack_sha256'] in {b['pack_sha256'] for b in builds.values()} and not row['errors'] and not row['external_requests'] and row['provenance'] and 'SwiftShader' in row['renderer'],'image executable provenance')
    check(row['capture_driver_sha256']==(CAPTURE_CURRENT if index in [5,7,13] else CAPTURE_OLD),'image exact driver provenance drift')
    check(bool(re.fullmatch(r'\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z',row['captured_utc'])),'image UTC missing')
    check(all(manifest[index-1][key]==row[key] for key in ['file','sha256','dimensions','version','captured_utc','pack_sha256','source_manifest_sha256','provenance']),'manifest/sample mismatch')
check(sum(r['dimensions']==[2532,1170] for r in samples)==12 and samples[0]['dimensions']==[960,1704] and samples[2]['dimensions']==[2732,1200] and samples[12]['dimensions']==[1170,2532],'review viewport/DPR contract')
for team in ['assault','escort']:
    rows=[r for r in samples if r.get('team')==team and r.get('label')in ['front-active','pincer-active','victory']]
    check({r['label'] for r in rows}=={'front-active','pincer-active','victory'} and all(not r['audio_gate_visible'] for r in rows),'actual continuous battle samples missing '+team)
guards=[r for r in samples if r.get('label','').startswith('guard-')]
check([r['label'] for r in guards]==['guard-warning','guard-impact','guard-recovery'] and guards[0]['time']<guards[1]['time']<guards[2]['time'],'guard sequence chronology')
states=[r['guards'][-1] for r in guards]
check(len({(r['id'],r['token']) for r in states})==1 and states[0]['telegraph']>0 and states[1]['impacts']>states[0]['impacts'] and states[2]['recoveries']>states[0]['recoveries'],'guard same-actor anticipation/impact/recovery missing')
milestone=next(r for r in samples if r.get('label')=='fourth-defeat')
check(milestone['settlements']==4 and milestone['vouchers']==1 and milestone['captain_dead'] and milestone['restart_text']=='免費整備' and milestone['ui_scale_index']==2,'real early fourth defeat/fifth choice missing')
check([r['settlements'] for r in milestone['progress_history']]==[1,2,3,4] and all(str(i+1)+'/4' in r['text'] for i,r in enumerate(milestone['progress_history'][:3])) and milestone['progress_history'][3]['vouchers']==1,'visible one-time progress chain missing')
for receipt in read('tests/browser-ledger.json'):
    p=OUT/'tests'/('browser-'+receipt['mode']+'.txt')
    check(receipt['exit_code']==0 and sha(p)==receipt['log_sha256'] and receipt['source_manifest_sha256']==manifest_sha,'browser run failed/changed')
    check(receipt['capture_driver_before_sha256']==receipt['capture_driver_after_sha256']==expected_driver(receipt['mode']),'browser exact before/after driver binding')
    check(receipt['protection_before']['status']==receipt['protection_after']['status']=='VERIFIED' and not receipt['protection_before']['failures'] and not receipt['protection_after']['failures'],'browser protected files changed')
check({r['mode'] for r in read('tests/browser-ledger.json')}=={'controls','preparation','assault','escort','milestone'},'browser required modes missing')
incident=read('tests/attempts/misrouted-native-output/boundary-incident.json')
check(incident['status']=='RESTORED_BYTE_EXACT' and len(incident['files'])==1,'boundary incident provenance missing')
for row in incident['files']:
    check(sha(ROOT/row['path'])==row['restored_sha256']==history['files'][row['path']] and sha(ROOT/row['misrouted_copy'])==row['misrouted_sha256'],'misrouted raw/restored original bytes mismatch')
attempts=read('tests/attempt-summary.json')
check(attempts['native_counts']['wrong_destination_win']==1 and attempts['native_counts']['terminated']==1 and attempts['native_counts']['accepted_final_wins']==2 and attempts['native_counts']['total']==len(attempts['native_paired_calls']) and attempts['native_counts']['total']>=4,'wrong-destination/terminated native attempts hidden')
pack=read('tests/pack-isolation.json')
check(pack['status']=='VERIFIED' and not pack['leaked'] and pack['physical_project_fallback'] is False and pack['pack_sha256']==builds['release']['pack_sha256'],'debug fixture in actual release pack')
scan=read('tests/secret-scan.json')
check(scan['status']=='VERIFIED' and not scan['hit_paths'] and scan['source_manifest_sha256']==manifest_sha and scan['pack_sha256']=={k:v['pack_sha256'] for k,v in builds.items()},'actual pack secret scan missing')
profile_before=read('tests/default-profile-before.json');profile_after=read('tests/default-profile-after.json')
check(profile_before['files']==profile_after['files'],'default native profiles touched')
cleanup=read('tests/cleanup.json')
check(cleanup['status']=='VERIFIED' and not cleanup['missing_initial'] and not cleanup['unexpected_changed_initial'] and not (ROOT/'.audit-tmp/content-r4').exists() and not (ROOT/'export/content-r4').exists(),'own cleanup/protection failed')
for name in ['docs/OPTIM_PLAN_CONTENT_R4.md','docs/CODEX_RESPONSE_CONTENT_R4.md','docs/content/r4/INDEX.md']:check((ROOT/name).is_file(),'missing handoff '+name)
owned=read('tests/owned-files.json');paths=set(owned['paths'])
check(len(paths)==owned['file_count'] and not paths.intersection(initial),'owned manifest includes foreign initial file')
check(all(p.startswith('docs/content/r4/') or p in owned['allowed_owned_paths_outside_evidence'] for p in paths) and not any(p.startswith('docs/content/CONTENT_REVIEW_') for p in paths),'unapproved authored path')
staged=set(filter(None,subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=ROOT).decode('utf8').split('\0')))
check(not staged or staged==paths,'index contains foreign/incomplete authored changes')
tracked=set(filter(None,subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode('utf8').split('\0')))
check(paths.issubset(tracked),'owned changes not explicitly staged/committed')
pattern=re.compile(rb'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}');hits=[]
for p in {ROOT/name for name in sources['files']}|{ROOT/name for name in paths if not name.endswith('delivery-check.json')}:
    tail=b''
    with p.open('rb') as handle:
        while chunk:=handle.read(1048576):
            if pattern.search((tail+chunk).lower()):hits.append(p.relative_to(ROOT).as_posix());break
            tail=chunk[-128:]
check(not hits,'secret scan paths only '+str(hits))
result={'status':'VERIFIED' if not failures else 'BLOCKED','checks':checks,'failures':failures,'version':VERSION,'base':BASE,'scope':'49 preserved existing CI + R4, real runtime event chains and font scaling, 8 true input cases, 2 continuous same-seed runs, 15 raw current images, frozen evidence and default profile preservation','quality_score':'not established by technical gate; independent content review pending; no >=9 claim'}
boundary.write_json(OUT/'tests/delivery-check.json',result)
print(json.dumps(result,ensure_ascii=False));raise SystemExit(0 if not failures else 1)
