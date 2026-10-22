// Real headless Chromium input only. Probes are read-only geometry/state.
const fs = require('node:fs/promises');
const path = require('node:path');
const {chromium} = require(path.join(process.env.UI_CAPTURE_PLAYWRIGHT, 'playwright-core'));
const before = process.argv.includes('--before');
const out = path.resolve(process.env.R44_REVIEW_OUT || 'docs/evidence/r44-store');
const shot = path.resolve(process.env.R44_REVIEW_SHOTS || 'docs/store/screenshots');
const base = process.env.UI_CAPTURE_URL || 'http://127.0.0.1:8144/r44-store/';
const check = (value, message) => { if (!value) throw Error(message); };
const rows=[];
const diagnostics=[];
(async()=>{
 await fs.mkdir(out,{recursive:true}); await fs.mkdir(shot,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:process.env.UI_CAPTURE_CHROME||'C:/Program Files/Google/Chrome/Application/chrome.exe',args:["--mute-audio", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", '--enable-webgl','--ignore-gpu-blocklist']});
 try {
  for (const [width,height,dpr] of (before?[[430,932,3],[1032,1376,2],[1366,600,1]]:process.argv.includes('--tablet-only')?[[1032,1376,2]]:[[430,932,3],[1032,1376,2]])) {
   const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:dpr,hasTouch:true,isMobile:true,userAgent:width<700?'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1':'Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
   const page=await context.newPage(); const errors=[], requests=[];
   page.on('pageerror',e=>errors.push(String(e)));
   page.on('request',r=>requests.push({url:r.url(),method:r.method()}));
   let phase='boot';
   page.on('console',m=>{if(m.type()==='error' && !m.text().includes('404') && !(m.text().includes("WARNING: 'res://")&&m.text().includes('invalid UID:')) && !m.text().includes('at: open (core/io/resource_format_binary.cpp:1028)')){errors.push(m.text());diagnostics.push({width,height,phase,text:m.text(),location:m.location()});console.log('R44_RUNTIME_ERROR '+phase+' '+m.text());}});
   const probe=async scope=>page.evaluate(s=>window.__cvR19Controls?.[s],scope);
   const wait=async(scope,key,value)=>{await page.waitForFunction(({scope,key,value})=>{const p=window.__cvR19Controls?.[scope];return p&&(key===null||p.flags[key]===value);},{scope,key,value},{timeout:90000});return probe(scope);};
   const touch=await context.newCDPSession(page);
   const click=async(p,id)=>{const c=p.controls[id];check(c?.visible,`missing ${id}`);await page.touchscreen.tap(c.center_x,c.center_y);};
   await page.goto(base+'index.html?cv_r19_test=1&cv_r22_test=1',{timeout:90000});
   let p=await wait('main_menu',null,null);
   await page.screenshot({path:path.join(out,`${before?'before':'after'}-${width}x${height}-menu.png`)});
   if(!before){
    await click(p,'guide'); p=await wait('main_menu','side_panel_visible',true);
    await page.screenshot({path:path.join(out,`guide-${width}x${height}.png`)});
    await click(p,'side_close'); p=await wait('main_menu','side_panel_visible',false);
    await context.setOffline(true);
   }
   phase='start';await click(p,'start'); p=await wait('hud','paused',false);
   if(!before&&p.controls.auto_battle?.visible&&!p.flags.auto_upgrade){
    await click(p,'auto_battle');p=await wait('hud','auto_upgrade',true);
   }
   await page.waitForTimeout(600);
   await page.screenshot({path:path.join(before?out:shot,`${before?'before':'01-relay'}-${width*dpr}x${height*dpr}.png`)});
   if(before){rows.push({width,height,dpr,status:'VERIFIED',errors});await context.close();continue;}
   const checkpoints=[]; const keys=new Set();
   const move=async(dx,dy)=>{
    const wanted=new Set();
    if(dx>18)wanted.add('d');if(dx< -18)wanted.add('a');if(dy>18)wanted.add('s');if(dy< -18)wanted.add('w');
    for(const key of keys)if(!wanted.has(key)){await page.keyboard.up(key);keys.delete(key);}
    for(const key of wanted)if(!keys.has(key)){await page.keyboard.down(key);keys.add(key);}
   };
   // R2 opens its third seal at 84s. Keep the game-time <180 assertion below;
   // allow headless software rendering enough wall time to reach that encounter.
   phase='relay';const deadline=Date.now()+240000; let lastStep=-1;
   while(Date.now()<deadline){
    p=await probe('hud'); const r=p.flags.relay;
    check(!p.flags.paused,'unexpected paused state during relay');
    if(r.completed){checkpoints.push({step:3,elapsed:p.flags.elapsed});break;}
    if(lastStep!==r.step){
     checkpoints.push({step:r.step,elapsed:p.flags.elapsed}); lastStep=r.step;
     await move(0,0);
     if(r.step>0){
      const form=['wedge','ring','scatter'][r.step];
      if(p.flags.formation_id!==form){
       await page.waitForFunction(()=>window.__cvR19Controls?.hud?.flags.formation_cooldown<=0&&window.__cvR19Controls?.hud?.flags.formation_ready,null,{timeout:15000});
       p=await probe('hud');
       const b=p.controls.formation;
       await touch.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:9,x:b.center_x,y:b.center_y}]});
       // Under concurrent CPU/GPU load, 480ms of wall time may contain too
       // few game frames. Keep the real finger down until the menu opens.
       await wait('hud','formation_picker',true);
       await touch.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
       p=await wait('hud','formation_picker',true);
       await page.waitForTimeout(250);p=await probe('hud');
       check(p.flags.formation_id!==form,'long press changed formation before direct choice');
       await page.screenshot({path:path.join(out,`picker-${form}-${width}x${height}.png`)});
       await fs.writeFile(path.join(out,`picker-${form}-${width}x${height}.json`),JSON.stringify(p,null,2));
       await click(p,'formation_'+form);
       await wait('hud','formation_id',form);
       await wait('hud','formation_picker',false);
       await page.screenshot({path:path.join(shot,`02-${form}-${width*dpr}x${height*dpr}.png`)});
      }
     }
    }
    // Stop inside the marker so the formation's facing can settle. Chasing
    // the exact pixel makes a controller spin the followers around forever.
    if(r.distance<=50 || r.hold>0)await move(0,0);
    else await move(r.anchor_x-r.captain_x,r.anchor_y-r.captain_y);
    await page.waitForTimeout(90);
   }
   await fs.writeFile(path.join(out,`last-hud-${width}x${height}.json`),JSON.stringify(p,null,2));
   await move(0,0); p=await probe('hud');
   check(p.flags.relay.completed&&p.flags.seal_saved,'relay did not complete/save '+JSON.stringify(p.flags));
   check(p.flags.elapsed<180,'signature loop exceeded three minutes');
   await page.screenshot({path:path.join(shot,`03-sealed-${width*dpr}x${height*dpr}.png`)});
   phase='pause';await click(p,'pause'); p=await wait('hud','paused',true);
   const elapsed=p.flags.elapsed;await page.waitForTimeout(700);check(Math.abs((await probe('hud')).flags.elapsed-elapsed)<0.1,'pause clock advanced');
   await click(p,'pause_run_tab');await page.waitForTimeout(200);
   await page.screenshot({path:path.join(shot,`04-objectives-${width*dpr}x${height*dpr}.png`)});
   await click(await probe('hud'),'pause_resume');await wait('hud','paused',false);
   await click(await probe('hud'),'pause');p=await wait('hud','paused',true);
   const back=p.controls.pause_return;check(back.visible&&back.width>=44&&back.height>=44&&back.x>=0&&back.y>=0&&back.x+back.width<=width+1&&back.y+back.height<=height+1,'retreat unreachable');
   phase='retreat';await click(p,'pause_return');p=await wait('main_menu','seal_saved',true);check(p.flags.seal_saved,'retreat lost seal');
   // A full engine reload simulates a restart. Only permanent rewards persist.
   phase='restart';await context.setOffline(false);await page.waitForTimeout(1000);await page.reload({timeout:90000});
   p=await wait('main_menu',null,null);check(p.flags.seal_saved,'restart lost permanent seal');check(p.flags.shards>=4,'restart lost earned currency');await click(p,'meta');p=await wait('main_menu','side_panel_visible',true);
   await click(p,'tactical_collection');await wait('main_menu','panel_id','tactical');
   await page.screenshot({path:path.join(shot,`05-saved-${width*dpr}x${height*dpr}.png`)});
   const outside=requests.filter(r=>!r.url.startsWith(new URL(base).origin+'/')&&!r.url.startsWith('blob:')&&!r.url.startsWith('data:'));
   check(errors.length===0,JSON.stringify(errors));check(outside.length===0,'external network '+JSON.stringify(outside));
   rows.push({width,height,dpr,status:'VERIFIED',offline_play_after_load:true,returned_via_pause_menu:true,checkpoints,elapsed_before_restart:elapsed,errors,external_requests:outside,request_count:requests.length});
   await context.close();console.log(`${width}x${height} reviewer path VERIFIED`);
  }
 }finally{await browser.close();await fs.writeFile(path.join(out,`${before?'before':'reviewer'}-path.json`),JSON.stringify(rows,null,2));await fs.writeFile(path.join(out,'runtime-diagnostics.json'),JSON.stringify(diagnostics,null,2));}
})().catch(e=>{console.error(e);process.exitCode=1;});
