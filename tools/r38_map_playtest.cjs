// Sequential real Chrome UI/keyboard/touch runs. All page evaluation is read-only.
const fs = require('node:fs'), path = require('node:path'), {createHash} = require('node:crypto');
const {chromium} = require(process.env.UI_CAPTURE_PLAYWRIGHT ? path.join(process.env.UI_CAPTURE_PLAYWRIGHT,'playwright-core') : 'playwright');
const url = process.env.UI_CAPTURE_URL || 'http://127.0.0.1:8072/?cv_r22_test=1&cv_r32_test=1&r38_preview=1&r36_gpu_preference=0';
const output = path.resolve(__dirname,'../docs/evidence/r38/playtest');
const expectedVersion = '0.26.0-r38';
fs.mkdirSync(output,{recursive:true});
const selectedStages = (process.env.R38_STAGES || 'dunes,tide,bloom,forge').split(',');
const jobs = selectedStages.map(stage=>({stage,mobile:false,seconds:20}));
if(process.env.R38_PHONE !== '0') jobs.push({stage:process.env.R38_PHONE_STAGE || 'tide',mobile:true,seconds:30});
(async()=>{
  const browser = await chromium.launch({executablePath:process.env.UI_CAPTURE_CHROME || chromium.executablePath(),headless:true,args:['--disable-gpu-sandbox']});
  const summaries=[];
  try {
    for(const job of jobs){
      const label=(process.env.R38_LABEL_PREFIX||'')+job.stage+(job.mobile?'-phone':'-desktop');
      const viewport=job.mobile?{width:844,height:390}:{width:1280,height:720};
      const context=await browser.newContext({viewport,hasTouch:job.mobile,isMobile:job.mobile,deviceScaleFactor:job.mobile?2:1,locale:'zh-TW',serviceWorkers:'block'});
      try {
        const page=await context.newPage(),cdp=await context.newCDPSession(page),samples=[],events=[],errors=[];
        page.on('pageerror',error=>errors.push(String(error)));
        page.on('console',message=>{if(/SCRIPT ERROR|WebGL.*(?:error|lost)|shader.*(?:error|failed)/i.test(message.text()))errors.push(message.text());});
        const probe=()=>page.evaluate(()=>({controls:window.__cvR22Controls||null,map:window.__cvR34WorldMap||null,runtime:window.__cvR32Runtime||null}));
        const click=async control=>{if(!control?.visible||control.disabled)throw Error('Hidden/disabled real UI control');if(job.mobile)await page.touchscreen.tap(control.center_x,control.center_y);else await page.mouse.click(control.center_x,control.center_y);};
        const response=await page.goto(url,{waitUntil:'commit',timeout:30000});
        const html=await response.text(),identity={htmlSHA256:createHash('sha256').update(html).digest('hex'),pckNames:[...new Set(html.match(/index-[a-f0-9]+\.pck/g)||[])]};
        let state;
        for(let n=0;n<150;n++){state=await probe();if(state.controls?.main_menu?.controls?.world_map?.visible)break;await page.waitForTimeout(400);}
        await click(state.controls.main_menu.controls.world_map);
        await page.waitForFunction(()=>window.__cvR34WorldMap?.chapters?.length===2);
        state=await probe();await click(state.map.chapters[1]);await page.waitForTimeout(200);
        state=await probe();const node=state.map.nodes.find(node=>node.id===job.stage);
        await click(node);await page.waitForTimeout(150);state=await probe();
        if(state.map.selected_stage_id!==job.stage||state.map.chapter!==1)throw Error('Actual chapter/node selection failed');
        await page.screenshot({path:path.join(output,label+'-world-map.png')});
        events.push({kind:'actual_world_map_chapter2_node',state:state.map});
        await click(state.map.start);
        await page.waitForFunction(()=>window.__cvR32Runtime?.game_running&&!window.__cvR32Runtime?.waiting_for_contract);
        state=await probe();if(state.runtime.version!==expectedVersion||state.runtime.stage_id!==job.stage)throw Error('Wrong release/stage '+JSON.stringify(state.runtime));
        process.stdout.write(JSON.stringify({phase:'R38_RUN_START',label,version:state.runtime.version,stage:state.runtime.stage_id})+'\n');
        const wallStart=Date.now();let playDeadline=wallStart+120000,pairDone=false,abilityTapped=false;
        while(Date.now()<playDeadline){
          state=await probe();const r=state.runtime;samples.push({wallMs:Date.now()-wallStart,runtime:r});
          if(r.is_game_over||r.elapsed_time>=job.seconds)break;
          if(r.waiting_for_upgrade){
            await page.waitForTimeout(450);
            const cardPath=path.join(output,label+'-upgrade-'+r.level+'.png');
            await page.screenshot({path:cardPath});
            let cardIndex=0,intent='first available card';
            if(process.env.R38_REVIEW_CARDS==='1'&&!job.mobile){const decision=path.join(output,'live-card-choice.json');if(fs.existsSync(decision))fs.unlinkSync(decision);const reviewStart=Date.now();process.stdout.write(JSON.stringify({phase:'R38_CARD_REVIEW',label,level:r.level,path:cardPath})+'\n');const deadline=Date.now()+120000;while(!fs.existsSync(decision)&&Date.now()<deadline)await page.waitForTimeout(250);if(!fs.existsSync(decision))throw Error('Card review timed out');playDeadline+=Date.now()-reviewStart;const answer=JSON.parse(fs.readFileSync(decision));cardIndex=answer.index;intent=answer.intent;if(!Number.isInteger(cardIndex)||cardIndex<0||cardIndex>2)throw Error('Invalid real card index');}
            if(job.mobile)await page.touchscreen.tap(180,225);else await page.mouse.click([345,640,935][cardIndex],395);
            events.push({kind:'actual_upgrade_card',cardIndex,intent,time:r.elapsed_time,level:r.level});await page.waitForTimeout(180);continue;
          }
          if(r.system_paused)throw Error('Unexpected non-upgrade modal');
          if(!pairDone&&r.elapsed_time>=3){await page.screenshot({path:path.join(output,label+'-mob-walk-a.png')});await page.waitForTimeout(200);await page.screenshot({path:path.join(output,label+'-mob-walk-b.png')});pairDone=true;}
          const direction=['d','s','a','w'][Math.floor(r.elapsed_time/3.0)%4];
          if(job.mobile){const joy=state.controls.hud.controls.virtual_joystick;const v={d:[1,0],s:[0,1],a:[-1,0],w:[0,-1]}[direction];await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:joy.center_x,y:joy.center_y,id:1}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:joy.center_x+v[0]*55,y:joy.center_y+v[1]*55,id:1}]});await page.waitForTimeout(750);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}
          else{await page.keyboard.down(direction);if(!abilityTapped&&r.elapsed_time>=9){await page.keyboard.press('Space');abilityTapped=true;events.push({kind:'actual_space_tap',time:r.elapsed_time});}await page.waitForTimeout(750);await page.keyboard.up(direction);}
        }
        state=await probe();
        const active=samples.filter(sample=>sample.runtime.elapsed_time>=5&&!sample.runtime.system_paused),fps=active.map(sample=>sample.runtime.fps).sort((a,b)=>a-b);
        const nativeGLVerification=await page.evaluate(()=>window.__r36WebGLCommitState?.verify()||null);
        const rendering=await page.evaluate(()=>{const canvas=document.querySelector('canvas'),gl=canvas.getContext('webgl2'),ext=gl.getExtension('WEBGL_debug_renderer_info');return {css:[innerWidth,innerHeight],canvas:[canvas.width,canvas.height],dpr:devicePixelRatio,renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):null};});
        await page.screenshot({path:path.join(output,label+'-battle.png')});
        const counts=state.runtime.horde?.regular_spawn_counts||{},roster=state.runtime.horde?.biome_roster||{};
        const summary={label,stage:job.stage,version:state.runtime.version,activeSeconds:state.runtime.elapsed_time,controlledNaturalInput:true,gameplayInjection:false,video:false,mobileEmulation:job.mobile,meanFPS:fps.reduce((a,b)=>a+b,0)/fps.length,medianFPS:fps[Math.floor(fps.length/2)],minFPS:fps[0],maxFPS:fps.at(-1),peakEnemies:Math.max(...active.map(s=>s.runtime.firepower.enemies_live)),peakLogicalShots:Math.max(...active.map(s=>s.runtime.firepower.projectiles_logical)),kills:state.runtime.kills,runTheme:state.runtime.run_theme_id,roster,actualSpeciesCounts:counts,newSpeciesActuallySpawned:Object.keys(counts).filter(id=>['dune_scarab','sand_stalker','tide_siren','coral_colossus','bloom_wisp','clockwork_reaper'].includes(id)),rendering,nativeGLVerification,identity,errors};
        if(!summary.newSpeciesActuallySpawned.length||!summary.kills||errors.length)throw Error('New biome real combat failed '+JSON.stringify(summary));
        fs.writeFileSync(path.join(output,label+'.json'),JSON.stringify({summary,events,samples},null,2));
        summaries.push(summary);fs.writeFileSync(path.join(output,(process.env.R38_LABEL_PREFIX||'')+'summary.json'),JSON.stringify({method:'Sequential one-Chrome real menu chapter/node/start; real keyboard/touch/card clicks, no gameplay writes; per-map active samples >=5 seconds, not a stable-FPS promise',url,runs:summaries},null,2));
        process.stdout.write(JSON.stringify({phase:'R38_RUN_COMPLETE',...summary})+'\n');
      } finally {await context.close();}
    }
  } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
