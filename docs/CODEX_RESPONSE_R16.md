# R16 Response

日期：2026-07-11  
基準：HEAD `49817a1`，未 commit、未 push。

## 交付摘要

R16 已完成玩家手機實玩回饋與 Grok R15 修正。重點是把手機操作從固定小搖桿改成更大的動態搖桿、把角色移動從單純 bob 改成真正循環步態、補上擊殺與隊長技爽度，並修掉 `Engine.time_scale` 多來源競態與 844x390 橫式 modal 溢出。

## 玩家回饋修正

1. 手機虛擬搖桿
   - `VirtualJoystick` 改為動態中心：觸點落下處就是搖桿中心，拖曳方向控制。
   - 手機直式視覺半徑依設定為螢幕寬 `22% / 25% / 29%`，觸控熱區固定為視覺區 `1.3x`。
   - 死區降到 `0.045`，輸入曲線提高小位移靈敏度。
   - 暫停設定頁新增搖桿大小滑桿：小 / 中 / 大，透過 `PlayerSettings` 持久化。
   - `MobileInputSmokeTest` 新增半徑與熱區比例回歸。

2. 角色與敵人步態
   - 新增 `tools/generate_walk_frames.py`，用 PIL 從既有 sprite 決定性產生步態 PNG。
   - 英雄產出 idle 2 幀、walk 4 幀；敵人產出 idle 1 幀、walk 2 幀。
   - `PlayerVisual` / `Enemy` 使用 `AnimatedSprite2D` 播放 idle / walk，移動時循環走路、停止時回 idle，播放速率依速度映射。
   - `R11RegressionTest` 已補 frame count 與 walk state 驗證。

3. 爽度加強
   - 敵人死亡新增短暫屍體殘影淡出，走 `EntityFactory` pooled `CorpseGhost`，避免即時配置。
   - 隊長技命中時 HUD 觸發 0.05s 全屏白色邊緣閃。
   - XP 寶石快速連撿時 pickup 音高遞升，連撿中斷後重置。

## Grok R15 修正

1. `time_scale` 多來源競態
   - `GameManager` 新增 owner/token stack：`acquire_time_scale()` / `release_time_scale()`。
   - hit-stop、升級慢動作等來源都持有 token；釋放順序錯亂或 stale token 不會把時間比例錯誤還原。
   - run start、死亡、boss kill、升級套用會清理 owner，避免卡慢速。
   - `R13RegressionTest` 新增 hit-stop 疊 level slow-mo 的釋放回歸。

2. 844x390 橫式 modal
   - `GameOverScreen`、`StageVictoryScreen` 改為橫式雙欄與 ScrollContainer，內容不再溢出。
   - `RiftShopScreen` 卡片區新增 ScrollContainer，窄高橫式下卡片高度與欄寬收斂。
   - `R14RegressionTest` 新增 844x390 戰內商店、勝利、結算 modal 覆蓋。

## 驗證

- Headless load：`--headless --path . --quit`，exit `0`。
- Font subset：掃描 project files `126`，Han coverage `482/482`，輸出字型 `1,513,724` bytes。
- 回歸全綠：
  - `PoolContractTest` PASS
  - `GameplayCapTest` PASS
  - `MobileInputSmokeTest` PASS
  - `SquadSmokeTest` PASS
  - `WeaponSmokeTest` PASS
  - `R5RegressionTest` PASS
  - `R6RegressionTest` PASS
  - `R7RegressionTest` PASS
  - `R10_5RegressionTest` PASS
  - `R11RegressionTest` PASS
  - `R12RegressionTest` PASS
  - `R13RegressionTest` PASS
  - `R14RegressionTest` PASS
  - `BalanceMockRun` PASS
  - `ArenaInstrumentationRun` PASS
- Stress：`STRESS_PASS`
  - `avg_ms=11.972`
  - `p95_ms=15.758`
  - `max_ms=26.016`
  - `enemy_group_scans=0`
  - pool exhausted / duplicate / foreign release 全為 `0`
  - corpse ghost live cap 命中 `24`，未 exhausted。
- Web export：
  - command：`--headless --path . --export-release "Web" "export/web/index.html"`
  - exit `0`
  - `export/web/index.pck`：`6,588,576` bytes
  - `export/web/index.html`：`5,305` bytes
  - 匯出產生的 `.gd.uid` 與 sprite `.png.import` cache sidecar 已清掉。

## 主要檔案

- `scripts/ui/virtual_joystick.gd`
- `scripts/ui/hud.gd`
- `scripts/autoload/player_settings.gd`
- `scripts/player/player_visual.gd`
- `scripts/enemies/enemy.gd`
- `scripts/autoload/entity_factory.gd`
- `scripts/autoload/game_manager.gd`
- `scripts/heroes/hero.gd`
- `scripts/pickups/pickup.gd`
- `scripts/ui/game_over_screen.gd`
- `scripts/ui/stage_victory_screen.gd`
- `scripts/ui/rift_shop_screen.gd`
- `scripts/debug/mobile_input_smoke_test.gd`
- `scripts/debug/r11_regression_test.gd`
- `scripts/debug/r13_regression_test.gd`
- `scripts/debug/r14_regression_test.gd`
- `scripts/vfx/corpse_ghost.gd`
- `scenes/vfx/CorpseGhost.tscn`
- `tools/generate_walk_frames.py`
- `assets/sprites/generated/*.png`
