const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const { prepare, start } = require("../web/mobile_startup.js");

function fixture(ua, w=390, h=844, dpr=3) {
  const canvas = {width:1,height:1};
  const events = [];
  const listeners = {};
  const doc = {getElementById:()=>canvas,dispatchEvent:e=>events.push(e.detail.phase)};
  const win = {navigator:{userAgent:ua},innerWidth:w,innerHeight:h,devicePixelRatio:dpr,
    performance:{now:()=>1},CustomEvent:class{constructor(type,options){this.detail=options.detail}},
    requestAnimationFrame:fn=>fn(),addEventListener:(type,fn)=>listeners[type]=fn};
  const config={executable:"index",mainPack:"index-test.pck",args:["--example"],canvasResizePolicy:2};
  const state=prepare(doc,win,config);
  return {canvas,win,config,state,events,listeners};
}

(async()=>{
  const phone=fixture("iPhone Mobile Safari");
  assert.equal(phone.config.canvasResizePolicy,0);
  assert.deepEqual([phone.canvas.width,phone.canvas.height],[390,844]);
  assert.equal(phone.win.devicePixelRatio,3,"do not overwrite browser DPR");
  phone.win.innerWidth=844;phone.win.innerHeight=390;phone.listeners.orientationchange();
  assert.deepEqual([phone.canvas.width,phone.canvas.height],[844,390]);
  const calls=[];
  const engine={init:async name=>calls.push(["init",name]),preloadFile:async (file,path)=>calls.push(["pack",file,path]),
    start:async cfg=>calls.push(["start",...cfg.args]),startGame:async()=>{throw Error("parallel mobile start used")}};
  await start(engine,phone.config,()=>{},phone.state);
  assert.deepEqual(calls,[["init","index"],["pack","index-test.pck","index-test.pck"],["start","--main-pack","index-test.pck","--example"]]);
  assert.equal(phone.state.phase,"ready");
  const large=fixture("iPad Mobile",2000,1500);
  assert.ok(large.canvas.width*large.canvas.height<=921600);
  const touchDesktopUA=fixture("Windows Chrome",844,390,3);
  touchDesktopUA.win.navigator.maxTouchPoints=1;
  const touched=prepare({getElementById:()=>touchDesktopUA.canvas,dispatchEvent(){}},touchDesktopUA.win,touchDesktopUA.config);
  assert.equal(touched.mobile,true,"coarse phone layout with desktop UA must also take the safe path");
  const desktop=fixture("Windows Chrome",1280,720,2);
  assert.equal(desktop.config.canvasResizePolicy,2);
  let desktopCalls=0;
  await start({startGame:async()=>desktopCalls++},desktop.config,()=>{},desktop.state);
  assert.equal(desktopCalls,1);
  const failed=fixture("iPhone Mobile");
  await assert.rejects(start({init:async()=>{throw Error("oom")}},failed.config,()=>{},failed.state),/oom/);
  assert.equal(failed.state.phase,"failed");
  const lost=fixture("iPhone Mobile");
  let releaseInit;
  let loadedAfterFailure=false;
  const lostStart=start({init:()=>new Promise(resolve=>{releaseInit=resolve}),
    preloadFile:async()=>{loadedAfterFailure=true}},lost.config,()=>{},lost.state);
  lost.state.fail("context lost during init");releaseInit();
  await assert.rejects(lostStart,/context lost/);
  assert.equal(lost.state.phase,"failed");assert.equal(loadedAfterFailure,false);
  const {installLoadingRecovery}=await import("../web/loading_recovery.mjs");
  let time=0;
  const make=()=>({textContent:"",hidden:true,isConnected:true,style:{display:"none"},classList:{add(){}},
    setAttribute(){},addEventListener(){},append(){}});
  const els={"rift-r25-inline-focal":make(),"status-notice":make(),"status-progress":make(),"rift-r30-mb":make()};
  els["status-progress"].value=100;els["status-progress"].max=100;
  let removed=0;
  const bootWin={__cvR41Startup:{phase:"initializing"},setInterval:()=>1,clearInterval(){},getComputedStyle:e=>e.style,
    location:{reload(){}},addEventListener(){},removeEventListener(){removed++}};
  const recovery=installLoadingRecovery({getElementById:id=>els[id],createElement:make},bootWin,()=>time);
  time=30001;recovery.tick();assert.equal(recovery.recovery.hidden,false);assert.match(recovery.message.textContent,/啟動尚未完成/);
  bootWin.__cvR41Startup.phase="ready";recovery.tick();assert.equal(recovery.recovery.hidden,true);
  assert.equal(removed,1,"ready removes listener closures that retain the loading DOM");
  const htmlIndex=process.argv.indexOf("--html");
  if(htmlIndex>=0){
    const html=fs.readFileSync(process.argv[htmlIndex+1],"utf8");
    const helper=html.match(/<script id="rift-r41-mobile-startup">([\s\S]*?)<\/script>/)?.[1];
    assert.ok(helper,"export has the mobile startup implementation");
    assert.ok(helper.includes("await engine.startGame({ onProgress: progress });"),"desktop helper must retain the Engine API call");
    assert.ok(!helper.includes("CrackveilMobileStartup.start("),"helper must not accidentally call itself");
    const body=html.slice(html.indexOf("<body>"));
    assert.ok(body.includes("CrackveilMobileStartup.start(engine, GODOT_CONFIG, {"),"actual BODY bootstrap calls sequential wrapper");
    assert.ok(body.includes("}.onProgress, r41Startup).then("),"actual BODY passes phase state and progress");
    assert.ok(!body.includes("engine.startGame({"),"mobile BODY must not retain original parallel bootstrap");
    for(const match of html.matchAll(/<script([^>]*)>([\s\S]*?)<\/script>/g)){
      if(!match[1].includes('type="module"')&&!match[1].includes("src="))new vm.Script(match[2]);
    }
  }
  console.log("R41_MOBILE_STARTUP_PASS css_canvas_cap=true sequential=true desktop_unchanged=true init_stall_recovery=true");
})().catch(error=>{console.error(error);process.exitCode=1});
