# R36 周回大世界地圖

地面週期為 4096 × 3072，角色世界座標可以連續前進。場景使用四張新 ImageGen 手繪地材與一張八地標透明 atlas，沒有把 R34 的小平台放大，也沒有背景跟鏡頭固定的邊框、鏡射平台或雲外地面。

四張地材原生 1254 × 1254：石地、草地、冷卻玄武岩、霜石。原畫、提示詞、工具保存路徑與 SHA-256 在 `sources/` 和 `source_manifest.json`。地材只做成對邊緣的窄羽化，保留原畫；交付版本左右／上下端點 RGB 完全一致，`qa/material_seam_report.json` 的最終對邊誤差均為 0。512 世界單位的材質跨度能整除世界週期，跨過世界接點也不會出現地材斷縫。這是新可平鋪材質，不是用棋盤或細線代替繪畫。

地面只用一個 GPU quad，shader 把完整實地覆蓋全部週期，再用兩張快取地材做寬而柔的道路混合。主環路中心為 `(0,0)`，橢圓半徑 `(1400,1000)`，路寬約 240；中央廣場半徑約 270，四向支路寬約 170。全域皆是可走實地，活動空間並非只有窄環路。

透明地標 atlas 原生 1774 × 887、4 欄 2 列。八個地標為月門遺館、翠泉花庭、南行驛門、緋焰祭台、星霜石碑、風潮晶塔、帷幕王座、晶心原。巡回點從東 `(1400,0)` 起，每 45 度一點；南 `(0,1000)` 是 index 2，作為出生路段。`position` 保持道路巡回點，`visual_position` 向環外偏 250，避免沿路人物腳底疊進裝飾花泉。

八個 Sprite2D 在初始化建好，Node UID 固定。每幀只把地標放到相機附近的最近週期影像並做可見性裁切，沒有重新建立地標、重新載圖或逐幀產生材質。四地材與一 atlas 共五張共享貼圖，皆已設定 mipmaps；六主題用不同地材／色盤，手機和平板仍用同一個大世界，不換成另一種地圖。

## API

來源為 `scripts/arena/r36_loop_world_background.gd` 與 `r36_loop_world_ground.gdshader`。主流程負責玩家／相機不設硬邊界、遠處怪物與掉落的最近週期位置、近視野生成與互動。

- `configure_run_theme(seed,theme)`：六個既有 theme ID 都支援。
- `get_loop_period()`：`Vector2(4096,3072)`。
- `get_map_world_rect()`／`get_playable_rect()`：`Rect2(-period/2,period)`，完整週期。
- `get_landmarks()`：八項 `{id,name,position,color,visual_position,road_index,obstacle_radius}`。
- `get_ring_waypoints()`：八個道路巡回點。
- `get_paths()`：環路、兩條穿過中央的四向支路與中央廣場。
- `get_r36_debug_state()`：實際 `bitmap_ready`、貼圖載入數、快取路徑、地標 UID、可見地標、週期與相機中心。

## 已執行的驗證

`qa/prototype_probe.gd` 在 headless 與 native OpenGL 都通過週期、全域地面、八節點 UID 與快取檢查。原生圖從南路 `(0,1000)` 移到 `+4096,+3072`，地材與地標仍是同一世界，沒有鏡射；正式位圖已讀回 `bitmap_ready=true`。

`qa/palette_cache_probe.gd` 原生輸出六主題色盤，之後跨過六個週期並切換手機 LOD，節點不變、暖快取只五張貼圖、重新載入數為 0。該檢查是原生渲染／LOD，不冒稱真手機硬體實玩。

`qa/R36NativeHeroWalk.tscn` 建立真正的 Arena，使用正常移動與實際升級卡選擇，不傳送角色、不注入 HP／XP／擊殺或無敵。從南路走到中央，再到東路、東南環路，共三段；接著持續向右走過 4163.53 世界單位。遊戲時間 29.58 秒、458 次自然擊殺，角色坐標連續跨過整個週期；八地標 UID 與初始兩張貼圖載入數始終不變。已逐張開圖確認月門、花泉、道路與可走實地，修正後路上腳底與花泉淨空，角色後層金色技能沒有遮住臉。

證據在 `qa/native_hero_walk.json`、`native_hero_walk.txt`、`hero_south_waypost.png`、三張 `hero_route_*.png` 與 `hero_after_full_period.png`。原畫和 QA／重建腳本可排除於遊戲包；runtime 只需要四張 `tile_*.png`、`landmarks.png` 及兩個背景來源檔。

地圖與圖景已 freeze，未改動 Hero、enemy、spawner、Arena wrapper 或 Root 控制服務，未推送。
