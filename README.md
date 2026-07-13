# Crackveil Vanguard

![cover](assets/art/cover.png)

Crackveil Vanguard 是一款 Godot 4.x / GDScript 製作的 2D squad-survivors roguelite 原型。玩家操作裂隙隊長與小隊，在競技場中移動、升級武器、收集經驗與金幣，並盡可能撐過敵潮。

## 線上遊玩

預定 GitHub Pages 網址：

https://mars-tw.github.io/crackveil-vanguard/

Web 版使用 Godot 4.7 單執行緒 HTML5/WebAssembly 匯出，避免 GitHub Pages 無法設定 COOP/COEP headers 時造成 SharedArrayBuffer 啟動失敗。

## 特色

- 單主控角色加小隊跟隨。
- 多種武器資料資源與武器場景。
- 敵人生成、投射物、爆炸區域、連鎖閃電與環繞武器。
- XP、升級、HUD、暫停與遊戲結束 UI。
- 物件池、sprite loader 與基本壓力測試場景。
- 桌機鍵盤與行動虛擬搖桿輸入。

## 本機執行

1. 安裝 Godot 4.x。
2. 用 Godot 開啟 `project.godot`。
3. 按 `F5` 執行主場景 `res://scenes/arena/Arena.tscn`。

## Web 匯出

本 repo 內含 `export_presets.cfg`，preset 名稱為 `Web`，並設定：

- `platform="Web"`
- `variant/thread_support=false`
- `export_path="export/web/index.html"`

PowerShell 範例：

```powershell
$godot = "$env:LOCALAPPDATA\Temp\codex-godot-4x\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
New-Item -ItemType Directory -Force -Path "export/web" | Out-Null
& $godot --headless --export-release "Web" "export/web/index.html"
```

匯出後可用靜態伺服器測試：

```powershell
Push-Location export/web
python -m http.server 8067
```

再開啟 `http://127.0.0.1:8067/`。

更完整的 Web 匯出與部署紀錄見 [docs/WEB_EXPORT.md](docs/WEB_EXPORT.md)。

宣傳與商店頁文案素材見 [PRESSKIT.md](PRESSKIT.md)。

## GitHub Pages 部署

採 GitHub Actions 匯出部署。`.github/workflows/deploy-web.yml` 會在 CI 下載 Godot 4.7 與官方 export templates，匯出 Web build 到 `public/`，加入 `.nojekyll`，再透過 Pages artifact 部署。

總稽核接手時需要：

1. commit 本次匯出設定、workflow 與文件。
2. 在 GitHub repo Settings > Pages 將 Source 設為 GitHub Actions。
3. push 到 `main` 或手動觸發 `Deploy Web` workflow。

## 操作

- `WASD`：移動。
- `P` / `Esc`：暫停或繼續。
- 行動裝置：使用畫面上的虛擬搖桿。

## 專案結構

```text
assets/       Sprite 與 atlas 圖檔
docs/         稽核、匯出與部署文件
resources/    Hero、Squad、Weapon 資源
scenes/       Arena、角色、敵人、投射物、UI、武器與測試場景
scripts/      GDScript 遊戲邏輯、autoload、服務與 UI
```

## 字型

Web 版內嵌 `assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf`，由 Noto Sans CJK TC Regular 子集化產生，用於繁體中文 UI。Noto Sans CJK 採 SIL Open Font License 1.1，授權文字見 `assets/fonts/OFL.txt`。

## R12 特色

- 本局地圖主題依 run seed 決定，包含「裂隙虛空」、「廢土農野」、「餘燼裂原」三種視覺。
- 玩家小隊移動時有交替步伐傾斜、小跳步、腳下步塵與低音量腳步 tick；敵人保留輕量交替步相位。
- 地圖加入 seed 決定性 decor 散佈、裂隙脈衝、遠景裂隙閃電、植物微晃與偶發流星/碎片。

## 素材 Credits

- 廢土農野地形與部分 decor 裁切/改色自同作者 MIT 開源專案 `pixel-idle-farm-skill` 的農場像素素材；本 repo 僅收錄 R12 需要的小裁片，不包含原始大型 atlas。
- M3 VFX 與實體音效精選自 Kenney Particle Pack、Impact Sounds、Sci-Fi Sounds、Digital Audio 與 UI Pack，均為 CC0 1.0；成品僅收錄 12 張 128px 主題色衍生紋理與 7 個 44.1kHz/16-bit/mono WAV。
- 完整來源連結、逐檔替換表、修改方式與授權聲明見 [`assets/CREDITS.md`](assets/CREDITS.md)。

## License

MIT License. See [LICENSE](LICENSE).
