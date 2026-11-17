// R48 B line: the tenth stage's gear core (時輪齒核) on the real Web export.
//
// Opens the exported build in headless Chromium with software rendering only
// (SwiftShader; the GPU is kept for other work), starts 時輪工坊 through the
// existing QA entry (?cv_r19_test=1&cv_start_stage=forge), and plays it with
// the game's own inputs: WASD on desktop, the touch joystick on the phone.
// The bot walks onto each core and carries it to a socket (first one near,
// then far). Screenshots: core dropped, carrying, set in the near socket, set
// in the far socket, the reaper's half-HP core, and the result screen; desktop
// 1280x720 and phone landscape 844x390.
//
// Each screenshot is measured from the HUD probe: every core mark (sockets,
// core, seconds dot, ground plate, verdict plate, socket tags) against the HUD
// areas the game reserves (buttons, top bar, score, minimap, notice), the touch
// joystick, the screen edge and the other marks; and the top bar's second line
// against its box. The game is never paused, edited or given HP.
//
// Usage: node tools/r48_forge_capture.cjs [desktop] [phone]
//   R48_URL         served Web export (default http://127.0.0.1:8148/)
//   R48_OUT         output folder (default docs/content/r48)
//   R48_PLAYWRIGHT  node_modules holding playwright-core (read only)
//   R48_TAG         file name prefix (default "")
//   R48_RESUME=1    keep the shots already in this view's JSON, play on for the rest
//   R48_ATTEMPTS / R48_RUN_MINUTES   natural runs per view (3) / minutes per run (18)
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const PW = process.env.R48_PLAYWRIGHT || 'C:/Users/digimkt/Desktop/遊戲/pixel-idle-farm-skill/node_modules';
const { chromium } = require(path.join(PW, 'playwright-core'));
const BASE = process.env.R48_URL || 'http://127.0.0.1:8148/';
const OUT = path.resolve(process.env.R48_OUT || path.join(__dirname, '..', 'docs', 'content', 'r48'));
const TAG = process.env.R48_TAG || '';
const VIEWS = {
	desktop: { width: 1280, height: 720, dpr: 1, mobile: false },
	phone: { width: 844, height: 390, dpr: 2, mobile: true },
};
let JSON_NAME = 'forge-capture.json';
const SHOTS = ['drop', 'carry', 'near', 'far', 'boss-drop', 'result'];
const MAX_ATTEMPTS = Number(process.env.R48_ATTEMPTS || 3);
const RUN_LIMIT_MS = Number(process.env.R48_RUN_MINUTES || 18) * 60 * 1000;
const UA = 'Mozilla/5.0 (Linux; Android 15; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);

// ---- geometry -------------------------------------------------------------
const area = (r) => Math.max(0, r[2]) * Math.max(0, r[3]);
function cut(a, b) {
	const x = Math.max(a[0], b[0]), y = Math.max(a[1], b[1]);
	const w = Math.min(a[0] + a[2], b[0] + b[2]) - x, h = Math.min(a[1] + a[3], b[1] + b[3]) - y;
	return w > 0 && h > 0 ? w * h : 0;
}
const round = (r) => r.map((v) => Math.round(v * 10) / 10);
// Marks that carry words or numbers must be fully readable; the sockets and
// the core must not hide under HUD buttons or panels.
const TEXT_MARKS = ['plate', 'verdict', 'digit', 'tag_near', 'tag_far'];
const BODY_MARKS = ['near', 'far', 'core', 'ring'];
// Pairs of marks that are allowed to touch by design.
const PAIR_OK = new Set(['core|ring', 'ring|core', 'tag_near|near', 'near|tag_near', 'tag_far|far', 'far|tag_far', 'digit|ring', 'ring|digit', 'digit|core', 'core|digit']);

function measure(s, view) {
	const hud = s.hud;
	const f = hud.flags;
	const W = hud.viewport_width, H = hud.viewport_height;
	const fm = f.forge_marks || {};
	const marks = fm.rects || {};
	const blockers = Object.entries(f.hud_areas || {}).map(([id, r]) => ({ id, r }));
	const joy = hud.controls.virtual_joystick;
	if (joy && joy.exists && joy.visible) blockers.push({ id: 'virtual_joystick', r: [joy.x, joy.y, joy.width, joy.height] });
	const hudHits = [], markHits = [], offscreen = [];
	// Words (plates, tags, seconds) under the HUD are failures; a socket or core
	// drawing that slid partly under it as the camera followed the captain is
	// recorded separately (its tag must then still be readable).
	for (const [id, r] of Object.entries(marks)) {
		if (!TEXT_MARKS.includes(id) && !BODY_MARKS.includes(id)) continue;
		for (const b of blockers) {
			const a = cut(r, b.r);
			if (a > 0.5) hudHits.push({ mark: id, kind: TEXT_MARKS.includes(id) ? 'text' : 'body', hud: b.id, area: Math.round(a), share: Math.round((a / Math.max(1, area(r))) * 100) });
		}
		const inside = cut(r, [0, 0, W, H]);
		if (inside < area(r) - 0.5) offscreen.push({ mark: id, rect: round(r), visible_share: Math.round((inside / Math.max(1, area(r))) * 100) });
	}
	const ids = Object.keys(marks);
	for (let i = 0; i < ids.length; i++) for (let j = i + 1; j < ids.length; j++) {
		const a = ids[i], b = ids[j];
		if (!TEXT_MARKS.includes(a) && !TEXT_MARKS.includes(b)) continue;
		if (PAIR_OK.has(a + '|' + b)) continue;
		const c = cut(marks[a], marks[b]);
		if (c > 0.5) markHits.push({ a, b, area: Math.round(c) });
	}
	const fit = f.mission_fit || {};
	const plate = marks.plate || marks.verdict;
	return {
		view, viewport: [W, H],
		state: { done: fm.done, solved: fm.solved, carried: fm.carried, socket: fm.socket, seconds: fm.seconds },
		marks: Object.fromEntries(Object.entries(marks).map(([k, v]) => [k, round(v)])),
		points: fm.at || {},
		spawned: fm.spawned || {},
		hud_hits: hudHits,
		mark_hits: markHits,
		offscreen,
		mission: { text: f.mission_text, size: fit.size, widest: fit.widest, room: fit.room, fits: fit.widest !== undefined ? fit.widest <= fit.room + 0.5 : null },
		// plates are drawn 28 units tall with 18-unit text (verdict 30 / 20)
		plate_text_px: plate ? Math.round((plate[3] / (marks.plate ? 28 : 30)) * (marks.plate ? 18 : 20) * 10) / 10 : null,
		tag_text_px: marks.tag_near ? Math.round((marks.tag_near[3] / 30) * 24 * 10) / 10 : null,
		notice: f.notice_text,
	};
}

// ---- page helpers ---------------------------------------------------------
async function read(page) {
	return page.evaluate(() => {
		const c = window.__cvR19Controls || {};
		const rt = window.__cvR32Runtime || null;
		return {
			hud: c.hud || null, level: c.level_up || null, shop: c.shop || null, result: c.result || null,
			guide: c.guide || null, menu: c.main_menu || null, contract: c.contract || null,
			rt: rt ? { elapsed: rt.elapsed_time, hp: rt.hp, max_hp: rt.max_hp, bosses: rt.bosses || [], fps: rt.fps } : null,
			k: window.innerWidth,
		};
	});
}
const scale = (s, probe) => s.k / Math.max(1, probe.viewport_width);

class Driver {
	constructor(page, cdp, view, conf) { this.page = page; this.cdp = cdp; this.view = view; this.conf = conf; this.keys = new Set(); this.touch = null; }
	async tap(probe, id, s) {
		const c = probe.controls[id];
		if (!c || !c.visible) return false;
		const k = scale(s, probe);
		await this.release();
		if (this.conf.mobile) await this.page.touchscreen.tap(c.center_x * k, c.center_y * k);
		else await this.page.mouse.click(c.center_x * k, c.center_y * k);
		await sleep(150);
		return true;
	}
	async steer(dir, s) {
		if (this.conf.mobile) return this.stick(dir, s);
		const want = new Set();
		if (dir) {
			const n = Math.hypot(dir[0], dir[1]) || 1, x = dir[0] / n, y = dir[1] / n;
			if (x > 0.38) want.add('d'); else if (x < -0.38) want.add('a');
			if (y > 0.38) want.add('s'); else if (y < -0.38) want.add('w');
		}
		for (const key of [...this.keys]) if (!want.has(key)) { await this.page.keyboard.up(key); this.keys.delete(key); }
		for (const key of want) if (!this.keys.has(key)) { await this.page.keyboard.down(key); this.keys.add(key); }
	}
	async stick(dir, s) {
		const joy = s.hud && s.hud.controls.virtual_joystick;
		if (!dir || !joy || !joy.visible) return this.release();
		const k = scale(s, s.hud);
		const n = Math.hypot(dir[0], dir[1]) || 1;
		const cx = (joy.x + joy.width * 0.5) * k, cy = (joy.y + joy.height * 0.5) * k, r = Math.min(joy.width, joy.height) * 0.36 * k;
		const point = { x: cx + (dir[0] / n) * r, y: cy + (dir[1] / n) * r, id: 1 };
		if (!this.touch) {
			await this.cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: cx, y: cy, id: 1 }] });
			this.touch = { x: cx, y: cy };
		}
		await this.cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [point] });
		this.touch = point;
	}
	async release() {
		for (const key of [...this.keys]) { await this.page.keyboard.up(key); this.keys.delete(key); }
		if (this.touch) { await this.cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); this.touch = null; }
	}
}

// ---- one natural attempt ----------------------------------------------------
async function attempt(browser, view, conf, have, rows, n, flush) {
	// The result screen is always taken from the latest attempt that reaches it.
	delete have.result;
	const context = await browser.newContext({ viewport: { width: conf.width, height: conf.height }, deviceScaleFactor: conf.dpr, hasTouch: conf.mobile, isMobile: conf.mobile, userAgent: conf.mobile ? UA : undefined, serviceWorkers: 'block' });
	const page = await context.newPage();
	const errors = [];
	page.on('pageerror', (e) => errors.push(String(e)));
	page.on('console', (m) => {
		const t = m.text();
		if (m.type() !== 'error') return;
		if (/invalid UID|resource_format_binary\.cpp|GDScript backtrace|^\s+\[\d+\]/.test(t)) return;
		errors.push(t);
	});
	const cdp = await context.newCDPSession(page);
	const drive = new Driver(page, cdp, view, conf);
	const url = new URL(BASE);
	url.pathname = url.pathname.replace(/\/?$/, '/') + 'index.html';
	for (const [k, v] of Object.entries({ cv_r19_test: '1', cv_r32_test: '1', cv_start_stage: 'forge' })) url.searchParams.set(k, v);
	await page.goto(url.href, { timeout: 120000 });
	const renderer = await page.evaluate(() => {
		const c = document.createElement('canvas'), gl = c.getContext('webgl2') || c.getContext('webgl');
		const ext = gl && gl.getExtension('WEBGL_debug_renderer_info');
		return gl ? String(gl.getParameter(ext ? ext.UNMASKED_RENDERER_WEBGL : gl.RENDERER)) : 'none';
	});
	if (!/SwiftShader/i.test(renderer)) throw new Error('hardware renderer refused: ' + renderer);
	await page.waitForFunction(() => window.__cvR19Controls && window.__cvR19Controls.main_menu, null, { timeout: 180000 });
	let s = await read(page);
	await drive.tap(s.menu, 'start', s);
	log(view, 'attempt', n, 'start pressed; renderer', renderer);
	const t0 = Date.now();
	let threat = null, threatAt = 0; // direction captain -> latest core (toward whoever threw it), and when
	let live = false, coreIndex = 0, pickedAt = 0, seenAt = 0, plan = 'near', bossCore = false, lastElapsed = -1, stallSince = Date.now();
	const summary = { attempt: n, renderer, cores: 0, delivered: [], overloads: 0, result: null, errors };
	while (Date.now() - t0 < RUN_LIMIT_MS) {
		s = await read(page);
		const shotNow = async (name, extra = {}) => {
			if (have[name]) return false;
			await drive.release();
			let before = await read(page);
			if (name !== 'result') {
				// Battle shots only while the run clock moves (no level-up or shop on top).
				await sleep(250);
				const later = await read(page);
				if (!before.rt || !later.rt || later.rt.elapsed <= before.rt.elapsed) return false;
				before = later;
			}
			const file = `${TAG}${view}-${String(SHOTS.indexOf(name) + 1).padStart(2, '0')}-${name}.png`;
			await page.screenshot({ path: path.join(OUT, file) });
			const row = { shot: name, file, attempt: n, elapsed: before.rt ? before.rt.elapsed : null, fps: before.rt ? before.rt.fps : null, ...extra };
			if (name !== 'result' && before.hud) row.measure = measure(before, view);
			rows.push(row);
			have[name] = true;
			flush();
			log(view, 'shot', file, row.measure ? `text_under_hud=${row.measure.hud_hits.filter((h) => h.kind === 'text').length} body_under_hud=${row.measure.hud_hits.filter((h) => h.kind === 'body').length} mark_hits=${row.measure.mark_hits.length} offscreen=${row.measure.offscreen.length}` : '');
			return true;
		};
		// The result screens publish once while they are built; only a payload
		// newer than the running HUD's means the run really ended.
		const resultUp = s.result && s.result.flags && s.result.flags.visible && s.hud && s.result.timestamp_msec > s.hud.timestamp_msec + 300;
		if (resultUp) {
			await drive.release();
			await sleep(1500);
			s = await read(page);
			summary.result = { victory: s.result.flags.victory, summary: s.result.flags.summary, cards: s.result.flags.cards };
			await shotNow('result', { victory: s.result.flags.victory });
			// The stage tally card (戰況統計) lives on a later tab; capture it too.
			const pagesSeen = [];
			for (const tab of [0, 1, 2]) {
				s = await read(page);
				if (!(await drive.tap(s.result, 'tab_' + tab, s))) continue;
				await sleep(600);
				s = await read(page);
				const cards = s.result.flags.cards || [];
				pagesSeen.push({ tab, cards });
				if (cards.some((c) => String(c).includes('戰況統計'))) {
					const file = `${TAG}${view}-07-result-tally.png`;
					await page.screenshot({ path: path.join(OUT, file) });
					const ctrls = Object.entries(s.result.controls).filter(([, c]) => c.visible).map(([id, c]) => ({ id, r: [c.x, c.y, c.width, c.height] }));
					rows.push({ shot: 'result-tally', file, attempt: n, cards, controls: ctrls });
					log(view, 'shot', file);
					break;
				}
			}
			summary.result.tabs = pagesSeen;
			break;
		}
		if (s.rt && s.rt.elapsed !== lastElapsed) { lastElapsed = s.rt.elapsed; stallSince = Date.now(); }
		// A modal counts as open when its payload is newer than the HUD's or
		// the run clock has stopped (a stale payload from its build is ignored).
		const stalled = Date.now() - stallSince > 1500;
		const open = (p) => p && p.flags && p.flags.visible && (stalled || !s.hud || p.timestamp_msec > s.hud.timestamp_msec);
		if (open(s.level)) { await drive.tap(s.level, 'card_0', s); await sleep(400); continue; }
		if (open(s.shop)) { await drive.tap(s.shop, 'skip', s); await sleep(400); continue; }
		if (open(s.guide)) { if (!(await drive.tap(s.guide, 'start', s))) await drive.tap(s.guide, 'skip', s); await sleep(400); continue; }
		if (open(s.contract)) { await drive.tap(s.contract, 'first_option', s); await sleep(400); continue; }
		if (!s.hud) { await sleep(200); continue; }
		const f = s.hud.flags;
		if (f.paused) { await drive.tap(s.hud, 'pause_resume', s); continue; }
		if (s.hud.controls.audio_prompt && s.hud.controls.audio_prompt.visible) { await drive.tap(s.hud, 'audio_prompt', s); continue; }
		if (Date.now() - stallSince > 20000) {
			const file = `${TAG}${view}-stall-${n}.png`;
			await page.screenshot({ path: path.join(OUT, file) });
			throw new Error('run stalled (elapsed not moving 20s); see ' + file);
		}
		const fm = f.forge_marks || {};
		const at = fm.at || {};
		const coreLive = fm.rects && fm.done === false;
		const bossPhase2 = s.rt && s.rt.bosses.some((b) => b.phase_two);
		if (coreLive && !live) {
			live = true; coreIndex += 1; summary.cores = coreIndex; pickedAt = 0;
			bossCore = bossPhase2 && !have['boss-drop'];
			plan = !have.near && !bossCore ? 'near' : 'far';
			log(view, `core #${coreIndex} at t=${s.rt && s.rt.elapsed.toFixed(1)} plan=${plan}${bossCore ? ' (boss half HP)' : ''}`);
			seenAt = Date.now();
			if (at.core && at.captain) { threat = [at.core[0] - at.captain[0], at.core[1] - at.captain[1]]; threatAt = Date.now(); }
		}
		const dropShot = bossCore ? 'boss-drop' : 'drop';
		if (coreLive && !fm.carried && !have[dropShot] && Date.now() - seenAt > 350) {
			if (await shotNow(dropShot, bossCore ? { boss: s.rt.bosses.map((b) => ({ pattern: b.pattern, phase_two: b.phase_two, volleys: b.volleys })) } : {})) continue;
		}
		if (live && fm.done) {
			live = false;
			if (fm.solved) { summary.delivered.push(fm.socket); log(view, `core #${coreIndex} set in ${fm.socket}`); }
			else { summary.overloads += 1; log(view, `core #${coreIndex} overloaded`); }
		}
		// The verdict plate stays up for two seconds; retry until a clean frame.
		if (fm.rects && fm.done && fm.solved && !have[fm.socket]) { if (await shotNow(fm.socket)) continue; }
		if (!fm.rects) live = false;
		let dir = null;
		// Victory also needs all three 封隙 seals, which this bot does not play,
		// so once every battle shot is in (and this run has set two cores, so
		// the result has a gear-core line) the run is ended by a defeat: the bot
		// walks a few seconds toward whoever threw the latest core (the reaper's
		// cores drop on the line toward it), then stands, and leaves cores alone.
		const endPhase = SHOTS.every((x) => x === 'result' || have[x]) && summary.delivered.length >= 2;
		if (endPhase) {
			dir = threat && Date.now() - threatAt < 6000 ? threat : null;
		} else if (coreLive && !fm.carried && !have[dropShot]) {
			dir = null; // let the drop be seen before walking onto it
		} else if (coreLive && at.captain) {
			if (fm.carried && !pickedAt) pickedAt = Date.now();
			if (fm.carried && pickedAt && Date.now() - pickedAt > 450 && !have.carry) { if (await shotNow('carry')) continue; }
			const target = fm.carried ? at[plan] : at.core;
			if (target) dir = [target[0] - at.captain[0], target[1] - at.captain[1]];
			if (dir && Math.hypot(dir[0], dir[1]) < 3) dir = null;
		} else {
			// No core: keep moving on a wide loop so the squad is not pinned.
			const a = (s.rt ? s.rt.elapsed : 0) * 0.45;
			dir = [Math.cos(a), Math.sin(a)];
		}
		await drive.steer(dir, s);
		await sleep(40);
	}
	await drive.release();
	summary.errors = errors;
	await context.close();
	return summary;
}

async function main() {
	fs.mkdirSync(OUT, { recursive: true });
	const views = process.argv.slice(2).filter((v) => VIEWS[v]);
	const pick = views.length ? views : Object.keys(VIEWS);
	JSON_NAME = `${TAG}forge-capture-${pick.join('+')}.json`;
	const browser = await chromium.launch({ headless: true, args: ['--mute-audio', '--disable-gpu', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
	const report = { generated_utc: new Date().toISOString(), url: BASE, rendering: 'headless Chromium, --disable-gpu + SwiftShader', views: {} };
	let failed = false;
	try {
		for (const view of pick) {
			const conf = VIEWS[view];
			const have = {}, rows = [], attempts = [];
			// R48_RESUME=1 keeps the shots already in this view's JSON (same
			// build) and only plays on for the missing ones (e.g. the result).
			const previous = path.join(OUT, JSON_NAME);
			if (process.env.R48_RESUME === '1' && fs.existsSync(previous)) {
				const old = JSON.parse(fs.readFileSync(previous, 'utf8')).views?.[view];
				for (const row of old?.shots || []) if (!row.shot.startsWith('result') && fs.existsSync(path.join(OUT, row.file))) { rows.push({ ...row, resumed: true }); if (SHOTS.includes(row.shot)) have[row.shot] = true; }
				for (const a of old?.attempts || []) attempts.push({ ...a, resumed: true });
			}
			for (let n = 1; n <= MAX_ATTEMPTS && SHOTS.some((x) => !have[x]); n++) {
				const flush = () => { report.views[view] = { viewport: [conf.width, conf.height], dpr: conf.dpr, input: conf.mobile ? 'touch joystick (CDP touch events)' : 'keyboard WASD', missing: SHOTS.filter((x) => !have[x]), attempts, shots: rows }; fs.writeFileSync(path.join(OUT, JSON_NAME), JSON.stringify(report, null, 1)); };
				try { attempts.push(await attempt(browser, view, conf, have, rows, n, flush)); }
				catch (e) { attempts.push({ attempt: n, error: String(e && e.stack || e) }); log(view, 'attempt', n, 'failed', String(e)); }
			}
			const missing = SHOTS.filter((x) => !have[x]);
			if (missing.length) failed = true;
			report.views[view] = { viewport: [conf.width, conf.height], dpr: conf.dpr, input: conf.mobile ? 'touch joystick (CDP touch events)' : 'keyboard WASD', missing, attempts, shots: rows };
			fs.writeFileSync(path.join(OUT, JSON_NAME), JSON.stringify(report, null, 1));
		}
	} finally {
		await browser.close();
	}
	const problems = [], notes = [];
	for (const [view, v] of Object.entries(report.views)) for (const row of v.shots) {
		const m = row.measure;
		if (!m) continue;
		for (const h of m.hud_hits) (h.kind === 'text' ? problems : notes).push(`${view}/${row.shot}: ${h.mark} under ${h.hud} (${h.share}%)`);
		for (const h of m.mark_hits) problems.push(`${view}/${row.shot}: ${h.a} overlaps ${h.b}`);
		for (const o of m.offscreen) problems.push(`${view}/${row.shot}: ${o.mark} off screen (${o.visible_share}% visible)`);
		if (m.mission.fits === false) problems.push(`${view}/${row.shot}: top bar line wider than its box`);
	}
	report.problems = problems;
	report.notes = notes;
	fs.writeFileSync(path.join(OUT, JSON_NAME), JSON.stringify(report, null, 1));
	console.log(problems.length ? 'PROBLEMS\n' + problems.join('\n') : 'NO LAYOUT PROBLEMS');
	if (notes.length) console.log('NOTES (socket/core drawing under HUD after the camera followed the captain)\n' + notes.join('\n'));
	console.log(failed ? 'R48_FORGE_CAPTURE status=INCOMPLETE' : 'R48_FORGE_CAPTURE status=CAPTURED');
	process.exitCode = failed ? 1 : 0;
}

main().catch((e) => { console.error(e); process.exitCode = 2; });
