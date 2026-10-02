# R32 整合獨立覆核

日期：2026-10-02。這是同模型、獨立上下文的程式碼與引擎覆核，不是多模型驗證，也不取代瀏覽器遊玩報告。

範圍：arena、GameManager、HUD、player_visual、first_run_guide、combat_readout、equipment services 與跨工作單位互動。覆核者未修改整合來源檔；修正由 root 執行。

## 發現與修正驗證

| 發現 | 影響與再現 | 狀態 |
| --- | --- | --- |
| HUD 的 `squad_count :=` 型別推導失敗 | `R31EndgameGate` 可以 exit 0 且印 PASS，但 HUD script 實際載入失敗。不能只看結束碼。 | root 已改成明確 `int`；最終 gate 乾淨通過 |
| silhouette shader 把 fragment `COLOR` 當成純 modulate | 原碼再次乘貼圖 RGB，導致顏色平方變暗；透明 texel 的 alpha 已是 0，描邊也被乘成透明。 | root 改用 vertex varying 傳遞 tint；來源已讀回確認 |
| 手機 quick controls 被 stats 更新重新顯示 | layout 隱藏後，10 Hz 的 stats handler 仍透過 `_on_pause_changed(false)` 顯示它。 | root 加上相同 mobile 條件；三視口引擎測試通過 |
| 直向裝備列覆蓋搖桿 | 390×844 原裝備框 `(45, 664, 300, 38)`，搖桿觸控框 `(18, 583.872, 232.128, 232.128)`，兩者交疊。 | root 將裝備列移到搖桿上緣 12 px；新框 `(45, 527.872, 300, 44)`，測試通過 |
| CombatReadout 經通用 mobile scaling 被撐大 | 直向原面板高 103 px，侵入 toast；橫向原寬 200 px，偏離配置的 168 px。 | root 固定 detail 字級與 rows 間距；最終三視口高 62 px，測試通過 |
| 殘響重置錯把固定裝備 HP 除以舊倍率 | 開局 `echo_vitality` Lv.5（×1.10）、裝備 +48 HP，重置殘響後實際 HP 153.636，應為 158。再次清掉裝備也會留下錯誤基礎值。 | root 在 meta 換算前扣掉固定裝備 HP、換算後加回。最終 actual／expected 同為 158；裝備 reset 亦通過 |

shader 的輸入定義已對照 [Godot 官方 CanvasItem shader 文件](https://docs.godotengine.org/en/latest/tutorials/shaders/shader_reference/canvas_item_shader.html)。該文件明確區分 vertex 的 modulate 與 fragment 已乘貼圖的 `COLOR`；這次修正只改取色，不改動畫序列。

## 已通過的跨系統檢查

- 真正的 arena 只有一個 CanvasModulate，theme grade 與 device grade 由同一 owner 相乘。
- 真正招募的新隊員收到一次護甲加成；重複執行 GameManager 的 meta／equipment refresh 不重複加值。
- 開局殘響 HP ×1.10、裝備固定 +48、暫停重置殘響後 HP 為正確的 158；清掉裝備會恢復正確基礎 HP，另加的 +20 個人移速仍保留。
- 魔王死亡完成後，保證傳說與先前待領裝備都在 `stage_victory_requested` 之前領取。引擎捕捉的勝利 summary 為拾取 5 件、含 1 件傳說、pending items 為 0。
- 新 HUD 裝備槽在桌面 1280×720、手機橫向 844×390、手機直向 390×844 皆留在視口內；最終手機字級與 toast 實際文字高度沒有截斷。
- 未改裝備時連續更新 20 次 stats，三個按鈕的 StyleBox instance IDs 保持相同，沒有在 10 Hz stats 更新時重建樣式。
- hero shader 附在既有 AnimatedSprite2D；8 格 walk 與 6 格 attack 仍存在。完整 impact timing 由 TrueAnimationRegressionTest 另驗。

## 引擎證據

新增可重跑測試：`res://scenes/debug/ReviewR32IntegrationTest.tscn`。測試資料使用專用 user save paths，不修改玩家正式存檔。測試涵蓋真實 recruit、meta refresh、魔王 loot／summary 順序、裝備 reset、三視口幾何、toast 文字尺寸、StyleBox cache。

- `docs/evidence/r32/review_R31EndgameGate.txt`：保留首輪 HUD Parse Error 與錯誤後仍印 PASS 的證據。
- `docs/evidence/r32/review_IntegrationGeometry_initial.txt`：保留直向裝備列覆蓋搖桿的再現。
- `docs/evidence/r32/review_IntegrationGeometry_runtime.txt`：前五項修正後的幾何與真實 runtime 檢查。
- `docs/evidence/r32/review_MetaReset_initial.txt`：非零殘響倍率與護甲交互的確定性失敗。
- `docs/evidence/r32/review_Integration_final.txt`：六項修正後，三視口、真實招募、魔王 summary、殘響／裝備 reset、StyleBox cache 全通過。
- `docs/evidence/r32/review_R31EndgameGate_final.txt`：最終重跑 boss、敗北、重試、主選單、勝利與 release hook exclusion，全通過。
- `docs/evidence/r32/review_TrueAnimationRegressionTest_final.txt`：shader 整合後，真正的 frame 2 impact、whiff 零傷害與 recovery／death contracts 全通過。

最終結論：本次覆核發現的六項問題都已修正。`ReviewR32IntegrationTest`、`R31EndgameGate`、`TrueAnimationRegressionTest` 均印出 PASS、exit 0，且輸出沒有 `SCRIPT ERROR`／`ERROR:`。目前沒有未修正的可再現整合問題。這份證據涵蓋事件、數值、介面幾何與樣式快取；畫面觀感與瀏覽器幀率仍以實際遊玩報告為準。
