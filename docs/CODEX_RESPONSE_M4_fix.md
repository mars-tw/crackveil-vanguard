# Crackveil Vanguard — M4 No-Go 修正輪回應

對照：`docs/GROK_REVIEW_M4.md` 全文。基線 commit：M3 `37f19c2`、M4 `d1cd0fa`。日期：2026-07-12。未 commit、未 push。

## 裁決摘要

| 議題 | 回應／證據 | 裁決 |
|---|---|---|
| 51.0ms 當「前值」 | 接受 Grok P0。該數字是髒 session，不能與 M2/M3 乾淨留檔混用，也不得再寫成 M4 的優化起點。 | **成立，撤回敘事** |
| M4 是否真約 2× M3 | 同機嚴格交替各三次後，Desktop M4 只比 M3 `+0.137ms / +0.74%`，Mobile `+0.169ms / +1.03%`。`30.9/27.4ms` 不是可重現的 M4 固有成本。 | **A/B 否證 2× 指控** |
| 60fps 級 | 即使修後 Desktop p95 中位為 `16.961ms`，仍略高於 16.67ms，max 也超線；本輪只宣告達成使用者指定的 `≤18ms`，不宣稱滿編 Stress 為 60fps 級。 | **Grok 指控成立** |
| 合成深度 | 美術身份保留；常態四層降三層，滿場動態降兩層，Desktop Boss／精英死亡仍四層；Mobile 更激進。 | **已修** |
| 出貨門檻 | 修後 Desktop/Mobile p95 三次中位 `16.961/14.918ms`；20/20 回歸、Web export、JS check 全綠。 | **本輪 Go（≤18ms 合約）** |

## 1. P0 度量誠信與乾淨 A/B

### 1.1 協議與機況

- Godot：`4.7.stable.official.5b4e0cb0f` console，Windows headless，`--fixed-fps 60`。
- Stress 契約未改：seed `52002`、180 warm-up、411 measured frames、150 enemies、80 初始 background projectiles；Desktop `1280×720`、Mobile LOD `390×844`。
- 兩個獨立 worktree 固定到 `37f19c2` 與 `d1cd0fa`；兩邊先完成 import／不計分預熱，再嚴格依 `M4→M3→M4→M3→M4→M3` 交替，每站連跑 Desktop/Mobile。
- 無殘留 Godot。保留唯一可見且與本工作相關的 `ChatGPT - Google Chrome` 與 Codex Node 子程序，未冒險終止工作環境；無其他可見測試 app。抽樣 CPU 約 `8.1–15.3%`，可用記憶體約 `5.0–5.1GB`，兩版承受同一背景狀態。
- 歷史 M3 留檔 `14.574/13.940ms` 仍是乾淨歷史證據；本次同 session 的 M3 中位 `18.566/16.417ms` 顯示當前機況較慢，因此產品成本只用本次交替 A/B 相減，不跨 session 嫁接。

### 1.2 三次原始結果與中位數

| 版本 | 模式 | Run 1 p95 | Run 2 p95 | Run 3 p95 | p95 中位 | avg 中位 | max 中位 |
|---|---|---:|---:|---:|---:|---:|---:|
| M3 `37f19c2` | Desktop | 17.293 | 18.566 | 18.927 | **18.566** | 12.562 | 25.932 |
| M4 `d1cd0fa` | Desktop | 17.191 | 18.703 | 19.206 | **18.703** | 12.844 | 28.626 |
| M3 `37f19c2` | Mobile | 17.203 | 16.417 | 16.339 | **16.417** | 11.593 | 27.528 |
| M4 `d1cd0fa` | Mobile | 15.130 | 16.872 | 16.586 | **16.586** | 11.500 | 23.733 |

真實 M4 視覺增量：

- Desktop：`18.703 - 18.566 = +0.137ms`，`+0.74%`。
- Mobile：`16.586 - 16.417 = +0.169ms`，`+1.03%`。

因此 Grok §1.1「Stress 情境未改」成立；§1.3「51.0 不可當可比前值」成立；但 §1.2/§3 以不同 session 的 `30.9` 對 `14.6` 推定 M4 固有約 2×，已被同機交替 A/B 否證。30.9/27.4 是機況污染與當輪變動，不再用於簽核。

### 1.3 Stress 覆蓋範圍

同意 Grok §1.4：常態爆炸／death burst、11 槽武器成長與單例隊長柔光有承壓；Boss 雙光與 phase 尖峰不在常態 Stress。Boss 表現邏輯由 M4 regression 鎖住，但本輪不把它冒充 Boss perf scenario。

## 2. 合成裁減（逐條對 §2.1–§2.4）

Grok 的成本排序採納：Layer 4 CPU 粒子先砍，Layer 3 大面積 additive 次之；主形與 impact ring 保留。

### Desktop

- 常態 `vfx_composite_layer_count`：`4→3`，預設關 debris／burst CPUParticles，保留主形、impact ring 與柔光身份層。
- 動態 LOD：live enemies `≥120` 或 live death bursts `≥12` 時，常態效果自動 `3→2`。Stress 150 敵、20 live burst 實際輸出 `composite_layers=2`。
- `elite_death`、`boss_phase`、`boss_death`：Desktop 明確保留四層，即使高 crowd 亦不犧牲高光時刻。
- 武器成長保留色、形與軌跡語彙；sprite/glow/trail/evolved 尺寸成長係數約砍半。
- 裂線長軌 `128→96`，追蹤飛彈 `92→72`；evolved 長度增幅 `18%→9%`。
- 爆炸粒子量改為 visual level 階梯 `0.55/0.70/0.85`，evolved 最多 `0.90`；不再讓每級尺寸與粒子一起線性膨脹。
- 隊長柔光 `620px / alpha 0.16 → 420px / 0.12`。它維持 child transform、只在 attach／viewport 事件刷新，沒有逐幀位置更新。

### Mobile

- 合成維持最多兩層；高光死亡也不悄悄升回四層。
- death burst cap `12→8`；Stress 實際 `vfx_live=8`。
- 武器升級尺寸成長歸零，只保留基礎色／形／不同軌跡身份；裂線／飛彈長軌再縮為 `72/56`。
- 隊長柔光 `390px / 0.12 → 240px / 0.08`。
- Boss 體積光由雙 additive 降為單光；Desktop 仍保留雙光。
- 既有粒子倍率 `0.60`、背景瞬時層關閉與兩層合成繼續有效。

### 明確保留

- 10 套武器形語言／11 個裝備槽、Kenney 紋理本體。
- Desktop Boss 雙光、Boss ring 專屬紋理與 phase／death 戲劇合成。
- UI 卡片動態與結算 count-up（不在 Stress 熱路徑）。

## 3. 裁減後三次驗收

每次結果均帶：

`baseline_source=M3_same_machine_AB_37f19c2`

`machine_condition=clean_warm_cache_ChatGPTChrome_CodexNode_only`

| 模式 | Run 1 avg / p95 / max | Run 2 avg / p95 / max | Run 3 avg / p95 / max | 中位 avg / p95 / max | 門檻 |
|---|---:|---:|---:|---:|---|
| Desktop | 11.378 / 17.230 / 23.773 | 11.093 / 16.961 / 22.749 | 11.269 / 16.747 / 25.347 | **11.269 / 16.961 / 23.773ms** | **PASS ≤18** |
| Mobile | 10.387 / 15.323 / 22.994 | 10.208 / 14.918 / 21.644 | 10.227 / 14.802 / 20.905 | **10.227 / 14.918 / 21.644ms** | **PASS ≤18** |

相對裁減前 M4 同 session 中位：Desktop p95 `18.703→16.961ms`（`-1.742ms / -9.31%`）；Mobile `16.586→14.918ms`（`-1.668ms / -10.06%`）。一次裁減即達門檻，未再犧牲美術身份。

本輪仍不寫「滿編 60fps 級」：Desktop 中位 p95 約 58.96fps，且兩檔 max 都有超過 16.67ms 的尖峰。正確宣告只有「指定 headless Stress p95 中位 ≤18ms」。

## 4. Stress 可觀測性（對 §4）

- `STRESS_PROVENANCE` 與每一行 `STRESS_RESULT` 現在必印 `baseline_source`、`machine_condition`；未傳參數時會明示 `UNSPECIFIED`，不再允許無標籤數字混入報告。
- `STRESS_SCENARIO` 新增 `composite_layers` 與 `vfx_live`，並保留 particle multiplier、cap 等既有欄位。
- M4 regression 語意由「Desktop 預設鎖四層」改為：常態三層、高 crowd 兩層、Desktop Boss／精英可四層、Mobile 兩層；另鎖 Mobile Boss 單光。
- per-system CPU/GPU frame budget 與專用 Boss perf scenario 仍是後續可觀測性工作；本輪未偽稱已完成 renderer profiler 拆帳。
- 每幀 `fit_sprite` 的活躍節點數已藉 layer LOD、cap 與軌跡縮短下降；未假稱函式本身已完全 cache。

## 5. 歷輪紅線與回歸

- Stress 全部 `STRESS_PASS`；pool exhausted／duplicate／foreign release 皆為 0，`enemy_group_scans=0`。
- 動態 LOD 只改表現層；爆炸傷害在 visual cap／layer 判斷前照常套用，玩法數值與 seed 不變。
- 完整 debug suite：**20/20 PASS**（M1/M2/M3/M4、R5/R6/R7/R10.5/R11/R12/R13/R14、PoolContract、GameplayCap、MobileInput、Weapon、Squad、Orbit repro、Arena instrumentation、Balance mock）。log 無 `SCRIPT ERROR`／`ERROR`。
- 這是部分回滾合成深度＋動態 LOD，不是整包回滾 `d1cd0fa`，符合 Grok §3.3 建議。

## 6. Web 與 pck

- Godot 4.7 `--headless --export-release "Web" "export/web/index.html"`：PASS。
- `node --check export/web/index.js`：PASS。
- `export/web/index.pck`：**4,652,032 bytes**（4.4365 MiB）。
- SHA-256：`4c0a4f6f8137f349b674bf14ac9f71407318ecef7735fafb181f22895a157146`。
- 相對 M3 `4,625,856 bytes`：`+26,176 bytes`；相對原 M4 `4,649,456 bytes`：`+2,576 bytes`，仍遠低於 +1MiB 預算。

## 7. 對 Grok 附錄與總判定的直接回應

- 附錄 A 的碼判讀正確：原本 Desktop 4／Mobile 2、`<4` 關 particles、`<3` 關 glow/core/smoke。本輪把「可用上限 4」與「常態預設 3／壓力 2」分開。
- 附錄 B 原列「未跑 headless／未驗 pck」現已補齊；本輪未做 renderer overdraw debugger，故不拿靜態成本排序冒充 GPU 分層 profiler。
- Grok 的 No-Go 對舊 M4 效能敘事成立；對「美術方向可留、深度砍一輪」也採納。修後以可重現證據通過 `≤18ms` 本輪門檻，但不恢復 60fps 級行銷用語。
