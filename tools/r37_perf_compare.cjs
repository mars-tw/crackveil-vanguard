// Real Chrome input and read-only Godot probes. Never changes gameplay state.
const fs = require('node:fs'), path = require('node:path');
const {createHash} = require('node:crypto');
const { chromium } = require(process.env.UI_CAPTURE_PLAYWRIGHT ? path.join(process.env.UI_CAPTURE_PLAYWRIGHT, 'playwright-core') : 'playwright');
const mobile = process.env.R36_MOBILE === '1';
const output = path.resolve(__dirname, '../docs/evidence/r37/performance');
const label = process.env.R36_PREFIX || 'c2-desktop-no-video';
const url = process.env.R36_URL || 'http://127.0.0.1:8072/?cv_r22_test=1&cv_r32_test=1&r36_revision=2';
const seconds = Number(process.env.R36_SECONDS || 30);
const manualCombat = process.env.R37_MANUAL === '1';
const expectedVersion = process.env.R37_EXPECT_VERSION || fs.readFileSync(path.resolve(__dirname, '../project.godot'),'utf8').match(/^config\/version="([^"]+)"/m)[1];
fs.mkdirSync(output, {recursive: true});
(async () => {
  const browser = await chromium.launch({executablePath: process.env.UI_CAPTURE_CHROME || chromium.executablePath(), headless: true, args: ['--disable-gpu-sandbox']});
  const viewport = mobile ? {width: 844, height: 390} : {width: 1280, height: 720};
  const context = await browser.newContext({viewport, hasTouch: mobile, isMobile: mobile, deviceScaleFactor: mobile ? 2 : 1, locale: 'zh-TW', serviceWorkers: 'block'});
  const page = await context.newPage(), cdp = await context.newCDPSession(page);
  const errors = [], failedResponses = [], samples = [], actions = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {if (message.type() === 'error' && !message.text().startsWith('WARNING:') && !message.text().includes('at: open')) errors.push(message.text());});
  page.on('response', response => {if(response.status() >= 400) failedResponses.push({url:response.url(),status:response.status()});});
  const probe = () => page.evaluate(() => ({runtime: window.__cvR32Runtime || null, controls: window.__cvR22Controls || null}));
  const response = await page.goto(url, {waitUntil: 'commit', timeout: 30000});
  const htmlText = await response.text();
  const shim = htmlText.match(/<script\b[^>]*id=["']rift-r36-webgl-state-cache["'][^>]*>([\s\S]*?)<\/script>/i);
  const artifactIdentity = {htmlSHA256:createHash('sha256').update(htmlText).digest('hex'),shimSHA256:shim?createHash('sha256').update(shim[1]).digest('hex'):null,pckNames:[...new Set(htmlText.match(/index-[a-f0-9]+\.pck/g)||[])]};
  let state;
  for (let n = 0; n < 120; n++) { state = await probe(); if(state.controls?.main_menu?.controls?.start?.visible) break; await page.waitForTimeout(400); }
  const startControl = process.env.R36_SEED ? state.controls?.main_menu?.controls?.seed_input : state.controls?.main_menu?.controls?.start;
  if (!startControl?.visible) throw Error('Actual start/seed control unavailable');
  if (mobile) await page.touchscreen.tap(startControl.center_x, startControl.center_y); else await page.mouse.click(startControl.center_x, startControl.center_y);
  if(process.env.R36_SEED){await page.keyboard.type(process.env.R36_SEED);await page.keyboard.press('Enter');actions.push({kind:'real_seed_input',text:process.env.R36_SEED});}
  for (let n = 0; n < 100; n++) { state = await probe(); if(state.runtime?.game_running && !state.runtime.waiting_for_contract) break; await page.waitForTimeout(150); }
  if (state.runtime?.version !== expectedVersion) throw Error('Wrong version ' + state.runtime?.version);
  // This observer only counts animation callbacks; it neither draws nor captures canvas.
  await page.evaluate(() => { window.__r36PerfObserver = {frames: 0, first: performance.now(), last: 0}; const observe = timestamp => {const p = window.__r36PerfObserver; p.frames++; p.last = timestamp; requestAnimationFrame(observe);}; requestAnimationFrame(observe); });
  let recordingProfile = false;
  const manualTaps = new Set();
  let manualHoldStarted = false, manualHoldEnded = false;
  const wallStart = Date.now();
  while (Date.now() - wallStart < 120000) {
    state = await probe(); const runtime = state.runtime;
    const observer = await page.evaluate(() => ({...window.__r36PerfObserver}));
    samples.push({wallMs: Date.now() - wallStart, observer, runtime});
    if (runtime?.elapsed_time >= seconds || runtime?.is_game_over) break;
    if (runtime?.waiting_for_upgrade) {
      if(manualCombat && manualHoldStarted && !manualHoldEnded){await page.keyboard.up('Space');manualHoldEnded=true;actions.push({kind:'manual_hold_modal_release',elapsed:runtime.elapsed_time});}
      await page.waitForTimeout(550);
      if(mobile) await page.touchscreen.tap(180,225); else await page.mouse.click(345,395);
      actions.push({kind:'upgrade_click', elapsed: runtime.elapsed_time});
      await page.waitForTimeout(180); continue;
    }
    if (runtime?.system_paused) throw Error('Unexpected modal');
    if (process.env.R36_PROFILE === '1' && !recordingProfile && runtime?.elapsed_time >= 12) { await cdp.send('Profiler.enable'); await cdp.send('Profiler.setSamplingInterval',{interval: 2000}); await cdp.send('Profiler.start'); recordingProfile = true; }
    const direction = ['d','s','a','w'][Math.floor((runtime?.elapsed_time || 0) / 2.4) % 4];
    if(manualCombat && !mobile) {
      await page.keyboard.down(direction);
      const tapTime = [8,11].find(time=>runtime.elapsed_time>=time && !manualTaps.has(time));
      if(tapTime!=null){manualTaps.add(tapTime);const before=await probe();await page.keyboard.press('Space');await page.waitForTimeout(180);const after=await probe();actions.push({kind:'real_space_tap',scheduled:tapTime,before:before.runtime,after:after.runtime});await page.screenshot({path:path.join(output,label+'-tap-'+tapTime+'.png')});}
      if(runtime.elapsed_time>=14 && !manualHoldStarted){manualHoldStarted=true;const before=await probe();await page.keyboard.down('Space');actions.push({kind:'real_space_hold_start',before:before.runtime});}
      if(runtime.elapsed_time>=17.5 && manualHoldStarted && !manualHoldEnded){manualHoldEnded=true;await page.keyboard.up('Space');await page.waitForTimeout(180);const after=await probe();actions.push({kind:'real_space_hold_release',after:after.runtime});}
      if(manualHoldStarted && !manualHoldEnded && runtime.elapsed_time>=15.5 && !actions.some(action=>action.kind==='public_battle_capture')){await page.screenshot({path:path.resolve(__dirname,'../docs/evidence/r37/gameplay.png')});actions.push({kind:'public_battle_capture',elapsed:runtime.elapsed_time});}
    }
    if(mobile) {
      const joy = state.controls?.hud?.controls?.virtual_joystick;
      if(!joy?.visible) throw Error('Actual touch joystick unavailable');
      const v = {d:[1,0],s:[0,1],a:[-1,0],w:[0,-1]}[direction];
      await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:joy.center_x,y:joy.center_y,id:1}]});
      await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:joy.center_x+v[0]*55,y:joy.center_y+v[1]*55,id:1}]});
      await page.waitForTimeout(800);
      await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    } else {await page.keyboard.down(direction); await page.waitForTimeout(800); await page.keyboard.up(direction);}
    actions.push({kind:'move',direction,elapsed:runtime?.elapsed_time});
  }
  if(manualCombat && manualHoldStarted && !manualHoldEnded) await page.keyboard.up('Space');
  if(recordingProfile) {const profile = await cdp.send('Profiler.stop'); fs.writeFileSync(path.join(output,label+'.cpuprofile'),JSON.stringify(profile.profile));}
  const active = samples.filter(sample => sample.runtime?.game_running && !sample.runtime.system_paused && sample.runtime.elapsed_time >= 5);
  const values = active.map(sample => sample.runtime.fps).sort((a,b)=>a-b);
  const rendering = await page.evaluate(() => {const canvas=document.querySelector('canvas');const gl=canvas?.getContext('webgl2');const ext=gl?.getExtension('WEBGL_debug_renderer_info');return {css:[innerWidth,innerHeight],canvas:[canvas?.width,canvas?.height],dpr:devicePixelRatio,renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):null,vendor:ext?gl.getParameter(ext.UNMASKED_VENDOR_WEBGL):null};});
  const nativeGLVerification = await page.evaluate(() => window.__r36WebGLCommitState?.verify() || null);
  const performanceMonitors = {};
  for(const key of ['process_ms','physics_ms','draw_calls','render_objects']){const measurements=active.map(sample=>sample.runtime.performance?.[key]).filter(value=>value!=null).sort((a,b)=>a-b);performanceMonitors[key]={mean:measurements.length?measurements.reduce((a,b)=>a+b,0)/measurements.length:null,median:measurements.length?measurements[Math.floor(measurements.length/2)]:null,max:measurements.length?measurements.at(-1):null};}
  const rates = {};
  for(const key of ['engine_physics_frames','projectile_physics_ticks','projectile_readability_checks','dart_redraw_requests','enemy_spatial_queries']) {
    let count=0,wall=0;
    for(let n=1;n<samples.length;n++){const a=samples[n-1],b=samples[n];if(a.runtime?.elapsed_time<5||a.runtime?.system_paused||b.runtime?.system_paused)continue;const previous=a.runtime?.firepower?.[key],current=b.runtime?.firepower?.[key];if(previous==null||current==null)continue;count+=current-previous;wall+=b.wallMs-a.wallMs;}
    rates[key]={count,activeWallMs:wall,perSecond:wall?count/(wall/1000):null};
  }
  const manualMetrics = manualCombat ? {taps:actions.filter(action=>action.kind==='real_space_tap').map(action=>({at:action.before.elapsed_time,hitsDelta:action.after.cleave.active_hits-action.before.cleave.active_hits,stepDistance:action.after.cleave.step_distance,assistedDelta:action.after.cleave.assisted_casts-action.before.cleave.assisted_casts,before:[action.before.player_x,action.before.player_y],after:[action.after.player_x,action.after.player_y]})),finalCleave:state.runtime?.cleave,finalChannel:state.runtime?.channel,exactWebAnimationFramePublished:false} : null;
  const summary = {label,url,viewport,artifactIdentity,rendering,nativeGLVerification,performanceMonitors,runSeed:state.runtime?.run_seed,manualMetrics,video:false,gameplayInjection:false,samples:active.length,finalSeconds:state.runtime?.elapsed_time,meanEngineFPS:values.reduce((a,b)=>a+b,0)/values.length,minEngineFPS:values[0],maxEngineFPS:values.at(-1),medianEngineFPS:values[Math.floor(values.length/2)],peakFriendlyShots:Math.max(...active.map(sample=>sample.runtime.firepower?.friendly_projectiles_visible||0)),peakLogicalShots:Math.max(...active.map(sample=>sample.runtime.firepower?.projectiles_logical||0)),peakEnemies:Math.max(...active.map(sample=>sample.runtime.firepower?.enemies_live||0)),rates,kills:state.runtime?.kills,failedResponses,errors};
  fs.writeFileSync(path.join(output,label+'.json'),JSON.stringify({summary,actions,samples},null,2));
  // One final still after FPS measurement; no video or recurring screenshot encoding.
  await page.screenshot({path:path.join(output,label+'.png')});
  if(manualCombat && !actions.some(action=>action.kind==='public_battle_capture')) fs.copyFileSync(path.join(output,label+'.png'),path.resolve(__dirname,'../docs/evidence/r37/gameplay.png'));
  console.log(JSON.stringify(summary,null,2));
  await context.close(); await browser.close();
})().catch(error => {console.error(error);process.exitCode = 1;});
