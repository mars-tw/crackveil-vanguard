# Codex Response R6

日期：2026-07-10

## R6 逐條回應

### R5 覆核

| 項目 | R6 判定 | Codex 回應 |
|---|---|---|
| S1 滿血急救 disable | 成立，殘留 P2 | 採納判定；本輪保留 disable/reason 契約，商店 2.0 新商品也套同一後端重檢。 |
| S2 質變滿層 disable | 成立，殘留 P2 | 採納判定；新增指定質變商品時一併做可用性檢查。 |
| E1 Boss 環彈 cap | 成立，R6-E1b 為 P2 | 本輪不改敵彈池架構；維持 boss priority/reclaim。 |
| Q1 fork 子池 | 成立，fork 自身 skip 為 P2 | 本輪不新增 fork 行為，不擴 cap。 |
| Q3 hazard LRU | 成立 | 不改。 |
| Q4 hazard redraw | 成立 | 不改。 |
| Q5 磁暴 run flag | 成立 | 延續 run flag；契約可開局啟用磁暴。 |

### R5 延後項

| 項目 | R6 建議 | 本輪處理 |
|---|---|---|
| E4 精英 XP 靜默 grant | P1，禁止 elite bonus 直接入帳 | 採納。`spawn_visible_xp_gem` 不再對 elite bonus 呼叫 direct grant；cap 滿時合併最近 gem，沒有目標時回收 XP gem 槽位再生可見 gem。 |
| E6 精英 cap 到點消失 | P0，A 短重試 + B 替換普通敵 | 採納。`_spawn_elite` 改回傳 bool；失敗只延後 1 秒；cap 滿時從 spatial live list 替換非精英、非 Boss 普通敵。 |
| S3 商店撞 Boss | P1，避開 `[boss_time-15, boss_time+25]` | 採納。定時店改 75/150/240/330...；定時與隨機店都避開 Boss 窗與 `boss_active`，階段勝利後不 0 秒塞店。 |

### P1 路線圖

| 項目 | R6 建議 | 本輪處理 |
|---|---|---|
| Meta 裂隙殘響 | 包 5 | 延後。遵守 §3.6 順序，本輪不做 Meta／hub。 |
| 武器進化 | 包 4 | 延後。不新增未池化彈種。 |
| 開局裂隙契約 | 包 2 | 採納。新增 6 張契約、開局三選一 UI、run seed 決定性抽卡、結算顯示本局契約。 |
| 商店深化 | 包 1 | 採納。改為恢復／力量／賭局三池輪換，保留 disable/reason 與價格曲線。 |
| 精英詞綴 | 包 3 | 延後。先修 E6，再做詞綴。 |

### §3.7 明確不做

| 不做項 | 本輪狀態 |
|---|---|
| 城鎮 hub／多地圖 | 未做。 |
| 超過 6 契約／過量詞綴 | 未做；契約固定 6 張。 |
| 永久大數值成長 | 未做。 |
| 新彈種無 pool | 未做。 |
| 把 BalanceMock 當平衡真理 | 未做；新驗證放入 regression/Arena 插樁。 |

## 本輪實作摘要

### 包 0：E6／E4

- E6：`EnemySpawner._spawn_elite()` 改回傳 `bool`。成功才排下一次 45–60 秒；失敗設 `next_elite_time = elapsed + 1.0` 短重試。
- E6：cap 滿時呼叫 `EntityFactory.reclaim_regular_enemy_for_elite()`，從 spatial index 的 live list 選非精英、非 Boss 普通敵回收後再生精英；不掃 group。
- E4：`spawn_visible_xp_gem()` 不再呼叫 `_grant_xp_direct()`。cap 滿時先合併最近 active XP gem；active registry 空時從 pool live list 重建並回收最遠 XP gem 槽位再生可見 gem。

### 包 1：S3／商店 2.0

- 定時店改為 75／150／240／330...。
- `_request_shop()` 遇 Boss 窗 `[165, 205]` 或 `boss_active` 不開店，改延後。
- 升級後 10% 隨機店也走同一 Boss 窗守門。
- 階段勝利後若 shop time 已過，延後 `elapsed + 12s`，不 0 秒塞店。
- 商店改三池各抽一張：
  - 恢復池：裂隙急救、深層急救、帷幕護盾。
  - 力量池：偏壓改裝、定向改裝、裂隙過載。
  - 賭局池：重整庫存、精英餌標。
- 價格曲線：每 180 秒 +15%，最多 +60%；刷新每次 +1 金。
- 新商品全部走 `enabled/disabled_reason` 與後端重檢。

### 包 2：裂隙契約

新增開局三選一 `ContractScreen`，實際 Arena 主場景會暫停等待契約；debug 場景內嵌 Arena 時跳過，避免測試停在開局 UI。

| id | 名稱 | 效果 | 規則改變 |
|---|---|---|---|
| `contract_blood_tax` | 血稅 | 全隊傷害 +12%，受擊傷害 +10%。 | 否 |
| `contract_golden_famine` | 金饑 | 金幣掉落 +40%；90 秒前升級只給 2 張選項。 | 是 |
| `contract_quiet_veil` | 靜幕 | 前 60 秒敵潮較疏；60 秒後敵潮加快補回壓力。 | 是 |
| `contract_elite_beacon` | 精英信標 | 首次精英提前到 35 秒；精英額外 +3 金幣。 | 是 |
| `contract_glass_magnet` | 玻璃磁界 | 開局即啟用磁暴回收；全隊最大 HP -8%。 | 是 |
| `contract_single_thread` | 單線協定 | 隊長傷害 +18%；隊員傷害 -10%。 | 是 |

結算畫面新增本局契約名稱。契約抽卡使用 Godot global RNG；Arena 會把 `--run-seed=`／`forced_run_seed` 套到 `seed()`，R6 regression 驗證同 seed 抽卡一致。

## 驗證紀錄

### Headless

- `Godot --headless --path . --quit`：通過，零錯。

### Regression

- `R5RegressionTest`：通過。
  - `R5_SHOP_HEAL_DISABLED`
  - `R5_MAGNETIC_RUN_FLAG`
  - `R5_SHOP_QUALITATIVE_DISABLED`
  - `R5_ENEMY_PROJECTILE_BOSS_RESERVED`
  - `R5_FORK_BUDGET`
  - `R5_HAZARD_LRU_REDRAW`
- `R6RegressionTest`：通過。
  - `R6_E6_ELITE_CAP_REPLACEMENT live=12 reclaims=1`
  - `R6_E4_VISIBLE_XP merge=1 reclaim=1 direct=0`
  - `R6_S3_SHOP_BOSS_WINDOW next_after_window=205 next_after_victory=232.0`
  - `R6_CONTRACTS seed_ids=["contract_golden_famine","contract_glass_magnet","contract_elite_beacon"]`

### Debug 場景

全部通過：

- `WeaponSmokeTest`
- `SquadSmokeTest`
- `PoolContractTest`
- `GameplayCapTest`
- `MobileInputSmokeTest`
- `BalanceMockRun`
- `StressTest`

`StressTest` 維持 `enemy_group_scans=0`。測試中出現既有 pool double-release warning，場景仍依契約判定 PASS。

### Web Export

- `Godot --headless --path . --export-release Web export/web/index.html`：完成，無匯出錯誤。
- 匯出過程有 Godot 重新建立 `.uid` 快取的 warning；產生的未追蹤 `.uid`／sprite `.import` 快取已清理。

## 紅線續守

- 未 git commit／push。
- 沒有新增未池化彈種。
- E6 替換敵人使用 spatial index live list，未新增 group 掃描熱路徑。
- E4 不提高 XP cap。
- 商店 UI 只在 open／refresh 時重建按鈕，未做每幀重建。
- BalanceMock 只同步事件時刻，不作平衡真理。

## 接手注意

- `docs/GROK_REVIEW_R6.md` 在本工作區原本就是未追蹤檔，本輪未納入版本操作。
- R6 包 3 精英詞綴可直接接在已修好的 `_spawn_elite()` config 上。
- Meta 與武器進化仍按 R6 §3.6 延後。
