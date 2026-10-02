# R35 透明動畫特效

內建 ImageGen 生成四張真正透明的 4 × 4 原始 sheet，每張包含兩種效果，各八張獨立動畫幀。所有原始 PNG、提示詞、保存路徑與 SHA-256 都保留在 `sources/` 和 `source_manifest.json`。金色雙斬另外做了一次格內留白修正；沒有用幾何程式替代生成的特效形狀。

`r35_skill_fx_atlas.png` 是 2048 × 2048 RGBA atlas，3,081,619 bytes。每格 256 × 256，八欄八列，一列一種效果。64 幀都使用同一格中心 `(128, 128)`，完整原 cell 固定裁切後等比縮入 216 × 216 畫布，四邊至少 20 像素完全透明；沒有按每幀輪廓重新置中或修改特效內容。

| Row | kind | 8 幀總時長 | Loop |
| --- | --- | --- | --- |
| 0 | `slash_a` | 0.24 秒 | 否 |
| 1 | `slash_b` | 0.24 秒 | 否 |
| 2 | `cyclone` | 0.32 秒一圈 | 是 |
| 3 | `critical_impact` | 0.28 秒 | 否 |
| 4 | `monster_fire` | 0.28 秒 | 否 |
| 5 | `monster_frost` | 0.28 秒 | 否 |
| 6 | `monster_shadow` | 0.26 秒 | 否 |
| 7 | `monster_bite` | 0.22 秒 | 否 |

Catalog 位於 `scripts/vfx/newskill_fx_catalog.gd`。`get_frames(kind)` 回傳快取的 SpriteFrames，動畫名皆為 `default`；`get_frame_textures(kind)` 回傳八張共用 GPU atlas 的 AtlasTexture；`get_lifetime(kind)` 回傳上表時長。旋斬的 `get_release_lifetime()` 為 0.10 秒，主流程負責停止持續施放後的 fade／回收，以及 pooled cap 和精確 expiry。此資料包沒有替主流程宣稱該回收行為已測過。

## 已執行的檢查

`tools/pack_r35_skill_fx.gd` 驗證 64 幀非空、每種效果八幀的有效 alpha 輪廓各不相同、最少 20 像素透明邊、固定中心及實際 RGBA。原始 crop 邊界使用 alpha ＞ 0.08 的可見內容檢查，沒有可見鋒刃或碎片跨過該邊界；更低 alpha 仍原樣保留。生成圖片預覽裡鮮紅／鮮黃的部分噪點實際 alpha 只有 1／255，不能把未正確合成的預覽誤讀成不透明霧牆。

`tools/test_r35_skill_fx_catalog.gd` 通過共享 atlas、SpriteFrames 快取、每種八張不同 runtime frame、`filter_clip`、mipmaps、時長與 loop／release 契約檢查。

`tools/preview_r35_skill_fx.gd` 在 Godot native OpenGL 下使用真正 AnimatedSprite2D 播放，八種效果都實際訪問全部八幀，並輸出 `qa/native_fx_on_painted_ground.png`。已開啟該圖和深淺底 contact sheets 檢查：金白核心、分色中層、薄透明外緣與獨立碎片清楚；旋斬中心保持透明；沒有跨格長連線、簡單青色三角或全屏霧幕。

驗證結果在 `qa/packing_report.json`、`catalog_test.json`、`catalog_test.txt`、`native_preview.json` 和 `native_preview.txt`。這是素材、介面與原生動畫合成驗證，主流程的真戰鬥效果、停止施法及 pool 壽命由整合後的遊玩測試確認。

## 重建

```powershell
& 'C:\Users\digimkt\AppData\Local\CodexTools\Godot47\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tools/pack_r35_skill_fx.gd
```

Runtime 只需要共用 atlas 與 catalog；`sources/` 和 `qa/` 是重建／驗證資料，可排除於公開遊戲包外。圖集已 freeze，六張地圖保持不變，未推送。
