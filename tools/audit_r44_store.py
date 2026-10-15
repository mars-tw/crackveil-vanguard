"""Read-only sibling comparison. Writes evidence only within this repository."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/r44-store'
OUT.mkdir(parents=True, exist_ok=True)
REPOS = ['storm-apocalypse','doomsday-shooter','tower-defense','skill',
         'pixel-idle-farm-skill','village-siege','seven-district-reckoning',
         'rift-forge-3d','taiwan-island-drive','taiwan-train-math',
         'taiwan-train-school','island-flight-school', 'night-train']
SUFFIXES = {'.gd','.tscn','.tres','.cfg','.godot','.png','.jpg','.webp',
            '.wav','.ogg','.mp3','.otf','.ttf','.css','.js','.mjs','.cjs', '.svg'}
def tracked(root):
    p = subprocess.run(['git','ls-files','-z'],cwd=root,capture_output=True)
    return p.stdout.decode('utf-8').split('\0') if p.returncode == 0 else []
def digest(p):
    return hashlib.file_digest(p.open('rb'), 'sha256').hexdigest()
own = {}
for name in tracked(ROOT):
    p = ROOT / name
    if not p.is_file() or p.suffix not in SUFFIXES or name.startswith(('docs/','.github/')):
        continue
    own.setdefault(p.stat().st_size, []).append(name)
hashes = {}
for names in own.values():
    for name in names:
        hashes.setdefault(digest(ROOT/name), []).append(name)
matches = []
coverage = []
for repo in REPOS:
    sibling = ROOT.parent / repo
    if not sibling.is_dir():
        coverage.append({'repo':repo,'status':'BLOCKED','reason':'folder missing; description-only comparison'})
        continue
    names = tracked(sibling)
    compared = 0
    for name in names:
        p = sibling / name
        if not p.is_file() or p.is_symlink() or p.suffix not in SUFFIXES or any(part in {'.git','node_modules','Library','Temp','build','docs'} for part in p.relative_to(sibling).parts):
            continue
        compared += 1
        if p.stat().st_size not in own:
            continue
        sha = digest(p)
        for target in hashes.get(sha, []):
            matches.append({'file':target,'other_repo':repo,'other_file':name,'sha256':sha})
    revision = subprocess.check_output(['git','rev-parse','HEAD'],cwd=sibling).decode().strip()
    coverage.append({'repo':repo,'revision':revision,'tracked_files':len(names),'compared_runtime_asset_files':compared,'status':'VERIFIED'})
runtime_hits = []
network = re.compile(r'HTTPRequest|HTTPClient|WebSocketPeer|ENetMultiplayerPeer|TCPServer|OS\.shell_open|https?://|fetch\(|XMLHttpRequest|sendBeacon|WebSocket\(')
residue = re.compile(r'Lorem|敬請期待|TODO|Sample|未命名|placeholder', re.I)
for name in tracked(ROOT) + ['scripts/services/formation_relay.gd']:
    if not name.startswith(('scripts/', 'web/', 'resources/')) or name.startswith('scripts/debug/'):
        continue
    p = ROOT/name
    if p.is_file() and p.suffix in {'.gd','.html','.js','.mjs','.tres'}:
        for line, text in enumerate(p.read_text(encoding='utf-8',errors='replace').splitlines(),1):
            if network.search(text) or residue.search(text):
                runtime_hits.append({'file':name,'line':line,'text':text.strip()[:350], 'kind':'network' if network.search(text) else 'residue'})
source_files = [{'file':name,'sha256':sha,'bytes':(ROOT/name).stat().st_size} for sha,names in hashes.items() for name in names]
report = {'status':'EXECUTED','method':'git-tracked runtime/assets; size-prefilter + SHA-256, no writes in siblings; excludes docs/builds/vendor caches; no inference of binary identity from source', 'source_files':source_files,'coverage':coverage,'matches':matches,'runtime_findings':runtime_hits}
(OUT/'shared-assets.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'repos':len(coverage),'matches':len(matches),'findings':len(runtime_hits)},ensure_ascii=False))
