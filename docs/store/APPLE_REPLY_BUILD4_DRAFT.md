# Apple 4.3 回覆草稿（1.0.0 build 4，內容 0.40.0-content-r11）

狀態：已送出（2026-10-28，使用者指示「我想推上去商店了」「執行」）。精簡版 3579 字元放在 App Review 備註（`APPLE_REVIEW_NOTES_BUILD4.txt`），隨 build 4 重新送審；讀回狀態 WAITING_FOR_REVIEW。尚未核准。第 4 題照實寫：TestFlight 公開群組 0 位測試者、0 則回饋；Google 封閉測試尚未讀到真實加入人數。

---

Hello App Review team,

Thank you for your patience. Build 4 (version 1.0.0) replaces build 3 and contains eleven further rounds of gameplay and readability work since our last reply. Answers to each question follow.

**1. What the app does**
Crackveil Vanguard is a single-player, offline action-strategy game in which you lead a whole squad of 3 to 9 heroes. Each stage opens three rifts in sequence, and each rift is guarded by one of three enemy attack patterns: a shield wall pushing from the front, a two-sided pincer, or long-range artillery that marks landing points. Each pattern has one correct counter formation (Wedge, Ring or Scatter), and the counter is marked on the ground. With the right formation, the captain and two squadmates must stand inside the rift for six seconds between attack waves to seal it; with the wrong formation, standing in the rift backfires and resets the seal. Sealing all three rifts summons the stage's gate guardian. A run takes about two to three minutes. Recruited heroes form bonds that resonate with specific formations, and before each run the player chooses a starting lineup and one starting node that trades a benefit for a cost.

**2. Intended users**
Players aged 12 and over who like short real-time sessions with a clear tactical decision each wave, and who want a game with no account, ads, purchases or network connection.

**3. Need or gap addressed**
In most auto-attack survival games the player controls one character and the only decision is which upgrade to pick. In Crackveil Vanguard the moment-to-moment decision is reading the incoming attack pattern, switching the whole squad into the counter formation, and physically bringing squadmates into the rift. Winning a stage requires this; damage upgrades alone cannot clear it.

**4. Beta testing and feedback**
We have not yet received external tester feedback. A public TestFlight group exists for this app but currently has no testers, and an Android closed test is set up but we have not confirmed any active testers. The changes in this build come from our own documented playtest and review rounds (eleven since the last submission). Examples: overlapping on-screen labels were removed so enemy names, rule text and seal rewards no longer cover each other; a correct-formation result is no longer shown in the same red as a wrong-formation result; dense line effects in the artillery phase that hid landing points were removed.

**5. Standalone product or suite?**
Crackveil Vanguard is a standalone product. Our account also lists games in different genres built on different codebases. None of them is a squad-formation action game.

**6. Could this be delivered inside another app on the account?**
No. No other app on our account shares its genre, engine project, controls or content.

**7. Shared code or assets with our other apps**
None. The app is its own Godot 4.7 project and shares no game code, scenes or art with our other apps. It uses standard third-party components only: the Godot Engine (MIT), the Noto Sans CJK font (SIL OFL), and a few CC0 sound and art assets from Kenney and OpenGameArt listed in the in-app credits. Parts of the code, the original 2D art and the music were produced with AI-assisted tools under the developer's direction; the developer designed, reviewed, edited and integrated everything, and the provenance is recorded in the public source repository.

**8. Shared codebase or SDK with third-party apps**
No. Apart from the components listed in answer 7, the app contains no third-party SDK, template, analytics or advertising library.

**9. Built for a client or third party?**
No. The account holder conceived, built and publishes the app as their own original product.

Thank you for your time.

---

## App Review Notes（隨 build 4）

How to review: Main menu → 開始出擊 (Start). Move with the bottom-left joystick. A blue/gold/purple rift appears on the ground with the required formation shown on it ("需：楔形 / 圓陣 / 散兵"). Tap the formation button (bottom right, above 旋斬) to switch formation, wait for the attack wave to pass, then bring the captain and two squadmates into the rift for six seconds to seal it. Seal three rifts to summon the gate guardian. No account, purchase or network connection is required.
