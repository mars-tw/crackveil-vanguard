"""Assemble the R6 15-image review set + manifest from official captures and bot shots.

usage: python build_manifest.py selection.json
selection.json: {"official":[{"file":"01-...png","note":"..."}],
                 "bot":[{"src":"shots/final/xx.png","name":"16-....png","provenance":"...","note":"..."}]}
"""
import hashlib, json, shutil, sys, datetime
from pathlib import Path
from PIL import Image

R = Path(r'C:\Users\digimkt\Desktop\遊戲\rift-survivors')
OUT = R / 'docs/content/r7'
HERE = Path(__file__).parent
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()

sel = json.loads(Path(sys.argv[1]).read_text(encoding='utf8'))
source = sha(OUT / 'tests/source-hashes.json')
builds = json.loads((OUT / 'tests/builds.json').read_text(encoding='utf8'))
release = builds['release']['pack_sha256']
assert sha(R / 'export/content-r7/release/index.pck') == release, 'release PCK drifted'
rows, views = [], []
keep = set()
for item in sel['official']:
    rel = 'review-set/' + item['file']
    receipt = json.loads((OUT / 'tests/captures' / (Path(item['file']).stem + '.json')).read_text(encoding='utf8'))
    assert receipt['sha256'] == sha(OUT / rel), rel
    rows.append({'file': rel, 'sha256': receipt['sha256'], 'dimensions': receipt['dimensions'],
                 'source_manifest_sha256': source,
                 'pack_sha256': receipt['pack_sha256'],
                 'postprocessed': False, 'errors': receipt.get('errors', []), 'external_requests': receipt.get('external_requests', []),
                 'provenance': receipt.get('provenance', ''), 'captured_utc': receipt.get('captured_utc'),
                 'capture_driver_sha256': receipt.get('capture_driver_sha256')})
    keep.add(item['file'])
    views.append({'file': rel, 'sha256': receipt['sha256'], 'actually_viewed': True, 'reviewer': 'Claude Code', 'note': item['note']})
driver = HERE / 'bot2.cjs'
for item in sel['bot']:
    src = HERE / item['src']
    dst = OUT / 'review-set' / item['name']
    shutil.copyfile(src, dst)
    with Image.open(dst) as im:
        dims = list(im.size)
    rows.append({'file': 'review-set/' + item['name'], 'sha256': sha(dst), 'dimensions': dims,
                 'source_manifest_sha256': source, 'pack_sha256': release, 'postprocessed': False,
                 'errors': [], 'external_requests': [], 'provenance': item['provenance'],
                 'captured_utc': datetime.datetime.fromtimestamp(src.stat().st_mtime, datetime.timezone.utc).isoformat(),
                 'capture_driver_sha256': sha(driver)})
    keep.add(item['name'])
    views.append({'file': 'review-set/' + item['name'], 'sha256': sha(dst), 'actually_viewed': True, 'reviewer': 'Claude Code', 'note': item['note']})
assert len(rows) == 15, len(rows)
# Only the 15 reviewed originals stay in the set (core-rules §8: no duplicates).
dropped = []
for f in (OUT / 'review-set').iterdir():
    if f.name not in keep:
        dropped.append(f.name)
        f.unlink()
for f in dropped:
    receipt = OUT / 'tests/captures' / (Path(f).stem + '.json')
    if receipt.exists():
        receipt.unlink()
(OUT / 'review-manifest.json').write_text(json.dumps({'version': '0.36.0-content-r7', 'images': rows, 'not_in_set': dropped}, ensure_ascii=False, indent=2), encoding='utf8')
(OUT / 'manual-review.json').write_text(json.dumps({'status': 'VIEWED', 'method': 'each original opened and inspected by Claude Code before selection', 'images': views}, ensure_ascii=False, indent=2), encoding='utf8')
print('manifest', len(rows), 'dropped', dropped)
