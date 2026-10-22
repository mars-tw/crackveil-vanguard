"""Strict current-round evidence gate. Exact dispatch preserves all older gates."""
from pathlib import Path
import hashlib,json,re,subprocess
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/content/r3'
VERSION='0.32.0-content-r3';BASE='ce94e02'
checks=0;failures=[]
def check(value,message):
    global checks
    checks+=1
    if not value:failures.append(message)
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads((OUT/path).read_text(encoding='utf8'))
def prior(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
def normalized(data):return (data.decode('utf8') if isinstance(data,bytes) else data).replace('\r\n','\n')
version=re.search(r'^config/version="([^"]+)"',(ROOT/'project.godot').read_text(encoding='utf8'),re.M)[1]
check(version==VERSION and VERSION in (ROOT/'README.md').read_text(encoding='utf8'),'version/README drift')
native=json.loads((ROOT/'native/build-config.json').read_text(encoding='utf8'));old=json.loads(prior('native/build-config.json'))
check(native['sourceVersion']==VERSION and {k:v for k,v in native.items() if k!='sourceVersion'}=={k:v for k,v in old.items() if k!='sourceVersion'},'native counters changed')
check(normalized((ROOT/'export_presets.cfg').read_bytes())==normalized(prior('export_presets.cfg')),'export presets changed')
check('res://scenes/ui/MainMenu.tscn' in (ROOT/'project.godot').read_text(encoding='utf8'),'QA entry leaked')
check(subprocess.check_output(['git','branch','--show-current'],cwd=ROOT).strip()==b'main','wrong branch')
history=read('tests/historical.json');check(history['base']==BASE,'wrong frozen history base')
for name,digest in history['files'].items():check((ROOT/name).is_file() and sha(ROOT/name)==digest,'frozen evidence changed '+name)
check(subprocess.run(['git','diff','--quiet',BASE,'--','docs/content/r2','docs/content/r2-1'],cwd=ROOT).returncode==0,'frozen tracked evidence changed')
external={row['path']:row for row in read('tests/external-changes.json')}
for name,row in read('tests/initial-files.json').items():
    check((ROOT/name).is_file(),'initial file removed '+name)
    if (ROOT/name).is_file():check(sha(ROOT/name)==external.get(name,{}).get('after_sha256',row['sha256']),'unrelated dirty file changed '+name)
check(set(external)=={'docs/CONTENT_R3_BRIEF.md','docs/專案導航.md'},'unexpected foreign exception set')
for name,row in external.items():check(row['owner']=='primary supervisor' and row['before_sha256']==read('tests/initial-files.json')[name]['sha256'] and sha(ROOT/name)==row['after_sha256'],'unauthorized external exception')
for name in ['verify_content_r1.py','verify_content_r2.py','verify_content_r2_1.py']:
    current=(ROOT/'tools'/name).read_text(encoding='utf8')
    stripped=re.sub(r'# R3_EXACT_ROUTE_START\n.*?# R3_EXACT_ROUTE_END\n','',normalized(current),flags=re.S)
    check(stripped==normalized(prior('tools/'+name)),'historical verifier body changed '+name)
for path in subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'scripts/debug'],cwd=ROOT).decode().splitlines():
    if not path.endswith('.gd'):continue
    current=normalized((ROOT/path).read_bytes())
    if path.endswith('r14_regression_test.gd'):current=current.replace(VERSION,'0.31.1-content-r2.1')
    check(current==normalized(prior(path)),'legacy test assertion changed '+path)
sources=read('tests/source-hashes.json')['files'];manifest_sha=sha(OUT/'tests/source-hashes.json')
for name,digest in sources.items():check((ROOT/name).is_file() and sha(ROOT/name)==digest,'source after build changed '+name)
builds=read('tests/builds.json')
for kind in ['review','release']:check(builds[kind]['source_manifest_sha256']==manifest_sha and builds[kind]['root_headers_unchanged'] and builds[kind]['release_entry_restored'],'build source mismatch '+kind)
contract=read('tests/ci-contract.json');gates=read('tests/gates/summary.json')
check(len(gates)==49 and contract['base_gate_count']==48 and contract['new_gate_count']==49,'CI scope count')
workflow=(ROOT/'.github/workflows/deploy-web.yml').read_text(encoding='utf8')
block=re.search(r'scenes=\((.*?)\n\s*\)',workflow,re.S)[1]
scenes=re.findall(r'^\s+([A-Za-z0-9]+)\s*$',block,re.M)+['R31EndgameGate']
check(scenes==contract['native_scenes'] and set(scenes)=={r['scene'] for r in gates if 'scene' in r},'CI scenes mismatch')
check(len(contract['node_scripts'])==3 and {r['script'] for r in gates if 'script' in r}==set(contract['node_scripts']),'Node scope mismatch')
for row in gates:
    name=row.get('scene',Path(row.get('script','')).name);p=OUT/'tests/gates'/(name+'.txt')
    check(row['status']=='VERIFIED' and row['exit_code']==0 and sha(p)==row['log_sha256'],'CI failed or log changed '+name)
    check('ERROR:' not in p.read_text(encoding='utf8'),'CI engine ERROR '+name)
    if 'scene'in row:check('--headless' in row['command'] and row['command'][row['command'].index('--audio-driver')+1]=='Dummy' and 'content-r3/native-profiles' in row['environment_override']['APPDATA'].replace('\\','/'),'CI silent isolation '+name)
binding=read('tests/ci-source-binding.json')
check(binding['pre_execution_hash_available'] is False and binding['limitation'] and binding['followup_scenes']==['R29MenuModalTest','R43MobileTacticsTest','ContentR3Test'],'honest CI source binding missing')
follow=read('tests/menu-followup/summary.json')
check({r['scene'] for r in follow}==set(binding['followup_scenes']),'affected menu checks missing')
for row in follow:
    p=OUT/'tests/menu-followup'/(row['scene']+'.txt');stamp=read(row['source_receipt'])
    check(row['status']=='VERIFIED' and row['exit_code']==0 and sha(p)==row['log_sha256'] and 'ERROR:' not in p.read_text(encoding='utf8'),'menu followup failed')
    check(stamp['unchanged'] and stamp['before']==stamp['after'] and sha(OUT/row['source_receipt'])==row['source_receipt_sha256'],'menu source receipt changed')
for name,count in [('mechanics.json',5000),('r2-mechanics.json',244),('r2-1-ui-regression.json',120)]:
    row=read('tests/'+name);check(row['status']=='VERIFIED' and row['checks']>=count and not row['failures'],'mechanics regression '+name)
r1=read('tests/r1-mechanics.json');r1_log=(OUT/'tests/gates/ContentR1Test.txt').read_text(encoding='utf8')
r1_count=re.search(r'CONTENT_R1_PASS checks=(\d+) failures=0',r1_log)
check(r1['status']=='VERIFIED' and not r1['failures'] and r1_count and int(r1_count[1])==r1['checks'],'R1 raw/receipt assertion result mismatch')
check({(row['width'],row['height']) for row in r1['viewports']}=={(390,844),(430,932),(844,390),(1366,600),(768,1024),(1024,768)} and len(r1['viewports'])==6,'R1 fixed viewport branches missing')
trace=read('tests/r1-count/trace-comparison.json');baseline_trace=trace['records']['baseline'];current_trace=trace['records']['current']
check(trace['same_original_test'] and trace['baseline_commit']==BASE and not trace['label_differences'] and not trace['baseline_only_calls'] and not trace['current_only_calls'],'R1 ce94/current assertion trace differs')
check(baseline_trace['calls']==current_trace['calls'] and len(current_trace['calls'])==r1['checks'] and baseline_trace['labels']==current_trace['labels'] and len(current_trace['labels'])==49,'R1 dynamic glyph count/required fits branches unexplained')
for name,row in [('baseline',baseline_trace),('current',current_trace)]:
    check(row['exit_code']==0 and row['result']['status']=='VERIFIED' and not row['result']['failures'] and sha(OUT/'tests/r1-count'/name/'trace.txt')==row['log_sha256'],'R1 traced original assertions failed '+name)
check(current_trace['test_source_sha256']==hashlib.sha256(normalized((ROOT/'scripts/debug/content_r1_test.gd').read_bytes()).encode()).hexdigest(),'R1 trace original test source changed')
attempts=read('tests/attempt-summary.json')
for kind,key in [('native_paired_calls','native_counts'),('web_battle_pilot_calls','web_counts')]:
    entries=attempts[kind]
    check(len(entries)==attempts[key]['total'] and len({json.dumps(r['record'],sort_keys=True) for r in entries})==len(entries),'attempt denominator lost/duplicated calls '+kind)
    for row in entries:check(row['record'] in read(row['receipt']),'attempt no longer matches original receipt '+row['receipt'])
check(attempts['native_counts']=={'total':11,'verified':8,'blocked':3,'exit_124':1} and attempts['web_counts']=={'total':8,'exit_0':6,'exit_nonzero':2},'pilot failures/aborted calls omitted')
no_clear_log=(OUT/'tests/attempts/final-concurrent-limits/browser-assault.txt').read_text(encoding='utf8')
check('"outcome":"no_clear"' in no_clear_log and '180.040066666666' in no_clear_log,'failed Web pilot raw outcome removed')
mechanics=read('tests/mechanics.json')
check(len(mechanics['atomic_cases'])==12 and all(r['recovered'] and (r['committed'] or r['before_sha256']==r['after_sha256']) for r in mechanics['atomic_cases']),'transaction interruption contract')
check(read('tests/default-profile-before.json')==read('tests/default-profile-after.json'),'real default profiles changed')
profile=read('tests/profile-isolation.json');check(profile['before_snapshot_scope']=='before first game-mechanics scene; after editor imports' and profile['default_hash_differences']==[],'profile boundary misreported')
font=read('tests/font-coverage.json');check(font['missing']==[] and font['font_sha256']==sha(ROOT/'assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf'),'new UI glyphs missing')
controls=read('tests/controls.json')
check(len(controls)==8 and {(r['width'],r['height'],r['scale']) for r in controls}=={(w,h,s) for w,h in [(844,390),(390,844),(320,568),(1366,600)] for s in [1,2]},'new UI viewport/scale matrix')
for row in controls:check(len(row['pages'])==18 and row['normal_unlock_equip_clear_close_reopen_launch'] and not row['errors'] and not row['external_requests'] and row['source_manifest_sha256']==manifest_sha and row['pack_sha256']==builds['release']['pack_sha256'],'new UI true input failed')
paired={team:read('tests/paired/'+team+'.json') for team in ['assault','escort']}
runner=read('tests/paired/runner.json');check(len(runner)==2 and all(r['status']=='VERIFIED' and r['exit_code']==0 for r in runner),'continuous run engine failure')
for record in runner:
    job='paired-'+record['command'][-2].split('=')[1];p=OUT/'tests'/job/'ContentR3Run.txt';stamp=read(record['source_receipt'])
    check(sha(p)==record['log_sha256'] and 'ERROR:' not in p.read_text(encoding='utf8'),'continuous log mismatch')
    check(sha(OUT/record['source_receipt'])==record['source_receipt_sha256'] and stamp['unchanged'] and stamp['before']==stamp['after'] and bool(stamp['after']),'continuous source changed/empty/receipt unbound')
    required={name for name in sources if (name.startswith(('scripts/','scenes/','resources/')) and Path(name).suffix in {'.gd','.gdshader','.tscn','.tres'}) or name in {'project.godot','export_presets.cfg','assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf'}}
    required|={'scripts/debug/content_r3_run.gd','scripts/debug/content_r2_run.gd','scenes/debug/ContentR3Run.tscn'}
    check(required.issubset(stamp['after']),'continuous source coverage incomplete')
    for name in required:check(stamp['after'].get(name,{}).get('sha256')==sha(ROOT/name),'continuous/current executable dependency source mismatch '+name)
qa_delta=read('tests/qa-only-delta.json');original=OUT/qa_delta['before_copy'];intermediate=OUT/qa_delta['after_copy']
check(sha(original)==qa_delta['before_sha256'] and sha(intermediate)==qa_delta['after_sha256'],'archived QA-only delta mismatch')
check(original.read_text(encoding='utf8').replace(qa_delta['old_expression'],qa_delta['new_expression'])==intermediate.read_text(encoding='utf8') and qa_delta['superseded_scope'],'archived QA fix changed beyond expired-player read or misrepresented as final')
for path in ['scripts/debug/content_r3_run.gd','scripts/debug/content_r2_run.gd','scenes/debug/ContentR3Run.tscn']:check('content_r3_review.gd' not in (ROOT/path).read_text(encoding='utf8') and 'ContentR3Review.tscn' not in (ROOT/path).read_text(encoding='utf8'),'native entry unexpectedly loads Web review fixture')
qa_before=read(qa_delta['before_source_manifest'])
check(sha(OUT/qa_delta['before_source_manifest'])==qa_delta['before_source_manifest_sha256'] and set(qa_before['files'])==set(sources),'QA-only prior manifest missing/changed')
check(qa_before['files'][qa_delta['path']]==qa_delta['before_sha256'],'archived QA before source mismatch')
for row in paired.values():check(row['status']=='VERIFIED' and row['version']==VERSION and row['outcome']=='win' and row['seals']==3 and len(row['history'])==3 and row['campaign_clear'] and row['seed']==55210 and row['initial']['shards']==0 and row['initial']['vouchers']==0 and row['initial']['valid_settlements']==0,'normal fresh equivalent run incomplete')
for key in ['shards','lifetime','upgrades','vouchers','valid_settlements','wallet_gold','campaign_clears']:check(paired['assault']['initial'][key]==paired['escort']['initial'][key],'unequal initial economy/progress '+key)
def phase(row,kind):return next(v for v in row['phases'].values() if v['kind']==kind)
assault=paired['assault'];escort=paired['escort'];a=phase(assault,'front');e=phase(escort,'front')
check(a['seal_seconds']<e['seal_seconds']*.97 and assault['benefits']['shield_damage']>0,'assault has no observed front advantage')
a=phase(assault,'pincer');e=phase(escort,'pincer')
check(e['taken_per_start_capacity']<a['taken_per_start_capacity']*.9,'escort has no normalized pincer advantage')
check(phase(escort,'front')['actual_formation']=='ring' and phase(assault,'front')['actual_formation']=='wedge','actual alternative formation not used')
samples=read('tests/samples.json');check(len(samples)==15 and len(list((OUT/'review-set').glob('*.png')))==15,'review set not exactly 15')
manifest=read('review-manifest.json');check(len(manifest)==15,'review manifest count')
for index,row in enumerate(samples,1):
    p=OUT/row['file'];check(p.name.startswith('%02d-'%index) and sha(p)==row['sha256'] and row['version']==VERSION and not row['postprocessed'],'image changed/old/processed')
    with Image.open(p) as im:check(list(im.size)==row['dimensions'],'image dimensions')
    check(row['source_manifest_sha256']==manifest_sha and row['pack_sha256'] in [builds[k]['pack_sha256'] for k in builds] and not row['errors'] and not row['external_requests'] and row['provenance'],'image source/runtime provenance')
    check(bool(re.fullmatch(r'\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z',row['captured_utc'])) and 'SwiftShader' in row['renderer'],'image capture time/software renderer evidence')
    check(all(manifest[index-1][key]==row[key] for key in ['file','sha256','dimensions','version','captured_utc','pack_sha256','source_manifest_sha256','provenance']),'review manifest/sample mismatch')
    warning_active=False
    for warning in row['known_uid_warnings']:
        if re.fullmatch(r"WARNING: 'res://[^']+': In external resource #\d+, invalid UID: 'uid://[^']+' - using text path instead: 'res://[^']+'\.",warning):warning_active=True;continue
        check(warning_active and bool(re.fullmatch(r'\s+at: open \(core/io/resource_format_binary\.cpp:1028\)|\s+GDScript backtrace \(most recent call first\):|\s+\[\d+\] [A-Za-z0-9_]+ \(res://scripts/[A-Za-z0-9_/-]+\.gd:\d+\)',warning)),'unknown engine diagnostic misclassified as UID warning')
check(sum(r['dimensions']==[2532,1170] for r in samples)>=12 and any(r['height']>r['width'] for r in samples) and any(r['width']==1366 and r['height']==600 for r in samples),'review mobile/portrait/short-desktop contract')
for team in ['assault','escort']:
    rows=[r for r in samples if r.get('team')==team and r.get('label')in ['front-active','pincer-active','victory']]
    check({r['label'] for r in rows}=={'front-active','pincer-active','victory'} and all(not r['audio_gate_visible'] for r in rows),'natural battle images missing '+team)
guards=[r for r in samples if r.get('label','').startswith('guard-')]
check([r['label'] for r in guards]==['guard-warning','guard-impact','guard-recovery'] and guards[0]['time']<guards[1]['time']<guards[2]['time'],'guardian cycle not chronological')
states=[row['guards'][-1] for row in guards]
check(len({(r['id'],r['token']) for r in states})==1 and states[0]['animation']=='attack' and states[0]['telegraph']>0 and states[1]['impacts']>states[0]['impacts'] and states[2]['recoveries']>states[0]['recoveries'],'guardian samples do not prove same actor actual anticipation/impact/recovery')
milestone=next(r for r in samples if r.get('label')=='fourth-defeat')
check(milestone['settlements']==4 and milestone['vouchers']==1 and milestone['captain_dead'] and milestone['restart_text']=='免費整備' and milestone['ui_scale_index']==2,'fourth real terminal/max-scale short control missing')
buttons=list(milestone['footer_buttons'].values());check(len(buttons)==3,'fourth result footer coverage')
for x,y,w,h in buttons:check(x>=0 and y>=0 and w>=44 and h>=44 and x+w<=844.5 and y+h<=390.5,'fourth max-scale footer out of viewport')
for index,a in enumerate(buttons):
    for b in buttons[index+1:]:check(not(a[0]<b[0]+b[2] and a[0]+a[2]>b[0] and a[1]<b[1]+b[3] and a[1]+a[3]>b[1]),'fourth result footer overlap')
pack=read('tests/pack-isolation.json');check(pack['status']=='VERIFIED' and not pack['leaked'] and pack['excluded_debug_paths']>=60 and pack['physical_project_fallback'] is False and pack['pack_sha256']==builds['release']['pack_sha256'],'QA fixture release isolation failed')
for path in ['docs/OPTIM_PLAN_CONTENT_R3.md','docs/CODEX_RESPONSE_CONTENT_R3.md','docs/content/r3/INDEX.md']:check((ROOT/path).is_file(),'missing handoff '+path)
cleanup=read('tests/cleanup.json');check(cleanup['status']=='VERIFIED' and not cleanup['missing_initial'] and not cleanup['unexpected_changed_initial'],'own cleanup/protection failed')
check(not (ROOT/'.audit-tmp/content-r3').exists() and not (ROOT/'export/content-r3').exists(),'own temporary build remains')
owned=read('tests/owned-files.json');owned_paths=set(owned['paths']);initial_paths=set(read('tests/initial-files.json'))
check(len(owned_paths)==owned['file_count'] and not (owned_paths&initial_paths),'own file manifest includes initial dirty paths/duplicates')
check(not any(p.startswith('docs/content/CONTENT_REVIEW_') for p in owned_paths) and all(p.startswith('docs/content/r3/') or p in owned['allowed_owned_paths_outside_evidence'] for p in owned_paths),'foreign review or unauthored path in own stage manifest')
tracked=set(subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode('utf8').strip('\0').split('\0'))
check(owned_paths.issubset(tracked),'owned file missing from explicit index/commit')
staged=set(filter(None,subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=ROOT).decode('utf8').split('\0')))
check(not staged or staged==owned_paths,'index contains foreign files or an incomplete own stage')
pack_scan=read('tests/secret-scan.json');check(pack_scan['status']=='VERIFIED' and not pack_scan['hit_paths'] and pack_scan['source_manifest_sha256']==manifest_sha and pack_scan['pack_sha256']=={k:v['pack_sha256'] for k,v in builds.items()},'release secret scan missing/unbound')
secret=re.compile(rb'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}');hits=[];scanned=0
paths={ROOT/name for name in sources}|{p for p in OUT.rglob('*') if p.is_file() and p.name!='delivery-check.json'}|{ROOT/'tools'/p for p in ['content_r3_native.py','content_r3_pipeline.py','content_r3_capture.cjs','verify_content_r3.py']}
paths.add(ROOT/'tools/finish_content_r3.py')
paths.add(ROOT/'tools/diagnose_r3_r1_count.py')
for path in paths:
    with path.open('rb') as handle:
        tail=b''
        while part:=handle.read(1048576):
            value=tail+part
            if secret.search(value.lower()):hits.append(path.relative_to(ROOT).as_posix());break
            tail=value[-128:]
    scanned+=1
check(not hits,'secret scan hit paths only '+str(hits))
result={'status':'VERIFIED' if not failures else 'BLOCKED','checks':checks,'failures':failures,'version':VERSION,'base':BASE,'scope':'48 existing CI + R3, affected UI followup, 8 true-input UI cases, 2 continuous same-seed formal runs, 15 current raw screenshots, transactional profile/migration boundaries','ci_source_limit':binding['limitation'],'secret_scan_files':scanned,'secret_scan_hit_paths':hits,'overall_quality_score':'not established by technical gate; no >=9 claim','performance':'software-rendered screenshots; no device performance certification'}
write_path=OUT/'tests/delivery-check.json';write_path.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8',newline='\n')
print(json.dumps(result,ensure_ascii=False));raise SystemExit(0 if not failures else 1)
