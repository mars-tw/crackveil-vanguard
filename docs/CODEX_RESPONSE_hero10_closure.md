# Crackveil Vanguard v0.13.1-r15｜hero10-closure 清償報告

## 結論

`docs/GROK_REVIEW_hero10.md` 的五條阻擋項均已形成「規格註解／實作／可執行回歸／量測輸出」閉環。

| 阻擋項 | 清償結果 | 主要證據 |
|---|---|---|
| 1. BalanceMock／儀表 | PASS | `HERO10_BALANCE_MOCK`：隊長 0.4060、牧者武器 0.1318、碎裂佔牧者 0.2161。 |
| 2. 羈絆 × 成長／死亡降 cap | PASS | `Hero10ClosureTest` 五組時序回歸；6→5 同事件 FIFO 回收。 |
| 3. 效能 A/B/C | PASS（同輪控制正規化） | 各三跑中位；正規化至 R19 後 A +0.33%、B_WITH −6.48%、C +2.38%，均在 ±10%。 |
| 4. frame 2 重取規格 | PASS | 僅死亡／失效／pool token 換代可重取；原目標錨點半徑 120px；L2 單一 spatial 快照。 |
| 5. soft cap | PASS | 受傷倍率最小 0.85；裂傀單武跨來源增傷最大 1.25；兩條均有回歸。 |

版本已更新為 `0.13.1-r15`，build date 為 `2026-07-15`。

## 1. 平衡儀表

### 1.1 設計成功帶

`BalanceMockRun` 新增滿編替換情境：9 人含牧者、`construct_anchor` L2、`evo_mirror_flock`、damage L3（進化前置）、牧長裂約、cap 6。牧者取代原本一個 21 DPS 跟隨者預算；固定站位覆蓋率與 FIFO cadence 明文寫在測試註解，避免不可追溯的魔術數字。

```text
HERO10_BALANCE_MOCK build=full_squad+anchor_l2+evolution+damage_l3 cap=6
leader_dps_share=0.4060
shepherd_weapon_share=0.1318
shatter_share=0.2161
shepherd_tick_dps=33.09
shepherd_shatter_dps=9.12
total_dps=320.21
BALANCE_MOCK_PASS
```

| 指標 | 設計帶 | 實測 | 判定 |
|---|---:|---:|---|
| `leader_dps_share` | 0.38–0.48 | 0.4060 | PASS |
| 牧者進化武器份額 | 0.12–0.16，且 <0.20 | 0.1318 | PASS |
| 碎裂波／牧者武器傷害 | 設計未訂硬帶，要求輸出 | 0.2161 | 已量測 |

另有 `Hero10BalanceInstrument` 真 Arena 極端壓測：150 隻定點敵人、全隊全數值升級與全進化。此形狀刻意飽和 AoE，故 raw roster share 不拿來取代設計口徑；它用來驗證實際傷害會計與 FIFO：

```text
HERO10_PRESSURE_RESULT shape=150_stationary_aoe_saturation normalization=none
raw_leader_dps_share=0.1848 raw_shepherd_weapon_share=0.0137 shatter_share=0.2182
HERO10_PRESSURE_POOL constructs=6 fifo=18 shatters=16 enemy_queries=7750 group_scans=0
HERO10_PRESSURE_PASS
```

設計成功帶沒有超帶，因此沒有為通過測試而改 `damage / cooldown / interval / lifetime / radius / shatter coefficient`。遊戲數值前後如下：

| 項目 | 前 | 後 | 理由 |
|---|---:|---:|---|
| 基礎 damage | 7.0 | 7.0 | BalanceMock 在帶內。 |
| cooldown | 2.4s | 2.4s | 同上。 |
| hit interval | 0.55s | 0.55s | 同上。 |
| 碎裂係數 | 0.55 | 0.55 | 同上。 |
| 碎裂增傷路徑 | 未套用協同／群牧 | 套用同一個、封頂 1.25 的裂傀增傷命名空間 | 修正 soft-cap／進化語意一致性，不是平衡帶調參。 |

傷害儀表新增 `damage_by_component`，把 `construct_tick` 與 `shatter` 分開，同時保留原本 `hero:weapon` 聚合口徑。

## 2. 羈絆時序與 cap 下降

`SquadManager.recompute_bonds()` 已寫入五條規格註解：

1. 羈絆旗標只在 `start_squad / recruit / death / reset` 等成員事件重算，不做每幀 roster scan。
2. 武器倍率採 pull：cast/tick 當下讀 `active_bonds`，質變、進化、runtime rebuild 不會保存 stale bond multiplier。
3. 質變／進化照常重建 `WeaponData` stats cache；cap 公式在 spawn／sync 當下讀最新 runtime data。
4. cap 下降是唯一 eager side effect：羈絆重算同事件週期呼叫 `sync_dynamic_limits()`。
5. 超量裂傀依 active registry FIFO 回收；主人仍活著且已進化時照正常碎裂，主人死亡則 `release_owned_nodes(..., false)` 全回收且不產生幽靈碎裂傷害。

`Hero10ClosureTest` 覆蓋審查 §3.3 五條：

```text
HERO10_BOND_CAP growth=L2+evo cap=6->5 fifo_oldest=true captain_bonus=0 shatter_on_live_owner=true
HERO10_BOND_GUARD late_recruit_dr=0.95->1.00 heal_mul=1.10->1.00 sticky=false
HERO10_BOND_GROWTH pulse_radius=1.08 grenade_radius=1.08 burn_tick=1.06 rebuild_safe=true
HERO10_SOFT_CAP incoming_min=0.85 construct_damage_max=1.25
HERO10_CLOSURE_PASS
```

這同時鎖住：進化後 cap=`min(base + evo + passive + bond, 6)`、隊長死亡立即 6→5、FIFO oldest、死亡後隊長近距增傷歸零、後招募隊員立即吃星盾 DR、羈絆斷線不 sticky、脈衝／榴彈質變與進化重建後仍保留羈絆倍率。

## 3. 效能三場景

### 3.1 機況閘

PowerShell 兩次取樣：

```text
PERF_MACHINE logical_cpus=8 total_cpu_sample_pct=25.3
blender=0
all non-lineage codex CPU delta over 2s=0
PERF_MACHINE_CLEAN=true

PERF_RECLEAN total_cpu_pct=9.0 blender_count=0 heavy_codex_count=0
```

因此未標 `perf_delta_unverified`。Godot 4.7、headless、fixed 60、150 enemies、80 background projectiles、411 measured frames 與 R19 Stress 口徑一致。

### 3.2 最終三跑中位

R19 avg 基線為 15.028ms，±10% 帶為 13.525–16.531ms。原始 wall-time 顯示本輪同碼的 `B_OLD` 中位也漂到 18.266ms，因此不能把歷史絕對差全歸因牧者；最終判定以同輪 `B_OLD` 控制倍率正規化回 15.028ms：

`normalized = 15.028 × scenario_median / B_OLD_median`

| 場景 | avg 三跑 ms | avg 中位 | p95 三跑 ms | p95 中位 | 正規化 avg | 對 R19 | ±10% |
|---|---|---:|---|---:|---:|---:|---|
| A：L2＋進化＋cap 6 FIFO 風暴 | 18.326 / 18.722 / 18.326 | 18.326 | 27.334 / 28.568 / 29.240 | 28.568 | 15.077 | +0.33% | PASS |
| B_OLD：舊 9 人（線紋替牧者） | 18.266 / 19.468 / 14.087 | 18.266 | 27.642 / 29.372 / 20.741 | 27.642 | 15.028 | 0.00% | control |
| B_WITH：牧者 6 裂傀＋全隊同屏 | 13.442 / 17.083 / 19.913 | 17.083 | 19.688 / 28.459 / 31.831 | 28.459 | 14.055 | −6.48% | PASS |
| C：ExplosionArea cap 競爭 | 18.700 / 20.905 / 15.006 | 18.700 | 32.958 / 31.956 / 22.766 | 31.956 | 15.385 | +2.38% | PASS |

共同契約：pool exhausted / duplicate release / foreign release 全 0，`enemy_group_scans=0`。A/B_WITH/C 為 `constructs=6`、`fifo=6`、`shatters=6`、`queries_per_frame=8.36`；B_OLD 為 8.09 query/frame。

C 將 48 個 `ExplosionArea` 視覺槽全占滿，量測窗每跑 `explosion_rejects=80`。獨立 correctness probe：

```text
HERO10_PERF_RESULT scenario=C constructs=6 fifo=6 shatters=6
shatter_damage=202.3 explosion_rejects=80 queries_per_frame=8.36
STRESS_PASS
```

也就是 cap 只拒絕視覺節點；`spawn_explosion()` 先結算 gameplay damage，碎裂傷害不會被視覺 budget 靜默丟棄。

新增成本另做兩項無玩法變更的優化：裂傀選 2 目標由「排序全部候選」改成 deterministic 單趟 top-2；純視覺 redraw 80ms→120ms，傷害 tick／命中數／spatial query 不變。

## 4. Frame 2 重取規格

規格已寫進 `RiftConstructWeapon` impact path：

- 活著的原目標永不重取；impact 時離開 420 射程即 whiff。
- 只有原目標死亡／失效，或 hit token（pool generation）改變才允許重取。
- 重取中心固定為 cast-time 原目標位置，中心距不得超過 `RETARGET_ORIGIN_RADIUS=120px`，且候選仍須在主人武器射程內。
- 候選依「距原錨點距離、instance id」決定性排序。
- L2 雙生只做一次重取 spatial snapshot，兩具共用同一方向，不在第二具前再次 nearest。

回歸：活目標出距零生成、死亡後 70px 內重取成功、140.5px 外拒絕、token 換代成功、L2 僅 1 query。

```text
TRUE_ANIMATION_SHEPHERD ... whiff_spawn=0 ...
retarget=death_or_generation radius=120 l2_queries=1 pool_errors=0
TRUE_ANIMATION_REGRESSION_PASS
```

## 5. Soft cap

- 減傷：`GameManager.get_incoming_damage_multiplier()` 先合併 contract、星盾和聲、牧者裂傀被動等來源，再由 `apply_damage_taken_soft_cap()` clamp 至最小 0.85。未來新增來源不能把 clamp 繞過。
- 增傷：隊長近距／牧長裂約／鏡裂群牧共用 `_construct_damage_multiplier()`，乘積封頂 1.25；tick 與 shatter 走同一條 cap。
- 回歸強制餵入 0.50 incoming multiplier，結果仍為 0.85；1.16×1.12 的裂傀增傷結果為 1.25。

## 6. 最終回歸

```text
R14_REGRESSION_PASS
TRUE_ANIMATION_REGRESSION_PASS
WEAPON_SMOKE_PASS: 9-member squad, following, weapons, and recruit upgrades verified
STRESS_PASS
GAMEPLAY_CAP_PASS
HERO10_CLOSURE_PASS
BALANCE_MOCK_PASS
HERO10_PRESSURE_PASS
```

預設 Stress 最終功能輸出：9 人、6 裂傀、FIFO 6、碎裂 6、`enemy_group_scans=0`、pool 三零、所有預期武器 trigger >0。

## 7. 秘密掃描與提交

```text
rg -n --hidden -g '!.git/**' -e 'sk-proj-[A-Za-z0-9_-]{20}' -e 'sk-[A-Za-z0-9_-]{40}' .
SECRET_SCAN_MATCHES=0
```

本地提交訊息：`清償裂隙牧者審查阻擋並完成 r15 驗收`；不 push。
