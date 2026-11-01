"""Strict local R15 source, workflow and evidence verifier; never publishes."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,re,sys
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/content/r15';VERSION='0.44.0-content-r15'
checks=0;failures=[]
def check(ok,message):
 global checks
 checks+=1
 if not ok:failures.append(message)
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads((OUT/path).read_text(encoding='utf8'))
def source_before_after():
 before=read('tests/source-before.json');check(before.get('status')=='FROZEN','R15 before-source manifest missing/floating')
 inputs=before.get('files',{});check(before.get('fileCount')==len(inputs) and bool(inputs),'R15 source manifest count/empty')
 after=read('tests/ci-source-after.json');snapshot=read('tests/ci-source-before.json');check(snapshot==after,'formal CI input changed before/after')
 for rel,row in inputs.items():
  p=ROOT/rel;check(p.is_file() and sha(p)==row.get('sha256'),'R15 source hash mismatch '+rel)
 for rel,row in after.items():
  p=ROOT/rel;check(p.is_file() and sha(p)==row.get('sha256'),'R15 CI input changed '+rel)
def ci_gate():
 version=re.search(r'^config/version="([^"]+)"',(ROOT/'project.godot').read_text(encoding='utf8'),re.M)
 check(version is not None and version[1]==VERSION,'project version is not strict R15')
 check(VERSION in (ROOT/'README.md').read_text(encoding='utf8'),'README version mismatch')
 native=json.loads((ROOT/'native/build-config.json').read_text(encoding='utf8'));check(native.get('sourceVersion')==VERSION,'native source version mismatch')
 source_before_after()
 contract=read('tests/ci-contract.json');summary=read('tests/gates/summary.json');rows=summary if isinstance(summary,list) else summary.get('gates',[])
 expected=int(contract.get('new_gate_count',-1));check(expected==len(rows) and expected>=61,'R15 workflow gate count drift')
 for row in rows:check(row.get('status')=='VERIFIED' and row.get('exit_code',row.get('returncode',0))==0,'workflow gate failed '+str(row.get('scene',row.get('script','?'))))
 for script,minimum in [('content_r5_test.gd',18),('content_r6_test.gd',25),('content_r7_test.gd',18),('content_r8_test.gd',35),('content_r9_test.gd',134),('content_r10_test.gd',128),('content_r11_test.gd',54),('content_r12_test.gd',73),('content_r13_test.gd',65),('content_r14_test.gd',13),('content_r15_test.gd',10)]:
  unit=next((row for row in rows if row.get('script')=='scripts/debug/'+script),{})
  check(unit.get('status')=='VERIFIED' and unit.get('exit_code')==0 and unit.get('checks',0)>=minimum,'focused regression gate missing or failed '+script)
 for script,marker,minimum in [('content_r5_test.txt',rb'R5_REGRESSION status=PASS checks=(\d+)',18),('content_r6_test.txt',rb'R6_REGRESSION status=PASS checks=(\d+)',25),('content_r7_test.txt',rb'R7_REGRESSION status=PASS checks=(\d+)',18),('content_r8_test.txt',rb'R8_REGRESSION status=PASS checks=(\d+)',35),('content_r9_test.txt',rb'R9_REGRESSION status=PASS checks=(\d+)',134),('content_r10_test.txt',rb'R10_REGRESSION status=PASS checks=(\d+)',128),('content_r11_test.txt',rb'R11_REGRESSION status=PASS checks=(\d+)',54),('content_r12_test.txt',rb'R12_REGRESSION status=PASS checks=(\d+)',73),('content_r13_test.txt',rb'R13_REGRESSION status=PASS checks=(\d+)',65),('content_r14_test.txt',rb'R14_REGRESSION status=PASS checks=(\d+)',13),('content_r15_test.txt',rb'R15_REGRESSION status=PASS checks=(\d+)',10)]:
  unit_log=OUT/'tests/gates'/script
  unit_match=re.search(marker,unit_log.read_bytes()) if unit_log.is_file() else None
  check(unit_match is not None and int(unit_match[1])>=minimum,'focused regression log missing or failed '+script)
 packs=read('tests/builds.json');manifest=read('tests/source-hashes.json');manifest_sha=sha(OUT/'tests/source-hashes.json')
 for kind in ['release','review']:
  info=packs.get(kind,{});pack=ROOT/'export/content-r15'/kind/'index.pck'
  check(info.get('source_manifest_sha256')==manifest_sha,'R15 '+kind+' export used a different source manifest')
  check(pack.is_file() and sha(pack)==info.get('pack_sha256'),'R15 '+kind+' PCK hash mismatch')
  check(info.get('content_version')==VERSION,'R15 '+kind+' version mismatch')

def release_gate():
 ci_gate();manifest=read('review-manifest.json');items=manifest.get('images',[]) if isinstance(manifest,dict) else manifest
 check(len(items)==15,'R15 reviewer set must contain exactly 15 images')
 builds=read('tests/builds.json');source=sha(OUT/'tests/source-hashes.json')
 for row in items:
  path=OUT/row['file'];ok=path.is_file()
  check(ok,'R15 review image missing '+str(row.get('file')))
  if not ok:continue
  check(sha(path)==row.get('sha256'),'R15 review image SHA mismatch '+str(row['file']))
  try:
   with Image.open(path) as im:dimensions=list(im.size)
  except Exception:dimensions=[]
  check(dimensions==row.get('dimensions'),'R15 review image dimensions mismatch '+str(row['file']))
  check(row.get('source_manifest_sha256')==source,'R15 review image is from the wrong source')
  check(row.get('pack_sha256') in [builds['release']['pack_sha256'],builds['review']['pack_sha256']],'R15 review image is from an unlisted PCK')
  check(not row.get('postprocessed',False),'R15 original image was postprocessed')
  check(not row.get('errors') and not row.get('external_requests'),'R15 image has an engine/network error')
  review=read('manual-review.json');view=next((v for v in review.get('images',[]) if v.get('file')==row['file']),{})
  check(view.get('actually_viewed') is True and view.get('sha256')==row['sha256'],'R15 original not manually viewed '+str(row['file']))
 check((ROOT/'docs/CODEX_RESPONSE_CONTENT_R15.md').is_file(),'R15 delivery report missing')

def main():
 mode=sys.argv[1] if len(sys.argv)>1 else 'release'
 if mode=='ci':ci_gate()
 elif mode=='release':release_gate()
 else:raise SystemExit('usage: verify_content_r15.py [ci|release]')
 print(json.dumps({'status':'VERIFIED' if not failures else 'BLOCKED','mode':mode,'checks':checks,'failures':failures[:40]},ensure_ascii=False))
 raise SystemExit(0 if not failures else 1)
if __name__=='__main__':main()
