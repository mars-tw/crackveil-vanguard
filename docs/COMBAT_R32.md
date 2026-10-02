# R32 戰鬥手感與清怪節奏

更新日期：2026-10-02。驗證引擎：Godot 4.7 stable Windows console。本文件記錄戰鬥工作單位；完整遊玩、掉裝備與畫面驗收由整合流程另行記錄。

## 已完成

- 每次有效命中都在實際傷害發生的位置畫出短暫、帶方向的碎光；斬殺增加交叉切線。效果由單一 `CombatFeedback` canvas 批次繪製，不為每次命中建立 node、timer 或 tween。
- 0.45 秒內完成 3／5／8 次斬殺，分別顯示 `CLEAVE`、`RAMPAGE`、`SLAUGHTER`。文字與短弧出現在擊殺位置的中心，搭配有冷卻的音效和震動；不新增任何全域慢動作 owner。
- 第 7 秒開始，每 16 秒加入一批 6 至 10 隻較脆的普通怪。同邊、兩列、27 像素間距的隊形讓貫穿射擊、環繞武器和範圍攻擊能一次掃掉一群。魔王期間停止補這批怪，並以剩餘 enemy cap 決定實際數量。
- 菁英與魔王有短暫的 stagger guard。小額連續傷害仍會扣血、閃白和顯示數字，但不再永久打斷牠們的攻擊；足夠重的命中仍可中斷並播放真正的 hurt poses。
- 保留原本逐幀 hurt／death clips、共享 animation ticker、impact frame 2 與完整 recovery。死亡後只補上小幅方向滑移，collider 已停用，六格 fall poses 仍繼續播放。
- 遠程怪的箭頭提示與射擊方向在起手時鎖定，玩家可以朝另一側閃避。衝刺怪有方向箭頭，魔王 radial volley 有環形起手提示，提示在 active impact 隱藏。
- 修正魔王半血轉階段的 14 發彈幕：先走 anticipation，再於真正的第 2 格發射；若當時正在近身攻擊，等待 recovery 後再施放。
- 高傷害數字增加字級、描邊和短暫 pop，前段保持不透明再淡出。連殺文字保留 0.86 秒且寬度依字數調整，避免長標籤被舊的 128 像素寬度截斷。
- 裝備服務 hook 位於 `death_finalized` guard 之後、`record_boss_kill()` 之前。同一個 pooled enemy 的每次生命只呼叫一次 `loot_director.on_enemy_defeated(position, is_elite, is_boss, type_id)`；勝利視窗不會先凍結這次掉落。
- 滿場時魔王會回收一隻最遠的普通怪後進場，不再卡在 150 隻上限外。

## 效能與接口

`EnemySpawner` 會在 arena 下自動建立一個 `CombatFeedback`；arena 不需重複建立。服務加入 `combat_feedback` group，提供 `get_debug_state()` 與 `set_feedback_enabled(bool)`。

命中效果同時最多桌面 28 組、mobile LOD 12 組，超額只捨棄視覺，不捨棄傷害、死亡、掉落或連殺紀錄。遠離玩家視野的命中不建立碎光。服務沒有工作時關閉 `_process`，暫停跟隨 scene tree，沒有獨立 timer 需要清理。

新碎光與連殺計算不呼叫全域 RNG。傷害數字的飄動改用獨立 cosmetic RNG，已驗證不推進 gameplay RNG。新怪群沿用既有 seeded spawn-position 流程；新版本可重現相同種子和輸入，不保證與舊版本產生完全相同的敵人序列。

## 引擎實測

新增測試：`res://scenes/debug/CombatR32RegressionTest.tscn`。

| 測試 | 已驗證內容 | 結果 |
| --- | --- | --- |
| CombatR32RegressionTest | 多殺 3／8 階段、28／12 效果 cap、cosmetic overflow、全域 time scale owner 為 0 | PASS |
| CombatR32RegressionTest | 小額傷害不打斷魔王 active attack、impact frame 2、hurt poses、忽略負傷害 | PASS |
| CombatR32RegressionTest | death clip 完成才呼叫 loot、pool reuse 每次生命一次 | PASS |
| CombatR32RegressionTest | 轉階段 anticipation 無彈幕、frame 2 正好 14 發、radial cue 隱藏 | PASS |
| CombatR32RegressionTest | 7 隻密集怪跨度小於 140、hard cap、滿場魔王回收一隻普通怪 | PASS |
| CombatR32RegressionTest | 連殺字寬、0.86 秒 hold、pop pooling reset、cosmetic RNG 隔離 | PASS |
| TrueAnimationRegressionTest | 10 角色 shared atlas、attack frame 2、whiff 零傷害、hurt knockback、death 延後回收、LOD | PASS |
| WeaponSmokeTest | 9 人小隊、招募、11 組武器啟動與跟隨 | PASS |
| GameplayCapTest | 爆炸視覺滿額仍扣血、拾取視覺滿額仍保留 XP／gold | PASS |

原始輸出存於 `docs/evidence/r32/combat_*.txt`。首輪曾遇到正在整合中的 `player_visual` 缺屬性轉 bool 問題；root 修正後，最終四場測試均以 exit 0 完成，沒有 `SCRIPT ERROR`。

## 接續遊玩應注意

實際爽度仍需依正常操控下的早期清怪時間、同屏危險辨識、連殺視覺是否擋住地面、手機幀率與中後期菁英壓力確認。這份 headless regression 驗證事件與上限，不代表完成主觀體驗評分。

## 第 3 輪自然遊玩回報：中段出怪空窗修正

體驗員在 00:37／01:08／01:39 觀察到畫面幾乎沒有敵人。確認舊出怪公式在 30 秒切換分支：29.9 秒約每秒 9.99 隻，30 秒突然變成每秒 1.17 隻，流量下降約 8.5 倍。這次只修 `enemy_spawner.gd`，沒有調整魔王數值或角色動畫。

- 30 秒後延續每批 3 隻／0.30 秒，間隔平滑下降至 0.24 秒。之後每 90 秒多一隻；37／68／109 秒的 baseline 都不再降檔。魔王仍降低出怪人數、拉長間隔，並暫停額外收割怪群。
- 出怪邊界改由 viewport 實際 canvas transform 的反矩陣推回世界座標，包含 camera zoom、offset、smoothing 與 stretch。桌面 1280×720、zoom 1.28 的可見世界範圍是 1000×562.5，出怪位置位於這個邊界外 110 像素。
- 每秒從既有 enemy registry 檢查一次，最多回收 10 隻距離畫面外超過 330 像素的普通怪。可見怪、剛在邊緣生成的怪、菁英、魔王及正在死亡的怪都保留。回收直接歸還 pool，不 reposition、不記擊殺、不發 XP／gold／裝備，也不消耗 RNG。

新增 `SpawnDensityR32Test` 實跑 PASS：29.9→30 秒 cadence 連續；桌面 normal／threat zoom 與手機直／橫四種視野各驗 64 個出怪點；256 個點都在可見世界範圍外，重設相同種子可完全重現。另驗回收 budget、可見／特色／死亡怪保留、零獎勵、零 RNG 增量、hard cap 與零 pooling error。

修正後再跑 `CombatR32RegressionTest`、`GameplayCapTest`、`WeaponSmokeTest`、`R31EndgameGate`，均 PASS、exit 0，沒有 `SCRIPT ERROR`／`ERROR:`。證據：`docs/evidence/r32/combat_SpawnDensityR32Test.txt` 與 `density_*.txt`。新版匯出後，體驗員已完成桌機與手機 30 到 70 秒中段的自然復測，未重現長空場；完整紀錄見 [最終遊玩報告](playtest/R32_PLAYTEST.md)。
