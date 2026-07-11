# R19 規模擴充交付回報

狀態：已完成實作、測試、字型重跑與 Web release 匯出。未 git commit / push。

## 玩家回饋對應

- 「環形武器後方尾翼很醜」：已重做 `orbit_projectile` 拖尾，從長直尾巴改成貼合刃體運動的短弧形能量殘光。現在使用短距離弧線、圓角接點、加算混合與由尾端透明到刃端發光的漸層，視覺語意是能量刃劃過而不是拖著尾巴。
- 「更多武器、更多英雄、隊友與武器上限值要非常多」：英雄從 5 擴到 9；新增 4 名英雄、4 把新行為武器、4 條新進化；小隊上限從 5 擴到 9，可全英雄同場。

## 新英雄與新武器

新增英雄都進入 `default_squad` 招募池，使用既有 sprite 變體與 runtime tint，不新增大量貼圖成本。

| 英雄 | 身分 / Passive | 初始武器 | 行為 |
| --- | --- | --- | --- |
| 燼焰擲彈兵 | `ember_grenadier` | `grenade_lob` | 拋物線榴彈，落點 AoE、燃燒區、進化後分裂爆破 |
| 虛空織網者 | `void_weaver` | `void_net` | 放置減速力場，進化後附加脆弱 / 吸附型區域控制 |
| 裂光狙擊手 | `rift_sniper` | `rail_lance` | 長冷卻超遠程貫通狙擊線，進化後尾端爆裂 |
| 迴響歌者 | `echo_singer` | `echo_hymn` | 週期治療脈衝、短暫全隊增傷、近身音波傷害 |

新進化：

- `grenade_lob` -> `evo_cinder_barrage`
- `void_net` -> `evo_event_horizon`
- `rail_lance` -> `evo_star_piercer`
- `echo_hymn` -> `evo_resonant_chorus`

相關 catalog / 升級池 / 定性升級 / 招募池均已接入；新武器總數達 10。

## 上限、招募與陣型

- `max_members`：5 -> 9。
- 招募節奏：新增 slot gate，後續成員依 level gate 開放，避免開局白給滿編。
- 招募權重：若實際小隊落後目標成長曲線，招募卡權重提高；仍保留非隊長升級保底與避免過度稀釋的升級池策略。
- 跟隨陣型：支援 9 人，隊長前方，8 名跟隨者採雙排 / 後弧陣型，WeaponSmoke 實測 follower 最大誤差 7.29。

## 效能護欄

新增武器均避免直接 group 掃描：

- `grenade_lob`：使用既有 projectile / explosion / hazard pool，落點爆炸與 cluster 有上限。
- `void_net`：使用 hazard pool，場域數量受 cap 控制。
- `rail_lance`：線段命中走 spatial query，目標數 capped。
- `echo_hymn`：治療與增傷直接走小隊資料，攻擊 pulse 使用 spatial query 且限制每輪命中量。

全域 pool / cap 調整：

- projectile prewarm 320。
- orbit prewarm 56。
- explosion prewarm 112，active cap 48。
- hazard prewarm 18，active cap 16。
- lightning arc prewarm 112，active cap 48。
- damage number active cap 48。
- 武器初始冷卻加入依 formation slot 與 weapon id 的 deterministic stagger，降低滿編同幀齊射尖峰。
- riftline fork 改 deferred spawn，避免物理 query flush 期間修改狀態。

## 平衡與壓力數據

`BalanceMockRun`：PASS。

- full squad time：236s。
- total DPS：317.0。
- leader DPS share：0.410。
- min HP：0.008 @ 199s；90s 前 min HP 0.685。
- boss phase two：212s；boss kill：222s。

`ArenaInstrumentationRun`：PASS。

- seed：771101。
- seconds：16.01。
- survived：true。
- kills：53。
- player HP：130 / 130。
- total damage：2121.3。
- 新武器皆有輸出紀錄：`rail_lance` 33.52 DPS、`grenade_lob` 13.19 DPS、`void_net` 6.20 DPS、`echo_hymn` 0.33 DPS。
- pool exhausted / duplicate release / foreign release：全 0。
- enemy group scans：0。
- enemy spatial queries：6113。

`StressTest`：PASS，已升級成 9 人滿編、全武器 / 全進化、150 敵、80 背景 projectile 情境。

- measured frames：411。
- avg frame：15.028 ms。
- p95 frame：22.976 ms。
- max frame：60.989 ms。
- avg FPS：66.54。
- p95 FPS：43.52。
- min FPS：16.40。
- enemy spatial queries：3378，平均 8.22 / frame。
- enemy group scans：0。
- kills：571。
- pool exhausted / duplicate release / foreign release：全 0。
- weapon triggers：所有預期武器皆 > 0。

注意：StressTest 邏輯通過，但 `STRESS_PERF_BELOW_60=true`。也就是平均已高於 60fps，但 p95 未達 16.7ms。R19 已做 stagger、pool cap、damage number cap、query cap 與滿編 HP/節奏調整；Web 真機若要把 150 敵滿編 p95 壓回 60fps，需要下一輪針對 VFX / damage text / hazard tick 進一步降頻或 LOD。

## 回歸

已跑過並通過：

- Headless project load。
- `WeaponSmokeTest`。
- `ArenaInstrumentationRun`。
- `StressTest`。
- `BalanceMockRun`。
- `PoolContractTest`。
- `GameplayCapTest`。
- `MobileInputSmokeTest`。
- R5 / R6 / R7 / R10_5 / R11 / R12 / R13 / R14 regression matrix。

已知輸出：`PoolContractTest` 仍會印出預期中的 double release warning，用於驗證 pool contract，不是本輪回歸失敗。

## 字型、素材與 Web 匯出

- `python tools/generate_walk_frames.py`：已重跑。新英雄使用既有角色 sprites + runtime tint，因此沒有額外 hero PNG 膨脹。
- `python tools/build_font_subset.py`：PASS。
  - project Han coverage：534 / 534。
  - output font bytes：1,517,152。
- Web release export：PASS。
  - `export/web/index.pck`：4,393,280 bytes。
  - `export/web/index.js`：`node --check` PASS。

## 主要改動檔案

- 新英雄資源：`resources/heroes/ember_grenadier.tres`、`void_weaver.tres`、`rift_sniper.tres`、`echo_singer.tres`。
- 新武器資源 / 場景 / 腳本：`grenade_lob`、`void_net`、`rail_lance`、`echo_hymn`。
- 核心資料：`weapon_data.gd`、`weapon_catalog.tres`、`squad_data.gd`、`default_squad.tres`。
- 小隊與視覺：`squad_manager.gd`、`hero.gd`、`player_visual.gd`。
- projectile / pool / perf：`projectile.gd`、`hazard_zone.gd`、`orbit_projectile.gd`、`entity_factory.gd`、`base_weapon.gd`。
- 測試與平衡：`weapon_smoke_test.gd`、`arena_instrumentation_run.gd`、`stress_test.gd`、`balance_mock_run.gd`、`gameplay_cap_test.gd`、`enemy_spawner.gd`。
