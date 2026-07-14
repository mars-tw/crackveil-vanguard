# Crackveil Vanguard — 真姿勢動畫總修對抗審（品質 × 效能）

**審查者**：動畫品質＋效能監工（**只審不改**）  
**產品**：`Crackveil Vanguard` / 文案用名 *Crackveil Vanguard*  
**工作樹**：`main` **ahead 1** → `ac42afb`「真姿勢動畫總修…暫不部署（p95 43ms 待優化）」  
**對照文件**：`docs/CODEX_RESPONSE_true_anim.md`、`AGENTS.md` 角色動畫鐵律、M3 Stress 留檔、`docs/GROK_REVIEW_M4.md` 出貨門檻語意  
**範圍**：(1) AGENTS.md 鐵律逐條；(2) p95 爆炸根因＋裁減排序；(3) 可部署 p95 門檻建議  
**方法**：靜態讀碼＋git 祖先對照（`a5b4822` 前一版 enemy/player 動畫路徑）＋pose proof 圖＋CODEX Stress 自述；**本輪未重跑 Godot headless**（以 CODEX 數字作次級證據，並與 M3 本機留檔交叉）  
**日期**：2026-07-14  

---

## 執行摘要

| # | 議題 | 判定 | 嚴重度 |
|---|------|------|--------|
| (1) | AGENTS.md 動畫品質鐵律 | **總體成立**；姿勢幀真的接進 render；假動畫已刪；impact 傷害與 death 回收契約正確 | 品質 **Go** |
| (2) | Stress p95 爆炸（~15 → 43.2 / 37.6 ms） | **根因成立且可解釋**；主凶是「全敵滿幀 AnimatedSprite 密度 × 死亡 cohort × LOD 退場」，不是 atlas 多份貼圖 | **P0 效能** |
| (3) | 可否部署 | **No-Go 硬部署**（效能）；動畫內容可留，**須先砍一輪 LOD／death 成本** | **P0 出貨** |

**總判定**：

- **動畫方向與契約：硬 Go**——相對舊「少數 generated 幀 + 整圖 bob」已真正落地五態姿勢與命中幀。  
- **效能與部署：硬 No-Go**——桌面 p95 **43.2ms（~23 fps 級）**、mobile **37.6ms（~27 fps 級）**，相對 M3 留檔（~14.5 / ~13.9ms）約 **3×**，不可對外宣稱可玩滿編或 60fps 級。  
- 建議：**保留真姿勢產線與狀態機**，用「分級幀率／遠距停格／死亡簡化／共享 ticker」把 p95 拉回可部署帶，再談 push。

狀態標籤：**成立**／**部分成立**／**未達**／**新風險**／**紅線違規**／**預存灰區**  
優先級：**P0** 軟鎖／破出貨門檻／謊稱；**P1** 明顯體感或可量測回歸；**P2** 衛生／調校。

---

## (0) 審查基準與數字來源

### 0.1 本輪交付面

| 項目 | 值 |
|------|-----|
| Commit | `ac42afb`（本地，**未 push**） |
| 核心產物 | `assets/sprites/true_character_atlas.png`（512×3200、~1.18MB PNG）、`scripts/animation/true_animation_library.gd` |
| 執行端 | `player_visual.gd`、`hero.gd`、`enemy.gd`、`entity_factory.gd` enemy pool **220→320** |
| 契約測試 | `TrueAnimationRegressionTest`（CODEX：`TRUE_ANIMATION_REGRESSION_PASS`） |
| Pose proof | `docs/true_animation_pose_proof.png`（idle/walk 交替腿、attack0 蓄力、attack2 命中姿、hurt、death5） |

### 0.2 效能數字（不混基線）

| 來源 | Desktop p95 / max | Mobile p95 / max | enemy pool live 行為 |
|------|-------------------|------------------|----------------------|
| **M3 本機留檔** `m3_stress_desktop/mobile.log` | **14.574 / 23.058** ms | **13.940 / 21.437** ms | pool `created=220`，live≈150（**即死回收**） |
| **真姿勢後 CODEX**（`CODEX_RESPONSE_true_anim.md`） | **43.195 / 61.018** ms | **37.584 / 57.672** ms | active 150；pool-live **175 / 205**（**含 dying**） |
| 相對 M3 留檔 | p95 **+196%** | p95 **+170%** | dying cohort 首次成為 live 主力增量 |

> 註：本機 `m3_stress_*.log` 仍是 **pool=220、p95~14ms** 的舊機況留檔，**不是** `ac42afb` 複跑結果。以下 p95 爆炸以 CODEX 自述為準，並以祖先碼 diff 解釋機制因果。

### 0.3 祖先對照（解釋「為何變貴」）

| 維度 | `a5b4822` 前 | `ac42afb` 現 |
|------|--------------|--------------|
| 視覺驅動 | `AnimatedSprite2D` **idle/walk** + **整圖 bob/tilt/squash** | 僅 `AnimatedSprite2D` **五態姿勢**；bob 全刪 |
| 一般 grunt 幀 | idle **1**、walk **2**；walk fps **~5–7** | idle **4**、walk **8**；walk fps **10**（全角色同檔） |
| Elite/Boss | walk 最多 **6**；mobile 再砍到 2 | 同樣滿幀 **8 walk** |
| `animation_mobile_lod` | **有實際砍幀／砍 fps** | **仍計算、debug 回報，但 runtime 未消費**（死碼） |
| 死亡 | `_die` 即 `release_enemy_deferred` + corpse ghost 佇列 | 播 **death 6 幀 @10fps ≈0.6s** 後才 finalize／回池 |
| 攻擊傷害 | 接觸路徑偏即時／舊契約 | **impact 第 2 幀** 才結算（正確且較貴） |
| Pool | 220 | **320**（為 dying cohort 預留） |

---

## (1) AGENTS.md 動畫品質鐵律——逐條驗

### 1.1 條文對照表

| # | 鐵律 | 判定 | 證據 |
|---|------|------|------|
| 1 | 禁止只靠平移／旋轉／縮放／bob 單張平圖冒充走／攻／傷／死 | **成立** | `enemy.gd`／`player_visual.gd` 已無 `_update_procedural_*`、`visual_walk_phase`、bob amplitude；`scripts/enemies|heroes|player` 無角色 `tween_property` 姿勢偽動畫；剩餘 tween 在 UI |
| 2 | 位移必須幀動畫／骨骼／分肢 | **成立** | `TrueAnimationLibrary` → `SpriteFrames` + `AnimatedSprite2D`；Blender 產線 `tools/generate_true_animation_atlas.py` + `true_character_rig.blend` |
| 3 | Walking 必須可見肢體姿勢變化 | **成立** | walk 8 幀；pose proof `walk1`↔`walk5` 腿交替；R11 回歸要求 leader/enemy 至少 **3 個不同 frame** 且 visual root 靜止 |
| 4 | Attack 須含 anticipation／impact／recovery | **成立** | attack 6 幀；庫註與 CODEX：0–1 蓄力、**2 impact**、3 延續、4–5 recovery；回歸驗證 anticip 無傷 |
| 5 | 傷害在 impact 幀或 active hitbox，非按下瞬間 | **成立** | Hero：`play_attack` → `frame_changed` frame==2 → `attack_impact` → `_cast_rift_pulse_damage`；Enemy：`_start_attack` 只存 pending，frame 2 → `_apply_attack_impact`；whiff 距離複驗 + `attack_hit_registry` |
| 6 | 敵人須有 hurt／death 反應 | **成立** | `take_damage`→hurt；`_die`→death；`animation_finished`→`_finalize_death` |
| 7 | 物理 root／collider 與視覺分離 | **成立** | `CharacterBody2D` + `CollisionShape2D` 在場景根；視覺為子節點 `AnimatedSprite2D`（`Enemy.tscn` 僅 root+collider）；hurt 擊退改 `knockback_velocity`／`move_and_slide`，不靠 sprite.position |
| 8 | 不得把 whole-sprite bob 稱為完成動畫 | **成立** | 假動畫刪除；R11 明確 fail「bob/rotation returned」 |
| 9 | 缺資產時報告並建可替換管線，不偽造完成 | **成立** | 缺角色 → `push_error` + static `Sprite2D` 錯誤標示、**不** procedural 動；atlas 覆蓋 runtime 使用的 3 hero + 7 enemy path |

### 1.2 姿勢幀是否真的接進 render？

**成立。** 熱路徑不是「算了 region 卻畫舊圖」：

1. `TrueAnimationLibrary.get_sprite_frames(sprite_path)` 為每個 archetype 建 `SpriteFrames`，每幀 `AtlasTexture` 指同一張 `true_character_atlas.png`，region = `(frame * 64, row * 64, 64, 64)`。  
2. `player_visual._apply_sprite` / `enemy._setup_animation_frames`：`animated_sprite.sprite_frames = frames`，`sprite.visible = false`，`animated_sprite.visible = true`，`play(state)`。  
3. 切態：`stop()` → 設 animation → `set_frame_and_progress(0, 0.0)` → `play()`；中間 `current_animation_name = &"transition"` 擋舊 frame index 冒充 impact。  
4. 共享 atlas：`get_shared_atlas_instance_id()` + 回歸 assert hero/enemy 同 atlas instance。

**結論**：render 路徑是 **AnimatedSprite2D 播 AtlasTexture 姿勢幀**，不是靜態圖 + bob。

### 1.3 切態有無跳幀／誤觸 impact？

| 風險 | 處置 | 判定 |
|------|------|------|
| 舊 walk frame=2 在切 attack 時觸發 impact | `transition` 閘門 + 先改 animation 再歸零 frame | **成立（防跳幀）** |
| 重複 impact | player `attack_impact_emitted`；enemy `attack_hit_registry` | **成立** |
| attack 中被 hurt 打斷 | impact 檢查 `current_animation_name == &"attack"` | **成立** |
| walk↔idle 每幀重播 | `current == next and not restart` early-return | **成立** |

**殘留灰區（非鐵律破線）**：`_play_animation_state` 在每次 **合法切態** 都會強制 frame 0；這是正確 reset，不是跳幀 bug。Hurt 可中斷 attack（survivors 常見）；若日後要「硬直優先」屬設計選擇，非本輪缺陷。

### 1.4 速度同步防腳滑？

| 角色 | 機制 | 判定 |
|------|------|------|
| Hero / Visual | `speed_scale = clamp(motion.length / move_speed, 0.65, 1.8)` | **成立** |
| Enemy | `speed_scale = clamp(velocity.length / speed, 0.6, 1.9)` | **成立** |
| Attack/Hurt/Death 入場 | `speed_scale = 1.0` 固定播放 | **正確** |

非完美 IK 腳鎖，但屬「幀動畫 + 步頻隨速」的合理防滑；**不**再用位移相位冒充步伐。

### 1.5 品質面「非阻塞」缺口（誠實列）

| 項 | 說明 | 等級 |
|----|------|------|
| 9 英雄 3 archetype | 視覺辨識仍薄；管線可擴列 | P2 內容 |
| 僅左右 `flip_h` | 無背面／斜向 | P2 美術 |
| 武器自動開火無 attack clip | 僅 Rift Pulse 走 attack 命中幀；符合 survivors 武器模型 | 預存設計 |
| Pose 為低模塊體 | proof 顯示關節姿勢清楚，美術 polish 仍有空間 | P2 |

**裁決 (1)**：鐵律 **逐條通過**；真姿勢總修在品質上 **可留、應留**。不得因 p95 問題把整包姿勢系統當假完成——它不是。

---

## (2) p95 爆炸根因分析

### 2.1 結論先講

**主因排序（因果權重）**：

1. **全場敵人滿規格幀動畫密度**（相對舊 LOD 的質變）  
2. **Death 延遲回收 cohort（0.6s × 高擊殺率）**  
3. **`animation_mobile_lod` 退場（行動端本可砍的成本沒砍）**  
4. **每敵 `AnimatedSprite2D` 自主 process + `frame_changed` 訊號**  
5. **Pool 320 與 free 池未 `stop()` 的次級 levies**（非主兇，但放大）

**不是主因**：atlas 每敵各載一份（**否**，共享單 atlas）；「每幀 GDScript 手寫改 `AtlasTexture.region`」（**否**，由引擎 AnimatedSprite 換幀）。

### 2.2 成本在哪裡？（機制拆解）

#### A. 姿勢幀切換的真實成本

| 層級 | 行為 | 成本型態 |
|------|------|----------|
| GPU/批次 | 共享 atlas → region UV 換幀 | 相對便宜（優於舊「多張獨立 PNG」） |
| CPU（引擎） | 每顆 `AnimatedSprite2D` 自己推進時間軸、換 frame texture 指標 | **O(live 動畫體)** |
| CPU（腳本） | 每 active 敵每幀 `_process` → flip、`speed_scale`、可能 state 查詢 | **O(active)** |
| 訊號 | `frame_changed` 每換幀觸發；attack 時進 GDScript impact 路徑 | 走／idle 也付訊號稅 |

粗算（量級，非 profiler）：

- Walk **10 fps × 150 敵 ≈ 1,500 次/秒** 換幀。  
- 舊 grunt 多數 **2 幀 @ ~6 fps ≈ 900 次/秒**，且無 attack/hurt/death 狀態機、無 impact 回呼。  
- 再加上 dying 25–55 體 death @10fps，換幀與 draw 再抬一截。

Atlas region 更新 **本身** 通常不是 3× 的唯一解釋；**「誰在動、動多快、動多久、有沒有 LOD」** 才是。

#### B. 每敵 AnimatedSprite 各自 process（主兇之一）

- 150 active：皆 `play(walk|idle)`，引擎側持續 process。  
- Dying：`is_active=false` 使 GDScript `_process` 幾乎空轉，但 **`AnimatedSprite2D` 仍在播 death**（直到 finished）。  
- CODEX：desktop live **175**、mobile **205** → 同一時間 **比舊版多 25–55 顆** 仍在畫＋推進的敵人。

舊版 `_die` **立即** `release_enemy_deferred`；新版必須等 death 播完——這是 **正確品質** 換來的 **確定性 live 膨脹**。

#### C. Death cohort 320 池

| 宣稱 | 覆核 |
|------|------|
| pool 320 = 150 active + ~0.6s dying headroom | **設計意圖成立**（`entity_factory.PREWARM_COUNTS` 註解） |
| 320 本身每幀燒光 p95 | **否**——free 節點 `set_process(false)`；主成本在 **live** |
| 320 有風險 | **次級**：warmup 記憶體／節點數；且 `pool_on_release` **未** `animated_sprite.stop()`——invisible free 體若仍 `is_playing()`，子節點可繼續推進（Godot：`set_process` 不連坐子節點） |

**裁決**：pool 320 是 **症狀的容量對策**，不是根治；真正該砍的是 **concurrent full death 數** 與 **動畫密度**。

#### D. LOD 退場（相對回歸的「隱形刪除」）

祖先路徑：

- 非 elite/boss：walk **2 幀**、較低 fps。  
- elite/boss：desktop 較多幀；**mobile_lod 再砍**。  

現況：

- 一律 4/8/6/3/6 @ 4/10/12/12/10。  
- `animation_mobile_lod` 只寫入 debug dict，**不影響 fps／幀數／停格**。  

這解釋了為何 **mobile 37.6 仍接近 desktop 43**——行動檔位幾乎沒吃到動畫折扣（只剩既有 particle／death_burst cap 等舊 mobile tuning）。

#### E. 假動畫刪除的「反向」

刪 bob 應 **省一點** GDScript sin/transform；但量級遠小於「滿場 8 幀 walk @10fps + death cohort」。淨效果仍是 **大崩**——符合觀測。

### 2.3 根因權重（監工排序）

| 順位 | 根因 | 預估對 p95 貢獻 | 性質 |
|------|------|-----------------|------|
| 1 | 全敵 walk/idle **滿幀高 fps**（相對舊 2 幀 LOD） | **大** | 持續每幀 |
| 2 | Death **0.6s** 延遲回收 → live 175–205 | **大** | 擊殺波尖峰疊加 |
| 3 | Mobile/crowd **LOD 死碼** | **中–大**（尤其 mobile） | 本可便宜沒兌現 |
| 4 | 每體 AnimatedSprite 自主 process + frame_changed | **中** | 架構稅 |
| 5 | Attack/hurt 狀態機與 impact 邏輯 | **小–中** | 正確性必要成本 |
| 6 | Pool 320／free 未 stop | **小–中** | 放大／衛生 |
| 7 | 共享 atlas region 切換 | **小** | 通常非主兇 |

### 2.4 裁減方案排序（建議實作序，仍只審不改）

> 原則：**不回退鐵律**（不恢復 whole-sprite bob 當走路）；砍的是 **密度、距離、死亡、排程**。

| 順位 | 方案 | 預期收益 | 品質風險 | 實作方向（給下輪） |
|------|------|----------|----------|-------------------|
| **P0-1** | **幀率／幀數 LOD 分檔**（恢復並擴充舊 mobile_lod 精神） | **最高** | 低（遠距／雜兵） | Grunt：walk 4 幀 @6fps 或 2–4 幀；elite/boss 保留 8；mobile 再 −30–50% fps；**真正讀取** `animation_mobile_lod` |
| **P0-2** | **遠距 LOD 停格／降頻** | **高** | 低（螢幕外／遠距） | 距玩家 >R：`speed_scale=0` 或 `pause` 停在 walk0；進圈再恢復；可用 spatial 分桶 |
| **P0-3** | **死亡動畫簡化 + 並發 cap** | **高**（削 cohort） | 中（須保留「有反應」） | 雜兵：2–3 幀 death 或 1 幀 pose + 既有 death_burst／corpse_ghost；elite/boss 保留 6 幀；**同時 full-death ≤ N（如 24）** 超出走簡化路徑 |
| **P1-4** | **共享 ticker／批次推進** | **中–高** | 中（時序） | 關閉每體自動 play 時鐘，由 Arena／Factory 每 50–100ms 推進一「動畫 tick」；impact 改時間門檻或共享 frame index |
| **P1-5** | **frame_changed 瘦身** | **中** | 低 | walk/idle **不連** frame_changed；attack 期間才 connect，或用 `get_frame()` 在 animation tick 輪詢 impact |
| **P1-6** | **Pool release 強制 `stop()` + process_mode** | **小–中** | 無 | `pool_on_release`：`animated_sprite.stop()`；必要時子樹 `PROCESS_MODE_DISABLED` |
| **P2-7** | 全局 walk fps 10→7（全角色） | **中** | 低 | 最快旋鈕；可與 LOD 疊加 |
| **P2-8** | 縮 pool 320→260（在 death 簡化後） | **小** | 無 | 跟 cohort 實測再砍，避免 exhausted |

**不建議**：

- 為了 p95 **整包刪除** hurt/death／impact 契約（鐵律倒退）。  
- 只靠「headless 比較慢、真機一定行」辯護（專案合約一貫是同一套 Stress）。  
- 只加 pool 不做 death 簡化（治標不治本）。

### 2.5 預期回收帶（工程判斷，非實測）

若落地 **P0-1 + P0-2 + P0-3**（不改鐵律）：

| 階段 | Desktop p95 想像帶 | 說明 |
|------|-------------------|------|
| 現況 | ~43 ms | CODEX |
| 只做 death 簡化+cap | ~28–34 ms | 削 live 尖峰 |
| + grunt/mobile 幀 LOD | ~18–24 ms | 回到「可談部署」邊緣 |
| + 遠距停格 | ~15–20 ms | 逼近 M3 噪音帶 |

需 **同機 A/B**（`a5b4822` 或 M3 留檔條件 vs 修後）才能升格「成立」。

---

## (3) 修到多少可部署——p95 門檻建議

### 3.1 專案歷史門檻語意

| 標籤 | 數字 | 語意 |
|------|------|------|
| 60fps 幀預算 | **16.67 ms** | p95 應 **靠近或低於** 才可稱「60fps 級」 |
| M3 留檔（可信基線） | Desktop **14.6** / Mobile **13.9** | 近期「可玩滿編」工程實績 |
| M4 監工曾建議軟目標 | Desktop **≤18** / Mobile **≤16.7** | 未宣稱 60 行銷下的出貨軟線 |
| 現況 true_anim | **43.2 / 37.6** | **遠超** 任何歷史可部署線 |
| `STRESS_PASS` | 契約綠 | **只代表** pool/cap/正確性，**不代表** 效能可出貨（CODEX 已標 `STRESS_PERF_BELOW_60=true`——正確） |

### 3.2 本輪建議門檻（分級）

| 等級 | Desktop p95 | Mobile p95 | max_ms 參考 | 可否部署 | 對外說法 |
|------|-------------|------------|-------------|----------|----------|
| **硬 No-Go（現況）** | ≥28 ms | ≥24 ms | ≥45 | **否** | 不得稱可玩滿編／60fps |
| **軟 Go（最低可部署）** | **≤22 ms** | **≤20 ms** | ≤40 | **內測／試玩可**，須註 headless 未穩 60 | 「真姿勢已上，滿編效能優化中」 |
| **硬 Go（建議出貨）** | **≤18 ms** | **≤16.7 ms** | ≤32 | **是**（Web 主目標） | 可對齊 M3/M4.1 敘事 |
| **60fps 級行銷** | **≤16.7 ms** | **≤16.7 ms** | 尖峰另敘 | 僅當 p95 達線 | 且應誠實保留 max 尖峰旗標 |

**本輪明確建議**：

1. **現況不可部署**（push／release 擋板）。  
2. **第一個解鎖部署的數字**：**Desktop p95 ≤22ms 且 Mobile ≤20ms**，且仍 `enemy_group_scans=0`、pool exhausted=0、TrueAnimation 回歸綠。  
3. **對外商店／宣傳「順暢 60」** 前：須進 **≤16.7ms p95** 帶；否則只寫「滿編壓力測試優化中」。  
4. 契約：`STRESS_PASS` ≠ 效能 Go；建議未來加 **`STRESS_PERF_GATE`**（例如 p95 超 22 則非零 exit）——**屬建議，本輪未改碼**。

### 3.3 部署檢核清單（下輪合併通過才開閘）

| 檢核 | 門檻 |
|------|------|
| TrueAnimationRegression | PASS（impact／whiff／hurt／death） |
| 全 debug 回歸 | 維持綠 |
| Desktop Stress p95 | ≤22ms（軟）／≤18ms（硬） |
| Mobile Stress p95 | ≤20ms（軟）／≤16.7ms（硬） |
| pool-live 尖峰 | 建議量測並印出 max dying；目標接近 active+少量 |
| AGENTS 鐵律 | 裁減後仍不得 bob 冒充 walk／假完成 |
| Web export | pck 預算持續監視（現 CODEX ~5.65MB；atlas 已占可觀體積） |

---

## (4) 附加發現（衛生／風險）

| ID | 項 | 判定 | 說明 |
|----|----|------|------|
| H-1 | `animation_mobile_lod` 死碼 | **新風險 P0（效能）** | 計算了卻不降載；mobile 幾乎付 desktop 動畫稅 |
| H-2 | free 池 AnimatedSprite 可能仍 playing | **新風險 P1** | `pool_on_release` 未 `stop()` |
| H-3 | 每敵 shadow + threat_glow + 可選 affix Line2D | **預存** | 非本輪引入；crowd 時仍在 |
| H-4 | M3 log 與 true_anim 數字不可混寫成「同一次跑」 | **方法論** | 本報告已分表 |
| H-5 | 品質回歸覆蓋佳、效能回歸無「動畫預算」計數 | **P2 測試債** | 建議 Stress 印 `anim_playing_count` / `dying_count` / `avg_walk_fps` |

---

## (5) 最終裁決

### 品質（AGENTS.md）

**通過。** 真姿勢 atlas、五態狀態機、命中幀傷害、敵 hurt/death、物理 root 分離、假動畫刪除——與 pose proof／回歸契約一致。這不是「換皮宣稱」，是 **render 真的在播姿勢幀**。

### 效能

**不通過。** p95 從 M3 級 ~15ms 爆到 **43 / 38ms** 的機制清楚：

1. 雜兵從「2 幀低 fps LOD」變成「8 幀 10fps 全員平等」；  
2. 死亡從「即回收」變成「0.6s 動畫 cohort」；  
3. 既有 mobile 動畫 LOD **名存實亡**。

### 部署

| 問題 | 答案 |
|------|------|
| 動畫內容能不能留？ | **能，且應留** |
| 現 commit 能不能部署？ | **不能** |
| 修到多少才能部署？ | **最低軟線 Desktop p95≤22 / Mobile≤20**；**出貨硬線 ≤18 / ≤16.7**；60 行銷另需 ≤16.7 雙端 |
| 第一刀砍哪？ | **(1) 幀 LOD 復活 (2) 遠距停格 (3) 死亡簡化+並發 cap**——見 §2.4 |

---

## (6) 給實作輪的一句話

> **姿勢系統已經及格；把「每位敵人、每一幀、同等高規格」改回「近精英滿配、遠雜兵降頻、死人簡短有反應」——p95 才回得去，部署閘才開得了。**

— 監工完。只審不改。
