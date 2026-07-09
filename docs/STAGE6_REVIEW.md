# 第六階段複審：手機控制與開源前置

日期：2026-07-09

## 實作摘要

- 新增左下虛擬搖桿：`scripts/ui/virtual_joystick.gd`。
- `PlayerController` 同時讀取鍵盤與 `GameManager.touch_move_vector`，兩種輸入可共存。
- `HUD` 改為響應式布局，手機 / 觸控環境顯示虛擬搖桿，桌機預設隱藏。
- 右上暫停按鈕沿用 `GameManager.toggle_pause()` / `set_manual_pause()`。
- 升級三選一卡片與結算面板改為依 viewport 直式 / 橫式重排。
- 新增 `MobileInputSmokeTest`，驗證直式布局、搖桿拖曳移動、釋放歸零、暫停按鈕。
- 新增 `README.md`、`LICENSE`、`.gitignore`，準備開源。

## 主要檔案

- `scripts/ui/virtual_joystick.gd`
- `scripts/ui/hud.gd`
- `scripts/ui/level_up_screen.gd`
- `scripts/ui/game_over_screen.gd`
- `scripts/heroes/player_controller.gd`
- `scripts/autoload/game_manager.gd`
- `scripts/debug/mobile_input_smoke_test.gd`
- `scenes/debug/MobileInputSmokeTest.tscn`
- `README.md`
- `LICENSE`
- `.gitignore`

## 驗證結果

Godot 版本：

```text
4.7.stable.official.5b4e0cb0f
```

Headless 載入：

```text
Godot_v4.7-stable_win64_console.exe --headless --path . --quit
PASS
```

長跑載入：

```text
Godot_v4.7-stable_win64_console.exe --headless --path . --quit-after 900
PASS
```

Pool contract：

```text
POOL_CONTRACT_LINEAR token_a=1 token_b=2 reused_instance=true
POOL_CONTRACT_ORBIT token_a=3 token_b=4 reused_instance=true
POOL_CONTRACT_DOUBLE_RELEASE duplicate_releases=1 duplicate_free=0
POOL_CONTRACT_PASS
```

Gameplay cap：

```text
GAMEPLAY_CAP_EXPLOSION hp_before=80.0 hp_after=62.0 visual_skipped=true
GAMEPLAY_CAP_PICKUPS xp=254 gold=241 visual_cap_triggered=true
GAMEPLAY_CAP_PASS
```

Squad smoke：

```text
SQUAD_SMOKE_INITIAL_COUNT=3
SQUAD_SMOKE_RECRUIT_COUNT=4
SQUAD_SMOKE_FOLLOW_MAX_ERROR=7.29
SQUAD_SMOKE_PASS
```

Weapon smoke：

```text
WEAPON_SMOKE_INITIAL_COUNT=3
WEAPON_SMOKE_RECRUIT_COUNT=4
WEAPON_SMOKE_FOLLOW_MAX_ERROR=7.29
WEAPON_SMOKE_PASS
```

Mobile input smoke：

```text
MOBILE_LAYOUT_SMOKE viewport=(1280.0, 2275.0) joystick=[P: (22.0, 2087.0), S: (164.0, 164.0)]
MOBILE_INPUT_MOVE start_x=0.00 end_x=88.17
MOBILE_PAUSE_BUTTON_PASS
MOBILE_INPUT_SMOKE_PASS
```

StressTest：

```text
STRESS_INIT enemies=150 projectiles=100
STRESS_RESULT enemies=150 projectiles=100 measured_frames=411 avg_ms=7.824 p95_ms=17.853 max_ms=32.927 avg_fps=127.81 p95_fps=56.01 min_fps=30.37
STRESS_COUNTERS enemy_spatial_queries=2938 queries_per_frame=7.15 enemy_group_scans=0 group_scans_per_frame=0.000 kills=780 gold=827 xp=882
STRESS_PERF_BELOW_60=true
STRESS_PASS
```

說明：平均 fps 已高於 60，但 p95 fps 仍低於 60，壓測誠實保留 `STRESS_PERF_BELOW_60=true`。後續若要穩定 60fps，優先檢查尖峰幀的 VFX / 碰撞查詢 / pickup 回收成本。

## 發佈注意

- 本輪沒有 `git init`、`git commit` 或 `git push`。
- `.gitignore` 已忽略 `.godot/`、匯出產物、暫存、log、機密環境檔。
- `assets/sprites/` 為專案原創素材，README 已註明可替換且無第三方版權素材。
