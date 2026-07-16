# cv art-r21 開源角色美術技法研究與落地

本輪不是再造程序化幾何，而是把 Hyper3D Rodin 的一體成形角色當可追溯模型底，進 Blender 做骨架、姿勢、燈光與 sprite 生產。研究基準採 Blender 官方手冊（文件 CC-BY-SA），實作則遵守專案 `AGENTS.md` 的逐幀動畫契約。

## 研究結論

1. **骨架與可視模型分離。** Blender 的 Armature modifier 以同名 vertex group 控制各骨骼對頂點的影響；權重通常應正規化為總和 1。R21 因此保留獨立 Armature root，不把 collider 或遊戲 physics root 烘進模型，也會在 automatic weights 後檢查沒有任何零權重頂點。[Blender Vertex Weights](https://docs.blender.org/manual/en/latest/modeling/meshes/properties/vertex_groups/vertex_weights.html)
2. **單幀姿勢必須由骨骼變形產生。** Blender Pose Mode 是相對 rest pose 編輯骨骼變形的正式途徑；pose asset 本質上是一幀 Action，可重複套用。R21 會以 18 骨規約建立可替換的 pose pipeline，逐格旋轉 pelvis/spine/四肢骨，不以整張 sprite 位移或縮放冒充動作。[Blender Posing Introduction](https://docs.blender.org/manual/en/4.5/animation/armatures/posing/introduction.html) · [Blender Pose Library](https://docs.blender.org/manual/en/latest/animation/armatures/posing/editing/pose_library.html)
3. **動作先讀剪影與節奏。** 64px 的 limb separation 比細碎表面更重要：walk 以左右腿與反向擺臂交替；attack 六格明確切成 anticipation（身體後收與武器蓄勢）、active impact（重心前壓、武器伸展）、recovery（收勢）；hurt 後仰，death 由失衡到倒地。每格由骨架 pose 輸出，傷害仍鎖 attack frame 2。
4. **AgX 要避免高曝光洗色。** AgX 提供寬動態範圍，也會在高曝光時自然降低飽和；因此沿用核准的暖 key／冷 fill／rim，但限制曝光與燈能，材質色票維持大色塊，輸出後再以雙閘門拒絕蒼白結果。[Blender Color Management](https://docs.blender.org/manual/en/latest/render/color_management.html)

## R21 實際套用

- Rodin 提示詞固定要求 `single seamless connected full-body`、A-pose、頭頸肩相連與雙腳落地，降低自動綁定時的漂浮部件風險。
- QC 不只數 object：逐 mesh 計算 loose component、各 component bbox／頂點數與整體腳底、頭部佔位；疑似頭或腳漂離主體就拒收並最多重生一次。
- 骨架採 `root/pelvis/spine/chest/neck/head`、左右 `upper_arm/forearm/hand/thigh/shin/foot` 共 18 骨；automatic weights 失敗時以最近骨段做可重建的 manual fallback，並記錄在報告。
- 正式 atlas 固定 512px 寬、64px cell、`idle4/walk8/attack6/hurt3/death6`；只覆寫十英雄的既有 cell，七種敵人列逐像素保留。
- 每位英雄在 native 64px 檢查身份剪影、臉／帽兜、主武器與色票；全圖再跑 `L=0.30–0.75`、平均飽和 `>=0.32`、低飽和 `<20%`。
