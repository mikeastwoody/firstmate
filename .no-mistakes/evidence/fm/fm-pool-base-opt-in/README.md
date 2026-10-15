# Live validation: opt-in config/spawn-base-primary-checkout

Every scenario ran the real `bin/fm-spawn.sh`, `bin/fm-review-diff.sh`, and `bin/fm-promote.sh`
from the gate worktree against a disposable marked lab home (`bin/fm-lab-home.sh create`).
The fixture setup:
- the real `tmux` on a private `fm-lab` socket, and the real `treehouse` v3.1.3 with `TREEHOUSE_ROOT` inside the lab;
- codex crew launches;
- a throwaway `labproj` repo whose `origin` (a local bare repo) is frozen at "instructions v1",
  while the primary checkout's `main` carries three local landings, including "instructions v2" in AGENTS.md.

| File | Scenario |
|---|---|
| s1-default-local-only-spawn.txt | no flag, local-only ship -> slot at origin/main (unchanged default) |
| s1b-default-scout-spawn.txt | no flag, scout -> slot at origin/main (unchanged default) |
| s2-optin-local-only-spawn.txt | flag, local-only ship -> slot at primary main, AGENTS.md v2 |
| s3-optin-scout-spawn.txt | flag, scout -> slot at primary main |
| s4-optin-direct-PR-spawn.txt | flag, direct-PR ship -> stays at origin/main |
| s4b-optin-no-mistakes-spawn.txt | flag, no-mistakes ship -> stays at origin/main |
| s5-review-anchor.txt | review anchor: opted-in local-only reviews only its own file vs main; flag removed shows the 3 foreign landings; direct-PR stays on origin/main |
| s6-promote-wording.txt | promote scout -> direct-PR: flag names origin's default branch; no flag keeps default wording |
| s7-optin-diverged-spawn.txt | flag, primary diverged from origin -> origin tip + note (ahead 3, behind 1) |
| s8-optin-named-base-spawn.txt | flag, --base-branch feature/hub with local copy ahead -> origin/feature/hub |
| lab-windows-and-pool.txt | tmux windows fm-spawn created and the lab-local treehouse slots |
| *-worker-pane.txt | codex worker pane; the worker stops at codex's own folder-trust prompt for the never-trusted lab repo. It was left unanswered so the operator's ~/.codex trust store stays untouched |
| lab-driver.sh, lab-inspect.sh | exact driver/inspection commands used |
