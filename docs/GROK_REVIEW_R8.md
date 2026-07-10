# Crackveil Vanguard — 對抗性設計／程式審查 R8

**審查者**：資深遊戲設計師＋Godot 4 技術總監（對抗式；以 `main@2bad09b` 與工作區現行程式為準，不採信 `CODEX_RESPONSE_R7.md` 語氣）  
**審查對象**：R7 輪入版修正（包 3–5 本體已於 R7 審過；本輪驗 **B1–B5 辯論修正是否真成立**＋殘留 P2＋對外發布品質）  
**對照**：`docs/GROK_REVIEW_R7.md`、`docs/CODEX_RESPONSE_R7.md`、commit `2bad09b`  
**方法**：靜態讀碼（`game_manager`／`meta_progress`／`squad_manager`／`weapon_data`／UI／`r7_regression_test`）＋ **本輪實際重跑** headless `R7RegressionTest` 與 `StressTest`；**只審不改**  
**日期**：2026-07-10  

---

## 執行摘要

| 面向 | 判定 |
|------|------|
| R7-B1 Meta 契約購買 delta 重套用 | **成立**；HP／拾取以 metadata 記已套用值，重套用 idempotent；共鳴火花走 live multiplier，三軌當局皆生效且不重複疊加 |
| R7-B1 `system_pause_owners` 互斥 | **主幹成立**；手動暫停 overlay 與系統 modal 顯示分流正確。硬互斥靠 `waiting_*` 擋新請求，owner 字典本身可疊加；商店／升級／勝利「同時開」在戰鬥暫停下 **實務難觸發**，回歸 **只覆蓋契約 vs 暫停** |
| R7-B2 招募 Meta 快照 | **成立** |
| R7-B3 swift 傷 ×0.9 | **成立**（靜態＋回歸 `swift_damage=16.38`） |
| R7-B4 餘燼井 0.45s 二段爆 | **成立**；傷走既有 `spawn_explosion`／cap 保 damage 先結算 |
| R7-B5 進化門檻＋線性權重 ×0.35 | **成立**；升級池 **仍健康**（不會「質變打完就只剩招募」），但滿編＋全進化後招募權重偏高屬 **可接受政策**；長無盡「池耗盡 0 選項」為 **預存軟鎖灰區** |
| 殘留 P2（B6／cfg／Stress） | B6／cfg **仍在**；Stress 宣稱本輪 **複跑驗證為真**（數字同級、PASS） |
| CODEX R7 驗證可信度 | **高**（R7 回歸本輪綠；Stress 本輪綠且指標對齊） |
| R8 總判定 | **R7 辯論必修（P0/P1）在碼與回歸上成立，可維持上線原型宣告**；尚未到「對外宣傳級發布」——缺教學閉環、死亡敘事、音效、成就／分享鉤子與長局軟鎖防護 |

**一句話**：R7 修的是「謊稱生效／暫停疊層／平衡方向／進化政策」這類會直接打臉玩家的洞，而且修對了；R9 該轉的是 **對外可講故事的產品完成度**，不是再挖三支柱主幹。

狀態標籤：

- **成立**／**部分成立**／**未達設計意圖**／**殘留**／**預存灰區**／**發布缺口**

優先級：

| 等級 | 意義 |
|------|------|
| **P0** | 正確性、軟鎖、UI 謊稱、破 cap |
| **P1** | 體驗閉環、平衡方向、池健康、Web 熱路徑 |
| **P2** | 文案／作弊韌性／體感調校／內容擴充 |

---

## (0) 變更盤點（以 commit `2bad09b` 為準）

| 項目 | 實況 |
|------|------|
| HEAD | `2bad09b` — *R7 輪：三支柱深度完成…＋辯論修正* |
| 分支 | `main` ≡ `origin/main`（本輪工作區乾淨） |
| 體量 | 30 files，+2222 / −52 |
| 本輪審點 | 非重審包 3–5 全量敘事，而驗 **R7 辯論回應是否落地** |

辯論修正落點（與 CODEX R7 對照）：

| 宣稱 | 主要檔案 |
|------|----------|
| Meta delta 重套用 | `game_manager.gd`（`META_*_APPLIED_KEY`、`apply_current_meta_progress_*`） |
| 契約購買後立即套用 | `contract_screen.gd` |
| `system_pause_owners` | `game_manager.gd`；HUD `manual_pause_visible` |
| Modal layer 25 | Contract／Shop／Victory `.tscn`／runtime `layer` |
| 招募 Meta | `squad_manager.gd` `recruit_hero` |
| swift ×0.9 | `enemy_spawner.gd` |
| 餘燼井延遲爆 | `explosion_weapon.gd`、`entity_factory.spawn_delayed_explosion` |
| evo 傷≥3＋權重 0.35 | `weapon_data.gd`、`squad_manager._numeric_upgrade_weight` |
| 回歸補洞 | `r7_regression_test.gd` |

---

## (1) R7 修正逐條對抗驗收

### 1.1 R7-B1：契約畫面購買 Meta — 當局 delta 重套用

#### 設計契約（R7 要求）

1. 契約 UI 買「裂隙韌性／回收餘波」後 **本局立即生效**（不可再「下一局才算」）。  
2. 重套用 **不重複疊加**。  
3. 三軌體驗一致（含共鳴火花當局傷）。  

#### 證據鏈

| 層 | 位置 | 行為 |
|----|------|------|
| 購買 | `contract_screen.gd:151-156` | `buy_upgrade` 成功 → `apply_current_meta_progress_to_squad()` → `emit_stats` |
| 套用 | `game_manager.gd:845-868` | HP：`base = max_hp / previous_multiplier`，`new = base * current`；拾取：`base = radius - previous_bonus`，再加新 bonus；結果寫回 meta key |
| 開局 | `:200`、`_apply_meta_progress_start_effects` | 開跑先套一次快照 |
| 傷害軌 | `get_outgoing_damage_multiplier` `:578-581` | **live 讀** `MetaProgress.get_damage_multiplier()`，無需寫入英雄欄位 |
| 回歸 | `r7_regression_test.gd:101-147` | 買 vitality／magnetism → HP×1.02、pickup+6；再 `apply` 不變；招募另測 |

#### 數值不疊加證明（靜態）

- 第一次買：`previous=1.0` → `new = base * 1.02`，meta=`1.02`。  
- 第二次同級重套（回歸有測）：`previous=1.02` → `base' = max/1.02` → `new = base' * 1.02` ≡ 原值。  
- 連升兩級：每次 `buy` 後 level+1，multiplier 階梯上升，delta 為相對前次 key 的比，**不會 1.02×1.02 連乘在錯誤基底上**。  

#### 三軌一致性

| 軌 | 機制 | 當局購買後 | 判定 |
|----|------|------------|------|
| 韌性 HP | sticky + meta key | 立即改 `max_hp`／比例保留 `current_hp` | **成立** |
| 拾取 | sticky + meta key | 立即改 `pickup_radius` | **成立** |
| 傷害 | live multiplier | 下一發武器傷即含新係數 | **成立**（機制不同，結果一致） |

#### 對抗註記（非否決）

| ID | 等級 | 觀察 |
|----|------|------|
| R8-M1 | P2 | 契約 `max_hp_multiplier`（如 0.92）在 **選約後** 直接乘在已含 Meta 的 `max_hp` 上，**不**寫入 `META_HP_APPLIED_KEY`。正常流程是「先買 Meta → 再選約」，組成正確。若未來允許局中再買 Meta，需把契約 HP 也納入可逆帳本，否則與個人 `max_hp` 升級交織會漂。 |
| R8-M2 | P2 | 回歸未測 `echo_focus` 購買後 DPS 即變（live 路徑靜態可信）。 |

| ID | 命題 | 判定 |
|----|------|------|
| R8-B1a | 當局 HP／拾取生效 | **成立** |
| R8-B1b | 不重複疊加 | **成立** |
| R8-B1c | 三軌一致 | **成立** |

---

### 1.2 R7-B1：`system_pause_owners` 與暫停面板互斥

#### 證據鏈

| 層 | 位置 | 行為 |
|----|------|------|
| Owner API | `game_manager.gd:266-297` | `_request/_release/_clear`；`tree.paused = manual \|\| system` |
| 顯示 | `_is_manual_pause_visible` = `manual && !system`；`pause_changed` 只發「手動可見」 | 系統 modal 開時 HUD 暫停面板 **不顯示** |
| HUD | `hud.gd:239-243` | 吃 `manual_pause_visible` |
| 手動切換擋 | `toggle_pause`／`set_manual_pause` | 契約／升級／商店／勝利／死亡／未開跑時 **直接 return** |
| 各系統 request | upgrade／shop／contract／stage_victory／game_over | 皆走 owner，不再裸 `get_tree().paused = true` |
| Layer | Contract／Shop／Victory = **25**；LevelUp = **20**；HUD = **10**；GameOver = **30** | 系統層高於 HUD |
| HUD 輸入 | `hud.gd` root `MOUSE_FILTER_IGNORE` | 不全螢幕吞輸入（R7 宣稱對齊） |
| 回歸 | `r7_regression_test.gd:150-213` | 手動暫停可見 → 契約 system pause → overlay 隱藏；layer 25>10；點選契約卡可收 |

#### 漏網路徑掃瞄（對抗重點）

| 情境 | 結果 | 判定 |
|------|------|------|
| 手動暫停中開契約 | overlay 隱藏，tree 仍 paused | **成立**（回歸覆蓋） |
| 契約／商店／升級 **新開** | `_request_shop` 等以 `waiting_*` 互斥 | **成立**（進不去雙開） |
| 升級結束 10% 轉商店 | 先 `waiting_for_upgrade=false` → request shop → release upgrade | owners 短暫可含二者，最終 `{shop}`；升級 UI 已在選卡時關 | **可接受** |
| Boss 擊殺 vs 商店／升級 | `record_boss_kill` **不**檢查 `waiting_*`，會加 `stage_victory` | 戰鬥在 system pause 下不跑，**實務難與商店並存**；屬防禦性缺口 | **灰區 P2** |
| 死亡 | `player_died` clear 全部 owner → `game_over`；商店聽 `waiting_for_shop` 自動 `visible=false` | **成立** |
| 勝利繼續 | 只 release `stage_victory`；若 manual 仍 true 會回到手動暫停 UI | **成立** |
| 商店 vs 勝利同 layer 25 | 理論 z 序依樹；因雙開難觸發 | **P2 未回歸** |
| 升級 layer 20 < 商店 25 | 升級→商店時升級已關 | **OK** |
| 回歸覆蓋商店／升級／勝利互斥 | **無**（僅契約） | **覆蓋缺口 P2** |

| ID | 命題 | 判定 |
|----|------|------|
| R8-P1a | 暫停面板不蓋契約 | **成立** |
| R8-P1b | 系統／手動分流 | **成立** |
| R8-P1c | 商店／升級／勝利交疊無漏 | **部分成立**（主路徑安全；owner 非硬互斥、回歸不全） |

---

### 1.3 R7-B2：招募 Meta 快照

| 層 | 位置 | 行為 |
|----|------|------|
| 招募 | `squad_manager.gd:390-392` | spawn 後 `apply_current_meta_progress_to_member(hero)` |
| 新成員 meta | 無 key → previous HP mult=1.0、pickup bonus=0 | 套 **當前** 全額快照 |
| 回歸 | recruit `line_mender` HP `91.80`=90×1.02、pickup 72+6 | **成立** |

**判定：成立。** 隊員中途入隊不再「裸基礎血」。

---

### 1.4 R7-B3：swift 傷 ×0.9

| 層 | 位置 | 實況 |
|----|------|------|
| 配置 | `enemy_spawner.gd:277` | `damage *= 0.9`（不再 1.05） |
| HP | `:275` | 仍 ×0.82 |
| AI | dasher | 保留質變 |
| 回歸 | `swift_damage=16.38` 且 `<16.5` 門檻 | 玻璃砲帶 |

**判定：成立**（對齊 R6／R7 設計方向）。field 數值略兇、星環脈動偏弱等 **非本輪必修**，仍屬體感 P2。

---

### 1.5 R7-B4：餘燼井 0.45s 延遲二段爆

| 層 | 位置 | 行為 |
|----|------|------|
| 開火 | `explosion_weapon.gd:18-27` | 主爆 → 井 → `spawn_delayed_explosion(..., 0.45)` |
| 二段係數 | `:59-67` | damage ×0.55、半徑 ×0.82 |
| 延遲 | `entity_factory.gd:229-235` | `create_timer(delay, false)`；結束若 `!game_running` 則 abort |
| 傷害紀律 | `spawn_explosion` **先** `_apply_explosion_damage` 再管 VFX cap | 爆滿 cap 仍結算傷害（與主爆一致） |
| 回歸 | 延遲 0.02s 測傷；係數 0.55 對齊 | **成立** |

**對抗註記**：延遲 timer `process_always=false`，系統暫停時會凍結——正確。局末 abort 防死後鞭屍——正確。  
本輪 R8 複跑日誌 `hp 30.00->0.00`（CODEX 寫 11.85）仍 **PASS**（斷言只要求扣血）；差額可能來自測試殘局／額外來源，**不否決**二段爆存在，但顯示回歸對「精準 0.55 段傷」的隔離度一般（P2 測品）。

**判定：成立。**

---

### 1.6 R7-B5：進化 `weapon_damage≥3`＋進化後線性權重 ×0.35 — 池是否還健康

#### 條件

| 層 | 位置 | 行為 |
|----|------|------|
| 定義 | `weapon_data.gd` 四 evo 皆 `required_damage_level: 3` | |
| 閘門 | `can_offer_evolution` | 質變滿層 ∧ `weapon_damage` 層數 ≥3 ∧ `run_level≥7` ∧ 未進化 |
| 投資記帳 | `apply_upgrade("weapon_damage")` → `_increment_runtime_modifier` | |

#### 權重

| 層 | 位置 | 行為 |
|----|------|------|
| 數值卡 | `squad_manager._numeric_upgrade_weight` | 已進化 → **0.35**，否則 1.0 |
| 作用面 | damage／cooldown／projectiles **共用** 該權重 | |
| evo 卡 | weight **8** 一次性 | |
| 回歸 | 未滿傷不給 evo；進化後 numeric weight ≤0.36 | **成立** |

#### 升級池健康度估算（對抗核心）

權重來源（實作常數）：

- 招募：每可招英雄 **4**（最多 2 席：5−3）  
- 質變：**3**／張（可耗盡）  
- 進化就緒：**8**／把  
- 線性：未進化 **1.0**×（傷／CD／彈數），已進化 **0.35**  
- 個人池：移速／HP／拾取各 **1**（有 max_level）  

| 情境 | 粗算權重結構 | 會不會「只剩招募」？ |
|------|----------------|----------------------|
| 質變打完、尚未 evo（缺傷或未 Lv7） | 線性仍 1.0 為主 + 招募 4 + 個人 1 | **否** — 線性仍厚 |
| 1–2 把 evo 就緒 | evo 8 搶眼，但池內仍有線性／招募／個人 | **否** — evo 高權重是設計 |
| 滿編 5 人、全武器已進化、質變盡 | 線性 ≈5×3×0.35=**5.25** + 個人 **3** + 招募 **0** | **否** — 反而是線性+個人 |
| 3 人、2 可招、全 evo、質變盡 | 招募 **8** vs 線性≈3.15 + 個人 3 → 招募約 **56%** | **偏招募但非唯一**；三選一仍常混到非招募 |
| 長無盡：數值／個人 max 耗盡 | filtered 池可能 **空** | **軟鎖風險（預存）** — 升級 UI 無卡可點 |

**結論**：×0.35 **不會**把池質變成「只剩招募」；招募在「未滿編＋已進化」時偏強是可預期的政策結果。真正的發布風險是 **池耗盡 0 options**（與 B5 無直接因果，屬長局完成度）。

| ID | 命題 | 判定 |
|----|------|------|
| R8-B5a | 傷≥3 門檻 | **成立** |
| R8-B5b | 進化後線性 ×0.35 | **成立** |
| R8-B5c | 池仍健康、非只剩招募 | **成立**（中後期可接受；長局空池灰區另列） |

---

## (2) 殘留 P2 與宣稱核對

### 2.1 R7-B6：split 硬 cap 下常只出 1 小體

| 項目 | 實況 |
|------|------|
| 機制 | 父體先 `is_active=false` 讓 1 格 → 小體 loop 遇 `active≥cap` 即停 |
| 安全 | **永不破 150** — 仍成立 |
| 設計取捨 | CODEX／R7 同意不修 — **本輪仍不修** |
| 玩家體感 | 滿場殺裂殖精英「只吐 1 隻」— 規則怪威脅被 cap 裁切 |

**判定：殘留 P2（邊界／體感），非 bug。** 若 R9 要強化威脅，應用「保證 2 隻但踢最舊雜兵」等 **有 cap 的置換策略**，而不是放寬 150。

---

### 2.2 cfg 校驗（`user://veil_echo.cfg`）

| 檢查 | 實況（`meta_progress.gd`） | 判定 |
|------|---------------------------|------|
| 缺檔／壞檔 | load 失敗 → 預設 0，不崩 | **成立** |
| level clamp | 0…max_level | **成立** |
| shards ≥0 | `max(0, …)` | **成立** |
| checksum／簽名 | **無** | **殘留 P2** |
| lifetime vs shards 一致性 | **不校驗**（可改 lifetime 騙解鎖） | **殘留 P2** |
| 載入失敗 UI 標示 | **無**（靜默新檔） | **殘留 P2** |

Web 單機可接受；**對外宣傳「有進度系統」時**建議至少：損壞提示＋可選「重置進度」入口（不必反作弊軍備賽）。

---

### 2.3 R7「未複跑 Stress」的宣稱 — R8 複跑結果

| 來源 | 宣稱 |
|------|------|
| GROK R7 | 本輪未複跑 Stress；靜態可信 |
| CODEX R7 | Stress avg 7.329ms、p95 16.078ms、`enemy_group_scans=0`、pool exhausted 0、全 debug PASS |

**R8 本機 headless 複跑**（Godot 4.7，`StressTest.tscn`）：

```
STRESS_RESULT ... avg_ms=7.026 p95_ms=15.207 max_ms=31.971
STRESS_COUNTERS ... enemy_group_scans=0 ...
STRESS_POOL_STATS ... exhausted=0（各池）
STRESS_PASS
```

| 指標 | CODEX R7 | R8 複跑 | 判定 |
|------|----------|---------|------|
| avg_ms | 7.329 | **7.026** | 同級 |
| p95_ms | 16.078 | **15.207** | 同級 |
| group_scans | 0 | **0** | **成立** |
| pool exhausted | 0 | **0** | **成立** |
| 結果 | PASS | **PASS** | **宣稱可採信** |

另：`R7RegressionTest` 本輪 **R7_REGRESSION_PASS**（含 B1／B2／B3／B4／B5／echo delta）。

**判定：殘留「R7 當時未複跑」的流程債已由 R8 清掉；數值宣稱不是空話。**  
附註：`STRESS_PERF_BELOW_60=true`（min_fps 因 max_ms 尖峰）— 與歷輪一致，屬尖峰監控，不是 group 掃描回歸。

---

### 2.4 其他 R7 已標、本輪未改的體感項

| 項 | 狀態 |
|----|------|
| field 128／22% 略兇 | 延後 P2 |
| 星環 sin 脈動偏弱 | 延後 P2 |
| 裂扇 fork cap 靜默 skip | 延後 P1 體感 |
| Meta 幅度偏保守 | 守紅線，可接受 |

---

## (3) 紅線快檢（R7 入版後）

| 紅線 | R8 | 證據 |
|------|-----|------|
| 命中 token | 維持 | 本輪未改主契約 |
| max_enemies 150 | 維持 | split 仍 active-count cap |
| 武器熱路徑 group 掃敵 | 維持 0 | Stress `enemy_group_scans=0` |
| 池化／explosion 延遲爆 | 成立 | 延遲最終 `spawn_explosion` |
| Meta 不破單局平衡 | 成立 | 幅度未改 |
| 決定性 seed | 維持 | affix 仍吃 run RNG |
| 新引入 P0 | **未發現** | B1–B5 主路徑成立 |

---

## (4) R7 修正總表

| ID | 項目 | CODEX 宣稱 | R8 對抗結論 |
|----|------|------------|-------------|
| B1 Meta 當局 | 修 | 修 | **成立** |
| B1 暫停互斥 | 修 | 修 | **主幹成立**（交疊回歸不全） |
| B2 招募 Meta | 修 | 修 | **成立** |
| B3 swift ×0.9 | 修 | 修 | **成立** |
| B4 餘燼二段爆 | 修 | 修 | **成立** |
| B5 門檻＋權重 | 修 | 修 | **成立**；池健康 **成立** |
| B6 split 1 小體 | 不修 | 不修 | **殘留 P2** |
| cfg 校驗 | 未做 | 未做 | **殘留 P2** |
| Stress | 宣稱 PASS | 本輪複跑 | **驗證成立** |

**R8 對 R7 修正的總判：P0/P1 必修項落地為真；可維持「可玩 Web 原型已上線」敘事，不可升級為「系統已完工、可大推」。**

---

## (5) R9「發布品質」檢查清單

標準：**這遊戲要對外宣傳**（Steam 頁／社群 Demo／投資人試玩／媒體包），不是「repo 裡能跑」。  
排序：影響「第一印象 → 第一死 → 想再開一局 → 願意轉分享」的漏斗。

### 5.1 P0 — 沒做就不要大聲宣傳

| # | 項目 | 現況 | 為何卡宣傳 | 建議最小交付 |
|---|------|------|------------|--------------|
| R9-0.1 | **首局引導／操作提示** | 無教學；僅 README 控鍵 | Web 點進來的人不知道 WASD／P／虛擬搖桿意義；契約三選一零解釋 | 開局 1 頁半透明提示（移動／自動攻擊／升級三選一）+ 首次契約「選一條本局規則」一句話；可永久關閉 |
| R9-0.2 | **死亡回饋閉環** | GameOver 有數字＋殘響，但缺「你為什麼死／下一局可做什麼」 | 失敗＝冷表格 → 流失 | 結算加：存活時長評價、擊殺階段、**本局殘響去向**（可買什麼）、一鍵「再來一局」（已有重開則強化文案） |
| R9-0.3 | **升級池耗盡軟鎖** | 長無盡可能 0 張卡 | 宣傳片玩家玩到後期卡死＝公關事故 | 保底：空池時給「全隊小回復／金幣／臨時傷」通用卡或自動跳過並解暫停 |
| R9-0.4 | **宣傳用穩定建置** | 有 Pages 部署與 pck≈3.06MB | 需保證每次宣傳連結可玩 | 固定 demo URL、版本號／build 日期顯示於 HUD 或暫停；CI 紅不部署 |

### 5.2 P1 — 有了才像「產品」而非「build」

| # | 項目 | 現況 | 建議 |
|---|------|------|------|
| R9-1.1 | **音效佔位** | **無任何** `.wav`／`.ogg`；純靜音 | 至少 6 槽：移動可無；**開火／命中／升級／買契／精英出現／死亡**；Web 需首次手勢解鎖 AudioContext 提示 |
| R9-1.2 | **Hit feedback** | 有傷害字／死亡 burst；缺 hit-stop／螢幕震 | 精英／Boss 擊殺 0.03–0.06s hit-stop（R4 已提過） |
| R9-1.3 | **詞綴／進化可讀性** | 有色環；缺圖鑑或首次遭遇說明 | 首次遇到 affix 跳 1.5s toast；進化時卡面強調「質變」色 |
| R9-1.4 | **Meta 進度入口** | 只在開局契約／結算看到 | 暫停或 GameOver 顯示三軌等級；損壞存檔提示 |
| R9-1.5 | **行動／直式 UI** | 有 responsive 與虛擬搖桿 | 實機瀏覽器測 3 機型；暫停／契約按鈕≥44px |
| R9-1.6 | **Boss／階段勝利敘事** | 有階段勝利＋無盡 | 勝利畫面加一句世界觀；「繼續無盡」風險提示（難度不減） |
| R9-1.7 | **性能宣傳底線** | Stress 尖峰 min_fps 可低於 60 | 對外寫「建議裝置／瀏覽器」；Web 低配檔（可關傷害字）可選 |
| R9-1.8 | **fork／裂扇體感** | cap skip 靜默 | 可選：極少裂片時小型 UI／音效提示（勿刷屏） |

### 5.3 P2 — 讓人「想分享／想追蹤」

| # | 項目 | 現況 | 建議 |
|---|------|------|------|
| R9-2.1 | **成就（輕量）** | 無 | 本地 8–12 個即可：首殺精英、首進化、首 Boss、滿編 5 人、三詞綴各遇一次、殘響解鎖契約槽…；GameOver 彈「解鎖！」 |
| R9-2.2 | **每日／種子分享** | 有 seed 基建 | 「複製本局種子」按鈕 → 社群互相比拼 |
| R9-2.3 | **設定頁** | 無 | 音量、傷害字開關、螢幕震動、重置 Meta |
| R9-2.4 | **內容可信包裝** | README 編碼有時亂碼；缺商店頁文案 | 一頁 `PRESSKIT`：3 圖、30 字 pitch、操作、瀏覽器需求 |
| R9-2.5 | **無障礙** | 僅部分 | 色盲：詞綴不只靠色相（形狀／圖示）；閃爍可關 |
| R9-2.6 | **cfg 韌性** | 無校驗 | 載入失敗 toast + 重置；可選簡單 checksum |
| R9-2.7 | **B6 裂殖體感** | 滿 cap 1 小體 | 置換生成或接受並寫進詞綴說明「裂殖受戰場容量限制」 |
| R9-2.8 | **音樂** | 無 | 1 條 loop BGM 即可大幅抬升宣傳片質感 |

### 5.4 明確「現階段不要承諾」

| 承諾 | 原因 |
|------|------|
| 完整聯機／排行榜 | 無後端；Web 本地可作弊 |
| 數十角色／自動棋深度 | 目前 5 英雄 4 武器骨架 |
| 「已平衡 100 小時」 | mock／回歸在，真人長測不足 |
| 原生移動商店包 | 現主線是 Web；行動是瀏覽器試玩 |

### 5.5 建議 R9 衝刺順序（兩週對外 Demo 假設）

```text
Week A（可信可玩）
  1) 首局引導 + 死亡結算文案     [P0]
  2) 空升級池保底                 [P0]
  3) 六槽音效佔位 + 升級/死亡音   [P1]
  4) 版本號／build 顯示           [P0]
  5) 首次詞綴 toast + 進化卡強調 [P1]

Week B（可分享）
  6) 本地成就 8 個 + 結算彈出     [P2]
  7) 暫停設定（音量／重置 Meta）  [P2]
  8) 種子複製 + Press kit 一頁    [P2]
  9) 行動瀏覽器實機修 UI          [P1]
 10) （可選）BGM loop 1 條        [P2]
```

**發布門檻建議（Go／No-Go）**

| 門檻 | Go 條件 |
|------|---------|
| 軟 Go（小圈試玩） | P0 全綠 + R5/R6/R7 回歸綠 + Stress group_scans=0 |
| 硬 Go（公開宣傳） | 軟 Go + 音效佔位 + 首局引導 + 死亡閉環文案 + 實機 3 場無軟鎖 |
| 宣傳升級（廣告放量） | 硬 Go + 成就或種子分享 + 已知問題清單公開 |

---

## (6) R9 技術債清單（只建議不改）

| 序 | 等級 | 項目 |
|----|------|------|
| 1 | P0 | 升級 choices 空陣列時的 UI／暫停解困 |
| 2 | P1 | 商店／升級／勝利 owner 回歸（雙開與死亡清 UI） |
| 3 | P1 | 契約 HP 與 Meta key 可逆帳本（若局中 Meta 擴充） |
| 4 | P2 | veil_echo.cfg 損壞提示＋可選 checksum |
| 5 | P2 | split 滿 cap 體感或文案誠實化 |
| 6 | P2 | 餘燼二段爆回歸改為隔離期望扣血值 |
| 7 | P2 | field／星環微調（非阻擋） |

---

## (7) 一句話結案

R7 入版修正 **經得起對抗複驗**：B1–B5 在程式與 headless 回歸上為真，Stress 指標本輪複跑對齊，**沒有發現新的 P0 主幹崩壞**。  
B6／cfg／部分暫停交疊覆蓋與長局空池仍是誠實的灰區。  

**R8 總判：辯論修復驗收通過；產品狀態 =「可公開試玩的深度原型」，距離「可對外大聲宣傳的 1.0 Demo」還差教學、死亡敘事、聲音與防軟鎖一層。R9 請按發布清單做完成度，而不是再開第四條大系統。**
