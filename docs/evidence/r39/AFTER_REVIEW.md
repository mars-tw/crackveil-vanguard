# R39 手機實玩覆核

實測候選版為 `0.26.1-r39`，`index-54e029130910.pck`；PCK SHA-256：`54e029130910ab6e8088d0aba9638f50149824a59504477f30e505d868526c0f`。Chrome 單一程序、844×390／DPR 2，使用手機模擬與實際觸控輸入，並非實體手機測試。只讀 runtime／controls，沒有注入生命、金幣、RNG 或遊戲時間。未購買召喚。Chrome 已關閉，production source 未更動。小型發布摘要為 [after_summary.json](after_summary.json)。

## 已驗證

- 自然戰鬥超過 10 秒。左手移動、右手按住旋斬可同時生效；右手放開後左移 79.9 world px；全部放開後移動 0 px。
- 同尺寸輸入區聯集由 48,612 降為 22,635 CSS px²，佔視窗比例 14.77%→6.88%。這是觸控熱區面積，不能當成不透明畫素遮擋率。新控制區與原本中央戰鬥 ROI 的交集全部為 0。
- 召喚 64×44、裝備 44×44、斬 60×60、搖桿熱區約 109×109；場上自動戰鬥按鈕隱藏。實圖中主角周圍及直式中段已空出。
- 同頁旋轉：斬 60→64→60，未留下放大尺寸。直式暫停為 54×44，右界 388，在 390 寬視窗內；符合最小 44 的點擊尺寸。原 fixture 強求寬 44 的失敗不構成越界。
- 裝備按鈕可打開暫停的「本局」分頁，第一列有自動戰鬥開關。初期三槽為空；後期自然取得裂刃晶核、雷鑄護甲、雷步戰靴。恢復設定時真圖文字顯示「自動戰鬥：開」。
- 沒有收集到 JavaScript／Godot script／WebGL 錯誤。

## 不冒稱通過的部分

暫停時 auto runtime snapshot 會留舊值。source 顯示 toggle 立即修改實際 boolean 與 player channel，HUD 的常駐 process 直接讀新值更新文字；但 toggle 不送 `emit_stats()`，暫停期間 GameManager 週期 stats 也停止。因此 raw checks 中 toggle／restore 的舊 boolean 不代表操作失敗；以實圖文字及恢復戰鬥後的狀態判讀。

按住時開召喚尚未驗證：第三指前的 snapshot 已是 `held=false`，沒有有效前提。該次及獨立單點 fallback 都未留下可見商店，因此不能把空彈窗後的「未殘留 input」稱為開／關商店通過。source 已有先清 touch 再開 shop，但需一個有效 pressed／guard 通過的實際操作證據。這份資料也不足以宣稱 summon production 必定故障。

第一次 runner 在自然升級附近因 modal 提前退出；第二次補上逐步 raw snapshots，完成上述控制／旋轉檢查。原始事件與未通過的 checks 保留於本機，未改成全通過，也不列入發布摘要。請依摘要的驗證限制及本文件判讀，避免把 stale probe 當 production failure。

發布證據：[橫式實玩圖](phone-after.png)、[直式實玩圖](phone-after-portrait.png)、[after_summary.json](after_summary.json)。Gear 原始截圖與完整事件留於本機。

## 最後單指召喚補驗

依相同候選版，只做一次全新 844×390 手機局。自然時間 0.8118 秒，確認 game_running 為真、contract／upgrade／shop／system pause 皆為假，且召喚按鈕可見；沒有先動 Gear、自動設定或其他手指。

實際單指按下時維持戰鬥畫面，放開後等一秒，星紋召喚完整面板可見且遊戲暫停。再實際點「返回戰場」，商店隱藏、system pause 解除、held／pending 都為假。六個限定檢查全通過，沒有錯誤，沒有買東西或注入狀態。新底部召喚入口可用，不需要因先前無效前置條件的測試修改 production。

補驗證據：[summon_single_check.json](summon_single_check.json)。按下／放開實圖與原始完整 snapshot 留於本機，發布檔保留必要 guard、開啟／關閉狀態與六項檢查。補驗不能倒推先前三指 while-held 檢查通過，原始紀錄仍保留。Chrome 已關閉。
