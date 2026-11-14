#!/usr/bin/env bash
# run_case.sh <case> <task-id> <pr-number> <scenario.json> <declarations-file|none> [fm-pr-merge args...]
set -u
LAB=/var/folders/t0/8lf233xd7bxcd3x5x09vqgvm0000gn/T/fm-lab.Uyc120
WT={run-worktree}
EVID=~/.no-mistakes/evidence/01M7BRB3DAY9S2WSX8AH59FA2V
name=$1 id=$2 num=$3 scen=$4 decl=$5; shift 5
out="$EVID/$name"; mkdir -p "$out"
url="https://github.localhost/acme/app/pull/$num"
jq --arg c "$name" --arg u "$url" --argjson n "$num" '. + {case: $c, url: $u, number: $n, owner: "acme", repo: "app"}' "$scen" > "$LAB/emu/scenario.json"
cp "$LAB/emu/scenario.json" "$out/emulated-github-state.json"
if [ "$decl" = none ]; then rm -f "$LAB/config/github-required-checks"; echo "(no config/github-required-checks in the lab home)" > "$out/github-required-checks"
else cp "$decl" "$LAB/config/github-required-checks"; cp "$decl" "$out/github-required-checks"; fi
printf '%s\n' "window=fm-$id" "worktree=$LAB/wt" "project=$LAB/projects/app" "kind=ship" "mode=no-mistakes" > "$LAB/state/$id.meta"
before=$(wc -l < "$LAB/emu/requests.jsonl")
printf 'FM_HOME=%s bin/fm-pr-merge.sh %s %s %s\n' "$LAB" "$id" "$url" "$*" > "$out/command.txt"
(
  . "$LAB/emu/ghenv.sh"
  cd "$WT" && env -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE \
    FM_HOME="$LAB" HOME="$LAB/user-home" bin/fm-pr-merge.sh "$id" "$url" "$@" > "$out/stdout" 2> "$out/stderr"
  echo $? > "$out/rc"
)
tail -n +$((before + 1)) "$LAB/emu/requests.jsonl" > "$out/github-requests.jsonl"
echo "== $name rc=$(cat "$out/rc")"; echo "-- stdout"; cat "$out/stdout"; echo "-- stderr"; cat "$out/stderr"
echo "-- requests"; jq -r '[.method, .path + (if .query != "" then "?" + .query else "" end), (.graphql // "" | .[0:90]), (if .merge_input then "MERGE expectedHeadOid=" + (.merge_input.expectedHeadOid // "none") + " method=" + (.merge_input.mergeMethod // "") else "" end)] | join(" ")' "$out/github-requests.jsonl"
