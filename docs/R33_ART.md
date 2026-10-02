# R33 場景重製

2026-10-02，本機實作完成。美術方向依使用者選擇，採華麗動漫風的魔法遺跡；場景保留足夠灰度，讓角色、大招與金色裝備掉落成為畫面亮點。

R32 的戰場問題很直接：大面積純黑或髒綠空底，亮青折線沒有材質，巨大晶石框在畫面邊緣，小道具像分開貼上的圖片。物件沒有共同尺度，人物也缺少站在地面上的感覺。

R33 換掉整個背景 runtime，沒有繼續疊加裝飾。新的材質與道具都是可重建的原生 SVG，由 Godot 匯入為共用紋理。場地名稱改為蒼月魔殿、翠晶庭院、緋霞祭壇；原有 theme ID、種子選擇與背景介面保留。

實玩員在 R33 桌機遊玩後指出，地磚縫的重複對比仍會搶走視線。第二次匯出前，地面限定的亮邊 opacity 由 0.54 降至 0.22，暗邊由 0.45 降至 0.16，刻紋由 0.26 降至 0.09；裂紋也同步變細變淡，再混入 22％原主題中間色。這次壓的是地板內部對比，舞台亮度、人物與道具保持原樣。修改後 native OpenGL 三主題 probe 再次通過。

## 看得見的改動

- 藍灰、灰青、紫灰三套石材地面，採斜向地面投影，配合道具與祭壇的橢圓透視。磚邊分色、少量刻紋與裂痕提供尺度；高亮魔法效果不必再跟亮青背景折線搶畫面。
- 三套材質各用固定而不同的種子，裂紋、符號位置與祭壇圖案各自不同。四顆鑲嵌寶石、金色細環和火盆的白色核心提供局部光點。
- 斷柱、低碎石、石碑、火盆與祭壇共用輪廓、材質及接地陰影。物件以世界座標放置，人物移動時保持相對位置。
- 新背景不建立 `R25ParallaxStack`、`RiftCracks`、舊 nebula 或全畫面 vignette。舊資產保留在專案內，但不出現在新戰場。

## Runtime 成本

地板只用一個 GPU quad，重複取樣快取材質。每幀更新的是世界座標與可視範圍，不產生材質、SVG 路徑、圖片或新的道具節點。48 個道具 Sprite2D 在初始化時建好；手機可見預算為 32 個，並省略一部分細碎石。只有玩家跨過 248 單位的配置格、可視配置格範圍改變或 LOD 切換才重建道具資料。相機平滑縮放不會因每個小數變動重建配置。

環境粒子由原本 90 個降為桌機 24、手機 12 個。新地面與道具不新增碰撞、導航或物理阻擋。

## 已執行的驗證

Godot 4.7 的 native OpenGL Compatibility renderer 實際載入三個主題並輸出 9 張 PNG；不是概念圖或只看 SVG 的驗收。`R33_ART_PROBE_PASS` 驗證全部 18 張材質／道具可載入、地板尺寸為 960 × 768、世界地板位移與玩家位移一致、每個道具的 global_position 與配置座標一致，以及格內移動不重建素材和道具配置。手機 LOD 的粒子／道具上限與單一地板 quad 也由程式讀回確認。

證據：`docs/evidence/r33/art/r33_art_probe.json`、同目錄的三個 `{theme}_origin.png`、`{theme}_move.png`、`{theme}_mobile_lod.png`。LOD 圖是在 1440 × 900 native 視窗切換 1.56 zoom 的效能／座標檢查，不代表真手機瀏覽器實玩截圖；完整實玩由 R33 體驗員另交報告。

R25 的舊 gate 要求固定背景框必須存在，與這次移除背景框的改動衝突。R33 以實際地板、世界定位、無舊覆蓋層、LOD 與快取測試取代該畫面條件，不把舊條件的失敗隱藏成通過。

## 檔案與重建

主要來源為 `scripts/arena/r33_world_background.gd`、`scripts/arena/r33_ground.gdshader`、`tools/build_r33_ruins.mjs` 與 `assets/art/r33/*.svg`。`arena_background.gd` 只保留相容入口。

```powershell
node tools/build_r33_ruins.mjs
& 'C:\Users\digimkt\AppData\Local\CodexTools\Godot47\Godot_v4.7-stable_win64_console.exe' --headless --path . --editor --import --quit
& 'C:\Users\digimkt\AppData\Local\CodexTools\Godot47\Godot_v4.7-stable_win64_console.exe' --path . --resolution 1440x900 --position=-32000,-32000 --rendering-method gl_compatibility res://scenes/debug/R33ArtProbe.tscn
```

文件用語已直接套用繁中 mode 2：「深度提升畫面沉浸感」這類無法核對的句子不保留，改為具體列出材質、世界定位、視覺層與已執行的驗證。
