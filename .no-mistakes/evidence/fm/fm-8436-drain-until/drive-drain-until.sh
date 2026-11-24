#!/usr/bin/env bash
# Live driver: real fm-captain-hold.sh (secondmate home, real tasks-axi on a
# disposable markdown backlog) publishes to a disposable parent home's channel;
# the real bin/fm-wake-drain.sh drains that parent home. Fakes only tmux/gh/etc.
set -u
ROOT=${ROOT:?}
. "$ROOT/tests/lib.sh"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-drain-until.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT
TASKS_AXI_BIN=$(command -v tasks-axi)
parent="$TMP_ROOT/parent-home"; mate="$TMP_ROOT/channel-mate-home"
mkdir -p "$parent/data" "$parent/state" "$parent/config" "$parent/projects"
mkdir -p "$mate/data" "$mate/state" "$mate/config" "$mate/projects"
fm_test_tasks_toml "$mate/.tasks.toml"
printf '# Synthetic secondmate home\n' > "$mate/AGENTS.md"
printf 'channel-mate\n' > "$mate/.fm-secondmate-home"
printf 'schema=fm-secondmate-parent.v1\nroute=local\nparent_home=%s\n' "$parent" > "$mate/.fm-secondmate-parent"
printf '## In flight\n\n## Queued\n\n## Done\n' > "$mate/data/backlog.md"
fb=$(fm_fakebin "$mate"); fm_fake_exit0 "$fb" tmux treehouse no-mistakes gh gh-axi
cap() { PATH="$mate/fakebin:$PATH" REAL_TASKS_AXI="$TASKS_AXI_BIN" FM_HOME="$mate" \
  FM_STATE_OVERRIDE="$mate/state" FM_DATA_OVERRIDE="$mate/data" FM_CONFIG_OVERRIDE="$mate/config" \
  "$ROOT/bin/fm-captain-hold.sh" "$@"; }
drain() { echo "\$ FM_STATE_OVERRIDE=<parent>/state bin/fm-wake-drain.sh   # drain #$1"
  FM_STATE_OVERRIDE="$parent/state" "${DRAIN_BIN:-$ROOT/bin/fm-wake-drain.sh}" > "$TMP_ROOT/out" 2>"$TMP_ROOT/err"; rc=$?
  sed -n '/OPEN DECISIONS/,$p' "$TMP_ROOT/out"; echo "(exit=$rc)"; echo; }
chan="$parent/state/channel-mate.status"
section() { echo "==================== $* ===================="; }

section "S1+S2: captain defers one call with hold --until, holds another undated"
echo "\$ fm-captain-hold.sh hold dated-call --title ... --reason 'pick the release train' --until 2026-12-11"
cap hold dated-call --title "Choose the dated release" --reason "pick the release train" --repo sample --until 2026-12-11
echo "\$ fm-captain-hold.sh hold owed-call --title ... --reason 'approve the API shape'   (no --until)"
cap hold owed-call --title "Approve API shape" --reason "approve the API shape" --repo sample
echo "--- parent channel status log as written by fm-captain-hold.sh:"; cat "$chan"; echo
drain 1

section "S3a: captain re-dates the same call (hold --until 2027-01-15)"
cap hold dated-call --reason "pick the release train" --until 2027-01-15 >/dev/null
tail -n 1 "$chan"; echo
drain 2

section "S3b: later UNDATED republish of the same key (hold without --until) clears the date"
cap hold dated-call --reason "pick the release train" >/dev/null
tail -n 1 "$chan"; echo
drain 3

section "S4: adversarial malformed / ambiguous [until=] fields (hand-appended to a task log)"
cat > "$parent/state/adv.status" <<'EOF'
needs-decision [key=word] [until=soon]: free-text date
needs-decision [key=short] [until=2026-1-5]: short date
needs-decision [key=twice] [until=2026-12-01] [until=2026-12-02]: two until fields
needs-decision [key=unclosed] [until=2026-12-01: unclosed bracket
needs-decision [key=inprose]: note mentions [until=2026-12-01] after the colon
EOF
cat "$parent/state/adv.status"; echo
drain 4

section "S5: per-line cap with a deferral date (220-char cap, shared marker)"
long=$(printf 'x%.0s' $(seq 1 400))
printf 'needs-decision [key=longk] [until=2026-12-11]: %s\n' "$long" > "$parent/state/capped.status"
FM_STATE_OVERRIDE="$parent/state" "$ROOT/bin/fm-wake-drain.sh" > "$TMP_ROOT/out" 2>&1
row=$(grep '^capped ' "$TMP_ROOT/out"); echo "row: $row"; echo "row length (chars): ${#row}"; echo

section "S6: captain answers the dated call -> row leaves OPEN DECISIONS"
printf 'Ship on the December train.\n' > "$TMP_ROOT/decision.txt"
cap answer dated-call --decision-file "$TMP_ROOT/decision.txt" >/dev/null; echo "answer exit=$?"
tail -n 1 "$chan"; echo
rm -f "$parent/state/adv.status" "$parent/state/capped.status"
drain 5
