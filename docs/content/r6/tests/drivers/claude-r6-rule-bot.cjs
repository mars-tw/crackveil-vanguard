// Rule-following bot: real keyboard/mouse input only, reads the QA probe.
const path=require('node:path'),fs=require('node:fs');
const {chromium}=require('C:/Users/digimkt/.bun/install/cache/playwright-core@1.59.1@@@1');
const out=process.argv[2],W=+process.argv[3]||1366,H=+process.argv[4]||600,secs=+process.argv[5]||200,url=process.env.URL||'http://127.0.0.1:8177';
const shotEvery=+(process.env.SHOT||6);
const P=async(p,s)=>p.evaluate(s=>window.__cvR19Controls?.[s],s);
(async()=>{
 const b=await chromium.launch({headless:true,args:['--mute-audio','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const c=await b.newContext({viewport:{width:W,height:H},deviceScaleFactor:1});
 const p=await c.newPage();const errs=[];p.on('pageerror',e=>errs.push(String(e)));p.on('console',m=>{const t=m.text();if(m.type()==='error'&&!/invalid UID|resource_format_binary|404/.test(t))errs.push(t)});
 await p.goto(url+'/index.html?cv_r19_test=1');await p.waitForFunction(()=>window.__cvR19Controls?.main_menu,null,{timeout:120000});
 let mm=await P(p,'main_menu');await p.mouse.click(mm.controls.start.center_x,mm.controls.start.center_y);
 await p.waitForTimeout(2500);
 const t0=Date.now();let n=1,lastShot=-99,lastE=-1,held=new Set(),lastQ=0,log=[];
 const hold=async ks=>{for(const k of [...held])if(!ks.includes(k)){await p.keyboard.up(k);held.delete(k);}for(const k of ks)if(!held.has(k)){await p.keyboard.down(k);held.add(k);}};
 while(Date.now()-t0<secs*1000){
  const lu=await P(p,'level_up');if(lu?.flags?.visible){globalThis.lv=(globalThis.lv||0)+1;await hold([]);await p.waitForTimeout(700);if(globalThis.lv<=4){await p.screenshot({path:`${out}/${String(n++).padStart(2,'0')}-levelup-${globalThis.lv}.png`});log.push('LEVELUP '+JSON.stringify(lu.flags.cards));}await p.keyboard.press('Digit1');await p.waitForTimeout(500);continue;}
  const h=await P(p,'hud');if(!h){await p.waitForTimeout(500);continue;}
  const f=h.flags,r=f.relay||{};const el=f.elapsed;
  if(el===lastE&&!f.paused){await hold([]);const xs=[0.285,0.5,0.715];await p.mouse.click(W*xs[Math.floor(Math.random()*3)],H*0.55);await p.waitForTimeout(500);lastE=-1;
   globalThis.st=(globalThis.st||0)+1;if(globalThis.st===1)await p.screenshot({path:`${out}/${String(n++).padStart(2,'0')}-pause.png`});if(globalThis.st>14){await p.screenshot({path:`${out}/${String(n++).padStart(2,'0')}-end.png`});const res=await P(p,'result');log.push('END '+JSON.stringify(res?.flags||{}).slice(0,900));break;}
   continue;}
  lastE=el;globalThis.st=0;
  // Equipment detail: the bottom slot button opens its real effect panel.
  if(el>24&&!globalThis.eq){globalThis.eq=1;await hold([]);await p.mouse.click(Math.round(W*0.398),H-28);await p.waitForTimeout(500);if((await P(p,'level_up'))?.flags?.visible){globalThis.eq=0;continue;}await p.screenshot({path:`${out}/${String(n++).padStart(2,'0')}-equipment-e${Math.round(el)}.png`});await p.mouse.click(Math.round(W*0.398),H-28);await p.waitForTimeout(300);}
  if(r.phase==='recovery'&&globalThis.lp==='active'&&(globalThis.vc=(globalThis.vc||0)+1)<=8){await p.waitForTimeout(350);if((await P(p,'level_up'))?.flags?.visible){globalThis.lp=r.phase;continue;}await p.screenshot({path:`${out}/${String(n++).padStart(2,'0')}-verdict-e${Math.round(el)}.png`});}
  globalThis.lp=r.phase;
  // Seal success: the step counter advanced on this frame (real seal), capture the flash.
  if(typeof r.step==='number'){if(globalThis.ls!==undefined&&r.step>globalThis.ls){await p.waitForTimeout(450);await p.screenshot({path:`${out}/${String(n++).padStart(2,'0')}-seal-${r.step}-e${Math.round(el)}.png`});}globalThis.ls=r.step;}
  // formation
  // Step 1 demo: keep the wrong formation on the seal until the real backlash fires.
  const holdWrong=r.step===1&&!(r.wrong>0);
  if(r.step===1&&r.wrong>0&&!globalThis.wrongShot&&!(await P(p,'level_up'))?.flags?.visible){globalThis.wrongShot=1;await p.waitForTimeout(200);await p.screenshot({path:`${out}/${String(n++).padStart(2,'0')}-wrong-backlash-e${Math.round(el)}.png`});globalThis.afterWrong=Date.now();}
  if(globalThis.afterWrong&&!globalThis.rightShot&&f.formation_id===r.required&&Date.now()-globalThis.afterWrong>2500){globalThis.rightShot=1;await p.screenshot({path:`${out}/${String(n++).padStart(2,'0')}-switched-correct-e${Math.round(el)}.png`});}
  if(!holdWrong&&r.required&&f.formation_id!==r.required&&r.open&&Date.now()-lastQ>1300&&f.formation_ready){await p.keyboard.press('KeyQ');lastQ=Date.now();}
  // movement toward anchor when open, else orbit
  let ks=[];
  if(r.open&&!r.completed){const dx=r.anchor_x-r.captain_x,dy=r.anchor_y-r.captain_y;if(Math.hypot(dx,dy)>30){if(dx>18)ks.push('KeyD');if(dx<-18)ks.push('KeyA');if(dy>18)ks.push('KeyS');if(dy<-18)ks.push('KeyW');}}
  else{const ph=Math.floor((Date.now()-t0)/1800)%4;ks=[['KeyD'],['KeyS'],['KeyA'],['KeyW']][ph];}
  await hold(ks);
  await p.waitForTimeout(250);
  if(el-lastShot>=shotEvery){lastShot=el;await p.screenshot({path:`${out}/${String(n++).padStart(2,'0')}-e${Math.round(el)}.png`});log.push(`${el.toFixed(1)} hp=${f.hp??''} ${JSON.stringify(f.mission_text)} relay=${JSON.stringify({s:r.step,k:r.pressure,ph:r.phase,req:r.required,fm:f.formation_id,hold:r.hold?.toFixed?.(1),set:r.settled,d:Math.round(r.distance)})}`);console.log(log[log.length-1]);}
 }
 fs.writeFileSync(out+'/log.txt',log.join('\n'));
 console.log('errors',JSON.stringify(errs.slice(0,8)));await b.close();
})();
