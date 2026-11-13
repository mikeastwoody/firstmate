# Live transcript: claudeMdExcludes for a Claude secondmate (Claude Code 2.1.323 (Claude Code), 2026-11-13T13:31:16Z)
Lab home (bin/fm-lab-home.sh): /private/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.UWf0Gs
Mate homes root (under a dir named 'projects'): /private/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-pm-mates.5LTBXX/projects

## 1. Real bin/fm-spawn.sh sm <home> --secondmate (tmux backend = launch recorder only)
spawned sm harness=claude kind=secondmate mode=secondmate yolo=off window=firstmate:fm-sm worktree=/private/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-pm-mates.5LTBXX/projects/sm
launch carries: --settings '/private/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.UWf0Gs/state/sm.claude-settings.json'
state/sm.claude-settings.json (non-hook keys):
{
  "claudeMdExcludes": [
    "/private/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-pm-mates.5LTBXX/projects/sm/projects/**/CLAUDE*.md",
    "/private/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-pm-mates.5LTBXX/projects/sm/projects/**/AGENTS.md",
    "/private/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-pm-mates.5LTBXX/projects/sm/projects/**/.claude/rules/**"
  ],
  "feedbackDrafts": "off",
  "attribution": {
    "commit": "",
    "pr": "",
    "sessionUrl": false
  },
  "hook_events": [
    "SessionEnd",
    "Stop",
    "StopFailure",
    "UserPromptSubmit"
  ]
}
mate home .claude/settings.local.json sha256 before: c9737a4421b270065ee21b308802dae08b03e161fe1960fc629385c1a9366f5d
mate home .claude/settings.local.json sha256 after:  c9737a4421b270065ee21b308802dae08b03e161fe1960fc629385c1a9366f5d
mate home .claude/ contents after spawn: settings.local.json

## 2. Real 'claude -p' in the mate home, scripted local API (tests/fixtures/fm-claude-read-replay.py) asks for one Read of projects/app/src/file.txt
(home = home CLAUDE.md marker reached the session; clone/import/rule = clone CLAUDE.md, its @AGENTS.md import, its .claude/rules/always.md in the request carrying the Read result)
arm=baseline (1s): home=1 clone=1 import=1 rule=1
arm=spawn (1s): home=1 clone=0 import=0 rule=0
arm=bareglob (0s): home=0 clone=0 import=0 rule=0
arm=relative (1s): home=1 clone=1 import=1 rule=1
  baseline = no settings; spawn = the --settings file fm-spawn wrote; bareglob = **/projects/** patterns; relative = projects/**/ patterns

## 3. Primary: documented snippet in the home's .claude/settings.local.json (no --settings), home under a dir named 'projects'
primary-before: home=1 clone=1 import=1 rule=1
primary-after: home=1 clone=0 import=0 rule=0
primary-unresolved: home=1 clone=1 import=1 rule=1
  before = settings.local.json with only {feedbackDrafts}; after = doc snippet with the pwd -P path merged in; unresolved = ./projects/** and $CLAUDE_PROJECT_DIR/projects/** spellings

## 4. Adversarial: mate home path with picomatch characters (projects/sm{1})
spawned sm2 harness=claude kind=secondmate mode=secondmate yolo=off window=firstmate:fm-sm2 worktree=/private/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-pm-mates.5LTBXX/projects/sm{1}
warning: sm2's Claude session will load the instructions of the projects cloned under /private/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-pm-mates.5LTBXX/projects/sm{1}/projects, because that path cannot be written as a claudeMdExcludes pattern
state/sm2.claude-settings.json keys: ["attribution","feedbackDrafts","hooks"]

## 5. Crewmate (ship worker): real bin/fm-spawn.sh crew-1 <project> --mode no-mistakes
spawned crew-1 harness=claude kind=ship mode=no-mistakes yolo=off window=firstmate:fm-crew-1 worktree=/private/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.UWf0Gs/wt-app
inline --settings keys: ["attribution","feedbackDrafts"]; worktree .claude/settings.local.json keys: ["hooks"]
real claude -p in the worktree with that --settings, reading src/file.txt: project CLAUDE.md=1 import=1 rule=1
