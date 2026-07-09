# Web 匯出與 GitHub Pages 部署

本文記錄 Crackveil Vanguard 的 Godot 4.7 Web 匯出設定、Pages 相容策略與本機驗證結果。

## 方案選擇

- Thread Support：採用 A，`variant/thread_support=false`，也就是 Godot Web 單執行緒匯出。
- 理由：GitHub Pages 不能自訂 COOP/COEP response headers；Godot 多執行緒 Web build 需要 SharedArrayBuffer 與 cross-origin isolation。單執行緒 build 不需要 COOP/COEP，Pages 直接可跑。
- 部署方式：採用 A，GitHub Actions 匯出並部署 Pages artifact。repo 不 commit `.wasm`、`.pck`、`.js` 等匯出 binary。
- 其他 Web preset 重點：`vram_texture_compression/for_mobile=false`。Godot 4.7 若啟用此項但專案未配置 ETC2/ASTC 匯入，Web preset validation 會失敗。

## 本機工具與範本

- Godot console exe：`%LOCALAPPDATA%\Temp\codex-godot-4x\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe`
- Godot version：`4.7.stable.official.5b4e0cb0f`
- Export templates：`%APPDATA%\Godot\export_templates\4.7.stable`
- 官方 templates 來源：`https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_export_templates.tpz`

已安裝的 Web template：

```text
web_debug.zip
web_dlink_debug.zip
web_dlink_nothreads_debug.zip
web_dlink_nothreads_release.zip
web_dlink_release.zip
web_nothreads_debug.zip
web_nothreads_release.zip
web_release.zip
```

## 本機匯出指令

PowerShell：

```powershell
$godot = "$env:LOCALAPPDATA\Temp\codex-godot-4x\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
New-Item -ItemType Directory -Force -Path "export/web" | Out-Null
& $godot --headless --export-release "Web" "export/web/index.html"
```

## 本機產出檔案

`export/web` 產出如下：

```text
index.audio.position.worklet.js     2,973 bytes
index.audio.worklet.js              7,298 bytes
index.html                          5,305 bytes
index.js                          279,815 bytes
index.pck                        1,602,176 bytes
index.png                          21,443 bytes
index.wasm                      39,509,339 bytes
```

`index.html` 內確認：

```text
GODOT_THREADS_ENABLED = false
ensureCrossOriginIsolationHeaders = false
fileSizes: index.pck=1602176, index.wasm=39509339
```

## 本機靜態伺服器驗證

PowerShell：

```powershell
Push-Location export/web
python -m http.server 8067
```

驗證項目：

- `GET /index.html` 回 200，title 為 `Crackveil Vanguard`。
- `index.html` 參照的 `.js`、`.wasm`、`.pck`、`.png`、audio worklet 檔案均存在。
- 不需要 COOP/COEP headers，因為 `GODOT_THREADS_ENABLED=false`。

HTTP HEAD 檢查結果：

```text
index.html                         200 text/html                5305
index.js                           200 text/javascript          279815
index.wasm                         200 application/wasm         39509339
index.pck                          200 application/octet-stream 1602176
index.png                          200 image/png                21443
index.audio.worklet.js             200 text/javascript          7298
index.audio.position.worklet.js    200 text/javascript          2973
```

其他本機檢查：

- `node --check export/web/index.js`：通過，無語法錯誤輸出。
- Chrome headless `--dump-dom http://127.0.0.1:8067/`：DOM 含 `<title>Crackveil Vanguard</title>`、`<canvas id="canvas">`、`GODOT_THREADS_ENABLED = false`，未匹配 `404`、`SharedArrayBuffer`、`Uncaught`、`wasm streaming compile failed` 等錯誤關鍵字。
- Chrome headless screenshot：成功渲染 Godot boot/loading 畫面與進度條，不是空白頁。未做人工遊玩驗證。

註：Codex in-app browser 工具在本機環境回報 `sandboxCwd must use the file URI scheme`，因此本次瀏覽器驗證改用系統 Chrome headless 與 HTTP 檢查。

## CI 部署

`.github/workflows/deploy-web.yml` 會：

1. 下載 Godot 4.7 Linux editor。
2. 下載官方 4.7-stable export templates，並只安裝 Web templates。
3. 執行 `Godot --headless --export-release "Web" public/index.html`。
4. 在 `public/` 加 `.nojekyll`。
5. 使用 `actions/upload-pages-artifact` 與 `actions/deploy-pages` 部署。

## 總稽核接手事項

1. 檢查本次 diff。
2. commit 這些設定與文件。
3. 到 GitHub repo Settings > Pages，將 Source 設為 GitHub Actions。
4. push 到 `main` 或手動執行 `Deploy Web` workflow。
5. 部署完成後開啟 `https://mars-tw.github.io/crackveil-vanguard/` 驗證。
