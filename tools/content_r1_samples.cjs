const fs=require('node:fs/promises'),path=require('node:path');
const {chromium}=require(path.join(process.env.UI_CAPTURE_PLAYWRIGHT,'playwright-core'));
const root=path.resolve('docs/content/r1/samples'),rows=[];
(async()=>{
 await fs.mkdir(root,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--mute-audio','--use-angle=swiftshader','--enable-unsafe-swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 try{for(const scenario of (process.argv.slice(2).length?process.argv.slice(2):['wedge','ring','scatter','bond','dense'])){
  const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:1,hasTouch:true,isMobile:true,userAgent:'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Chrome/140.0.0.0 Mobile Safari/537.36'});
  const page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{if(m.type()==='error'&&!m.text().includes('404')&&!m.text().includes('invalid UID')&&!m.text().includes('resource_format_binary'))errors.push(m.text());});
  await page.goto(`http://127.0.0.1:8151/content-r1-review/index.html?cv_r19_test=1&cv_r22_test=1&scenario=${scenario}`,{timeout:90000});
  for(let index=0;index<(scenario==='bond'?3:scenario==='dense'?2:1);index++){
   await page.waitForFunction(i=>window.__cvContentR1Sample?.sample===i,index,{timeout:240000});
   // One more rendered frame lets the HUD publish the final simulated frame.
   await page.waitForTimeout(160);
   const data=await page.evaluate(()=>window.__cvContentR1Sample);
   const image=path.join(root,`${scenario}-${index}.png`);
   await page.screenshot({path:image});
   rows.push({...data,errors:[...errors],image:path.relative(process.cwd(),image),kind:'debug fixture; ordinary Arena combat; no altered enemy health/damage/spawn cadence; formation comparison freezes equipment pickup for equal growth'});
   console.log(`${scenario}/${index} t=${data.time} level=${data.level} enemies=${data.enemy_count} captured`);
   if(index<(scenario==='bond'?2:scenario==='dense'?1:0))await page.evaluate(()=>{window.__cvContentR1Next=true;});
  }
  await context.close();if(errors.length)throw Error(errors.join('\n'));
 }}finally{await browser.close();await fs.writeFile(path.join(root,'samples.json'),JSON.stringify(rows,null,2));}
 const comparison=rows.filter(r=>['wedge','ring','scatter'].includes(r.scenario));
 if(comparison.length===3){
  if(new Set(comparison.map(r=>r.seed)).size!==1||new Set(comparison.map(r=>r.level)).size!==1||Math.max(...comparison.map(r=>r.time))-Math.min(...comparison.map(r=>r.time))>1/60+0.001||new Set(comparison.map(r=>r.roster.map(x=>x.id).join(','))).size!==1||comparison.some(r=>Object.keys(r.equipment).length))throw Error('formation comparison conditions differ');
 }
})().catch(e=>{console.error(e);process.exitCode=1;});
