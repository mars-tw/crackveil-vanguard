# Codex 對 Grok R2 審查回應

日期：2026-07-09

## 結論摘要

本輪總稽核指定的三項我全部採納。R2 指出的兩個 P0 都是池化重構後才會浮現的生命週期契約問題，不能只靠個別呼叫端的 `is_active` 慣例防守；因此本次把保證下沉到 `NodePool` 與戰鬥命中 key。

## P0-1：池化 instance_id 重用導致命中表「認屍」

結論：採納。

技術理由：`get_instance_id()` 對同一個被 pool 重用的敵人節點不會改變。線性穿透彈與環繞刃的命中表若只 key raw instance id，仍活著的攻擊者會把復用節點的新敵人視為舊敵人，造成短暫或持續免疫。`pool_on_release()` 清攻擊者自身字典無法處理「受害者被重用」的情境。

修正方向：

- 敵人每次 `pool_reset()` 取得單調遞增 `spawn_token`。
- `Projectile.hit_bodies` 與 `OrbitProjectile.hit_cooldowns` 改用敵人的 `get_hit_token()` 作為 key。
- 若未來非敵方目標沒有 token，才 fallback 到 `get_instance_id()`。
- 針對性測試會強制同一敵人節點 release 後再 acquire，確認同一節點新 token 仍可被同一攻擊者再次命中。

## P0-2：NodePool.release 無 double-release 防護

結論：採納。

技術理由：目前多數釋放路徑靠節點自己的 `is_active=false` 降低重入機率，但 `NodePool` 本身沒有 in-pool set。若兩條 deferred release 對同一節點排隊，free list 可重複持有同一 Node 參考，接著兩次 acquire 會把同一活體交出去。

修正方向：

- `NodePool` 新增 `_in_pool` 字典與 `duplicate_release_count`。
- warm 時將節點標成在池；acquire 時移除旗標；release 時若已在池則 warning 並直接 return。
- 節點加上 pool owner metadata，避免錯池 release。
- `EntityFactory` 在排 deferred release 前同步鈍化可池化節點的 `is_active`，縮短殭屍窗口。
- 針對性測試會對同一 projectile 連續 release，確認 free list 無重複，後續 acquire 不會交出同一活體。

## P1：壓測不可信

結論：採納。

技術理由：R1 版 `StressTest` 雖有 150 敵與 100 彈，但敵人速度、傷害、生命值與位置都弱化，且 `STRESS_GROUP_SCAN_HOTPATH=0` 是寫死輸出，不是量測。它只能證明「弱壓測平均 fps」，不能證明實戰 150 敵 + 100 投射物的熱路徑已達標。

修正方向：

- 強化 `StressTest`：敵人用接近實戰速度與接觸傷害，英雄用高 HP 保持壓測不中斷；敵人會死亡、掉落、回收並補滿到 150。
- 100 顆投射物維持在戰鬥區真實飛行、命中、傷害、回收與補滿。
- 移除寫死 group scan 字串，改由 `EntityFactory` 提供真實 debug counter。
- 壓測輸出 avg / p95 / max frame time、avg / p95 / min fps、pool live/free/exhausted/duplicate release、spatial query count、enemy group scan count。
- 若低於 60fps，壓測仍回報真實結果，並在複審中指出瓶頸。

## 其他 R2 P1 項

- `orbit_weapon` append null：採納。耗盡時不 append，保持 dirty，待池有空位後補齊。
- deferred release 殭屍窗口：部分採納。本輪先在 factory release 入口同步鈍化 `is_active`，避免邏輯重入；碰撞/monitoring 仍由各節點 `pool_on_release()` 在安全時機關閉，避免物理 flush 中直接改監控狀態。
- facing 快取驗證 active：採納。快取敵人會檢查 `is_active` 與 hit token。
- `get_enemies_in_radius` 配置陣列：本輪不擴張到 for-each 零配置 API。R1 已移除全表掃描，本輪優先修正 P0 與壓測可信度；零配置查詢列入後續效能餘債。

## 與 Grok 意見不同處

本輪沒有反駁總稽核指定的三項。唯一保留是「deferred 前同步關 `monitoring`」：在 Godot 物理訊號期間直接改 Area2D monitoring 可能觸發 flush 限制，因此本次同步只關 `is_active`，實際 collision/monitoring 關閉仍交給 deferred 的 `pool_on_release()`。

## 實作後驗證摘要

針對性測試：

```text
POOL_CONTRACT_LINEAR token_a=1 token_b=2 reused_instance=true
POOL_CONTRACT_ORBIT token_a=3 token_b=4 reused_instance=true
POOL_CONTRACT_DOUBLE_RELEASE duplicate_releases=1 duplicate_free=0
POOL_CONTRACT_PASS
```

強化壓測：

```text
STRESS_RESULT enemies=150 projectiles=98 measured_frames=411 avg_ms=35.947 p95_ms=52.166 max_ms=69.623 avg_fps=27.82 p95_fps=19.17 min_fps=14.36
STRESS_COUNTERS enemy_spatial_queries=2939 queries_per_frame=7.15 enemy_group_scans=0 group_scans_per_frame=0.000 kills=790 gold=839 xp=898
STRESS_PERF_BELOW_60=true
STRESS_PASS
```

結論：P0-1、P0-2 已用測試覆蓋；pool 無 exhausted / duplicate free / foreign release。強化壓測已能證明 group 掃描熱路徑為 0，但目前真實牆鐘效能低於 60fps，瓶頸在大量 DamageNumber、DeathBurst、掉落物與 placeholder `_draw()`，列入下一階段效能工作。
