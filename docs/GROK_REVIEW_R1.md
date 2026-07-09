# Crackveil Vanguard / Rift Survivors — 對抗式優化審查 R1

**審查者**：資深 Godot 4.x + GDScript 工程師（對抗式）  
**範圍**：`scripts/`、`scenes/` 全量靜態審查（Godot 4.2、`GameManager` / `EntityFactory` autoload）  
**原型階段**：核心迴圈 → WeaponData Resource 化（4 武器）→ 小隊系統（HeroData / SquadData）  
**效能目標**：同屏 **150 敵 + 100 投射物、60fps**  
**日期**：2026-07-09  

---

## 執行摘要

本原型在資料驅動（`WeaponData` / `HeroData` / `SquadData`）與集中生成入口（`EntityFactory`）上方向正確，`setup()` 重設狀態的習慣也有利於之後接 object pooling。  
但以 150 敵 + 100 投射物的目標衡量，**目前架構尚未 pooling 就緒**，且多處熱路徑會在同幀反覆：

1. `instantiate` + `queue_free`（敵人 / 子彈 / 掉落 / 傷害數字 / VFX）
2. `get_tree().get_nodes_in_group("enemies")` 全表掃描（武器尋敵、環繞刃傷害、爆炸、英雄朝向）
3. 大量 `_draw` / `queue_redraw`（敵人血條、掉落物、背景格線、傷害數字）

**WeaponData 執行時 `duplicate(true)` 升級不會寫回 `.tres` 原檔**——此點正確。  
**最大風險不在單一邏輯 bug，而在「O(敵人 × 系統數) 的每幀掃描 + 無池化分配」會在目標負載下先把幀預算打穿。**

優先級定義：

| 等級 | 意義 |
|------|------|
| **P0** | 目標負載下幾乎必炸幀，或可重現正確性缺陷 / 資料污染風險 |
| **P1** | 明顯 bug 或擴充地雷；中期必改，否則系統難長 |
| **P2** | 品質、慣用法、可維護性；建議排程但不阻塞原型驗證 |

---

## (1) 正確性與潛在 Bug

### P0

#### `scripts/weapons/orbit_weapon.gd`：每幀強制 `_sync_orbiters()` 造成多餘配置與潛在邏輯抖動
- **問題**：`_process` 無條件呼叫 `_sync_orbiters()`；內部對每個 orbiter 每幀呼叫 `configure_orbit()`，而 `orbit_projectile.gd` 的 `configure_orbit` 會 `stats.duplicate(true)`、`_apply_shape()`（`CircleShape2D.new()`）、`queue_redraw()`。
- **行為影響**：環繞刃數值每幀重建；升級當幀與非升級幀成本相同；形狀資源每幀配置新物件（舊 shape 依賴 GC）。
- **建議**：只在 `setup` / `_on_data_changed` / orbiter 數量變化時 sync；平時僅讓 orbiter 自己 `_physics_process` 繞行。提供 `OrbitWeapon.mark_dirty()`，升級時設 dirty 一次。

#### `scripts/heroes/hero.gd`：`_clear_weapons()` 用 `queue_free` 後立刻裝備新武器
- **問題**：`queue_free()` 延遲到幀末才釋放；舊武器節點仍在樹內、`_process` 仍可能開火一幀，與新武器並存。
- **觸發條件**：`reset_for_run()` 重裝武器時（目前 Arena 用 `start_run(..., reset_player=false)` 較少踩到，但是明確地雷；重開 run 不 reload 場景時必現）。
- **建議**：`for child in weapons_root.get_children(): child.free()`（確定無再入時），或先 `set_process(false)` / 移出樹再 `queue_free`；並在 `weapons` Dictionary 清空後以「僅 dictionary 內武器可開火」為準。

#### `scripts/enemies/enemy.gd` + `scripts/projectiles/orbit_projectile.gd`：環繞刃完全不用 Area2D 重疊，卻開著 monitoring
- **問題**：`OrbitProjectile.tscn` 設 `monitoring=true`、`collision_mask=2`，但傷害走 `get_nodes_in_group("enemies")` 手動距離判定；物理空間成本付了、正確命中仍靠 O(n) 掃描。
- **建議（二選一）**：  
  - A）關掉 monitoring，專用空間網格查詢（見第 2 節）；  
  - B）用 `get_overlapping_bodies()` 或 `body_entered` + hit interval（與線性子彈一致），刪除 group 掃描。

### P1

#### `scripts/autoload/game_manager.gd`：升級鏈與 HUD 競態（輕度）
- **問題**：`apply_upgrade` 若 `xp >= xp_required` 會立刻再 `_request_level_up()`，此分支**不** `emit_stats()`；多級連升時 UI 可能短暫顯示過期等級，直到下一幀 `_process` 的 `emit_stats()`。
- **建議**：`_request_level_up` 開頭或結尾呼叫 `emit_stats()`；或 `apply_upgrade` 兩條路徑都 emit。

#### `scripts/autoload/game_manager.gd`：`add_xp` 在 `waiting_for_upgrade` 時仍累加 XP（設計需文件化）
- **問題**：暫停後理論上 pickup 不跑；但任何未跟隨 `paused` 的來源（`PROCESS_MODE_ALWAYS`、debug、未來系統）仍可 `add_xp`，只加數字不開第二層 UI，直到選完升級才串第二張。行為合理但未註明。
- **建議**：註解契約；或 `waiting_for_upgrade` 時把溢出 XP 放 `pending_xp` 明確化。

#### `scripts/heroes/hero.gd`：隊長死亡不 `queue_free`，狀態半屍
- **問題**：`_die()` 對 leader 只 `is_alive=false`、移出 `heroes`，不釋放節點；`GameManager.player` 仍指向屍體。因 `player_died` 會 `paused=true` 目前可遮住後果，但若改「隊長可被救 / 不立即 pause」會出現：隊友仍跟屍體站位、pickup 仍吸向屍體、相機停屍。
- **建議**：game over 流程明確 `leader.set_process(false)`、停相機；或 leader 也走退場 VFX + 延遲 free，並把 `GameManager.player` 置 null。

#### `scripts/heroes/squad_manager.gd`：成員死亡後 `formation_index` 不重編
- **問題**：`member_died` 只 `erase` 陣列與 `member_ids`；存活隊友保留舊 slot。站位不會「卡住」，但會出現中間空槽、陣型不對稱。
- **建議**：死亡後 `reindex_formation()`，或改用穩定 `slot_id` 與稀疏隊形表；招募時填補空 slot。

#### `scripts/heroes/squad_manager.gd`：死亡後可再次招募同 `hero_id`
- **問題**：`member_ids.erase(hero_id)` 使同英雄可再招；若設計是「唯一英雄」則為 bug，若是「可再招募」則缺冷卻 / 費用。
- **建議**：用 `recruited_once` 或 `dead_ids` 分離「場上存活」與「本局已用過」。

#### `scripts/pickups/pickup.gd`：僅 `GameManager.player`（隊長）可磁吸與拾取
- **問題**：隊友站在 gem 上也不吃；小隊分散時經濟節奏怪。
- **建議**：對 `squad_manager.get_members()` 取最近存活英雄，或用「小隊共享 pickup 半徑 = max(成員半徑) + 隊長位置」。

#### `scripts/enemies/enemy.gd`：`target.get("hit_radius")` 弱型別
- **問題**：若未來非 Hero 進 `heroes` group 且無 `hit_radius`，`float(null)==0`，攻擊距離偏大。
- **建議**：`var r: float = target.hit_radius if "hit_radius" in target else 12.0`，或要求實作 `get_hit_radius()`。

#### `scripts/projectiles/projectile.gd`：`source` 比較與友軍傷害
- **問題**：只排除 `body == source` 且只打 `enemies`；目前安全。若之後有「可破壞友方物件 / 中立」需明確 faction。
- **建議**：預留 `team_id` / `can_hit(body)`。

#### `scripts/heroes/hero.gd` + Resource：`hero_data` / `squad_data` **未** duplicate
- **問題**：武器路徑有 `weapon_data.duplicate(true)`（安全）；英雄資源是直接引用 `.tres`。目前升級改的是 Hero 節點欄位，**尚未污染檔案**；但若未來寫 `hero_data.max_hp += ...` 會改到記憶體中的 Resource，編輯器中開啟的 `.tres` 可能被標 dirty。
- **建議**：`setup` 時 `hero_data = new_hero_data.duplicate(true)`，或嚴格禁止寫回 Resource，只讀。

#### `scripts/weapons/base_weapon.gd`：`data = weapon_data.duplicate(true)` 已正確隔離 `.tres`
- **現狀判定**：**升級不會改到磁碟上的 WeaponData 原檔**（執行時 deep copy）。`WeaponData.make_runtime_copy()` 與這條重複且未被呼叫——死碼。
- **建議**：統一走 `make_runtime_copy()`；文件註明「執行時必 copy」。

### P2

#### `scripts/enemies/enemy.gd`：攻擊距離用 `length()` 非 `length_squared()`
- **問題**：熱路徑多餘 `sqrt`。
- **建議**：預先算 `(radius + hit_radius + 4)^2` 後比 squared distance。

#### `scripts/ui/level_up_screen.gd`：每次升級重建 Button
- **問題**：非正確性，但 `queue_free` + 新建在暫停幀可接受；連升時可感卡頓。
- **建議**：三張卡池化，只改 text / bind。

#### `scripts/arena/arena.gd`：訊號連線
- **問題**：`level_up_requested` / `game_over_requested` 有 `is_connected` 防護；`upgrade_selected` 無（場景 reload 時舊節點釋放通常 OK）。
- **建議**：統一 `is_connected` 風格，避免未來不 reload 的 soft restart 雙連線。

#### `scripts/debug/weapon_smoke_test.gd`：依賴幀數硬編碼
- **問題**：低幀機器上 follow 檢查可能假失敗。
- **建議**：改等「誤差連續 N 幀 < 閾值」或 timeout + 條件。

---

## (2) 效能與 Object Pooling 就緒度（最重要）

### 2.1 現況評分（對照 150 敵 + 100 投射物 @ 60fps）

| 子系統 | 現況 | Pooling 就緒度 | 目標負載預估 |
|--------|------|----------------|--------------|
| `EntityFactory` | 全面 `instantiate` | **低**（僅有集中入口，無 acquire/release） | 生成/死亡尖峰掉幀 |
| 敵人 | `queue_free` + 每幀尋英雄 + `_draw` | **中**（有 `setup`） | 150 AI + 繪製壓力高 |
| 線性子彈 | Area2D `body_entered` + `queue_free` | **中高**（`setup` 清 `hit_bodies`） | 100 發可接受若池化 |
| 環繞刃 | **每幀 group 掃描全敵** | **低** | **P0 幀殺手** |
| 爆炸 / 連鎖 | 觸發時 group 掃描 | **中** | 觸發頻率×150 |
| 傷害數字 | 每下 `instantiate` + 每幀 `queue_redraw` | **低** | 群傷時分配爆炸 |
| 掉落物 | 每殺 1–2 個 instantiate + 每幀 redraw | **低** | 場上殘留數百時崩 |
| 英雄朝向 | 每英雄每幀掃全敵 | **低** | 5×150/幀多餘 |
| Spawner cap | `get_nodes_in_group` 算數量 | **低** | 每次生成配置陣列 |
| 背景 | 每幀全螢幕格線 + crack | **N/A** | 固定高成本 |

**結論**：介面集中在 `EntityFactory` 是好事，但**離「乾淨換成 pooling」還差完整生命週期協議**（activate/deactivate、禁止熱路徑 `queue_free`、碰撞/group/process 開關、shape 重用）。

### 2.2 熱路徑罪魁（必須先砍，再談池）

#### P0 — `get_nodes_in_group("enemies")` 擴散

| 檔案 | 行為 | 成本模型（約） |
|------|------|----------------|
| `base_weapon.gd` `find_nearest_enemy` | 每把冷卻就緒武器掃全敵 | 武器數 × 150 |
| `chain_lightning_weapon.gd` `_find_next_chain_target` | 每跳一次全掃 | chain_count × 150 |
| `orbit_projectile.gd` `_damage_overlapping_enemies` | **每物理幀每刃全掃** | orbiter × 150 / 幀 |
| `explosion_area.gd` `_apply_damage` | 每次爆炸全掃 | 1 × 150 |
| `hero.gd` `get_nearest_enemy`（朝向） | **每英雄每物理幀全掃** | heroes × 150 / 幀 |
| `enemy_spawner.gd` `_spawn_one` | 每次生成取整 group 算 size | 配置 Array + O(n) |

環繞刃若 3 英雄 × 平均 2 刃 = 6，僅此就 **900 次/幀** 距離檢查；再加上 5 英雄朝向 750、敵人找英雄（英雄少，尚可），武器開火尖峰再疊一層。

#### P0 — 熱路徑 `instantiate` / `queue_free`

`entity_factory.gd` 所有 `spawn_*` 皆 `PackedScene.instantiate()` + `add_child`；死亡/飛行結束皆 `queue_free()`。  
在 150 敵持續換血 + 子彈對穿 + 傷害數字下，**分配器與場景樹變動**會與邏輯成本疊加。

#### P0 — 繪製與 UI 噪音

| 檔案 | 問題 |
|------|------|
| `enemy.gd` | 受傷 `queue_redraw`；血條用 Canvas `_draw` |
| `pickup.gd` | **每物理幀** `queue_redraw`（含未磁吸） |
| `damage_number.gd` / `death_burst.gd` / `lightning_arc.gd` / `explosion_area.gd` | 生命期每幀 redraw |
| `arena_background.gd` | **每幀**重畫大範圍格線 + 雙重迴圈 crack |
| `game_manager.gd` | `game_running` 時**每幀** `emit_stats()` → HUD 改字串 |

### 2.3 建議 Pool 架構（可直接實作的契約）

#### 核心介面

```gdscript
# scripts/pooling/poolable.gd
# 所有可池化節點實作（duck typing 或單一 base）
func pool_on_acquire() -> void   # 顯示、開 process/physics、開碰撞、加 group
func pool_on_release() -> void   # 隱藏、關 process、關 monitoring/collision、清狀態、移 group
func pool_reset(args: Dictionary) -> void  # 等同強化版 setup
```

```gdscript
# scripts/pooling/node_pool.gd
class_name NodePool
extends RefCounted

var scene: PackedScene
var free_list: Array[Node] = []
var live_count: int = 0
var pool_root: Node  # 建議掛在 Arena/Runtime/Pools 下，避免進 gameplay 查詢

func warm(n: int, parent: Node) -> void:
    for i in n:
        var node := scene.instantiate()
        parent.add_child(node)
        _deactivate(node)
        free_list.append(node)

func acquire(parent: Node) -> Node:
    var node: Node
    if free_list.is_empty():
        node = scene.instantiate()
        parent.add_child(node)
    else:
        node = free_list.pop_back()
        if node.get_parent() != parent:
            node.reparent(parent)
    live_count += 1
    if node.has_method("pool_on_acquire"):
        node.pool_on_acquire()
    return node

func release(node: Node) -> void:
    if not is_instance_valid(node):
        return
    if node.has_method("pool_on_release"):
        node.pool_on_release()
    live_count = max(live_count - 1, 0)
    free_list.append(node)
```

#### `EntityFactory` 改造方向

```gdscript
# 偽碼 — 熱路徑只走 acquire/release
var _pools: Dictionary  # "enemy" / "projectile" / "xp_gem" / ...

func spawn_enemy(id, config, pos) -> Node:
    var e := _pools["enemy"].acquire(_get_runtime_parent())
    e.pool_reset({"enemy_id": id, "config": config, "position": pos})
    EnemyRegistry.register(e)  # 見空間結構
    return e

func release_enemy(e: Node) -> void:
    EnemyRegistry.unregister(e)
    _pools["enemy"].release(e)

# 禁止：遊戲邏輯直接 queue_free 可池化物件
# 允許：queue_free 僅用於非池化、一次性編輯器/UI 節點
```

#### 各類型 `pool_on_release` 檢查清單

| 類型 | 必須做 |
|------|--------|
| Enemy | `visible=false`；`set_physics_process(false)`；`collision_shape.disabled=true`；`remove_from_group("enemies")`；`hp=0` 哨兵；清 velocity |
| Projectile | `monitoring=false`；`set_physics_process(false)`；`hit_bodies.clear()`；`remove_from_group("projectiles")` |
| OrbitProjectile | 同上 + `hit_cooldowns.clear()`；勿 `queue_free` 當 player 無效時改 `EntityFactory.release_*` |
| XPGem/Coin | 關 process；`magnetized=false`；移出 pickups group |
| DamageNumber/DeathBurst/LightningArc/Explosion | 關 process；visible=false；**不要**每幀 redraw 當 inactive |

#### `setup` → `pool_reset` 必改點（否則池會漏狀態）

1. **禁止**每次 `CircleShape2D.new()`：改 `shape.radius = r`（shape 在場景載入時建一次）。  
   影響：`enemy.gd`、`projectile.gd`、`orbit_projectile.gd`、`hero.gd`。
2. 訊號：`body_entered` 只在 `_ready` 連一次，**release 後不要 disconnect/reconnect**。
3. `queue_free` 全面替換為 `EntityFactory.release_*(self)`（可用 `tree_exiting` 斷言抓漏）。
4. 預熱建議（進入 Arena 時）：
   - Enemy 160
   - Projectile 120
   - DamageNumber 80
   - XPGem 80 / Coin 40
   - Explosion 16 / DeathBurst 32 / LightningArc 12
   - OrbitProjectile 16（或跟武器綁定常駐，不走短池）

### 2.4 取代 `get_nodes_in_group`：空間網格 / Registry

#### 建議：`EnemySpatialIndex`（autoload 或掛 Runtime）

```gdscript
class_name EnemySpatialIndex
extends Node

const CELL := 128.0  # 約等於常見武器 range 的分數
var _cells: Dictionary = {}      # Vector2i -> Array[Node]
var _enemy_cell: Dictionary = {} # instance_id -> Vector2i
var _live: Array[Node] = []      # 緊湊陣列，供需要全表時使用
var live_count: int = 0

func register(enemy: Node) -> void: ...
func unregister(enemy: Node) -> void: ...
func update_position(enemy: Node) -> void:
    # 僅當 cell 變更時搬移 Array（敵人速度有限，多數幀 no-op）

func for_each_in_radius(center: Vector2, radius: float, callable: Callable) -> void:
    var r_sq := radius * radius
    var min_c := _cell_of(center - Vector2(radius, radius))
    var max_c := _cell_of(center + Vector2(radius, radius))
    for x in range(min_c.x, max_c.x + 1):
        for y in range(min_c.y, max_c.y + 1):
            var bucket: Array = _cells.get(Vector2i(x, y), [])
            for e in bucket:
                if is_instance_valid(e) and center.distance_squared_to(e.global_position) <= r_sq:
                    callable.call(e)

func find_nearest(center: Vector2, max_range: float) -> Node2D:
    # 由近到遠擴環查 cell，或查 radius 內取 min distance_squared
    ...
```

#### 遷移對照

| 現有 API | 改為 |
|----------|------|
| `get_nodes_in_group("enemies")` 尋最近 | `EnemySpatialIndex.find_nearest` |
| 爆炸/連鎖半徑 | `for_each_in_radius` |
| 環繞刃傷害 | 小半徑 query（或 Area2D overlapping） |
| Spawner `size() >= max` | `EnemySpatialIndex.live_count` 或 `NodePool.live_count` |
| 英雄朝向每幀尋敵 | **降頻**（0.1–0.2s）或共用 Squad 級 cache |

#### 敵人 → 英雄

英雄數量 ≤ 5，可維持小陣列 `SquadManager.get_members()` 快取，**不要** 150 次 `get_nodes_in_group("heroes")` 配置新 Array；改 `SquadManager.iter_alive_heroes()` 回傳快取陣列參考。

### 2.5 其他 60fps 必做優化（Pool 以外）

#### P0 — `orbit_weapon.gd` / `orbit_projectile.gd`
- 停止每幀 sync；傷害改空間查詢或 overlapping。
- 使用 `distance_squared_to`；`hit_interval` 邏輯保留。

#### P0 — `hero.gd` `_update_facing`
- 不要每幀全圖尋敵；武器已有 target 可複用，或 10Hz 更新 facing。

#### P0 — `game_manager.gd` `emit_stats`
- 時間用 0.1s timer 刷新；`kills/xp/hp` 事件驅動。

#### P1 — `arena_background.gd`
- 改 `ParallaxBackground` / 靜態 tile / 僅相機移動超過 cell 時重畫；禁止每幀雙重 for crack。

#### P1 — 掉落物
- 合併 XP（同屏超 N 個時磁吸合併或直接加 XP）。
- `_draw` 改 Sprite2D 貼圖（專案已有 `gem_xp.png` / `coin.png` 未使用）。
- 未磁吸時不要每幀 `queue_redraw`（bob 可用 `Sprite2D.position.y = sin`）。

#### P1 — 傷害數字
- 池化 + 上限（同幀同敵最多 1 個合併數字）。
- 考慮 Label 池或 MultiMesh；避免 `ThemeDB.fallback_font` + 雙次 `draw_string` 過量。

#### P1 — 敵人渲染
- 血條用 progress 節點或受擊後短時間顯示；type 外觀用 sprite atlas（assets 已有 `enemy_*.png`）。
- `collision_mask=0` 使敵人不互撞——對 CPU 友善，但重疊坦克會「一坨」；可接受時在文件註明。

#### P2 — 子彈
- 線性子彈已用物理查詢，池化後是最好的 100 投射物方案。
- `traveled` 用 `speed * delta` 累加即可，避免每幀 `step.length()`。

### 2.6 Pooling 就緒度總評

| 面向 | 分數 (1–5) | 說明 |
|------|------------|------|
| 集中工廠入口 | 4 | `EntityFactory` 可做單一切換點 |
| 狀態重設 API | 3 | 多有 `setup`，但不完整、有 new Shape |
| 釋放協議 | 1 | 只有 `queue_free`，無 release |
| 空間查詢 | 1 | 全面 group 掃描 |
| 繪製預算 | 2 | 程序化 `_draw` 過多 |
| **總體** | **2 / 5** | **可演進，但未就緒；需 1 次「Pool + SpatialIndex」結構 PR 才能談 150/100/60** |

---

## (3) 架構與可擴充性

### P1

#### `scripts/autoload/entity_factory.gd`：工廠有了，缺「執行時世界服務」
- **問題**：工廠只負責 new；沒有 registry、pool、spatial、faction。
- **建議**：拆
  - `EntityFactory`（生成/回收）
  - `EnemyService` / `SpatialIndex`（查詢）
  - `VfxService`（傷害字、burst，可獨立限流）

#### `scripts/weapons/base_weapon.gd`：Duck typing `Resource` + `data.get`
- **問題**：可跑，但 IDE/型別檢查弱；錯字欄位靜默 fallback。
- **建議**：`var data: WeaponData`，直接 `.damage`；`data_float` 僅給 mod 用。

#### 武器行為四支腳本 vs `behavior_id`
- **問題**：`WeaponData.behavior_id` 與 scene 雙重來源；不一致時難查。
- **建議**：單一來源——scene 即行為，或 behavior_id → 自動掛 script。

#### `scripts/heroes/hero.gd` 同時承擔
- 移動、受傷、相機、武器庫、升級、尋敵朝向。
- **建議**：`CombatantStats`、`WeaponLoadout`、`DamageReceiver` 分組；相機只在 leader 組件。

#### 升級系統字串 match 散落
- `GameManager.PLAYER_UPGRADE_POOL`、`SquadManager.apply_upgrade`、`WeaponData.apply_upgrade`、`Hero.apply_personal_upgrade`。
- **建議**：`UpgradeEffect` Resource 或單一 `UpgradeApplier`，避免每加一種升級改 4 個檔。

#### `scripts/player/player.gd` 只 `extends hero.gd`
- **問題**：場景 `Player.tscn` 可能遺留；實際用 `Hero.tscn` + Squad。
- **建議**：刪冗餘或讓 Player 專職「非小隊模式」入口，避免雙重路徑。

### P2

#### `WeaponCatalog.get_weapon_data` / `SquadData.get_hero_data`：線性搜尋
- **問題**：內容少時 OK；建議 `Dictionary` id→Resource 快取於 `_init`。

#### 被動技能欄位已預留、未接線
- `HeroData.passive_id` 無執行器；擴充點清楚，缺 `PassiveRegistry`。

#### 碰撞層語意
- Layer1 英雄、Layer2 敵人；子彈 mask=2。無環境層、無 pickup 層。擴地圖碰撞時 Hero `collision_mask` 需重開。
- **建議**：`project.godot` 命名 layer（Player / Enemy / Projectile / World）。

#### 除錯場景
- `SquadSmokeTest` / `WeaponSmokeTest` 有助回歸；建議 CI 用 headless `--quit-after` 跑 smoke。

---

## (4) GDScript 慣用法品質

### P1

#### 路徑字串繼承
- `extends "res://scripts/weapons/base_weapon.gd"` 等。
- **建議**：`class_name BaseWeapon` 後 `extends BaseWeapon`，利於型別與重構。

#### `class_name` 不完整
- 有 `Enemy`、`Hero`、`WeaponData`…；武器、工廠、池無 class_name。
- **建議**：公開 API 類型都具名。

#### `has_method` / `get` 防禦過度與不足並存
- 工廠對幾乎所有 spawn 都 `has_method("setup")`（可信任場景時多餘）。
- 另一方面對 group 內節點又假設有 `radius` / `hit_radius`。
- **建議**：信任第一方場景，用型別；邊界才 duck type。

### P2

#### `base_weapon.gd` 的 `data_*` helpers
- 實用；若改 `WeaponData` 型別可刪大半。

#### `make_runtime_copy` 死碼
- 與 `duplicate(true)` 重複；應統一。

#### 魔術數字
- 冷卻初始 0.15、xp 曲線 1.25、formation 間距等應進 export / const 命名。

#### `player_controller.gd` 混用 `is_physical_key_pressed` 與 `is_key_pressed`
- 建議統一 `Input.get_vector` + InputMap action（`move_left`…），利於手把。

#### 暫停模式
- UI `PROCESS_MODE_ALWAYS` 正確；遊戲實體預設 inherit 正確。
- 池化後 inactive 節點應 `PROCESS_MODE_DISABLED` 比靠 early-return 更省。

#### 註解與文件語言
- 程式與 UI 已中文化；建議在 `EntityFactory` / `GameManager` 頂部用 10 行契約註解（誰能 pause、誰能 add_xp、Resource 是否可 mutate）。

---

## 分級清單清單（檔案:問題:具體建議）

### P0

1. **`scripts/weapons/orbit_weapon.gd`：每幀 `_sync_orbiters` + 全 orbiter `configure_orbit`：改為 dirty-only sync，平時零配置。**
2. **`scripts/projectiles/orbit_projectile.gd`：每物理幀 `get_nodes_in_group("enemies")`：改空間網格半徑查詢或 `get_overlapping_bodies`，並用 `distance_squared_to`。**
3. **`scripts/heroes/hero.gd`：每幀 `get_nearest_enemy` 做朝向：降頻或快取目標，禁止每幀全表掃描。**
4. **`scripts/weapons/base_weapon.gd` + `chain_lightning_weapon.gd` + `explosion_area.gd`：group 全掃尋敵：統一經 `EnemySpatialIndex`。**
5. **`scripts/autoload/entity_factory.gd`：熱路徑只 `instantiate`/`add_child`：引入 `NodePool.acquire/release`，預熱敵/彈/VFX/掉落。**
6. **`scripts/enemies/enemy.gd` / `projectile.gd` / `orbit_projectile.gd` / 各 VFX / pickups：死亡與生命結束 `queue_free`：改 `EntityFactory.release_*` + `pool_on_release`。**
7. **`scripts/enemies/enemy.gd` 等：`CircleShape2D.new()` 每次 setup：改 mutation既有 shape.radius，以利池化與減分配。**
8. **`scripts/autoload/game_manager.gd`：每幀 `emit_stats`：時間節流 + 事件驅動。**
9. **`scripts/arena/arena_background.gd`：每幀完整 grid/crack 重繪：改靜態/髒矩形/tile，移出熱路徑。**
10. **`scripts/pickups/pickup.gd`：每幀 `queue_redraw`：改 Sprite 或僅狀態變更時重繪；考慮掉落合併。**
11. **`scripts/heroes/hero.gd`：`_clear_weapons` + 立即 `_equip_starting_weapons`：避免 `queue_free` 殘留舊武器同幀開火（`free` 或先 disable）。**

### P1

12. **`scripts/weapons/base_weapon.gd`：`duplicate(true)` 正確隔離 `.tres`：保留並統一 `WeaponData.make_runtime_copy()`；刪死碼分叉。**
13. **`scripts/heroes/hero.gd` / `squad_manager.gd`：`hero_data`/`squad_data` 未 copy：setup 時 duplicate 或強制唯讀。**
14. **`scripts/heroes/hero.gd`：隊長死亡半屍狀態：明確停用 process/相機或延遲回收，並清空 `GameManager.player` 契約。**
15. **`scripts/heroes/squad_manager.gd`：死亡不重編 formation / 可重招同 id：定義產品規則並實作 reindex 或 dead 集合。**
16. **`scripts/pickups/pickup.gd`：只吸隊長：改小隊共享拾取。**
17. **`scripts/enemies/enemy_spawner.gd`：用 group.size 做上限：改 `live_count` O(1)。**
18. **`scripts/autoload/game_manager.gd`：連升未 `emit_stats`：補齊。**
19. **`scripts/vfx/damage_number.gd`：無上限 instantiate：池化 + 每幀生成 cap + 合併。**
20. **架構：缺 SpatialIndex / Pool 模組：在 `EntityFactory` 旁新增，勿把邏輯繼續塞進 autoload 巨石。**
21. **`scripts/player/player_controller.gd`：硬編碼 key：改 InputMap + `get_vector`。**
22. **武器/英雄尋敵 API 重複 3+ 份：收到 `CombatTargeting` 或 SpatialIndex 單一實作。**

### P2

23. **`scripts/weapons/*.gd`：字串路徑 `extends`：改 `class_name BaseWeapon`。**
24. **`scripts/resources/weapon_data.gd`：`make_runtime_copy` 未使用：與 base_weapon 對齊。**
25. **`scripts/resources/weapon_catalog.gd` / `squad_data.gd`：線性查找：建 id 索引 Dictionary。**
26. **`scripts/enemies/enemy.gd`：攻擊 `length()`：改 squared。**
27. **`scripts/ui/level_up_screen.gd`：按鈕每次重建：三卡複用。**
28. **`project.godot`：碰撞層未命名：補 layer 名稱。**
29. **assets 精靈未接上程式 `_draw`：逐步替換以減 CPU draw 與增可讀性。**
30. **`scripts/debug/weapon_smoke_test.gd`：固定幀等待：改條件式穩定判定。**
31. **升級字串分散：集中 Upgrade 管線以便新武器/新被動。**
32. **`HeroData.passive_*` 未接：加 PassiveRegistry 或標 TODO 避免偽完成感。**

---

## 建議實作順序（通往 150/100/60）

```text
Phase A — 量測（0.5 日）
  Godot Profiler：Script / Physics / Canvas item
  同屏強制 150 敵 + 自動武器，記錄 1% low fps

Phase B — 砍查詢（1–2 日）  【收益最大】
  EnemySpatialIndex + live_count
  環繞刃 / 朝向 / 武器 / 爆炸 / 連鎖 全搬家
  orbit_weapon dirty sync

Phase C — Pool（2 日）
  NodePool + EntityFactory acquire/release
  改 shape mutation、禁熱路徑 queue_free
  預熱 + 傷害字/掉落 cap

Phase D — 繪製（1 日）
  背景去每幀重繪；pickup/enemy 改 sprite；stats 節流

Phase E — 正確性收尾（0.5 日）
  清武器 free、隊長死亡契約、Resource copy 政策、小隊拾取
```

---

## 正面肯定（對抗式仍應記錄）

- **Weapon 執行時 `duplicate(true)`**：升級安全，不寫回 `.tres`。
- **`EntityFactory` 單入口**：是接 pool 的正確形狀。
- **多數實體有 `setup` 重設欄位**：池化改造成本可控。
- **線性子彈用 Area2D signal**：比 group 掃描正確且可擴到 100 彈。
- **小隊拆 `Hero` / `PlayerController` / `FollowerController` / `SquadManager`**：職責比「全塞 Player」清晰。
- **升級 pause + `waiting_for_upgrade` 旗標**：基本避免雙 UI；XP 溢出保留合理。
- **敵人 `collision_mask=0`**：避免 150 體物理互撞爆炸（刻意取捨）。

---

## 最終判定

| 維度 | 判定 |
|------|------|
| 正確性 | **可玩原型級**；Resource 武器 copy 正確；武器清除、隊長死亡、小隊拾取有中期坑 |
| 效能 / Pooling | **未達 150/100/60**；最大洞是 **group 全掃 + 無 pool + 程序化每幀繪製** |
| 架構 | **資料驅動方向對**；缺 Spatial/Pool/Upgrade 管線才能繼續長內容 |
| GDScript 品質 | **中上原型**；duck typing 與字串 extends 拖累擴充 |

**R1 結論**：不要先加更多武器/敵人數值；先做 **SpatialIndex + ObjectPool + 停掉 orbit/facing 的每幀全表掃描**。否則內容增加只會線性（甚至超線性）放大現有熱路徑。

---

*本報告為靜態對抗式審查，未在本機啟動 Godot Profiler；Phase A 量測應用實機數據修正優先序。*
