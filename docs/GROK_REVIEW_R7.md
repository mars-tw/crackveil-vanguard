# Crackveil Vanguard — 對抗性設計／程式審查 R7

**審查者**：資深遊戲設計師＋Godot 4 技術總監（對抗式；以工作區**未 commit** diff 與現行程式為準，不採信 `CODEX_RESPONSE_R6_pkg345` 語氣）  
**審查對象**：R6 路線圖包 3–5（精英詞綴、武器進化、Meta 殘響）  
**對照**：`docs/GROK_REVIEW_R6.md` §3.1／§3.2／§3.5、`docs/CODEX_RESPONSE_R6_pkg345.md`  
**方法**：`git status`／`git diff`（19 檔 +613/−30）＋靜態讀碼（`enemy*`、`weapon*`、`projectile*`、`meta_progress`、`game_manager`、UI、R7 回歸）；本輪**只審不改**，未重跑 Godot headless／瀏覽器長測  
**日期**：2026-07-10  

---

## 執行摘要

| 面向 | 判定 |
|------|------|
| 包 3 精英詞綴（split／field／swift） | **大致成立**；三詞綴皆有行為差，非純換皮 tank。split cap **安全**；field 走位壓力 **成立**；swift **是 AI 質變**，但傷害方向與設計相反 |
| 包 4 武器進化 ×4 | **部分成立**；四條皆有可感知差異，預算主幹守住。達成條件偏寬（只綁質變滿層 + Lv7）、**未稀釋**進化後線性卡；餘燼井缺設計中的「第二段延遲爆」 |
| 包 5 Meta 殘響 | **主幹成立**；幅度守住「不破單局平衡」；delta 防重複領取 **正確**。契約畫面即時購買與 `start_run` 套用順序有 **新 bug**；招募隊員不吃 HP／拾取 Meta |
| 歷輪紅線快檢 | **主幹維持**；無新增 group 熱掃描、進化走既有 pool／spatial。`get_nodes_in_group("heroes")` 仍為 fallback（非新引入） |
| CODEX 驗證可信度 | **中高**：R7 回歸覆蓋 split cap／field／swift 配置／evo 一次性／Meta roundtrip；**未**覆蓋契約畫面購買當局生效、招募 Meta、fork 極限 skip 體感、多 field 疊加實戰 |
| R7 總判定 | **包 3–5 主契約有落地，三支柱深度從「紙上路線圖」進到「可感知閉環原型」**；尚未到「第二局與第十局質性分家」。對抗性剩餘在 **體驗邊界／順序 bug／進化池權重政策／swift 平衡方向**，不是「完全沒做」 |

**一句話**：實作方把「詞綴＝規則怪、進化＝質變二層、殘響＝局間微進度」的骨架接對了，且 cap／pool／delta 紀律大多比 CODEX 宣稱更保守；但 **契約 UI 買 Meta 當局失效**、**swift 反玻璃化**、**進化條件過寬且不稀釋線性卡** 會在實戰稀釋「想再開一局」的清晰回饋。

狀態標籤：

- **成立**／**部分成立**／**未達設計意圖**／**新 bug**／**紅線違規（灰／實）**／**延後仍在**

優先級：

| 等級 | 意義 |
|------|------|
| **P0** | 正確性、會吞心跳／重複發獎／破 cap／UI 謊稱生效 |
| **P1** | 質變意圖、平衡方向、池權重稀釋、Web 熱路徑邊界 |
| **P2** | 文案／mock 誠信、視覺佔位、作弊韌性、長期擴充 |

---

## (0) 變更盤點（以 git 為準）

### 工作區狀態

- 分支：`main`（與 `origin/main` 同步）
- **未 commit**；本輪審查主體為 working tree diff + untracked

### 已修改（19 files，約 +613 / −30）

| 路徑 | 角色 |
|------|------|
| `project.godot` | 註冊 `MetaProgress` autoload |
| `scripts/autoload/meta_progress.gd`（新） | 殘響存檔／三軌／解鎖／發獎 |
| `scripts/autoload/game_manager.gd` | `gold_earned`、echo delta、Meta 開局套用、契約／升級候選 +1 |
| `scripts/autoload/entity_factory.gd` | `get_enemy_active_count()` |
| `scripts/enemies/enemy.gd` | affix 狀態、field tick、ring 視覺、death spawn 改 active 計數 |
| `scripts/enemies/enemy_spawner.gd` | 三詞綴 roll／config 覆寫 |
| `scripts/heroes/hero.gd` | `apply_movement_slow` |
| `scripts/heroes/squad_manager.gd` | 進化選項 weight 8 |
| `scripts/resources/weapon_data.gd` | `evo_*` 定義／條件／apply |
| `scripts/weapons/*`、`projectiles/*` | 四進化行為 |
| `scripts/ui/contract_screen.gd` 等 | Meta 購買 UI、結算／HUD 殘響顯示 |
| `scripts/debug/r7_regression_test.gd` + 場景（新） | 包 3–5 回歸 |
| `scripts/debug/balance_mock_run.gd` | 紙上 mock 加 affix／evo 字串（**非實局**） |
| `docs/CODEX_RESPONSE_R6_pkg345.md`（新） | 實作方自述 |

**本輪不在包 3–5 但影響體驗的既有項**（R6 已記，仍影響詞綴／進化可感知度）：E4 精英 XP fallback 邊界、S3 若未完全對齊實戰仍可能搶節拍——本輪 diff **未再動**這些主幹，僅作紅線上下文。

---

## (1) 包 3：精英詞綴 — 是否真的質變威脅

### 1.1 生成與辨識

| 檢查 | 位置 | 實況 |
|------|------|------|
| roll | `enemy_spawner.gd:251-254` | 三選一 `randi() % 3`；`debug_forced_elite_affix_id` 供回歸 |
| 套用 | `:257-290` | split／field／swift 覆寫 config |
| 視覺 | `enemy.gd:634-658` | tint + `AffixRing`（Line2D 圓）；field 環＝力場半徑 |
| 生命週期 | `pool_on_release` 清 affix 欄位、藏 ring | 池化可重入 |

**判定**：辨識 **成立**（色相 + 環 + HP 條色），玩家可在接近時區分「綠裂／青場／橘閃」。

---

### 1.2 `affix_split` 裂殖

#### 設計意圖（R6 §3.5）

死亡吐 2 小體、**禁連鎖**、**必須** `death_spawn_cap`、等同 spawner 紀律。

#### 證據鏈

| 層 | 位置 | 行為 |
|----|------|------|
| 配置 | `enemy_spawner.gd:260-267` | `spawns_on_death=true`、`death_spawn_count=2`、`death_spawn_cap=max_enemies`、HP×0.92 |
| 死亡序 | `enemy.gd:470-497` | **先** `is_active=false` → 再 `_spawn_death_children` → 再 `release_enemy_deferred` |
| cap | `enemy.gd:499-508` + `entity_factory.gd:431-443` | 用 `get_enemy_active_count()`（跳過 `is_active==false`） |
| 小體 | `enemy.gd:511-528` | `spawns_on_death=false`；無 `affix_id`；綠 tint；不繼承 split |
| 回歸 | `r7_regression_test.gd:63-103` | 有 cap 時 2 隻；硬 cap 下 `active ≤ max` |

#### 逐條結論

| ID | 命題 | 判定 | 檔案:行號 | 最小重現／說明 |
|----|------|------|-----------|----------------|
| A-S1 | 死亡裂 2 且禁連鎖 | **成立** | `enemy.gd:511-528`；`enemy_spawner.gd:264-267` | 殺 `affix_split` 精英 → 出現 2 `affix_split_spawnling`；小體再死不裂 |
| A-S2 | 永不破 `max_enemies`（150） | **成立** | `enemy.gd:501-505`；`entity_factory.gd:431-443` | 填滿 cap 後殺裂殖精英 → active 不超過 cap（R7 回歸 cap=4） |
| A-S3 | 硬 cap 邊界「盡量 2 隻」 | **部分成立** | 同上 | 父體先 `is_active=false` 故 **讓出 1 格**；若場上原已滿 150，死後 active≈149 → **通常只容 1 隻小體**再觸頂。安全優先於保證 2 隻——與 CODEX 自述一致，**未破紅線** |
| A-S4 | 質變威脅（非大號 tank） | **成立** | 配置 + 小體速度 124 | 擊殺瞬間變「清雜波」事件；有 cap 時威脅被裁切是紀律代價 |

**對抗註記**：`get_enemy_active_count` 每次死亡掃 `live_enemies` O(n)——僅死亡路徑，可接受。spawner 仍用 `get_enemy_live_count`（含未 unregister 的屍體到 deferred）——與 death spawn 的 active 計數 **刻意不同**，不構成 cap 破洞。

---

### 1.3 `affix_field` 磁滯力場

#### 設計意圖

半徑 ~120 內英雄減速（×0.82 或 slow status）；**禁止**每精英每幀 `get_nodes_in_group`；用 squad 列表。

#### 證據鏈

| 層 | 位置 | 行為 |
|----|------|------|
| 配置 | `enemy_spawner.gd:268-273` | radius **128**、slow **0.22**、speed×0.86（較慢貼身） |
| tick | `enemy.gd:531-554` | 每 **0.12s** 掃 `squad_manager.get_members()`（≤5）；fallback 僅 `GameManager.player` |
| 英雄 | `hero.gd:179-196` | `movement_slow_timer/strength`；速度 × `(1 - strength)`，strength clamp 0.65 |
| 視覺 | `enemy.gd:645-647` | 青色大半徑 ring |

#### 逐條結論

| ID | 命題 | 判定 | 檔案:行號 | 最小重現／說明 |
|----|------|------|-----------|----------------|
| A-F1 | 對走位有實際影響 | **成立** | `enemy.gd:554`；`hero.gd:154-155,195-196` | 貼 field 精英 128px 內 → 移速約 **−22%**（設計 18%）；0.2s 持續 + 0.12s 刷新＝**區內近乎常駐 slow** |
| A-F2 | 非 group 熱掃描 | **成立** | `enemy.gd:539-543` | 熱路徑只讀 members 小陣列；**無** `get_nodes_in_group` |
| A-F3 | 效能可接受（Web） | **成立**（主路徑） | 同上 | 最壞：場上數隻 field × 每 0.12s × ≤5 距離平方——遠低於每幀 spatial 查詢 |
| A-F4 | 與設計數值對齊 | **部分成立** | spawner:272-273 | 半徑 128＞120；slow 22%＞18%——略兇，仍屬同一設計帶 |
| A-F5 | 多 field 疊加 | **可接受／P2** | `hero.gd:182-183` | strength 取 **max** 非相加；兩場不會叠成 44%（有 cap 0.65） |

**對抗註記**：field 精英 **自己變慢**（speed×0.86）→ 玩家可用風箏降低貼身機率；威脅來自「被包夾時的走廊壓縮」而非追擊。仍比「大號 tank」有規則差。

---

### 1.4 `affix_swift` 疾閃

#### 設計意圖

速度×1.45、**傷×0.9**、切 dasher；玻璃砲威脅。

#### 證據鏈

| 層 | 位置 | 行為 |
|----|------|------|
| 配置 | `enemy_spawner.gd:274-290` | HP×0.82、speed×1.45、**damage×1.05**、`behavior_id=dasher`、`dash_speed=465` |
| AI | 既有 dasher 狀態機（未新 instantiate） | 突進／前搖／恢復 |
| 回歸 | `r7_regression_test.gd:126-137` | 只驗 `behavior_id==dasher` 且 dash≥450 |

#### 逐條結論

| ID | 命題 | 判定 | 檔案:行號 | 最小重現／說明 |
|----|------|------|-----------|----------------|
| A-W1 | 是否只是數值加速 | **否 → 成立為 AI 質變** | `enemy_spawner.gd:284-290` | 同精英血條但會 **dash 切入**；與 chaser tank 手感不同 |
| A-W2 | 玻璃砲（傷↓） | **未達設計意圖** | `:277` vs R6 §3.5「傷×0.9」 | 實作 **×1.05**；加上精英基底 `damage×1.3`（`:174`）→ 接觸傷偏高。最小重現：比較同秒 spawn 的 split vs swift 單次 contact damage |
| A-W3 | HP 下調防又快又肉 | **成立** | `:275` HP×0.82 | 對齊「swift 降 HP 係數」精神 |
| A-W4 | 無新 per-frame instantiate | **成立** | 復用 dasher | 紅線 OK |

**結論（詞綴總）**：三詞綴 **達到「規則怪」門檻**；split／field 紀律乾淨。swift **不是純數值加速**，但 **平衡方向與設計文件相反**（更快且略更痛，而非更快更玻璃）——記 **P1 未達設計意圖**，非實作缺失。

---

## (2) 包 4：四武器進化

### 2.0 共通規則

| 規則 | R6 設計 | 實作 | 判定 |
|------|---------|------|------|
| 觸發 | 質變滿層 + **傷≥3**（或類似投資） | 質變滿層 + **`run_level≥7`  only** | **部分成立**（更易達成，投資門檻變薄） |
| 卡池 | 進化卡 weight 高／保底 | weight **8**、一次性 modifier | **成立** |
| 行為差 | 質變二層，非 +20% 傷 | 四條皆改行為語彙 | **大致成立** |
| 進化後稀釋線性卡 | 建議 weight↓ | **未做** | **未達設計意圖** |
| cap／pool | 不新池或入 factory | 全走既有 fork／hazard／explosion／arc | **成立** |

條件 API：`weapon_data.gd:162-173`；池注入：`squad_manager.gd:209-229`。

#### 達成可達性

| 武器 | 條件 | 預估 | 判定 |
|------|------|------|------|
| 裂線 | `riftline_fork` Lv2 + Lv7 | 質變 weight 3、需 2 層；Lv7 中後期常態 | **可達** |
| 星環／爆花／雷鏈 | 各質變 Lv1 + Lv7 | 單層質變即可 | **偏易可達** |

R7 回歸在 `level=7` 強制滿質變後四 evo 皆進池且選後消失（`r7_regression_test.gd:148-190`）——**一次性成立**。

#### 權重稀釋（招募／質變）

| 情境 | 估算 | 判定 |
|------|------|------|
| 單把武器 evo 就緒 | evo weight 8 vs 質變 3 vs 招募 4 vs 線性 1 | evo **偏容易刷到**（符合「高權重提示」） |
| 2–4 把同時就緒 | 池內 +16～32 evo 權重 | **可能擠壓**招募尾段與剩餘質變——P1 政策風險 |
| 進化後 | 線性 `weapon_damage`／`projectiles` 仍 weight 1 | 與 R6「避免指數爆炸」**未對齊** |

---

### 2.1 `evo_rift_fan` 裂隙扇編

| 檢查 | 位置 | 行為差 |
|------|------|--------|
| apply | `weapon_data.gd:189-192` | 主彈數 clamp 3–5、spread≥48、改色 |
| 開火 | `linear_bullet_weapon.gd:25-44` | 扇形；側彈傷／程 ×0.82 |
| 裂片 | `projectile.gd:161-167,174-177` | 2 片→**3 向**（±30°／0°）；裂片傷 0.38；仍 `spawn_fork_projectile` |
| 禁遞迴 | `projectile.gd:155,185-186` | `fork_depth`／`riftline_fork_level=0` |

| ID | 命題 | 判定 | 最小重現 |
|----|------|------|----------|
| E-RF1 | 可感知差異（非換皮） | **成立** | 進化前後：彈道由單線變扇 + 命中三向裂片 |
| E-RF2 | fork cap 48 | **成立（紀律）** | 仍子池；極限下 skip 增加——體感「有時少裂片」**灰區 P1**（R6-Q1b 延續放大） |
| E-RF3 | 條件含傷≥3 | **未達設計意圖** | 只看 fork Lv2 + run Lv7 |

**fork 預算壓力**：進化後單輪最多約 `5 主 × 3 裂 = 15` 子彈需求／齊射（未計穿透多段觸發），比進化前 `~2×2` 高一個數量級——cap 安全但 **靜默裁切更常發生**。

---

### 2.2 `evo_shear_halo` 剪界星環

| 檢查 | 位置 | 行為差 |
|------|------|--------|
| apply | `weapon_data.gd:193-197` | 軌道半徑 **+28 常駐**、刃略大、hit_interval×0.84 |
| 脈動 | `orbit_projectile.gd:89-90` | `sin(...) * 9` 連續微脈動（非「一拍外擴 0.35s」） |
| 命中 | `:134-135` | 在易傷外再套 **slow 0.9s／0.22** |
| 池 | 既有 orbit | 無新節點 |

| ID | 命題 | 判定 | 說明 |
|----|------|------|------|
| E-SH1 | 行為可感知 | **部分成立** | slow + 常駐大環 **可感**；sin±9 脈動 **偏弱**，不如設計「外擴一拍」清楚 |
| E-SH2 | 非純數值 | **成立** | slow 改敵群移動語彙 |
| E-SH3 | 對齊設計「外擴期易傷+30%」 | **未達設計意圖** | 實作選 slow 路線（設計允許二選一）——可接受但文案「剪界／切開」靠 slow 支撐 |

---

### 2.3 `evo_ember_well` 餘燼井

| 檢查 | 位置 | 行為差 |
|------|------|--------|
| 觸發 hazard | `explosion_weapon.gd:19-20` | `pulse_embers` **或** evo 皆生井 |
| evo stats | `:32-42` | duration **2.0**、tick 0.45、**slow** status 0.7／0.18 |
| 基底 embers | `:43-49` | duration 1.2、無 slow |
| 池 | hazard cap 8 + LRU | 沿用 R5 |

| ID | 命題 | 判定 | 說明 |
|----|------|------|------|
| E-EW1 | 可感知差異 | **成立** | 井更久 + 敵進井變慢；顏色更紅 |
| E-EW2 | 設計「第二段延遲爆 0.45s」 | **未達設計意圖** | **完全沒做**延遲第二爆；只做了 duration／slow 半套 |
| E-EW3 | cap 不吞玩法 | **成立** | LRU 頂最舊，不會「有卡無火」 |

---

### 2.4 `evo_overload_nova` 超載新星

| 檢查 | 位置 | 行為差 |
|------|------|--------|
| 分支 | `chain_lightning_weapon.gd:45-50` | evo 時走 nova，**取代**原 overload 小爆（非疊加雙爆） |
| 新星 | `:71-79` | 更大半徑／略高傷係數 |
| 補弧 | `:82-105` | `get_enemies_in_radius` 最多 3 未命中目標；`spawn_lightning_arc` |
| 查詢 | spatial index | **無 group 掃敵** |

| ID | 命題 | 判定 | 說明 |
|----|------|------|------|
| E-ON1 | 可感知差異 | **成立** | 末端開花 + 短弧補刀，與「末跳小爆」明顯不同 |
| E-ON2 | 設計磁吸可選 | **刻意省略**（可接受） | CODEX 未做磁吸；不破預算 |
| E-ON3 | 池／cap | **成立** | explosion／lightning_arc 既有 cap |

**進化總判**：四條皆 **有行為差**；強度上 **裂扇／新星** 最清楚，**星環** 中等，**餘燼井** 因缺二段爆偏「加長版 embers」。條件與權重政策使進化 **偏早、偏容易刷到**，長線數值仍靠線性卡堆——**未完全達成**「進化是 build 終點」敘事。

---

## (3) 包 5：Meta 殘響

### 3.1 幅度與「不破單局平衡」紅線

| 軌 | 設計（R6） | 實作 | 滿階 |
|----|------------|------|------|
| 韌性 | 每級 &lt;4% HP，建議 +4% | **+2%**／級（`meta_progress.gd:184-185`） | +10% max HP |
| 拾獲 | +8 建議 | **+6**／級（`:188-189`） | +30 radius |
| 傷害 | +3% 建議 | **+1.5%**／級（`:192-193`） | +7.5% 全隊傷 |
| 解鎖 | 契約欄／配方可見等 | 契約候選 +1（lifetime 60）、起始升級 +1（120） | 內容解鎖優先 **精神成立** |

對照局內：單張質變／契約常有 +12% 傷或規則改寫 → Meta 滿階仍 **小於一張強契約**。

| ID | 命題 | 判定 | 說明 |
|----|------|------|------|
| M1 | 不破單局平衡 | **成立** | 總加乘可見且保守；甚至 **低於** R6 建議帶 |
| M2 | 解鎖優先於數值 | **部分成立** | 有 2 解鎖，但 **無**「進化配方可見／詞綴圖鑑」；改 lifetime 門檻免花碎片——務實可接受 |
| M3 | 碎片曲線 2–4 局升 1 小級 | **大致成立**（靜態） | 成本 16–22 起跳；公式 `floor(gold_earned*0.25)+…`（`:113-130`）中局約十數片；Boss +8 有目標感 |

---

### 3.2 `user://veil_echo.cfg` 韌性

| 情境 | 行為 | 判定 |
|------|------|------|
| 首次／檔案不存在 | `load` 失敗 → 預設 0（`:60-65`） | **成立** |
| 損壞／無法 parse | 同上，不崩潰 | **成立** |
| 重置 | `reset_progress` 寫零並 save（`:87-90`） | **成立**（R7 回歸覆蓋） |
| 數值越界 | level clamp 到 max（`:70-74`）；shards `max(0,…)` | **成立** |
| 作弊改 cfg | 可直接改 shards／lifetime | **預期灰區 P2**；無 checksum／簽名——Web 單機可接受，但 **lifetime 解鎖極易被改** |
| lifetime vs shards 不一致 | 只 clamp 各自欄位，不校驗「lifetime ≥ 歷史花費」 | **P2** |

**無**「失敗時 session 降級並 UI 標示」——R6 有提，本輪 **未做**（載入失敗＝靜默當新檔）。

---

### 3.3 delta 防重複領取

#### 證據鏈

| 層 | 位置 | 行為 |
|----|------|------|
| 本局累計 | `game_manager.gd:143,190` | `echo_shards_awarded_this_run`，`start_run` 清零 |
| 發獎 | `:805-819` | `total_eligible = calculate_run_shards`；`delta = total - awarded`；只 `award_run(fixed_delta)` |
| fixed | `:822-831` + `meta_progress.gd:114-115` | `_fixed_echo_delta` 短路公式，避免二次解析 stats |
| 勝利 | `record_boss_kill` → `_summary_with_echo` | 發一次 |
| 繼續後死亡 | `player_died` → 再 `_summary_with_echo` | 只補 **增量** |
| 雙殺 Boss | `record_boss_kill` 開頭 `if boss_killed: return` | 不重入 |
| 雙死亡 | `player_died` `if is_game_over: return` | 不重入 |

| ID | 命題 | 判定 | 最小重現 |
|----|------|------|----------|
| M-D1 | Boss 勝後繼續再死不雙倍 | **成立** | 擊殺 Boss 見「殘響 +X／本局 X」→ 繼續清雜 → 再死 → 本次 +Y 僅對應新增 gold／kills 等，本局合計 ≈ 最終 eligible |
| M-D2 | 使用 `gold_earned` 不懲罰消費 | **成立** | `add_gold` 累加 `gold_earned`（`:263-266`）；結算公式讀 `gold_earned` |
| M-D3 | 回歸覆蓋 delta 路徑 | **部分** | R7 直接 `award_run` 兩次灌 lifetime，**未**模擬 victory→continue→death 的 `echo_shards_awarded_this_run` |

---

### 3.4 開局套用與 UI — **新 bug**

| ID | 等級 | 問題 | 位置 | 最小重現 |
|----|------|------|------|----------|
| M-B1 | **P0 體驗／正確性** | Meta 購買放在**契約畫面**，但 HP／拾取在 `start_run` 於**開契約前**就 `_apply_meta_progress_start_effects` | `game_manager.gd:193-198,785-802`；`contract_screen.gd:149-152` | 開局契約 UI 花碎片買「裂隙韌性」→ **本局 max_hp 不變**；需再打一局才生效。同時「共鳴火花」走 `get_outgoing_damage_multiplier` **當局立即生效** → 三軌體驗不一致 |
| M-B2 | **P1** | 中途 `recruit_hero` **不**套用 Meta HP／拾取 | `squad_manager.gd:373-384` 無 Meta 鉤子 | 滿 Meta 後開局隊長有 +HP；升級招募新英雄為 **基礎 max_hp** |
| M-B3 | **P2** | 解鎖「起始選擇 +1」條件 `run_level <= 2` | `meta_progress.gd:180-181`；`add_xp` 先 `level += 1` 再建池 | 第一次升級時 level 已是 2 → **成立**；第二次 level=3 不加。多段升級佇列仍 OK |

**存檔路徑**：`user://veil_echo.cfg` 與設計一致；UI 顯示結算 +N／本局合計／持有（`game_over_screen.gd`／`stage_victory_screen.gd`／`hud.gd`）**成立**。

---

## (4) 歷輪紅線快檢

| 紅線 | R7 狀態 | 證據 |
|------|---------|------|
| 命中 `spawn_token` | **維持** | 本輪 diff **未改** `get_hit_token`／projectile hit key 主契約；`entity_factory._issue_enemy_spawn_token` 仍在 |
| cap 不吞玩法 | **主幹成立** | split 小體裁切；fork／hazard／explosion／arc 既有 pool。**灰區**：裂扇進化提高 fork skip 頻率（玩法變薄，非破 cap） |
| 無 group 掃描（武器熱路徑） | **成立** | 進化用 `get_enemies_in_radius`／既有 overlap；field 用 squad members |
| `get_nodes_in_group("heroes")` | **灰區既有** | `enemy.gd:405` 僅 squad_manager 缺失時 fallback；**非本輪新引入**，Arena 正常路徑不走 |
| 池化 cap | **成立** | 無新 runtime 池類型；AffixRing 為敵節點子 Line2D，池重用 |
| 決定性 seed | **成立（主 RNG）** | affix `randi()`、升級 `randf()` 吃 Arena `seed(run_seed)`（`arena.gd:56-64`） |
| Web 單執行緒預算 | **大致成立** | 無新每幀 instantiate；契約 Meta UI 僅開局；field 0.12s tick；**注意** `_ensure_visual_nodes` 會為敵建立 AffixRing（40 點 Line2D），池化後常駐——成本固定可接受 |
| E6 精英 cap 回收 | **維持（前序）** | `reclaim_regular_enemy_for_elite` 仍在；詞綴掛在成功 spawn 後 |

**無本輪「實」紅線違規**（破 150、武器 group 掃全場、新無 cap 彈種）。  
**灰區**：fork 靜默 skip 因扇編放大；Meta 購買順序造成「UI 可買但當局無效」屬 **體驗正確性 P0**，非 cap 紅線。

---

## (5) 新引入 bug 與 Web 效能

### 5.1 新 bug／回歸缺口

| ID | 等級 | 判定 | 問題 | 檔案:行號 | 最小重現 |
|----|------|------|------|-----------|----------|
| R7-B1 | P0 | **新 bug** | 契約畫面購買韌性／拾取 **本局不生效**（傷害卻生效） | `game_manager.gd:193-198,785-802`；`contract_screen.gd:149-152` | 見 M-B1 |
| R7-B2 | P1 | **新 bug** | 招募隊員不吃 Meta HP／拾取 | `squad_manager.gd:373-384` | 見 M-B2 |
| R7-B3 | P1 | **未達設計意圖** | swift 傷×1.05 而非×0.9 | `enemy_spawner.gd:277` | 見 A-W2 |
| R7-B4 | P1 | **未達設計意圖** | 餘燼井無第二段延遲爆 | `explosion_weapon.gd:31-42` vs R6 §3.2 | 進化後只見更久 slow 井 |
| R7-B5 | P1 | **未達設計意圖** | 進化不要求傷≥3、進化後不稀釋線性卡 | `weapon_data.gd:162-173`；`squad_manager.gd:147-180` | Lv7 + 一張質變即可刷 evo；選後仍大量 +傷卡 |
| R7-B6 | P2 | **邊界** | 硬 cap 下 split 常只出 1 小體 | `enemy.gd:470-505` | 150 滿場殺裂殖 |
| R7-B7 | P2 | **回歸缺口** | R7 未測 victory→continue→death delta；未測契約購買當局 | `r7_regression_test.gd:193-240` | — |

### 5.2 Web／效能

| 項目 | 判定 | 說明 |
|------|------|------|
| field tick | **安全** | 0.12s × ≤5 members |
| AffixRing | **可接受** | 每敵最多一 Line2D；非每幀 redraw（點集 setup 時寫入） |
| evo_rift_fan fork 壓力 | **灰區** | 不卡死主執行緒，但 cap skip↑ → 手感不穩 |
| evo_overload_nova | **安全** | 每次施放 +1 spatial 查詢 +≤1 arc，與原鏈相近量級 |
| Meta I/O | **安全** | 僅結算／購買 `ConfigFile.save`，非熱路徑 |
| 契約 UI 變重 | **可接受** | 開局一次；4 契約卡 + 3 Meta 按鈕；responsive 有改 offset |

CODEX 宣稱 Stress `enemy_group_scans=0`、pool exhausted=0——本輪**未複跑**；以靜態碼論 **可信**（本 diff 未新增 group 熱路徑）。

---

## (6) 與 CODEX 自述／R6 設計的偏差表

| 項目 | CODEX／實作 | R6 設計 | 對抗結論 |
|------|-------------|---------|----------|
| split cap 裁切 | 明確裁切 | 必須 cap | **對齊且正確** |
| field 數值 | 128／22% | 120／×0.82 | **略兇，意圖對** |
| swift 傷害 | ×1.05 | ×0.9 | **偏離** |
| 進化條件 | Lv7 + 質變 | 質變 + 傷≥3 | **放寬** |
| 裂扇 | 扇形主彈 + 三向裂 | 主推三向裂（或線掃） | **超額實作主彈扇，意圖成立** |
| 星環 | sin 脈動 + slow | 外擴拍 或 slow | **選 slow；脈動偏弱** |
| 餘燼井 | 久井 + slow | 久井 + **二段爆** | **缺半套** |
| 新星 | 大爆 + 3 短弧 | 半徑×1.55 ± 磁吸 | **意圖成立** |
| Meta 商店位置 | 契約畫面 | GameOver 或 Hub | **務實；但順序 bug** |
| Meta 幅度 | 更保守 | 每級 &lt;4% | **守紅線** |
| 解鎖花費 | lifetime 門檻 | 花碎片解鎖 | **可接受偏差** |

---

## (7) 總表（包 3–5 對抗結論）

| ID | 項目 | 結論 |
|----|------|------|
| A-S1～S2 | split 裂體＋cap 安全 | **成立** |
| A-S3 | 滿 cap 保證 2 小體 | **部分成立**（安全優先） |
| A-F1～F3 | field 走位／效能／無 group | **成立** |
| A-W1 | swift 非純數值 | **成立** |
| A-W2 | swift 玻璃砲 | **未達設計意圖** |
| E-RF1／ON1 | 扇編／新星質變 | **成立** |
| E-SH1／EW1 | 星環／餘燼可感知 | **部分成立** |
| E-EW2 | 餘燼二段爆 | **未達設計意圖** |
| E-pool | 進化池權重／不稀釋線性 | **部分成立／未達意圖** |
| M1 | Meta 不破單局平衡 | **成立** |
| M-D1 | delta 防重複 | **成立** |
| M-B1 | 契約購買當局 HP／拾取 | **新 bug（P0）** |
| M-B2 | 招募不吃 Meta | **新 bug（P1）** |
| 紅線 | token／cap／pool／決定性 | **主幹成立** |
| Web | 單執行緒熱路徑 | **大致成立**（fork 壓力灰區） |

---

## (8) R8 建議優先序（只建議，本輪不改碼）

| 序 | 等級 | 項目 |
|----|------|------|
| 1 | P0 | 契約畫面購買 Meta 後 **重套用** HP／拾取，或改為結算後商店、開局只讀快照並禁用「本局未生效」的誤導 |
| 2 | P1 | 招募時套用 Meta HP／拾取；swift `damage` 改 ×0.9（或明確改設計文件） |
| 3 | P1 | 餘燼井補延遲二段爆 **或** 改文案降承諾；進化後降低該武線性卡 weight |
| 4 | P1 | 進化條件加回「傷害升級 ≥N」或保證首次就緒保底，避免純 Lv7 門檻 |
| 5 | P2 | R7 回歸補 victory→continue→death echo delta；契約購買當局；可選 cfg 校驗 |

---

## (9) 一句話結案

R6 包 3–5 **不是空殼**：詞綴有規則、進化有語彙、殘響有局間鉤子，且 **cap／pool／delta 紀律整體合格**。對抗性否定的是「已完美達標」——**契約 Meta 當局謊言**、**swift 反玻璃**、**餘燼井半套**、**進化過寬且不收斂線性** 仍會阻止「第二局與第十局真正分家」。  

**R7 總判：主契約成立，體驗閉環部分成立；放行可玩原型，不放行「深度系統已完成」宣告。**
