// Real silent Chromium/SwiftShader input and untouched Godot screenshots.
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const {chromium}=require(path.join(process.env.UI_CAPTURE_PLAYWRIGHT,'playwright-core'));
const root=path.resolve(process.env.CONTENT_EVIDENCE_DIR||'docs/content/r3');
const url=process.env.CONTENT_BUILD_URL||'http://127.0.0.1:8153';
const mode=process.argv[2]||'controls',sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const invariant=(value,message)=>{if(!value)throw Error(message);};
const read=async file=>JSON.parse(await fs.readFile(path.join(root,file),'utf8'));
const write=async(file,value)=>{await fs.mkdir(path.dirname(path.join(root,file)),{recursive:true});await fs.writeFile(path.join(root,file),JSON.stringify(value,null,2));};
let browser,builds,samples=[];
async function surface(width,height,dpr=3){
 const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:dpr,hasTouch:width!==1366,isMobile:width!==1366,userAgent:width!==1366?'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Chrome/140.0.0.0 Mobile Safari/537.36':undefined});
 await context.route('**/favicon.ico',r=>r.fulfill({status:204,body:''}));
 const page=await context.newPage(),errors=[],warnings=[],external=[];
 let continuation=false;
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{const t=m.text();if(t.startsWith('CONTENT_R2_PROGRESS'))console.log(t);if(m.type()!=='error')return;
  if(/^WARNING: 'res:\/\/[^']+': In external resource #\d+, invalid UID: 'uid:\/\/[^']+' - using text path instead: 'res:\/\/[^']+'\.$/.test(t)){warnings.push(t);continuation=true;return;}
  if(continuation&&(/^\s+at: open \(core\/io\/resource_format_binary\.cpp:1028\)$/.test(t)||/^\s+GDScript backtrace \(most recent call first\):$/.test(t)||/^\s+\[\d+\] [A-Za-z0-9_]+ \(res:\/\/scripts\/[A-Za-z0-9_\/-]+\.gd:\d+\)$/.test(t))){warnings.push(t);return;}
  continuation=false;errors.push(t);console.log('GODOT_DIAGNOSTIC '+t);
 });
 page.on('requestfailed',r=>errors.push(r.url()+' '+r.failure()?.errorText));
 page.on('response',r=>{if(r.status()>=400)errors.push(r.status()+' '+r.url());});
 page.on('request',r=>{if(new URL(r.url()).origin!==url)external.push(r.url());});
 return {context,page,errors,warnings,external,width,height,dpr};
}
async function probe(s,scope){return s.page.evaluate(scope=>window.__cvR19Controls?.[scope],scope);}
async function wait(s,scope,key,value){await s.page.waitForFunction(({scope,key,value})=>{let p=window.__cvR19Controls?.[scope];return p&&(key===null||p.flags[key]===value);},{scope,key,value},{timeout:90000});return probe(s,scope);}
async function click(s,scope,id,touch=false){await s.page.waitForFunction(({scope,id})=>window.__cvR19Controls?.[scope]?.controls?.[id]?.visible,{scope,id},{timeout:15000});let p=await probe(s,scope),c=p?.controls[id];invariant(c?.visible,scope+'/'+id+' missing');invariant(c.width>=43.5&&c.height>=43.5,scope+'/'+id+' below 44px');invariant(c.x>=0&&c.y>=0&&c.x+c.width<=s.width+.5&&c.y+c.height<=s.height+.5,scope+'/'+id+' offscreen '+JSON.stringify(c));let element=await s.page.evaluate(({x,y})=>document.elementFromPoint(x,y)?.id,{x:c.center_x,y:c.center_y});invariant(element==='canvas','DOM intercept '+scope+'/'+id+' '+element);if(touch)await s.page.touchscreen.tap(c.center_x,c.center_y);else await s.page.mouse.click(c.center_x,c.center_y);await s.page.waitForTimeout(70);}
async function enterPreparation(s,touch=false){await wait(s,'main_menu',null,null);await click(s,'main_menu','meta',touch);await wait(s,'main_menu','side_panel_visible',true);await wait(s,'main_menu','panel_id','meta');await click(s,'main_menu','build_preparation',touch);await wait(s,'build_preparation','visible',true);}
function geometry(p,s){
 const cs=Object.entries(p.controls).filter(([,c])=>c.visible);
 for(const [id,c] of cs){invariant(c.width>=43.5&&c.height>=43.5,id+' size');invariant(c.x>=-0.5&&c.y>=-0.5&&c.x+c.width<=s.width+.5&&c.y+c.height<=s.height+.5,id+' bounds');}
 for(let a=0;a<cs.length;a++)for(let b=a+1;b<cs.length;b++){let x=cs[a][1],y=cs[b][1];invariant(!(x.x<y.x+y.width&&x.x+x.width>y.x&&x.y<y.y+y.height&&x.y+x.height>y.y),'overlap '+cs[a][0]+'/'+cs[b][0]);}
 invariant(p.flags.detail_visible_lines>=p.flags.detail_lines,'clipped benefit/cost/mode text '+JSON.stringify(p.flags));
}
async function shot(s,index,label,kind,state,provenance){
 await s.page.waitForTimeout(120);
 const file=`review-set/${String(index).padStart(2,'0')}-${label}.png`;
 await s.page.screenshot({path:path.join(root,file)});
 const renderer=await s.page.evaluate(()=>{const gl=document.querySelector('#canvas').getContext('webgl2'),ext=gl.getExtension('WEBGL_debug_renderer_info');return gl.getParameter(ext.UNMASKED_RENDERER_WEBGL);});
 invariant(renderer.includes('SwiftShader'),'hardware renderer prohibited '+renderer);
 const row={...state,version:'0.32.0-content-r3',captured_utc:new Date().toISOString(),renderer,file,sha256:sha(await fs.readFile(path.join(root,file))),dimensions:[s.width*s.dpr,s.height*s.dpr],width:s.width,height:s.height,dpr:s.dpr,postprocessed:false,errors:[...s.errors],known_uid_warnings:[...s.warnings],external_requests:[...s.external],provenance,...builds[kind]};
 await write('tests/captures/'+path.basename(file,'.png')+'.json',row);
 const receipts=await fs.readdir(path.join(root,'tests/captures'));
 samples=await Promise.all(receipts.filter(f=>f.endsWith('.json')).sort().map(f=>read('tests/captures/'+f)));await write('tests/samples.json',samples);
 invariant(!s.errors.length&&!s.external.length,'runtime diagnostic '+JSON.stringify(s.errors));console.log(file);
}
async function controls(){
 const records=[];
 try{for(const [width,height] of [[844,390],[390,844],[320,568],[1366,600]])for(const scale of [1,2]){
  const s=await surface(width,height,width===1366?2:3),touch=width<500;
  await s.page.goto(url+'/release/index.html?cv_r19_test=1',{timeout:90000});await wait(s,'main_menu',null,null);
  if(scale===2){await click(s,'main_menu','settings',touch);await wait(s,'main_menu','panel_id','settings');let slider=(await probe(s,'main_menu')).controls.ui_scale;invariant(slider?.visible,'scale slider not reachable');if(slider.y<0||slider.y+slider.height>s.height-40){const panel=(await probe(s,'main_menu')).controls.side_panel;await s.page.mouse.move(panel.center_x,panel.center_y);await s.page.mouse.wheel(0,1400);await s.page.waitForTimeout(100);await s.page.setViewportSize({width:width+1,height});await s.page.waitForTimeout(180);await s.page.setViewportSize({width,height});await s.page.waitForTimeout(250);slider=(await probe(s,'main_menu')).controls.ui_scale;}invariant(slider.y>=0&&slider.y+slider.height<=height,'max scale slider still clipped');await s.page.mouse.click(slider.x+slider.width-5,slider.center_y);await wait(s,'main_menu','ui_scale_index',2);await click(s,'main_menu','side_close',touch);}
  await enterPreparation(s,touch);const pages=[];
  for(let tab=0;tab<4;tab++){
   await click(s,'build_preparation','tab_'+tab,touch);await wait(s,'build_preparation','tab',tab);
   for(let index=0;index<(tab===0?3:5);index++){
    const p=await wait(s,'build_preparation','index',index);geometry(p,s);pages.push(p);
    if(index+1<(tab===0?3:5))await click(s,'build_preparation','next',touch);
   }
   await click(s,'build_preparation','previous',touch);await wait(s,'build_preparation','index',tab===0?1:3);
  }
  // Actual free unlock -> equip -> roster change, clear, close, reopen, launch.
  await click(s,'build_preparation','tab_2',touch);await wait(s,'build_preparation','index',0);
  await click(s,'build_preparation','action',touch);await wait(s,'build_preparation','vouchers',0);
  await click(s,'build_preparation','action',touch);let equipped=await wait(s,'build_preparation','equipped','bond_harmony');invariant(JSON.stringify(equipped.flags.roster)===JSON.stringify(['rift_captain','orbit_guard','echo_singer']),'effective roster mismatch');
  await click(s,'build_preparation','clear',touch);await wait(s,'build_preparation','equipped','');
  await click(s,'build_preparation','close',touch);await enterPreparation(s,touch);await click(s,'build_preparation','launch',touch);await wait(s,'hud','paused',false);
  const hud=await probe(s,'hud');const gate=hud.controls.audio_prompt; // official gate may be published under a different key; use read-only start rect below.
  if(gate?.visible)await click(s,'hud','audio_prompt',touch);
  records.push({width,height,scale,input:touch?'touch':'mouse',pages,normal_unlock_equip_clear_close_reopen_launch:true,errors:s.errors,warnings:s.warnings,external_requests:s.external,...builds.release});
  invariant(!s.errors.length&&!s.external.length,'controls runtime errors '+JSON.stringify(s.errors));await s.context.close();console.log(`controls ${width}x${height} scale${scale} ${pages.length} pages`);
 }}finally{await write('tests/controls.json',records);}
}
async function preparationImages(){
 const s=await surface(844,390);await s.page.goto(url+'/release/index.html?cv_r19_test=1',{timeout:90000});await enterPreparation(s);await click(s,'build_preparation','action');await wait(s,'build_preparation','team','assault');
 await shot(s,1,'formal-assault','release',await probe(s,'build_preparation'),'official release main menu -> echoes -> preparation, real pointer');
 await click(s,'build_preparation','tab_1');await wait(s,'build_preparation','tab',1);
 await shot(s,2,'crew-trade','release',await probe(s,'build_preparation'),'official first crew node preview; resource and trade text');
 await click(s,'build_preparation','tab_2');await click(s,'build_preparation','action');await click(s,'build_preparation','action');await wait(s,'build_preparation','equipped','bond_harmony');
 await shot(s,3,'harmony-equipped','release',await probe(s,'build_preparation'),'initial free choice then actual exclusive equip; final three portraits update');await s.context.close();
 const d=await surface(1366,600,2);await d.page.goto(url+'/release/index.html?cv_r19_test=1',{timeout:90000});await enterPreparation(d);await click(d,'build_preparation','tab_3');for(let i=0;i<4;i++)await click(d,'build_preparation','next');await wait(d,'build_preparation','index',4);
 await shot(d,4,'fifth-specialization-short-desktop','release',await probe(d,'build_preparation'),'official short desktop fifth horizontal node with real next clicks');await d.context.close();
}
async function battle(team){
 const s=await surface(844,390);await s.page.goto(url+`/review/index.html?cv_r19_test=1&team=${team}`,{timeout:90000});
 await s.page.waitForFunction(()=>window.__cvContentR3Gate,{timeout:90000});let g=await s.page.evaluate(()=>window.__cvContentR3Gate);await s.page.mouse.click(g.rect[0]+g.rect[2]/2,g.rect[1]+g.rect[3]/2);
 let index=0;const expected=team==='assault'?['front-active','pincer-active','guard-warning','guard-impact','guard-recovery','victory']:['front-active','pincer-active','victory'];const numbers=team==='assault'?[5,7,9,10,11,12]:[6,8,13];
 for(const label of expected){
  const deadline=Date.now()+420000;let ready=false;
  while(Date.now()<deadline){invariant(!s.errors.length,'runtime diagnostic '+JSON.stringify(s.errors));ready=await s.page.evaluate(i=>!!window.__cvContentR3Failure||window.__cvContentR3Sample?.sample===i,index);if(ready)break;await s.page.waitForTimeout(150);}
  invariant(ready,'natural battle checkpoint timeout '+label);
  const fail=await s.page.evaluate(()=>window.__cvContentR3Failure);invariant(!fail,JSON.stringify(fail));
  let state=await s.page.evaluate(()=>window.__cvContentR3Sample);invariant(state.label===label,'missing chronological '+label+' got '+state.label);invariant(!state.audio_gate_visible,'start gate remained over battle');
  if(team==='assault'&&label==='victory'){await s.page.mouse.move(315,270);await s.page.mouse.wheel(0,420);await s.page.waitForTimeout(150);state.normal_summary_scroll='real pointer wheel down inside victory summary to expose equipped tactic and measured benefit';}
  if(team==='escort'&&label==='victory'){await s.page.setViewportSize({width:390,height:844});s.width=390;s.height=844;await s.page.waitForTimeout(350);}
  await shot(s,numbers[index],team+'-'+label,'review',state,state.provenance);
  if(label!=='victory')await s.page.evaluate(()=>window.__cvContentR3Next=true);index++;
 }
 await s.context.close();
}
async function milestone(){
 const s=await surface(844,390);await s.page.goto(url+'/review/index.html?cv_r19_test=1&scenario=milestone&max_ui=1',{timeout:90000});
 await s.page.waitForFunction(()=>window.__cvContentR3Gate,{timeout:90000});let g=await s.page.evaluate(()=>window.__cvContentR3Gate);await s.page.mouse.click(g.rect[0]+g.rect[2]/2,g.rect[1]+g.rect[3]/2);
 await s.page.waitForFunction(()=>window.__cvContentR3Milestone,{timeout:90000});let state=await s.page.evaluate(()=>window.__cvContentR3Milestone);invariant(state.settlements===4&&state.vouchers===1&&state.captain_dead,'fourth true terminal missing');
 invariant(state.ui_scale_index===2&&state.restart_text==='免費整備','max-scale short footer not active');const buttons=Object.entries(state.footer_buttons);for(const [id,r]of buttons)invariant(r[0]>=0&&r[1]>=0&&r[2]>=44&&r[3]>=44&&r[0]+r[2]<=844.5&&r[1]+r[3]<=390.5,'fourth footer out of viewport '+id+' '+JSON.stringify(r));for(let a=0;a<buttons.length;a++)for(let b=a+1;b<buttons.length;b++){let x=buttons[a][1],y=buttons[b][1];invariant(!(x[0]<y[0]+y[2]&&x[0]+x[2]>y[0]&&x[1]<y[1]+y[3]&&x[1]+x[3]>y[1]),'fourth footer buttons overlap');}
 await shot(s,14,'fourth-real-defeat-fixture','review',state,state.provenance);const r=state.menu_rect;await s.page.mouse.click(r[0]+r[2]/2,r[1]+r[3]/2);await wait(s,'build_preparation','vouchers',1);await wait(s,'build_preparation','visible',true);await click(s,'build_preparation','tab_3');
 let p=await probe(s,'build_preparation');invariant(p.flags.vouchers===1&&p.flags.equipped==='spec_escort','fifth choice not available');
 await shot(s,15,'fifth-run-free-second-choice','review',p,'controlled four-defeat fixture -> actual pointer return -> normal fifth-run free choice; no settlement counter injection');await s.context.close();
}
(async()=>{
 await fs.mkdir(path.join(root,'review-set'),{recursive:true});builds=await read('tests/builds.json');try{samples=await read('tests/samples.json');}catch{}
 browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--mute-audio','--use-angle=swiftshader','--enable-unsafe-swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 try{if(mode==='controls')await controls();else if(mode==='preparation')await preparationImages();else if(['assault','escort'].includes(mode))await battle(mode);else if(mode==='milestone')await milestone();else throw Error('unknown capture mode');}
 finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
