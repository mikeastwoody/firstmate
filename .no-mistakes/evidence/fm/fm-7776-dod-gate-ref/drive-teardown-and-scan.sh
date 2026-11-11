#!/usr/bin/env bash
# Live driver, part 2: runs the real bin/fm-teardown.sh (which now sources
# bin/fm-dod-lib.sh and shares fm_dod_refresh_remote_refs) and the real
# `bin/fm-pr-check.sh scan` deadline hand-off, from the run worktree, against
# disposable lab homes minted by bin/fm-lab-home.sh, with real git repositories.
# tmux calls go to the lab's private, empty tmux dir (TMUX_TMPDIR), never the
# default server. treehouse and no-mistakes are logging stand-ins: the real
# treehouse would act on the host's worktree pool, and this gate phase must not
# invoke the real no-mistakes CLI. gh/gh-axi/glab stand-ins keep every forge
# read off the network.
# Usage: drive-teardown-and-scan.sh <product-root>
set -u
PRODUCT=$1
WORK=$(mktemp -d "${TMPDIR:-/tmp}/fm7776-td.XXXXXX")
: > "$WORK/labs.list"
# new_lab runs in $(...), so the labs it mints are recorded in a file, not an array.
cleanup() {
  local lab
  while IFS= read -r lab; do
    [ -n "$lab" ] && [ -f "$lab/.fm-lab-home" ] && rm -rf -- "$lab"
  done < "$WORK/labs.list"
  rm -rf -- "$WORK"
}
trap cleanup EXIT

export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$WORK/gitconfig"
printf '[user]\n\tname = lab\n\temail = lab@example.invalid\n[init]\n\tdefaultBranch = main\n[advice]\n\tdetachedHead = false\n' > "$GIT_CONFIG_GLOBAL"

SHIMS="$WORK/shims"
mkdir -p "$SHIMS"
cat > "$SHIMS/treehouse" <<SH
#!/bin/sh
printf 'treehouse %s\n' "\$*" >> "$WORK/treehouse.log"
exit 0
SH
cat > "$SHIMS/no-mistakes" <<SH
#!/bin/sh
printf 'no-mistakes %s\n' "\$*" >> "$WORK/no-mistakes.log"
exit 0
SH
cat > "$SHIMS/gh-axi" <<'SH'
#!/bin/sh
case "${1:-} ${2:-}" in
  "pr list") printf '%s\n' "count: 0 (showing first 0)" "pull_requests[]: []"; exit 0 ;;
  "pr view") echo "error: pull request not found" >&2; exit 1 ;;
esac
exit 0
SH
for tool in gh glab tea; do
  printf '#!/bin/sh\nprintf "%%s %%s\\n" %s "$*" >> "%s/forge.log"\nexit 1\n' "$tool" "$WORK" > "$SHIMS/$tool"
done
cat > "$SHIMS/git-remote-probe" <<SH
#!/bin/sh
printf 'fetch %s\n' "\$1" >> "$WORK/probe.log"
sleep 60
exit 1
SH
chmod +x "$SHIMS"/*

new_lab() {
  local lab
  lab=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")
  # The lab allowance requires a canonical FM_HOME (macOS TMPDIR is behind /var -> /private/var).
  lab=$(cd "$lab" && pwd -P)
  "$PRODUCT/bin/fm-lab-home.sh" create "$lab" >/dev/null || { echo "lab create failed" >&2; exit 1; }
  mkdir -p "$lab/tmux"
  printf '%s\n' "$lab" >> "$WORK/labs.list"
  printf '%s\n' "$lab"
}

run_in_lab() {  # <lab> [env...] -- <script> <args...>
  local lab=$1; shift
  local envs=()
  while [ "$1" != -- ]; do envs+=("$1"); shift; done
  shift
  local script=$1; shift
  env -u TMUX -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE \
    TMUX_TMPDIR="$lab/tmux" FM_HOME="$lab" PATH="$SHIMS:$PATH" "${envs[@]}" \
    "$PRODUCT/bin/$script" "$@"
}

write_meta() {  # <lab> <id> <wt> <project> <mode>
  printf '%s\n' "window=firstmate:fm-$2" "endpoint_task_id=$2" "worktree=$3" "project=$4" \
    "kind=ship" "mode=$5" "spawn_gen=lab-$2" > "$1/state/$2.meta"
}

mk_project() {  # <name>
  local d="$WORK/$1"
  mkdir -p "$d"
  git init -q --bare "$d/origin.git"
  git init -q --bare "$d/gate.git"
  git init -q "$d/project"
  git -C "$d/project" commit -q --allow-empty -m init
  git -C "$d/project" remote add origin "$d/origin.git"
  git -C "$d/project" push -q origin main
  git -C "$d/project" fetch -q origin
  git -C "$d/project" remote set-head origin main
  git -C "$d/project" remote add no-mistakes "$d/gate.git"
}

mk_task_wt() {  # <name> <id>
  local d="$WORK/$1" w="$WORK/$1/wt-$2"
  git -C "$d/project" worktree add -q -b "fm/$2" "$w" main
  printf 'landed work\n' > "$w/feature.txt"
  git -C "$w" add feature.txt
  git -C "$w" commit -q -m "add feature for $2"
  printf '%s\n' "$w"
}

# The task's commits reach origin on another branch from another clone; the
# copy's own tracking refs never saw them.
land_from_other_clone() {  # <name> <id> <target-branch>
  local d="$WORK/$1" o="$WORK/$1/_other"
  git clone -q "$d/origin.git" "$o"
  git -C "$o" fetch -q "$d/project" "fm/$2"
  git -C "$o" push -q origin "FETCH_HEAD:refs/heads/$3"
  rm -rf "$o"
}

say() { printf '%s\n' "$*"; }
hr() { printf '\n==== %s ====\n' "$*"; }
PASS=0 FAIL=0
check() {
  local desc=$1; shift
  if "$@"; then say "  PASS: $desc"; PASS=$((PASS + 1)); else say "  FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}
show() { say "$1" | sed 's/^/  | /'; }

say "product: $PRODUCT ($(git -C "$PRODUCT" rev-parse --short HEAD))"
say "NO_MISTAKES_GATE is ${NO_MISTAKES_GATE:+set}${NO_MISTAKES_GATE:-unset} (lifecycle allowed only because each FM_HOME is a marked lab home)"

#############################################################################
hr "T1 teardown refreshes through the shared fm_dod_refresh_remote_refs and proves work landed from another clone"
LAB=$(new_lab)
mk_project t1
W=$(mk_task_wt t1 task-x1)
land_from_other_clone t1 task-x1 release
# A canary branch on the gate (pushed by URL, so no tracking ref is created).
git -C "$W" push -q "$WORK/t1/gate.git" HEAD:refs/heads/canary
say "before teardown, commits not on a tracked remote: $(git -C "$W" log --oneline HEAD --not --remotes -- | wc -l | tr -d ' ')"
write_meta "$LAB" task-x1 "$W" "$WORK/t1/project" no-mistakes
: > "$WORK/treehouse.log"
out=$(run_in_lab "$LAB" -- fm-teardown.sh task-x1 2>&1); rc=$?
say "\$ fm-teardown.sh task-x1 -> exit $rc"; show "$out"
check "teardown allowed (exit 0)" [ "$rc" = 0 ]
check "no REFUSED line" bash -c "! grep -q REFUSED <<<\"\$1\"" _ "$out"
check "origin's release branch was fetched into the copy's refs" git -C "$W" rev-parse -q --verify refs/remotes/origin/release
check "the no-mistakes gate was not fetched (no canary ref)" bash -c "! git -C '$W' rev-parse -q --verify refs/remotes/no-mistakes/canary >/dev/null"
check "treehouse return was reached" grep -q "treehouse return --force $W" "$WORK/treehouse.log"

#############################################################################
hr "T2 teardown with an unreachable origin refuses and names it (FM_DOD_REFRESH_FAILED)"
LAB=$(new_lab)
mk_project t2
W=$(mk_task_wt t2 task-x2)
land_from_other_clone t2 task-x2 release
git -C "$WORK/t2/project" remote set-url origin "$WORK/t2/missing.git"
write_meta "$LAB" task-x2 "$W" "$WORK/t2/project" direct-PR
: > "$WORK/treehouse.log"
out=$(run_in_lab "$LAB" -- fm-teardown.sh task-x2 2>&1); rc=$?
say "\$ fm-teardown.sh task-x2 -> exit $rc"; show "$out"
check "teardown refused (exit 1)" [ "$rc" = 1 ]
check "REFUSED line printed" grep -q REFUSED <<<"$out"
check "says 'Could not refresh remote: origin. This verdict used the last-known refs'" grep -qF "Could not refresh remote: origin. This verdict used the last-known refs, so the work may be there; retry once the remote is reachable." <<<"$out"
check "worktree kept, treehouse return not called" bash -c "[ -d '$W' ] && [ ! -s '$WORK/treehouse.log' ]"

#############################################################################
hr "T3 teardown of work only on the no-mistakes gate mirror refuses (gate never fetched)"
LAB=$(new_lab)
mk_project t3
W=$(mk_task_wt t3 task-x3)
git -C "$W" push -q no-mistakes fm/task-x3
git -C "$W" push -q "$WORK/t3/gate.git" HEAD:refs/heads/canary
say "refs holding the head: $(git -C "$W" for-each-ref --contains HEAD --format='%(refname)' refs/remotes | tr '\n' ' ')"
write_meta "$LAB" task-x3 "$W" "$WORK/t3/project" no-mistakes
: > "$WORK/treehouse.log"
out=$(run_in_lab "$LAB" -- fm-teardown.sh task-x3 2>&1); rc=$?
say "\$ fm-teardown.sh task-x3 -> exit $rc"; show "$out"
check "teardown refused (exit 1)" [ "$rc" = 1 ]
check "REFUSED line printed" grep -q REFUSED <<<"$out"
check "no refresh-failure note (origin fetched fine)" bash -c "! grep -q 'Could not refresh remote' <<<\"\$1\"" _ "$out"
check "the no-mistakes gate was not fetched (no canary ref)" bash -c "! git -C '$W' rev-parse -q --verify refs/remotes/no-mistakes/canary >/dev/null"
check "worktree kept, treehouse return not called" bash -c "[ -d '$W' ] && [ ! -s '$WORK/treehouse.log' ]"

#############################################################################
hr "S8 scan: once the refresh deadline passes the sweep starts no other task; the next sweep opens with it"
LAB=$(new_lab)
mk_project s8
W=$(mk_task_wt s8 task-a)
# Both tasks share one copy whose remotes are origin and backup, both served by
# a remote helper that sleeps and fails, so every refresh hangs to its bound.
git -C "$WORK/s8/project" remote set-url origin probe::origin
git -C "$WORK/s8/project" remote add backup probe::backup
write_meta "$LAB" task-a "$W" "$WORK/s8/project" no-mistakes
write_meta "$LAB" task-b "$W" "$WORK/s8/project" no-mistakes
printf '%s\n' 'done [at=2]: PR https://gitlab.example.test/g/r/-/merge_requests/11 checks green' > "$LAB/state/task-a.status"
printf '%s\n' 'done [at=2]: PR https://gitlab.example.test/g/r/-/merge_requests/12 checks green' > "$LAB/state/task-b.status"
SHA=$(git -C "$W" rev-parse HEAD)
start=$(date +%s)
out=$(run_in_lab "$LAB" FM_CHECK_TIMEOUT=16 -- fm-pr-check.sh scan 2>/dev/null); rc=$?
el=$(( $(date +%s) - start ))
say "sweep 1: \$ FM_CHECK_TIMEOUT=16 fm-pr-check.sh scan -> exit $rc in ${el}s"; show "${out:-<no output>}"
check "sweep 1 reports exactly one task" [ "$(printf '%s\n' "$out" | grep -c 'reported https')" = 1 ]
check "sweep 1 reports task-a with the last-known-refs reason" grep -qF "task-a reported https://gitlab.example.test/g/r/-/merge_requests/11 in a done line, but it was not recorded: named head $SHA is unreachable outside the worker copy; could not refresh remote: origin, backup, so this verdict used the last-known refs" <<<"$out"
check "task-b not started after the refresh deadline (no marker)" [ ! -e "$LAB/state/task-b.pr-register-refused" ]
check "sweep 1 within its 11s budget" [ "$el" -le 12 ]
start=$(date +%s)
out=$(run_in_lab "$LAB" FM_CHECK_TIMEOUT=16 -- fm-pr-check.sh scan 2>/dev/null); rc=$?
el=$(( $(date +%s) - start ))
say "sweep 2: -> exit $rc in ${el}s"; show "${out:-<no output>}"
check "sweep 2 opens with task-b and reports its last-known-refs refusal" grep -qF "task-b reported https://gitlab.example.test/g/r/-/merge_requests/12 in a done line, but it was not recorded: named head $SHA is unreachable outside the worker copy; could not refresh remote: origin, backup" <<<"$out"
check "sweep 2 does not re-report task-a" bash -c "! grep -q '^task-a' <<<\"\$1\"" _ "$out"

hr "stand-in calls"
say "no-mistakes stand-in calls: $(cut -d' ' -f2-3 "$WORK/no-mistakes.log" 2>/dev/null | sort | uniq -c | tr '\n' ';')"
say "treehouse stand-in calls (last case): $(cat "$WORK/treehouse.log" 2>/dev/null | tr '\n' ';')"
say "probe fetches: $(sort "$WORK/probe.log" 2>/dev/null | uniq -c | tr '\n' ';')"
hr "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
