# R4 交付：把戰況與構築直接呈現給玩家

版本 **0.33.0-content-r4**，基準 `0b764c10287124c3fc78b0691dd70e4035d32624`。本輪完成五個有界可見改善；只在本機提交，沒有發布。技術驗收不能代替內容評分，雙評審平均至少 9 分與零嚴重問題的目標仍未成立，等待獨立內容覆核；沒有宣稱新的 Claude 分數。

[八面向實作計畫](OPTIM_PLAN_CONTENT_R4.md) · [十五張實拍入口](content/r4/INDEX.md) · [逐張來源清冊](content/r4/review-manifest.json) · [原始收據](content/r4/tests/)

## 玩家可見的變化

| 面向 | 已落地 | 驗證重點 |
|---|---|---|
| UI／UX | 招募、一般菁英、追獵與拾取進固定邊角戰報；點開暫停、三則一頁，重複保留次數與首末時間 | 普通通知不再以長條覆蓋戰場；真正預警、反噬、封隙、護衛訊息仍即時 |
| 選單 | 每線五項同屏；三線共用一格；現役／選後實際三人、換下／先發、被換節點、成本與收益代價 | 320×568 最大字級亦可直接點第五節點，無長捲動 |
| 人物 | 隊長唯一暖金冠形與腳邊角標；隊友冰藍職責符號 | 不改角色、碰撞或血量，密集畫面仍可找隊長 |
| 地圖 | 正面石門、包抄雙側柱門、遠射晶塔／祭壇、守關王座 | 重用真既有地標圖，不以換色占位，不新增障礙 |
| 技能 | 友方旋斬亮度與普通拾取視覺收斂；普通傷害數字加強合併 | 傷害、拾取價值與判定不變；敵招維持珊瑚色危險輪廓 |
| 角色外觀 | 保留原有角色貼圖、臉、配色與動畫 | 只增加外層識別，不重新生成素材 |
| 動作流暢 | 實際出招者加方向輪廓；同一護衛起手／命中／收招實拍 | 原真逐幀動畫、空揮、回收與兩輪攻防斷言保留 |
| 結算與進度 | 首屏構築／時間／存活／實測收益；輸出、支援、紀錄分頁；主要按鈕固定；第二次免費選擇 0～4 進度 | 羈絆總量與個人支援分開，HP 有單位；倒下隊員仍入出擊分母 |

事件計數與被動收益分開處理：真事件零次會寫未觸發；已換先發顯示真隊員傷害／回復／減傷；被動寫適用條件，無盡停用的封隙節點明示。沒有把缺少事件 counter 當成整個節點沒作用。成絆與換陣改由單一權威來源收錄，普通招募名稱含「護衛」不會搶預警位置。

## 實際驗證

- 現行 **50 個回歸 gate（47 Godot＋3 Node）**，含全部既有 49 項與新增 R4；原測試斷言保留，只有 R14 精確版本更新。逐案 exit0、無 engine ERROR、原始成功訊息與 SHA；[原始清單](content/r4/tests/gates/summary.json)。這是本機回歸與匯出，沒有冒稱已跑遠端部署 workflow。
- 新 R4 runtime fixture：**33374 checks／0 failures**；三視口×小／預設／最大字級，各 15 節點預覽。檢查真實字級增長、五種 Button 狀態文字尺寸、真通知事件鏈、真死亡後結算分母，以及真先發傷害→帳本→正式摘要→首屏。[機制收據](content/r4/tests/mechanics.json)。字元／幾何 checks 不當成獨立遊戲語義案例數。
- 八組 Web 真輸入：844×390、390×844、320×568、1366×600，各預設／最大字級；每組 18 頁、五節點直接選、真免費解鎖／裝備／卸下／關閉／重進／出擊，及戰報開關／翻頁。第四敗結果另點輸出／支援／紀錄與分頁，再由主要按鈕到第五局整備。[控制收據](content/r4/tests/controls.json)。護送真通關後另縮至 320×568 最大字級，真觸控遍歷全部九位實際隊員的輸出／支援與紀錄，短手機每頁一位、其他視口每頁兩位，最後點固定整備入口。[連續結果操作收據](content/r4/tests/result-controls.json)。
- 真字型 subset 對全部當前 runtime 繁中字元覆蓋，缺字 0；另以原始圖實看。[字型證據](content/r4/tests/font-coverage.json)。
- 來源在本輪完整 CI **執行前**與執行後綁定，含全部 runtime／資產、debug 測試、實際 Python runner、三個 Node driver 與 workflow；每個 Godot case 另有前後收據。原生子程序獨立 APPDATA／LOCALAPPDATA＋autoload 前 QA profile，Web fresh context。[CI 前來源](content/r4/tests/ci-source-before.json)／[後來源](content/r4/tests/ci-source-after.json)。

## 同種子正式實跑

兩套以 fresh 等價進度、seed 55210，透過正常編成、免費解鎖、裝備、種子欄位與移動／換陣操作。沒有改 HP、DPS、時間、完成旗標。三封後只以正常移動優先追仍須解決的真護衛／Boss，避免被最近雜兵無限牽走。

| 比較 | 裂線突擊／楔形破盾 | 星盾護送／圓陣護送 |
|---|---:|---:|
| 真通關秒數 | 104.787 | 105.732 |
| 正面封合用時 | 11.519 | 12.495 |
| 包抄承傷／當段起始 HP 容量 | 0.1208 | 0.0622 |
| 實際正面陣形 | wedge | ring |

突擊正面較快約 7.8%，實際破盾額外傷害 59.32 HP；護送包抄歸一化承傷較低約 48.5%。不以兩套不同原始生命的剩餘總 HP 直接推論優勢。[兩份完整資料與 runner](content/r4/tests/paired/runner.json)。

## 圖證、嘗試與限制

十五張 PNG 每張有 UTC、版本、source manifest、實際 PCK 與 PNG SHA；多數橫式 DPR3，另含短手機、直式真通關與短桌面。12／13 是實際連續通關；14／15 是四次真致死結算的受控 fixture，畫面 0 秒與大額減傷來自致死注入，不拿來證明自然支援強度。原圖沒有抹除、裁切或覆字。[十五張清冊](content/r4/review-manifest.json)。

開發時真圖抓出觸控按下樣式撐大、普通字級放大後名稱與說明截字，均修正並保留必要 before 圖與 raw。一次 milestone 取景因既有 invalid-UID warning 的匿名 callback 尾行被 driver 判成 error 而 BLOCKED；保留 [原始失敗 log](content/r4/tests/attempts/milestone-warning-frame-and-footer-refine/browser-milestone.txt) 與該次 captures JSON，改為可追查命名 callback 後重驗，沒有放寬 ERROR 判定。首個開發 smoke raw 曾在加上自動歸檔前被後次覆寫，未列正式驗收；此後 raw 歸檔與最終正式收據分開保留。自然 pilot 的全部嘗試分母另見 [嘗試收據](content/r4/tests/attempt-summary.json)。護送自然局在 Codex 停止回應後由 Claude Code 接手完成：先後兩次護送嘗試因設定檢查不成立而停止，其中一次是取景 driver 讀到過時的滑桿矩形，點到中點，原圖顯示「介面大小：標準」，所以 Claude 刻意不寫確認檔，讓它在開戰前停下；保留原圖與 [拒收原因](content/r4/tests/attempts/escort-stale-pre-click-rect/reason.json)。driver 只加「矩形穩定後若與點擊時不同，就在實際端點補點一次」，runtime 與 CI 輸入不變；補點後原圖實看為「介面大小：大」才確認，隨後同一局自然通關，取得 05／07／13 與 320×568 最大字級結果頁操作。

完整 CI 首輪為 49／50，R31 抓到新結果頁漏掉既有精確敗北／擊破文案；恢復後第二輪 50／50、前後來源一致。其後真裝備兩行描述在最大字戰報超出列高，新增相交檢查又抓到短手機雙角色卡 3 px 重疊；保留原文，只調顯示換行與短手機每頁人數。第三輪 50／50 亦保留為此前來源；事故審查期間，一批完成 6 項後依 supervisor hold 停止，沒有 after snapshot、不列完整通過。最後以修正後 guard 與來源完整 50／50，不拿前輪成功冒充後改來源。[首輪](content/r4/tests/attempts/ci-first-r31-copy-failure/reason.json)／[第二輪](content/r4/tests/attempts/ci-second-verified-before-text-spacing/reason.json)／[第三輪](content/r4/tests/attempts/ci-third-verified-before-output-guard/reason.json)／[中止批次](content/r4/tests/attempts/ci-fourth-interrupted-by-primary-hold/reason.json)。首輪封存時一份 JSON 曾誤取後續 unit 收據，原誤取檔另存並由既有自動歸檔恢復原始 33260／0；[修正來源與 SHA](content/r4/tests/attempts/ci-first-r31-copy-failure/receipt-provenance-correction.json) 明列，不改 raw。

實跑輸出曾有一次實際邊界事故：複製的 QA driver 漏改目錄，突擊雖真通關，卻暫時覆寫 R3 的一份 paired JSON。立即停止自己的護送程序、保留誤寫資料；先核對 Git 原 blob 的 SHA 等於本輪事前 history，才完整恢復該一檔。此後 669 個歷史與 2675 個 foreign 檔案已逐 SHA 恢復一致；不宣稱整輪從未觸碰。該批 **1 次錯址通關＋1 次中止**都列入 native 嘗試分母。修正後所有 native 含 unit／pilot 一律用獨立 docs 副本；執行前拒絕越界與 live ROOT，唯一 token／seed／run ID／mtime、exit0／無 ERROR／真 PASS 及前後保全全通過才 copyback 到固定 R4 目的地。JSON／PNG／PCK／報告寫入亦先檢 resolved allowlist，三份事前清冊有獨立固定 SHA。[事故與恢復](content/r4/tests/attempts/misrouted-native-output/boundary-incident.json)／[靜態拒絕檢查](content/r4/tests/boundary-static-check.json)。

既有 PCK 匯出仍可能輸出 invalid-UID 的明確 text-path fallback warning；逐張保留 warning，沒有把它寫成零警告。真正 SCRIPT ERROR／engine ERROR 一律失敗。這輪沒有新增生成美術或音樂；戰報展開會暫停，完整名單仍需明確翻頁。真人試玩、實機與乾淨機效能由 owner 另安排，不宣稱通過，也不以此代替本輪內容評分。

R1／R2／R2.1／R3 原證據 669 檔收尾與事前 SHA 一致，前述暫時覆寫事故另有記錄；本輪開始 2675 個他人髒檔逐檔保全，父代理工單／導航／review 不進提交。只 stage [逐檔作者清單](content/r4/tests/owned-files.json)，不以「新檔」推論作者。清理先移除本輪 junction 本身，才移除經界線驗證的暫存副本與包體；必要 15 圖、before 圖、raw 與 JSON 保留。[清理收據](content/r4/tests/cleanup.json)。預設六個原生 profile 以本輪任何 Godot 前快照與收尾大小／mtime／SHA 比對，不讀出存檔內容。

最終來源 640 檔，manifest `3be3075b1e3bc0f1c86f006e8afc74880b9d9b581abde3ffcb126bda0131ebdc`；release PCK `0cbe4475cecac56ff73c11ede34e9a3f6d892d4de336cf0ae4c424c9d42a6979`，review PCK `58393fb163a21c39a528833490c9acefaf01325a7949b9da6407834120ecb2f3`。四個舊驗證入口只加精確 0.33.0 路由；舊 body 逐位元組（換行正規化）對基準保留，新版本由嚴格 R4 驗證器檢查自身來源、測試、圖證與保全。
