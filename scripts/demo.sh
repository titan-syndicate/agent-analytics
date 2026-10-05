#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
need openssl; private_dir
health
run="demo-$(date -u +%Y%m%dT%H%M%SZ)-$(openssl rand -hex 3)"
now=$(date +%s)
directory="$ROOT/.local-lab/$run"
mkdir "$directory"
jq -n -f "$ROOT/local/demo-scenarios.jq" > "$directory/scenarios.json"
printf '[]\n' > "$directory/links.json"
project=$(http http://127.0.0.1:6006/v1/projects --get --data-urlencode limit=100 |
  jq -er '.data[] | select(.name=="copilot-lab") | .id')
while IFS= read -r scenario; do
  slug=$(printf '%s' "$scenario" | jq -r .slug)
  trace=$(openssl rand -hex 16)
  printf '%s' "$scenario" | jq --arg trace "$trace" --arg prefix "$(openssl rand -hex 6)" \
    --arg run "$run" --argjson now "$now" -f "$ROOT/scripts/demo-payload.jq" > "$directory/$slug.json"
  http "$OTLP/v1/traces" -H 'Content-Type: application/json' --data-binary "@$directory/$slug.json" |
    jq -e '(.partialSuccess // {} | length)==0' >/dev/null || fail "Trace partial rejection"
  printf '%s' "$scenario" | jq --arg run "$run" --argjson now "$now" '
    def sa($k;$v): {key:$k,value:{stringValue:$v}};
    . as $s | {resourceMetrics:[{resource:{attributes:[sa("service.name";"agent-cost-demo")]},
      scopeMetrics:[{scope:{name:"agent-analytics.synthetic-fixtures"},metrics:(
        {input_tokens:(.input|add),output_tokens:(.output|add),model_calls:(.input|length),
         agent_calls:.agents,tool_calls:.tools,failed_tools:.failed,wall_seconds:.seconds} |
        to_entries | map({name:("agent_demo_"+.key),description:"Synthetic fixture, not production usage",
          gauge:{dataPoints:[{attributes:[sa("scenario";$s.slug),sa("demo_run";$run),
            sa("model";$s.model)],timeUnixNano:($now*1e9|tostring),asDouble:.value}]}})
      )}]}]}' > "$directory/$slug-metrics.json"
  http "$OTLP/v1/metrics" -H 'Content-Type: application/json' \
    --data-binary "@$directory/$slug-metrics.json" |
    jq -e '(.partialSuccess // {} | length)==0' >/dev/null || fail "Metric partial rejection"
  bash "$ROOT/scripts/viewers.sh" verify --trace-id "$trace" > "$directory/$slug-verification.json"
  jq -e --argjson scenario "$scenario" '
    .matching_spans == ($scenario.agents + ($scenario.input|length) + $scenario.tools) and
    .operations.chat == ($scenario.input|length) and
    .operations.invoke_agent == $scenario.agents
  ' "$directory/$slug-verification.json" >/dev/null || fail "Fixture span totals differ"
  data=$(jq --argjson scenario "$scenario" --arg run "$run" --arg trace "$trace" --arg project "$project" '
    . + [{
      scenario:$scenario.slug,title:$scenario.title,trace_id:$trace,
      grafana:("http://127.0.0.1:3000/d/agent-cost-demo?var-demo_run="+$run+"&var-scenario="+$scenario.slug),
      phoenix:("http://127.0.0.1:6006/projects/"+($project|@uri)+"/spans/"+$trace+"?timeRangeKey=24h"),
      langfuse:("http://127.0.0.1:3001/project/copilot/traces/"+$trace)
    }]' "$directory/links.json")
  printf '%s\n' "$data" > "$directory/links.json"
  printf 'Stored and verified: %s\n' "$slug"
done < <(jq -c '.[]' "$directory/scenarios.json")
query="{__name__=~\"agent_demo_.*\",demo_run=\"$run\"}"
metric_ready() {
  proxy prometheus api/v1/query --get --data-urlencode "query=$query" > "$directory/metric-check.json" || return $?
  jq -e '.status == "success"' "$directory/metric-check.json" >/dev/null || fail "Demo metric query failed"
  jq -e '.data.result | length == 42' "$directory/metric-check.json" >/dev/null || return 45
  jq -e --slurpfile scenarios "$directory/scenarios.json" '
    all(.data.result[]; . as $series |
      ($series.metric.__name__ | sub("^agent_demo_";"")) as $key |
      any($scenarios[0][]; .slug == $series.metric.scenario and
        ({input_tokens:(.input|add),output_tokens:(.output|add),model_calls:(.input|length),
          agent_calls:.agents,tool_calls:.tools,failed_tools:.failed,wall_seconds:.seconds}[$key]) ==
          ($series.value[1]|tonumber)))
  ' "$directory/metric-check.json" >/dev/null || fail "Fixture metric totals differ"
}
poll "42 demo metric series with exact fixture totals" 120 metric_ready
jq -n --arg run "$run" --argjson created "$now" --slurpfile scenarios "$directory/links.json" \
  '{run:$run,created_unix:$created,synthetic:true,scenarios:$scenarios[0]}' > "$ROOT/.local-lab/demo-latest.json"
jq -r '"# Synthetic demo " + .run + "\n\nNo model calls or billed usage. Generated locally.\n\n" +
  ([.scenarios[] | "## " + .title + "\n\n- [Grafana](" + .grafana + ")\n- [Phoenix]("+
    .phoenix+")\n- [Langfuse]("+.langfuse+")\n- Trace ID: `" + .trace_id + "`\n"] | join("\n"))' \
  "$ROOT/.local-lab/demo-latest.json" > "$ROOT/.local-lab/demo-links.md"
printf '\nDemo ready. Per-scenario links: .local-lab/demo-links.md\n'
printf 'Dashboard: http://127.0.0.1:3000/d/agent-cost-demo?var-demo_run=%s\n' "$run"
