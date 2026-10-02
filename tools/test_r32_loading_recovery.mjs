import assert from "node:assert/strict";
import { installLoadingRecovery } from "../web/loading_recovery.mjs";

function fixture() {
  const elements = new Map();
  const make = (id = "") => {
    const element = { id, textContent: "", hidden: false, isConnected: true, style: { display: "none" },
      classList: { values: new Set(), add(value) { this.values.add(value); } },
      listeners: {}, children: [], setAttribute() {},
      addEventListener(event, callback) { this.listeners[event] = callback; },
      append(...children) { this.children.push(...children); } };
    if (id) elements.set(id, element);
    return element;
  };
  const artwork = make("rift-r25-inline-focal");
  const notice = make("status-notice");
  const progress = make("status-progress");
  const mb = make("rift-r30-mb");
  progress.value = 0;
  progress.max = 100;
  let time = 0;
  let reloads = 0;
  const doc = { getElementById: id => elements.get(id), createElement: () => make() };
  const win = { setInterval: () => 1, clearInterval() {}, getComputedStyle: e => e.style,
    location: { reload() { reloads += 1; } } };
  const control = installLoadingRecovery(doc, win, () => time);
  return { artwork, notice, progress, mb, control, setTime: value => { time = value; }, reloads: () => reloads };
}

const slow = fixture();
assert.equal(slow.control.recovery.hidden, true);
slow.setTime(30000);
slow.control.tick();
assert.equal(slow.control.recovery.hidden, false);
assert.match(slow.control.message.textContent, /下載暫停/);
slow.progress.value = 20;
slow.setTime(31000);
slow.control.tick();
assert.equal(slow.control.recovery.hidden, true);

const failed = fixture();
failed.notice.textContent = "network error";
failed.notice.style.display = "block";
failed.control.tick();
assert.equal(failed.control.recovery.hidden, false);
assert.match(failed.control.message.textContent, /載入失敗/);
assert.ok(failed.artwork.classList.values.has("load-failed"));
assert.equal(failed.mb.textContent, "遊戲尚未啟動");
failed.control.retry.listeners.click();
assert.equal(failed.reloads(), 1);

const complete = fixture();
complete.progress.value = 100;
complete.control.tick();
complete.setTime(90000);
complete.control.tick();
assert.equal(complete.control.recovery.hidden, true);
console.log("R32_LOADING_RECOVERY_PASS failure=visible retry=one-click stall=30s recovery=progress complete=no-false-stall");
