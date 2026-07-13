# Crackveil Vanguard — 全面健檢監工 R19

**審查者**：監工／對抗覆核（**只審不改**）  
**產品**：`Crackveil Vanguard`（Godot Web）  
**工作樹**：`HEAD = 5d082e4`（已含 R19 規模擴充祖先 `1c1d5d9`）＋**未提交**的 enemy_art CC0 交付層  
**基準文件**：`docs/CODEX_RESPONSE_enemy_art.md`、`docs/CODEX_RESPONSE_R19.md`、`docs/GROK_REVIEW_R17.md`、`docs/GROK_REVIEW_R18.md`  
**範圍**：(1) enemy_art CC0 素材輪殘留／半套；(2) 歷輪紅線快檢；(3) 內容／體驗缺口排序＋下一輪最划算 3 步  
**方法**：靜態讀碼＋磁碟盤點（PNG 尺寸／alpha／SHA-256／體積／git 狀態／spawner 對照／CREDITS）；**本輪未重跑 headless Godot**（CODEX 自述回歸／Stress／export 作次級證據）  
**日期**：2026-07-13  

---

## 執行摘要

| # | 議題 | 判定 | 嚴重度 |
|---|------|------|--------|
| (1) | enemy_art CC0：sprite ↔ CREDITS ↔ 管線是否完成 | **資產與對照表完整，非半套**；殘留主在 **未 commit**、風格雙軌、行為型共用剪影 | 交付 **成立**；衛生 **P2** |
| (2) | 歷輪紅線 | **未見破線**（150 cap／group 熱掃／池 cap／spawn_token／time_scale stack／pck 預算） | — |
| (3) | 內容／體驗缺口 | 規模（9 英雄／10 武器）已上；**可辨識度與氣氛**落後玩法量 | **P1×2 + P2 一串** |

**總判定**：**軟 Go／可當「敵人美術升級已落地的可玩原型」**。  
- enemy_art 輪在**工作樹**已收斂到可重建、可匯出、與 CREDITS 一致的狀態，**不是**「檔改一半逾時殘片」。  
- 不可當硬 Go／對外「內容完成」的點：**(A) 交付層尚未入 git**；**(B) 9 英雄仍 3 底圖 tint**；**(C) 滿編 p95 未達 60fps 守門**（R19 Stress 自述）。

狀態標籤：**成立**／**部分成立**／**未達**／**新風險**／**紅線違規**／**預存灰區**  
優先級：**P0** 軟鎖／破 cap／謊稱；**P1** 首載／明顯體感或宣傳落差；**P2** 衛生／調校／測試債。

---

## (0) 審查基準與工作樹狀態

| 項目 | 值 |
|------|-----|
| Git HEAD | `5d082e4` 封面圖／README |
| R19 規模擴充 | 祖先 `1c1d5d9` **已合入 main**（9 英雄、`max_members=9`、10 武器行為） |
| enemy_art | **工作樹修改＋大量 untracked**；CODEX 自述未 commit／push |
| `export/web/index.pck` | **4,934,168** bytes；SHA-256 `3F3682597C563C86AD9C47E794B56A6163DB6D59588D3B20706C21DC919D821F`（與 `CODEX_RESPONSE_enemy_art.md` **一致**） |
| 相對 R18 預算 | R18 曾 4.34MB；現 ~4.93MB 仍 **&lt; 5MB 級** 且相對 art 前基線 **淨減**（CODEX：−165,768 B） |

**方法論註記**：本報告以「工作樹＝玩家實際匯出所依」為主；若只看 `git show HEAD`，**尚未**含 elite／boss 專圖與完整 generated 幀集合。

---

## (1) enemy_art CC0：盤點、CREDITS、半套判定

### 1.1 宣稱 vs 磁碟（對照 `CODEX_RESPONSE_enemy_art.md`）

| 宣稱 | 覆核 | 證據 |
|------|------|------|
| 7 個 base + 48 idle/walk = 55 PNG | **成立** | `assets/sprites/enemy_*.png`×7 + `generated/enemy_*`×48 |
| 合計 158,128 bytes | **成立** | 逐檔 `Length` 加總 **158,128** |
| 全數 96×96 | **成立** | Pillow：全部 `size=(96,96)` `mode=RGBA` |
| 來源 CC0 + CREDITS 逐檔 SHA | **成立** | 見 §1.2 |
| 未改 gameplay stats | **成立（靜態）** | `enemy_spawner.gd` normal/fast/tank HP/speed 與回歸鎖一致 |
| runtime LOD：crowd 2 walk／elite 4／boss 6；mobile→2 | **成立** | `enemy.gd:981-983,1003-1031`；`enemy_art_regression_test.gd` |
| `generate_walk_frames.py` 不再覆寫敵幀 | **成立** | `ENEMIES: list[str] = []` ＋註解；敵改走 `process_enemy_cc0_assets.py` |
| 回歸測試入場 | **成立（檔在樹上）** | `EnemyArtRegressionTest.tscn` + `enemy_art_regression_test.gd`（untracked） |
| Web pck SHA／體積 | **成立** | 見 §0 |

### 1.2 CREDITS ↔ 來源 ↔ 衍生一致性

`assets/CREDITS.md`「OpenGameArt CC0 animated enemies」與管線對照：

| CREDITS 上游檔名（SHA） | 本機 `tools/asset_sources/`（gitignored） | 遊戲衍生 |
|-------------------------|------------------------------------------|----------|
| `roaming_cultist.png` | `cultist.png` **SHA MATCH** | `enemy_grunt.png` + idle/walk |
| `monster_flesh_eye_sheet.png` | `tentacle_eye.png` **MATCH** | `enemy_tank.png` + frames |
| `monster_flesh_teeth_sheet.png` | `tentacle_teeth.png` **MATCH** | `enemy_boss.png` + frames |
| `beetle2.png` | `eman_beetle2.png` **MATCH** | `enemy_fast.png` + frames |
| `crystal_2.png` | `eman_crystal.png` **MATCH** | `enemy_elite_split.png` + frames |
| `mushroom_9.png` | `eman_mushroom.png` **MATCH** | `enemy_elite_field.png` + frames |
| `crab2.png` | `eman_crab.png` **MATCH** | `enemy_elite_swift.png` + frames |

| 命題 | 判定 |
|------|------|
| CREDITS 缺檔／錯 hash | **否**（7 源全 MATCH） |
| 衍生路徑未寫入 CREDITS | **否** |
| 未採用包進 `assets/` | **否**（candidate 留在 `asset_sources`，符合「不進 pck」） |
| 本地檔名 ≠ OGA 原始檔名 | **有意重命名**；JOBS 字典固定，**非半套** |

### 1.3 幀集合完整性（對 `process_enemy_cc0_assets.py` JOBS）

| base | idle 檔 | walk 檔 | runtime 桌機使用 | 判定 |
|------|---------|---------|------------------|------|
| `enemy_grunt` | 2 | 6 | idle1／walk2（crowd） | 檔齊；多幀為來源完整 bake |
| `enemy_fast` | 2 | 4 | idle1／walk2 | 同上 |
| `enemy_tank` | 2 | 6 | idle1／walk2 | 同上 |
| `enemy_elite_*` | 2 | 4 | idle2／walk4（非 mobile） | 檔齊且與 LOD 對齊 |
| `enemy_boss` | 2 | 6 | idle2／walk6 | 檔齊 |

- **missing frames：NONE**  
- **orphan enemy generated：NONE**  
- 精英 base 僅 554–711 B：alpha 實心像素比 0.37–0.59、非空圖；小檔因 **48 色＋稀疏像素剪影**，不是 0-byte 殘片。

### 1.4 程式接線（是否「圖在、遊戲還用舊 tank tint」）

| 接線 | 狀態 | 位置 |
|------|------|------|
| 普通三型 base path | **新圖** | `enemy_spawner.gd:12,25,38` |
| 精英三 affix **專圖** | **成立** | `ELITE_SPRITE_PATHS` → split/field/swift `:111-115,279+` |
| Boss **專圖** | **成立** | `BOSS_SPRITE_PATH` → `enemy_boss.png` `:116,220` |
| 高細節單位才吃多幀 | **成立** | `is_elite or is_boss` → idle2/walk≤6 `:973-983` |
| crowd prewarm 只熱 2 walk | **成立** | `sprite_loader.gd:64-73` |
| 英雄 rebuild 不踩敵幀 | **成立** | `generate_walk_frames.py:21-25` |

### 1.5 「半套／殘留」清單（誠實版）

| ID | 類型 | 說明 | 嚴重度 |
|----|------|------|--------|
| R19A-1 | **衛生殘留** | 整包 enemy_art **未 commit**（base 修改、elite/boss untracked、工具／回歸／CREDITS 改動）→ 他機／CI 只 checkout HEAD 會 **掉圖** | **P1 工程**（非玩法正確性，但交付不完整） |
| R19A-2 | **非半套、屬設計取捨** | 行為型 `ranged`/`spawner`/`dasher` 仍共用 grunt/tank/fast 剪影（只靠 tint／行為讀） | **P2** 內容 |
| R19A-3 | **體積殘渣** | crowd 執行期不用的 `idle_1` + `walk_2+` ≈ **42 KB** 仍進包（完整 bake 可重現） | **P2** 可選瘦身 |
| R19A-4 | **風格雙軌** | 英雄 base ~70–135 KB、數萬 unique RGB；敵 96px 且 unique RGB 約 4–42 → 同框「繪製英雄 vs 像素怪物」 | **P1 體感／宣傳** |
| R19A-5 | **死碼輕量** | `generate_walk_frames.make_enemy_frame` 仍在，但 `ENEMIES=[]` 不執行 | **P2** 衛生 |
| R19A-6 | **R18 放大糊** | Boss/tank 仍 96px + 大 `sprite_scale`；CC0 專剪影改善可讀性，**不自動取消** R18-1c tpp 問題 | **P2→宣傳 P1** |

**條目總結 (1)**：  
> **素材輪本身：完成，非半套。**  
> **工程交付輪：半套（磁碟有、git 無）。**  
> **內容語意輪：行為三型未獨立剪影；英雄未跟敵美術同級升級。**

---

## (2) 歷輪紅線快檢

對照 R15–R18 既有紅線與 R19／enemy_art 宣稱；本輪為**靜態快檢**。

| 紅線 | 判定 | 證據 |
|------|------|------|
| 敵硬 cap **150** | **未破** | `enemy_spawner.gd:118`；`death_spawn_cap` 綁 max |
| 武器熱路徑 **不** `get_nodes_in_group("enemies")` 掃全場 | **未見呼叫端** | 全 `scripts/` 僅 `entity_factory.record_enemy_group_scan` 定義；新武器走 pool／spatial（CODEX R19） |
| 池 live cap／野 new | **結構維持** | `entity_factory.gd`：explosion 48、hazard 16、corpse 24、lightning 48、DN 48、敵彈 72 等 |
| `spawn_token` | **維持** | factory issue + enemy art 回歸鎖 token 不變 |
| time_scale owner stack | **維持** | `acquire`／`release`／`clear`；死亡／Boss／升級硬清路徑仍在 |
| hit-stop 在 modal pause 不新開 | **維持（前輪）** | 未見 enemy_art 觸碰 |
| 橫式 modal／form-factor 三檔 | **維持** | `mobile_tuning` LayoutTier；`0774bfa` 仍在歷史 |
| Web pck 預算（≤~5MB 級、enemy_art 增量 &lt; 1.5 MiB） | **達標** | 4.93MB；且相對 art 前基線 **下降** |
| 敵 art 不改 HP／速度／傷害 | **靜態成立** | config 數值未動；僅 `sprite_path`／動畫 LOD |
| 決定性 seed 主幹 | **未見 art 引入新戰鬥 RNG** | bake 資產；LOD cache 為裝置級 |
| 新 P0 軟鎖 | **未發現** | 滿 cap 仍靜默丟 VFX；缺幀 fallback 靜圖 |

### 預存灰區（非本輪新引入）

- 掉落 scatter／部分 VFX 非嚴格決定性  
- 音效池搶播（R15）  
- 直式大搖桿熱區貼技能鈕（R17-1d）  
- 無雙指（搖桿+技能）自動化（R17-1e）  
- pause 凍結 hit-stop timer 暫留 slow-mo（R17-3c）  
- R19 Stress：`STRESS_PERF_BELOW_60=true`（avg 可過、**p95 未達**）  
- 英雄 9／精靈 3 + tint（R18-risk3 **被 R19 放大**）

### R19 規模護欄（附帶）

| 項 | 狀態 |
|----|------|
| `max_members = 9` + level gate 4→9 | **成立** `squad_data`／`RECRUIT_LEVEL_GATES` |
| 10 武器 behavior + 4 新 evo | **成立** `weapon_data.gd` enum／EVOLUTION |
| orbit 尾改短弧 | **碼上成立** `orbit_projectile.gd` 弧點＋圓角＋加算 |
| prewarm 上調（proj 320 等） | **成立** `PREWARM_COUNTS` |

**條目總結 (2)**：**紅線未破。** 效能屬「滿編尖峰未達 60fps 宣傳」的 **P1 體驗／壓力**，不是正確性紅線違規。

---

## (3) 內容／體驗缺口排序

排序標準：**玩家 3 分鐘／商店圖／一局中段**最容易感到「還沒完成」或「被唬爛」的落差（正確性紅線另列 §2）。

| 順位 | 缺口 | 為何痛 | 嚴重度 |
|------|------|--------|--------|
| **#1** | **9 英雄、3 張 `hero_*` + tint** | R19 擴編直接放大「紙片分色」；招募卡／滿編同框最露餡 | **P1** |
| **#2** | **英雄繪製風 vs 敵 CC0 像素風雙軌** | 敵剛升級後，**對比更刺眼**；宣傳「美術升級」只兌現半邊 | **P1** |
| **#3** | **滿編 9 + 全武器 + 150 敵 p95 未穩 60** | R19 自承 `STRESS_PERF_BELOW_60`；Web 低階機是差評源 | **P1** 壓力 |
| #4 | 行為敵（ranged／spawner／dasher）無專剪影 | 與「精英有專圖」不對稱；中期可讀性靠行為不靠形 | P2 |
| #5 | **無 BGM**（僅 SFX 池） | 長局氣氛空；survivors 品類期望低成本也能有 loop | P2→上架 P1 |
| #6 | 主題 3 套場景但**同一套敵表／Boss 單體** | run 變異靠契約／seed／背景，敵花樣有限 | P2 |
| #7 | Meta 三軌＋少量 unlock | 有骨架；長線「再打一局」鉤子偏薄 | P2 |
| #8 | 新手導引／第一局教學薄 | 契約／進化／招募 gate 資訊密度高 | P2 |
| #9 | enemy_art **未入庫** | 協作／回滾／CI 風險；玩家匯出若對齊 HEAD 會退步 | **P1 工程** |
| #10 | 搖桿大檔貼技能／雙指無測 | 行動差評邊角 | P2 |

### 已補相對「空殼」的部分（本輪不扣分）

- 武器量（10）與進化線、招募曲線、陣型 9 人、空間查詢武器、池 cap 擴充  
- 敵剪影從「tank tint 全家桶」→ **7 可辨家族**（三普＋三精＋Boss）  
- 三 run theme 地面／飾片已有  

---

## (4) 下一輪最划算 3 步

以 **投入工時／體積／風險 vs 玩家感知** 排序（只建議，不實作）。

### 步驟 1 — **把 enemy_art 工程閉環（commit + 回歸進矩陣）**（0.5 日級）

| 面向 | 內容 |
|------|------|
| 做什麼 | 提交 CREDITS、7 base、48 generated、spawner／enemy／sprite_loader／process 腳本、`EnemyArtRegressionTest`；CI／本地 suite 掛上 |
| 為何最划算 | 否則「完成」只存在本機；一 `git clean`／他機 clone = **整輪蒸發** |
| 驗收 | 乾淨 checkout → EnemyArt + 既有 R* 綠；`index.pck` 含 `enemy_elite_*`／`enemy_boss` |
| 不做的代價 | R19A-1 永久 P1 工程債 |

### 步驟 2 — **英雄可辨識度急救（不重畫 9 套）**（1–2 日級）

| 面向 | 內容 |
|------|------|
| 做什麼（擇一或組合） | (a) 每英雄固定 **剪影配件**（帽／肩甲／武器 silhouette 疊層，仍可 CC0／自繪小圖）；(b) 至少再 **+2～3 張** 底圖拆開「遠程／坦克／輔助」；(c) 統一 **描邊／色帶 shader** 讓 tint 英雄與 96px 敵同框不違和 |
| 為何划算 | 直接打 #1+#2；比再擴第 11 把武器更影響商店圖與滿編辨識 |
| 驗收 | 暫停／招募列 **不靠讀字** 能分 6 種以上；pck 增量目標 **&lt; 300KB** |
| 避開 | 再吹「九名獨立角色立繪」除非真有圖 |

### 步驟 3 — **滿編尖峰 p95 再砍一刀（Web 向）**（1–2 日級）

| 面向 | 內容 |
|------|------|
| 做什麼 | 依 R19 自述優先：hazard tick 降頻、damage number merge／cap 再壓、死亡 VFX LOD、滿編時非焦點 follower 武器特效降級；必要時 crowd 敵 bob／glow 再削 |
| 為何划算 | 規模賣點已上；**穩 40–60fps 體感**決定「爽」還是「卡」；不動數值曲線也能做 |
| 驗收 | Stress 滿編固定 seed：`STRESS_PERF_BELOW_60=false` **或** 明文降標＋實機錄影；`enemy_group_scans=0`、pool exhausted=0 維持 |
| 避開 | 為幀率砍 150 cap 或關掉 spatial（會動紅線） |

### 刻意未選進「最划算 3 步」但下一輪可排

| 候選 | 理由 |
|------|------|
| BGM 單 loop（CC0） | 氣氛 CP 高；排第 4 因不阻塞正確性，且與美術雙軌相比較「可後補」 |
| ranged／dasher 專剪影 | 有 enemy 管線後成本低；優先級低於英雄辨識 |
| 刪 crowd 未用幀 ~42KB | 收益小；步驟 1 閉環後再做即可 |
| Boss 獨立更高解析 | 宣傳截圖用；步驟 2 風格統一後再決定 |

---

## 總表

### 發現清單

| ID | 等級 | 標題 |
|----|------|------|
| R19A-complete | — | 55 敵 PNG／158,128 B／96px／CREDITS SHA／spawner 專圖 **完成** |
| R19A-1 | **P1 工程** | enemy_art **未 commit**；HEAD 無 elite/boss 專圖 |
| R19-hero3 | **P1** | 9 英雄／3 sprite + tint（R19 放大） |
| R19-style | **P1** | 英雄高彩繪製 vs 敵 48 色像素雙軌 |
| R19-perf | **P1** | 滿編 Stress p95 未達 60（自述） |
| R19A-2 | P2 | ranged/spawner/dasher 共用三普剪影 |
| R19A-3 | P2 | crowd 未用幀 ~42KB |
| R19A-4/5 | P2 | 風格／死碼衛生 |
| R18-1c | P2（宣傳可抬） | Boss/tank 96px 強放大仍在 |
| 紅線集 | — | **未見違規** |

### 非問題

- CREDITS 與來源 hash **不一致** → 否  
- 精英／Boss 空圖或缺 generated 幀 → 否  
- `generate_walk_frames` 會蓋掉 CC0 敵幀 → 否（`ENEMIES=[]`）  
- 敵 art 偷改 cap／group scan／token → 靜態未見  
- pck 被 art 輪炸穿 5MB 級 → 否（4.93MB 且 SHA 對得上）

### 總判定

> **軟 Go。**  
> (1) **enemy_art 素材與對照表：收斂完成，不是逾時半套**；殘留是 **git 未閉環** + **英雄／行為剪影未跟進**。  
> (2) **歷輪正確性紅線：快檢通過。**  
> (3) 下一輪 CP 最高：**入庫閉環 → 英雄可辨識 → 滿編 p95**。  

---

*本報告僅覆核，不修改程式碼（本檔為審查產物）。*  
*磁碟與行號對應工作樹狀態；git 物件以 `5d082e4` + uncommitted enemy_art 為準。*
