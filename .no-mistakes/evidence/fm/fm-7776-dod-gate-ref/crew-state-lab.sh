#!/usr/bin/env bash
# Live lab driver: the real bin/fm-crew-state.sh reading a done: claim for a
# task whose pane lives on a private lab tmux server, in a marked disposable
# lab home with real bare origin/gate repos. Usage:
#   crew-state-lab.sh <repo-worktree> <base-commit>
set -u
REPO=$1
BASE=$2

unset NO_MISTAKES_GATE FM_GATE_REFUSE_BYPASS FM_ROOT_OVERRIDE FM_STATE_OVERRIDE \
  FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE TMUX

LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")
"$REPO/bin/fm-lab-home.sh" create "$LAB" >/dev/null || exit 1
mkdir -p "$LAB/tmux"
SOCK=
cleanup() {
  if [ -n "$SOCK" ] && [ -S "$SOCK" ]; then tmux -S "$SOCK" kill-server 2>/dev/null; fi
  rm -rf "$LAB"
}
trap cleanup EXIT

BASE_ROOT="$LAB/base-root"
mkdir -p "$BASE_ROOT"
git -C "$REPO" archive "$BASE" bin | tar -x -C "$BASE_ROOT"

cat > "$LAB/gitconfig" <<EOF
[user]
	name = fm lab
	email = lab@example.invalid
[init]
	defaultBranch = main
EOF
export GIT_CONFIG_GLOBAL="$LAB/gitconfig" GIT_CONFIG_NOSYSTEM=1

# The lab task's project has no no-mistakes CLI installed: mirror
# /opt/homebrew/bin without it and drop that dir from PATH, so crew-state
# reads only the pane and status log and never reaches a real daemon.
mkdir -p "$LAB/pathbin"
for f in /opt/homebrew/bin/*; do
  [ "${f##*/}" = no-mistakes ] || ln -s "$f" "$LAB/pathbin/${f##*/}"
done
NEWPATH="$LAB/pathbin"
IFS=: read -r -a parts <<<"$PATH"
for p in "${parts[@]}"; do [ "$p" = /opt/homebrew/bin ] || NEWPATH="$NEWPATH:$p"; done
export PATH="$NEWPATH"
if command -v no-mistakes >/dev/null 2>&1; then echo "no-mistakes still on PATH"; exit 1; fi

# Private lab tmux server; every tmux call below and inside crew-state is
# routed to it through TMUX/TMUX_TMPDIR, never the default server.
export TMUX_TMPDIR="$LAB/tmux"
tmux -L fm-lab new-session -d -s fm -n placeholder -c "$LAB" || exit 1
SOCK=$(tmux -L fm-lab display -p '#{socket_path}')
PID=$(tmux -L fm-lab display -p '#{pid}')
export TMUX="$SOCK,$PID,0"
printf 'lab tmux socket: %s (crew-state resolves: %s)\n' "$SOCK" "$(tmux display -p '#{socket_path}')"

mkdir -p "$LAB/remotes" "$LAB/projects" "$LAB/wt"
git init -q --bare "$LAB/remotes/origin.git"
git init -q --bare "$LAB/remotes/gate.git"
git init -q "$LAB/seed"; git -C "$LAB/seed" commit -q --allow-empty -m init
git -C "$LAB/seed" push -q "$LAB/remotes/origin.git" main; rm -rf "$LAB/seed"
git clone -q "$LAB/remotes/origin.git" "$LAB/projects/demo"
git -C "$LAB/projects/demo" remote add no-mistakes "$LAB/remotes/gate.git"

mk_task() {  # <id> <branch> <mode> <done-line> [standalone]
  local id=$1 br=$2 mode=$3 line=$4 standalone=${5:-} wt gen
  wt="$LAB/wt/$id"
  if [ -n "$standalone" ]; then
    git clone -q "$LAB/remotes/origin.git" "$wt"
    git -C "$wt" switch -q -c "$br"
  else
    git -C "$LAB/projects/demo" worktree add -q -b "$br" "$wt" origin/main
  fi
  git -C "$wt" commit -q --allow-empty -m "fix for $id"
  printf '%s\n' "kind=ship" "mode=$mode" "worktree=$wt" "project=$LAB/projects/demo" \
    "window=fm:fm-$id" "harness=claude" > "$LAB/state/$id.meta"
  printf '%s\n' "$line" > "$LAB/state/$id.status"
  tmux new-window -d -t fm: -n "fm-$id" -c "$wt"
  # The Claude Stop hook records the harness as idle through fm-busy-event.sh.
  gen=$(FM_HOME="$LAB" "$REPO/bin/fm-busy-event.sh" arm "$LAB/state" "$id")
  FM_HOME="$LAB" "$REPO/bin/fm-busy-event.sh" apply "$LAB/state" "$id" idle --gen "$gen" \
    --source claude-hook --event stop
}

crew_state() {  # <root> <id>
  printf '$ FM_HOME=%s %s/bin/fm-crew-state.sh %s\n' "$LAB" "$1" "$2"
  FM_HOME="$LAB" "$1/bin/fm-crew-state.sh" "$2" 2>&1
  printf 'exit=%s\n' "$?"
}

say() { printf '\n### %s\n' "$*"; }

say "C1 no-mistakes done; head only on the local gate mirror"
mk_task nm-fix fm/nm-fix no-mistakes 'done: PR https://gitlab.example.test/o/demo/-/merge_requests/7 checks green'
git -C "$LAB/wt/nm-fix" push -q no-mistakes fm/nm-fix
printf 'HEAD=%s; refs containing it:\n' "$(git -C "$LAB/wt/nm-fix" rev-parse HEAD)"
git -C "$LAB/wt/nm-fix" for-each-ref --contains=HEAD --format='  %(refname)'
say "C1 on THIS change"
crew_state "$REPO" nm-fix
say "C1 on BASE commit"
crew_state "$BASE_ROOT" nm-fix

say "C2 pipeline pushed to origin and the copy fetched -> done"
git -C "$LAB/remotes/gate.git" push -q "$LAB/remotes/origin.git" fm/nm-fix
git -C "$LAB/wt/nm-fix" fetch -q origin
git -C "$LAB/wt/nm-fix" for-each-ref --contains=HEAD --format='  %(refname)'
crew_state "$REPO" nm-fix

say "C3 local-only done; branch in the project clone AND on the gate mirror -> done"
mk_task local-fix fm/local-fix local-only 'done: ready in branch fm/local-fix'
git -C "$LAB/wt/local-fix" push -q no-mistakes fm/local-fix
git -C "$LAB/wt/local-fix" for-each-ref --contains=HEAD --format='  %(refname)'
crew_state "$REPO" local-fix
printf 'pinned local done head in meta: %s\n' "$(grep -E '^(local_done_head|done_head)' "$LAB/state/local-fix.meta" || grep -v -E '^(kind|mode|worktree|project|window|harness)=' "$LAB/state/local-fix.meta" | tr '\n' ' ')"

say "C4 local-only standalone copy; head only on the project clone's gate mirror -> blocked"
mk_task solo-local fm/solo-local local-only 'done: ready in branch fm/solo-local' standalone
git -C "$LAB/wt/solo-local" push -q "$LAB/remotes/gate.git" fm/solo-local
git -C "$LAB/projects/demo" fetch -q no-mistakes
printf 'project clone refs containing HEAD:\n'
git -C "$LAB/projects/demo" for-each-ref --contains="$(git -C "$LAB/wt/solo-local" rev-parse HEAD)" --format='  %(refname)'
say "C4 on THIS change"
crew_state "$REPO" solo-local
say "C4 on BASE commit"
crew_state "$BASE_ROOT" solo-local

say "lab tmux windows"
tmux list-windows -t fm -F '  #{window_name}'
