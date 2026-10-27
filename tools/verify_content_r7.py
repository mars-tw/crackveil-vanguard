"""Strict local R7 source, workflow and evidence verifier; never publishes."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,re,sys
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/content/r7';VERSION='0.36.0-content-r7'
checks=0;failures=[]
def check(ok,message):
 global checks
 checks+=1
 if not ok:failures.append(message)
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads((OUT/path).read_text(encoding='utf8'))
def source_before_after():
 before=read('tests/source-before.json');check(before.get('status')=='FROZEN','R7 before-source manifest missing/floating')
 inputs=before.get('files',{});check(before.get('fileCount')==len(inputs) and bool(inputs),'R7 source manifest count/empty')
 after=read('tests/ci-source-after.json');snapshot=read('tests/ci-source-before.json');check(snapshot==after,'formal CI input changed before/after')
 for rel,row in inputs.items():
  p=ROOT/rel;check(p.is_file() and sha(p)==row.get('sha256'),'R7 source hash mismatch '+rel)
 for rel,row in after.items():
  p=ROOT/rel;check(p.is_file() and sha(p)==row.get('sha256'),'R7 CI input changed '+rel)
def ci_gate():
 version=re.search(r'^config/version="([^"]+)"',(ROOT/'project.godot').read_text(encoding='utf8'),re.M)
 check(version is not None and version[1]==VERSION,'project version is not strict R7')
 check(VERSION in (ROOT/'README.md').read_text(encoding='utf8'),'README version mismatch')
 native=json.loads((ROOT/'native/build-config.json').read_text(encoding='utf8'));check(native.get('sourceVersion')==VERSION,'native source version mismatch')
 source_before_after()
 contract=read('tests/ci-contract.json');summary=read('tests/gates/summary.json');rows=summary if isinstance(summary,list) else summary.get('gates',[])
 expected=int(contract.get('new_gate_count',-1));check(expected==len(rows) and expected>=53,'R7 workflow gate count drift')
 for row in rows:check(row.get('status')=='VERIFIED' and row.get('exit_code',row.get('returncode',0))==0,'workflow gate failed '+str(row.get('scene',row.get('script','?'))))
 for script,minimum in [('content_r5_test.gd',18),('content_r6_test.gd',25),('content_r7_test.gd',18)]:
  unit=next((row for row in rows if row.get('script')=='scripts/debug/'+script),{})
  check(unit.get('status')=='VERIFIED' and unit.get('exit_code')==0 and unit.get('checks',0)>=minimum,'focused regression gate missing or failed '+script)
 for script,marker,minimum in [('content_r5_test.txt',rb'R5_REGRESSION status=PASS checks=(\d+)',18),('content_r6_test.txt',rb'R6_REGRESSION status=PASS checks=(\d+)',25),('content_r7_test.txt',rb'R7_REGRESSION status=PASS checks=(\d+)',17)]:
  unit_log=OUT/'tests/gates'/script
  unit_match=re.search(marker,unit_log.read_bytes()) if unit_log.is_file() else None
  check(unit_match is not None and int(unit_match[1])>=minimum,'focused regression log missing or failed '+script)
 packs=read('tests/builds.json');manifest=read('tests/source-hashes.json');manifest_sha=sha(OUT/'tests/source-hashes.json')
 for kind in ['release','review']:
  info=packs.get(kind,{});pack=ROOT/'export/content-r7'/kind/'index.pck'
  check(info.get('source_manifest_sha256')==manifest_sha,'R7 '+kind+' export used a different source manifest')
  check(pack.is_file() and sha(pack)==info.get('pack_sha256'),'R7 '+kind+' PCK hash mismatch')
  check(info.get('content_version')==VERSION,'R7 '+kind+' version mismatch')

def release_gate():
 ci_gate();manifest=read('review-manifest.json');items=manifest.get('images',[]) if isinstance(manifest,dict) else manifest
 check(len(items)==15,'R7 reviewer set must contain exactly 15 images')
 builds=read('tests/builds.json');source=sha(OUT/'tests/source-hashes.json')
 for row in items:
  path=OUT/row['file'];ok=path.is_file()
  check(ok,'R7 review image missing '+str(row.get('file')))
  if not ok:continue
  check(sha(path)==row.get('sha256'),'R7 review image SHA mismatch '+str(row['file']))
  try:
   with Image.open(path) as im:dimensions=list(im.size)
  except Exception:dimensions=[]
  check(dimensions==row.get('dimensions'),'R7 review image dimensions mismatch '+str(row['file']))
  check(row.get('source_manifest_sha256')==source,'R7 review image is from the wrong source')
  check(row.get('pack_sha256') in [builds['release']['pack_sha256'],builds['review']['pack_sha256']],'R7 review image is from an unlisted PCK')
  check(not row.get('postprocessed',False),'R7 original image was postprocessed')
  check(not row.get('errors') and not row.get('external_requests'),'R7 image has an engine/network error')
  review=read('manual-review.json');view=next((v for v in review.get('images',[]) if v.get('file')==row['file']),{})
  check(view.get('actually_viewed') is True and view.get('sha256')==row['sha256'],'R7 original not manually viewed '+str(row['file']))
 check((ROOT/'docs/CODEX_RESPONSE_CONTENT_R7.md').is_file(),'R7 delivery report missing')

def main():
 mode=sys.argv[1] if len(sys.argv)>1 else 'release'
 if mode=='ci':ci_gate()
 elif mode=='release':release_gate()
 else:raise SystemExit('usage: verify_content_r7.py [ci|release]')
 print(json.dumps({'status':'VERIFIED' if not failures else 'BLOCKED','mode':mode,'checks':checks,'failures':failures[:40]},ensure_ascii=False))
 raise SystemExit(0 if not failures else 1)
if __name__=='__main__':main()
