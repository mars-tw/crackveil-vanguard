// Real silent Chromium/SwiftShader input and untouched Godot screenshots.
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const {chromium}=require(path.join(process.env.UI_CAPTURE_PLAYWRIGHT,'playwright-core'));
const root=path.resolve(process.env.CONTENT_EVIDENCE_DIR||'docs/content/r4');
const expectedRoot=path.resolve(__dirname,'../docs/content/r4');
const url=process.env.CONTENT_BUILD_URL||'http://127.0.0.1:8153';
const mode=process.argv[2]||'controls',sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const invariant=(value,message)=>{if(!value)throw Error(message);};
invariant(root.toLowerCase()===expectedRoot.toLowerCase(),'evidence root must be exact R4 folder');
invariant(['controls','preparation','milestone','assault','escort'].includes(mode),'unlisted capture mode');
invariant(['127.0.0.1','localhost'].includes(new URL(url).hostname),'local build URL required');
const inputPins={'tests/historical.json':'0ef9d86d9b974252ebcf1aa5e94c4ff07893ab21f99a2be06ddc781e36c376e2','tests/initial-files.json':'b3ec79620d18a5ba874939195b77cf6074cc3a19a0b7ea21fee045ddc0be4bce','tests/default-profile-before.json':'b569c4ebb24b3bc49a0862663c6a729bd6b127b22d29b53bad7173829494f433'};
function evidencePath(file){invariant(typeof file==='string'&&!path.isAbsolute(file),'relative R4 output required');const p=path.resolve(root,file);invariant(p.toLowerCase().startsWith(root.toLowerCase()+path.sep),'evidence traversal rejected');return p;}
async function writable(file){const p=evidencePath(file);invariant(!Object.keys(inputPins).some(k=>evidencePath(k).toLowerCase()===p.toLowerCase()),'immutable manifest write rejected');let ancestor=p;while(true){try{const real=await fs.realpath(ancestor);invariant(real.toLowerCase()===root.toLowerCase()||real.toLowerCase().startsWith(root.toLowerCase()+path.sep),'junction/symlink output escape');break;}catch(e){if(e.code!=='ENOENT')throw e;ancestor=path.dirname(ancestor);}}return p;}
const read=async file=>JSON.parse(await fs.readFile(evidencePath(file),'utf8'));
const write=async(file,value)=>{const p=await writable(file);await fs.mkdir(path.dirname(p),{recursive:true});await fs.writeFile(p,JSON.stringify(value,null,2));};
async function protection(){
 for(const [file,digest]of Object.entries(inputPins))invariant(sha(await fs.readFile(evidencePath(file)))===digest,'immutable manifest changed '+file);
 const history=(await read('tests/historical.json')).files,initial=(await read('tests/initial-files.json')).files,expected={...history,...Object.fromEntries(Object.entries(initial).map(([p,r])=>[p,r.sha256]))},project=path.resolve(__dirname,'..');
 for(const r of await read('tests/external-changes.json')){invariant(['docs/CONTENT_R4_BRIEF.md','docs/專案導航.md'].includes(r.path)&&r.owner==='primary supervisor'&&r.authorization&&r.before_sha256===initial[r.path].sha256,'invalid foreign exception');expected[r.path]=r.after_sha256;}
 const failures=[];for(const [file,digest]of Object.entries(expected)){try{if(sha(await fs.readFile(path.resolve(project,file)))!==digest)failures.push(file);}catch{failures.push(file);}}
 return {status:failures.length?'BLOCKED':'VERIFIED',failures,history_files:Object.keys(history).length,initial_files:Object.keys(initial).length,manifest_pins:inputPins,captured_utc:new Date().toISOString()};
}
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
 if(p.flags.detail_lines!==undefined)invariant(p.flags.detail_visible_lines>=p.flags.detail_lines,'clipped benefit/cost/mode text '+JSON.stringify(p.flags));
}
async function shot(s,index,label,kind,state,provenance){
 await s.page.waitForTimeout(120);
 const file=`review-set/${String(index).padStart(2,'0')}-${label}.png`;
 await s.page.screenshot({path:await writable(file)});
 const renderer=await s.page.evaluate(()=>{const gl=document.querySelector('#canvas').getContext('webgl2'),ext=gl.getExtension('WEBGL_debug_renderer_info');return gl.getParameter(ext.UNMASKED_RENDERER_WEBGL);});
 invariant(renderer.includes('SwiftShader'),'hardware renderer prohibited '+renderer);
 const row={...state,version:'0.33.0-content-r4',captured_utc:new Date().toISOString(),capture_driver_sha256:process.env.CONTENT_DRIVER_SHA256,renderer,file,sha256:sha(await fs.readFile(path.join(root,file))),dimensions:[s.width*s.dpr,s.height*s.dpr],width:s.width,height:s.height,dpr:s.dpr,postprocessed:false,errors:[...s.errors],known_uid_warnings:[...s.warnings],external_requests:[...s.external],provenance,...builds[kind]};
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
    if(index+1<(tab===0?3:5))await click(s,'build_preparation','node_'+(index+1),touch);
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
  await wait(s,'battle_journal','visible',false);await click(s,'battle_journal','open',touch);await wait(s,'battle_journal','visible',true);geometry(await probe(s,'battle_journal'),s);await click(s,'battle_journal','next',touch);await click(s,'battle_journal','previous',touch);await click(s,'battle_journal','close',touch);await wait(s,'hud','paused',false);
  records.push({width,height,scale,input:touch?'touch':'mouse',pages,normal_unlock_equip_clear_close_reopen_launch:true,errors:s.errors,warnings:s.warnings,external_requests:s.external,...builds.release});
  invariant(!s.errors.length&&!s.external.length,'controls runtime errors '+JSON.stringify(s.errors));await s.context.close();console.log(`controls ${width}x${height} scale${scale} ${pages.length} pages`);
 }}finally{await write('tests/controls.json',records);}
}
async function preparationImages(){
 const p=await surface(320,568);await p.page.goto(url+'/release/index.html?cv_r19_test=1',{timeout:90000});await wait(p,'main_menu',null,null);
 await click(p,'main_menu','settings',true);await wait(p,'main_menu','panel_id','settings');let slider=(await probe(p,'main_menu')).controls.ui_scale;
 if(slider.y<0||slider.y+slider.height>p.height-40){const panel=(await probe(p,'main_menu')).controls.side_panel;await p.page.mouse.move(panel.center_x,panel.center_y);await p.page.mouse.wheel(0,1400);await p.page.waitForTimeout(250);await p.page.setViewportSize({width:321,height:568});await p.page.waitForTimeout(180);await p.page.setViewportSize({width:320,height:568});await p.page.waitForTimeout(250);slider=(await probe(p,'main_menu')).controls.ui_scale;}
 await p.page.mouse.click(slider.x+slider.width-5,slider.center_y);await wait(p,'main_menu','ui_scale_index',2);await click(p,'main_menu','side_close',true);
 await enterPreparation(p,true);await click(p,'build_preparation','tab_1',true);await click(p,'build_preparation','node_3',true);
 await shot(p,1,'crew-overview-max-portrait','release',await probe(p,'build_preparation'),'official release 320x568 maximum font setting; five choices and actual outgoing/incoming preview, real touch');await p.context.close();
 const s=await surface(844,390);await s.page.goto(url+'/release/index.html?cv_r19_test=1',{timeout:90000});await enterPreparation(s);await click(s,'build_preparation','action');await wait(s,'build_preparation','team','assault');
 await click(s,'build_preparation','tab_2');await click(s,'build_preparation','action');await click(s,'build_preparation','action');await wait(s,'build_preparation','equipped','bond_harmony');
 await click(s,'build_preparation','node_1');await wait(s,'build_preparation','index',1);
 await shot(s,2,'bond-equipped-versus-preview','release',await probe(s,'build_preparation'),'initial free choice then actual equip; current bond replaced by preview, shared slot and both actual rosters');await s.context.close();
 const d=await surface(1366,600,2);await d.page.goto(url+'/release/index.html?cv_r19_test=1',{timeout:90000});await enterPreparation(d);await click(d,'build_preparation','tab_3');for(let i=0;i<4;i++)await click(d,'build_preparation','next');await wait(d,'build_preparation','index',4);
 await shot(d,3,'specialization-short-desktop','release',await probe(d,'build_preparation'),'official short desktop five simultaneous horizontal nodes, fifth node benefit and cost');await d.context.close();
}
async function saveMaximumSetting(s){
 await s.page.goto(url+'/release/index.html?cv_r19_test=1',{timeout:90000});await wait(s,'main_menu',null,null);
 await click(s,'main_menu','settings');await wait(s,'main_menu','panel_id','settings');let slider=(await probe(s,'main_menu')).controls.ui_scale;
 if(slider.y<0||slider.y+slider.height>s.height-40){const panel=(await probe(s,'main_menu')).controls.side_panel;await s.page.mouse.move(panel.center_x,panel.center_y);await s.page.mouse.wheel(0,1400);await s.page.waitForTimeout(200);await s.page.setViewportSize({width:s.width+1,height:s.height});await s.page.waitForTimeout(150);await s.page.setViewportSize({width:s.width,height:s.height});await s.page.waitForTimeout(200);slider=(await probe(s,'main_menu')).controls.ui_scale;}
 await s.page.mouse.click(slider.x+slider.width-5,slider.center_y);await wait(s,'main_menu','ui_scale_index',2);await click(s,'main_menu','side_close');await s.page.waitForTimeout(1600);
 await s.page.reload({timeout:90000});const saved=await wait(s,'main_menu','ui_scale_index',2);
 return {saved_utc:new Date().toISOString(),actual_reload_verified:true,main_menu:saved,...builds.release};
}
async function resultTraversal(s,settingProof){
 await s.page.setViewportSize({width:320,height:568});s.width=320;s.height=568;await s.page.waitForTimeout(300);
 const initial=await probe(s,'result'),expected=initial.flags.rows.filter(r=>r.id!=='unattributed').map(r=>r.id),records=[],visited={};
 invariant(expected.length===9,'natural result had '+expected.length+' heroes; retain actual outcome, no recruited fixture substitution');
 for(const tab of [0,1,2]){
  await click(s,'result','tab_'+tab,true);await wait(s,'result','tab',tab);const ids=[];const pages=(await probe(s,'result')).flags.pages;
  for(let page=0;page<pages;page++){
   const p=await wait(s,'result','page',page);geometry(p,s);records.push(p);
   if(tab<2)for(const text of p.flags.cards){if(!text)continue;const name=text.split('\n')[0],row=p.flags.rows.find(r=>r.name===name);invariant(row,'actual card name not in ledger '+name);if(row.id!=='unattributed')ids.push(row.id);}
   if(page+1<pages)await click(s,'result','next',true);
  }
  await click(s,'result','previous',true);await wait(s,'result','page',Math.max(0,pages-2));
  if(tab<2)invariant(JSON.stringify(ids)===JSON.stringify(expected),'real touch pages omitted/duplicated hero IDs');visited[tab]=ids;
 }
 const beforeFooter=await probe(s,'result');geometry(beforeFooter,s);await click(s,'result','menu',true);const preparation=await wait(s,'build_preparation','visible',true);
 invariant(preparation.flags.ui_scale_index===2,'same natural run lost its live maximum font setting');settingProof.final_live_ui_scale_index=preparation.flags.ui_scale_index;
 await write('tests/result-controls.json',{status:'VERIFIED',width:320,height:568,input:'touch',scale:2,setting_saved_reload:settingProof,expected_ids:expected,visited_ids:visited,pages:records,footer_before:beforeFooter,preparation_after:preparation,controlled_hero_injection:false,provenance:'same uninterrupted natural escort victory -> portrait screenshot -> 320x568 maximum-font actual touch pages -> fixed preparation footer',capture_driver_sha256:process.env.CONTENT_DRIVER_SHA256,...builds.review});
}
async function battle(team){
 const s=await surface(844,390);let settingProof=null;if(team==='escort')settingProof=await saveMaximumSetting(s);await s.page.goto(url+`/review/index.html?cv_r19_test=1&team=${team}`,{timeout:90000});
 await s.page.waitForFunction(()=>window.__cvContentR4Gate,{timeout:90000});let g=await s.page.evaluate(()=>window.__cvContentR4Gate);await s.page.mouse.click(g.rect[0]+g.rect[2]/2,g.rect[1]+g.rect[3]/2);
 if(team==='escort'){
  // Review's two-frame menu is already outside the tree. Use visible official
  // settings controls, then the same run's final preparation live setting.
  await s.page.waitForFunction(()=>window.__cvR19Controls?.hud?.flags.elapsed>0,null,{timeout:90000});
  await click(s,'hud','pause');await wait(s,'hud','paused',true);await click(s,'hud','pause_settings_tab');
  let hud=await probe(s,'hud'),slider=hud.controls.pause_ui_scale;invariant(slider?.visible,'official pause scale control missing');
  if(slider.y<0||slider.y+slider.height>s.height-60){const panel=hud.controls.pause_overlay;await s.page.mouse.move(panel.center_x,panel.center_y);await s.page.mouse.wheel(0,1400);await s.page.waitForTimeout(200);await s.page.setViewportSize({width:s.width+1,height:s.height});await s.page.waitForTimeout(150);await s.page.setViewportSize({width:s.width,height:s.height});await s.page.waitForTimeout(200);slider=(await probe(s,'hud')).controls.pause_ui_scale;}
  invariant(slider.x>=0&&slider.y>=0&&slider.x+slider.width<=s.width&&slider.y+slider.height<=s.height,'official pause scale endpoint outside viewport');
  await s.page.mouse.click(slider.x+slider.width-5,slider.center_y);await s.page.waitForTimeout(180);
  const file='tests/settings-review-max.png';await s.page.screenshot({path:await writable(file)});
  settingProof.review_live_ui={file,sha256:sha(await fs.readFile(evidencePath(file))),captured_utc:new Date().toISOString(),endpoint_rect:slider,paused:await probe(s,'hud'),provenance:'official gate center click, normal pause/settings and maximum endpoint pointer; original screenshot shows live setting label; no setter/storage/HTML/PCK substitution',...builds.review};
  await write('tests/settings-review-max.json',settingProof);await click(s,'hud','pause_resume');await wait(s,'hud','paused',false);
 }
 let index=0;const expected=team==='assault'?['front-active','pincer-active','artillery-active','guard-warning','guard-impact','guard-recovery','victory']:['front-active','pincer-active','artillery-active','victory'];const numbers=team==='assault'?[4,6,8,9,10,11,12]:[5,7,0,13];
 for(const label of expected){
  const deadline=Date.now()+420000;let ready=false;
  while(Date.now()<deadline){invariant(!s.errors.length,'runtime diagnostic '+JSON.stringify(s.errors));ready=await s.page.evaluate(i=>!!window.__cvContentR4Failure||window.__cvContentR4Sample?.sample===i,index);if(ready)break;await s.page.waitForTimeout(150);}
  invariant(ready,'natural battle checkpoint timeout '+label);
  const fail=await s.page.evaluate(()=>window.__cvContentR4Failure);invariant(!fail,JSON.stringify(fail));
  let state=await s.page.evaluate(()=>window.__cvContentR4Sample);invariant(state.label===label,'missing chronological '+label+' got '+state.label);invariant(!state.audio_gate_visible,'start gate remained over battle');
  if(label==='victory'){await click(s,'result','tab_1');state.result=await probe(s,'result');}
  if(team==='escort'&&label==='victory'){await s.page.setViewportSize({width:390,height:844});s.width=390;s.height=844;await s.page.waitForTimeout(350);}
  if(numbers[index])await shot(s,numbers[index],team+'-'+label,'review',state,state.provenance);
  if(team==='escort'&&label==='victory')await resultTraversal(s,settingProof);
  if(label!=='victory')await s.page.evaluate(()=>window.__cvContentR4Next=true);index++;
 }
 await s.context.close();
}
async function milestone(){
 const s=await surface(844,390);await s.page.goto(url+'/review/index.html?cv_r19_test=1&scenario=milestone&max_ui=1',{timeout:90000});
 await s.page.waitForFunction(()=>window.__cvContentR4Gate,{timeout:90000});let g=await s.page.evaluate(()=>window.__cvContentR4Gate);await s.page.mouse.click(g.rect[0]+g.rect[2]/2,g.rect[1]+g.rect[3]/2);
 await s.page.waitForFunction(()=>window.__cvContentR4Milestone,{timeout:90000});let state=await s.page.evaluate(()=>window.__cvContentR4Milestone);state.progress_history=await s.page.evaluate(()=>window.__cvContentR4ProgressHistory);invariant(state.settlements===4&&state.vouchers===1&&state.captain_dead,'fourth true terminal missing');
 invariant(state.progress_history.length===4&&state.progress_history.every((r,i)=>r.settlements===i+1&&(i===3?r.vouchers===1:r.text.includes((i+1)+'/4'))),'visible one-time choice progress missing');
 invariant(state.ui_scale_index===2&&state.restart_text==='免費整備','max-scale short footer not active');const buttons=Object.entries(state.footer_buttons);for(const [id,r]of buttons)invariant(r[0]>=0&&r[1]>=0&&r[2]>=44&&r[3]>=44&&r[0]+r[2]<=844.5&&r[1]+r[3]<=390.5,'fourth footer out of viewport '+id+' '+JSON.stringify(r));for(let a=0;a<buttons.length;a++)for(let b=a+1;b<buttons.length;b++){let x=buttons[a][1],y=buttons[b][1];invariant(!(x[0]<y[0]+y[2]&&x[0]+x[2]>y[0]&&x[1]<y[1]+y[3]&&x[1]+x[3]>y[1]),'fourth footer buttons overlap');}
 for(const tab of [1,2,0]){await click(s,'result','tab_'+tab);geometry(await probe(s,'result'),s);await click(s,'result','next');await click(s,'result','previous');}
 await shot(s,14,'fourth-real-defeat-fixture','review',state,state.provenance);const r=state.menu_rect;await s.page.mouse.click(r[0]+r[2]/2,r[1]+r[3]/2);await wait(s,'build_preparation','vouchers',1);await wait(s,'build_preparation','visible',true);await click(s,'build_preparation','tab_3');
 let p=await probe(s,'build_preparation');invariant(p.flags.vouchers===1&&p.flags.equipped==='spec_escort','fifth choice not available');
 await shot(s,15,'fifth-run-free-second-choice','review',p,'controlled four-defeat fixture -> actual pointer return -> normal fifth-run free choice; no settlement counter injection');await s.context.close();
}
(async()=>{
 const before=await protection();await write('tests/boundary-browser-'+mode+'-before.json',before);invariant(!before.failures.length,'protected files changed before browser');
 await fs.mkdir(await writable('review-set'),{recursive:true});builds=await read('tests/builds.json');try{samples=await read('tests/samples.json');}catch{}
 browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--mute-audio','--use-angle=swiftshader','--enable-unsafe-swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 try{if(mode==='controls')await controls();else if(mode==='preparation')await preparationImages();else if(['assault','escort'].includes(mode))await battle(mode);else if(mode==='milestone')await milestone();else throw Error('unknown capture mode');}
 finally{await browser.close();const after=await protection();await write('tests/boundary-browser-'+mode+'-after.json',after);invariant(!after.failures.length,'protected files changed after browser');}
})().catch(e=>{console.error(e);process.exitCode=1;});
