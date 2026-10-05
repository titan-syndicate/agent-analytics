#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
command=${1:-help}; [ "$#" -eq 0 ] || shift
timeout=180 trace= project=copilot-lab
while [ "$#" -gt 0 ]; do
  [ "$#" -ge 2 ] || fail "Missing option value"
  case "$1" in --trace-id) trace=$2 ;; --timeout) timeout=$2 ;; --project) project=$2 ;;
    *) fail "Unknown option: $1" ;; esac
  shift 2
done
positive "$timeout"; private_dir
need openssl
if [ "$command" = smoke ]; then
  trace=$(openssl rand -hex 16)
  root=$(openssl rand -hex 8)
  jq -n --arg trace "$trace" --arg root "$root" \
    --arg chat "$(openssl rand -hex 8)" --arg tool "$(openssl rand -hex 8)" \
    --argjson now "$(date +%s)" '
    def a($k;$v): {key:$k,value:{stringValue:$v}};
    def span($id;$op;$offset):
      {traceId:$trace,spanId:$id,name:($op + " comparison-smoke"),kind:1,
       startTimeUnixNano:(($now-3+$offset)*1e9 | tostring),
       endTimeUnixNano:($now*1e9 | tostring),status:{code:1},
       attributes:[a("gen_ai.operation.name";$op),a("gen_ai.conversation.id";"synthetic-"+$trace)]};
    {resourceSpans:[{resource:{attributes:[a("service.name";"agent-viewer-smoke")]},
      scopeSpans:[{scope:{name:"viewer-comparison"},spans:[
        span($root;"invoke_agent";0),
        (span($chat;"chat";1) + {parentSpanId:$root} |
          .attributes += [a("gen_ai.request.model";"synthetic-model"),
            {key:"gen_ai.usage.input_tokens",value:{intValue:"12"}},
            {key:"gen_ai.usage.output_tokens",value:{intValue:"3"}}]),
        (span($tool;"execute_tool";2) + {parentSpanId:$root})
      ]}]}]}' > "$ROOT/.local-lab/probe.json"
  http "$OTLP/v1/traces" -H 'Content-Type: application/json' \
    --data-binary "@$ROOT/.local-lab/probe.json" |
    jq -e '(.partialSuccess // {} | length) == 0' >/dev/null || fail "Partial OTLP rejection"
elif [ "$command" != verify ]; then
  fail "Usage: bash scripts/viewers.sh smoke | verify --trace-id ID [--project NAME] [--timeout SECONDS]"
fi
[[ "$trace" =~ ^[0-9a-f]{32}$ ]] || fail "Expected lowercase hexadecimal 32-character trace ID"
[ -f "$ROOT/.local-lab/credentials.json" ] || fail "Run bash scripts/viewer-setup.sh"
auth=$(jq -er .LANGFUSE_AUTH "$ROOT/.local-lab/credentials.json")
work=$(mktemp -d "$ROOT/.local-lab/viewers.XXXXXX")
trap 'rm -f "$work/tempo.json" "$work/phoenix.json" "$work/langfuse.json" "$work/result.json"; rmdir "$work"' EXIT
read_back() {
  local code=0
  proxy tempo "api/traces/$trace" > "$work/tempo.json" || code=$?
  [ "$code" -eq 0 ] || return "$code"
  normalize_tempo "$work/tempo.json"
  jq -e "$content_filter" "$work/tempo.json" >/dev/null || fail "Known content fields detected"
  encoded=$(jq -nr --arg project "$project" '$project | @uri')
  code=0
  http "http://127.0.0.1:6006/v1/projects/$encoded/spans" --get \
    --data-urlencode "trace_id=$trace" --data-urlencode limit=1000 > "$work/phoenix.json" || code=$?
  [ "$code" -eq 0 ] || return "$code"
  http 'http://127.0.0.1:3001/api/public/v2/observations' --get -H "Authorization: Basic $auth" \
    --data-urlencode "traceId=$trace" --data-urlencode limit=1000 \
    --data-urlencode fields=core,basic,time,io,model,usage,metadata,trace_context \
    > "$work/langfuse.json" || return $?
  count=$(jq "$spans_filter | length" "$work/tempo.json")
  [ "$(jq '.data | length' "$work/phoenix.json")" -ge "$count" ] || return 45
  [ "$(jq '.data | length' "$work/langfuse.json")" -ge "$count" ] || return 45
  jq -n --arg trace "$trace" --slurpfile tempo "$work/tempo.json" \
    --slurpfile phoenix "$work/phoenix.json" --slurpfile langfuse "$work/langfuse.json" \
    -f "$ROOT/scripts/check-viewers.jq" > "$work/result.json"
}
poll "all three matching traces" "$timeout" read_back
cat "$work/result.json"
