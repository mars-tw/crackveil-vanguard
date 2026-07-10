# Crackveil Vanguard — 美術監工＋玩家體驗監工對抗覆核 R10 / R10.5

**審查者**：美術監工＋玩家體驗監工（帶美術團隊 × 玩家團隊互審；以工作區 HEAD 靜態讀碼為準）  
**審查對象**：
- **R10** 美術翻修 `7e16fec`（程序化素材／星雲裂隙背景／光暈陰影／拖尾／hit-stop／UI Theme）
- **R10.5** 玩家體驗翻修 `4bfd7ae`（相機 1.28x／裂隙脈衝／環刃 82／COMBO＋掉落噴射磁吸／MainMenu）
**對照**：`docs/ART_DIRECTION_R10.md`、`docs/CODEX_RESPONSE_R10_art.md`、commit message `4bfd7ae`、既有 `docs/GROK_REVIEW_R9.md` 紅線  
**方法**：`git show`／`git diff` 靜態逐條讀碼（**只審不改**；本輪**未**重跑 headless Stress／回歸）  
**日期**：2026-07-10  

---

## 執行摘要

| 面向 | 判定 |
|------|------|
| R10 美術語言落地（背景／光暈／Theme） | **成立**（主幹對齊 ART 聖經；九宮格素材為死資產） |
| 程序化素材「色塊感」風險 | **部分成立／可接受灰區**（徑向光暈可接受；星雲偏 soft blob） |
| 150 敵加法光暈過曝 | **中風險殘留 P1**（非瞬間白屏，但滿場 cyan 洗白可預期） |
| CanvasModulate 敵彈／預示可讀性 | **未破紅線，但有降幅**（約 14% 暗化；UI CanvasLayer 不受影響） |
| hit 白閃材質策略 | **成立**（modulate 白閃，無 per-entity new material；additive 共用） |
| 相機 zoom 1.28 可讀性／迴避空間 | **中風險 P1**（視野面積約縮至 61%；Boss 環彈預讀變緊） |
| 裂隙脈衝 3.2s／傷 30 在 DPS 曲線 | **成立為 CC 恐慌鈕**（單點 DPS 低於主武器；AOE＋擊退定位正確） |
| 環刃 82 與 tank／近戰交互 | **成立改善體感**；`mirror_husk` **碼庫不存在** |
| COMBO ＋傷害數字視覺噪音 | **中噪音 P2**（字串不 merge，連殺時搶 damage_number 池） |
| 掉落噴射再磁吸 | **部分成立**；scatter **0.24s**（非 0.3s）；高速撤離＋精英雨有撿不到／延遲磁吸風險 |
| MainMenu→契約→局→結算→回主選單 | **主幹成立**；回歸只驗 wiring 未真切換場景 |
| 殘響入口與契約畫面資料一致 | **成立**（同一 `MetaProgress.buy_upgrade`） |
| 歷輪紅線（group 掃敵／cap／owner） | **未見破線**（靜態） |
| Stress 宣稱可信度 | **中等可信**（R10 表完整；R10.5 僅 commit 摘要，p95 16.9ms 貼 60fps 邊緣） |
| **R10/R10.5 總判定** | **軟 Go／可進實玩驗收**；硬 Go 前需處理：滿場光暈洗白、zoom 迴避空間、scatter 與 `force_magnet` 互斥 |

**一句話**：R10 把「黑格線草稿」拉成可宣傳的裂隙虛空語言，R10.5 補上「有主選單／有主動技／環刃摸得到／有爆裝感」五條玩家痛點——主幹碼對得上；殘留是**滿場加法洗白**、**拉近鏡頭的彈幕預讀**、以及**掉落噴射窗口期間強制磁吸被擋**。

狀態標籤：

- **成立**／**部分成立**／**未達設計意圖**／**殘留**／**預存灰區**／**發布缺口**／**碼庫無此物**

優先級：

| 等級 | 意義 |
|------|------|
| **P0** | 正確性、軟鎖、UI 謊稱、破 cap、可讀性紅線崩潰 |
| **P1** | 體驗閉環、滿場可讀、池健康、Web 熱路徑 |
| **P2** | 體感調校、文案、死資產、內容擴充 |

---

## (0) 變更盤點

| 項目 | 實況 |
|------|------|
| HEAD | `4bfd7ae`（R10.5） |
| R10 錨點 | `7e16fec` |
| 體量（R10+R10.5 累積 stat） | 68 files，+3249 / −145（含二進位 art／audio） |
| 主場景 | `project.godot:10` → `res://scenes/ui/MainMenu.tscn` |
| 版本字串 | `project.godot:11` → `0.10.5-r10.5` |

### R10 落點

| 宣稱 | 主要檔案 |
|------|----------|
| 程序化素材 | `tools/generate_art_assets.py` → `assets/art/*` |
| 背景 | `scripts/arena/arena_background.gd` |
| 共用加法材質 | `scripts/services/art_resources.gd` |
| 敵／玩家／投射物 VFX | `enemy.gd`、`player_visual.gd`、`projectile.gd`、`orbit_projectile.gd`、`death_burst.gd` |
| hit-stop | `game_manager.request_combat_impact` |
| UI Theme | `assets/fonts/default_theme.tres`（**StyleBoxFlat**，非 9-slice） |

### R10.5 落點

| 宣稱 | 主要檔案 |
|------|----------|
| zoom 1.28＋英雄 scale | `hero.gd:4,92-98`、各 `resources/heroes/*.tres` |
| 裂隙脈衝 | `hero.gd:5-12,232-328`、`player_controller.gd:19-20,35`、`hud.gd:187-210` |
| 環刃 58→82 | `resources/weapons/orbit_blades.tres:19-24` |
| COMBO／掉落雨 | `game_manager.gd:22,433-446`、`entity_factory.gd:253-328,372-375`、`pickup.gd` |
| MainMenu | `scripts/ui/main_menu.gd`、`scenes/ui/MainMenu.tscn`、結算 `main_menu_requested` |
| 回歸 | `scripts/debug/r10_5_regression_test.gd`、`orbit_blade_hit_repro.gd` |

---

## (1) 美術團隊視角

### 1.1 程序化素材品質：徑向光暈／星雲會不會像色塊？

#### 證據

| 資產 | 生成邏輯 | 行號 |
|------|----------|------|
| `radial_glow` | 距離場 `** 2.65` 外緣軟衰減＋core `** 0.7`；非硬邊圓 | `tools/generate_art_assets.py:27-37` |
| `nebula_layer` | 四階 noise 雙立方放大＋三正弦場；α 上限 150 | `:66-89` |
| `deep_space_gradient` | 徑向＋對角漸層，不透明 | `:92-104` |
| `rift_cracks` | 折線分支＋ GaussianBlur(7) 疊加 | `:107-141` |
| 運行時星雲 | 兩層 parallax 貼圖，α 0.36／0.18 | `arena_background.gd:64-65` |

#### 美術團隊結論

| ID | 命題 | 判定 | 說明 |
|----|------|------|------|
| A-1.1a | 徑向光暈像色塊？ | **否／可接受** | 衰減曲線足夠軟；被大量 tint＋放大後**會**變成「柔邊圓盤」而非體積光，但符合 ART「shared additive sprites」預算（`ART_DIRECTION_R10.md:34`） |
| A-1.1b | 星雲像色塊？ | **部分像 soft blob** | 無高頻絲狀結構；低頻 blob＋波浪可讀成「虛空雲」，**不是**純色矩形。tile_scale 1.25／0.86 下長時間平移可能露出重複感（P2） |
| A-1.1c | 裂縫像敵方預示？ | **低風險** | 背景裂縫 α 0.16；中央 additive 裂縫 z_index 4–5 但仍在背景節點（`arena_background.gd:66,121-131`）。與敵彈橙紅分離 OK |

**玩家團隊挑戰回覆**：滿場時「每一隻怪一圈 soft disc」會把星雲洗成一片霧——見 1.3。素材本身不是色塊，**疊加策略**才是風險源。

---

### 1.2 九宮格 UI 底圖拉伸邊界？

#### 證據

| 層 | 實況 |
|----|------|
| 生成 | `generate_art_assets.py:158-166` 產出 `ui_panel_9slice.png`（96×96，圓角描邊） |
| 運行時引用 | **全專案 grep `ui_panel_9slice`／`StyleBoxTexture`／`axis_stretch` → 0 筆** |
| 實際 Theme | `default_theme.tres:5-21,147` 全為 **StyleBoxFlat**（corner 8、cyan border） |

#### 結論

| ID | 命題 | 判定 |
|----|------|------|
| A-1.2a | 九宮格拉伸邊界會爛？ | **碼庫無此風險**（素材未掛載） |
| A-1.2b | 「九宮格 UI 底圖」實作宣稱 | **未達設計意圖／死資產 P2**（檔案在 repo，Theme 走 Flat） |

**監工備註**：StyleBoxFlat 路線正確、邊界安全；應在文件中改口「Flat Theme」或真正接上 9-slice，避免美術資產表誤導。

---

### 1.3 加法混合光暈疊 150 敵會不會過曝白屏？

#### 證據鏈（單實體貢獻）

| 來源 | α / 尺度 | 行號 |
|------|----------|------|
| 普通敵 threat_glow | α **0.18**，徑 `radius * 4.2` | `enemy.gd:709-718` |
| 精英 | α **0.34**，`* 5.6` | 同上 |
| Boss | α **0.46**，`* 7.2` | 同上 |
| 玩家投射物 glow | α 0.34（敵彈 0.44）＋短 trail | `projectile.gd:278-301` |
| 背景 rift_glow | α 0.28，scale ~4.9，**additive** | `arena_background.gd:139-140` |
| 共用 material | 單一 `CanvasItemMaterial` ADD | `art_resources.gd:13-21` |
| 聖經約束 | 普通敵 glow 弱於精英；150 敵可讀 | `ART_DIRECTION_R10.md:52` |

#### 分析

- **不會**瞬間整屏 clip 成純白：普通敵 α 刻意壓到 0.18，且 body 偏深紅／洋紅，非全白。
- **會**在敵群密度高峰產生 **cyan／粉紅霧狀洗白**：150 個 soft disc 在 2D ADD 下近似面積重疊積分；再加 100 投射物 glow／trail（Stress 配置）與中央 rift，相容渲染器無 HDR 壓縮時易「霧中戰場」。
- 精英／Boss 少數高 α 可接受；風險在**普通敵全員發光**（與「Only high-information objects glow」聖經 `ART_DIRECTION_R10.md:28` 略衝——普通敵仍有 glow）。

| ID | 命題 | 判定 | 優先級 |
|----|------|------|--------|
| A-1.3a | 150 敵瞬間白屏 | **未成立為必現** | — |
| A-1.3b | 滿場霧狀過曝／對比崩壞 | **中風險殘留** | **P1** |
| A-1.3c | 共用 additive material 正確 | **成立** | — |

**建議方向（只審不改）**：普通敵 glow 可改「僅邊緣 1–2 隻高亮／距離衰減／關閉普通 glow 只留 shadow」；或 α 0.18→0.10。

---

### 1.4 CanvasModulate 會不會把敵彈預示也調暗？（可讀性紅線）

#### 證據

```98:109:scripts/arena/arena_background.gd
func _ensure_canvas_tone() -> void:
	...
	tone.color = Color(0.86, 0.94, 1.0, 1.0)
```

| 項目 | 值 | 影響 |
|------|-----|------|
| CanvasModulate | (0.86, 0.94, 1.0) | 世界 CanvasItem 乘色：R×0.86、G×0.94、B×1.0 |
| 掛載點 | Arena parent `R10CanvasTone` | 影響世界節點；**不**乘到獨立 `CanvasLayer` UI |
| 敵彈色 | `Color(1.0, 0.35, 0.24)`（`enemy.gd:360`） | 視覺約 (0.86, 0.33, 0.24)，仍偏橙紅 |
| 遠程 windup | `Color(1.0, 0.88, 0.36)`（`enemy.gd:233`） | 仍黃，略暗 |
| 衝刺 windup | `Color(1.0, 0.55, 0.42)`（`enemy.gd:263`） | 仍可辨 |
| 敵彈 glow α | 0.44 > 玩家 0.34（`projectile.gd:281-283`） | 刻意抬高危險層 |

#### 結論

| ID | 命題 | 判定 |
|----|------|------|
| A-1.4a | CanvasModulate 調暗世界危險色 | **成立（約 R 通道 −14%）** |
| A-1.4b | 可讀性紅線崩潰（敵彈變背景） | **未破**——橙紅＋高 glow 仍分離 cyan 玩家彈 |
| A-1.4c | HUD／Modal 被一起調暗 | **否**（CanvasLayer） |

**灰區 P2**：hazard `_draw` 與 Line2D 預示同樣被乘色；若未來背景再亮，需把危險層改「不受 tone」或反校正。

---

### 1.5 hit 白閃：共用材質還是每實體 new？（效能）

#### 證據

| 機制 | 實作 | 行號 |
|------|------|------|
| 敵 hit 白閃 | `hit_flash_timer`＋`sprite.modulate` lerp，**無** ShaderMaterial | `enemy.gd:489,721-728` |
| 環刃 hit 白閃 | 同：modulate lerp | `orbit_projectile.gd:151-167` |
| 加法 glow material | **static 單例** `ArtResources.additive_material` | `art_resources.gd:13-21` |
| 貼圖 | `SpriteLoader`／`ArtResources` 路徑快取 | 同上 |

#### 結論

| ID | 命題 | 判定 |
|----|------|------|
| A-1.5a | 白閃每 hit new material？ | **否（成立優化）** |
| A-1.5b | additive 共用？ | **成立** |
| A-1.5c | 每敵仍有 Glow Sprite2D 子節點 | **成立（池化實體常駐）**——成本在 draw call／overdraw，不在 material 配置 |

---

### 1.6 美術其他快檢

| 項目 | 判定 | 證據 |
|------|------|------|
| hit-stop 僅精英／Boss 死 | **成立** | `enemy.gd:529-532` → `request_combat_impact`；`game_manager.gd:285-295` 用 token 還原 `time_scale`，paused 時跳過 |
| 螢幕震動尊重設定 | **成立** | 路由 `Hero.request_screen_shake`（R10 文件宣稱；與既有 PlayerSettings 鏈） |
| death_burst 池 cap | **成立** | `entity_factory.gd:39,378-380` `DEATH_BURST_CAP=20` |
| 投射物 trail cap | **成立** | `projectile.gd:7-8,291-294` `TRAIL_NODE_CAP=160` |
| vignette 蓋 HUD？ | **低風險** | vignette 在背景節點下 CanvasLayer layer=0（`arena_background.gd:185-197`）；HUD 通常更高 layer——需實機確認，靜態傾向 OK |
| 粒子池化 | **成立** | dust 單節點 amount 90；death 綁 pool |

---

## (2) 玩家團隊視角

### 2.1 相機 zoom 1.28 後 Boss／精英出場可讀性與敵彈迴避空間

#### 證據

```4:4:scripts/heroes/hero.gd
const LEADER_CAMERA_ZOOM := Vector2(1.28, 1.28)
```

```92:98:scripts/heroes/hero.gd
	if camera != null:
		camera.enabled = is_leader
		if is_leader:
			camera.zoom = LEADER_CAMERA_ZOOM
```

| 幾何 | 估算 |
|------|------|
| Godot Camera2D zoom 1.28 | **放大**角色，可見世界線性寬度 ≈ 1/1.28 ≈ **78%** |
| 面積視野 | ≈ **61%** 舊視野 |
| 英雄 sprite | captain 1.18 等（`rift_captain.tres:13`）——角色可讀 **改善** |
| Boss 環彈 | `_fire_ring_projectiles(10/14)`（`enemy.gd:310,369`），彈速 260、射程 820 |
| 遠程偏好距 | 245–255（`enemy_spawner.gd:58`） |

#### 玩家團隊結論

| ID | 命題 | 判定 | 優先級 |
|----|------|------|--------|
| P-2.1a | 角色太小痛點被解決 | **成立** | — |
| P-2.1b | Boss／精英「登場份量」 | **成立**（大＋glow＋marker 更吃畫面） | — |
| P-2.1c | 敵彈迴避空間／預讀 | **中風險惡化** | **P1** |
| P-2.1d | HUD／搖桿不受 zoom | **成立**（Control 在 CanvasLayer） | — |

**對抗裁決**：1.28 對「角色可讀」是正確方向；對「彈幕生存遊戲」是**用視野換角色感**。建議實玩量測：Boss 一階環彈是否常在螢幕外生成後才切入；必要時 1.15–1.20 折衷，或僅放大 hero sprite 而不動 camera。

---

### 2.2 裂隙脈衝 3.2s CD／傷 30 在 DPS 曲線：邊緣化還是必按？

#### 數值對照

| 來源 | 計算 | 結果 |
|------|------|------|
| 脈衝單點理論 DPS | 30 / 3.2 | **≈ 9.4** |
| 隊長主武裂線 | 12 / 0.86（`riftline_emitter.tres:13-15`） | **≈ 14.0** |
| 脈衝／主武單點比 | 9.4 / 14 | **≈ 0.67×**（單點不如普攻） |
| 脈衝 AOE | 扇形 76°（半角 38°）、距 195、**最多 28** 目標 | `hero.gd:6-12,290-314` |
| 附加 | 擊退 46、slow 0.55s @0.34 | 同上 |
| 限制 | 僅 `rift_captain` leader、未 pause、`game_running` | `hero.gd:248-256` |
| 方向輔助 | 優先最近敵（射程+120） | `hero.gd:281-287` |

#### 結論

| ID | 命題 | 判定 |
|----|------|------|
| P-2.2a | 會被邊緣化成「可有可無」？ | **單點 DPS 視角：偏弱；CC 視角：有價值** |
| P-2.2b | 會變成每 CD 必按的主輸出？ | **否**——不如持續開火；滿扇 28 目標時瞬間爆發可觀，但非旋轉輸出核心 |
| P-2.2c | 定位 | **恐慌清近距／打斷 dash windup／精英剝離** —— 設計健康 |
| P-2.2d | 操作可發現性 | **成立**（教學文案＋右下「裂」鈕＋Space）`first_run_guide.gd:50`、`hud.gd:187-190` |

**殘留 P2**：無 i-frame、無傷害衰減曲線；對 tank 58 HP 需兩發——作為開場「一鍵刪小兵」爽感足夠，對精英可能偏癢。

---

### 2.3 環刃 82 徑與 mirror_husk／正盾等敵

#### 碼庫事實

| 查詢 | 結果 |
|------|------|
| `mirror_husk` | **全 repo 無此 id／文案** |
| 定向盾／正面格擋 | **無** |
| 最近似「厚血近戰大體」 | `tank` radius 20、HP 58（`enemy_spawner.gd:30-42`） |
| Boss 站位 | 距玩家 >180 才追，否則站樁環彈（`enemy.gd:299-311`） |

#### 環刃變更（R10.5）

| 參數 | 舊 | 新 | 檔案 |
|------|----|----|------|
| orbit_radius | 58 | **82** | `orbit_blades.tres:22` |
| projectile_radius | 8 | **10.5** | `:20` |
| angular_speed | 4.35 | **3.55** | `:23` |
| hit_interval | 0.42 | **0.36** | `:24` |
| damage | 7 | **8** | `:13` |
| sprite_scale | 1.0 | **1.22** | `:18` |

命中採空間索引距離判定，非物理 body（`orbit_projectile.gd:119-136`）——R10.5 宣稱「非碰撞 bug」與碼一致。

#### 交互分析

| 情境 | 判定 |
|------|------|
| 普通／fast 貼身追 orbit_guard | **明顯改善**——有效環帶外移 24px，刃體變大 |
| tank（r=20） | 更易掃到；厚血仍需多轉 |
| Boss 保持 ~180 距離 | 環刃 **仍常掃不到**（82 ≪ 180）——合理：Boss 該由遠程／脈衝處理 |
| 隊長被追、orbit_guard 掉隊 | 刃繞 **護衛** 而非隊長；隊長身邊「真空」預存問題仍在 |
| mirror_husk 正盾 | **碼庫無此物**——無法驗收；若為未來敵，需另開詞綴設計 |

| ID | 命題 | 判定 |
|----|------|------|
| P-2.3a | 58→82 修「打不到」體感根因 | **成立**（靜態＋回歸鎖定 radius） |
| P-2.3b | mirror_husk 交互 | **碼庫無此物** |
| P-2.3c | 過強？ | **低風險**——降轉速換半徑，DPS 溫和上修 |

---

### 2.4 COMBO 浮字與傷害數字疊加噪音

#### 證據

| 機制 | 行為 | 行號 |
|------|------|------|
| COMBO 窗口 | 1.15s | `game_manager.gd:22` |
| 觸發 | `combo_count >= 3` 每次殺都 `spawn_combo_text` | `:433-446` |
| 實作 | `spawn_damage_number("COMBO ×N", …, font 24)` | `entity_factory.gd:372-375` |
| merge | **僅 numeric**（`has_numeric_value`） | `damage_number.gd:60-61,90-98` |
| 池 cap | 72 共用 | `entity_factory.gd:32,357-358` |
| 位置 | 玩家上方 −72 | `game_manager.gd:443-445` |

#### 結論

| ID | 命題 | 判定 | 優先級 |
|----|------|------|--------|
| P-2.4a | COMBO 與數字搶同一池 | **成立風險** | **P2** |
| P-2.4b | 連殺時螢幕噪音 | **中**——每殺刷新新字串節點，不 merge | **P2** |
| P-2.4c | 關閉傷害數字設定 | 連 COMBO 一起關（同入口） | 預期行為／可接受 |

**建議方向**：COMBO 單例刷新（同一 label 改數字）或獨立 cap；與數字分色分層（已分色：COMBO 青綠 `0.72,1,0.92` vs 傷害米白）。

---

### 2.5 掉落噴射「0.3s」再磁吸：高速移動撿不到？

#### 碼實況（與 commit 宣稱微差）

| 項目 | 值 | 行號 |
|------|-----|------|
| scatter_time | **0.24s**（非 0.3） | `entity_factory.gd:265,319` |
| 噴射速度 | 95–190 × scatter_scale | `:903-905` |
| 精英／Boss scale | 1.35–1.85 | `enemy.gd:513-521` |
| scatter 期間 | **直接 return，不進磁吸** | `pickup.gd:100-106` |
| `force_magnet_to` | 設 flag，但 scatter 未結束前**仍被 return 擋掉** | `pickup.gd:100-106,159-164` |
| 正常磁吸條件 | 距離 ≤ pickup_radius（captain 96） | `pickup.gd:122-129`、`rift_captain.tres:17` |
| 回歸 | 靜止 leader、pickup_radius **180**、驗 scatter 內不撿 | `r10_5_regression_test.gd:139-160` |

#### 高速場景估算

| 量 | 估算 |
|----|------|
| 0.24s 內玩家位移（230 speed） | ≈ 55px |
| 普通噴射位移 | ≈ 23–46px（再減速） |
| 精英雨 scale 1.75 | 速度可至 ~330，0.24s ≈ 60–80px 外拋 |
| 結果 | 撤離方向與噴射反向時，寶石可落在 **pickup_radius 外**；需玩家繞回才磁吸 |

| ID | 命題 | 判定 | 優先級 |
|----|------|------|--------|
| P-2.5a | 噴射→再磁吸節奏存在 | **成立**（0.24s） | — |
| P-2.5b | 宣稱 0.3s | **文案／記憶誤差**（碼 0.24） | P2 |
| P-2.5c | 高速撤離撿不到 | **真實風險** | **P1** |
| P-2.5d | 精英死 magnetic_reclaim 立刻吸 | **部分失效**——scatter 擋住 force_magnet | **P1** |
| P-2.5e | 回歸覆蓋高速 | **未覆蓋**（靜止＋加大半徑） | 發布缺口 |

---

## (3) 主選單流程與狀態 owner

### 3.1 狀態機路徑

```
MainMenu (_ready: paused=false, game_running=false, owners.clear)
  │ 開始出擊 / 種子出擊
  ▼
Arena._ready → start_squad → start_run
  │ _should_request_contract? → _request_system_pause("contract")
  ▼
ContractScreen（可買殘響）→ apply_contract → release "contract"
  ▼
局中（manual pause / upgrade / shop owners）
  ├─ player_died → clear owners → "game_over" → 回主選單 | 再來一局
  └─ record_boss_kill → clear → "stage_victory" → 繼續無盡 | 回主選單
```

| 步驟 | Owner／暫停 | 證據 |
|------|-------------|------|
| MainMenu 進入 | 清 `system_pause_owners`、`paused=false` | `main_menu.gd:36-39` |
| 出擊 | `change_scene` Arena | `main_menu.gd:309-313` |
| 契約 | `waiting_for_contract` + owner `contract` | `game_manager.gd:834-837` |
| 手動暫停互斥 | contract／upgrade／shop／victory／game_over 時 `toggle_pause` return | `game_manager.gd:1113-1121` |
| 死亡 | 清全部 owner 再要 `game_over` | `game_manager.gd:1147-1153` |
| 勝利 | 清後要 `stage_victory` | `game_manager.gd:1215-1219` |
| 回主選單 | `paused=false`、清 owners、`game_running=false` | `arena.gd:76-80` |
| 主場景設定 | `run/main_scene=MainMenu` | `project.godot:10` |

### 3.2 漏洞掃描

| 情境 | 判定 | 說明 |
|------|------|------|
| 契約中開手動暫停 | **安全** | toggle 被擋 |
| 升級／商店交疊 | **主幹沿用 R7/R9 owner 模型** | 本輪未重構；未見新破口 |
| 勝利後回主選單殘 pause | **安全** | arena 清 owners |
| MainMenu 未清 `waiting_for_*` | **低風險灰區** | 下一次 `start_run` 會重置（`game_manager.gd:201-205`）；MainMenu 自身不依這些旗標 |
| 教學 layer 45 蓋契約 | **成立（R9 延續）** | `first_run_guide.gd:15` |
| 回歸「回主選單」 | **只驗 signal 存在** | `r10_5_regression_test.gd:192-195` **未** `change_scene` 真跑一圈 |

| ID | 命題 | 判定 |
|----|------|------|
| M-3.1 | 主路徑 owner 互斥 | **成立** |
| M-3.2 | 結算→主選單可達 | **成立**（UI 鈕＋handler） |
| M-3.3 | 自動化全路徑 | **部分成立**（缺真切換場景 e2e） |

---

### 3.3 殘響入口：MainMenu vs 契約畫面資料一致？

| 項目 | MainMenu | ContractScreen |
|------|----------|----------------|
| 資料源 | `MetaProgress.get_track_definitions` / `get_upgrade_cost` / `buy_upgrade` | 同 |
| 購買 | `main_menu.gd:320-324` | `contract_screen.gd:233-239` |
| 存檔 | `buy_upgrade` → `save_progress`（`meta_progress.gd:138-151`） | 同 |
| 購買後套用小隊 | 開局 `start_run` → `_apply_meta_progress_start_effects` | **額外** `apply_current_meta_progress_to_squad`（契約時已在局內） |
| UI 差異 | 顯示 description 全文＋解鎖列表 | 精簡 level/cost；另顯契約槽解鎖摘要 |

| ID | 命題 | 判定 |
|----|------|------|
| M-3.4 | 碎片／等級／價格一致 | **成立**（單一後端） |
| M-3.5 | 雙入口導致雙扣款 | **否** |
| M-3.6 | UX 文案完全一致 | **否／可接受**——資訊密度不同，數值同源 |

---

## (4) 紅線快檢與 Stress 宣稱可信度

### 4.1 歷輪紅線

| 紅線 | 靜態判定 | 證據 |
|------|----------|------|
| 禁止熱路徑 `get_nodes_in_group("enemies")` 掃傷 | **未破** | 脈衝／環刃走 `EntityFactory.get_enemies_in_radius`（`hero.gd:293`、`orbit_projectile.gd:124`） |
| 池 cap 不可無聲膨脹 | **未破** | damage 72、death 20、xp/coin 180、trail 160… |
| hit-stop 不卡 modal | **成立** | paused 時不進 hit-stop（`game_manager.gd:288-289`） |
| system pause owner 互斥 | **主幹成立** | 見 §3 |
| Meta 數值幅度未失控 | **成立** | TRACKS 未改幅度（本輪只加入口） |
| 字型豆腐 | **宣稱 Han 451/451** | 本輪未重跑 subset 工具 |

### 4.2 Stress／回歸宣稱可信度

#### R10（`CODEX_RESPONSE_R10_art.md:106-116`）

| Metric | Baseline R9 | R10 Art | 宣稱 |
|--------|-------------|---------|------|
| avg_ms | 6.954 | 6.992 | +0.55% |
| p95_ms | 13.506 | 14.252 | +5.52% |
| max_ms | 36.293 | 35.797 | 略降 |
| group_scans | 0 | 0 | 不變 |
| 結果 | — | STRESS_PASS | |

**可信度**：**中高**——有表、有 baseline、有方法敘述；本監工輪**未複跑**，不能蓋章「本機再現」。

#### R10.5（僅 commit message）

| 宣稱 | 內容 |
|------|------|
| Stress | avg **7.3ms** / p95 **16.9ms**、group_scans=0 |
| 回歸 | R10_5RegressionTest＋全 debug 綠 |
| pck | 3.60MB |
| 字型 | Han 451/451 |

**可信度**：**中**——缺正式 `CODEX_RESPONSE_R10_5.md` 表與環境說明。

| 疑點 | 說明 |
|------|------|
| p95 16.9ms | **貼 60fps 幀預算 16.67ms**；R9→R10.5 p95 約 +25%，與 VFX／COMBO／scatter／光暈堆疊**方向一致**，數字本身不離譜 |
| Stress 場景 | `stress_test.gd` 仍 150 敵＋100 彈＋初始 VFX；**含** R10 敵 glow，**未必**打滿精英雨＋COMBO 峰值 |
| 回歸缺口 | 無 zoom 可視面積；無高速 pickup；無 MainMenu e2e change_scene；無 mirror_husk |

| ID | 命題 | 判定 |
|----|------|------|
| S-4.1 | R10 Stress 表 | **中高可信（未複跑）** |
| S-4.2 | R10.5 Stress 一句話 | **中可信；p95 警戒** |
| S-4.3 | 「全回歸綠」 | **碼存在且邏輯自洽**；執行結果本輪未驗證 |

---

## (5) 逐條總表（附檔案:行號）

### 美術

| ID | 結論 | 檔案:行號 | 優先級 |
|----|------|-----------|--------|
| A-1.1a | 徑向光暈非硬色塊 | `tools/generate_art_assets.py:27-37` | — |
| A-1.1b | 星雲 soft blob 可接受 | `generate_art_assets.py:66-89`；`arena_background.gd:64-65` | P2 接縫 |
| A-1.2 | 九宮格**未使用**，Theme 走 Flat | `default_theme.tres:5-21`；資產死檔 | P2 |
| A-1.3 | 150 敵加法：非必現白屏，滿場霧洗 **P1** | `enemy.gd:707-718`；`art_resources.gd:16-21` | **P1** |
| A-1.4 | CanvasModulate 微暗世界危險色，未破紅線 | `arena_background.gd:98-109`；`enemy.gd:233,360` | P2 監視 |
| A-1.5 | 白閃用 modulate；material 共用 | `enemy.gd:721-728`；`art_resources.gd:13-21` | — |
| A-1.6 | hit-stop 精英／Boss only | `enemy.gd:529-532`；`game_manager.gd:285-295` | — |

### 玩家

| ID | 結論 | 檔案:行號 | 優先級 |
|----|------|-----------|--------|
| P-2.1 | zoom 1.28 角色↑、迴避空間↓ | `hero.gd:4,92-98` | **P1** |
| P-2.2 | 脈衝 30/3.2 為 CC 鈕非主 DPS | `hero.gd:5-12,232-314`；`riftline_emitter.tres:13-15` | P2 調校 |
| P-2.3 | 環刃 82 成立；mirror_husk **無** | `orbit_blades.tres:19-24`；`orbit_projectile.gd:95-136` | — |
| P-2.4 | COMBO 不 merge、搶數字池 | `game_manager.gd:433-446`；`entity_factory.gd:372-375`；`damage_number.gd:60-61` | P2 |
| P-2.5 | scatter **0.24s** 擋磁吸；高速／force_magnet 風險 | `entity_factory.gd:265`；`pickup.gd:100-106,159-164` | **P1** |

### 流程

| ID | 結論 | 檔案:行號 | 優先級 |
|----|------|-----------|--------|
| M-3.1 | 主選單→契約→局→結算 owner 主幹 OK | `main_menu.gd:34-39`；`game_manager.gd:834-837,1113-1153,1215-1219`；`arena.gd:76-80` | — |
| M-3.2 | 回主選單 wiring | `game_over_screen.gd:82-84`；`stage_victory_screen.gd:97-99`；`arena.gd:43-44,49-50` | — |
| M-3.3 | 回歸未真切換 MainMenu | `r10_5_regression_test.gd:164-196` | P2 |
| M-3.4 | 殘響雙入口資料一致 | `main_menu.gd:320-324`；`contract_screen.gd:233-239`；`meta_progress.gd:138-151` | — |

### Stress／紅線

| ID | 結論 | 來源 | 優先級 |
|----|------|------|--------|
| S-4.1 | R10 表中高可信 | `CODEX_RESPONSE_R10_art.md:106-116` | 待複跑 |
| S-4.2 | R10.5 p95 16.9 警戒 | commit `4bfd7ae` message | **P1 監視** |
| S-4.3 | group scan 靜態未破 | 武器／脈衝空間索引路徑 | — |

---

## (6) 兩團隊對抗裁決紀錄（摘要）

| 議題 | 美術提案 | 玩家挑戰 | 監工終裁 |
|------|----------|----------|----------|
| 全員 glow | 解決「色點敵」 | 150 疊加洗白 | **保留精英強 glow；普通敵 α 已低但仍有滿場霧——P1 殘留** |
| CanvasModulate | 統一虛空冷調 | 敵彈變暗 | **未破紅線；維持監視** |
| zoom 1.28 | 角色可讀 | 彈幕預讀變差 | **接受方向；硬 Go 前實玩 Boss 環彈** |
| 脈衝 30/3.2 | 主角有按鈕 | DPS 邊緣 | **定位 CC／恐慌——成立** |
| 噴射掉落 | 爆裝感 | 高速撿不到 | **節奏成立；scatter 擋 force_magnet 是真 bug 級體驗洞 P1** |
| 九宮格 | 資產表有 | 拉伸？ | **未接線；改口 Flat** |

---

## (7) 總判定與下一步（只審建議）

### 總判定

**R10 + R10.5 = 軟 Go（可小圈實玩／Web 試）**  
硬 Go 前建議先收斂 **P1**：滿場光暈、zoom 迴避、scatter 與強制磁吸互斥。

### 建議驗收清單（給實作方，本輪不改碼）

1. **實機／Web**：150 敵波＋精英，錄是否「霧白」；Boss 環彈是否生成於螢幕外。  
2. **修或辯護** `pickup.gd` scatter 期間 `force_magnet_to` 無效。  
3. **補回歸**：MainMenu `change_scene` 往返；高速移動 pickup；可選降低普通敵 glow 的 A/B。  
4. **文件**：`ui_panel_9slice` 死資產註記；R10.5 補 `CODEX_RESPONSE` Stress 全表；scatter 寫 0.24s。  
5. **複跑** `StressTest` 與 `R10_5RegressionTest` 並貼環境（Godot 版、是否 headless）。

---

*本報告僅審查、不修改原始碼。HEAD：`4bfd7ae`。*
