# Crackveil Vanguard — 對抗性設計／程式審查 R6

**審查者**：資深遊戲設計師＋Godot 4 技術總監（對抗式，以 git 與工作區現行程式為準，不採信 `CODEX_RESPONSE_R5` 語氣）  
**審查對象**：R5 辯論修正後的三支柱原型（commit `e04d739` 為主；前一 commit `08766b6` 為字型子集／豆腐回歸）  
**線上**：https://mars-tw.github.io/crackveil-vanguard/  
**對照**：`docs/GROK_REVIEW_R4~R5.md`、`docs/CODEX_RESPONSE_R4~R5.md`  
**方法**：`git log`／`git show e04d739` diff + 靜態讀碼（`scripts/`、`scenes/`、`resources/`、R5 regression 腳本）；本輪**只審不改**，未重跑 Godot headless／瀏覽器長測  
**日期**：2026-07-10  

---

## 執行摘要

| 面向 | 判定 |
|------|------|
| R5 指定 P0（S1／S2／E1） | **成立**（主路徑完整；殘留為邊界與次要 UX） |
| R5 指定 P1（Q1／Q3／Q4／Q5） | **成立**；Q1 改寫為「主池不再被 fork 掏空」，fork 自身 cap 靜默仍可發生 |
| R5 延後（E4／E6／S3） | **仍未修**；E6 仍屬 P0 體驗地雷；S3 仍會在 3:00 與 Boss 搶節拍 |
| 三支柱「想一直玩」 | **未達**；局內可感知，局間仍歸零，build／威脅深度仍薄 |
| R6 總判定 | **R5 修到了該修的正確性／紅線灰區主幹**；距離黏著力閉環還差一整層 **P1 深度系統**（Meta／進化／開局契約／店深化／精英詞綴） |

**一句話**：R5 把「會卡死／會缺角／會空槍／會拖幀」的 P0–P1 補洞補對了；但 **E6 精英到點消失、S3 店撞 Boss** 仍在，且即便全修完，玩家第二局與第十局仍高度同構——本輪重點應是**可落地的 P1 閉環路線圖**，不是再堆數值卡。

狀態標籤：

- **成立**／**部分成立**／**未修好**／**新 bug**／**紅線灰區**／**延後仍在**

優先級：

| 等級 | 意義 |
|------|------|
| **P0** | 正確性、心跳事件被吞、UI 卡死感 |
| **P1** | 「想再開一局」深度：Meta／進化／詞綴／店／精英 |
| **P2** | 文案、邊界、文件／mock 誠信、長期擴充 |

---

## (0) 變更盤點（以 git 為準）

### 最近兩個 commit

| Commit | 標題 | 與 R5 指定修的關係 |
|--------|------|-------------------|
| `e04d739` | R5 辯論修正：商店卡死／Boss 環彈缺角／fork 佔池／hazard 效能／磁暴局級 | **本輪覆核主體**（13 files，+1240/−46） |
| `08766b6` | 修正 Web 中文豆腐回歸——字型子集納 R4 新字＋CI 自動重建 | **非玩法邏輯**；防部署文字 □；字型 1.50MB 守門 |

`e04d739` 觸及：

| 路徑 | 角色 |
|------|------|
| `scripts/autoload/game_manager.gd` | 商店 enable／reason、磁暴 run flag、購買後端重檢 |
| `scripts/ui/rift_shop_screen.gd` | disable 文案、金幣不足提示 |
| `scripts/autoload/entity_factory.gd` | 敵彈 72＋boss reclaim、fork 子池、hazard LRU |
| `scripts/projectiles/projectile.gd` | fork 走子池＋stats cache |
| `scripts/projectiles/hazard_zone.gd` | modulate 淡出、取消每幀 redraw |
| `scripts/enemies/enemy.gd` | 環彈 priority、磁暴查 run flag |
| `scripts/heroes/squad_manager.gd` | `can_heal_members`／質變可用性、磁暴 enable |
| `scripts/weapons/base_weapon.gd` | `apply_data_upgrade` 回 bool + `can_apply` |
| `scripts/debug/r5_regression_test.gd` + 場景 | S1/S2/E1/Q1/Q3–Q5 回歸 |

**未進本 commit（延後仍在）**：E4 精英 XP 可見 fallback、E6 精英 cap 跳過、S3 180s 店／Boss 時刻表。

---

## (1) R5 修正逐條覆核

### 1.1 S1／S2 — 商店無意義選項 disable + 提示 + 後端保護

#### 證據鏈

| 層 | 位置 | 行為 |
|----|------|------|
| 選項建構 | `game_manager.gd:295-338` | `_shop_option` → `_shop_option_disabled_reason` 寫入 `enabled`／`disabled_reason` |
| 急救 | `:329-331` | `can_heal_members()` 假 →「全隊已滿血」 |
| 質變 | `:332-334` | `has_available_qualitative_upgrade()` 假 →「沒有可套用的質變」 |
| 護盾 | `:335-337` | `get_member_count() <= 0` →「沒有存活隊員」 |
| UI | `rift_shop_screen.gd:161-186` | `enabled=false` 或金幣不足 → disabled + 後綴文案 |
| 後端 | `game_manager.gd:345-374` | `_is_shop_option_meaningful` 失敗 → **不扣金、不關店**；成功才 `spend_gold` + `_close_shop` |
| 小隊 | `squad_manager.gd:247-255,269-285,288-305` | 滿血／質變池共用收集邏輯 |

#### 判定

| ID | 命題 | 判定 | 說明 |
|----|------|------|------|
| S1 | 滿血急救不再「點了沒反應」 | **成立** | UI disable +「全隊已滿血」；後端重檢 |
| S2 | 質變滿層「偏壓改裝」同上 | **成立** | 同上；`can_apply_upgrade` 亦由 `base_weapon.gd:40-52` 守門 |
| S1/S2 其他無意義路徑漏掉？ | 現有**三固定商品**主路徑 | **主路徑完整** | 見下「殘留」 |

#### 殘留／邊界（非 R5 回歸失敗，但對抗性要記）

| ID | 等級 | 問題 | 位置 | 說明 |
|----|------|------|------|------|
| S1b | P2 | 店開時 `enabled` **快照**；`stats_changed` 只重算金幣與既有 `enabled`，**不重跑** `_shop_option_disabled_reason` | `rift_shop_screen.gd:100-113` | 單次購買即關店，實務風險低；若未來允許多購／店內狀態變化會 stale |
| S1c | P2 | `squad_manager` 異常 null 時急救 reason 仍寫「全隊已滿血」（語意偏） | `game_manager.gd:329-331` | 正常 Arena 必有 squad |
| S4 | P2 | 護盾文案仍未寫 12s 時長 | `game_manager.gd:309-313,368-369` | R5 未修，仍在 |
| S5 | P2 | `player_died` 仍不清 `waiting_for_shop` | `game_manager.gd:414-436` | paused 下難觸發；髒旗標理論殘留 |
| S-shield | P2 | 「帷幕護盾」幾乎永遠有意義（`max` 疊層／續時），無「已滿護盾」disable | `hero.gd:259-263` | 可接受；非卡死路徑 |

**結論**：R5 指定的 S1／S2 **成立**。現行固定三選一商品沒有第二條「點了沒反應」的主漏網（護盾在有隊員時幾乎總可買）。

---

### 1.2 E1 — Boss 環彈 priority + cap 72 + 回收最舊一般彈

#### 證據鏈

| 檢查 | 位置 | 實況 |
|------|------|------|
| cap | `entity_factory.gd:38` | `ENEMY_PROJECTILE_CAP = 72`（原 48） |
| API | `:152-165` | `priority` 預設 `"normal"`；滿且 `boss` → reclaim；滿且 normal → `null` |
| meta | `:163` | `_enemy_projectile_priority` |
| reclaim | `:534-546` | **由前向後**掃 `active_enemy_projectiles`（append 序＝較舊在前），**跳過** `boss`，`release_projectile` 一顆即 return |
| Boss 環 | `enemy.gd:312-318` | `priority := "boss" if is_boss else "normal"` |
| 遠程 | `enemy.gd:303-309` | 明確 `"normal"` |
| 回歸 | `r5_regression_test.gd:164-191` | 填滿 72 normal → 生 14 boss → 要求 boss≥14 且不超 cap |

#### cap 72 夠嗎？

| 情境 | 估算 | 判定 |
|------|------|------|
| Boss 週期環 10 + 二階 14 | 同時段 Boss 彈約 ≤24（彈壽命 ≈ range/speed ≈ 940/215 ≈ 4.4s；CD 5.4s） | **足夠** |
| + 大量 ranged 慢彈 | 72 − Boss 配額後仍有 ~48 一般額度；滿則丟 general（設計取捨） | **可接受** |
| 極端：場上 72 全是 boss 優先彈 | reclaim 失敗 → 新環彈 `null` | **邊界殘留 P2**（單 Boss、彈壽命有限，極難堆滿 72 boss） |

#### 會不會誤殺「剛出膛」？

| 風險 | 判定 | 理由 |
|------|------|------|
| 誤殺剛出的 **Boss** 環彈 | **不會（成立）** | boss meta 被 skip |
| 誤殺剛出的 **一般** 敵彈 | **優先殺最舊** | 陣列頭＝最早 append；新彈在尾 |
| reclaim 後主池 acquire 失敗 | **灰區新邊界** | 見下 R6-E1b |

| ID | 等級 | 問題 | 位置 | 說明 |
|----|------|------|------|------|
| E1 | P0 原題 | Boss 環因 cap 缺角 | — | **成立已修** |
| R6-E1b | P2 | `release_projectile` 為 **deferred** 回池（`:344-351`），reclaim 當幀只從 active 列表騰位；若主 `projectile` **free_list 已空**（玩家彈＋敵彈合計逼近 prewarm 240），`spawn_projectile` 可 `null` → **已回收一顆一般彈卻生不出 Boss 彈** | `entity_factory.gd:152-165,344-351`；`node_pool.gd:36-54` | 需「池真耗盡」才踩；迴歸未覆蓋。最小修法：boss reclaim 失敗路徑改同步 release，或敵彈獨立池 |

**結論**：E1 **成立**。cap 72 + boss 優先回收對現行單 Boss 節奏合理；不會優先誤殺剛出膛 Boss 彈。

---

### 1.3 Q1 — fork 子池 cap 48，主池不再空槍

#### 證據鏈

| 檢查 | 位置 | 實況 |
|------|------|------|
| 子池 | `entity_factory.gd:21,37,87-88,134-149` | `fork_projectile` prewarm 56、cap 48、獨立 active 列表 |
| 生成 | `projectile.gd:151-161` | `_try_spawn_riftline_forks` → `spawn_fork_projectile`（不再走主 `spawn_projectile`） |
| 不遞迴 | `projectile.gd:152,169-180` | `fork_depth > 0` return；裂片 `riftline_fork_level=0`、`fork_depth+1` |
| 釋放 | `entity_factory.gd:344-351` | 依 `_node_pool_name` 回 `fork_projectile` 或 `projectile` |
| stats | `projectile.gd:164-181` | setup 時 cache，命中只改 `pierce`（Q2 部分採納） |
| 回歸 | `r5_regression_test.gd:194-223` | 灌爆 fork 後主彈仍可生、`projectile.exhausted` 不升 |

#### 判定

| 命題 | 判定 |
|------|------|
| 主 `projectile` 池不再被碎彈扇出掏空 → 主槍空槍 | **成立** |
| 碎彈永不靜默消失 | **未承諾／部分** — cap 滿 `return null` + `fork_projectile_cap_skips++`（`:136-138`） |

| ID | 等級 | 問題 | 位置 |
|----|------|------|------|
| Q1 | P1 原題 | fork 佔主池 | **成立已修** |
| R6-Q1b | P2 | 極限穿透＋多發＋fork Lv2 仍可讓**碎彈**大量 skip（體感「有時少兩片」） | `entity_factory.gd:136-138`；`projectile.gd:157-161` |

**結論**：Q1 原意（主武器空槍）**成立**。不是無限碎彈保證。

---

### 1.4 Q3／Q4 — hazard LRU + modulate 淡出

#### Q3 LRU

| 檢查 | 位置 | 實況 |
|------|------|------|
| 追蹤 | `entity_factory.gd:52,197-210` | `active_hazard_zones` append |
| 滿 cap | `:199-200` | `_reclaim_oldest_hazard_zone()` 而非 `return null` |
| 最舊 | `:549-556` | compact 後取 `[0]`（append 序） |
| 釋放 | `:364-367` | **同步** `_release`（比敵彈 deferred 乾淨） |
| 回歸 | `r5_regression_test.gd:226-268` | 第 9 個替換最舊且 live 維持 8 |

**判定：Q3 成立** — 餘燼 cap 滿改頂最舊，不再「有卡無火」。

殘留設計：被頂掉的餘燼傷害時間被截斷（玩法取捨，非 bug）。

#### Q4 淡出／redraw

| 檢查 | 位置 | 實況 |
|------|------|------|
| setup 一次 redraw | `hazard_zone.gd:42,98-100` | `_request_redraw()` |
| `_process` | `:45-60` | **無** `queue_redraw`；改 `_update_fade` |
| 淡出 | `:63-69` | `modulate.a`；Δα &lt; 0.025 跳過 |
| `_draw` | `:89-95` | 固定幾何 alpha，靠 modulate 乘算 |
| 回歸 | regression 等 8 frame，`redraw_request_count` 不變 | 對齊 |

**判定：Q4 成立** — 每幀 CanvasItem 重繪已移除；淡出正確（視覺為 modulate 乘在 fill/arc 上）。

| ID | 等級 | 殘留 | 位置 |
|----|------|------|------|
| R6-Q4b | P2 | 淡出階梯約 0.025，壽命末端可能停在極低非零 alpha（無感） | `hazard_zone.gd:66-69` |

---

### 1.5 Q5 — 磁暴 run 級旗標

#### 證據鏈

| 檢查 | 位置 | 實況 |
|------|------|------|
| 旗標 | `game_manager.gd:66,103,377-382` | `magnetic_reclaim_enabled`；`start_run` 清零；`enable`／`has` API |
| 升級取得 | `squad_manager.gd:228-229,279-280` | 升級或商店隨機質變套到 `magnetic_reclaim` → `GameManager.enable_magnetic_reclaim()` |
| 死亡觸發 | `enemy.gd:475-476` | **只**查 `GameManager.has_magnetic_reclaim()`，**不**掃武器 |
| 英雄死 | — | 旗標在 GameManager，非英雄 modifier 生命週期 |
| 回歸 | `r5_regression_test.gd:96-123` | 無 weapon modifier 仍 magnetize |

**判定：Q5 成立（真局級）** — 斥候死亡不關磁暴；新 run 重置。

| ID | 等級 | 殘留 | 位置 |
|----|------|------|------|
| R6-Q5b | P2 設計 | 磁暴**取得入口**仍只掛在 `chain_lightning` 質變表（`squad_manager.gd:42-53`）——沒斥候就幾乎抽不到；一旦取得則局級 | 與「局級效果／單武器卡」敘事略裂，非功能 bug |
| R6-Q5c | P2 | `_die` 用 `call_deferred` 先 spawngem 再 magnetize，同幀 idle 序可工作；若未來改同步 spawn 順序須重驗 | `enemy.gd:466-476` |

---

### 1.6 R5 覆核總表

| ID | R5 命題 | R6 裁決 | 檔案:行號（錨點） |
|----|---------|---------|-------------------|
| S1 | 滿血急救 disable+提示+不扣金 | **成立** | `game_manager.gd:327-355`；`rift_shop_screen.gd:161-186`；`squad_manager.gd:247-255` |
| S2 | 質變滿 disable+提示+不扣金 | **成立** | `game_manager.gd:332-334,353-367`；`squad_manager.gd:269-305`；`base_weapon.gd:40-52` |
| E1 | Boss 環不因 cap 缺角 | **成立** | `entity_factory.gd:38,152-165,534-546`；`enemy.gd:312-318` |
| Q1 | fork 不掏空主彈池 | **成立** | `entity_factory.gd:134-149`；`projectile.gd:151-161` |
| Q3 | hazard cap LRU | **成立** | `entity_factory.gd:197-210,549-556` |
| Q4 | 取消每幀 redraw／modulate 淡出 | **成立** | `hazard_zone.gd:45-69,89-100` |
| Q5 | 磁暴 run 旗標 | **成立** | `game_manager.gd:66,103,377-382`；`enemy.gd:475-476` |
| R6-E1b | reclaim 後主池耗盡仍可能丟 Boss 彈 | **新邊界（P2）** | `entity_factory.gd:152-165,344-351` |
| R6-Q1b | fork 自身 cap 靜默 skip | **已知殘留（P2）** | `entity_factory.gd:136-138` |

---

## (2) R5 延後項是否該修？

### 2.1 E4 — 精英 XP 極端 cap fallback

**現況**（仍未修）：

```466:469:scripts/enemies/enemy.gd
	if xp_value > 0:
		EntityFactory.call_deferred("spawn_xp_gem", global_position, xp_value)  # cap → 靜默 grant
	if elite_bonus_xp > 0:
		EntityFactory.call_deferred("spawn_visible_xp_gem", global_position, elite_bonus_xp)
```

`spawn_visible_xp_gem`（`entity_factory.gd:249-260`）：優先可見／合併；**場上無 active gem 可合 → `_grant_xp_direct`**。

| 項目 | 結論 |
|------|------|
| **該不該修** | **該修，但列 P1 而非立刻 P0** |
| **嚴重度** | 經驗值**不會丟**；丟的是「精英大顆可見心跳」與磁吸路徑的體感。需 **XP 池 180 滿且場上無可合寶石** 的極端局 |
| **與 R4 紅線** | 「精英不得靜默 grant」仍是**灰區違規**；頻率低於 E6 |
| **最小修法** | ① `elite_bonus_xp` **禁止** `_grant_xp_direct`：滿則 **強制合併最近 gem**，若 `active_xp_gems` 空則 **回收最遠／最舊普通 gem 槽位再 spawn**；② 或精英改只走一顆合併後的大 gem（`xp+bonus` 單一可見物）。**不要**為此提高 cap 到無上限 |

---

### 2.2 E6 — 精英 cap 到點消失

**現況**（仍未修）：

```123:125:scripts/enemies/enemy_spawner.gd
	if elapsed >= next_elite_time:
		_spawn_elite()
		next_elite_time = elapsed + randf_range(45.0, 60.0)
```

```151:153:scripts/enemies/enemy_spawner.gd
func _spawn_elite() -> void:
	if EntityFactory.get_enemy_live_count() >= max_enemies:
		return
```

| 項目 | 結論 |
|------|------|
| **該不該修** | **必須修，維持 P0** |
| **嚴重度** | 滿 150 時整段 **45–60s 精英心跳被吞**，威脅支柱直接假死；比 E4 常見得多（後期常貼 cap） |
| **最小修法（擇一）** | **A（最小）**：`_spawn_elite` 失敗時 **不要**前進 `next_elite_time`（或設 `next_elite_time = elapsed + 1.0` 短重試）。**B（體驗更好）**：cap 滿時 **替換**一隻非精英、非 Boss 的普通敵（LRU／最遠玩家）再 spawn 精英。**C**：精英預留 soft slot（`max_enemies - 2` 才允許普通刷，精英可用最後 2）。建議 **A 立刻 + B 同迭代** |
| **注意** | Boss 路徑（`:169-172`）已是「失敗不設 `boss_spawned`、每幀重試」——精英應對齊這個哲學 |

---

### 2.3 S3 — 180s 商店撞 Boss

**現況**（仍未修）：

| 時刻表 | 來源 |
|--------|------|
| 店：`next_shop_time = 90`，每次 +90 → **90 / 180 / 270…** | `game_manager.gd:64,102,120-122` |
| Boss：`boss_time = 180.0` | `enemy_spawner.gd:108,120-121` |

**節拍衝突推理**（靜態）：

- `GameManager` 為 Autoload 且 `PROCESS_MODE_ALWAYS`，但加時條件含 `not get_tree().paused`。
- 開店會 `paused = true`（`game_manager.gd:289-290`）。
- 場景內 `EnemySpawner` 預設可暫停 → **同刻先開店則 Boss 延後到關店後**；若同幀 Spawner 已跑則可能 Boss 已出再開店（樹序依賴，Autoload 通常更早）。
- 無論哪種：**3:00 節奏被「強制暫停店」污染**，階段高潮被打斷。

| 項目 | 結論 |
|------|------|
| **該不該修** | **該修，P1（建議與商店深化同一包）**；不修也能玩，但 **Boss 節拍可信度**差 |
| **最小修法** | ① 定時店序列改 **75 / 150 / 240 / 330…** 或 **90 / 165 / 255…**，**硬性避開 `[boss_time - 15, boss_time + 25]`**；② `_request_shop` 若 `boss_active` 或 `elapsed` 在窗內 → **延後** `next_shop_time = boss_time + 25` 而非開店；③ Boss 擊殺後的階段勝利已是暫停，**不要**在 victory 後 0s 再塞店 |
| **一併** | 升級後 10% 隨機店（`:230-231`）在 Boss 窗也應 `return` 或延後 |

---

### 2.4 延後項優先序（給下輪實作）

| 序 | ID | 優先 | 理由 |
|----|-----|------|------|
| 1 | **E6** | **P0** | 心跳事件被吞，威脅支柱假死 |
| 2 | **S3** | **P1** | Boss 節拍；與商店深化同包最划算 |
| 3 | **E4** | **P1 灰** | 極端才現；修法小，可跟 E6 同 PR |

---

## (3) P1 深度設計審查 —「想一直玩」閉環路線圖

### 3.0 設計前提（務實）

| 約束 | 含義 |
|------|------|
| 佔位美術 | 質變靠 **色／尺度／殘留 VFX／彈幕形狀**，不靠新角色立繪 |
| Web 單執行緒 | 禁止無上限 instantiate；新系統走既有 pool／spatial／cap 契約 |
| 現有架構 | 武器差異在 `WeaponData.modifier_levels` + behavior script；敵在 config + `behavior_id`；進程在 `GameManager` |
| 現況缺口 | 局內三支柱＝可感知原型；**局間＝零**；build 頂在「質變滿層＋數值卡」；精英＝大號 tank |

**P1 成功判準（可測）**：

1. 失敗後有 **&lt;10s** 的「我帶回了什麼／下一局要試什麼」決策。  
2. 同一武器在「未進化／進化後」清場語彙 **肉眼可辨**（不靠讀 DPS）。  
3. 開局 30s 內兩次 run 因契約不同而 **走位或優先級不同**。  
4. 商店至少一次讓玩家 **存錢賭下一檔** 或 **錯開 Boss**。  
5. 精英死亡／交戰至少一種詞綴讓玩家說「是那個會分裂的紫怪」。

---

### 3.1 a) Meta 局間進程 —「裂隙殘響」

#### 命名與體驗

| 項目 | 內容 |
|------|------|
| 系統名 | **裂隙殘響（Veil Echo）** |
| 貨幣 | **殘響碎片**（與局內金幣分離，避免心智混亂） |
| 來源 | 每局結算：存活時間分 + 擊殺分 + 精英／Boss 紅利；**局內未花金幣可折現 30–50%**（鼓勵店有意義地花，也允許存） |
| 永久升級（最小） | 3 軌小幅：**韌性**（開局全隊 +4% max HP）、**拾獲**（開局 pickup_radius +8）、**彈藥預熱**（開局全武器 damage +3%）— **每軌最多 5 級，總加乘封頂可見** |
| 解鎖（比純數值重要） | 用碎片解鎖：**第 2 開局契約欄位**、**一種武器進化配方可見**、**一種精英詞綴圖鑑**（先解鎖再掉落，控制內容量） |

**預期體驗**：死了不虛無——「這把殘響夠升韌性 III，下一把敢換高風險契約」。

#### 為何最小且不破平衡

- **不**做「永久 +50% 傷」雪球；每級 &lt;4%，5 級仍遠小於一張局內質變。  
- Meta **解鎖內容**優先於數值，避免第十局碾壓。  
- 與局內金幣 **分帳**：局內 sink 仍驅動商店。

#### 實作接點

| 元件 | 接點 |
|------|------|
| 存檔 | 新 `scripts/autoload/meta_progress.gd`（或 `GameManager` 旁路）+ `user://veil_echo.cfg`（`ConfigFile`） |
| 結算寫入 | `game_manager.player_died`／`record_boss_kill` 後的 summary；`game_over_screen.gd`／`stage_victory_screen.gd` 顯示「本局殘響 +N」 |
| 開局讀取 | `arena.gd` `start_run` 前套用 HP／pickup／damage 微量；**勿**寫進 `WeaponData` 資源檔本身，只改 runtime copy |
| UI | 極簡：GameOver 下半「殘響商店」3 按鈕；或獨立 `MetaHub` 場景（可第二迭代） |

#### Web／預算

- 僅結算與開局 I/O，**零熱路徑**。  
- 注意 GitHub Pages 仍可用 `user://`（瀏覽器持久化視平台）；失敗時降級「本機 session 記憶」並在 UI 誠實標示。

#### 平衡注意

- 殘響獲取曲線對齊「平均死在 2:00–3:30」：約 **2–4 局升 1 小級**。  
- Boss 擊殺給明顯紅利，強化 3:00 目標。

---

### 3.2 b) 武器進化 — 四武器各一條

接在現有 **`WeaponData.modifier_levels` + behavior script`**，新增 **evolution_id**（或 `modifier` 命名空間 `evo_*`），**不要**複製整把武器 scene，除非行為差到必須。

#### 共通規則（最小）

| 規則 | 內容 |
|------|------|
| 觸發 | 該武器 **對應質變滿層** + **該武器傷害升級 ≥3**（或累計擊殺 token 可選） |
| 提示 | 升級卡池出現 **「進化：xxx」** 單選（weight 高），或自動在滿足時下次 level-up 保底一張 |
| 佔位表現 | 色相偏移 + 彈體 scale 1.15–1.3 + 既有 VFX 複用 |
| cap | 進化不新增池類型則優先；若新彈種 → 必須入 factory pool |

#### 四條路徑

| 武器 | 進化名 | 達成條件（建議） | 質變後形態 | 實作接點 | 預算 |
|------|--------|------------------|------------|----------|------|
| 裂線發射器 `riftline_emitter` | **裂隙扇紡（Rift Fanloom）** | `riftline_fork` Lv2 + 傷≥3 | 主彈命中裂 **3** 片（±0°／±28°）但 fork 傷害 0.4；或主彈變短程「線掃」多 hit box（二選一，建議前者） | `projectile.gd` fork 邏輯讀 `evo_rift_fan`；`weapon_data.gd` max／to_projectile_stats | 仍走 **fork 子池**；可略降主射速補償 |
| 星環飛刀 `orbit_blades` | **裁斷星環（Shear Halo）** | `orbit_resonance` + 刃數升級≥2 | 刃週期性 **外擴一拍**（orbit_radius 脈衝 +28，0.35s）並在外擴期易傷 +30%；或命中附加短 **slow** | `orbit_projectile.gd` + `orbit_weapon.gd` 計時；status 已有基礎設施 | 無新池；避免每幀 new Dictionary |
| 脈衝爆花 `pulse_bloom` | **餘燼井（Ember Well）** | `pulse_embers` | 餘燼 duration 2.0、tick 略升；爆心留下 **第二段延遲爆**（0.45s，傷 0.55） | `explosion_weapon.gd`；延遲可用 timer on hazard 或 factory 延遲 spawn_explosion | 爆炸 cap 已有；延遲爆算入 cap |
| 裂弧雷鏈 `arc_chain` | **過載星暴（Overload Nova）** | `chain_overload` +（可選）磁暴 | 末跳爆半徑 ×1.55；若已有磁暴，爆心 **附帶小幅磁吸**（複用 run flag 半徑較小） | `chain_lightning_weapon.gd` `_make_overload_stats` | 爆炸／arc cap 已有 |

#### 預期體驗

「這把斥候不是比較痛，是雷鏈收尾會開花」——進化是 **質變的第二層**，不是 +20% 傷卡。

#### 平衡

- 進化後 **關閉或稀釋** 該武器部分線性卡（例如進化後 `weapon_projectiles` weight↓），避免指數爆炸。  
- 裂線進化必須繼續受 **fork cap 48** 約束；可改「每主彈最多 fork 一次」若壓力測試爆表。

---

### 3.3 c) 開局詞綴／祝福 —「裂隙契約」三選一

#### 命名與體驗

| 項目 | 內容 |
|------|------|
| 系統名 | **裂隙契約（Rift Contract）** |
| 時機 | `start_run` 後、**第一波敵人前**強制暫停三選一（可 skip＝「空白契約」無獎懲） |
| 預期 | 開局 10 秒就決定「這局我要激進還是穩」；run variance 主來源 |

#### 最小契約池（建議 6 選 3 呈現，先做 6 張）

| id | 名稱 | 規則改寫 | 風險 |
|----|------|----------|------|
| `contract_blood_tax` | **血稅** | 全隊傷害 +12%，受擊 +10% | 高攻脆 |
| `contract_golden_famine` | **金饑** | 金幣掉落 +40%，升級選項少 1 張（三選一→二選一）到 90s | 經濟局 |
| `contract_quiet_veil` | **靜幕** | 前 60s 敵 spawn_timer ×1.25（較疏），60s 後密度補償 ×0.9 | 前期教學友好 |
| `contract_elite_beacon` | **精英信標** | 首次精英提早至 35s，精英 bonus 金幣 +3 | 配合 E6 修 |
| `contract_glass_magnet` | **玻璃磁界** | 開局即磁暴 run flag；max_hp −8% | QoL 換脆 |
| `contract_single_thread` | **單線協定** | 隊長傷 +18%，隊員傷 −10% | 編制決策 |

#### 實作接點

| 元件 | 接點 |
|------|------|
| 狀態 | `GameManager.active_contract_id` + `contract_modifiers` Dictionary；`start_run` 重置 |
| UI | 複用 `LevelUpScreen` 版型或輕量 `ContractScreen.tscn`（PROCESS_ALWAYS） |
| 消費端 | `enemy_spawner`（密度／精英時刻）、`enemy._die`（金幣）、`hero` 傷／HP、`GameManager._build_upgrade_choices`（選項數） |
| Seed | 契約隨機吃 `run_seed`，便於回歸 |

#### Web／預算

- 僅開局一次 UI，零熱路徑。  
- 契約效果用 **乘子欄位**，禁止在 `_physics_process` 字串 match 大表。

---

### 3.4 d) 商店深化（含 S3）

#### 命名與體驗

| 項目 | 內容 |
|------|------|
| 系統名 | **裂隙商亭 2 號規程** |
| 目標 | 從「停一次買一個」→「看時刻表、看庫存、決定花或賭」 |

#### 時刻表（直接解決 S3）

| 建議 | 內容 |
|------|------|
| 定時店 | **80s、155s、250s、340s**（示例） |
| Boss 窗 | `[165, 205]` **禁止**定時店與升級後隨機店 |
| Boss 後 | 階段勝利「繼續」後 **+12s** 可插一次「戰利品店」（庫存偏恢復／護盾） |

#### 商品輪換（最小）

固定欄位 3，但 **池抽取**：

| 欄 | 池 |
|----|-----|
| 恢復欄 | 急救 30／急救 55 貴版／護盾 12s（權重） |
| 力量欄 | 隨機質變／指定「當前未滿質變」之一（文案寫死武器名，降低純隨機挫敗）／臨時 +15% 全隊傷 20s |
| 賭欄 | **刷新本店 +1 金**（或免費第一次）／「下一精英保證可見大 XP」消耗品 |

- 仍 **單次購買可關** 或改 **可買 1～2 次再離開**（建議 P1 先 **可買到離開，最多 2 購**，避免經濟崩）。  
- S1／S2 邏輯 **沿用** `enabled`／`disabled_reason`；新商品都必須進 `_shop_option_disabled_reason`。

#### 實作接點

| 元件 | 接點 |
|------|------|
| 時刻 | `game_manager.gd` `next_shop_time` 改序列或函式 `_schedule_next_shop()` |
| 庫存 | `_build_shop_options` 改為從 `SHOP_POOLS` 加權抽 3 |
| UI | `rift_shop_screen.gd` 支援 2 購或「刷新」按鈕 |
| Boss 窗 | `_request_shop` 查 `boss_time`／`boss_active` |

#### 平衡／Web

- 金幣收入維持現狀時，2 購需調價（急救 8、質變 18 可維持；刷新 4）。  
- 禁止店內每幀重建 Button；只在 open／refresh 時建。

---

### 3.5 e) 精英詞綴化 — 不是大號 tank

#### 命名與體驗

| 項目 | 內容 |
|------|------|
| 系統名 | **扭曲詞綴（Distortion Affix）** |
| 目標 | 精英＝**規則怪**，玩家改走位／集火優先級 |

#### 最小 3 詞綴（先做 3，spawn 時 roll 1）

| id | 名稱 | 行為 | 佔位表現 | 實作接點 | 預算注意 |
|----|------|------|----------|----------|----------|
| `affix_split` | **分裂** | 死亡時若 cap 允許，吐 **2** 隻小扭曲體（禁用再分裂；可用既有 spawnling 色相紫） | 死亡多兩小紫 | `enemy.gd` `_die`／config `affix_id`；**必須** `death_spawn_cap` | 等同 spawner 紀律，禁連鎖 |
| `affix_field` | **磁場** | 半径 120 內英雄 `move_speed` 乘 0.82（或施加 `slow` status 若英雄支援；最小可改英雄 `_process` 讀鄰近旗標） | 精英外圈低 alpha 環（複用 hazard **或** 單 Circle 繪製，**全場最多 1–2 個** elite field） | `enemy.gd` + 可選輕量 `affix_aura` | **禁止**每精英每幀 `get_nodes_in_group`；用 squad members 列表（≤5） |
| `affix_swift` | **迅捷** | 速度 ×1.45，傷 ×0.9，dash 觸發（可直接套 `behavior_id=dasher` 底 + 精英數值） | 更亮、trail 用既有 modulate | `enemy_spawner._spawn_elite` 覆寫 behavior | AI 已有 dasher，成本低 |

#### 生成

```text
_spawn_elite:
  修 E6 後
  roll affix ∈ {split, field, swift}
  config["affix_id"] = ...
  config 數值仍 ×3 HP 等，但 swift 降 HP 係數到 ×2.4 防又快又肉
```

#### 預期體驗

「紫的來了——磁場那個，先別貼」；精英從血海進度條變成 **事件**。

---

### 3.6 建議實作順序（務實迭代）

| 序 | 交付包 | 內容 | 依賴 | 預估體感回報 |
|----|--------|------|------|--------------|
| **0** | 熱修 | **E6**（+可選 E4） | 無 | 恢復精英心跳可信度 |
| **1** | 商店 2.0 + S3 | 時刻表錯開、池化商品、disable 契約延續 | R5 店已穩 | Boss 節拍 + 金幣決策 |
| **2** | 開局契約 | 6 張契約、Contract UI、seed | GameManager 狀態 | **立刻** run variance |
| **3** | 精英詞綴 3 | split／field／swift + E6 | 敵 config | 威脅支柱「質變」 |
| **4** | 武器進化 ×4 | 條件 + evo modifier + 行為差 | 質變滿層系統已在 | build 長線目標 |
| **5** | Meta 殘響 | 結算碎片、3 軌小升級、1–2 解鎖 | 結算 UI | 局間黏著 |

**原則**：先修 **E6** 再加精英詞綴（否則詞綴也會被 cap 吞）。Meta 放後半——沒有局內差異時 Meta 只是數字安慰劑。

---

### 3.7 明確不做（本 P1 邊界）

| 不做 | 理由 |
|------|------|
| 完整城鎮 hub／多地圖 | 佔位美術與 Web 包體不划算 |
| 十種以上契約／詞綴 | 先 6+3 打磨可讀性 |
| 永久大數值成長 | 破單局平衡、加速同質碾壓 |
| 新彈種無 pool | 違反 R1–R3 紅線 |
| 把 BalanceMock 當平衡真理 | R5 已判定紙上模擬；新系統用 **Arena 插樁／R5Regression 擴表** |

---

## (4) 紅線與 Web 預算（R6 快檢）

| 紅線 | R6 狀態 |
|------|---------|
| 命中 `spawn_token` | **維持**（本輪 diff 未改命中表） |
| 武器禁 group 掃敵 | **維持** |
| 視覺 cap 不吞玩法 | **改善**（E1／Q3）；**殘留** E4／E6／fork skip |
| 無上限 instantiate | **維持**（fork／hazard／敵彈皆 cap） |
| 熱路徑 | Q4／Q5 改善；敵 AI 找英雄、active 列表 erase 仍為舊債 P2 |

---

## (5) 本輪未驗證邊界（誠實）

- 未執行 Godot headless、未重跑 `R5RegressionTest`／Stress／Playwright。  
- 未實機長測 3:00 Boss＋多 ranged 彈幕手感。  
- E1／Q1 等「成立」以 **程式路徑 + 迴歸腳本意圖** 為準；R6-E1b 等邊界需壓力插樁才能量化。  
- 線上部署是否已含 `e04d739` 未在本輪驗證。

---

## (6) 最終一句

R5 **把該補的洞補對了**（店卡死、Boss 環、fork 主池、hazard 幀成本、磁暴局級）——對抗性覆核下主路徑 **成立**；但 **E6 精英到點消失** 與 **S3 店撞 Boss** 仍會在實戰偷走節拍，且就算修完，若沒有 **契約／進化／詞綴／殘響** 這層 P1，三支柱仍停在「可感知原型」，到不了「想一直玩」。下一輪請按 **E6 → 商店時刻表 → 開局契約 → 精英詞綴 → 武器進化 → Meta** 推進，並繼續用真實 Arena 回歸而非紙上 mock 宣告勝利。
