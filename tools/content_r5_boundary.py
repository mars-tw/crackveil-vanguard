"""R5 exact output boundary, derived from R4 frozen-input snapshots."""
from pathlib import Path
import hashlib,json,re,time
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/content/r5'
TMP=ROOT/'.audit-tmp/content-r5'
BUILD=ROOT/'export/content-r5'
SANDBOX=TMP/'regression-project'
PINS={'tests/historical.json': '0ef9d86d9b974252ebcf1aa5e94c4ff07893ab21f99a2be06ddc781e36c376e2', 'tests/initial-files.json': 'b3ec79620d18a5ba874939195b77cf6074cc3a19a0b7ea21fee045ddc0be4bce', 'tests/default-profile-before.json': 'b569c4ebb24b3bc49a0862663c6a729bd6b127b22d29b53bad7173829494f433', 'tests/external-changes.json': 'd473df9aac673fa14aa444cbbf8ca375bd54d45b98bbbc27ee7a727cc7fd670f'}
HANDOFF={ROOT/'docs/CODEX_RESPONSE_CONTENT_R5.md'}
# Only R5's explicit release-version and workflow routers may differ from the
# frozen workspace list; each must carry a before and after SHA in R5 evidence.
EXTERNAL_ALLOW={'project.godot','README.md','export_presets.cfg','native/build-config.json','.github/workflows/deploy-web.yml','tools/verify_content_r1.py','tools/verify_content_r2.py','tools/verify_content_r2_1.py','tools/verify_content_r3.py','tools/verify_content_r4.py','docs/專案導航.md'}
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def assert_output(path,*,handoff=False):
 path=Path(path).absolute();resolved=path.resolve()
 if resolved in {(OUT/name).resolve() for name in PINS}:raise ValueError('immutable R5 input is not an output')
 allowed=any(resolved.is_relative_to(base.resolve()) for base in [OUT,TMP,BUILD])
 if handoff and path in HANDOFF and resolved==path:allowed=True
 if not allowed:raise ValueError('output outside exact R5 allowlist: '+str(path))
 return resolved
def write_text(path,text,*,handoff=False):
 path=assert_output(path,handoff=handoff);path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text,encoding='utf8',newline='\n')
def write_json(path,value):write_text(path,json.dumps(value,ensure_ascii=False,indent=2))
def snapshot(include_initial=True):
 for name,digest in PINS.items():
  if sha(OUT/name)!=digest:raise ValueError('pinned R5 input changed: '+name)
 history=json.loads((OUT/'tests/historical.json').read_text(encoding='utf8'))['files'];expected=dict(history)
 initial=json.loads((OUT/'tests/initial-files.json').read_text(encoding='utf8'))['files']
 if include_initial:expected.update({name:row['sha256'] for name,row in initial.items()})
 changes=OUT/'tests/external-changes.json'
 for row in json.loads(changes.read_text(encoding='utf8')) if changes.is_file() else []:
  name=row['path']
  if name not in EXTERNAL_ALLOW or row.get('owner')!='primary supervisor' or not row.get('authorization') or name not in initial or row['before_sha256']!=initial[name]['sha256']:raise ValueError('invalid R5 source exception: '+str(name))
  expected[name]=row['after_sha256']
 failures=[name for name,digest in expected.items() if not (ROOT/name).is_file() or sha(ROOT/name)!=digest]
 return {'status':'VERIFIED' if not failures else 'BLOCKED','failures':failures,'history_files':len(history),'initial_files':len(initial) if include_initial else 0,'pins':PINS,'captured_unix_ns':time.time_ns()}
def assert_snapshot(value):
 if value['failures']:raise ValueError('protected bytes changed; stop without restore: '+str(value['failures']))
def sandbox_docs(project):
 if Path(project).resolve()!=SANDBOX.resolve():raise ValueError('R5 native work requires only the isolated project copy')
 docs=(SANDBOX/'docs').resolve()
 if not docs.is_relative_to(TMP.resolve()) or docs==(ROOT/'docs').resolve() or not docs.is_dir():raise ValueError('R5 sandbox docs must be an independent copied directory')
 return docs
def junction(link,target):
 link=Path(link);target=Path(target).resolve()
 assert target in {(ROOT/name).resolve() for name in ['scripts','scenes','resources','assets','web','native','.godot']},'unlisted R5 junction target'
 assert link.name==target.name and link.parent.resolve().is_relative_to(TMP.resolve()),'unlisted R5 junction entry'
 if link.exists():
  if link.resolve()!=target:raise ValueError('R5 junction target mismatch')
  return
 link.parent.mkdir(parents=True,exist_ok=True)
 import subprocess
 esc=lambda x:str(x).replace("'","''")
 subprocess.run(['powershell','-NoProfile','-NonInteractive','-Command',f"New-Item -ItemType Junction -Path '{esc(link)}' -Target '{esc(target)}' | Out-Null"],check=True,capture_output=True)

def collect(source,destination):
 source=Path(source).resolve();destination=assert_output(destination)
 if not source.is_relative_to((SANDBOX/'docs').resolve()) or not destination.is_relative_to(OUT.resolve()):raise ValueError('R5 copyback must stay between isolated docs and R5 output')
 relative=destination.relative_to(OUT.resolve()).as_posix();source_rel=source.relative_to((SANDBOX/'docs').resolve()).as_posix()
 exact={'tests/mechanics.json':'content/r4/tests/mechanics.json','tests/r3-mechanics.json':'content/r3/tests/mechanics.json','tests/r2-mechanics.json':'content/r2/tests/mechanics.json','tests/r1-mechanics.json':'content/r1/tests/mechanics.json','tests/r1-navigation.json':'content/r1/tests/navigation.json','tests/r2-1-ui-regression.json':'content/r2-1/tests/ui-regression.json'}
 if relative in exact:
  if source_rel!=exact[relative]:raise ValueError('R5 baseline copyback source/destination mismatch')
 elif relative in {'tests/paired/assault.json','tests/paired/escort.json'}:
  team=Path(relative).stem
  if not re.fullmatch(r'content/r5/tests/paired/'+team+r'-[0-9a-f]{32}\.json',source_rel):raise ValueError('R5 pair requires a unique tokenized sandbox run')
 else:raise ValueError('unlisted R5 copyback: '+relative)
 if not source.is_file():raise ValueError('R5 sandbox result missing: '+str(source))
 previous=None
 if destination.is_file() and sha(destination)!=sha(source):
  archive_dir=assert_output(OUT/'tests/attempts'/('copyback-'+str(time.time_ns())))
  archive=assert_output(archive_dir/destination.name)
  archive.parent.mkdir(parents=True,exist_ok=True)
  import shutil
  shutil.copyfile(destination,archive);previous={'sha256':sha(destination),'archived_to':archive.relative_to(OUT).as_posix()}
 destination.parent.mkdir(parents=True,exist_ok=True)
 import shutil
 shutil.copyfile(source,destination)
 if sha(destination)!=sha(source):raise ValueError('R5 copyback byte mismatch')
 return {'source':str(source),'destination':destination.relative_to(OUT).as_posix(),'sha256':sha(destination),'previous':previous}
