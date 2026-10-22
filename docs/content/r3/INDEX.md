# 內容 R3 證據入口

版本 `0.32.0-content-r3`，基準 `ce94e02`。本輪只在本機提交，尚未發布。技術驗證不等於整體達到九分。

- [完整交付與限制](../../CODEX_RESPONSE_CONTENT_R3.md)
- [實作計畫與十五節點契約](../../OPTIM_PLAN_CONTENT_R3.md)
- [精選圖清冊](review-manifest.json)：十五張原始 runtime 截圖；每張記錄時間、來源、包與 PNG SHA-256。
- [來源清冊](tests/source-hashes.json)、[匯出包收據](tests/builds.json)、[嚴格交付驗證](tests/delivery-check.json)
- [CI 49 項原始結果](tests/gates/summary.json)、[後續相關 UI 驗證](tests/menu-followup/summary.json)、[來源時序限制](tests/ci-source-binding.json)
- [新頁真點擊矩陣](tests/controls.json)：四視口 × 一般／最大字級，包含 320×568，每組十八頁及解鎖、裝備、卸下、關閉、重開、出擊。
- [突擊連續實跑](tests/paired/assault.json)、[護送連續實跑](tests/paired/escort.json)、[實跑執行及來源收據](tests/paired/runner.json)
- [十五節點與交易／遷移回歸](tests/mechanics.json)、[預設存檔隔離界線](tests/profile-isolation.json)

圖 01–04 為正式 release 選單與整備；05–13 為同一正常輸入自動駕駛流程的連續戰鬥與真通關，取樣時暫停觀測，不改 HP、DPS、遊戲時間或通關旗標。圖 14–15 是明確標示的四次早期戰敗 fixture，以真角色受傷／死亡回呼與正式重試出擊入口驗證免費選擇，不能當成自然遊玩結果。

`tests/attempts/` 保留本輪失敗日誌與被取代證據，不列入最新十五張。R2 與 R2.1 原有證據完全保留在各自目錄，沒有改標為 R3。
