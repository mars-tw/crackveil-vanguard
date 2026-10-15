// Local Web evidence and real pointer-input checks; never launches a visible window.
const fs = require('node:fs/promises');
const path = require('node:path');
const {chromium} = require(path.join(process.env.UI_CAPTURE_PLAYWRIGHT, 'playwright-core'));
const phase = process.argv[2] || 'after';
const out = path.resolve('docs/evidence/r43-mobile');
const rows = [];
const check = (v, m) => { if (!v) throw Error(m); };
(async () => {
 await fs.mkdir(out, {recursive:true});
 const browser = await chromium.launch({headless:true, executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe', args:['--enable-webgl','--ignore-gpu-blocklist']});
 try {
  for (const [width,height] of [[390,844],[844,390],[1366,600]]) {
   const mobile = width < 1000;
   const context = await browser.newContext({viewport:{width,height}, hasTouch:mobile, isMobile:mobile, deviceScaleFactor:1, userAgent:mobile?'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36':undefined});
   const page = await context.newPage();
   const errors=[];
   page.on('pageerror',e=>errors.push(String(e)));
   page.on('console',m=>{if(m.type()==='error' && !m.text().includes('404') && !(m.text().includes("WARNING: 'res://") && m.text().includes('invalid UID:')) && !m.text().includes('at: open (core/io/resource_format_binary.cpp:1028)')) errors.push(m.text());});
   const probe = async scope => page.evaluate(s=>window.__cvR19Controls?.[s],scope);
   const wait = async (s,key,val)=>{await page.waitForFunction(({s,key,val})=>{const p=window.__cvR19Controls?.[s];return p && (key===null || p.flags[key]===val);},{s,key,val},{timeout:60000});return probe(s);};
   const click = async (p,id)=>{const c=p.controls[id]; check(c?.visible,'missing '+id);await page.mouse.click(c.center_x,c.center_y);};
   await page.goto(`http://127.0.0.1:8143/r43-${phase}/index.html?cv_r19_test=1&cv_r22_test=1`,{timeout:60000});
   let p=await wait('main_menu',null,null);
   if(phase==='after') {
    await click(p,'meta');
    p=await wait('main_menu','side_panel_visible',true);
    await click(p,'tactical_collection');
    p=await wait('main_menu','panel_id','tactical');
    for(const id of ['tactical_previous','tactical_next','side_close']) {
     const c=p.controls[id];check(c.visible && c.height>=44 && c.y+c.height<=height,`collection/${id}`);
    }
    await page.screenshot({path:path.join(out,`after-${width}x${height}-collection.png`)});
    await click(p,'tactical_next');
    await wait('main_menu','tactical_page',1);
    await click(await probe('main_menu'),'side_close');
    p=await wait('main_menu','side_panel_visible',false);
   }
   await click(p,'start');
   p=await wait('hud','paused',false);
   await page.waitForTimeout(1200);
   await page.screenshot({path:path.join(out,`${phase}-${width}x${height}-battle.png`)});
   if(phase==='after') {
    p=await probe('hud');
    const b=p.controls.formation;
    check(b.height>=44 && b.width>=44, 'formation target');
    let touchSession, joyPoint;
    if(mobile) {
     touchSession=await context.newCDPSession(page);
     const joy=p.controls.virtual_joystick;
     const start={x:joy.center_x,y:joy.center_y,id:7};
     joyPoint={x:joy.center_x+24,y:joy.center_y-8,id:7};
     await touchSession.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[start]});
     await touchSession.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[joyPoint]});
     await touchSession.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[joyPoint,{x:b.center_x,y:b.center_y,id:9}]});
     await page.waitForTimeout(600);
     await touchSession.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[{x:b.center_x,y:b.center_y,id:9}]});
    } else {
     await page.mouse.move(b.center_x,b.center_y);
     await page.mouse.down();
     await page.waitForTimeout(600);
     await page.mouse.up();
    }
    p=await wait('hud','formation_picker',true);
    for(const id of ['formation_wedge','formation_ring','formation_scatter','formation_cancel']) {
     const c=p.controls[id];
     check(c.visible && c.height>=44 && c.width>=44 && c.x>=0 && c.y>=0 && c.x+c.width<=width+1 && c.y+c.height<=height+1,`${width}/${id} geometry`);
    }
    await page.screenshot({path:path.join(out,`after-${width}x${height}-formation.png`)});
    if(mobile) {
     const choice=p.controls.formation_scatter;
     await touchSession.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[joyPoint,{x:choice.center_x,y:choice.center_y,id:9}]});
     await touchSession.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[{x:choice.center_x,y:choice.center_y,id:9}]});
     await touchSession.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    } else await click(p,'formation_scatter');
    p=await wait('hud','formation_picker',false);
    check(p.flags.formation_id==='scatter','direct formation choice failed '+JSON.stringify(p.flags));
    await click(p,'pause');
    p=await wait('hud','paused',true);
    await click(p,'pause_run_tab');
    await page.waitForTimeout(200);
    await page.screenshot({path:path.join(out,`after-${width}x${height}-objectives.png`)});
   }
   check(errors.length===0,JSON.stringify(errors));
   rows.push({width,height,phase,errors,input:phase==='after'&&mobile?'CDP physical two-finger joystick + long-press + direct choice':'mouse',status:'VERIFIED'});
   await context.close();
   console.log(`${phase} ${width}x${height} VERIFIED`);
  }
 } finally {await browser.close(); await fs.writeFile(path.join(out,`${phase}-web.json`),JSON.stringify(rows,null,2));}
})().catch(e=>{console.error(e);process.exitCode=1;});
