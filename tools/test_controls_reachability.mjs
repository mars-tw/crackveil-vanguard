import fs from "node:fs/promises";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const playwrightRoot = process.env.UI_CAPTURE_PLAYWRIGHT;
if (!playwrightRoot) {
	throw new Error("UI_CAPTURE_PLAYWRIGHT must point to a node_modules directory containing playwright-core");
}

const { chromium } = require(path.join(playwrightRoot, "playwright-core"));
const chromePath = process.env.UI_CAPTURE_CHROME ?? "C:/Program Files/Google/Chrome/Application/chrome.exe";
const targetUrl = new URL(process.env.UI_CAPTURE_URL ?? "http://127.0.0.1:8067/");
targetUrl.searchParams.set("cv_r19_test", "1");
targetUrl.searchParams.set("cv_r22_test", "1");
const evidenceDir = path.resolve(process.env.UI_CAPTURE_EVIDENCE_DIR ?? "docs/evidence/R22_controls");

const desktopUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36";
const mobileUserAgent = "Mozilla/5.0 (Linux; Android 15; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36";
const matrix = [
	{ width: 1920, height: 1080, touch: false, evidence: "1920x1080_main_menu.png" },
	{ width: 1440, height: 780, touch: false },
	{ width: 1366, height: 600, touch: false, evidence: "1366x600_pause.png" },
	{ width: 1280, height: 640, touch: false },
	{ width: 390, height: 844, touch: true, dpr: 3, evidence: "390x844_touch_controls.png" },
	{ width: 844, height: 390, touch: true, dpr: 3, evidence: "844x390_touch_controls.png" },
	{ width: 1024, height: 768, touch: true, dpr: 2, evidence: "1024x768_touch_controls.png" },
	{ width: 1366, height: 600, touch: true, coarseOnly: true, dpr: 1, evidence: "1366x600_coarse_touch.png" },
];

function invariant(condition, message) {
	if (!condition) {
		throw new Error(message);
	}
}

function isKnownConsoleNoise(text) {
	return text.includes("Failed to load resource: the server responded with a status of 404")
		|| (text.includes("WARNING: 'res://") && text.includes("invalid UID:") && text.includes("using text path instead"))
		|| text.includes("at: open (core/io/resource_format_binary.cpp:1028)");
}

async function readProbe(page, scope) {
	return page.evaluate((probeScope) => {
		const probe = window.__cvR22Controls?.[probeScope] ?? window.__cvR19Controls?.[probeScope] ?? null;
		if (!probe) return null;
		const normalized = structuredClone(probe);
		const scaleX = window.innerWidth / Math.max(1, Number(probe.viewport_width ?? window.innerWidth));
		const scaleY = window.innerHeight / Math.max(1, Number(probe.viewport_height ?? window.innerHeight));
		for (const control of Object.values(normalized.controls ?? {})) {
			if (!control?.exists) continue;
			control.x *= scaleX;
			control.y *= scaleY;
			control.width *= scaleX;
			control.height *= scaleY;
			control.center_x *= scaleX;
			control.center_y *= scaleY;
		}
		normalized.viewport_width = window.innerWidth;
		normalized.viewport_height = window.innerHeight;
		return normalized;
	}, scope);
}

async function waitForProbe(page, scope, flag = null, expected = null) {
	await page.waitForFunction(
		({ probeScope, probeFlag, probeExpected }) => {
			const probe = window.__cvR19Controls?.[probeScope];
			if (!probe) return false;
			return probeFlag === null || probe.flags?.[probeFlag] === probeExpected;
		},
		{ probeScope: scope, probeFlag: flag, probeExpected: expected },
		{ timeout: 30000 },
	);
	return readProbe(page, scope);
}

async function assertCanvasFillsViewport(page, viewport) {
	const box = await page.locator("#canvas").boundingBox();
	invariant(box !== null, `${viewport.width}x${viewport.height}: canvas missing`);
	invariant(Math.abs(box.x) <= 1 && Math.abs(box.y) <= 1, `${viewport.width}x${viewport.height}: canvas offset ${JSON.stringify(box)}`);
	invariant(Math.abs(box.width - viewport.width) <= 1 && Math.abs(box.height - viewport.height) <= 1, `${viewport.width}x${viewport.height}: canvas does not fill viewport ${JSON.stringify(box)}`);
}

async function assertProbeControls(page, probe, controlNames, viewport, label) {
	invariant(probe !== null, `${label}: missing Godot reachability probe`);
	for (const name of controlNames) {
		const control = probe.controls?.[name];
		invariant(control?.exists, `${label}/${name}: control missing`);
		invariant(control.visible, `${label}/${name}: control hidden`);
		invariant(control.height >= 43.5, `${label}/${name}: hit height ${control.height} below 44px`);
		invariant(control.center_x >= 0 && control.center_x <= viewport.width, `${label}/${name}: center x outside viewport`);
		invariant(control.center_y >= 0 && control.center_y <= viewport.height, `${label}/${name}: center y outside viewport`);
		const hit = await page.evaluate(
			({ x, y }) => {
				const element = document.elementFromPoint(x, y);
				return element ? { id: element.id, tag: element.tagName } : null;
			},
			{ x: control.center_x, y: control.center_y },
		);
		invariant(hit?.id === "canvas", `${label}/${name}: elementFromPoint missed Godot canvas: ${JSON.stringify(hit)}`);
	}
}

async function clickProbeControl(page, probe, name) {
	const control = probe.controls?.[name];
	invariant(control?.visible, `${probe.scope}/${name}: cannot click hidden control`);
	await page.mouse.click(control.center_x, control.center_y);
}

function rectOf(control) {
	return {
		x: control.x,
		y: control.y,
		right: control.x + control.width,
		bottom: control.y + control.height,
		width: control.width,
		height: control.height,
	};
}

function rectsOverlap(a, b) {
	return a.x < b.right && a.right > b.x && a.y < b.bottom && a.bottom > b.y;
}

function assertNoProbeOverlaps(probe, controlNames, label) {
	const visibleRects = [];
	for (const name of controlNames) {
		const control = probe.controls?.[name];
		if (!control?.exists || !control.visible) continue;
		visibleRects.push({ name, rect: rectOf(control) });
	}
	for (let i = 0; i < visibleRects.length; i += 1) {
		for (let j = i + 1; j < visibleRects.length; j += 1) {
			invariant(!rectsOverlap(visibleRects[i].rect, visibleRects[j].rect), `${label}: ${visibleRects[i].name} overlaps ${visibleRects[j].name}`);
		}
	}
}

async function exerciseTwoFingerTouch(page, hudProbe, viewport) {
	const joystick = hudProbe.controls?.virtual_joystick;
	const ability = hudProbe.controls?.active_ability;
	if (!joystick?.visible || !ability?.visible) return;
	const joyX = Math.max(2, joystick.center_x - joystick.width * 0.18);
	const joyY = joystick.center_y;
	const abilityX = ability.center_x;
	const abilityY = ability.center_y;
	await page.dispatchEvent("#canvas", "touchstart", {
		touches: [
			{ identifier: 1, clientX: joyX, clientY: joyY },
			{ identifier: 2, clientX: abilityX, clientY: abilityY },
		],
		targetTouches: [
			{ identifier: 1, clientX: joyX, clientY: joyY },
			{ identifier: 2, clientX: abilityX, clientY: abilityY },
		],
		changedTouches: [
			{ identifier: 1, clientX: joyX, clientY: joyY },
			{ identifier: 2, clientX: abilityX, clientY: abilityY },
		],
	});
	await page.waitForTimeout(80);
	await page.dispatchEvent("#canvas", "touchend", {
		touches: [{ identifier: 1, clientX: joyX, clientY: joyY }],
		targetTouches: [{ identifier: 1, clientX: joyX, clientY: joyY }],
		changedTouches: [{ identifier: 2, clientX: abilityX, clientY: abilityY }],
	});
	await page.waitForTimeout(80);
	await page.dispatchEvent("#canvas", "touchend", {
		touches: [],
		targetTouches: [],
		changedTouches: [{ identifier: 1, clientX: joyX, clientY: joyY }],
	});
	const latest = await readProbe(page, "hud");
	invariant(latest !== null, `${viewport.width}x${viewport.height}: hud probe missing after two-finger touch`);
}

await fs.mkdir(evidenceDir, { recursive: true });
const browser = await chromium.launch({
	executablePath: chromePath,
	headless: true,
	args: ["--disable-dev-shm-usage", "--ignore-gpu-blocklist", "--enable-webgl"],
});
const results = [];

try {
	for (const viewport of matrix) {
		const context = await browser.newContext({
			viewport: { width: viewport.width, height: viewport.height },
			hasTouch: viewport.touch,
			isMobile: viewport.touch,
			deviceScaleFactor: viewport.dpr ?? 1,
			userAgent: viewport.touch ? mobileUserAgent : desktopUserAgent,
		});
		if (!viewport.touch) {
			await context.addInitScript(() => {
				Object.defineProperty(Navigator.prototype, "maxTouchPoints", { configurable: true, get: () => 0 });
			});
		} else if (viewport.coarseOnly) {
			await context.addInitScript(() => {
				Object.defineProperty(Navigator.prototype, "maxTouchPoints", { configurable: true, get: () => 5 });
			});
		}
		const page = await context.newPage();
		const pageErrors = [];
		const consoleErrors = [];
		const requestFailures = [];
		page.on("pageerror", (error) => pageErrors.push(error.message));
		page.on("console", (message) => {
			if (message.type() === "error" && !isKnownConsoleNoise(message.text())) consoleErrors.push(`${message.type()}: ${message.text()}`);
		});
		page.on("requestfailed", (request) => requestFailures.push(`${request.url()} ${request.failure()?.errorText ?? ""}`));
		await page.goto(targetUrl.href, { waitUntil: "load", timeout: 60000 });
		await page.locator("#canvas").waitFor({ state: "visible", timeout: 30000 });
		const mainProbe = await waitForProbe(page, "main_menu");
		await assertCanvasFillsViewport(page, viewport);

		const device = await page.evaluate(() => ({
			maxTouchPoints: navigator.maxTouchPoints,
			primaryCoarse: matchMedia("(pointer: coarse)").matches,
			finePointer: matchMedia("(any-pointer: fine)").matches,
			domVirtualControls: document.querySelectorAll("[id*='joystick' i],[class*='joystick' i],[id*='ability' i],[class*='ability' i]").length,
		}));
		if (viewport.touch) {
			invariant(device.maxTouchPoints > 0 || device.primaryCoarse, `${viewport.width}x${viewport.height}: touch emulation not active`);
		} else {
			invariant(device.maxTouchPoints === 0, `${viewport.width}x${viewport.height}: desktop maxTouchPoints=${device.maxTouchPoints}`);
			invariant(!device.primaryCoarse, `${viewport.width}x${viewport.height}: desktop primary pointer is coarse`);
		}

		await assertProbeControls(page, mainProbe, ["start", "guide", "meta", "achievements", "settings", "seed_input", "seed_start"], viewport, `${viewport.width}x${viewport.height}/main`);
		assertNoProbeOverlaps(mainProbe, ["start", "guide", "meta", "achievements", "settings", "seed_input", "seed_start"], `${viewport.width}x${viewport.height}/main`);
		if (viewport.evidence === "1920x1080_main_menu.png") {
			await page.locator("#canvas").screenshot({ path: path.join(evidenceDir, viewport.evidence) });
		}

		await clickProbeControl(page, mainProbe, "settings");
		const settingsProbe = await waitForProbe(page, "main_menu", "side_panel_visible", true);
		await assertProbeControls(page, settingsProbe, ["side_panel", "side_close"], viewport, `${viewport.width}x${viewport.height}/settings`);
		await clickProbeControl(page, settingsProbe, "side_close");
		await page.waitForTimeout(100);
		const closedProbe = await readProbe(page, "main_menu");
		await clickProbeControl(page, closedProbe, "start");

		await waitForProbe(page, "contract", "visible", true);
		for (let guideStep = 0; guideStep < 8; guideStep += 1) {
			const guideProbe = await readProbe(page, "guide");
			if (!guideProbe?.flags?.visible) break;
			await assertProbeControls(page, guideProbe, ["dont_show", "start"], viewport, `${viewport.width}x${viewport.height}/guide`);
			await clickProbeControl(page, guideProbe, "start");
			await page.waitForTimeout(150);
		}
		const finalGuideProbe = await readProbe(page, "guide");
		invariant(!finalGuideProbe?.flags?.visible, `${viewport.width}x${viewport.height}: guide did not close after paging`);

		const contractProbe = await readProbe(page, "contract");
		await assertProbeControls(page, contractProbe, ["first_option"], viewport, `${viewport.width}x${viewport.height}/contract`);
		await clickProbeControl(page, contractProbe, "first_option");
		if (viewport.touch) {
			await page.waitForTimeout(80);
			await clickProbeControl(page, await readProbe(page, "contract"), "first_option");
		}

		const hudProbe = await waitForProbe(page, "hud", "paused", false);
		await assertProbeControls(page, hudProbe, ["pause"], viewport, `${viewport.width}x${viewport.height}/hud`);
		assertNoProbeOverlaps(hudProbe, ["pause", "quick_mute", "quick_screen_shake", "quick_joystick_size", "virtual_joystick", "active_ability"], `${viewport.width}x${viewport.height}/hud`);
		if (!viewport.touch) {
			invariant(hudProbe.flags?.confirmed_touch === false, `${viewport.width}x${viewport.height}: Godot detected false touch`);
			invariant(hudProbe.flags?.touch_controls_visible === false, `${viewport.width}x${viewport.height}: virtual joystick visible on desktop`);
			invariant(hudProbe.controls?.virtual_joystick?.visible === false, `${viewport.width}x${viewport.height}: joystick control visible`);
			invariant(hudProbe.controls?.active_ability?.visible === false, `${viewport.width}x${viewport.height}: right-bottom ability visible`);
		} else {
			invariant(hudProbe.flags?.confirmed_touch === true, `${viewport.width}x${viewport.height}: Godot missed confirmed touch`);
			invariant(hudProbe.flags?.touch_controls_visible === true, `${viewport.width}x${viewport.height}: virtual joystick hidden on touch`);
			invariant(hudProbe.controls?.virtual_joystick?.visible === true, `${viewport.width}x${viewport.height}: joystick control hidden`);
			await exerciseTwoFingerTouch(page, hudProbe, viewport);
			await page.locator("#canvas").screenshot({ path: path.join(evidenceDir, viewport.evidence) });
		}

		await clickProbeControl(page, hudProbe, "pause");
		const pauseProbe = await waitForProbe(page, "hud", "paused", true);
		await assertProbeControls(page, pauseProbe, ["pause_settings_tab", "pause_achievements_tab", "pause_run_tab", "pause_resume", "pause_high_contrast", "pause_ui_scale"], viewport, `${viewport.width}x${viewport.height}/pause`);
		invariant(pauseProbe.controls?.pause?.visible === false, `${viewport.width}x${viewport.height}: external pause button visible over pause panel`);
		invariant(pauseProbe.controls?.quick_controls?.visible === false, `${viewport.width}x${viewport.height}: quick controls visible over pause panel`);
		assertNoProbeOverlaps(pauseProbe, ["pause_settings_tab", "pause_achievements_tab", "pause_run_tab", "pause_resume", "pause_high_contrast", "pause_ui_scale"], `${viewport.width}x${viewport.height}/pause`);
		if (viewport.evidence && !viewport.touch && viewport.evidence !== "1920x1080_main_menu.png") {
			await page.locator("#canvas").screenshot({ path: path.join(evidenceDir, viewport.evidence) });
		}

		invariant(device.domVirtualControls === 0, `${viewport.width}x${viewport.height}: unexpected DOM virtual controls`);
		invariant(pageErrors.length === 0, `${viewport.width}x${viewport.height}: browser errors: ${pageErrors.join(" | ")}`);
		invariant(consoleErrors.length === 0, `${viewport.width}x${viewport.height}: console errors: ${consoleErrors.join(" | ")}`);
		invariant(requestFailures.length === 0, `${viewport.width}x${viewport.height}: request failures: ${requestFailures.join(" | ")}`);
		results.push({
			viewport: `${viewport.width}x${viewport.height}`,
			touch: viewport.touch,
			device,
			canvasHitMode: "Godot probe center + document.elementFromPoint(canvas host)",
			main: mainProbe.controls,
			pause: pauseProbe.controls,
			consoleErrors,
			requestFailures,
			status: "pass",
		});
		await context.close();
		console.log(`R22_CONTROLS_PASS ${viewport.width}x${viewport.height} touch=${viewport.touch} dpr=${viewport.dpr ?? 1}`);
	}
} finally {
	await browser.close();
}

await fs.writeFile(path.join(evidenceDir, "playwright_results.json"), `${JSON.stringify(results, null, 2)}\n`, "utf8");
console.log("R22_CONTROLS_REACHABILITY_PASS canvas_controls=godot_probe dom_hit=canvas_host overlap=asserted console=requests_clean");
