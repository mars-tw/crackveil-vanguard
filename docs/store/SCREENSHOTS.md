# 真實遊戲截圖清單

PREPARED：本機商店素材草稿，沒有上傳。所有圖均由無頭 Chromium 對本輪 Godot Web release 的**實際遊戲畫面**直接擷取；沒有合成角色、改圖、加促銷字卡或假裝是原生裝置截圖。

手機以 430×932 CSS、DPR 3 擷取 1290×2796 PNG；iPad 13 吋比例以 1032×1376 CSS、DPR 2 擷取 2064×2752 PNG。遊戲畫布仍遵循既有行動裝置解析度預算，截圖不是用影像編輯器放大後製。原生 iPhone／iPad 的安全區、最終匯出及實機清晰度另待驗證。

可重跑：`UI_CAPTURE_PLAYWRIGHT=<既有 node_modules> node tools/test_r44_reviewer.cjs`。遊戲從本機 `http://127.0.0.1:8144/r44-store/` 載入，完成載入後切成離線測封隙、暫停與撤退；重開 Web 引擎前恢復本機網路。未用 JS 修改遊戲血量、任務或獎勵。

iPad 路徑按下現有「自動戰鬥」後測試，與手機的初始模式相同；移動、長按、直選、暫停與撤退仍由實際輸入完成。這個設定也列在英文審查步驟中。

| 順序 | 真實畫面與一句說明 | 手機 | iPad |
|---|---|---|---|
| 1 | 開局橘色楔形陣記：帶隊靠近，隊員到位才開始封隙 | [1290×2796](screenshots/01-relay-1290x2796.png) | [2064×2752](screenshots/01-relay-2064x2752.png) |
| 2 | 切成圓陣，隊友圍住隊長，向第二道藍色陣記移動 | [1290×2796](screenshots/02-ring-1290x2796.png) | [2064×2752](screenshots/02-ring-2064x2752.png) |
| 3 | 散兵陣位拉開隊伍，前往第三道綠色陣記 | [1290×2796](screenshots/02-scatter-1290x2796.png) | [2064×2752](screenshots/02-scatter-2064x2752.png) |
| 4 | 三陣封隙完成，回到敵潮戰鬥；實際場景會顯示當時獎勵／下一目標 | [1290×2796](screenshots/03-sealed-1290x2796.png) | [2064×2752](screenshots/03-sealed-2064x2752.png) |
| 5 | 暫停「本局」列出完成狀態，底部可繼續或撤退 | [1290×2796](screenshots/04-objectives-1290x2796.png) | [2064×2752](screenshots/04-objectives-2064x2752.png) |
| 6 | 撤退並重開後，戰術收藏保留「三陣封隙：已封合」 | [1290×2796](screenshots/05-saved-1290x2796.png) | [2064×2752](screenshots/05-saved-2064x2752.png) |

每張尺寸、SHA-256、來源 PCK 與圖像增量由 `screenshots/manifest.json` 記錄。擷取時的遊戲時間及操作驗證在 `../evidence/r44-store/reviewer-path.json`；before／after 主選單和 before 戰鬥圖在本輪 evidence，至少三種視口。

這些素材已可本機檢閱；送審前仍需與未來真正含 R44 的簽署包核對，不把目前 build 3 當成相同遊戲版本。
