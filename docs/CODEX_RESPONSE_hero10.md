# Crackveil Vanguard v0.13.0-r14｜第 10 英雄實作報告

## 交付結果

- 新英雄 `rift_shepherd`（裂隙牧者）已加入名冊；名冊為 10、單局上限維持 9、起始三人不變。
- 新武器 `rift_constructs`（裂傀編制）已加入第 11 把武器與升級池，含 `construct_anchor` 兩級質變及 `evo_mirror_flock` 進化。
- 裂傀是固定站位、可回收的獨立 NodePool 實體；只透過 EnemySpatialIndex 局部查詢，單次最多 2 目標，全域上限 6，無 steering、pathfinding、heroes group 或拾取能力。
- 牧者被動、隊長近距供能、星環攻速互動與四組 Bond Lite 均已接通；羈絆在招募／死亡事件重算並顯示於 HUD。
- 版本已更新為 `0.13.0-r14`，Web release export 成功。

## 設計案對照與取捨

| 項目 | 實作 | 與設計案的差異／理由 |
|---|---|---|
| 英雄數值 | HP 96、速度 218、碰撞 12、拾取 74 | 完全依設計案。 |
| 武器基值 | damage 7、CD 2.4、range 420、offset 72、radius 54、interval 0.55、lifetime 5.5、base cap 3 | 完全依設計案。 |
| 上限／pool | 每 tick 2 目標、全域 cap 6、prewarm 10、超額 FIFO | 完全依設計案並沿用現有 EntityFactory／NodePool 契約。 |
| 一般「數量」升級 | 對裂傀映射為 lifetime +0.4 秒 | 現有系統的 `weapon_projectiles` 是共用升級鍵；依設計紅線寫死語意映射，避免把召喚數堆到 20。 |
| 進化碎裂波 | 復用現有 pooled ExplosionArea | 依設計優先使用既有爆炸 cap，不另造子投射物或第二次召喚。 |
| 專屬美術 | 新增獨特燈籠／肩部剪影及完整真姿勢 atlas | 設計案把專屬 PNG 列為可選，但本任務的 AGENTS 鐵律要求真姿勢產線，因此採更高規格實作。 |
| frame 2 目標重驗 | 活目標離開射程仍揮空；若原目標已死亡或 pool token 換代，僅在 frame 2 透過 spatial index 重取目標 | 滿編時其他隊員常在兩個預備幀內擊殺鎖定目標；此取捨維持「只在命中幀生效」及真正揮空零生成，同時避免召喚武器在滿編永久失效。 |
| 壓測九人名單 | 以牧者替換線紋修補者 | 現況 `max_members=9`，依設計的 10 選 9 與 Stress 建議情境取捨，不擴滿編上限。 |
| 文件資產 | `docs/.gdignore` 排除 QA 圖 | `export_filter=all_resources` 會把證據截圖誤包進 PCK；文件仍保留於 repo，但不成為 runtime 資源。 |

## 真姿勢動畫證據

`tools/generate_true_animation_atlas.py` 已擴充 `hero_shepherd`：角色由腿、手、身體、肩部與多部件裂隙燈籠組成，每幀直接改變關節姿勢與武器部件位置。五態為 idle 4／walk 8／attack 6／hurt 3／death 6；角色的物理 root／collider 未參與視覺姿勢變形。

![裂隙牧者五態逐幀姿勢證據](hero10_true_animation_proof.png)

Blender 5.1 產線輸出：

```text
TRUE_ANIMATION_GEOMETRY hero_shepherd
TRUE_ANIMATION_MESH vertices=78300 faces=69228
TRUE_ANIMATION_ATLAS assets/sprites/true_character_atlas.png 512x3520
TRUE_ANIMATION_REFERENCE assets/sprites/hero_shepherd.png 64x64
```

攻擊時序：frame 0–1 抬燈籠蓄力；frame 2 前踏並伸出燈籠，發出唯一 `attack_impact`；frame 3 為主動姿勢延續；frame 4–5 收回。武器只在 `attack_impact` 重驗目標並投放，輸入／預備幀不投放、不傷害；揮空仍播放全部 recovery。

## Headless 測試輸出

### R14RegressionTest

```text
R14_FORMFACTOR phone=phone tablet=tablet touch_desktop=desktop desktop=desktop seed_max=400
R14_HERO10 roster=10/9 weapons=11 construct_cap=6 targets=2 bonds=4 impact=frame2
R14_MOBILE_UI portrait_scale=1.96 landscape_scale=1.86 font=39 touch=76.0
R14_CAMERA desktop=1.28 mobile=1.56 threat=1.36
R14_BACKGROUND interval=88.98 sig_len=41
R14_PRESS_CAPTURE phase_banner=heat_red adaptive_layers=3 beauty_layers=4
R14_REGRESSION_PASS
exit 0
```

### TrueAnimationRegressionTest

```text
TRUE_ANIMATION_PLAYER hero=rift_shepherd poses=4/8/6/3/6 impact_frame=2 duplicate_hits=0 shared_atlas=-9223371955887929764
TRUE_ANIMATION_SHEPHERD impact_spawn=frame2 anticipation_spawn=0 whiff_damage=0 whiff_spawn=0 recovery=full cap=6 pool_errors=0
TRUE_ANIMATION_ENEMY impact_delayed=true whiff_damage=0 hurt_knockback=true death_delayed=true lod=6/3/1.5/freeze shared_ticker=true
TRUE_ANIMATION_REGRESSION_PASS
exit 0
```

### 補充回歸

```text
WEAPON_SMOKE_COUNTS={...,"rift_shepherd:rift_constructs":5,...}
WEAPON_SMOKE_PASS: 9-member squad, following, weapons, and recruit upgrades verified
exit 0

STRESS_WEAPON_TRIGGERS={...,"rift_shepherd:rift_constructs":4,...}
STRESS_SHEPHERD_DEBUG={"cancellations":0,"casts":4,"impacts":4,"rejections":0,"whiffs":0,...}
STRESS_COUNTERS enemy_spatial_queries=3388 queries_per_frame=8.24 enemy_group_scans=0 group_scans_per_frame=0.000 kills=714 gold=756 xp=816
STRESS_PASS
exit 0
```

Stress 的功能與 pool 契約通過，裂傀 live=6，`exhausted / duplicate_releases / foreign_releases` 均為 0。本次主機當下鎖在約 1.05 GHz 且有其他前景負載，wall-time 效能數字不可與 R19 的 15.028 ms 基線直接比較；同次 A/B 切回舊英雄甚至超過 120 秒未完成，因此未把該次數字當成牧者效能結論。

## Web 匯出

```text
WEB_EXPORT_EXIT=0
WEB_PCK_BASELINE=5665976
WEB_PCK_FINAL=5766808
WEB_PCK_DELTA=100832
WEB_PCK_SHA256=A617195BB4651267301F78E2EB47C9C30A30E029FBE16E013ED18810852B6C4C
```

PCK 增量 100,832 bytes，低於設計案 150 KB 目標。

## 掃描與提交

```text
grep -rniE "sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}" --exclude-dir=.git .
SECRET_SCAN_MATCHES=0
grep exit 1（零命中）

grep -rniE "v?0\\.12\\.1-r13" --exclude-dir=.git .
OLD_VERSION_MATCHES=0
grep exit 1（零命中）
```

本地提交訊息：`實作第十英雄裂隙牧者與真姿勢動畫`；未 push。
