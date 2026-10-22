// Local debug-only checkpoints rendered by the actual Web Godot runtime.
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const {chromium}=require(path.join(process.env.UI_CAPTURE_PLAYWRIGHT,'playwright-core'));
const root=path.resolve(process.env.CONTENT_EVIDENCE_DIR||'docs/content/r2-1');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
(async()=>{
 await fs.mkdir(path.join(root,'review-set'),{recursive:true});
 const build=JSON.parse(await fs.readFile(path.join(root,'tests/builds.json'),'utf8')).review;
 const browser=await chromium.launch({headless:true,executablePath:process.env.UI_CAPTURE_CHROME||'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--mute-audio','--use-angle=swiftshader','--enable-unsafe-swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 const records=[],runs=[];
 try{for(const [width,height,input,gateOnly] of [[844,390,'mouse',false],[390,844,'mouse',false],[1366,600,'mouse',false],[844,390,'touch',true],[390,844,'touch',true]].filter(row=>!process.argv[2]||(row[0]===390&&row[2]==='touch'))){
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:1,hasTouch:width!==1366,isMobile:width!==1366});
  // The test server has no site icon; this browser-only request is unrelated
  // to the exported game. Supply an empty icon rather than suppressing 404s.
  await context.route('**/favicon.ico',route=>route.fulfill({status:204,body:''}));
  const page=await context.newPage(),errors=[],known_uid_warnings=[],external_requests=[];
  let uidWarningContinuation=false;
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{
   if(m.type()!=='error')return;
   const text=m.text();
   if(/^WARNING: 'res:\/\/[^']+': In external resource #\d+, invalid UID: 'uid:\/\/[^']+' - using text path instead: 'res:\/\/[^']+'\.$/.test(text)){
    known_uid_warnings.push(text);uidWarningContinuation=true;return;
   }
   if(uidWarningContinuation&&/^\s+at: open \(core\/io\/resource_format_binary\.cpp:1028\)$/.test(text)){
    known_uid_warnings.push(text);uidWarningContinuation=false;return;
   }
   uidWarningContinuation=false;errors.push(text);
  });
  page.on('requestfailed',r=>errors.push(`${r.url()} ${r.failure()?.errorText}`));
  page.on('response',r=>{if(r.status()>=400)errors.push(`${r.status()} ${r.url()}`);});
  page.on('request',r=>{if(new URL(r.url()).origin!==new URL(process.env.CONTENT_BUILD_URL||'http://127.0.0.1:8152').origin)external_requests.push(r.url());});
  await page.goto((process.env.CONTENT_BUILD_URL||'http://127.0.0.1:8152')+'/review/index.html?cv_r19_test=1'+(gateOnly?'&gate_only=1':''),{timeout:90000});
  await page.waitForFunction(()=>window.__cvContentR21Start,{timeout:90000});
  const start=await page.evaluate(()=>window.__cvContentR21Start);
  const click=async(x,y)=>input==='touch'?page.touchscreen.tap(x,y):page.mouse.click(x,y);
  await click(start.rect[0]+start.rect[2]/2,start.rect[1]+start.rect[3]/2);
  await page.waitForFunction(()=>window.__cvContentR21AfterStart,{timeout:15000});
  const afterStart=await page.evaluate(()=>window.__cvContentR21AfterStart);
  if(afterStart.paused||afterStart.manual_paused||afterStart.system_paused||afterStart.summon_visible||afterStart.gate_visible)throw Error('start gesture click-through '+JSON.stringify({width,height,input,afterStart}));
  await click(afterStart.pause_rect[0]+afterStart.pause_rect[2]/2,afterStart.pause_rect[1]+afterStart.pause_rect[3]/2);
  await page.waitForFunction(()=>window.__cvR19Controls?.hud?.flags.paused===true,{timeout:15000});
  const resume=await page.evaluate(()=>window.__cvR19Controls.hud.controls.pause_resume);
  await click(resume.center_x,resume.center_y);
  await page.waitForFunction(()=>window.__cvR19Controls?.hud?.flags.paused===false,{timeout:15000});
  await page.evaluate(()=>window.__cvContentR21VerifyNextInput=true);
  let index=0;
  while(true){
   await page.waitForFunction(i=>window.__cvContentR21Result||window.__cvContentR21Sample?.sample===i,index,{timeout:90000});
   if(await page.evaluate(()=>!!window.__cvContentR21Result))break;
   const state=await page.evaluate(()=>window.__cvContentR21Sample);
   if(state.failures_so_far.length)throw Error(JSON.stringify(state));
   let image={};
   if(state.screenshot){
    const file=`review-set/${width}x${height}-${state.label}.png`;
    await page.screenshot({path:path.join(root,file)});
    image={file,sha256:sha(await fs.readFile(path.join(root,file))),dimensions:[width,height],postprocessed:false};
   }
   records.push({...state,...build,...image,errors:[...errors],external_requests:[...external_requests],dpr:1});
   await page.evaluate(()=>window.__cvContentR21Next=true);index++;
  }
  const result=await page.evaluate(()=>window.__cvContentR21Result);
  runs.push({width,height,input,gate_only:gateOnly,result,errors,known_uid_warnings,external_requests,start_input:{method:'Playwright centre '+input+' on Godot official audio_prompt_button',rect:start.rect,normal_pause_resume_verified:true,after_start:afterStart},...build});
  if(result.status!=='VERIFIED'||errors.length||external_requests.length)throw Error(JSON.stringify(runs.at(-1)));
  await context.close();console.log(`${width}x${height} ${input}: ${result.checks} checks, ${index} checkpoints`);
 }}finally{
  await browser.close();
  await fs.writeFile(path.join(root,'tests/samples.json'),JSON.stringify(records,null,2));
  await fs.writeFile(path.join(root,'tests/runtime-runs.json'),JSON.stringify(runs,null,2));
 }
})().catch(e=>{console.error(e);process.exitCode=1;});
