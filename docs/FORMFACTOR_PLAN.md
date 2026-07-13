# Crackveil Vanguard Form-factor Plan

## Problem

Playwright evidence shows that touch capability is currently able to select the phone layout on larger screens. That breaks two device classes:

- iPad/tablet `1024x768`, touch-only UA: the seed row becomes a huge full-width phone row, buttons are oversized, and the virtual joystick remains visible in a desktop-style play area.
- Windows touch desktop `1920x1080`, touch plus mouse UA: the same phone layout and joystick are applied even though the viewport is desktop-sized.

The root rule for this fix is:

**Layout is selected by viewport/form factor. Touch capability only selects input affordances. Touch must never scale the whole layout by itself.**

Mobile LOD remains the M1 device/performance contract and is not driven by the new layout tier.

## Layout Tiers

`MobileTuning.layout_tier()` owns layout classification. Runtime Web hints may include UA, touch, and fine-pointer state; tests may inject the same hints explicitly.

| Tier | Detection | Layout behavior |
| --- | --- | --- |
| `phone` | short side `< 700px`, or handset/mobile phone UA | Existing phone layout and current phone scale, about `1.84x-1.96x` |
| `tablet` | short side `700-1099px` with touch and not handset phone UA | Desktop-style composition with medium readable controls, `1.25x` fonts, spacing `1.12x`, touch targets `>= 44px` |
| `desktop` | short side `>= 1100px`, or no touch in the tablet band, or large touch desktop with mouse/fine pointer | Original desktop layout and `1.0x` UI scale |

Important cases:

- `390x844` phone UA -> `phone`
- `1024x768` iPad/tablet touch UA -> `tablet`
- `1920x1080` Windows touch plus mouse UA -> `desktop`
- `1536x864` no touch -> `desktop`

Window resize and rotation must re-run responsive layout through existing `Viewport.size_changed` paths and restore font/min-size overrides when moving back to desktop.

## Seed Row

Seed entry rows must be capped in every tier.

- Shared cap: `MobileTuning.SEED_ROW_MAX_WIDTH = 400px`
- Main menu seed row: never full-width on tablet or desktop touch devices
- Contract seed row: centered and capped the same way

## Virtual Joystick

Joystick visibility is an input affordance, not a layout signal.

| Tier/device | Default joystick | Force joystick setting |
| --- | --- | --- |
| phone with touch | visible | visible |
| tablet with touch | visible | visible |
| phone-sized viewport without touch | hidden | visible |
| desktop with touch plus mouse | hidden | visible |
| desktop without touch | hidden | visible |

The force setting must only affect joystick visibility. It must not change layout tier, UI scale, seed row width, or LOD.

The setting is exposed in both the main menu settings panel and the HUD pause settings panel as `PlayerSettings.force_joystick_visible`.

## LOD Contract

`mobile_lod_enabled()` keeps the M1 semantics:

- force debug setting still enables mobile LOD
- mobile OS/mobile UA still enables mobile LOD
- touch-only without mouse/fine pointer still enables mobile LOD
- touch desktop with mouse/fine pointer does not enable mobile LOD

LOD remains performance/visual budget only. Layout tier must not enable or disable LOD.

## Regression Matrix

Regression coverage is split across `R14RegressionTest`, `M1RegressionTest`, and the mobile input smoke test.

- Form-factor matrix: `390x844` phone, `1024x768` touch tablet, `1920x1080` touch desktop, `1536x864` desktop
- UI scale: phone keeps `1.96x` portrait scale, tablet locks `1.25x`, desktop locks `1.0x`
- Touch target: tablet `>= 44px`; phone keeps existing larger target
- Seed row: main menu and contract rows stay `<= 400px`
- Joystick: phone/tablet touch visible, touch desktop hidden, force setting visible without layout scaling
- Live switching: HUD phone -> tablet -> touch desktop re-applies layout and clears stale joystick movement
- M1 LOD: existing device gate remains unchanged and same-seed hazard gameplay stays equivalent

## Verification

Required verification before final report:

1. Godot headless regression scenes covering the form-factor matrix.
2. Stress contract scenes for desktop and mobile LOD.
3. Font subset workflow rerun.
4. Web export; report whether `.pck` generation succeeds.
5. Browser/Playwright checks where available for phone, tablet touch, touch desktop, and desktop viewports.
6. Write `docs/CODEX_RESPONSE_formfactor.md`.

No `git commit` or `git push`.
