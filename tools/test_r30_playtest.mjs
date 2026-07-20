import fs from "node:fs/promises";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const playwrightRoot = process.env.UI_CAPTURE_PLAYWRIGHT;
if (!playwrightRoot) throw new Error("UI_CAPTURE_PLAYWRIGHT must point to node_modules containing playwright-core");
const { chromium } = require(path.join(playwrightRoot, "playwright-core"));

const chromePath = process.env.UI_CAPTURE_CHROME ?? "C:/Program Files/Google/Chrome/Application/chrome.exe";
const targetUrl = new URL(process.env.UI_CAPTURE_URL ?? "http://127.0.0.1:8067/");
targetUrl.searchParams.set("cv_r22_test", "1");
targetUrl.searchParams.set("cv_r30_test", "1");
const screenshotPath = path.resolve(process.env.R30_PLAYTEST_SCREENSHOT ?? "export/r30-844x390-combat.png");
const mobileUserAgent = "Mozilla/5.0 (Linux; Android 15; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36";

function invariant(condition, message) {
	if (!condition) throw new Error(message);
}

async function waitScope(page, scope, timeout = 120000) {
	await page.waitForFunction((name) => Boolean(window.__cvR22Controls?.[name]), scope, { timeout });
	return readScope(page, scope);
}

async function readScope(page, scope) {
	return page.evaluate((name) => {
		const probe = window.__cvR22Controls?.[name];
		if (!probe) return null;
		const data = structuredClone(probe);
		const scaleX = window.innerWidth / Math.max(1, Number(probe.viewport_width));
		const scaleY = window.innerHeight / Math.max(1, Number(probe.viewport_height));
		for (const control of Object.values(data.controls ?? {})) {
			if (!control?.exists) continue;
			control.x *= scaleX;
			control.y *= scaleY;
			control.width *= scaleX;
			control.height *= scaleY;
			control.center_x *= scaleX;
			control.center_y *= scaleY;
		}
		data.viewport_width = window.innerWidth;
		data.viewport_height = window.innerHeight;
		return data;
	}, scope);
}

async function waitNewScope(page, scope, timestamp, timeout = 30000) {
	await page.waitForFunction(
		({ name, oldTimestamp }) => Number(window.__cvR22Controls?.[name]?.timestamp_msec ?? 0) > oldTimestamp,
		{ name: scope, oldTimestamp: timestamp },
		{ timeout },
	);
	return readScope(page, scope);
}

async function tapControl(page, scope, name) {
	const data = await readScope(page, scope);
	const control = data?.controls?.[name];
	invariant(control?.exists && control.visible, `${scope}.${name} is not visible`);
	await page.touchscreen.tap(control.center_x, control.center_y);
}

function controlEnd(control) {
	return { x: control.x + control.width, y: control.y + control.height };
}

async function assertPortraitSeedRow(page) {
	const menu = await readScope(page, "main_menu");
	const row = menu.controls.seed_row;
	const input = menu.controls.seed_input;
	const button = menu.controls.seed_start;
	for (const [name, control] of [["row", row], ["input", input], ["button", button]]) {
		invariant(control?.visible, `portrait seed ${name} hidden after rotation`);
		const end = controlEnd(control);
		invariant(control.x >= -0.75 && end.x <= 390.75, `portrait seed ${name} clipped: ${JSON.stringify(control)}`);
	}
	invariant(row.width <= 354.75, `portrait seed row retained landscape width: ${row.width}`);
	return { row, input, button };
}

async function main() {
	const browser = await chromium.launch({ executablePath: chromePath, headless: true, args: ["--disable-gpu-sandbox"] });
	const context = await browser.newContext({
		viewport: { width: 390, height: 844 },
		screen: { width: 390, height: 844 },
		deviceScaleFactor: 2,
		isMobile: true,
		hasTouch: true,
		userAgent: mobileUserAgent,
		serviceWorkers: "allow",
	});
	const page = await context.newPage();
	try {
		await page.goto(targetUrl.href, { waitUntil: "commit", timeout: 30000 });
		let menu = await waitScope(page, "main_menu");
		await page.setViewportSize({ width: 844, height: 390 });
		menu = await waitNewScope(page, "main_menu", menu.timestamp_msec);
		await page.setViewportSize({ width: 390, height: 844 });
		menu = await waitNewScope(page, "main_menu", menu.timestamp_msec);
		await page.waitForTimeout(250);
		const seedLayout = await assertPortraitSeedRow(page);

		await page.setViewportSize({ width: 844, height: 390 });
		await waitNewScope(page, "main_menu", menu.timestamp_msec);
		await tapControl(page, "main_menu", "start");
		await waitScope(page, "guide", 30000);
		for (let pageIndex = 0; pageIndex < 5; pageIndex += 1) {
			const guide = await readScope(page, "guide");
			await tapControl(page, "guide", "start");
			await waitNewScope(page, "guide", guide.timestamp_msec);
		}
		await tapControl(page, "guide", "start");
		await page.waitForFunction(() => window.__cvR22Controls?.contract?.flags?.visible === true, null, { timeout: 30000 });
		await tapControl(page, "contract", "first_option");
		await page.waitForTimeout(250);
		await tapControl(page, "contract", "first_option");
		await waitScope(page, "hud", 30000);
		await page.waitForTimeout(1250);

		const hud = await readScope(page, "hud");
		const panel = hud.controls.hud_panel;
		const hp = hud.controls.hp_label;
		const level = hud.controls.level_label;
		const xp = hud.controls.xp_readout;
		const bar = hud.controls.xp_bar;
		invariant([panel, hp, level, xp, bar].every((control) => control?.visible), "844x390 HUD probe missing a visible stat row");
		invariant(controlEnd(hp).y + 1 <= level.y, `HP overlaps level: ${JSON.stringify({ hp, level })}`);
		invariant(controlEnd(level).y + 1 <= xp.y, `level overlaps XP: ${JSON.stringify({ level, xp })}`);
		invariant(controlEnd(xp).y + 1 <= bar.y, `XP text overlaps bar: ${JSON.stringify({ xp, bar })}`);
		for (const [name, control] of [["hp", hp], ["level", level], ["xp", xp], ["bar", bar]]) {
			const end = controlEnd(control);
			const panelEnd = controlEnd(panel);
			invariant(control.x >= panel.x - 1 && end.x <= panelEnd.x + 1 && control.y >= panel.y - 1 && end.y <= panelEnd.y + 1, `${name} escaped HUD panel`);
		}
		await fs.mkdir(path.dirname(screenshotPath), { recursive: true });
		await page.screenshot({ path: screenshotPath });

		const registration = await page.evaluate(async () => {
			const ready = await Promise.race([
				navigator.serviceWorker.ready,
				new Promise((resolve) => setTimeout(() => resolve(null), 20000)),
			]);
			const current = await navigator.serviceWorker.getRegistration();
			return {
				scope: ready?.scope ?? current?.scope ?? null,
				active: Boolean(ready?.active ?? current?.active),
				installing: current?.installing?.state ?? null,
				waiting: current?.waiting?.state ?? null,
				currentActive: current?.active?.state ?? null,
			};
		});
		invariant(registration.active, `R30 service worker did not activate: ${JSON.stringify(registration)}`);
		await context.setOffline(true);
		await page.reload({ waitUntil: "domcontentloaded", timeout: 30000 });
		const offlineTitle = await page.locator("h1").textContent({ timeout: 15000 });
		invariant(offlineTitle?.includes("裂隙需要連線"), `offline navigation did not show fallback: ${offlineTitle}`);
		await context.setOffline(false);

		console.log(JSON.stringify({
			result: "R30_PLAYWRIGHT_PASS",
			viewport: "844x390",
			hud: { panel, hp, level, xp, bar },
			rotationSeedRow: seedLayout,
			screenshot: screenshotPath,
			serviceWorker: registration,
			offlineTitle,
		}));
	} finally {
		await context.setOffline(false).catch(() => {});
		await browser.close();
	}
}

await main();
