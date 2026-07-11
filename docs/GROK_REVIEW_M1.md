# Crackveil Vanguard — 對抗性覆核 M1（手機優化第 1 圈）

**審查者**：手機端監工／對抗覆核（只審不改）  
**審查對象**：`2004e78` — *M1 手機優化循環第 1 圈：拇指工學/可讀性/Mobile LOD*  
**基準對照**：`docs/ART_DIRECTION_M1_mobile.md`、`docs/CODEX_RESPONSE_M1.md`  
**範圍**：(1) LOD 檔位正確性；(2) 傷害字激進合併語意；(3) 升級／契約二次確認節奏；(4) HUD 金幣移暫停後商店餘額；(5) hazard tick 降頻 vs 傷害；(6) 歷輪紅線快檢  
**方法**：靜態讀 `2004e78` diff + HEAD 現況碼 + 回歸腳本契約對照；**本輪未重跑 headless Godot／Stress**  
**日期**：2026-07-11  

---

## 執行摘要

| # | 議題 | 判定 | 嚴重度 |
|---|------|------|--------|
| (1) | LOD 切換正確性（誤傷桌面／中途切換一致性） | **部分成立**；標準桌面 1280×720 不吃 LOD，但 touch／窄窗會把桌面當手機；中途旋轉時部分狀態「鎖 setup、不回寫」 | **P1** 一致性／誤觸發 |
| (2) | 傷害字激進合併語意 | **可讀性取向成立**；語意是「空間總和」，非 per-hit／per-weapon；滿 cap 靜默丟數字（不丟傷） | **P2** 讀取成本 |
| (3) | 二次確認對節奏 | **全卡一律兩下**（含一般升級）；契約一次可接受；升級三選一每局多次會磨節奏 | **P1** 手感／節奏 |
| (4) | 商店是否看得到金幣 | **成立**；`RiftShopScreen` 自有餘額列，不依賴戰鬥 HUD | — |
| (5) | hazard tick 降頻 | **降的是傷害 tick，不是純視覺**；每 tick 傷 = DPS×interval → 平均 DPS 名義保全，但離散取樣／狀態刷新已造成 **手機／桌面平衡分裂** | **P1** 紅線灰／平衡 |
| (6) | 歷輪紅線 | **熱掃敵／pool 主幹未炸**；**「視覺 budget 不改玩法」被 hazard LOD 局部踩線** | 見 §6 |

**總判定**：**軟 Go／可進真機第 2 圈調校，不可當硬 Go 關帳**。  
拇指工學、HUD 精簡、敵彈可讀、商店餘額、桌面大視窗 LOD off 主幹落地；宣稱 p95 改善需信任 Codex 自述（本輪未複跑）。  
**擋硬 Go 的三點**：(5) hazard 降頻綁玩法；(3) 升級一律二次確認過重；(1) LOD／UI 開關中途與「類桌面觸控機」誤傷。

狀態標籤：**成立**／**部分成立**／**未達**／**新風險**／**紅線違規**／**預存灰區**  
優先級：**P0** 軟鎖／破 cap／謊稱／玩法結果靜默丟失；**P1** 平衡分裂、節奏摩擦、狀態不一致；**P2** 調校與監視。

---

## (0) 變更盤點（對照宣稱）

| 宣稱 | 碼上狀態 | 主要位置 |
|------|----------|----------|
| 搖桿熱區 1.24x | **成立** | `mobile_tuning.gd:19`；`virtual_joystick.gd:8`；`m1_regression_test.gd:65-70` |
| 技能鈕直式 92／橫式 84 + 冷卻環 | **成立** | `mobile_tuning.gd:98-102`；`hud.gd:229-231,812-830`；`cooldown_ring.gd` |
| 敵彈深框亮核 | **成立** | `projectile.gd:469-516` |
| 傷害字合併加劇 | **成立** | `mobile_tuning.gd:13-15,159-175`；`entity_factory.gd:371-393,603-615` |
| HUD 精簡金幣／殘響入暫停 | **成立** | `hud.gd:524-525,757-767` |
| 契約／升級二次確認 | **成立（一律）** | `contract_screen.gd:173-184`；`level_up_screen.gd:95-106` |
| 粒子 0.6x | **成立** | `mobile_tuning.gd:10,147-148`；`entity_factory.gd:414`；`death_burst.gd:249-251` |
| hazard 降頻 0.24→0.372 | **成立（且綁傷害）** | `mobile_tuning.gd:17,186-188`；`hazard_zone.gd:44,57-58,80` |
| 殘影 24→12／爆散 20→12 | **成立** | `mobile_tuning.gd:18-19,191-196`；`entity_factory.gd:404,421` |
| p95 31.2→15.3ms | **宣稱成立於文件**；**本輪未複跑** | `docs/CODEX_RESPONSE_M1.md:38-44` |
| 桌面不受影響 | **部分成立**（見 §1） | `mobile_tuning.gd:137-140`；`m1_regression_test.gd:222-234` |
| `index.pck` ~4.42MB | **成立**（4420376 B） | `export/web/index.pck` |

---

## (1) LOD 檔位切換正確性

### 1.1 啟用條件與「偵測失敗／誤傷」

```137:140:scripts/services/mobile_tuning.gd
static func mobile_lod_enabled(viewport_size: Vector2, force_mobile: bool = false) -> bool:
	if bool(ProjectSettings.get_setting(FORCE_MOBILE_LOD_SETTING, false)):
		return true
	return use_mobile_ui(viewport_size, force_mobile)
```

`use_mobile_ui` 任一成立即 true（`mobile_tuning.gd:26-43`）：

| 條件 | 行為 | 桌面誤傷風險 |
|------|------|--------------|
| `force_mobile` | 強制 mobile UI／LOD | 測試用 |
| `OS` feature `mobile`／`android`／`ios` | true | 正確 |
| `DisplayServer.is_touchscreen_available()` | true | **觸控筆電／二合一會整包吃 mobile LOD** |
| `size.x < 700` | true | 桌面窄窗／半螢幕 |
| short≤520 且 long≤980 | true | 小視窗／部分平板模擬 |
| portrait 且 x≤760 y≤1400 | true | 桌面直式視窗 |

| 命題 | 判定 | 檔案:行 |
|------|------|---------|
| 標準桌面 1280×720 不開 LOD | **成立**（無 touch／非 mobile OS 假設下） | `m1_regression_test.gd:222-234`；`mobile_tuning.gd:26-43` |
| mobile 偵測「失敗」導致桌面被降級 | **方向反了**：失敗＝**不開** LOD（桌面安全）；真正風險是 **false positive** | `mobile_tuning.gd:33-42,137-140` |
| force 只能強制開、不能強制關 | **成立** | `mobile_tuning.gd:137-144`（`set_force_mobile_lod` 僅 set setting true/false；true 時無條件 on） |
| 回歸鎖桌面常數 | **部分**——只驗 `force=false` + 1280×720，**未** mock 觸控螢幕路徑 | `m1_regression_test.gd:225-234` |

**結論 (1a)**：不是「偵測失敗誤傷桌面」，而是「**把觸控／窄視窗桌面當成手機**」會整包吃粒子 0.6、傷害字 cap 30、**hazard 傷害 tick 變稀**。對純滑鼠大桌面 OK；對 Surface 類裝置是 **新風險（P1）**。

### 1.2 中途切換（旋轉／縮放）狀態一致性

| 子系統 | 是否每幀／每次 spawn 重算 LOD | 中途旋轉行為 | 檔案:行 |
|--------|------------------------------|--------------|---------|
| 背景 redraw 間隔、ambient 線、decor sway | **每 process／draw 讀** | 大致跟隨 | `arena_background.gd:232-245,257-260,515-525,831-832` |
| 背景 dust `amount` | **只在 ensure 時寫一次** | **可能卡在首次建立時的 LOD** | `arena_background.gd:433` |
| death_burst 粒子倍率 | **spawn 當下** | 新 VFX 跟新檔位；舊的不管 | `entity_factory.gd:402-415` |
| damage number merge／cap | **每次 spawn** | 跟隨 | `entity_factory.gd:375-377,606-607` |
| corpse／death cap | **每次 spawn** | 跟隨 | `entity_factory.gd:404,421` |
| hazard `tick_interval` | **只在 `setup()`** | **場上既有 zone 鎖死舊 interval** | `hazard_zone.gd:38-44` |
| 敵彈可讀色 | `_configure_projectile_vfx` 時 | 既有彈可能不重配 | `projectile.gd:468-516` |
| HUD 金幣隱藏 | stats／layout 時 `use_mobile_ui` | 跟隨 | `hud.gd:757-765` |

| 命題 | 判定 | 嚴重度 |
|------|------|--------|
| 旋轉後「新」物件檔位一致 | **大致成立** | — |
| 旋轉後「活著」的 hazard／dust 一致 | **未達**（setup 鎖／ensure 一次） | **P1** |
| 縮放跨 700 寬門檻 | 可能瞬間切換 UI 比例 + LOD；無 debounce | **P2** |
| 雙向還原（mobile→desktop）完整 | **未達**（dust amount、既有 hazard） | **P1** |

**條目總結 (1)**：**部分成立**。桌面大窗契約有回歸鎖；**誤傷路徑是 touch／窄窗 false positive**，不是 false negative。中途切換有**半套熱更新**——視覺背景大半跟、**玩法向 hazard 不跟**。

---

## (2) 傷害字激進合併：玩家還看得懂輸出嗎？

### 2.1 參數

| 參數 | Desktop | Mobile LOD | 檔案:行 |
|------|---------|------------|---------|
| cap | 48 | **min → 30** | `entity_factory.gd:35`；`mobile_tuning.gd:15,174-175` |
| base merge radius | 48 | **至少 82** | `entity_factory.gd:36`；`mobile_tuning.gd:13,159-167` |
| merge age | 0.24s | **至少 0.34s** | `entity_factory.gd:37`；`mobile_tuning.gd:14,170-171` |
| 滿 cap 再放大 | ×2.4 | 另在 ≥30 時 **×1.45** | `mobile_tuning.gd:161-166` |
| 字級 | 請求值 | cap **20**，預設 **14** | `mobile_tuning.gd:178-183` |

### 2.2 合併語意（實際規則）

合併條件（`damage_number.gd:60-61` + `entity_factory.gd:603-615`）：

1. 值必須是 **int/float**（`"COMBO ×n"` 字串 **不參與**合併）  
2. 既有數字 `is_active` 且 `age ≤ merge_age`  
3. 世界距離 ≤ radius（**無** enemy id／weapon id／crit 旗標）  
4. 掃描 `active_damage_numbers` **第一個**符合者即合併（**非最近優先**）  
5. `merge_value`：**加總** `numeric_total`，**覆寫顏色**為最新一擊，位置 lerp 35% 向新擊，age 壓回 ≤0.08（`damage_number.gd:64-75`）

| 玩家可能以為 | 實際語意 | 判定 |
|--------------|----------|------|
| 單下傷害 | 半徑內、時間窗內的 **空間累加總和** | 高 AOE／多武器時「一坨數字」 |
| 分武器 DPS | **無法**從數字拆武器 | 輸出讀取降級 |
| 分敵人血條反饋 | 鄰近多敵會併進同一節點 | 清潮時尤其糊 |
| 爆擊／不同色種 | 顏色被最後一擊覆蓋 | 語意弱化 |
| 玩家受傷紅字 vs 輸出米黄 | 同為 numeric，距離夠近理論可互併（位置通常分離） | 低機率灰區 |

滿 cap 且找不到 merge target → `return null`（`entity_factory.gd:380-381`）：**只丟 VFX，不丟傷害**——符合「數字是表現層」；玩家可能覺得「有打沒字」。

| 命題 | 判定 | 嚴重度 |
|------|------|--------|
| 合併是否「激進」如宣稱 | **成立**（82px + 0.34s + cap30 + 再×1.45） | — |
| 會不會讓人看不懂輸出 | **部分**——總輸出量級仍在；**細粒度／分武器／分目標**變差 | **P2** |
| 是否誤傷玩法結算 | **否**（純 VFX） | — |

**條目總結 (2)**：語意應標成 **「區域傷害聚合器」**，不是 hit log。對手機清場可讀性（少遮怪）方向正確；若設計要「看數字學 build」，這圈會變難——屬體驗取捨，非正確性 bug。

---

## (3) 二次確認對節奏的傷害

### 3.1 實作範圍

| 畫面 | 是否二次確認 | 範圍 | 檔案:行 |
|------|--------------|------|---------|
| 升級三選一 | **手機一律** | 所有卡，含普通升級與進化 | `level_up_screen.gd:95-106` |
| 契約三選一 | **手機一律** | 所有契約卡 | `contract_screen.gd:173-184` |
| 商店購買 | **無** | 單點即 `purchase_selected` | `rift_shop_screen.gd:106-107` |
| 種子開局 | **無** | 單點 | `contract_screen.gd:192-194` |

行為細節：

- 第一下：標成「再次點擊確認」+ 原文，**不** emit（`level_up_screen.gd:98-102`）  
- 第二下同一顆：才選取  
- 改點另一張：重置前一張，新卡進入確認態（合理）  
- 桌面 `use_mobile_ui==false`：單點即選  

回歸鎖「兩下才選」：`m1_regression_test.gd:160-218`。

### 3.2 節奏評估

| 情境 | 摩擦 | 誤觸風險 | 評價 |
|------|------|----------|------|
| 契約（每局一次） | 低 | 中（滑動誤觸開局） | **值得一律確認** |
| 升級（每局多次，潮間暫停） | **中～高** | 中（拇指大卡） | **一律兩下過重** |
| 進化卡／高影響選項 | 應更高門檻 | 高 | **沒有分級**——與普通卡相同 |
| 商店（花金幣／不可逆） | 無確認 | 中高 | **風險與保護反置** |

| 命題 | 判定 | 嚴重度 |
|------|------|--------|
| 「每次升級都要點兩下」 | **是**（mobile） | **P1** 節奏 |
| 「只有誤觸風險高的卡」 | **否**——全卡一刀切 | **P1** 設計 |
| 會軟鎖／選不到 | **否**（第二下有通） | — |

**條目總結 (3)**：防誤觸方向對，**粒度錯**。建議（僅審查意見、本輪不改）：契約維持雙確認；升級改「首點高亮、滑離取消」或僅進化／稀有；商店若不可逆應比普通升級更需要確認。

---

## (4) HUD 金幣進暫停後，商店看得到餘額嗎？

### 4.1 戰鬥 HUD

手機戰鬥列只留擊殺（`hud.gd:757-765`）：

- `score_label`：`擊殺 %d`（無金幣／殘響）  
- `gold_icon.visible = not mobile`（`hud.gd:524-525`）  
- 暫停頁：`pause_run_stats_label` = `本局：擊殺 %d   金幣 %d   殘響 %d`（`hud.gd:766-767`），於 `stats_changed` 持續更新  

### 4.2 商店（關鍵）

`RiftShopScreen` **自帶** `gold_label`，不讀 HUD：

| 行為 | 證據 |
|------|------|
| 開商店寫入 `金幣 %d` | `rift_shop_screen.gd:89` |
| 購買後 `stats_changed` 刷新餘額 | `rift_shop_screen.gd:119-132` |
| 商品列印 `cost` 金幣、不足顯示「金幣不足」 | `rift_shop_screen.gd:201-219` |
| disable 當 `current_gold < cost` | `rift_shop_screen.gd:195-198` |

| 命題 | 判定 |
|------|------|
| 買東西時看得到餘額 | **成立** |
| 買完後餘額會更新 | **成立**（掛 `GameManager.stats_changed`） |
| 戰鬥中邊撿金幣邊看總額 | **刻意不可**——僅暫停／商店／結算 | **P2** 經濟察覺（非本問阻擋） |

**條目總結 (4)**：**商店路徑安全**。HUD 精簡沒有切斷購買決策資訊。

---

## (5) hazard tick 降頻：視覺還是傷害？平衡分裂？

### 5.1 降的是什麼

```44:58:scripts/projectiles/hazard_zone.gd
	tick_interval = MOBILE_TUNING.hazard_tick_interval(_viewport_size_for_lod(), float(stats.get("tick_interval", 0.24)))
	...
	if tick_timer <= 0.0:
		_apply_tick_damage()
		tick_timer = tick_interval
```

```78:80:scripts/projectiles/hazard_zone.gd
func _apply_tick_damage() -> void:
	...
	var tick_damage: float = float(stats.get("damage_per_second", 4.0)) * tick_interval
```

```186:188:scripts/services/mobile_tuning.gd
static func hazard_tick_interval(...) -> float:
	...
	return safe_interval * MOBILE_HAZARD_TICK_INTERVAL_MULTIPLIER if mobile_lod_enabled(...) else safe_interval
```

`MOBILE_HAZARD_TICK_INTERVAL_MULTIPLIER = 1.55` → 預設 0.24 → **0.372**（`mobile_tuning.gd:17`；回歸 `m1_regression_test.gd:250-252`）。

| 層級 | 是否被 1.55 影響 | 說明 |
|------|------------------|------|
| `_apply_tick_damage` 呼叫頻率 | **是** | 玩法 |
| 每 tick 傷害量 | **同步放大**（×interval） | 名義 DPS = `damage_per_second` 不變 |
| status 套用頻率 | **是**（每 tick） | 控場／dot 刷新變稀 |
| status_duration 預設 | 常等於 `tick_interval` | 單次狀態時長也變長（`hazard_zone.gd:95-103`） |
| 輪廓加粗／暗邊 | **否**（另走 `use_mobile_ui` 繪製） | 純可讀性（`hazard_zone.gd:115-122`） |
| 淡出 `modulate` | 依 duration，非 tick | 視覺 |

**判定**：宣稱寫在「Mobile LOD」與 perf 項下，但實作是 **傷害／狀態 tick 降頻**，不是「少畫一點」。對比歷輪 **「視覺 budget 不得改變戰鬥結算」**（R3/R4/R5）——此處為 **紅線灰／局部違規**。

### 5.2 「傷害變低」？還是「不一樣」？

名義：  
`tick_damage = DPS * interval` → 理想連續近似下 **時間平均 DPS 相同**。

離散現實（`tick_timer` 初值 0 → **立刻第一 tick**，之後每 interval，直到 `age >= duration`）：

| 例子（duration=1.2，base interval=0.24） | Desktop | Mobile (×1.55) |
|------------------------------------------|---------|----------------|
| interval | 0.24 | 0.372 |
| 約略 tick 次數（含 t=0） | 5（0…0.96） | 4（0…1.116） |
| 總傷 ≈ n × DPS × interval | 1.20 × DPS | **1.488 × DPS** |

→ 短壽命 zone 上 mobile **總傷可偏高**（量化邊界），不是單調「變低」。  
反過來：敵人 **快速蹭過** 時，較稀的 tick 更容易 **整段 0 hit** → 有效傷 **偏低**。

武器自帶 interval 同樣被乘：

| 來源 | base tick | mobile tick | 檔案 |
|------|-----------|-------------|------|
| 預設／回歸 | 0.24 | 0.372 | `hazard_zone.gd:9` |
| 餘燼類 | 0.24 / 0.45 | ×1.55 | `explosion_weapon.gd:47,58` |
| 榴彈落點 | 0.34 | ×1.55 | `grenade_lob_weapon.gd:90` |
| 虛空網 | 0.32 | ×1.55 | `void_net_weapon.gd:40` |

| 命題 | 判定 | 嚴重度 |
|------|------|--------|
| 降的是視覺？ | **否**——降傷害／狀態 tick | **P1** |
| 手機版傷害變低？ | **不精確**；平均 DPS 名義保全，**分佈與總量離散結果與桌面分裂** | **P1** |
| 平衡分裂（同 seed 跨平台） | **成立風險**（尤其 status 刷新） | **P1** |
| 中途 LOD 切換改既有 zone | **不改**（setup 鎖定）→ 同一局混檔可能 | 見 §1.2 |

**條目總結 (5)**：這是本輪 **最硬的對抗點**。若 LOD 只能動表現，hazard 應只降 **redraw／arc 精度**，tick 傷維持桌面 interval，或改「累積 delta 連續結算」使降頻不改期望輸出。現狀把 perf 帳記在玩法 tick 上。

---

## (6) 歷輪紅線快檢

| 紅線 | M1 判定 | 證據 |
|------|---------|------|
| 熱路徑禁 `get_nodes_in_group("enemies")` 掃傷 | **未破** | 全 `scripts/**/*.gd` **0 命中**；hazard 走 `EntityFactory.get_enemies_in_radius`（`hazard_zone.gd:82`） |
| 池 cap 不可無聲膨脹 | **未破**；mobile **更緊**（death 20→12、ghost 24→12、dmg num 48→30） | `entity_factory.gd:35-42,404,421`；`mobile_tuning.gd:15-19` |
| 視覺 cap 不吞玩法結果 | **局部踩線** | 數字／爆散／殘影 cap 仍只吞 VFX；**hazard tick LOD 改玩法**（§5） |
| XP／金幣 visual cap fallback | **本輪未動**（預存機制） | 非 M1 diff 焦點 |
| 敵彈 cap 可能吞投射物 | **預存灰區**（R5 E1）；M1 未修未惡化 | — |
| 桌面檔位不自動吃 mobile LOD | **部分成立**（§1 touch／窄窗） | `mobile_tuning.gd:137-140`；`m1_regression_test.gd:226-228` |
| hit-stop / time_scale owner | **本輪未動**；R16/R17 預存架構 | 非 M1 範圍 |
| Web pck 預算 | **成立** 4,420,376 B（&lt;5MB 歷史預算） | `export/web/index.pck` |
| 決定性 seed | **未見 M1 新 RNG**；hazard 離散跨裝置差異屬 **平台分裂** 非同機非決定 | §5 |
| p95 宣稱 | **文件有數；本輪未複跑** | `CODEX_RESPONSE_M1.md:38-44` |

### 6.1 本輪宣稱 vs 對抗

| 宣稱 | 對抗結論 |
|------|----------|
| 「桌面不受影響」 | 大視窗滑鼠：**大致真**；觸控桌面／窄窗：**假** |
| 「hazard tick 降頻」當 LOD | 實為 **玩法 tick**；與「視覺優化」敘事不符 |
| 「p95 31.2→15.3」 | 靜態無法證偽；需 Stress 複跑才可升格「成立」 |
| M1Regression 全綠 | 契約測工學／HUD／雙確認／常數；**不**測 hazard DPS 等價、不測旋轉一致性、不測商店金幣（但商店碼本身 OK） |

---

## 總表與建議優先序（只審）

| ID | 結論 | 嚴重度 |
|----|------|--------|
| M1-1a | 桌面 1280 不開 LOD 有鎖；**touch／窄窗 false positive** 會整包降級 | P1 |
| M1-1b | 中途旋轉：背景多半跟、**hazard／dust 半殘** | P1 |
| M1-2a | 傷害字＝空間加總器；細讀輸出變差但 **不改結算** | P2 |
| M1-3a | 升級 **一律兩下** 傷節奏；應分級 | P1 |
| M1-3b | 商店高風險反而不確認——保護反置 | P2 |
| M1-4a | 商店自有金幣列 → **購買可見餘額** | —（通過） |
| M1-5a | hazard 降頻＝**傷害 tick**；名義 DPS 公式保全、離散／status **平衡分裂** | P1 |
| M1-5b | 相對「視覺不改玩法」紅線 → **灰／局部違規** | P1 |
| M1-6a | group 掃敵／pool 膨脹 **未破** | — |
| M1-6b | p95 數字 **未本輪複驗** | 文件債 |

### 建議下一圈（非本輪施工）

1. **P1** hazard：LOD 只動繪製；或改累積 `damage_per_second * delta` 結算，讓「降頻」不改期望與跨端。  
2. **P1** 二次確認：契約保留；升級改分級或「選取＋確認條」；評估商店不可逆項。  
3. **P1** LOD 閘門：`mobile_lod_enabled` 與 `use_mobile_ui` 解耦（觸控桌面可大 UI、不一定 hazard 改 tick）；中途 resize 重綁 dust／可選刷新 hazard。  
4. **P2** 傷害字：文件化「聚合語意」；可選 per-target merge key。  
5. 複跑 `MobileLodStressTest`／雙檔位 DPS 對照（同 seed 桌面 vs force mobile LOD）寫進回歸。

---

## 一句話

M1 把手機拇指與可讀性骨架立起來了，商店金幣也沒斷；但 **把 hazard 玩法 tick 塞進 LOD**、**升級全卡雙擊**、以及 **LOD 與觸控桌面綁死**，讓這圈只能 **軟 Go**，硬關帳前先切開「表現降載」與「戰鬥數字」。
