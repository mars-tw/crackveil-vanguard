# CODEX_RESPONSE_R4 — P0 收尾驗證回應

日期：2026-07-10  
範圍：採納 `docs/GROK_REVIEW_R4.md` 第 (4) 節 P0，收尾上一輪未完成的驗證、mock run、Web 匯出與報告。未 commit / 未 push。

## 盤點結果

上一輪已完成的 P0 主體：

- 質變升級：`riftline_fork`、`orbit_resonance`、`pulse_embers`、`chain_overload`、`magnetic_reclaim`。
- 新威脅：`ranged`、`dasher`、`spawner`；精英 `elite_distortion`；proto-Boss `veil_gatekeeper`。
- 生存曲線：90s 後 HP/傷害時間倍率、刷怪數量斜坡調整、Boss 期間降密度。
- 金幣閉環：`RiftShopScreen` 裂隙商亭，支援回血、隨機質變、暫時護盾。
- 階段勝利：`StageVictoryScreen`，Boss 死亡後可繼續無盡。
- C5 seed：`Arena.run_seed`、`--run-seed=`、`GameManager.forced_run_seed`；預設仍 `randomize()`，可注入固定 seed。

本輪補完 / 修正：

- `scripts/debug/balance_mock_run.gd` 改成 deferred 執行，避免 `_ready()` 直接 quit 在 headless 下卡住。
- `scripts/ui/rift_shop_screen.gd` 改由 `GameManager.waiting_for_shop` 狀態關閉 UI；購買失敗時不會隱藏畫面但仍暫停。
- `scripts/weapons/chain_lightning_weapon.gd` 的本次施法 used 集合改為優先使用 `get_hit_token()`，避免敵人 pool 復用時沿用 `instance_id`。
- 清掉 Web 匯出後短暫產生的未追蹤 `.uid` / sprite `.import` 側檔噪音；保留忽略的 `export/web` 匯出結果。

## 逐條回應

| R4 條目 | 處置 | 回應 |
|---|---|---|
| P0-1 質變升級包 | 採納 | 5 張質變卡已進 `SquadManager.QUALITATIVE_UPGRADES`，並由 `WeaponData.modifier_levels` 控制層數。 |
| P0-2 新敵行為 | 採納 | `ranged` 慢彈、`dasher` 三段 dash、`spawner` 死亡吐小怪皆由 config 驅動。 |
| P0-3 精英 + proto-Boss | 採納 | 52s 後每 45-60s 保底精英；3:00 固定 Boss，50% 血二階，死亡觸發階段勝利。 |
| P0-4 生存曲線 | 採納 | 90s 後縮放 HP/傷害，刷怪斜坡較平滑，Boss 期間降密度。 |
| P0-5 金幣局內用途 | 採納 | 商店每 90s 或升級後 10% 機率出現，金幣可換回血、質變、護盾。 |
| D1 星環冷卻無效 | 採納 | 無冷卻收益的星環不產生 `weapon_cooldown` 卡，改走 `orbit_resonance`。 |
| C1 spatial 查詢不濾 active | 採納 | `EnemySpatialIndex` query / compact 均濾掉 `is_active=false`。 |
| C3 每發 duplicate Dictionary | 部分採納 | `BaseWeapon` 改 stats cache；命中分裂與敵彈只在事件點建立小 dict。 |
| P1 / P2 | 暫緩 | Meta、進化、開局編制、地圖變異未納入本輪 P0 收尾。 |

## 實作清單

| id | 類別 | 效果 |
|---|---|---|
| `riftline_fork` | 質變 / 裂線 | 命中後產生 ±20° 分叉彈；裂片 50% 傷害、不遞迴、最多 2 層。 |
| `orbit_resonance` | 質變 / 星環 | 命中套 `vulnerable` 1.35s，受傷 +20%。 |
| `pulse_embers` | 質變 / 脈衝 | 爆炸後生成 1.2s 低 DPS `HazardZone`。 |
| `chain_overload` | 質變 / 雷鏈 | 末跳呼叫既有 explosion damage path 產生小爆。 |
| `magnetic_reclaim` | 質變 / 回收 | 擊殺時短距吸附近 XP。 |
| `ranged` | 敵人 | 30s 入池，停距離外，0.3s 預示後射慢彈。 |
| `dasher` | 敵人 | 55s 入池，windup → dash → recover。 |
| `spawner` | 敵人 | 45s 入池，死亡吐 2 隻不連鎖小怪。 |
| `elite_distortion` | 精英 | x3 HP、x1.3 傷、大體型；死亡掉可見大 XP。 |
| `veil_gatekeeper` | Boss | 3:00 固定出現，820 HP，50% 血環形彈 + 召 dasher。 |

## 紅線檢查

| 紅線 | 狀態 |
|---|---|
| 命中表必用 `spawn_token` | 維持。`Projectile` / `OrbitProjectile` / 雷鏈 used 集合優先 `get_hit_token()`；PoolContract 驗證重生節點 token 更新。 |
| 視覺 cap 不吞玩法 | 維持。爆炸與雷鏈小爆先結算傷害再嘗試 VFX；XP/金幣 cap fallback 保留；精英大 XP 走可見掉落或合併到既有 XP。 |
| 武器熱路徑禁掃 `get_nodes_in_group("enemies")` | 維持。`rg` 無敵人 group 掃描；武器、爆炸、hazard 走 spatial index。 |
| 新 hazard / 敵彈 / 小怪池化且 cap | 維持。`hazard_zone` pool cap 8；敵彈共用 projectile pool 並有 active cap 48；小怪受 150 enemy cap，死亡召喚不連鎖。 |
| Spawner 死亡不爆池 | 維持。死亡小怪生成前檢查 `EntityFactory.get_enemy_live_count() >= death_spawn_cap`。 |
| 熱路徑避免每發 duplicate Dictionary | 維持。武器 stats cache；分裂彈與敵彈 dict 僅在命中/發射事件建立。 |
| C5 決定性 seed | 維持。預設隨機，可用 `--run-seed=` / `Arena.run_seed` / `GameManager.forced_run_seed` 固定；mock run 固定 `424242`。 |

## Headless 驗證

Godot binary：`%LOCALAPPDATA%\Temp\codex-godot-4x\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe`

| 驗證 | 結果 |
|---|---|
| `--headless --path . --quit` | PASS，無 GDScript parse/load error。 |
| `PoolContractTest` | PASS；linear token 1→2、orbit token 3→4；double-release guard 正常。 |
| `GameplayCapTest` | PASS；爆炸 cap 下 HP 80→62；pickup cap 後 XP=254 / gold=241。 |
| `WeaponSmokeTest` | PASS；4 人招募後武器皆觸發；follow max error 7.29。 |
| `StressTest` | PASS；411 frames；avg 7.046ms、p95 14.389ms、max 37.601ms；enemy_group_scans=0；pool exhausted / duplicate / foreign release 皆 0。 |
| `BalanceMockRun` | PASS；seed=424242。 |

Stress 仍輸出 `STRESS_PERF_BELOW_60=true`，原因是 headless wall-clock 最大 frame 37.601ms 對應 min_fps 26.60；契約測試仍通過，無 pool 或 group-scan 退化。

Balance mock 摘要：

```text
BALANCE_MOCK_RESULT seed=424242 survival_time=03:50 elapsed=230 min_hp=0.008 min_hp_before_90=0.683
BALANCE_MOCK_UPGRADES={"chain_overload":1,"magnetic_reclaim":1,"max_hp":1,"orbit_resonance":1,"pickup_radius":1,"pulse_embers":1,"recruit_hero":1,"riftline_fork":2,"weapon_cooldown":2}
BALANCE_MOCK_SHOP={"random_qualitative":2}
BALANCE_MOCK_EVENTS elites_spawned=4 elites_killed=4 elite_spawn_times=[52,106,161,216] elite_kill_times=[61,115,170,225] boss_spawn_time=180 boss_phase_two_time=195 boss_kill_time=211 density_drop_during_boss=true
```

## Web 匯出

命令：

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --export-release "Web" export/web/index.html
```

結果：成功，exit code 0，無 export error；preset 仍為 single-thread Web（`variant/thread_support=false`）。匯出 pack log 已包含 `BalanceMockRun`、`HazardZone`、`RiftShopScreen`、`StageVictoryScreen`。

新 `export/web/index.pck` 大小：`1,799,332` bytes（約 1.72 MiB）。

## 接手風險

- 尚未做瀏覽器端 Playwright 實測；需在部署後確認商店、Boss 勝利 UI、敵彈碰撞與 mobile viewport。
- Stress 契約綠，但 headless wall-clock 仍有 `STRESS_PERF_BELOW_60=true`；若總稽核要求 60fps 下限，需要再做性能專項。
- Boss / 精英曲線目前以 mock run 與 debug 契約驗證，仍需真人或 Playwright 長跑確認實戰手感。
