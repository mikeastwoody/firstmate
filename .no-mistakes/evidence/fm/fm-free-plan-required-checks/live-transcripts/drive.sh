#!/usr/bin/env bash
# Drives the real bin/fm-pr-merge.sh and bin/fm-park.sh, through the real gh CLI,
# against the local GitHub API emulator (ghemu.py), in disposable lab homes.
set -u
WT={run-worktree}
EVID=$1
PORT=${PORT:-18766}
RUN=$(mktemp -d "${TMPDIR:-/tmp}/fm-live-run.XXXXXX")
PTR=$RUN/active
URL=https://github.localhost/example/repo/pull/120
: > "$PTR"
python3 -I /tmp/fmlive/ghemu.py "$PORT" "$PTR" 2> "$RUN/emu.err" &
EMU=$!
LABS=$RUN/labs; : > "$LABS"
cleanup() {
  kill $EMU 2>/dev/null; wait $EMU 2>/dev/null
  if [ "${KEEP:-0}" != 1 ]; then
    while IFS= read -r l; do [ -n "$l" ] && rm -rf "$l"; done < "$LABS"
    rm -rf "$RUN"
  fi
}
trap cleanup EXIT
sleep 0.7

# A pushed feature commit whose message carries [skip ci], so it has no checks.
REPO=$RUN/repo
git init -q -b main "$REPO"
git -C "$REPO" -c user.name=Lab -c user.email=lab@example.invalid commit -q --allow-empty -m base
git -C "$REPO" checkout -q -b feature
printf 'tweak\n' > "$REPO/notes.txt"; git -C "$REPO" add notes.txt
git -C "$REPO" -c user.name=Lab -c user.email=lab@example.invalid commit -q -m 'docs: tweak notes [skip ci]'
HEAD_SHA=$(git -C "$REPO" rev-parse HEAD)
git -C "$REPO" update-ref refs/remotes/origin/feature "$HEAD_SHA"

new_lab() {  # <name> -> sets LAB, SC
  LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")
  printf '%s\n' "$LAB" >> "$LABS"
  "$WT/bin/fm-lab-home.sh" create "$LAB" >/dev/null || { echo "lab create failed"; exit 1; }
  mkdir -p "$LAB/tmux" "$LAB/user-home" "$LAB/ghcfg"
  printf 'github.localhost\n' > "$LAB/config/github-hosts"
  cat > "$LAB/.tasks.toml" <<'TOML'
backend = "markdown"

[markdown]
path = "data/backlog.md"
archive = "data/done-archive.md"
done_keep = 10
TOML
  printf '%s\n' '## In flight' '' '## Queued' '' '## Done' > "$LAB/data/backlog.md"
  printf '%s\n' "window=fm-task-x1" "worktree=$REPO" "project=$RUN/project" "kind=ship" "mode=no-mistakes" \
    > "$LAB/state/task-x1.meta"
  SC=$RUN/scen-$1; mkdir -p "$SC"; : > "$SC/requests.log"
  printf '%s\n' "$SC" > "$PTR"
}

fmenv() {
  env -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE \
    -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE -u GITHUB_TOKEN -u HTTPS_PROXY -u https_proxy \
    FM_HOME="$LAB" HOME="$LAB/user-home" GH_CONFIG_DIR="$LAB/ghcfg" \
    GH_TOKEN=lab-fake-token GH_ENTERPRISE_TOKEN=lab-fake-token GH_NO_UPDATE_NOTIFIER=1 GH_PROMPT_DISABLED=1 \
    HTTP_PROXY="http://127.0.0.1:$PORT" http_proxy="http://127.0.0.1:$PORT" NO_PROXY= no_proxy= \
    TMUX_TMPDIR="$LAB/tmux" "$@"
}

merge() {  # <name> [args...]
  local name=$1; shift
  local out=$EVID/$name.transcript.txt rc
  {
    echo "### scenario: $name"
    echo "### head commit: $HEAD_SHA ($(git -C "$REPO" log -1 --format=%s "$HEAD_SHA"))"
    echo "### config/github-required-checks:"
    if [ -e "$LAB/config/github-required-checks" ]; then sed 's/^/    /' "$LAB/config/github-required-checks"; else echo "    (absent)"; fi
    echo "### away-posture record: $([ -e "$LAB/state/.afk-contract" ] && echo present || echo absent)"
    echo "### emulated GitHub state:"; jq -c '{rules_hidden, rollup: [.rollup[] | {name, status, conclusion, startedAt}], check_runs: [.check_runs[] | {name, app: .app.slug, suite: .check_suite.id, conclusion}], workflow_runs: [.workflow_runs[] | {check_suite_id, event}]}' "$SC/scenario.json" | sed 's/^/    /'
    echo "\$ bin/fm-pr-merge.sh task-x1 $URL $*"
  } > "$out"
  (cd "$WT" && fmenv bin/fm-pr-merge.sh task-x1 "$URL" "$@") > "$SC/stdout" 2> "$SC/stderr"
  rc=$?
  {
    echo "--- stdout"; cat "$SC/stdout"
    echo "--- stderr"; cat "$SC/stderr"
    echo "--- exit code: $rc"
    echo "--- requests the emulated GitHub API received (via the real gh $(gh --version | head -1 | awk '{print $3}')):"
    sed 's/^/    /' "$SC/requests.log"
    echo "--- merge mutation reached GitHub: $([ -e "$SC/merged" ] && echo "YES (expectedHeadOid=$(cat "$SC/merged"))" || echo NO)"
  } >> "$out"
  echo "$name rc=$rc merged=$([ -e "$SC/merged" ] && echo yes || echo no)"
}

scenario() {  # <rules_hidden> <rollup-json> <check-runs-json> <workflow-runs-json>
  jq -n --arg head "$HEAD_SHA" --argjson hidden "$1" --argjson rollup "$2" --argjson cr "$3" --argjson wr "$4" \
    '{head: $head, rules_hidden: $hidden, rollup: $rollup, check_runs: $cr, workflow_runs: $wr}' > "$SC/scenario.json"
}

declare_checks() { printf '%s\n' "$@" > "$LAB/config/github-required-checks"; }
away() { (cd "$WT" && fmenv bin/fm-afk-contract.sh enter --words 'merge task-x1 when green' >/dev/null) || echo "away enter failed"; }

ROLL_FAIL='{"__typename":"CheckRun","name":"build","status":"COMPLETED","conclusion":"FAILURE","startedAt":"2026-11-14T10:00:00Z","completedAt":"2026-11-14T10:03:00Z","detailsUrl":"","checkSuite":{"workflowRun":{"workflow":{"name":"CI"}}}}'
ROLL_OK='{"__typename":"CheckRun","name":"build","status":"COMPLETED","conclusion":"SUCCESS","startedAt":"2026-11-14T10:05:00Z","completedAt":"2026-11-14T10:08:00Z","detailsUrl":"","checkSuite":{"workflowRun":{"workflow":{"name":"CI"}}}}'
CR_FAIL='{"name":"build","status":"completed","conclusion":"failure","started_at":"2026-11-14T10:00:00Z","app":{"id":15368,"slug":"github-actions"},"check_suite":{"id":1001}}'
CR_OK='{"name":"build","status":"completed","conclusion":"success","started_at":"2026-11-14T10:05:00Z","app":{"id":15368,"slug":"github-actions"},"check_suite":{"id":1002}}'
DECL='github.localhost/example/repo github-actions pull_request build'

park_gate() {  # <name>
  local name=$1 out=$EVID/$1.transcript.txt rc
  {
    echo "### scenario: $name"
    echo "### head commit: $HEAD_SHA ($(git -C "$REPO" log -1 --format=%s "$HEAD_SHA"))"
    echo "### config/github-required-checks:"
    if [ -e "$LAB/config/github-required-checks" ]; then sed 's/^/    /' "$LAB/config/github-required-checks"; else echo "    (absent)"; fi
    echo "### emulated GitHub state:"; jq -c '{rules_hidden, rollup_state, rollup: [.rollup[] | {name, status, conclusion, startedAt}], check_runs: [.check_runs[] | {name, app: .app.slug, suite: .check_suite.id, conclusion}], workflow_runs: [.workflow_runs[] | {check_suite_id, event}]}' "$SC/scenario.json" | sed 's/^/    /'
    echo "\$ bin/fm-park.sh gate task-x1"
  } > "$out"
  : > "$SC/requests.log"
  (cd "$WT" && fmenv FM_PARK_QUIET_SECS=60 bin/fm-park.sh gate task-x1) > "$SC/stdout" 2> "$SC/stderr"
  rc=$?
  {
    echo "--- stdout"; cat "$SC/stdout"
    echo "--- stderr"; cat "$SC/stderr"
    echo "--- exit code: $rc (0 clean, 3 unclean, 1 unreadable)"
    echo "--- requests the emulated GitHub API received:"; sed 's/^/    /' "$SC/requests.log"
  } >> "$out"
  echo "$name rc=$rc"
}

case "${2:-all}" in
  merge|all)
  # S1: [skip ci] head, no checks at all, declaration present, standing (away) authority.
  new_lab s1-skipci-declared-away; away; declare_checks "$DECL"
  scenario true '[]' '[]' '[]'; merge s1-skipci-declared-away
  # S2: same head, no declaration file: behaviour unchanged (merges), standing authority.
  new_lab s2-skipci-undeclared-away; away
  scenario true '[]' '[]' '[]'; merge s2-skipci-undeclared-away
  # S3: failed pull_request run replaced by a later same-named workflow_dispatch success; declared; away.
  new_lab s3-dispatch-declared-away; away; declare_checks "$DECL"
  scenario true "[$ROLL_FAIL,$ROLL_OK]" "[$CR_FAIL,$CR_OK]" '[{"check_suite_id":1001,"event":"pull_request"},{"check_suite_id":1002,"event":"workflow_dispatch"}]'
  merge s3-dispatch-declared-away
  # S4: same as S3 without a declaration: merges as before.
  new_lab s4-dispatch-undeclared-away; away
  scenario true "[$ROLL_FAIL,$ROLL_OK]" "[$CR_FAIL,$CR_OK]" '[{"check_suite_id":1001,"event":"pull_request"},{"check_suite_id":1002,"event":"workflow_dispatch"}]'
  merge s4-dispatch-undeclared-away
  # S5: declared pull_request check re-run succeeded after a failure: merges.
  new_lab s5-rerun-declared-away; away; declare_checks "$DECL"
  scenario true "[$ROLL_FAIL,$ROLL_OK]" "[$CR_FAIL,$CR_OK]" '[{"check_suite_id":1001,"event":"pull_request"},{"check_suite_id":1002,"event":"pull_request"}]'
  merge s5-rerun-declared-away
  # S6: branch rules readable (plan does not hide them), declaration present, no checks: file not consulted.
  new_lab s6-rules-visible-declared; declare_checks "$DECL"
  scenario false '[]' '[]' '[]'; merge s6-rules-visible-declared
  # S7: malformed declaration (event "-" for github-actions) refuses and names the line.
  new_lab s7-malformed-declared; declare_checks '# operator declarations' "github.localhost/example/repo github-actions - build"
  scenario true "[$ROLL_OK]" "[$CR_OK]" '[{"check_suite_id":1002,"event":"pull_request"}]'; merge s7-malformed-declared
  # S8: attended --allow-missing build waives the unreported declared check by name.
  new_lab s8-skipci-declared-waived; declare_checks "$DECL"
  scenario true '[]' '[]' '[]'; merge s8-skipci-declared-waived --allow-missing build
  ;;
esac
case "${2:-all}" in
  park|all)
  # P: park-on-review gate reads the same declarations on a plan that hides branch rules.
  OLD_FAIL=${ROLL_FAIL//2026-11-14/2026-11-13}; OLD_OK=${ROLL_OK//2026-11-14/2026-11-13}
  OCR_FAIL=${CR_FAIL//2026-11-14/2026-11-13}; OCR_OK=${CR_OK//2026-11-14/2026-11-13}
  new_lab p1-park-skipci-declared; declare_checks "$DECL"
  printf '%s\n' "branch=feature" "harness=claude" "endpoint_task_id=task-x1" "pr=$URL" >> "$LAB/state/task-x1.meta"
  scenario true '[]' '[]' '[]'; park_gate p1-park-skipci-declared
  new_lab p2-park-dispatch-declared; declare_checks "$DECL"
  printf '%s\n' "branch=feature" "harness=claude" "endpoint_task_id=task-x1" "pr=$URL" >> "$LAB/state/task-x1.meta"
  scenario true "[$OLD_FAIL,$OLD_OK]" "[$OCR_FAIL,$OCR_OK]" '[{"check_suite_id":1001,"event":"pull_request"},{"check_suite_id":1002,"event":"workflow_dispatch"}]'
  park_gate p2-park-dispatch-declared
  new_lab p3-park-rerun-declared; declare_checks "$DECL"
  printf '%s\n' "branch=feature" "harness=claude" "endpoint_task_id=task-x1" "pr=$URL" >> "$LAB/state/task-x1.meta"
  scenario true "[$OLD_FAIL,$OLD_OK]" "[$OCR_FAIL,$OCR_OK]" '[{"check_suite_id":1001,"event":"pull_request"},{"check_suite_id":1002,"event":"pull_request"}]'
  park_gate p3-park-rerun-declared
  new_lab p4-park-dispatch-undeclared
  printf '%s\n' "branch=feature" "harness=claude" "endpoint_task_id=task-x1" "pr=$URL" >> "$LAB/state/task-x1.meta"
  scenario true "[$OLD_FAIL,$OLD_OK]" "[$OCR_FAIL,$OCR_OK]" '[{"check_suite_id":1001,"event":"pull_request"},{"check_suite_id":1002,"event":"workflow_dispatch"}]'
  park_gate p4-park-dispatch-undeclared
  ;;
esac
echo "RUN=$RUN"
