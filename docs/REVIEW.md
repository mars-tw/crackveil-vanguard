# Crackveil Vanguard - 第五階段視覺與效能複審（R3 修正後）

日期：2026-07-09

## 第五階段更新摘要

本輪把 `assets/sprites/` 的原創 gpt-image-2 PNG 接入 gameplay，並針對 R2 真實壓測暴露的瓶頸收斂 VFX budget。

### Sprite 套用

資料驅動欄位：

- `HeroData.sprite_path` / `HeroData.sprite_scale`
- `WeaponData.projectile_sprite_path`
- `WeaponData.orbit_sprite_path`
- `WeaponData.explosion_sprite_path`
- `WeaponData.lightning_sprite_path`
- 敵人 config 的 `sprite_path` / `sprite_scale`
- Pickup 場景的 `pickup_kind` / `sprite_path`

已替換：

- 英雄：隊長 `hero_captain.png`、守衛 `hero_guardian.png`、斥候 `hero_scout.png`
- 敵人：普通 `enemy_grunt.png`、快速 `enemy_fast.png`、坦克 `enemy_tank.png`
- 掉落物：`gem_xp.png`、`coin.png`
- 投射物：`proj_bullet.png`、`proj_blade.png`
- 爆炸/死亡特效：`fx_explosion.png`
- 雷弧：`proj_lightning.png` 以 Sprite2D segment 串接

技術做法：

- 新增 `scripts/services/sprite_loader.gd`，快取 PNG Texture；若 Godot 尚未產生 `.import`，會 fallback 到 `Image.load()`。
- `player_visual.gd`、`enemy.gd`、`projectile.gd`、`orbit_projectile.gd`、`pickup.gd`、`explosion_area.gd`、`death_burst.gd`、`lightning_arc.gd` 改用 Sprite2D。
- 幾何 `_draw()` 熱點已移除；目前只剩 arena 背景的降頻 `_draw()`。
- 敵人血條改成兩條 `Line2D`，預設隱藏，只在受傷後短時間顯示。

### VFX 效能優化

- DamageNumber 改為 Label 節點，不再每幀 `_draw()` 字串。
- DamageNumber 新增短時間/近距離合併：同一區域 0.24 秒內累加成單一浮字。
- DamageNumber 同屏 cap：64；超過則合併或跳過顯示，傷害結算不受影響。
- DeathBurst 同屏 cap：20；超過時跳過純視覺特效。
- Explosion 視覺 cap：36；超過時跳過爆炸 sprite，但範圍傷害仍永遠結算。
- LightningArc cap：32；超過時跳過純視覺雷弧。
- XP / coin pickup 視覺 cap：各 180；超過或 pool 耗盡時直接把 XP / 金幣加入 `GameManager`，資源不丟失。
- Pool 預熱收斂：damage_number 80、death_burst 28、xp_gem 220、coin 220；避免隱藏 Label/Sprite 節點塞滿場景樹。

### R3 玩法 cap 修正

Grok R3 指出第五階段初版把 visual cap 寫在 gameplay spawn 入口，會導致爆炸傷害與 XP/金幣掉落被丟棄。R3 已修：

- `EntityFactory.spawn_explosion()` 會先執行範圍傷害，再依 `EXPLOSION_CAP` 決定是否顯示爆炸 sprite。
- `ExplosionArea` 現在只負責視覺生命週期，不再扣血，避免雙重傷害。
- `spawn_xp_gem()` / `spawn_gold_coin()` 在 visual cap 滿或 pool 耗盡時直接入帳，玩家應得資源不丟。
- 純視覺項目（DamageNumber / DeathBurst / LightningArc）仍可合併、跳過或 cap。
- Poolable 視覺節點補 rotation reset，避免 pool 重用時角度殘留。

針對性測試：

```text
GAMEPLAY_CAP_EXPLOSION hp_before=80.0 hp_after=62.0 visual_skipped=true
GAMEPLAY_CAP_PICKUPS xp=254 gold=241 visual_cap_triggered=true
GAMEPLAY_CAP_PASS
```

### 壓測對比

R2 誠實壓測基準：

```text
avg_ms=35.947 p95_ms=52.166 max_ms=69.623
avg_fps=27.82 p95_fps=19.17 min_fps=14.36
```

第五階段 R3 修正後最終壓測：

```text
STRESS_RESULT enemies=150 projectiles=100 measured_frames=411 avg_ms=10.834 p95_ms=24.193 max_ms=37.470 avg_fps=92.30 p95_fps=41.33 min_fps=26.69
STRESS_COUNTERS enemy_spatial_queries=2993 queries_per_frame=7.28 enemy_group_scans=0 group_scans_per_frame=0.000 kills=814 gold=869 xp=930
STRESS_POOL_STATS={"coin":{"created":220,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":213,"in_pool":213,"live":7},"damage_number":{"created":80,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":18,"in_pool":18,"live":62},"death_burst":{"created":28,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":11,"in_pool":11,"live":17},"enemy":{"created":220,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":70,"in_pool":70,"live":150},"enemy_group_scans":0,"enemy_queries":2993,"explosion":{"created":80,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":80,"in_pool":80,"live":0},"lightning_arc":{"created":80,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":80,"in_pool":80,"live":0},"orbit_projectile":{"created":40,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":38,"in_pool":38,"live":2},"projectile":{"created":240,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":140,"in_pool":140,"live":100},"xp_gem":{"created":220,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":212,"in_pool":212,"live":8}}
STRESS_PERF_BELOW_60=true
STRESS_PASS
```

判讀：

- 平均 fps：27.82 → 92.30。
- p95 fps：19.17 → 41.33。
- min fps：14.36 → 26.69。
- Pool 契約仍乾淨：exhausted 0、duplicate_free 0、duplicate_releases 0、foreign_releases 0。
- enemy group scan 仍為 0。
- 平均已超過 60fps，但 p95/min 尚未穩定達 60；剩餘尖峰主要在 150 敵物理/碰撞、100 projectile Area2D、以及高擊殺幀的 Label/Sprite transform 更新。

### 第五階段驗證

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --quit
Godot_v4.7-stable_win64_console.exe --headless --path . --quit-after 900
Godot_v4.7-stable_win64_console.exe --headless --path . res://scenes/debug/PoolContractTest.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . res://scenes/debug/GameplayCapTest.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . res://scenes/debug/SquadSmokeTest.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . res://scenes/debug/WeaponSmokeTest.tscn
Godot_v4.7-stable_win64_console.exe --headless --fixed-fps 60 --path . res://scenes/debug/StressTest.tscn
```

結果：

- 專案載入通過。
- 主場景 900 幀通過。
- `POOL_CONTRACT_PASS`，spawn_token / double-release guard 未回歸。
- `GAMEPLAY_CAP_PASS`，爆炸傷害與 XP/金幣資源不受 visual cap 影響。
- `SQUAD_SMOKE_PASS`。
- `WeaponSmokeTest` 通過。
- `STRESS_PASS`，平均 fps 達標，p95/min 尚未達 60。

## 第四階段 R2 複審紀錄

日期：2026-07-09

## 本輪範圍

- 讀取並回應 `docs/GROK_REVIEW_R2.md`。
- 修正 pooling 重構後新引入的兩個 P0。
- 將 `StressTest` 從弱化展示負載改成真實戰鬥負載。
- 用 Godot 4.7 headless 驗證主場景、小隊、武器、pool contract 與壓測。
- 不建立 `.git`，不 commit，不 push。

## Grok R2 回應

逐點回應文件：

- `docs/CODEX_RESPONSE_R2.md`

結論摘要：

- P0-1 instance_id 重用命中表污染：採納。
- P0-2 NodePool double-release 無防護：採納。
- P1 壓測不可信：採納。
- `orbit_weapon` append null、facing 快取 active/token 驗證、deferred release 先鈍化：採納或部分採納。
- 本輪沒有反駁總稽核指定的三項；唯一保留是 deferred 前不直接改 Area2D monitoring，避免 Godot 物理 flush 限制。

## Pooling 修正

`scripts/pooling/node_pool.gd`：

- 新增 `_in_pool` set，warm 時標記、acquire 時移除、release 時寫回。
- `release()` 若發現同節點已在 pool，會記錄 `duplicate_release_count`、`push_warning`，並直接 return。
- 新增 pool owner metadata，拒絕錯池 release。
- acquire 會丟棄 free list 中已不在 `_in_pool` 的重複/髒 entry。
- `get_pool_stats()` 現在輸出 `duplicate_free`、`duplicate_releases`、`foreign_releases`、`in_pool`。

`scripts/autoload/entity_factory.gd`：

- release 入口在 deferred 前同步將 `is_active=false`，縮短殭屍窗口。
- 敵人 acquire 時發單調遞增 `spawn_token`。
- 新增真實 debug counter：`enemy_group_scans`、`enemy_queries`。
- 預熱調整為：enemy 220、projectile 240、orbit_projectile 40、explosion 80、xp_gem 600、coin 600、damage_number 1200、death_burst 500、lightning_arc 80。

## P0-1 修法

`scripts/enemies/enemy.gd`：

- 新增 `spawn_token`。
- 每次 `pool_reset()` 從 `EntityFactory` 取得新 token。
- 新增 `get_hit_token()`。

`scripts/projectiles/projectile.gd`：

- `hit_bodies` 改 key on `body.get_hit_token()`。
- 無 token 的目標才 fallback 到 `get_instance_id()`。

`scripts/projectiles/orbit_projectile.gd`：

- `hit_cooldowns` 改 key on `body.get_hit_token()`。
- 半徑傷害會跳過 `is_active=false` 的敵人。

`scripts/heroes/hero.gd`：

- 朝向快取會驗證 `is_active` 與 hit token，避免同一 pool 節點重生後被舊快取誤用。

## P0-2 修法

`NodePool.release()` 現在具備 double-release guard。針對性測試結果：

```text
POOL_CONTRACT_LINEAR token_a=1 token_b=2 reused_instance=true
POOL_CONTRACT_ORBIT token_a=3 token_b=4 reused_instance=true
POOL_CONTRACT_DOUBLE_RELEASE duplicate_releases=1 duplicate_free=0
POOL_CONTRACT_PASS
```

測試中的 warning 是預期行為，代表第二次 release 被 pool 層攔截：

```text
Pool double release ignored: projectile
```

## 壓測更新

新增/重寫：

- `scenes/debug/PoolContractTest.tscn`
- `scripts/debug/pool_contract_test.gd`
- `scripts/debug/stress_test.gd`

新版 `StressTest`：

- 維持 150 名敵人。
- 維持約 100 顆線性投射物。
- 敵人用接近實戰的速度、HP、接觸傷害、XP/金幣掉落。
- 英雄提高 HP，避免壓測被 game over 截斷。
- 敵人會死亡、掉落、回收，再補滿到 150。
- 投射物真實飛行、碰撞、命中、傷害、回收，再補滿到 100。
- 真實輸出 spatial query、enemy group scan、pool live/free/exhausted/duplicate。
- frame time 改用 `Time.get_ticks_usec()` 牆鐘量測，不再用 fixed delta 假 fps。

完整壓測結果：

```text
STRESS_INIT enemies=150 projectiles=100
STRESS_RESULT enemies=150 projectiles=98 measured_frames=411 avg_ms=35.947 p95_ms=52.166 max_ms=69.623 avg_fps=27.82 p95_fps=19.17 min_fps=14.36
STRESS_COUNTERS enemy_spatial_queries=2939 queries_per_frame=7.15 enemy_group_scans=0 group_scans_per_frame=0.000 kills=790 gold=839 xp=898
STRESS_POOL_STATS={"coin":{"created":600,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":590,"in_pool":590,"live":10},"damage_number":{"created":1200,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":806,"in_pool":806,"live":394},"death_burst":{"created":500,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":449,"in_pool":449,"live":51},"enemy":{"created":220,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":70,"in_pool":70,"live":150},"enemy_group_scans":0,"enemy_queries":2939,"explosion":{"created":80,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":80,"in_pool":80,"live":0},"lightning_arc":{"created":80,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":80,"in_pool":80,"live":0},"orbit_projectile":{"created":40,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":38,"in_pool":38,"live":2},"projectile":{"created":240,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":142,"in_pool":142,"live":98},"xp_gem":{"created":600,"duplicate_free":0,"duplicate_releases":0,"exhausted":0,"foreign_releases":0,"free":590,"in_pool":590,"live":10}}
STRESS_PERF_BELOW_60=true
STRESS_PASS
```

判讀：

- Pool 契約乾淨：exhausted 0、duplicate_free 0、duplicate_releases 0、foreign_releases 0。
- 敵人 group 熱路徑掃描為 0。
- 壓測低於 60fps：avg 27.82fps、p95 19.17fps、min 14.36fps。
- 主要瓶頸已不是 instantiate / queue_free 或敵人 group 掃描，而是高擊殺週轉下的繪製與特效更新：同時約 394 個 DamageNumber、51 個 DeathBurst、掉落物磁吸與大量 placeholder `_draw()`。

## 其他修正

- `scripts/weapons/orbit_weapon.gd`：pool 耗盡時不 append null，保持 dirty，待有空位再補 orbiter。
- `scripts/autoload/entity_factory.gd`：新增 `get_pool_live_count()`，壓測每幀不再呼叫完整 pool stats 掃 free list。

## 驗證

Godot：

- `4.7.stable.official.5b4e0cb0f`
- 官方 Windows console build，位於 `%TEMP%/codex-godot-4x/...`

命令與結果：

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --quit
```

結果：通過。

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --quit-after 900
```

結果：通過。

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . res://scenes/debug/PoolContractTest.tscn
```

結果：`POOL_CONTRACT_PASS`。

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . res://scenes/debug/SquadSmokeTest.tscn
```

結果：`SQUAD_SMOKE_PASS`，4 名英雄招募後武器都觸發。

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . res://scenes/debug/WeaponSmokeTest.tscn
```

結果：通過；目前該場景沿用小隊 smoke 腳本。

```powershell
Godot_v4.7-stable_win64_console.exe --headless --fixed-fps 60 --path . res://scenes/debug/StressTest.tscn
```

結果：`STRESS_PASS`，pool 乾淨，但真實牆鐘效能低於 60fps。

## 目前限制

- 強壓測低於 60fps。下一輪要處理 DamageNumber 合併/節流、死亡 VFX cap、掉落物合併或拾取批次化。
- `EnemySpatialIndex.get_enemies_in_radius()` 仍回傳新 Array，尚未改成 zero-allocation callback/buffer。
- 池化節點仍會 acquire/release reparent，後續可改固定 parent + visible/process/collision 切換。
- placeholder 敵人、VFX、傷害數字仍大量 `_draw()`；後續應改 Sprite2D/atlas 或 MultiMesh 類策略。

## 下一步建議

1. 第五階段先做 VFX/傷害數字預算：每幀上限、同敵同幀合併、低優先級跳過。
2. Spatial query 改 `for_each_enemy_in_radius(center, radius, Callable)` 或重用 buffer，降低 GC。
3. Pool 固定 parent，減少 reparent 成本。
4. 敵人與掉落物 placeholder 改 sprite atlas。
5. 再進入手機虛擬搖桿或視覺精修前，先把強壓測拉回 60fps。
