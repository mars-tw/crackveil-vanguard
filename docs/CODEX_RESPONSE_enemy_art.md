# Crackveil Vanguard — CC0 敵人美術強化回報

日期：2026-07-13；Godot：`4.7.stable.official.5b4e0cb0f`；目標：Web。

## 基線

- 任務指定 HEAD `0774bfa`，實際乾淨工作樹 HEAD 是 `5d082e4`（其上一筆才是
  `0774bfa`，多了一筆 README 封面圖變更）。沒有 reset、commit 或 push；本輪以
  實際 HEAD `5d082e4` 做 A/B 基線。
- 未修改 HEAD 的隔離 Web 匯出 `index.pck`：`5,099,936 bytes`。

## 採用素材與授權

三個 OpenGameArt 頁面均在來源頁明示 **CC0**，與本 repo 的 MIT 發行相容。
作者、原始檔名、逐檔 SHA-256、來源到衍生檔對照與 CC0 連結完整記在
`assets/CREDITS.md`；原始下載只留在 gitignored `tools/asset_sources/`。

| CC0 來源 | 作者 | 遊戲內用途 |
| --- | --- | --- |
| [Top Down Cultist Creature](https://opengameart.org/content/top-down-cultist-creature) | Sean Noonan | grunt 的 6 個來源步態幀 |
| [Top Down Tentacle Creature](https://opengameart.org/content/top-down-tentacle-creature) | Sean Noonan | tank 眼球觸手、Boss 齒口觸手，各 6 幀 |
| [Animated Walk-Cycle Monsters + Hijabi from Eman Quest](https://opengameart.org/content/animated-walk-cycle-monsters-hijabi-from-eman-quest) | Night Blade | fast 甲蟲、split 水晶、field 蕈菇、swift 螃蟹，各 4 幀 |

未採用：Warlock's Gauntlet 的俯視動畫雖完整但為 CC-BY 3.0，不符合本輪 CC0
硬條件；`Top Down Simple Monsters` 雖為 CC0，但只有靜態原型圖，辨識與動態都
不足；Hand-Drawn Square Characters 為 CC0／八方向，但方塊角色語彙與現有
英雄衝突，沒有硬換。未採用候選不進 `assets/`／pck。

## 敵人前後

| 敵人 | 之前 | 現在 |
| --- | --- | --- |
| grunt | 單一紅色人形輪廓＋程式 lean | 暗紅盤根邪教生物，真實來源步態 |
| fast | 紅色尖獸 | 琥珀甲蟲，橫向腿部步態清楚 |
| tank | 裝甲人形／也被大量重用 | 紫紅單眼觸手，寬幅重量輪廓 |
| split 精英 | tank 換綠 tint＋三角標 | 發光裂晶，仍保留綠色與三角語意 |
| field 精英 | tank 換青 tint＋力場方標 | 青色孢蕈，仍保留力場環與方標 |
| swift 精英 | tank 換橘 tint＋雙箭頭 | 橘色多足螃蟹，仍保留雙箭頭／衝刺預警 |
| Boss | 放大的 tank | 專屬齒口觸手，維持大型、雙層紫光與 Phase 2 紅熱 |

`tools/process_enemy_cc0_assets.py` 可決定性重建遊戲用衍生物：來源 alpha 清理、
跨幀 union crop、透明 `96x96` canvas、裂隙中性亮度 ramp、2px 深梅色外描邊、
最多 48 色 palettize；runtime 再乘既有 `body_color`，因此普通敵維持暗紅／餘燼
家族，精英維持綠／青／橘發光碼，Boss 維持大型紫色危機層級。

`AnimatedSprite2D` 仍沿用原 cache 與命名管線。高密度 grunt/fast/tank 取來源中
兩個真實 walk 幀，維持原 Stress 熱路徑；低數量精英取 4 幀、Boss 取 6 幀。
mobile LOD 把精英／Boss 降為 2 walk 幀與 5 fps。特殊幀採首次出現時 lazy load，
避免把罕見 Boss 細節的常駐成本乘上 150 隻一般怪。

## Gameplay／效能紅線

- 沒有改 HP、速度、傷害、半徑、掉落、權重、spawn 節奏、cap 或 RNG 次數。
- `spawn_token`、碰撞半徑與普通三型 stats 由新增 EnemyArtRegressionTest 鎖住。
- 沒有新增 group scan；最終 `R11` 與兩檔 Stress 皆為
  `enemy_group_scans=0`。
- 仍使用 EntityFactory／NodePool；兩檔 Stress 的 exhausted、duplicate release、
  foreign release 全為 0。

## 大小

- 舊敵人 base＋generated PNG：`317,063 bytes`。
- 新 7 個 base＋48 個 idle/walk PNG，共 55 張：`158,128 bytes`。
- 原始 PNG 層面淨減 `158,935 bytes`；所有遊戲用圖皆 `96x96`，來源包不進 pck。
- 最終 Web `index.pck`：`4,934,168 bytes`；相對實際 HEAD 基線減少
  `165,768 bytes`（`-3.25%`），低於 `1.5 MiB` 增量預算；SHA-256：
  `3F3682597C563C86AD9C47E794B56A6163DB6D59588D3B20706C21DC919D821F`。

## Stress

固定 seed `52002`；初始化 150 enemies、80 background projectiles、11 個武器槽，
量測 411 幀。共享主機同時有兩個 09:35 起的既存 Godot 程序，幀時間在多輪間由
`7 ms` 到 `132 ms` 大幅漂移，因此採最終 candidate 與緊鄰的未修改 HEAD
時間控制組，不宣稱真機 60fps。

| 場景 | 最終 candidate avg / p95 / max | 緊鄰 HEAD 控制 avg / p95 / max | correctness |
| --- | --- | --- | --- |
| Desktop 1280x720 | `76.458 / 144.030 / 221.389 ms` | `86.421 / 184.143 / 433.904 ms` | `STRESS_PASS` |
| Mobile LOD 390x844 | `48.211 / 87.032 / 192.776 ms` | `92.780 / 186.456 / 240.331 ms` | `STRESS_PASS` |

兩檔最終 candidate 都輸出 `STRESS_PERF_BELOW_60=true`；同時段 A/B 沒有回退，
但這只是共享主機 headless 守門，不替代低階 Android／iOS 實機 profiling。

## 最終守門

- `--headless --path . --quit`：PASS。
- EnemyArt、R14、M1、M2、M3、M4、R5、R6、R7、R10_5、R11、R12、R13：PASS。
- MobileInput、PoolContract、GameplayCap、Squad、Weapon、Orbit repro、Balance、
  Arena instrumentation：PASS。合計 21 個 debug scene 全綠。
- 字型重建：PASS；專案漢字 `563/563`、總輸入碼點 `3,279`，subset
  `1,517,152 bytes`。
- Web release export：PASS（Godot exit `0`）；必要 6 檔齊全，
  `node --check export/web/index.js` PASS，PCK 亦確認含新敵人與 subset font 資源。
- 沒有 git commit／push。
