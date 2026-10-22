// Explicit debug checkpoints, actual running Godot renderer. No image edits.
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const {chromium}=require(path.join(process.env.UI_CAPTURE_PLAYWRIGHT,'playwright-core'));
const root=path.resolve('docs/content/r2'),out=path.join(root,'review-set');
const configs=[['front',1,3],['pincer',4,3],['artillery',7,3],['decision',10,2],['guard',12,2],['summary',14,1],['combo',15,1]];
(async()=>{
 await fs.mkdir(out,{recursive:true});
 const build=JSON.parse(await fs.readFile(path.join(root,'tests/builds.json'),'utf8')).review;
 let records=[];try{records=JSON.parse(await fs.readFile(path.join(root,'tests/samples.json'),'utf8'));}catch{}
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--mute-audio','--use-angle=swiftshader','--enable-unsafe-swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 try{for(const [scenario,start,count] of configs.filter(r=>!process.argv[2]||r[0]===process.argv[2])){
  const portrait=scenario==='combo',width=portrait?390:844,height=portrait?844:390;
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:3,hasTouch:true,isMobile:true,userAgent:'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Chrome/140.0.0.0 Mobile Safari/537.36'});
  const page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{if(m.type()==='error'&&!m.text().includes('404')&&!m.text().includes('invalid UID')&&!m.text().includes('resource_format_binary'))errors.push(m.text());});
  await page.goto(`http://127.0.0.1:8152/review/index.html?cv_r19_test=1&scenario=${scenario}`,{timeout:90000});
  for(let index=0;index<count;index++){
   try{await page.waitForFunction(index=>window.__cvContentR2Failure||(window.__cvContentR2Sample?.sample===index),index,{timeout:400000});}
   catch(error){await fs.writeFile(path.resolve(`.audit-tmp/content-r2/${scenario}-capture-failure.json`),JSON.stringify(await page.evaluate(()=>({failure:window.__cvContentR2Failure,sample:window.__cvContentR2Sample,hud:window.__cvR19Controls?.hud,runtime:window.__cvR32Runtime})),null,2));throw error;}
   const failure=await page.evaluate(()=>window.__cvContentR2Failure);if(failure)throw Error(scenario+' '+JSON.stringify(failure));
   await page.waitForTimeout(200);
   const state=await page.evaluate(()=>window.__cvContentR2Sample);
   const file=`${String(start+index).padStart(2,'0')}-${scenario}-${state.label}.png`;
   await page.screenshot({path:path.join(out,file)});
   const bytes=await fs.readFile(path.join(out,file));
   records=records.filter(r=>!(r.scenario===scenario&&r.sample===index));
   records.push({...state,...build,file:'review-set/'+file,width,height,dpr:3,dimensions:[width*3,height*3],errors:[...errors],sha256:crypto.createHash('sha256').update(bytes).digest('hex'),postprocessed:false});
   await fs.writeFile(path.join(root,'tests/samples.json'),JSON.stringify(records,null,2));
   console.log(file+' t='+state.time+' errors='+errors.length);
   if(errors.length)throw Error(errors.join('\n'));
   if(index+1<count)await page.evaluate(()=>window.__cvContentR2Next=true);
  }
  await context.close();
 }}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
