#!/usr/bin/env bash
# spawn.sh <id> <spawn-args...>  -> runs the real fm-spawn.sh in the lab and records base facts
. /private/tmp/fmpb.nefE3r/driver/env.sh
id=$1; shift
echo "\$ FM_HOME=\$LAB bin/fm-spawn.sh $id \$LAB/projects/demo $*"
out=$(cd "$LAB" && lab_run "$WT/bin/fm-spawn.sh" "$id" "$LAB/projects/demo" "$@" 2>&1); rc=$?
printf '%s\n' "$out"
echo "exit=$rc"
wt=$(sed -n 's/^worktree=//p' "$LAB/state/$id.meta" 2>/dev/null | tail -1)
P="$LAB/projects/demo"
echo "--- base facts for $id"
echo "primary checkout main : $(git -C "$P" rev-parse --short main) ($(git -C "$P" log -1 --format=%s main))"
echo "origin/main (fetched) : $(git -C "$P" ls-remote origin refs/heads/main | cut -c1-7)"
if [ -n "$wt" ]; then
  echo "worker worktree       : $wt"
  echo "worker HEAD           : $(git -C "$wt" rev-parse --short HEAD) ($(git -C "$wt" log -1 --format=%s HEAD)) branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
  echo "worker CLAUDE.md      : $(grep 'Instruction marker' "$wt/CLAUDE.md" 2>/dev/null)"
fi
