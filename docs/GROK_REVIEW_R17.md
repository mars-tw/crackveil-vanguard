# Crackveil Vanguard — 對抗性覆核 R17（R16 交付）

**審查者**：監工／對抗覆核（只審不改）  
**審查對象**：`de003cf` — *R16：動態大搖桿＋大小設定/多幀步態（真邁步非搖擺）/屍體殘影/技能白閃/連撿音高/time_scale owner stack/橫式 modal 修正*  
**基準對照**：`docs/CODEX_RESPONSE_R16.md` 宣稱；前輪 `docs/GROK_REVIEW_R15.md`（time_scale 競態／橫式 modal 為 R15 阻擋項）  
**範圍**：動態搖桿與多指輸入、walk frames／AnimatedSprite2D、time_scale owner stack、CorpseGhost 池 cap、`index.pck` 體積、歷輪紅線  
**方法**：靜態讀 `de003cf` diff + HEAD 現況碼對照；**本輪未重跑 headless Godot**（CODEX 自述回歸／Stress／export 僅作次級證據）  
**日期**：2026-07-11  

---

## 執行摘要

| # | 議題 | 判定 | 嚴重度 |
|---|------|------|--------|
| (1) | 動態搖桿 vs 鍵盤／固定搖桿；一指搖桿＋一指技能 | **主幹成立**；鍵鼠可疊加、非互斥；多指語意正確但**無雙指回歸** | **P2** 測試債 |
| (2) | walk frames 品質／idle↔walk／速率映射／150 敵記憶體 | **功能成立**；品質為程序裁切步態（敵更弱）；**雙軌 bob+幀動畫**；VRAM／PCK 代價高 | **P2** |
| (3) | time_scale owner stack 異常路徑 | **R15-2a 已修**；死亡／Boss／升級硬清；暫停中**不新開** hit-stop；**暫停中途凍結 timer 可暫留慢速** | **P2** 邊角 |
| (4) | CorpseGhost 池 cap | **成立**（live 24／prewarm 32／滿則靜默丟） | — |
| (5) | pck 4.15→6.59MB | **多幀 PNG 是主因**（~2.7MB 檔案增量對齊 +2.4MB）；Web 首載明顯變重；壓縮空間大 | **P1** 預算 |
| (6) | 歷輪紅線 | **未見破線**；R15 兩條 P1 本輪有對應修正 | — |

**總判定**：**軟 Go**。R15 的 time_scale 競態與橫式 modal 主幹已落地；R16 玩法／手感項可進實機。  
**不可當硬 Go 的點**：(5) Web `index.pck` 約 +59% 與過大 source 幀；(2) 150 敵每體獨立 `SpriteFrames` + 全尺寸貼圖的預算；(1) 缺「搖桿中 + 技能鈕」雙指自動化。

狀態標籤：**成立**／**部分成立**／**未達**／**新風險**／**紅線違規**／**預存灰區**  
優先級：**P0** 軟鎖／破 cap／謊稱；**P1** 首載預算、明顯錯誤體感；**P2** 調校／測試債／邊角。

---

## (0) 變更盤點（對照 CODEX R16 宣稱）

| 宣稱 | 碼上狀態 | 主要位置 |
|------|----------|----------|
| 動態中心搖桿（觸點即中心） | **成立** | `virtual_joystick.gd:28-32,89-104,142-150` |
| 熱區 1.3× 視覺半徑 | **成立** | `virtual_joystick.gd:8,127-131`；`mobile_input_smoke_test.gd:61-66` |
| 搖桿大小設定（小/中/大） | **成立** | `player_settings.gd:9,56-60`；`hud.gd:394-407,692-702,1001-1006`；`virtual_joystick.gd:69-87` |
| 多幀步態生成器 | **成立** | `tools/generate_walk_frames.py`；`assets/sprites/generated/*`（27 PNG） |
| AnimatedSprite2D idle/walk + 速比 | **成立** | `player_visual.gd:189-249`；`enemy.gd:882-943` |
| CorpseGhost 池化 | **成立** | `corpse_ghost.gd`；`entity_factory.gd:16,30,42,116,413-428,493-495`；`enemy.gd:563` |
| 隊長技白閃 | **成立** | `game_manager.gd:17,315-316`；`hud.gd:269-278,812-821`；`hero.gd:322-323` |
| 連撿音高遞升 | **成立** | `pickup.gd:27-28,276-289` |
| time_scale owner stack | **成立** | `game_manager.gd:193-195,319-357,360-369,622-643,669,1398,1467` |
| 橫式 modal 修正 | **成立** | `game_over_screen.gd:59-72,224-303`；`stage_victory_screen.gd`／`rift_shop_screen.gd`（R16 diff）；`r14_regression_test.gd:105-116` |

---

## (1) 動態搖桿 vs 既有輸入；多指觸控

### 1.1 輸入合流

| 路徑 | 行為 | 檔案:行 |
|------|------|---------|
| 觸控搖桿 | `direction_changed` → `GameManager.set_touch_move_vector` | `hud.gd:761-762`；`game_manager.gd:1382-1387` |
| 鍵盤 | `Input.get_vector(move_*)` | `player_controller.gd:22` |
| 合成 | `(keyboard + touch).limit_length(1.0)` | `player_controller.gd:22-27` |

| 命題 | 判定 | 說明 |
|------|------|------|
| 動態搖桿取代「固定中心」語意 | **成立** | 按下設 `center_active` + `_clamped_center`；放開 `_reset_direction` 回預設中心 `virtual_joystick.gd:28-36,106-114` |
| 與鍵盤互斥／搶寫 | **否（設計為疊加）** | 兩者相加後 clamp；同向加速、反向可對消。**非衝突 bug**，但桌面「鍵＋滑鼠拖搖桿」可疊成斜向 |
| 舊固定中心殘留 | **未見** | 繪製與方向皆吃 `dynamic_center if center_active` `:89-90,116-117` |
| 死區／曲線 | **成立** | `dead_zone=0.045`；`pow(magnitude, 0.9)` `:9,96-99` |
| 大小持久化 | **成立** | `PlayerSettings.joystick_size_index` 0–2 |

### 1.2 多指：一指搖桿、一指技能

| 機制 | 證據 | 判定 |
|------|------|------|
| 搖桿單指鎖定 | `active_touch_index == -1` 才接管；僅同 index 的 drag／release `virtual_joystick.gd:28-41` | **成立** |
| 技能鈕分離 Control | 右下角 `ActiveAbilityButton`，與左下搖桿分區 `hud.gd:634-642,692-702` | **成立** |
| 搖桿 `accept_event` | 只吞本 Control 上的事件 `:33,36,41` | 第二指在技能鈕上**不應**被搖桿吃掉 |
| 搖桿熱區 vs 技能鈕重疊（390 直式） | 大檔：熱區控制寬 ≈294px，視口寬 390 → 右緣空隙 ≈96px；技能鈕 ≈82px 置於 `x = 390-82-24=284` | **大檔下熱區右緣可逼近技能鈕左緣**（約 x≈294 vs 技能 284）→ **極窄機型大搖桿有重疊風險** **P2** |
| 橫式 844×390 | 熱區遠小於寬度，左右分區安全 | **成立** |
| 回歸覆蓋 | `MobileInputSmokeTest` 驗單指移動／釋放／熱區比例；**無**「index A 搖桿 + index B 技能」 | **測試債 P2** |

### 1.3 結論

| ID | 結論 | 嚴重度 |
|----|------|--------|
| R17-1a | 動態中心＋熱區 1.3×＋設定檔主幹正確 | — |
| R17-1b | 與鍵盤為**向量疊加**，非破壞性衝突 | — |
| R17-1c | 多指架構正確（單指鎖定 + 分離按鈕） | — |
| R17-1d | 直式「大」搖桿熱區可能與技能鈕貼邊／重疊 | **P2** |
| R17-1e | 缺雙指 E2E 回歸 | **P2** 測試債 |

**條目總結**：**可接受**；建議實機驗「左指拖、右指點裂」與直式大搖桿是否擋技能。

---

## (2) walk frames 品質、狀態機、150 敵預算

### 2.1 生成品質（`tools/generate_walk_frames.py`）

| 角色 | 幀數 | 手法 | 品質判語 |
|------|------|------|----------|
| 英雄 | idle 2／walk 4 | 上下半身裁切 + 腿位移／shear + 身體 lean `:53-87,90-100` | **可讀的循環邁步近似**；非手繪，關節處可能有重疊／破邊 |
| 敵人 | idle 1（原圖拷）／walk 2 | 全圖 dx/dy + lean `:103-112` | **偏左右傾／位移**，比英雄更不像「真邁步」 |

輸出尺寸與原 sprite **同像素**（例 captain 320×328、tank 334×265），`optimize=True` PNG 合計 **~2.69MB／27 檔**。顯示時再 `fit` 到 `radius * 3`（數十 px 級）→ **source 遠大於螢幕需求**。

### 2.2 狀態機與速率映射

| 項目 | 英雄 | 敵人 |
|------|------|------|
| 幀載入 | `generated/{base}_idle/walk_*.png` `player_visual.gd:223-234` | 同模式 `enemy.gd:917-928` |
| 缺幀 fallback | 回 `Sprite2D` 靜圖 `:197-200` | `:890-893` |
| idle↔walk | `moving := motion²>9` → 切 animation `:135-136,237-244` | `velocity²>4` `:845-846,931-938` |
| 播放速率 | `speed_scale = clamp(speed_ratio*1.18, 0.72, 1.85)`，分母 `move_speed` `:245-249,252-259` | `clamp(speed_ratio*1.08, 0.65, 1.95)` 分母 `speed` `:939-943` |
| 回歸 | R11：walk frame count + 切到 walk `r11_regression_test.gd:291-338` | 同檔 |

| 命題 | 判定 |
|------|------|
| 真切換 AnimatedSprite2D（非只 bob） | **成立**（有幀時 `sprite.visible=false`、`animated_sprite.visible=true`） |
| 停步回 idle | **成立** |
| 速率隨移動速度 | **成立**（夾在合理區間） |
| 仍疊加程序 bob／tilt／squash | **成立** `_update_procedural_motion`／`_update_procedural_visual` 同時改 position/rotation/scale | **雙軌動畫**，邁步感可能被 bob 放大或「晃＋換幀」過載 **P2 體感** |

### 2.3 150 敵記憶體與效能

| 項目 | 分析 | 判定 |
|------|------|------|
| 貼圖快取 | `SpriteLoader.texture_cache` 按 path 共用 `sprite_loader.gd:4-27` | **VRAM 不隨敵數複製像素** **成立** |
| 每敵 `SpriteFrames.new()` | 每次 `setup`→`_setup_animation_frames` `enemy.gd:762,882-910` | **150 份小 Resource 引用同一 Texture**；分配／GC 有成本但通常低於像素 |
| 每敵雙節點 | `Sprite2D` + `AnimatedSprite2D` 常駐 | 輕量 |
| 每幀動畫 tick | Godot 內建；外加既有 procedural visual | Stress 自述 p95≈15.8ms／cap 24 ghost **未顯示動畫為主因**（次級證據） |
| 解壓 VRAM（RGBA 粗估） | generated 全幀 ≈ **8.6MB** raw；角色基底另 ≈1.8MB | Web GPU 上可接受但**偏肥**（顯示只需 ~1/6 線性尺寸 → 面積 ~1/36） |
| 池重設 | `pool_on_release` 藏 animated；再 `setup` 重建 frames | 正確但每波重生多一次配置 |

### 2.4 結論

| ID | 結論 | 嚴重度 |
|----|------|--------|
| R17-2a | idle/walk 狀態機與 speed_scale **正確** | — |
| R17-2b | 英雄步態可接受；敵人 2 幀偏「傾身」 | **P2** 品質 |
| R17-2c | 程序 bob + 幀動畫雙軌 → 可能過動 | **P2** |
| R17-2d | 150 敵**不**因幀複製爆 VRAM；瓶頸在**貼圖尺寸與 PCK** | **P1** 見 §5 |
| R17-2e | 每 spawn `SpriteFrames.new()` 可優化為共享資源 | **P2** |

---

## (3) time_scale owner stack 異常路徑

### 3.1 設計（對 R15-2a）

| API | 行為 | 行 |
|-----|------|-----|
| `acquire_time_scale(owner, scale)` | 寫入 token+scale；`_sync` 取 **min** | `game_manager.gd:319-327,350-357` |
| `release_time_scale(owner, token)` | token 不符則 **no-op** | `:330-337` |
| `clear_time_scale_owners` | 清空並 `Engine.time_scale=1.0` | `:340-343` |
| hit-stop | 唯一 owner `"hit_stop:%d"`，await 後 release | `:360-369` |
| level-up slowmo | `"level_up:%d"`，結束／mismatch **皆 release** | `:622-643` |

對照 R15：舊邏輯 hit-stop timeout **強制 1.0** 會砍掉升級 0.35 → **本輪已修**。R13 回歸 `r13_regression_test.gd:159-183` 覆蓋：0.35→hit 0.18→恢復 0.35→stale token 不誤釋→最終 1.0。

### 3.2 異常路徑劇本

| 劇本 | 結果 | 判定 |
|------|------|------|
| hit-stop 中再 hit-stop | 各用獨立 owner key；min 仍 0.18；先結束者不拉回 1.0 | **正確** |
| hit-stop ∩ level slow | min(0.18,0.35)=0.18；hit 釋放後回 0.35 | **正確**（R13 有測） |
| level token mismatch | 仍 `release_time_scale` 自己的 owner | **正確**（修掉 R15「不還原」洞） |
| **owner「死亡」未釋放** | 本系統 owner 是字串非實體；**無**「敵人死了 token 殘留」路徑 | **N/A** |
| 玩家死亡／Boss 殺／開局／套用升級 | `clear_time_scale_owners` | **成立** `:215,669,1398,1467` |
| **暫停中觸發 slow-mo** | `request_combat_impact` 在 `get_tree().paused` 時 **直接 return**（不 acquire） | **成立** `:363-364` |
| hit-stop **進行中**再 system／manual pause | timer：`create_timer(dur, true, false, true)` → **ignore_pause=false**，timer **凍結**；owner 仍在 → **time_scale 可維持 0.18 直到解暫停後 timeout 或 clear** | **邊角 P2**；UI 多為 `PROCESS_MODE_ALWAYS`，戰內邏輯已 paused |
| 升級 modal 開啟後 | 已 pause → 新 hit-stop 不進；apply 時 clear | **成立** |
| 永久卡慢 | 需 clear 全失敗且 owner 殘留；正常結算／死亡會硬清 | **實務低**；優於 R15 |

### 3.3 結論

| ID | 結論 | 嚴重度 |
|----|------|--------|
| R17-3a | R15-2a 跨系統搶寫 **已修** | — |
| R17-3b | 暫停中**不新開** combat slow-mo | — |
| R17-3c | 暫停凍結 hit-stop timer → 暫留慢速至 resume／clear | **P2** |
| R17-3d | 無「實體死亡漏 release」類 owner 模型問題 | — |

**條目總結**：**可關 R15-2a**；剩餘為 pause 與 timer 互動的邊角，非 P0 卡死。

---

## (4) CorpseGhost 池 cap

| 項目 | 值／行為 | 行 |
|------|----------|-----|
| Prewarm | 32 | `entity_factory.gd:30` |
| Live cap | **24** | `:42,413-415` |
| 滿 cap | `return null`（靜默，不 instantiate） | `:414-415` |
| 池耗盡 | `_acquire` null → return null | `:416-418` |
| 生命週期 | 0.34s 後 `release_corpse_ghost` | `corpse_ghost.gd:10,71-74` |
| 觸發 | 敵 `_die` `call_deferred("spawn_corpse_ghost", …)` 用**靜態** `sprite_path` | `enemy.gd:555-563` |
| 契約 | `pool_on_acquire/release/reset` 齊 | `corpse_ghost.gd:19-50` |

| 命題 | 判定 |
|------|------|
| 有硬 cap | **成立** |
| 破 cap／無限 new | **未見** |
| 高壓擊殺丟殘影 | **預期**（爽度削峰，非正確性事故） |
| Stress 自述 live cap 命中 24、未 exhausted | 與碼一致（次級證據） |
| `sprite.scale *= 1+δ*0.05` | 0.34s 內輕微膨脹；release 重設 scale | **可忽略 P2** |

**條目總結**：**cap 設計正確**；滿載丟棄可接受。

---

## (5) pck 4.15MB → 6.59MB

### 5.1 歸因

| 來源 | 量級 | 說明 |
|------|------|------|
| `assets/sprites/generated/*.png` | **~2.69MB**（27 檔） | R16 新增；與 pck 增量 **+2.44MB**（4.15→6.59）高度對齊 |
| 腳本／tscn／回歸 | 數十 KB 級 | 可忽略 |
| 音效／字型 | 本 commit **未**新增大音效／字型 | — |
| 基底 hero/enemy PNG | 仍保留（殘影／fallback／生成源） | 與 generated **內容重複度高**（敵 idle_0≈原圖） |

**結論：多幀 sprite 是主因 — 成立。**

### 5.2 Web 首載影響

| 項目 | 觀察 |
|------|------|
| `export/web/index.pck` 現況 | **6,588,576** bytes（與 CODEX 6,588,576 一致） |
| 相對舊 4.15MB | 約 **+59%** 僅 pck 本體 |
| 總下載 | 另含 `index.wasm`／js（本輪未重測）；pck 仍是可玩內容主體之一 |
| 匯出設定 | `export_filter=all_resources`；`vram_texture_compression/for_mobile=false`，`for_desktop=true` `export_presets.cfg:9,27-28` → Web 端壓縮策略**偏保守**，不利行動網路 |

### 5.3 壓縮／瘦身空間（只建議，不改碼）

| 方向 | 預期收益 | 備註 |
|------|----------|------|
| 生成幀降採樣到顯示直徑的 2–3×（如 64–96px） | **高**（面積 ∝ 邊長²） | 現 ~300px 對戰場圓直徑過大 |
| 精靈圖集（atlas）+ 共用 `SpriteFrames` 資源 | 中（減少檔頭／重複；便於 import 壓縮） | 並消每敵 `SpriteFrames.new()` |
| 敵 walk 改 shader／2 幀共用 lean 參數免存檔 | 中 | 敵動畫本就弱 |
| 啟用 Web 合適 VRAM／lossy 匯入（或 mobile 壓縮） | 中 | 需實機色帶驗證 |
| 移除與 base 重複的 idle_0 全拷 | 低～中 | 直接引用 base path |
| 英雄 4 幀改 2–3 幀 | 低～中 | 品質取捨 |

### 5.4 結論

| ID | 結論 | 嚴重度 |
|----|------|--------|
| R17-5a | pck 膨脹**主因=generated 多幀 PNG** | **P1** 預算 |
| R17-5b | Web 首載明顯變重（+~2.4MB pck） | **P1** |
| R17-5c | 壓縮空間大（解析度／圖集／重複 idle） | 建議後續 |

---

## (6) 歷輪紅線快檢

| 紅線 | 判定 | 證據 |
|------|------|------|
| 敵硬 cap 150 | **未破** | `enemy_spawner.gd:112`；split `death_spawn_cap` 仍裁切 |
| 武器熱路徑不 `get_nodes_in_group("enemies")` 掃全場 | **未見本輪倒退** | 空間索引／工廠 API 仍在；Stress 自述 `enemy_group_scans=0` |
| 池 cap／無野 new 彈種 | **未破**；CorpseGhost **有** cap 24 | `entity_factory.gd:34-45,413-415` |
| `spawn_token` | **維持** | `entity_factory`／`enemy.gd:155` |
| hit-stop 在 modal pause 不啟動 | **成立** | `game_manager.gd:363-364` |
| time_scale 多來源互砍 | **本輪已修**（§3） | R15-2a → closed |
| 橫式結算倒掛 | **本輪已修主幹** | Scroll + 雙欄 `game_over_screen.gd:59-72,224-303`；R14 補 shop/victory/go 844×390 |
| 敵彈／預示可讀 | **本輪未動 tone** | 沿用 R15 未破 |
| 決定性 seed | **未見新 RNG 主幹** | walk 幀為 bake 資產；pickup streak 用 `Time.get_ticks_msec`（**音效表達**，非戰鬥 RNG） |
| 新 P0 軟鎖 | **未發現** | ghost 滿 cap 靜默；搖桿不阻死輸入 |

### 預存灰區（非本輪引入）

- 掉落 scatter／部分 VFX 非決定性  
- 長無盡升級池耗盡（R8/R9 起）  
- 音效 12 池搶播（R15-5b）  
- `enemy.gd:458` heroes group fallback（非新）

---

## 附帶快檢（宣稱內、非六大題）

| 項 | 判定 | 行 |
|----|------|-----|
| 隊長白閃 0.05s | **成立** | `hud.gd:812-821` |
| XP 連撿 pitch | **成立**；520ms 窗、每級 +0.045、上限 1.48 | `pickup.gd:282-289` |
| coin 不走遞升 | **成立**（固定 0.96） | `:278` |

---

## 總表與建議（只審不改）

### 發現清單

| ID | 等級 | 標題 | 證據 |
|----|------|------|------|
| R17-5a/b | **P1** | Web pck +2.4MB，主因全尺寸 generated 多幀 | `assets/sprites/generated` ~2.69MB；`export/web/index.pck` 6,588,576 |
| R17-2c | P2 | 幀動畫 + 程序 bob 雙軌可能過動 | `player_visual.gd:131-186,237-249`；`enemy.gd:841-875,931-943` |
| R17-2b | P2 | 敵 walk 僅 lean，宣稱「真邁步」對敵偏強 | `generate_walk_frames.py:103-112` |
| R17-2e | P2 | 每敵重建 `SpriteFrames` | `enemy.gd:887-910` |
| R17-1d | P2 | 直式大搖桿熱區貼近技能鈕 | 熱區寬≈294 vs 技能 x≈284（390 寬） |
| R17-1e | P2 | 無雙指（搖桿+技能）回歸 | `mobile_input_smoke_test.gd:106-149` |
| R17-3c | P2 | pause 凍結 hit-stop timer 可暫留 time_scale&lt;1 | `game_manager.gd:368-369`（ignore_pause=false） |

### 本輪可關單（相對 R15）

| 原 ID | 狀態 |
|-------|------|
| R15-2a time_scale 互砍 | **已修** → owner stack + R13 回歸 |
| R15-3d GameOver 橫式倒掛 | **主幹已修** + R14 補測 shop/victory/go |
| R15-3c 商店／結算無回歸 | **已補** `r14_regression_test.gd:105-116` |

### 非問題

- CorpseGhost **有** live cap，未破池紅線  
- 鍵盤與觸控合成不會互鎖卡死  
- 暫停中**不會**新開 combat hit-stop  
- 死亡／Boss／開局硬清 time_scale owners  
- 歷輪 150 cap／group 熱掃紅線 **未見違規**

### 總判定

> **軟 Go**。R16 對 R15 的兩條 P1（time_scale、橫式 modal）有對應落地；動態搖桿與步態主幹正確。  
> **硬 Go／對外強調「更輕 Web」前**建議至少處理：**（P1）generated 幀解析度或圖集壓縮**，並實機確認直式大搖桿＋技能雙指。

---

*本報告僅覆核，不修改程式碼。*  
*附檔案:行號均指工作區 HEAD（對應 commit `de003cf` 內容）。*
