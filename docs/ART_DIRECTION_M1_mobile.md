# M1 Mobile Art Direction

目標：手機版優先，讓直式 390x844 與橫式 844x390 在 `MOBILE_CAMERA_ZOOM=1.56` 下仍可單手操作、看清危險、維持 p95。

## 拇指熱區

| 元件 | 直式 | 橫式 | 規則 |
| --- | --- | --- | --- |
| 左搖桿視覺半徑 | short side x 0.24，預設約 94px | short side x 0.20，預設約 78px | 可在暫停頁調小/中/大；熱區倍率固定 1.24 |
| 左搖桿熱區 | 約 232x232px | 約 194x194px | 靠左下，底邊含 safe bottom + 18/14px |
| 隊長技按鈕 | 92x92px | 84x84px | 靠右下，與搖桿熱區至少 10px buffer |
| 暫停鈕 | 104x76px | 116x68px 以上 | 固定上緣 safe top，遠離右下技能誤觸區 |
| 結算主按鈕 | 最下方堆疊 | 右側堆疊 | `繼續無盡` / `再來一局` 必須落在下方拇指帶 |

## 字級表

| 用途 | 手機直式 | 手機橫式 | 備註 |
| --- | --- | --- | --- |
| HUD HP | 18 base -> mobile scale 後 >= 24 | >= 24 | 只顯示必要戰鬥資訊 |
| HUD timer | 22 base -> mobile scale 後 >= 28 | >= 28 | 置上，避開暫停鈕 |
| HUD kills | 14 base -> mobile scale 後約 27 | 約 30 | 手機只顯示擊殺，不顯示金幣/殘響 |
| Level/contract cards | 18 | 18 | 卡片間距手機 22px vertical / 26px horizontal |
| Damage numbers | cap 20px，預設 14px | cap 20px | 手機更小、合併半徑更大，避免蓋怪 |
| Combo/milestone | 25 | 32 | 位置下移到安全中上區，避開左右下拇指遮擋 |

## 對比規則

- 敵彈在手機上使用橘亮核心加深色外緣，優先高於玩家 cyan projectile。
- Hazard telegraph 在手機上加 7px 暗邊與 4.5px 主輪廓；內圈同步加粗。
- 背景 mobile LOD 下只保留主要 rift 氣氛：粒子 0.6x、裝飾密度 0.72x、環境線條 18 -> 8、redraw 0.08s -> 0.14s。
- 傷害數字手機 cap 30、merge radius 82、merge age 0.34；數字應聚合成較少節點，不遮住敵群輪廓。
- 手機 HUD 戰鬥中只留 HP、等級/XP、時間、擊殺。金幣/殘響移到暫停頁 run stats。

## LOD 檔位

| 項目 | Desktop | Mobile LOD |
| --- | --- | --- |
| Death burst particles | 1.0x | 0.6x |
| Damage number cap | 48 | 30 |
| Damage merge radius/age | 48 / 0.24s | 82 / 0.34s |
| Hazard tick interval | 0.24s base | 0.372s base |
| Corpse ghost live cap | 24 | 12 |
| Death burst live cap | 20 | 12 |
| Background decor target | 96 | 69 |

桌面檔位不得自動吃 mobile LOD；`M1RegressionTest` 鎖此契約。
