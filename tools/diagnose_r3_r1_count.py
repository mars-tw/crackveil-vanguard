"""Read-only assertion trace of identical R1 test under ce94/R3 runtimes.

Only temp copies add prints; original tests and every assertion remain intact.
"""
from pathlib import Path
import collections,datetime,hashlib,io,json,os,subprocess,tarfile
from content_r3_native import ROOT,OUT,TMP,GODOT,junction,write,sha

work=TMP/'r1-count';baseline=work/'baseline';baseline.mkdir(parents=True,exist_ok=True)
archive=subprocess.check_output(['git','archive','--format=tar','ce94e02','scripts','scenes','resources','project.godot'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
    for entry in tar:
        assert (baseline/entry.name).resolve().is_relative_to(baseline.resolve())
    tar.extractall(baseline,filter='data')
junction(baseline/'assets',ROOT/'assets')
(baseline/'.godot').mkdir(exist_ok=True)
junction(baseline/'.godot/imported',ROOT/'.godot/imported')
for name in ['global_script_class_cache.cfg','uid_cache.bin']:
    path=ROOT/'.godot'/name
    if path.exists():(baseline/'.godot'/name).write_bytes(path.read_bytes())
old=(baseline/'scripts/debug/content_r1_test.gd').read_text(encoding='utf8');current=(ROOT/'scripts/debug/content_r1_test.gd').read_text(encoding='utf8')
assert old==current,'the original R1 test changed'
probe=current.replace('\tchecks += 1','\tchecks += 1\n\tprint("R1_COUNT_CHECK="+JSON.stringify(message))').replace('\tvar font := label.get_theme_font("font")','\tprint("R1_COUNT_LABEL="+JSON.stringify({"tag":tag,"text":label.text}))\n\tvar font := label.get_theme_font("font")')
assert probe.count('R1_COUNT_CHECK=')==1 and probe.count('R1_COUNT_LABEL=')==1
records={}
for name,project,folder in [('baseline',baseline,baseline),('current',ROOT,work/'current')]:
    folder.mkdir(parents=True,exist_ok=True)
    (folder/'probe.gd').write_text(probe,encoding='utf8',newline='\n')
    (folder/'Probe.tscn').write_text('[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://'+(folder/'probe.gd').relative_to(project).as_posix()+'" id="1"]\n\n[node name="R1CountProbe" type="Node"]\nscript=ExtResource("1")\n',encoding='utf8',newline='\n')
    env=os.environ.copy();env['CV_QA_PROFILE']='content_r3_count_'+name
    for key,value in [('APPDATA','roaming'),('LOCALAPPDATA','local')]:
        path=work/'profiles'/name/value;path.mkdir(parents=True,exist_ok=True);env[key]=str(path)
    output=OUT/'tests/r1-count'/name;output.mkdir(parents=True,exist_ok=True)
    env['CV_TEST_EVIDENCE_DIR']=str(output)
    command=[str(GODOT),'--headless','--audio-driver','Dummy','--fixed-fps','60','--path',str(project),str(folder/'Probe.tscn')]
    result=subprocess.run(command,cwd=project,env=env,capture_output=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
    log=(result.stdout+result.stderr).decode('utf8',errors='replace').replace('\r\n','\n').rstrip()+'\n'
    (output/'trace.txt').write_text(log,encoding='utf8',newline='\n')
    assert result.returncode==0 and 'ERROR:' not in log,log[-2500:]
    calls=[json.loads(line.split('=',1)[1]) for line in log.splitlines() if line.startswith('R1_COUNT_CHECK=')]
    labels=[json.loads(line.split('=',1)[1]) for line in log.splitlines() if line.startswith('R1_COUNT_LABEL=')]
    records[name]={'command':command,'exit_code':result.returncode,'calls':calls,'labels':labels,'test_source_sha256':hashlib.sha256(current.encode()).hexdigest(),'log_sha256':sha(output/'trace.txt'),'result':json.loads((output/'mechanics.json').read_text(encoding='utf8'))}
    print(name,'checks',len(calls),'labels',len(labels),flush=True)
base_labels={x['tag']:x['text'] for x in records['baseline']['labels']};new_labels={x['tag']:x['text'] for x in records['current']['labels']}
differences=[{'tag':tag,'baseline':text,'current':new_labels.get(tag)} for tag,text in base_labels.items() if text!=new_labels.get(tag)]
old_counter=collections.Counter(records['baseline']['calls']);new_counter=collections.Counter(records['current']['calls'])
write(OUT/'tests/r1-count/trace-comparison.json',{'captured_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'same_original_test':old==current,'instrumentation':'temp copies add only print before check and fits; no assertion or branch removed/rewritten','baseline_commit':'ce94e02','records':records,'label_differences':differences,'baseline_only_calls':list((old_counter-new_counter).elements()),'current_only_calls':list((new_counter-old_counter).elements())})
print(json.dumps({'label_differences':differences,'baseline_only_calls':list((old_counter-new_counter).elements()),'current_only_calls':list((new_counter-old_counter).elements())},ensure_ascii=True))
