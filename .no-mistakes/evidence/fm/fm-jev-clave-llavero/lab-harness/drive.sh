# Sourced driver for the live credential-source scenarios.
# drive <title> [VAR=VAL ...] -- <resolver args...>
# Knobs (shell vars): TOOL (resolver path), FMH (FM_HOME), SHIMPATH (PATH prefix),
# FULLPATH (replace PATH entirely), DECL_FILE (declaration to display).
: "${LAB:?}" "${WT:?}"
TOOL=${TOOL:-$WT/bin/fm-dispatch-resolve.sh}
drive() {
  local title=$1; shift
  local envs=() fmh=${FMH:-$LAB/home} rpath
  while [ $# -gt 0 ] && [ "$1" != -- ]; do envs+=("$1"); shift; done
  shift
  rpath=${FULLPATH:-${SHIMPATH:-$LAB/shim}:$PATH}
  : > "$LAB/logs/security.log"; : > "$LAB/logs/curl.log"; : > "$LAB/logs/quota.log"; : > "$LAB/logs/requests.jsonl"
  find "$LAB/rtmp" -mindepth 1 -delete
  echo "===== $title ====="
  printf '$ FM_HOME=%s %s' "${fmh/#$LAB/\$LAB}" "${envs[*]:+$(printf '%s ' "${envs[@]}" | sed -E 's/(API_KEY=)[^ ]+/\1<canary>/g; s#'"$LAB"'#$LAB#g')}"
  printf '%s ' "${TOOL/#$WT\//}" "${@/#$LAB/\$LAB}"; echo
  local decl=${DECL_FILE:-$fmh/config/dispatch-credential-sources.json}
  if [ -f "$decl" ]; then echo "# ${decl/#$LAB/\$LAB}: $(tr -d '\n' < "$decl")"; else echo "# ${decl/#$LAB/\$LAB}: (absent)"; fi
  if [ -f "$fmh/.env" ]; then echo "# .env: $(sed -E 's/(KEY=).*/\1<.env canary>/' "$fmh/.env" | tr '\n' ' ')"; else echo "# .env: (absent)"; fi
  local t0 t1
  t0=$(python3 -c 'import time;print(int(time.time()*1000))')
  env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u TYPESAFE_API_KEY -u OPENROUTER_API_KEY -u OPENAI_API_KEY \
    -u FM_DISPATCH_PROVIDER -u FM_DISPATCH_MODEL -u FM_DISPATCH_BASE_URL -u FM_DISPATCH_API_KEY -u FM_CONFIG_OVERRIDE \
    -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_PROJECTS_OVERRIDE \
    PATH="$rpath" FM_HOME="$fmh" TMPDIR="$LAB/rtmp" FM_LAB="$LAB" "${envs[@]}" \
    "$TOOL" "$@" > "$LAB/logs/stdout" 2> "$LAB/logs/stderr"
  local rc=$?
  t1=$(python3 -c 'import time;print(int(time.time()*1000))')
  echo "--- exit: $rc   (wall ${t1}-${t0} = $((t1 - t0)) ms)"
  echo "--- stdout:"; [ -s "$LAB/logs/stdout" ] && sed "s#$LAB#\$LAB#g" "$LAB/logs/stdout" || echo "(empty)"
  echo "--- stderr:"; [ -s "$LAB/logs/stderr" ] && sed "s#$LAB#\$LAB#g" "$LAB/logs/stderr" || echo "(empty)"
  echo "--- security invocations:"; [ -s "$LAB/logs/security.log" ] && sed "s#$LAB#\$LAB#g" "$LAB/logs/security.log" || echo "(none)"
  echo "--- curl invocations:"; [ -s "$LAB/logs/curl.log" ] && sed "s#$LAB#\$LAB#g" "$LAB/logs/curl.log" || echo "(none)"
  echo "--- quota-axi invocations:"; [ -s "$LAB/logs/quota.log" ] && cat "$LAB/logs/quota.log" || echo "(none)"
  echo "--- requests received by the local stub endpoint:"
  if [ -s "$LAB/logs/requests.jsonl" ]; then
    # Show which canary the Bearer header carried, never the canary value itself.
    jq -c '.authorization = (if .authorization_is then "Bearer <\(.authorization_is)>" elif .authorization == "" then "(none)" else "<other>" end)' "$LAB/logs/requests.jsonl"
  else echo "(none)"; fi
  echo "--- key containment:"
  local c v n
  for c in "$LAB"/*-canary; do
    [ -f "$c" ] || continue
    v=$(cat "$c"); n=$(basename "$c")
    if grep -qF -- "$v" "$LAB/logs/stdout" "$LAB/logs/stderr"; then echo "LEAK: $n in resolver stdout/stderr"; else echo "ok: $n not in resolver stdout/stderr"; fi
    grep -qF -- "$v" "$LAB/logs/security.log" && echo "LEAK: $n on security argv"
    grep -qF -- "$v" "$LAB/logs/curl.log" && echo "LEAK: $n on curl argv/env"
    grep -rqF -- "$v" "$LAB/rtmp" 2>/dev/null && echo "LEAK: $n left in resolver temp dir"
  done
  echo
  return 0
}
canary() { cat "$LAB/$1-canary"; }
declare_src() { printf '%s\n' "$1" > "${2:-$LAB/home}/config/dispatch-credential-sources.json"; }
no_decl() { rm -f "${1:-$LAB/home}/config/dispatch-credential-sources.json"; }
