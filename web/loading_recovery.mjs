// The loading artwork must not conceal the engine's failure state.
export function installLoadingRecovery(doc, win, now = () => performance.now()) {
  const artwork = doc.getElementById("rift-r25-inline-focal");
  const notice = doc.getElementById("status-notice");
  const progress = doc.getElementById("status-progress");
  if (!artwork || !notice || !progress) return null;

  const recovery = doc.createElement("div");
  recovery.id = "rift-r32-loading-recovery";
  recovery.style.cssText = "position:absolute;left:5%;right:5%;bottom:4%;z-index:2;text-align:center;color:#e4f4ff;font:15px/1.4 system-ui,sans-serif";
  recovery.hidden = true;
  const message = doc.createElement("span");
  message.setAttribute("role", "status");
  const retry = doc.createElement("button");
  retry.type = "button";
  retry.textContent = "重新載入";
  retry.style.cssText = "margin:0 0 0 12px;padding:10px 18px;border:1px solid #64d8ff;border-radius:8px;background:#102636;color:#e4f4ff;cursor:pointer;font:15px system-ui,sans-serif";
  retry.addEventListener("click", () => win.location.reload());
  recovery.append(message, retry);
  artwork.append(recovery);
  let lastValue = Number(progress.value) || 0;
  let lastActivity = now();
  let lastPhase = win.__cvR41Startup?.phase || "";
  let timer;
  const canvas = doc.getElementById("canvas");
  const cleanup = () => {
    win.clearInterval(timer);
    win.removeEventListener?.("unhandledrejection", startupFailure);
    canvas?.removeEventListener?.("webglcontextlost", startupFailure);
  };

  const tick = () => {
    if (!artwork.isConnected || win.__cvR41Startup?.phase === "ready") {
      recovery.hidden = true;
      cleanup();
      return;
    }
    const phase = win.__cvR41Startup?.phase || "";
    if (phase !== lastPhase) {
      lastPhase = phase;
      lastActivity = now();
      recovery.hidden = true;
    }
    const failed = phase === "failed" || (notice.textContent.trim() !== "" && win.getComputedStyle(notice).display !== "none");
    if (failed) {
      artwork.classList.add("load-failed");
      const mb = doc.getElementById("rift-r30-mb");
      if (mb) mb.textContent = "遊戲尚未啟動";
      message.textContent = "載入失敗，可重新載入再試。";
      recovery.hidden = false;
      cleanup();
      return;
    }
    const value = Number(progress.value);
    if (Number.isFinite(value) && value !== lastValue) {
      lastValue = value;
      lastActivity = now();
      recovery.hidden = true;
    }
    const total = Number(progress.max);
    if (phase && phase !== "ready" && Number.isFinite(value) && Number.isFinite(total) &&
        value >= total && now() - lastActivity >= 30000) {
      message.textContent = "資料已下載，遊戲啟動尚未完成，可重新載入。";
      recovery.hidden = false;
      return;
    }
    if (Number.isFinite(value) && Number.isFinite(total) && value < total && now() - lastActivity >= 30000) {
      message.textContent = "下載暫停了，可繼續等待或重新載入。";
      recovery.hidden = false;
    }
  };
  timer = win.setInterval(tick, 200);
  const startupFailure = event => {
    if (win.__cvR41Startup && win.__cvR41Startup.phase !== "ready") {
      const reason = event?.reason?.message || event?.reason || event?.message || "graphics context lost";
      if (win.__cvR41Startup.fail) win.__cvR41Startup.fail(reason);
      else win.__cvR41Startup.phase = "failed";
      tick();
    }
  };
  win.addEventListener?.("unhandledrejection", startupFailure);
  canvas?.addEventListener?.("webglcontextlost", startupFailure);
  tick();
  return { tick, recovery, message, retry };
}

if (typeof document !== "undefined") {
  const start = () => installLoadingRecovery(document, window);
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
}
