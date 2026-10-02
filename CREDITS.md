# Third-party credits and licenses

Crackveil Vanguard 的程式與專案自有內容採根目錄 [MIT License](LICENSE)。下表盤點 repo 中實際使用的第三方字型、字集與素材；未列於表內的遊戲美術與程序產生音效為本專案製作內容。

## 授權總表

| 項目 | 來源 | 授權 | 專案用途 |
| --- | --- | --- | --- |
| Noto Sans CJK TC Regular（Sans 2.004） | [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk/tree/Sans2.004/Sans/OTF/TraditionalChinese) | [SIL Open Font License 1.1](assets/fonts/OFL.txt) | 經 fontTools 子集化為 `assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf`，供所有繁中 UI 使用。 |
| 3000+ traditional hanzi | [agj/3000-traditional-hanzi `notes.tsv`，pinned commit `855200d`](https://github.com/agj/3000-traditional-hanzi/blob/855200d72670b8053096b6d706906d2cad265dbe/output/notes.tsv) | [MIT](https://github.com/agj/3000-traditional-hanzi/blob/855200d72670b8053096b6d706906d2cad265dbe/LICENSE) | `tools/build_font_subset.py` 取前 2,800 字作繁中字型安全集；輸出字集記錄於 `.chars.txt`。 |
| pixel-idle-farm-skill | [mars-tw/pixel-idle-farm-skill](https://github.com/mars-tw/pixel-idle-farm-skill) | [MIT](https://github.com/mars-tw/pixel-idle-farm-skill/blob/main/LICENSE) | 廢土農野 ground 與部分 farm decor 經裁切／改色後置於 `assets/art/decor/`。 |
| Kenney Particle Pack | [Kenney Particle Pack](https://kenney.nl/assets/particle-pack) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 12 張火焰、電弧、煙環、光斑與衝擊波來源圖，裁切並調色為 `assets/vfx/kenney_particle/`。 |
| Kenney Impact Sounds | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | `hit.wav`、`kill_thump.wav`。 |
| Kenney Sci-Fi Sounds | [Kenney Sci-Fi Sounds](https://kenney.nl/assets/sci-fi-sounds) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | `explosion.wav`、`fire.wav`。 |
| Kenney Digital Audio | [Kenney Digital Audio](https://kenney.nl/assets/digital-audio) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | `pickup.wav`、`upgrade.wav`。 |
| Kenney UI Pack | [Kenney UI Pack](https://kenney.nl/assets/ui-pack) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 僅使用 `tap-b.ogg` 衍生的 `ui_click.wav`；未散布該包 UI 圖像。 |
| Top Down Cultist Creature（Sean Noonan） | [OpenGameArt](https://opengameart.org/content/top-down-cultist-creature) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | `enemy_grunt.png` 與對應逐幀姿勢的來源。 |
| Top Down Tentacle Creature（Sean Noonan） | [OpenGameArt](https://opengameart.org/content/top-down-tentacle-creature) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | `enemy_tank.png`、`enemy_boss.png` 與對應逐幀姿勢的來源。 |
| Animated Walk-Cycle Monsters + Hijabi from Eman Quest（Night Blade） | [OpenGameArt](https://opengameart.org/content/animated-walk-cycle-monsters-hijabi-from-eman-quest) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | `enemy_fast.png`、三種 elite 敵人與對應逐幀姿勢的來源。 |

## R35 專案自製資產

- `assets/art/r35/captain_combo_sheet*.png`：內建 imagegen 製作的 18 個原創隊長動作；機械排版追加於 `assets/sprites/r35_character_atlas.png`，保留原圖集全部像素。來源與排版資料見 `docs/evidence/r35/captain_combo_atlas.json`。
- `assets/art/r35/sources/`：八種技能／攻擊特效共 64 幀的原始透明圖、提示詞及來源記錄；Godot Image 只做裁切、尺寸整理與排版，輸出 `r35_skill_fx_atlas.png`。詳細紀錄見同目錄及 `assets/art/r35/qa/`。
- `assets/audio/critical_impact.wav`：本專案原創程序音效，由 `tools/build_critical_impact_audio.py` 生成低頻撞擊、短噪訊與金屬尾音，44.1 kHz、16-bit mono、0.18 秒。

## R34 專案自製資產

- `assets/art/r34/` 的六張角色／魔物姿勢原圖、局部修正版、六個戰場與世界地圖，皆由 Codex 內建 imagegen 製作。原始檔、提示詞及 SHA-256 保留於素材目錄與 `docs/evidence/r34/`。
- 遊戲使用 `assets/sprites/r34_character_atlas.png`。17 種角色各有 12 個姿勢欄位；其中 E 圖三種魔物各使用 11 個不同原畫，另一次步伐複用。27 格是播放時序，不代表 27 張不同原畫。
- Atlas 只做原 RGBA 連通元件分離、等比尺寸整理與排版。牧者準備姿勢單獨取用修正版的單杖元件，其餘 D 圖 35 個姿勢沿用原圖。提取與逐姿勢來源記錄見 `docs/evidence/r34/atlas_preparation.json`。
- 既有 CC0 魔物圖檔仍保留作歷史與設定路徑相容；R34 的角色／魔物畫面由新 Atlas 提供。

## R33 專案自製資產（歷史）

- `assets/sprites/r33_character_atlas.png`：原創 cel 造型與逐格關節姿勢，由 `scripts/services/r33_sprite_painter.gd` 與 Godot 原生烘焙產生，17 種角色／魔物各 27 格。
- `assets/art/r33/` 的地面與道具 SVG：本專案原創、可重建的動漫遺跡材質與裝飾。
- `assets/art/r33/r33_keyart.png`：本次使用 Codex 內建 imagegen 製作的原創動漫四人主視覺；提示詞與來源記錄見 `docs/evidence/r33/art/r33_keyart_prompt.txt`。

## R36 環狀世界與寵物素材

- `assets/art/r36/` 四種無縫手繪地面與八處透明地標為本專案新製素材；原始圖、提示詞、衍生檔與 SHA-256 記錄於該目錄的 `source_manifest.json`、`README.md`。
- `assets/pets/r36/pet_atlas.png` 是狐狸、羽鷹、靈兔共 36 個原始姿勢的整理圖集。原畫由內建 imagegen 製作，來源與提示詞、每個動作的裁切位置保存在 `pet_sheet_original.png`、`pet_sheet.prompt.txt`、`pose_manifest.json`。
- 原始大圖保留於本機來源目錄，Web 匯出只使用實際播放圖集與地景素材；未取用《暗黑破壞神》的角色、地圖或特效。

## R24 專案自製視覺資產（歷史）

- `assets/art/r24/` 的 8 張環刃／迴旋刃與 VFX、2 張主選單 key art 為本專案 cv R24 製作內容，不是第三方素材。
- 原畫模型 slug：`gpt-image-2`（內建介面 PNG provenance：`gpt-image/2.0`）；去背／修邊 slug：`local-pilot-matte-decontamination-v1`，依 `VISUAL_REFRESH_PILOT` 的 Wave 0 校準管線執行。
- Key art 的 Captain、Orbit Guard、Rift Sniper 身份只以 R21 Hyper3D Rodin → Blender 三視圖渲染為 reference；模型僅負責氣氛與構圖，未替換 R21 角色 atlas 或動畫契約。
- 完整 prompt、opaque master、mask、RGBA master、hash、alpha／亮度／飽和 gate 與實機證據保存在 `docs/evidence/R24_art/`。

## R25 裂隙先鋒視差場景

- `assets/art/r25/parallax/` 的三個戰場、各遠／中／近三層共九層，為本專案 Wave 2 R25 製作內容，不是第三方素材。
- 原畫模型 slug 為 `gpt-image-2`；九份 PNG master 皆保留內嵌 C2PA，`c2pa-python` 驗證 `softwareAgent=gpt-image 2.0`、claim signature 與 data hash 有效。
- 中／近景以 imagegen skill 色鍵工具去背；runtime 以固定 LANCZOS、亮度／飽和度與 WebP quality 86 管線輸出。完整 prompt、style board、master、C2PA JSON、來源與 runtime SHA-256、逐步後製紀錄位於 `docs/evidence/R25/` 與 `assets/art/r25/parallax/manifest.json`。
- `r25_boot_splash.png` 與 `r25_web_focal.webp` 是上述三層裂隙虛空素材的可重建衍生檔；Web focal 使用 `?v=48393809` 並列入 R25 PWA 離線快取。

## 衍生與重建說明

- 字型由 `python tools/build_font_subset.py` 重建；上游版本與字集 commit 都固定於腳本。
- Kenney VFX／音效由 `python tools/process_m3_assets.py` 產生；轉為遊戲所需尺寸、色盤與 44.1 kHz / 16-bit mono WAV。
- OpenGameArt 敵人由 `python tools/process_enemy_cc0_assets.py` 重建；來源逐幀裁切、描邊、調色並置入共用角色 atlas。
- 上游原始包位於被忽略的 `tools/asset_sources/`，不隨 repo 或 Web build 散布。
- 每個上游檔名、輸出檔與既有 SHA-256 的詳細對照保留於 [assets/CREDITS.md](assets/CREDITS.md)。

CC0 素材依法不要求署名，但本專案保留作者、來源與修改紀錄，以方便稽核及後續維護。
