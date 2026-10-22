// Actual normal release input path. No game state mutation or QA entry point.
const fs=require('node:fs/promises'),path=require('node:path');
const {chromium}=require(path.join(process.env.UI_CAPTURE_PLAYWRIGHT,'playwright-core'));
const out=path.resolve('docs/content/r1/live');
(async()=>{
 await fs.mkdir(out,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--mute-audio','--use-angle=swiftshader','--enable-unsafe-swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:1,hasTouch:true,isMobile:true,userAgent:'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Chrome/140.0.0.0 Mobile Safari/537.36'});
 const page=await context.newPage(),errors=[],events=[],shots=[];let success=false;
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error'&&!m.text().includes('404')&&!m.text().includes('invalid UID')&&!m.text().includes('resource_format_binary'))errors.push(m.text());});
 const probe=()=>page.evaluate(()=>window.__cvR19Controls?.hud);
 const wait=async(s,k,v)=>{await page.waitForFunction(({s,k,v})=>{const p=window.__cvR19Controls?.[s];return p&&(k===null||p.flags[k]===v);},{s,k,v},{timeout:90000});return page.evaluate(s=>window.__cvR19Controls[s],s);};
 const tap=async(p,id)=>{const c=p.controls[id];if(!c?.visible)throw Error('missing '+id);await page.touchscreen.tap(c.center_x,c.center_y);};
 const shot=async name=>{const state=await probe();await page.screenshot({path:path.join(out,name+'.png')});shots.push({name,state:state.flags});};
 const keys=new Set();
 const move=async(dx,dy)=>{const wanted=new Set();if(dx>22)wanted.add('d');if(dx< -22)wanted.add('a');if(dy>22)wanted.add('s');if(dy< -22)wanted.add('w');for(const k of keys)if(!wanted.has(k)){await page.keyboard.up(k);keys.delete(k);}for(const k of wanted)if(!keys.has(k)){await page.keyboard.down(k);keys.add(k);}};
 try{
  await page.goto('http://127.0.0.1:8151/content-r1/index.html?cv_r19_test=1&cv_r22_test=1',{timeout:90000});
  let p=await wait('main_menu',null,null);await tap(p,'start');p=await wait('hud','paused',false);
  const cdp=await context.newCDPSession(page);
  const picker=async()=>{const b=(await probe()).controls.formation;await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:8,x:b.center_x,y:b.center_y}]});await wait('hud','formation_picker',true);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});return probe();};
  p=await picker();await shot('01-picker');await tap(p,'formation_cancel');
  let last=-1,holding=0;const deadline=Date.now()+180000;
  while(Date.now()<deadline){
   p=await probe();if(!p)continue;const r=p.flags.relay;
   if(p.flags.paused)throw Error('unexpected pause');
   if(r.completed){await move(0,0);await shot('04-sealed');break;}
   const required=['wedge','ring','scatter'][r.step];
   if(p.flags.formation_id!==required){await move(0,0);await page.waitForFunction(()=>window.__cvR19Controls?.hud?.flags.formation_ready,null,{timeout:15000});p=await picker();await tap(p,'formation_'+required);await wait('hud','formation_id',required);}
   if(r.step!==last){events.push({step:r.step,time:p.flags.elapsed});last=r.step;}
   if(r.distance<50||r.hold>0)await move(0,0);else await move(r.anchor_x-r.captain_x,r.anchor_y-r.captain_y);
   if(r.step===0&&r.hold>0.05&&holding===0){await shot('02-hold-a');holding=1;}
   else if(r.step===0&&r.hold>0.65&&holding===1){await shot('03-hold-b');holding=2;}
   await page.waitForTimeout(70);
  }
  p=await probe();if(!p.flags.relay.completed||!p.flags.seal_saved)throw Error('relay not completed/saved');
  if(errors.length)throw Error(errors.join('\n'));
  if(holding!==2)throw Error('missing continuous hold frames');
  success=true;
 }finally{
  await move(0,0);await browser.close();await fs.writeFile(path.join(out,'path.json'),JSON.stringify({status:success?'VERIFIED':'BLOCKED',events,shots,errors,input:'CDP long press/direct selection and supported movement keys; ordinary release'},null,2));
 }
 console.log('CONTENT_R1_LIVE_PASS');
})().catch(e=>{console.error(e);process.exitCode=1;});
