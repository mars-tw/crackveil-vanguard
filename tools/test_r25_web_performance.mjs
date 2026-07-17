import fs from "node:fs/promises";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const playwrightRoot = process.env.UI_CAPTURE_PLAYWRIGHT;
if (!playwrightRoot) throw new Error("UI_CAPTURE_PLAYWRIGHT must point to node_modules containing playwright-core");
const { chromium } = require(path.join(playwrightRoot, "playwright-core"));

const chromePath = process.env.UI_CAPTURE_CHROME ?? "C:/Program Files/Google/Chrome/Application/chrome.exe";
const targetUrlObject = new URL(process.env.R25_WEB_URL ?? "http://127.0.0.1:8067/");
targetUrlObject.searchParams.set("cv_r19_test", "1");
targetUrlObject.searchParams.set("cv_r22_test", "1");
const targetUrl = targetUrlObject.href;
const outputPath = path.resolve(process.env.R25_WEB_OUTPUT ?? "docs/evidence/R25/web_performance_after.json");
const screenshotPath = path.resolve(process.env.R25_WEB_SCREENSHOT ?? "docs/evidence/R25/browser/r25_main_focal_1280x720.png");
const baselinePath = process.env.R25_WEB_BASELINE_JSON ? path.resolve(process.env.R25_WEB_BASELINE_JSON) : null;
const mode = process.env.R25_WEB_MODE ?? "after";

function invariant(condition, message) {
	if (!condition) throw new Error(message);
}

await fs.mkdir(path.dirname(outputPath), { recursive: true });
await fs.mkdir(path.dirname(screenshotPath), { recursive: true });

const browser = await chromium.launch({
	executablePath: chromePath,
	headless: true,
	args: ["--disable-dev-shm-usage", "--ignore-gpu-blocklist", "--enable-webgl"],
});

let result;
try {
	const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
	const page = await context.newPage();
	const cdp = await context.newCDPSession(page);
	const failures = [];
	const pageErrors = [];
	page.on("requestfailed", (request) => failures.push(`${request.url()} ${request.failure()?.errorText ?? ""}`));
	page.on("pageerror", (error) => pageErrors.push(error.message));
	await cdp.send("Network.enable");
	await cdp.send("Emulation.setCPUThrottlingRate", { rate: 4 });
	await cdp.send("Network.emulateNetworkConditions", {
		offline: false,
		latency: 150,
		downloadThroughput: (1.6 * 1024 * 1024) / 8,
		uploadThroughput: (750 * 1024) / 8,
		connectionType: "cellular3g",
	});
	await page.goto(targetUrl, { waitUntil: "commit", timeout: 30000 });
	await page.waitForFunction(() => {
		const splash = document.getElementById("status-splash");
		return performance.getEntriesByName("rift-r25-main-focal").length > 0 || Boolean(splash?.complete && splash.naturalWidth > 0);
	}, null, { timeout: 3000 });
	const focalMs = await page.evaluate(() => {
		const marked = performance.getEntriesByName("rift-r25-main-focal")[0];
		if (marked) return marked.startTime;
		performance.mark("rift-r25-main-focal-fallback");
		return performance.getEntriesByName("rift-r25-main-focal-fallback")[0].startTime;
	});
	if (mode !== "before") invariant(focalMs <= 3000, `Fast3G/4x focal ${focalMs.toFixed(1)}ms exceeded 3000ms`);
	await page.locator("#status").screenshot({ path: screenshotPath, type: "png" });

	// The hard focal gate above is Fast3G + 4x CPU. Restore local CPU/network for
	// the separate relative TTI gate so the before/after bundle delta stays
	// reproducible and does not turn the 39 MiB engine bootstrap into a timeout.
	await cdp.send("Emulation.setCPUThrottlingRate", { rate: 1 });
	await cdp.send("Network.emulateNetworkConditions", {
		offline: false,
		latency: 0,
		downloadThroughput: -1,
		uploadThroughput: -1,
		connectionType: "none",
	});
	// A transfer that began under Fast3G keeps its original throttling. Cancel
	// that focal-only navigation, then measure TTI in a separate clean navigation.
	await page.goto("about:blank", { waitUntil: "commit", timeout: 30000 });
	failures.length = 0;
	pageErrors.length = 0;
	await page.goto(targetUrl, { waitUntil: "commit", timeout: 30000 });
	await page.waitForFunction(() => Boolean(window.__cvR22Controls?.main_menu ?? window.__cvR19Controls?.main_menu), null, { timeout: 120000 });
	const ttiMs = await page.evaluate(() => performance.now());
	const focalEntry = await page.evaluate(() => performance.getEntriesByName("rift-r25-main-focal")[0]?.toJSON() ?? null);
	let baseline = null;
	let ttiDeltaPercent = null;
	if (baselinePath) {
		baseline = JSON.parse(await fs.readFile(baselinePath, "utf8"));
		ttiDeltaPercent = ((ttiMs - baseline.tti_ms) / baseline.tti_ms) * 100;
		invariant(ttiDeltaPercent <= 10, `TTI delta ${ttiDeltaPercent.toFixed(2)}% exceeded 10%`);
	}
	invariant(failures.length === 0, `request failures: ${failures.join(" | ")}`);
	invariant(pageErrors.length === 0, `page errors: ${pageErrors.join(" | ")}`);
	result = {
		schema: "rift-r25-web-performance.v1",
		mode,
		url: targetUrl,
		profile: {
			focal: "Fast3G 1.6Mbps down / 750Kbps up / 150ms RTT + CPU 4x",
			tti: "local transfer + CPU 1x after focal; reproducible before/after bundle comparison",
		},
		focal_ms: focalMs,
		focal_budget_ms: 3000,
		focal_budget_passed: focalMs <= 3000,
		tti_ms: ttiMs,
		baseline_tti_ms: baseline?.tti_ms ?? null,
		tti_delta_percent: ttiDeltaPercent,
		tti_delta_budget_percent: 10,
		performance_mark: focalEntry,
		request_failures: failures,
		page_errors: pageErrors,
		passed: true,
	};
	await context.close();
} finally {
	await browser.close();
}

await fs.writeFile(outputPath, `${JSON.stringify(result, null, 2)}\n`, "utf8");
console.log(`R25_WEB_PERFORMANCE_PASS focal_ms=${result.focal_ms.toFixed(1)} tti_ms=${result.tti_ms.toFixed(1)} delta=${result.tti_delta_percent === null ? "baseline" : result.tti_delta_percent.toFixed(2) + "%"}`);
