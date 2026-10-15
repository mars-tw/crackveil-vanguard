# R44 上架可能性優化

2026-10-15；遊戲版本 `0.29.0-r44`。本機候選版實作與自動證據：VERIFIED；商店稿：PREPARED。沒有 push、部署、原生重新匯出或商店操作。計畫：[OPTIM_PLAN_R44.md](OPTIM_PLAN_R44.md)。

## 上架風險

**Apple 4.3：高。** 同帳號已因 4.3／4.2.6 整批退件，且市場已有小隊生存遊戲。本輪有真實的空間任務與操作改進，仍不能把零檔案重複、改版號或自動測試當成 Apple 認可的重大改變。是否合併成另一款遊戲的模式、內容擁有者與代製關係、真實 TestFlight 回饋仍需產品擁有人確認。詳細比較：[DIFFERENTIATION.md](store/DIFFERENTIATION.md)。

Google 的同質內容與品質風險亦未因本機測試消失；資料安全草稿沒有上傳，也未宣稱已核對線上表單。

## 三項主要改進

1. **三陣封隙。** 開局就有地面陣記。隊長走進指定區域，兩名活隊員到達各自真實陣位，連續停留 1.2 秒才封合；楔形、圓陣、散兵依序更換位置，敵潮持續。每道回復全隊 8 HP，每關首取全封殘響 4，永久收藏、舊存檔相容、防重領與寫入失敗回復。原有三徽記和 Boss 目標保留。
2. **中斷與返回完整。** 背景／失焦會清除搖桿與斬擊輸入並暫停，回前景後由玩家明確繼續。暫停新增「撤退」，永久紀錄保留、結束本局回主選單；修正離場時旋斬特效可能讀取已離樹角色的錯誤。手機提示移開連斬面板。
3. **出貨完整度與商店材料。** 修正武器資料仍引用已被匯出排除的 R24 圖檔：八個既有 PNG 原樣移入出貨目錄，原檔保留，原生 preset 不動；新增實際 PCK 解碼檢查。另完成逐款區隔、跨 repo 素材清冊、隱私與原生缺件、繁中說明、英文審查步驟與指定尺寸真實截圖。

另外修正實際觸控長按換陣後，瀏覽器合成滑鼠放開可能多循環一次的問題；測試要求長按本身不換陣、直選後選單關閉。

長局另重現：隊員已被釋放，其留下的範圍傷害仍把失效物件傳進傷害統計，會產生 GDScript 型別錯誤。範圍傷害與普通投射物現在先驗證來源，來源消失仍可完成原有傷害，不再傳遞失效物件；新增真實敵人受傷與傷害紀錄回歸，失敗種子修正後重跑。

## 驗證與證據

| 狀態 | 驗證 | 證據 |
|---|---|---|
| VERIFIED | CI 權威清單含新增 R44、R31 終局與三支 Node 回歸，44／44 | [gates/summary.json](evidence/r44-store/gates/summary.json)；指令：`python tools/run_r43_checks.py --godot <Godot 4.7 console> --node <node> --out docs/evidence/r44-store/gates` |
| VERIFIED | R44 **96 項**：空間條件、錯陣／離開／缺隊友／死亡隊友、停留、獎勵保存／失敗回復及重試節流、背景、撤退防重複、失效來源、字型與九尺寸幾何（含 SE、大手機壓力視口、iPad 直橫／13 吋比例） | [mechanics.json](evidence/r44-store/mechanics.json)、[R44StoreTest.txt](evidence/r44-store/R44StoreTest.txt) |
| VERIFIED | 手機與 iPad：冷啟動→玩法→斷網→真實輸入換陣與就位→完成→暫停／繼續／撤退→重開→收藏；外部請求與 console error 均零 | [reviewer-path.json](evidence/r44-store/reviewer-path.json)、`tools/test_r44_reviewer.cjs` |
| VERIFIED | 既有八視口按鈕／觸控可達矩陣 | [controls/playwright_results.json](evidence/r44-store/controls/playwright_results.json) |
| VERIFIED | 既有亮度／飽和度、歷史 C2PA、R37（31 項）、R38 素材閘 | 本目錄 `luminance.txt`、`provenance.txt`、`r37-assets.txt`、`r38-assets.txt` |
| VERIFIED | 35 個遊戲資料素材引用不被四個 preset 排除，隔離空目錄載入實際 Web PCK，24 個不重複貼圖全數可解碼；舊 R43 PCK 對八個新出貨路徑確實失敗，排除工作樹檔案回退假陽性 | [runtime-assets.json](evidence/r44-store/runtime-assets.json)、[packaged-assets.json](evidence/r44-store/packaged-assets.json)、[負向對照](evidence/r44-store/pack-isolation-negative.json)；兩項加入 CI |
| VERIFIED | 版本舊字串零命中、秘密掃描零命中、nativeBuild 與原生 preset 不變 | [release-audit.json](evidence/r44-store/release-audit.json)；`tools/check_r43_release.py --previous-version 0.28.0-r43 --out docs/evidence/r44-store` |
| VERIFIED | Boss 真實 Arena 長局 **14／14 組**完成、零執行錯誤；有／無半血護衛走位樣本各 **5／6 勝** | [long-run/summary.json](evidence/r44-store/long-run/summary.json)、[analysis.json](evidence/r44-store/long-run/analysis.json) |

截圖來源為本輪 Godot Web release，無頭 Chromium 實際渲染：手機 430×932 DPR 3（1290×2796）、iPad 1032×1376 DPR 2（2064×2752）。共十二張，未後製；[畫面清單](store/SCREENSHOTS.md)、[尺寸與雜湊](store/screenshots/manifest.json)。before 三視口與 after 選單、直選介面在 `docs/evidence/r44-store/`。

最後的真實輸入路徑在手機 11.15 秒、iPad 10.52 秒完成封隙；這是控制器時間，並非人類玩家完成時間。iPad 先按現有「自動戰鬥」以免升級卡中斷示範，移動／換陣仍由輸入完成。iPad 暫停按鈕原有 2px 超出右緣，已在不放寬邊界斷言下修正。字型補上缺失的「・」，涵蓋 984／984 專案漢字；素材體積上限沒有放寬。

自動控制器按玩家正常操作移動、放開搖桿讓隊友就位；沒有改血量、傷害、任務或直接注入完成狀態。測試等待換陣冷卻與新場景的最新狀態，不把前一場景殘留 probe 當返回成功。原有測試沒有刪除或放寬；R14 只更新應等於的遊戲版號，新增 R44 並保留其餘斷言。

## Boss 護衛長局

使用真正的 `Arena.tscn`、武器、敵人、命中幀、掉落、升級與死亡規則，以固定 60 fps 模擬，不用 DPS 公式假推勝率、不跳時間、不補血、不修改敵人血量。每局新存檔；控制器選走位與陣形，啟用遊戲已有的自動升級／自動旋斬，跳過商亭。配對對照只禁用 Boss 半血護衛，保留追獵菁英。

矩陣：蒼月空庭、帷幕王庭、時輪工坊，各兩種固定種子、有／無半血護衛；另兩局蒼月零移動輸入對照（保留遊戲內建攻擊及其位移）。共十四局。後期關卡直接用新存檔進入，沒有順序解鎖時累積的局外成長。`tools/summarize_r44_evidence.py` 已逐檔驗證矩陣、原始錯誤、兩秒預告與截圖，輸出 `long-run/analysis.json`。

| 戰場／控制 | 護衛開啟 | 護衛關閉 | 觀察 |
|---|---|---|---|
| 蒼月空庭／走位 | 2／2 勝 | 2／2 勝 | Boss 約 99–101 秒擊破；一個開啟護衛樣本在預告結束前已擊破 Boss |
| 帷幕王庭／走位 | 2／2 勝 | 2／2 勝 | Boss 約 180–184 秒擊破；護衛有實際生成 |
| 時輪工坊／走位 | 1／2 勝 | 1／2 勝 | 種子 44101 約 247 秒勝；44102 兩邊均在 194.52 秒戰敗，早於 Boss 的 225 秒門檻 |
| 蒼月空庭／零移動輸入 | 2／2 勝 | 未安排 | 內建自動戰鬥足以通過此兩個開局種子，不代表玩家理解陣形 |

十二組走位配對合計 10／12 勝，有／無護衛均為 5／6（83.3%）。開啟護衛的六組走位樣本中，四組實際生成 Boss 護衛且均通關；它們從生成至 Boss 結束只有約 0.12–9.69 秒。**沒有觀察到護衛造成額外敗北，但樣本很小，不能說護衛難度或全部招式已充分驗證。** 後期敗北與隊伍／升級隨機組合，以及開局自動戰鬥較容易，都是 beta 應再觀察的平衡問題；本輪未任意調高 Boss 或護衛數值。

所有執行時間、效能或長局量測一律是**「並發載量測，僅供參考」**。控制器勝率不是人類玩家勝率，三個戰場與兩個種子不能代表全部十關、多日留存或平衡已完成；若 Boss 在兩秒預告結束前死亡，護衛開啟不等於實際遭遇護衛，統計另列實際生成數。

## 邊界與缺件

- **BLOCKED：原生實機與最終簽署包。** 本地舊匯出有 PrivacyInfo，來源是 R42、build 3 的未簽署／未實機證據，不能代表目前審查包。沒有重新匯出；需未來含 R44 的簽署 IPA／AAB、manifest／SDK、飛航冷啟動、iPad 安全區、多指與背景恢復實機證明。
- **BLOCKED：完整 Web 離線冷啟動。** 本輪驗證載入後斷網遊玩與保存；Web 外殼沒有快取完整 PCK／WASM，重新載入需網路。未把離線提示頁叫作離線遊戲。原生內容全在本機，但飛航實機仍待補。
- **BLOCKED：乾淨機效能與 beta。** 不能在同機並發情況宣稱 p95 ≤18 ms；也沒有 TestFlight 使用者回饋或多日留存證據。
- **BLOCKED：平台／帳號政策。** 未讀回 Play Console 已發布資料安全表單；未驗證正在審查二進位的所有隱私宣告。夜行列車缺本地遊戲 repo，最終二進位的跨產品比對亦未做。
- **PREPARED：商店草稿。** [名稱／副標／說明／關鍵字](store/METADATA_ZH_TW.md)、[英文審查備註](store/APP_REVIEW_NOTES_EN.md)、[隱私稽核](store/PRIVACY_AUDIT.md)、[共用素材稽核](store/SHARED_ASSETS_AUDIT.md)。這些不是上傳或已核准狀態。
- **VERIFIED：範圍。** 只有本 repo 的本輪變更進入本機提交；起始髒檔與未追蹤檔保留。沒有讀取 `.secrets`、送出內容派工、發訊息給他人、push、部署或操作 App Store Connect／Google Play。

沒有新生成點陣角色／地圖／音樂；八個既有武器／特效 PNG 以相同雜湊新增至出貨目錄，原始素材與真逐幀動畫保留。新陣記是功能性向量 UI，沒有把程序幾何當成新人物美術。素材增量：[ART_MANIFEST_R44.json](store/ART_MANIFEST_R44.json)。繁中文案依 `speak-human-tw` mode 2 直接套用，原句／原因／改法見商店文案稿。
