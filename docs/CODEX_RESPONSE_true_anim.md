# True character animation final report

日期：2026-07-14  
引擎：Godot 4.7 stable (`5b4e0cb0f`)  
限制：未執行 git commit／push。

## 結論

目前所有遊戲中英雄與敵人 sprite path 都由同一張 `512x3200` 真姿勢 atlas 驅動。五態為 `Idle / Walk / Attack / Hurt / Death`，每角色分別有 `4 / 8 / 6 / 3 / 6` 幀。Walk 是腿與手臂交替姿勢；Attack 第 0-1 幀蓄力、第 2 幀 impact、第 3 幀延續、第 4-5 幀 recovery；Hurt 為後仰反應；Death 為六幀倒地。

物理 root／`CollisionShape2D` 留在 `CharacterBody2D`，`AnimatedSprite2D` 只負責視覺。走速以 `speed_scale = actual_speed / configured_speed` 同步並 clamp，避免腳滑。朝左只做 `flip_h`，不移動、旋轉、縮放整張角色圖來冒充姿勢。

## 修改檔案

新增／產線：

- `assets/sprites/true_character_atlas.png` 與 import：10 個現有視覺 archetype 共用的五態 atlas；PNG `1,238,420 bytes`，SHA-256 `EF8FBB6D24FBDEA7CA6C0C8D076E55B99087E92BBF175B3ABBB4B5C96C280B59`。
- `scripts/animation/true_animation_library.gd`：依角色與狀態切 atlas region，cache 每 archetype 的 `SpriteFrames`，所有 instance 共用一張 atlas texture。
- `tools/generate_true_animation_atlas.py`、`tools/true_character_rig.blend`：Blender 5.1 分離肢體／關節姿勢產線。
- `tools/generate_walk_frames.py`：舊入口改為呼叫上述 Blender 產線並產生 pose proof，不再 affine-skew 平圖。
- `docs/true_animation_pose_proof.png`：姿勢證明，`32,190 bytes`，SHA-256 `20022B723653659475AC097ABD398F0223438A76648F9E30835339894527F86F`。
- `scenes/debug/TrueAnimationRegressionTest.tscn`、`scripts/debug/true_animation_regression_test.gd`：atlas／五態／impact／whiff／hurt／death 回收契約。

Runtime：

- `scripts/player/player_visual.gd`：五態狀態切換、走速同步、attack impact／finished、death finished 訊號、接觸幀腳步粒子；static fallback 只顯示錯誤，不做假動畫。
- `scripts/heroes/hero.gd`：Rift Pulse 先播放 Attack，僅收到 impact 訊號才結算傷害；受傷與死亡接 Hurt／Death，死亡完成才 finalization。
- `scripts/enemies/enemy.gd`：接觸、遠程與 boss ring 統一經 Attack impact；active-frame 距離複驗與單次 hit registry；Hurt 物理擊退；Death finished 才給獎勵、生成子體並回 pool。
- `scripts/services/sprite_loader.gd`：預熱 shared atlas，移除舊 generated frame 預熱。
- `scripts/autoload/entity_factory.gd`：enemy pool `220 -> 320`，容納 150 active 加 0.6 秒 dying 動畫 cohort；atlas texture 仍只載入一份。

回歸調整：

- `enemy_art_regression_test.gd`、`m4_regression_test.gd`、`r5_regression_test.gd`、`r7_regression_test.gd`、`r10_5_regression_test.gd`、`r11_regression_test.gd`、`r12_regression_test.gd`、`r13_regression_test.gd`：把舊的立即死亡／整圖 bob／立即位移假設改為真姿勢幀、impact 時序、Death finished 與物理 root 擊退契約。
- 刪除 `assets/sprites/generated/` 下 66 張舊 idle/walk 圖與 66 個 import；它們是平圖加工／舊來源幀，不再有 runtime 引用。

## 傷害觸發點

- 玩家 Rift Pulse：`try_cast_active_ability()` 只設 `active_ability_pending` 並呼叫 `Visual.play_attack()`；`AnimatedSprite2D.frame_changed` 到 Attack frame `2` 時發 `attack_impact`；`Hero._on_visual_attack_impact()` 才呼叫 `_cast_rift_pulse_damage()`。輸入／蓄力幀不扣血。
- 敵人：`_start_attack()` 只保存 weak target、攻擊種類與倍率；Attack frame `2` 才進 `_apply_attack_impact()`。接觸攻擊在該幀重新量距，超出 active hitbox 即揮空；`attack_hit_registry` 保證同一 attack 不重複傷害。遠程彈與 boss ring 也只在 impact 幀生成。
- Hitbox：只在 `_apply_attack_impact()` 同步 active 段設為 true，處理完成立即 false；測試在 impact callback 內確認 active。Attack 動畫即使無目標也完整播完 recovery。

## 已刪除的假動畫

- Enemy：刪除 `_update_procedural_visual()`、`_apply_visual_transform()`、`_apply_visual_motion_profile()`，以及 `visual_walk_phase`、`visual_idle_phase`、bob amplitude/frequency、tilt、整圖 breath scale、step squash、hit squash、boss 整層 scale pulse。
- Player visual：刪除 `_update_procedural_motion()`、`_apply_visual_transform()`，以及 walk/idle phase、整圖上下位移、rotation tilt、breath scale、turn/hit squash。
- Generator：刪除 `body_lean()`、flat-image affine shear 與 `make_hero_frame()`／`make_enemy_frame()` 假幀產法。
- 最終 grep：`scripts/enemies`、`scripts/heroes`、`scripts/player` 無 character `tween_property(position/rotation/scale/skew)`、bob、skew 或 procedural whole-sprite pose 程式；剩餘 `AnimatedSprite2D.scale` 僅為一次性尺寸 fit，position/rotation 只重設為零。

## 驗證

### 載入與動畫專項

- `--headless --path . --editor --quit`：exit 0，無 ERROR／SCRIPT ERROR／WARNING。
- `--headless --path . --quit-after 2`：exit 0，無 ERROR／SCRIPT ERROR／WARNING。
- `TrueAnimationRegressionTest`：`TRUE_ANIMATION_REGRESSION_PASS`。
  - shared atlas instance 相同；五態幀數 `4/8/6/3/6`。
  - Player anticipation 無 impact、frame 2 單次 impact、callback 時 hitbox active、recovery 回 Idle。
  - Enemy anticipation 無傷、frame 2 扣血一次、移出範圍 whiff 為 0 傷。
  - Hurt 播放且 physics root 擊退；Death 0.45 秒時仍 visible，完成後才回收。

### 全 debug 回歸

最終皆 PASS：

- `EnemyArtRegressionTest`、`GameplayCapTest`
- `M1RegressionTest`、`M2RegressionTest`、`M3RegressionTest`、`M4RegressionTest`
- `MobileInputSmokeTest`、`OrbitBladeHitRepro`、`PoolContractTest`（刻意觸發一次 double-release warning 以驗 guard）
- `R5RegressionTest`、`R6RegressionTest`、`R7RegressionTest`
- `R10_5RegressionTest`、`R11RegressionTest`、`R12RegressionTest`、`R13RegressionTest`、`R14RegressionTest`
- `SquadSmokeTest`、`WeaponSmokeTest`
- `ArenaInstrumentationRun`、`BalanceMockRun`

R11 實測 hero/enemy walk 各觀察到至少 3 個不同姿勢且 visual root 靜止；R13 物理擊退 `7.82 px`。

### 150 敵 Stress

- Desktop `1280x720`：`STRESS_PASS`；active enemies `150`，pool-live（含 dying）`175`；avg/p95/max `28.783 / 43.195 / 61.018 ms`；enemy pool exhausted/duplicate/foreign `0/0/0`；group scan `0`。
- Mobile LOD `390x844`：`STRESS_PASS`；active enemies `150`，pool-live（含 dying）`205`；avg/p95/max `25.023 / 37.584 / 57.672 ms`；enemy pool exhausted/duplicate/foreign `0/0/0`；group scan `0`。
- 兩檔皆為 `STRESS_PERF_BELOW_60=true`。這代表 correctness／pool／cap 契約綠，但本機 headless 未達穩定 60fps，不宣稱 60fps 達標。

### Web export

- `--headless --path . --export-release Web export/web/index.html`：exit 0。
- `export/web/index.pck`：`5,646,536 bytes`；SHA-256 `D23A18B7115E70E586F63853CC20F3B7D3B111957165B21CC5976436189A351A`。
- PCK 內可查到 imported `true_character_atlas`、`true_animation_library` 與 `TrueAnimationRegressionTest`。

## 缺的素材

阻塞素材：無。現有 runtime 使用的 3 個英雄 base sprite path 與 7 個敵人 sprite path 全部有五態 atlas 姿勢，缺幀時會明確 `push_error` 並只顯示 static error fallback，不會偽造完成。

非阻塞的進一步美術空缺：9 名英雄目前沿用 3 個既有視覺 archetype，尚無每名英雄獨立五態素材；尚無每把武器各自 attack clip，也沒有背面／斜向等多方向姿勢（左向目前鏡像右向）。產線的 character/state row mapping 可直接替換或擴列，不需改物理 root 與傷害時序。
