# ui_hotfix r13 實作報告

版本：`v0.13.0-r14`（後續 hero10 release 統一版號）
日期：2026-07-14
目標：修復全 UI 控件互黏、CheckBox 內外距不足、簡報底部重疊，以及升級卡上半部空白。

## 根因

1. `MobileTuning.spacing_scale()` 雖已有 phone/tablet/desktop 三檔數值，但 `apply_control_tree()` 只套用字級與最小高度，完全沒有把 spacing scale 套到 `BoxContainer`、`GridContainer` 或 `CheckBox`。手機按鈕放大到 76px、字級放大到 1.96 倍後，容器仍保留 4–10px 舊間距，外框陰影把可見空隙吃光。
2. 全域 `default_theme.tres` 只定義 Button，沒有 `BoxContainer`/`GridContainer` separation，也沒有 CheckBox 專用 style、外框內距與圖示/文字間距。CheckBox 因而回退到 Button 外觀，勾選圖示緊貼列框。
3. 「裂隙先鋒簡報」以絕對座標分別擺放 CheckBox 與 Button；Web canvas 尺寸換算與觸控高度放大後，兩者缺少容器約束，會相貼甚至重疊。
4. 主選單與契約種子列的寬度計算硬編碼舊 8px gap；全域 gap 修正後若不連動，列寬會反被撐破 400px 上限。

## 改動

- 全域 Theme：新增 Box/Grid 12px 基準 separation；新增 CheckBox 專用 normal/hover/pressed/disabled style、12px 外框內距與 10px 圖示文字間距。
- `MobileTuning`：遞迴套用容器安全間距；desktop 至少 12px、tablet 依 1.12 倍取整、phone 依 1.32 倍取整；CheckBox 內部間距同步縮放。既有較大頁面 override 仍保留。
- 主選單、設定、暫停、結算 VBox 的明示 separation 統一至 12px；手機維持 76px touch target，tablet 44px。
- 簡報彈窗：CheckBox 與「開始行動」改放入 `VBoxContainer`，以 12–16px separation 排版，不再用兩組互不相關的絕對座標。
- 主選單與契約種子列：寬度公式納入實際 separation，維持 `<= 400px`。
- 升級三選一：使用既有 `icon_xp.png`、`icon_health.png`、`icon_gold.png`；卡片內容改為圖示、分類、標題、描述的分層版面，卡高收斂至 180–260px，消除上半部大片空白。
- 回歸：擴充 `R14RegressionTest`，在 1920×1080、1024×768、390×844 對主選單、設定、簡報、殘響、升級卡、裂隙商亭、契約、暫停列執行相鄰 Rect 不相交且 gap `>= 8px`；手機 touch target `>= 44px`；另驗證升級卡圖示存在。
- 新增 `tools/capture_ui_hotfix.mjs`，以本地 Playwright/Chrome 對 Godot WebGL canvas 產生三視口九張驗收圖。
- 版本目前統一為 `0.13.0-r14`、build date 為 `2026-07-14`。
- 未修改 `export_presets.cfg`，未碰角色動畫 runtime。

## 三視口截圖

| 視口 | 主選單 | 設定 | 裂隙先鋒簡報 |
|---|---|---|---|
| 1920×1080 | [1920x1080_main_menu.png](ui_hotfix_r13/1920x1080_main_menu.png) | [1920x1080_settings.png](ui_hotfix_r13/1920x1080_settings.png) | [1920x1080_briefing.png](ui_hotfix_r13/1920x1080_briefing.png) |
| 1024×768 | [1024x768_main_menu.png](ui_hotfix_r13/1024x768_main_menu.png) | [1024x768_settings.png](ui_hotfix_r13/1024x768_settings.png) | [1024x768_briefing.png](ui_hotfix_r13/1024x768_briefing.png) |
| 390×844 | [390x844_main_menu.png](ui_hotfix_r13/390x844_main_menu.png) | [390x844_settings.png](ui_hotfix_r13/390x844_settings.png) | [390x844_briefing.png](ui_hotfix_r13/390x844_briefing.png) |

肉眼驗收：三視口的主選單四個主按鈕與種子列均有可見空隙；設定四個 CheckBox 列互不相貼，圖示與文字有內距；簡報「不再顯示」與「開始行動」上下分離。手機主按鈕與勾選列高度均超過 44px。

## 測試結果

### Godot 4.7 UI / form-factor 回歸

命令：

```powershell
Godot_v4.7-stable_win64_console.exe --headless --fixed-fps 60 --path . scenes/debug/R14RegressionTest.tscn
```

結果：exit 0。

```text
R13_UI_SPACING viewports=1920x1080,1024x768,390x844 gap>=8 touch>=44
R14_REGRESSION_PASS
```

### 動畫鐵律保護回歸

命令：

```powershell
Godot_v4.7-stable_win64_console.exe --headless --fixed-fps 60 --path . scenes/debug/TrueAnimationRegressionTest.tscn
```

結果：exit 0。

```text
TRUE_ANIMATION_PLAYER impact_frame=2 duplicate_hits=0
TRUE_ANIMATION_ENEMY impact_delayed=true whiff_damage=0 hurt_knockback=true death_delayed=true lod=6/3/1.5/freeze shared_ticker=true
TRUE_ANIMATION_REGRESSION_PASS
```

### Web 匯出與本地站

- `--headless --export-release "Web" export/web/index.html`：exit 0。
- `node --check export/web/index.js`：PASS。
- HTTP：`index.html`、`index.js`、`index.wasm`、`index.pck` 全部 200。
- Playwright capture：`CAPTURE_PASS 1920x1080`、`CAPTURE_PASS 1024x768`、`CAPTURE_PASS 390x844`。
- 匯出產物：`index.pck` 5,665,976 bytes；`index.wasm` 39,509,339 bytes。

### 版本與安全

- 前一版 runtime 版號字串：零命中。
- `git diff -- export_presets.cfg`：空白，部署 preset 未變更。
- commit 前秘密掃描結果記錄於本次 commit 前檢查：排除 `.git` 後零命中。
