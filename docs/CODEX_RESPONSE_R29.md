實作：Claude subagent（Codex 額度封鎖至 7/24）

# R29 交付報告：手機選單 P0 修正＋美術/內容打磨

版本：`v0.19.0-r29`（自 `v0.18.1-r26`；R27/R28 未 bump）
依據：`menuscan/rift/FINDINGS_R29.md`（390×844 Playwright 實測）＋ `docs/OPTIM_PLAN_R29.md` 驗收清單。
Codex 佇列項（C-01/C-02/D-02-step2/C-03/A-01）未碰。

## 修正總表

| id | 狀態 | 摘要 |
|---|---|---|
| P0-1 | 完成 | 設定面板改響應式單欄流式（版面寬 <700px 單欄）；滑桿流式寬；音量併列；面板寬 clamp ≤ viewport−24px |
| P0-2 | 完成 | 四面板共用深底 StyleBoxFlat（α0.97）＋全幅 backdrop；`ui_cancel`（Esc/Android back）與面板外點擊皆可關閉；「關閉」鈕保留 |
| P1-3 | 完成 | 面板內文對比 16.0:1／14.4:1；殘響 disabled 文字 3.9→8.3:1（計算見 evidence） |
| P1-4 | 完成 | 玩法長文改七則列表＋文案改寫（九人/等級七、Boss 移離斷行位）、字級 15 |
| P1-5 | 完成 | 載入層 inline focal 加「已載 X.X / YY.Y MB」數字（>20MB 附行動網路提示） |
| ART-1 | 完成 | 面板/按鈕視覺語言統一：四態 stylebox（含新增 focus 態）、圓角/邊框/字級階一致；純程序化、無新 AI 圖 |
| CONTENT-1 | 完成 | 選單文案潤飾：玩法七則＋殘響「解鎖入口」✓/□ 語彙統一（R27 裁決非 Codex 佇列小項） |
| VER | 完成 | 0.19.0-r29 五處同步；舊版號 grep 歸零（docs 歷史/evidence 除外） |

## 修改檔案

- `scripts/ui/main_menu.gd`：P0-1/P0-2/P1-3/P1-4/ART-1/CONTENT-1 全部佈局與互動修正
- `tools/finalize_r25_web_export.py`：RELEASE bump＋P1-5 MB 計數器（含匯出 gate 與 evidence 欄位）
- `export_presets.cfg`：head_include `rift-cache-version` meta → 0.19.0-r29
- `project.godot`／`README.md`：版號
- `scripts/debug/r14_regression_test.gd`：R14 版本漂移 gate 基準 → 0.19.0-r29
- `web/offline.html`：`rift-cache-version` meta 同步（舊版號 grep 抓出的漏網）
- `scripts/debug/r29_menu_modal_test.gd`＋`scenes/debug/R29MenuModalTest.tscn`：新增 R29 模態/單欄回歸 gate
- `.github/workflows/deploy-web.yml`：CI scenes 補 `R29MenuModalTest`
- `docs/OPTIM_PLAN_R29.md`／`docs/evidence/r29/R29_BEFORE_AFTER.md`：計畫與前後對照
- `web/icons/*.png.import`：R28 PWA 圖示的 Godot import 中繼檔補入庫（本輪 `--headless --import` 產出）

## 各 P0/P1 修法細節

### P0-1 設定面板（手機直向跑版）
- 根因：`GridContainer` 固定 2 欄，390px 直向兩欄合計最小寬 ~436px > 內容寬 306px，右欄整排出界不可點。
- 修法：欄數改由 `_apply_responsive_layout` 每次依版面寬重算——`<700px` 一律單欄、`≥700px` 兩欄（勿固定兩欄，與 FINDINGS 修法基準一致）；checkbox 字級基準 16→14（手機縮放後 27px 仍過可讀階）；兩支滑桿 `SIZE_EXPAND_FILL`＋min x=0 跟隨容器寬；音量標籤＋滑桿併一列；直向面板抬升至 7.5% 頂距、底部空帶 84→24px，設定全部控制（含介面大小滑桿）免捲動入畫且命中 ≥44px。
- 面板寬統一收口：終值 `min(panel_width, viewport−24px)`＋`panel_x` clamp，任何檔位不再水平溢出。

### P0-2 面板模態陷阱
- 根因：面板無 `ui_cancel` 處理、無面板外關閉路徑；且 `modulate α=0.88` 半透明讓底下主選單文字穿透，玩家誤判選單仍在。
- 修法：`side_panel` 掛 StyleBoxFlat 深底（bg α=0.97 ≥0.94）＋modulate 歸 1.0；新增全幅 `PanelBackdrop`（α0.62、`MOUSE_FILTER_STOP`）——點擊/觸控 backdrop 即 `_close_side_panel()`；`_unhandled_input` 收 `ui_cancel`（Esc／Android back）關閉＋`set_input_as_handled()`；右上「關閉」鈕保留原行為。玩法/殘響/成就/設定四面板共用同一 `side_panel`，一次修齊。

### P1-3 對比
深底＋backdrop 後：內文 16.0:1、預設灰白 14.4:1、殘響 disabled 補色 8.3:1、成就未解鎖 5.9:1，全數 ≥4.5:1（WCAG 相對亮度計算入 evidence）。

### P1-4 玩法文案
整段 6 句長文 → 「戰場/無盡/契約/隊伍/羈絆/進化/商亭」七則獨立 Label；「最多 9 人」→「最多九人」、「等級 7」→「等級七」、Boss 移離斷行孤兒位；字級 15（手機 29px、行寬 ≥10 字）。

### P1-5 載入層 MB 數字
`finalize_r25_web_export.py` inline focal（引擎下載期實際可見層）加 `#rift-r29-mb`，掛既有 50ms 輪詢讀 `#status-progress` value/max（bytes）→「已載 X.X / YY.Y MB」；總量 >20MB 附「行動網路首次載入需時較久」；未有進度值顯示「連線下載中…」。匯出後 HTML 缺標記即 fail。

## 本地驗證（Godot 4.7 stable headless，Windows；完整輸出：docs/evidence/r29/gate_outputs.txt）

`--headless --import` ×2 → 九個 gate 場景全綠：

```
R14RegressionTest            exit=0  R14_REGRESSION_PASS（R22 八視口 controls spec 全 PASS、hit>=44、no_overlap）
R29MenuModalTest（本輪新增）  exit=0  R29_MENU_MODAL_PASS portrait=single_column desktop=two_column
                                     modal=backdrop+ui_cancel panel_alpha>=0.94（guide_rows=8）
TrueAnimationRegressionTest  exit=0  TRUE_ANIMATION_REGRESSION_PASS
PoolContractTest             exit=0  POOL_CONTRACT_PASS
GameplayCapTest              exit=0  GAMEPLAY_CAP_PASS
SquadSmokeTest               exit=0  WEAPON_SMOKE_PASS（9 人隊伍/跟隨/武器/招募升級）
WeaponSmokeTest              exit=0  WEAPON_SMOKE_PASS
EnemyArtRegressionTest       exit=0  ENEMY_ART_REGRESSION_PASS（assets=7 heroes=10 packed=true）
R25ParallaxRegressionTest    exit=0  R25_PARALLAX_REGRESSION_PASS
```

本地 web 匯出驗證（本機有 4.7 export templates）：`--export-release Web` exit=0 →
`finalize_r25_web_export.py` → `R25_PWA_CACHE_PASS version=0.19.0-r29|48393809 files=11`；
匯出 HTML 實測含 `rift-r29-mb` 計數器與 `rift-cache-version=0.19.0-r29` meta，service worker `CACHE_VERSION` 連動。
（審計註記：Weapon/EnemyArt 首跑因本機兩個 Godot 實例併發互踩被誤殺（exit=127，非測試失敗），已獨占重跑轉綠；R29 gate 同因重跑，獨占執行數秒即過。）

秘密掃描：`grep -rniE "sk-proj-…|sk-…|xai-…" . --exclude-dir=.git` 含二進位全量 → **零命中**。
舊版號 `0.18.1-r26` grep：非 docs 歸零（含 `web/offline.html` 漏網修補）；docs 僅 R29 計畫/報告以「版本鏈來源」形式提及，歷史文件/evidence 未動。
DOM 級行為驗證（真瀏覽器 Esc/點外/MB 數字）由 CI `test_controls_reachability.mjs` 與總稽核部署後實測把關。

## 殘留風險

- **Esc/點外關閉的真瀏覽器行為**：本地以 `R29MenuModalTest` 驗 `_unhandled_input`／backdrop 邏輯；真 DOM 事件鏈（canvas focus 下的 Esc、觸控合成點擊）由 CI Playwright 環境與總稽核部署後 390×844 實測補驗。
- **Android back 鍵**：一般瀏覽器分頁的 back 會觸發瀏覽歷史返回，引擎收不到；PWA 安裝版／原生版才映射 `ui_cancel`。面板外點擊與關閉鈕為手機主要出口。
- **MB 數字口徑**：讀 Godot shell 寫入 `#status-progress` 的 value/max（bytes）；若未來升級 Godot 版本改變 shell 進度回報，需回歸此顯示。傳輸壓縮（gzip/brotli）下顯示的是引擎回報口徑。
- **字型子集**：新文案用字均落在 3000 常用字安全集內，且 CI 每次部署重建子集，無缺字風險；本地 committed 子集未重建（與 R28 相同流程）。
- **窄直向桌機視窗**（fine-pointer portrait，如 680×900）沿用 r26 桌機直向面板參數，非 FINDINGS 案例範圍；如需一併打磨列後續輪。
- **引擎 40MB 首載瘦身**：Codex 7/24 佇列（D-02 第二步等），本輪僅補下載量體感。
