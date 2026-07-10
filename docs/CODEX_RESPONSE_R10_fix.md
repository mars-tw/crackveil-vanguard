# R10 Fix Response

日期：2026-07-10  
基準：HEAD `4bfd7ae`，未 commit / 未 push。

## 六項修法

1. 滿場加法光暈洗白
   - `Enemy` 新增 crowd-aware glow alpha，`EntityFactory` 每 `0.24s` 以 spatial index live registry 批次刷新，不走 group scan。
   - 敵數 `<=80` 維持原 R10 讀性；`80 -> 150` 線性衰減。
   - 150 敵時：普通敵 `0.18 -> 0.0756`；精英 `0.34 -> 0.2924`；Boss `0.46` 不衰減。
   - 理由：普通敵滿場時不再堆成 cyan 霧，精英/Boss 的威脅分級仍保留。

2. zoom 1.28 迴避空間緊
   - 保留平時 `1.28` 大角色體感，新增威脅相機拉遠到 `1.12`，由 `Hero._update_camera_zoom()` 平滑過渡。
   - Boss 出場 `3.0s`、精英出場 `1.25s`、Boss 環彈 `1.55s` 觸發 `GameManager.request_camera_threat_zoom()`。
   - 選這個方案而非永久降到 `1.2`：平時不犧牲 R10.5 的角色手感，只在需要預讀 Boss/精英壓力時給視野面積。

3. scatter 與 force_magnet 互斥
   - `Pickup.force_magnet_to()` 立即清 `scatter_timer`、`drift_velocity`、`arc_velocity`，直接進強制磁吸。
   - 一般拾取仍維持 scatter 結束後才磁吸。
   - `R10_5RegressionTest` 新增 `R10_5_FORCE_MAGNET_INTERRUPT xp=7`。

4. 主選單 LOGO 殘影錯位
   - glow label 改為與主 LOGO 同 offset、同 font size，改用低 alpha 文字與較厚 outline 當柔光。
   - 不再有向下錯位的重複字層。

5. 殘響升級面板預設展開
   - 移除 `_ready()` 的 `_show_panel("meta")`。
   - `SidePanel.visible = false` 作為初始狀態；點「殘響升級」才建 panel。
   - 回歸測試改為先驗證預設收合，再 emit meta button pressed。

6. 背景星雲拼接縫
   - `tools/generate_art_assets.py` 改為週期性 value noise + 整數週期波形，重生 `nebula_layer.png`、`deep_space_gradient.png`。
   - 邊界平均差（RGBA 0-255）：nebula 左右/上下 `0.420 / 0.520`；deep-space `0.021 / 0.109`。
   - 已重跑 `python tools/generate_art_assets.py`。

## 驗證

Font subset：
- `python tools/build_font_subset.py`
- Project Han coverage：`451/451`
- Output font：`1,504,552` bytes

Debug scenes：全部 PASS。
- PoolContract、GameplayCap、MobileInputSmoke
- R5 / R6 / R7 Regression
- OrbitBladeHitRepro、WeaponSmoke、SquadSmoke、BalanceMockRun
- R10_5Regression：`R10_5_FORCE_MAGNET_INTERRUPT xp=7`、主選單預設收合與點擊展開皆通過

Stress 對比：

| Metric | R10 Art | R10.5 摘要 | R10 Fix |
|---|---:|---:|---:|
| avg_ms | 6.992 | 7.3 | 9.859 |
| p95_ms | 14.252 | 16.9 | 13.889 |
| max_ms | 35.797 | - | 21.527 |
| enemy_group_scans | 0 | 0 | 0 |
| result | STRESS_PASS | STRESS_PASS | STRESS_PASS |

Current Stress output：
- `STRESS_RESULT enemies=150 projectiles=100 measured_frames=411 avg_ms=9.859 p95_ms=13.889 max_ms=21.527`
- `STRESS_COUNTERS ... enemy_group_scans=0 group_scans_per_frame=0.000`
- pool exhausted / duplicate / foreign release：`0`
- `STRESS_PERF_BELOW_60=true` 仍為既有 min-fps 尖峰旗標；契約判定為 `STRESS_PASS`。

Web export：
- Command：`Godot_v4.7-stable_win64_console.exe --headless --path . --export-release Web export/web/index.html`
- Result：exit code `0`，無 `ERROR`，pck 生成成功。
- `export/web/index.pck`：`3,647,188` bytes
- `export/web/index.html`：`5,305` bytes

備註：Godot export 期間重新建立未追蹤 `.uid` cache 與 sprite import cache；這些生成噪音已從工作樹移除，未納入修正。
