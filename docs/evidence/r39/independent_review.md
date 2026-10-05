# R39 手機 HUD 最終獨立覆核

2026-10-05，獨立上下文，同模型。已核對 HUD、MobileTuning、VirtualJoystick、EquipmentPanel、Minimap 的 production diff，以及現有測試 JSON／實玩報告；未改 production source、未開 GPU／瀏覽器，也未重跑測試。

**結論：此範圍沒有待修的阻擋問題，可進入 root 的發布流程。**

先前回報的兩項模式回復問題已讀回修正：

- `hud.gd:1314` 的非 phone 分支移除召喚按鈕的 `normal` style override，避免手機透明樣式留在後續 tablet／desktop 布局。
- `virtual_joystick.gd:155` 的淡色 active shadow 限制在 `phone_compact`；非 phone 恢復原本 radius＋10／alpha 0.26。

Root 額外找出的 R14 Settings slider 點擊中心被裁切問題也已處理。Auto 按鈕目前加入 `pause_run_page` 首列（`hud.gd:736–740`），不是 Settings。手機「裝備」入口先清 touch、暫停，再打開「本局」；Auto 直接呼叫同一 toggle，立即修改 `auto_upgrade_enabled` 與玩家 auto channel。暫停中的 runtime probe 可能維持舊值，不能拿它否定 live 按鈕文字與實際 boolean 路徑。

本次來源核對結果：

- 手機 compact pass 在通用字型／menu 縮放之後執行；斬擊按鈕再 reset size，避免原本 minimum／font 將 60／64 膨成 73。實際暫停按鈕可為 54×44，符合最小 44 且不越界，不要求它一定只有 44 寬。
- 召喚與裝備移到底部，窄視窗有上移角落的 fallback；常駐 Auto 隱藏，Minimap 縮為 68×88。主角、相機倍率、武器範圍與怪物世界邏輯未因縮 HUD 而變動。
- `battle_hidden` 參與裝備面板的 stats visibility 判斷，loot／stats signal 不會把手機三槽列重新亮回場上。裝備名稱與效果說明可在 Pause Run 查看。
- Joystick 對 paused／非 game_running／不可見狀態拒絕新輸入；有 touch owner 時忽略 emulated mouse。HUD 在 pause、layout、focus／exit 清除移動與手動 held，Joystick 清除 touch index／mouse／中心／vector。Feedback tween 在替換前 kill，未發現累積 tween 的來源路徑。
- Tablet／desktop 的觸控尺寸、圓圈主要配色與裝備列保留；phone 專用視覺依 `phone_compact` 分支套用，兩個已發現的 style 回復缺口已解除。

已讀回證據：

- `mobile_hud_test.json`：六種手機視口及同 Arena 的旋轉紀錄，`failures=[]`；中央戰鬥 ROI 不與主要觸控矩形相交，最小點擊目標、暫停／召喚／旋轉後清除舊輸入通過。Headless fixture 使用真 ScreenTouch／ScreenDrag 與 MouseButton routing，不將它單獨稱為真手機雙指驗證。
- `targeted_gates.json`：R14、R29、ReviewR36Root、R36SummonIntegration、R36SummonRegression、AutoChannelR36 六項均 exit 0、errors 0。
- `after.json`／`AFTER_REVIEW.md`：體驗員在 `0.26.1-r39`、`index-54e029130910.pck` 的單一 Chrome 使用 native touch，左右手同時移動與旋斬、釋放、60→64→60 旋轉、Gear／Run／Auto live label 已驗證。中央清空亦由 root 讀圖確認；此 reviewer 沒有重開圖或重新實玩。
- `summon_single_check.json`：同候選包的全新局單指召喚，正常開啟並保持完整可見一秒、實際關閉，六個限定檢查全通過，沒有購買或注入狀態。先前三指 while-held 混合步驟沒有成立的前置條件，仍不追認為通過，也不將它誤報成 production 故障。

PCK SHA-256：`54e029130910ab6e8088d0aba9638f50149824a59504477f30e505d868526c0f`。來源覆核、headless geometry／input fixture、體驗員 Web 實玩與 root 讀圖的範圍已分開記錄。本報告不宣稱 R39 已公開部署。
