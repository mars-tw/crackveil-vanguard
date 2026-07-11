# R17 Response

Date: 2026-07-11
HEAD: de003cf
Commit/push: not performed

## P1 Fixed

R17's blocking P1 was the Web first-load budget regression from generated walk PNGs.

- `assets/sprites/generated/*.png` was reduced from about 2.69 MB to 116,901 bytes.
- `export/web/index.pck` was reduced from 6,588,576 bytes to 4,344,496 bytes.
- Net pck reduction: 2,244,080 bytes.
- Result is below the requested <= 5 MB budget.

Implementation:

- `tools/generate_walk_frames.py`
  - Crops each character/enemy animation set with one shared alpha union bbox, so frame-to-frame foot/body offsets are preserved.
  - Downscales generated hero frames to max 112 px and enemy frames to max 96 px.
  - Saves generated frames as 96-color paletted PNGs with alpha.
  - Keeps all existing output paths and frame counts, so existing loaders and tests remain compatible.
- `scripts/player/player_visual.gd`
  - Computes animation scale from the largest loaded generated frame across idle + walk, not just `idle_0`.
- `scripts/enemies/enemy.gd`
  - Same scale calculation fix for enemy generated frames.

## R17 Non-P1 Items

R17's joystick, walk-quality, owner-stack, and CorpseGhost notes are either already covered or explicitly P2 in the report:

- Joystick: existing dynamic center / heat zone / dead zone behavior retained; `MobileInputSmokeTest` is green.
- Walk frames: frame count and walk state contract retained; R11 animation regression is green after compression.
- `time_scale` owner stack: R13 regression remains green.
- CorpseGhost cap: Stress confirms live cap at 24 with `exhausted=0`.

Deferred P2s recorded from R17:

- Multi-touch joystick + ability E2E automation.
- Joystick visual overlap polish on narrow portrait layouts.
- Enemy walk-frame expressiveness beyond lean.
- Shared `SpriteFrames` resource reuse instead of per-spawn allocation.
- Pause-resume edge behavior for hit-stop timer.
- CorpseGhost scale-reset polish.

## Verification

- Headless load: pass
- Regression scenes: pass
  - `PoolContractTest`
  - `GameplayCapTest`
  - `MobileInputSmokeTest`
  - `SquadSmokeTest`
  - `WeaponSmokeTest`
  - `R5RegressionTest`
  - `R6RegressionTest`
  - `R7RegressionTest`
  - `R10_5RegressionTest`
  - `R11RegressionTest`
  - `R12RegressionTest`
  - `R13RegressionTest`
  - `R14RegressionTest`
  - `BalanceMockRun`
  - `ArenaInstrumentationRun`
- Stress: pass
  - `avg_ms=7.273`
  - `p95_ms=14.182`
  - `max_ms=37.630`
  - `enemy_group_scans=0`
  - `corpse_ghost.live=24`
  - `corpse_ghost.exhausted=0`
- Web export: pass
  - command: `--headless --path . --export-release "Web" "export/web/index.html"`
  - `export/web/index.pck`: `4,344,496` bytes
  - `export/web/index.html`: `5,305` bytes

Godot export re-created transient `.uid` and sprite `.import` sidecars; those cache files were removed from the working tree.
