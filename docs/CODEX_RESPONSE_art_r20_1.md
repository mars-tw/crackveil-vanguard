# Crackveil Vanguard — cv art-r20.1 角色渲染色彩修正報告

日期：2026-07-16
版本：`0.15.1-r20.1`

## 結論

R20.1 僅修正 Blender atlas 的打光、色彩管理、材質色彩反應與部署前閘門。十英雄與七種敵人的模型幾何、三視圖、輪廓、道具、臉部、骨架式分件姿勢，以及 `idle 4 / walk 8 / attack 6 / hurt 3 / death 6`、attack frame 2 命中契約均未變更。

正式重建後，十英雄可見像素加權平均為：

- 平均亮度 `0.3585`；近黑 `24.30%`。
- 平均 HSV 飽和度 `0.4288`；低飽和像素（`S < 0.15`）`10.80%`。
- 17 個 atlas 角色全部通過亮度＋飽和度雙閘門。

## 去飽和根因

R20 的色票本身仍在 source palette 中，但正式 sprite 同時承受：

1. 四盞 Sun 的總能量為 `6.98`（key `2.85`、fill `1.25`、rim `2.20`、bounce `0.68`），世界光強度另為 `0.46`。
2. AgX Base 再加 `+0.85 EV`，把大面積 skin、secondary cloth 與 metal 中間調推進高光 roll-off；AgX 在該區域會壓縮色度，因此 64px 下採樣後變成近白色塊。
3. R20 部署前只量亮度與近黑比例。它能證明「不暗」，卻不能拒絕「亮但沒有顏色」的 sprite。

依本輪統一採用的可見像素 HSV 算法，舊 R20 十英雄加權數據為 `L=0.4475 / S=0.3225 / 低飽和=28.96%`；十英雄僅 Captain 與 Void Weaver 通過新閘門。這與實機看到的蒼白結果一致。

Selective outline 只寫入每格輪廓外側透明像素，沒有覆寫內部臉部、服裝或道具顏色，因此不是蒼白來源。

## 修法

正式生成器 `tools/generate_true_animation_atlas.py` 固化以下校正：

- view transform 由 `AgX / Base / +0.85 EV` 改為 `Standard / None / +1.30 EV`。曝光只在降低燈能量後恢復顯示亮度，不再先把中間調沖進高光壓縮區。
- 世界光由 `0.46` 降為 `0.18`；key / fill / rim / bounce 降為 `1.10 / 0.38 / 0.75 / 0.20`，總 Sun 能量由 `6.98` 降到 `2.43`。
- 保留 R20 的暖 key、冷 fill、冷 rim 方向與 roughness / metallic 分工；僅在 baked vertex ramp 上依表面做輕度 chroma 補償：skin `1.12`、cloth `1.28`、leather `1.32`、hair `1.28`、metal `1.25`、lens `1.18`。
- Line Mender 的淺 mint secondary 是唯一仍產生大面積 `S < 0.15` 的材質槽，因此只對該 secondary cloth / metal 再乘 `1.75`。此處只改頂點色彩，不改 mesh、材質種類或三視圖幾何。
- 未加入整張 atlas 的重手濾鏡；臉部、道具、體塊明暗與 selective silhouette outline 都由正式渲染結果保留。

## 亮度＋飽和度雙閘門

`tools/check_sprite_luminance.py` 現在逐一統計每個角色五組動畫的所有 `alpha > 8` 像素，任一條不符即 exit 1：

- 平均亮度 `0.30–0.75`。
- `L < 0.10` 的近黑比例 `<35%`。
- 平均 HSV 飽和度 `>=0.32`。
- `S < 0.15` 的低飽和比例 `<20%`。

`.github/workflows/deploy-web.yml` 已在 Web export 前執行這個雙閘門。完整機器可讀資料：[color_metrics_r20_1.json](evidence/art_r20_1/color_metrics_r20_1.json)。

| 角色 | 平均 L | 近黑 | 平均 S | 低飽和 | 結果 |
| --- | ---: | ---: | ---: | ---: | --- |
| Captain | 0.3417 | 24.16% | 0.5226 | 9.97% | PASS |
| Rift Sniper | 0.3408 | 24.43% | 0.4506 | 9.96% | PASS |
| Void Weaver | 0.3377 | 25.35% | 0.4506 | 5.25% | PASS |
| Arc Scout | 0.3440 | 27.24% | 0.5097 | 7.63% | PASS |
| Echo Singer | 0.3720 | 23.25% | 0.3601 | 14.22% | PASS |
| Ember Grenadier | 0.3425 | 23.44% | 0.4080 | 9.16% | PASS |
| Line Mender | 0.4034 | 26.13% | 0.3869 | 17.27% | PASS |
| Orbit Guard | 0.3668 | 22.80% | 0.3839 | 11.96% | PASS |
| Pulse Artificer | 0.3620 | 24.36% | 0.4389 | 9.00% | PASS |
| Rift Shepherd | 0.3724 | 22.30% | 0.3887 | 13.18% | PASS |
| Enemy Grunt | 0.3019 | 28.02% | 0.4011 | 5.61% | PASS |
| Enemy Fast | 0.3084 | 28.93% | 0.5070 | 0.60% | PASS |
| Enemy Tank | 0.3364 | 23.73% | 0.4234 | 10.00% | PASS |
| Enemy Elite Field | 0.3329 | 25.46% | 0.4595 | 0.55% | PASS |
| Enemy Elite Split | 0.3094 | 26.80% | 0.4309 | 0.73% | PASS |
| Enemy Elite Swift | 0.3621 | 29.03% | 0.5363 | 4.90% | PASS |
| Enemy Boss | 0.3223 | 20.01% | 0.4729 | 0.45% | PASS |

全 atlas 加權總計為 `L=0.3452 / S=0.4414 / 低飽和=7.79%`。

## Before / After 與實機證據

- [十英雄 R20 蒼白版 vs R20.1 鮮明版](evidence/art_r20_1/before_after/all_heroes_r20_vs_r20_1.png)：每位英雄並排顯示 native 64px idle、walk 與 attack impact frame 2，並附各自 L / S 數據。
- [R20.1 Web 深藍裂隙實機戰鬥](evidence/art_r20_1/web_battle_r20_1.png)：正式 Web export、1280×720、seed 6、戰鬥第 10 秒；64px 隊長藍、護衛紫與斥候綠可在深藍戰場辨識，臉與道具仍可見。
- 舊 R20 atlas 與舊實機畫面保存於 `docs/evidence/art_r20_1/before/`，可重跑相同量測。

三視圖未重渲染、未修改；R20 已核准的 3D 造型與幾何完整保留。正式重建再次輸出相同的十英雄 idle triangle budget（`3,956–5,152 tris`）。

## 回歸、匯出與範圍

- `TrueAnimationRegressionTest`：exit `0`，`TRUE_ANIMATION_REGRESSION_PASS`；`heroes=10`、`poses=4/8/6/3/6`、`impact_frame=2`、hurt/death 延遲與 hitbox 契約均通過。
- `R14RegressionTest`：exit `0`，`R14_REGRESSION_PASS`；版本鎖更新為 `0.15.1-r20.1`。
- Godot 4.7 Web export：exit `0`；`index.html 6,352`、`index.js 279,815`、`index.pck 6,599,948`、`index.wasm 39,509,339` bytes。
- 正式 Web build 已在 in-app browser 走完主選單、契約與裂隙虛空戰鬥流程並擷取證據。
- 秘密掃描排除 `.git` 與既有二進位資產後零命中。
- 本輪沒有 push；僅建立繁中訊息的本地 commit。
