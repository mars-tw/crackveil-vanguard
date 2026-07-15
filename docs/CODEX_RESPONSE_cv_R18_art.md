# Crackveil Vanguard v0.14.2-r18｜cv R18 美術修正

## 修法

- 閃電彈採治法 (a)：把 `assets/sprites/proj_lightning.png` 從黃底改成白/中性灰階底圖，保留原 alpha 與尺寸，讓 `lightning_arc.gd` 既有 `modulate` 乘法能乘出 cyan。
- 同步修正三把玩家閃電武器色值：`arc_chain`、`rail_lance`、`echo_hymn` 改為裂隙青；`echo_hymn` 進化色與 fallback 也改為 cyan，避免進化後退回暖黃。
- 敵方 ember 彈不走 `proj_lightning.png`：`enemy.gd::_enemy_projectile_stats` 仍使用 `proj_bullet.png` 與 `Color(1.0, 0.35, 0.24)`。
- 新增 `tools/build_r18_art_assets.py`，可重產 R18 閃電、decor 與 evidence。

## 前後對照

- `docs/evidence/R18/proj_lightning_before_after.png`：黃底閃電 vs 中性灰白閃電。
- `docs/evidence/R18/lightning_weapon_cyan_samples.png`：arc_chain / rail_lance / echo_hymn 三把實際色值套用後皆為 cyan。
- `docs/evidence/R18/lightning_color_metrics.json`：
  - `proj_lightning_base_mean_rgb = [0.889, 0.889, 0.889]`
  - `proj_lightning_neutral_max_channel_delta = 0.0`
  - 三把武器 `cyan_pass = true`
  - enemy ember reference `uses_proj_lightning = false`, `ember_pass = true`

## Decor 去占位

替換 Grok 指名 9 件，路徑、尺寸、`run_theme.gd` 對應 key 均不變。

- void：`void_bush_ghost`、`void_debris_01`、`void_rock_01`、`void_rock_02`、`void_stump`
- ember：`ember_ash_bush`、`ember_rock_01`、`ember_rock_02`、`ember_ruin_barn`

證據：

- `docs/evidence/R18/decor_contact_after.png`：新 void/ember decor contact sheet。
- `docs/evidence/R18/decor_silhouette_vs_farm.png`：新 decor vs farm 參照與 alpha diff。
- `docs/evidence/R18/decor_alpha_metrics.json`：9 對全部 `alpha_same = false`。

缺件揭露：本輪 Grok 指名 9 件已全數替換，無缺件。

## 驗證

```text
python tools/build_r18_art_assets.py
R18_ART_ASSETS_PASS
```

```text
Godot --headless --fixed-fps 60 res://scenes/debug/R14RegressionTest.tscn
R14_REGRESSION_PASS
```

```text
Godot --headless --fixed-fps 60 res://scenes/debug/TrueAnimationRegressionTest.tscn
TRUE_ANIMATION_REGRESSION_PASS
```

```text
Godot --headless --export-release "Web" "export/web/index.html"
exit 0
```
