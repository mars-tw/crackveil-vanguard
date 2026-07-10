# CODEX_RESPONSE_R11_debate

日期：2026-07-10  
對象：`docs/GROK_REVIEW_R11.md`  
狀態：不 commit、不 push。Grok 的「軟 Go」成立；本輪修正 P1/P2 可落地項，未把 BalanceMock 當平衡通過證據。

## 逐條辯論

| Grok 指控 | 我的立場 | 證據 / 修法 |
|---|---|---|
| N1：`evo_razor_bulwark` pierce 在 `weapon_data.gd` 與 `boomerang_weapon.gd` 雙加，實際 +4。 | 同意修正。 | 移除 `boomerang_weapon.gd` 開火路徑的 evo `+2`，保留 `WeaponData._apply_evolution()` 作為進化 pierce 單一來源；`boomerang_rebound` 仍可另外提供返刃穿透。R11 回歸鎖定 `pierce=7`（基礎 3 + evo 2 + rebound 2），舊路徑會變 9。 |
| N7：`evo_hunter_swarm` turn_rate 在資料層 +2.2 後開火再 +1.4。 | 同意修正。 | 移除 `homing_missile_weapon.gd` evolved 分支的 `+1.4`。現在 turn rate = 資料層進化後 `5.8+2.2` + `missile_guidance` 兩級 `2.2`，R11 回歸輸出 `turn_rate=10.20`。 |
| 進化文案承諾「易傷」但未實作。 | 同意，採「改文案」而非臨時補效果。 | `evo_razor_bulwark` 描述改為「返場時重置命中表，刃體加寬，穿透與航程提升」。未新增 `vulnerable`，避免把未平衡狀態硬塞進 projectile 熱路徑。星環共鳴的易傷仍存在於 `orbit_projectile.gd`，不受影響。 |
| 基礎迴旋鏢 / 剃界盾輪文案超賣。 | 同意修正。 | `rift_shield_boomerang.tres` 改成「返場可掃過尚未被它命中的敵人」，不再暗示基礎同目標二次命中；boomerang 數值卡文案改為一般穿透與射程；`missile_guidance` 文案改為提高重取頻率與鎖定距離。 |
| Boomerang 命中表：基礎武器不會同目標返場再傷，rebound/evo 才清表。 | 部分同意，行為保留、文案修正、回歸補上。 | 新增 R11 回歸 `R11_BOOMERANG_HIT_TABLE base_second_blocked=true rebound_return_hit=true`：基礎第二次同目標被擋；`boomerang_rebound` 進入返場後清表並可再傷。spawn token 契約仍成立。 |
| 升級池被隊長三武器佔領，招募 / 隊員卡被稀釋。 | 部分同意。反駁「永遠選不到」，同意「三選滿隊長卡」體感有風險。 | 在 `GameManager._pick_upgrade_choices()` 加健康守門：當選項數 >= 3、抽出結果全是隊長武器卡、且池內仍有非隊長卡時，用加權抽一張非隊長卡替換一張隊長卡。新增 R11 回歸用極端權重驗證 `nonleader_three_choice_guard=true`。 |
| BalanceMock 是自嗨曲線，不能當平衡通過依據。 | 同意。 | `BalanceMockRun` 新增輸出 `BALANCE_MOCK_NOTE trend_only=true arena_instrumentation_required=true`。它仍可看趨勢，但不再作為平衡結論。 |
| pierce / turn_rate 修正後要用可信方法重驗新武器 DPS。 | 同意並實作 Arena 插樁。 | 新增 `scripts/debug/arena_instrumentation_run.gd` / `scenes/debug/ArenaInstrumentationRun.tscn`：真實 `Arena.tscn`、固定 seed、強制兩把新武器進化、headless 跑 12 秒，記錄實際命中傷害到 `hero:weapon` DPS。最後一次輸出：`total_damage=817.3`，`arc_scout:rift_seeker_missiles=37.49 DPS`，`orbit_guard:rift_shield_boomerang=4.96 DPS`，`enemy_group_scans=0`。 |
| Homing 在 150 敵會有找最近與效能風險。 | 反駁主幹，接受文案精度修正。 | Homing 仍走 `EntityFactory.find_nearest_enemy()` / spatial index，重取間隔 0.1s，guidance 後 0.07s；非每幀全掃 group。Stress 最後一次：150 enemies、100 projectiles、avg 7.031ms、p95 14.828ms、`STRESS_PASS`。 |
| `missile_guidance` Lv2「短距再鎖定」文案膨脹。 | 同意修正。 | 改成「第 2 級提高重取目標頻率與鎖定距離」，與實際 retarget timer / radius 行為對齊。 |
| 新武器質變 / 進化進池不足或 R11 覆蓋不足。 | 主功能反駁，回歸缺口部分同意。 | `squad_manager.gd` 仍有 `boomerang_rebound` / `missile_guidance`，`weapon_data.gd` 仍有兩個 evo；R7 已驗進池。R11 本輪新增「進化屬性只套一次」與 boomerang hit table 回歸，補 R11 缺口。 |
| 程序動畫 150 敵 sin / flip 效能可能炸。 | 反駁。 | Stress 場景綠；沒有新增 group scan；動畫不是當前瓶頸。 |
| squash 與白閃材質衝突。 | 反駁。 | 現行仍是 scale 與 modulate 分離，沒有 per-entity ShaderMaterial 或材質 churn。 |
| 視覺放大 / bob 與判定錯位是體驗風險。 | 部分同意，未在本輪改判定。 | Grok 對體感風險的指控成立；但它不是本輪雙加/池健康紅線。保留為後續視覺 debug overlay 或 hit radius 表現調校項。 |
| 同 seed 決定性 / Homing 等距平手灰區。 | 部分同意。 | 新武器沒有新增 RNG；homing 目標選擇依 spatial index 掃描序，等距 tie-break 仍是預存灰區。未在本輪改動，避免擴大範圍。 |
| 歷輪紅線可能破：spawn token、pool、group scan、cap。 | 反駁。 | R11RegressionTest 與 ArenaInstrumentationRun 均顯示 `enemy_group_scans=0`；PoolContractTest PASS；GameplayCapTest PASS；新增指標只在 `combat_metrics_enabled` 開啟時記錄。 |
| N10：kill thump / hit / combo 音效密度滿場可能嘈雜。 | 部分同意，保留調校項。 | 這是體感混音風險，不是本輪正確性 bug。本輪未改音效節流；Stress 與功能測試未顯示紅線問題。 |

## 修法摘要

- `boomerang_weapon.gd`：移除 evo pierce 開火二次加成。
- `homing_missile_weapon.gd`：移除 evo turn_rate 開火二次加成。
- `weapon_data.gd` / `rift_shield_boomerang.tres` / `squad_manager.gd`：改掉易傷、雙程命中、再鎖定、返場穿透等超賣文案。
- `game_manager.gd`：新增三選一非隊長卡健康守門；新增 debug-only combat metrics。
- `enemy.gd` 與各傷害來源：`take_damage()` 回傳實際傷害，debug metrics 開啟時累計每武器實傷。
- `r11_regression_test.gd`：新增 boomerang hit table、evo 屬性只套一次、三選一非隊長保底回歸。
- `ArenaInstrumentationRun.tscn`：新增真 Arena 固定 seed 插樁，補強 BalanceMock 可信度。

## 驗證

- `R11RegressionTest`：PASS。關鍵輸出：`R11_BOOMERANG_HIT_TABLE ...`、`R11_EVOLUTION_STATS pierce=7 turn_rate=10.20`、`R11_POOL_HEALTH nonleader_three_choice_guard=true`。
- 全 debug 場景：PASS。PoolContractTest 會刻意觸發 double-release warning；測試本身 PASS。
- `ArenaInstrumentationRun`：PASS。固定 seed 771101，12 秒真場景，實際 DPS 分佈輸出。
- Web export：`--export-release Web export/web/index.html` exit 0，產出 `export/web/index.html`、`index.pck`、`index.wasm`。Godot 只輸出 `.uid` cache 重建 warning，無 SCRIPT ERROR / ERROR。

