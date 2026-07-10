# Web 匯出與 GitHub Pages 部署

本文記錄 Crackveil Vanguard 的 Godot 4.7 Web 匯出設定、Pages 相容策略與本機驗證結果。

## 方案選擇

- Thread Support：採用 A，`variant/thread_support=false`，也就是 Godot Web 單執行緒匯出。
- 理由：GitHub Pages 不能自訂 COOP/COEP response headers；Godot 多執行緒 Web build 需要 SharedArrayBuffer 與 cross-origin isolation。單執行緒 build 不需要 COOP/COEP，Pages 直接可跑。
- 部署方式：採用 A，GitHub Actions 匯出並部署 Pages artifact。repo 不 commit `.wasm`、`.pck`、`.js` 等匯出 binary。
- 其他 Web preset 重點：`vram_texture_compression/for_mobile=false`。Godot 4.7 若啟用此項但專案未配置 ETC2/ASTC 匯入，Web preset validation 會失敗。

## 繁體中文字型

Web 匯出不會使用玩家作業系統的中文字型 fallback，因此專案內嵌 CJK 字型避免中文 UI 顯示成豆腐方塊。

- 字型：Noto Sans CJK TC Regular，SIL Open Font License 1.1。
- 專案字型：`assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf`。
- 字型匯入 metadata：`assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf.import`，需與字型一併入版，讓 Godot 在初始化 custom Theme 時可載入 FontFile。
- 授權檔：`assets/fonts/OFL.txt`。
- 字集清單：`assets/fonts/NotoSansCJKtc-Regular-UI-Subset.chars.txt`。
- Theme：`assets/fonts/default_theme.tres` 設定 `default_font`。
- 專案綁定：`project.godot` 的 `gui/theme/custom="res://assets/fonts/default_theme.tres"`。

子集策略：

1. 掃描專案 runtime 資源：`*.gd`、`*.tscn`、`*.tres`、`*.godot`，排除 `.git`、`.godot`、`export`、`exports`、`build`、`dist`。
2. 加入 ASCII `U+0020..U+007E`、CJK Symbols and Punctuation `U+3000..U+303F`、Fullwidth Forms `U+FF01..U+FF5E`。
3. 合併繁中安全集：`agj/3000-traditional-hanzi` 的 `output/notes.tsv` 前 2800 個繁中字，pinned commit `855200d72670b8053096b6d706906d2cad265dbe`。該資料集為 MIT 授權，來源包含 Heisig & Richardson、TOCFL 與 Chih-Tsao Hai 常用頻率資料。
4. 使用 fontTools `pyftsubset` 產生 OTF 子集，並檢查專案掃描到的漢字與 R4 代表字都存在。

容量取捨：

- 台灣教育部《常用國字標準字體表》4808 字全納入時，Noto CJK OTF 子集約 2.63MB。
- 台灣教育部常用 4808 + 次常用約 6343 字全納入時，Noto CJK OTF 子集約 5.92MB。
- 目前採用 2800 個頻率/學習排序繁中字 + 專案實際字，讓 OTF 維持在 1.5MB 內，同時比只掃專案文字有大幅緩衝。

重建子集：

```powershell
python tools/build_font_subset.py
```

腳本會在缺少來源字型時下載 pinned Noto Sans CJK TC Regular `Sans2.004`，掃描專案文字，下載 pinned 繁中安全集，輸出同名 OTF 與 `.chars.txt`。預設 `--max-size-bytes=1500000`，超過即失敗，避免 Web build 字型失控。

本次大小：

```text
NotoSansCJKtc-Regular.otf                 16,435,884 bytes
NotoSansCJKtc-Regular-UI-Subset.otf        1,496,500 bytes
project Han characters scanned:                  257
safety Han characters:                          2,800
subset input:                                   3,058 codepoints, 2,805 Han characters
previous subset:                                  460 codepoints, 207 Han characters
R4 coverage: 載/暴 were missing before; 載/暴/距/引/跳 are present now
```

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
python tools/build_font_subset.py
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
index.pck                        2,966,100 bytes
index.png                          21,443 bytes
index.png.import                      930 bytes
index.wasm                      39,509,339 bytes
```

`index.html` 內確認：

```text
GODOT_THREADS_ENABLED = false
ensureCrossOriginIsolationHeaders = false
fileSizes: index.pck=2966100, index.wasm=39509339
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
index.pck                          200 application/octet-stream 2966100
index.png                          200 image/png                21443
index.audio.worklet.js             200 text/javascript          7298
index.audio.position.worklet.js    200 text/javascript          2973
```

其他本機檢查：

- `node --check export/web/index.js`：通過，無語法錯誤輸出。
- `rg -a "NotoSansCJKtc-Regular-UI-Subset|default_theme|fontdata" export/web/index.pck`：可找到 `default_theme.res`、字型匯入 `.fontdata` 與字型 resource path。
- Chrome headless `--dump-dom http://127.0.0.1:8067/`：DOM 含 `<title>Crackveil Vanguard</title>`、`<canvas id="canvas">`、`GODOT_THREADS_ENABLED = false`，未匹配 `404`、`SharedArrayBuffer`、`Uncaught`、`wasm streaming compile failed` 等錯誤關鍵字。
- Chrome headless screenshot：成功渲染 Godot boot/loading 畫面與進度條，不是空白頁。未做人工遊玩驗證。

註：Codex in-app browser 工具在本機環境回報 `sandboxCwd must use the file URI scheme`，因此本次瀏覽器驗證改用系統 Chrome headless 與 HTTP 檢查。

## CI 部署

`.github/workflows/deploy-web.yml` 會：

1. 下載 Godot 4.7 Linux editor。
2. 下載官方 4.7-stable export templates，並只安裝 Web templates。
3. 安裝 `fonttools`。
4. 執行 `python3 tools/build_font_subset.py`，每次部署都用當前專案文字重建 `assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf`。
5. 執行 `Godot --headless --export-release "Web" public/index.html`。
6. 在 `public/` 加 `.nojekyll`。
7. 使用 `actions/upload-pages-artifact` 與 `actions/deploy-pages` 部署。

## 總稽核接手事項

1. 檢查本次 diff。
2. commit 這些設定與文件。
3. 到 GitHub repo Settings > Pages，將 Source 設為 GitHub Actions。
4. push 到 `main` 或手動執行 `Deploy Web` workflow。
5. 部署完成後開啟 `https://mars-tw.github.io/crackveil-vanguard/` 驗證。
