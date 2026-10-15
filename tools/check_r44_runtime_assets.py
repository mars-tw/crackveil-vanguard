"""Every asset path in shipped gameplay data must survive every release filter."""
from pathlib import Path
import fnmatch
import json
import re

root = Path(__file__).resolve().parents[1]
presets = (root/'export_presets.cfg').read_text(encoding='utf-8')
filters = re.findall(r'^exclude_filter="([^"]*)"',presets,re.M)
rows = []
for resource in sorted((root/'resources').rglob('*.tres')):
    text=resource.read_text(encoding='utf-8')
    for asset in re.findall(r'"res://(assets/[^"\n]+)"',text):
        missing = not (root/asset).is_file()
        excluded = [i for i,patterns in enumerate(filters) if any(fnmatch.fnmatchcase(asset,p) for p in patterns.split(','))]
        rows.append({'resource':resource.relative_to(root).as_posix(),'asset':asset,'exists':not missing,'excluded_presets':excluded})
        assert not missing and not excluded, (resource,asset,excluded)
manifest=json.loads((root/'docs/store/ART_MANIFEST_R44.json').read_text(encoding='utf-8'))
import hashlib
for row in manifest['relocated_existing_assets']:
    for field in ['source','runtime']:
        assert hashlib.sha256((root/row[field]).read_bytes()).hexdigest()==row['sha256'],row[field]
out=root/'docs/evidence/r44-store/runtime-assets.json'
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps({'status':'VERIFIED','presets':len(filters),'checks':len(rows),'unchanged_relocated_pngs':len(manifest['relocated_existing_assets']),'assets':rows},ensure_ascii=False,indent=2),encoding='utf-8')
print(f'R44_RUNTIME_ASSETS_PASS paths={len(rows)} presets={len(filters)} relocated={len(manifest["relocated_existing_assets"])}')
