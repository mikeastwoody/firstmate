#!/usr/bin/env bash
# Live driver: a primary home that sits under a directory named projects, with the
# docs/configuration.md "Claude and cloned projects' instructions" snippet in its untracked
# .claude/settings.local.json (physical pwd -P path), run with the real installed claude from
# the home (no --settings, as an operator-launched primary) against the repo's scripted
# replay server. Arms: no local settings, the documented snippet, and the bare
# **/projects/** shortcut the docs warn against.
set -u
ROOT=$1
WORLD=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")" && pwd -P)
trap 'kill ${SERVER_PID:-} 2>/dev/null; rm -rf "$WORLD"' EXIT
H=$WORLD/projects/home; C=$H/projects/app
mkdir -p "$H/.claude" "$C/src" "$C/.claude/rules" "$C/docs" "$WORLD/user-home"
printf 'fm-home-own-instructions-marker\n' > "$H/CLAUDE.md"
printf 'fm-clone-instructions-marker\n@docs/imported.md\n' > "$C/CLAUDE.md"
printf 'fm-clone-import-marker\n' > "$C/docs/imported.md"
printf 'fm-clone-rule-marker\n' > "$C/.claude/rules/always.md"
printf 'clone file\n' > "$C/src/file.txt"
git -C "$H" init -q; git -C "$C" init -q
P=$(cd "$H/projects" && pwd -P)
READ="$P/app/src/file.txt"
arm() {  # <label> <settings.local.json content or empty>
  local label=$1 cap=$WORLD/$1.jsonl pf=$WORLD/$1.port
  if [ -n "$2" ]; then printf '%s\n' "$2" > "$H/.claude/settings.local.json"; else rm -f "$H/.claude/settings.local.json"; fi
  python3 "$ROOT/tests/fixtures/fm-claude-read-replay.py" "$pf" "$cap" "$READ" & SERVER_PID=$!
  for _ in $(seq 1 50); do [ -s "$pf" ] && break; sleep 0.1; done
  (cd "$H" && env -i PATH="$PATH" HOME="$WORLD/user-home" TERM=dumb CLAUDE_CONFIG_DIR="$WORLD/cc-$label" \
    ANTHROPIC_API_KEY=sk-ant-synthetic-capture-only ANTHROPIC_BASE_URL="http://127.0.0.1:$(cat "$pf")" \
    DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude -p "read the file" --max-turns 3 --allowedTools Read </dev/null >/dev/null 2>&1)
  kill "$SERVER_PID" 2>/dev/null; SERVER_PID=
  python3 -I - "$cap" <<'PY'
import json, sys
m = {"home": "fm-home-own-instructions-marker", "clone": "fm-clone-instructions-marker",
     "import": "fm-clone-import-marker", "rule": "fm-clone-rule-marker"}
seen = dict.fromkeys(m, False); rr = False; n = 0
for line in open(sys.argv[1]):
    n += 1; seen["home"] |= m["home"] in line
    try: msgs = json.loads(line).get("messages", [])
    except ValueError: continue
    if '"tool_result"' in json.dumps(msgs):
        rr = True
        for k in ("clone", "import", "rule"): seen[k] |= m[k] in line
print(f"requests={n} read_result_sent={rr} home_CLAUDE.md={seen['home']} clone_CLAUDE.md={seen['clone']} clone_@import={seen['import']} clone_rule={seen['rule']}")
PY
}
SNIPPET=$(jq -n --arg p "$P" '{claudeMdExcludes: [$p+"/**/CLAUDE*.md", $p+"/**/AGENTS.md", $p+"/**/.claude/rules/**"]}')
echo "== real claude $(claude --version | head -1), primary home $H (under a dir named projects)"
echo "== documented snippet written to .claude/settings.local.json:"; printf '%s\n' "$SNIPPET"
echo -n "no settings.local.json:            "; arm none ""
echo -n "documented snippet:                "; arm snippet "$SNIPPET"
echo -n "bare **/projects/** (docs warn):   "; arm bare '{"claudeMdExcludes":["**/projects/**"]}'
