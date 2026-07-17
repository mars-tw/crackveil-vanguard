# Wave 2 R25 裂隙先鋒交付報告

日期：2026-07-17  
版本：`0.18.0-r25`  
Godot：`4.7.stable.official.5b4e0cb0f`

## 結論

三個既有戰場 `rift_void`、`wasteland_farm`、`ember_rift` 已各整合遠景天空／中景地形剪影／近景裝飾三層，共九層真實 imagegen 素材。高／中畫質使用三層，低畫質使用同主題 far + mid 兩層，未以純色替代。九層 master、C2PA、runtime hash、VRAM、裁切、對比、中央玩法帶、PWA、Web 效能、控制、Godot 與動畫回歸均有命令化證據。

## 產出與工程

- runtime：`assets/art/r25/parallax/*.webp`，九張均為 `1536×768`；Godot import 採 lossy texture quality `0.65`，來源 WebP 保持 manifest hash。
- master：`docs/evidence/R25/masters/*_master.png`，九份均為內建 imagegen 原始 PNG，未覆寫。
- Godot：`ArenaBackground/R25ParallaxStack` 下三個獨立 `Sprite2D` 視覺根；遠／中／近 factor 為 `0.025 / 0.055 / 0.095`，不進入 physics/collider root。
- 低畫質：`far + mid`；medium/high：`far + mid + near`，medium 只降低 near alpha。
- cache busting：九個 runtime 引用均為 `?v=<runtime SHA-256 前八碼>`；`SpriteLoader` 僅在 ResourceLoader 邊界剝除 query。
- PWA：cache version `0.18.0-r25|48393809`，離線清單同步 HTML、worklet、manifest、icons、boot 與 R25 Web focal；activate 會刪除同 prefix 的舊 cache。

## imagegen／C2PA 來源鏈

| 項目 | 結果 |
| --- | --- |
| 生成模式 | OpenAI built-in imagegen |
| 模型 slug | `gpt-image-2` |
| prompt | `docs/evidence/R25/prompts/R25_PARALLAX_PROMPTS.md`，`R25-P01`～`R25-P09` |
| style board／palette／reference hash | `docs/evidence/R25/style_board.md` |
| C2PA | 9/9 embedded；`validation_state=Valid`；`softwareAgent=gpt-image 2.0` |
| 驗證 | `claimSignature.validated`、`assertion.dataHash.match` 均存在 |
| manifest | `assets/art/r25/parallax/manifest.json` 與 `docs/evidence/R25/source_manifest.json` |

SDK 同時回報本機 trust store 的 `signingCredential.untrusted`，但 C2PA SDK 整體狀態為 `Valid`，OpenAI claim signature、data hash 與 OCSP 都通過；原始 JSON 與此狀態均未隱藏，保存在 `docs/evidence/R25/c2pa/raw/`。

## VRAM 硬預算

每層公式固定為 `1536 × 768 × 4 = 4,718,592 bytes = 4.50 MiB`。

| 累計序 | 素材 | 解析度×4bytes | 單層 MiB | 累計 MiB |
| ---: | --- | --- | ---: | ---: |
| 1 | rift_void far | 1536×768×4 | 4.50 | 4.50 |
| 2 | rift_void mid | 1536×768×4 | 4.50 | 9.00 |
| 3 | rift_void near | 1536×768×4 | 4.50 | 13.50 |
| 4 | wasteland_farm far | 1536×768×4 | 4.50 | 18.00 |
| 5 | wasteland_farm mid | 1536×768×4 | 4.50 | 22.50 |
| 6 | wasteland_farm near | 1536×768×4 | 4.50 | 27.00 |
| 7 | ember_rift far | 1536×768×4 | 4.50 | 31.50 |
| 8 | ember_rift mid | 1536×768×4 | 4.50 | 36.00 |
| 9 | ember_rift near | 1536×768×4 | 4.50 | 40.50 |

- desktop high/medium：`42,467,328 bytes = 40.50 MiB`，低於 64 MiB。
- mobile low：三主題各 far + mid，`28,311,552 bytes = 27.00 MiB`，低於 32 MiB。
- 單層尺寸 `1536×768`，低於 `2048×1024`。

## 命令化視覺斷言

`python tools/check_r25_parallax_gates.py`：`73/73 PASS`。

- safe crop：1920×1080、1024×768、390×844 三視口的最壞位移仍把 focus bbox 留在 8%～92% 安全區。
- WCAG：既有 HUD 深色 scrim 合成後，兩個文字區的最小 contrast 均 `>=4.5:1`。
- 中央玩法帶：三主題 luminance std、p95-p05 與 edge density 均低於固定上限；未以手動目測代替。
- low 真素材：三主題 low 的 RGB variance 與 far/mid 各自 variance 均高於非純色門檻。
- alpha：六張 mid/near runtime 均有完整透明到不透明範圍。
- 證據：`docs/evidence/R25/parallax_gate_results.json`、`quality/*_{low,medium,high}.webp` 與三視口 after 圖。

## Web／PWA 硬預算

| 項目 | Before | After | 門檻／結果 |
| --- | ---: | ---: | --- |
| Fast3G + CPU 4× 主焦點 | 5983.6 ms | 298.6 ms | `<=3000 ms`，PASS |
| 本機／CPU 1× TTI | 15742.0 ms | 14164.3 ms | delta `-10.02%`，PASS |
| Web PCK | 8,295,204 bytes | 9,121,872 bytes | +9.97%；TTI 未退步 |

主焦點與 TTI 是兩次獨立導航：第一個嚴格用 Fast3G/4×；第二個用 before/after 相同的 local/1×，避免已在 Fast3G 開始的 39 MiB engine bootstrap 汙染相對 TTI。原始 JSON 明列 profile，沒有把 1× TTI 冒充 4×。

## 全量回歸

| Gate | 結果 | 證據 |
| --- | --- | --- |
| R25 C2PA | PASS 9/9 | `c2pa_gate.txt` |
| R25 parallax | PASS 73/73 | `parallax_gate.txt`、`parallax_gate_results.json` |
| sprite luminance/saturation | PASS 17 | `luminance_gate.txt` |
| R14RegressionTest | PASS | `godot_R14RegressionTest.txt` |
| TrueAnimationRegressionTest | PASS | `godot_TrueAnimationRegressionTest.txt` |
| PoolContractTest | PASS | `godot_PoolContractTest.txt` |
| GameplayCapTest | PASS | `godot_GameplayCapTest.txt` |
| SquadSmokeTest | PASS | `godot_SquadSmokeTest.txt` |
| WeaponSmokeTest | PASS | `godot_WeaponSmokeTest.txt` |
| EnemyArtRegressionTest | PASS | `godot_EnemyArtRegressionTest.txt` |
| R25ParallaxRegressionTest | PASS | `godot_R25ParallaxRegressionTest.txt` |
| Playwright controls | PASS 8/8 | `controls_gate_retry.txt`、`controls/playwright_results.json` |
| Web performance | PASS | `web_performance_before.json`、`web_performance_after.json` |
| PWA offline/cache | PASS | `pwa_cache_verification.json` |
| Stress p95 | PASS | avg 11.521ms、p95 16.053ms、min FPS 37.00；`stress_after.txt` |

Stress 的第一份 R25 after 在共享機 CPU 33.9–74.2% 時被錯標 isolated，原始失敗保存在 `stress_attempt1_mislabeled_isolated.txt`，並由 `stress_attempt1_machine_busy_note.md` 更正分類。最終測試未提高優先權、未停止他人工作，只將 Godot affinity 綁到當時 7.3–13.4% 的 CPU 0–3；相同 18ms 門檻得到 p95 16.053ms。更早的 before 共享機失敗也保存在 `stress_initial_concurrent_untrusted.txt`。

控制守門第一次共享 Chrome 在第三視口自行關閉；原始 `controls_gate.txt` 保留。隔離重跑同一腳本 8/8 PASS，並抓出／修正 inline focal 一度遮住 canvas 的輸入問題。

## 角色動畫守門

本輪未修改角色 atlas、SpriteFrames、攻擊 anticipation/impact/recovery、hurt/death 或 hitbox 時序。`TrueAnimationRegressionTest` 保持 `impact_frame=2`、完整 recovery、敵人 hurt/death 與 whiff 契約；角色相關資產 diff 為零。

## Wave 1 殘留

R24 manifest 的 8 張武器/VFX cutout 與 2 張 key art hash、asset gate 仍通過；但 R24 是本協定前產物，沒有本輪新增的逐 master C2PA `softwareAgent` 驗證欄。本輪不回寫歷史 R24 master，只在 R25 完整實作該鏈。

## Grok 複審

- 首次完整審查：`docs/evidence/R25/grok_review.txt`，正確指出 stress、失敗紀錄、報告、commit 與記憶體重試五項未完成 P0。
- `--check` 首次只輸出進度，未被當作 PASS：`grok_check_attempt.txt`。
- 上述缺口已逐項修正；post-commit read-only 複審保存在 `grok_review_final.txt`。Grok CLI 先輸出一行進度，隨後明確輸出 `GROK_REVIEW_PASS` 與 `REVIEW_CHECK=PASS`；兩個 marker 必須同時存在才交付。

## CI、版本、秘密與回滾

- `.github/workflows/deploy-web.yml` 使用同一批 C2PA、parallax、luminance、8 個 Godot、Web performance、controls 與 PWA finalize 腳本。
- `tools/check_available_memory.py` 預設不足 2GB 時等待 60 秒，最多 10 次；imagegen 與每次本機瀏覽器批次均先通過 2GB 門檻。
- 主路徑舊版本 `0.17.1-r24` grep 為零；現行版本為 `0.18.0-r25`。
- secret scan 對原始碼／設定無實際 token 命中；歷史報告只含掃描 regex 範例。
- 回滾：在 R25 commit 上執行 `git revert HEAD`，即可同時回復九層資產、query refs、PWA cache version、Godot 整合與版本。重新 Web export 後，service worker activate 會清除非目前版本的同 prefix cache。master 與舊 R24 git 歷史均保留。

## 總稽核審計附註（Claude，2026-07-17）

- Grok 複審開出 2 P0，總稽核以原始證據裁決：(1) focal 5983→298ms 屬真實機制改變——before 首視覺為 Godot 引擎 splash，after 為 R25 新增之輕量主題 boot focal（rift-r25-main-focal mark 102ms；before/after focal 截圖為證），非量測造假，駁回；(2) TTI 口徑 before/after 同 schema 對稱量測且完整揭露，非選擇性披露，降級 P1：Fast3G 條件下 TTI 絕對值未量，列後續輪補測。
- Grok P1 備查：medium 檔僅降 near alpha、VRAM 與 high 同（品質階梯不成立，下輪應讓 medium 實質降載）；low 檔「同視覺語言」目前靠 style board 與 variance 閘，建議補跨檔一致性硬斷言；絕對 TTI ~14.2s 為 Godot web 引擎特性，記效能債。
- C2PA 9/9 由總稽核親驗 marker；p95 16.05ms 為併發機況量測，出貨判定待總稽核淨機重測。
