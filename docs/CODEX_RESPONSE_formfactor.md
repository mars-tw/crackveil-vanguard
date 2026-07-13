# CODEX RESPONSE: Form-factor P0

Status: implemented, verified, exported. No `git commit` or `git push`.

## Summary

- Wrote `docs/FORMFACTOR_PLAN.md` before implementation.
- Added `MobileTuning.layout_tier()` with three tiers:
  - `phone`: short side `<700px` or handset phone UA. Keeps current phone scale, about `1.84x-1.96x`.
  - `tablet`: short side `700-1099px` with touch. Uses desktop-style composition, `1.25x` fonts, `1.12x` spacing, and touch targets `>=44px`.
  - `desktop`: large viewport or no-touch desktop. Uses original `1.0x` layout.
- Added `MobileTuning.SEED_ROW_MAX_WIDTH = 400px`; MainMenu and ContractScreen seed rows are capped and no longer stretch full width.
- Added `MobileTuning.should_show_virtual_joystick()`:
  - phone/tablet touch: visible by default.
  - desktop, including touch desktop: hidden by default.
  - force setting: visible, without changing layout tier, UI scale, or LOD.
- Added `PlayerSettings.force_joystick_visible` plus toggles in MainMenu settings and HUD pause settings.
- HUD force joystick no longer forces phone layout; hiding joystick clears `GameManager.touch_move_vector`.
- Tablet joystick now has a medium radius tier instead of phone-sized proportional radius.
- M1 LOD semantics remain unchanged and separate from layout tier.

## Regression Locks

`R14RegressionTest` now locks:

| Case | Expected |
| --- | --- |
| `390x844` phone touch | `phone`, joystick visible, scale `1.96` |
| `1024x768` tablet touch | `tablet`, joystick visible, scale `1.25`, touch target `>=44`, joystick radius not phone-sized |
| `1920x1080` touch desktop | `desktop`, joystick hidden, scale `1.0` |
| `1536x864` no-touch desktop | `desktop`, joystick hidden |

Also locked:

- MainMenu / Contract seed rows stay `<=400px`.
- HUD live switch phone -> tablet -> touch desktop restores desktop fonts and hides joystick.
- Forced joystick display does not change desktop UI scale.
- MainMenu and HUD pause settings include the force joystick toggle.

`M1RegressionTest` additionally verifies the form-factor fix does not alter M1 LOD: `1920x1080 touch+mouse` remains desktop form-factor and LOD off.

## Godot Regressions

Godot: `4.7.stable.official.5b4e0cb0f`, Windows headless.

- `--headless --path . --quit`: PASS
- `R14RegressionTest`: PASS, `phone=phone tablet=tablet touch_desktop=desktop desktop=desktop seed_max=400`
- `M1RegressionTest`: PASS, hazard gameplay tick `0.240`, same-seed damage `559.157`
- `MobileInputSmokeTest`: PASS
- `M2RegressionTest`, `M3RegressionTest`, `M4RegressionTest`: PASS
- `PoolContractTest`: PASS, with the expected double-release warning path
- `GameplayCapTest`: PASS
- `SquadSmokeTest`, `WeaponSmokeTest`: PASS with `--fixed-fps 60`
- `R5RegressionTest`: PASS when run alone. One parallel run hit a hazard steady-redraw timing false failure; rerun passed.
- `R6RegressionTest`, `R7RegressionTest`, `R10_5RegressionTest`, `R11RegressionTest`, `R12RegressionTest`, `R13RegressionTest`: PASS
- `OrbitBladeHitRepro`: PASS
- `BalanceMockRun`: PASS
- `ArenaInstrumentationRun`: PASS, 16.01s survived, total damage `2297.3`, `enemy_group_scans=0`

## Stress

Seed `52002`, 150 enemies, 80 background projectiles, 411 measured frames.

| Scenario | Result | avg / p95 / max |
| --- | --- | --- |
| Desktop `1280x720` | `STRESS_PASS` | `61.633 / 96.968 / 160.136 ms` |
| Mobile LOD `390x844` | `STRESS_PASS` | `62.674 / 107.585 / 357.326 ms` |

Both runs had pool exhausted / duplicate / foreign release counts at 0, and `enemy_group_scans=0`.

This machine was very slow during the headless Stress pass, so both runs honestly printed `STRESS_PERF_BELOW_60=true`. This signoff only claims Stress correctness/contract green, not 60fps performance.

## Font And Web

- `python tools/build_font_subset.py`: PASS
  - scanned project files: `152`
  - project Han coverage: `563/563`
  - output font: `1,517,152 bytes`
- Web export: `--headless --path . --export-release "Web" "export/web/index.html"` PASS
- `node --check export/web/index.js`: PASS
- `export/web/index.pck`: `4,668,864 bytes`
- `rg -a "NotoSansCJKtc-Regular-UI-Subset|default_theme|fontdata" export/web/index.pck`: font/theme resources found

## Playwright Smoke

Playwright Chromium smoke was run against exported Web through temporary `127.0.0.1:8067`; the server was stopped after the run.

WebKit device descriptors were not installed locally, so browser smoke used Chromium descriptors. The exact iPad/touch-desktop logic is locked by `R14RegressionTest` injected hints.

| Screenshot | Descriptor | Size |
| --- | --- | ---: |
| `phone.png` | Pixel 5, `390x844` | `1,410,331 bytes` |
| `tablet_touch.png` | Galaxy Tab S4, `1024x768` | `1,566,194 bytes` |
| `touch_desktop.png` | Galaxy Tab S4 touch + Windows UA, `1920x1080` | `2,956,342 bytes` |
| `desktop.png` | Desktop Chrome, `1536x864` | `674,039 bytes` |

Visual check: tablet/touch-desktop main menu uses desktop-style left menu and the seed row is capped, not full-width. The faint circle visible in those screenshots is a background rift decoration, not the HUD joystick. HUD joystick hidden on touch desktop is covered by the live HUD R14 test.

## Worktree Note

`git diff --check` passes with only CRLF warnings. The worktree already contains many untracked Godot `.uid` / `.png.import` generated sidecars; I left them in place to avoid deleting pre-existing user/worktree state.
