# Crackveil Vanguard — cv art-r20 角色美術總修報告

日期：2026-07-16

版本：`v0.15.0-r20`
最終用途：Blender 3D 生產來源 → 64px 角色格 → Godot 4.7 Web 2D 共用 sprite atlas

## 結果摘要

R20 已完成十英雄的 stylized low-poly 精品化重建、正／側／背三視圖、5 態逐幀圖集、亮度前置閘門、遊戲回歸、Web export 與線上實機驗收。遊戲仍是 2D；Blender 模型只作為可重建的 sprite 生產來源。

- 十英雄 idle 模型皆落在 3,956–5,152 tris，符合每角 3,000–6,000 tris。
- 約四頭身 heroic-chibi 比例；頭、眼、手、腳放大，肩寬腰窄，四肢使用圓切面 tapered forms，不再是方塊素體。
- 每角具眼白、虹膜、黑瞳、眉、鼻、嘴，並以髮型、帽／兜帽、披風、背包與武器建立可辨剪影。
- skin／cloth／leather／hair／metal／lens 分離材質；使用暖頂冷底的 mesh color ramp、24% AO 調制、faceted normals、AgX Base、暖 key／冷 fill／rim／bounce 與 `+0.85 EV`。
- 每個 64px cell 只擴張外輪廓 1px，不畫內部線，且不跨格污染相鄰動畫幀。
- 完全自建 `bpy` 幾何，未引用外部 CC0／CC-BY 模型或貼圖。

完整技法研究與原理見 [CG_ART_STUDY.md](CG_ART_STUDY.md)。本輪把姊妹專案 Storm R8 的色彩梯度、材質分離、AgX 與暖 key／冷 fill／rim 思路移植到此 repo，再依 64px sprite 的亮度閘門校準曝光。

## 動畫與可用性契約

共享圖集、角色排列、狀態與幀數維持不變：`idle 4 / walk 8 / attack 6 / hurt 3 / death 6`。走路幀由左右腿交替與反向擺臂構成；攻擊仍有 anticipation／active impact／recovery，命中固定在 attack frame 2；hurt 與 death 播放及回收規則未改。物理 root／collider 仍由 Godot 場景持有，視覺動畫只切換 atlas frame。

生產工具：

- `tools/generate_true_animation_atlas.py`：模型、材質、燈光、姿勢、圖集與獨立英雄 sprite。
- `tools/postprocess_character_atlas.py`：64px cell 內的 selective outline 後製。
- `tools/render_character_threeviews.py`：正交三視圖與 triangle manifest。
- `tools/build_art_r20_evidence.py`：三視圖標示、色票與 R16／R20 動作對照。
- `tools/check_sprite_luminance.py`：部署工作流在 Web export 前執行的亮度閘門。

## 十英雄造型決策

色票欄依序為「主色／副色／淺體塊／亮點」。所有角色另保留膚色、眼白與黑瞳作臉部辨識。

| 英雄 | Tris | 剪影、服裝與道具決策 | 四色色票 |
| --- | ---: | --- | --- |
| Captain | 4,176 | 寬肩短披風、長刃、雙肩甲；海軍指揮官輪廓 | `#143F6B / #1E94B8 / #8FC2D1 / #D97A1F` |
| Rift Sniper | 3,956 | 寬簷帽、單眼鏡、長槍；水平帽簷對比直立槍身 | `#293D66 / #2E8C94 / #A8C2C7 / #B8D938` |
| Void Weaver | 4,524 | 虛空長髮、面紗層、長杖；髮束與杖尖形成流動輪廓 | `#3D296B / #7A42A6 / #B885C7 / #33D1D9` |
| Arc Scout | 4,096 | 發光 visor、短圍巾、超長槍；前傾敏捷體態 | `#19594F / #24A37F / #8ACCAE / #D9611F` |
| Echo Singer | 4,792 | 頭側共鳴器、音叉杖、舞台式衣襬；金色聲學亮點 | `#5C3866 / #A3669E / #CCABC7 / #D9BA3D` |
| Ember Grenadier | 5,152 | 護目鏡、爆破背包、彈架、厚重發射器；最厚實上身 | `#663319 / #AD4C1F / #D19952 / #D9D15C` |
| Line Mender | 4,636 | 醫療兜帽、線軸、長針工具；淺色醫療體塊與金線亮點 | `#2E5766 / #4CA39E / #B8CCB3 / #D9A333` |
| Orbit Guard | 4,520 | 防護頭盔、盾牌、軌道刃；圓盾對比尖刃 | `#3D3366 / #6B57A6 / #B8A3D1 / #38D1D9` |
| Pulse Artificer | 4,308 | 工具背包、護目鏡、手砲；工匠裝備集中於背與手 | `#2B4F6B / #3B94AD / #9EC2D1 / #D96152` |
| Shepherd | 4,236 | 深兜帽、分層披風、籠燈；冷白燈籠作唯一高亮焦點 | `#382E6B / #5999A6 / #A6C2D1 / #C7D9D9` |

## 三視圖與 before／after

每張三視圖皆用正交相機、同尺度、非黑影的正／側／背模型審查：

- [Captain](evidence/art_r20/threeview/hero_captain.png)、[Rift Sniper](evidence/art_r20/threeview/hero_rift_sniper.png)、[Void Weaver](evidence/art_r20/threeview/hero_void_weaver.png)、[Arc Scout](evidence/art_r20/threeview/hero_arc_scout.png)、[Echo Singer](evidence/art_r20/threeview/hero_echo_singer.png)
- [Ember Grenadier](evidence/art_r20/threeview/hero_ember_grenadier.png)、[Line Mender](evidence/art_r20/threeview/hero_line_mender.png)、[Orbit Guard](evidence/art_r20/threeview/hero_orbit_guard.png)、[Pulse Artificer](evidence/art_r20/threeview/hero_pulse_artificer.png)、[Shepherd](evidence/art_r20/threeview/hero_shepherd.png)

十英雄 R16／R20 的 native 64px idle、walk、attack impact frame 2 並排總覽：[all_heroes_r16_vs_r20.png](evidence/art_r20/before_after/all_heroes_r16_vs_r20.png)。個別對照位於 `docs/evidence/art_r20/before_after/`，R16 原始基線位於 `docs/evidence/art_r20/before/`。

## 亮度閘門

規格：每角色格所有不透明像素的平均亮度 `0.30–0.80`，近黑像素比例 `<35%`。最終 atlas 十英雄全部通過；完整 JSON（含七種敵人）見 [luminance_r20.json](evidence/art_r20/luminance_r20.json)，總計 17/17 PASS。

| 英雄 | 平均亮度 | 近黑比例 | 結果 |
| --- | ---: | ---: | --- |
| Captain | 0.4382 | 23.62% | PASS |
| Rift Sniper | 0.4368 | 23.88% | PASS |
| Void Weaver | 0.4277 | 24.93% | PASS |
| Arc Scout | 0.4280 | 26.72% | PASS |
| Echo Singer | 0.4596 | 22.86% | PASS |
| Ember Grenadier | 0.4302 | 23.08% | PASS |
| Line Mender | 0.4770 | 25.82% | PASS |
| Orbit Guard | 0.4574 | 22.44% | PASS |
| Pulse Artificer | 0.4536 | 24.00% | PASS |
| Shepherd | 0.4638 | 21.54% | PASS |

## 回歸測試輸出

`TrueAnimationRegressionTest`，headless exit `0`：

```text
TRUE_ANIMATION_PLAYER heroes=10 unique_cells=10 hero=rift_shepherd poses=4/8/6/3/6 impact_frame=2 duplicate_hits=0 shared_atlas=-9223371953002248598
TRUE_ANIMATION_SHEPHERD impact_spawn=frame2 anticipation_spawn=0 whiff_damage=0 whiff_spawn=0 recovery=full cap=6 retarget=death_or_generation radius=120 l2_queries=1 pool_errors=0
TRUE_ANIMATION_ENEMY impact_delayed=true whiff_damage=0 hurt_knockback=true death_delayed=true lod=6/3/1.5/freeze shared_ticker=true
TRUE_ANIMATION_REGRESSION_PASS
TRUE_ANIMATION_EXIT=0
```

`R14RegressionTest`，headless exit `0`：

```text
R19_FORMFACTOR phone=touch tablet=touch coarse_desktop=touch fine_desktop=desktop fail_closed=true seed_max=400
BONDS_ACTIVE=["bond_ember_pulse", "bond_void_rail", "bond_guard_echo", "bond_captain_shepherd"]
BONDS_ACTIVE=["bond_ember_pulse", "bond_void_rail", "bond_guard_echo", "bond_captain_shepherd"]
R14_HERO10 roster=10/9 weapons=11 construct_cap=6 targets=2 bonds=4 impact=frame2
R14_MOBILE_UI portrait_scale=1.96 landscape_scale=1.86 font=39 touch=76.0
R19_CONTROLS_REACHABILITY viewports=1920x1080,1440x780,1366x600,1280x640,390x844 rect=inside hit>=44 canvas=internal
R14_CAMERA desktop=1.28 mobile=1.56 threat=1.36
R14_BACKGROUND interval=88.98 sig_len=41
SCREENSHOT_BEAUTY_ON hud_hidden=true vfx_layers=4
SCREENSHOT_BEAUTY_OFF hud_hidden=false vfx_layers=adaptive
R14_PRESS_CAPTURE phase_banner=heat_red adaptive_layers=3 beauty_layers=4
R14_REGRESSION_PASS
R14_EXIT=0
```

## Web export 與實機

Godot 4.7 `--headless --export-release Web export/web/index.html` exit `0`。主要產物：`index.html` 6,352 bytes、`index.js` 279,815 bytes、`index.pck` 6,543,276 bytes、`index.wasm` 39,509,339 bytes。瀏覽器實際載入、以固定種子 `3` 進入「裂隙虛空」並持續戰鬥成功；既有場景 UID 警告皆由 Godot 自動改走文字路徑，未造成載入或戰鬥失敗。

- [R20 Web 主選單](evidence/art_r20/web_menu_r20.png)
- [R20 深藍裂隙線上戰鬥](evidence/art_r20/web_battle_r20.png)
- [最終共用 atlas](../assets/sprites/true_character_atlas.png)

## 驗收結論

R20 已把角色從 R16 的低解析方塊感，提升為具有臉部、曲面體塊、表面材質差異、角色道具與乾淨外輪廓的可辨 64px sprite；同時保留所有可動與命中契約、通過亮度 gate、兩套 headless 回歸與 Web export。三視圖、before／after 與深藍場景實機證據均已納入 `docs/evidence/art_r20/`。
