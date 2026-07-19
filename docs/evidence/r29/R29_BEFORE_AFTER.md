# R29 修改前後對照（佈局參數與程式差異說明）

實作：Claude subagent（Codex 額度封鎖至 7/24）。修改前實測證據：`menuscan/rift/`（390×844 Playwright，2026-07-19）。
部署後實機截圖由總稽核補驗；本檔記錄可比對的佈局參數差異。

## P0-1 設定面板手機直向跑版（before：50-settings-open.png）

| 參數 | before（r26） | after（r29） |
|---|---|---|
| 切換群欄數 | GridContainer 固定 2 欄 | 響應式：版面寬 <700px 單欄、≥700px 兩欄（`_apply_responsive_layout` 每次重算） |
| 390px 直向欄寬需求 | 2×(checkbox min ~210px)+間距 ≈ 436px（>內容寬 306px，右欄出界） | 1×~200px ≤ 306px，全入畫 |
| checkbox 字級 | 無 override（基準 16 → 手機縮放 31px） | 基準 14 → 手機直向 27px、橫向 26px（仍 ≥24px 可讀階） |
| 滑桿寬 | 固定 `custom_minimum_size.x = 240`（<240px 容器時溢出） | `SIZE_EXPAND_FILL`＋min x=0，寬度跟隨容器 |
| 音量列 | 標籤、滑桿各占一列 | HBox 併一列（省 54px 直向高度） |
| 面板 y（手機直向） | `max(126, logo_top+112)` = 146 | `max(40, viewport.y×7.5%)` = 63（390×844；模態後可蓋 logo） |
| 捲動區底部保留 | 84px（無控件的空帶） | 24px |
| 面板寬收口 | 各分支自行計算，無統一上限 | 終值 `min(panel_width, viewport−24px)`＋`panel_x` clamp ≥12px |
| 390×844 設定內容總高 | ~510px（2 欄硬塞、水平溢出換來的） | ~646px，可用捲動區 ~662px → 無裁切、命中 ≥44px（R14/R22 gate 斷言） |

## P0-2 面板模態陷阱（before：41-tap-y*.png、42-after-escapes.png）

| 行為 | before | after |
|---|---|---|
| 面板背景 | Panel 預設樣式＋`modulate α=0.88` → 主選單文字穿透 | StyleBoxFlat 深底 `Color(0.027,0.062,0.094,0.97)`（α≥0.94）＋`modulate α=1.0` |
| 面板外點擊 | 無效（6 次點擊實測不關） | 全幅 `PanelBackdrop`（ColorRect α=0.62，MOUSE_FILTER_STOP）`gui_input` 收滑鼠左鍵／觸控即 `_close_side_panel()` |
| Esc / Android back | 無效（6 次 Esc 實測不關） | `_unhandled_input` 收 `ui_cancel` 關閉＋`set_input_as_handled()` |
| 右上「關閉」鈕 | 有效 | 保留（行為不變，CI DOM gate `side_close` 點擊斷言不動） |
| 適用面板 | — | 玩法／殘響升級／成就／設定共用同一 `side_panel`，一次修四面板 |

## P1-3 面板文字對比（WCAG 相對亮度計算）

- 面板底 `(0.027,0.062,0.094)` 相對亮度 L≈0.0048。
- 內文 `(0.87,0.93,0.97)`：L≈0.828 → 對比 (0.878/0.0548) ≈ **16.0:1** ✓
- 預設 Label 灰白 `(0.875,…)`：≈ **14.4:1** ✓
- 殘響已滿級 disabled 文字補 `(0.62,0.72,0.8)`：對按鈕底 ≈ **8.3:1**（before 預設 disabled 半透明灰 ≈3.9:1 ✗）
- 成就未解鎖徽章 `(0.5,0.56,0.62)` 對徽章底 ≈ **5.9:1** ✓（維持）
- 全部 ≥4.5:1；且 backdrop＋不透明底移除「底層文字疊字」的實際可讀性破壞源。

## P1-4 玩法文案破碎斷行（before：41-tap-y354.png「擊敗 Boss／後可繼續」）

- 整段 6 句長文 → 7 則「主題」逐則列表（每則獨立 Label，字級 15 → 手機 29px，行寬 ≥10 字）。
- 「最多 9 人」→「最多九人」、「等級 7」→「等級七」：阿拉伯數字換中文，消除 ASCII 斷行孤兒。
- 「擊敗 Boss 後可繼續無盡作戰」→「擊敗 Boss 之後可續戰無盡敵潮，衝擊更高紀錄」：Boss 移離斷行位，390px 實算斷點落於整詞邊界。

## P1-5 載入層下載量數字

- `tools/finalize_r25_web_export.py` inline focal 區塊新增 `#rift-r29-mb`（bottom 9.5%，轉圈 spinner 下方）。
- 掛在既有 50ms 輪詢：讀 `#status-progress` 的 value/max（bytes）→「已載 X.X / YY.Y MB」；總量 >20MB 附「行動網路首次載入需時較久」提示；無進度值顯示「連線下載中…」。
- 匯出後 gate：HTML 缺 `rift-r29-mb` 標記即 SystemExit；evidence JSON 增列 `loading_mb_marker`。

## ART-1 面板視覺語言統一（程序化，無新 AI 圖）

- 面板：圓角 14／邊框 2px 裂隙青 `(0.34,0.82,0.94,0.85)`／陰影，與主選單按鈕同語言。
- 按鈕四態抽出 `_apply_menu_button_style()`：normal/hover/pressed 沿用 r26 值，新增 focus 態（draw_center=false 青白描邊）；「關閉」鈕與主選單按鈕同組樣式；成就徽章補 focus 態。
- 標題字級階 24/22 維持，補色階 `(0.92,0.98,1.0)`。

## 版本鏈

`0.18.1-r26` → `0.19.0-r29`：`project.godot`、`README.md`、`tools/finalize_r25_web_export.py`（RELEASE→CACHE_VERSION 連動）、`export_presets.cfg`（head_include `rift-cache-version` meta，finalize marker gate 依此驗證）、`scripts/debug/r14_regression_test.gd`（R14 版本漂移 gate 基準）。
