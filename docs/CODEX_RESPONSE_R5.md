# Codex 對抗再審 R5 回應

日期：2026-07-10  
範圍：依使用者指定，修 S1、S2、E1、Q1、Q3、Q4、Q5，並補 R5 regression 驗證。未 git commit / push。

## 總結

R5 對 R4 的主判定採納：方向正確，但商店失敗路徑、敵彈 cap、fork/hazard 預算與磁暴綁單武器都會在實戰放大。這輪已把指定 P0/P1 全部落成可驗證修正。

未納入本輪的 R5 項目會列為「未採納/後續」，不把 mock 或文件口徑當成真實 Arena 平衡證明。

## 指定 P0

| ID | R5 判定 | 本輪回應 |
|----|---------|----------|
| S1 滿血買裂隙急救卡死感 | 採納 | `GameManager._build_shop_options()` 會標註 `enabled=false`、原因「全隊已滿血」；`RiftShopScreen` 顯示原因並 disable；後端 `apply_shop_purchase()` 也重新判斷，不扣金、不關店。 |
| S2 滿質變買偏壓改裝卡死感 | 採納 | `SquadManager.has_available_qualitative_upgrade()` 共用質變池檢查；商店無可套用質變時 disable 並顯示「沒有可套用的質變」；後端同樣保護。 |
| E1 敵彈 cap 吞 Boss 環彈 | 採納 | `ENEMY_PROJECTILE_CAP` 由 48 調到 72；Boss 環彈用 `priority="boss"`；cap 滿時優先回收最舊一般敵彈，不回收 Boss 彈。Boss 14 發 regression 已驗證完整。 |

## 指定 P1

| ID | R5 判定 | 本輪回應 |
|----|---------|----------|
| Q1 fork 扇出佔主 projectile 池 | 採納 | 新增 `fork_projectile` 子池與 `FORK_PROJECTILE_CAP=48`；fork 使用 `spawn_fork_projectile()`，主 projectile 池不會被碎彈打空。 |
| Q2 fork 每命中新 Dictionary | 部分採納 | fork stats 改為每顆主彈 setup 時快取，命中時只更新 `pierce` 欄位；敵彈/雷鏈事件 dict 仍列後續。 |
| Q3 hazard cap 滿靜默 null | 採納 | `EntityFactory.spawn_hazard_zone()` 改為 active list + LRU，cap 滿時回收最舊 hazard，新的餘燼會出。 |
| Q4 hazard 每幀 queue_redraw | 採納 | `HazardZone` 只在 setup 時 queue_redraw；淡出改走 `modulate.a`，不再每幀重繪 CanvasItem。 |
| Q5/Q6 磁暴綁斥候且每殺掃武器 | 採納 | 新增 `GameManager.magnetic_reclaim_enabled` run flag；取得磁暴後升為局級旗標，死亡不失效；敵人死亡只查 run flag，不掃 squad 武器。 |

## R5 其他項目

| ID | 回應 |
|----|------|
| E2 敵彈與玩家彈共用池 | 部分採納：fork 已獨立子池，敵彈 cap 提升並保 Boss；未拆敵彈獨立池。 |
| E3 spawner parent 當幀仍占 cap | 未採納；偏保守少生，非本輪指定。 |
| E4 精英可見 XP cap fallback | 未採納；仍是後續紅線灰區。 |
| E5 精英保證質變掉落 | 未採納；設計範圍外。 |
| E6 精英 cap 到點整窗消失 | 未採納；R5 有標 P0，但本輪使用者指定 P0 未包含，需下輪處理。 |
| E7 Boss cap 滿延後 | 未採納；現行每幀重試仍較安全。 |
| E8 精英 AI 仍像 tank | 未採納；內容設計後續。 |
| S3 180s 商店撞 Boss | 未採納；需另排 Boss/shop 時刻表。 |
| S4 護盾文案未寫時長 | 未採納。 |
| S5 game over 未清 waiting_for_shop | 未採納。 |
| C1 BalanceMock 不是真實 Arena | 採納為限制；本輪仍跑 mock，但不把它宣稱為真實平衡證明。 |
| C2 Boss HP 文件口徑不一致 | 採納為文件問題；本輪回報以程式 1500 HP 為準。 |
| B1 商店質變不寫 GameManager.upgrade_counts | 未採納；實際層數以 `WeaponData.modifier_levels` 控制。 |
| B2 `upgrade_weapon` 不檢查 can_apply | 採納：`base_weapon.apply_data_upgrade()` 現在回傳 bool 並先檢查 `can_apply_upgrade()`。 |
| B3 階段勝利缺 build 摘要 | 未採納。 |
| B4 fixed seed | 維持成立。 |

## 驗證

新增：

- `scripts/debug/r5_regression_test.gd`
- `scenes/debug/R5RegressionTest.tscn`

R5 regression headless 結果：

```text
R5_SHOP_HEAL_DISABLED reason=全隊已滿血
R5_MAGNETIC_RUN_FLAG magnetized=true
R5_SHOP_QUALITATIVE_DISABLED reason=沒有可套用的質變 applied=5
R5_ENEMY_PROJECTILE_BOSS_RESERVED boss=14 normal=58 reclaims=14
R5_FORK_BUDGET active=48 cap_skips=24 main_exhausted=0
R5_HAZARD_LRU_REDRAW live=8 reclaims=1 redraws=2
R5_REGRESSION_PASS
```

既有 debug 場景：

- `PoolContractTest` PASS
- `GameplayCapTest` PASS
- `WeaponSmokeTest` PASS
- `SquadSmokeTest` PASS
- `MobileInputSmokeTest` PASS
- `BalanceMockRun` PASS
- `StressTest` PASS

Stress 摘要：

```text
STRESS_RESULT enemies=150 projectiles=100 measured_frames=411 avg_ms=7.486 p95_ms=14.519 max_ms=20.380
STRESS_COUNTERS enemy_spatial_queries=2940 enemy_group_scans=0
projectile.exhausted=0 fork_projectile.exhausted=0 hazard_zone.exhausted=0
STRESS_PERF_BELOW_60=true
STRESS_PASS
```

`STRESS_PERF_BELOW_60=true` 是既有效能門檻訊號，未造成測試失敗；本輪未宣稱 Web p95 已穩達 60fps。

## 紅線確認

- spawn token 命中表未改，仍由敵人 `get_hit_token()` 驅動。
- 武器熱路徑未新增 `get_nodes_in_group("enemies")`；fork/hazard 仍走 factory/spatial。
- Boss 敵彈不再因一般 ranged 彈滿 cap 缺角。
- fork 子彈池化並有 cap，不會把主 projectile 池耗盡。
- hazard 池化與 cap 維持，cap 滿改 LRU，不無上限 instantiate。
- 磁暴改 run flag 後，擊殺路徑不掃 squad weapon modifier。

## 後續風險

- E6 精英 cap 到點消失仍未修。
- E4 精英大 XP 在極端 cap 下仍可能靜默 fallback。
- S3 180s 商店與 Boss 撞時刻仍未修。
- BalanceMock 仍是紙上 mock，不是真實 Arena 平衡插樁。
