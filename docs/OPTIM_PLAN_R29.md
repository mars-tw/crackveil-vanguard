# OPTIM_PLAN R29（手機選單 P0 修正＋美術/內容打磨）

2026-07-19。依據：`menuscan/rift/FINDINGS_R29.md`（390×844 Playwright 實測）＋ OPTIM_PLAN_R27 裁決。
實作：Claude subagent（Codex 額度封鎖至 7/24）。Codex 佇列項（C-01/C-02/D-02-step2/C-03/A-01）不碰。

## 驗收清單

| id | 項目 | 修法 | 驗收標準 |
|---|---|---|---|
| P0-1 | 設定面板手機直向跑版 | `main_menu.gd` 設定切換群改響應式 GridContainer：手機層（phone tier）或版面寬 <900px 一律單欄；滑桿改 `SIZE_EXPAND_FILL`＋去除固定 240px 底寬，寬度跟隨容器 | 390×844 下所有控制完整入畫、無水平溢出；R14 `mobile_ui`/R22 三視口 gate 綠；所有控制命中 ≥44px（gate 既有斷言） |
| P0-1b | 面板寬 clamp | 面板寬終值 `min(panel_width, viewport−24px)` 統一收口 | 任一視口面板 rect 不超出 viewport−24px；R14 `_control_inside_viewport` 綠 |
| P0-2a | 面板背景穿透 | `side_panel` 掛 StyleBoxFlat 深底（bg alpha 0.97 ≥0.94）；移除 modulate 0.88 半透明；面板後加全幅暗化 backdrop（alpha 0.62） | 面板開啟時底下主選單文字不可見；四面板（玩法/殘響/成就/設定）共用同一 `side_panel` 一次修 |
| P0-2b | 模態陷阱 | `_unhandled_input` 支援 `ui_cancel`（Esc/Android back）關閉；backdrop `gui_input` 點擊（滑鼠＋觸控）關閉；右上「關閉」鈕保留 | Esc 一次關閉；面板外任一點點擊關閉；「關閉」鈕行為不變（CI DOM gate `side_close` 點擊斷言不變） |
| P1-3 | 面板文字對比 | 近不透明深底（#071017 級）＋backdrop 暗化後，內文 #dfe9f2 對白底比 >10:1、對面板底 >9:1；標題補色階 | 對比 ≥4.5:1（以面板底色計算，附計算於 evidence） |
| P1-4 | 玩法文案破碎斷行 | 玩法面板改逐則列表（七則、每則獨立 Label）；字級基準 15（手機縮放後 ~29px，行寬 ≥10 字）；文案改寫：數字改中文（九人/等級七）、ASCII 詞（Boss）移離斷行孤兒位 | 390×844 下無「擊敗 Boss／後可繼續」式硬拆孤兒行；文案語意不變 |
| P1-5 | 載入層下載量數字 | `tools/finalize_r25_web_export.py` inline focal 區塊加 `#rift-r29-mb`，掛在既有 50ms 輪詢上讀 `#status-progress` value/max → 「已載 X.X / YY.Y MB」；無進度值時顯示引導文案 | 匯出後 index.html 含 `rift-r29-mb` 標記；進度數字隨 `#status-progress` 更新（DOM 驗證交 CI/總稽核實測） |
| ART-1 | 面板視覺語言統一（程序化，無新 AI 圖） | 面板圓角 14/邊框 2px 裂隙青、與主選單按鈕同語言；「關閉」鈕套主選單按鈕三態（normal/hover/pressed）＋補 focus 態；標題字級階（24/22）與色階統一 | 四面板同一視覺語言；按鈕四態 stylebox 齊備 |
| CONTENT-1 | 選單內文案潤飾（R27 非 Codex 佇列小項） | 玩法七則重寫（見 P1-4）＋殘響面板「解鎖入口」列格式化；不動契約/英雄機制句（R28 契約） | 文案入庫；R14 契約斷言不變 |
| VER | 版本鏈 | `0.18.1-r26` → `0.19.0-r29`：project.godot / README / finalize RELEASE / export_presets head_include meta / r14_regression_test 基準同步 | 舊版號 grep 歸零（docs 歷史/evidence 除外）；R14 版本漂移 gate 綠 |
| GATE | 本地驗證 | Godot 4.7 headless：`--import` ×2 → R14 / TrueAnimation / PoolContract / GameplayCap / SquadSmoke / WeaponSmoke / EnemyArt / R25Parallax 全綠；新增 **R29MenuModalTest**（模態行為＋單欄切換回歸保護，入 CI scenes）；秘密掃描零命中 | 全部 exit 0；輸出摘要入 evidence |

## 不做（本輪約束）
- Blender MCP / gpt-image-2 未連線：不產任何新 AI 圖，僅程序化 StyleBox/佈局。
- C-01（放棄本局）、C-02（進化進度）、D-02 第二步、C-03（羈絆展開）、A-01（武器素材）：Codex 復工佇列，不碰。
- 引擎瘦身（40MB 首載）：已列 Codex 7/24 佇列，本輪僅補 MB 數字體感。
