# cv R17 UX 重設計報告

版本：`v0.14.1-r17`

## 實作摘要

- 暫停面板改為頂部分頁：`設定`、`成就`、`本局`，移除原本把設定、工具、本局統計、殘響重置、成就與繼續全塞進同一個長捲動的結構。
- HUD 右上新增三個畫面內小圖示切換：靜音、螢幕震動、搖桿大小，直接重用既有設定 callback 與 `PlayerSettings`。
- 暫停面板與主選單的成就清單改為 `GridContainer` 徽章格。已解鎖成就高亮、未解鎖暗色；點擊徽章才開詳述彈窗。
- 裂隙商亭採低風險改善：保留既有 `GameManager.shop_requested` / `purchase_selected` modal 流程，但手機 portrait 改為緊湊雙欄卡片，三個選項與離開按鈕同屏可見，避免捲動。
- 搖桿顯示改為觸控保底：只要有觸控能力且不是明確純桌機輸入，就預設顯示虛擬搖桿，避免觸控筆電或 JS 偵測不穩時開局沒有控制盤。

## 商亭取捨

R17 沒有把商亭改成真正場內 `Area2D` 浮動購買按鈕。原因是目前商亭流程由 `GameManager` 控制暫停、商店事件與購買選項生命週期；改成場內互動會牽動戰鬥暫停時機與可購買狀態同步，風險高於本輪 UX 修補目標。已落地的 fallback 是手機 portrait 緊湊雙欄，符合「不用捲才能看完三卡與離開」的驗收痛點。

## 證據截圖

- `docs/evidence/R17_ux/390x844_pause_settings_hud_quick_joystick.png`
- `docs/evidence/R17_ux/1024x768_pause_achievement_badges.png`
- `docs/evidence/R17_ux/1920x1080_main_menu_achievement_badges.png`
- `docs/evidence/R17_ux/390x844_shop_compact_two_column.png`
- `docs/evidence/R17_ux/1920x1080_touch_desktop_joystick_fallback.png`

## 驗證

### R14RegressionTest

命令：

```powershell
& "$env:TEMP\godot47\Godot_v4.7-stable_win64_console.exe" --headless --fixed-fps 60 --path . res://scenes/debug/R14RegressionTest.tscn
```

結果：exit `0`

```text
R14_FORMFACTOR phone=phone tablet=tablet touch_desktop=desktop joystick_fallback=true desktop=desktop seed_max=400
BONDS_ACTIVE=["bond_ember_pulse", "bond_void_rail", "bond_guard_echo", "bond_captain_shepherd"]
BONDS_ACTIVE=["bond_ember_pulse", "bond_void_rail", "bond_captain_shepherd"]
R14_HERO10 roster=10/9 weapons=11 construct_cap=6 targets=2 bonds=4 impact=frame2
R14_MOBILE_UI portrait_scale=1.96 landscape_scale=1.86 font=39 touch=76.0
R13_UI_SPACING viewports=1920x1080,1024x768,390x844 gap>=8 touch>=44
R14_CAMERA desktop=1.28 mobile=1.56 threat=1.36
R14_BACKGROUND interval=88.98 sig_len=41
SCREENSHOT_BEAUTY_ON hud_hidden=true vfx_layers=4
SCREENSHOT_BEAUTY_OFF hud_hidden=false vfx_layers=adaptive
R14_PRESS_CAPTURE phase_banner=heat_red adaptive_layers=3 beauty_layers=4
R14_REGRESSION_PASS
```

### TrueAnimationRegressionTest

命令：

```powershell
& "$env:TEMP\godot47\Godot_v4.7-stable_win64_console.exe" --headless --fixed-fps 60 --path . res://scenes/debug/TrueAnimationRegressionTest.tscn
```

結果：exit `0`

```text
TRUE_ANIMATION_PLAYER heroes=10 unique_cells=10 hero=rift_shepherd poses=4/8/6/3/6 impact_frame=2 duplicate_hits=0 shared_atlas=-9223371953002248598
TRUE_ANIMATION_SHEPHERD impact_spawn=frame2 anticipation_spawn=0 whiff_damage=0 whiff_spawn=0 recovery=full cap=6 retarget=death_or_generation radius=120 l2_queries=1 pool_errors=0
TRUE_ANIMATION_ENEMY impact_delayed=true whiff_damage=0 hurt_knockback=true death_delayed=true lod=6/3/1.5/freeze shared_ticker=true
TRUE_ANIMATION_REGRESSION_PASS
```

### Web export

命令：

```powershell
New-Item -ItemType Directory -Force -Path export\web | Out-Null
& "$env:TEMP\godot47\Godot_v4.7-stable_win64_console.exe" --headless --path . --export-release "Web" "export/web/index.html"
```

結果：exit `0`，輸出包含 `[ DONE ] savepack`。

### 秘密掃描

命令：

```powershell
rg -n -i --hidden -g "!.git/**" "sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}" .
git grep -n -i -E "sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}" -- .
```

結果：零命中。
