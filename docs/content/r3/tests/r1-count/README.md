# R1 動態檢查次數診斷

本輪 CI 的未修改 `ContentR1Test` 原始輸出為 `1337/0`，歷史 R2.1 收據為 `1355/0`。第一次 R3 嚴格驗證草稿套用歷史 `>=1355` 因而 BLOCKED，原收據保留在 `attempts/verifier-first-count-blocked.json`。

`fits()` 會對每行、每個非換行字元執行 `check()`，因此總數包含當下 HUD 字串長度，不是固定測項數。歷史收據沒有保存該次逐一字串，不能回補或宣稱已找出那十八次的確切舊文字。

這次另外從 `ce94e02` 取出 baseline runtime，在相同 Godot 4.7 headless／Dummy、fresh 隔離 profile 下，與 R3 runtime 各執行原 R1 test 的暫存副本。副本只在原 `check()`／`fits()` 前加入 print，沒有刪改斷言或分支；原始 source 保持不變。

- baseline 與 R3 均為 **1337 checks、49 次 fits、0 failures**。
- 逐條 assertion message 及 49 組 label text 完全一致；差異陣列皆空。
- 原 CI 與 R3 診斷 count 同為 1337，六個必需視口完整。

新 R3 gate 驗證六視口集合、原場景 exit0、raw／JSON 次數相等、全部原斷言 body 保留，以及兩份完整 call／label trace 一致。沒有修改舊 R1／R2／R2.1 的歷史計數條件，也沒有把舊 fail 直接降低門檻當成通過。
