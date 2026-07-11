# Crackveil Vanguard — 對抗性覆核 R18（R17 壓縮修正）

**審查者**：監工／對抗覆核（只審不改）  
**審查對象**：`cee62bf` — *R17 修正：walk frames 壓縮（2.69MB→117KB，pck 6.59→4.34MB 回預算內）＋動畫尺寸判斷修正*  
**基準對照**：`docs/CODEX_RESPONSE_R17.md`；前輪 `docs/GROK_REVIEW_R17.md`（P1：Web pck 膨脹／全尺寸 generated 幀）  
**範圍**：(1) 壓縮後步態視覺品質（96 色 palette／112px × 1.5× scale）；(2) 動畫尺寸判斷修正正確性；(3) 對外宣傳標準下玩家抱怨風險 Top 3  
**方法**：靜態讀 `cee62bf` diff + HEAD 現況碼；Pillow 量化 PNG 屬性（mode／尺寸／unique／半透明占比）；以 `fit` 公式＋英雄／敵人 `radius`×`sprite_scale`×相機 zoom 推算螢幕覆蓋；視覺抽樣生成 native／1.5× bilinear／3× nearest 對照（分析用、不入庫）  
**本輪未重跑 headless Godot**（CODEX 自述回歸／Stress／export 作次級證據）  
**日期**：2026-07-11  

---

## 執行摘要

| # | 議題 | 判定 | 嚴重度 |
|---|------|------|--------|
| (1a) | 96 色 palette 色帶 | **戰鬥距離可接受**；甲面／金邊平滑漸層在放大檢視有 **輕度海報化**；`dither=NONE` 放大風險 | **P2** 畫質 |
| (1b) | 112px 幀 × ~1.5× 顯示模糊 | **英雄主體偏 OK／邊沿偏軟**；**Tank／Boss 級放大嚴重欠 texel** | 英雄 **P2**；Boss/Tank **P1** 宣傳截圖 |
| (2) | 尺寸判斷改 max(idle+walk) | **演算法正確**；現管線全角色幀同尺寸 → **視覺幾乎無差**（防禦性修正） | —（修對了） |
| (3) | 對外抱怨風險 Top 3 | 見 §3 | **P1×2 + P2×1** |
| 預算 | pck 6.59→4.34MB；generated ~117KB | **數字成立**；R17-5a/b **可關** | — |

**總判定**：**軟 Go／可維持 Web 上線原型**。R17 的 P1 預算回歸 **已用壓縮還債**；壓縮本身對**一般英雄／小兵**在實戰解析度下 **未炸品質**。  
**不可當「對外宣傳級美術完成」的點**：大體型敵／Boss 在 96px 源上被 `radius×sprite_scale×zoom` 拉到 **tpp≪1**；步態仍是程序裁切＋程序 bob 雙軌；Press 文案若強調「真邁步／精緻像素」會被玩家打臉。

狀態標籤：**成立**／**部分成立**／**未達**／**新風險**／**紅線違規**／**預存灰區**  
優先級：**P0** 軟鎖／破 cap／謊稱；**P1** 首載預算、明顯體感／宣傳截圖級瑕疵；**P2** 調校／測試債／邊角。

---

## (0) 變更盤點與數字驗收

| 宣稱（CODEX R17 / commit） | 覆核結果 | 證據 |
|---------------------------|----------|------|
| generated 2.69MB → ~117KB | **成立**：27 檔合計 **116,901 B（114.2 KB）** | `assets/sprites/generated/*.png` |
| `index.pck` 6.59 → 4.34MB | **成立**：**4,344,496** bytes | `export/web/index.pck` |
| ≤5MB 預算 | **成立** | 4.34 &lt; 5.0 |
| 英雄 max 112 / 敵 max 96 | **成立**（長邊 cap） | 見 §1 表 |
| 96-color paletted PNG + alpha | **成立**：全數 `mode=P`，palette 96，帶 transparency | Pillow |
| 共用 alpha union bbox 裁切 | **成立** | `generate_walk_frames.py:118-136,171-182` |
| 尺寸判斷改掃全部 idle+walk | **成立** | `player_visual.gd:217-229`；`enemy.gd:911-923` |
| 幀路徑／數量相容 | **成立**（hero idle2/walk4；enemy idle1/walk2） | 生成器 + loader 未改路徑語意 |

| 角色組 | 輸出尺寸（全幀一致） | 單檔約略 |
|--------|----------------------|----------|
| `hero_captain` | **109×112** | ~5.3 KB |
| `hero_guardian` | **112×96** | ~4.8 KB |
| `hero_scout` | **112×87** | ~3.7 KB |
| `enemy_grunt` | **96×88** | ~4.2 KB |
| `enemy_fast` | **69×96** | ~3.1 KB |
| `enemy_tank` | **96×76** | ~3.9 KB |

壓縮管線（`tools/generate_walk_frames.py`）：

1. 程序合成 idle/walk  
2. 同角色 **padded union bbox**（`FRAME_PADDING=10`）  
3. 長邊 &gt; cap 則 **LANCZOS** 縮到 112／96  
4. `quantize(colors=96, FASTOCTREE, dither=NONE)` → 索引色 PNG `optimize=True`

---

## (1) 壓縮後步態動畫視覺品質

### 1.1 Palette 96 色：會不會色帶？

| 觀測 | 數值／現象 | 解讀 |
|------|------------|------|
| 每幀 unique RGBA | **恰 96**（palette 打滿） | 無「沒用滿」；也無空間再藏細節 |
| 源圖（captain 裁切）unique | 約 **3.9 萬** → 縮到 112 後中央甲面仍 **~1.1k** 不透明色 → quant 後中央約 **~53** | **平滑漸層被海報化**是結構結果，不是偶然 |
| 不透明純色 unique | 約 4–22（整圖） | 多數「顏色預算」花在 **半透明邊緣** |
| 半透明像素占比 | captain／tank 約 **0.45–0.61** | 抗鋸齒邊緣在 96 色下變 **軟邊／暈邊**，比硬色帶更搶眼 |
| `dither` | **NONE** | 檔案乾淨、無點陣噪訊；**換代價是漸層階梯更可見** |
| 3× nearest 目視 | 金邊、藍甲弧面可見 **輕度階躍** | 像素級檢視有色帶；非「16 色災難」 |
| 1.5× bilinear 目視 | 階躍被濾波糊掉；整體仍可讀 | **實戰／一般錄影距離可接受** |

| 命題 | 判定 | 嚴重度 |
|------|------|--------|
| 96 色導致不可遊玩的色帶崩壞 | **否** | — |
| 甲面／金屬漸層有海報化 | **是（輕～中）**；宣傳大圖／暫停近看會露餡 | **P2** |
| 無 dither 是錯誤選擇 | **取捨成立**（體積優先）；若要宣傳靜幀可改有限 dither 或 128～192 色 | 建議 |

**結論 (1a)**：以 **survivors 戰場距離**（角色世界約 50–70px 級）看，96 色 **過關**；以 **itch／社群截圖放大** 看，金邊與大面積藍甲有 **可察覺色階**，屬 **P2 畫質債**，不是 R17 預算修復的阻擋項。

### 1.2 112px 幀在 ~1.5× scale 下糊不糊？

顯示公式（與靜態 `fit_sprite` 同構）：

```text
target_diameter = body_radius * 3.1   # 英雄；敵為 radius * 3.0
scale_value     = target_diameter / max(frame_w, frame_h) * sprite_scale
world_span      ≈ max_dim * scale_value   # = target_diameter * sprite_scale
螢幕覆蓋（近似）≈ world_span * camera.zoom
texels_per_screen_px (tpp) ≈ max_dim / 螢幕覆蓋
```

英雄 `body_radius = hit_radius + 2`（`hero.gd:85`）；隊長 `sprite_scale=1.48`。相機：桌機 zoom **1.28**，行動 **1.56**（`mobile_tuning.gd:4-7,69-70`）。

| 實體 | 源長邊 | world 約 | zoom 1.5 螢幕約 | tpp@1.5 | 判語 |
|------|--------|----------|-----------------|---------|------|
| Captain | 112 | 68.8 | 103 | **1.08** | 接近 1:1，**略軟、不算糊爛** |
| 其他英雄 | 112 | 56–62 | 85–92 | **1.2–1.3** | 仍偏安全 downscale |
| Grunt / Fast | 96 | 38–51 | 56–76 | **≥1.26** | OK |
| Tank（r20×s1.36） | 96 | 81.6 | 122 | **0.78** | **放大；線性濾波變糊** |
| Boss 向 tank（r28×s1.56） | 96 | 131 | 197 | **0.49** | **明顯欠解析** |
| Boss（r34×s2.08） | 96 | 212 | 318 | **0.30** | **宣傳級糊** |

補充：

- 使用者問的「1.5×」與實機 **`sprite_scale≈1.4–1.5` + 行動 zoom 1.56** 同量級；英雄 tpp≈1.0–1.2 → **邊緣軟（半透明量化）&gt; 幾何糊**。  
- Godot 預設紋理濾波（線性）在非整數縮放下會再抹一層；本 repo 的 generated **無 checked-in `.import`**（export 時 Godot 重產），審查以引擎預設行為為準。  
- **同一套 96px 敵幀**要服務 grunt 與 Boss 雙極端 → 壓縮 cap 對小兵正確、對 Boss **系統性不足**。

| ID | 結論 | 嚴重度 |
|----|------|--------|
| R18-1a | 英雄 112px @ ~1.5×：**可接受**；非像素銳利風 | **P2** |
| R18-1b | 半透明邊緣占比高 → **軟邊／輕暈** 比色帶更影響「精緻感」 | **P2** |
| R18-1c | Tank／Boss 96px 被 scale×zoom **強放大** → 糊是 **可預期結果** | **P1**（宣傳／Boss 鏡頭） |
| R18-1d | 步態「可讀性」在壓縮後仍在；肢體裁切瑕疵被降採樣部分掩蓋 | 中性／略有利 |

**條目總結 (1)**：壓縮 **沒有**把一般角色步態做成色帶災難；**真正的模糊地雷在大 `sprite_scale` 敵人**，不是 112px 英雄本身。

---

## (2) 尺寸判斷修正正確性

### 2.1 改了什麼

| 位置 | 舊 | 新 |
|------|----|----|
| `player_visual.gd` | `max_size = max(idle_frames[0].w, idle_frames[0].h)` | `_max_animation_frame_size(idle + walk)` |
| `enemy.gd` | 同上（idle_0 only） | 同上 |

```gdscript
# 語意：與 SpriteLoader.fit_sprite 一致——用長邊對齊 target_diameter
max_size = max over frames of max(width, height)
scale_value = target_diameter / max_size * scale_multiplier
```

### 2.2 正確性判定

| 命題 | 判定 | 說明 |
|------|------|------|
| 與 `fit_sprite` 長邊語意一致 | **成立** | `sprite_loader.gd:35-40` |
| 應納入 walk（可能比 idle 伸出更多） | **成立（防禦）** | 舊邏輯在「walk 畫布更大」時會 **低估 max_size → 過大 scale → 步態看起來比 idle／碰撞圈肥一圈** |
| null 幀略過 | **成立** | `_max_animation_frame_size` |
| 空集合 → scale 1.0 | **成立**（且上游缺幀會 fallback 靜態圖） | |
| 現產資產是否會觸發數值差 | **幾乎否** | 同角色全幀 **尺寸集合基數 = 1**（union crop + 統一 resize 的構造結果） |
| 壓縮前（全畫布同尺寸 PNG）是否已有差 | **否** | R16 亦整幅同尺寸輸出 → 舊 bug **實務上多半從未現形** |
| 靜態 `Sprite2D` fallback 與動畫 on-screen 對齊 | **仍成立** | 兩者皆 fit 到同一 `target_diameter * sprite_scale` |

### 2.3 殘留邊界（非本修錯誤，屬預存語意）

| 邊界 | 說明 | 等級 |
|------|------|------|
| 只看長邊、不看有效 alpha bbox | 大量透明 padding 會讓角色「視覺偏小」（現 crop 後 padding 有限） | P2 理論 |
| `AnimatedSprite2D` 與 `Sprite2D` 都寫入同一 `sprite_base_scale` | 切換可見性時尺度連動，正確 | — |
| CorpseGhost 仍用 **base** `sprite_path` 而非 generated | 殘影不播 walk；尺度另 fit，**非本修範圍** | 預存 |

| ID | 結論 | 嚴重度 |
|----|------|--------|
| R18-2a | max(idle+walk) **正確** | — |
| R18-2b | 對 **cee62bf 現資產** 多為 **no-op**（防回歸債） | — |
| R18-2c | 未引入新的尺度漂移 | — |

**條目總結 (2)**：**修對了該修的抽象 bug**；不要在 changelog 寫成「修復角色忽大忽小」除非有實機 repro——以目前 bake 管線，**玩家體感差應接近零**。

---

## (3) 對外宣傳標準：玩家會抱怨的風險 Top 3

排序標準：**公開頁／Press／短影音／Boss 截圖**下，非開發者玩家最可能留下一星或社群負評的事項（正確性紅線已另列歷輪）。

### #1 — 大體型敵／Boss「近看糊成棉」與美術期望落差（**P1**）

| 面向 | 內容 |
|------|------|
| 現象 | 敵 generated 統一 **96px**；Boss／tank 配置 `radius` 大且 `sprite_scale` 1.5–2.0+（`enemy_spawner.gd`），再乘相機 zoom → **tpp 可到 0.3** |
| 為何排第一 | 宣傳素材最愛 **Boss／精英特寫**；糊掉的是 **焦點角色**，不是背景小兵 |
| 與本 commit 關係 | 預算修復的 **直接副作用**：從前「過肥但銳」變成「夠輕但大怪軟」 |
| 玩家原話預演 | 「Boss 怎麼像被放大模糊濾鏡」「大怪畫質比小怪還差」 |
| 緩解方向（只建議） | Boss／elite 獨立更高 cap 或沿用 base 高解析靜態＋僅小兵走壓縮幀；宣傳圖避免極端 crop Boss 臉 |

### #2 — 步態被讀成「假動畫／Jam 感」：程序裁腿 + bob 雙軌 + 敵只是傾身（**P1** 體感／敘事）

| 面向 | 內容 |
|------|------|
| 現象 | 英雄：裁切腿位移／shear（`generate_walk_frames.py:56-90`）＋執行期 bob／tilt／squash（`player_visual.gd:153-181`）**同時作用**；敵 walk 實為 dx/dy+lean（`:106-115`），僅 2 幀 |
| 為何排第二 | R16/R17 敘事是「真邁步非搖擺」；玩家 10 秒錄影就能看出 **敵人不邁步、英雄在晃＋換幀** |
| Press 風險 | `PRESSKIT.md` 仍偏 R12「程序步伐」；若對外升級話術到「完整 walk cycle」會 **過度承諾** |
| 玩家原話預演 | 「走路好怪、像紙片剪的」「敵人只會歪來歪去」 |
| 緩解方向（只建議） | 對外維持「輕量程序步態」話術；或降 bob 振幅／敵加真腳幀；宣傳片用遠景密度鏡頭而非腳部特寫 |

### #3 — 「原型完成度」一眼穿：3 張英雄底圖撐 5 人、風格與品類標竿比偏軟（**P2→宣傳時抬成 P1 體感**）

| 面向 | 內容 |
|------|------|
| 現象 | 五英雄資源、三套 `hero_*` 精靈；generated 再共享同一壓縮語彙；survivors 玩家會對標 VS／Brotato 的 **剪影清晰與讀秒可辨** |
| 為何第三 | 不致於「不能玩」，但 **商店圖／GIF 第一印象**決定 wishlist；軟邊＋共用模版會被標「素材重複／AI 感／未完成」 |
| 與本 commit 關係 | 壓縮 **放大**了「邊緣與漸層預算不足」的既有印象，但不是唯一來源 |
| 玩家原話預演 | 「角色都長一樣」「還是個 prototype」 |
| 緩解方向（只建議） | 宣傳強調玩法支柱（契約／詞綴／進化／種子）而非美術精度；截圖位遵守 PRESSKIT 的「密度／UI／詞綴」而非角色特寫 |

### 未進 Top 3 但需監視

| 項 | 理由 |
|----|------|
| Web 首載 | **本輪已止血**（4.34MB pck）；不再是抱怨主因 |
| 直式大搖桿貼技能鈕 | 仍 P2；行動差評來源，但屬操作非本 commit 主軸 |
| time_scale／橫式 modal | R17 已關主幹；非本輪回歸焦點 |

---

## (4) 歷輪紅線與本輪副作用快檢

| 項目 | 判定 |
|------|------|
| R17-5a/b pck 預算 P1 | **可關**（4.34MB、generated 117KB） |
| 敵 cap 150／池／group 熱掃 | **未見本 commit 觸碰** |
| 動畫狀態機／路徑契約 | **保留**；幀數未砍 |
| VRAM | 解析度下降 → **優於** R16 全尺寸幀；150 敵仍共享 texture cache |
| 新 P0 | **未發現** |
| 新 P1 | **Boss/Tank 放大糊**（品質維度，非正確性） |

---

## 總表

### 發現清單

| ID | 等級 | 標題 | 證據 |
|----|------|------|------|
| R18-budget | —（關閉 R17-5） | pck／generated 體積宣稱成立 | 4,344,496 B；116,901 B |
| R18-1c | **P1** | Tank／Boss 96px 強放大 tpp≪1 | spawner scale；§1.2 表 |
| R18-risk1 | **P1** | 宣傳焦點怪畫質 | 同上 |
| R18-risk2 | **P1** | 步態話術 vs 雙軌／敵 lean | `generate_walk_frames.py`；`player_visual.gd` bob |
| R18-1a/b | P2 | 96 色輕海報化＋軟邊 | unique／semi_ratio；3× 目視 |
| R18-risk3 | P2 | 原型感／模版重複 | 3 hero sprites／5 heroes |
| R18-2a | — | 尺寸 max 掃描正確（現多為 no-op） | diff + 均勻尺寸證明 |

### 非問題

- 壓縮未破壞 idle/walk 路徑與幀數契約  
- 英雄在桌機 zoom 1.28 下 texel 預算足夠  
- 尺寸修正未引入錯誤 scale 公式  
- Web ≤5MB pck 目標 **達標**

### 總判定

> **軟 Go**。`cee62bf` 作為 **R17 P1 預算急修** 合格：數字真、管線可重現、一般角色步態在實戰距離 **可接受**。  
> **硬 Go／對外當「美術完成版」宣傳前** 至少要誠實降級話術，或補：**（1）Boss／大體型獨立解析度策略**、（2）步態雙軌／敵 walk 表達**、（3）避免角色特寫當主視覺**。

---

*本報告僅覆核，不修改程式碼。*  
*行號與檔案狀態對應工作區 HEAD = `cee62bf`。*
