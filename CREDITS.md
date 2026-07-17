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

## R24 專案自製視覺資產

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
