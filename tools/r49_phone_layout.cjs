// Run against a served Web export. The R48 driver sends only touch events.
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { chromium, UA, Driver, read } = require('./r48_forge_capture.cjs');
const out = process.env.CV_R49_OUT || path.join(__dirname, '..', 'docs', 'content', 'r49', 'a');
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

function intersection(a, b) {
	const l = Math.max(a[0], b[0]), t = Math.max(a[1], b[1]);
	const r = Math.min(a[0] + a[2], b[0] + b[2]), d = Math.min(a[1] + a[3], b[1] + b[3]);
	return r > l && d > t ? [l, t, r-l, d-t] : null;
}

// Exact union, including overlapping HUD controls and their parent panels.
function coveredArea(rects, region) {
	const cuts = rects.map(r => intersection(r, region)).filter(Boolean);
	const xs = [...new Set(cuts.flatMap(r => [r[0], r[0]+r[2]]))].sort((a,b)=>a-b);
	let area = 0;
	for (let i=1;i<xs.length;i++) {
		const spans = cuts.filter(r => r[0]<xs[i] && r[0]+r[2]>xs[i-1]).map(r=>[r[1],r[1]+r[3]]).sort((a,b)=>a[0]-b[0]);
		let length = 0, bottom = -Infinity;
		for (const [y,end] of spans) {
			length += Math.max(0,end-Math.max(y,bottom));
			bottom = Math.max(bottom,end);
		}
		area += length*(xs[i]-xs[i-1]);
	}
	return area;
}

async function capture(browser) {
	const width = 844, height = 390;
	const context = await browser.newContext({ viewport:{width,height}, deviceScaleFactor:1, isMobile:true, hasTouch:true, userAgent:UA, serviceWorkers:'block' });
	try {
		const page = await context.newPage(), cdp = await context.newCDPSession(page);
		const drive = new Driver(page, cdp, 'phone', {mobile:true});
		const url = new URL('index.html', process.env.CV_R49_URL || 'http://127.0.0.1:8149/');
		url.search = 'cv_r19_test=1&cv_r32_test=1&cv_start_stage=forge';
		await page.goto(url.href, {timeout:180000});
		const renderer = await page.evaluate(() => {
			const gl = document.createElement('canvas').getContext('webgl2');
			return gl.getParameter(gl.getExtension('WEBGL_debug_renderer_info').UNMASKED_RENDERER_WEBGL);
		});
		if (!renderer.includes('SwiftShader')) throw new Error('software renderer required');
		await page.waitForFunction(()=>window.__cvR19Controls?.main_menu, null, {timeout:180000});
		let s = await read(page);
		await drive.tap(s.menu,'start',s);
		const samples = [], start = Date.now();
		let lesson = '', shot = false, lastTime = -1, stall = Date.now();
		while (Date.now()-start<600000 && samples.length<5) {
			s = await read(page);
			const time = s.rt?.elapsed ?? -1;
			if (time !== lastTime) { lastTime=time; stall=Date.now(); }
			const open = p => p?.flags?.visible && (!s.hud || p.timestamp_msec>s.hud.timestamp_msec || Date.now()-stall>900);
			if (open(s.guide)) { if (!await drive.tap(s.guide,'start',s)) await drive.tap(s.guide,'skip',s); continue; }
			if (open(s.level)) { await drive.tap(s.level,'card_0',s); continue; }
			if (open(s.shop)) { await drive.tap(s.shop,'skip',s); continue; }
			if (open(s.contract)) { await drive.tap(s.contract,'first_option',s); continue; }
			if (s.result?.flags?.visible && s.hud && s.result.timestamp_msec > s.hud.timestamp_msec + 300) break;
			if (!s.hud || !s.rt) { await sleep(100); continue; }
			if (s.hud.controls.audio_prompt?.visible) { await drive.tap(s.hud,'audio_prompt',s); continue; }
			const f=s.hud.flags;
			if (!lesson && f.mission_text?.includes('反噬歸零')) {
				lesson=f.mission_text;
				await page.screenshot({path:path.join(out,'phone-first-seal.png')});
			}
			const rt=await page.evaluate(()=>{const r=window.__cvR32Runtime; return { text:r.battle_text_rects || {}, forge:r.forge_layout || {}, hud:r.hud_areas || {}, mission:r.mission_text, specials:r.special_elites?.length || 0, spawned:r.horde?.enemies_spawned || 0, t:r.elapsed_time };});
			const forge=rt.forge;
			if (forge.rects && rt.text.seal_verdict && rt.specials>0 && (samples.length===0 || rt.t-samples.at(-1).elapsed>=0.15)) {
				const W=s.hud.viewport_width,H=s.hud.viewport_height;
				const center=[W*.25,H*.25,W*.5,H*.5];
				const panels=Object.entries(rt.text);
				for (const id of ['plate','verdict','tag_near','tag_far','digit']) if (forge.rects[id]) panels.push(['forge_'+id,forge.rects[id]]);
				const hud=Object.values(rt.hud);
				const count=panels.filter(([,r])=>intersection(r,center)).length;
				const free=1-coveredArea([...hud,...panels.map(x=>x[1])],center)/(center[2]*center[3]);
				const sockets=Object.entries(forge.rects).filter(([k])=>k==='near'||k==='far');
				const overlaps=sockets.filter(([,r])=>intersection(rt.text.seal_verdict,r)).map(x=>x[0]);
				samples.push({elapsed:rt.t,stageEvent:forge.done?'set or expired':'gear core active',specialElites:rt.specials,spawned:rt.spawned,centralTextPanels:count,uncoveredShare:free,socketIntersections:overlaps,panels:Object.fromEntries(panels),sockets:Object.fromEntries(sockets),hudAreas:rt.hud,mission:rt.mission});
				if (!shot && !forge.done && sockets.length===2) {
					await page.screenshot({path:path.join(out,'phone-event-verdict.png')});
					shot=true;
				}
				if (!shot && samples.length===5) samples.pop();
			}
			if (samples.length>=5 && shot) break;
			// Remain near the seal: take a small, repeatable circle using the joystick.
			const a=time*.74;
			await drive.steer([Math.cos(a),Math.sin(a)],s);
			await sleep(110);
		}
		const valid=lesson && shot && samples.length>=5 && samples.every(r=>r.uncoveredShare>=.55 && r.centralTextPanels<=3 && !r.socketIntersections.length);
		const report={status:valid?'PASS':'FAIL',viewport:[width,height],centralRegion:[211,97.5,422,195],renderer,lesson,samples};
		fs.writeFileSync(path.join(out,'phone-layout.json'), JSON.stringify(report,null,2)+'\n');
		console.log('R49_PHONE_LAYOUT',report.status,'frames',samples.length,'lesson',Boolean(lesson),'live core',shot);
		if (!valid) throw new Error('phone layout gate failed');
	} finally { await context.close(); }
}
(async () => {
	fs.mkdirSync(out,{recursive:true});
	const browser=await chromium.launch({headless:true,args:['--disable-gpu','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist','--mute-audio']});
	try { await capture(browser); } finally { await browser.close(); }
})().catch(e=>{ console.error(e); process.exitCode=1; });
