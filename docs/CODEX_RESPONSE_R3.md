# Codex 對 Grok R3 審查回應

日期：2026-07-09

## 結論摘要

本輪總稽核指定的 P1 全部採納。Grok 判斷正確：第五階段把 VFX cap 寫在 `EntityFactory.spawn_explosion()` / `spawn_xp_gem()` / `spawn_gold_coin()` 前段，導致 cap 不只影響視覺，還會影響玩法結果。這違反「視覺 budget 不得改變戰鬥/成長結算」原則。

## P1-1：爆炸 cap 會略過傷害

結論：採納。

技術理由：目前 `spawn_explosion()` 先檢查 `EXPLOSION_CAP`，超過就 `return null`；而爆炸傷害原本是在 `ExplosionArea._process()` 內由 `_apply_damage()` 執行。因此視覺節點沒生成時，傷害也不會執行。

修正方向：

- 將爆炸範圍傷害移到 `EntityFactory.spawn_explosion()` 入口，永遠先做 gameplay damage。
- `ExplosionArea` 改為純視覺生命週期，不再負責扣血。
- `EXPLOSION_CAP` 只控制爆炸 sprite 是否顯示。

## P1-2：掉落 cap 會丟 XP / 金幣

結論：採納。

技術理由：目前 `spawn_xp_gem()` / `spawn_gold_coin()` 在 live count 達 cap 時直接 `return null`，敵人死亡後資源不會補發。這會讓高擊殺負載下玩家損失成長資源。

修正方向：

- visible pickup 未達 cap 時維持原本掉落與磁吸。
- visual pickup 達 cap 或 pool 耗盡時，改用 immediate fallback：直接把 XP / 金幣加入 `GameManager`。
- 這讓資源總額不丟失；cap 只犧牲部分掉落 sprite 呈現。

## P2：文件過度宣稱

結論：採納。

技術理由：文件不能寫「復用最舊」但實作是 `return null` 跳過。總稽核傾向採用誠實描述，我同意。

修正方向：

- 更新 `docs/REVIEW.md`，明確描述本輪 cap 策略：純視覺節點超 cap 時跳過顯示；爆炸傷害與掉落資源不受 cap 影響。

## P2：池化節點 rotation 殘留

結論：採納。

技術理由：敵人 sprite 與 death burst sprite 會在生命期中改 rotation，pool reset 若不清，下一次 acquire 可能短暫沿用上一個視覺角度。

修正方向：

- enemy / projectile / orbit / explosion / pickup / death_burst / lightning_arc / damage_number 在 release/reset 時清 `rotation` 或子 sprite rotation。
- 不改動 R2 的 `spawn_token` 與 `_in_pool` 契約。

## 驗證要求

新增針對性測試：

- 爆炸視覺 cap 觸發時，敵人仍扣血。
- XP / 金幣 pickup visual cap 觸發時，玩家最後取得的 XP / 金幣總額等於應得總額。

維持驗證：

- Godot 4.7 headless 專案載入。
- PoolContract / SquadSmoke / WeaponSmoke。
- 強化 StressTest，確認 pool 契約與 fps 沒明顯倒退。

## 實作後驗證摘要

針對性 gameplay cap 測試：

```text
GAMEPLAY_CAP_EXPLOSION hp_before=80.0 hp_after=62.0 visual_skipped=true
GAMEPLAY_CAP_PICKUPS xp=254 gold=241 visual_cap_triggered=true
GAMEPLAY_CAP_PASS
```

強化壓測：

```text
STRESS_RESULT enemies=150 projectiles=100 measured_frames=411 avg_ms=10.834 p95_ms=24.193 max_ms=37.470 avg_fps=92.30 p95_fps=41.33 min_fps=26.69
STRESS_COUNTERS enemy_spatial_queries=2993 queries_per_frame=7.28 enemy_group_scans=0 group_scans_per_frame=0.000 kills=814 gold=869 xp=930
STRESS_PERF_BELOW_60=true
STRESS_PASS
```

結論：爆炸與掉落 cap 已解耦，玩法結果不再受視覺 cap 影響。相較第五階段修正前 avg 105.81fps，本次 avg 92.30fps，有少量倒退但仍遠高於 R2 的 27.82fps；p95 約 41fps，仍未達穩定 60fps。
