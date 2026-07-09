# Codex Response R1 - 對 Grok R1 的逐點回應

## 立場摘要

Grok 對效能熱路徑的批評成立：目前最大風險是無 pooling、敵人全表掃描、環繞刃每幀重同步、UI/繪製噪音。第四階段採納其核心方向：新增 `NodePool`、`EnemySpatialIndex`，並把 EntityFactory 熱路徑改成 acquire/release。

## P0 回應

| # | 發現 | 結論 | 技術理由 / 處置 |
|---|------|------|-----------------|
| 1 | `orbit_weapon.gd` 每幀 `_sync_orbiters()` | 採納 | 每幀 duplicate stats、重設 shape、redraw 不必要。改成 dirty-only sync，升級或數量變化才同步。 |
| 2 | `orbit_projectile.gd` 每幀掃全敵 | 採納 | 目標負載下為 O(orbiter * enemy)。改查 `EnemySpatialIndex.for_each_in_radius()`，並關 Area2D monitoring。 |
| 3 | `hero.gd` 每幀掃全敵做朝向 | 採納 | 5 英雄時每幀 750 次距離檢查。改成 10Hz 查 spatial index。 |
| 4 | 武器尋敵、爆炸、連鎖全表掃描 | 採納 | `BaseWeapon.find_nearest_enemy()`、爆炸、雷鏈改走 `EnemySpatialIndex`。 |
| 5 | `EntityFactory` 熱路徑 instantiate/add_child | 採納 | 新增 `NodePool`，Arena 初始化時預熱；熱路徑改 acquire。 |
| 6 | 實體生命結束 queue_free | 採納 | 敵人、投射物、掉落物、傷害數字、爆炸、死亡特效、雷電弧改 release 回 pool。 |
| 7 | setup 時 `CircleShape2D.new()` | 採納 | 池化節點應重用 shape，改成取得既有 CircleShape2D 後只改 radius。 |
| 8 | `GameManager.emit_stats()` 每幀 | 採納 | 時間 UI 0.1s 節流；HP/XP/金幣/擊殺仍事件驅動。 |
| 9 | `arena_background.gd` 每幀重畫 | 採納 | 背景只在相機跨 cell 或初始化時 redraw，不再每幀畫 crack/grid。 |
| 10 | pickup 每幀 queue_redraw | 採納 | 靜止掉落不 redraw；磁吸/漂移才 redraw；生命結束回 pool。 |
| 11 | `_clear_weapons()` queue_free 競態 | 採納 | 先停 process/physics，再 `free()` 或釋放可池化子節點，避免舊武器多開一幀。 |

## P1 回應

| # | 發現 | 結論 | 技術理由 / 處置 |
|---|------|------|-----------------|
| 12 | WeaponData runtime copy 正確但 `make_runtime_copy()` 死碼 | 採納 | `BaseWeapon.setup()` 統一呼叫 `make_runtime_copy()`，文件化執行時 copy 契約。 |
| 13 | `hero_data` / `squad_data` 未 duplicate | 採納 | Hero setup 與 SquadManager 啟動時 duplicate(true)，避免未來誤改 `.tres` 記憶體資源。 |
| 14 | 隊長死亡半屍狀態 | 採納 | 隊長死亡時停 process/physics、停相機，並由 GameManager 清理 player 參照。 |
| 15 | 成員死亡不重編 formation / 可重招同 id | 採納 | 加 `recruited_once` 與 `dead_ids`，死亡後 reindex 存活成員。 |
| 16 | pickup 只吸隊長 | 採納 | 改查 SquadManager 存活成員，取最近且在拾取半徑內者。 |
| 17 | Spawner 用 group.size 做上限 | 採納 | 改使用 `EnemySpatialIndex.live_count`，O(1)。 |
| 18 | 連升未 emit_stats | 採納 | `_request_level_up()` 進入升級 UI 前 emit stats；apply 分支也保持 emit。 |
| 19 | 傷害數字無上限 instantiate | 採納 | 傷害數字池化；本輪先池化，合併/限流保留為下一步視覺優化。 |
| 20 | 缺 SpatialIndex / Pool 模組 | 採納 | 新增 `scripts/pooling/node_pool.gd`、`scripts/services/enemy_spatial_index.gd`，EntityFactory 僅調度。 |
| 21 | 玩家輸入硬編碼 key | 部分採納 | 第四階段主軸是效能。先補 InputMap actions 並用 `Input.get_vector()`；完整手把/重綁 UI 留後續。 |
| 22 | 尋敵 API 重複 | 採納 | 敵人查詢統一走 `EnemySpatialIndex`，英雄查詢走 SquadManager 存活成員快取。 |

## 其他 P1 架構意見

| 發現 | 結論 | 技術理由 |
|------|------|----------|
| `Projectile.source` / faction 預留 | 部分採納 | 目前只打 enemies 正確。加入 `can_hit()`，完整 faction 系統留到有中立/可破壞物件時。 |
| `EntityFactory` 缺世界服務拆分 | 採納 | 本輪新增 pool 與 spatial service，但不拆成過多 autoload，避免原型期過度設計。 |
| `BaseWeapon` duck typing `Resource + get` | 部分採納 | 原本使用強型別曾在 Godot class cache 首次載入踩錯。保持 Resource runtime copy，但把查詢集中在 helper，避免擴散。 |
| `behavior_id` 與 scene 雙來源 | 部分採納 | `.tres` 仍保留 `behavior_id` 供升級描述和 smoke 檢查；真正行為以 `weapon_scene` 為準。 |
| `hero.gd` 職責偏多 | 部分採納 | 後續可拆 `WeaponLoadout/DamageReceiver`；本輪只修熱路徑與正確性，不做大重構。 |
| 升級字串散落 | 部分採納 | 屬中期架構改善。第四階段不新增 `UpgradeEffect`，避免擴張風險。 |
| `scripts/player/player.gd` 殘留 | 採納 | 保留兼容 wrapper 但不再作主要路徑；文件註明主入口走 Squad/Hero。 |
| 字串路徑 extends / class_name 不完整 | 部分採納 | 可逐步改善；本輪只對新服務加 class_name，避免 Godot 首次解析風險。 |
| `has_method/get` 防禦不一致 | 部分採納 | 熱路徑減少 duck typing；資料 Resource 仍保留邊界檢查。 |

## 與 Grok 意見不同處

- 我不同意本輪應全面把 `WeaponData` 改回強型別直接欄位存取；先前 Godot 4.7 首次載入對 class cache 順序敏感，維持 `Resource` + 集中 helper 在本專案更穩。
- 我不同意第四階段同時導入完整 faction、UpgradeEffect、被動註冊器；這些是擴內容架構，不是 150 敵 + 100 投射物的主要瓶頸。
