#!/usr/bin/env bash
# Shared local HTTP/JSON helpers; never source a credential file as shell code.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GRAFANA=http://127.0.0.1:3000
OTLP=http://127.0.0.1:4318
NAMESPACE=agent-analytics-lab

fail() { printf 'Lab error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || fail "Missing prerequisite: $1"; }
for dependency in curl jq; do need "$dependency"; done

http() {
  local output code
  output=$(mktemp)
  if ! code=$(curl --silent --show-error --max-time 15 -o "$output" -w '%{http_code}' "$@"); then
    cat "$output" >&2; rm "$output"; fail "HTTP connection failed"
  fi
  case "$code" in
    2??) cat "$output"; rm "$output" ;;
    404) rm "$output"; return 44 ;;
    *) printf 'HTTP %s: ' "$code" >&2; cat "$output" >&2; rm "$output"; return 1 ;;
  esac
}
proxy() { local source=$1 path=$2; shift 2; http "$GRAFANA/api/datasources/proxy/uid/$source/$path" "$@"; }
health() {
  http "$GRAFANA/api/health" | jq -e '.database == "ok"' >/dev/null ||
    fail "Grafana is not healthy; start Tilt first"
}
positive() { [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ] || fail "Expected positive integer: $1"; }
poll() {
  local description=$1 timeout=$2 deadline code
  shift 2
  deadline=$((SECONDS + timeout))
  while :; do
    code=0
    "$@" || code=$?
    [ "$code" -eq 0 ] && return
    [ "$code" -eq 44 ] || [ "$code" -eq 45 ] || fail "$description failed"
    [ "$SECONDS" -lt "$deadline" ] || fail "Timed out waiting for $description"
    sleep 2
  done
}
private_dir() { umask 077; mkdir -p "$ROOT/.local-lab"; chmod 700 "$ROOT/.local-lab"; }
normalize_tempo() {
  local file=$1 value hex mapping='{}' result
  while IFS= read -r value; do
    [[ "$value" =~ ^[0-9a-f]+$ ]] && continue
    hex=$(printf '%s' "$value" | openssl base64 -d -A | od -An -tx1 | tr -d ' \n')
    [[ "$hex" =~ ^[0-9a-f]+$ ]] || fail "Invalid Tempo ID"
    mapping=$(jq -nc --argjson map "$mapping" --arg key "$value" --arg value "$hex" '$map + {($key):$value}')
  done < <(jq -r '[.. | objects | .spanId?, .parentSpanId?, .traceId? |
    select(type == "string" and length > 0)] | unique[]' "$file")
  result=$(jq --argjson mapping "$mapping" 'walk(
    if type == "object" then
      with_entries(if (.key == "spanId" or .key == "parentSpanId" or .key == "traceId")
        and (.value | type == "string") then .value = ($mapping[.value] // .value) else . end)
    else . end)' "$file")
  printf '%s\n' "$result" > "$file"
}
spans_filter='[ (.resourceSpans // .batches // [])[] | (.scopeSpans // .instrumentationLibrarySpans // [])[] | .spans[] ]'
content_filter='[
  .. | objects |
  (keys[], (.key? | select(type == "string"))) |
  select(. == "gen_ai.input.messages" or . == "gen_ai.output.messages" or
    . == "gen_ai.system_instructions" or . == "gen_ai.tool.definitions" or
    . == "gen_ai.tool.call.arguments" or . == "gen_ai.tool.call.result")
] | length == 0'
