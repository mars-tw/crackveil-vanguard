(function (root) {
  "use strict";
  function isMobile(win) {
    const nav = win.navigator || {};
    return /iPhone|iPad|iPod|Android|Mobile/i.test(nav.userAgent || "") ||
      (nav.platform === "MacIntel" && nav.maxTouchPoints > 1) ||
      (nav.maxTouchPoints > 0 && Math.min(win.innerWidth,win.innerHeight) <= 600 &&
        Math.max(win.innerWidth,win.innerHeight) < 1100);
  }
  function prepare(doc, win, config) {
    const mobile = isMobile(win);
    const state = { mobile, phase: "loading_engine", startedAt: win.performance.now(), transitions: [], canvasPixels: 0 };
    win.__cvR41Startup = state;
    const transition = phase => {
      if (state.fatal && phase !== "failed") return;
      state.phase = phase;
      state.transitions.push({ phase, at: win.performance.now() });
      doc.dispatchEvent(new win.CustomEvent("crackveil-startup", { detail: { phase } }));
    };
    state.transition = transition;
    state.fail = error => {
      state.fatal = true;
      state.error = String(error && error.message || error);
      transition("failed");
    };
    config.unloadAfterInit = true;
    const canvas = doc.getElementById("canvas");
    if (mobile && canvas) {
      config.canvasResizePolicy = 0;
      function resize() {
        const width = Math.max(1, Math.floor(win.innerWidth));
        const height = Math.max(1, Math.floor(win.innerHeight));
        const scale = Math.min(1, Math.sqrt(921600 / (width * height)));
        const targetWidth = Math.max(1, Math.floor(width * scale));
        const targetHeight = Math.max(1, Math.floor(height * scale));
        if (canvas.width !== targetWidth) canvas.width = targetWidth;
        if (canvas.height !== targetHeight) canvas.height = targetHeight;
        state.canvasPixels = targetWidth * targetHeight;
        state.renderScale = scale;
      }
      resize();
      let resizePending = false;
      const queueResize = () => {
        if (resizePending) return;
        resizePending = true;
        win.requestAnimationFrame(() => { resizePending = false; resize(); });
      };
      win.addEventListener("resize", queueResize);
      win.addEventListener("orientationchange", queueResize);
      if (win.visualViewport) win.visualViewport.addEventListener("resize", queueResize);
    }
    return state;
  }
  async function start(engine, config, progress, state) {
    const ensureAlive = () => { if (state.fatal) throw new Error(state.error || "startup failed"); };
    try {
      if (!state.mobile) {
        await engine.startGame({ onProgress: progress });
      } else {
        // Supported Engine API: compile first, then allocate the package.
        state.transition("loading_engine");
        await engine.init(config.executable);
        ensureAlive();
        state.transition("loading_pack");
        await engine.preloadFile(config.mainPack, config.mainPack);
        ensureAlive();
        state.transition("initializing");
        const args = ["--main-pack", config.mainPack].concat(config.args || []);
        await engine.start({ args, onProgress: progress });
      }
      ensureAlive();
      state.transition("ready");
    } catch (error) {
      state.fail(error);
      throw error;
    }
  }
  const api = { isMobile, prepare, start };
  root.CrackveilMobileStartup = api;
  if (typeof module === "object" && module.exports) module.exports = api;
})(typeof window === "object" ? window : globalThis);
