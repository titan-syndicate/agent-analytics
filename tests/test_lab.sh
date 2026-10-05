#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
for file in "$ROOT"/scripts/*.sh "$ROOT"/tests/*.sh; do bash -n "$file"; done
source "$ROOT/scripts/common.sh"
work=$(mktemp -d)
trap 'rm -f "$work/source.json" "$work/phoenix.json" "$work/langfuse.json" "$work/bad.json" "$work/result.json" "$work/curl" "$work/copilot"; rmdir "$work"' EXIT

# The fake CLI sees only the wrapper's child environment, never real authentication.
cat > "$work/copilot" <<'SH'
#!/usr/bin/env bash
jq -n --arg endpoint "$OTEL_EXPORTER_OTLP_ENDPOINT" \
  --arg content "$OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT" \
  --arg inherited "${OTEL_EXPORTER_OTLP_CLIENT_KEY:-absent}" \
  --arg auth "${GH_TOKEN:-}" --args '$ARGS.positional as $args |
    {endpoint:$endpoint,content:$content,inherited:$inherited,auth:$auth,args:$args}' -- "$@"
SH
cat > "$work/curl" <<'SH'
#!/usr/bin/env bash
while [ "$#" -gt 0 ]; do
  if [ "$1" = -o ]; then output=$2; shift 2; else shift; fi
done
if [ "${MOCK_STATUS:-200}" = 200 ]; then
  printf '{"database":"ok"}' > "$output"
else
  printf '{"error":"synthetic backend rejection"}' > "$output"
fi
printf '%s' "${MOCK_STATUS:-200}"
SH
chmod +x "$work/copilot" "$work/curl"
PATH="$work:$PATH" GH_TOKEN=synthetic-auth OTEL_EXPORTER_OTLP_CLIENT_KEY=bad \
  OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=true \
  bash "$ROOT/scripts/lab.sh" run -- -p 'synthetic prompt' > "$work/result.json"
jq -e '.endpoint=="http://127.0.0.1:4318" and .content=="false" and
  .inherited=="absent" and .auth=="synthetic-auth" and
  .args==["--no-remote-export","-p","synthetic prompt"]' "$work/result.json" >/dev/null
if PATH="$work:$PATH" bash "$ROOT/scripts/lab.sh" run -- --remote-export >/dev/null 2>&1; then
  fail "remote-export override accepted"
fi
if PATH="$work:$PATH" MOCK_STATUS=500 bash "$ROOT/scripts/lab.sh" run >/dev/null 2>"$work/result.json"; then
  fail "HTTP 500 treated as success"
fi
grep -q 'synthetic backend rejection' "$work/result.json"
if bash -c 'source "$1"; not_ready() { return 45; }; poll missing 1 not_ready' \
    _ "$ROOT/scripts/common.sh" >/dev/null 2>"$work/result.json"; then
  fail "Missing data treated as success"
fi
grep -q 'Timed out' "$work/result.json"
printf '{"data":{"result":[{"values":[[200,"90"]]},{"values":[[200,"110"]]}]}}' |
  jq -e '[.data.result[] | select(any(.values[]; (.[1]|tonumber)>=100))] | length==1' >/dev/null
if bash "$ROOT/scripts/viewers.sh" verify --trace-id invalid >/dev/null 2>&1; then
  fail "Invalid trace accepted"
fi

printf '{"spanId":"EjRWeJCrze8=","parentSpanId":null}\n' > "$work/source.json"
normalize_tempo "$work/source.json"
jq -e '.spanId=="1234567890abcdef"' "$work/source.json" >/dev/null
printf '{"key":{"nested":"value"}}\n' | jq -e "$content_filter" >/dev/null
if printf '{"events":[{"attributes":[{"key":"gen_ai.tool.call.result"}]}]}' |
  jq -e "$content_filter" >/dev/null; then fail "Content field escaped recursive check"; fi

while IFS= read -r scenario; do
  printf '%s' "$scenario" | jq --arg trace 1234567890abcdef1234567890abcdef \
    --arg prefix 1234567890ab --arg run synthetic-test --argjson now 1800000000 \
    -f "$ROOT/scripts/demo-payload.jq" > "$work/source.json"
  jq -e "$content_filter" "$work/source.json" >/dev/null
  jq -e "$spans_filter | all(.[]; (.traceId|length)==32 and (.spanId|length)==16)" "$work/source.json" >/dev/null
  jq "$spans_filter"' | {data:map(
    ([.attributes[]|{key:.key,value:(.value.stringValue // .value.intValue)}]|from_entries) as $a |
    {context:{span_id:.spanId,trace_id:.traceId},parent_id:.parentSpanId,
     span_kind:({invoke_agent:"AGENT",chat:"LLM",execute_tool:"TOOL"}[$a["gen_ai.operation.name"]]),
     start_time:(.startTimeUnixNano|tonumber/1e9|todateiso8601),
     end_time:(.endTimeUnixNano|tonumber/1e9|todateiso8601),
     attributes:{"session.id":$a["gen_ai.conversation.id"],
       "llm.model_name":$a["gen_ai.request.model"],
       "llm.token_count.prompt":($a["gen_ai.usage.input_tokens"] // "0"|tonumber),
       "llm.token_count.completion":($a["gen_ai.usage.output_tokens"] // "0"|tonumber)}})}' \
    "$work/source.json" > "$work/phoenix.json"
  jq "$spans_filter"' | {data:map(
    ([.attributes[]|{key:.key,value:(.value.stringValue // .value.intValue)}]|from_entries) as $a |
    {id:.spanId,traceId:.traceId,parentObservationId:.parentSpanId,
     type:({invoke_agent:"AGENT",chat:"GENERATION",execute_tool:"TOOL"}[$a["gen_ai.operation.name"]]),
     startTime:(.startTimeUnixNano|tonumber/1e9|todateiso8601),
     endTime:(.endTimeUnixNano|tonumber/1e9|todateiso8601),
     model:$a["gen_ai.request.model"],sessionId:$a["gen_ai.conversation.id"],
     usageDetails:{input:($a["gen_ai.usage.input_tokens"] // "0"|tonumber),
       output:($a["gen_ai.usage.output_tokens"] // "0"|tonumber)}})}' \
    "$work/source.json" > "$work/langfuse.json"
  jq -n --arg trace 1234567890abcdef1234567890abcdef --slurpfile tempo "$work/source.json" \
    --slurpfile phoenix "$work/phoenix.json" --slurpfile langfuse "$work/langfuse.json" \
    -f "$ROOT/scripts/check-viewers.jq" > "$work/result.json"
  printf 'Fixture checked: %s\n' "$(printf '%s' "$scenario" | jq -r .slug)"
done < <(jq -nc -f "$ROOT/local/demo-scenarios.jq" | jq -c '.[]')

for corruption in '.data[0].parentObservationId="wrong"' '.data[0].type="WRONG"' \
    '.data[0].startTime="2020-01-01T00:00:00Z"' '.data[0].input="unexpected content"' \
    '.data[1].usageDetails.input=999999'; do
  jq "$corruption" "$work/langfuse.json" > "$work/bad.json"
  if jq -n --arg trace 1234567890abcdef1234567890abcdef --slurpfile tempo "$work/source.json" \
      --slurpfile phoenix "$work/phoenix.json" --slurpfile langfuse "$work/bad.json" \
      -f "$ROOT/scripts/check-viewers.jq" >/dev/null 2>&1; then fail "Corrupted viewer record accepted"; fi
done
jq '.data |= map(if .type=="GENERATION" then .usageDetails.output -= 2 |
  .usageDetails.output_reasoning_tokens=2 else . end)' "$work/langfuse.json" > "$work/bad.json"
jq -n --arg trace 1234567890abcdef1234567890abcdef --slurpfile tempo "$work/source.json" \
  --slurpfile phoenix "$work/phoenix.json" --slurpfile langfuse "$work/bad.json" \
  -f "$ROOT/scripts/check-viewers.jq" >/dev/null
jq -e '.uid=="agent-cost-demo" and (.panels|length)==8' "$ROOT/local/demo-dashboard.json" >/dev/null
printf 'Bash environment isolation, guards, JSON fixtures and viewer checks passed.\n'
