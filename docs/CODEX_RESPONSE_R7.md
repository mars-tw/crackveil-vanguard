# Codex Response R7

日期：2026-07-10  
範圍：回應 `docs/GROK_REVIEW_R7.md`，修 P0/P1/P2 指定項，未 commit、未 push。

## 總回應

我同意 R7 總判：「包 3-5 主契約成立，但未完美達標」。R7 指出的剩餘問題不是 cap/pool/delta 主幹崩壞，而是當局生效順序、系統暫停 ownership、進化門檻/權重政策、swift 平衡方向，以及餘燼井設計缺口。本輪已按 R8 建議修正 P0/P1，並補 R7RegressionTest 的三個缺口。

## 逐條回應

| R7 條目 | 回應 | 理由/處置 |
|---|---|---|
| A-S1/A-S2 split 裂體與 cap | 同意 | 維持父體先 inactive 再產小體，active count cap 不破。 |
| A-S3 滿 cap 不保證 2 小體 | 同意其觀察，不同意列為 bug | 這是安全優先的裁切，避免破 150 cap。未改。 |
| A-F1-A-F5 field slow 與效能 | 同意 | 仍走 squad members，小陣列 tick，無 group 熱掃描。 |
| A-W1 swift 是 AI 質變 | 同意 | 保留 dasher 行為。 |
| A-W2 swift 傷害方向錯 | 同意 | 已將 `affix_swift` 傷害係數由 `1.05` 改為 `0.9`，HP `0.82` 保留。R7 測得 swift damage `16.38`。 |
| 進化共通條件偏寬 | 同意 | 四把進化定義新增 `required_damage_level = 3`，`WeaponData` 追蹤 `weapon_damage` 投資層數。 |
| 進化後線性卡未稀釋 | 同意 | 已進化武器的 `weapon_damage`/`weapon_cooldown`/`weapon_projectiles` 權重降為 `0.35`。 |
| E-RF 裂隙扇編成立但 fork 壓力灰區 | 同意 | 未加新池，仍走 fork cap；本輪只補進化門檻與權重收斂。 |
| E-SH 星環可感但脈動偏弱 | 同意 | 本輪未改，因 R7 指定必修集中在 B1-B5/B7。 |
| E-EW 餘燼井缺二段爆 | 同意 | 已補 0.45 秒延遲小爆，傷害為當次爆花傷害 `0.55`，走 `EntityFactory.spawn_delayed_explosion()`，最終仍用既有 `spawn_explosion()`/`_apply_explosion_damage()`，VFX 受 explosion cap 保護可為 null。 |
| E-ON 超載新星成立 | 同意 | 未改。 |
| M1 Meta 不破單局平衡 | 同意 | 幅度不變。 |
| M-D1 delta 防重複領 | 同意主幹，補測 | 新增 victory -> continue -> death 回歸，R7 測得 victory `40`、final `57`、death delta `17`。 |
| R7-B1 契約畫面買 Meta 當局 HP/拾取不生效 | 同意，已修 | `GameManager` 新增 `apply_current_meta_progress_to_squad/member`，以每名英雄 metadata 記錄已套用 HP 乘數與 pickup bonus，購買後 delta 重套用，不重複疊加。契約畫面購買成功後立即重套用並 emit stats。 |
| R7-B1 暫停面板與契約畫面重疊 | 同意，已修 | `GameManager` 新增 `system_pause_owners`，契約/升級/商店/階段勝利/死亡由 system owner 暫停；HUD pause overlay 只顯示 `manual_paused && !system_paused`。Contract/Shop/Victory layer 提到 25，HUD root 不攔截全螢幕輸入。 |
| R7-B2 中途招募不吃 Meta | 同意，已修 | `recruit_hero()` spawn 後立即 `GameManager.apply_current_meta_progress_to_member(hero)`。R7 測得 line_mender HP `91.80`，pickup `78.00`。 |
| R7-B3 swift 傷害 | 同意，已修 | 見 A-W2。 |
| R7-B4 餘燼井二段爆 | 同意，已修 | R7 測得延遲爆 damage `18.15`，目標 HP `30.00 -> 11.85`。 |
| R7-B5 進化門檻與權重 | 同意，已修 | 先滿質變但未升傷時 R7 回歸確認不給 evo；升傷 3 後才給。進化後線性卡權重確認 <= `0.36`。 |
| R7-B6 split 滿 cap 只出 1 小體 | 同意觀察，不修 | 這是 cap 安全的設計取捨，未列本輪必修。 |
| R7-B7 回歸缺口 | 同意，已補 | R7RegressionTest 補契約 Meta 當局生效/不疊加、契約與暫停 overlay 互斥、victory -> continue -> death delta。 |
| 紅線總表 | 同意 | 本輪未引入 group 熱掃描，延遲爆走既有 explosion cap，Meta 不破單局幅度。 |

## 修法摘要

- `scripts/autoload/game_manager.gd`
  - 加入 `system_pause_owners`，手動暫停與系統 modal 暫停分流。
  - Meta HP/拾取改成 delta 重套用，不重複疊加。
  - 公開 `apply_current_meta_progress_to_squad()` 與 `apply_current_meta_progress_to_member()`。
- `scripts/ui/hud.gd`、`scripts/ui/contract_screen.gd`、系統 modal 場景
  - HUD pause overlay 只顯示手動暫停。
  - Contract/Shop/StageVictory layer = 25，高於 HUD layer 10。
  - Contract 購買 Meta 成功後立即重套用當局效果。
- `scripts/heroes/squad_manager.gd`
  - 招募新英雄套用當前 Meta 快照。
  - 進化後該武器線性卡權重降到 `0.35`。
- `scripts/resources/weapon_data.gd`
  - 進化條件新增該武器 `weapon_damage >= 3`。
  - `WeaponData` 記錄數值升級層數。
- `scripts/enemies/enemy_spawner.gd`
  - swift damage 係數改為 `0.9`。
- `scripts/weapons/explosion_weapon.gd`、`scripts/autoload/entity_factory.gd`
  - 餘燼井補 0.45 秒延遲小爆。
- `scripts/debug/r7_regression_test.gd`
  - 新增 R7-B1/B2/B4/B5/B7 回歸覆蓋。
- `scripts/debug/balance_mock_run.gd`
  - mock 進化條件同步改為傷害投資 >=3，進化後線性權重下降。

## 驗證

Headless 載入：零錯。

回歸：

- `R5RegressionTest`：PASS
- `R6RegressionTest`：PASS
- `R7RegressionTest`：PASS
  - `R7_META_CONTRACT_APPLY hp 110.00->112.20 pickup 96.00->102.00 recruit_hp=91.80`
  - `R7_CONTRACT_PAUSE_EXCLUSION contract_layer=25 hud_layer=10`
  - `R7_AFFIX_FIELD_SWIFT ... swift_damage=16.38`
  - `R7_EMBER_WELL_DELAYED_BURST damage=18.15 hp 30.00->11.85`
  - `R7_ECHO_DELTA victory=40 final=57 death_delta=17`
- Debug scenes：PoolContract、GameplayCap、WeaponSmoke、SquadSmoke、Stress、MobileInput 全 PASS。
- Stress：avg `7.329 ms`、p95 `16.078 ms`、`enemy_group_scans=0`、pool exhausted `0`。
- BalanceMockRun：PASS。因新增傷害投資門檻，本次 mock `evolution_trigger_time=-1`，但 survival/boss curve 仍通過。

Web export：

- `--export-release Web export/web/index.html` exit 0。
- 匯出只有 Godot 重新建立 UID cache 的 warning，無錯誤。
- `export/web/index.pck`：`3,057,836` bytes。

## 結論

我接受 R7 對「主契約成立但未完美」的判定。本輪修完後，P0 的 UI 謊稱當局生效與暫停重疊已關閉，P1 的招募 Meta、swift、餘燼井、進化投資/權重政策已落地，R7 回歸缺口已補上。未處理項保留為 R8 之後的體感調校：field 數值細修、星環脈動更強可讀性、split 滿 cap 體感，以及 fork cap skip 的長測手感。
