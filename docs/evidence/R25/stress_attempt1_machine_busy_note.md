# R25 stress attempt 1 — machine busy

The raw command output is preserved as `stress_attempt1_mislabeled_isolated.txt`.
The command-line label said `codex-local-headless-isolated`, but a post-failure CPU audit proved that description inaccurate:

- total CPU samples: 59.1%, 60.2%, 33.9%; a later 10-sample window stayed 41.3–74.2%;
- concurrent Codex/CUA sessions were active in other workspaces;
- a separate Godot R14 process was active outside this repository command.

Therefore this attempt is classified `concurrent_untrusted` despite the immutable raw log label. It is not accepted as final performance evidence.
