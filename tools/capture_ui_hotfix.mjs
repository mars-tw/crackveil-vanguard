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
const targetUrl = process.env.UI_CAPTURE_URL ?? "http://127.0.0.1:8067/";
const outputDir = path.resolve("docs/ui_hotfix_r13");
const viewports = [
	{ width: 1920, height: 1080 },
	{ width: 1024, height: 768 },
	{ width: 390, height: 844 },
];

function menuCoordinates(viewport) {
	const phonePortrait = viewport.width <= 430 && viewport.height > viewport.width;
	if (phonePortrait) {
		const menuTop = 278;
		const buttonHeight = 76;
		const gap = 16;
		return {
			start: { x: viewport.width / 2, y: menuTop + buttonHeight / 2 },
			settings: { x: viewport.width / 2, y: menuTop + 3 * (buttonHeight + gap) + buttonHeight / 2 },
		};
	}
	return {
		start: { x: 163, y: 188 },
		settings: { x: 163, y: 368 },
	};
}

async function waitForGodot(page, coldStart = false) {
	await page.locator("#canvas").waitFor({ state: "visible", timeout: 30000 });
	// Godot renders UI inside WebGL canvas and exposes no DOM-ready marker.
	await page.waitForTimeout(coldStart ? 5500 : 3200);
}

async function captureCanvas(page, outputPath) {
	const dataUrl = await page.locator("#canvas").evaluate((canvas) => canvas.toDataURL("image/png"));
	await fs.writeFile(outputPath, Buffer.from(dataUrl.split(",", 2)[1], "base64"));
}

await fs.mkdir(outputDir, { recursive: true });
const browser = await chromium.launch({
	executablePath: chromePath,
	headless: false,
	args: ["--window-position=-32000,-32000", "--disable-dev-shm-usage", "--ignore-gpu-blocklist", "--enable-webgl"],
});

try {
	for (const viewport of viewports) {
		const context = await browser.newContext({ viewport });
		const page = await context.newPage();
		const browserErrors = [];
		page.on("pageerror", (error) => browserErrors.push(error.message));
		await page.goto(targetUrl, { waitUntil: "load", timeout: 60000 });
		await waitForGodot(page, true);
		const prefix = `${viewport.width}x${viewport.height}`;
		await captureCanvas(page, path.join(outputDir, `${prefix}_main_menu.png`));

		const coordinates = menuCoordinates(viewport);
		await page.mouse.click(coordinates.settings.x, coordinates.settings.y);
		await page.waitForTimeout(500);
		await captureCanvas(page, path.join(outputDir, `${prefix}_settings.png`));

		await page.reload({ waitUntil: "load", timeout: 60000 });
		await waitForGodot(page);
		await page.mouse.click(coordinates.start.x, coordinates.start.y);
		await page.waitForTimeout(2200);
		await captureCanvas(page, path.join(outputDir, `${prefix}_briefing.png`));
		if (browserErrors.length > 0) {
			throw new Error(`${prefix} browser errors: ${browserErrors.join(" | ")}`);
		}
		await context.close();
		console.log(`CAPTURE_PASS ${prefix}`);
	}
} finally {
	await browser.close();
}
