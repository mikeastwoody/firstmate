#!/usr/bin/env bash
# Stand-in for a Keychain access prompt nobody answers: never returns.
LAB=${FM_LAB:?}
{ printf 'argv(hanging stand-in, pid %s):' "$$"; printf ' %q' "$@"; printf '\n'; } >> "$LAB/logs/security.log"
echo $$ > "$LAB/logs/hang.pid"
exec sleep 600
