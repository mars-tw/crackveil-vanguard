# R11 Response

日期：2026-07-10  
基準：HEAD `e055381`，工作區未 commit / 未 push。

## 盤點與補完

R11 A-D 主要實作已由上一段 session 留在工作區：隊長三武器、新迴旋鏢/追蹤飛彈、程序化移動動畫、視覺放大、開場密度、combo pulse、kill thump、升級時緩、R11RegressionTest、WeaponSmoke/Balance/Stress 更新皆已接線。

本輪補完項：
- 補正 C 的紅線：`riftline_emitter` 與 `orbit_blades` 的既有 projectile hit radius 保持原值，只保留 `sprite_scale`、glow、trail 的視覺放大。
- 重跑 `tools/generate_placeholder_audio.py`，確認 `combo.wav` 與 `kill_thump.wav` 生成。
- 重跑 `tools/build_font_subset.py`，確認 R11 新中文名覆蓋。
- 清除 Godot export 產生的 `.gd.uid` 與 sprite `.png.import` cache 噪音。
- 寫入本報告。

## A. 隊長武裝與新武器

定案 loadout：
- `rift_captain`：`riftline_emitter` + `orbit_blades` + `arc_chain`
- `orbit_guard`：`rift_shield_boomerang`
- `arc_scout`：`rift_seeker_missiles`
- `weapon_catalog`：三把旗艦武器進 starting pool；六把武器都在 available pool。

新武器：
- `rift_shield_boomerang`：單發高寬刃，`damage=13`、`cooldown=1.36`、`range=560`、`speed=455`、`pierce=3`，飛出到 `52%` range 後返場；`boomerang_rebound` 讓返場可二次命中，進化為 `evo_razor_bulwark`。
- `rift_seeker_missiles`：雙發導引，`damage=9`、`cooldown=1.08`、`range=680`、`speed=370`、`homing_turn_rate=5.8`、`retarget_radius=620`；`missile_guidance` 提高導引，進化為 `evo_hunter_swarm`。

升級池處理：
- 新增 `boomerang_rebound`、`missile_guidance` 與兩個進化定義。
- 隊長武器升級權重 `1.35`，隊友武器 `0.82`，進化後數值升級權重降到 `35%`。

## B. 程序化動畫

英雄：
- `player_visual.gd` 新增 bob、傾斜、`flip_h`、呼吸、受擊 squash。
- `hero.gd` 改為將面向方向交給 Visual，不再直接旋轉整個 visual。

敵人：
- `enemy.gd` 新增 per-type motion profile：boss/tank 慢且穩、fast/dasher 高頻 bob、ranged 中頻。
- 受擊觸發 squash，移動時依速度方向翻面與傾斜。
- pool release 重置 visual transform，避免重用殘留。

## C. 尺寸與判定表

英雄只放大視覺，`hit_radius` 未改。

| Hero | Before sprite_scale | R11 sprite_scale |
|---|---:|---:|
| `rift_captain` | 1.18 | 1.48 |
| `orbit_guard` | 1.15 | 1.42 |
| `arc_scout` | 1.13 | 1.40 |
| `line_mender` | 1.12 | 1.38 |
| `pulse_artificer` | 1.12 | 1.38 |

既有武器碰撞半徑保持原值；放大走 sprite/glow/trail。

| Weapon | Visual before | R11 visual | 判定 |
|---|---:|---:|---|
| `riftline_emitter` | sprite 1.00 | sprite 1.45 | `projectile_radius` 4.5 不變 |
| `orbit_blades` | sprite 1.22 | sprite 1.56 | `projectile_radius` 10.5 不變 |
| `arc_chain` | sprite 1.00 / lifetime 0.24 | sprite 1.35 / lifetime 0.28 | 無 projectile radius |
| `pulse_bloom` | sprite 1.00 | sprite 1.18 | `area_radius` 82 不變 |

敵人放大視覺，`radius` 未改；同時提高 HP 抵消開場密度與隊長三武器。

| Enemy | Before scale | R11 scale | Radius |
|---|---:|---:|---:|
| normal | 1.00 | 1.30 | 13 |
| fast | 1.00 | 1.25 | 10 |
| tank | 1.00 | 1.36 | 20 |
| ranged | 1.05 | 1.30 | 12 |
| spawner | 0.92 | 1.22 | 18 |
| dasher | 1.08 | 1.30 | 11 |
| elite base | 1.25 | 1.56 | 28 |
| boss | 1.58 | 2.08 | 34 |

## D. 爽感與平衡

爽感：
- 開場 `0-10s` 每波 2 隻、`10-30s` 每波 3 隻，spawn interval 前 30 秒提高到 `0.42 -> 0.20s` 下限。
- 每 10 combo 觸發 fullscreen radial pulse、combo SFX pitch 遞升、death burst、短 hit impact。
- 每次擊殺播放 `kill_thump`，boss/elite/normal 有不同 pitch。
- 升級進場前 `0.3s` real-time slow motion，然後才打開升級暫停 UI；死亡、升級套用、boss kill 都重置 `Engine.time_scale`。
- 掉落 scatter 提高，讓擊殺噴發更明顯。

平衡：
- 普通/fast/tank/ranged/spawner/dasher HP 約提高 16-24%，boss HP `1500 -> 1950`。
- 時間 scaling 從 90s 提前到 60s，倍率 `+0.055/min`。
- Boss 期間 spawn density 降到約 `45%`，避免三武器隊長與 boss 壓力疊成不可讀。
- Balance mock 以 leader DPS share 驗證隊長旗艦定位：最終 `leader_dps_share=0.643`。

## 驗證

Headless load：
- `Godot_v4.7-stable_win64_console.exe --headless --path . --quit`
- exit `0`

Debug scenes：`scenes/debug/*.tscn` 共 13 個，全 PASS。
- `BalanceMockRun`
- `GameplayCapTest`
- `MobileInputSmokeTest`
- `OrbitBladeHitRepro`
- `PoolContractTest`
- `R10_5RegressionTest`
- `R11RegressionTest`
- `R5RegressionTest`
- `R6RegressionTest`
- `R7RegressionTest`
- `SquadSmokeTest`
- `StressTest`
- `WeaponSmokeTest`

R11Regression：
- `R11_LOADOUT captain=riftline+orbit+chain guard=boomerang scout=missiles`
- `R11_NEW_WEAPONS boomerang_hp 140.0->114.0 missile_hp 120.0->84.0`
- `R11_ANIMATION leader_y 0.28->0.04 tilt=0.000 enemy_y 0.00->-0.25`
- `enemy_group_scans=0`

WeaponSmoke：
- `WEAPON_SMOKE_FOLLOW_MAX_ERROR=7.29`
- counts：`rift_captain:riftline_emitter=5`、`rift_captain:orbit_blades=27`、`rift_captain:arc_chain=3`、`orbit_guard:rift_shield_boomerang=4`、`arc_scout:rift_seeker_missiles=4`、`pulse_artificer:pulse_bloom=2`

BalanceMock：
- seed `424242`
- survival `03:50`
- `min_hp=0.154 @ 213s`
- `min_hp_before_90=0.746`
- `leader_dps_share=0.643`
- `total_dps=246.0`
- elites `4/4` killed，boss phase two `201s`，boss kill `213s`

Stress 對比：

| Metric | R10 Art | R10 Fix | R11 final |
|---|---:|---:|---:|
| avg_ms | 6.992 | 9.859 | 6.938 |
| p95_ms | 14.252 | 13.889 | 14.639 |
| max_ms | 35.797 | 21.527 | 32.100 |
| enemy_group_scans | 0 | 0 | 0 |
| result | PASS | PASS | PASS |

R11 Stress final：
- `STRESS_RESULT enemies=150 projectiles=100 measured_frames=411 avg_ms=6.938 p95_ms=14.639 max_ms=32.100 avg_fps=144.14 p95_fps=68.31 min_fps=31.15`
- `STRESS_COUNTERS enemy_spatial_queries=1302 queries_per_frame=3.17 enemy_group_scans=0 group_scans_per_frame=0.000 kills=330 gold=294 xp=304`
- pool exhausted / duplicate_free / duplicate_releases / foreign_releases：全 `0`
- `STRESS_PERF_BELOW_60=true` 保留既有 min-fps 尖峰旗標；契約結果為 `STRESS_PASS`。

紅線快檢：
- spawn token：`PoolContractTest` linear/orbit token 重用檢查 PASS。
- cap：`GameplayCapTest`、`StressTest` 全 PASS，Stress 無 pool exhausted。
- 無敵群 group 掃描：R11/Stress 均 `enemy_group_scans=0`。
- pool：Stress duplicate/foreign release 全 `0`；`PoolContractTest` 的 double release warning 是刻意驗證 guard。
- deterministic seed：R11 `seed(11011)`、Balance `424242`、歷輪 seed 回放測試仍 PASS。

## 資產與匯出

Audio：
- `combo.wav`：10,628 bytes
- `kill_thump.wav`：7,100 bytes

Font subset：
- Project Han chars：`471`
- coverage：`471/471`
- output font：`1,506,492` bytes

Web export：
- command：`Godot_v4.7-stable_win64_console.exe --headless --path . --export-release Web export/web/index.html`
- result：exit code `0`
- `export/web/index.pck`：`3,689,368` bytes
- `export/web/index.html`：`5,305` bytes
- export warning 只有 Godot `.uid` cache 重建；生成 cache 已清理。

## 接手 Commit 注意

應納入的新檔：
- `assets/audio/combo.wav`
- `assets/audio/combo.wav.import`
- `assets/audio/kill_thump.wav`
- `assets/audio/kill_thump.wav.import`
- `resources/weapons/rift_shield_boomerang.tres`
- `resources/weapons/rift_seeker_missiles.tres`
- `scenes/weapons/BoomerangWeapon.tscn`
- `scenes/weapons/HomingMissileWeapon.tscn`
- `scripts/weapons/boomerang_weapon.gd`
- `scripts/weapons/homing_missile_weapon.gd`
- `scenes/debug/R11RegressionTest.tscn`
- `scripts/debug/r11_regression_test.gd`
- `docs/CODEX_RESPONSE_R11.md`

不要納入：
- `scripts/**/*.gd.uid`
- `assets/sprites/*.png.import`
- `.godot/` cache

本輪已明確遵守：未執行 `git commit` / `git push`。
