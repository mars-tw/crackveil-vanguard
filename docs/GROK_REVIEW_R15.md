# Crackveil Vanguard — 對抗性覆核 R15（R13 爽度 + R14 行動端）

**審查者**：監工／對抗覆核（只審不改）  
**審查對象**（最近 commit；使用者指稱「三 commit」之 R13/R14 交付與急修）：

| Commit | 說明 |
|--------|------|
| `d1d0336` | R13 爽度加碼 + R14 行動端翻修 |
| `49817a1` | R14 急修：1.96x／字 39px／觸控 76px／小視口觸發／設定按鈕回歸 |
| `HEAD` | `49817a1`（其前一基線 `7d4e47d` R12 不在本輪功能宣稱，僅作對照） |

**範圍**：彈著擊退／雷鏈爆閃／COMBO 里程碑 buff／Boss 出場／精英 slow-mo／升級光柱；`mobile_tuning`；手機 zoom；背景主題對比 + 色相演化；新音效池與節流；歷輪紅線 + 決定性快檢。  
**方法**：靜態讀碼 + 回歸腳本對照（R13/R14Regression）；**本輪未重跑 headless Godot**。  
**日期**：2026-07-11  

---

## 執行摘要

| # | 議題 | 判定 | 嚴重度 |
|---|------|------|--------|
| (1) | COMBO 里程碑 5s 射速 +10% 與升級／進化疊加；斷連判定 | **可接受（輕度乘算）**；斷連主幹正確；里程碑可重刷 | **P2** 平衡監視 |
| (2) | slow-mo / hit-stop 多來源 `time_scale` 競態 | **會互相搶寫**；**永久卡慢速機率低**；**會提前結束彼此緩速** | **P1** 手感／正確性 |
| (3) | `mobile_tuning` 戰內覆蓋 + 844×390 | 戰內 HUD **有接**；選單／契約／升級 **有測**；**商店／結算橫式未進回歸**且 **GameOver 橫式內容區可倒掛** | **P1** 橫式結算 |
| (4) | 背景色相演化 × CanvasModulate 敵彈預示 | **未破可讀性紅線**；`ember_rift` 晚場風險抬升 | **P2** 監視 |
| (5) | roar / milestone / catch 池與節流 | **有池（12）+ 每 id 冷卻**；滿場仍可能搶槽 | **P2** |
| (6) | 歷輪紅線 + 決定性 | **未見破線**；決定性主幹大致成立（預存灰區仍在） | — |

**總判定**：**軟 Go／可進實機與橫式結算驗收**。R13 爽度與 R14 行動端主幹落地；**不可當硬 Go 的兩點**是 (2) `time_scale` 跨系統無共享 token，以及 (3) 橫式 390 高結算／未覆蓋的 modal 回歸缺口。  

狀態標籤：**成立**／**部分成立**／**未達**／**新風險**／**紅線違規**／**預存灰區**

優先級：**P0** 軟鎖／破 cap／可讀性崩潰／謊稱；**P1** 競態體感、橫式 UI 壞版、平衡誤導；**P2** 調校與監視。

---

## (0) 變更盤點（對照宣稱）

| 宣稱 | 碼上狀態 | 主要位置 |
|------|----------|----------|
| 彈著擊退（裂線） | **成立** | `projectile.gd:263-270` |
| 雷鏈爆閃／加寬 | **成立** | `chain_lightning_weapon.gd:55-63`；`lightning_arc.gd:10,34-40` |
| COMBO 25/50/100 + 5s 射速 | **成立** | `game_manager.gd:26-28,508-521,952-953` |
| Boss 出場演出 + roar | **成立** | `game_manager.gd:1394-1399`；`hud.gd:865-886`；`arena_background.gd:823-825` |
| 精英 slow-mo（加長 hit-stop） | **成立**（0.15s） | `enemy.gd:568-571`（R13 自 0.04→0.15） |
| 升級光柱 | **成立** | `game_manager.gd:579-582`；`death_burst.gd` `level_column` |
| `mobile_tuning` 觸控或寬&lt;700 | **成立** | `mobile_tuning.gd:15-32` |
| portrait 1.96x／觸控 76 | **成立**（短邊≤430） | `mobile_tuning.gd:41-42,64-65` |
| 手機 zoom 1.56 | **成立** | `mobile_tuning.gd:6,69-70` |
| 背景主題對比 + 色相演化 | **成立** | `arena_background.gd:19-78,816-880` |
| 新音效 | **成立** | `audio_manager.gd:21-23,37-39`；資產 `boss_roar`／`combo_milestone`／`boomerang_catch` |

---

## (1) COMBO 里程碑射速 buff：疊加與斷連

### 1.1 機制證據

| 項目 | 值／行為 | 檔案:行 |
|------|----------|---------|
| 里程碑 | `[25, 50, 100]` | `game_manager.gd:27` |
| Buff 時長 | `5.0` s，`max(timer, 5)` **刷新不疊層** | `game_manager.gd:28,516` |
| 射速倍率 | **固定 1.1 或 1.0**（非 1.1³） | `game_manager.gd:952-953` |
| 接入武器 | `scaled_cooldown = base / mult` | `base_weapon.gd:63-67` |
| 永久冷卻升級 | `cooldown *= cooldown_upgrade_multiplier`（下限 0.08） | `weapon_data.gd:147-148,154` |
| 進化 | 改 data／質變，**不**另開 fire_rate API | `weapon_data.gd:160-163` |
| 星環 | **不受** `scaled_cooldown`（無射速 timer） | `orbit_weapon.gd:13-17` |
| UI 文案 | `OVERDRIVE +10%` | `hud.gd:807` |
| 斷連窗口 | `COMBO_WINDOW = 1.15` | `game_manager.gd:26,476-485,524-533` |
| 斷連時 | 清 `combo_count`／pulse／**milestone 進度**；**不清** `combo_fire_rate_timer` | `game_manager.gd:529-532` vs `283-284` |
| 暫停 | `elapsed_time` 與 buff timer **僅未 pause 時推進** | `game_manager.gd:278-287` |

### 1.2 與升級／進化疊加

- **乘算結構**：永久 CD 先寫入 `data.cooldown`，開火時再 `/ get_fire_rate_multiplier()`。  
- **量級**：+10% 射速 = 冷卻 ÷1.1（約 −9.1% CD）。在已堆 3～4 層 `weapon_cooldown`（常見 0.88～0.9／層）之上，屬**短窗增益**，不是第二條永久射速軌。  
- **不疊倍率**：25→50→100 只刷新 5s 計時，倍率仍 1.1。  
- **可重刷里程碑**：`_tick_combo_break` 將 `last_combo_milestone_count = 0`（`:532`），同局斷連後再練到 25/50/100 可再拿 5s buff。高練度清場下屬 **P2 節奏偏甜**，非爆炸疊乘。  
- **跨量跳殺**：`_try_trigger_combo_milestone` 無 `break`（`:508-511`），理論上一次把 count 拉過 100 會連觸三里程碑（三發 VFX／impact）；一般 `add_kill(1)` 不會。  
- **回歸**：R13 只驗 25 觸發、timer≥4.9、斷連 signal（`r13_regression_test.gd:62-86`），**未**驗與 CD 升級乘算或 50/100。

### 1.3 斷連判定

| 命題 | 判定 | 說明 |
|------|------|------|
| 超窗重置 combo | **成立** | `elapsed_time - combo_last_kill_time > 1.15` |
| 窗內累加 | **成立** | `:479-480` |
| 斷連後清里程碑進度 | **成立** | 可重觸發，設計取捨 |
| 斷連不砍進行中射速 buff | **成立**（合理） | timer 獨立於 combo_count |
| 暫停凍結 combo／buff | **成立** | 避免 UI 暫停偷掉窗口 |

### 1.4 結論

| ID | 結論 | 嚴重度 |
|----|------|--------|
| R15-1a | +10% 與永久 CD／進化為**溫和乘算**，量級可接受 | P2 |
| R15-1b | 斷連邏輯正確；buff 不隨斷連立刻消失 | — |
| R15-1c | 斷連重刷里程碑 → 可反覆拿 5s 窗 | P2 監視 |
| R15-1d | 星環不受 fire_rate mult → 里程碑爽感**武器不均** | P2 |

**條目總結**：**不構成平衡紅線**；建議實玩觀察「高 COMBO 清潮是否過乾」，非本輪阻擋項。

---

## (2) slow-mo / hit-stop：`time_scale` 多來源競態

### 2.1 寫入點盤點

| 來源 | 寫入 | Token | 還原條件 | 檔案:行 |
|------|------|-------|----------|---------|
| 戰鬥 impact（精英／Boss／COMBO pulse／milestone） | `min(scale, 0.18)` | **`hit_stop_token`** | 僅最新 token 還原 `1.0` | `game_manager.gd:311-321` |
| 升級進場 | `min(scale, 0.35)` 後 0.3s | **`upgrade_entry_token`**（另一套） | token 匹配才還原；**不匹配則直接 return 且不還原** | `game_manager.gd:566-595` |
| 精英死亡 | impact **0.15s** | hit_stop | 同上 | `enemy.gd:568-571` |
| Boss 死亡 | 先 `record_boss_kill` → `time_scale=1.0` + system pause；再 impact 時因 **paused 直接 return** | — | `enemy.gd:543-544,568-571`；`game_manager.gd:1411-1430,314-315` |
| 死亡／開局／套用升級 | 強制 `1.0` | 各路徑 | `game_manager.gd:211,619,1348` |

Timer 皆為 `create_timer(..., true, false, true)` → **無視 time_scale 的真實時間**，方向正確。

### 2.2 競態劇本

| 劇本 | 結果 | 判定 |
|------|------|------|
| 連續 hit-stop（A 後 B） | 僅 B 的 token 還原 1.0；A 過期不還原 | **同系統正確** |
| 精英 0.15s hit-stop **中途** 升級進場 0.35 | hit-stop 結束強制 `1.0` → **砍掉升級剩餘 slowmo** | **跨系統競態** |
| 升級 0.3s slowmo **中途** 再觸發 hit-stop | scale 被壓到 0.18，hit-stop 結束設 `1.0` → **升級慢動作提前結束** | **同上** |
| 升級 token 被死亡／Boss／新升級 bump | `_finish_level_up_slowmo` mismatch **不還原** scale | 通常其他路徑已設 1.0；**理論殘留窗** |
| Boss 擊殺 | pause 擋掉 Boss hit-stop；Boss 路徑先設 1.0 | **不易卡慢** |
| 永久卡在 0.18／0.35 | 需「設慢速後所有還原路徑都失敗」 | **實務低機率**；未見穩 repro 路徑 |

### 2.3 與 R13 變更的關係

- 精英 hit-stop **0.04 → 0.15**（`enemy.gd:571`）拉長與升級 0.3s 重疊窗口。  
- Milestone／pulse 也呼叫 `request_combat_impact`（`game_manager.gd:502,519`），連殺 + 升級時更容易交叉。

### 2.4 結論

| ID | 結論 | 嚴重度 |
|----|------|--------|
| R15-2a | **hit_stop 與 level-up 不共享協調器** → 誰後寫誰贏、誰先 timeout 誰可能把 scale 拉回 1.0 | **P1** |
| R15-2b | **永久卡慢速**：正常死亡／Boss／升級套用／開局會硬重置；**不列 P0** | P2 邊角 |
| R15-2c | Boss 出場本身**不**改 `time_scale`（UI tween + 背景 flash） | — |
| R15-2d | 回歸**未**覆蓋多來源 time_scale | 測試債 |

**條目總結**：**會搶恢復、會縮短對方緩速**；**不像會穩態卡死慢速**。建議後續單一 `CombatTimeScale` 協調器（本輪只審不改）。

---

## (3) `mobile_tuning` 覆蓋度與 844×390

### 3.1 觸發與尺度

| API | 行為 | 行 |
|-----|------|----|
| `use_mobile_ui` | mobile OS／觸控／寬&lt;700／短邊≤520 等 | `mobile_tuning.gd:15-32` |
| `ui_scale` | 短邊≤430：直 1.96／橫 1.86 | `:35-47` |
| `touch_target` | 短邊≤430：直 76／橫 68 | `:58-66` |
| 相機 | 1.56／威脅 1.36 | `:6-7,69-74` |

### 3.2 畫面覆蓋矩陣

| 畫面 | 接 `MobileTuning` | 自有 responsive | R14 回歸 390×844 & 844×390 |
|------|-------------------|-----------------|----------------------------|
| MainMenu | 是 `:484` | 是 | **有** |
| Contract | 是 | 是 | **有** |
| LevelUp | 是 | 是 | **有** |
| FirstRunGuide | 是 | 是 | **有** |
| **HUD（戰鬥中）** | 是 `hud.gd:659` | **完整**（面板／暫停／搖桿／技能／toast／Boss／milestone）`hud.gd:435-659` | **有**（字級＋邊界＋timer/pause 不重疊） |
| RiftShop | 是 `:179` | 是；mobile 強制 panel 高=視口- margin | **無** |
| StageVictory | 是 `:168` | 是 | **無** |
| GameOver | 是 `:276` | 是 | **無** |

### 3.3 戰內（非選單）覆蓋結論

- **成立**：暫停鈕觸控高、虛擬搖桿、主動技能鈕、HP/XP/金幣/計時/分數、COMBO pulse／milestone／break、Boss intro 標籤皆走 `_apply_responsive_layout`。  
- 字級經 `apply_control_tree` 再乘 `ui_scale`（例如 base 18 → 約 33～35px），與 R14「字真的放大」急修一致。  
- R14 驗證 HUD 在 844×390：`pause`／`hud_panel`／`score_panel` 在視口內、timer 不與 pause 重疊（`r14_regression_test.gd:231-268`）。

### 3.4 橫式 844×390 風險

| 畫面 | 靜態推演 | 判定 |
|------|----------|------|
| HUD | 橫式分支把 score 頂到 offset_top≈84；搖桿 170；技能右下 | **回歸覆蓋 → 主幹 OK** |
| LevelUp／Contract | panel 高吃滿短邊；卡片 scroll | **回歸覆蓋 → 主幹 OK** |
| Shop | `panel_height = 390-24`；三欄卡 `card_height≈206` | **靜態可塞；未回歸** |
| StageVictory | summary 可用高 ≈ `366 - 268 ≈ 98` px（三顆 68px 觸控鈕） | **極擠 P2** |
| **GameOver** | `summary` 底固定 ~276；`achievements` 頂固定 288；底 `panel_height - (touch+12)×3+24` → 約 **366−264=102** → **頂 288 &gt; 底 102（高度倒掛）** | **P1 佈局缺陷** |

證據：

```212:251:scripts/ui/game_over_screen.gd
# panel_height = min(viewport.y - 24, …) → 橫式約 366
# summary_label.offset_bottom = 276（mobile 固定）
# achievements_label.offset_top = 288
# achievements_label.offset_bottom = panel_height - ((touch_height + 12) * 3 + 24)
```

### 3.5 結論

| ID | 結論 | 嚴重度 |
|----|------|--------|
| R15-3a | 戰內 HUD **有** mobile 覆蓋，非「只修選單」 | — |
| R15-3b | R14 回歸覆蓋選單+契約+升級+指南+HUD | — |
| R15-3c | 商店／勝利／失敗 **橫式未測** | 測試債 P2 |
| R15-3d | GameOver **844×390 成就區可倒掛／與按鈕爭高** | **P1** |

**條目總結**：戰內主路徑可接受；**橫式結算是最大 UI 洞**。

---

## (4) 背景色相演化 × CanvasModulate × 敵彈預示

### 4.1 管線

| 層 | 行為 | 行 |
|----|------|-----|
| 三主題 `canvas_tone` | void `(0.82,0.94,1)`／farm `(0.82,1,0.78)`／ember `(1,0.82,0.62)` | `arena_background.gd:24,43,63` |
| 掛載 | Arena 父節點 `R10CanvasTone`（世界乘色；**CanvasLayer UI 不受**） | `:365-379` |
| 演化 | 每 75s step；`evolution_hue_step` 0.026～0.035；smoothstep | `:138,856-864` |
| canvas 演化強度 | `_evolved_color(..., 0.35)` | `:366,819-820` |
| Boss flash | 0.42s 內插反相／主題 flash 色 | `:141,823-825,871-879` |

### 4.2 敵危險色（仍固定，只被 tone 乘）

| 元素 | 色 | 行 |
|------|-----|-----|
| 敵彈 | `(1.0, 0.35, 0.24)` | `enemy.gd:390` |
| 遠程 windup | `(1.0, 0.88, 0.36)` | `enemy.gd:261` |
| 衝刺 windup | `(1.0, 0.55, 0.42)` | `enemy.gd:291` |

### 4.3 可讀性推演

| 主題 | 約略效果 | 風險 |
|------|----------|------|
| rift_void | R×0.82 冷調（歷輪約 −14～18% 紅） | 與 R10 同級；**未破** |
| wasteland_farm | 偏綠 tone | 橙紅彈仍分離 |
| **ember_rift** | 暖橙 tone + 暖地 + 演化抬 S/V | **敵彈與地表同色系**；對比最低 |
| Boss flash 瞬間 | 反相／閃色 | **短窗干擾**（0.42s），非常態 |

色相累積：10 分鐘級 `step≈8` × 0.035 × strength 0.35 → canvas 色相偏移約 **0.1 量級**，屬緩變，不像一幀洗掉預示。

### 4.4 結論

| ID | 結論 | 嚴重度 |
|----|------|--------|
| R15-4a | **未破**「敵彈／預示不可讀」紅線（對齊 R10 A-1.4） | — |
| R15-4b | 主題化 + 演化使 **ember 晚場** 監視優先級上升 | **P2** |
| R15-4c | Boss 出場 flash 與 dim 疊加為短時可讀性毛刺 | P2 |

---

## (5) 新音效：池與節流

### 5.1 配置

| sfx_id | 冷卻 (s) | 典型觸發 | 行 |
|--------|----------|----------|-----|
| `boss_roar` | **1.2** | `record_boss_spawn` | `audio_manager.gd:37`；`game_manager.gd:1398-1399` |
| `combo_milestone` | **0.8** | 里程碑 | `audio_manager.gd:38`；`game_manager.gd:520-521` |
| `boomerang_catch` | **0.12** | 迴旋鏢回捕 | `audio_manager.gd:39`；`projectile.gd:276-281` |

共用：

- 池大小 **12**（`PLAYER_POOL_SIZE`）`:7,128-137`  
- 先找空閒；滿則 round-robin **stop 搶播** `:151-160`  
- 冷卻以 `Time.get_ticks_msec` 全域 per-id `:163-170`  

### 5.2 評估

| 命題 | 判定 |
|------|------|
| 新 id 有節流 | **成立** |
| Boss roar 與連殺 thump 搶池 | 可能；roar 長音可被 hit/fire 擠掉 → **體感削峰**，非崩潰 |
| 同幀多 milestone | 冷卻 0.8 → 多半只出一聲 | 可接受 |
| 多迴旋鏢回捕 | 0.12s 節流合理 | — |
| 與 kill_thump 0.055／hit 0.045 疊噪 | **預存 N10 密度問題延續** | P2 |

### 5.3 結論

| ID | 結論 | 嚴重度 |
|----|------|--------|
| R15-5a | 池 + 冷卻設計完整，新音效**已接入** | — |
| R15-5b | 滿場 12 槽搶占 → roar／milestone 可能被吃 | P2 |

---

## (6) 歷輪紅線 + 決定性快檢

### 6.1 紅線快檢

| 紅線 | 判定 | 證據 |
|------|------|------|
| `spawn_token` 命中表 | **未破** | `entity_factory.gd:49,127,878-880` |
| 敵查詢走空間索引／工廠，非散落 `get_nodes_in_group` 熱路徑 | **未見本輪倒退** | 既有 EntityFactory API；R13 測用工廠 spawn |
| 池 cap（死亡 burst 等） | **未見本輪拆 cap** | death_burst 新 style 仍走池 |
| hit-stop 在 modal pause 不啟動 | **成立** | `game_manager.gd:314-315` |
| UI 不受 CanvasModulate | **成立** | CanvasLayer vs `R10CanvasTone` |
| 敵彈預示可讀 | **未破**（見 §4） | — |
| 破 gameplay cap／軟鎖 | **未見**本輪引入 | time_scale 競態屬手感 P1，非軟鎖 P0 |

### 6.2 決定性

| 項目 | 判定 | 說明 |
|------|------|------|
| 背景演化 signature | **決定性**（同 seed／time／center） | `get_background_evolution_signature`；R14 有測（`r14_regression_test` background 階段） |
| COMBO／里程碑 | **由 elapsed_time + 擊殺序**決定 | 無額外 RNG |
| 掉落 scatter／部分 VFX | **預存非決定性** | 歷輪灰區 |
| Homing 等距 | **預存灰區** | R11 已載 |

### 6.3 回歸覆蓋缺口（決定性／正確性）

| 有 | 無 |
|----|----|
| R13：milestone 25、break、Boss signal、knockback 帶、level 光柱池 | time_scale 多來源 |
| R14：mobile scale、主選單／契約／升級／指南／HUD 雙向、背景演化 | 商店／勝利／**失敗橫式**；ember 可讀性目視 |

---

## 總表與建議（只審不改）

### 發現清單

| ID | 等級 | 標題 | 證據 |
|----|------|------|------|
| R15-2a | **P1** | hit-stop 與升級 slowmo 分 token，互相提前結束緩速 | `game_manager.gd:311-321,574-592`；`enemy.gd:571` |
| R15-3d | **P1** | GameOver 橫式 844×390 成就區 offset 可倒掛 | `game_over_screen.gd:222-250` |
| R15-1c | P2 | 斷連重刷里程碑 → 反覆 5s +10% 射速 | `game_manager.gd:516,532,952-953` |
| R15-1d | P2 | 星環不受 fire_rate buff | `orbit_weapon.gd` vs `base_weapon.gd:63-67` |
| R15-3c | P2 | 商店／勝利橫式無回歸 | `r14_regression_test.gd:82-101` 無 shop/go/victory |
| R15-4b | P2 | ember + 演化下敵彈對比監視 | `arena_background.gd:59-72`；`enemy.gd:390` |
| R15-5b | P2 | 12 池搶播可能吃掉 roar／milestone | `audio_manager.gd:7,151-160` |

### 非問題（本輪可關單）

- COMBO +10% **未**與升級做成指數爆炸疊乘。  
- 斷連窗口 1.15s 與暫停凍結行為合理。  
- Boss 擊殺路徑不易留下 time_scale 慢速。  
- 敵彈可讀性紅線 **未破**。  
- 新 SFX 皆有獨立冷卻。  
- 歷輪 pool／token／cap 紅線 **未見違規**。

### 總判定

> **軟 Go**。R13 爽度與 R14 行動端主幹可進實玩；硬 Go 前建議至少處理或驗收：**（P1）time_scale 協調**、**（P1）橫式 GameOver 佈局**，並補商店／結算 844×390 回歸。

---

*本報告僅覆核，不修改程式碼。*
