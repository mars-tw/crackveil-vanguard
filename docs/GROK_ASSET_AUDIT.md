# Crackveil Vanguard — 2D 素材品質監工報告

**角色**：素材品質監工（只審不改）  
**產品**：Crackveil Vanguard（`rift-survivors`）  
**日期**：2026-07-14  
**對照聖經**：`docs/ART_DIRECTION_R10.md`、`docs/ART_DIRECTION_M1_mobile.md`  
**方法**：逐張檢視 `assets/sprites/*`、`assets/sprites/generated/*`、`assets/art/decor/*`；量測解析度／唯一色數／邊緣型態／主題再上色結構相似度；對照 runtime 縮放（`SpriteLoader.fit_sprite`、`enemy.gd` radius×3、武器 `projectile_radius`）。**未修改任何資產或程式。**

---

## 0. 執行摘要

| 面向 | 判定 |
|------|------|
| 英雄底圖（`hero_*.png`） | **中上**：俯視卡通完成度高，黑描邊清楚 |
| 英雄 runtime 動畫幀 | **短板**：generated 幀色數崩壞（約 7 萬色 → 70 色） |
| 敵人 live sprite | **短板**：CC0 管線 48 色／中性 ramp 後變「泥粉剪影」；與英雄不在同一美術宇宙 |
| 武器／彈體 | **部分成立**：`proj_bullet` 對齊裂隙青；`proj_blade`／`proj_lightning` 語意偏通用 icon |
| Decor 三主題 | **結構成立、外觀半成品**：farm 源圖品質最好；void／ember 多為 **同輪廓 recolor** |
| 封面 vs 局內 | **嚴重斷層**：封面寫實暗黑裂隙部隊 vs 局內 chibi 騎士／菇／蟹 |
| **總判定** | **不可當「可宣傳的統一 2D 包」出貨**；玩法可讀靠 glow／marker／tint 撐，**像素本體**需 P0–P1 重繪 |

**一句話**：英雄像商店資產包、敵人像壓色 CC0 怪物、彈體像 emoji 拼貼、decor 像農莊 recolor——四套語言同框，裂隙先鋒的「虛空＋青紫能量」只落在背景與 VFX，沒落在角色本體。

---

## 1. 盤點範圍

### 1.1 局內會被看到的主要 2D

| 類別 | 路徑 | 數量／備註 |
|------|------|------------|
| 敵人 base | `assets/sprites/enemy_*.png` | 7（grunt／fast／tank／3 elite／boss） |
| 敵人動畫 | `assets/sprites/generated/enemy_*_{idle,walk}_*.png` | 48 幀（皆 96×96） |
| 英雄 base | `assets/sprites/hero_{captain,guardian,scout}.png` | 3 張底圖 → **9 英雄共用**（+ tint） |
| 英雄動畫 | `assets/sprites/generated/hero_*_{idle,walk}_*.png` | 18 幀 |
| 彈體 | `proj_bullet`／`proj_blade`／`proj_lightning` | 3 張服務 ~10 武器 |
| 掉落 | `coin.png`／`gem_xp.png` | 2 |
| Decor | `assets/art/decor/*` | 41 PNG（farm／void／ember + ground） |
| 行銷／合成 | `cover.png`、`_atlas_all.png` | 封面與舊合成圖；**atlas 敵人與 live 敵人已分家** |

### 1.2 刻意不納入本輪重繪清單（但註記）

- Kenney VFX 粒子（`assets/vfx/kenney_particle/`）：功能向、授權清楚；品質屬「可接受共用庫」。
- UI icons／panel／vignette／radial_glow：程序化或共用 FX，非角色／場景 prop 本體。
- 音訊。

---

## 2. 對照 ART 聖經的違規總表

| 規則（`ART_DIRECTION_R10`） | 現況 | 嚴重度 |
|---------------------------|------|--------|
| 英雄：clean compact silhouette、pale cyan aura | 隊長=藍金騎士、護衛=綠機甲、斥候=紫忍者；**無統一裂隙部隊語彙** | P1 |
| 敵人：heavier warmer silhouette；desaturated crimson／magenta | 素材本體已中性灰紫，靠 `body_color` modulate；**細節與色階過低** | P0–P1 |
| Elite／Boss：shape **and** hue 可分 | Runtime 有幾何標／光環；**本體剪影** field／split／swift 在 40px 下易糊成 blob | P0 |
| 玩家彈=青、敵彈=ember | `proj_lightning` 為**純黃**；`proj_blade` 為無色金屬 | P0 |
| 背景不搶 foreground | farm 主題 intact 紅穀倉＋乾草極搶眼；void ground 幾乎實心色塊 | P1 |
| 對比優先序：小隊 > 威脅 > 彈 > pickup > BG | 英雄硬描邊＋高飽和 vs 敵人 4–9 色泥粉 → **敵潮可讀但「醜且不像同一遊戲」** | P1 |

### 2.1 關鍵量化（本體 PNG）

| 資產 | 尺寸 | 唯一不透明色約 | 邊緣 | 備註 |
|------|------|----------------|------|------|
| `enemy_grunt` | 96×96 | **9** | soft alpha | 剪影尚可 |
| `enemy_fast` | 96×96 | **6** | soft | 過亮中性 |
| `enemy_tank` | 96×96 | 47 | soft | 最佳敵人細節 |
| `enemy_boss` | 96×96 | 47 | soft | 與 tank 同系觸手改口 |
| `enemy_elite_swift` | 96×96 | **4** | soft | 色階崩潰 |
| `enemy_elite_split` | 96×96 | **6** | soft | 菱形 blob |
| `enemy_elite_field` | 96×96 | **7** | soft | 蕈菇簡筆 |
| `hero_captain` base | 320×328 | **~39k** | hard outline | 品質天花板 |
| `hero_captain` idle_0 gen | 109×112 | **76** | 半 soft | 動畫管線降級 |
| `proj_bullet` | 163×192 | ~12k | hard | 色對 |
| `proj_blade` | 207×212 | ~9k | hard | 語意錯 |
| `proj_lightning` | 129×213 | ~7k | hard | **黃 emoji** |
| `void_crystal_01` | 59×79 | **6** | soft | 草圖級 |
| `ember_lava_crack` | 87×37 | **3** | soft | 草圖級 |
| `ground_void_stone` | 32×32 | 5 | n/a | 近實心，std≈1 |
| `farm_ruined_barn` | 236×223 | ~5k | mixed | 高品質但**不破** |

**Runtime 顯示粗估**（非 UI 像素完美）：普通敵顯示直徑 ≈ `radius×3×sprite_scale` → ~38–52px；tank ~82px；彈體來源 160–210px 再縮到 radius 量級（~9–24px）。**敵人在螢幕上幾乎只有剪影在工作**——卻把剪影畫成低對比軟邊 blob。

---

## 3. 分類短板

### 3.1 敵人 sprite

**來源現況**（`CODEX_RESPONSE_enemy_art`）：OpenGameArt CC0 → `process_enemy_cc0_assets.py`（alpha 清理、union crop、96×96、中性 brightness ramp、2px 描邊、≤48 色）。  
**優點**：類型可分、有 walk、體積可控、授權乾淨。  
**短板**：

1. **風格宇宙錯誤**：cultist／甲蟲／觸手／菇／晶／蟹 vs 英雄 chibi 武裝部隊 vs 封面紅色裂隙魔物——三套生物設計。
2. **色階過殺**：swift 僅 4 色、多数 elite ≤7 色；中性 ramp 讓 modulate 後仍像「染色剪紙」。
3. **Boss ≠ 獨立設計**：與 tank 同觸手骨架，口部差異在小縮放下不足撐 180s 高潮威脅。
4. **行為型共用本體**：`ranged` 用 grunt、`spawner` 用 tank、`dasher` 用 fast——玩法差異無視覺錨點（屬內容缺口，列入 P1）。
5. **`_atlas_all.png` 過期**：atlas 仍是殭屍／紅蜥／釘甲坦克，**不是** live CC0 套；行銷／除錯易誤導。

| 敵人 | 剪影可讀（近） | 剪影可讀（遠／手機 zoom） | 裂隙語彙 | 建議處置 |
|------|----------------|---------------------------|----------|----------|
| grunt | 中 | 中 | 弱 | P1 重繪保留多肢 |
| fast | 中高 | 中 | 弱 | P1 改裂隙掠食蟲 |
| tank | 高 | 中高 | 中 | P1 強化甲殼裂縫 |
| elite_split | 低 | **極低** | 中 | **P0** |
| elite_field | 低中 | 低 | 弱 | **P0** |
| elite_swift | 中 | 低 | 弱 | **P0** |
| boss | 中高 | 中 | 中 | **P0** |

### 3.2 英雄圖

**優點**：三張 base 完成度、黑描邊、俯視可讀性都明顯高於敵人。  
**短板**：

1. **9 英雄 3 皮**：  
   - `hero_captain` ← captain + sniper  
   - `hero_guardian` ← orbit_guard + pulse_artificer + ember_grenadier  
   - `hero_scout` ← arc_scout + line_mender + void_weaver + echo_singer  
   招募「新隊員」時常像 **換色分身**。
2. **陣營語言分裂**：隊長奇幻板甲 vs 護衛科幻機甲 vs 斥候未來刺客——不是同一支「裂隙先鋒」。
3. **動畫幀品質斷崖**：generated 幀 palettize／縮放後色帶與糊邊；對比 base 像另一套資產。
4. **與封面／ART 不符**：ART 要 pale cyan 部隊光暈；封面是寫實青藍裂隙戰士；局內是商店風 chibi。

### 3.3 武器彈體

| 檔 | 現貌 | 服務武器（節錄） | 問題 |
|----|------|------------------|------|
| `proj_bullet` | 青銀科幻彈頭 | seeker、riftline、grenade 等 | 語意尚可；榴彈／裂線共用偏偷懶 |
| `proj_blade` | 銀手裏劍 | orbit_blades、boomerang | **無裂隙能量**；像忍者道具 |
| `proj_lightning` | **黃**閃電 emoji | arc_chain、rail_lance、echo_hymn | **破玩家青／敵 ember 色法** |

額外：高解析硬描邊 icon 縮到 10–20px 後只剩色塊；不如專為小尺寸設計的「亮核＋暗描邊」形狀（M1 敵彈規則有寫，玩家彈未對齊）。

### 3.4 Decor

三主題（`run_theme.gd`）：`rift_void`／`wasteland_farm`／`ember_rift`。

| 觀察 | 證據 |
|------|------|
| void／ember **結構抄 farm** | barn／rock／bush／wood_stack 與 farm 對應檔 **alpha mask 完全相同**（recolor 差 ~11–50 channel） |
| farm 品質最高但主題最違和 | `farm_ruined_barn` 實際是**完好**紅穀倉；`farm_hay_bale` 高飽和金黃 |
| void 專用件草圖級 | crystal 6 色、crack_marker 3 色 |
| ground tile 無材質 | 32×32 近實心；裂隙石板 std≈1，無法承載「破碎虛空地面」 |
| 命名謊稱 | `*ruined*`／`dead_oak` 等與畫面 intact 程度不符 |

**主題風險**：`wasteland_farm` 一開局就宣告「我是農場幸存者」而非「裂隙先鋒」——與封面、主選單、武器語彙衝突最大。

---

## 4. 優先級定義（本報告）

| 級 | 意義 | 重繪觸發 |
|----|------|----------|
| **P0** | 可讀性紅線、威脅誤判、色法／語意直接打臉 ART、Boss／精英高潮塌陷 | 必須進下一美術 sprint |
| **P1** | 風格統一、英雄辨識、武器分化、主題 decor 不再像 recolor | 發佈／宣傳前應完成主幹 |
| **P2** | 精緻度、次要道具、atlas／死資產、封面對齊 | 排程可滑；不擋玩法 |

---

## 5. P0 重繪清單 ＋ 規格

### P0-01 · Boss 本體（`enemy_boss` 全動畫組）

| 項 | 規格 |
|----|------|
| 檔案 | `enemy_boss.png` + `generated/enemy_boss_{idle,walk}_*`（建議 idle 2／walk 6，維持現管線） |
| 畫布 | **128×128** 透明（runtime 仍 fit；細節預算高於 96） |
| 風格 | 與英雄同：**俯視 3/4、硬描邊 2–3px 深梅／近黑、有限色盤 24–32 色（非 4 色）** |
| 剪影 | 明顯大於 tank；**非觸手複製品**。建議：中央裂口核心 ＋ 環狀碎甲 ＋ 2–4 條能量觸鬚 |
| 色 | 本體 desat 紫紅；核心可有 **violet `#9D6CFF` 內光**；Phase 2 由 runtime 紅熱 modulate，**本體需預留可染色亮區** |
| 可讀 | 在 ~90–120px 顯示下仍能與 tank 一秒區分；雙層 glow 為輔助非唯一差異 |
| 禁止 | 再從 tank 差值改口；過軟 alpha 邊；寫實肌肉貼圖 |

### P0-02 · 三精英本體（split／field／swift）

| 精英 | 剪影必須 | 色錨（本體可含，runtime 再乘 affix 色） | 畫布 |
|------|-----------|------------------------------------------|------|
| **split** | **三角／晶簇** 可讀，非圓菱 blob；裂縫或雙核暗示分裂 | 綠晶光 `#6dff9a` 系高光 | 96×96 或 112×112 |
| **field** | **方環／孢盾** 外輪廓；本體有「力場膜」厚度 | 青 `#4FEAFF` 半透明膜（畫在 sprite 內，低 alpha 區） | 同上 |
| **swift** | **雙箭頭／流線多足**；水平速度感 | 橘 ember `#FF7A3D` 肢端 | 同上 |

共通規格：

- 色數 **≥16 有效色**（opaque unique 目標 24–40，避免再 4–7 色）。
- 硬描邊；與 grunt 同一「裂隙生物」族：碎甲、能量紋、非農莊動物。
- walk ≥4 幀（現有）；mobile LOD 可砍幀，但**第 0 幀靜態必須是完整可讀招牌剪影**。
- 檔名／路徑維持，方便不改 spawner。

### P0-03 · `proj_lightning`（玩家電系語意）

| 項 | 規格 |
|----|------|
| 色 | **主體 rift cyan `#4FEAFF`–`#7DF7FF`**；芯近白；**禁止主色純黃** |
| 形 | 短折線／裂隙電弧，非 emoji 閃電；建議長寬比 ~1:2，中心質量高 |
| 尺寸 | 設計 **64×96**（或 48×72）小尺寸友好；亮核 ＋ 2px 深藍描邊（對齊 M1 敵彈可讀哲學） |
| 用途 | arc_chain／rail_lance／echo 共用可暫留一張；若只做一張，優先 **「裂隙電弧」** 非「天氣閃電」 |

### P0-04 · `proj_blade`（軌道／迴旋語意）

| 項 | 規格 |
|----|------|
| 形 | 環形裂刃／迴旋盾刃；**保留旋轉對稱**以利 orbit |
| 色 | 刃身冷灰青 ＋ **cyan 能量刃緣**；中心可有小裂核 |
| 禁止 | 無能量的純金屬手裏劍、忍者標 |
| 尺寸 | 設計 64×64 或 80×80 正方形 |

### P0-05 · 敵彈專用 sprite（若仍共用 `proj_bullet`）

| 項 | 規格 |
|----|------|
| 現況 | Boss／敵投射可走 `proj_bullet` 或 kenney flare（見 `enemy.gd` 配置） |
| 要求 | **獨立 `proj_enemy_bolt.png`（建議）**：ember 核 `#FF7A3D` ＋ 深褐描邊；形短梭或碎裂彈 |
| 理由 | ART 明令敵彈不得與玩家青彈混淆；M1 亦要求橘亮核加深色外緣 |
| 尺寸 | 32×32 或 48×48 即可 |

> P0-05 若工程暫不改路徑，至少 **禁止** 敵彈繼續用高飽和青銀 `proj_bullet` 無 tint；但本報告只審素材——標為 **素材缺口 P0**。

---

## 6. P1 重繪清單 ＋ 規格

### P1-01 · 普通三型敵人族（grunt／fast／tank）

統一 **「裂隙侵蝕生物」** 族譜，告別 CC0 雜湊動物園。

| 型 | 角色 | 剪影關鍵 | 建議顯示直徑對應細節 |
|----|------|----------|----------------------|
| grunt | 雜兵潮 | 多肢／破布甲，群聚仍可數 | 48–56px 可辨肢體數 |
| fast | 側翼壓迫 | 尖、前傾、細長 | 36–44px 仍像「尖」非「圓」 |
| tank | 前線肉牆 | 寬、重、甲塊 | 70–90px 有甲分塊高光 |

規格共通：

- 畫布 96×96；有效色 20–32；硬描邊；暖敵色本體（允許 runtime 再乘 `body_color`）。
- walk：grunt／tank 維持可 6 幀來源、runtime 熱路徑 2 幀策略可續；**兩關鍵幀肢位差要大**。
- 與英雄 **同一描邊粗度語言**（勿再 soft-blob 敵人 vs hard-hero）。

### P1-02 · 行為亞種視覺（ranged／spawner／dasher）

| 亞種 | 現用皮 | 最低成本規格 |
|------|--------|--------------|
| ranged | grunt | 同族 ＋ **背上晶管／單眼瞄具** 變體幀或獨立 PNG |
| spawner | tank | 同族 ＋ **腹部裂口／寄生囊** |
| dasher | fast | 同族 ＋ **前掠焰紋／後噴氣裂縫** |

可先做「base ＋ 變體 decal」減少整組動畫成本。

### P1-03 · 英雄族統一 ＋ 最低辨識擴張

**階段 A（統一語彙，3 皮重繪）**

| 皮 | 對應定位 | 必須具備 |
|----|----------|----------|
| Captain 系 | 旗艦／點殺 | 披風或肩裂紋 ＋ **青能武器**；板甲可留但加裂隙電路 |
| Guardian 系 | 近戰／爆發 | 厚甲或盾環 ＋ **青／綠能刃**；去掉「無關連的純綠玩具機甲感」或改寫成裂隙動力甲 |
| Scout 系 | 側翼／輔助 | 輕裝兜帽可留；武器改 **青紫裂匕**，與 void／echo 可 tint |

共通：

- 俯視一致；硬描邊；本體可帶低飽和，**能量件固定 cyan／violet**。
- 產出 **同一管線** 的 idle2＋walk4，且 generated 不得再砍到 <64 有效色（建議導出前 32–48 色有序調色盤，而非毀滅性 posterize）。

**階段 B（辨識擴張，P1 後半）**

優先獨立剪影（招募可讀）：

1. `echo_singer` — 儀器／音波環  
2. `void_weaver` — 網／織梭  
3. `ember_grenadier` — 榴彈筒／餘燼罐  
4. `rift_sniper` — 長槍／瞄鏡肩架  

其餘可暫 tint。第 10 英雄 `rift_shepherd`（設計中）預留「肩上裂傀」剪影位。

### P1-04 · 武器彈體分化（在 P0 三張之上）

| 新建建議檔 | 形與色 | 對應 |
|------------|--------|------|
| `proj_rift_slug.png` | 青長彈／裂線段 | riftline、rail 段 |
| `proj_missile.png` | 短導彈 ＋ 青尾焰 | seeker |
| `proj_grenade.png` | 圓罐 ＋ ember 縫 | grenade_lob |
| `proj_shield_boomer.png` | 回旋盾輪廓 | boomerang（可與 blade 分家） |

尺寸一律為 **小螢幕優先**（32–64px 設計，而非 200px 再縮）。

### P1-05 · Decor：void 主題「真虛空化」（非 farm recolor）

| 資產組 | 規格 |
|--------|------|
| `void_rock_0x` | 浮空碎石 ＋ 青紫裂縫內光；去掉草葉 |
| `void_debris_01` | **禁止原木堆**；改碎裂建築板塊／結晶渣 |
| `void_bush_ghost` | 鬼火灌叢或能量絲團，非青綠色球樹 |
| `void_crystal_0x` | 重繪：**≥16 色**、硬邊、有內部折射面 |
| `void_crack_marker` | 對齊 `rift_cracks` 語彙的短裂縫，非 3 色 Y |
| `ground_void_stone` | 64×64 可 tile；微裂縫噪聲；亮度 std 目標 ≥12；色落在 `#050914`–`#15102D` 帶 |

### P1-06 · Decor：ember 主題

| 資產組 | 規格 |
|--------|------|
| rocks／stumps／bush | 焦黑 ＋ ember 縫；可從 void 形變，**不要**只 hue-shift farm |
| `ember_lava_crack` | 重繪熔縫，有內外兩層橙；≥12 色 |
| `ember_ruin_*` | 若保留 barn 輪廓，必須 **半崩＋燒焦**，不可再是完好穀倉染紅 |
| ground_ember_* | 焦土 tile 有灰燼點，非實心褐 |

### P1-07 · Decor：farm／廢土（可保留主題但降「主題樂園」）

| 項 | 規格 |
|----|------|
| `farm_ruined_barn` | 名實相符：塌角、破洞、偏色灰藍綠，**降飽和**，避免純紅搶過敵人 |
| hay／well／fence | 降飽和 15–25%；加裂隙塵或裂紋貼花，讓它屬於「被裂隙掃過的農野」 |
| ground_grass | 脫離高飽和遊戲綠；偏枯黃綠，std≥8 |

### P1-08 · 掉落物微調（可選併 P1）

`coin`／`gem_xp` 品質已高於敵人；建議：

- gem 保持 cyan 珠寶形（已對 ART）。
- coin 可加極弱裂隙紋，避免「純 RPG 金幣」；非必須。

---

## 7. P2 重繪／清理清單 ＋ 規格

| ID | 項目 | 規格摘要 |
|----|------|----------|
| P2-01 | `_atlas_all.png` | 重生合成：**live** 敵＋英＋彈；或標死資產移出打包路徑 |
| P2-02 | 封面 `cover.png` 與局內對齊策略 | 二選一：**(A)** 封面改 chibi 部隊宣傳風；**(B)** 局內角色向封面寫實靠攏（成本極高）。需產品拍板，**不可長期雙宇宙** |
| P2-03 | 英雄 generated 管線品質 | 禁止破壞性 48 色；改「有序調色盤 + 保持描邊」；輸出檢查 unique≥64 |
| P2-04 | 次要 decor 變體 | 每主題 1 棵特色地標（void 石碑、ember 焦塔、farm 裂井）提升 run 記憶點 |
| P2-05 | 拾取／UI 小圖與局內 prop 統一描邊粗度 | icon_health／xp／gold 與 sprite 描邊語言一致 |
| P2-06 | 動畫表現力 | Boss 專用 roar pose 1 幀；swift dash stretch 1 幀（可 runtime squash 替代則降級） |
| P2-07 | 授權註記同步 | 新繪素材進 `assets/CREDITS.md`；CC0 衍生物退役時更新對照表 |

---

## 8. 建議重繪排程（僅建議，不施工）

```
Sprint A（P0，可讀紅線）
  Boss 全組 → 三精英 → proj_lightning → proj_blade →（敵彈專用）

Sprint B（P1 主幹統一）
  grunt/fast/tank 族 → 英雄 3 皮統一語彙 → void decor 真虛空 → ember 焦土化

Sprint C（P1 內容／P2）
  亞種變體 → 4 英雄獨特皮 → farm 降調 → 彈體分化 → atlas/cover 策略
```

**體積守門（沿用專案習慣）**：單次 Web pck 增量建議仍守 **≤1.5 MiB**；優先 **較小畫布 + 好剪影**，不要無腦 256 全彩。

**效能守門**：維持現有 prewarm 策略（高密度敵 2 walk 幀；精英／Boss lazy）；新圖勿迫使 150 敵全載 6 幀高彩。

---

## 9. 驗收清單（重繪完成時用）

### 9.1 單張資產

- [ ] 透明底、無雜底色 fringe  
- [ ] 硬描邊或等效高對比外輪廓  
- [ ] 在目標顯示尺寸截圖下 0.3s 可辨類型  
- [ ] 色符合 ART（英雄／玩家彈 cyan 系；敵暖／紫；敵彈 ember）  
- [ ] 不靠 glow 也能看出威脅階（glow 僅加強）

### 9.2 同框

- [ ] 英雄＋普通敵＋精英＋彈 同螢幕不顯「四套素材包」  
- [ ] void 主題截圖無「完好紅穀倉／乾草捆」違和（除非 seed 落在 farm）  
- [ ] farm 主題不蓋過敵潮可讀（飽和與亮度低於敵）

### 9.3 工程相容

- [ ] 路徑／命名相容 `enemy_spawner`／`hero_data`／weapon `.tres`  
- [ ] `SpriteLoader.fit_sprite` 下錨點大致置中  
- [ ] EnemyArt／Stress 回歸綠；group scan 不回潮  

---

## 10. 總評分數（素材本體，不含程式 VFX 急救）

| 類別 | 分（/10） | 評語 |
|------|-----------|------|
| 敵人 | **3.5** | 有動畫與類型，但色階／族譜／Boss 權威不足 |
| 英雄 | **6.0** | 單張漂亮；族不統一、9 人 3 皮、動畫降級 |
| 武器彈體 | **4.0** | 一張對、兩張錯；共用過度 |
| Decor | **4.5** | farm 源圖好；void／ember 是染色作業 |
| 風格一致性 | **2.5** | 封面／英雄／敵人／彈／場景五裂 |
| **加權總分** | **≈4.0** | **可玩原型美術，未達可宣傳統一 2D** |

---

## 11. 結論

本輪**只審不改**。最大品質短板不是「缺圖」，而是：

1. **風格管線分裂**（商店英雄 ＋ 壓色 CC0 敵 ＋ emoji 彈 ＋ 農場 recolor 場景）；  
2. **威脅本體在像素層資訊不足**（精英 4–7 色、Boss 非獨立設計）；  
3. **色法未落在彈體檔**（黃電、金屬刃 vs ART 青／ember）。

P0 五條（Boss、三精英、電、刃、敵彈）做完，局內高潮與色法會立刻「像同一款裂隙遊戲」。  
P1 做完族譜與 decor，才配得上封面那句 **Crackveil Vanguard／裂隙先鋒**。

---

*報告路徑：`docs/GROK_ASSET_AUDIT.md`*  
*審查者：Grok 素材品質監工 · 2026-07-14*
