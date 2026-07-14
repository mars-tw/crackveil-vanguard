# DESIGN：第 10 英雄 ＋ 羈絆輕系統

**產品**：Crackveil Vanguard（squad-survivors roguelite）  
**作者角色**：遊戲設計總監（規劃規格，**只規劃不改碼**）  
**基準狀態**：R19 後＝**9 英雄 / 10 武器行為**、`max_members = 9`、隊長三武、質變→進化管線齊備  
**日期**：2026-07-13  
**文件路徑**：`docs/DESIGN_hero10.md`

---

## 0. 目標與成功標準

| 目標 | 成功長相 |
|------|----------|
| 第 10 英雄定位不撞車 | 與現有 9 位的「輸出形狀／戰場角色／操作體感」皆可一句話區分 |
| 編隊有取捨 | 玩家會為**特定組合**調整招募順序，而非永遠「能招就招」 |
| 輕量可維護 | 羈絆不做大樹／不做 3 人以上複雜條件；實作可掛在 SquadManager 旗標層 |
| 不破歷輪紅線 | 無 `enemies` group 熱掃、pool／cap 可量測、視覺 budget 不改玩法、Web pck 不失控 |
| 平衡可驗 | BalanceMock / ArenaInstrumentation 可讀到合理 DPS 分攤與存活曲線 |

**非目標（本輪規格刻意不做）**

- 不改既有 9 英雄武器核心行為。
- 不做「第 11 武器行為以外」的第二把新武器。
- 不做完整天賦樹、跨局永久羈絆、或 5 人陣營系統。
- 不承諾把滿編 Stress p95 壓回 60fps（既有 R19 債務）；只要求**新增內容不得明顯惡化**。

---

## 1. 現有 9 英雄定位地圖（避撞基準）

| ID | 顯示名 | 戰場角色 | 武器形狀 | 已佔用語意 |
|----|--------|----------|----------|------------|
| `rift_captain` | 裂隙隊長 | 旗艦主控 | 裂線 + 星環 + 雷鏈（3 槽） | 多軸輸出、相機／失敗中心 |
| `orbit_guard` | 星環護衛 | 近身前線切開 | 迴旋鏢往返 | 護盾刃、返場 |
| `arc_scout` | 裂弧斥候 | 側翼補刀／機動 | 追蹤飛彈 | 鎖定、蜂群 |
| `pulse_artificer` | 脈衝工匠 | 定點爆發 | 脈衝爆花 | 瞬爆 AoE |
| `line_mender` | 線紋修補者 | 遠火分攤 | 第二組裂線 | 與隊長共享原型的火力複製品 |
| `ember_grenadier` | 燼焰擲彈兵 | 區域壓制 | 拋物線榴彈＋燃區 | 延遲落點、連爆 |
| `void_weaver` | 虛空織網者 | 控場／窗口製造 | 虛空減速網 | **空間力場**、易傷／拖慢 |
| `rift_sniper` | 裂光狙擊手 | 高威脅點殺 | 超遠貫通狙擊線 | 長 CD 高傷直線 |
| `echo_singer` | 迴響歌者 | 存活輔助 | 治療脈衝＋短增傷 | **隊傷回復／光環** |

### 1.1 空缺分析（三選一）

| 方向 | 與現況重疊風險 | 編隊策略價值 | 工程／效能風險 | 判定 |
|------|----------------|--------------|----------------|------|
| **召喚系** | 低（無單位／建構體） | 高（站位、覆蓋、消耗品式 DPS） | 中（必須嚴格 cap，不可當第 2 小隊 AI） | **採用** |
| 時空系 | **高**（`void_weaver` 已佔空間控場；裂隙美學已覆蓋「縫／門」） | 中（時間減速易變全局 buff） | 中高（時間尺度 stack 是歷輪敏感點） | 備選 B |
| 吸血系 | **中高**（`echo_singer` 已佔可持續性；吸血易變純數值） | 中（偏單一「打得更久」） | 低 | 備選 C（更適合做羈絆或質變，而非整角） |

**總裁決策：第 10 英雄走召喚系。**  
時空留給虛空織網者深化；吸血留給羈絆／後期武器修飾，避免再塞一個「半治療半 DPS」。

---

## 2. 第 10 英雄規格

### 2.1 身分卡

| 欄位 | 規格 |
|------|------|
| `id` | `rift_shepherd` |
| 顯示名 | **裂隙牧者** |
| 一句定位 | **短命裂隙建構體的牧養者**：投放可自動攻擊的「裂傀」，用數量與站位換覆蓋，而不是自己射子彈。 |
| 對比句 | 不是第二個歌者（不奶人）；不是織網者（不主控場）；不是斥候（不追蹤彈）；建構體也不是可操作隊員。 |
| 角色標籤 | `Summon / Area Presence / Soft Sustain via constructs` |
| 建議 tint | 體色：冷紫青 `Color(0.42, 0.72, 0.88)`；核心：蒼白裂光 `Color(0.92, 0.98, 1.0)`（與虛空紫、隊長青可分） |
| Sprite 策略（成本） | **沿用 R19 方針**：既有 hero 底圖 + runtime tint；不強制新 PNG。若有美術預算，優先獨特剪影（肩上裂傀／手持裂隙燈籠）。 |
| `max_hp` | **96**（略高於多數跟隨者、低於隊長 110；召喚角需要扛一點近身交換） |
| `move_speed` | **218**（中慢：鼓勵「先佈陣再移動」，避免變成kite 機槍） |
| `hit_radius` | 12 |
| `pickup_radius` | 74 |
| 開局武器 | 僅 `rift_constructs`（1 槽） |
| `passive_id` | `shepherd` |
| `passive_value` | `1`（旗標語意：可同時維持的建構體上限加成見 §2.4） |
| 被動文案 | **裂牧心法**：場上每有 1 具存活裂傀，牧者自身受到傷害 −2%（上限 −8%，即 4 具時滿）。 |

被動故意做成**小防禦、可讀、有上限**，避免「召喚物越多輸出指數成長」。

### 2.2 招募與陣容槽位

| 項目 | 規格 |
|------|------|
| 進池 | `default_squad.available_heroes` 追加 `rift_shepherd` |
| **不進** starting trio | 開局仍：`rift_captain` + `orbit_guard` + `arc_scout` |
| `max_members` | **維持 9**（見 §4 平衡預算） |
| 名冊結果 | **10 選 9**：永遠有 1 名英雄被擠出本局，羈絆才有牙齒 |
| 招募 gate | 沿用 `RECRUIT_LEVEL_GATES`；第 9 槽仍 L8。牧者**不**需要特殊 gate，但建議權重與其他 R19 跟隨者同級（見 §4.2） |
| 死亡／重招 | 沿用 `recruited_once` + `dead_ids`：死亡不可同 id 重招；裂傀隨主人死亡**立即全部回收** |

### 2.3 專武：`rift_constructs`（裂傀編制）

#### 2.3.1 武器身分

| 欄位 | 規格 |
|------|------|
| `id` | `rift_constructs` |
| 顯示名 | **裂傀編制** |
| `behavior_id` | `rift_construct`（**新行為**；第 11 把武器） |
| 一句描述 | 週期在最近敵群方向前方投放短命裂傀；裂傀自主以低頻近距打擊周遭敵人，到期碎裂。 |
| 色票 | 青紫裂縫光 `Color(0.55, 0.82, 1.0)` |
| 視覺語言 | 半透明多面體／裂縫燈籠；落地有短「縫開」；死亡碎成 2–3 片小裂片（純 VFX，可不帶傷） |

#### 2.3.2 基礎行為（玩法契約）

```
每 cooldown 觸發一次「編制投放」：
1. 以 spatial index 找最近敵人（禁 group 掃）
2. 在「主人 → 目標」方向上、距離 spawn_offset 處生成 1 具裂傀
3. 若場上裂傀數已達 hard cap，回收最舊 1 具（FIFO）再生成
4. 裂傀：
   - 固定站位（不追人、不 pathfind）
   - 每 hit_interval 對 radius 內最多 max_targets_per_tick 名敵人造成 damage
   - 查敵只走 EnemySpatialIndex 小半徑 query
   - lifetime 結束 → 回收進 pool
```

**為什麼固定站位而非追擊 AI**

- 跟隨者已是 8 AI 單位；再加會追人的召喚物會把 formation／威脅讀取打爆。
- 固定站位讓玩家用**走位**決定覆蓋，形成可學的微操，而非自動清圖。

#### 2.3.3 建議基準數值（初稿，實作後以 BalanceMock 校）

| 參數 | 初值 | 註記 |
|------|------|------|
| `damage` | 7.0 | 單擊偏低；靠多體覆蓋 |
| `cooldown` | 2.4 s | 投放節奏 |
| `range` | 420 | 投放尋敵距離 |
| `spawn_offset` | 72 px | 落在主人前方，不貼臉 |
| `area_radius`（裂傀攻擊半徑） | 54 | 近距「咬一口」 |
| `hit_interval` | 0.55 s | 低頻，避免 tick 爆炸 |
| `effect_lifetime`（裂傀壽命） | 5.5 s | 與 CD 交錯可維持 2–3 具 |
| `projectile_count` 語意 | **同時存在上限 base = 3** | 不是子彈數 |
| `max_targets_per_tick` | 2 | 每具每 tick 最多打 2 個 |
| `hard_cap_global` | **6** | 全場裂傀上限（含質變／進化／被動加成後仍不可破） |
| `pool prewarm` 建議 | 8–12 | 與 hazard／orbit 同級謹慎擴張 |
| 數值升級 | damage +2.0；cooldown ×0.9；lifetime +0.4（可走 `area`/`projectiles` 槽語意映射） | 映射需寫死，避免誤加「子彈數」到 20 |

**DPS 期望（單英雄滿編情境下的「公平份額」）**

- 未進化、中期：約 **全隊總 DPS 的 8–12%**
- 進化後高峰：約 **12–16%**
- **不得**長期超過斥候飛彈或隊長單一主武的穩定份額成為 carry 核

參考 R19：`leader_dps_share ≈ 0.41`（滿編）。牧者加入後目標仍維持：

- `leader_dps_share`：**0.38–0.48**
- 任一跟隨者單武（含進化）：**< 0.20** 全隊 DPS

#### 2.3.4 質變（Qualitative）

沿用現有「行為鍵 → 質變卡 → 滿級後可進化」模式。

| `upgrade_kind` | 名稱 | 最大等級 | 效果 |
|----------------|------|----------|------|
| `construct_anchor` | **裂錨定駐** | 2 | **L1**：裂傀壽命 +1.2s，攻擊半徑 +8。**L2**：投放改為「雙裂傀並肩」（同 tick 生成 2，仍受 hard cap）；單次投放傷害係數 ×0.85（防暴衝）。 |

**不做**第二條質變（例如再加爆炸），避免升級池稀釋與 cap 失控。雷鏈那類雙質變是歷史例外，新武統一 **1 質變 → 1 進化**。

#### 2.3.5 進化（Evolution）

| 欄位 | 規格 |
|------|------|
| `evolution_id` | `evo_mirror_flock` |
| 名稱 | **鏡裂群牧** |
| 前置 | `construct_anchor` ≥ 2、`weapon_damage` ≥ 3、`run_level` ≥ 7 |
| 質變描述（進化卡） | 裂傀碎裂時釋放短距裂片波；場上裂傀之間若距離 < 120，共享 +12% 傷害（不疊層）。 |
| 數值套用（建議） | `projectile_count` 上限語意 +1（3→4，仍 ≤ hard cap 6）；`hit_interval` ×0.9；`color` 轉高亮青白；碎裂波：`damage * 0.55`、`radius 70`、**單次** spatial query、不生成新投射物實體（可用既有 `ExplosionArea` 但受 explosion active cap） |

進化的可讀 fantasy：**群牧共鳴**——人多時彼此強化，死亡仍有告別一擊。  
禁止：碎裂再召喚、無限連鎖、對全圖 query。

### 2.4 與隊長的協同（Captain Synergy）

隊長是編隊核，新英雄必須「靠近隊長有感覺」，但不能綁死到沒隊長就不能用。

| 協同層 | 規則 | 預算 |
|--------|------|------|
| **A. 被動光環（常駐小）** | 裂傀中心點若落在隊長 `hit_radius + 140` 內，該裂傀傷害 **+10%** | 小；可讀為「隊長裂隙核心供能」 |
| **B. 武器交互（可選、建議做）** | 隊長 `orbit_blades` 掃過裂傀時，**不**造成友傷；改為給該裂傀 **+15% 攻速 1.0s**（刷新不疊） | 中；強化星環定位又不改 orbit 對敵公式 |
| **C. 文案／教學** | 招募卡副標：「與隊長靠近時裂傀更兇」 | 零成本 |

**明確不做的隊長協同**

- 不讓裂傀繼承隊長三武傷害。
- 不在隊長死亡後讓裂傀「接管鏡頭」或延命。
- 不加「全隊每招一個牧者就 triple」的隊長被動。

### 2.5 與其他英雄的自然相性（非羈絆、僅設計直覺）

| 搭檔 | 直覺 |
|------|------|
| `void_weaver` | 網住敵人 → 裂傀站樁輸出窗口拉長 |
| `echo_singer` | 歌者保命，牧者用身體與裂傀換前線 |
| `ember_grenadier` / `pulse_artificer` | 燃區／爆花清外圈，裂傀守內圈 |
| `rift_sniper` | 狙擊點殺精英，裂傀處理雜兵 |
| `line_mender` | 較弱（兩者都偏「補火力」）；靠羈絆系統以外的取捨自然弱化 |

---

## 3. 英雄羈絆輕系統（Bond Lite）

### 3.1 設計原則

1. **輕**：同場存活 ≥ 2 名指定英雄即啟動；無需裝備、無需升級、無需站位（站位留給武器本身）。
2. **小**：每條羈絆只給 **一個** 可感知但非局變的小被動。
3. **少**：本規格只定 **4 組**；日後擴充上限建議全遊戲 ≤ 6 組。
4. **可讀**：HUD 或 LevelUp 不強制大 UI；最小實作可在招募卡 description 末行註記「羈絆：xxx」。進階可在 HUD 以小圖示列出已啟動羈絆（1 行文字）。
5. **可疊但有天花板**：多組羈絆可同時存在，但**單一名詞屬性**（如傷害%、減速）全來源合計要有全域 soft cap（見 §4.3）。
6. **不引入新成長曲線軸**：羈絆**不**進升級三選一池，避免再稀釋招募／質變／進化。

### 3.2 啟動與失效規則

| 規則 | 規格 |
|------|------|
| 檢測時機 | 成員 `recruit` / `death` / `start_squad` 後重算一次（事件驅動，**非每幀**） |
| 條件 | 名單中英雄皆 `is_alive` 且已在 `member_ids` |
| 隊長 | 可參與羈絆（有一組含隊長） |
| 死亡 | 任一成員死亡 → 該組立即失效；不回溯已造成的傷害 |
| 重算成本 | O(bonds × 2) 查表；bonds 常數 4，可忽略 |
| Debug | 建議 log 旗標：`BONDS_ACTIVE=[id,...]`（僅 debug build） |

### 3.3 四組羈絆定案

#### 羈絆 1｜燼脈聯爆（AoE 線）

| 欄位 | 內容 |
|------|------|
| `bond_id` | `bond_ember_pulse` |
| 成員 | `ember_grenadier` + `pulse_artificer` |
| 名稱 | **燼脈聯爆** |
| 效果 | 範圍系武器（`behavior_id in {explosion, grenade_lob}`）的 `area_radius` **+8%**；燃區／餘燼 tick 傷害 **+6%** |
| 設計意圖 | 獎勵「雙爆發」編隊；清潮感 upstream，不直接加暴擊 |
| 紅線注意 | 只改這兩把武器 runtime 倍率，不掃全武器；mobile 表現 cap 不變 |

#### 羈絆 2｜縫獵協議（控場 × 點殺）

| 欄位 | 內容 |
|------|------|
| `bond_id` | `bond_void_rail` |
| 成員 | `void_weaver` + `rift_sniper` |
| 名稱 | **縫獵協議** |
| 效果 | 對**處於減速狀態**的敵人，`rail_lance` 傷害 **+12%**；`void_net` 持續時間 **+0.4s** |
| 設計意圖 | 經典 CC → 爆發窗口；教玩家先網後狙 |
| 紅線注意 | 易傷／減速讀既有 status，不新造第二套狀態機；禁止改 `Engine.time_scale` |

#### 羈絆 3｜星盾和聲（前線存活）

| 欄位 | 內容 |
|------|------|
| `bond_id` | `bond_guard_echo` |
| 成員 | `orbit_guard` + `echo_singer` |
| 名稱 | **星盾和聲** |
| 效果 | 全隊受到傷害 **−5%**；`echo_hymn` 治療量 **+10%** |
| 設計意圖 | 明確「能扛更久」的防守編；對抗後期密度 |
| 紅線注意 | 減傷與治療分項都小；與牧者被動疊加時受 §4.3 soft cap |

#### 羈絆 4｜牧長裂約（新英雄錨點）

| 欄位 | 內容 |
|------|------|
| `bond_id` | `bond_captain_shepherd` |
| 成員 | `rift_captain` + `rift_shepherd` |
| 名稱 | **牧長裂約** |
| 效果 | 裂傀 hard cap **+1**（3/4 基礎語意不變，但 global hard cap 6→**仍封頂 6** 時，此 +1 只在 base≤5 時有效——實作上：**同時存在上限 +1，最終 `min(base+bonuses, 6)`**）；裂傀在隊長 140px 內的協同傷害由 +10% 提升至 **+16%** |
| 設計意圖 | 給第 10 英雄一個「值得為他擠掉某人」的旗艦理由；強化隊長中心編隊 fantasy |
| 紅線注意 | **絕對不得**把 hard cap 開到 8+；+1 必須吃全域 cap |

### 3.4 未收錄但可後備的羈絆（本版不做）

| 構想 | 為何暫緩 |
|------|----------|
| `arc_scout` + `rift_sniper`（雙遠程） | 兩者已強；再加易變 hang-back 最優解 |
| `line_mender` + `rift_captain`（雙裂線） | 共享原型，數值疊加風險高 |
| 三人羈絆 | 違反「輕系統」；UI 與組合爆炸 |

### 3.5 玩家可見文案範本

- 招募卡（牧者）：`「可與裂隙隊長觸發羈絆：牧長裂約。」`
- 招募卡（擲彈兵）：`「與脈衝工匠同場：燼脈聯爆。」`
- HUD 最小版：`羈絆 2/4　燼脈聯爆 · 牧長裂約`

### 3.6 資料形狀建議（實作備註，非本輪改碼）

```text
BondDefinition:
  id: String
  hero_ids: PackedStringArray  # 長度 2
  display_name: String
  description: String
  modifiers: Dictionary       # 例：{ "aoe_radius_mul": 1.08, "damage_taken_mul": 0.95 }
```

掛點建議：`SquadManager.recompute_bonds()` → 寫入 `GameManager` run flags 或 squad runtime buff table；武器讀取時乘上對應倍率。

---

## 4. 平衡預算與紅線

### 4.1 內容預算

| 項目 | 預算 | 理由 |
|------|------|------|
| 新英雄 | **+1**（名冊 10） | 任務目標 |
| 新武器行為 | **+1**（總武器 11） | 召喚必須有獨立行為，不可复用 orbit／hazard 假冒 |
| `max_members` | **不增加**（維持 9） | 滿編已接近 perf 邊緣；10 選 9 服務編隊策略 |
| 羈絆 | **4 組** | 可感知又不爆炸 |
| 新質變／進化 | 各 **1** | 對齊 R19 武器管線 |
| 新被動實作 | 牧者 1 + 羈絆旗標 | 既有 `passive_id` 多為預留，本輪允許**真正生效**但只限本英雄與羈絆 |
| 美術 | tint 可上線；專屬 sprite **可選** | 不擋玩法 |
| 字型子集 | 需重跑 `build_font_subset.py` | 新增中文名／羈絆名 |
| Web pck | 目標增量 **< 150KB**（無新大圖時遠低於此） | 相對 R19／art 後預算 |

### 4.2 升級池與招募健康

| 風險 | 對策 |
|------|------|
| 第 11 武器進池後，質變／進化／數值卡再稀釋招募 | 維持 R11 **非隊長三選一保底**；招募落後曲線時權重上調（既有） |
| 隊長三武權重 1.35 過強 | 新武為跟隨者武器，權重走 `FOLLOWER_WEAPON_WEIGHT_MULTIPLIER 0.82` |
| 牧者過強導致必招 | 開局不進 trio；傷害份額封頂見 §2.3.3；羈絆 4 強但不破 hard cap |
| 雙 AoE 羈絆清圖過快 | 半徑 +8% 而非 +20%；以 BalanceMock 90s 前 min HP 與 clear speed 校 |

### 4.3 數值 Soft Cap（跨來源）

避免「牧者被動 −8% + 星盾和聲 −5% + 其他未來減傷」叠成無敵。

| 屬性 | 全來源合計建議上限 |
|------|--------------------|
| 傷害減免（最終 mul） | 受傷倍率 ≥ **0.85**（最多 −15%） |
| 對單武傷害加成（含羈絆／協同） | ≤ **+25%** |
| 裂傀同時存在 | ≤ **6** |
| 裂傀每 tick 全場命中目標總次數 | 建議 soft：`construct_count * 2`（已內建 per-construct max_targets） |
| 治療倍率 | ≤ **+25%** |

### 4.4 效能紅線（必須寫進實作驗收）

延續歷輪契約，本規格**新增**下列硬條件：

1. **禁止** `get_nodes_in_group("enemies")` 於裂傀 tick／投放路徑。
2. 裂傀查敵 **只** 用 `EnemySpatialIndex` 局部 query。
3. 裂傀實體必須進 **NodePool**；`exhausted / duplicate / foreign release` 測試須為 0。
4. 全域 `hard_cap = 6`；超出 FIFO 回收，不得 silent leak。
5. 裂傀 **不做** 獨立 steering、不做 avoidance、不加入 `heroes` group、不吃拾取、不被敵當第二優先目標（敵人仍只追小队成員，除非既有 aggro 邏輯已支援——**預設不擴 aggro**）。
6. 進化碎裂波優先复用 `ExplosionArea`／既有 cap；禁止每碎裂再 spawn 子裂傀。
7. 武器初始 CD 沿用 formation slot stagger，避免與滿編齊射同幀。
8. Mobile LOD：裂傀可用更簡 silhouette；**不得**用降低 tick 傷害的方式假裝優化（「視覺 budget 不改玩法」）。
9. Stress 情境更新：9 人滿編可含牧者（擠掉 1 名既有跟隨者）+ 裂傀 cap 打滿 + 全進化；`enemy_group_scans=0`。
10. 不引入 `time_scale` stack、不改 spawn token 契約、不改敵人 HP 來「配合」新英雄（若需調敵，另開平衡輪並明文）。

### 4.5 玩法／體驗紅線

| 紅線 | 說明 |
|------|------|
| 裂傀不是隊員 | 不佔 `max_members`、不進招募、不觸發羈絆人數 |
| 無友傷 | 裂傀／碎裂波不傷小队 |
| 主人死＝全回收 | 避免幽靈 DPS |
| 文案不超賣 | 質變／進化描述必須與實際 cap、倍率一致（R11 迴旋鏢文案教訓） |
| 不強制完美陣容 | 無任一羈絆時，牧者仍完整可用 |
| 決定性 | 投放位置／FIFO 回收須 deterministic（同 seed 可回歸） |

### 4.6 驗收指標（實作階段用）

| 測試 | 通過條件（建議） |
|------|------------------|
| `WeaponSmokeTest` | 招募牧者後 `rift_constructs` trigger > 0；follow 誤差不惡化 |
| `ArenaInstrumentationRun` | 16s 窗內裂傀武器有實傷；`enemy_group_scans=0`；pool 三零 |
| `BalanceMockRun` | 滿編（含或不含牧者各一檔）可通關曲線；`leader_dps_share` ∈ 0.38–0.48 |
| `GameplayCapTest` | 裂傀無法突破 hard cap 6 |
| 新回歸 `Hero10BondTest`（建議） | 4 組羈絆啟停正確；死亡失效；減傷 soft cap |
| `StressTest` | PASS 邏輯；允許既有 `STRESS_PERF_BELOW_60`，但 avg frame 不得較 R19 基線惡化 > **10%** |
| 字型 | Han coverage 含新字 |
| Web export | pck 可建；無缺資源 |

### 4.7 預估對局節奏影響

| 階段 | 預期 |
|------|------|
| 0–60s | 牧者未招或剛招：影響小 |
| 60–150s | 2–3 裂傀成形，中近距離「地盤」變清楚 |
| 進化後 | 碎裂波提升清雜能力，但仍弱於雙 AoE 羈絆的爆發清潮 |
| Boss | 站樁裂傀對移動 Boss 效率中等；依賴隊長／狙擊補 burstd——**有意保留**，避免召喚物單殺 Boss |

---

## 5. 備選方向（若召喚在技術評審被擋）

### 5.1 備選 B：時空系（濃縮版）

- 英雄：`chrono_stitcher`（時縫紡者）
- 武器：短距離「時縫標記」——標記敵人 2s 內受到的傷害的 **12%** 在標記結束時結算為一次裂傷（延遲回放），而非全局慢動作。
- 優點：獨特結算節奏。  
- 風險：與 `void_weaver` 控場語意近；傷害延遲會計與 UI 複雜；易與「易傷」同質化。  
- **僅在召喚物 pool 方案被否決時啟用。**

### 5.2 備選 C：吸血系（濃縮版）

- 英雄：`blood_rift_adept`（血縫使）
- 武器：近距裂鐮揮砍，命中回復 **造成傷害的 4%** 給最近受傷隊員（優先隊長）。
- 優點：實作便宜。  
- 風險：與 `echo_singer` 搶存活敘事；數值要嘛廢要嘛破壞張力。  
- **更建議做成某武器質變或羈絆，而不是第 10 整角。**

---

## 6. 實作分期建議（供後續 /execute 用，本文件不改碼）

| 階段 | 內容 | 依賴 |
|------|------|------|
| P0 | `HeroData`/`WeaponData` 資源、`behavior_id`、pool、基礎投放與 cap | 無 |
| P1 | 質變 `construct_anchor`、進化 `evo_mirror_flock`、進 catalog／升級池 | P0 |
| P2 | 隊長協同 A（距離加成）；被動減傷 | P0 |
| P3 | 4 組羈絆旗標 + 最小 HUD／卡面文案 | P0 |
| P4 | 測試矩陣、字型、Web export、Balance 調參 | P1–P3 |
| P5（可選） | 隊長協同 B（星環加速裂傀）、專屬 sprite | 美術／時間 |

---

## 7. 開放問題（需產品拍板時再決）

1. **HUD 羈絆**要不要做？最小可只作文案，零 UI。  
2. 隊長協同 B（星環觸發加速）是否進 P2 或延後——多一個武器耦合點。  
3. 若未來 `max_members` 升到 10，羈絆強度是否要整體下調 30%（建議：是）。  
4. 裂傀是否需要「被敵彈打掉」？  
   - **建議 v1：不可被擊殺，只到期／FIFO**（降複雜度與網路表現噪音）。  
   - v2 再加「建構體耐久」若要加深操作。

---

## 8. 總裁結論（TL;DR）

1. **第 10 英雄 = 裂隙牧者（`rift_shepherd`）**，召喚短命**固定站位**裂傀，填補現有 9 人完全沒有的「場域存在／消耗性單位」軸。  
2. **專武 `rift_constructs`** 成為第 11 武器行為；質變 `construct_anchor` → 進化 `evo_mirror_flock`；與隊長有靠近供能協同。  
3. **羈絆輕系統 4 組**：燼脈聯爆、縫獵協議、星盾和聲、牧長裂約；事件重算、不進升級池。  
4. **`max_members` 維持 9**，用 10 選 9 逼出編隊策略；裂傀 hard cap 6、減傷／增傷 soft cap、全面遵守 spatial／pool／文案不超賣紅線。  
5. 本文件為**可交付規格**；實作前以本檔為單一真相來源，數值以 BalanceMock 回寫修訂，不在未測量前拍脑袋加大倍率。

---

## 附錄 A｜現況武器 ↔ 行為一覽（實作對照）

| 武器 id | behavior_id | 質變 | 進化 |
|---------|-------------|------|------|
| `riftline_emitter` | `linear` | `riftline_fork` | `evo_rift_fan` |
| `orbit_blades` | `orbit` | `orbit_resonance` | `evo_shear_halo` |
| `pulse_bloom` | `explosion` | `pulse_embers` | `evo_ember_well` |
| `arc_chain` | `chain_lightning` | `chain_overload` / `magnetic_reclaim` | `evo_overload_nova` |
| `rift_shield_boomerang` | `boomerang` | `boomerang_rebound` | `evo_razor_bulwark` |
| `rift_seeker_missiles` | `homing_missile` | `missile_guidance` | `evo_hunter_swarm` |
| `grenade_lob` | `grenade_lob` | `grenade_cluster` | `evo_cinder_barrage` |
| `void_net` | `void_net` | `void_anchor` | `evo_event_horizon` |
| `rail_lance` | `rail_lance` | `rail_focus` | `evo_star_piercer` |
| `echo_hymn` | `echo_hymn` | `echo_crescendo` | `evo_resonant_chorus` |
| **`rift_constructs`（新）** | **`rift_construct`** | **`construct_anchor`** | **`evo_mirror_flock`** |

## 附錄 B｜名詞對照

| 中文 | 英文／id |
|------|----------|
| 裂隙牧者 | `rift_shepherd` |
| 裂傀編制 | `rift_constructs` |
| 裂錨定駐 | `construct_anchor` |
| 鏡裂群牧 | `evo_mirror_flock` |
| 羈絆 | bond |
| 質變 | qualitative modifier |
| 進化 | evolution |
| 硬上限 | hard cap |
| 軟上限 | soft cap |
