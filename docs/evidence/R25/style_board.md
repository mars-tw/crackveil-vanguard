# R25 三戰場視差 Style Board

共同語言：手繪科幻末世 2D 場景、霧化遠景、硬邊中景剪影、少量高對比近景；中央 56% × 58% 保持低細節／低局部對比，角色與敵人永遠是視覺第一層級。禁止文字、logo、人物、敵人、UI、浮水印。

## 色票

| 主題 | 暗底 | 中間色 | 能量色 | 暖亮點 | 中央帶策略 |
| --- | --- | --- | --- | --- | --- |
| 裂隙虛空 `rift_void` | `#061229` | `#243765` | `#54DCEB` | `#B478E6` | 深藍低紋理霧帶；青紫只在外圍與地平線 |
| 廢土農野 `wasteland_farm` | `#12261B` | `#3C5A36` | `#76D68C` | `#D4A45B` | 暗綠霧化田野；穀倉／枯木只在外側 |
| 餘燼裂原 `ember_rift` | `#25100D` | `#5A2920` | `#F06B3E` | `#F2B35B` | 暗褐灰燼帶；熔光限制在邊緣裂縫 |

## 圖層職責

- far：完整不透明天空／大氣基底；低頻、無文字，容許大尺度裂隙或雲霧，但中央不放尖銳焦點。
- mid：透明地形剪影；輪廓靠上／下 18% 與左右外圍，中央保持可穿透。
- near：透明裝飾；只在四角及左右 18%，中央玩法帶 alpha 接近 0；low 完全停用本層。

## Reference hashes（僅風格／色彩參考，非 edit target）

- `assets/art/r24/keyart/menu_keyart_desktop.png` — `6d2540154b6afbbaa089e480ad06674cdad507a11f33436204f0f09416d03113`
- `assets/art/decor/ground_void_stone.png` — `be757188cd4e1b68fd725b32d811c3a53f0bfaf9937b75324adf661d9e270c80`
- `assets/art/decor/farm_ruined_barn.png` — `b304e16f5c46a34f1e9d9cb3ed02772d8f677aec05f6fe085a7b359636e2ffd9`
- `assets/art/decor/ember_lava_crack.png` — `6b58a2d073a945dadffabd6a496e9ecd69a9333bb8e15bbc4c1d9c0969397d57`

Reference role：只鎖定既有 Crackveil Vanguard 的冷青／農野綠／餘燼橙色語彙；九張 master 均為全新 generation，不修改參考圖。

