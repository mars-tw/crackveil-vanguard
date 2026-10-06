# R41 Web 素材與配置稽核

稽核基準：`export\web\index-3304a85dd586.pck`（SHA-256 `3304a85dd586b86a929789ded90c29265bae90d29cf3e74d035b1e15e87e2657`），初始稽核為純讀取；後續依授權完成下列兩個程式與 11 份非角色 import 設定調整。PNG、原始生成圖、provenance、角色／FX atlas 及其 import 均未改，也未啟動瀏覽器／GPU／headless 遊戲測試。

## 結果

- PCK：47,267,208 bytes（45.08 MiB）；WASM：39,509,339 bytes（37.68 MiB）；合計 82.76 MiB。未計 HTML、圖片、編譯器與引擎配置。
- Godot 4.7 pack format 4：651 個 entries、134 個 `.ctex`。前 15 項合計 37.76 MiB。全部 `.ctex` 若全以 RGBA8 解碼，合計 167.22 MiB；這是素材容量上限估算，**不是同時 resident 或 Safari RSS 實測**。
- 稽核基準貼圖採 lossless/mode0、size_limit0；角色／FX atlas 無 mipmaps，地形／地標保留 mipmaps。`CompressedTexture2D` 名稱代表磁碟封裝，不能直接當作 GPU VRAM 壓縮已生效。
- WASM memory section 宣告初始 32 MiB、最大 2 GiB；最大值不是啟動時已配置量。
- 十個主題實際重用七張 1254×1254 地形（PCK 18.19 MiB、RGBA 41.99 MiB）與兩張八格地標圖（PCK 3.90 MiB、RGBA 12.01 MiB）。
- R35 主角色 atlas 31.50 MiB、R38 atlas 16 MiB、技能 FX atlas 16 MiB，共 63.50 MiB RGBA。AtlasTexture／SpriteFrames 是共享同一 atlas，不應把每個播放格再乘一次。

## 前 15 個 PCK 項目

| 項目 | 包內 MiB | PNG／ctex 尺寸 | RGBA8 MiB |
|---|---:|---|---:|
| `assets/sprites/r35_character_atlas.png`（ctex） | 3.464 | 2048×4032 | 31.500 |
| `assets/art/r35/r35_skill_fx_atlas.png`（ctex） | 3.405 | 2048×2048 | 16.000 |
| `assets/art/r36/tile_grass.png`（ctex） | 3.113 | 1254×1254 | 5.999 |
| `assets/art/r36/tile_stone.png`（ctex） | 3.057 | 1254×1254 | 5.999 |
| `assets/art/r36/tile_frost.png`（ctex） | 2.848 | 1254×1254 | 5.999 |
| `assets/art/r33/r33_keyart.png`（原始檔） | 2.707 | 1672×941 原始 PNG | 6.002 |
| `assets/art/r38/tile_coral.png`（ctex） | 2.635 | 1254×1254 | 5.999 |
| `assets/art/r36/landmarks.png`（ctex） | 2.457 | 1774×887 | 6.003 |
| `assets/art/r36/tile_basalt.png`（ctex） | 2.329 | 1254×1254 | 5.999 |
| `assets/art/r34/world_map.png`（ctex） | 2.159 | 1672×941 | 6.002 |
| `assets/art/r33/r33_keyart.png`（ctex） | 2.147 | 1672×941 | 6.002 |
| `assets/art/r38/tile_desert.png`（ctex） | 2.141 | 1254×1254 | 5.999 |
| `assets/art/r38/tile_clockwork.png`（ctex） | 2.067 | 1254×1254 | 5.999 |
| `assets/sprites/true_character_atlas.png`（ctex） | 1.709 | 512×3712 | 7.250 |
| `assets/sprites/r38_character_atlas.png`（ctex） | 1.523 | 2048×2048 | 16.000 |

## 優先縮減，保留原畫

1. **先停止封面後方的主選單世界背景初始化。** `main_menu.gd:120` 建立 R36 背景，會載入 tile_stone＋landmarks 共 12.00 MiB RGBA，前方已覆蓋全頁 keyart。主選單三張 texture 合計 18.00 MiB。可先只在遊戲場景建立地形；不需要改原圖或動畫。
2. **合併啟動封面入口。** `r33-web-focal.png`、`index.png` 與 inline base64 像素 SHA 完全相同。HTML 的 inline image 有 3,784,676 字元／2,838,505 原始 bytes；若以 UTF-16 字串估算最多 7,569,352 bytes，實際 JS 引擎可用其他表示法。HTML 共 3,802,097 bytes。單張 1672×941 圖 RGBA 約 6.00 MiB；data URI、外部 URL 與 Godot GPU 貼圖可能各自持有副本，這裡不假設瀏覽器一定合併。先採單一 URL／單一 overlay，保留 progress、error/retry、service worker cache key。
3. **取消歷史 atlas 的 eager prewarm。** `true_character_atlas.png` 512×3712、7.25 MiB RGBA、PCK 1.709 MiB，只有 SpriteLoader prewarm 與 debug 舊測試直接引用；目前 TrueAnimationLibrary 正式使用 R35/R38。先移除 prewarm，再經依賴檢查決定 runtime export 排除；原檔保留。
4. **給 SpriteLoader cache 分組／期限。** static `texture_cache` 對載入圖片保留強引用。MainMenu、WorldMap、七地形、兩地標完全走過，可把約 66 MiB 圖像跨場景留住；關閉舊場景後解除 menu/map/stage texture cache，保留共享角色與 FX 群組。不能把七张terrain當 unused，動態 ROOT+路徑確實在 runtime 使用。
5. **素材匯入層做手機地形限尺寸。** 七地形 1254→768 同內容 runtime derivative：RGBA 41.99→15.75 MiB，減 26.24 MiB；1254→512 則 7.00 MiB，減 34.99 MiB。兩個地標 1774×887→887×444 約 12.01→3.00 MiB，減約 9 MiB。原始 PNG／生成來源／簽章不得改寫；只調 Godot 匯入或建立有 lineage 的 runtime tier。要實畫確認，不承諾低解析細節一定足夠。
6. **角色／技能 atlas 使用可替換 tier，不能只改 size_limit。** TrueAnimationLibrary 的 cell128、Captain combo160／origin3712，以及 FX cell256 都是固定 region 座標。直接縮 `.ctex` 會讓 AtlasTexture region 越界、角色變小或缺格。必須依實際 texture 尺寸等比例算 region，並把 PlayerVisual／FX 顯示比例反向補償，保持目前世界尺寸、body readability、144 個來源姿勢、27 playback timing、真 F2、hurt/death 和 collider。
7. **拆下載資源群組。** boot pack 僅 menu/UI/font；進場再載共用角色／FX與選定 terrain/props，新增 R38 actor pack 可於對應世界／招募前載入。WASM 37.68 MiB仍是獨立成本。現行 all_resources會一次下載全部地形，即使解碼是lazy。Split pack成本需另做PWA快取、offline、轉場與缺資源 gate。

## Tier 容量草案（純 RGBA 算式，不是匯出大小預測）

| 群組 | 現行 | 中階草案 | 較低草案 |
|---|---:|---:|---:|
| R35 角色 | 2048×4032：31.50 MiB | 1536×3024：17.72 MiB | 1024×2016：7.875 MiB |
| R38 角色 | 2048²：16 MiB | 1536²：9 MiB | 1024²：4 MiB |
| FX | 2048²：16 MiB | 1024²：4 MiB | 1024²：4 MiB |
| 合計 | 63.50 MiB | 30.72 MiB（省32.78） | 15.875 MiB（省47.625） |

需用 capability-aware 手機 VRAM 壓縮與實機可用 fallback；現行 export `for_mobile=false`，不應直接宣稱 ASTC/ETC 已可用。這輪沒有試驗或改匯入。

## 其他配置與匯出問題

- EntityFactory 入場預建 1,836 個池節點；單一 enemy/projectile scene 各含多個子節點。這是初始物件数量，無法僅靠檔案推算實際 heap bytes。Root 可先調手機池預熱而保留 hard caps／必要 attack/death pose 流程；此輪沒執行遊戲。
- prewarm 44 個路徑中有 10 個 R24 圖片被 export exclude 排除、PCK zero entries；目前只能產生找不到圖的警告，不能計成已載入 GPU 圖。移除無效 prewarm 可減冗餘載入；仍引用這些路徑的武器視覺需要先確認替代素材，避免把缺圖忽略為通過。
- Raw source masters 與 qa sheets 在 current PCK 都為 0 entries：R38 sources、R35 sources、R34 sheets、R36 pet original 已有 export exclude，不能宣稱這些仍造成 current PCK 大包。主要「歷史未用資源」候選是被 eager prewarm 的 true_character_atlas，以及僅社群使用的 cover、舊背景圖，需依賴 gate後排除。
- `cover.png` 是 OG/分享圖，1280×640／0.446 MiB PNG；不需作為遊戲貼圖 eager decode。包內 ctex0.422MiB 可考慮排除，保留網站公開分享PNG。

## 證據與界線

`asset_budget_baseline.json` 含全部651 entries、134 ctex的pack offset／bytes／尺寸／對應PNG／import模式及top15；`runtime_references.json` 記錄直接字串引用與44 prewarm路徑；`alloc_summary.json` 含WASM memory section與pool配置；`package_groups.json` 分群。
RGBA8＝寬×高×4。不含 mipmaps、driver padding、GPU/CPU多份副本、WASM編譯器、framebuffer或JS DOM資源。所有容量為來源碼／封裝讀值與算式，尚不能把iPhone14無法進入的原因裁定成OOM，也不假稱已通過iPhone實機。

## 已完成的限定調整

- `scripts/services/sprite_loader.gd`：prewarm 44 → 33 個小型核心路徑，移除歷史 true_character_atlas 與十個 export 已排除的 R24 路徑。
- `scripts/ui/main_menu.gd`：手機使用現有 MobileTuning 判定；`MenuBackground` Node2D 名稱與 z-index 保留，但不安裝被封面遮住的地形腳本；桌機分支維持原設定。
- 以下 11 份 `.png.import` 只改 `compress/mode=1`、quality 和 size_limit；seven terrain quality0.88/1024，two landmarks quality0.90/1024，keyart與world_map quality0.90/1536。未使用 VRAM/Basis 壓縮。

| 素材 | 原 ctex KiB | 新 ctex KiB | 尺寸：原 → 新 |
|---|---:|---:|---|
| `assets/art/r36/tile_stone.png.import` | 3129.9 | 532.9 | 1254×1254 → 1024×1024 |
| `assets/art/r36/tile_grass.png.import` | 3187.4 | 598.0 | 1254×1254 → 1024×1024 |
| `assets/art/r36/tile_basalt.png.import` | 2384.4 | 299.6 | 1254×1254 → 1024×1024 |
| `assets/art/r36/tile_frost.png.import` | 2916.0 | 496.9 | 1254×1254 → 1024×1024 |
| `assets/art/r38/tile_desert.png.import` | 2192.1 | 328.5 | 1254×1254 → 1024×1024 |
| `assets/art/r38/tile_coral.png.import` | 2698.6 | 459.4 | 1254×1254 → 1024×1024 |
| `assets/art/r38/tile_clockwork.png.import` | 2117.0 | 301.9 | 1254×1254 → 1024×1024 |
| `assets/art/r36/landmarks.png.import` | 2515.8 | 430.9 | 1774×887 → 1024×512 |
| `assets/art/r38/landmarks.png.import` | 1479.8 | 252.3 | 1774×887 → 1024×512 |
| `assets/art/r33/r33_keyart.png.import` | 2198.5 | 422.0 | 1672×941 → 1536×864 |
| `assets/art/r34/world_map.png.import` | 2210.5 | 441.9 | 1672×941 → 1536×864 |

實際重建後 11 份 ctex 合 26.396 → 4.457 MiB，減 21.939 MiB；base RGBA 66.000 → 42.125 MiB，減 23.875 MiB。含原有 mipmaps 的估計 75.999 → 48.125 MiB。

這是本機 `.ctex` 真實 bytes／尺寸；最終 PCK 大小待重新匯出後讀取，不把相减預估當成已匯出的成果。Import rebuild exit0、無 SCRIPT ERROR。11 個 PNG 的 SHA-256逐一不變；R35角色／R38角色／FX三組 PNG與import SHA亦逐一不變。原本4×2地標切格與scale都採actual texture／region dimensions，新1024×512仍符合布局；需要實際畫面檢查lossy色彩／alpha邊緣。
完整metadata在 `import_budget_before.json` 與 `import_budget_after.json`。Legacy EnemyArt 原測試仍硬斷言歷史atlas預載，已通知改成驗真正正式Atlas／SpriteFrames；本輪沒有改未授權的測試，也沒有放寬姿勢或F2契約。
