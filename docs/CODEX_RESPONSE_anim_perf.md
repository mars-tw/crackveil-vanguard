# Crackveil Vanguard — true animation performance response

日期：2026-07-14  
基準：本地 `HEAD ac42afb`（`main` ahead 1，未 push）  
引擎：Godot `4.7.stable.official.5b4e0cb0f` console  
限制：**未 git commit、未 git push**。

## 判定

**品質 Go、效能 Go（本輪 M4 p95 ≤18ms 出貨閘）**。

- Desktop 三跑 p95 中位：**15.575ms**。
- Mobile LOD 三跑 p95 中位：**13.436ms**。
- `TrueAnimationRegressionTest` PASS；完整 debug suite 最終 **22/22 PASS**。
- Desktop/Mobile Stress 各 3/3 `STRESS_PASS`；`enemy_group_scans=0`，所有 pool exhausted / duplicate / foreign release 均為 0。
- 此處只宣告指定 Stress 的 p95 門檻通過。Desktop max 中位仍為 `26.079ms`，不宣稱「每一幀 60fps」。

## 依 Grok §2.4 的裁減順序

### 1. 分級幀率／幀數

敵人仍使用 atlas 真姿勢幀，沒有恢復 whole-sprite bob。

| 距玩家（camera focus proxy） | LOD | 普通敵 walk | Elite/Boss walk |
|---|---:|---:|---:|
| `≤180` | 近距 1× | 4 姿勢（atlas `0/2/4/6`）@ 6fps | 8 姿勢 @ 10fps |
| `180–320` | 中距 1/2× | 3fps | 5fps |
| `320–560` | 遠距 1/4× | 1.5fps | 2.5fps |
| `>560` | offscreen | 停在當前姿勢幀 | 停在當前姿勢幀 |

Mobile 對上述 locomotion fps 再乘 `0.5`，所以 `animation_mobile_lod` 已真正影響 runtime。Attack/Hurt 維持 12fps 完整時序，不用距離 LOD 改動 impact 契約。

### 2. 遠距停格

`>560` 時不重設到 walk0、不切 static fallback，只停止推進目前 atlas 姿勢；回圈後從同一姿勢續播。專項回歸鎖定 frame 不變，且程式碼無 bob／skew／整圖 transform 假走路。

### 3. 死亡 cohort 簡化

- Active enemy `≥120` 時，普通敵使用 death `0→5` 兩個真死亡姿勢 @10fps，約 `0.2s` 後才 finalize。
- 非 crowd 時普通 full-death 並發 cap 為 `24`；超額同樣走簡化序列。
- Elite/Boss 保留 6 幀 @10fps，不犧牲 feature death。
- 獎勵、magnetic reclaim、子體生成、burst 與 pool release 仍只在所選 death sequence **播完後**執行。

最終 Stress 測量結束時，Desktop/Mobile enemy pool-live 為 `156/154`（active 均為 150），簡化 death live 為 `7/4`；Grok 原報告為 `175/205` live。

### 4. 共享 ticker

- `EntityFactory` 持有唯一 50ms enemy animation clock，以 3 個相位 bucket 錯峰派送，避免同幀集中換 atlas region。
- Enemy 的個別 `_process` 已關閉；`AnimatedSprite2D` 永遠 `stop()` 且 `PROCESS_MODE_DISABLED`，frame index 由共享 ticker 手動推進。
- Physics root／`CollisionShape2D` 仍在 `CharacterBody2D`，與 visual animation 分離。
- Client registry 使用 O(1) slot map/free-slot reuse；pool release 會 stop 並 unregister。
- 密集多段命中不會把進行中的 Hurt 一直重置回 frame0；反應仍完整播放。

## 真動畫契約

`TrueAnimationRegressionTest` 最終輸出：

```text
TRUE_ANIMATION_PLAYER impact_frame=2 duplicate_hits=0
TRUE_ANIMATION_ENEMY impact_delayed=true whiff_damage=0 hurt_knockback=true death_delayed=true lod=6/3/1.5/freeze shared_ticker=true
TRUE_ANIMATION_REGRESSION_PASS
```

鎖定內容：共享 atlas、`4/8/6/3/6` 五態素材、walk 肢體姿勢、Attack anticipation/impact/recovery、frame 2 命中、whiff、Hurt、physics-root knockback、Death 播畢回收、共享 ticker 與 LOD/freeze。R11 另以 mid 3fps 真時間窗觀察到 4 個不同 walk 姿勢，連跑 3/3 PASS。

## Stress 三跑

固定條件：seed `52002`、`--fixed-fps 60`、warm-up 180 frames、measured 411 frames；Desktop `1280x720`、Mobile `390x844`。

基準標籤為 Grok/ac42afb 已報告值 `43.195/37.584ms`，**不是本輪 same-session A/B**。本輪簽核只使用下列同條件三跑中位；不與舊 M3 留檔混為同機數字。

機況標籤：`warm_cache_no_residual_godot_user_apps_unchanged_cpu13pct_start`。開始/結束 Godot process 均為 0；8 logical CPU；free memory `9673.6→9693.3MB`；CPU snapshot `13%→23%`。Chrome/VS Code/Claude/ldremote 等使用者程式原樣保留，未擅自終止，因此這是「專案無殘留、暖 cache」機況，不是假稱 OS idle clean room。

| 模式 | Run 1 avg / p95 / max | Run 2 avg / p95 / max | Run 3 avg / p95 / max | 三跑中位 avg / p95 / max | 門檻 |
|---|---:|---:|---:|---:|---:|
| Desktop | `10.906 / 15.879 / 37.744` | `10.748 / 15.120 / 26.079` | `10.730 / 15.575 / 25.967` | **`10.748 / 15.575 / 26.079ms`** | **PASS ≤18** |
| Mobile | `9.774 / 13.507 / 19.151` | `9.623 / 13.149 / 16.180` | `9.596 / 13.436 / 18.876` | **`9.623 / 13.436 / 18.876ms`** | **PASS ≤18** |

相對 Grok 已報告 p95，Desktop `43.195→15.575ms`（`-63.94%`），Mobile `37.584→13.436ms`（`-64.25%`）。三跑的 deterministic counters 各自一致：Desktop kills `684`、Mobile kills `698`。

只有 Mobile Run 2 的 max 未超過 16.67ms；其餘 run 仍印 `STRESS_PERF_BELOW_60=true`。這不影響本輪 p95 ≤18 合約，但阻止「無尖峰 60fps」宣告。

## 回歸與匯出

- Editor parse/load：exit 0，無 `SCRIPT ERROR`／`ERROR`／`WARNING`。
- Main scene `--quit-after 2`：exit 0，無 `SCRIPT ERROR`／`ERROR`／`WARNING`。
- 完整 debug suite：EnemyArt、GameplayCap、M1–M4、R5–R7、R10.5–R14、MobileInput、Orbit repro、PoolContract、Squad、Weapon、Arena instrumentation、Balance mock、TrueAnimation，最終 **22/22 PASS**。
- Web release export：exit 0；`node --check export/web/index.js` PASS。
- `export/web/index.pck`：**5,656,616 bytes（5.3946 MiB）**，SHA-256 `5FA807FE22EA975C0BCF05D7203B7AE0E12146192D0D9791DFB50786239D2AE8`。
- PCK 可查到 imported `true_character_atlas`、`true_animation_library`、`TrueAnimationRegressionTest`。
- 相對 true-animation 原報告 pck `5,646,536 bytes`，增量 `10,080 bytes`。

## 最終出貨語意

本輪解除 Grok 的「效能硬 No-Go」：兩檔 p95 三跑中位均進入 M4 `≤18ms` 帶，且真姿勢、impact、hurt、death 播畢契約全數保留。max 尖峰仍需如實保留；本報告不把 `STRESS_PASS` 或 p95 Go 擴張成「所有 frame 都 60fps」。
