// R5 official Web UI geometry audit. Every write is pinned to docs/content/r5.
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const {chromium}=require(path.join(process.env.UI_CAPTURE_PLAYWRIGHT,'playwright-core'));
const project=path.resolve(__dirname,'..'),root=path.resolve(process.env.CONTENT_EVIDENCE_DIR||'docs/content/r5');
const expected=path.resolve(project,'docs/content/r5'),url=process.env.CONTENT_BUILD_URL||'http://127.0.0.1:8155';
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),invariant=(x,m)=>{if(!x)throw Error(m);};
invariant(root.toLowerCase()===expected.toLowerCase(),'R5 evidence root must be exact');
invariant(['127.0.0.1','localhost'].includes(new URL(url).hostname),'local build URL required');
const evidence=file=>{invariant(typeof file==='string'&&!path.isAbsolute(file),'relative R5 path required');const full=path.resolve(root,file);invariant(full.toLowerCase().startsWith(root.toLowerCase()+path.sep),'R5 output traversal');return full;};
async function writable(file){const full=evidence(file);let parent=full;while(true){try{const resolved=await fs.realpath(parent);invariant(resolved.toLowerCase()===root.toLowerCase()||resolved.toLowerCase().startsWith(root.toLowerCase()+path.sep),'R5 output junction escape');break;}catch(e){if(e.code!=='ENOENT')throw e;parent=path.dirname(parent);}}return full;}
const read=async file=>JSON.parse(await fs.readFile(evidence(file),'utf8'));
const write=async(file,value)=>{const full=await writable(file);await fs.mkdir(path.dirname(full),{recursive:true});await fs.writeFile(full,JSON.stringify(value,null,2)+'\n','utf8');};
const rect=c=>[c.x,c.y,c.width,c.height];
function overlaps(a,b){return a[0]<b[0]+b[2]&&a[0]+a[2]>b[0]&&a[1]<b[1]+b[3]&&a[1]+a[3]>b[1];}
function geometry(c,width,height){invariant(c&&c.visible,'visible control missing');invariant(c.width>=44&&c.height>=44,'touch target below44');invariant(c.x>=0&&c.y>=0&&c.x+c.width<=width+0.5&&c.y+c.height<=height+0.5,'control outside viewport '+JSON.stringify(c));}
async function surface(browser,width,height,dpr){
 const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:dpr,hasTouch:width!==1366,isMobile:width!==1366,userAgent:width!==1366?'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Chrome/140.0.0.0 Mobile Safari/537.36':undefined});
 const page=await context.newPage(),errors=[],warnings=[],external=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()!=='error')return;const t=m.text();if(/^WARNING: 'res:\/\/[^']+': In external resource #\d+, invalid UID: 'uid:\/\/[^']+' - using text path instead: 'res:\/\/[^']+'\.$/.test(t))warnings.push(t);else errors.push(t);});
 page.on('console',m=>{if(m.type()==='error'&&!/^WARNING: 'res:\/\/[^']+': In external resource #\d+, invalid UID: 'uid:\/\/[^']+' - using text path instead: 'res:\/\/[^']+'\.$/.test(m.text()))errors.push(m.text());});
 page.on('request',r=>{if(new URL(r.url()).origin!==url)external.push(r.url());});
 page.on('requestfailed',r=>errors.push(r.url()+' '+r.failure()?.errorText));
 page.on('response',r=>{if(r.status()>=400)errors.push(r.status()+' '+r.url());});
 await context.route('**/favicon.ico',r=>r.fulfill({status:204,body:''}));
 return {context,page,errors,warnings,external,width,height,dpr};
}
async function probe(s){return s.page.evaluate(()=>window.__cvR19Controls);}
async function wait(s,scope,key,value,timeout=90000){await s.page.waitForFunction(({scope,key,value})=>{const p=window.__cvR19Controls?.[scope];return p&&(key===null||p.flags[key]===value);},{scope,key,value},{timeout});return (await probe(s))[scope];}
async function click(s,scope,id){await s.page.waitForFunction(({scope,id})=>window.__cvR19Controls?.[scope]?.controls?.[id]?.visible,{scope,id},{timeout:15000});const p=(await probe(s))[scope],c=p.controls[id];geometry(c,s.width,s.height);const hit=await s.page.evaluate(({x,y})=>document.elementFromPoint(x,y)?.id,{x:c.center_x,y:c.center_y});invariant(hit==='canvas','pointer intercepted '+scope+'/'+id);await s.page.mouse.click(c.center_x,c.center_y);await s.page.waitForTimeout(90);}
async function exposeScale(s){let h=(await probe(s)).hud,c=h.controls.pause_ui_scale;if(c.y<0||c.y+c.height>s.height-60){const panel=h.controls.pause_overlay;await s.page.mouse.move(panel.center_x,panel.center_y);await s.page.mouse.wheel(0,1400);await s.page.waitForTimeout(250);await s.page.setViewportSize({width:s.width+1,height:s.height});await s.page.waitForTimeout(150);await s.page.setViewportSize({width:s.width,height:s.height});await s.page.waitForTimeout(250);h=(await probe(s)).hud;c=h.controls.pause_ui_scale;}invariant(c.visible&&c.y>=0&&c.y+c.height<=s.height-40,'pause scale setting is not visible after official settings scroll');return c;}
async function stableSlider(s){let previous='',stable=0,last=null;const deadline=Date.now()+10000;while(stable<3&&Date.now()<deadline){await s.page.waitForTimeout(150);const p=await probe(s),hud=p.hud,c=hud.controls.pause_ui_scale;geometry(c,s.width,s.height);const signature=JSON.stringify([c.x,c.y,c.width,c.height]);stable=signature===previous?stable+1:0;previous=signature;last={hud,c};}invariant(stable===3,'pause settings layout did not settle');return last;}
async function verifySources(){const baseline=await read('tests/source-before.json');invariant(baseline.status==='FROZEN'&&baseline.fileCount===Object.keys(baseline.files).length,'bad R5 source baseline');const failures=[];for(const [rel,entry]of Object.entries(baseline.files)){try{if(sha(await fs.readFile(path.resolve(project,rel)))!==entry.sha256)failures.push(rel);}catch{failures.push(rel);}}return {status:failures.length?'BLOCKED':'VERIFIED',failures,fileCount:baseline.fileCount};}
async function capture(){
 const before=await verifySources();invariant(before.status==='VERIFIED','R5 source changed before UI run '+before.failures.slice(0,5).join(','));
 const builds=await read('tests/builds.json');invariant(builds.review?.pack_sha256&&builds.review?.source_manifest_sha256,'R5 review build evidence missing');
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--mute-audio','--use-angle=swiftshader','--enable-unsafe-swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 const cases=[];
 try{
  for(const [width,height,dpr,label] of [[320,568,3,'320x568'],[844,390,3,'844x390'],[1366,600,2,'1366x600']]){
   const s=await surface(browser,width,height,dpr);
   try{
    await s.page.goto(url+'/release/index.html?r5_pause_layout=1',{timeout:90000});
    await wait(s,'main_menu',null,null);
    await click(s,'main_menu','start');
    if((await probe(s)).hud?.controls?.audio_prompt?.visible)await click(s,'hud','audio_prompt');
    await s.page.waitForFunction(()=>{const p=window.__cvR19Controls?.hud;return p&&p.flags.elapsed>0&&p.flags.paused===false;},null,{timeout:90000});
    await click(s,'hud','pause');await wait(s,'hud','paused',true);await click(s,'hud','pause_settings_tab');
    await exposeScale(s);
    const history=[];
    for(const scale of [0,1,2]){
     let state=await stableSlider(s),c=state.c;
     const fraction=scale/2,pointX=c.x+5+fraction*Math.max(0,c.width-10);
     invariant(pointX>=c.x&&pointX<=c.x+c.width,'scale slider endpoint outside slider');
     await s.page.mouse.click(pointX,c.center_y);
     await s.page.waitForFunction(value=>window.__cvR19Controls?.hud?.flags?.ui_scale_index===value,scale,{timeout:15000});
     await s.page.waitForTimeout(200);
     state=await stableSlider(s);const hud=state.hud,title=hud.controls.pause_title,tabs=['pause_settings_tab','pause_achievements_tab','pause_run_tab'].map(id=>hud.controls[id]);
     geometry(title,width,height);for(const tab of tabs)geometry(tab,width,height);
     invariant(tabs.every(t=>!overlaps(rect(title),rect(t))),'pause heading overlaps a tab at scale '+scale+' '+label);
     history.push({scale,index:hud.flags.ui_scale_index,title:rect(title),tabs:tabs.map(rect),scaleSlider:rect(hud.controls.pause_ui_scale)});
     if(scale===2){
      const file='review-set/'+label+'-pause-max.png',out=await writable(file);await s.page.screenshot({path:out});
      const bytes=await fs.readFile(evidence(file));
      const renderer=await s.page.evaluate(()=>{const gl=document.querySelector('canvas').getContext('webgl2')||document.querySelector('canvas').getContext('webgl');const ext=gl.getExtension('WEBGL_debug_renderer_info');return gl.getParameter(ext.UNMASKED_RENDERER_WEBGL);});
      invariant(renderer.includes('SwiftShader'),'hardware renderer prohibited '+renderer);
      cases.push({viewport:[width,height],dpr,pixels:[width*dpr,height*dpr],scale:2,setting_index:hud.flags.ui_scale_index,file,sha256:sha(bytes),history,renderer,knownUidWarnings:s.warnings,provenance:'real menu Start and official HUD pause/settings pointer clicks; setting persisted only by UI to isolated profile; no PlayerSettings setter',build:builds.review});
     }
    }
    invariant(!s.errors.length&&!s.external.length,'browser diagnostics '+JSON.stringify(s.errors));
   }finally{await s.context.close();}
  }
 }finally{await browser.close();}
 const after=await verifySources();invariant(after.status==='VERIFIED','R5 source changed during UI run '+after.failures.slice(0,5).join(','));
 await write('tests/pause-layout.json',{status:'VERIFIED',scope:'Three official viewport sizes and all three UI scales; heading/tab non-overlap and 44px bounds measured from the live HUD controls.',input:'real pointer; continuous campaign begun through release MainMenu; pause during battle; no natural-outcome claim',driverSha256:process.env.CONTENT_DRIVER_SHA256,sourceManifestSha256:builds.review.source_manifest_sha256,reviewPackSha256:builds.review.pack_sha256,cases,before,after,errors:[]});
 console.log('R5_PAUSE_LAYOUT VERIFIED '+cases.length+' viewport screenshots');
}
(async()=>{const s=await verifySources();await write('tests/source-protection-before.json',s);invariant(s.status==='VERIFIED','source protection before capture failed');await capture();await write('tests/source-protection-after.json',await verifySources());})().catch(e=>{console.error(e);process.exitCode=1;});
