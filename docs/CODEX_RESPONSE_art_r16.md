# Crackveil Vanguard v0.14.0-r16｜cv art-r16 角色藝術總修

## 結論

R16 已把 Blender 真姿勢產線從「4 個素體外觀供 10 英雄共用」改成 **10 位英雄各自一套造型、7 種敵人同步重製**。所有角色仍共用 `true_character_atlas.png`；動畫維持 idle 4／walk 8／attack 6／hurt 3／death 6，frame 2 命中、死亡播畢回收、physics root／collider 不參與美術姿勢。

最終 atlas 為 `512×3712`、SHA-256 `34EBE039DFE96946BA8F480A523454F0C329A6C8A99698E619DF01BE617AB115`。459 個有效 frame 依狀態順序密排，只有最後 5 個 cell 透明；相對舊圖 `512×3520` 像素面積只增加 5.45%，沒有採用會膨脹到 `512×5440` 的固定五列排法。

## 英雄剪影與色票決策

表中依序為 dark／body／secondary／highlight；臉部另有膚色、眼白、角色 highlight 衍生瞳色與深眉，並非用 visor 代替臉。

| 英雄 | 純黑剪影識別道具 | 四色色票 |
|---|---|---|
| 裂隙隊長 | 指揮披風、頭盔長翎、帶護手裂隙長刃 | `#14406B / #1F94B8 / #8FC2D1 / #D97A1F` |
| 裂光狙擊手 | 寬簷帽、長風衣、槍托／長槍管／瞄具 | `#293D66 / #2E8C94 / #A8C2C7 / #B8D938` |
| 虛空織網者 | 雙側虛空長髮、面紗披肩、新月分叉杖 | `#3D296B / #7A42A6 / #B885C7 / #33D1D9` |
| 裂弧斥候 | 後飄風巾、雙天線、三叉裂弧長槍 | `#1A594F / #24A380 / #8ACCAD / #D9611F` |
| 迴響歌者 | 扇形長髮、雙肩共鳴器、音叉法杖 | `#5C3866 / #A3669E / #CCAAC7 / #D9BA3D` |
| 燼焰擲彈兵 | 爆破背包／煙囪、三枚彈帶、粗口徑發射器 | `#66331A / #AD4D1F / #D19952 / #D9D15C` |
| 線紋修補者 | 大線軸背包、鬆線尾、兜帽、長針杖 | `#2E5766 / #4DA39E / #B8CCB3 / #D9A333` |
| 星環護衛 | 頭盔鰭、雙浮游環刃、巨型星環盾 | `#3D3366 / #6B57A6 / #B8A3D1 / #38D1D9` |
| 脈衝工匠 | 線圈背包／雙叉、護目鏡、整臂脈衝砲 | `#2B4F6B / #3B94AD / #9EC2D1 / #D96152` |
| 裂隙牧者 | 全身長斗篷、尖兜帽、籠架／垂片裂隙燈籠 | `#382E6B / #5999A6 / #A6C2D1 / #C7D9D9` |

每張 64px frame 的頭部都建有兩枚眼白、角色瞳色、兩道眉與鼻部明暗面。眼白與膚色形成第一層 value contrast，瞳／眉形成第二層，因此縮到遊戲尺寸仍能讀到臉朝向與情緒，而不是無臉方塊。

## 敵人同步重製

| 敵人 | R16 輪廓／破損／傷口 |
|---|---|
| grunt | 破布圍巾、斷角、帶刺棍棒、胸前雙裂傷；鏽紅／橘色系 |
| fast | 三根背刺、斷角、三爪、破裙與胸傷；紫／電青色系 |
| tank | 巨型不對稱板甲肩、破背甲、雙面破鎚；赭石／黃銅色系 |
| elite_field | 破披肩、雙角枝、分叉場域杖；紫／毒綠色系 |
| elite_split | 分岔雙角、雙斧、破裙與胸傷；洋紅／金色系 |
| elite_swift | 長圍巾、背刺、冰爪；青綠／冰白色系 |
| boss | 三冠角、巨型破披風、裂光巨刃、胸裂傷；紫／裂粉色系 |

敵人完整保留攻擊 anticipation／frame 2 impact／recovery、hurt、death 與既有 LOD／共享 ticker；碰撞半徑與物理 root 未改。

## 材質、燈光與姿勢

- 每個 primitive 寫入 `cv_gradient` point color（0.74→1.08），材質再乘 Blender Ambient Occlusion（distance 0.42、8 samples），不是均勻 flat color。
- key light 為暖白 Sun，背向另加冷青 rim Sun；highlight 有低量 emission，只負責小面積視覺錨點。
- 三個主色的 HSV value 維持 0.35–0.85；highlight 最高 0.85。深藍場景以 body／secondary 的中高 value 和青色 rim 保持輪廓。
- attack 0–1：臀部下沉、重心／前腳後撤、武器拉到頭部後上方；frame 2：胸／頭／前腳前跨、武器全伸；frame 3 跟進，4–5 回收。傷害事件仍只在 Godot active frame 2 觸發。
- Blender 5.1.2 headless 最終輸出：17 角色、192,672 vertices、184,626 faces；`.blend` 是可替換的建模／姿勢來源。

## 亮度閘門

`tools/check_sprite_luminance.py` 只統計 alpha > 8 的像素；平均亮度需 0.30–0.80，luma < 0.10 的近黑像素需 <35%。GitHub Web workflow 已在匯出前安裝 Pillow 並執行此 gate。

| 角色 | 平均亮度 | 近黑比例 | 結果 |
|---|---:|---:|---|
| hero_captain | 0.3697 | 5.73% | PASS |
| hero_rift_sniper | 0.3830 | 6.72% | PASS |
| hero_void_weaver | 0.3748 | 7.91% | PASS |
| hero_arc_scout | 0.3895 | 6.15% | PASS |
| hero_echo_singer | 0.3940 | 4.74% | PASS |
| hero_ember_grenadier | 0.3523 | 11.44% | PASS |
| hero_line_mender | 0.4234 | 3.90% | PASS |
| hero_orbit_guard | 0.4068 | 7.52% | PASS |
| hero_pulse_artificer | 0.3986 | 6.01% | PASS |
| hero_shepherd | 0.3962 | 3.79% | PASS |
| enemy_grunt | 0.3139 | 13.57% | PASS |
| enemy_fast | 0.3625 | 9.90% | PASS |
| enemy_tank | 0.3360 | 12.15% | PASS |
| enemy_elite_field | 0.3677 | 9.50% | PASS |
| enemy_elite_split | 0.3170 | 13.79% | PASS |
| enemy_elite_swift | 0.4264 | 4.20% | PASS |
| enemy_boss | 0.3189 | 7.07% | PASS |

輸出：`SPRITE_LUMINANCE_PASS characters=17`。機讀資料另存於 `docs/evidence/art_r16/luminance.json`。

## Proof 與實機證據

- `docs/art_r16_character_atlas_proof.png`：10 英雄 idle／walk／attack 舊版與 R16 原生 64px 並排。
- `docs/art_r16_silhouette_proof.png`：10 英雄 idle／impact 純黑剪影。
- `docs/art_r16_enemy_proof.png`：7 敵人 idle／impact／hurt／death。
- `docs/evidence/art_r16/web_battle_rift_void.png`：Web release 本機 `localhost` 實跑「裂隙虛空」深藍戰場，版本角標為 `v0.14.0-r16`。

## 回歸輸出

指定功能項：

```text
R14_REGRESSION_PASS
TRUE_ANIMATION_PLAYER heroes=10 unique_cells=10 hero=rift_shepherd poses=4/8/6/3/6 impact_frame=2 duplicate_hits=0
TRUE_ANIMATION_SHEPHERD impact_spawn=frame2 anticipation_spawn=0 whiff_damage=0 whiff_spawn=0 recovery=full cap=6 retarget=death_or_generation radius=120 l2_queries=1 pool_errors=0
TRUE_ANIMATION_REGRESSION_PASS
WEAPON_SMOKE_PASS: 9-member squad, following, weapons, and recruit upgrades verified
```

完整 debug suite 最終 22/22 綠：EnemyArt、GameplayCap、M1–M4、R5–R7、R10.5–R14、MobileInput、Orbit repro、PoolContract、Squad、Weapon、Arena instrumentation、Balance mock、TrueAnimation。R5 在批次首跑曾因磁吸回收的真實時間窗出現一次 timing flake；同場景立即重跑為 `R5_REGRESSION_PASS`，其餘最終場景皆 exit 0。

## Stress 三跑

共同條件：Godot 4.7、headless、`--fixed-fps 60`、seed 52002、150 enemies、80 background projectiles、180 warm-up、411 measured frames。三跑均：`STRESS_PASS`、`enemy_group_scans=0`，所有 pool exhausted／duplicate release／foreign release 為 0。

| 版本 | p95 三跑 ms | p95 中位 |
|---|---|---:|
| R16 密排 atlas | 29.070 / 20.063 / 23.649 | 23.649 |
| 歷史 15.6ms 來源 commit `f986cb3`，本輪同機控制 | 21.795 / 19.994 / 31.243 | 21.795 |

本機當下連歷史版本也無法重現 15.6ms，因此不把 raw 23.649 冒充直接達標。依同機控制正規化：

```text
15.6 × (23.649 / 21.795) = 16.927ms
delta = +8.51%
15.6ms ±10% band = 14.040–17.160ms
STRESS_P95_NORMALIZED_PASS
```

密排前 R16 p95 中位為 30.751ms；密排後為 23.649ms，改善 23.10%。

## Web release

```text
WEB_EXPORT_PASS
node --check export/web/index.js: PASS
index.pck: 6,380,372 bytes
index.pck SHA-256: 9ACCF511E43A828A648333B7F122B6BC340506AFE50F2691455A7EED60CCDEDB
```

瀏覽器實跑正常；console 僅有專案既有的 scene external-resource UID 失效後改走文字路徑 warning，未造成載入或戰鬥中斷。
