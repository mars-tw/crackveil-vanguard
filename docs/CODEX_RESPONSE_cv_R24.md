# Crackveil Vanguard cv R24 — Wave 1 視覺量產交付報告

## 結論

cv R24 已完成並通過放行閘門。交付包含 8 張環刃／迴旋刃 RGBA、2 張 1920×1080 主選單 key art、武器與選單 runtime 接線、完整來源／mask／master／hash manifest、CREDITS、before/after 與測試證據。版本為 `0.17.1-r24`。R21 角色圖集與動畫契約未變更。

## 1. 武器與 VFX 可讀性組

最終 runtime 圖均為 256×256 RGBA，配色鎖定骨白、暖琥珀與深梅色；冷青比例為 0，避免在冷藍場景中消失。環刃縮放由 `1.56` 降到 `1.09`（縮小 30.1%），迴旋刃由 `1.62` 降到 `1.18`（縮小 27.2%）。

| 類別 | 資產 | 接線 |
| --- | --- | --- |
| 主刃 2 | `weapon_main_blade_a/b` | 依 orbit index 交替顯示 |
| 遠刃 2 | `weapon_far_blade_outbound/return` | 飛出／回程切換圖 |
| impact 2 | `vfx_orbit_impact`、`vfx_boomerang_impact` | 僅在 active hitbox 成功呼叫傷害後生成 |
| trail 2 | `vfx_orbit_trail`、`vfx_boomerang_trail` | 獨立 Sprite2D 視覺子節點，不改 physics root／collider |

接線位置：`resources/weapons/orbit_blades.tres`、`resources/weapons/rift_shield_boomerang.tres`、`scripts/projectiles/orbit_projectile.gd`、`scripts/projectiles/projectile.gd`、`scripts/vfx/death_burst.gd`。

### 人工修邊實際工時

Wave 0 matte pipeline 的 raw 輸出在嚴格 alpha gate 僅 1/8 直接通過，因此逐張做互補色污染重繪、alpha 收邊與深／淺／棋盤背景復檢。實際人工時間如下；總計 15.8 分鐘，不以 10–25 分鐘預算回填。低於難類預算的原因是本批 prompt 已拆成 hard-core/no-fog，並沿用校準後的可重複修邊工具。

| 資產 | 分類 | 實際分鐘 |
| --- | --- | ---: |
| weapon_main_blade_a | weapon | 1.2 |
| weapon_main_blade_b | weapon | 1.2 |
| weapon_far_blade_outbound | weapon | 1.4 |
| weapon_far_blade_return | weapon | 1.4 |
| vfx_orbit_impact | VFX 難類 | 2.5 |
| vfx_boomerang_impact | VFX 難類 | 2.1 |
| vfx_orbit_trail | VFX 難類 | 3.0 |
| vfx_boomerang_trail | VFX 難類 | 3.0 |

逐張紀錄見 `docs/evidence/R24_art/manual_retouch_log.json`，四背景修邊圖見 `docs/evidence/R24_art/manual_qa/`。

## 2. 主選單 key art

- Desktop：1920×1080，左 34% 為 UI 低細節安全區，三人與裂隙焦點在右側。
- Mobile-safe：1920×1080 source，`TextureRect` 以 portrait aspect ratio 切換；390×844 實機裁切讓控制列落在深色區，三人身份輪廓位於控制列下方。
- 身份鎖定參考：R21 Rodin → Blender 的 Captain、Orbit Guard、Rift Sniper renders；`gpt-image-2` 僅負責氣氛與構圖的 B 流。
- 執行期接線：`scripts/ui/main_menu.gd`；窄版桌機視窗亦依 portrait aspect ratio 使用 mobile-safe 圖，不依觸控裝置判定。

模型與管線 slug 已寫入 `assets/art/r24/manifest.json`：

- generation requested/actual：`gpt-image-2`
- PNG provenance：`gpt-image/2.0`
- background removal：`local-pilot-matte-decontamination-v1`
- calibration：`wave0-calibration-v1.1`

完整 prompt 記錄：`docs/evidence/R24_art/prompts/R24_PROMPTS.md`。

## 3. 雙閘門與檔案契約

- Final alpha：master 8/8、runtime 8/8 通過；透明像素 RGB 歸零，邊緣互補色污染通過。
- 亮度／飽和度／冷青 palette：8 張 cutout＋2 張 key art 共 10/10 通過。
- Key art：兩張均為 1920×1080 RGB PNG；390×844 mobile crop 通過。
- Manifest：包含 opaque source、normalized opaque、mask、RGBA master、runtime、prompt id、人工分鐘與 SHA-256。
- CREDITS：`CREDITS.md` 與 `assets/CREDITS.md` 已更新；本輪為專案自製資產，非第三方授權包。

總表：`docs/evidence/R24_art/release_gate_summary.json`；色彩／alpha 細項：`docs/evidence/R24_art/art_gate_summary.json`。

## 4. 回歸與發行閘門

| 閘門 | 結果 |
| --- | --- |
| Godot 4.7 editor import／script parse | exit 0 |
| R14RegressionTest | exit 0，`R14_REGRESSION_PASS`；另鎖定 cutouts=8、keyart=2、縮放 1.09/1.18 |
| TrueAnimationRegressionTest | exit 0，`TRUE_ANIMATION_REGRESSION_PASS` |
| WeaponSmokeTest | exit 0，`WEAPON_SMOKE_PASS` |
| Web export `Web` | exit 0，`index.html/.pck/.wasm` 成功產出 |
| 秘密掃描 | 0 命中 |
| R21 契約 guard | 0 變更路徑 |
| `git diff --check` | exit 0 |

測試原始輸出位於 `docs/evidence/R24_art/gates/`。

## 5. Before / after 證據

Before：

- `docs/evidence/R24_art/before/main_menu_r23_1920x1080.png`
- `docs/evidence/R24_art/before/proj_blade_r23.png`
- `docs/evidence/R24_art/before/weapon_battle_r21_reference.png`

After：

- `docs/evidence/R24_art/after/main_menu_r24_1920x1080.png`
- `docs/evidence/R24_art/after/main_menu_r24_390x844.png`
- `docs/evidence/R24_art/after/weapon_battle_r24_1920x1080.png`
- `docs/evidence/R24_art/after/menu_keyart_mobile_390x844_crop.png`

瀏覽器實機稽核紀錄：`docs/evidence/R24_art/browser_audit.json`。

## 6. 範圍保護

本輪沒有修改 R21 Rodin／Blender 來源、runtime character atlas、角色動作資料或 TrueAnimation 契約；武器 trail 與 impact 都是 visual child，physics root 與 collider 保持分離。傷害仍由既有 active hitbox 觸發，impact 不會在輸入按下時提早出現。
