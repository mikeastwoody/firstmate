#!/usr/bin/env bash
# scaffold.sh <id> <task-text> <spec-text> <brief-args...>
. /private/tmp/fmpb.nefE3r/driver/env.sh
id=$1 task=$2 spec=$3; shift 3
(cd "$LAB" && lab_run "$WT/bin/fm-brief.sh" "$id" demo "$@") >/dev/null || { echo "brief failed" >&2; exit 1; }
TASK_TEXT="$task" SPEC_TEXT="$spec" python3 - "$LAB/data/$id/brief.md" <<'PY' || exit 1
import os, sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
t = t.replace("{TASK}", os.environ["TASK_TEXT"], 1).replace("{FIRSTMATE_SPEC}", os.environ["SPEC_TEXT"], 1)
open(p, "w", encoding="utf-8").write(t)
PY
kind=ship; case " $* " in *" --scout "*) kind=scout ;; esac
(cd "$LAB" && lab_run "$WT/bin/fm-tasks-axi.sh" add "$id" "lab $id" --kind "$kind" --repo demo) >/dev/null || { echo "tasks add failed" >&2; exit 1; }
echo "scaffolded $id ($kind)"
