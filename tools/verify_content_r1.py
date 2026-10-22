"""Verify the final R1 evidence contract without starting a game or browser."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys
from PIL import Image

root=Path(__file__).resolve().parents[1]
round_root=root/'docs/content/r1'
failures=[]
checks=0
def check(value,message):
    global checks
    checks+=1
    if not value:failures.append(message)
def read(relative):return json.loads((round_root/relative).read_text(encoding='utf-8'))
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

version=re.search(r'^config/version="([^"]+)"',(root/'project.godot').read_text(encoding='utf-8'),re.M).group(1)
# R4_EXACT_ROUTE_START
if version=='0.33.0-content-r4':
    raise SystemExit(subprocess.run([__import__('sys').executable,str(root/'tools/verify_content_r4.py')],cwd=root).returncode)
# R4_EXACT_ROUTE_END
# R3_EXACT_ROUTE_START
# Exact version only: separate current evidence; all archived assertions remain.
if version=='0.32.0-content-r3':
    raise SystemExit(subprocess.run([__import__('sys').executable,str(root/'tools/verify_content_r3.py')],cwd=root).returncode)
# R3_EXACT_ROUTE_END
# Keep every frozen R1 assertion below. R2 has new source/build/image hashes
# and a different encounter contract; the established entry point dispatches
# that exact version to its stricter current-round verifier rather than rewriting
# R1's archived expected values or pretending R1 hashes describe the new game.
if version in {'0.31.0-content-r2', '0.31.1-content-r2.1'}:
    raise SystemExit(subprocess.run([sys.executable,str(root/'tools/verify_content_r2.py')],cwd=root).returncode)
check(version=='0.30.0-content-r1','version drift')
check(version in (root/'README.md').read_text(encoding='utf-8'),'README version mismatch')
check(subprocess.check_output(['git','branch','--show-current'],cwd=root).strip()==b'main','wrong branch')
source=read('tests/source-hashes.json')
for name,sha in source['files'].items():check(digest(root/name)==sha,'source changed after capture build: '+name)
builds=read('tests/builds.json')
check(builds['source_manifest_sha256']==digest(round_root/'tests/source-hashes.json'),'build/source manifest mismatch')
check(builds['release_entry_restored'],'review entry leaked into project')
manifest=read('review-manifest.json')
check(len(manifest)==15 and len(list((round_root/'review-set').glob('*.png')))==15,'review set count')
dimensions=[]
for index,row in enumerate(manifest,1):
    file=round_root/row['file']
    check(file.name.startswith('%02d-'%index),'review order')
    check(row['version']==version and not row['postprocessed'],'old or processed screenshot')
    check(digest(file)==row['sha256'],'screenshot hash mismatch')
    with Image.open(file) as image:dimensions.append(list(image.size))
    check(dimensions[-1]==row['dimensions'],'screenshot dimensions mismatch')
    check(row['source_manifest_sha256']==builds['source_manifest_sha256'],'screenshot source build mismatch')
    expected_pack=builds['review_pack_sha256'] if row['build_kind']=='debug_fixture' else builds['release_pack_sha256']
    check(row['pack_sha256']==expected_pack,'screenshot pack mismatch')
check(dimensions.count([844,390])==12,'primary landscape count')
check(dimensions.count([1366,600])==1,'desktop count')
check(sorted(d for d in dimensions if d[0]<d[1])==[[390,844],[430,932]],'portrait count/sizes')
matrix=read('matrix/matrix.json')
check({(r['width'],r['height']) for r in matrix}=={(390,844),(430,932),(844,390),(1366,600),(768,1024),(1024,768)},'viewport matrix incomplete')
for row in matrix:
    check(not row['errors'],'matrix runtime error')
    check({r['name'] for r in row['captures']}=={'battle','guide','formation','pause'},'matrix scenes incomplete')
gates=read('tests/gates/summary.json')
check(len(gates)==46 and all(r['status']=='VERIFIED' and r['exit_code']==0 for r in gates),'CI gates incomplete')
mechanics=read('tests/mechanics.json')
check(mechanics['status']=='VERIFIED' and mechanics['checks']==1403 and not mechanics['failures'],'mechanics gate')
navigation=read('tests/navigation.json')
check(not navigation['failures'] and len(navigation['runs'])==4,'navigation runs')
for run in navigation['runs']:check(run['returned'] and run['late_kills']==0 and run['remaining_animation_clients']==0,'navigation lifecycle failure')
browser=read('tests/browser-gates.json')
check(len(browser)==6 and all(r['status']=='VERIFIED' and r['exit_code']==0 for r in browser),'browser gates incomplete')
controls=read('tests/controls/playwright_results.json')
check(len(controls)==8 and all(r['status']=='pass' and not r['consoleErrors'] and not r['requestFailures'] for r in controls),'controls matrix')
reviewer=read('tests/reviewer/reviewer-path.json')
check(len(reviewer)==2 and all(r['status']=='VERIFIED' and not r['errors'] and not r['external_requests'] and r['offline_play_after_load'] for r in reviewer),'reviewer path')
check(not read('tests/reviewer/runtime-diagnostics.json'),'reviewer diagnostics contain errors')
live=read('live/path.json')
check(live['status']=='VERIFIED' and not live['errors'] and len(live['shots'])==4,'ordinary release path')
check(live['shots'][2]['state']['relay']['hold']>live['shots'][1]['state']['relay']['hold'],'hold sequence did not progress')
check(live['shots'][-1]['state']['relay']['completed'] and live['shots'][-1]['state']['seal_saved'],'seal completion/save')
samples=read('samples/samples.json')
comparison=[r for r in samples if r['scenario'] in ['wedge','ring','scatter']]
check(len(comparison)==3 and all(r['level']==1 and r['seed']==55210 and not r['equipment'] and not r['errors'] for r in comparison),'formation growth/seed conditions')
check(max(r['time'] for r in comparison)-min(r['time'] for r in comparison)<=1/60+0.001,'formation sample timing')
check(len({tuple(p['id'] for p in r['roster']) for r in comparison})==1,'formation rosters differ')
check(len([r for r in samples if r['scenario']=='bond'])==3,'bond sequence missing')
check(all(r['exit_code']==0 for r in read('tests/asset-gates.json')),'asset gate failed')
pack=read('tests/packaged-assets.json')
check(pack['status']=='VERIFIED' and pack['checks']==24 and not pack['failures'] and not pack['physical_project_fallback'],'packaged assets')
release=read('tests/release-audit.json')
check(release['status']=='VERIFIED' and not release['secret_scan_hit_paths'] and not release['old_runtime_version_hits'],'release/secret gate')
check(release['protected_native_config_unchanged'] and release['ios_android_preset_sections_unchanged'],'native contract changed')
cleanup=read('tests/cleanup.json')
check(cleanup['status']=='VERIFIED' and not cleanup['remaining_targets'] and cleanup['initial_files_deleted']==0,'cleanup incomplete')
check(all(not Path(p).exists() for p in cleanup['targets']),'temporary build remains')
check(not read('tests/initial-protection.json')['missing'],'initial protected files deleted')
result={'status':'VERIFIED' if not failures else 'BLOCKED','checks':checks,'failures':failures,'version':version}
(round_root/'tests/delivery-check.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
raise SystemExit(0 if not failures else 1)
