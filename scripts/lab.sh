#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
command=${1:-help}; [ "$#" -eq 0 ] || shift

case "$command" in
  doctor)
    for tool in bash jq curl openssl docker kubectl tilt copilot; do need "$tool"; done
    [ "$(kubectl config current-context)" = docker-desktop ] || fail "Select docker-desktop yourself"
    docker info --format '{{.ServerVersion}}'
    kubectl --context docker-desktop get nodes
    tilt version; copilot version
    printf 'Check ports 3000, 3001, 4318, 6006, 9090 and 10350 before Tilt.\n'
    ;;
  run)
    need copilot
    [ "${1:-}" != -- ] || shift
    for argument in "$@"; do
      [[ "$argument" != *remote-export* ]] || fail "Session syncing is disabled; omit remote-export flags"
    done
    health
    while IFS= read -r key; do
      case "$key" in OTEL_*|COPILOT_OTEL_*) unset "$key" ;; esac
    done < <(compgen -e)
    export COPILOT_OTEL_ENABLED=true COPILOT_OTEL_EXPORTER_TYPE=otlp-http
    export OTEL_EXPORTER_OTLP_ENDPOINT="$OTLP" OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
    export OTEL_SERVICE_NAME=github-copilot-local
    export OTEL_RESOURCE_ATTRIBUTES=deployment.environment.name=local,agent_analytics.client_surface=cli
    export OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=false
    printf 'Local metadata -> %s; content off; session syncing off. Managed policy may override.\n' "$OTLP" >&2
    exec copilot --no-remote-export "$@"
    ;;
  smoke)
    exec bash "$ROOT/scripts/viewers.sh" smoke "$@"
    ;;
  verify-copilot)
    since= expected=1 timeout=120
    while [ "$#" -gt 0 ]; do
      [ "$#" -ge 2 ] || fail "Missing option value"
      case "$1" in
        --since) since=$2 ;; --expected-traces) expected=$2 ;; --timeout) timeout=$2 ;;
        *) fail "Unknown option: $1" ;;
      esac
      shift 2
    done
    positive "$expected"; positive "$timeout"
    [[ "$since" =~ ^[0-9]+$ ]] && [ "$since" -le "$(date +%s)" ] || fail "--since needs a past Unix timestamp"
    health; private_dir
    need openssl
    work=$(mktemp -d "$ROOT/.local-lab/verify.XXXXXX")
    trap 'rm -f "$work/search.json" "$work/trace.json" "$work/spans.json" "$work/metrics.json"; rmdir "$work"' EXIT
    trace_check() {
      local start=$((since > 60 ? since - 60 : 0)) trace code
      proxy tempo api/search --get \
        --data-urlencode 'q={ resource.service.name = "github-copilot-local" }' \
        --data-urlencode "start=$start" --data-urlencode "end=$(date +%s)" \
        --data-urlencode 'limit=100' > "$work/search.json" || return $?
      jq --argjson since "$since" '[.traces[]? |
        select((.startTimeUnixNano | tonumber / 1000000000) >= $since)]' \
        "$work/search.json" > "$work/trace.json"
      [ "$(jq length "$work/trace.json")" -ge "$expected" ] || return 45
      printf '[]\n' > "$work/spans.json"
      while IFS= read -r trace; do
        code=0
        proxy tempo "api/traces/$trace" > "$work/search.json" || code=$?
        [ "$code" -eq 0 ] || return "$code"
        jq -e "$content_filter" "$work/search.json" >/dev/null || fail "Known content fields detected"
        data=$(jq -s ".[0] + (.[1] | $spans_filter)" "$work/spans.json" "$work/search.json")
        printf '%s\n' "$data" > "$work/spans.json"
      done < <(jq -r '.[].traceID' "$work/trace.json")
      jq -e '[.[].attributes[]? | select(.key == "gen_ai.operation.name") | .value.stringValue] |
        (index("chat") != null and index("invoke_agent") != null and index("execute_tool") != null)' \
        "$work/spans.json" >/dev/null || return 45
    }
    metrics_check() {
      proxy prometheus api/v1/query_range --get --data-urlencode \
        'query=timestamp(label_replace({__name__=~"(gen_ai|github_copilot).*",service_name="github-copilot-local"}, "agent_analytics_metric_name", "$1", "__name__", "(.+)"))' \
        --data-urlencode "start=$since" --data-urlencode "end=$(($(date +%s) + 1))" \
        --data-urlencode step=30 > "$work/metrics.json" || return $?
      jq -e '.status == "success"' "$work/metrics.json" >/dev/null || fail "Prometheus query failed"
      jq --argjson since "$since" '[.data.result[] | select(any(.values[]; (.[1]|tonumber) >= $since)) |
        .metric.agent_analytics_metric_name] | unique' "$work/metrics.json" > "$work/search.json"
      jq -e 'index("gen_ai_client_inference_usage_input_tokens_total") != null and
        index("gen_ai_client_inference_usage_output_tokens_total") != null and
        index("github_copilot_tool_call_count_total") != null' "$work/search.json" >/dev/null || return 45
    }
    poll "CLI traces with invocation/model/tool operations" "$timeout" trace_check
    poll "CLI token/tool metric samples" "$timeout" metrics_check
    jq -n --slurpfile traces "$work/trace.json" --slurpfile spans "$work/spans.json" \
      --slurpfile metrics "$work/search.json" '{
        trace_count:($traces[0]|length),trace_ids:[$traces[0][].traceID],
        operations:([$spans[0][].attributes[]? | select(.key=="gen_ai.operation.name") |
          .value.stringValue] | group_by(.) | map({key:.[0],value:length}) | from_entries),
        metric_names:$metrics[0],known_content_fields:"absent in retrieved traces",
        viewer:"http://127.0.0.1:3000/explore"
      }'
    ;;
  *) fail "Usage: bash scripts/lab.sh doctor | run [-- CLI args] | smoke | verify-copilot --since SECONDS [--expected-traces N] [--timeout SECONDS]" ;;
esac
