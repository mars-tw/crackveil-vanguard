"""Remove only this round's verified intermediate files; write a receipt."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil

parser=argparse.ArgumentParser()
parser.add_argument('--apply',action='store_true')
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
assert Path.cwd().resolve()==root,'Unexpected working directory'
round_root=root/'docs/content/r1'
initial=json.loads((root/'.audit-tmp/content-r1/initial.json').read_text(encoding='utf-8'))
manifest=json.loads((round_root/'review-manifest.json').read_text(encoding='utf-8'))
assert len(manifest)==15
for row in manifest:
    image=round_root/row['file']
    assert hashlib.sha256(image.read_bytes()).hexdigest()==row['sha256'],str(image)
    source=round_root/row['source']
    assert hashlib.sha256(source.read_bytes()).hexdigest()==row['sha256'],'Copy newest screenshots first'

directories=[root/'export/content-r1',root/'export/content-r1-review',root/'.audit-tmp/content-r1']
files=[]
for relative in ['samples','live','tests/controls','tests/reviewer']:
    files.extend((round_root/relative).glob('*.png'))
files.extend(round_root/row['source'] for row in manifest if row['source'].startswith('matrix/'))

def verify(path: Path) -> Path:
    resolved=path.resolve()
    assert root in resolved.parents,'Target escapes workspace: '+str(resolved)
    assert not path.is_symlink(),'Unexpected symlink: '+str(path)
    assert resolved.relative_to(root).as_posix() not in initial,'Protected initial file: '+str(path)
    return resolved

for directory in directories:
    verify(directory)
    assert directory.parent in [root/'export',root/'.audit-tmp']
    if directory.exists():
        for item in directory.rglob('*'):
            verify(item)
            if item.is_file():files.append(item)
files=sorted({verify(file) for file in files if file.is_file()})
rows=[{'path':file.relative_to(root).as_posix(),'bytes':file.stat().st_size} for file in files]
receipt={'status':'PREPARED','targets':[str(verify(p)) for p in directories],'file_count':len(rows),'logical_bytes':sum(r['bytes'] for r in rows),'files':rows,'initial_files_deleted':0}
output=round_root/'tests/cleanup.json'
output.write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in receipt.items() if k!='files'},indent=2))
if not args.apply:
    raise SystemExit(0)

free_before=shutil.disk_usage(root).free
for file in files:
    if not any(directory in file.parents for directory in directories):file.unlink()
for directory in directories:
    if directory.exists():shutil.rmtree(verify(directory))
receipt.update(status='VERIFIED',disk_free_delta=shutil.disk_usage(root).free-free_before,remaining_targets=[str(p) for p in directories if p.exists()])
assert not receipt['remaining_targets']
assert not any((root/row['path']).exists() for row in rows)
output.write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print('CLEANUP_VERIFIED files=%d logical_bytes=%d'%(len(rows),receipt['logical_bytes']))
