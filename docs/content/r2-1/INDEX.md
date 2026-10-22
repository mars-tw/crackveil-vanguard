# R2.1 UI 回歸證據

版本 `0.31.1-content-r2.1`，歷史基準 `f384969`。本目錄的圖證只支持本次 UI 修復，不代替完整內容評分或效能測試。

- [三視口、45 個 runtime 檢查點與 21 張原始圖的雜湊](tests/samples.json)
- [3 組中心 mouse、2 組中心 touch；後續 pause／resume 實際操作](tests/runtime-runs.json)
- [新增 120 項 headless／Dummy UI 與手勢回歸](tests/ui-regression.json)
- [8 項相關原 CI 場景](tests/gates/summary.json)
- [原 R1 1355 項](tests/r1/mechanics.json)、[原 R2 244 項](tests/mechanics.json)
- [匯出來源](tests/source-hashes.json)、[review／release 包](tests/builds.json)、[QA 排除檢查](tests/pack-isolation.json)
- [原 R2 檔案雜湊與起始 git status](tests/historical-r2.json)

三種視口為 `844×390`、`390×844`、`1366×600`。每個視口各留 picker-open、picker-closed、front-active、pincer-active、artillery-active、artillery-recovery、urgent-預警，共 7 張；總計 21 張。DPR 1、未裁切／後製，使用真實 Godot Web renderer 與 headless Chrome SwiftShader、靜音。

對照舊缺陷：[原 R2 圖 15](../r2/review-set/15-combo-combo_condition.png)、[圖 02](../r2/review-set/02-front-active.png)、[圖 05](../r2/review-set/05-pincer-active.png)、[圖 08](../r2/review-set/08-artillery-active.png)。舊圖與原 JSON 保留 `0.31.0-content-r2`，不改標為 patch。

UI fixture 載入正式 Arena／HUD／攻勢與裝備程式；為固定檢查點而停止戰鬥移動及自然時間，透過正式方法進行攻勢階段轉移。這些圖不是自然通關或效能證據。開始按鈕由 Playwright 真實中心點擊／觸控解除；沒有以 JavaScript 刪除、隱藏或呼叫 unlock 取代輸入。
