#!/usr/bin/env bash
# Live lab driver for #7776 (gate-mirror exclusion in the done: reachability gate).
# Runs the real firstmate scripts from the run worktree (and, for a before/after
# comparison, from the base commit exported into the lab) against a disposable,
# marked lab FM_HOME with real git remotes:
#   remotes/origin.git  - the real remote (bare)
#   remotes/gate.git    - stands where no-mistakes' local gate repo sits; added
#                         to the project as the `no-mistakes` remote, so a push
#                         to it creates refs/remotes/no-mistakes/<branch>
# Only external services are shimmed: glab (forge CLI; never called before the
# gate), no-mistakes daemon (answers "repo not initialized" as it does for an
# uninitialised repo), treehouse/gh/gh-axi for teardown.
# Usage: lab-driver.sh <run-worktree> <base-commit>
set -u
RUN_WT=$1
BASE=$2
LAB=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")" && pwd -P)   # canonical: the lab allowance requires it
"$RUN_WT/bin/fm-lab-home.sh" create "$LAB" >/dev/null || { echo "lab create failed"; exit 1; }
TMUXD=$("$RUN_WT/bin/fm-lab-home.sh" tmux-dir "$LAB") || { echo "lab tmux-dir failed"; exit 1; }
SOCK="$TMUXD/tmux-$(id -u)/default"
HANG_PID=
cleanup() {
  [ -z "$HANG_PID" ] || kill "$HANG_PID" 2>/dev/null
  [ -S "$SOCK" ] && tmux -S "$SOCK" kill-server 2>/dev/null
  "$RUN_WT/bin/fm-lab-home.sh" teardown "$LAB" >/dev/null 2>&1
  rm -rf "$LAB"
}
trap cleanup EXIT
git config --global --get user.name >/dev/null 2>&1 || true
export GIT_AUTHOR_NAME=lab GIT_AUTHOR_EMAIL=lab@example.invalid GIT_COMMITTER_NAME=lab GIT_COMMITTER_EMAIL=lab@example.invalid
unset FM_GATE_REFUSE_BYPASS FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE TMUX
export FM_HOME="$LAB"
export TMUX_TMPDIR="$TMUXD"   # every tmux call in the lab reaches only the lab's private server
STATE="$LAB/state"
touch "$STATE/.last-watcher-beat"

# --- base-commit copy of bin/ for the before/after comparison ---------------
mkdir -p "$LAB/base"
git -C "$RUN_WT" archive "$BASE" bin | tar -x -C "$LAB/base"

# --- external-service shims --------------------------------------------------
SHIMS="$LAB/shims"
mkdir -p "$SHIMS"
cat > "$SHIMS/glab" <<'SH'
#!/bin/sh
printf 'glab %s\n' "$*" >> "$FM_HOME/glab.log"
echo "glab: forge unreachable in the lab" >&2
exit 1
SH
cat > "$SHIMS/no-mistakes" <<'SH'
#!/bin/sh
echo "error: repo not initialized (run 'no-mistakes init' first)"
exit 1
SH
printf '#!/bin/sh\nexit 0\n' > "$SHIMS/treehouse"
cat > "$SHIMS/gh-axi" <<'SH'
#!/bin/sh
case "$1 $2" in
  "pr list") printf '%s\n' "count: 0 (showing first 0)" "pull_requests[]: []"; exit 0 ;;
esac
exit 1
SH
printf '#!/bin/sh\nexit 1\n' > "$SHIMS/gh"
chmod +x "$SHIMS"/*
export PATH="$SHIMS:$PATH"

# --- repositories -----------------------------------------------------------
R="$LAB/remotes"; mkdir -p "$R"
git init -q --bare -b main "$R/origin.git"
git init -q --bare -b main "$R/gate.git"
git clone -q "$R/origin.git" "$LAB/seed" 2>/dev/null
git -C "$LAB/seed" commit -q --allow-empty -m baseline
git -C "$LAB/seed" push -q origin main
rm -rf "$LAB/seed"
PROJECT="$LAB/projects/demo"
git clone -q "file://$R/origin.git" "$PROJECT"
git -C "$PROJECT" remote add no-mistakes "file://$R/gate.git"
git -C "$PROJECT" push -q no-mistakes main
# Sentinels written straight into the bare repos (no push, so no tracking ref
# is created locally): one branch only the gate holds, one only origin holds. A
# refresh that ran shows origin's; one that skipped the gate never shows the gate's.
git -C "$R/gate.git" update-ref refs/heads/gate-only-sentinel "$(git -C "$R/gate.git" rev-parse main)"
git -C "$R/origin.git" update-ref refs/heads/origin-sentinel "$(git -C "$R/origin.git" rev-parse main)"
tmux new-session -d -s fm -n placeholder
[ -S "$SOCK" ] || { echo "lab tmux server did not start on its private socket"; exit 1; }

mk_task() {  # <id> <mode> -> worktree path
  local id=$1 mode=$2 wt="$LAB/worktrees/$1"
  mkdir -p "$LAB/worktrees"
  git -C "$PROJECT" worktree add -q -b "fm/$id" "$wt" main
  printf '%s\n' "window=fm:fm-$id" "endpoint_task_id=$id" "worktree=$wt" "project=$PROJECT" \
    "kind=ship" "mode=$mode" "harness=claude" "spawn_gen=lab-$id" > "$STATE/$id.meta"
  tmux new-window -d -t fm: -n "fm-$id" -c "$wt"
  gen=$("$RUN_WT/bin/fm-busy-event.sh" arm "$STATE" "$id")
  "$RUN_WT/bin/fm-busy-event.sh" apply "$STATE" "$id" idle --gen "$gen" --source claude-hook --event stop >/dev/null
  printf '%s\n' "$wt"
}
commit_in() {  # <wt> <file>
  printf '%s\n' "$2" > "$1/$2.txt"
  git -C "$1" add "$2.txt"
  git -C "$1" commit -q -m "work $2"
  git -C "$1" rev-parse HEAD
}
has_ref() { git -C "$PROJECT" rev-parse -q --verify "$1" >/dev/null; }
section() { printf '\n==== %s ====\n' "$*"; }
run() { printf '$ %s\n' "$*"; "$@"; local rc=$?; printf '[exit %s]\n' "$rc"; return $rc; }

MR=https://gitlab.example.test/g/demo/-/merge_requests

#############################################################################
section "S1: done claim whose head reached ONLY the local no-mistakes gate mirror"
WT_A=$(mk_task task-a no-mistakes)
SHA_A=$(commit_in "$WT_A" a)
git -C "$WT_A" push -q no-mistakes fm/task-a    # the worker's /no-mistakes push
printf 'done: PR %s/1 checks green\n' "$MR" > "$STATE/task-a.status"
echo "named head: $SHA_A"
echo "refs holding it outside the copy:"; git -C "$PROJECT" for-each-ref --contains "$SHA_A" --format='  %(refname)' refs/remotes
echo "origin holds it? $(git -C "$R/origin.git" branch --contains "$SHA_A" 2>/dev/null | wc -l | tr -d ' ') branches"

section "S1a (before, base $BASE): crew-state and registration through the OLD gate"
run bash "$LAB/base/bin/fm-crew-state.sh" task-a
cp "$STATE/task-a.meta" "$LAB/task-a.meta.orig"
run bash "$LAB/base/bin/fm-pr-check.sh" task-a "$MR/1" 2>&1 | tail -3
echo "meta pr= after OLD registration: $(grep '^pr=' "$STATE/task-a.meta" || echo '(none)')"
cp "$LAB/task-a.meta.orig" "$STATE/task-a.meta"; rm -f "$STATE"/task-a.pr-poll* "$STATE"/task-a.pr-check* 2>/dev/null
echo "(task-a meta restored for the new-code run)"

section "S1b (after): crew-state read of the same done claim"
run "$RUN_WT/bin/fm-crew-state.sh" task-a

section "S1c (after): registration (bin/fm-pr-check.sh) of the same done claim"
run "$RUN_WT/bin/fm-pr-check.sh" task-a "$MR/1"
echo "meta pr= after NEW registration: $(grep '^pr=' "$STATE/task-a.meta" || echo '(none)')"
echo "refresh ran (origin-sentinel fetched)? $(has_ref refs/remotes/origin/origin-sentinel && echo yes || echo no)"
echo "gate fetched (gate-only-sentinel present)? $(has_ref refs/remotes/no-mistakes/gate-only-sentinel && echo yes || echo no)"
echo "glab calls: $(cat "$LAB/glab.log" 2>/dev/null | wc -l | tr -d ' ')"

section "S1d (after): merge-time re-record through bin/fm-pr-merge.sh"
run "$RUN_WT/bin/fm-pr-merge.sh" task-a "$MR/1"
echo "meta pr= after merge attempt: $(grep '^pr=' "$STATE/task-a.meta" || echo '(none)')"
echo "glab calls (a refused record makes none): $(cat "$LAB/glab.log" 2>/dev/null | wc -l | tr -d ' ')"

#############################################################################
section "S2: same task once the worker pushes the head to origin itself"
git -C "$WT_A" push -q origin fm/task-a
run "$RUN_WT/bin/fm-crew-state.sh" task-a
run "$RUN_WT/bin/fm-pr-check.sh" task-a "$MR/1"
echo "meta pr= : $(grep '^pr=' "$STATE/task-a.meta" || echo '(none)')"

#############################################################################
section "S3: GitLab no-mistakes task: pipeline pushes origin from its own gate clone; copy never fetched"
WT_B=$(mk_task task-b no-mistakes)
SHA_B=$(commit_in "$WT_B" b)
git -C "$WT_B" push -q no-mistakes fm/task-b
git clone -q "file://$R/gate.git" "$LAB/gate-clone"
git -C "$LAB/gate-clone" push -q "file://$R/origin.git" "origin/fm/task-b:refs/heads/fm/task-b"
printf 'done: PR %s/2 checks green\n' "$MR" > "$STATE/task-b.status"
echo "named head: $SHA_B; origin holds it: $(git -C "$R/origin.git" rev-parse -q --verify refs/heads/fm/task-b)"
echo "copy tracks origin/fm/task-b before registration? $(has_ref refs/remotes/origin/fm/task-b && echo yes || echo no)"
section "S3a: crew-state before registration (read never fetches)"
run "$RUN_WT/bin/fm-crew-state.sh" task-b
section "S3b: registration refreshes non-gate remotes, then accepts"
run "$RUN_WT/bin/fm-pr-check.sh" task-b "$MR/2"
echo "meta pr= : $(grep '^pr=' "$STATE/task-b.meta" || echo '(none)')"
echo "copy tracks origin/fm/task-b after registration? $(git -C "$PROJECT" rev-parse -q --verify refs/remotes/origin/fm/task-b || echo no)"
section "S3c: crew-state after registration sees the fetched head"
run "$RUN_WT/bin/fm-crew-state.sh" task-b

#############################################################################
section "S4: merge-time re-record (bin/fm-pr-merge.sh) of a GitLab task origin holds through the gate clone"
WT_C=$(mk_task task-c no-mistakes)
SHA_C=$(commit_in "$WT_C" c)
git -C "$WT_C" push -q no-mistakes fm/task-c
git -C "$LAB/gate-clone" fetch -q origin
git -C "$LAB/gate-clone" push -q "file://$R/origin.git" "origin/fm/task-c:refs/heads/fm/task-c"
printf 'done: PR %s/3 checks green\n' "$MR" > "$STATE/task-c.status"
: > "$LAB/glab.log"
echo "copy tracks origin/fm/task-c before merge? $(has_ref refs/remotes/origin/fm/task-c && echo yes || echo no)"
run "$RUN_WT/bin/fm-pr-merge.sh" task-c "$MR/3"
echo "meta pr= after merge attempt: $(grep '^pr=' "$STATE/task-c.meta" || echo '(none)')"
echo "copy tracks origin/fm/task-c after merge? $(git -C "$PROJECT" rev-parse -q --verify refs/remotes/origin/fm/task-c || echo no)"
echo "glab calls after record (the merge proceeded to the forge, which the lab shim fails):"; sed 's/^/  /' "$LAB/glab.log"

#############################################################################
section "S5: teardown refuses a gate-mirror-only head, and does not count the gate after its refresh"
WT_D=$(mk_task task-d no-mistakes)
SHA_D=$(commit_in "$WT_D" d)
git -C "$WT_D" push -q no-mistakes fm/task-d
touch "$STATE/.last-watcher-beat"
run "$RUN_WT/bin/fm-teardown.sh" task-d 2>&1 | grep -vE '^\s*$' | tail -8
echo "worktree still present? $([ -d "$WT_D" ] && echo yes || echo no)"
section "S5b: teardown of a task whose head origin holds via the gate clone (copy never fetched)"
WT_E=$(mk_task task-e no-mistakes)
SHA_E=$(commit_in "$WT_E" e)
git -C "$WT_E" push -q no-mistakes fm/task-e
git -C "$LAB/gate-clone" fetch -q origin
git -C "$LAB/gate-clone" push -q "file://$R/origin.git" "origin/fm/task-e:refs/heads/fm/task-e"
echo "copy tracks origin/fm/task-e before teardown? $(has_ref refs/remotes/origin/fm/task-e && echo yes || echo no)"
run "$RUN_WT/bin/fm-teardown.sh" task-e 2>&1 | grep -vE '^\s*$' | tail -8
echo "worktree still present? $([ -d "$WT_E" ] && echo yes || echo no)"
echo "gate-only-sentinel ever fetched? $(has_ref refs/remotes/no-mistakes/gate-only-sentinel && echo yes || echo no)"

#############################################################################
section "S6: watcher scan behind a remote that hangs (real git:// listener that never answers)"
python3 -c 'import socket,time,sys
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); s.bind(("127.0.0.1",0)); s.listen(8)
print(s.getsockname()[1]); sys.stdout.flush()
c=[]
while True:
    a,_=s.accept(); c.append(a)' > "$LAB/hang.port" &
HANG_PID=$!
sleep 1
PORT=$(cat "$LAB/hang.port")
git -C "$PROJECT" remote add slow "git://127.0.0.1:$PORT/never-answers.git"
WT_F=$(mk_task task-f no-mistakes); SHA_F=$(commit_in "$WT_F" f)
WT_G=$(mk_task task-g no-mistakes); SHA_G=$(commit_in "$WT_G" g)
printf 'done: PR %s/6 checks green\n' "$MR" > "$STATE/task-f.status"
printf 'done: PR %s/7 checks green\n' "$MR" > "$STATE/task-g.status"
echo "task-f head $SHA_F and task-g head $SHA_G exist only in their copies; remote slow=git://127.0.0.1:$PORT hangs"
for sweep in 1 2; do
  echo "-- sweep $sweep (FM_CHECK_TIMEOUT=16, as bin/fm-watch.sh runs it with config/pr-register-scan on)"
  t0=$(date +%s)
  printf '$ fm-pr-check.sh scan\n'
  FM_CHECK_TIMEOUT=16 FM_STATE_OVERRIDE="$STATE" "$RUN_WT/bin/fm-pr-check.sh" scan 2>/dev/null
  echo "[exit $?, $(( $(date +%s) - t0 ))s]  cursor=$(cat "$STATE/.pr-check-scan-cursor")  refused-markers: $(cd "$STATE" && ls *.pr-register-refused 2>/dev/null | tr '\n' ' ')"
done

section "lab teardown"
echo "rm -rf $LAB"
