# App Review Notes — local draft

PREPARED — 15 October 2026. Intended for a future binary containing game version 0.29.0-r44. **Do not attach these instructions to the existing native build 3 as if it already contains this update.** No submission or response was sent.

Crackveil Vanguard is a real-time formation action game. The new Formation Seal Relay is available immediately in the first stage. Changing formation also changes each living squad member's destination. Pressing the formation button alone cannot complete a seal: the captain must enter its ground marker, and at least two living followers must reach their actual formation slots for 1.2 continuous seconds while combat remains active.

## See the defining interaction within three minutes

1. Launch the app. No account, sign-in, purchase or server is required. Tap **「三陣封隙・出擊」** on the main menu. The default starting stage is **「蒼月空庭」**. **「玩法」** explains the same interaction before starting.
2. On iPad, you may tap **「自動戰鬥：關」** to enable the existing automatic attack/upgrade mode for this demonstration; phones enable it initially. Formation and movement remain manual. Move with the lower-left virtual joystick toward the orange wedge marker. A small arrow beside the captain points toward it. Stop in the marker and let both followers settle. The progress ring fills, the squad receives a small heal, and the next marker appears nearby.
3. The second marker requires **「圓陣」**. Tap the formation control to cycle, or hold it for approximately 0.35 seconds and select the named formation. Formation switching has a four-second cooldown; wait until the button is ready. Walk to the blue ring marker and let the followers form up.
4. Repeat at the green **「散兵」** marker. Release the joystick inside each marker so the followers can settle instead of continually turning around. If an upgrade card appears, choose one and continue. Completing all three seals grants four echo shards on the first completion for that stage, and saves its record. Walking away, selecting the wrong formation, or leaving the followers behind prevents progress. Ordinary weapons continue firing and enemies remain active.
5. Tap **「暫停」**, then **「本局」** to inspect the relay and the three other tactical objectives. Tap **「繼續」** to resume, or **「撤退」** to end the sortie and return to the menu. On a fresh launch, open **「殘響升級」 → 「戰術收藏」** to see the saved **「三陣封隙：已封合」** record. Permanent progress persists; a running combat session is not restored after termination.

The first Boss normally arrives at 90 seconds. At half health, a two-second warning precedes an escort enemy. This is an additional encounter; the relay does not require waiting for the Boss. A defeated captain can retry or return to the menu. The guide, formation picker and other modal screens have visible exit controls.

## Product distinction and submission facts

The squad roster, formation/hero-passive and bond interactions, grounded seal relay, and ten fantasy battlefields are implemented in this Godot project. Shared third-party components include Godot and the licensed Noto font. The local source/asset comparison and limitations are in `SHARED_ASSETS_AUDIT.md`; this is not a final-binary identity audit.

We acknowledge that squad survival games already exist, including Survive Squad. We do not claim that adding followers or automatic attacks alone is novel. The intended distinction is the squad's actual occupancy and formation changes as the immediate battle objective. Automated local checks do not replace user beta feedback.

No third-party analytics, advertising, account or purchase SDK was found in this source revision. Native assets and saves are local. The Web preview has different loading/cache behavior and is not the native offline verification. Final signed-binary privacy checks and physical iPhone/iPad beta testing remain outstanding.

## Owner information still required before any response

- Who owns the game's original content and submits it; whether any client or partner commissioned it.
- Actual TestFlight/beta participants, feedback and resulting changes. None are invented in this draft.
- Product-owner rationale for a separate app rather than a mode in another same-account survival game; the technical possibility of consolidation remains open.
- A future signed binary containing this change, physical-device evidence, and confirmation that privacy disclosures match it. Native build counters were deliberately left unchanged in this work round.
