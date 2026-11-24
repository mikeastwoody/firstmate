#!/usr/bin/env bash
# Live driver: the real bin/fm-spawn.sh spawns a Claude secondmate into a disposable lab
# home (only tmux is replaced by a launch-capturing shim, so no pane or real session is
# started), then the real installed `claude` runs in that secondmate home with the exact
# --settings file fm-spawn wrote, against the repo's scripted local replay server
# (no model, no tokens). A baseline run without the file shows what leaks otherwise.
# Usage: s2-spawn-then-claude.sh <repo-root> <home-path-variant: plain|pattern>
set -u
ROOT=$1 VARIANT=${2:-plain}
WORLD=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")" && pwd -P)
LAB=$WORLD/home; mkdir "$LAB"
cleanup() { [ -z "${SERVER_PID:-}" ] || kill "$SERVER_PID" 2>/dev/null; chmod -R u+w "$WORLD" 2>/dev/null; rm -rf "$WORLD"; }
trap cleanup EXIT
"$ROOT/bin/fm-lab-home.sh" create "$LAB" >/dev/null || { echo "lab create failed"; exit 1; }
mkdir -p "$LAB/config" "$LAB/state" "$LAB/data" "$LAB/user-home"
printf 'claude\n' > "$LAB/config/secondmate-harness"

# The secondmate home (outside the primary lab home, as fm-spawn requires) sits under a directory named projects (the bare **/projects/** trap).
if [ "$VARIANT" = pattern ]; then SM="$WORLD/projects/sm{1}"; else SM="$WORLD/projects/sm"; fi
mkdir -p "$SM/bin" "$SM/data" "$SM/.claude"
printf '# Firstmate\n' > "$SM/AGENTS.md"
printf 'fm-home-own-instructions-marker\n' > "$SM/CLAUDE.md"
printf 'sm\n' > "$SM/.fm-secondmate-home"
printf 'charter\n' > "$SM/data/charter.md"
printf '%s\n' projects/ state/ data/ config/ .no-mistakes/ > "$SM/.gitignore"
printf '{"operatorKey":"keep-me"}\n' > "$SM/.claude/settings.local.json"
git -C "$SM" init -q -b main
LOCAL_BEFORE=$(shasum "$SM/.claude/settings.local.json" | cut -d' ' -f1)

# A clone under the secondmate home's projects/: CLAUDE.md with an @import, an
# unconditional rule, and the file the session will read.
CLONE="$SM/projects/app"
mkdir -p "$CLONE/src" "$CLONE/.claude/rules" "$CLONE/docs"
printf 'fm-clone-instructions-marker\n@docs/imported.md\n' > "$CLONE/CLAUDE.md"
printf 'fm-clone-import-marker\n' > "$CLONE/docs/imported.md"
printf 'fm-clone-rule-marker\n' > "$CLONE/.claude/rules/always.md"
printf 'clone file\n' > "$CLONE/src/file.txt"
git -C "$CLONE" init -q

# Launch-capturing tmux shim (same shape as tests/fm-secondmate-harness.test.sh).
FAKE="$LAB/fakebin"; mkdir -p "$FAKE"
cat > "$FAKE/tmux" <<'SH'
#!/usr/bin/env bash
set -u
case "$*" in *"#{pane_current_path}"*) exit 0 ;; esac
wf="$(dirname "$0")/.spawn-window"
case "${1:-}" in
  display-message) printf 'firstmate\n' ;;
  list-windows) [ ! -s "$wf" ] || cat "$wf" ;;
  new-window) n=; p=; for a in "$@"; do [ "$p" = -n ] && n=$a; p=$a; done; printf '%s\n' "$n" > "$wf" ;;
  kill-window) : > "$wf" ;;
  send-keys) p=; for a in "$@"; do if [ "$p" = -l ]; then
      case "$a" in ". '"*"'") s=${a#". '"}; s=${s%"'"}; [ ! -f "$s" ] || a=$(cat "$s") ;; esac
      printf '%s\n' "$a" >> "$FM_FAKE_LAUNCH_LOG"; fi; p=$a; done ;;
esac
exit 0
SH
chmod +x "$FAKE/tmux"
ln -sf "$(command -v node)" "$FAKE/node"
LAUNCH="$LAB/launch.log"; : > "$LAUNCH"

echo "== fm-spawn.sh sm $SM --secondmate (FM_HOME=$LAB, secondmate-harness=claude)"
env -u NO_MISTAKES_GATE -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE \
  -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE \
  PATH="$FAKE:/usr/bin:/bin:/usr/sbin:/sbin" TMUX='' CLAUDECODE=1 FM_BACKEND=tmux \
  FM_HOME="$LAB" HOME="$LAB/user-home" CLAUDE_CONFIG_DIR='' FM_SPAWN_NO_GUARD=1 \
  FM_FAKE_LAUNCH_LOG="$LAUNCH" "$ROOT/bin/fm-spawn.sh" sm "$SM" --secondmate > "$LAB/spawn.out" 2> "$LAB/spawn.err"
echo "spawn exit=$?"
cat "$LAB/spawn.err" | tail -15
SETTINGS="$(cd "$LAB/state" && pwd -P)/sm.claude-settings.json"
echo "== generated $SETTINGS (keys and claudeMdExcludes):"
jq -c 'keys' "$SETTINGS"; jq '.claudeMdExcludes' "$SETTINGS"
echo "== physical secondmate projects dir: $(cd "$SM/projects" && pwd -P)"
echo "== launch command passes that file with --settings:"
grep -o -- "--settings '[^']*'" "$LAUNCH" | head -1
LOCAL_AFTER=$(shasum "$SM/.claude/settings.local.json" | cut -d' ' -f1)
echo "== secondmate home .claude/settings.local.json unchanged: $([ "$LOCAL_BEFORE" = "$LOCAL_AFTER" ] && echo yes || echo NO) ($(cat "$SM/.claude/settings.local.json"))"
[ "$VARIANT" = pattern ] && exit 0
[ -f "$SETTINGS" ] || exit 1

READ="$(cd "$CLONE/src" && pwd -P)/file.txt"
arm() {  # <label> [claude args]
  local label=$1 port cap=$LAB/$1.jsonl pf=$LAB/$1.port; shift
  python3 "$ROOT/tests/fixtures/fm-claude-read-replay.py" "$pf" "$cap" "$READ" & SERVER_PID=$!
  for _ in $(seq 1 50); do [ -s "$pf" ] && break; sleep 0.1; done
  port=$(cat "$pf")
  (cd "$SM" && env -i PATH="$PATH" HOME="$LAB/user-home" TERM=dumb CLAUDE_CONFIG_DIR="$LAB/cc-$label" \
    ANTHROPIC_API_KEY=sk-ant-synthetic-capture-only ANTHROPIC_BASE_URL="http://127.0.0.1:$port" \
    DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude -p "read the file" --max-turns 3 --allowedTools Read "$@" </dev/null >/dev/null 2>&1)
  kill "$SERVER_PID" 2>/dev/null; SERVER_PID=
  python3 -I - "$cap" <<'PY'
import json, sys
seen = {k: False for k in ("home", "clone", "import", "rule")}
marks = {"home": "fm-home-own-instructions-marker", "clone": "fm-clone-instructions-marker",
         "import": "fm-clone-import-marker", "rule": "fm-clone-rule-marker"}
reqs = 0; read_result = False
for line in open(sys.argv[1]):
    reqs += 1
    seen["home"] = seen["home"] or marks["home"] in line
    try: msgs = json.loads(line).get("messages", [])
    except ValueError: continue
    if '"tool_result"' in json.dumps(msgs):
        read_result = True
        for k in ("clone", "import", "rule"):
            seen[k] = seen[k] or marks[k] in line
print(f"requests={reqs} read_result_sent={read_result} home_CLAUDE.md={seen['home']} "
      f"clone_CLAUDE.md={seen['clone']} clone_@import={seen['import']} clone_rule={seen['rule']}")
PY
}
echo "== real claude $(claude --version | head -1) in the secondmate home, Read of $READ"
echo -n "baseline (no --settings):            "; arm baseline
echo -n "with fm-spawn's generated --settings: "; arm spawned --settings "$SETTINGS"
