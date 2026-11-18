# Crackveil Vanguard R49 本機接手紀錄

版本為 `0.78.0-content-r49`。首次封隙提示會顯示快封、慢封的補血差異與錯陣後果。手機減少中央文字，戰鬥加入隊長輪廓與四種敵攻提示，無盡每三波更換戰場規則。這一輪的程式已整合，本機完整回歸停在 R38。

- Web 匯出、封包資產檢查、啟動及瀏覽器實際輸入通過。整合版的 844×390 首次封隙與齒核實拍見 [手機量測](content/r49/a/phone-layout.json)。
- [桌面戰鬥](content/r49/combat/desktop/measurements.json) 是整合版。[手機戰鬥](content/r49/combat/phone/measurements.json) 是 B 線完成的實拍；整合版手機重拍因電腦負載中止。
- [無盡自然對局](content/r49/endless-natural.json) 是 C 線的 844×390 紀錄。第 20.0 秒出現荊藤，第 103.8 秒進入第四波並出現影槍。觀測在局中結束，結算另由分線測試覆蓋。
- [整合檢查紀錄](content/r49/integration-checks.json) 留下執行完畢的項目。R38ContentTest 在 endless_unlock 階段超過 20 秒，原因待確認。後續回歸尚未跑完。
