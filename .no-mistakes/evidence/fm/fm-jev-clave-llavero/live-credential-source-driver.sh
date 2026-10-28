#!/usr/bin/env bash
# Live validation driver for the declared credential source (issue 7879).
#
# Runs the REAL bin/fm-dispatch-resolve.sh and bin/fm-bootstrap.sh from the run
# worktree against a disposable lab home minted with bin/fm-lab-home.sh.
# Stand-ins are used only where the real thing would leak or spend:
#   - curl         : the typesafe/OpenRouter endpoint stand-in (no network), it
#                    records argv, body, the fd-3 header and its environment.
#   - quota-axi    : fixture snapshot (never reads the operator's real quota).
#   - security     : EITHER a logging spy that execs the REAL /usr/bin/security
#                    (real-Keychain scenarios, random never-existing service so
#                    no real item is read), OR a Keychain stand-in that serves a
#                    canary key for one disposable service (happy path), since
#                    adding an item to the real Keychain would edit a credential
#                    store.
# Usage: live-credential-source-driver.sh <worktree>
set -u
WT=${1:?worktree}
TOOL="$WT/bin/fm-dispatch-resolve.sh"
BOOT="$WT/bin/fm-bootstrap.sh"
REAL_SECURITY=/usr/bin/security
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")
LAB2=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")
WORK=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab-work.XXXXXX")
trap 'rm -rf "$LAB" "$LAB2" "$WORK"' EXIT
"$WT/bin/fm-lab-home.sh" create "$LAB" >/dev/null
"$WT/bin/fm-lab-home.sh" create "$LAB2" >/dev/null
mkdir -p "$WORK/shim" "$WORK/spy" "$WORK/standin" "$WORK/nosec" "$WORK/hang" "$WORK/refuse" "$WORK/log" "$LAB/tmp"
PASS=0 FAIL=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }
hdr()  { printf '\n=== %s ===\n' "$1"; }
show() { printf '  $ %s\n' "$1"; }

CANARY="fm-lab-canary-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 20)"
ENV_CANARY="fm-lab-envkey-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 12)"
DOTENV_CANARY="fm-lab-dotenvkey-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 12)"
OR_CANARY="fm-lab-orkey-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 12)"
ABSENT_SVC="fm-lab-absent-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 16)"
STANDIN_SVC="fm-lab-typesafe-standin"
printf '%s' "$CANARY" > "$WORK/canary"

# ---- shims ------------------------------------------------------------------
cat > "$WORK/shim/curl" <<'SH'
#!/usr/bin/env bash
# endpoint stand-in: never touches the network
set -u
L=${LIVE_LOG:?}
printf 'called\n' >> "$L/curl.calls"
env > "$L/curl.env"
canary=$(cat "$LIVE_CANARY_FILE")
for d in $LIVE_SCAN_DIRS; do grep -rqF -- "$canary" "$d" 2>/dev/null && printf 'canary-in-file:%s\n' "$d" >> "$L/curl.leak"; done
out=''
: > "$L/curl.argv"
while [ $# -gt 0 ]; do case "$1" in -o) out=$2; shift 2;; *) printf '%s\n' "$1" >> "$L/curl.argv"; shift;; esac; done
cat > "$L/curl.body"
cat /dev/fd/3 > "$L/curl.header" 2>/dev/null || printf 'fd3 unreadable\n' > "$L/curl.header"
cp "$LIVE_RESPONSE" "$out"
printf 200
SH
cat > "$WORK/shim/quota-axi" <<'SH'
#!/usr/bin/env bash
printf 'called\n' >> "${LIVE_LOG:?}/quota.calls"
env > "$LIVE_LOG/quota.env"
cat "${LIVE_QUOTA:?}"
SH
# spy: logs argv + env cleanliness, then runs the REAL security binary
cat > "$WORK/spy/security" <<SH
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "\${LIVE_LOG:?}/security.argv"
env > "\$LIVE_LOG/security.env"
exec $REAL_SECURITY "\$@"
SH
# Keychain stand-in for the happy path: serves the canary for one service only
cat > "$WORK/standin/security" <<SH
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "\${LIVE_LOG:?}/security.argv"
env > "\$LIVE_LOG/security.env"
[ "\$1" = find-generic-password ] || exit 2
shift; svc='' acct='' w=0
while [ \$# -gt 0 ]; do case "\$1" in -s) svc=\$2; shift 2;; -a) acct=\$2; shift 2;; -w) w=1; shift;; *) exit 2;; esac; done
[ "\$svc" = "$STANDIN_SVC" ] && [ \$w = 1 ] || { echo "security: SecKeychainSearchCopyNext: The specified item could not be found in the keychain." >&2; exit 44; }
cat "$WORK/canary"; echo
SH
# a Keychain that never answers (unanswered access dialog)
cat > "$WORK/hang/security" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${LIVE_LOG:?}/security.argv"
printf '%s\n' "$$" > "$LIVE_LOG/hang.pid"
exec sleep 60
SH
# a Keychain that refuses after printing decoys
cat > "$WORK/refuse/security" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${LIVE_LOG:?}/security.argv"
printf 'DECOY-STDOUT-%s\n' refuse
printf 'DECOY-STDERR-%s\n' refuse >&2
exit 51
SH
chmod +x "$WORK"/shim/* "$WORK"/spy/* "$WORK"/standin/* "$WORK"/hang/* "$WORK"/refuse/*
# PATH dir with every system tool EXCEPT security (host lacks the adapter tool)
for d in "$(dirname "$(command -v bash)")" /bin /usr/bin /usr/sbin /sbin; do
  for f in "$d"/*; do b=${f##*/}; [ "$b" = security ] && continue; [ -e "$WORK/nosec/$b" ] || ln -s "$f" "$WORK/nosec/$b"; done
done
SYS_PATH="$(dirname "$(command -v bash)"):$(dirname "$(command -v jq)"):/usr/bin:/bin:/usr/sbin:/sbin"

# ---- fixtures ---------------------------------------------------------------
BRIEF="$WORK/brief.md"
cat > "$BRIEF" <<'MD'
# Task
## Captain's intent
Fix the off-by-one in the pager.
## Firstmate spec
Root cause is the `<=` on line 40 of pager.sh; expected behavior is one page per call.
MD
RULES_JSON='{"rules":[{"when":"A simple bug fix with a stated root cause.","use":{"harness":"claude","model":"sonnet","effort":"high"}}],"default":{"harness":"claude","model":"opus"}}'
printf '%s\n' "$RULES_JSON" > "$LAB/config/crew-dispatch.json"
printf '%s\n' "$RULES_JSON" > "$LAB2/config/crew-dispatch.json"
printf '%s\n' manual > "$LAB/config/backlog-backend"
cat > "$WORK/response.json" <<'JSON'
{ "model": "jev-1.13.0",
  "answers": { "rule": { "type": "choice", "choice": "rule_1", "confidence": 0.93,
    "probabilities": { "rule_1": 0.93, "default": 0.07 } } },
  "usage": { "input_tokens": 400, "output_tokens": 20 } }
JSON
cat > "$WORK/quota.json" <<'JSON'
{ "generatedAt": "2030-01-01T00:00:00Z", "schemaVersion": 5,
  "providers": [ { "provider": "claude", "state": { "status": "fresh" }, "quotaSemantics": { "status": "known", "effectiveAvailability": [
      { "scope": "all_models", "status": "known", "effectivePercentRemaining": 79, "runway": { "status": "through_reset" }, "selection": { "spendPriority": 0.5 } } ] } } ] }
JSON
CRED="$LAB/config/dispatch-credential-sources.json"

# run_resolver <label> <security-dir|-> [env assignments...] -- runs the real resolver
run_resolver() {
  local label=$1 secdir=$2; shift 2
  rm -rf "$WORK/log"; mkdir -p "$WORK/log"
  local path="$WORK/shim:$SYS_PATH"
  case "$secdir" in
    -) ;;
    nosec) path="$WORK/shim:$WORK/nosec" ;;
    *) path="$WORK/shim:$WORK/$secdir:$SYS_PATH" ;;
  esac
  local t0 t1
  t0=$(date +%s)
  env -i HOME="$HOME" USER="${USER:-}" TMPDIR="$LAB/tmp/" PATH="$path" FM_HOME="$LAB" \
    LIVE_LOG="$WORK/log" LIVE_CANARY_FILE="$WORK/canary" LIVE_SCAN_DIRS="$LAB" \
    LIVE_RESPONSE="$WORK/response.json" LIVE_QUOTA="$WORK/quota.json" "$@" \
    bash "$TOOL" "$BRIEF" --project pager > "$WORK/out" 2> "$WORK/err"
  RC=$?
  t1=$(date +%s); ELAPSED=$((t1 - t0))
  OUT=$(cat "$WORK/out"); ERR=$(cat "$WORK/err")
  printf '  -> exit=%s elapsed=%ss\n' "$RC" "$ELAPSED"
  [ -z "$OUT" ] || printf '%s\n' "$OUT" | sed 's/^/     stdout| /'
  [ -z "$ERR" ] || printf '%s\n' "$ERR" | sed 's/^/     stderr| /'
  [ -f "$WORK/log/security.argv" ] && sed 's/^/     security argv| /' "$WORK/log/security.argv"
  [ -f "$WORK/log/curl.header" ] && sed -E 's/(Bearer ).*/\1<redacted:len='"$(sed -n 's/.*Bearer //p' "$WORK/log/curl.header" | tr -d '\n' | wc -c | tr -d ' ')"'>/' "$WORK/log/curl.header" | sed 's/^/     curl fd3 header| /'
  return 0
}
curl_called()  { [ -s "$WORK/log/curl.calls" ]; }
quota_called() { [ -s "$WORK/log/quota.calls" ]; }
sec_called()   { [ -s "$WORK/log/security.argv" ]; }
header_is()    { [ "$(cat "$WORK/log/curl.header")" = "Authorization: Bearer $1" ]; }
nowhere_but_header() {  # <secret>
  ! grep -qF -- "$1" "$WORK/log/curl.argv" && ! grep -qF -- "$1" "$WORK/log/curl.body" &&
  ! grep -qF -- "$1" "$WORK/log/curl.env" && ! grep -qF -- "$1" "$WORK/log/quota.env" &&
  ! printf '%s%s' "$OUT" "$ERR" | grep -qF -- "$1" && [ ! -s "$WORK/log/curl.leak" ] &&
  ! grep -rqF -- "$1" "$LAB" 2>/dev/null
}

echo "Live validation: declared credential source (issue 7879)"
echo "worktree commit: $(git -C "$WT" rev-parse --short HEAD)   host: $(uname -s) $(sw_vers -productVersion 2>/dev/null)"
echo "lab home: $LAB (fm-lab-home.sh create)   real security: $REAL_SECURITY"

# =============================================================================
hdr "S1 capability probe (real host, no declaration read, no credential tool run)"
printf '%s\n' '{"typesafe":{"source":"macos-keychain","service":"x","key":"PROBE-MUST-NOT-READ"}}' > "$CRED"
for src in macos-keychain hashicorp-vault ''; do
  rm -rf "$WORK/log"; mkdir -p "$WORK/log"
  show "FM_HOME=\$LAB bin/fm-dispatch-resolve.sh --supports-credential-source '$src'   (security spy on PATH)"
  o=$(env -i HOME="$HOME" PATH="$WORK/spy:$SYS_PATH" FM_HOME="$LAB" LIVE_LOG="$WORK/log" bash "$TOOL" --supports-credential-source "$src" 2>&1); rc=$?
  printf '  -> exit=%s output=%s\n' "$rc" "$o"
  case "$src" in
    macos-keychain) check "macos-keychain on this Mac -> supported, exit 0" '[ "$o" = supported ] && [ $rc = 0 ]' ;;
    *) check "'$src' -> unsupported, exit 1" '[ "$o" = unsupported ] && [ $rc = 1 ]' ;;
  esac
  check "probe ran no security and ignored the (invalid) declaration" '! sec_called'
done
show "PATH without security: bin/fm-dispatch-resolve.sh --supports-credential-source macos-keychain"
o=$(env -i HOME="$HOME" PATH="$WORK/nosec" FM_HOME="$LAB" bash "$TOOL" --supports-credential-source macos-keychain 2>&1); rc=$?
printf '  -> exit=%s output=%s\n' "$rc" "$o"
check "missing tool -> unsupported, exit 1" '[ "$o" = unsupported ] && [ $rc = 1 ]'
rm -f "$CRED"

# =============================================================================
hdr "S2 unconfigured home stays off exactly as today (no key, no declaration)"
show "FM_HOME=\$LAB bin/fm-dispatch-resolve.sh brief.md --project pager"
run_resolver off spy
check "exit 0, nothing on stdout" '[ $RC = 0 ] && [ -z "$OUT" ]'
check "stderr is the unchanged off line" '[ "$ERR" = "dispatch-resolve: off (TYPESAFE_API_KEY absent from the environment and $LAB/.env)" ]'
check "no network (curl) call, no quota call, no security call" '! curl_called && ! quota_called && ! sec_called'

# =============================================================================
hdr "S3 declared macos-keychain source, REAL Keychain, item absent -> sanitized error, nothing sent"
printf '{"typesafe":{"source":"macos-keychain","service":"%s"}}\n' "$ABSENT_SVC" > "$CRED"
show "config/dispatch-credential-sources.json = $(cat "$CRED")"
run_resolver real-absent spy
check "exit 0 with status: error" '[ $RC = 0 ] && printf "%s" "$OUT" | grep -qx "  status: error"'
check "reason: credential source macos-keychain declared for typesafe is unavailable; nothing sent" 'printf "%s" "$OUT" | grep -qx "  reason: credential source macos-keychain declared for typesafe is unavailable; nothing sent"'
check "not mistaken for off (no 'dispatch-resolve: off' line)" '! printf "%s" "$ERR" | grep -q "dispatch-resolve: off"'
check "real security was asked exactly: find-generic-password -s <service> -w" '[ "$(cat "$WORK/log/security.argv")" = "find-generic-password -s $ABSENT_SVC -w" ]'
check "security's child env carries no key variable" '! grep -qE "^(TYPESAFE|OPENROUTER)_API_KEY" "$WORK/log/security.env"'
check "security's own stderr (could-not-be-found text) is not relayed" '! printf "%s" "$ERR$OUT" | grep -qi "could not be found"'
check "no network (curl) call and no quota call" '! curl_called && ! quota_called'
printf '{"typesafe":{"source":"macos-keychain","service":"%s","account":"fm-lab-acct"}}\n' "$ABSENT_SVC" > "$CRED"
show "with account: $(cat "$CRED")"
run_resolver real-absent-acct spy
check "account becomes -a in the real lookup; same sanitized error; no call" '[ "$(cat "$WORK/log/security.argv")" = "find-generic-password -s $ABSENT_SVC -a fm-lab-acct -w" ] && printf "%s" "$OUT" | grep -q "is unavailable; nothing sent" && ! curl_called'

# =============================================================================
hdr "S4 declared source supplies the key -> typed request, key only in fd-3 header"
printf '{"typesafe":{"source":"macos-keychain","service":"%s","account":"me"}}\n' "$STANDIN_SVC" > "$CRED"
show "config/dispatch-credential-sources.json = $(cat "$CRED")   (Keychain stand-in serves a canary for this service)"
run_resolver happy standin
check "exit 0, status: clear with the rule's profile line" '[ $RC = 0 ] && printf "%s" "$OUT" | grep -qx "  status: clear" && printf "%s" "$OUT" | grep -qx "  profile: --harness .claude. --model .sonnet. --effort .high."'
check "Keychain was asked for exactly the declared service and account" '[ "$(cat "$WORK/log/security.argv")" = "find-generic-password -s $STANDIN_SVC -a me -w" ]'
check "endpoint got Authorization: Bearer <declared key> on fd 3" 'header_is "$CANARY"'
check "request went to the fixed typesafe endpoint" 'grep -qx "https://api.typesafe.ai/v1/systemone" "$WORK/log/curl.argv"'
check "declared key absent from curl argv, body, curl/quota env, stdout/stderr, and every file in the home while in flight" 'nowhere_but_header "$CANARY"'
check "no key variable reached the curl, quota-axi or security child env" '! grep -qE "^(TYPESAFE|OPENROUTER)_API_KEY" "$WORK/log/curl.env" "$WORK/log/quota.env" "$WORK/log/security.env"'

# =============================================================================
hdr "S5 precedence: environment, then .env, then the declared source"
show "TYPESAFE_API_KEY=<env key> with the same declaration"
run_resolver env-wins standin TYPESAFE_API_KEY="$ENV_CANARY"
check "env key is sent; declared source never consulted" 'header_is "$ENV_CANARY" && ! sec_called'
check "env key appears nowhere but the header" 'nowhere_but_header "$ENV_CANARY"'
printf 'TYPESAFE_API_KEY=%s\n' "$DOTENV_CANARY" > "$LAB/.env"
show "\$LAB/.env has TYPESAFE_API_KEY, no env key"
run_resolver dotenv-wins standin
check ".env key is sent; declared source never consulted" 'header_is "$DOTENV_CANARY" && ! sec_called'
show ".env key AND env key"
run_resolver env-over-dotenv standin TYPESAFE_API_KEY="$ENV_CANARY"
check "environment beats .env" 'header_is "$ENV_CANARY" && ! sec_called'
rm -f "$LAB/.env"
printf '%s\n' '{"typesafe":{"source":"macos-keychain","service":"x","key":"inline-secret"}}' > "$CRED"
show "invalid declaration but env key present"
run_resolver invalid-but-env standin TYPESAFE_API_KEY="$ENV_CANARY"
check "invalid declaration is not even read when a key is already present (clear, exit 0)" '[ $RC = 0 ] && header_is "$ENV_CANARY" && ! sec_called'

# =============================================================================
hdr "S6 invalid declaration -> actionable exit 2, value never printed, nothing sent"
for decl in \
  '{"typesafe":{"source":"macos-keychain","service":"typesafe-api-key","key":"sk-LIVE-SECRET-VALUE"}}' \
  '{"typesafe":{"source":"hashicorp-vault","service":"x"}}' \
  '{"typesafe":{"source":"macos-keychain"}}' \
  '{"anthropic":{"source":"macos-keychain","service":"x"}}' \
  '{"typesafe":{"source":"macos-keychain","service":"sk-LIVE-SECRET-VALUE\u0007"}}' \
  'not json sk-LIVE-SECRET-VALUE' \
  '{"openrouter":{"source":"macos-keychain","service":"x","password":"sk-LIVE-SECRET-VALUE"},"typesafe":{"source":"macos-keychain","service":"ok"}}'; do
  printf '%s\n' "$decl" > "$CRED"
  show "declaration: $decl"
  run_resolver invalid spy
  check "exit 2, one actionable 'malformed credential source declaration' line" '[ $RC = 2 ] && [ "$(printf "%s\n" "$ERR" | wc -l | tr -d " ")" = 1 ] && printf "%s" "$ERR" | grep -q "^error: malformed credential source declaration: "'
  check "declared value never printed; no curl/quota/security call" '! printf "%s%s" "$OUT" "$ERR" | grep -q "sk-LIVE-SECRET-VALUE" && ! curl_called && ! quota_called && ! sec_called'
done
chmod 000 "$CRED" 2>/dev/null
printf '%s\n' '{}' > /dev/null
show "unreadable declaration file (mode 000)"
run_resolver unreadable spy
check "exit 2: credential source declaration not readable" '[ $RC = 2 ] && printf "%s" "$ERR" | grep -q "credential source declaration not readable"'
chmod 600 "$CRED"; rm -f "$CRED"

# =============================================================================
hdr "S7 provider isolation"
printf '{"typesafe":{"source":"macos-keychain","service":"%s"}}\n' "$STANDIN_SVC" > "$CRED"
show "FM_DISPATCH_PROVIDER=openrouter FM_DISPATCH_MODEL=openai/gpt-5 with only a typesafe entry"
run_resolver or-no-entry standin FM_DISPATCH_PROVIDER=openrouter FM_DISPATCH_MODEL=openai/gpt-5
check "openrouter stays off; typesafe entry not used; nothing sent" '[ $RC = 0 ] && [ -z "$OUT" ] && printf "%s" "$ERR" | grep -q "^dispatch-resolve: off (OPENROUTER_API_KEY absent" && ! sec_called && ! curl_called'
printf '{"openrouter":{"source":"macos-keychain","service":"%s"}}\n' "$STANDIN_SVC" > "$CRED"
show "only an openrouter entry, no provider setting (default typesafe)"
run_resolver ts-no-entry standin
check "declaration never selects a provider: typesafe stays off" '[ $RC = 0 ] && [ -z "$OUT" ] && printf "%s" "$ERR" | grep -q "^dispatch-resolve: off (TYPESAFE_API_KEY absent" && ! sec_called && ! curl_called'
printf '%s' "$OR_CANARY" > "$WORK/canary"
show "FM_DISPATCH_PROVIDER=openrouter with an openrouter entry"
run_resolver or-entry standin FM_DISPATCH_PROVIDER=openrouter FM_DISPATCH_MODEL=openai/gpt-5
check "openrouter key from its own entry goes to the OpenRouter endpoint on fd 3 only" 'header_is "$OR_CANARY" && grep -qx "https://openrouter.ai/api/alpha/decisions" "$WORK/log/curl.argv" && nowhere_but_header "$OR_CANARY"'
printf '%s' "$CANARY" > "$WORK/canary"
rm -f "$CRED"

# =============================================================================
hdr "S8 effective-home isolation"
printf '{"typesafe":{"source":"macos-keychain","service":"%s"}}\n' "$STANDIN_SVC" > "$LAB2/config/dispatch-credential-sources.json"
show "another home (\$LAB2) declares a source; resolver runs with FM_HOME=\$LAB"
run_resolver other-home standin
check "other home's declaration is ignored: off, no security, no curl" '[ $RC = 0 ] && printf "%s" "$ERR" | grep -q "^dispatch-resolve: off" && ! sec_called && ! curl_called'
printf '{"typesafe":{"source":"macos-keychain","service":"%s"}}\n' "$STANDIN_SVC" > "$CRED"
mkdir -p "$WORK/override-config"; printf '%s\n' "$RULES_JSON" > "$WORK/override-config/crew-dispatch.json"
show "\$LAB/config declares a source but FM_CONFIG_OVERRIDE selects a directory without one"
run_resolver override standin FM_CONFIG_OVERRIDE="$WORK/override-config"
check "only the effective config dir counts: off, no security, no curl" '[ $RC = 0 ] && printf "%s" "$ERR" | grep -q "^dispatch-resolve: off" && ! sec_called && ! curl_called'
show "FM_CONFIG_OVERRIDE points at \$LAB2/config (which declares the source)"
run_resolver override-declared standin FM_CONFIG_OVERRIDE="$LAB2/config"
check "the override's declaration is used" '[ $RC = 0 ] && header_is "$CANARY"'
rm -f "$LAB2/config/dispatch-credential-sources.json"

# =============================================================================
hdr "S9 unavailable-source distinctions (each: error outcome, exit 0, nothing sent)"
printf '{"typesafe":{"source":"macos-keychain","service":"%s"}}\n' "$STANDIN_SVC" > "$CRED"
show "host lacks the security tool (PATH without it)"
run_resolver nosec nosec
check "reason says not supported on this host; nothing sent" 'printf "%s" "$OUT" | grep -qx "  reason: credential source macos-keychain declared for typesafe is not supported on this host; nothing sent" && [ $RC = 0 ] && ! curl_called && ! quota_called'
show "Keychain refuses (exit 51) after printing decoys on stdout and stderr"
run_resolver refuse refuse
check "reason says unavailable; decoys not relayed; nothing sent" 'printf "%s" "$OUT" | grep -qx "  reason: credential source macos-keychain declared for typesafe is unavailable; nothing sent" && ! printf "%s%s" "$OUT" "$ERR" | grep -q DECOY && ! curl_called'
show "Keychain never answers (unanswered access dialog)"
run_resolver hang hang
check "reason says did not answer in time; nothing sent" 'printf "%s" "$OUT" | grep -qx "  reason: credential source macos-keychain declared for typesafe did not answer in time; nothing sent" && [ $RC = 0 ] && ! curl_called'
check "bounded at ~5 s (elapsed ${ELAPSED}s)" '[ "$ELAPSED" -ge 4 ] && [ "$ELAPSED" -le 9 ]'
sleep 1
HPID=$(cat "$WORK/log/hang.pid" 2>/dev/null)
check "the hung security process was stopped (pid $HPID gone)" '[ -n "$HPID" ] && ! kill -0 "$HPID" 2>/dev/null'
rm -f "$CRED"

# =============================================================================
hdr "S10 bootstrap parity (real bin/fm-bootstrap.sh, detect-only, no network) - never runs security"
boot() {
  rm -rf "$WORK/log"; mkdir -p "$WORK/log"
  env -i HOME="$HOME" USER="${USER:-}" TMPDIR="$LAB/tmp/" PATH="$WORK/spy:$WORK/shim:$SYS_PATH:$(dirname "$(command -v quota-axi)"):$(dirname "$(command -v tmux 2>/dev/null || echo /usr/bin/true)")" \
    FM_HOME="$LAB" LIVE_LOG="$WORK/log" FM_BOOTSTRAP_DETECT_ONLY=1 FM_BOOTSTRAP_NETWORK=skip "$@" \
    bash "$BOOT" 2>&1 | grep '^CREW_DISPATCH' || true
}
GEM='{"rules":[{"when":"gemini work","use":{"harness":"gemini","model":"gemini-3.8-flash-high","provider":"google"}}]}'
CAP='{"rules":[{"when":"hard design","approval":"Captain","use":{"harness":"claude"}}]}'
printf '%s\n' "$GEM" > "$LAB/config/crew-dispatch.json"
show "gemini+provider profile, no key, no declaration"
b=$(boot); printf '  -> %s\n' "${b:-<no CREW_DISPATCH line>}"
check "baseline kept: unverified harness: gemini" '[ "$b" = "CREW_DISPATCH: invalid config/crew-dispatch.json - unverified harness: gemini" ]'
printf '{"typesafe":{"source":"macos-keychain","service":"%s"}}\n' "$STANDIN_SVC" > "$CRED"
show "same profile + valid typesafe declaration"
b=$(boot); printf '  -> %s\n' "${b:-<no CREW_DISPATCH line>}"
check "typed checks on: gemini accepted (no CREW_DISPATCH line)" '[ -z "$b" ]'
check "bootstrap never ran security" '! sec_called'
printf '%s\n' "$CAP" > "$LAB/config/crew-dispatch.json"
show "approval \"Captain\" rule + valid typesafe declaration"
b=$(boot); printf '  -> %s\n' "${b:-<no CREW_DISPATCH line>}"
check "typed approval check fires" '[ "$b" = "CREW_DISPATCH: invalid config/crew-dispatch.json - approval must be \"captain\" when present" ]'
check "bootstrap never ran security" '! sec_called'
show "and the resolver agrees on the same home (declared source served by the Keychain stand-in)"
run_resolver parity standin
check "resolver also applies typed rule checks: exit 2 malformed rules file" '[ $RC = 2 ] && printf "%s" "$ERR" | grep -q "malformed rules file" && ! curl_called'
printf '%s\n' "$GEM" > "$LAB/config/crew-dispatch.json"
for decl in '{"openrouter":{"source":"macos-keychain","service":"x"}}' '{"typesafe":{"source":"macos-keychain","service":"x","key":"inline"}}'; do
  printf '%s\n' "$decl" > "$CRED"
  show "gemini profile + non-qualifying declaration $decl"
  b=$(boot); printf '  -> %s\n' "${b:-<no CREW_DISPATCH line>}"
  check "baseline kept (unverified harness: gemini); no security" '[ "$b" = "CREW_DISPATCH: invalid config/crew-dispatch.json - unverified harness: gemini" ] && ! sec_called'
done

echo
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
