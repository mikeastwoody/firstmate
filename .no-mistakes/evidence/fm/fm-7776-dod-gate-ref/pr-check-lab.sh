#!/usr/bin/env bash
# Live lab driver: the real bin/fm-pr-check.sh (direct and scan) against a
# disposable marked lab home, real bare "origin" and no-mistakes gate repos,
# a real project clone, and a real worker worktree. Run with:
#   pr-check-lab.sh <repo-worktree> <base-commit>
set -u
REPO=$1
BASE=$2
SCR=$(cd "$(dirname "$0")" && pwd)

unset NO_MISTAKES_GATE FM_GATE_REFUSE_BYPASS FM_ROOT_OVERRIDE FM_STATE_OVERRIDE \
  FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE TMUX

LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")
LAB_BASE=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")
"$REPO/bin/fm-lab-home.sh" create "$LAB" >/dev/null || exit 1
"$REPO/bin/fm-lab-home.sh" create "$LAB_BASE" >/dev/null || exit 1
trap 'rm -rf "$LAB" "$LAB_BASE"' EXIT

# Base-commit copy of bin/ so the same scenario runs against the pre-fix code.
BASE_ROOT="$LAB_BASE/base-root"
mkdir -p "$BASE_ROOT"
git -C "$REPO" archive "$BASE" bin | tar -x -C "$BASE_ROOT"

# Isolated git identity; no user-global config or hooks reach the lab repos.
cat > "$LAB/gitconfig" <<EOF
[user]
	name = fm lab
	email = lab@example.invalid
[init]
	defaultBranch = main
EOF
export GIT_CONFIG_GLOBAL="$LAB/gitconfig" GIT_CONFIG_NOSYSTEM=1

# glab is only presence-checked before the gate on the GitLab path; this
# shim records any call so the transcript shows the gate never needed a forge.
mkdir -p "$LAB/pathbin"
cat > "$LAB/pathbin/glab" <<'SH'
#!/usr/bin/env bash
printf 'glab %s\n' "$*" >> "${FM_LAB_GLAB_LOG:?}"
exit 1
SH
chmod +x "$LAB/pathbin/glab"
export FM_LAB_GLAB_LOG="$LAB/glab.log"
: > "$FM_LAB_GLAB_LOG"
export PATH="$LAB/pathbin:$PATH"

say() { printf '\n### %s\n' "$*"; }
run() { printf '$ %s\n' "$*"; "$@"; }

mk_remotes() {  # <home>
  local h=$1
  mkdir -p "$h/remotes" "$h/projects" "$h/wt"
  git init -q --bare "$h/remotes/origin.git"
  git init -q --bare "$h/remotes/gate.git"
  git init -q "$h/seed"
  git -C "$h/seed" commit -q --allow-empty -m init
  git -C "$h/seed" push -q "$h/remotes/origin.git" main
  rm -rf "$h/seed"
  git clone -q "$h/remotes/origin.git" "$h/projects/demo"
  # no-mistakes init adds a remote named no-mistakes for its local gate repo.
  git -C "$h/projects/demo" remote add no-mistakes "$h/remotes/gate.git"
}

mk_task() {  # <home> <id> <branch> <mode> [standalone]
  local h=$1 id=$2 br=$3 mode=$4 standalone=${5:-} wt
  wt="$h/wt/$id"
  if [ -n "$standalone" ]; then
    git clone -q "$h/remotes/origin.git" "$wt"
    git -C "$wt" remote add no-mistakes "$h/remotes/gate.git"
    git -C "$wt" switch -q -c "$br"
  else
    git -C "$h/projects/demo" worktree add -q -b "$br" "$wt" origin/main
  fi
  git -C "$wt" commit -q --allow-empty -m "fix for $id"
  printf '%s\n' "kind=ship" "mode=$mode" "worktree=$wt" "project=$h/projects/demo" \
    "window=fm:fm-$id" "harness=claude" > "$h/state/$id.meta"
}

show_record() {  # <home> <id>
  local h=$1 id=$2
  printf 'meta pr= line: %s\n' "$(grep '^pr=' "$h/state/$id.meta" || echo '<none>')"
  printf 'published poll files: %s\n' "$(cd "$h/state" && ls -1 | grep -E "^$id\.pr-poll" | tr '\n' ' ' || true)"
}

pr_check() {  # <root> <home> <id> <url>
  local root=$1 h=$2 id=$3 url=$4 rc
  printf '$ FM_HOME=%s %s/bin/fm-pr-check.sh %s %s\n' "$h" "$root" "$id" "$url"
  FM_HOME="$h" "$root/bin/fm-pr-check.sh" "$id" "$url" 2>&1 | grep -v '^$'
  rc=${PIPESTATUS[0]}
  printf 'exit=%s\n' "$rc"
  show_record "$h" "$id"
  return 0
}

URL='https://gitlab.example.test/o/demo/-/merge_requests/4'

for h in "$LAB" "$LAB_BASE"; do mk_remotes "$h"; done

say "S1 adversarial: no-mistakes done whose head only reached the local gate mirror"
mk_task "$LAB" demo-fix fm/demo-fix no-mistakes
WT="$LAB/wt/demo-fix"
HEAD_SHA=$(git -C "$WT" rev-parse HEAD)
run git -C "$WT" push -q no-mistakes fm/demo-fix
printf 'worker HEAD=%s\n' "$HEAD_SHA"
printf 'refs containing HEAD (worker copy):\n'
git -C "$WT" for-each-ref --contains="$HEAD_SHA" --format='  %(refname)'
printf 'done: PR %s checks green\n' "$URL" > "$LAB/state/demo-fix.status"
printf 'status: %s\n' "$(cat "$LAB/state/demo-fix.status")"
say "S1 on THIS change ($(git -C "$REPO" rev-parse --short HEAD))"
pr_check "$REPO" "$LAB" demo-fix "$URL"

say "S1 on BASE commit ($(git -C "$REPO" rev-parse --short "$BASE")) - same fixture, pre-fix code"
mk_task "$LAB_BASE" demo-fix fm/demo-fix no-mistakes
git -C "$LAB_BASE/wt/demo-fix" push -q no-mistakes fm/demo-fix
git -C "$LAB_BASE/wt/demo-fix" for-each-ref --contains=HEAD --format='  %(refname)'
pr_check "$BASE_ROOT" "$LAB_BASE" demo-fix "$URL"

say "S2 watcher scan path: fm-pr-check.sh scan sees the done line and refuses it"
printf '$ FM_HOME=%s bin/fm-pr-check.sh scan\n' "$LAB"
FM_HOME="$LAB" "$REPO/bin/fm-pr-check.sh" scan 2>&1; printf 'exit=%s\n' "$?"
show_record "$LAB" demo-fix

say "S3 documented consequence: pipeline pushed to origin from the gate clone; copy has not fetched"
run git -C "$LAB/remotes/gate.git" push -q "$LAB/remotes/origin.git" fm/demo-fix
printf 'origin.git now holds fm/demo-fix=%s\n' "$(git -C "$LAB/remotes/origin.git" rev-parse fm/demo-fix)"
pr_check "$REPO" "$LAB" demo-fix "$URL"

say "S4 happy path: worker copy fetches origin -> registration accepted and poll armed"
run git -C "$WT" fetch -q origin
git -C "$WT" for-each-ref --contains="$HEAD_SHA" --format='  %(refname)'
pr_check "$REPO" "$LAB" demo-fix "$URL"

say "S4b scan after acceptance: nothing left to refuse"
FM_HOME="$LAB" "$REPO/bin/fm-pr-check.sh" scan 2>&1; printf 'exit=%s\n' "$?"

say "S5 nested gate branch fm/nested/fix only on the gate mirror -> refused"
mk_task "$LAB" nested-fix fm/nested/fix no-mistakes
git -C "$LAB/wt/nested-fix" push -q no-mistakes fm/nested/fix
git -C "$LAB/wt/nested-fix" for-each-ref --contains=HEAD --format='  %(refname)'
pr_check "$REPO" "$LAB" nested-fix "$URL"

say "S6 boundary: a real remote whose name merely starts with no-mistakes still counts"
mk_task "$LAB" fork-fix fm/fork-fix no-mistakes
git init -q --bare "$LAB/remotes/fork.git"
git -C "$LAB/projects/demo" remote add no-mistakes-fork "$LAB/remotes/fork.git"
git -C "$LAB/wt/fork-fix" push -q no-mistakes fm/fork-fix
git -C "$LAB/wt/fork-fix" push -q no-mistakes-fork fm/fork-fix
git -C "$LAB/wt/fork-fix" for-each-ref --contains=HEAD --format='  %(refname)'
pr_check "$REPO" "$LAB" fork-fix "$URL"

say "S7 standalone worker clone: only the project clone's gate mirror holds the head -> refused"
mk_task "$LAB" solo-fix fm/solo-fix no-mistakes standalone
SOLO="$LAB/wt/solo-fix"
git -C "$SOLO" push -q "$LAB/remotes/gate.git" fm/solo-fix
git -C "$LAB/projects/demo" fetch -q no-mistakes
printf 'worker copy refs containing HEAD:\n'
git -C "$SOLO" for-each-ref --contains=HEAD --format='  %(refname)'
printf 'project clone refs containing HEAD:\n'
git -C "$LAB/projects/demo" for-each-ref --contains="$(git -C "$SOLO" rev-parse HEAD)" --format='  %(refname)'
pr_check "$REPO" "$LAB" solo-fix "$URL"
say "S7b project clone fetches origin after the pipeline push -> accepted"
git -C "$LAB/remotes/gate.git" push -q "$LAB/remotes/origin.git" fm/solo-fix
git -C "$LAB/projects/demo" fetch -q origin
git -C "$LAB/projects/demo" for-each-ref --contains="$(git -C "$SOLO" rev-parse HEAD)" --format='  %(refname)'
pr_check "$REPO" "$LAB" solo-fix "$URL"

say "glab shim invocations during all runs (gate needs no forge read):"
if [ -s "$FM_LAB_GLAB_LOG" ]; then cat "$FM_LAB_GLAB_LOG"; else echo '<none>'; fi
