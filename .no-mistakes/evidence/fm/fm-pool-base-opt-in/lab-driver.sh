#!/usr/bin/env bash
# Lab driver: run the real bin/fm-spawn.sh from the lab captain pane and record its transcript.
L=/private/var/folders/t1/hn73dcyn0mg70rx5np1f41_80000gn/T/fm-lab.bIhpVC
P=$L/work/labproj
ROOT=/Users/mike/.no-mistakes/worktrees/8544444aa3b7/01M4ZX9JQ61DPTE40S1KFJZZER
id=$1; shift
out=$L/out/$id.log
{
  printf '$ FM_HOME=%s bin/fm-spawn.sh %s %s %s\n' "$FM_HOME" "$id" "$P" "$*"
  cd "$ROOT" && bin/fm-spawn.sh "$id" "$P" "$@"
  echo "exit=$?"
} > "$out" 2>&1
touch "$L/out/$id.done"
