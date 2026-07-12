# Crackveil Vanguard — 對抗性覆核 M4（畫面強化／效能監工）

**審查者**：效能監工／對抗覆核（只審不改）  
**審查對象**：`d1cd0fa` — *M4 畫面強化：四層爆炸合成／武器專屬視覺／Boss 體積光／隊伍柔光／UI 微打磨*  
**基線 commit（CODEX 自稱）**：`37f19c2`（M3）  
**對照文件**：`docs/CODEX_RESPONSE_M4.md`、`docs/CODEX_RESPONSE_M2.md`、`docs/CODEX_RESPONSE_M3.md`  
**範圍**：(1) Stress「前值 51.0」與 M2 基準 14.5 的三倍差；(2) 四層合成成本與裁減；(3) 30.9ms p95 是否推翻 60fps 級宣稱、回滾／LOD 判定  
**方法**：靜態讀 `d1cd0fa` diff、`stress_test.gd` 歷史、`m3_stress_*.log` 留檔、M4 視覺熱路徑碼；**本輪未重跑 headless Godot／Stress**  
**日期**：2026-07-12  

---

## 執行摘要

| # | 議題 | 判定 | 嚴重度 |
|---|------|------|--------|
| (1) | 51.0「前值」vs M2/M3 的 ~14.5ms | **Stress 情境／腳本未改**；51.0 **不可**當 M2 可比前值；同輪 A/B 與歷史基線 **混用會誤導** | **P0** 度量誠信 |
| (1b) | 新視覺是否真讓基準劣化 | **高度可疑但未孤立證明**；完工 30.9／27.4 仍約 **2×** M3 留檔 14.6／13.9 | **P0** 效能回歸（待乾淨 A/B 定讞） |
| (2) | 哪層最貴／值不值得 | **Layer 4 碎片粒子最貴**；Layer 3 多片 additive 柔光／煙次之；主形＋衝擊環最值 | **P1** 成本／收益 |
| (3) | 30.9ms p95 ≈ 32fps 級 | **成立為倒退**；不可再掛「60fps 級」行銷；**建議部分回滾合成深度 + 更激進 LOD，非整包撤銷身份語言** | **P0** 宣稱／出貨門檻 |

**總判定**：**No-Go 硬關帳**（效能敘事與 60fps 級宣稱）；**軟 Go 僅限「美術身份方向可留、合成深度必須再砍一輪」**。

- 正確性／pool／字型／pck 增量（CODEX 自述）本輪不反證。  
- 效能：同輪「51→30.9 改善 39%」**不能**洗白「相對 M2/M3 留檔仍 ~2×」。  
- 出貨前最低門檻：同機、同 session、`37f19c2` vs `d1cd0fa` 各跑 Desktop/Mobile Stress；p95 需回到 **接近 M3 噪音帶**（建議桌面 ≤18ms、mobile ≤16.7ms 作為軟目標；宣稱 60fps 級則 p95 應 <16.7ms）。

狀態標籤：**成立**／**部分成立**／**未達**／**不可信**／**新風險**／**預存灰區**  
優先級：**P0** 謊稱／不可比數字／明顯 fps 倒退；**P1** 過重合成層；**P2** 可觀測性與微調。

---

## (0) 變更盤點（對照宣稱）

| 宣稱 | 碼上狀態 | 主要位置 |
|------|----------|----------|
| 爆炸四層合成 | **成立** | `explosion_area.gd`：core_flash／主形／shockwave／smoke + debris |
| 死亡三套 preset | **成立** | `death_burst.gd`：`elite_death`／`boss_phase`／`boss_death` |
| Desktop 4／Mobile 2 層 | **成立** | `mobile_tuning.gd:19,242-244`；`entity_factory.gd` spawn 注入 `composite_layers` |
| 武器 visual_level／進化放大 | **成立** | `weapon_data.gd`；`projectile.gd` glow／trail／sprite growth |
| Boss 雙層體積光 | **成立**；僅 Boss acquire 建節點 | `enemy.gd` `_ensure_boss_volume_nodes` |
| 隊長柔光 | **成立** | `arena.gd` 620px／390px additive |
| UI 卡片滑入／結算 count-up | **成立** | `level_up_screen.gd` 等（**不在 Stress 熱路徑**） |
| Stress 51.0→30.9 改善 | **同輪數字自洽**；**跨輪基線不可比** | `CODEX_RESPONSE_M4.md:31-40` |
| pck +23.6KB | **文件宣稱成立**（本輪未重驗 SHA） | 同上 |
| 20/20 回歸 | **文件宣稱**；本輪未複跑 | 同上 |

---

## (1) 疑點：51.0 前值 vs M2 的 14.5ms——情境改了，還是畫面讓基準爛掉？

### 1.1 Stress 契約有沒有被改？

| 檢查項 | 結果 |
|--------|------|
| `scripts/debug/stress_test.gd` 在 `1d4e03d`（M2）→`d1cd0fa`（M4） | **無 diff**（`git log 1d4e03d..d1cd0fa -- stress_test.gd` 空） |
| seed | 固定 `52002` |
| warm-up / measured | 180 / 411 |
| 敵／背景彈 | 150 / 80 |
| 滿編＋11 槽進化預熱 | 仍在 |
| Desktop／Mobile 視口 | `1280×720`／`390×844` |
| 量測方式 | wall-clock `Time.get_ticks_usec()`；`--fixed-fps 60`（依 CODEX） |

**結論 (1a)**：**不是 Stress 情境被改**。協議自 M2 起已鎖死；M4 的 51.0 **不是**「換了更狠的 Stress 才變慢」。

### 1.2 歷史數字對齊

| 來源 | Desktop p95 / max | Mobile p95 / max |
|------|------------------:|------------------:|
| M2 完工（文件） | 14.552 / 24.282 | 14.949 / 24.338 |
| M3 完工（`m3_stress_*.log` 留檔） | **14.574 / 23.058** | **13.940 / 21.437** |
| M4 施工前（CODEX 同輪） | **51.012 / 76.168** | **27.581 / 38.034** |
| M4 完工（CODEX 同輪） | **30.940 / 45.917** | **27.356 / 38.577** |

M3 留檔桌面：`avg_ms=7.294`、`p95_ms=14.574`、spike 僅 3 幀、`kills=326`、`death_burst live≤20`、`explosion created=112`。  
與 M4 完工 30.9ms p95 相比，歷史機況下約 **+112% 幀時**（若機況可比）。

### 1.3 為什麼 51.0 會是 14.5 的三倍？

CODEX 已自承（`CODEX_RESPONSE_M4.md:33`）：

> 本輪施工前環境明顯慢於 M3 留檔……所以簽核使用同一輪同機 A/B，不混用歷史機器狀態。

這句話 **部分正確、部分危險**：

| 命題 | 判定 |
|------|------|
| 51.0 不應拿來和 M2 的 14.5 直接算「M4 修好三倍」 | **成立**——那是 **跨 session 機況／熱狀態／背景負載** 汙染 |
| 同輪 51→30.9 證明「M4 視覺沒讓東西變慢」 | **不成立**——同輪 A/B 只能證明「M4 完工碼相對當輪施工前碼桌面較快」；**無法**證明相對乾淨 M3 無回歸 |
| 新視覺「不可能」造成劣化 | **不成立**——碼上明確增加每幀 `fit_sprite`、多片 additive、桌面 CPUParticles debris；應預期 **正成本** |
| 同輪桌面 -39% 但 Mobile 幾乎不動（-0.8%） | **合理訊號**：Mobile 已砍到 2 層，M4 合成增量在 mobile 路徑上被 LOD 吃掉大半；桌面 4 層＋粒子才是變量。若「環境」是唯一主因，兩檔應同向大幅抖動，**不完全符合** |

**最可能解釋（對抗式排序）**：

1. **P0／主因候選**：**session 機況差**把 M3 碼量測抬到 51ms（熱節流、AV、其他行程）；M4 完工時稍緩 → 假性「優化」。  
2. **P0／並行候選**：相對 **乾淨 M3 留檔**，M4 桌面四層＋武器成長 **真實抬高 p95**；30.9 可能是「髒機況 × 真回歸」的混合。  
3. **排除**：Stress 改情境、seed、敵彈數、refill budget（皆未變）。

**結論 (1b)**：  
- **「51.0 前值」對 M2/M3 基線不可信**，禁止再寫成「M4 從 51 優化到 30」。  
- **「30.9 相對 14.5 仍約 2×」是產品上真正要回答的問題**，且目前 **偏向回歸未清**。  
- **補測命令（給下一輪，本輪不執行）**：同機連續  
  `checkout 37f19c2` → Desktop/Mobile Stress → `checkout d1cd0fa` → 再跑同樣兩檔；輸出完整 `STRESS_RESULT` 並附 spike 事件。

### 1.4 Stress 是否打到 M4 新成本？

| M4 功能 | Stress 是否承壓 | 說明 |
|---------|------------------|------|
| 死亡／爆炸多層合成 | **是** | 滿場擊殺＋`death_burst_cap=20`；初始還預噴 60 次 death_burst；榴彈／脈衝等走 explosion pool |
| 武器專屬軌跡／光暈成長 | **是** | 11 槽全進化；`visual_level`／`evolved_visual` 放大 glow／trail／爆炸 radius |
| Boss 雙層體積光 | **否（常態）** | Stress 敵是 normal／fast／tank，**不刷 Boss** |
| Boss phase 全場波 | **否** | 無 phase 觸發 |
| 隊長柔光 | **是（固定 1 個）** | 低頻成本 |
| 背景主題瞬時層 | **部分** | Desktop `dynamic_multiplier` 滿時偶發；Mobile 關瞬時主題層 |
| UI tween／count-up | **否** | Stress 壓掉升級 UI |

→ Stress **足以暴露**「常時戰鬥 VFX 合成＋武器成長」；**不足以**代表 Boss 戲劇場景尖峰（Boss 要另開 scenario）。

---

## (2) 若真劣化 ~2×：哪層最貴？值不值得？裁減建議

### 2.1 四層合成實際對應（碼）

**Explosion**（`explosion_area.gd`）：

| 層級門檻 | 元件 | 每幀成本型態 |
|---------:|------|--------------|
| 永遠 | 主爆形 `sprite` | 1× textured sprite + `fit_sprite` |
| 永遠 | 衝擊環 `shockwave_sprite` | 1× additive sprite，可擴到 ~3.65× radius |
| `>=3` | `glow` + `core_flash` | **2×** 大面積 additive 徑向光 |
| `>=3` | `smoke_sprite` | 又一片半透明大 sprite |
| `>=4` | `debris_particles`（CPUParticles2D） | amount ~12–30，lifetime ~0.3s+ |

**Death burst**（`death_burst.gd`）同構：主形 + impact_ring；`>=3` glow/core/smoke；`>=4` particles。Boss／elite preset 把 ring 拉到 **146→230→340→720** 量級，glow 亦同步放大。

Mobile：`vfx_composite_layer_count` → **2**＝主形＋衝擊環（關柔光／煙／碎片）。  
Desktop：預設 **4**＝全開。

### 2.2 成本排序（靜態推估；無 profiler 拆幀）

在 Stress 熱路徑（大量短命 VFX 並發，非單一 Boss）：

| 排名 | 成本源 | 為何貴 | 畫面邊際收益 |
|-----:|--------|--------|--------------|
| 1 | **Layer 4：CPUParticles 碎片／burst particles** | CPU 模擬 + 多 sprite 粒子；並發時與擊殺尖峰疊加（M3 spike 已標 `drop_vfx/gc_pressure`） | 滿場時可讀性低，糊成噪點 |
| 2 | **Layer 3：core_flash + glow + smoke（多片 additive）** | fill-rate／overdraw；每幀多次 `fit_sprite`；並發 20 個 burst ≈ 60+ 半透明大圓 | 單發很「電影」；滿場互相洗白 |
| 3 | **武器成長：更大 glow／更長 trail／爆炸 radius +4.5–28%** | **常駐**於 80 背景彈 + 全隊火力，不是短瞬間 | 辨識度有感，但尺寸成長可打折 |
| 4 | **Layer 2 衝擊環** | 單片 additive，中等成本 | **高**——打擊感主幹 |
| 5 | **Layer 1 主形** | 必要 silhouette | **最高**——不可砍 |
| 6 | 隊長 620px 柔光 | 單例 persistent | 氛圍中等；可縮不可無（桌面） |
| 7 | Boss 雙光／phase 波 | Stress 外；Boss 在場時中高 | **高戲劇價值**，保留但可 mobile 單層 |

**結論 (2a)**：最貴且最不值得的是 **桌面 Layer 4 粒子**；次貴是 **Layer 3 的三重柔光／煙在「並發 cap 內全開」**。主形＋衝擊環是 C/P 之王。

### 2.3 值不值得？（畫面收益 vs 幀成本）

| 功能包 | 建議 | 理由 |
|--------|------|------|
| 武器專屬形語言（色、比例、軌跡語彙） | **保留** | 身份感高；成本主要在尺寸成長，可調係數 |
| Boss 專屬彈／雙光／phase 合成 | **保留（mobile 降級）** | 罕見高光時刻；不進 150 雜兵熱路徑 |
| 死亡／爆炸「四層全開」當桌面預設 | **不值得** | Stress 滿場時 overdraw 與粒子和尖峰同源；M3 已用 2 層質感（主＋shock）達可用水準 |
| UI 滑入／count-up | **保留** | 不在戰鬥 p95 |
| 背景火星雨／裂隙弧 | **桌面可留、注意 pulse 門檻** | 偶發；非主凶 |
| 隊長大柔光 | **縮小** | 單例便宜，但 620px additive 無謂 |

### 2.4 裁減建議（桌面保留／mobile 砍）

#### Desktop（目標：逼回 p95 接近 M3）

| 項 | 建議 | 預設 |
|----|------|------|
| `vfx_composite_layer_count` | **3 而非 4** | 關 debris／burst particles；保留 core 或 glow **二選一** + 主形 + 環 |
| 並發節流 | live `death_burst` ≥12 或單幀 kills ≥8 時 **強制 layer≤2** | 尖峰保護 |
| 爆炸 smoke | 僅 `area_radius` 大或 evolved 時開 | 小爆兩層即可 |
| 武器尺寸成長 | `visual_level` 係數砍半（如 0.07→0.035；evo 0.28→0.14） | 辨識留、fill 降 |
| trail `max_length` | riftline 128→96；seeker 92→72 | |
| 隊長柔光 | 620→420，alpha 0.16→0.12 | |
| Boss | 雙光可留；`boss_phase` ring 720 桌面可 480 | |

#### Mobile（已 2 層；再激進一檔）

| 項 | 建議 |
|----|------|
| 合成 | **維持 2**（主＋環）；禁止悄悄回 3 |
| 隊長柔光 | **關或 ≤240px、alpha≤0.08** |
| Boss | **單層** glow，不要 inner+core 雙 additive |
| 武器成長 | mobile 忽略 `visual_level` 尺寸，只保留色／形 |
| trail | 強制 `TRAIL_NODE_CAP` 更嚴或 mobile 縮 width |
| 背景 | 維持關瞬時主題層 |
| cap | `death_burst_cap=12` 可試 **8**；爆炸視覺 cap 可低於玩法 cap（玩法已解耦） |

#### 不建議整包回滾的部分

- 武器形語言（青束／橘拋物／紫網等）  
- Boss 環彈專屬紋理與 phase 觸發戲（改 LOD，不刪敘事）  
- M3 Kenney 紋理本體  

---

## (3) 30.9ms p95 ≈ 32fps——M4 該不該部分回滾？

### 3.1 數字含義

| 指標 | 值 | 含義 |
|------|-----|------|
| 16.67ms | 60fps 預算 | 「60fps 級」通常至少要求 **p95 靠近此線** |
| M3 桌面 p95 14.57ms | ~68.6 p95 fps | 文件與 log 一致；仍 `STRESS_PERF_BELOW_60=true`（因 **max**） |
| M4 桌面 p95 30.94ms | **~32.3 p95 fps** | 明確低於 60；連「平均 60 體感」都危險 |
| M4 桌面 max 45.9ms | ~21.8 min fps | 尖峰可感卡頓 |
| M4 mobile p95 27.4ms | **~36.5 p95 fps** | 相對 M3 13.9 **約 2×**；同輪幾乎無「M4 修好」 |

CODEX 誠實印 `STRESS_PERF_BELOW_60=true`：**加分**。  
但 commit／回應語境若讓人以為「M4 效能過關／甚至優化」，則是 **敘事問題**。

### 3.2 與「60fps 級」宣稱

- M2 commit 訊息寫過「兩檔 60fps 級」，但當時已保留 `STRESS_PERF_BELOW_60`（max 仍 >16.7）。那是 **偏樂觀標籤**。  
- M4 若沿用「60fps 級」：**倒退且不成立**。  
- 正確對外： **「滿編 Stress headless p95 未達 60；M4 以表現為主，效能需 M4.1 LOD」**。

### 3.3 回滾 vs 更激進 LOD

| 選項 | 判定 |
|------|------|
| 整包回滾 `d1cd0fa` | **過當**。身份語言與 Boss 戲值得留；UI 無害 |
| **部分回滾合成深度（建議）** | Desktop 預設 4→**2 或 3**；Layer 4 粒子預設關；並發強制降層 |
| **更激進 LOD 分檔（建議並行）** | 不只 mobile 2 層：加 `high_kill_pressure` 動態檔；武器尺寸成長分檔；Boss mobile 單光 |
| 只靠「真機一定比較快」辯護 | **拒絕**。headless 是專案自訂合約；M2/M3 用同一合約達 ~14ms |

**裁決 (3)**：

1. **M4 效能敘事 No-Go**；不可標 60fps 級。  
2. **不要求美術身份整包回滾**。  
3. **要求 M4.1（或同 PR 補丁）**：合成預設降檔 + 並發 LOD + 武器尺寸係數下修；以 **同機 M3↔M4 乾淨 A/B** 證明 p95 回到可接受帶。  
4. 若乾淨 A/B 顯示 M4 桌面 p95 仍 >22ms：優先砍 Layer 3 並發，而不是再加特效。

---

## (4) 度量與工程債（監工附加）

| 項 | 判定 | 說明 |
|----|------|------|
| 跨文件基線混用 | **新風險 P0** | 51.0 與 14.5 並列不標「不可比」會誤導簽核 |
| Stress 未印 `composite_layers` | **P2** | `STRESS_SCENARIO` 有 particle_multiplier／death_burst_cap，無層數 |
| 無 per-system frame budget | **預存灰區** | 無法在 log 內指認「爆炸 vs 彈軌 vs 物理」 |
| Boss 不進 Stress | **預存灰區** | Boss 雙光／720 ring 的最壞幀未覆蓋 |
| `fit_sprite` 每幀多呼叫 | **新風險 P1** | 每個 visible 層每幀重算 scale；並發時 CPU 可觀 |
| 回歸鎖 4 層桌面 | **雙面刃** | `m4_regression_test.gd` 鎖死 4 層，會阻撓「預設改 3」——改預設時需同步改回歸語意為「上限 4、預設可 3」 |

---

## (5) 歷輪紅線快檢

| 紅線 | M4 狀態 |
|------|---------|
| 熱路徑 group 掃敵 | 未見新增（Stress 仍報 `enemy_group_scans=0`，依 CODEX） |
| Pool exhausted／foreign release | CODEX 報 0 |
| 視覺 cap 吃玩法傷害 | 未見改壞；explosion 仍走既有 cap 路徑 |
| 決定性／玩法數值被 LOD 改 | 合成層與 glow 屬表現；**武器成長僅視覺**（`visual_level` 不進 damage 欄位）——主幹 OK |
| pck 預算 | +23KB 遠低於 +1MiB 敘事 |
| 效能不謊稱 | **同輪改善數字 OK**；**若暗示已優於／持平 M2 則違規** |

---

## (6) 總判定與下一輪必做

### 總判定

| 維度 | 結果 |
|------|------|
| 美術方向（身份、Boss 戲、UI） | **方向成立，可留** |
| 效能相對 M2/M3 留檔 | **未達／高度疑似回歸** |
| 51.0 前值敘事 | **不可信作跨輪基線** |
| 60fps 級 | **倒退；禁止宣稱** |
| 出貨 | **No-Go** 直到 M4.1 合成降檔 + 乾淨 A/B |

### 下一輪必做（仍屬建議；本輪不改碼）

1. **乾淨 A/B**：`37f19c2` vs `d1cd0fa` 同機連續 Stress×2 檔。  
2. **Desktop 預設 composite ≤3**，Layer 4 粒子預設 off。  
3. **擊殺壓力動態 LOD**（並發 burst／單幀 kills）。  
4. **武器尺寸成長減半**；mobile 可 0 成長只留色形。  
5. Stress log 增加 `composite_layers=`、可選 `vfx_live=`。  
6. 對外文案刪「60fps 級」直到 p95 證據回來。

---

## 附錄 A — 關鍵碼錨點

```19:19:scripts/services/mobile_tuning.gd
const MOBILE_VFX_COMPOSITE_LAYERS := 2
```

```242:244:scripts/services/mobile_tuning.gd
static func vfx_composite_layer_count(viewport_size: Vector2, force_mobile: bool = false) -> int:
	# Gameplay VFX keep their silhouette on mobile, while smoke/debris are dropped.
	return MOBILE_VFX_COMPOSITE_LAYERS if mobile_lod_enabled(viewport_size, force_mobile) else 4
```

```198:213:scripts/projectiles/explosion_area.gd
func _emit_debris() -> void:
	if debris_particles == null or int(stats.get("composite_layers", 4)) < 4:
		return
	# ... CPUParticles2D amount ~12–30 ...
```

（Death burst 同檔：`composite_layers < 4` 關 particles；`< 3` 關 glow／core／smoke。）

### 附錄 B — 本輪未做

- 未執行 Godot headless／未重跑 Stress  
- 未用 renderer debugger 量 overdraw  
- 未驗證 pck SHA 與瀏覽器實機幀率  

**一句話**：M4 把「好看」堆在桌面四層合成與常駐武器放大上；Stress 腳本沒變，但 **51ms 前值不能洗白歷史 14.5ms 基線**；**30.9ms p95 是 32fps 級，60fps 敘事必須收回**，合成深度部分回滾 + 動態 LOD，而不是整包刪美術身份。
