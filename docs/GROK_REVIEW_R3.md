# Crackveil Vanguard / Rift Survivors — 對抗式驗證審查 R3

**審查者**：Grok（對抗式驗證，不採信宣稱）  
**對照文件**：`docs/GROK_REVIEW_R1.md`、`docs/GROK_REVIEW_R2.md`、`docs/CODEX_RESPONSE_R2.md`、`docs/REVIEW.md`  
**驗證對象**：第五階段 sprite 接入、`SpriteLoader`、VFX/掉落 cap、R2 pooling 契約是否被破壞、`StressTest` 誠實度  
**方法**：靜態讀碼 + 生命週期/契約推理（本輪**未**重跑 Godot headless / Profiler）  
**日期**：2026-07-09  

---

## 執行摘要

| 面向 | 判定 |
|------|------|
| R2 P0-1 `spawn_token` 命中表 | **維持完整** |
| R2 P0-2 `NodePool._in_pool` double-release | **維持完整** |
| 第五階段 sprite 資料驅動 | **大致成立**（HeroData / WeaponData / 敵人 config / pickup 場景） |
| VFX cap 不破壞戰鬥結算（傷害本體） | **傷害數字 / 死亡特效 / 雷弧：視覺可丟；爆炸 cap 會連帶丟傷害** |
| 壓測仍為真實 150 敵 + 100 彈負載 | **成立**（相對 R1 假壓測已誠實） |
| `STRESS_PERF_BELOW_60` | **誠實**（以 min fps 判定，最嚴格） |
| 第五階段新 P0 | **無** |
| 平均 106fps 宣稱 | **程式路徑支持可信；本輪未重測牆鐘，數字本身不複驗** |

**總判定**：第五階段**沒有破壞** R2 修好的 pooling 契約；sprite 接入方向正確且多為資料驅動；VFX budget 對平均幀率的改善方向合理。但 `docs/REVIEW.md` 對 cap 行為有**過度宣稱**（寫「復用最舊」，實作是 **return null 跳過**），且 **爆炸 / 掉落 cap 會靜默丟玩法結果**（爆炸傷害、XP/金幣）。壓測標記 `STRESS_PERF_BELOW_60=true` 與程式邏輯一致。

優先級定義同前：

| 等級 | 意義 |
|------|------|
| **P0** | 正確性缺陷或目標負載下必炸 / 可重現髒狀態 |
| **P1** | 明顯回歸、壓測誤導、擴充地雷、會丟玩法結果的 cap |
| **P2** | 品質、狀態重置殘留、文件誇大 |

狀態標籤：

- **R1 已解決** / **R2 已解決** / **R2 維持** / **R2 餘債** / **第五階段新問題**

---

## (1) Sprite 掛載正確性

### 1.1 資料驅動（大致成立）

| 來源 | 路徑欄位 | 消費端 |
|------|----------|--------|
| `HeroData.sprite_path` / `sprite_scale` | `.tres` 已填（captain/guardian/scout 等） | `hero.gd` → `player_visual.configure_visual` |
| `WeaponData.projectile/orbit/explosion/lightning_sprite_path` | 各武器 `.tres` 已填 | `to_projectile_stats` / `to_effect_stats` → 彈/刃/爆/雷 |
| 敵人 `config.sprite_path` | `enemy_spawner.gd` / `stress_test.gd` | `enemy.setup` |
| Pickup 場景 export | `XPGem.tscn` / `CoinPickup.tscn` | `pickup.gd` |

**不是硬寫死在 render 迴圈裡**，而是 path 進 stats/config 再 `SpriteLoader.get_texture`。這點 Codex 宣稱成立。

仍有**合理 fallback / 硬編碼例外**（不算破壞資料驅動，但要標清）：

- `projectile.gd` 預設 `proj_bullet.png`；`orbit_projectile.gd` 預設 `proj_blade.png`。
- `enemy.gd` 有 `_default_sprite_path_for_type`。
- `death_burst.gd` **直接硬寫** `res://assets/sprites/fx_explosion.png`，未走 config（P2）。
- `SpriteLoader` / 消費端：path 為 `""` 時回 `null` 並 `sprite.visible = false`（隱形，不 crash）。

**注意（P2）**：`Dictionary.get("projectile_sprite_path", default)` 在 key **存在但值為空字串**時**不會**用 default。目前 `.tres` 都有填，故實戰 OK；未來若漏填 export，投射物會隱形而非 fallback。

### 1.2 `SpriteLoader` 快取與 fallback

```gdscript
# scripts/services/sprite_loader.gd
static var texture_cache: Dictionary = {}
```

| 檢查點 | 判定 |
|--------|------|
| 快取 key 為 path | 正確 |
| 命中直接回傳 | 正確 |
| `ResourceLoader.exists` → `load` as Texture2D | 正確 |
| 否則 `Image.load` → `ImageTexture` | 合理 fallback（無 `.import` 時） |
| 失敗 `push_warning` + `null` | 正確，不塞髒 cache |
| 永久 static 快取 | **非洩漏**（路徑集合固定在 assets）；無 clear API，長跑可接受 |

**無發現**「錯誤 texture 被 cache 成成功」或 path 無限增長類洩漏。

`fit_sprite`：以 max(w,h) 對 `target_diameter` 縮放，`centered=true`。acquire 時多數路徑會重跑 `_apply_sprite` / `fit_sprite`，scale 會重算。

### 1.3 池化節點 sprite / modulate / scale 重置

| 節點 | acquire/reset 是否重套 sprite | modulate | scale | 殘留風險 |
|------|-------------------------------|----------|-------|----------|
| `enemy` | `setup` → `_apply_sprite` | 設為 `body_color` | `fit_sprite` | **`sprite.rotation` 不重置**（移動時寫入，死亡角度可殘留到下一隻，直到再移動） |
| `projectile` | `setup` → `_apply_sprite` | `projectile_color` | `fit_sprite` | 低（rotation 用方向重設） |
| `orbit_projectile` | `configure_orbit` → `_apply_sprite` | stats color | `fit_sprite` | 低 |
| `explosion_area` | `setup` → `_apply_sprite` | color + alpha | 每幀 fit | 低 |
| `death_burst` | `setup` → `_apply_sprite` | color + alpha | 每幀 fit | **`sprite.rotation` 累加且 setup 不歸零** |
| `lightning_arc` | `_sync_segments` | 每幀 alpha | 依段長重算 | 多餘 segment `visible=false`，OK |
| `damage_number` | Label text/color 重置 | setup 時 alpha=1 | N/A | 低 |
| `pickup` | `setup` → `_apply_sprite` | 預設白 | 依 value fit | `bob_phase` release 有清 |
| `hero` visual | 非池化；受傷 flash 結束回 WHITE | `reset_for_run` 設 WHITE | 重 configure | **無池化 modulate 殘留問題** |

**受傷閃爍**：只在 `hero._update_flash` 改 `visual.modulate`；敵人**沒有**受擊 modulate 閃爍，故**不存在**「敵人 flash 殘留到 pool 復用者」這條 R3 懷疑路徑。

**結論**：sprite 掛載與主流 reset **正確**；新的是 **rotation 殘留**（P2 視覺），不是 hit-token 級正確性洞。

### 1.4 `_draw()` 熱點

全專案 gameplay 腳本僅剩 `arena_background.gd` 的 `_draw()`。敵人血條改 `Line2D`、傷害字改 `Label`、實體改 `Sprite2D`。此點 Codex 宣稱**成立**。

---

## (2) VFX cap 與玩法/正確性

### 2.1 實際 cap 常數（`entity_factory.gd`）

| 類型 | Cap | 預熱 | 達 cap 行為（程式實況） |
|------|-----|------|------------------------|
| damage_number | 64 | 80 | 先 merge；失敗則 **return null（跳過顯示）** |
| death_burst | 20 | 28 | **return null** |
| explosion | 36 | 80 | **return null** |
| lightning_arc | 32 | 80 | **return null** |
| xp_gem / coin | 180 | 220 | **return null** |

### 2.2 與 REVIEW 宣稱的落差（重要）

`docs/REVIEW.md` 用語接近「合併或跳過 / 特效 cap」，並在摘要語感上像有 budget 管理；但**沒有任何「復用最舊節點、重置後改位置」的實作**。

實作一律是：

```gdscript
if get_pool_live_count("death_burst") >= DEATH_BURST_CAP:
    return null
```

**不是** recycle oldest。此為**文件誇大 / 行為誤解**（P2 文件；對 death_burst/lightning 只影響視覺）。

### 2.3 傷害數字合併 — 會不會算錯傷害？

結算順序（`enemy.take_damage` / `hero.take_damage`）：

1. **先改 HP**  
2. 再 `EntityFactory.spawn_damage_number(...)`

因此：

- merge 失敗或 cap 跳過 → **只影響浮字，不影響傷害**。  
- merge 成功 → `numeric_total += value`，顯示 `int(round(total))`，**數字加總正確**，不是隨機錯值。

**視覺/可讀性問題（非結算）**：

| 問題 | 等級 | 說明 |
|------|------|------|
| 近距離 0.24s 合併 | 設計取捨 | 群傷可讀性↑、單體 hit 反饋↓ |
| 合併**不區分**友傷/敵傷顏色 | P2 | `can_merge` 只看距離與 age，`merge_value` 覆寫 color；英雄受傷紅字可能被附近敵傷奶油色吞掉 |
| cap 時 merge 半徑 ×2.4 | P2 | 更遠的無關傷害更易被併進同一浮字，反饋更糊 |
| cap 且無法 merge | OK | 靜默不顯示；DPS 結算仍在 |

**結論**：傷害數字 cap/merge **不會漏結算或顯示錯總和到玩法層**；最多是 feedback 糊掉。非 P0。

### 2.4 特效 cap — 閃爍/錯位？

因**不復用最舊**，也就**沒有**「舊 VFX 瞬間 teleport 到新位置」的錯位閃爍。副作用改為：

- 達 cap 後新特效**直接消失**（缺特效，非錯位）。  
- `death_burst` 自己的 `sprite.rotation` 跨次累加，重用時可能以奇怪角度開場（P2）。

### 2.5 會影響玩法的 cap（P1）

| 路徑 | 影響 |
|------|------|
| `spawn_explosion` 達 cap → null | **爆炸本體與 `_apply_damage` 都不會跑** → 該次範圍傷害整段消失 |
| `spawn_xp_gem` / `spawn_gold_coin` 達 cap → null | **XP/金幣永久遺失**（敵已死，不會補發） |
| `spawn_lightning_arc` 達 cap | 僅視覺；傷害已在 `chain_lightning_weapon` 先結算 |
| `spawn_death_burst` 達 cap | 僅視覺 |

爆炸 cap=36 在目前武器密度下**不易**長期打滿，但是 **API 語意是「soft visual cap」卻套在「含傷害的 gameplay spawn」上**，屬擴充地雷。掉落 180 在 150 敵 + 慢磁吸時較可能咬到。

> 對照 R2 P1「熱路徑 spawn 靜默 null」：第五階段把 cap 又疊一層，**P1 加重**而非解決。

---

## (3) Pooling 契約：R2 是否被第五階段破壞？

### 3.1 P0-1 spawn_token 命中表 — **R2 維持**

仍完整：

- `EntityFactory.spawn_enemy` → `_issue_enemy_spawn_token()` 單調遞增。  
- `enemy.pool_reset` 寫入 `spawn_token`；`get_hit_token()` 回傳之。  
- `projectile._hit_key_for` / `orbit_projectile._hit_key_for` 優先 `get_hit_token()`。  
- `hero` facing cache 仍驗證 `is_active` + token。  
- `pool_contract_test.gd` 仍覆蓋 linear/orbit token 重用可再命中。

第五階段 sprite 改動**未**改回 raw `instance_id` 當命中 key。

### 3.2 P0-2 double-release / `_in_pool` — **R2 維持**

`node_pool.gd` 仍有：

- warm 標記 `_in_pool`  
- acquire 移除並丟棄 free_list 髒 entry  
- release 時已在 pool → `duplicate_release_count` + return  
- foreign pool metadata 拒絕  

`EntityFactory._mark_inactive_for_release` 仍在 deferred release 前同步 `is_active=false`。

### 3.3 第五階段有無引入新的 acquire 未重置？

| 項目 | 判定 |
|------|------|
| hit_bodies / hit_cooldowns | release 仍 clear；token key 仍正確 |
| sprite texture/modulate/scale | 多數 setup 重套 |
| enemy/death_burst rotation | **新視覺殘留（P2）**，不影響 hit 契約 |
| damage_number age/text | release/setup 重置完整 |
| active_damage_numbers 追蹤 | release 時 erase；compact 去無效引用 |

**結論：R2 pooling 正確性契約仍完整；第五階段未繞過。**

### 3.4 R2 其他項狀態快照

| R2 項 | R3 狀態 |
|-------|---------|
| orbit_weapon 不 append null、耗盡保持 dirty | **維持**（`orbit_weapon.gd`） |
| facing cache token | **維持** |
| 壓測弱負載 / 寫死 group scan | **R2 已修，本輪維持真實計數** |
| `get_enemies_in_radius` 配新 Array | **R2 餘債仍在**（P1/P2 性能） |
| 熱路徑 soft null spawn | **仍在，且 cap 擴大影響面** |

---

## (4) 壓測誠實度

### 4.1 是否仍是真實負載？

讀 `scripts/debug/stress_test.gd`：

| 條件 | 實況 |
|------|------|
| 150 敵 | `ENEMY_COUNT=150`，每幀補到上限（每幀最多 +24） |
| 敵 AI | 真實 `move_and_slide` 追英雄、距離內 `take_damage` |
| 敵數值 | speed 88/142/54、HP 30/22/85、接觸傷害 6/4/12 — **接近實戰**（非 R1 弱化） |
| 敵死亡週轉 | 會死、掉落、release、再 spawn（宣稱 kills~780 量級與路徑一致） |
| 100 彈 | 真實 `spawn_projectile`、Area2D 碰撞、pierce、release、補滿 |
| 牆鐘幀時 | `Time.get_ticks_usec()` 差分，**非** fixed-delta 假 fps |
| group scan | 由 `EntityFactory` counter 輸出，**非**寫死 0 字串 |
| pool stats | exhausted / duplicate_free / duplicate_releases / foreign_releases 任一 >0 → `STRESS_FAIL` |

**判定**：相對 R1「假壓測」、對齊 R2「強化壓測」——**本輪仍是真實戰鬥負載**。第五階段 cap 改變的是 VFX/掉落上限，**沒有**把敵或彈改回假人。

額外：開場 `_spawn_initial_vfx` 打 60 傷害字 + 60 death_burst；death_burst cap=20 會讓多數初始 burst 直接 null。這只影響開場 VFX 噪音，**不**讓 150/100 主負載變假。

### 4.2 `STRESS_PERF_BELOW_60` 是否誠實？

```gdscript
if float(stats.get("min_fps", 0.0)) < 59.5:
    print("STRESS_PERF_BELOW_60=true")
else:
    print("STRESS_PERF_BELOW_60=false")
print("STRESS_PASS")
```

| 點 | 判定 |
|----|------|
| 用 min_fps（由 max_ms 反推） | **最嚴格**：min≥60 ⇒ p95/avg 必≥60 |
| avg 高、p95/min 低仍標 true | **誠實**（REVIEW 自稱 p95/min 未達 60 與此一致） |
| `STRESS_PASS` 不代表 60fps 達標 | **語意清楚**：PASS = pool 契約驗證過；perf 另印 flag |
| 未把 avg≥60 粉飾成全面達標 | **未發現造假** |

本輪**未重跑** Godot，故 `avg_fps=105.81` 等數字以 Codex 輸出為引用；**程式邏輯不否定**該結果的可產出性，但審查不背書未複測的精確數字。

### 4.3 剩餘瓶頸「物理 / transform」是否成立？

支持證據（靜態）：

- 敵 group 熱掃路徑仍為 0 的計數架構。  
- placeholder `_draw` 已移除。  
- damage_number / death_burst 被 cap 住（live 上限 64/20）。  
- 仍每幀：150×`CharacterBody2D.move_and_slide`、100×Area2D 子彈、spatial query、大量 Node2D transform、Label 更新、掉落磁吸。  

**成立為合理主因假設**；**未**用 Profiler 定量拆分 physics vs canvas vs script。下一輪若要閉環，應用 Godot Profiler / monitors 證明，而非只靠刪 VFX 後的推論。

### 4.4 壓測仍未覆蓋的面向（餘債，非本輪造假）

- 爆炸武器高密度 + explosion cap 交互  
- 雷弧 + orbit 同時滿載  
- 掉落 cap 造成的 XP/金幣損失率  
- 非 headless / 實機 GPU 填充分  

---

## (5) 分級發現清單

### P0

**本輪無新 P0。**  
R2 兩個 P0（token 命中表、double-release）**維持修復**。

### P1 — 第五階段新問題 / 加重

1. **`spawn_explosion` 達 `EXPLOSION_CAP` 直接 null → 該次爆炸傷害整段消失**  
   - 檔案：`entity_factory.gd`  
   - 建議：傷害與 VFX 分離；或 cap 時「無 VFX 仍結算」；或 recycle oldest **僅**對純視覺節點。

2. **`spawn_xp_gem` / `spawn_gold_coin` 達 cap 靜默丟獎勵**  
   - 敵已 `add_kill` 且排程掉落，null 後資源不補。  
   - 建議：合併堆疊 pickup、磁吸批次、或 cap 時加值到最近同種 gem/coin。

3. **REVIEW/口語「特效 cap 復用最舊」與程式不符**（若團隊依文件做後續設計會誤判）  
   - 實作是 skip；爆炸 skip 有玩法後果。

### P2 — 第五階段新問題 / 品質

4. **`death_burst.sprite.rotation` 跨 pool 生命累加，setup 未歸零** → 可能歪斜開場。  
5. **`enemy.sprite.rotation` 不在 `setup` 重置** → 復用時短暫以死亡朝向站立。  
6. **傷害字 merge 不區分陣營/顏色**，cap 時放大 merge 半徑 → feedback 糊。  
7. **`death_burst` 貼圖 path 硬編碼**，未走資料欄位。  
8. **空字串 sprite path 不會觸發 Dictionary 預設 fallback** → 未來漏填會隱形。  
9. **`SpriteLoader` 無 clear**（低優先；固定 assets 可接受）。

### R2 餘債（未因第五階段解決）

10. `get_enemies_in_radius` 仍配新 Array（GC 壓力）。  
11. acquire/release reparent 成本。  
12. 壓測未強制 60fps 才 PASS（有意設計；需產品層接受「結構 PASS ≠ 效能達標」）。

### 已確認維持的正確項（記功）

- `spawn_token` + hit key  
- `_in_pool` double-release / foreign release  
- 工廠 deferred 前同步 `is_active=false`  
- orbit 耗盡不 append null  
- facing cache token  
- Stress 牆鐘幀時 + 真實 150/100 交戰  
- `STRESS_PERF_BELOW_60` 不粉飾 min fps  
- gameplay `_draw` 熱點實質清空  

---

## (6) 對 Codex 第五階段宣稱的對抗式對照表

| 宣稱 | 代碼判定 |
|------|----------|
| PNG sprite 接入 gameplay | **成立** |
| 資料驅動 path | **大致成立**（death_burst 例外） |
| `SpriteLoader` cache + Image fallback | **成立** |
| 幾何 `_draw` 熱點移除 | **成立**（僅背景） |
| DamageNumber Label + merge + cap 64 | **成立** |
| DeathBurst/Explosion/Lightning/Pickup cap | **有 cap**；行為是 **skip 非 recycle** |
| 傷害結算不受 damage_number cap 影響 | **成立** |
| Pool 契約未回歸 | **成立**（靜態） |
| 真實壓測 150/100 | **成立** |
| avg ~106fps、p95/min <60、`STRESS_PERF_BELOW_60=true` | **標記邏輯誠實**；精確數字本輪未複測 |
| 剩餘瓶頸物理/transform | **合理假設，未 Profiler 證明** |

---

## (7) R1 → R2 → R3 總分對照

| 維度 | R1 | R2 | R3（第五階段後） |
|------|----|----|------------------|
| group 熱掃敵人 | 全面掃描 | 已清除 | **維持** |
| Pool 契約 | 無 | 兩 P0 後修 | **契約維持** |
| 繪製熱點 `_draw` | 多 | 仍多 | **大幅清除** |
| VFX budget | 無 | 建議項 | **有 cap；爆炸/掉落語意不乾淨** |
| 壓測誠實度 | 假/弱 | 強化但仍 <60 | **仍誠實；avg 改善、min/p95 未達標** |
| 新 P0 | — | token / double-free | **無新 P0** |

---

## 最終判定

### 第五階段有無新 P0？

**無。**

### pooling 契約是否仍完整？

**是。** `spawn_token` 命中表與 `NodePool._in_pool` double-release guard **未被第五階段繞過或回退**。

### 壓測是否誠實？

**是。** 仍為 150 敵實戰追擊/攻擊/死亡週轉 + 100 彈真實碰撞回收；牆鐘幀時；`STRESS_PERF_BELOW_60` 依 **min_fps** 標記，不因 avg≈106 而假裝全面 60fps 達標。

### 主要剩餘風險（給下一輪）

1. 把 **gameplay 結果**（爆炸傷害、XP/金幣）從 **visual cap** 拆開。  
2. 純 VFX 若要 cap，明確選 skip 或 recycle-oldest，並寫進文件與測試。  
3. 補 enemy/death_burst rotation 重置。  
4. Profiler 定量證明物理 vs transform vs Label 尖峰，再決定 MultiMesh / 固定 parent / spatial zero-alloc。  

---

*本文件僅審查與記錄；未修改任何遊戲程式碼。*
