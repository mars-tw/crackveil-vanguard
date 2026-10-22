// Local, silent, headless rendering. Read-only probes; gameplay uses pointer/key input.
const fs=require('node:fs/promises'),path=require('node:path');
const {chromium}=require(path.join(process.env.UI_CAPTURE_PLAYWRIGHT,'playwright-core'));
const phase=process.argv[2]||'baseline';
const root=path.resolve('docs/content/r1'),out=path.join(root,phase);
const sizes=[[390,844],[430,932],[844,390],[1366,600],[768,1024],[1024,768]];
const rows=[];
(async()=>{
 await fs.mkdir(out,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--mute-audio','--use-angle=swiftshader','--enable-unsafe-swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 try{for(const [width,height] of sizes.filter(([w])=>!process.argv[3]||w===Number(process.argv[3]))){
  const touch=width!==1366;
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:1,hasTouch:touch,isMobile:touch,userAgent:touch?(width===768||width===1024?'Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1':'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Chrome/140.0.0.0 Mobile Safari/537.36'):undefined});
  const page=await context.newPage(),errors=[],captures=[];
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{if(m.type()==='error'&&!m.text().includes('404')&&!m.text().includes('invalid UID')&&!m.text().includes('resource_format_binary'))errors.push(m.text());});
  const probe=async s=>page.evaluate(s=>window.__cvR19Controls?.[s],s);
  const wait=async(s,k,v)=>{await page.waitForFunction(({s,k,v})=>{const p=window.__cvR19Controls?.[s];return p&&(k===null||p.flags[k]===v);},{s,k,v},{timeout:90000});return probe(s);};
  const click=async(p,id)=>{let c=p.controls[id];if(!c?.visible){console.log('WAIT_CONTROL '+JSON.stringify({scope:p.scope,id,control:c,flags:p.flags}));try{await page.waitForFunction(({scope,id})=>window.__cvR19Controls?.[scope]?.controls?.[id]?.visible,{scope:p.scope,id},{timeout:15000});}catch(error){await fs.writeFile('.audit-tmp/content-r1/input-failure.json',JSON.stringify({requested:p,latest:await probe(p.scope)},null,2));throw error;}c=(await probe(p.scope)).controls[id];}if(!c?.visible)throw Error('missing '+id);await page.mouse.click(c.center_x,c.center_y);};
  const shot=async name=>{await page.waitForTimeout(250);const state=await probe(name==='guide'?'main_menu':'hud');await page.screenshot({path:path.join(out,`${width}x${height}-${name}.png`)});captures.push({name,state});};
  await page.goto((process.env.UI_CAPTURE_URL||'http://127.0.0.1:8151/')+'index.html?cv_r19_test=1&cv_r22_test=1',{timeout:90000});
  let p=await wait('main_menu',null,null);
  await click(p,'guide');p=await wait('main_menu','side_panel_visible',true);await shot('guide');
  await click(p,'side_close');p=await wait('main_menu','side_panel_visible',false);
  await click(p,'start');p=await wait('hud','paused',false);
  if(phase!=='baseline'&&p.controls.auto_battle?.visible&&!p.flags.auto_upgrade){await click(p,'auto_battle');p=await wait('hud','auto_upgrade',true);}
  await page.waitForTimeout(900);await shot('battle');
  p=await probe('hud');const b=p.controls.formation;await page.mouse.move(b.center_x,b.center_y);await page.mouse.down();
  await wait('hud','formation_picker',true);await page.mouse.up();await shot('formation');
  p=await probe('hud');await click(p,'formation_cancel');await click(await probe('hud'),'pause');p=await wait('hud','paused',true);
  await click(p,'pause_run_tab');await shot('pause');
  rows.push({width,height,phase,errors,captures,hud:await probe('hud'),menu:p});
  await context.close();console.log(`${phase} ${width}x${height}: ${errors.length?'ERROR':'captured'}`);
 }}finally{await browser.close();await fs.writeFile(path.join(out,'matrix.json'),JSON.stringify(rows,null,2));}
 if(rows.some(r=>r.errors.length))throw Error('runtime errors');
})().catch(e=>{console.error(e);process.exitCode=1;});
