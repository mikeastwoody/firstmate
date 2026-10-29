#!/usr/bin/env bash
# Logs argv and whether any key is in curl's environment or argv, rewrites only
# the fixed provider hosts to the local stub, then execs the REAL /usr/bin/curl
# (fd 3, which carries the Authorization header, is inherited untouched).
LAB=${FM_LAB:?}; port=$(cat "$LAB/port")
{ printf 'argv:'; printf ' %q' "$@"; printf '\n'
  env | grep -E '^(TYPESAFE|OPENROUTER|OPENAI)_API_KEY|_PRIVATE=' | sed 's/=.*/=<set>/' | sed 's/^/env-key: /'
  for c in "$LAB"/*-canary; do [ -f "$c" ] || continue
    env | grep -qF -- "$(cat "$c")" && echo "env-has-canary: $(basename "$c")"
    printf '%s\n' "$@" | grep -qF -- "$(cat "$c")" && echo "argv-has-canary: $(basename "$c")"
  done
} >> "$LAB/logs/curl.log"
args=()
for a in "$@"; do
  a=${a/https:\/\/api.typesafe.ai/http://127.0.0.1:$port}
  a=${a/https:\/\/openrouter.ai\/api/http://127.0.0.1:$port}
  args+=("$a")
done
exec /usr/bin/curl "${args[@]}"
