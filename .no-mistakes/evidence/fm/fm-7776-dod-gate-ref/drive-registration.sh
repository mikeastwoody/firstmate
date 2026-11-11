#!/usr/bin/env bash
# Live driver for the #7776 done-gate change: runs the real bin/fm-pr-check.sh
# (registration, merge-time re-record, and scan) from the run worktree against
# disposable lab homes minted by bin/fm-lab-home.sh, with real git repositories
# (bare origin, project clone, linked or standalone worker copy, a local
# no-mistakes gate bare repo and a separate gate clone that pushes to origin).
# Only external forge CLIs are stand-ins (glab is not installed on this host,
# and no real forge may be contacted); git-remote-hang stands in for a network
# remote that never answers.
# Usage: drive-registration.sh <product-root> [<base-bin-root> <prefix-bin-root>]
set -u
PRODUCT=$1
BASE_ROOT=${2:-}
PREFIX_ROOT=${3:-}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/fm7776-work.XXXXXX")
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
for tool in glab gh tea; do
  printf '#!/bin/sh\nprintf "%%s %%s\\n" %s "$*" >> "%s/forge.log"\nexit 1\n' "$tool" "$WORK" > "$SHIMS/$tool"
done
printf '#!/bin/sh\nexec sleep 30\n' > "$SHIMS/git-remote-hang"
chmod +x "$SHIMS"/*

new_lab() {
  local lab
  lab=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")
  "$PRODUCT/bin/fm-lab-home.sh" create "$lab" >/dev/null || { echo "lab create failed" >&2; exit 1; }
  mkdir -p "$lab/tmux"
  printf '%s\n' "$lab" >> "$WORK/labs.list"
  printf '%s\n' "$lab"
}

# run_check <root> <lab> [env...] -- <args...>
run_check() {
  local root=$1 lab=$2; shift 2
  local envs=()
  while [ "$1" != -- ]; do envs+=("$1"); shift; done
  shift
  env -u TMUX -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE \
    TMUX_TMPDIR="$lab/tmux" FM_HOME="$lab" PATH="$SHIMS:$PATH" "${envs[@]}" \
    "$root/bin/fm-pr-check.sh" "$@"
}

write_meta() {  # <lab> <id> <wt> <project>
  printf '%s\n' "window=firstmate:fm-$2" "endpoint_task_id=$2" "worktree=$3" "project=$4" \
    "kind=ship" "mode=no-mistakes" "spawn_gen=lab-$2" > "$1/state/$2.meta"
}

# A project clone with a bare origin and a local no-mistakes gate bare repo.
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
  git -C "$d/project" remote add no-mistakes "$d/gate.git"
}

# The worker pushes to the local gate (this creates refs/remotes/no-mistakes/<b>).
worker_push_to_gate() {  # <wt> <branch>
  git -C "$1" push -q no-mistakes "$2"
}

# The pipeline pushes from its own gate clone to origin; the copy never fetches it.
gate_clone_push_to_origin() {  # <name> <branch>
  local d="$WORK/$1" c="$WORK/$1/gate-clone-$RANDOM"
  git clone -q "$d/gate.git" "$c"
  git -C "$c" push -q "$d/origin.git" "refs/remotes/origin/$2:refs/heads/$2"
  rm -rf "$c"
}

has_ref() { git -C "$1" rev-parse -q --verify "$2" >/dev/null 2>&1; }
meta_pr() { grep '^pr=' "$1" | tail -1 || true; }
say() { printf '%s\n' "$*"; }
hr() { printf '\n==== %s ====\n' "$*"; }

PASS=0 FAIL=0
check() {  # <desc> <cmd...>
  local desc=$1; shift
  if "$@"; then say "  PASS: $desc"; PASS=$((PASS + 1)); else say "  FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

say "product: $PRODUCT ($(git -C "$PRODUCT" rev-parse --short HEAD))"
say "git: $(git --version); bash: ${BASH_VERSION}"

#############################################################################
hr "S1 gate-mirror-only head is refused at PR registration (GitLab MR, no-mistakes)"
LAB=$(new_lab)
mk_project s1
P="$WORK/s1/project" W="$WORK/s1/wt-task-a"
git -C "$P" worktree add -q -b fm/task-a "$W" main
git -C "$W" commit -q --allow-empty -m 'fix pushed only to the local gate'
SHA=$(git -C "$W" rev-parse HEAD)
worker_push_to_gate "$W" fm/task-a
# A canary branch on the gate: if a refresh ever fetched the gate it would appear.
git -C "$WORK/s1/gate.git" update-ref refs/heads/canary "$SHA"
# A probe branch on origin the project has not fetched: it appears only if the refresh fetched origin.
git -C "$WORK/s1/origin.git" update-ref refs/heads/probe "$(git -C "$P" rev-parse main)"
write_meta "$LAB" task-a "$W" "$P"
URL=https://gitlab.example.test/g/r/-/merge_requests/4
say "named head: $SHA"
say "refs holding it before registration:"; git -C "$P" for-each-ref --contains "$SHA" --format='  %(refname)' refs/remotes
out=$(run_check "$PRODUCT" "$LAB" -- task-a "$URL" 2>&1); rc=$?
say "\$ fm-pr-check.sh task-a $URL   -> exit $rc"; say "$out" | sed 's/^/  | /'
check "registration refused (exit 1)" [ "$rc" = 1 ]
check "reason names the head as unreachable outside the worker copy" grep -qF "error: named head $SHA is unreachable outside the worker copy" <<<"$out"
check "no pr= recorded" [ -z "$(meta_pr "$LAB/state/task-a.meta")" ]
check "refresh did not fetch the no-mistakes gate (no canary ref)" bash -c "! git -C '$P' rev-parse -q --verify refs/remotes/no-mistakes/canary >/dev/null"
check "origin WAS refreshed (its new probe branch is now tracked)" has_ref "$P" refs/remotes/origin/probe
if [ -n "$BASE_ROOT" ]; then
  BLAB=$(new_lab)
  write_meta "$BLAB" task-a "$W" "$P"
  bout=$(run_check "$BASE_ROOT" "$BLAB" -- task-a "$URL" 2>&1); brc=$?
  say "BASE (1d43f9cb) same fixture -> exit $brc; $(meta_pr "$BLAB/state/task-a.meta")"; say "$bout" | sed 's/^/  | /'
  check "base commit accepted the gate-mirror-only head (the #7776 bug reproduced)" [ "$brc" = 0 ]
fi

#############################################################################
hr "S2 head the pipeline pushed to origin from its gate clone is accepted after the refresh"
gate_clone_push_to_origin s1 fm/task-a
say "origin holds: $(git -C "$WORK/s1/origin.git" rev-parse refs/heads/fm/task-a 2>/dev/null || echo none)"
check "fixture: copy/project have NOT fetched origin's branch" bash -c "! git -C '$P' rev-parse -q --verify refs/remotes/origin/fm/task-a >/dev/null"
out=$(run_check "$PRODUCT" "$LAB" -- task-a "$URL" 2>&1); rc=$?
say "\$ fm-pr-check.sh task-a $URL   -> exit $rc"; say "$out" | sed 's/^/  | /'
check "registration accepted (exit 0)" [ "$rc" = 0 ]
check "pr= recorded in meta" [ "$(meta_pr "$LAB/state/task-a.meta")" = "pr=$URL" ]
check "refresh left origin's head in the refs" [ "$(git -C "$P" rev-parse refs/remotes/origin/fm/task-a 2>/dev/null)" = "$SHA" ]
check "gate still not fetched (no canary ref)" bash -c "! git -C '$P' rev-parse -q --verify refs/remotes/no-mistakes/canary >/dev/null"
say "lab state after registration:"; ls "$LAB/state" | sed 's/^/  /'
say "meta:"; sed 's/^/  /' "$LAB/state/task-a.meta"

#############################################################################
hr "S3 merge-time re-record (FM_PR_CHECK_MERGE=1, as bin/fm-pr-merge.sh calls it) refreshes before refusing"
W3="$WORK/s1/wt-task-b"
git -C "$P" worktree add -q -b fm/task-b "$W3" main
git -C "$W3" commit -q --allow-empty -m 'fix for the merge-time case'
SHA3=$(git -C "$W3" rev-parse HEAD)
worker_push_to_gate "$W3" fm/task-b
write_meta "$LAB" task-b "$W3" "$P"
URL3=https://gitlab.example.test/g/r/-/merge_requests/5
out=$(run_check "$PRODUCT" "$LAB" FM_PR_CHECK_MERGE=1 -- task-b "$URL3" 2>&1); rc=$?
say "unpushed (gate mirror only): exit $rc"; say "$out" | sed 's/^/  | /'
check "merge-time re-record refuses an unpushed head" [ "$rc" = 1 ]
check "  with the unreachable reason" grep -qF "named head $SHA3 is unreachable outside the worker copy" <<<"$out"
gate_clone_push_to_origin s1 fm/task-b
out=$(run_check "$PRODUCT" "$LAB" FM_PR_CHECK_MERGE=1 -- task-b "$URL3" 2>&1); rc=$?
say "after the gate clone pushed to origin: exit $rc"; say "$out" | sed 's/^/  | /'
check "merge-time re-record accepts origin's unfetched head" [ "$rc" = 0 ]
check "  pr= recorded" [ "$(meta_pr "$LAB/state/task-b.meta")" = "pr=$URL3" ]

#############################################################################
hr "S4 failed refresh: refusal says the verdict used the last-known refs"
mk_project s4
P4="$WORK/s4/project" W4="$WORK/s4/wt-task-c"
git -C "$P4" worktree add -q -b fm/task-c "$W4" main
git -C "$W4" commit -q --allow-empty -m 'fix behind an unreachable origin'
SHA4=$(git -C "$W4" rev-parse HEAD)
worker_push_to_gate "$W4" fm/task-c
git -C "$P4" remote set-url origin "$WORK/s4/missing.git"
write_meta "$LAB" task-c "$W4" "$P4"
out=$(run_check "$PRODUCT" "$LAB" -- task-c https://gitlab.example.test/g/r/-/merge_requests/6 2>&1); rc=$?
say "exit $rc"; say "$out" | sed 's/^/  | /'
check "refused (exit 1)" [ "$rc" = 1 ]
check "reason says could not refresh origin and used the last-known refs" grep -qF "error: named head $SHA4 is unreachable outside the worker copy; could not refresh remote: origin, so this verdict used the last-known refs and the work may be there; retry once the remote is reachable" <<<"$out"

#############################################################################
hr "S5 failed origins in a standalone copy and its project clone are named unambiguously"
mk_project s5
P5="$WORK/s5/project" W5="$WORK/s5/wt-task-d"
git clone -q "$P5" "$W5"
git -C "$W5" checkout -q -b fm/task-d
git -C "$W5" commit -q --allow-empty -m 'fix in a standalone copy'
git -C "$W5" remote set-url origin "$WORK/s5/missing-copy-origin.git"
git -C "$P5" remote set-url origin "$WORK/s5/missing-project-origin.git"
write_meta "$LAB" task-d "$W5" "$P5"
out=$(run_check "$PRODUCT" "$LAB" -- task-d https://gitlab.example.test/g/r/-/merge_requests/7 2>&1); rc=$?
say "exit $rc"; say "$out" | sed 's/^/  | /'
check "refused (exit 1)" [ "$rc" = 1 ]
check "names 'origin, origin (project clone)'" grep -qF "could not refresh remote: origin, origin (project clone), so this verdict used the last-known refs" <<<"$out"

#############################################################################
hr "S6 scan: a remote that hangs and sorts before origin cannot starve origin's refresh"
SLAB=$(new_lab)
mk_project s6
P6="$WORK/s6/project" W6="$WORK/s6/wt-task-e"
git -C "$P6" worktree add -q -b fm/task-e "$W6" main
git -C "$W6" commit -q --allow-empty -m 'fix the pipeline pushes from its gate clone'
SHA6=$(git -C "$W6" rev-parse HEAD)
worker_push_to_gate "$W6" fm/task-e
gate_clone_push_to_origin s6 fm/task-e
git -C "$P6" remote add backup hang::backup
say "remote order: $(git -C "$P6" remote | tr '\n' ' ')"
write_meta "$SLAB" task-e "$W6" "$P6"
URL6=https://gitlab.example.test/g/r/-/merge_requests/8
printf '%s\n' "done [at=2]: PR $URL6 checks green" > "$SLAB/state/task-e.status"
start=$(date +%s)
out=$(run_check "$PRODUCT" "$SLAB" FM_CHECK_TIMEOUT=14 -- scan 2>&1); rc=$?
el=$(( $(date +%s) - start ))
say "\$ FM_CHECK_TIMEOUT=14 fm-pr-check.sh scan -> exit $rc in ${el}s (budget 9s, refresh deadline start+4s)"; say "${out:-<no output>}" | sed 's/^/  | /'
check "scan exit 0" [ "$rc" = 0 ]
check "task-e registered (pr= recorded)" [ "$(meta_pr "$SLAB/state/task-e.meta")" = "pr=$URL6" ]
check "origin fetched behind the hanging remote" [ "$(git -C "$P6" rev-parse refs/remotes/origin/fm/task-e 2>/dev/null)" = "$SHA6" ]
check "scan finished within its budget" [ "$el" -le 10 ]
check "no refusal marker" [ ! -e "$SLAB/state/task-e.pr-register-refused" ]

#############################################################################
hr "S7 scan: a hanging remote in a standalone copy cannot starve the project clone's origin"
mk_project s7
P7="$WORK/s7/project" W7="$WORK/s7/wt-task-f"
git clone -q "$P7" "$W7"
git -C "$W7" checkout -q -b fm/task-f
git -C "$W7" commit -q --allow-empty -m 'fix in a standalone copy'
SHA7=$(git -C "$W7" rev-parse HEAD)
git -C "$W7" remote add fork hang::fork
# The pipeline's gate clone pushed this head to the project clone's origin.
git -C "$WORK/s7/origin.git" fetch -q "$W7" "fm/task-f:refs/heads/fm/task-f"
say "copy remotes: $(git -C "$W7" remote | tr '\n' ' '); project remotes: $(git -C "$P7" remote | tr '\n' ' ')"
URL7=https://gitlab.example.test/g/r/-/merge_requests/9
run_scan_s7() {  # <root> <lab>
  write_meta "$2" task-f "$W7" "$P7"
  printf '%s\n' "done [at=2]: PR $URL7 checks green" > "$2/state/task-f.status"
  start=$(date +%s)
  out=$(run_check "$1" "$2" FM_CHECK_TIMEOUT=16 -- scan 2>&1); rc=$?
  el=$(( $(date +%s) - start ))
}
if [ -n "$PREFIX_ROOT" ]; then
  PLAB=$(new_lab)
  run_scan_s7 "$PREFIX_ROOT" "$PLAB"
  say "BEFORE the last fix (a0f63350): scan exit $rc in ${el}s"; say "${out:-<no output>}" | sed 's/^/  | /'
  say "  pr recorded: $(meta_pr "$PLAB/state/task-f.meta" | sed 's/^$/none/')"
  check "a0f63350 starved the project clone's origin (refused, project origin unfetched)" bash -c "[ -z '$(meta_pr "$PLAB/state/task-f.meta")' ] && ! git -C '$P7' rev-parse -q --verify refs/remotes/origin/fm/task-f >/dev/null"
fi
SLAB7=$(new_lab)
run_scan_s7 "$PRODUCT" "$SLAB7"
say "AFTER (target): \$ FM_CHECK_TIMEOUT=16 fm-pr-check.sh scan -> exit $rc in ${el}s (budget 11s, refresh deadline start+6s)"; say "${out:-<no output>}" | sed 's/^/  | /'
check "scan exit 0" [ "$rc" = 0 ]
check "task-f registered (pr= recorded)" [ "$(meta_pr "$SLAB7/state/task-f.meta")" = "pr=$URL7" ]
check "project clone origin fetched behind the copy's hanging remote" [ "$(git -C "$P7" rev-parse refs/remotes/origin/fm/task-f 2>/dev/null)" = "$SHA7" ]
check "scan finished within its budget" [ "$el" -le 12 ]

hr "forge CLI stand-in calls"
cat "$WORK/forge.log" 2>/dev/null | sed 's/^/  /' || say "  (none)"
hr "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
