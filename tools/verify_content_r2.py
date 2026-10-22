"""Audit R2's evidence, actual run results and isolated local release contract."""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/content/r2'
checks=0;failures=[]
def check(value,message):
 global checks
 checks+=1
 if not value:failures.append(message)
def read(p):return json.loads((OUT/p).read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
version=re.search(r'^config/version="([^"]+)"',(ROOT/'project.godot').read_text(encoding='utf-8'),re.M)[1]
# R2 remains frozen at f384969. The patch has separate source/build/screenshots
# and a narrower, explicitly reported gate scope; never rewrite R2's receipts.
if version=='0.31.1-content-r2.1':
 raise SystemExit(subprocess.run([sys.executable,str(ROOT/'tools/verify_content_r2_1.py')],cwd=ROOT).returncode)
check(version=='0.31.0-content-r2','wrong version')
check(version in (ROOT/'README.md').read_text(encoding='utf-8'),'README version mismatch')
check(subprocess.check_output(['git','branch','--show-current'],cwd=ROOT).strip()==b'main','wrong branch')
sources=read('tests/source-hashes.json')
for name,value in sources['files'].items():check(sha(ROOT/name)==value,'source changed after capture build: '+name)
builds=read('tests/builds.json');manifest_sha=sha(OUT/'tests/source-hashes.json')
for kind in ['release','review']:
 check(builds[kind]['source_manifest_sha256']==manifest_sha,'builds use different sources')
 check(builds[kind]['release_entry_restored'],'QA entry leaked into project')
rows=sorted(read('tests/samples.json'),key=lambda r:r['file'])
check(len(rows)==15 and len(list((OUT/'review-set').glob('*.png')))==15,'review set is not exactly 15')
dimensions=[]
for index,row in enumerate(rows,1):
 p=OUT/row['file'];check(p.name.startswith('%02d-'%index),'review numbering')
 check(row['version']==version and not row['postprocessed'],'old or processed capture')
 check(sha(p)==row['sha256'],'capture hash mismatch')
 check(row['source_manifest_sha256']==manifest_sha and row['pack_sha256']==builds['review']['pack_sha256'],'capture/build binding')
 check(not row['errors'],'capture runtime error')
 with Image.open(p) as im:dimensions.append(list(im.size))
 check(dimensions[-1]==row['dimensions'],'capture dimensions mismatch')
check(dimensions.count([2532,1170])==14 and dimensions.count([1170,2532])==1,'3x landscape/portrait contract')
for name,kind in [('front','front'),('pincer','pincer'),('artillery','artillery')]:
 group=sorted([r for r in rows if r['scenario']==name],key=lambda r:r['sample'])
 check([r['label'] for r in group]==['warning','active','handled'],'pressure sequence missing '+name)
 check(all(r['relay']['pressure']==kind for r in group),'pressure is just a stage name')
 check(group[0]['time']<group[1]['time']<group[2]['time'],'continuous sequence not chronological')
 check(group[2]['relay']['hold']>0,'handling did not earn capture hold')
wrong=next(r for r in rows if r['label']=='wrong_cost');right=next(r for r in rows if r['label']=='counter_reward')
check(wrong['relay']['wrong']>0 and wrong['relay']['hold']==0 and '反噬' in wrong['relay']['marker'],'wrong formation has no visible backlash/reset')
check(right['relay']['step']==1 and len(right['history'])==1 and right['history'][0]['cycles']>=2,'right formation has no actual reward/completion')
combo=next(r for r in rows if r['scenario']=='combo')
check(combo['combo']>=100 and '斷連' in combo['combo_status'] and '25 連斬' not in combo['combo_status'],'stale high-combo explanation')
summary=next(r for r in rows if r['scenario']=='summary')
check(summary['relay']['completed'] and summary['time']>=90 and summary['contributions'],'summary lacks real outcome/contributions')
check(sum(r['kills'] for r in summary['contributions'].values())==summary['kills'],'summary role kills contradict total')
check(summary['bond']['healing']>0 or summary['bond']['prevented']>0,'summary has no evidenced support-bond gain')
check(read('tests/r1-baseline-verification.json')['checks']==317 and read('tests/r1-baseline-verification.json')['status']=='VERIFIED','R1 baseline verification missing')
for phase in ['baseline','matrix']:
 matrix=read(phase+'/matrix.json')
 check({(r['width'],r['height']) for r in matrix}=={(844,390),(390,844),(1366,600)},'regression viewport matrix incomplete')
 for row in matrix:
  check(not row['errors'] and {r['name'] for r in row['captures']}=={'battle','guide','formation','pause'},'regression scene missing/error')
gates=read('tests/gates/summary.json')
check(len(gates)==47 and all(r['status']=='VERIFIED' and r['exit_code']==0 for r in gates),'CI gates incomplete')
mechanics=read('tests/mechanics.json')
check(mechanics['status']=='VERIFIED' and mechanics['checks']>=244 and not mechanics['failures'],'R2 mechanics gate')
runs=read('tests/paired-runs.json')
check(len(runs)==6 and {(r['stage'],r['policy']) for r in runs}=={(s,p) for s in ['moon','garden','ember'] for p in ['active','idle']},'paired runs incomplete')
for r in runs:
 check(r['seed']==55210 and r['status']=='VERIFIED' and r['exit_code']==0,'paired run error')
 check(sum(c['kills'] for c in r['contributions'].values())==r['kills'],'paired run role kills contradict total')
 if r['policy']=='active':
  check(r['outcome']=='win' and r['seals']==3 and r['campaign_clear'],'active policy cannot clear')
  check(r['history'][-1]['time']>=90 and all(h['cycles']>=2 for h in r['history']),'seal bypassed timing/cycles')
  check(any(h['reason']=='boss_guard' and h.get('recoveries',0)>=2 and h.get('impacts',0)>=2 for h in r['guards']),'half-HP escort skipped its cycles')
 else:check(r['seals']==0 and not r['campaign_clear'] and r['outcome']!='win','zero-movement campaign clear')
controls=read('tests/controls/playwright_results.json')
check(len(controls)==8 and all(r['status']=='pass' and not r['consoleErrors'] and not r['requestFailures'] for r in controls),'controls matrix')
pack=read('tests/packaged-assets.json');check(pack['status']=='VERIFIED' and pack['checks']==24 and not pack['physical_project_fallback'],'isolated texture decode')
check(read('tests/r2-pack-isolation.json')['status']=='VERIFIED','R2 debug fixture leaked into release')
reviewer=read('tests/reviewer/reviewer-path.json')
check(len(reviewer)==2 and all(r['status']=='VERIFIED' and not r['errors'] and not r['external_requests'] and r['offline_play_after_load'] for r in reviewer),'ordinary release reviewer path')
check(not read('tests/reviewer/runtime-diagnostics.json'),'reviewer runtime diagnostics')
browser=read('tests/browser-ledger.json')
for script in ['content_r2_samples.cjs','content_r2_capture.cjs','test_controls_reachability.mjs','test_r44_reviewer.cjs','test_r33_web_smoke.mjs']:
 record=next((r for r in browser if Path(r['script']).name==script),{})
 check(record.get('exit_code')==0 and record.get('source_manifest_sha256')==manifest_sha,'latest browser gate missing: '+script)
native=json.loads((ROOT/'native/build-config.json').read_text(encoding='utf-8'))
prior=json.loads(subprocess.check_output(['git','show','HEAD:native/build-config.json'],cwd=ROOT).decode('utf-8'))
check(all(native[k]==v for k,v in prior.items() if k!='sourceVersion') and native['sourceVersion']==version,'native counters/config changed')
preset=(ROOT/'export_presets.cfg').read_text(encoding='utf-8').split('[preset.1]',1)[1]
check(preset==subprocess.check_output(['git','show','HEAD:export_presets.cfg'],cwd=ROOT).decode('utf-8').split('[preset.1]',1)[1],'native presets changed')
old=[]
for folder in ['scripts','resources','web','native']:
 for p in (ROOT/folder).rglob('*'):
  if p.is_file() and p.suffix in {'.gd','.tres','.tscn','.json','.js','.html'} and '0.30.0-content-r1' in p.read_text(encoding='utf-8',errors='replace'):old.append(p.relative_to(ROOT).as_posix())
check(not old,'old runtime version')
pattern=re.compile(rb'sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}')
hits=[];scanned=0
for directory,dirs,files in os.walk(ROOT):
 dirs[:]=[d for d in dirs if d not in {'.git','node_modules'}]
 for name in files:
  p=Path(directory)/name
  assert not p.is_symlink(),'symlink scope requires review'
  tail=b''
  with p.open('rb') as stream:
   while block:=stream.read(65536):
    part=tail+block
    if pattern.search(part.lower()):hits.append(p.relative_to(ROOT).as_posix());break
    tail=part[-128:]
  scanned+=1
check(not hits,'secret scan hit')
cleanup=read('tests/cleanup.json')
check(cleanup['status']=='VERIFIED' and not cleanup['missing_initial'],'cleanup/protection failed')
check(all(not Path(r['target']).exists() for r in cleanup['targets']),'temporary build remains')
result={'status':'VERIFIED' if not failures else 'BLOCKED','checks':checks,'failures':failures,'version':version,'secret_scan_files':scanned,'secret_scan_hit_paths':hits,'old_runtime_version_hits':old}
(OUT/'tests/delivery-check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False));raise SystemExit(0 if not failures else 1)
