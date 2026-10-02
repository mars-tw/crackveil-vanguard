const assert = require('node:assert/strict');
const {trackCommitState} = require('../web/webgl_state_cache.js');
const listeners = {}, state = new Map([[3089, false], [36006, null], [36010, null], [34016, 33984]]);
let nativeReads = 0;
const gl = {
  blitFramebuffer() {},
  createFramebuffer() { return {}; },
  getParameter(key) { nativeReads++; return state.get(key); },
  bindFramebuffer(target, framebuffer) {
    if (target === 36160 || target === 36009) state.set(36006, framebuffer);
    if (target === 36160 || target === 36008) state.set(36010, framebuffer);
  },
  deleteFramebuffer(framebuffer) { for (const key of [36006,36010]) if (state.get(key) === framebuffer) state.set(key, null); },
  enable(key) { state.set(key, true); }, disable(key) { state.set(key, false); }
};
const tracker = trackCommitState(gl, {addEventListener(event, callback) {listeners[event] = callback;}});
const first = gl.createFramebuffer(), second = gl.createFramebuffer();
gl.bindFramebuffer(36160, first); gl.bindFramebuffer(36008, second); gl.enable(3089);
assert.equal(gl.getParameter(36006), first);
assert.equal(gl.getParameter(36010), second);
assert.equal(gl.getParameter(3089), true);
assert.equal(nativeReads, 3, 'frame-commit queries must not contact the native driver');
assert.equal(gl.getParameter(34016), 33984, 'untracked enums pass through');
gl.deleteFramebuffer(first); assert.equal(gl.getParameter(36006), null);
assert.equal(gl.getParameter(36010), second);
gl.disable(3089);
assert.deepEqual(tracker.verify(), {ready:true,cachedQueries:5,scissorMatches:true,drawMatches:true,readMatches:true});
listeners.webglcontextlost();
state.set(36006, null); state.set(36010, null); state.set(3089, false);
gl.getParameter(3089); assert.equal(nativeReads, 8, 'lost context bypasses cache');
listeners.webglcontextrestored();
assert.equal(gl.getParameter(36010), null);
assert.equal(tracker.verify().readMatches, true);
console.log('R36_WEBGL_COMMIT_CACHE_PASS separate read/draw, deletion, scissor, context restoration, untracked enums');
