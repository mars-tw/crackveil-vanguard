# R38 三位新英雄與武器

三位英雄已加入共 13 人的可招募名單，開場維持原三人，隊伍上限仍為九人。每位都有獨立 HeroData、武器資源與實際戰鬥節點；沒有用原角色別名充數。

| 角色 | 武器與基本效果 | 質變 | 進化 |
|---|---|---|---|
| 星焰槍騎 `solar_lancer` | 星焰貫槍：兩列直刺，每列最多四人；同次出手不重複命中同一敵人。角色特性額外 12% 槍傷。 | 灼星烙印：命中後附加 10%／20% 易傷，1.4 秒。 | 日冕槍陣：多兩列、射程 +80；各列尾端追加 35% 傷害爆裂。 |
| 潮汐魔導 `tide_oracle` | 潮汐誓約：88 半徑爆潮、24% 緩速 1.3 秒；每次替 340 距離內隊友回復 1 點。 | 潮生祝禱：每次額外回復 2／4 點，緩速 32%／40%。 | 滄海聖域：半徑 +42、傷害 +8，追加六發追蹤水晶，附近隊友額外回復 2 點。 |
| 影刃遊俠 `shadow_ronin` | 追影雙刃：兩把有實際碰撞的返場刀，穿透後飛回角色；角色特性額外 10% 刀傷。 | 回影追斬：返程重置命中表，可再次命中；返場傷害 +18%／36%，第 2 級航程 +35。 | 緋影刃陣：多兩把、刀寬 +2、穿透 +2，返場另加 22% 傷害。 |

三把武器都有傷害、冷卻與擴張升級。進化條件為當局等級至少 7、該武器傷害升級三級、自己的質變升級二級。所有數值修改只作用於 runtime copy，下一局不繼承；沒有新增全域亂數呼叫。

`Hero.unlock_weapon()` 由 `weapon_catalog.tres` 取得新 `weapon_scene`。`SquadManager` 新增兩個 resource hooks：`get_qualitative_upgrade_definitions()`、`get_count_upgrade_description()`；原武器維持原路徑。實際招募卡、武器卡與付費技能池共用 canonical option，新英雄皆已接入動畫與技能池。

`ImpactWeaponBase` 先呼叫 `Visual.play_attack()`，只在 `attack_impact` 訊號執行槍刺／爆潮／投射物生成。方向同步至 Hero 既有的 `attack_direction_lock`。失效或重用的目標 token、超出射程、死亡、reset 都不得產生晚到傷害。

## 本次驗證

- `R38_CATALOG_ONLY_PASS`：13 個唯一角色 ID、三位原開場角色、九人上限、新武器資源與場景、質變與進化條件、source immutable。
- `HERO10_CLOSURE_PASS`：本次重新執行，原英雄、四組羈絆、減傷與裂傀上限仍正常。
- `TRUE_ANIMATION_REGRESSION_PASS`：本次重新執行，既有動畫的 F2 傷害、回收代次、hurt/death 正常。
- `R38_HERO_WEAPON_PASS`：三張新 icon 與外部 atlas 已匯入；三角色各有至少三種走路與攻擊姿勢、idle 分屬不同 actor。實際從升級 pool 招募，並確認三人皆存在於付費技能卡合法池。新英雄的真 F2 出手、前搖無傷、敵人碰撞、質變／進化實益、pool generation、reset 無鬼影傷害、九人上限與下一局清除全通過。另以武器正常 `_process` 檢查自動尋敵、播放、命中。
- 雙刃實際 Area2D 回程碰撞：先觀察同一敵人的出程命中 token，再確認回程重置命中表，將同一敵人移到觀察到的返場路徑；不呼叫傷害或碰撞 handler。回程第二次命中額外造成 59.09 傷害。潮汐進化實際回復 7 點並發射六顆追蹤水晶。

受控單次出手樣本：星焰 38.08 → 79.21、潮汐 24.00 → 125.96（含六水晶）、雙刃 48.40 → 133.89（含一次返場再擊）。這些是隔離場景的單次傷害；測試前半段停用武器 `_process` 以觀察 F2，debug 的瞬時計算 `projectiles_per_second` 因 clock 不累積不能視為自然遊玩 DPS。最後的 `automatic_process` 欄才是正常程序尋敵／出招樣本，且仍只是單次出手。

受控測試摘要保存在 [回歸結果](evidence/r38/gates.json)，測試本身可從 `scenes/debug/R38HeroWeaponTest.tscn` 重現。九個新 actor 各有 16 個來源姿勢，TrueAnimationLibrary 用 27 個播放位置安排時間，不宣稱 27 張獨特原畫。Web 真實招募與活動取樣另見 [實玩摘要](evidence/r38/playtest_summary.json)。

## 真實招募畫面的角色尺寸修正

自然遊玩截圖 `docs/evidence/r38/playtest/recruit-bloom-desktop-battle.png` 顯示槍騎比原隊員明顯偏小。原三位新英雄均採 `sprite_scale=1`，加上長武器限制 atlas packing，身體讀起來像小圖示。只修改三份 HeroData 的顯示倍率：星焰 2.0、潮汐 1.7、影刃 2.1。

量測讀取 TrueAnimationLibrary 使用的實際 atlas 前 12 格 idle／walk，alpha 門檻 96；密集身體區取像素最多直行左右九格、每橫列至少四個不透明像素，排除單獨細杖與武器尖端。PlayerVisual 公式為隊員 `80/128*sprite_scale`。量測值是攝影機與 CSS 縮放前的 logical pixels，不能當作所有裝置的實畫像素。

| 角色 | 倍率 | 身體密集區：修前 → 修後 | 修後完整 alpha 高度 |
|---|---|---|---|
| 星焰槍騎 | 1 → 2.0 | 41.25–46.25 → 82.5–92.5 | 92.5–95 |
| 潮汐魔導 | 1 → 1.7 | 48.12–55 → 81.81–93.5 | 91.38–94.56 |
| 影刃遊俠 | 1 → 2.1 | 38.75–46.88 → 81.38–98.44 | 97.12–101.06 |
| 舊裂盾隊員 | 1.42 | 73.66–91.41 | 89.64–92.3 |
| 舊裂弧隊員 | 1.4 | 75.25–90.12 | 87.5–91 |

新角色與原隊員接近，仍比隊長完整 alpha 高度 118.98–126.26 小。原圖、atlas、16 種來源動作、步態、動畫事件、碰撞半徑與戰鬥數值皆未變；這是固定顯示比例修正。量測工具 `tools/measure_r38_hero_body_scale.py`，完整 [修前數據](evidence/r38-hero-body-scale-before.json) 與 [修後數據](evidence/r38-hero-body-scale-after.json) 已保留；另補驗真實 Web 招募後的戰鬥畫面。
