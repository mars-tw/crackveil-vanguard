# Crackveil Vanguard v0.14.3-r19｜cv R19 控制可達性硬化

日期：2026-07-16
範圍：Godot 4.7 Web 控制可達性 P0；未改角色動畫與 R18 美術資產。

## 結果

- 主選單四個主操作與種子列維持固定可見；右側設定／殘響／成就面板依剩餘視口高度收斂，內容由自身 `ScrollContainer` 捲動，關閉鍵固定在面板頂端。
- 暫停分頁內容繼續自身捲動，`繼續` 固定在面板底部；分頁、設定操作、關閉／確認類控制的命中高度至少 44px。
- 升級三選一、契約、商亭卡片使用自身捲動區；商亭 `離開`、勝利 `繼續／回主選單`、失敗 `再來一局／回主選單` 都在捲動區外固定顯示。
- `GameOverScreen` 與 `StageVictoryScreen` 補上 Web CSS 視口換算，避免 canvas backing viewport 與瀏覽器 CSS viewport 不一致時溢出。
- Web shell 明確設定 `viewport-fit=cover`、`html/body` 零邊距與 `#canvas` 100vw × 100vh；Godot `html/canvas_resize_policy=2` 保留。

## 裝置偵測

`MobileTuning` 改為 fail-closed：

- 非觸控、primary pointer 非 coarse 的桌機，即使短邊只有 600px，仍是 desktop tier。
- Web 只有 mobile UA 或 `(pointer: coarse)` 才確認為觸控；native 另保留「touchscreen available 且無滑鼠」分支。
- `navigator.maxTouchPoints`、UA、pointer 資訊以 JSON 字串跨 `JavaScriptBridge` 解析，避免 release Web 的 `JavaScriptObject` 屬性誤判。
- 舊的「強制顯示搖桿」偏好不能在無觸控桌機製造虛擬控制；桌機同時隱藏虛擬搖桿、右下技能鈕、搖桿大小快速鍵與無效的搖桿設定列。
- 390×844 coarse／mobile UA 會顯示左下搖桿與右下技能鈕。

## Playwright 守門方法

Godot 控制項繪在單一 WebGL canvas 內，沒有可逐按鈕查詢的 DOM 元素。因此 `tools/test_controls_reachability.mjs` 使用兩層驗證：

1. `WebReachabilityProbe` 僅在 URL 帶 `?cv_r19_test=1` 時，把 Godot 實際控制矩形、中心點與 visible 狀態發布為唯讀測試資料。
2. Playwright 驗證每個關鍵控制中心在 CSS viewport 內、命中高度 ≥44px，且該中心的 `document.elementFromPoint()` 命中承載控制的 `#canvas`，並檢查 canvas 填滿 viewport。
3. `R14RegressionTest` 在 Godot 內部補做 ScrollContainer clipping、固定操作列不重疊、桌機虛擬控制 hidden 的座標斷言；這一層負責 canvas 內部控制語意。

Headless Chromium 結果：

| 視口 | 觸控模擬 | 結果 |
|---|---:|---|
| 1920×1080 | 否，maxTouchPoints=0 | PASS |
| 1440×780 | 否，maxTouchPoints=0 | PASS |
| 1366×600 | 否，maxTouchPoints=0 | PASS |
| 1280×640 | 否，maxTouchPoints=0 | PASS |
| 390×844 | 是，primary coarse | PASS |

原始探針與命中結果：`docs/evidence/R19_controls/playwright_results.json`。

## 證據截圖

- `docs/evidence/R19_controls/1920x1080_main_menu.png`
- `docs/evidence/R19_controls/1366x600_pause.png`
- `docs/evidence/R19_controls/390x844_touch_controls.png`

## 驗收紀錄

- `R14RegressionTest`：exit 0，`R14_REGRESSION_PASS`；新增 `R19_CONTROLS_REACHABILITY` 五視口輸出。
- `TrueAnimationRegressionTest`：exit 0，`TRUE_ANIMATION_REGRESSION_PASS`。
- Web release export：exit 0；`export/web/index.html`、`.pck`、`.wasm` 產出成功。
- Playwright：exit 0，五視口皆 `R19_CONTROLS_PASS`，總結 `R19_CONTROLS_REACHABILITY_PASS`。
- 版本：`0.14.3-r19`，build date `2026-07-16`。
- 秘密掃描：依指定 regex 排除 `.git`，零命中。
- 本地 commit 訊息：`cv R19：硬化各裝置控制可達性`；未 push。
