#!/usr/bin/env bash
# Live driver for the Keychain fallback of bin/fm-dispatch-resolve.sh and
# bin/fm-bootstrap.sh. Uses the REAL /usr/bin/security (read-only, the
# operator's login Keychain item `typesafe-api-key`), the REAL curl against
# api.typesafe.ai, and the REAL quota-axi. PATH spies log argv only and then
# exec the real binaries. A throwaway FM_HOME holds all firstmate state.
# "No Keychain item" is produced WITHOUT touching the Keychain: HOME points at
# an empty dir, so security's search list holds only the System keychain.
# The key itself is never printed: leak checks print only yes/no.
set -u
WT=${1:?worktree}
T=$(mktemp -d /tmp/fm-kc-live.XXXXXX)
SPY="$T/spy"; mkdir -p "$SPY" "$T/home/config" "$T/empty-home" "$T/nosec-bin"
cat > "$SPY/security" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FM_LIVE_LOG/security.argv"
exec /usr/bin/security "$@"
EOS
cat > "$SPY/curl" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FM_LIVE_LOG/curl.argv"
exec /usr/bin/curl "$@"
EOS
chmod +x "$SPY/security" "$SPY/curl"
# A PATH with every tool the resolver needs except security (a non-macOS host).
for c in bash dirname jq mktemp cp chmod rm cat head tr awk grep tail date perl; do
  p=$(command -v "$c") && ln -s "$p" "$T/nosec-bin/$c"
done
ln -s "$SPY/curl" "$T/nosec-bin/curl"

cat > "$T/home/config/crew-dispatch.json" <<'JSON'
{"rules":[
  {"when":"The task only edits documentation text such as a README typo or a doc comment.","use":{"harness":"claude","model":"claude-sonnet-5","effort":"low"}},
  {"when":"The task is a large architectural redesign spanning many modules.","use":{"harness":"claude","model":"claude-opus-5-5","effort":"high"}}
],
 "default":{"harness":"claude"}}
JSON
cat > "$T/brief.md" <<'MD'
# Task
Fix one spelling typo in README.md: change "recieve" to "receive". Documentation only; no code changes.
MD

KEY=$(/usr/bin/security find-generic-password -s typesafe-api-key -w 2>/dev/null) || KEY=''
show() { if [ "$(leak "$1")" = yes ]; then echo "[suppressed: contains the Keychain key]"; else cat "$1"; fi; }
leak() { local f; for f in "$@"; do [ -f "$f" ] && [ -n "$KEY" ] && grep -qF -- "$KEY" "$f" && { echo yes; return; }; done; echo no; }

run_resolver() { # name, then env assignments via env(1)
  local name=$1; shift
  local L="$T/$name"; mkdir -p "$L"
  echo "=================== $name"
  env -u TYPESAFE_API_KEY FM_LIVE_LOG="$L" FM_HOME="$T/home" "$@" \
    "$WT/bin/fm-dispatch-resolve.sh" "$T/brief.md" --project demo-readme >"$L/stdout" 2>"$L/stderr"
  echo "exit=$?"
  echo "--- stdout"; show "$L/stdout"
  echo "--- stderr"; show "$L/stderr"
  echo "--- security argv (spy)"; cat "$L/security.argv" 2>/dev/null || echo "(security never invoked)"
  echo "--- curl invoked?"; [ -f "$L/curl.argv" ] && echo "yes: $(wc -l < "$L/curl.argv" | tr -d ' ') call(s) to $(grep -oE 'https://[^ ]+' "$L/curl.argv" | head -1)" || echo "no (no network call)"
  echo "--- Keychain key present in stdout/stderr/argv logs? $(leak "$L/stdout" "$L/stderr" "$L/curl.argv" "$L/security.argv")"
}

echo "Keychain item readable by real security: $([ -n "$KEY" ] && echo yes || echo no) (length ${#KEY})"
[ -e "$T/home/.env" ] && echo ".env present" || echo "throwaway FM_HOME has no .env"

# S1: Keychain is the only source -> resolver ON, real API answer.
run_resolver S1-keychain-only PATH="$SPY:$PATH"
# S2: an environment key wins over the Keychain (bogus key -> real API 401).
run_resolver S2-env-wins PATH="$SPY:$PATH" TYPESAFE_API_KEY=fm-live-bogus-env-key
# S3: a .env key wins over the Keychain (bogus key -> real API 401).
printf '%s\n' 'TYPESAFE_API_KEY=fm-live-bogus-dotenv-key' > "$T/home/.env"
run_resolver S3-dotenv-wins PATH="$SPY:$PATH"
rm -f "$T/home/.env"
# S4: no Keychain item for this user -> off, no network call.
run_resolver S4-no-keychain-item PATH="$SPY:$PATH" HOME="$T/empty-home"
# S5: no security command at all (non-macOS host) -> off, no network call.
run_resolver S5-no-security-command PATH="$T/nosec-bin"

# S6: bootstrap applies typed validation from a Keychain-only key.
boot() { # name, crew-dispatch json, extra env
  local name=$1 json=$2; shift 2
  local H="$T/boot-$name"; mkdir -p "$H/config" "$T/$name"
  printf '%s\n' manual > "$H/config/backlog-backend"
  printf '%s\n' "$json" > "$H/config/crew-dispatch.json"
  echo "=================== bootstrap $name"
  echo "crew-dispatch.json: $json"
  env -u TYPESAFE_API_KEY FM_LIVE_LOG="$T/$name" FM_HOME="$H" FM_ROOT_OVERRIDE="$H" \
    FM_BOOTSTRAP_DETECT_ONLY=1 FM_BOOTSTRAP_NETWORK=skip PATH="$SPY:$PATH" "$@" \
    "$WT/bin/fm-bootstrap.sh" >"$T/$name/out" 2>"$T/$name/err"
  echo "exit=$?"
  echo "--- CREW_DISPATCH lines:"; grep '^CREW_DISPATCH' "$T/$name/out" || echo "(none)"
  echo "--- security argv (spy)"; cat "$T/$name/security.argv" 2>/dev/null || echo "(security never invoked)"
  echo "--- Keychain key present in bootstrap output? $(leak "$T/$name/out" "$T/$name/err")"
}
APPROVAL='{"rules":[{"when":"hard design","approval":"firstmate","use":{"harness":"claude"}}]}'
GEMINI='{"rules":[{"when":"gemini work","use":{"harness":"gemini","model":"gemini-3.8-flash-high","provider":"google"}}]}'
boot S6a-keychain-approval "$APPROVAL"
boot S6b-no-item-approval "$APPROVAL" HOME="$T/empty-home"
boot S6c-keychain-gemini "$GEMINI"
boot S6d-no-item-gemini "$GEMINI" HOME="$T/empty-home"
unset KEY
echo "scratch dir: $T"
