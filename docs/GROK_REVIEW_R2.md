# Crackveil Vanguard / Rift Survivors — 對抗式驗證審查 R2

**審查者**：資深 Godot 4.x + GDScript 工程師（對抗式驗證，不採信宣稱）  
**對照文件**：`docs/GROK_REVIEW_R1.md`、`docs/CODEX_RESPONSE_R1.md`  
**驗證對象**：NodePool、EnemySpatialIndex、EntityFactory acquire/release、實體腳本、StressTest  
**方法**：靜態讀碼 + 生命週期/時序推理（本輪未啟動 Godot Profiler）  
**日期**：2026-07-09  

---

## 執行摘要

Codex 第四階段**方向正確且多數 R1 P0 已真正改掉**，不是只搬註解：

| 面向 | 判定 |
|------|------|
| R1 熱路徑 group 全掃敵人 | **已解決**（`get_nodes_in_group("enemies")` 已從武器/環繞/爆炸/朝向消失） |
| R1 環繞刃每幀 sync | **已解決**（dirty-only） |
| R1 `_clear_weapons` queue_free 競態 | **已解決**（disable + `free()` + `release_owned_nodes`） |
| Object pooling 骨架 | **已落地**（預熱、acquire/release、shape 重用） |
| Spatial index 骨架 | **已落地**（register/unregister、cell 更新、半徑/最近查詢） |

但對抗式抽查後，**仍有可重現的正確性缺口與壓測可信度問題**：

1. **新 P0**：池化節點 `instance_id` 穩定重用，環繞刃 `hit_cooldowns` / 穿透彈 `hit_bodies` 會把「新敵人」當成「上一隻已打過的舊敵人」。  
2. **新 P0**：`NodePool.release` **無 double-release / in-pool 防護**；`call_deferred` 釋放路徑下，free_list 一旦重複同一節點，下兩次 `acquire` 會交出**同一個活體**。  
3. **壓測 P1**：`StressTest` 有 150 敵 + 100 彈且 AI/物理有跑，但是**弱化負載**；`STRESS_GROUP_SCAN_HOTPATH=0` 是**寫死字串**，不是量測。145fps 在弱壓測下可信，**不能**直接等同「實戰 150/100 全系統 60fps 已達標」。

**總判定**：Codex **確實解決了 R1 的主要效能架構洞**；但 pooling 契約未閉環，**有新 P0**，尚不能宣告「池化正確且可安心擴 boss / 高週轉」。

優先級定義同 R1：

| 等級 | 意義 |
|------|------|
| **P0** | 正確性缺陷或目標負載下必炸 / 可重現髒狀態 |
| **P1** | 明顯回歸、壓測誤導、擴充地雷 |
| **P2** | 品質與微優化 |

狀態標籤：

- **R1 已解決** / **R1 未解決** / **R1 部分解決** / **新問題**

---

## (1) Pooling 正確性

### 架構現況（屬實）

- `scripts/pooling/node_pool.gd`：`warm` → free_list；`acquire` pop + `reparent` + `pool_on_acquire`；`release` → `pool_on_release` + reparent 回 `pool_root`。  
- `EntityFactory.initialize_for_arena` 預熱：enemy 170、projectile 140、orbit 24、explosion 24、xp 120、coin 64、damage_number 120、death_burst 48、lightning 24。  
- 熱路徑實體大多改走 `release_*`，敵人/子彈/掉落/VFX/爆炸/雷弧有 `pool_on_*` + `pool_reset`。  
- **耗盡策略**：`acquire` 回 `null` + warning，**不**在熱路徑 `instantiate`（符合 Codex 宣稱，但見下方邏輯風險）。

### P0 — 新問題：`instance_id` 重用導致命中表「認屍」

**檔案**：`scripts/projectiles/orbit_projectile.gd`、`scripts/projectiles/projectile.gd`

池化後節點物件身分不變，Godot `get_instance_id()` **在 acquire/release 之間保持不變**。

環繞刃：

```gdscript
# orbit_projectile.gd
var instance_id := body.get_instance_id()
if hit_cooldowns.has(instance_id):
    continue
hit_cooldowns[instance_id] = float(stats.get("hit_interval", 0.42))
```

線性彈：

```gdscript
# projectile.gd
if hit_bodies.has(instance_id):
    return
hit_bodies[instance_id] = true
```

**重現條件（高週轉時必現）**：

1. 環繞刃打到敵人 A（id=X），寫入 cooldown。  
2. A 死亡 → `release_enemy` → 回池。  
3. Spawner 再 `acquire` 同一節點當新敵人 B（仍是 id=X）。  
4. 在 `hit_interval`（預設 ~0.42s）內，**該刃對 B 完全不結算傷害**。  
5. 穿透彈若尚未 `release`，`hit_bodies` 同樣讓 B 免疫該彈。

`pool_on_release` 有清自己的 `hit_cooldowns` / `hit_bodies`，但**清的是攻擊者字典**；受害方回收後，**其他仍活著的攻擊者字典不會清 X**。

**建議**：

- 為可池化戰鬥實體加單調 `spawn_generation` / `spawn_token`（int，每次 `pool_reset` +1）。  
- 命中表 key 改 `(instance_id, generation)` 或只存 generation 對照。  
- 或敵人 `pool_on_release` 時廣播/登記「此 id 世代失效」（成本較高，不如 token）。

> 此為 pooling 重構最經典回歸之一；**R1 未存在（當時 queue_free 使 instance_id 消失）→ 新 P0**。

### P0 — 新問題：`NodePool.release` 無 double-release / 歸屬檢查

**檔案**：`scripts/pooling/node_pool.gd`

```gdscript
func release(node: Node) -> void:
    # 無：是否已在 free_list、是否屬於本 pool、是否已 live
    if node.has_method("pool_on_release"):
        node.pool_on_release()
    ...
    live_count = max(live_count - 1, 0)
    free_list.append(node)
```

`EntityFactory.release_projectile` / `release_orbit_projectile` / `release_enemy_deferred` 多用 `call_deferred("_release", ...)`。  
目前多數路徑靠 `is_active=false` 避免重入，**但 pool 層本身不防**：

- 若兩處各 `call_deferred(_release, same_node)`（例如未來再加一條釋放路徑、或 `is_active` 漏設），free_list 會出現**兩個相同參考**。  
- 之後兩次 `acquire` → **同一節點當兩個活體**：雙重 `_physics_process` 語意、雙重 register、空間索引錯亂、HP/位置互相覆寫。  
- `live_count` 被多減，統計與 spawner cap 失真。

**現有可碰觸邊緣**：

- `orbit_weapon.release_owned_nodes()` 與 orbiter 在 `owner_player` 失效時自釋放，目前時序多半錯開，但**契約未禁止重疊**。  
- `release_orbit_projectile` **不會立刻** `is_active=false`（等 deferred 才 `pool_on_release`），擴大與其他邏輯重疊的窗口。

**建議**：

```gdscript
# 偽碼
var _in_pool: Dictionary = {} # instance_id -> true
func release(node):
    var id = node.get_instance_id()
    if _in_pool.get(id, false):
        push_error("double release: %s" % pool_name)
        return
    ...
    _in_pool[id] = true
func acquire(...):
    ...
    _in_pool.erase(id)
```

並在 deferred 前同步 `is_active=false` / `monitoring=false`。

### P1 — 新問題：pool 耗盡 `null` 造成靜默邏輯錯誤

**檔案**：`entity_factory.gd`、`orbit_weapon.gd`、各 `spawn_*` 呼叫端

`acquire` 耗盡回 `null` 後：

| 呼叫端 | 行為 | 風險 |
|--------|------|------|
| `spawn_enemy` | spawner 當幀少怪 | 可接受（已有 live_count cap）；**未來 boss 若走同一 API 會被跳過** |
| `spawn_projectile` | 武器開火無彈 | 靜默 DPS 流失，無 UI/log 到玩家 |
| `orbit_weapon._sync_orbiters` | **`orbiters.append(null)`** | 用 null 填滿 desired_count，之後 `orbit_dirty=false`，**即使池子稍後有空位也不補刃** |
| VFX / damage_number | 少特效 | 可接受；但壓測不檢查其 exhausted |

```gdscript
# orbit_weapon.gd — 明確缺陷
while orbiters.size() < desired_count:
    var orbiter: Node = EntityFactory.spawn_orbit_projectile(...)
    orbiters.append(orbiter)  # null 也 append
```

**建議**：`append` 前 null 檢查；耗盡時保持 `orbit_dirty=true` 下幀重試；boss 走 `spawn_enemy_critical` 允許溢出 instantiate 或獨立預留池。

### P1 — 新問題：deferred release 期間「殭屍一幀」

| 類型 | 釋放 | 延遲期間狀態 |
|------|------|----------------|
| Enemy | unregister **立刻**；`pool_on_release` deferred | `is_active=false` 已在 `_die` 設；**仍在 `enemies` group** 直到 deferred；碰撞 shape 仍 enabled |
| Projectile / Orbit | 整段 deferred | 多半已 `is_active=false`；orbit **自釋放**有設，**武器 release_owned_nodes 未先設** |
| Explosion / VFX / pickup | 多為同步 | 較乾淨 |

敵人：`take_damage` 看 `is_active`，線性彈 `can_hit` 也看 `is_active` → 多數安全。  
但 `orbit_projectile` 先 `is_in_group("enemies")` 再 `take_damage`：會對已死未出池敵人多走呼叫（no-op），非致命。

**英雄 facing 快取**（`cached_facing_enemy`，0.1s）：`is_instance_valid` 在池化後**仍為 true**，可能短暫朝向「已回收／已重生在別處」的節點 → 表現小 bug（P1/P2 邊界，列 P1）。

### P1 — 狀態重置清單抽查

| 類型 | HP/數值 | velocity/timer | hit 表 | monitoring/process | group | visible | 判定 |
|------|---------|----------------|--------|--------------------|-------|---------|------|
| Enemy | release 清 hp/timer/vel；reset 再 setup | OK | N/A | OK | remove/add | OK | **佳** |
| Projectile | setup 重寫；release 清 traveled/source | OK | clear | OK | OK | OK | **佳**（除 id 重用） |
| Orbit | release 清 stats/cooldown/owner | OK | clear 自己 | monitoring 關 | OK | OK | **佳**（除 id 重用） |
| Explosion | clear stats/age/flag | OK | N/A | OK | N/A | OK | **佳** |
| DamageNumber | age/text | OK | N/A | OK | N/A | OK | **佳** |
| DeathBurst / Lightning | age/points | OK | N/A | OK | N/A | OK | **佳** |
| Pickup | value/magnet/drift | OK | N/A | process 關；**Area2D monitoring/collision 未關** | OK | OK | **可** |
| Hero | 未池化 | — | — | — | — | — | N/A |

**CircleShape2D**：敵/彈/刃改 mutation radius，**R1 已解決**。Hero 仍 `CircleShape2D.new()`（未池化，可接受）。

**訊號**：`projectile.gd` `body_entered` 只在 `_ready` 連一次，**正確**（避免重複 connect）。

**`_ready` 只跑一次**：warm 時已 `_ready`；後續靠 `pool_on_acquire` + `pool_reset`。目前欄位有補，**未發現「只在 _ready 初始化卻 acquire 後缺設」的致命洞**（除上述 id 策略與 orbit null）。

### P2 — reparent 成本與 pool 根

每次 acquire/release `reparent` Runtime ↔ Pools，150 敵高死亡率時有樹操作成本。可改為固定 parent + `visible`/process/collision 開關。屬優化，非錯誤。

### P2 — `pickup.gd` 預設 `collect` 呼叫 `release_xp_gem`

子類有覆寫；基類誤用只在直接用 base 時發生。地雷級。

---

## (2) 空間索引正確性

### 實作摘要（屬實）

`EnemySpatialIndex`：

- `cell_size = 128`  
- `register` / `unregister`  
- 每物理幀 `_update_enemy_cells()` 搬格  
- `find_nearest`：以 `ceil(range/cell)` 擴正方形格  
- `get_enemies_in_radius`：`center ± radius` 對應 min/max cell + `distance_squared`  
- 敵人死亡：`release_enemy_deferred` **先 unregister 再 deferred release** → 查詢端即時不可見  

熱路徑遷移：

| 原 R1 熱點 | 現況 |
|------------|------|
| `base_weapon.find_nearest_enemy` | `EntityFactory` → spatial |
| `chain_lightning` 下一跳 | `get_enemies_in_radius` |
| `orbit_projectile` 傷害 | `get_enemies_in_radius` + 關閉 monitoring |
| `explosion_area` | spatial |
| `hero` 朝向 | 10Hz + spatial |
| `enemy_spawner` cap | `get_enemy_live_count()` |

全專案 `get_nodes_in_group("enemies")`：**0 處**。  
殘留 `get_nodes_in_group("heroes")` 僅 `enemy.gd` fallback（英雄 ≤5，可接受）。

### P0 — 跨格半徑：未發現漏鄰格實作錯誤

`get_enemies_in_radius` 用軸對齊包围盒覆蓋圓的 AABB，再 squared 距離過濾，**幾何正確**，不是「只查中心一格」。

`find_nearest` 用 `radius_cells = ceil(max_range/cell_size)` 的正方形環，可覆蓋距離 ≤ max_range 的點所在 cell（多餘角角落用距離濾掉）。**正確**。

### P1 — 新問題：格更新與移動同幀順序 → 最多 1 幀過期格

- `EnemySpatialIndex` 掛在 Autoload `EntityFactory` 下，`process_mode` 繼承 ALWAYS。  
- 典型順序：索引先用**上一幀位置**更新 cell → 之後敵人才 `move_and_slide`。  
- 查詢用 **過期 cell + 當幀 `global_position`**。  

敵人速度 ~54–142 px/s，單幀位移遠小於 128 cell，**實戰幾乎不漏**；極邊角（剛好在半徑邊緣 + 跨格）可能 1 幀 miss/extra。列 **P1 邊界**，非立即炸局。

快速子彈不進敵人格索引；敵人索引過期不直接等於子彈錯位。

### P1 — 新問題：查詢配置陣列，非 R1 建議的 `for_each` 零配置

每次 `get_enemies_in_radius` `Array[Node2D]` 新建。環繞刃每物理幀每刃一次，爆炸/雷鏈觸發時亦然。  
比全表 group **好一個數量級**，但未到「熱路徑零配置」。壓力大時仍有 GC 毛刺。  
**R1 部分解決**（演算法對，分配策略弱）。

### P2 — `live_enemies.has` / `Array.erase` O(n)

150 規模可接受；長期可改 dict 集合成員資格。

### P2 — 未過濾 `is_active`

仰賴 unregister 契約；目前死亡路徑有 unregister，**一致則安全**。若未來只 `is_active=false` 不 unregister 會漏。

---

## (3) R1 問題逐條狀態

### R1 P0

| # | 問題 | 狀態 | 證據 |
|---|------|------|------|
| 1 | orbit 每幀 `_sync_orbiters` | **R1 已解決** | `orbit_dirty`；`_process` 僅 dirty 時 sync |
| 2 | orbit 每幀 group 全敵 | **R1 已解決** | spatial + `monitoring=false` |
| 3 | hero 每幀掃敵朝向 | **R1 已解決** | 0.1s 快取 + spatial |
| 4 | 武器/爆炸/連鎖 group 掃 | **R1 已解決** | 皆走 EntityFactory/spatial |
| 5 | Factory 只 instantiate | **R1 已解決** | NodePool acquire |
| 6 | 生命結束 queue_free | **R1 已解決**（可池化類型） | release_*；英雄/武器仍 free（合理） |
| 7 | setup 每次 `CircleShape2D.new` | **R1 已解決**（敵/彈/刃） | mutation radius；Hero 仍 new |
| 8 | `emit_stats` 每幀 | **R1 已解決** | 0.1s 節流 + 事件 emit |
| 9 | 背景每幀重畫 | **R1 已解決** | 相機跨 cell 才 redraw |
| 10 | pickup 每幀 redraw | **R1 已解決** | 僅 moved/magnetized |
| 11 | `_clear_weapons` queue_free 競態 | **R1 已解決** | process 關 + `release_owned_nodes` + `free()` |

### R1 P1（抽查）

| # | 問題 | 狀態 |
|---|------|------|
| 12 | `make_runtime_copy` 死碼 | **R1 已解決**（`BaseWeapon.setup` 呼叫） |
| 13 | hero/squad data 未 duplicate | **R1 已解決** |
| 14 | 隊長死亡半屍 | **R1 已解決**（停 process/相機；`player=null`） |
| 15 | formation / 重招 | **R1 已解決**（`dead_ids`/`recruited_once`/`_reindex_formation`） |
| 16 | pickup 只吸隊長 | **R1 已解決**（小隊最近成員） |
| 17 | spawner group.size | **R1 已解決**（`live_count`） |
| 18 | 連升 emit_stats | **R1 已解決**（`_request_level_up` emit） |
| 19 | 傷害數字無上限 | **R1 部分解決**（有池；耗盡跳過；**無合併/每幀 cap**） |
| 20 | 缺 Spatial/Pool 模組 | **R1 已解決** |
| 21 | 硬編碼 key | **R1 部分解決**（InputMap + `get_vector`；無重綁 UI） |
| 22 | 尋敵 API 重複 | **R1 已解決**（收斂 EntityFactory） |

### R1 未再列為阻塞、但效能餘債

- 敵人血條/受擊 `_draw`、VFX 生命期每幀 `queue_redraw`、傷害字 ThemeDB font：仍在，**非 group 掃描級**，高群傷時仍吵。  
- 屬 R1 繪製項的延續，本輪降為 **P2 餘債**。

---

## (4) 壓測是否有效

### 場景與腳本

- `scenes/debug/StressTest.tscn` → `scripts/debug/stress_test.gd`  
- 實例化完整 `Arena.tscn` → 會 `initialize_for_arena`、開 `game_running`、生成小隊與**真實武器**。  
- 關掉 `EnemySpawner`，改手動刷 150 敵 + 100 彈。

### 屬實的部分

| 宣稱 | 驗證 |
|------|------|
| 同屏 150 敵 | `ENEMY_COUNT=150` + `spawn_enemy`；預熱 170；結束檢查 `exhausted` |
| 100 投射物 | 手動 spawn 100；`range=20000`、`pierce=999` 會長存 |
| AI 有跑 | 敵 `speed=18`，每幀 `_find_nearest_hero` + `move_and_slide` |
| 碰撞/監控有跑 | 線性彈 `monitoring=true`、mask=2；敵 layer=2 |
| 繪製有跑 | 敵 `_draw`、彈 `_draw`、開場 40 組 VFX |
| 武器系統 | `game_running` 下小隊武器會找尋空間索引並開火 |

### 削弱與不可信點（P1）

1. **敵是「假威脅」**：`damage=0`、`max_hp=99999`、`speed=18`（遠低於 normal 88 / fast 142）。移動與 AI 有，但**遠低於實戰密度**。  
2. **100 彈與 150 敵空間分離**：敵在隊長前方網格（y-360），彈從 `leader + (1200,1200)` 外圈飛出；短測窗口內**大量子彈可能幾乎不與敵重疊**，物理 pair 壓力被低估。  
3. **`STRESS_GROUP_SCAN_HOTPATH=0` 是字面常數**，不是 profiler/計數器：

```gdscript
print("STRESS_GROUP_SCAN_HOTPATH=0")
```

   用此輸出當「熱路徑歸零」的證據 → **方法論無效**（靜態已確認 enemies group 掃描移除，但**不該用假 metric 背書**）。  
4. **avg_fps 含初始化後所有幀**，未報告 1% low / min；未關 VSync 的說明。145 平均值在中高階機、弱 AI、gl_compatibility 下**可以真實**，但不能外推「升級後滿場爆炸+掉落+環繞刃」仍 145。  
5. **武器會額外消耗 projectile / damage_number 池**：壓測只 fail enemy/projectile exhausted；傷害字耗盡被忽略。若本機曾跑出 PASS，只能說明那兩池沒爆，不代表 VFX 池健康。  
6. **環繞刃 / 爆炸 / 雷鏈查詢成本**取決於小隊配裝；有測到，但是在「敵不死亡、無掉落雪崩」的環境。

### 壓測結論

| 問題 | 判定 |
|------|------|
| 是否同屏 150+100 | **大致是**（數量層面） |
| 是否 AI/碰撞/繪製有跑 | **有，但降載** |
| group 熱路徑歸零 | **程式碼層已歸零**；壓測字串 **不能當證據** |
| 145fps 可信？ | **在此弱壓測腳本下可信為平均幀**；**不足以證明 R1 目標「實戰 150/100/60」已達標** |

---

## (5) 新引入 / 池化典型回歸

### P0（新）

1. **instance_id 命中表污染**（§1）— 環繞刃、穿透彈。  
2. **Pool double-release 無防護**（§1）— 契約層缺陷，deferred 放大風險。

### P1（新）

3. **`orbit_weapon` append null + 耗盡後不再 dirty** — 刃數永久短缺直到下次升級 dirty。  
4. **熱路徑 spawn 靜默 null** — DPS/特效無反饋；boss 共用 API 危險。  
5. **deferred release 未先硬關 orbit 活動旗標**（武器釋放路徑）。  
6. **facing 快取 + 池化 `is_instance_valid` 仍 true**。  
7. **壓測假 metric / 弱負載**（§4）。  
8. **`get_enemies_in_radius` 每查配置 Array** — 性能回歸餘地。

### P2（新或餘債）

9. Pickup 未關 Area2D monitoring/collision。  
10. 敵人/VFX 程序化 `_draw` 仍多。  
11. `register`/`erase` O(n)。  
12. 每次 acquire/release reparent。  
13. `hero.gd` 仍每次 setup `CircleShape2D.new()`。  
14. 傷害數字無合併/全場 cap（R1 部分解決）。

### 已正確避開的典型坑（應記功）

- `body_entered` 不在 acquire 重複 connect。  
- `pool_on_release` 關 process / monitoring / shape（敵彈為主）。  
- 敵死亡先 `is_active=false` 再 deferred release。  
- shape 重用 radius。  
- 武器清除用 `free()` 而非只靠 `queue_free`。

---

## 分級清單清單

### P0

1. **`orbit_projectile.hit_cooldowns` / `projectile.hit_bodies` 用 raw `instance_id`：池化重用導致新敵短暫/持續免疫 — 改 spawn generation token。**（新問題）  
2. **`NodePool.release` 必須防 double-release（in-pool set）；deferred 釋放前同步钝化節點。**（新問題）

### P1

3. **`orbit_weapon._sync_orbiters` 禁止 `append(null)`；耗盡保持 dirty 重試。**（新問題）  
4. **區分 soft-spawn（可跳過）與 critical-spawn（boss/必出）；耗盡策略文件化。**（新問題）  
5. **`StressTest`：敵用實戰速度/武器交戰區重疊；印真實 query/group 計數；報 min/1% low fps；勿寫死 `GROUP_SCAN_HOTPATH=0`。**（新問題）  
6. **`get_enemies_in_radius` 改 `for_each_in_radius(Callable)` 或重用 buffer，減少 GC。**（R1 部分解決）  
7. **英雄 `cached_facing_enemy` 需驗證 `is_active` 或 generation。**（新問題）  
8. **傷害數字：池化後仍缺合併與每幀上限。**（R1 部分解決）

### P2

9. Pickup release 關 monitoring / shape。  
10. 敵血條/VFX draw 預算。  
11. Spatial 成員結構 O(1)。  
12. 減少 reparent。  
13. 壓測納入 orbit 刃數、爆炸次數、掉落物雪崩場景。

---

## R1 → R2 總分對照

| 維度 | R1 | R2 |
|------|----|----|
| enemies group 熱路徑 | 全面掃描 | **已清除** |
| Object pool 就緒度 | 2/5 | **4/5 骨架；契約 2.5/5（id/double-free）** |
| Spatial index | 無 | **有且查詢幾何正確** |
| 正確性 | 可玩原型 | **可玩 + 池化命中表新洞** |
| 150/100/60 證據 | 無 | **弱壓測平均 fps；未達嚴格證明** |

---

## 最終判定

### Codex 是否確實解決 R1？

**是（主幹）**。R1 列出的 P0 效能洞——環繞每幀 sync、group 全掃、Factory 無池、queue_free 熱路徑、背景/ stats 噪音、武器清除競態——在程式碼層**已實質改掉**，不是文件空話。

### 有無新 P0？

**有。**

1. 池化 **`instance_id` 命中表污染**（環繞刃 / 穿透彈）。  
2. **`NodePool` 無 double-release 防護**（deferred 路徑下可演成雙重 acquire 同一節點）。

### 一句话给實作者

> 架構分過關；下一個 PR 請先修 **spawn generation + pool 歸屬断言**，並把 StressTest 改成「會死人、會掉落、子彈打進敵群」的誠實負載，再談 145fps。

---

*本報告為對抗式靜態驗證，針對 `docs/CODEX_RESPONSE_R1.md` 的實作宣稱；未在本機重跑 Godot 取得 145fps 原始輸出。*
