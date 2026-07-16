# Crackveil Vanguard — Stylized Game Character 技法研究與 R20 落地

日期：2026-07-16

適用版本：`v0.15.0-r20`
目標媒介：Blender 3D 製作，最終以 Godot 4.7 Web 使用的 64px 2D sprite atlas 出貨。

## 研究來源與可重用原理

本輪只採用公開文件、開源工具鏈與 repo 內已驗證產線的技法；沒有下載或改作第三方角色模型。

1. **從大形、比例與剪影開始。** Blender Studio 的 [Stylized Character Workflow](https://video.blender.org/w/bd2A5cWzo5nVsPhjxsoDeJ) 展示從 sculpt 到 final asset/render 的完整 stylized 流程；Blender Studio 的 Project Storm 也公開其從 [concept sketch、sculpt 到 3D 定型](https://studio.blender.org/projects/storm/production-log/302/) 的製程。對 64px sprite 而言，細小紋理會先消失，所以辨識順序定為「頭身比例 → 外輪廓道具 → 大色塊 → 臉 → 小裝飾」。R20 採約 4 頭身 heroic-chibi 比例：頭、手、腳與武器端點放大，肩線寬、腰線收、腿較短，讓臉與動作在縮圖仍可讀。

2. **Stylized low-poly 不是把方塊堆成人。** 低面數應服務曲面轉折與輪廓，而不是平均刪面。R20 將面數優先放在頭、胸甲、肩甲、帽沿、盾牌和武器端點：大曲面使用 320-tri faceted icosphere；四肢改為 10 邊、上粗下細的 tapered forms；布料以有厚度的 prism、披風和不對稱下襬塑形。每位英雄 idle 模型實測 3,956–5,152 tris，仍保留平面切光的 low-poly 語言，但不再有 R16 的 20-tri 球頭與等粗柱狀四肢。

3. **暖亮、冷暗與 hue shift。** Gooch 等人的 [Non-Photorealistic Lighting Model](https://www.cs.princeton.edu/courses/archive/fall00/cs597b/papers/gooch98.pdf) 指出，以明度和色相共同表示表面方向、把極亮與極暗保留給 highlight/edge，可比單純 Phong 明暗更清楚地傳達體積。R20 的 `cv_gradient` 因此不是灰階乘色：上方色票略暖、略亮，下方色票混入藍青並壓到中暗值；燈光再用暖 key、冷 fill、冷 rim 與中性 bounce 分離受光面。

4. **Gradient ramp / toon shading。** Blender 的 [Toon BSDF](https://docs.blender.org/manual/es/4.1/render/shader_nodes/shader/toon.html) 說明以有限反射區間形成卡通式明暗；Godot 的 [Spatial Shader](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html) 也提供 `diffuse_toon`、rim 與 AO 等 NPR 元件。R20 最終是預渲染 sprite，不依賴 runtime 3D shader，因此把兩段式概念改成可重建的 vertex ramp：每個 primitive 依局部高度寫入暖上色／冷下色，配合 faceted normals 形成穩定色階，避免動畫不同幀出現 shader 閃爍。

5. **Baked AO / 體塊壓暗。** Blender [Render Baking 文件](https://docs.blender.org/manual/ka/4.5/render/cycles/baking.html) 說明 AO 可烘焙到 image texture 或 color attribute，讓遊戲資產不必逐幀重算昂貴遮蔽。R20 沒有 UV 貼圖需求，採等價的 mesh-generation bake：`cv_gradient` 在建模時寫進 point color，底部與凹處以受控中暗值分組，材質節點只加入 24% AO 調制。這使 459 格動畫的體塊深淺可重現，也避免 AO 把眼窩、披風和深色英雄壓成黑洞。

6. **Selective outline，而非滿畫面黑線。** Blender Freestyle 可依 [silhouette、crease、border、edge mark](https://docs.blender.org/manual/pt/5.0/render/freestyle/view_layer/line_set.html) 選線；Blender Studio 的 toon workflow 也示範 [backface-culling outline](https://studio.blender.org/training/toon-character-workflow/5859a5da1f47427e3fe82330/)。64px 下若把所有 primitive 接縫描黑，臉會變髒，因此 R20 只對每個 64px cell 的 alpha 外輪廓做 1px dilation：不跨格、不畫內線；模型本身再用冷 rim 把肩、髮、帽與道具從深藍戰場分離。

7. **有限色盤與 value hierarchy。** OpenGameArt 的 [Color Palettes 章節](https://opengameart.org/node/5493) 說明同一組 palette 應貫穿設計流程。R20 每位英雄固定「3 主色＋1 accent」，另有共用 skin/sclera/pupil；accent 只放在眼、徽記、武器核心與職業道具，不拿來平均灑滿全身。暗色負責髮、皮革和輪廓，中色為布料，大亮色為金屬／領巾／披風；在 64px 先讀角色色塊，再看到亮點。

8. **臉部必須是幾何與對比設計。** R16 的小眼點不足以撐住 64px。R20 頭部放大到約 0.69 world-unit 直徑，臉由獨立眼白、虹膜、黑瞳、左右眉、鼻和嘴組成；角色特徵再疊加單眼鏡、護目鏡、額心符文、冠帶或髮飾。眼白建立明度底、虹膜接角色 accent、黑瞳與眉提供最小有效對比，因此縮到原生格仍能辨識臉，而不是靠報告中的高解析 render 假裝完成。

## Storm R8 移植決策

本機姊妹專案 `../storm-apocalypse` 的 R8 已獲驗收，本輪直接研讀其下列產線：

- `tools/blender/blender_utils.py`：`StormGradient`／`COLOR_0` 垂直體積漸層、real bevel、surface roughness/metallic 分組。
- `tools/blender/char_*.py`、`hero_rig_factory.py`、`character_factory.py`：以職業道具、帽、包、披肩與臉部幾何建立剪影與故事性。
- `tools/blender/build_character_pack.py`：可重建、批次輸出而非手工覆寫成品。
- `public/images/ui/render-preset-r8.json`：AgX Base、暖 key／冷 fill／rim／bounce、3 主色＋1 accent 的出貨規約。

R20 保留 AgX Base 與四燈色彩關係。Storm portrait 的 `+1.25 EV` 是為 384–512px 人像設計；直接套到 64px 會讓皮膚和金屬色塊接近白色，因此以亮度 gate 實測校正為 `+0.85 EV`。材質反應移植為 skin `roughness 0.66`、cloth `0.90`、leather `0.72`、hair `0.84`、metal `roughness 0.30 / metallic 0.76`、lens `roughness 0.24 / metallic 0.18`。

## R20 可重建實作對照

- 模型、姿勢、材質與 atlas：`tools/generate_true_animation_atlas.py`
- 每格 selective outline：`tools/postprocess_character_atlas.py`
- 正／側／背正交審查：`tools/render_character_threeviews.py`
- R16/R20 比較與 evidence 標籤：`tools/build_art_r20_evidence.py`
- 亮度 gate：`tools/check_sprite_luminance.py`，已在 `.github/workflows/deploy-web.yml` 的 web export 前執行。
- 可編輯 Blender source：`tools/true_character_rig.blend`；物理 root 與碰撞器仍留在 Godot scene，不進入視覺 mesh。

## 授權與素材聲明

R20 十位英雄的 mesh、材質、臉、服裝、道具、姿勢與渲染皆由 repo 內 `bpy` 程序自建；沒有引用 CC0、CC-BY 或其他外部角色模型，因此沒有第三方 mesh 改作項目。研究連結只作技法依據；Blender 手冊頁面標示 CC-BY-SA，Blender Studio／Blender Video 內容依各頁標示授權使用為學習參考。
