# R37 戰鬥與效能修整

R36 實玩曾出現手動攻擊有施放、沒有命中的情況：12–20 發遠程彈幕先把近身敵人清掉，隊長的 280 旋斬／360 大斬只在空區演出。R37 讓新的手動 Space 點按在敵人位於外圈時，利用真準備動作踏進再拔刀；同時移除幾項已確認的重複查詢與文字更新。這份報告是 controlled headless fixture 的證據，尚未宣稱自然遊玩命中率或 FPS 改善。

## 操作與真傷害

Space／手機斬按鈕的新手動 cast 才能踏進。搜尋範圍 536、踏進上限 200；目標已在 360 內時不踏進。位移只由 `CharacterBody2D.move_and_slide` 在攻擊的 anticipation 執行，沒有直接改座標的瞬移，傷害仍只在第 2 格 pose。近身 combo、自動戰鬥與持續旋斬都不會強迫玩家 dash。

受傷、死亡、模態暫停、重新開局、目標死亡／pool generation 更換會清掉踏進狀態；手動單點仍有 2.35 秒冷卻。原三段 18 個 authored poses、原 27 格其他狀態、按住旋斬的 180 能量／每次 8 成本與 32／秒回能維持。射擊數量 12→16→20、40.28 枚／秒 starter 與實際 damage／pierce 都保留。

新 gate 使用真 Space key 事件和 production PlayerController 的輪詢路徑；Hero movement、Visual 與 SceneTree clock 真正運行。放三隻在約 500 像素外的敵人：按鍵當下座標／HP 不變；準備動作中實際前進；第 2 幀 Hero 位於 `(180, 0)`，三隻都受真傷，後方敵人未傷。原固定原點的 360 cone 無法碰到該群。角色素材未以旋轉單張圖片假造新動畫。

## 已量測的運算減量

| 項目 | 原行為 | 新 fixture 結果 |
| --- | --- | --- |
| 近身普攻空場搜尋 | ready 後每 render tick 查詢 | 60 ticks 查 12 次，最多約 80 ms 重新找近敵 |
| Cone 篩選 | 每個候選 length／normalize／angle_to | range 用距離平方，正常小於 90° cone 用 dot 平方；本群 0 次 sqrt |
| Channel presentation | 每 update 查 group、debug／assets_ready | 120 updates 只有 1 次 readiness check；服務釋放或 run generation 更換會重查 |
| DamageNumber | 複製一個 shadow Label，merge 重設 font／rect | 一個有 native outline 的 Label；100 次 merge 合計 101，重複 layout override 0 次 |
| DamageNumber pop | lifetime 全程寫 scale | 8 個 render ticks 後停止 scale 重設；漂浮與淡出仍完整 |
| CombatFeedback | kill bookkeeping 即使無效果也 redraw | effects 為空時 redraw 0，kill clock 保留 |

Presentation cache 有 arena instance ID、Hero run generation、WeakRef 三個檢查。原服務被釋放時立即查替換者，只有找不到服務的 miss 使用短 TTL，避免留下已釋放節點或錯等 250 ms。傷害數字 reuse 會恢復 root alpha、pop、顏色與字體，critical caption 仍完整。

## 唯讀 probe

既有 HUD runtime 不需新增 gameplay mutation API。`cleave` 新欄位：`step_active`、`step_distance`、`step_total_distance`、`assisted_casts`、`step_aborts`、`step_reason`、`empty_active_impacts`、`auto_target_queries`、`candidate_checks`、`cone_sqrt_calls`、`presentation_lookups`、`presentation_ready_checks`。

`firepower.r37_polish` 包含同樣的真計數，以及 damage number 的 `damage_number_layout_updates`、`damage_number_process_updates`、`damage_number_alpha_updates`、`damage_number_scale_updates`。`DamageNumber.get_render_debug_state` 提供 Label 數／font／alpha／pop 狀態；`CombatFeedback.get_debug_state.redraw_requests` 提供真正 redraw requests。Damage number static counters 是 process lifetime 累積值，做相鄰 sample 差，不當作每 run 已自動歸零的數值。

## 驗證與界限

`CombatPolishR37Test`、`CaptainComboChannelR35Test`、`FirepowerR36Test`、`CombatR33RegressionTest` 均通過，無 SCRIPT_ERROR。新的 controlled gate 與 R35／R36 原始 log 在 `docs/evidence/r37/combat/`；舊 R33 gate 在本輪實際執行，未覆寫歷史 R33 報告。

上述實作與 headless 驗證階段未開 Chrome／native GPU，沒有新增貼圖或改背景、Enemy／GM／HUD。Root 負責對外文字、完整整合與發布驗證；候選匯出後的真自然遊玩補驗記錄在下一節。

## 候選 fef310 的真 Chrome 補驗

完成後另依 root 指示，對 `0.25.0-r37`／PCK `fef310ab72747659d869ead507b6ec72f269ef052802b01c32ffb66a1934ca52` 進行單一 Chrome 的依序實玩，沒有錄影或 gameplay state 注入。真 main-menu seed 輸入讓三段都使用 `20261002`，GPU preference 關閉，實際都是 ANGLE Intel Graphics D3D11。

| 場景 | active 秒 | FPS 平均／中位數／最低 | 敵人／logical 子彈峰值 |
| --- | ---: | ---: | ---: |
| R36 release baseline，桌機 | 30.19 | 59.76／60／58 | 95／82 |
| R37 候選，桌機 | 30.66 | 59.97／60／59 | 111／52 |
| R37 候選，手機尺寸 | 45.02 | 59.72／60／57 | 102／102 |

桌機 CSS／canvas 都為 1280×720、DPR 1；手機 CSS 844×390、canvas 1688×780、DPR 2，是桌機 Chrome 的觸控模擬，不是實體手機測試。三段在量測結束後，SCISSOR／DRAW／READ 原生 GL state 比對都正確，未見 WebGL failure 或 gameplay SCRIPT_ERROR；每段仍有一筆未對應 URL 的 console HTTP 404。相同 seed 的實際尖峰負載仍不同，而且桌機兩段都碰到 60 Hz 上限，沒有宣稱固定百分比提升。R37 平均 draw calls 為 457，R36 為 566，只作本次負載下的實數紀錄。

另做 20.05 秒真鍵盤走位／Space 的手動段。8.79 秒點按大斬實際命中 9 隻，手動大斬累積 10 hits、empty_active_impacts 0；14.45 秒開始按住，17.58 秒升級模態出現時真 keyup，持續旋斬有 8 個 impacts／9 hits、成本 64。結束後 held、pending、effect_active 全為 false。這局近敵已在 360 內，assisted_casts／step_distance 都是 0，因此只確認自然實玩的手動近戰有真用處，沒有冒稱在 Web 自然實玩觀察到踏進或精確動畫 frame；180px／第 2 幀的證據仍來自前述 controlled gate。

已檢視 15.97 秒的 [場內截圖](evidence/r37/gameplay.png)：金白旋斬、多排實際子彈、完整角色與地標都可辨，沒有黑畫面或 GL state 異常。完整 JSON／PNG 在 `docs/evidence/r37/performance/`，供公開文件引用的 compact 資料為 `docs/evidence/r37/performance_summary.json`。所有自開 Chrome 已關閉，production source 仍 frozen；這一 lane 沒有 commit 或發布。
