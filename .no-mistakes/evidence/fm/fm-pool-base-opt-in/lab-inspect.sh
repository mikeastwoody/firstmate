#!/usr/bin/env bash
# Print the observable base of a spawned lab task: slot HEAD vs origin/main vs the primary's main.
L=/private/var/folders/t1/hn73dcyn0mg70rx5np1f41_80000gn/T/fm-lab.bIhpVC
P=$L/work/labproj
id=$1
echo "## $id"
echo "flag config/spawn-base-primary-checkout present: $([ -e $L/config/spawn-base-primary-checkout ] && echo yes || echo no)"
cat "$L/out/$id.log"
WT=$(grep '^worktree=' "$L/state/$id.meta" 2>/dev/null | cut -d= -f2-)
[ -n "$WT" ] || { echo "(no worktree recorded)"; exit 0; }
echo "recorded meta:"; grep -E '^(kind|mode|worktree|base_branch)=' "$L/state/$id.meta" | sed 's/^/  /'
echo "slot HEAD    : $(git -C "$WT" rev-parse --short HEAD) $(git -C "$WT" log -1 --format=%s HEAD)"
echo "origin/main  : $(git -C "$P" rev-parse --short origin/main) $(git -C "$P" log -1 --format=%s origin/main)"
echo "primary main : $(git -C "$P" rev-parse --short main) $(git -C "$P" log -1 --format=%s main)"
echo "slot AGENTS.md -> $(grep 'Instruction marker' "$WT/AGENTS.md")"
echo "slot files   : $(cd "$WT" && ls | tr '\n' ' ')"
echo "slot status  : $(git -C "$WT" status --porcelain | wc -l | tr -d ' ') uncommitted paths"
echo
