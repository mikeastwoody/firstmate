# Live lab: opt-in config/spawn-base-primary-checkout

Disposable lab home created with bin/fm-lab-home.sh, a private tmux server (TMUX_TMPDIR in the lab), TREEHOUSE_ROOT inside the lab, a throwaway project 'demo' with a lab-private bare origin, and real Claude Code crewmates (sonnet, low effort).
Every command below is the real firstmate script run from the change's worktree with FM_HOME=<lab home>.
The project's CLAUDE.md carries 'Instruction marker: STALE-ORIGIN-v1' on origin; a real worker changed it to FRESH-LOCAL-v2 and bin/fm-merge-local.sh landed that on the primary checkout's main, so origin stayed frozen one commit behind.
Each probe worker was told to report, without reading any file, the marker from the instructions it loaded at launch.

## Setup: a real local landing (flag absent)
```
$ FM_HOME=$LAB bin/fm-spawn.sh lab-land $LAB/projects/demo --mode local-only --yolo on --harness claude --model sonnet --effort low
spawned lab-land harness=claude kind=ship mode=local-only yolo=on window=firstmate:fm-lab-land worktree=/private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/1/demo
exit=0
--- base facts for lab-land
primary checkout main : e4566b5 (seed demo)
origin/main (fetched) : e4566b5
worker worktree       : /private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/1/demo
worker HEAD           : e4566b5 (seed demo) branch=HEAD
worker CLAUDE.md      : Instruction marker: STALE-ORIGIN-v1
$ FM_HOME=$LAB bin/fm-merge-local.sh lab-land
merged fm/lab-land into local main (e4566b5 -> c73bf9f) in /private/tmp/fmpb.nefE3r/home/projects/demo
exit=0
primary main : c73bf9f Update instruction marker to FRESH-LOCAL-v2
origin main  : e4566b5
primary CLAUDE.md: Instruction marker: FRESH-LOCAL-v2
commits primary main is ahead of origin: 1
```

## S1: flag absent, local-only ship starts from origin tip (unchanged default)
```
$ FM_HOME=$LAB bin/fm-spawn.sh lab-default $LAB/projects/demo --mode local-only --yolo on --harness claude --model sonnet --effort low
WARNING: watcher still down (same stale episode; last beat: never, grace 300s) - full banner already printed this episode.
spawned lab-default harness=claude kind=ship mode=local-only yolo=on window=firstmate:fm-lab-default worktree=/private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/2/demo
exit=0
--- base facts for lab-default
primary checkout main : c73bf9f (Update instruction marker to FRESH-LOCAL-v2)
origin/main (fetched) : e4566b5
worker worktree       : /private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/2/demo
worker HEAD           : e4566b5 (seed demo) branch=HEAD
worker CLAUDE.md      : Instruction marker: STALE-ORIGIN-v1
worker status: done [at=1793192549]: booted with STALE-ORIGIN-v1
```

## S1b: flag absent, scout starts from origin tip (unchanged default)
```
$ FM_HOME=$LAB bin/fm-spawn.sh lab-scout2 $LAB/projects/demo --scout --harness claude --model sonnet --effort low
WARNING: watcher still down (same stale episode; last beat: never, grace 300s) - full banner already printed this episode.
spawned lab-scout2 harness=claude kind=scout window=firstmate:fm-lab-scout2 worktree=/private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/7/demo
exit=0
--- base facts for lab-scout2
primary checkout main : c73bf9f (Update instruction marker to FRESH-LOCAL-v2)
origin/main (fetched) : e4566b5
worker worktree       : /private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/7/demo
worker HEAD           : e4566b5 (seed demo) branch=HEAD
worker CLAUDE.md      : Instruction marker: STALE-ORIGIN-v1
worker status: done [at=1793192683]: done: booted with STALE-ORIGIN-v1
```

## S2: flag present, local-only ship starts from the primary checkout main
```
$ touch $LAB/config/spawn-base-primary-checkout
$ FM_HOME=$LAB bin/fm-spawn.sh lab-optin $LAB/projects/demo --mode local-only --yolo on --harness claude --model sonnet --effort low
WARNING: watcher still down (same stale episode; last beat: never, grace 300s) - full banner already printed this episode.
spawned lab-optin harness=claude kind=ship mode=local-only yolo=on window=firstmate:fm-lab-optin worktree=/private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/3/demo
exit=0
--- base facts for lab-optin
primary checkout main : c73bf9f (Update instruction marker to FRESH-LOCAL-v2)
origin/main (fetched) : e4566b5
worker worktree       : /private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/3/demo
worker HEAD           : c73bf9f (Update instruction marker to FRESH-LOCAL-v2) branch=HEAD
worker CLAUDE.md      : Instruction marker: FRESH-LOCAL-v2
worker status: done [at=1793192570]: booted with FRESH-LOCAL-v2
```

## S3: flag present, scout without --base-branch starts from the primary checkout main
```
$ FM_HOME=$LAB bin/fm-spawn.sh lab-scout $LAB/projects/demo --scout --harness claude --model sonnet --effort low
WARNING: watcher still down (same stale episode; last beat: never, grace 300s) - full banner already printed this episode.
spawned lab-scout harness=claude kind=scout window=firstmate:fm-lab-scout worktree=/private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/4/demo
exit=0
--- base facts for lab-scout
primary checkout main : c73bf9f (Update instruction marker to FRESH-LOCAL-v2)
origin/main (fetched) : e4566b5
worker worktree       : /private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/4/demo
worker HEAD           : c73bf9f (Update instruction marker to FRESH-LOCAL-v2) branch=HEAD
worker CLAUDE.md      : Instruction marker: FRESH-LOCAL-v2
worker status: done [at=1793192599]: done: booted with FRESH-LOCAL-v2
```

## S4: flag present, no-mistakes and direct-PR ships keep origin tip
```
$ FM_HOME=$LAB bin/fm-spawn.sh lab-nm $LAB/projects/demo --mode no-mistakes --yolo off --harness claude --model sonnet --effort low
WARNING: watcher still down (same stale episode; last beat: never, grace 300s) - full banner already printed this episode.
spawned lab-nm harness=claude kind=ship mode=no-mistakes yolo=off window=firstmate:fm-lab-nm worktree=/private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/5/demo
exit=0
--- base facts for lab-nm
primary checkout main : c73bf9f (Update instruction marker to FRESH-LOCAL-v2)
origin/main (fetched) : e4566b5
worker worktree       : /private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/5/demo
worker HEAD           : e4566b5 (seed demo) branch=HEAD
worker CLAUDE.md      : Instruction marker: STALE-ORIGIN-v1
worker status: done [at=1793192607]: booted with STALE-ORIGIN-v1

$ FM_HOME=$LAB bin/fm-spawn.sh lab-dpr $LAB/projects/demo --mode direct-PR --yolo off --harness claude --model sonnet --effort low
WARNING: watcher still down (same stale episode; last beat: never, grace 300s) - full banner already printed this episode.
spawned lab-dpr harness=claude kind=ship mode=direct-PR yolo=off window=firstmate:fm-lab-dpr worktree=/private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/6/demo
exit=0
--- base facts for lab-dpr
primary checkout main : c73bf9f (Update instruction marker to FRESH-LOCAL-v2)
origin/main (fetched) : e4566b5
worker worktree       : /private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/6/demo
worker HEAD           : e4566b5 (seed demo) branch=HEAD
worker CLAUDE.md      : Instruction marker: STALE-ORIGIN-v1
worker status: done [at=1793192621]: booted with STALE-ORIGIN-v1
```

## S5: flag present, primary diverged from origin (forge-only push): note + origin tip
```
$ FM_HOME=$LAB bin/fm-spawn.sh lab-div $LAB/projects/demo --mode local-only --yolo on --harness claude --model sonnet --effort low
WARNING: watcher still down (same stale episode; last beat: never, grace 300s) - full banner already printed this episode.
note: pooled worktree '/private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/8/demo': main in the primary checkout has diverged from origin/main (ahead by 1, behind by 1); starting from origin's tip
spawned lab-div harness=claude kind=ship mode=local-only yolo=on window=firstmate:fm-lab-div worktree=/private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/8/demo
exit=0
--- base facts for lab-div
primary checkout main : c73bf9f (Update instruction marker to FRESH-LOCAL-v2)
origin/main (fetched) : bbda8ab
worker worktree       : /private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/8/demo
worker HEAD           : bbda8ab (forge-only commit) branch=HEAD
worker CLAUDE.md      : Instruction marker: STALE-ORIGIN-v1
worker has forge-only.txt: yes
worker status: done [at=1793192689]: done: booted with STALE-ORIGIN-v1
```

## S6: flag present, named --base-branch keeps origin copy even when the local branch is ahead
```
origin/feature/hub=79fd75e local feature/hub=7b57a8d
$ FM_HOME=$LAB bin/fm-spawn.sh lab-base $LAB/projects/demo --scout --base-branch feature/hub --harness claude --model sonnet --effort low
WARNING: watcher still down (same stale episode; last beat: never, grace 300s) - full banner already printed this episode.
spawned lab-base harness=claude kind=scout window=firstmate:fm-lab-base worktree=/private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/9/demo
exit=0
--- base facts for lab-base
primary checkout main : c73bf9f (Update instruction marker to FRESH-LOCAL-v2)
origin/main (fetched) : bbda8ab
worker worktree       : /private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/9/demo
worker HEAD           : 79fd75e (hub on origin) branch=HEAD
worker CLAUDE.md      : Instruction marker: STALE-ORIGIN-v1
worker HEAD full=79fd75e == origin/feature/hub? yes; == local feature/hub? no
```

## Review anchor (bin/fm-review-diff.sh), after each task committed its own work
```
== R1: flag ON, local-only ship planted on the primary checkout's main ==
$ FM_HOME=$LAB bin/fm-review-diff.sh lab-optin --stat
WARNING: watcher still down (same stale episode; last beat: never, grace 300s) - full banner already printed this episode.
diff base: main
 farewell_lab-optin.py | 2 ++
 1 file changed, 2 insertions(+)
exit=0

== R2: flag ON, no-mistakes ship planted on origin/main ==
$ FM_HOME=$LAB bin/fm-review-diff.sh lab-nm --stat
WARNING: watcher still down (same stale episode; last beat: never, grace 300s) - full banner already printed this episode.
diff base: origin/main
 farewell_lab-nm.py | 2 ++
 1 file changed, 2 insertions(+)
exit=0

== R3: flag REMOVED (pre-change behavior), same local-only ship ==
$ FM_HOME=$LAB bin/fm-review-diff.sh lab-optin --stat
WARNING: watcher still down (same stale episode; last beat: never, grace 300s) - full banner already printed this episode.
diff base: origin/main
 CLAUDE.md             | 2 +-
 farewell_lab-optin.py | 2 ++
 2 files changed, 3 insertions(+), 1 deletion(-)
exit=0
== R4: flag ON, local-only ship that was planted on origin's tip before the opt-in ==
$ FM_HOME=$LAB bin/fm-review-diff.sh lab-default --stat
WARNING: watcher still down (same stale episode; last beat: never, grace 300s) - full banner already printed this episode.
diff base: main
 own_work.py | 1 +
 1 file changed, 1 insertion(+)
exit=0
```

## Promotion wording (bin/fm-promote.sh)
```
== P1: flag ON, scout (planted on primary main) promoted to no-mistakes ==
$ FM_HOME=$LAB bin/fm-promote.sh lab-scout --mode no-mistakes --yolo off
WARNING: watcher still down (same stale episode; last beat: never, grace 300s) - full banner already printed this episode.
promoted lab-scout to ship mode=no-mistakes yolo=off (teardown protection restored)
wrote ship instructions for mode=no-mistakes: /private/tmp/fmpb.nefE3r/home/data/lab-scout/ship-instructions.md
next: FM_HOME=/private/tmp/fmpb.nefE3r/home bin/fm-send.sh fm-lab-scout "$(cat /private/tmp/fmpb.nefE3r/home/data/lab-scout/ship-instructions.md)"
exit=0
11:3. Return to a clean copy of origin's default branch rather than the primary checkout's, which can carry commits origin has never received, then create your branch: `git checkout -b fm/lab-scout --`.


== P2: flag ABSENT, scout promoted to no-mistakes ==
$ FM_HOME=$LAB bin/fm-promote.sh lab-scout2 --mode no-mistakes --yolo off
WARNING: watcher still down (same stale episode; last beat: never, grace 300s) - full banner already printed this episode.
promoted lab-scout2 to ship mode=no-mistakes yolo=off (teardown protection restored)
wrote ship instructions for mode=no-mistakes: /private/tmp/fmpb.nefE3r/home/data/lab-scout2/ship-instructions.md
next: FM_HOME=/private/tmp/fmpb.nefE3r/home bin/fm-send.sh fm-lab-scout2 "$(cat /private/tmp/fmpb.nefE3r/home/data/lab-scout2/ship-instructions.md)"
exit=0
11:3. Return to a clean default-branch base, then create your branch: `git checkout -b fm/lab-scout2 --`.


== P3: flag ON, named-base scout promoted to no-mistakes ==
$ FM_HOME=$LAB bin/fm-promote.sh lab-base --mode no-mistakes --yolo off
WARNING: watcher still down (same stale episode; last beat: never, grace 300s) - full banner already printed this episode.
promoted lab-base to ship mode=no-mistakes yolo=off (teardown protection restored)
wrote ship instructions for mode=no-mistakes: /private/tmp/fmpb.nefE3r/home/data/lab-base/ship-instructions.md
next: FM_HOME=/private/tmp/fmpb.nefE3r/home bin/fm-send.sh fm-lab-base "$(cat /private/tmp/fmpb.nefE3r/home/data/lab-base/ship-instructions.md)"
exit=0
11:3. Return to a clean copy of the base branch `feature/hub`, then create your branch: `git checkout -b fm/lab-base --`.
```

## Worker panes (boot evidence)
### lab-default
```
 ▐▛███▛█   Claude Code v2.1.312
▝▜██████▀  Sonnet 5.5 with low effort · Claude Max
 ▝▝   ▝▝   /private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/2/demo
❯ : Firstmate operational input waiting: read '/private/tmp/fmpb.nefE3r/home/state/operational-inbox/1793192536-e3a118cc8c9a24f3.msg' and handle its contents as Firstmate operational input.
  Read 1 file, ran 1 shell command
⏺ done: booted with STALE-ORIGIN-v1
✻ Baked for 12s · done 2:02 PM
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
❯ 
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
  Sonnet 5.5 demo/HEAD ░░░░░6% 13s +0-0 2026-10-28 14:02
  ⏵⏵ auto mode on (shift+tab to cycle)
```
### lab-optin
```
 ▐▛███▛█   Claude Code v2.1.312
▝▜██████▀  Sonnet 5.5 with low effort · Claude Max
 ▝▝   ▝▝   /private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/3/demo
❯ : Firstmate operational input waiting: read '/private/tmp/fmpb.nefE3r/home/state/operational-inbox/1793192561-b44cfb644e02ef60.msg' and handle its contents as Firstmate operational input.
  Read 1 file, ran 1 shell command
⏺ done: booted with FRESH-LOCAL-v2
✻ Sautéed for 8s · done 2:02 PM
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
❯ 
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
  Sonnet 5.5 demo/HEAD ░░░░░6% 9s +0-0 2026-10-28 14:02
  ⏵⏵ auto mode on (shift+tab to cycle)
```
### lab-nm
```
 ▐▛███▛█   Claude Code v2.1.312
▝▜██████▀  Sonnet 5.5 with low effort · Claude Max
 ▝▝   ▝▝   /private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/5/demo
❯ : Firstmate operational input waiting: read '/private/tmp/fmpb.nefE3r/home/state/operational-inbox/1793192594-6db694a6580d5d3a.msg' and handle its contents as Firstmate operational input.
  Read 1 file, ran 1 shell command
⏺ done: booted with STALE-ORIGIN-v1
✻ Brewed for 11s · done 2:03 PM
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
❯ 
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
  Sonnet 5.5 demo/HEAD ░░░░░7% 12s +0-0 2026-10-28 14:03
  ⏵⏵ auto mode on (shift+tab to cycle)
```
### lab-div
```
 ▐▛███▛█   Claude Code v2.1.312
▝▜██████▀  Sonnet 5.5 with low effort · Claude Max
 ▝▝   ▝▝   /private/tmp/fmpb.nefE3r/treehouse/.treehouse/demo-989807/8/demo
❯ : Firstmate operational input waiting: read '/private/tmp/fmpb.nefE3r/home/state/operational-inbox/1793192680-483a72d49ea5fae7.msg' and handle its contents as Firstmate operational input.
  Read 1 file, ran 1 shell command
⏺ I appended the status line done: booted with STALE-ORIGIN-v1 to /private/tmp/fmpb.nefE3r/home/state/lab-div.status. The marker came from the CLAUDE.md loaded into my context at launch.
  I didn't read any project files, run git, create the branch or commit, because the spec ruled those out. The worktree is untouched.
✻ Crunched for 8s · done 2:04 PM
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
❯ 
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
  Sonnet 5.5 demo/HEAD ░░░░░6% 9s +0-0 2026-10-28 14:04
```
