# Crackveil Vanguard — 對抗性稽核 R11（手感重構）

**審查者**：資深遊戲設計師＋Godot 4 技術總監（對抗式；只審不改）  
**審查對象**：R11 手感重構 `5e334f7` ＋熱修 `a9879de`  
**對照**：`docs/CODEX_RESPONSE_R11.md`、HEAD `a9879de`、歷輪紅線（`GROK_REVIEW_R2`～`R10`）  
**方法**：靜態讀碼（squad 池／武器／projectile／visual／BalanceMock／回歸）；權重 Monte Carlo 輔助；**本輪未重跑 headless**  
**日期**：2026-07-10  

---

## 執行摘要

| 面向 | 判定 |
|------|------|
| 隊長三武器旗艦定位 | **成立**（loadout 碼對齊；開局 DPS 重心在隊長） |
| 升級池被三武器擠爆、招募永遠選不到 | **部分成立／未達「永遠選不到」**（招募約 42% 出現；隊長卡面約 56% 權重，主觀「滿屏隊長卡」成立） |
| 三把全進化後中後期無威脅 | **中風險未證偽**（紙面 DPS 強；BalanceMock 不能當威脅證明） |
| BalanceMock `min_hp=0.154@213s` 可信 | **不可信作為平衡真理**（硬 clamp 不死、boss HP 與真實不一致、扁平池） |
| Boomerang 來回路徑命中表 | **主幹成立**（`spawn_token` 正確；返場二次命中需 rebound／evo） |
| Homing 150 敵重取／效能 | **成立**（空間索引＋0.1s 節流；非每幀全掃） |
| 新武器質變／進化進池 | **成立**（`squad_manager`＋`weapon_data`＋R7 回歸有掛） |
| 程序動畫效能 | **成立**（sin 量級可忽略；Stress 宣稱可對齊） |
| 受擊 squash × 白閃衝突 | **無材質衝突**（scale vs modulate 分屬） |
| 視覺放大／bob 與判定錯位 | **成立為體驗風險 P1**（放大＋bob；判定未跟） |
| 同 seed 決定性 | **主幹大致成立**；homing 平手距離有桶序依賴（預存灰區） |
| 歷輪紅線 | **未見破線**（spawn_token／pool／group 掃敵／cap） |
| **R11 總判定** | **軟 Go／可進實玩驗收**；硬 Go 前需修文案謊稱、evo pierce 雙加、並用真實 Arena 取代 BalanceMock 話術 |

**一句話**：R11 把「隊長旗艦＋兩把新武器＋會動的實體」主幹接上了，且效能紅線沒炸；但升級池主觀被隊長卡佔領、BalanceMock 數字是自嗨曲線、迴旋鏢／剃界盾輪文案超賣、以及 evo pierce 雙重套用是新引入的可修 bug。

狀態標籤：

- **成立**／**部分成立**／**未達**／**新 bug**／**紅線違規**／**預存灰區**／**不可信**

優先級：

| 等級 | 意義 |
|------|------|
| **P0** | 正確性謊稱、破 cap、軟鎖、命中表契約 |
| **P1** | 池健康、平衡可信度、視覺誤導、進化數值雙加 |
| **P2** | 文案精度、體感調校、Mock 工具債 |

---

## (0) 變更盤點

| 項目 | 實況 |
|------|------|
| R11 主 commit | `5e334f7`（48 files，+1370 / −145 含音訊） |
| 熱修 | `a9879de`（字型 Latin-1 `±/°/×`，版本 `0.11.0-r11`） |
| HEAD | `a9879de` |
| 對照文檔 | `docs/CODEX_RESPONSE_R11.md` |

### Loadout 定案 vs 碼

| 角色 | 宣稱 | 碼 |
|------|------|-----|
| `rift_captain` | 裂線＋星環＋雷鏈 | `resources/heroes/rift_captain.tres:18` |
| `orbit_guard` | 裂盾迴旋鏢 | `orbit_guard.tres:18` |
| `arc_scout` | 追蹤飛彈 | `arc_scout.tres:18` |
| 開局小隊 | 隊長＋護衛＋斥候 | `default_squad.tres:13` |
| catalog | 三旗艦 starting；六把 available | `weapon_catalog.tres:13-14` |

---

## (1) 隊長三武器平衡與升級池健康

### 1.1 池構建與權重（擠爆？招募選不到？）

#### 證據

| 機制 | 位置 | 行為 |
|------|------|------|
| 池入口 | `game_manager.gd:535-549` | `PLAYER_UPGRADE_POOL` → `squad_manager.build_upgrade_pool` → filter → 加權抽 3 |
| 每把武器三數值卡 | `squad_manager.gd:149-199` | damage / cooldown / projectiles（有 cooldown 才加 cd） |
| 隊長權重 | `:19-20,255-259` | leader `1.35`、follower `0.82`；進化後數值 `×0.35` |
| 質變權重 | `:219` | leader `4`、follower `3` |
| 進化權重 | `:242` | leader `9`、follower `8` |
| 招募 | `:127-146` | weight `4`；已在隊／死過／滿員剔除 |
| 選項數 | `game_manager.gd:811-817` | 預設 3（金饑契約可砍到 2） |

**開局卡片盤點**（3 人起始小隊、5 把武器）：

| 來源 | 卡數 | 權重合計（約） |
|------|-----:|---------------:|
| 隊長三武器數值 | 9 | 12.15 |
| 隊長質變（fork／resonance／overload／magnetic） | 4 | 16.0 |
| 護衛＋斥候數值 | 6 | 4.92 |
| 護衛／斥候質變 | 2 | 6.0 |
| 招募（pulse／mender） | 2 | 8.0 |
| 個人（移速／HP／磁吸） | 3 | 3.0 |
| **合計** | **26** | **≈50.1** |

權重 Monte Carlo（20000 次、模擬 `_pick_weighted_choices` 不放回 3 抽）：

| 指標 | 結果 |
|------|------|
| 隊長武器相關權重占比 | **≈56%** |
| 單次升級「至少一張招募」 | **≈42%** |
| 單次升級「至少一張隊員武器」 | **≈55%** |
| 三張全是隊長武器卡 | **≈15%** |

#### 結論

| ID | 命題 | 判定 | 說明 |
|----|------|------|------|
| R11-1.1a | 隊長武器卡×3 擠爆池 | **部分成立 P1** | 權重與卡面數量都偏隊長；玩家主觀「滿屏隊長升級」合理 |
| R11-1.1b | 招募永遠選不到 | **未達** | 招募單卡 weight=4 高於隊長單張數值 1.35；≈42% 出現率不是「永遠」 |
| R11-1.1c | 隊員升級永遠選不到 | **未達** | 約 55% 會看到至少一張 follower 武器卡；但單張權重低，**強化節奏偏慢** |
| R11-1.1d | 進化後數值降權 | **成立** | `×0.35` 有接上；晚局 follower／招募相對變好看 |

**最小重現（池偏斜）**：

1. 開局進 Arena，打到第一次升級。  
2. 記錄 10 次升級的 3 選項來源（隊長武器／隊員武器／招募／個人）。  
3. 預期：隊長武器卡佔多數；招募**不是**零。

**設計後果**：不是「鎖死招募」，而是**成長曲線自增幅隊長**——與「旗艦隊長」一致，但會讓護衛／斥候的 boomerang／missile 質變更難湊到進化門檻（尤其 `required_damage_level=3` 還要佔隊長槽）。

---

### 1.2 三把全進化後的 DPS 與中後期威脅

#### 開局理論輸出（粗算，單目標理想）

| 武器 | 粗 DPS 算法 | 約值 |
|------|-------------|-----:|
| `riftline_emitter` | 12 / 0.86 | ~14.0 |
| `orbit_blades` | 8×2 / 0.36（命中間隔；多刃重疊另計） | ~44+（近身） |
| `arc_chain` | 16×鏈（falloff）/ 1.75 | ~20–35（群） |
| 護衛 boomerang | 13 / 1.36（單程；pierce=3） | ~10–25 |
| 斥候 missiles | 9×2 / 1.08 | ~16.7 |

開局近身時**星環主導**；隊長三把合計遠高於單一隊員武器——與 `leader_dps_share=0.643` 方向一致，但 mock 起手就寫死 `leader_dps=104 / total=132`（`balance_mock_run.gd:32-34`），不是量測值。

#### 全進化後

| 進化 | 效果摘要 | 位置 |
|------|----------|------|
| `evo_rift_fan` | 彈數上抬、扇形 fork | `weapon_data.gd:232-235` |
| `evo_shear_halo` | 半徑＋、間隔縮、slow | `:236-240` + `orbit_projectile.gd:142-145` |
| `evo_overload_nova` | 鏈半徑／新星 | `:244-247` |
| （隊員）`evo_razor_bulwark` | 彈數＋、pierce＋、返場 | `:248-254` |
| （隊員）`evo_hunter_swarm` | 彈數+2、pierce≥1、cd×0.82 | `:255-260` |

**判定**：**中風險、未達「已證明碾壓」也未達「已證明健康」**。

- 隊長三進化齊全時，近身清場＋鏈清群＋裂線補線會非常強。  
- 敵人側有：HP +16–24%、time scale 自 60s 起 `+0.055/min`（`enemy_spawner.gd:300-307`）、boss 1950、boss 期間 spawn×0.45（`:151-152`）。  
- **沒有**真實 Arena 插樁對「全進化 180s+」的威脅曲線；僅靠 mock 不能裁決。

**最小重現（需實機）**：seed 固定 → 強制餵滿隊長三進化 → 觀察 150–210s 精英／boss 是否「站不住」或「秒清」。

---

### 1.3 BalanceMock 宣稱 `min_hp=0.154@213s` 可信嗎？

#### 證據（致命）

| 問題 | 位置 | 說明 |
|------|------|------|
| HP 硬下限 1.0 | `balance_mock_run.gd:132` | `hp = clamp(..., 1.0, max_hp)` → **永遠不死** |
| boss HP 失真 | `:37` vs `enemy_spawner.gd:207` | mock `3600`；真實 boss **`1950`** |
| 扁平升級池 | `:187-218` | 單一 `weapon_damage`，**未**模擬「每武器×成員」膨脹 |
| DPS 起手寫死 | `:32-34` | `leader_dps=104` 非戰鬥量測 |
| 通過條件自嗨 | `:164` | `min_hp_before_90 < 0.82` 且 `leader_share >= 0.55` 等 |
| 歷輪已定性 | `CODEX_RESPONSE_R5/R6`、`GROK_REVIEW` 系列 | Mock **不是** Arena 平衡真理 |

`leader_dps_share=0.643` 只是 mock 內部累加比值，與 WeaponSmoke 的 trigger count（`orbit_blades=27` 遠高於其他）方向一致，但**不能**外推為真實 DPS 占比。

#### 結論

| ID | 命題 | 判定 |
|----|------|------|
| R11-1.3a | `min_hp=0.154@213s` 可信 | **不可信**（工具債 P1；文檔當作驗證結果過強） |
| R11-1.3b | `leader_dps_share=0.643` 可信 | **方向可採、數值不可採** |
| R11-1.3c | 把 Mock PASS 當平衡通過 | **紅線邊緣／設計流程違規傾向**（歷輪已警告） |

**最小重現**：讀 `balance_mock_run.gd:132`；把 `incoming` 調成極大仍 `hp≥1`；對照 `enemy_spawner.gd:207` 的 1950。

---

## (2) 新武器實作品質

### 2.1 Boomerang（裂盾迴旋鏢）命中表

#### 證據

| 項目 | 位置 | 行為 |
|------|------|------|
| 發射 | `boomerang_weapon.gd:20-36` | `motion_mode=boomerang`，走共用 `Projectile` 池 |
| 去程 | `projectile.gd:207-221` | 飛到 `range * return_ratio(0.52)` 後返場 |
| 命中鍵 | `:237-241,273-276` | `_hit_key_for` → `get_hit_token()`（spawn_token） |
| 返場清表 | `:208-211` | **僅** `boomerang_rebound_level>0` 或 `evo_razor_bulwark_level>0` 時 `hit_bodies.clear()` |
| 返場傷害 | `:253-256` | 返場倍率 `1 + 0.18*rebound + 0.22*evo` |
| Pierce 不重置 | `:246-250` | 清表後 **不** 回補 pierce |

#### 判定表

| ID | 命題 | 判定 | 說明 |
|----|------|------|------|
| R11-2.1a | 去程／回程各算一次 | **有條件成立** | 基礎裝：同目標**不**二次；有 rebound／evo 才清表可再打 |
| R11-2.1b | spawn_token 用對 | **成立** | 與 R2 契約一致；非 instance_id 裸用（有 token 時） |
| R11-2.1c | 基礎描述「出手與返場都能切開」 | **未達／文案謊稱 P1** | `rift_shield_boomerang.tres:10` 暗示雙程有效；無 rebound 時同目標回程被 hit 表擋 |
| R11-2.1d | 清表但不回 pierce | **設計灰區 P2** | 去程打滿 pierce 會在返場前就 release，rebound 形同虛設 |

**最小重現（基礎無二次）**：

1. 單敵、無升級、`pierce=3`。  
2. 去程命中後 HP 下降；同一 spawn_token 敵人在回程穿過。  
3. 預期：`hit_bodies` 仍含該 token → 回程不傷（直到取得 `boomerang_rebound`）。

**最小重現（rebound 二次）**：

1. `apply_data_upgrade("boomerang_rebound")`。  
2. 返場瞬間 `hit_bodies.clear()`（`:210-211`）。  
3. 同敵可再吃一次（pierce 尚餘時）。

---

### 2.2 Homing missile（追蹤裂隙飛彈）

#### 證據

| 項目 | 位置 | 行為 |
|------|------|------|
| 開火鎖定 | `homing_missile_weapon.gd:12-36,43-57` | 最近敵；寫入 `homing_target` |
| 飛行重取 | `projectile.gd:185-204` | 無效或 timer≤0 時重取；間隔 **0.1s**（guidance>0 → **0.07s**） |
| 搜敵 | `:194` + `entity_factory.gd:474-477` | `EnemySpatialIndex.find_nearest` |
| Token 防屍 | `projectile.gd:279-287` | `homing_target_token` 對 `get_hit_token()` |
| 轉向 | `:201-204` | `homing_turn_rate * delta` 夾角 |

#### 150 敵效能

- **不是**每幀 `get_nodes_in_group("enemies")`。  
- 空間格 `cell_size=128`；`retarget_radius≈620` → 約 11×11 cell 桶掃（`enemy_spatial_index.gd:59-80`）。  
- 主動飛彈數有限（cd 1.08、雙發；進化後更多但仍遠低於敵數）。  
- Stress 宣稱 `enemy_group_scans=0`、`queries_per_frame≈3.17` 與架構一致（本輪未重跑）。

| ID | 命題 | 判定 |
|----|------|------|
| R11-2.2a | 每幀找最近？ | **未達（好事）** — 0.1s／0.07s 節流 |
| R11-2.2b | 走 spatial index？ | **成立** |
| R11-2.2c | 150 敵可接受 | **成立**（架構面；Stress 數字僅作旁證） |
| R11-2.2d | guidance Lv2「短距再鎖定」 | **部分成立／文案膨脹 P2** — 僅加快重取＋加 range×1.12（`homing_missile_weapon.gd:52-53`），無獨立「再鎖定」狀態機 |

---

### 2.3 質變／進化是否真接進池

| 項目 | 證據 | 判定 |
|------|------|------|
| 質變定義 | `squad_manager.gd:56-69` `boomerang_rebound`／`missile_guidance` | **成立** |
| 進化定義 | `weapon_data.gd:114-131` `evo_razor_bulwark`／`evo_hunter_swarm` | **成立** |
| max level | `:67-68,73-74` rebound/guidance=2；evo=1 | **成立** |
| 門檻 | `can_offer_evolution`：run_level≥7、質變滿、damage≥3 | **成立** |
| 回歸 | `r7_regression_test.gd:340-341` 含兩把新 evo | **成立** |
| R11 回歸 | `r11_regression_test.gd` **只**測 loadout＋能扣血＋bob | **未覆蓋** 質變／進化進池（缺口 P2） |

| ID | 命題 | 判定 |
|----|------|------|
| R11-2.3 | 兩把新武器質變／進化進池 | **成立** |

---

### 2.4 新引入數值 bug：evo pierce／turn 雙加

| ID | 問題 | 判定 | 證據 |
|----|------|------|------|
| R11-2.4a | `evo_razor_bulwark` pierce **雙加** | **新 bug P1** | `weapon_data.gd:251` `pierce += 2` **且** `boomerang_weapon.gd:49-50` 開火再 `+2` → 實際 **+4** |
| R11-2.4b | `evo_hunter_swarm` turn_rate 疊加 | **新 bug／灰區 P2** | data `:259` `+2.2` 後 fire 路徑 `:56-57` 再 `+1.4` |
| R11-2.4c | evo 文案「附加短暫易傷」 | **未達 P1** | `weapon_data.gd:117` 描述易傷；`projectile.gd` 命中**無** `apply_status_effect("vulnerable")`（易傷只見 `orbit_projectile.gd:142-143`） |

**最小重現（pierce 雙加）**：

1. 進化 `evo_razor_bulwark`。  
2. 讀 runtime `data.pierce`（已 +2）與 `_projectile_stats_for_fire()["pierce"]`（再 +2）。  
3. 差值應為 2，實為 4。

---

## (3) 程序動畫

### 3.1 150 敵 sin／flip 效能

| 路徑 | 位置 | 每敵每幀 |
|------|------|----------|
| 敵人 | `enemy.gd:801-828` | 2×`sin`、flip、scale、position |
| 英雄 | `player_visual.gd:103-135` | 同類 |

**判定**：**成立（可接受）**。150 × 幾個 sin 相對 physics／spatial query 可忽略。R11 Stress 宣稱 avg≈6.9ms 與 R10 同量級；動畫不是瓶頸候選。

R11 回歸只證明 transform **有變**（`r11_regression_test.gd:143-179`），不證明效能。

---

### 3.2 受擊 squash × hit 白閃

| 通道 | 位置 | 屬性 |
|------|------|------|
| 白閃 | `enemy.gd:518,791-798` | `sprite.modulate` lerp 白→body |
| Squash | `:519,807-824` | `sprite.scale` |
| 英雄 | `hero.gd:403-404` + `player_visual.gd:48-49,118-131` | squash；受擊另有 visual modulate 閃 |

`_set_sprite_modulate` 在 `hit_flash_timer>0` 時不覆寫（`:733-735`）— windup 黃／橙與白閃互斥合理。

| ID | 命題 | 判定 |
|----|------|------|
| R11-3.2 | squash 與白閃材質衝突 | **未成立（無衝突）** — 皆 modulate／scale，**無** per-entity 新 ShaderMaterial |

---

### 3.3 碰撞視覺錯位／放大誤導

| 實體 | 視覺 | 判定 | 位置 |
|------|------|------|------|
| 隊長 | `sprite_scale=1.48` | `hit_radius=13` 不變 | `rift_captain.tres` |
| 護衛／斥候 | 1.42／1.40 | hit_radius 12／11 | 各 hero tres |
| 敵人 normal | scale 1.30 | radius 13 | `enemy_spawner.gd:4-16` |
| Boss | scale 2.08 | radius 34 | `:207-216` |
| Bob | 敵最高 ~3.2px Y | 碰撞在 CharacterBody 原點 | `enemy.gd:815-822` |
| 舊武器半徑 | 宣稱不變 | riftline 4.5、orbit 10.5 維持 | tres；視覺 sprite_scale↑ |

近戰接觸：`enemy.gd:350-353` 用 **邏輯 radius**，不用 sprite 外緣。

| ID | 命題 | 判定 |
|----|------|------|
| R11-3.3a | 視覺放大判定不變 | **成立（實作）** |
| R11-3.3b | 誤導度 | **成立為體驗風險 P1** — 大精靈「看起來打到」／「看起來該被打到」與判定差一圈 |
| R11-3.3c | bob 加劇錯位 | **部分成立 P2** — 振幅小（2–3.6px）但滿場高速敵可感知 |

**最小重現**：開 debug 畫 collision circle（或暫時顯示 shape）；對比 boss scale 2.08 精靈外緣 vs radius 34。

---

## (4) 決定性

### 4.1 武器移轉後同 seed 回放

| 因子 | 評估 |
|------|------|
| 開局 seed | `arena.gd` `_apply_run_seed` → `seed(selected_seed)` |
| Loadout 固定 | tres 決定，無隨機武器 roll |
| 武器 AI | 最近敵／固定 cd，無額外 rand |
| 掉落 scatter | `randf_range`（`enemy.gd`／`entity_factory`）— **預存** 非決定性源（影響 XP 路徑→升級時點） |
| 升級選項 | `randf` 加權 — 同 seed 同操作序列應可重放 |

武器從護衛／斥候「移轉」本身**不**引入新 RNG；旗艦三武器掛隊長後，最近敵查詢次數↑，但在決定性世界狀態下仍是純函數。

| ID | 命題 | 判定 |
|----|------|------|
| R11-4.1 | 武器移轉後同 seed 回放仍成立 | **主幹成立**（相對 R10；掉落／VFX 預存灰區仍在） |

---

### 4.2 Homing 目標選擇決定性

`EnemySpatialIndex.find_nearest`（`:59-80`）：

- 掃描順序：cell x 遞增 → y 遞增 → bucket 陣列序。  
- 比較：`distance_squared < best`（**嚴格小於**）。  
- 等距時：**先掃到的贏**（依賴 register／換格後的 bucket 序）。

同 seed 下若物理與生成序穩定，bucket 序通常穩定 → **實務可重放**。  
等距平手是**預存灰區**（所有 `find_nearest` 共用），非 homing 獨有；homing 因 0.1s 重取會**放大**平手窗口的可見性。

| ID | 命題 | 判定 |
|----|------|------|
| R11-4.2 | Homing 目標選擇決定性 | **部分成立** — 有序掃描＋token；等距平手無 tie-break |

**最小重現（平手理論）**：兩敵與飛彈距離完全相同 → 勝者 = 空間索引遍歷先者，非 entity_id 排序。

---

## (5) 歷輪紅線快檢＋新引入 bug

### 5.1 紅線快檢

| 紅線 | 判定 | 證據 |
|------|------|------|
| spawn_token 命中表 | **未違規** | `projectile.gd:273-276`；敵 `get_hit_token`→`spawn_token`（`enemy.gd:214-215`） |
| 禁止 enemies group 掃瞄戰鬥熱路徑 | **未違規** | 新武器皆 `EntityFactory.find_nearest_enemy`；R11 回歸要求 `enemy_group_scans=0` |
| Pool double-release guard | **未違規** | `node_pool.gd` 仍在；新武器共用 projectile 池 |
| Cap（敵 150／fork／敵彈） | **未違規** | 未見放寬；boomerang／missile 走一般 projectile |
| 視覺放大不偷改判定（舊武器） | **成立** | riftline／orbit `projectile_radius` 維持；doc 與 tres 一致 |
| BalanceMock 當真理 | **流程風險** | R11 文檔仍大書 mock 數字（歷輪已禁當真理） |

### 5.2 新引入／本輪暴露問題清單

| ID | 嚴重度 | 判定 | 摘要 | 位置 |
|----|--------|------|------|------|
| N1 | P1 | **新 bug** | evo_razor pierce 雙加（+4 而非 +2） | `weapon_data.gd:251` + `boomerang_weapon.gd:49-50` |
| N2 | P1 | **未達** | evo 文案「短暫易傷」未實作 | `weapon_data.gd:117` vs projectile 命中 |
| N3 | P1 | **未達** | 基礎 boomerang 文案暗示雙程切割；無 rebound 同目標不返傷 | `rift_shield_boomerang.tres:10` + `projectile.gd:210-211` |
| N4 | P1 | **不可信** | BalanceMock min_hp／leader share 話術過強 | `balance_mock_run.gd` |
| N5 | P1 | **部分成立** | 升級池隊長卡權重≈56%，成長自增幅 | `squad_manager.gd` |
| N6 | P1 | **體驗風險** | 精靈放大＋bob vs 判定錯位 | hero／enemy tres + visual |
| N7 | P2 | **新 bug／灰區** | hunter evo turn_rate 雙疊 | `weapon_data.gd:259` + `homing_missile_weapon.gd:56-57` |
| N8 | P2 | **文案膨脹** | missile guidance Lv2「再鎖定」僅調參 | `squad_manager.gd:66-68` |
| N9 | P2 | **回歸缺口** | R11 不測池權重／rebound 二次／進化 | `r11_regression_test.gd` |
| N10 | P2 | **音效密度** | 每殺 `kill_thump`（cd 55ms）+ hit + combo；滿場嘈雜風險 | `enemy.gd:536` + `audio_manager.gd:30` |

### 5.3 逐條總表（任務清單對齊）

| # | 稽核項 | 結論 |
|---|--------|------|
| 1a | 隊長三武器卡擠爆池 | **部分成立** — 權重≈56%；非完全鎖死招募 |
| 1b | 招募／隊員升級永遠選不到 | **未達** — 招募≈42%、隊員武器≈55% 可見 |
| 1c | 三進化後中後期無威脅 | **未證偽／中風險** — 需真實 Arena |
| 1d | BalanceMock min_hp 0.154@213s | **不可信** |
| 2a | Boomerang 來回命中表 | **有條件成立**；token **成立** |
| 2b | Homing 重取／效能 | **成立**（空間索引＋節流） |
| 2c | 質變／進化進池 | **成立** |
| 3a | 150 敵 sin／flip 效能 | **成立** |
| 3b | squash×白閃衝突 | **無衝突** |
| 3c | 視覺／判定錯位 | **成立為 P1 風險** |
| 4a | 武器移轉 seed 回放 | **主幹成立** |
| 4b | Homing 決定性 | **部分成立**（等距平手灰區） |
| 5a | 歷輪紅線 | **未見紅線違規** |
| 5b | 新 bug | **N1 pierce 雙加** 等（上表） |

---

## (6) 對 CODEX_RESPONSE_R11 宣稱的採信度

| 宣稱 | 採信 |
|------|------|
| Loadout 定案 | **高** — tres 一致 |
| 新武器數值表 | **高** — tres 一致 |
| 升級權重 1.35／0.82／進化 35% | **高** — 碼一致 |
| 視覺放大判定不變 | **高** |
| 開場密度／boss 45%／time scale 60s | **高** — spawner 一致 |
| 全 debug 13 場景 PASS | **中** — 本輪未重跑；回歸碼存在 |
| Stress 6.9ms／group_scans=0 | **中** — 架構支持；數字未複測 |
| BalanceMock min_hp／leader_share | **低** — 工具本質限制 |
| 「返場可二次命中」作為基礎武器印象 | **低** — 需 rebound |

---

## (7) 總判定與建議方向（只審不改）

**總判定**：**軟 Go／小圈實玩驗收**。R11 手感目標（旗艦隊長、新武器、會動的場、爽感層）**主幹落地**；效能與紅線**未炸**。

硬 Go 前建議（供下一輪，**本輪不實作**）：

1. **P1** 修 evo_razor pierce 雙加；evo 易傷要嘛做要嘛改文案。  
2. **P1** 校正 boomerang 基礎描述，或基礎就 clear hit 表（並想清楚 pierce 經濟）。  
3. **P1** 升級池：對 leader 武器數值卡做 soft cap／合併展示，或提高 follower 權重下限，避免主觀三選全隊長。  
4. **P1** 平衡改以 Arena 插樁（真實 HP、真實 boss 1950、真實升級池）取代 Mock 數字上報。  
5. **P2** R11 回歸補：rebound 二次命中、進化進池、可選 seed 回放。  
6. **P2** 評估精靈 scale 與 hit 顯示輔助（或微調 bob 振幅）。

---

## 附錄 A — 關鍵檔案索引

| 主題 | 路徑 |
|------|------|
| 升級池 | `scripts/heroes/squad_manager.gd` |
| 升級抽取 | `scripts/autoload/game_manager.gd` |
| Boomerang 武器 | `scripts/weapons/boomerang_weapon.gd` |
| Homing 武器 | `scripts/weapons/homing_missile_weapon.gd` |
| 運動／命中 | `scripts/projectiles/projectile.gd` |
| 武器資料／進化 | `scripts/resources/weapon_data.gd` |
| 空間索引 | `scripts/services/enemy_spatial_index.gd` |
| 英雄視覺 | `scripts/player/player_visual.gd` |
| 敵人動畫／白閃 | `scripts/enemies/enemy.gd` |
| 刷怪／HP／boss | `scripts/enemies/enemy_spawner.gd` |
| BalanceMock | `scripts/debug/balance_mock_run.gd` |
| R11 回歸 | `scripts/debug/r11_regression_test.gd` |

## 附錄 B — 開局池權重速算

```
leader_numeric   = 9 × 1.35 = 12.15
leader_qual      = 4 × 4.00 = 16.00
follower_numeric = 6 × 0.82 =  4.92
follower_qual    = 2 × 3.00 =  6.00
recruit          = 2 × 4.00 =  8.00
personal         = 3 × 1.00 =  3.00
--------------------------------
total                        ≈ 50.07
captain_share                ≈ 56.2%
```

---

*本報告為對抗性靜態稽核，不修改遊戲碼、不 commit、不 push。*
