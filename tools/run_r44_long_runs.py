"""Sequential paired, real-Arena long runs; performance is concurrent-load only."""
from pathlib import Path
import argparse
import json
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--godot', required=True)
p.add_argument('--quick', action='store_true')
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
out = root / 'docs/evidence/r44-store/long-run'
out.mkdir(parents=True, exist_ok=True)
jobs = [(stage, seed, guard, 'orbit') for stage in ['moon', 'veil', 'forge']
        for seed in [44101, 44102] for guard in [True, False]]
jobs += [('moon', seed, True, 'idle') for seed in [44101, 44102]]
if a.quick:
    jobs = jobs[:1]
results = []
for stage, seed, guard, policy in jobs:
    name = f'{stage}-{seed}-{"guard" if guard else "control"}-{policy}'
    command = [a.godot, '--headless', '--fixed-fps', '60', '--path', '.',
               'res://scenes/debug/R44LongRun.tscn', '--', f'stage={stage}',
               f'seed={seed}', f'guard={int(guard)}', f'policy={policy}']
    if (out / f'{name}.json').exists() and (out / f'{name}.txt').exists():
        log = (out / f'{name}.txt').read_text(encoding='utf-8')
        existing = json.loads((out / f'{name}.json').read_text(encoding='utf-8'))
        if 'SCRIPT ERROR' not in log and existing.get('outcome') in {'win','death','time_limit'}:
            existing['status'] = 'VERIFIED'
            existing['command'] = command
            results.append(existing)
            print(f'{name}: existing VERIFIED {existing["outcome"]}', flush=True)
            continue
    try:
        run = subprocess.run(command, cwd=root, capture_output=True, timeout=510,
                             creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        log = (run.stdout + run.stderr).decode('utf-8', errors='replace')
        code = run.returncode
    except subprocess.TimeoutExpired:
        log, code = 'BLOCKED: wall timeout', -1
    log = log.replace('\r\n', '\n').replace('\r', '').rstrip() + '\n'
    (out / f'{name}.txt').write_text(log, encoding='utf-8', newline='\n')
    result_file = out / f'{name}.json'
    row = json.loads(result_file.read_text(encoding='utf-8')) if result_file.exists() else {'outcome': 'missing'}
    row['command'] = command
    row['status'] = 'VERIFIED' if code == 0 and 'SCRIPT ERROR' not in log else 'BLOCKED'
    results.append(row)
    (out / 'summary.json').write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding='utf-8')
    print(f'{name}: {row["status"]} {row["outcome"]} t={row.get("seconds", 0):.1f}', flush=True)
    if row['status'] != 'VERIFIED':
        print(log[-2500:], flush=True)
        break
raise SystemExit(0 if all(x['status'] == 'VERIFIED' for x in results) else 1)
