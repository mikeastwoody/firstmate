#!/usr/bin/env bash
# dispatch.sh <base|head> : run that tree's REAL fm-dispatch-resolve.sh in the lab home.
set -u
LAB=$(cat /tmp/fm-lab-path-01M72Z); V=$1
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE \
  -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE -u TYPESAFE_API_KEY -u OPENROUTER_API_KEY -u OPENAI_API_KEY \
  PATH="$LAB/qbin:/opt/homebrew/bin:/usr/bin:/bin" FM_HOME="$LAB/home" \
  FM_DISPATCH_PROVIDER=systemone FM_DISPATCH_MODEL=jev-1.13.0 FM_DISPATCH_BASE_URL="http://127.0.0.1:$(cat "$LAB/port")" \
  bash "$LAB/$V/bin/fm-dispatch-resolve.sh" "$LAB/home/data/fm-lab-7463/brief.md" --project lab
echo "[exit=$?] task-record: $(cat "$LAB/home/data/fm-lab-7463/dispatch-resolution.json" 2>/dev/null)"
