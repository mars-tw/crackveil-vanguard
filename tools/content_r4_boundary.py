"""R4 output boundary. Check resolved destinations before opening any writer.

Native games run only against copied docs in the R4 sandbox. Immutable input
manifests are pinned independently from their own content. No auto restoration.
"""
from pathlib import Path
import hashlib,json,time,shutil,re

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/content/r4'
TMP=ROOT/'.audit-tmp/content-r4'
BUILD=ROOT/'export/content-r4'
SANDBOX=TMP/'regression-project'
PINS={
 'tests/historical.json':'0ef9d86d9b974252ebcf1aa5e94c4ff07893ab21f99a2be06ddc781e36c376e2',
 'tests/initial-files.json':'b3ec79620d18a5ba874939195b77cf6074cc3a19a0b7ea21fee045ddc0be4bce',
 'tests/default-profile-before.json':'b569c4ebb24b3bc49a0862663c6a729bd6b127b22d29b53bad7173829494f433'}
HANDOFF={ROOT/'docs/CODEX_RESPONSE_CONTENT_R4.md'}

def assert_own_cache(path):
    path=Path(path).resolve()
    if path.parent!=(ROOT/'tools/__pycache__').resolve() or not re.fullmatch(r'content_r4_(?:boundary|native|pipeline)\.cpython-\d+\.pyc',path.name):raise ValueError('unlisted own bytecode cache')
    return path

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def assert_output(path,*,handoff=False):
    """Return canonical target; reject traversal, junction escape and inputs."""
    path=Path(path).absolute();resolved=path.resolve()
    if resolved in {(OUT/name).resolve() for name in PINS}:raise ValueError('immutable boundary input is not an output: '+str(path))
    allowed=any(resolved.is_relative_to(base.resolve()) for base in [OUT,TMP,BUILD])
    if handoff and path in HANDOFF and resolved==path:allowed=True
    if not allowed:raise ValueError('output outside exact R4 allowlist: '+str(path))
    return resolved

def write_text(path,text,*,handoff=False):
    path=assert_output(path,handoff=handoff);path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(text,encoding='utf8',newline='\n')

def write_json(path,value):write_text(path,json.dumps(value,ensure_ascii=False,indent=2))

def snapshot(include_initial=True):
    for name,digest in PINS.items():
        if sha(OUT/name)!=digest:raise ValueError('immutable manifest hash mismatch: '+name)
    history=json.loads((OUT/'tests/historical.json').read_text(encoding='utf8'))['files']
    expected=dict(history)
    initial=json.loads((OUT/'tests/initial-files.json').read_text(encoding='utf8'))['files']
    if include_initial:expected.update({name:row['sha256'] for name,row in initial.items()})
    changes=OUT/'tests/external-changes.json'
    for row in json.loads(changes.read_text(encoding='utf8')) if changes.is_file() else []:
        name=row['path']
        if name not in {'docs/CONTENT_R4_BRIEF.md','docs/專案導航.md'} or row['owner']!='primary supervisor' or not row['authorization'] or row['before_sha256']!=initial[name]['sha256']:raise ValueError('invalid authorized external exception')
        if name in expected:expected[name]=row['after_sha256']
    failures=[name for name,digest in expected.items() if not (ROOT/name).is_file() or sha(ROOT/name)!=digest]
    return {'status':'VERIFIED' if not failures else 'BLOCKED','failures':failures,'history_files':len(history),'initial_files':len(initial) if include_initial else 0,'manifest_pins':PINS,'captured_unix_ns':time.time_ns()}

def assert_snapshot(value):
    if value['failures']:raise ValueError('protected bytes changed; stop, never auto-restore: '+str(value['failures']))

def sandbox_docs(project):
    if Path(project).resolve()!=SANDBOX.resolve():raise ValueError('all native R4 games require the isolated sandbox, never ROOT')
    docs=(SANDBOX/'docs').resolve()
    if not docs.is_relative_to(TMP.resolve()) or docs==(ROOT/'docs').resolve() or not docs.is_dir():raise ValueError('sandbox docs must be an independent existing copy')
    return docs

def collect(source,destination):
    """Copy only a sandbox result into true R4 evidence; archive owned prior."""
    source=Path(source).resolve();destination=assert_output(destination)
    if not source.is_relative_to((SANDBOX/'docs').resolve()) or not source.is_relative_to(TMP.resolve()):raise ValueError('copyback source is not isolated copied docs')
    if not destination.is_relative_to(OUT.resolve()):raise ValueError('copyback destination must be R4 evidence')
    relative=destination.relative_to(OUT.resolve()).as_posix()
    source_relative=source.relative_to((SANDBOX/'docs').resolve()).as_posix()
    exact={'tests/mechanics.json':'content/r4/tests/mechanics.json','tests/r3-mechanics.json':'content/r3/tests/mechanics.json','tests/r2-mechanics.json':'content/r2/tests/mechanics.json','tests/r1-mechanics.json':'content/r1/tests/mechanics.json','tests/r1-navigation.json':'content/r1/tests/navigation.json','tests/r2-1-ui-regression.json':'content/r2-1/tests/ui-regression.json'}
    if relative in exact:
        if source_relative!=exact[relative]:raise ValueError('copyback source/destination contract mismatch')
    elif relative in {'tests/paired/assault.json','tests/paired/escort.json'}:
        team=Path(relative).stem
        if not re.fullmatch(r'content/r4/tests/paired/'+team+r'-[0-9a-f]{32}\.json',source_relative):raise ValueError('paired copyback requires unique R4 attempt filename')
    else:raise ValueError('unlisted copyback destination: '+relative)
    if not source.is_file():raise ValueError('expected sandbox result missing: '+str(source))
    previous=None
    if destination.is_file() and sha(destination)!=sha(source):
        archive=assert_output(OUT/'tests/attempts'/('copyback-'+str(time.time_ns()))/destination.name)
        archive.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(destination,archive)
        previous={'sha256':sha(destination),'archived_to':archive.relative_to(OUT).as_posix()}
    destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,destination)
    if sha(destination)!=sha(source):raise ValueError('copyback byte mismatch')
    return {'source':str(source),'destination':destination.relative_to(OUT).as_posix(),'sha256':sha(destination),'previous':previous}
