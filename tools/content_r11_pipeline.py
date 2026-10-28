"""R11 isolated release/review export and source-bound local Web capture."""
from pathlib import Path
from functools import partial
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
import hashlib,json,os,subprocess,sys,threading,time
import content_r4_pipeline as core
import content_r11_boundary as boundary

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/content/r11'
TMP=ROOT/'.audit-tmp/content-r11'
BUILD=ROOT/'export/content-r11'
PROJECT=TMP/'export-project'
core.ROOT=ROOT;core.OUT=OUT;core.TMP=TMP;core.BUILD=BUILD;core.PROJECT=PROJECT;core.boundary=boundary;core.junction=boundary.junction
core.ALLOWED.update({'content_r5_test.gd','content_r5_pilot.gd','content_r5_run.gd','ContentR5Run.tscn','content_r6_test.gd','content_r7_test.gd','content_r8_test.gd','content_r9_test.gd','content_r10_test.gd','content_r11_test.gd'})
_base_sources=core.sources
def _r5_sources():return _base_sources()
core.sources=_r5_sources
def _r5_write(path,value):boundary.write_json(path,value)
core.write=_r5_write

def source_map():
 state=core.sources()
 for rel in ['tools/content_r11_boundary.py','tools/content_r11_pipeline.py','tools/content_r11_native.py','tools/content_r11_capture.cjs','tools/verify_content_r11.py','scripts/debug/r14_regression_test.gd','.github/workflows/deploy-web.yml','README.md','native/build-config.json']:
  p=ROOT/rel;state[p.relative_to(ROOT).as_posix()]=core.sha(p)
 return state

def freeze_sources():
 boundary.assert_snapshot(boundary.snapshot())
 state=source_map();path=boundary.assert_output(OUT/'tests/source-before.json');runtime=core.sources()
 if path.exists():
  old=json.loads(path.read_text(encoding='utf8'))
  if old['files']!={key:{'sha256':digest} for key,digest in state.items()}:raise ValueError('R11 source manifest is frozen; preserve the changed attempt and create a new R11 source epoch')
 else:
  core.write(path,{'status':'FROZEN','version':'0.40.0-content-r11','files':{k:{'sha256':v} for k,v in state.items()},'fileCount':len(state),'baselineCommit':'d9f061ff0c73b90a206e99f5dda0579447cda586','frozenUtc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())})
 manifest=boundary.assert_output(OUT/'tests/source-hashes.json')
 if manifest.exists():
  if json.loads(manifest.read_text(encoding='utf8'))['files']!=runtime:raise ValueError('R11 runtime source hash differs from frozen source map')
 else:
  core.write(manifest,{'files':runtime,'version':'0.40.0-content-r11','scope':'runtime source and exact debug capture allowlist','capturedUtc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())})
 return path

def export(kind):
 freeze_sources();core.export(kind)
 metadata=boundary.assert_output(OUT/'tests/builds.json');builds=json.loads(metadata.read_text(encoding='utf8'))
 for name in ['release','review']:
  if name in builds:
   builds[name]['export_driver_sha256']=core.sha(Path(__file__))
   builds[name]['boundary_driver_sha256']=core.sha(ROOT/'tools/content_r11_boundary.py')
   builds[name]['content_version']='0.40.0-content-r11'
 core.write(metadata,builds)
 print(kind,builds[kind]['pack_sha256'],flush=True)

class Quiet(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass

def browser(mode):
 allowed={'controls','preparation','milestone','assault','escort','pause-layout'}
 if mode not in allowed:raise ValueError('unsupported R11 browser capture mode: '+mode)
 boundary.assert_snapshot(boundary.snapshot())
 manifest=freeze_sources();driver=ROOT/'tools/content_r11_capture.cjs';before=core.sha(driver)
 server=ThreadingHTTPServer(('127.0.0.1',8160),partial(Quiet,directory=str(BUILD)))
 thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
 env=os.environ.copy();env.update({'PLAYWRIGHT_CORE_PATH':str(Path.home()/'.bun/install/cache/playwright-core@1.59.1@@@1'),'CONTENT_BUILD_URL':'http://127.0.0.1:8160','CONTENT_EVIDENCE_DIR':str(OUT),'CONTENT_DRIVER_SHA256':before,'CONTENT_SOURCE_MANIFEST_SHA256':core.sha(manifest),'CONTENT_BROWSER_PORT':'8160','CV_QA_PROFILE':'content_r11_web'})
 log=boundary.assert_output(OUT/'tests'/('browser-'+mode+'.txt'));log.parent.mkdir(parents=True,exist_ok=True)
 try:
  with log.open('w',encoding='utf8',newline='\n') as stream:
   result=subprocess.run(['node','tools/content_r11_capture.cjs',mode],cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW,timeout=2400)
  after=core.sha(driver);snapshot=boundary.snapshot();boundary.assert_snapshot(snapshot)
  receipt={'status':'VERIFIED' if result.returncode==0 and before==after else 'BLOCKED','exitCode':result.returncode,'captureDriverBefore':before,'captureDriverAfter':after,'sourceManifestSha256':core.sha(manifest),'builds':json.loads((OUT/'tests/builds.json').read_text(encoding='utf8')),'logSha256':core.sha(log),'protection':snapshot,'boundaryBefore':boundary.snapshot()}
  core.write(OUT/'tests'/('browser-'+mode+'.json'),receipt)
  if result.returncode!=0:raise SystemExit(log.read_text(encoding='utf8'))
 finally:
  server.shutdown();server.server_close();thread.join(timeout=5)

def ci():
 freeze_sources()
 import content_r11_native as native
 native.ci()

def main():
 OUT.mkdir(parents=True,exist_ok=True);(OUT/'tests').mkdir(parents=True,exist_ok=True);TMP.mkdir(parents=True,exist_ok=True)
 if len(sys.argv)<2:raise SystemExit('usage: content_r11_pipeline.py freeze|export release|export review|browser controls|preparation|milestone|assault|escort|pause-layout|ci|pilot')
 action=sys.argv[1]
 if action=='freeze':print(freeze_sources())
 elif action=='export' and len(sys.argv)==3:
  if not (OUT/'tests/source-before.json').exists():freeze_sources()
  export(sys.argv[2])
 elif action=='browser' and len(sys.argv)==3:browser(sys.argv[2])
 elif action=='ci' and len(sys.argv)==2:ci()
 elif action=='pilot' and len(sys.argv)==2:
  freeze_sources()
  import content_r11_native as native
  native.pilot()
 else:raise SystemExit('invalid R11 pipeline action')

if __name__=='__main__':
 sys.stdout.reconfigure(encoding='utf8')
 main()
