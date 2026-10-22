# 內容 R2.1：UI 遮擋與開始手勢修復

版本 `0.31.1-content-r2.1`。以 `f384969` 為歷史基準，本機修復，未推送或部署。

## 已完成的修改

1. 換陣 picker 開啟立即隱藏地標 label，關閉恢復；HUD 統計及暫停回呼改回讀取相同的可見性規則，不能穿透重顯。
2. 裝備通知在攻勢 warning／active、換陣、暫停、重要訊息與羈絆揭露期間延後，保留最新裝備通知及其完整顯示時間。預警／反噬／封隙／護衛依序優先顯示，重要訊息不受一般通知上限裁除，也不再被 loot 或 bond 隱藏。
3. 修正取圖時實際發現的官方「點擊開始」按鈕穿透。AudioManager 在 gate 可見時消耗解鎖手勢與配對尾端，不讓同一次操作點到後方召喚／裝備。Web 實際 trace 為 emulated mouse press → raw touch press → mouse release → touch release，已涵蓋此順序。wheel 沒有 release，不建立持續 mouse guard；失焦清除遺失的尾端狀態。主選單沒有 gate 的首筆輸入維持原行為。
4. project、README、native sourceVersion 同步；nativeVersion／nativeBuild、export preset 及商店設定維持原值。
5. R1→R2→R2.1 的既有驗證入口精確路由 patch，新驗證器檢查本輪來源／匯出包／圖證、原測試斷言保全、舊 R2 保全與實際回歸範圍。沒有放寬原 R1／R2 的歷史驗證條件。

## 本次實跑

- Godot `--headless --audio-driver Dummy --fixed-fps 60`：8 個相關 CI 場景通過；包括新增 UI／手勢 120 項、原 ContentR1Test 1355 項、原 ContentR2Test 244 項，以及 R14 release regression、R29 modal、R39 HUD、R42 formation、R43 mobile tactics。
- 真實 Web runtime：3 視口的 45 個檢查點、21 張未後製圖；開始 gate 中心的 3 組 mouse 與 2 組 touch 通過，沒有召喚／裝備／暫停穿透，下一筆正常 pause／resume 實際操作亦通過。
- release pack 在隔離目錄 headless 載入：12 項通過，R2／R2.1 QA fixture 未洩漏。
- 原 controls 8 視口全部通過。從舊 `verify_content_r1.py` 入口實際接續 R2／R2.1，嚴格來源、歷史、圖證、測試與秘密掃描驗證 VERIFIED，秘密字串零命中，見 [delivery-check.json](content/r2-1/tests/delivery-check.json) 與 [controls 結果](content/r2-1/tests/controls/playwright_results.json)。

新圖、測試與來源證據統一放在 [content/r2-1](content/r2-1/INDEX.md)。原 R2 的 15 張圖及整個 R2 JSON／收據保持原檔，不冒充本版。原 5 個測試只增加可選 `CV_TEST_EVIDENCE_DIR`，沒有變更原斷言；R14 的嚴格當前版本期望同步到新 patch，沒有移除版本斷言。本輪輸出到新目錄，沒有重寫舊 tracked 驗證紀錄。

## 範圍、保全與未完成

本次只重新執行上述 8 個 Godot CI 場景及相關 Web controls；歷史完整 47 項沒有全部重跑。UI fixture 固定時間／戰鬥移動以驗證通知與模態，不能據此聲稱自然通關、整局戰鬥或三跑 p95 達標。software renderer 使用 CPU，沒有占用 H3 GPU，也沒有可見視窗或聲音。

[獨立 R2 覆核](content/CONTENT_REVIEW_R2_CODEX.md) 的 7.8/10 是修復前評分。這次解決明確 UI 缺陷，沒有對 patch 做完整內容重評，不能宣稱整體已達 9 分；原覆核對戰術差異、美術／動作可讀性與完整戰鬥品質的其他意見，仍需另輪內容工作和完整實玩覆核。

本輪以明確檔案清單 stage／本機繁中 commit。起始即有大量他人髒檔、舊測試紀錄及導航新增檔，均不納入本次提交。自己的 review／release 匯出、暫存與新測試存檔已清除 57 個檔案、395,660,411 bytes，起始 2678 個髒檔無刪改；必要圖與 JSON／log 保留，見 [cleanup.json](content/r2-1/tests/cleanup.json)。

## 驗證過程中的修正

初版取圖揭露未解除的開始 gate；改成真實中心輸入後再揭露手機 touch 穿透，因此新增上述配對修復及原始 input trace 驗證，最後重新建置及重拍。瀏覽器原有 invalid UID 文字路徑回退警告逐條保留於 runtime-runs 的 `known_uid_warnings`；只有精確既有警告及其配對來源行列入該欄，其他 console／network 錯誤仍會使測試失敗。測試伺服器缺 favicon 以獨立空 icon 回應處理，沒有概括忽略 404。

新 log 的 Windows 換行與尾端空白在 stage 前正規化，字元內容及測試結果不變；轉換前後雜湊記於 `tests/log-normalization.json`，gate summary 更新為正規化檔案雜湊。原 R2 的 log 與 JSON 均未修改。
