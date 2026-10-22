"""Build a local debug review fixture; restore settings in memory, no backups.

The production release excludes scripts/debug and scenes/debug. This temporary
pack only changes its entry scene and includes test fixtures. Game scripts,
assets, damage, spawns and animation are the same working-tree sources.
"""
import argparse
import json
import re
import subprocess
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('--godot',required=True)
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
output=root/'export/content-r1-review'
output.mkdir(parents=True,exist_ok=True)
project=root/'project.godot'
preset=root/'export_presets.cfg'
original_project=project.read_bytes()
original_preset=preset.read_bytes()
try:
    project.write_bytes(original_project.replace(b'res://scenes/ui/MainMenu.tscn',b'res://scenes/debug/ContentR1Review.tscn'))
    preset.write_bytes(original_preset.replace(b'scripts/debug/**,scenes/debug/**,',b''))
    with (root/'.audit-tmp/content-r1/review-export.txt').open('w',encoding='utf-8') as log:
        subprocess.run([args.godot,'--headless','--audio-driver','Dummy','--path',str(root),'--export-debug','Web',str(output/'index.html')],cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
finally:
    project.write_bytes(original_project)
    preset.write_bytes(original_preset)
subprocess.run(['python','tools/finalize_r25_web_export.py','--dir',str(output),'--evidence','.audit-tmp/content-r1/review-shell.json'],cwd=root,check=True)
html=output/'index.html'
text=html.read_text(encoding='utf-8')
match=re.search(r'const GODOT_CONFIG = (\{[^\n]+\});',text)
config=json.loads(match.group(1))
config['args']=['--fixed-fps','60']
text=text[:match.start(1)]+json.dumps(config)+text[match.end(1):]
html.write_text(text,encoding='utf-8')
print('Review fixture built; production settings restored.')
