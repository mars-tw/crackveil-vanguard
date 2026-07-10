# Crackveil Vanguard — 對抗性設計／程式審查 R5

**審查者**：資深遊戲設計師＋Godot 4 技術總監（對抗式，以工作區未 commit 程式碼為準，不採信 `CODEX_RESPONSE_R4` 語氣）  
**審查對象**：R4 P0 更新（質變升級、新敵行為、精英／proto-Boss、生存曲線、局內店、階段勝利、固定 seed）  
**對照**：`docs/GROK_REVIEW_R4.md`、`docs/CODEX_RESPONSE_R4.md`、工作區 `git diff`／新檔  
**方法**：靜態讀碼（`scripts/`、`scenes/`、`resources/`、未追蹤新場景）；本輪**只審不改**，未重跑 Godot headless／瀏覽器長測  
**日期**：2026-07-10  

---

## 執行摘要

| 面向 | 判定 |
|------|------|
| build 質變（5 張升級） | **部分成立**：分叉／餘燼／過載明顯改清場語彙；共鳴偏規則 debuff；磁暴偏 QoL。仍混大量線性數值卡 |
| 威脅質變（敵／精英／Boss） | **大致成立**：ranged／dasher／spawner／Boss 二階有行為差；精英仍是「大號 tank」心跳，非新 AI |
| 進程閉環（金幣店／階段勝） | **弱成立**：金幣終於有 sink；店為「單次三選一停頓」，深度淺；Boss 後有階段勝可繼續無盡 |
| R4 紅線（token／cap 不吞玩法／熱路徑） | **主幹維持**；精英 cap 跳過、敵彈 cap、精英 XP fallback 有**局部違規或灰區** |
| CODEX 驗證可信度 | **高估**：`BalanceMockRun` 是紙上模擬，**不是**真實 Arena 插樁；Boss HP 與回應數字不一致 |
| R5 總判定 | **P0 骨架有落地，三根 Roguelite 支柱從「幾乎沒有」拉到「可感知原型」**；尚未達到「想一直玩」的閉環強度。殘留 bug 與效能債會在 Web 與中後期放大 |

**一句話**：R4 修正**方向對、主契約大多守住**，但「質變／威脅／進程」仍是**薄實作**——能做出差異，卻不足以讓第二局與第十局質性地分家；且有數個 cap／商店／時刻表交叉的實戰地雷。

優先級（本輪）：

| 等級 | 意義 |
|------|------|
| **P0** | 正確性、紅線、會直接弄丟心跳事件／卡住 UI |
| **P1** | 體驗缺口、平衡、可重現 cap 吞結果、Web 熱路徑 |
| **P2** | 文件／mock 誇大、可讀性、長期擴充 |

狀態標籤：

- **成立**／**部分成立**／**未修好**／**新 bug**／**紅線違規（灰／實）**

---

## (0) 變更盤點（以 git 為準）

**已修改（18 files，約 +1276 / −60）**：`game_manager`、`entity_factory`、`enemy`、`enemy_spawner`、`squad_manager`、`weapon_data`、武器／投射物、`arena`、HUD 結算等。

**未追蹤新檔**：

| 路徑 | 角色 |
|------|------|
| `scripts/projectiles/hazard_zone.gd` + `scenes/projectiles/HazardZone.tscn` | 脈衝餘燼池化 hazard |
| `scripts/ui/rift_shop_screen.gd` + `RiftShopScreen.tscn` | 局內商亭 |
| `scripts/ui/stage_victory_screen.gd` + `StageVictoryScreen.tscn` | Boss 階段勝利 |
| `scripts/debug/balance_mock_run.gd` + 場景 | **非實局**曲線 mock |
| `docs/CODEX_RESPONSE_R4.md`、`docs/GROK_REVIEW_R4.md` | 文件 |

`Arena.tscn` 已掛 `RiftShopScreen`／`StageVictoryScreen`。

---

## (1) 質變升級 — 是否真質變？池化／debuff／裂片

### 1.1 總表

| id | 掛載 | 是否改變操作／清場語彙 | 判定 |
|----|------|------------------------|------|
| `riftline_fork` | linear | 命中噴 ±20° 碎彈；彈幕形狀變胖 | **成立（真質變）** |
| `orbit_resonance` | orbit | 命中套 `vulnerable` 1.35s，受傷 +20% | **部分成立**（規則 debuff，非新操作） |
| `pulse_embers` | explosion | 爆點留 1.2s 燃燒區 | **成立（真質變）** |
| `chain_overload` | chain_lightning | 末跳小範圍爆 | **成立（真質變）** |
| `magnetic_reclaim` | **僅** chain_lightning | 擊殺 155px 吸 XP | **偏數值／QoL**；且綁雷鏈角色 |

權重與層數（`squad_manager`／`weapon_data`）：

- 數值卡 weight **1**、質變 **3**、招募 **4** — **成立**（R4 P0-4）。
- 質變 max：fork 2、其餘 1 — **成立**。
- D1 星環無效冷卻：`_weapon_has_meaningful_cooldown_upgrade` 跳過 CD=0／multiplier≈1 — **成立（D1 已修）**。

### 1.2 裂線分叉 — 不遞迴？

**結論：不遞迴 — 成立。**

```148:168:scripts/projectiles/projectile.gd
func _try_spawn_riftline_forks() -> void:
	if target_group != "enemies" or riftline_fork_level <= 0 or fork_depth > 0:
		return
	var fork_stats := {
		...
		"riftline_fork_level": 0,
		"fork_depth": fork_depth + 1
	}
```

- 裂片強制 `riftline_fork_level = 0` 且 `fork_depth > 0` 直接 return。
- 傷害 ×0.5 — 符合 R4。

**殘留設計風險（非遞迴 bug）**：

| ID | 等級 | 問題 | 位置 | 最小重現 |
|----|------|------|------|----------|
| Q1 | P1 | **每次命中**都裂 2 發；穿透＋多發會指數級佔用 `projectile` 池（非遞迴，但是扇出） | `projectile.gd:117-125,148-168`；`linear_bullet_weapon.gd` 多發 | 疊 `riftline_fork` Lv2 + `weapon_projectiles`×2 + 穿透，對密集怪掃射；觀察 pool exhausted |
| Q2 | P1 | 裂片在事件點 **每命中 new Dictionary**（見 §5） | `projectile.gd:152-164` | 同上，Profiler 看 Dictionary 分配 |

### 1.3 星環共鳴 — debuff 池化？死亡清除？每幀 new？

**結論：debuff 實作正確 — 成立。**

| 檢查 | 實況 |
|------|------|
| 資料結構 | `status_timers`／`status_strengths` 字典，**非**每幀 `new` 物件 |
| 套用 | `orbit_projectile.gd:130-131` → `apply_status_effect("vulnerable", 1.35, 0.2)` |
| tick | `enemy._tick_status_effects` 倒數後 erase |
| 死亡清除 | `_die` 與 `pool_on_release` 皆 `clear()`（`enemy.gd:88-89,456-457`） |
| 傷害消費 | `take_damage` → `_damage_taken_multiplier()` |

**體驗向**：易傷 +20% 是**規則改寫**，但玩家操作仍是「站著讓刃轉」——比純 +傷好，仍弱於分叉／餘燼的「看得見的語彙」。

### 1.4 脈衝餘燼 — Hazard 池化／cap／死亡清理

**結論：池化與 cap 成立；cap 滿時靜默丟餘燼（灰區）。**

| 檢查 | 實況 |
|------|------|
| 場景／池 | `HazardZone.tscn`；`PREWARM_COUNTS.hazard_zone=8`；`HAZARD_ZONE_CAP=8` |
| 生成 | `explosion_weapon.gd:19-20` → `spawn_hazard_zone` |
| cap | `entity_factory.gd:161-163` live≥8 → `return null`（**無傷害 fallback**；餘燼本體即玩法） |
| 釋放 | duration 到 → `release_hazard_zone`；`pool_on_release` 清 stats／timer |
| 傷害路徑 | spatial `get_enemies_in_radius`，**未**掃 `enemies` group |

| ID | 等級 | 問題 | 位置 | 最小重現 |
|----|------|------|------|----------|
| Q3 | P1／紅線灰 | 餘燼 **cap 直接 null**，低 CD 爆炸流會「有卡無效」 | `entity_factory.gd:161-163`；`hazard_zone` 無排隊 | 工匠 `pulse_embers` + 冷卻疊滿；同時存在 >8 爆點 |
| Q4 | P1 效能 | **每幀 `queue_redraw()`**（最多 8 個 Node2D） | `hazard_zone.gd:39-55,74-82` | Web 開餘燼，Profiler CanvasItem |

### 1.5 雷鏈過載

**結論：成立。**

- 末跳 `EntityFactory.spawn_explosion`（先結算傷害再 VFX）— `chain_lightning_weapon.gd:45-46`。
- used 集合優先 `get_hit_token()` — **紅線維持**。

### 1.6 磁暴回收

**結論：功能成立；質變身份弱；綁定過窄。**

| 檢查 | 實況 |
|------|------|
| 觸發 | `_die` 若 `has_weapon_modifier("magnetic_reclaim")` → deferred `magnetize_xp_near(..., 155)` |
| 非全圖 | 半徑 155 — 符合 R4 |
| 池／狀態 | `force_magnet_to` 設 collector＋1.45s timer；`pool_on_release` 清除 |
| 掛載 | **只**在 `QUALITATIVE_UPGRADES["chain_lightning"]` — 實務上幾乎只有裂弧斥候能抽到 |

| ID | 等級 | 問題 | 位置 | 最小重現 |
|----|------|------|------|----------|
| Q5 | P1 設計 | 磁暴應是**局級 QoL 質變**，卻綁單武器；斥候死後 modifier 消失 | `squad_manager.gd:42-53`；`enemy.gd:474-476` | 只升斥候磁暴 → 讓斥候死 → 擊殺不再吸 XP |
| Q6 | P1 效能 | **每次擊殺**掃全隊武器找 modifier | `enemy.gd:474-476`；`has_weapon_modifier` | 150 敵高速清場 |

### 1.7 質變小結（支柱 1）

| 命題 | 判定 |
|------|------|
| 「至少有改規則的卡」 | **成立**（3/5 強、1 中、1 弱） |
| 「升級 entropic 質變主導體驗」 | **未達**：數值卡仍多數；滿編後池仍被武器線性卡稀釋 |
| debuff／hazard 不每幀 new、死亡清 | **成立** |
| 裂片不遞迴 | **成立** |

---

## (2) 新敵／精英／Boss — token、cap、池、spawner

### 2.1 行為一覽（config 驅動 — 成立）

| type | min_time | 行為 | 證據 |
|------|----------|------|------|
| `ranged` | 30s | 保持距離 → windup 變色 0.3s → 慢彈 | `enemy.gd:196-222,303-309`；config 44-64 |
| `dasher` | 55s | windup → dash → recover | `enemy.gd:225-264` |
| `spawner` | 45s | chaser；死亡吐 2 不連鎖小怪 | config 65-83；`_spawn_death_children` |
| `elite_distortion` | 52s 起，每 45–60s | tank×3HP×1.3 傷，大體型 | `enemy_spawner.gd:151-166` |
| `veil_gatekeeper` | 180s | 二階段：50% 環彈＋召 4 dasher；週期環彈 | `enemy.gd:267-348`；spawner 169-197 |

### 2.2 spawn_token 命中表

**結論：主幹維持 — 成立。**

| 路徑 | token |
|------|--------|
| 玩家彈 `Projectile._hit_key_for` | `get_hit_token()` |
| 星環 `OrbitProjectile` | 同上 |
| 雷鏈 used | 同上 |
| 敵生成 | `entity_factory.spawn_enemy` → `_issue_enemy_spawn_token` → `pool_reset` |

敵彈打英雄用 `instance_id`（英雄不進池）— **可接受**。

### 2.3 敵彈池化與 cap

**結論：池化成立；cap 可能吞 Boss／遠程傷害（玩法 cap，非純視覺）。**

| 檢查 | 實況 |
|------|------|
| API | `spawn_enemy_projectile` → 共用 `projectile` 池 + `active_enemy_projectiles` |
| cap | `ENEMY_PROJECTILE_CAP = 48`；滿則 `null` |
| layer | `target_group=heroes` → `collision_mask=1`；`Hero.tscn` layer=1 — **碰撞正確** |
| 釋放 | `release_projectile` erase 追蹤陣列 |

| ID | 等級 | 問題 | 位置 | 最小重現 |
|----|------|------|------|----------|
| E1 | **P0 紅線灰／實** | 敵彈 cap **直接丟傷害投射物**（Boss 環彈 10～14 + 場上 ranged） | `entity_factory.gd:35,121-128`；`enemy.gd:312-317` | 3:00 Boss 二階環彈同時場上多 ranged；部分環缺角／無彈 |
| E2 | P2 | 敵彈與玩家彈搶同一 240 池 | 同上 + 分叉扇出 | 後期分叉＋Boss 同屏 |

### 2.4 Spawner 死亡不爆池

**結論：有 cap 閘 — 大致成立。**

```481:505:scripts/enemies/enemy.gd
func _spawn_death_children() -> void:
	...
		if EntityFactory.get_enemy_live_count() >= death_spawn_cap:
			return
		EntityFactory.spawn_enemy(death_spawn_id, _death_child_config(), ...)
# _death_child_config: spawns_on_death = false
```

- 子怪強制不連鎖 — **成立**。
- Boss 召 dasher 同樣查 `death_spawn_cap` — **成立**。
- `death_spawn_id = "spawnling"` **不在** `ENEMY_CONFIGS`，但呼叫端帶完整 config — **可運作**（靠字串 type_id，非查表）。

| ID | 等級 | 問題 | 位置 | 最小重現 |
|----|------|------|------|----------|
| E3 | P2 | 死亡當幀 parent 仍占 `live_count`，再 unregister — 略偏保守（寧可少生） | `_die` 先 spawn 再 `release_enemy_deferred` | cap 貼 150 殺 spawner，可能少 1 隻子怪 |

### 2.5 精英掉落「不得靜默 grant」

R4 要求：精英死亡**必掉可見物**，不要靜默 grant。

實作：

```465:468:scripts/enemies/enemy.gd
	if xp_value > 0:
		EntityFactory.call_deferred("spawn_xp_gem", global_position, xp_value)  # cap 時 _grant_xp_direct
	if elite_bonus_xp > 0:
		EntityFactory.call_deferred("spawn_visible_xp_gem", global_position, elite_bonus_xp)
```

`spawn_visible_xp_gem`：優先可見／合併既有寶石；**若無任何 active gem 可合併 → `_grant_xp_direct`（靜默）**。

| ID | 等級 | 問題 | 位置 | 最小重現 |
|----|------|------|------|----------|
| E4 | **P1 紅線灰** | 精英「大 XP」在 XP cap + 場上無寶石時仍可能靜默 | `entity_factory.gd:211-222`；`enemy.gd:467-468` | 堆滿 180 XP 寶石不撿 → 殺精英；bonus 可能直接進帳無物 |
| E5 | P1 設計落差 | R4 還建議「保證質變選項」— **未做**，只有大 XP＋金幣 | `enemy_spawner.gd:151-166` | 殺精英無升級 UI |

另：精英 **cap 滿時整隻不生** 且 **計時器仍前進**（見 E6）— 比靜默 grant 更傷心跳。

### 2.6 精英／Boss 與 150 cap

| ID | 等級 | 問題 | 位置 | 最小重現 |
|----|------|------|------|----------|
| E6 | **P0** | 精英：`_spawn_elite` 因 cap return，但 `next_elite_time` **已推進** → **整窗精英消失** | `enemy_spawner.gd:123-125,151-153` | 2:00 後維持 150 滿場；到點無紫大怪 |
| E7 | P1 | Boss：cap 滿則 **不**設 `boss_spawned`，每幀重試 — 較安全；但若長期 150 滿，Boss 延後到有空位 | `enemy_spawner.gd:169-172` | 刻意不清怪卡 150 到 3:00+ |
| E8 | P2 | 精英仍是 chaser tank 皮，無獨特招式 | config 用 tank 底 | 視覺：大紫 tank |

### 2.7 威脅小結（支柱 2）

| 命題 | 判定 |
|------|------|
| 不再只有一種腦 | **成立**（至少 4 套行為 + Boss） |
| 精英心跳 | **半成立**；E6 可整段吞掉 |
| Boss 故事節拍 | **成立**（3:00、二階、階段勝） |
| 紅線 token | **成立** |
| 紅線 cap 不吞玩法 | **未完全**（E1／E4／E6） |

---

## (3) 金幣商店閉環 — 是否真有意義？暫停競態？

### 3.1 閉環是否成立

| 項目 | 實況 | 判定 |
|------|------|------|
| Sink | `spend_gold`；商品 8／18／12 | **成立（最小閉環）** |
| 來源 | 擊殺／精英 6 金／Boss 16 金 | 足夠買 1～2 次 |
| 觸發 | 每 90s；升級後 10% | **成立** |
| 單次購買即關店 | `apply_shop_purchase` 成功 → `_close_shop` | 有意設計；深度淺 |
| Meta | 仍無 | R4 P0 允許 |

**體驗**：金幣不再是謊言 — **支柱 3 弱成立**。但仍是「停下來花一次」而非經營張力（無刷新、無多購、無存錢賭 Boss）。

### 3.2 暫停／失敗路徑

| 路徑 | 行為 | 判定 |
|------|------|------|
| 開啟 | `waiting_for_shop=true`；`paused=true`；UI ALWAYS | 成立 |
| 成功購買 | 扣金 + `_close_shop` → `paused=manual_paused` | 成立 |
| 金幣不足 | 按鈕 disabled；後端再 check | 成立 |
| 購買邏輯失敗 | **不關店、不扣金**；`emit_stats` | 成立（CODEX 修復點） |
| UI 關閉條件 | `stats.waiting_for_shop==false` 才 hide | 成立 |
| 與升級互斥 | `_request_shop` 若 `waiting_for_upgrade` return | 成立 |
| 手動暫停 | shop／upgrade／victory 中不可 toggle | 成立 |

### 3.3 商店新 bug／殘留

| ID | 等級 | 問題 | 位置 | 最小重現 |
|----|------|------|------|----------|
| S1 | **P0 UX／邏輯** | **全隊滿血**時 `heal_members` 全 false → 點「裂隙急救」**無效果、不扣金、店不關、無提示** | `hero.gd:250-256`；`game_manager.gd:329-340` | 滿血進店 → 連點急救 |
| S2 | **P0 UX** | 質變已滿層 → `apply_random_qualitative_upgrade` false → 同上卡死感；按鈕**只**依金幣 disable | `squad_manager.gd:256-278`；`rift_shop_screen.gd:82` | 五質變皆滿 → 進店點偏壓改裝 |
| S3 | P1 | **180s 商店與 Boss 同刻**：`next_shop_time` 序列 90→180→270 與 `boss_time=180` 重疊；GameManager 先暫停開店可 **延後 Boss 出場** | `game_manager.gd:64,118-120`；`enemy_spawner.gd:108,120-121` | 不開暫停到 3:00；常先見商亭 |
| S4 | P2 | 護盾描述「30 點暫時護盾」未寫時長；實為 12s 全隊 | `game_manager.gd:306-311,335` | 讀文案 vs 實測 |
| S5 | P2 | `player_died` 未清 `waiting_for_shop`（實務因 paused 難觸發） | `game_manager.gd:372-380` | 理論髒狀態 |

### 3.4 進程小結（支柱 3）

| 命題 | 判定 |
|------|------|
| 金幣有用途 | **成立** |
| 有階段目標（Boss／勝利 UI） | **成立** |
| 局間回饋／Meta | **仍無**（R4 P1，不記本輪失敗，但黏著力上限仍在） |
| 商店 UX 可發布 | **S1／S2 未修好** |

---

## (4) 生存曲線 — 早期／精英心跳／Boss 降密度

### 4.1 實作參數（對照 R4 建議）

| 項目 | R4 建議 | 實作 | 判定 |
|------|---------|------|------|
| 時間倍率 | 1:30 起 HP/傷 ×(1+0.04/min) | `elapsed<90` return；之後 `1+0.04*minutes_after` | **成立** |
| 含彈傷 | — | `projectile_damage` 一併乘 | 成立 |
| spawn_count | 略緩 | `1+int(elapsed/60)`（舊 /45） | 成立 |
| spawn_timer | 略緩 | `max(0.28, 1.05-elapsed*0.0048)`（舊 0.22／0.006） | 成立 |
| Boss 降密度 | 要 | count×0.45、timer×1.35 | **成立** |
| 開局 0–20s 壓力 | 可選 | **未做**額外 early 壓力 | 早期仍偏軟（見 mock 自打臉） |

### 4.2 節奏推導（非實機長測）

| 時段 | 預期 | 風險 |
|------|------|------|
| 0:00–0:30 | 三武器開局清 normal；仍易「幾乎沒被摸」 | 早期驚險 **可能未達** |
| 0:30–1:30 | ranged／spawner／dasher 進池；質變開始出現 | 威脅語彙最好的窗 |
| 1:30+ | 軟性 HP/傷成長 4%/min | 3 分鐘後僅 ×1.08，**偏溫** |
| 精英 | 52s 起每 45–60s | **E6 cap 可吞** |
| 3:00 Boss | 1500 HP（見下）、降密度 | 與商店搶 180s（S3） |
| 3:00+ 無盡 | 無第二里程碑；倍率緩慢爬 | 長尾可能再回「密度＋雪球」 |

### 4.3 Boss HP 與 mock 誠信

| 來源 | Boss HP |
|------|---------|
| `enemy_spawner.gd:174` | **1500** |
| `CODEX_RESPONSE_R4` | 寫 820 |
| `balance_mock_run.gd:31` | 紙上 **2600**，且 DPS 為假公式 |

| ID | 等級 | 問題 | 位置 | 最小重現 |
|----|------|------|------|----------|
| C1 | **P1 驗證誠信** | BalanceMock **不載入 Arena、不跑真實 spawn／傷害**；PASS 不代表曲線成立 | `balance_mock_run.gd` 全程局部變數 | 讀腳本即可 |
| C2 | P2 文件 | CODEX Boss 820 ≠ 程式 1500 | 文件 vs `enemy_spawner.gd:174` | diff |

Mock 自報 `min_hp_before_90=0.683` → 連**假公式**都承認前 90s 掉不到 32% 血 — 與 R4「早期驚險」目標衝突。

### 4.4 曲線小結

| 命題 | 判定 |
|------|------|
| 有時間縮放 | **成立**（偏保守） |
| Boss 前／中降密度 | **成立** |
| 精英心跳可靠 | **未修好（E6）** |
| 早期驚險 | **很可能未達** |
| 中後期失衡 | 倍率溫＋玩家質變／五砲 → **偏易**風險仍在；隊友死光斷崖仍在（R4 舊債） |

---

## (5) 新引入 bug、Web 單執行緒效能

### 5.1 紅線總表（R4 §3.3）

| 紅線 | R5 判定 | 註 |
|------|---------|-----|
| 命中表用 `spawn_token` | **維持** | 雷鏈已改 token |
| 視覺 cap 不吞玩法 | **局部違反／灰** | 爆炸傷仍先結算；**敵彈 cap、精英 XP fallback、餘燼 cap、精英 skip** 有吞或無感 |
| 武器禁 `get_nodes_in_group("enemies")` | **維持** | 武器／hazard 走 spatial |
| Web 禁無上限 instantiate | **大致維持** | 池化齊；分叉扇出仍可能逼近池頂 |

### 5.2 效能熱路徑

| ID | 等級 | 熱點 | 位置 | 說明 |
|----|------|------|------|------|
| P1 | P1 | 分叉／敵彈 **事件 Dictionary** | `projectile.gd:152`；`enemy.gd:320-331`；`chain_lightning._make_overload_stats` | 武器主 stats 已 cache（C3 部分採納 **成立**）；高射速分叉仍配 |
| P2 | P1 | Hazard **每幀 redraw** | `hazard_zone.gd:55` | Web Canvas 成本 |
| P3 | P1 | 磁暴每殺掃武器 + 掃 active XP | `enemy.gd:474-476`；`entity_factory.magnetize_xp_near` | 可改 run flag |
| P4 | P2 | `active_enemy_projectiles.erase` O(n) | `entity_factory.gd:309` | cap 48 尚可 |
| P5 | P2 | 敵 AI 每幀找最近英雄 | `enemy.gd:379-399` | R4 已標；150×5 可接受 |
| P6 | 繼承 | Stress 仍可能 `STRESS_PERF_BELOW_60` | CODEX 自述 | 未本輪重測 |

### 5.3 其他正確性

| ID | 等級 | 問題 | 位置 | 最小重現 |
|----|------|------|------|----------|
| B1 | P2 | 商店隨機質變 **不**寫入 `GameManager.upgrade_counts`（層數以 `WeaponData.modifier_levels` 為準，功能仍對） | `apply_shop_purchase` vs `_register_upgrade_pick` | 比對升級池 |
| B2 | P2 | `upgrade_weapon` 不檢查 `can_apply`；靠 `_increment_modifier` 封頂；若未來多購店會「成功扣金無成長」 | `hero.gd:332-340` | 改店允許多買時 |
| B3 | P1 | 階段勝利 **僅**「繼續無盡」，無結束結算／build 摘要 | `stage_victory_screen.gd` | 打贏 Boss |
| B4 | 成立 | 固定 seed：`Arena.run_seed`／`--run-seed=`／`forced_run_seed` | `arena.gd:50-60` | CLI |

### 5.4 C1 spatial active 過濾

`enemy_spatial_index` query／compact 均跳過 `is_active=false` — **R4 C1 已修，成立**。

---

## (6) 對 R4 P0 清單逐條裁決

| R4 條目 | 裁決 | 說明 |
|---------|------|------|
| P0-1 質變包 5 張 | **部分成立** | 3 強質變 + 機制正確；磁暴弱且綁鏈；池仍偏數值 |
| P0-2 ranged/dasher/spawner | **成立** | 行為可區分；美術同皮可讀性弱 |
| P0-3 精英 + proto-Boss | **部分成立** | Boss／二階／階段勝有；精英易被 cap 吞（E6）；無保證質變掉落 |
| P0-4 生存曲線 | **部分成立** | 縮放與 Boss 降密度有；早期偏軟；mock 不可信 |
| P0-5 金幣局內店 | **部分成立** | sink 有；S1/S2/S3 傷發布 |
| D1 星環冷卻 | **成立** | 已剔除無效卡 |
| C3 stats cache | **部分成立** | 武器 cache 好；分叉／敵彈事件 dict 仍在 |
| C5 seed | **成立** | 可注入；預設 randomize |

### 三支柱總判

| 支柱 | R4 時 | R5 時 |
|------|-------|-------|
| build 質變 | 幾乎沒有 | **可感知原型**（未穩固） |
| 威脅質變 | 幾乎沒有 | **可感知原型**（精英／cap 不穩） |
| 進程閉環 | 幾乎沒有 | **最小閉環**（店＋Boss 節點；無 Meta） |

---

## (7) 優先修復建議（只建議不改碼）

### 立刻（P0）

1. **E6 精英 cap**：生成失敗時 **不要**前進 `next_elite_time`；或 cap 時預留 slot／強制替換最弱普通怪。  
2. **S1／S2 商店**：滿血／無質變可買時 disable 或改文案「無法購買」並允許明確 skip；失敗要有 UI 反饋。  
3. **S3**：Boss 窗（例如 170–190s）禁止定時店，或 `next_shop_time` 避開 `boss_time`。

### 短期（P1）

4. **E1 敵彈 cap**：Boss 環彈走「必出配額」或獨立 cap；滿時至少保留 Boss 彈。  
5. **E4 精英可見掉落**：bonus 永不 `_grant_xp_direct`，改強制合併／頂掉最遠普通寶石。  
6. **Q1／P1 分叉預算**：每發主彈最多裂一次、或全場 fork 子彈 budget。  
7. **Q4 hazard redraw**：降為 10–15Hz 或用 sprite 動畫。  
8. **磁暴改 run flag**（解 Q5／Q6）。  
9. 用**真實 Arena headless 插樁**取代紙上 `BalanceMockRun`。

### 再下一輪（對齊 R4 P1）

10. Meta／開局編制／武器進化 — 否則「再開一局」動機仍薄。

---

## (8) 本輪未驗證邊界（誠實）

- 未執行 Godot headless、未跑 PoolContract／Stress／瀏覽器 Playwright。  
- 未實機長測 5+ 分鐘手感與 Web 幀率。  
- 結論以靜態讀碼＋生命週期推理為主；標為「很可能」者需實機確認。

---

## (9) 最終一句

R4 P0 **有把三根支柱從零拉到「看得見的骨架」**，且 token／武器 spatial／爆炸傷解耦等紅線主幹仍在；但 **精英可被 cap 靜默跳過、商店失敗無感卡死、180s 店與 Boss 撞車、敵彈／餘燼 cap 吞效果、BalanceMock 不能當平衡證明**——在宣稱「P0 收尾」之前，這些是對抗性審查下仍會擋發布品質的實打實問題。
