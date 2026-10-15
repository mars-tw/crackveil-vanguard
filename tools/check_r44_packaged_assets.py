"""Load referenced textures from the actual Web PCK, using headless Godot."""
from pathlib import Path
import argparse
import json
import subprocess

parser=argparse.ArgumentParser()
parser.add_argument('--godot',required=True)
parser.add_argument('--pack',required=True)
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
report=root/'docs/evidence/r44-store/runtime-assets.json'
assets=sorted({'res://'+r['asset'] for r in json.loads(report.read_text(encoding='utf-8'))['assets']})
temporary=root/'.audit-tmp/r44'
temporary.mkdir(parents=True,exist_ok=True)
script=temporary/'packaged_asset_probe.gd'
script.write_text('''extends SceneTree
func _initialize() -> void:
    var failures: Array[String] = []
    var assets: Array = %s
    for path in assets:
        if not ResourceLoader.exists(path):
            failures.append(path + ":missing")
            continue
        var texture = load(path)
        if not texture is Texture2D or texture.get_width() <= 0 or texture.get_height() <= 0:
            failures.append(path + ":not_decodable")
    print("R44_PACKAGED_ASSETS=" + JSON.stringify({"checks":assets.size(),"failures":failures}))
    quit(0 if failures.is_empty() else 1)
''' % json.dumps(assets),encoding='utf-8')
isolation=temporary/'pack-mount'
isolation.mkdir(parents=True,exist_ok=True)
command=[args.godot,'--headless','--path',str(isolation),'--main-pack',str(Path(args.pack).resolve()),'--script',str(script)]
run=subprocess.run(command,cwd=isolation,capture_output=True,timeout=90,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
log=(run.stdout+run.stderr).decode('utf-8',errors='replace').replace('\r\n','\n').replace('\r','').rstrip()+'\n'
output=root/'docs/evidence/r44-store/packaged-assets.txt'
output.write_text(log,encoding='utf-8',newline='\n')
assert run.returncode==0 and 'ERROR:' not in log,log[-4000:]
line=next(line for line in log.splitlines() if line.startswith('R44_PACKAGED_ASSETS='))
result=json.loads(line.split('=',1)[1])
assert not result['failures'] and result['checks']==len(assets)
result.update({'status':'VERIFIED','pack':Path(args.pack).as_posix(),'physical_project_fallback':False,'command':command})
output.with_suffix('.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print('R44_PACKAGED_ASSETS_PASS textures='+str(len(assets)))
