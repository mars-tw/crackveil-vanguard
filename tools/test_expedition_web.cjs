// Local-only software-rendered smoke. Contexts are ephemeral; no personal browser/profile.
const fs = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require(path.join(process.env.UI_CAPTURE_PLAYWRIGHT, 'playwright-core'));
const origin = process.env.UI_CAPTURE_URL || 'http://127.0.0.1:8766/';
if (!['127.0.0.1', 'localhost'].includes(new URL(origin).hostname)) throw Error('local export only');
const out = path.resolve(__dirname, '../export/expedition-r46/qa');
const assert = (ok, message) => { if (!ok) throw Error(message); };
const reports = [];
async function probe(page) { return page.evaluate(() => window.__cvR19Controls?.main_menu); }
async function ready(page, panel = null) {
  await page.waitForFunction(panel => {
    const p = window.__cvR19Controls?.main_menu;
    return p && (panel === null || (p.flags.side_panel_visible && p.flags.panel_id === panel));
  }, panel, { timeout: 90000 });
  return probe(page);
}
async function clickProbe(page, name, touch) {
  const p = await probe(page), c = p.controls[name];
  assert(c?.visible, `missing visible main menu control ${name}`);
  const scale = await page.evaluate(() => [innerWidth, innerHeight]);
  const x = c.center_x * scale[0] / p.viewport_width;
  const y = c.center_y * scale[1] / p.viewport_height;
  if (touch) await page.touchscreen.tap(x, y); else await page.mouse.click(x, y);
}
async function run(browser, viewport, touch) {
  const label = `${viewport.width}x${viewport.height}`;
  const context = await browser.newContext({ viewport, deviceScaleFactor: 1, hasTouch: touch, isMobile: touch,
    userAgent: touch ? 'Mozilla/5.0 (Linux; Android 15; Pixel 7) AppleWebKit/537.36 Chrome/140.0.0.0 Mobile Safari/537.36' : undefined });
  const page = await context.newPage(), errors = [], failedRequests = [];
  page.on('pageerror', e => errors.push(String(e)));
  page.on('console', m => { if (m.type() === 'error' && /SCRIPT ERROR|(^|\s)ERROR:/.test(m.text())) errors.push(m.text()); });
  page.on('requestfailed', r => failedRequests.push({ url: r.url(), error: r.failure()?.errorText }));
  await page.route('**/favicon.ico', r => r.fulfill({status:204, body:''}));
  const url = new URL(origin); url.searchParams.set('cv_r19_test', '1'); url.searchParams.set('cv_r22_test','1');
  await page.goto(url.href, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await ready(page);
  const renderer = await page.evaluate(() => {
    const c = document.querySelector('#canvas'); const gl = c.getContext('webgl2') || c.getContext('webgl');
    const ext = gl?.getExtension('WEBGL_debug_renderer_info');
    return ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : '';
  });
  assert(renderer.includes('SwiftShader'), `non-software renderer rejected: ${renderer}`);
  await page.screenshot({ path: path.join(out, `main-menu-${label}.png`) });
  await clickProbe(page, 'achievements', touch);
  const journal = await ready(page, 'achievements');
  await page.screenshot({ path: path.join(out, `missions-${label}.png`) });
  if(process.argv.includes('--capture')) {
    reports.push({viewport,touch,renderer,journal,errors,failedRequests,captureOnly:true});
    await context.close();
    return;
  }
  // Coordinates observed in the original mission screenshots at these exact viewports.
  const points = touch ? {next:[305,447],legacy:[305,212],missions:[125,212],scroll:[210,720]} : {next:[1110,375],legacy:[1110,254],missions:[875,254],scroll:[1000,510]};
  const tap = async point => { if(touch) await page.touchscreen.tap(...point); else await page.mouse.click(...point); await page.waitForTimeout(150); };
  await tap(points.next);
  await page.screenshot({ path: path.join(out, `next-stage-${label}.png`) });
  await tap(points.legacy);
  await page.screenshot({ path: path.join(out, `achievements-${label}.png`) });
  await tap(points.missions);
  await tap(points.next);
  await page.mouse.move(...points.scroll);
  // Godot settles scroll minimums after the deferred responsive-layout pass.
  for(let n=0;n<2;n++){await page.mouse.wheel(0,2000);await page.waitForTimeout(250);}
  await page.screenshot({ path: path.join(out, `mission-map-link-${label}.png`) });
  if(process.argv.includes('--capture-navigation')) {
    reports.push({viewport,touch,renderer,journal,errors,failedRequests,captureOnly:true});
    await context.close();
    return;
  }
  // Map link centres observed in the unaltered bottom-of-journal captures.
  await tap(touch ? [225,853] : [1000,557]);
  await page.waitForFunction(() => window.__cvR34WorldMap?.selected_stage_id === 'garden', null, {timeout:15000});
  const map = await page.evaluate(() => window.__cvR34WorldMap);
  await page.screenshot({path:path.join(out,`world-map-${label}.png`)});
  assert(!errors.length && !failedRequests.length, `runtime errors: ${JSON.stringify({errors,failedRequests})}`);
  reports.push({ viewport, touch, renderer, journal, map, observedClickTargets:points, navigationVerified:true, errors, failedRequests, isolatedContext:true, naturalGameplay:false });
  await context.close();
  console.log(`EXPEDITION_WEB_CAPTURE ${label} renderer=${renderer} errors=${errors.length}`);
}
(async () => {
  await fs.mkdir(out, {recursive:true});
  const browser = await chromium.launch({headless:true, executablePath:process.env.UI_CAPTURE_CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe', args:['--mute-audio','--use-angle=swiftshader','--enable-unsafe-swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
  try { await run(browser,{width:430,height:932},true); await run(browser,{width:1280,height:720},false); }
  finally { await browser.close(); await fs.writeFile(path.join(out,'web-smoke.json'),JSON.stringify({status:reports.length===2&&reports.every(r=>r.navigationVerified&&!r.errors.length&&!r.failedRequests.length)?'VERIFIED':'INCOMPLETE',reports},null,2)); }
})().catch(error => { console.error(error); process.exitCode=1; });
