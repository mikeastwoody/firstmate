#!/usr/bin/env bash
# Logs argv, then execs the REAL /usr/bin/security. A find-generic-password call
# gets the throwaway keychain path appended so the real Keychain services read
# the lab item, and the user's keychain search list is never touched.
LAB=${FM_LAB:?}
{ printf 'argv:'; printf ' %q' "$@"; printf '\n'; } >> "$LAB/logs/security.log"
if [ "${1:-}" = find-generic-password ]; then exec /usr/bin/security "$@" "$LAB/fm-lab.keychain-db"; fi
exec /usr/bin/security "$@"
