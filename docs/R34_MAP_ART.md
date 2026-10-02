# R34 六關手繪地圖

2026-10-02，本機完成六張原創 raster 地圖，並接入 Arena 的地面渲染，另交付六區世界地圖背景。Candidate 1 的 2200 世界單位投影在正常戰鬥鏡頭只剩中央地材，未通過場景構圖檢查；鏡射接邊也產生複製地貌。這兩個問題已撤換，以下描述目前的有限場地版本。R33 的 SVG 地磚、幾何道具、舊亮青折線和固定晶石邊框都不再建立；R33 原檔保留。

六張場地與世界地圖透過內建 `image_gen.imagegen` 分別生成，沒有使用 CLI 或 API 備援。場地提示詞要求 2048 × 2048，工具的原生輸出實際是 1254 × 1254；世界地圖為 1672 × 941。交付保留原生大小，沒有放大圖片後冒稱 2048。每張 PNG 的來源、尺寸、大小、SHA-256 與完整提示詞都保存在 `docs/evidence/r34/art/`。

## 六張原圖的美術檢查

| 場地 | 已開圖確認的內容 | 中央戰鬥區 |
| --- | --- | --- |
| 蒼月空庭 | 白灰石質圓庭、淡金月紋、藍紫晶石、雕刻遺跡、藤葉與周緣水道／瀑布 | 連續石材、少量自然裂痕，沒有方磚棋盤或中央高亮光柱 |
| 翠晶花園 | 草地、泥色自然變化、不規則石路、白紫藤花、翠晶和池泉 | 開闊草地，低矮草葉與三葉草提供自然細節；地貌不同於石造空庭 |
| 緋星熔庭 | 暗紫灰天然岩盤、邊緣熔岩、紫紅靈花、金色祭壇與晶石 | 大面積暗岩可走地材，金線低亮度，熔岩集中在周緣 |
| 風暴空島 | 浮空岩台、青晶、風雕柱、雲旋與破橋 | 完整的藍灰岩台，少量金色風紋，中央安全矩形不跨雲海 |
| 星霜冰庭 | 霜冰、冰拱、雪松、冬花、冰晶和凍泉 | 淺藍灰霜面，裂痕是表面紋理，中央不含冰窟或水面 |
| 帷幕王庭 | 紫灰大理石、金白雕柱、紫晶、帷幕、花叢和遠側王座 | 安靜的宮廷地面，沒有中央王座或高亮魔法遮住戰鬥區 |

六張場地原檔都逐張從專案路徑開啟檢查，視角為俯視 3/4，沒有地平線、人物、UI、文字或 logo。中心的空間與周緣的精細雕刻、植物和晶石分開，沒有把整張地圖填滿特效。再檢查 Godot 實際畫面，確認這些原圖確實成為地面，而不是另外交一組概念圖。

世界地圖 `world_map.png` 是同畫風的六島背景，六個地標依主流程提供的位置安排：蒼月 `.15,.63`、翠晶 `.31,.43`、緋星 `.46,.66`、風暴 `.59,.31`、星霜 `.75,.50`、王庭 `.89,.27`。原圖沒有文字、節點或 UI；可點選節點、標籤與關卡流程由主流程疊入。世界地圖背景已開檔確認，互動頁面的驗證由主流程及體驗員完成。

## 實際整合

`arena_background.gd` 改為 `r34_world_background.gd` 的相容入口。新背景是一張地面 Sprite2D 配合 `r34_raster_ground.gdshader`，把整張原圖投影到 1240 × 790 世界單位，形成俯視正交場地。在 1280 × 720、正常 1.28 鏡頭縮放下，可見原場地約 80.6％寬與 71.2％高，周緣景觀直接出現在戰鬥畫面。角色、怪物和武器沿用原有 gameplay／碰撞根；地面取樣由世界座標計算。

材質只取樣一次原圖，UV 超出原圖時 clamp，Sprite 與 shader 都禁用 repeat。沒有鏡射、複製地圖或小磚拼貼。固定種子只調整小幅地圖相位，不改畫作內容。原三個 theme ID 保留；新增 `storm_isles`、`star_frost`、`veil_court`，`run_theme.gd` 和背景 API 都包含六個主題。

`get_map_world_rect()` 回傳整張原圖的有限世界矩形，`get_playable_rect()` 回傳中央 50％的安全作戰矩形，避開周緣岩漿、池泉和懸崖。主流程用這兩個介面限制角色及鏡頭，背景本身不暗中移動碰撞根。地板 quad 跟隨相機的實際畫面中心，而非跟隨角色；鏡頭到達限制位置時，角色繼續在場內移動也不會露出 quad 邊緣。手機直向場地的尺寸與鏡頭限制仍需由主流程配合較高的 viewport 處理，不以複製原圖掩蓋外域。

地面是一個 GPU quad、一次材質取樣，移動時只更新世界座標。沒有幾何道具池、碰撞裝飾、即時生成圖片或持續重建材質。六張場地已在 Godot 匯入時產生 mipmaps，手機降低環境粒子至 6 個，桌機為 14 個；縮放時使用 mipmap 過濾。

## 已執行的驗證

目前的構圖驗證由 `R34CompositionProbe.tscn` 直接建立真正的 Arena，使用預設戰鬥鏡頭、R34 成人角色、敵人與武器，在 1280 × 720 native OpenGL 下逐一執行六個主題。每個主題輸出靜止戰鬥及實際移動後的 PNG，沒有用 overview 鏡頭代替戰鬥畫面。角色在每次檢查中實際移動 76.67–77.36 世界單位，地面仍按世界位置取樣，材質沒有重載，shader 和 Sprite 的 mirror／repeat 均為零。

六張原生戰鬥圖已逐張開啟檢查：原三張地圖的水道、花草、柱雕、晶石與熔光同屏，新增場地的浮空雲旋／風柱、冰晶／雪松與紫幕／花柱也進入正常戰鬥鏡頭。隊伍腳底仍站在各自中央平台／草地／暗岩／冰面上，中央保留清楚作戰區。先前風暴場地的敵人周緣雲海出生問題已由主流程將生成、移動、受傷及死亡滑動同步到安全 bounds，並完成下述自然實機覆驗，狀態為 resolved。

目前結果在 `docs/evidence/r34/art/composition/` 的六份 `*_probe.txt`、六份 `*_actual_arena.json` 與十二張 `*_actual_arena.png`／`*_actual_move.png`。六主題的材質載入、mipmaps、LOD 與真 Arena 移動也通過 headless 檢查，記錄在 `headless_six_assets.txt` 和 `r34_headless_probe.json`。原先 `native_probe.txt`、`r34_native_probe.json` 與 overview 圖保留為素材匯入歷史，不能用來宣稱 Candidate 1 的 2200 投影構圖通過。完整瀏覽器與手機遊玩由體驗員執行。

## 風暴關卡 20 秒自然覆驗

`R34FinalStormProbe.tscn` 透過公開選關介面選擇真正的 `storm` 關卡，建立 Arena，只送正常移動輸入及按下實際出現的升級卡。沒有修改生命、傷害、擊殺或生成狀態，也沒有 godmode、beauty mode 或加速到指定擊殺量。

1280 × 720 native OpenGL 實跑至遊戲時間 20.06 秒，真實產生 300 次擊殺、35 隻存活敵人與六次升級卡操作。當下角色為等級 7、HP 137／137，數值為引擎讀回的正常遊玩結果；腳本沒有賦值任何生命、傷害或擊殺數據。全程記錄 34,917 次存活敵人位置，安全作戰矩形外的數量始終為零。已開啟 `final_arena_storm.png` 檢視畫面確認：存活怪群腳底位於岩台內，右側雲海、風雕柱、晶石和下側建築仍入鏡；鏡頭完整落在有限地圖內，沒有鏡射地貌或全屏接縫。此結果才用來將敵人雲外殘留標為 resolved。

另以原生視窗 390 × 844、內部 viewport 720 × 1558 與手機輸入介面設定核對直向幾何，正常遊玩 6.06 秒，鏡頭自動 fit 為 2.031317。當下 71 次擊殺、12 隻存活敵人，6,620 次位置觀測均未越過安全矩形；可視世界矩形完整包含於地圖。`final_arena_storm_portrait.png` 也已實際開圖，隊伍與怪物仍在岩台上，頂部破橋與下側雕柱／雲角可見。這是 native 手機幾何檢查，不冒稱真手機或瀏覽器實玩。

最終圖與資料都在 `docs/evidence/r34/art/composition/`：`final_arena_storm.png`、`final_storm_natural_20s.json`、`final_storm_20s_probe.txt`，以及直向圖、`final_storm_portrait.json` 和 `final_storm_portrait_probe.txt`。

## 交付檔案

- `assets/art/r34/map_moon.png`：3,304,040 bytes。
- `assets/art/r34/map_garden.png`：3,289,753 bytes。
- `assets/art/r34/map_ember.png`：3,109,385 bytes。
- `assets/art/r34/map_storm.png`：3,217,993 bytes。
- `assets/art/r34/map_ice.png`：3,253,421 bytes。
- `assets/art/r34/map_veil.png`：3,232,820 bytes。
- `assets/art/r34/world_map.png`：2,863,256 bytes。
- 七張原圖都是不透明 RGB PNG，原始 `generated_images` 檔案保留。
- `scripts/arena/r34_world_background.gd` 與 `r34_raster_ground.gdshader`。
- `scripts/arena/r34_art_probe.gd` 與 `scenes/debug/R34ArtProbe.tscn`。
- `scripts/arena/r34_composition_probe.gd` 與 `scenes/debug/R34CompositionProbe.tscn`。

本機地圖版本已 freeze，未推送或發布。
