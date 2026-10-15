"""Check and index real screenshot and simulation artifacts; never fabricates runs."""
from pathlib import Path
import hashlib
import json
from PIL import Image

root = Path(__file__).resolve().parents[1]
evidence = root/'docs/evidence/r44-store'
shots = root/'docs/store/screenshots'
rows = []
for p in sorted(shots.glob('*.png')):
    with Image.open(p) as im:
        size = im.size
        im.verify()
    assert size in {(1290,2796),(2064,2752)}, (p.name,size)
    rows.append({'file':p.name,'width':size[0],'height':size[1],
                 'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
assert len(rows) == 12, f'Expected six real game frames for each device, got {len(rows)}'
paths = json.loads((evidence/'reviewer-path.json').read_text(encoding='utf-8'))
assert len(paths) == 2 and all(r['status']=='VERIFIED' for r in paths)
assert all(r['offline_play_after_load'] and r['returned_via_pause_menu'] and not r['errors'] for r in paths)
cache = json.loads((evidence/'pwa-cache.json').read_text(encoding='utf-8'))
(shots/'manifest.json').write_text(json.dumps({
    'version':cache['release'],'status':'VERIFIED','capture':'headless Chromium, actual Godot Web gameplay; no image editing',
    'native_device_capture':False,'game_pack':cache['game_pack'],
    'game_pack_sha256':cache['game_pack_sha256'],'files':rows,
},ensure_ascii=False,indent=2),encoding='utf-8')

runs = json.loads((evidence/'long-run/summary.json').read_text(encoding='utf-8'))
for log in (evidence/'long-run').glob('*.txt'):
    text = log.read_text(encoding='utf-8').replace('\r\n', '\n').replace('\r', '').rstrip() + '\n'
    assert 'SCRIPT ERROR:' not in text and 'ERROR:' not in text, str(log)
    log.write_text(text,encoding='utf-8',newline='\n')
expected = {(s,n,g,'orbit') for s in ['moon','veil','forge'] for n in [44101,44102] for g in [True,False]}
expected |= {('moon',n,True,'idle') for n in [44101,44102]}
actual = {(r['stage'],r['seed'],r['guard_enabled'],r['policy']) for r in runs}
assert actual == expected, f'Incomplete long-run matrix: missing {expected-actual}'
assert all(r['status']=='VERIFIED' for r in runs)
groups = []
for stage in ['moon','veil','forge']:
    for guard in [True,False]:
        selected=[r for r in runs if r['stage']==stage and r['guard_enabled']==guard and r['policy']=='orbit']
        wins=sum(r['outcome']=='win' for r in selected)
        exposed=sum(any(x['reason']=='boss_guard' for x in r['guard_history']) for r in selected)
        for r in selected:
            for event in r['guard_history']:
                if event['reason']=='boss_guard':
                    assert guard and event['time']>=r['phase_two']+2.0-0.02, 'escort skipped its warning'
        groups.append({'stage':stage,'guard_enabled':guard,'runs':len(selected),'wins':wins,'win_rate':wins/len(selected),
                       'actual_escort_exposure':exposed,'min_hp_ratio':min(r['min_hp_ratio'] for r in selected),
                       'escort_seconds_before_boss_end':[max(0.0,r['boss_kill']-event['time']) for r in selected if r['outcome']=='win' for event in r['guard_history'] if event['reason']=='boss_guard'],
                       'boss_kill_seconds':[r['boss_kill'] for r in selected]})
idle = [r for r in runs if r['policy']=='idle']
summary={'status':'VERIFIED','performance_note':'並發載量測，僅供參考','sample_count':len(runs),'groups':groups,
         'idle_outcomes':[{k:r[k] for k in ['seed','outcome','seconds','min_hp_ratio']} for r in idle],
         'method':'real Arena fixed 60fps; fresh saves; no HP, DPS, enemy or elapsed-time shortcuts; auto-upgrade and auto-channel enabled; shop skipped; orbital avoidance versus idle; paired removal of half-HP escort only',
         'limitations':['scripted controller, not human win rate','two seeds per stage','three of ten stages','late stages entered with fresh saves rather than earned meta upgrades','idle policy supplies zero movement input but built-in attack movement remains enabled','not device thermals, battery or performance certification','an enabled escort can be absent when the Boss dies before its warning expires']}
(evidence/'long-run/analysis.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print('R44_EVIDENCE_VERIFIED screenshots=12 runs='+str(len(runs)))
