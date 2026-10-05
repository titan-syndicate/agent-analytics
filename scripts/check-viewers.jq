def attrs: [.attributes[]? | {key:.key,value:(.value.stringValue // .value.intValue // .value.doubleValue)}] | from_entries;
def epoch: sub("Z$"; "+00:00") | capture("^(?<s>[^.]+)(?:\\.(?<f>[0-9]+))?\\+00:00$") |
  ((.s + "Z" | fromdateiso8601) + (("0." + (.f // "0")) | tonumber));
def ensure($condition; $message): if $condition then . else error($message) end;
def envelope($raw; $output):
  if $output == null or $output == "" then true else
    ($output | if type == "string" then fromjson else . end) as $v |
    ($v | type == "object") and
    all($v | to_entries[]; (.key == "id" and .value == $raw["gen_ai.response.id"]) or
      (.key == "model" and .value == $raw["gen_ai.response.model"]))
  end;
($phoenix[0].data | map({key:.context.span_id,value:.}) | from_entries) as $p |
($langfuse[0].data | map({key:.id,value:.}) | from_entries) as $l |
[($tempo[0].resourceSpans // $tempo[0].batches // [])[] |
  (.scopeSpans // .instrumentationLibrarySpans // [])[] | .spans[]] as $spans |
ensure(($spans | length) > 0; "Tempo returned no spans") |
reduce $spans[] as $span (.;
  ($span | attrs) as $a | $p[$span.spanId] as $ps | $l[$span.spanId] as $ls |
  ensure($ps != null and $ls != null; "Matching spans not yet stored") |
  ensure($ps.context.trace_id == $trace and $ls.traceId == $trace; "Trace identity mismatch") |
  ensure(($ps.parent_id // "") == ($span.parentSpanId // "") and
    ($ls.parentObservationId // "") == ($span.parentSpanId // ""); "Parent identity mismatch") |
  ({"invoke_agent":["AGENT","AGENT"],"chat":["LLM","GENERATION"],"execute_tool":["TOOL","TOOL"]}
    [$a["gen_ai.operation.name"]]) as $k |
  ensure($k == null or ($ps.span_kind == $k[0] and ($ls.type | ascii_upcase) == $k[1]); "Operation kind mismatch") |
  ensure($a["gen_ai.conversation.id"] == null or
    ($ps.attributes["session.id"] == $a["gen_ai.conversation.id"] and
     $ls.sessionId == $a["gen_ai.conversation.id"]); "Session identity mismatch") |
  ensure(($ps.attributes["input.value"] // "") == "" and envelope($a; $ps.attributes["output.value"])
    and ($ls.input == null or $ls.input == "") and ($ls.output == null or $ls.output == "");
    "Unexpected message content") |
  ensure((($ps.start_time | epoch) - ($span.startTimeUnixNano | tonumber / 1e9) | fabs) <= 0.0011 and
    (($ls.startTime | epoch) - ($span.startTimeUnixNano | tonumber / 1e9) | fabs) <= 0.0011 and
    (($ps.end_time | epoch) - ($span.endTimeUnixNano | tonumber / 1e9) | fabs) <= 0.0011 and
    (($ls.endTime | epoch) - ($span.endTimeUnixNano | tonumber / 1e9) | fabs) <= 0.0011; "Timestamp mismatch") |
  if $a["gen_ai.operation.name"] == "chat" then
    ($a["gen_ai.response.model"] // $a["gen_ai.request.model"]) as $model |
    ensure($model == null or ($ps.attributes["llm.model_name"] == $model and $ls.model == $model); "Model mismatch") |
    ensure($a["gen_ai.usage.input_tokens"] == null or
      ($ps.attributes["llm.token_count.prompt"] == ($a["gen_ai.usage.input_tokens"] | tonumber) and
       (($ls.usageDetails.input // 0) + ($ls.usageDetails.input_cached_tokens // 0) +
        ($ls.usageDetails.input_cache_creation // 0)) == ($a["gen_ai.usage.input_tokens"] | tonumber));
      "Input/cache token mismatch") |
    ensure($a["gen_ai.usage.output_tokens"] == null or
      ($ps.attributes["llm.token_count.completion"] == ($a["gen_ai.usage.output_tokens"] | tonumber) and
       (($ls.usageDetails.output // 0) + ($ls.usageDetails.output_reasoning_tokens // 0)) ==
        ($a["gen_ai.usage.output_tokens"] | tonumber)); "Output/reasoning token mismatch")
  else . end
) |
{trace_id:$trace,matching_spans:($spans|length),
 operations:([$spans[] | attrs | .["gen_ai.operation.name"]] |
   group_by(.) | map({key:.[0],value:length}) | from_entries),
 identity_parent_kind_time_session_and_usage_checks:"passed"}
