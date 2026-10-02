/* Godot/Emscripten restores these three WebGL states at every frame commit.
 * Track mutations in JavaScript so restoring the offscreen buffer does not
 * synchronously query the graphics driver. All drawing still uses native GL.
 */
(function () {
  'use strict';
  function trackCommitState(gl, canvas) {
    const SCISSOR = 3089, FRAMEBUFFER = 36160, DRAW = 36009, READ = 36008;
    const DRAW_BINDING = 36006, READ_BINDING = 36010;
    const get = gl.getParameter.bind(gl);
    const bind = gl.bindFramebuffer.bind(gl);
    const remove = gl.deleteFramebuffer.bind(gl);
    const create = gl.createFramebuffer.bind(gl);
    const enable = gl.enable.bind(gl), disable = gl.disable.bind(gl);
    const isWebGL2 = typeof gl.blitFramebuffer === 'function';
    let scissor, draw, read, ready = true, cachedQueries = 0;
    let knownFramebuffers = new WeakSet();
    function reset() {
      scissor = get(SCISSOR);
      draw = get(DRAW_BINDING);
      read = isWebGL2 ? get(READ_BINDING) : draw;
      if (draw) knownFramebuffers.add(draw);
      if (read) knownFramebuffers.add(read);
    }
    reset();
    gl.createFramebuffer = function () {
      const framebuffer = create();
      if (framebuffer) knownFramebuffers.add(framebuffer);
      return framebuffer;
    };
    gl.getParameter = function (parameter) {
      if (ready) {
        if (parameter === SCISSOR) { cachedQueries++; return scissor; }
        if (parameter === DRAW_BINDING) { cachedQueries++; return draw; }
        if (isWebGL2 && parameter === READ_BINDING) { cachedQueries++; return read; }
      }
      return get(parameter);
    };
    gl.bindFramebuffer = function (target, framebuffer) {
      bind(target, framebuffer);
      // Binding a deleted/foreign object sets a WebGL error and leaves the
      // real binding intact. Preserve that behavior without a driver query.
      if (framebuffer !== null && !knownFramebuffers.has(framebuffer)) return;
      if (target === FRAMEBUFFER) draw = read = framebuffer;
      else if (isWebGL2 && target === DRAW) draw = framebuffer;
      else if (isWebGL2 && target === READ) read = framebuffer;
    };
    gl.deleteFramebuffer = function (framebuffer) {
      remove(framebuffer);
      if (framebuffer) knownFramebuffers.delete(framebuffer);
      if (draw === framebuffer) draw = null;
      if (read === framebuffer) read = null;
    };
    gl.enable = function (capability) {
      enable(capability);
      if (capability === SCISSOR) scissor = true;
    };
    gl.disable = function (capability) {
      disable(capability);
      if (capability === SCISSOR) scissor = false;
    };
    canvas.addEventListener('webglcontextlost', function () { ready = false; });
    canvas.addEventListener('webglcontextrestored', function () { knownFramebuffers = new WeakSet(); reset(); ready = true; });
    return {
      // Read-only verification is explicit; native driver reads never happen
      // in the combat loop or the regular HUD probe.
      verify: function () {
        return {ready, cachedQueries, scissorMatches: get(SCISSOR) === scissor,
          drawMatches: get(DRAW_BINDING) === draw,
          readMatches: !isWebGL2 || get(READ_BINDING) === read};
      },
      get cachedQueries() { return cachedQueries; }
    };
  }
  if (typeof module === 'object') module.exports = {trackCommitState};
  if (typeof window === 'undefined') return;
  const parameters = new URLSearchParams(location.search);
  const cacheEnabled = parameters.get('r36_gl_cache') !== '0';
  const preferFastGPU = parameters.get('r36_gpu_preference') !== '0';
  const original = HTMLCanvasElement.prototype.getContext;
  const contexts = new WeakMap();
  HTMLCanvasElement.prototype.getContext = function (kind, attributes) {
    const isGame = this.id === 'canvas' && (kind === 'webgl2' || kind === 'webgl' || kind === 'experimental-webgl');
    const options = isGame && preferFastGPU ? {...attributes, powerPreference: 'high-performance'} : attributes;
    const gl = original.call(this, kind, options);
    if (gl && isGame && cacheEnabled && !contexts.has(gl)) {
      const tracker = trackCommitState(gl, this);
      contexts.set(gl, tracker);
      window.__r36WebGLCommitState = tracker;
    }
    return gl;
  };
})();
