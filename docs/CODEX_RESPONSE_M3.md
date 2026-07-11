# CODEX response — M3 免費開源素材升級

## 結論

M3 完成。這次不是全盤換皮，而是把預算集中在最有感的 VFX 與高頻
SFX：原本單張、漫畫式的爆炸星形已移除，改為 Kenney Particle Pack
裁切出的火焰、電弧、煙環、光斑、光柱與衝擊環；擊中、擊殺、爆炸、
開火、拾取、升級、UI click 改為 Kenney CC0 錄製／設計音效。角色維持
現有專案專屬風格，UI 視覺也維持深色裂隙 Theme。

Web `index.pck` 從 **4,458,248 bytes** 增至 **4,625,856 bytes**，增量
**167,608 bytes（0.160 MiB）**，只使用 1.5 MiB 預算約 10.7%。

## 選材與實際整合

### VFX：Kenney Particle Pack 1.1（CC0）

從透明版 193 張 PNG 中選 12 張不同來源，逐張 alpha crop、縮到
128x128，並做裂隙青／餘燼橘雙色階。成品位於
`assets/vfx/kenney_particle/`：

| 遊戲用途 | 裂隙青 | 餘燼橘 |
| --- | --- | --- |
| 一般死亡／爆炸主體 | `burst_fire_cyan.png` | `burst_fire_ember.png` |
| 火花／雷擊死亡 | `burst_arc_cyan.png` | `burst_arc_ember.png` |
| 煙環／飛彈消散 | `smoke_ring_cyan.png` | `smoke_ring_ember.png` |
| 金雨／拾取光斑 | `flare_cyan.png` | `flare_ember.png` |
| 升級／Echo 光柱 | `level_column_cyan.png` | `level_column_ember.png` |
| 爆炸第二層衝擊環 | `shockwave_cyan.png` | `shockwave_ember.png` |

整合方式：

- `DeathBurst` 仍由既有 pool acquire/reset/release；只依 `burst_style` 與
  原事件色彩切換預熱紋理，沒有新增臨時 VFX node。
- `ExplosionArea` 仍使用既有 explosion pool；主爆雲外加一個常駐於池
  節點內的 shockwave Sprite2D，reset 時只換 texture／visible／scale。
- `SpriteLoader.GAMEPLAY_PREWARM_PATHS` 收入 12 張素材；Stress 的量測期
  texture cache 固定為 99，沒有 first-use texture spike。
- 舊 `assets/sprites/fx_explosion.png` 已刪除，所有 weapon／測試 fallback
  已切到新主題紋理。

### 音效：Kenney CC0

所有選用 OGG 都裁掉靜音／長尾、加 6ms 邊界 fade、peak normalize，並
輸出為 **44.1kHz、16-bit、mono PCM WAV**：

| 遊戲檔 | Kenney 原檔 | 來源包 | 長度 |
| --- | --- | --- | ---: |
| `hit.wav` | `impactGeneric_light_002.ogg` | Impact Sounds | 0.140s |
| `kill_thump.wav` | `impactPunch_heavy_002.ogg` | Impact Sounds | 0.324s |
| `explosion.wav` | `explosionCrunch_000.ogg` | Sci-Fi Sounds | 0.762s |
| `fire.wav` | `laserSmall_000.ogg` | Sci-Fi Sounds | 0.239s |
| `pickup.wav` | `highUp.ogg` | Digital Audio | 0.388s |
| `upgrade.wav` | `powerUp1.ogg` | Digital Audio | 0.976s |
| `ui_click.wav` | `tap-b.ogg` | UI Pack | 0.056s |

- `AudioManager` 的 12-player pool、音量／pitch clamp、Web unlock 與原有
  cooldown 均保留。
- 新增 `explosion=0.11s`、`ui_click=0.035s` 節流；爆炸 pitch 只依 radius
  做 0.82–1.18 的小範圍變化。
- 所有 `BaseButton` 在非 headless runtime 自動接低音量 `ui_click`，不用
  每個 UI screen 各自複製播放碼。

### UI 與角色的美術指導判斷

- 有實際下載、解壓並檢視 UI Pack 2.0。其高亮藍／綠／紅膠囊與白底
  斜面更像休閒工具 UI，換上會削弱現有深藍玻璃面板、青色描邊與紫色
  pressed state 的裂隙語言，因此**不替換 UI 視覺**；只採用 click 音。
- Kenney Top-down Shooter 與現有專案專屬角色的比例、描線與材質不同；
  依任務原則**角色完全不動**，也不為了增加 credit 而硬塞風格不合素材。

## 授權留檔

完整逐檔來源、上游授權聲明與修改方式已寫入 `assets/CREDITS.md`，README
也新增總 credit 與連結。採用來源全部為 Kenney CC0 1.0：

- Particle Pack: <https://kenney.nl/assets/particle-pack>
- Impact Sounds: <https://kenney.nl/assets/impact-sounds>
- Sci-Fi Sounds: <https://kenney.nl/assets/sci-fi-sounds>
- Digital Audio: <https://kenney.nl/assets/digital-audio>
- UI Pack: <https://kenney.nl/assets/ui-pack>
- CC0 1.0: <https://creativecommons.org/publicdomain/zero/1.0/>

官方 zip 與內附 `License.txt` 保留在本機
`tools/asset_sources/`；該目錄已列入 `.gitignore`。另加 `tools/.gdignore`，
避免 Godot 無視 git ignore 而把 1,800 多個原始素材錯掃進資源資料庫／pck。
Repo 只分發 12 張處理後 PNG 與 7 個 WAV。

處理流程可由 `tools/process_m3_assets.py` 重建，沒有把來源 zip 或大型 atlas
放進 `assets/`。

## 前後視覺描述

### 前

- 爆炸與死亡共用單張尖角放射的橘黃漫畫星形，輪廓硬、層次單一。
- cyan／purple 技能只是把橘色圖 tint，容易有顏色混濁與「同一貼圖反覆
  放大」的感覺。
- 粒子核心是程序生成 soft dot；爆炸、煙、魔法、火花無材質差異。

### 後

- 餘燼系使用有空洞、碎屑與亮芯的爆雲；裂隙系使用青色電弧、霧環與
  白熱光柱，不再只是改色同一張星形。
- 爆炸為「有機爆雲 + 擴張 shockwave + 原有 radial glow」三層，短生命
  內仍清楚，但不留下滿場長尾。
- spark、smoke_ring、gold_rain、level_column 各有可辨識 silhouette；
  顏色仍由原 gameplay event 決定暖／冷派系。
- 內建瀏覽器實際驗證 1280x720 Web build：主選單、首次教學、契約選擇、
  實戰與新的餘燼爆裂均正常顯示，繁中與既有角色沒有被替換。

## 回歸

### 完整矩陣

下列 **19 檔全部 PASS，exit 0**：

- M1、M2、M3 Regression。
- R5、R6、R7、R10_5、R11、R12、R13、R14 Regression。
- PoolContract、GameplayCap、MobileInputSmoke。
- WeaponSmoke、SquadSmoke、OrbitBladeHitRepro。
- ArenaInstrumentationRun、BalanceMockRun。

M3Regression 額外驗證：12 張 VFX 皆為 128x128、全部進 texture prewarm；
7 個 WAV 皆可由 Godot 載入，且磁碟 RIFF header 為
44.1kHz／16-bit／mono；AudioManager 含 explosion／ui_click cue。

### Stress 兩檔

固定 seed `52002`、180 warm-up、411 measured frames：

| 情境 | M2 基準 p95 / max | M3 p95 / max | 結果 |
| --- | ---: | ---: | --- |
| Desktop 1280x720 | 14.552 / 24.282 ms | **14.574 / 23.058 ms** | PASS；p95 +0.022ms（0.15% 噪音範圍），max 改善 |
| Mobile LOD 390x844 | 14.949 / 24.338 ms | **13.940 / 21.437 ms** | PASS；p95/max 均改善 |

兩檔均為 150 enemies、80 background projectiles、9 人滿編、全武器／全
進化；`enemy_group_scans=0`，pool exhausted／duplicate release／foreign
release 全 0，所有預期 weapon trigger > 0。`STRESS_PERF_BELOW_60=true`
仍保留，因 max frame 仍高於 16.7ms；不宣稱每一幀達 60fps。

## Web 匯出

- Godot 4.7 `--headless --export-release Web export/web/index.html`：PASS。
- `node --check export/web/index.js`：PASS。
- 瀏覽器載入與進入實戰：PASS，無 `SCRIPT ERROR`。
- `export/web/index.pck`：**4,625,856 bytes**。
- HEAD M3 前基準：**4,458,248 bytes**。
- 增量：**167,608 bytes（0.160 MiB）**，小於 **1.5 MiB** 預算。

瀏覽器 console 仍會列出 repo 既存的 missing script `.uid` fallback warning；
Godot 會照文字 `res://` path 正常載入，這不是 M3 新資產錯誤，所有 headless
回歸與 Web 實戰均正常。
