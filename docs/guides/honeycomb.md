# Copilot CLI + Honeycomb Agent Timeline

**Honeycomb's Agent Timeline is a documented agent-specific view of conversations, model operations and tool calls.** It is a useful reference for the local viewer we want. Full context appears only when the client emits it and the backend can parse it; it is not automatically collected.

This guide describes setup, not an integration exercised by this repository. No Honeycomb key is needed to build or read the docs.

!!! warning "External data boundary"
    Configure Honeycomb only with explicit organizational approval for the data, region and retention. Keep content off for real work by default. For the full-context demonstration, use synthetic tasks or an approved, non-sensitive example. Never capture secrets as a test.

## 1. Prepare Honeycomb

Create or select a dedicated pilot environment and an ingest key with the minimum required scope. Choose the correct ingest region:

| Region | OTLP HTTP base endpoint |
| --- | --- |
| US | `https://api.honeycomb.io` |
| EU | `https://api.eu1.honeycomb.io` |

Use the region for your account; endpoints are not interchangeable. Honeycomb documents OTLP HTTP/protobuf and HTTP/JSON support, but explicitly choosing protobuf makes the same client configuration portable.

## 2. Recommended route: through a Collector

Use a dedicated Collector so the client has no vendor credential and traces/metrics can use separate export settings. Below is a minimal local-only configuration following Honeycomb's [Collector guide](https://docs.honeycomb.io/send-data/opentelemetry/collector).

The exporter component is named `otlp_http` in current documentation. Older Collector builds may use `otlphttp`; validate with the exact release you install. Do not mix arbitrary Collector versions with copied configuration.

```yaml
receivers:
  otlp:
    protocols:
      http:
        endpoint: 127.0.0.1:4318

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 256
    spike_limit_mib: 64
  batch: {}

exporters:
  otlp_http/honeycomb:
    endpoint: ${env:HONEYCOMB_OTLP_ENDPOINT}
    headers:
      x-honeycomb-team: ${env:HONEYCOMB_API_KEY}
    retry_on_failure:
      enabled: true
    sending_queue:
      enabled: true
      queue_size: 256
  otlp_http/honeycomb_metrics:
    endpoint: ${env:HONEYCOMB_OTLP_ENDPOINT}
    headers:
      x-honeycomb-team: ${env:HONEYCOMB_API_KEY}
      x-honeycomb-dataset: copilot-pilot-metrics
    retry_on_failure:
      enabled: true
    sending_queue:
      enabled: true
      queue_size: 256

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp_http/honeycomb]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp_http/honeycomb_metrics]
```

Honeycomb metrics require a dataset header; normal traces use `service.name` for routing. Honeycomb Classic traces also require a dataset header. Adapt according to the account, not by assuming all signal routes work the same way.

This receiver is for a **native Collector on the laptop**. If it runs in a container/Pod, use an appropriate container-reachable bind address internally and expose only a loopback host port. Do not run it alongside the lab's port 4318 listener without selecting another port.

### Launch without a checked-in credential

Install an approved official [Collector distribution](https://opentelemetry.io/docs/collector/installation/) providing the components above. The example assumes the `otelcol-contrib` executable and a private `honeycomb-collector.yaml`:

```sh
export HONEYCOMB_OTLP_ENDPOINT=https://api.honeycomb.io
printf 'Honeycomb ingest key: '
read -r -s HONEYCOMB_API_KEY
printf '\n'
export HONEYCOMB_API_KEY

otelcol-contrib validate --config=honeycomb-collector.yaml
otelcol-contrib --config=honeycomb-collector.yaml
```

Use Bash for the `read -r -s` example. Get the actual key through your secret manager; do not paste it into a shell command, `.env` committed to Git, screenshot, or global Copilot instructions. Clear it with `unset HONEYCOMB_API_KEY` when finished. Environment variables are not a security boundary against other processes running as the same user.

In another terminal, use the [CLI local configuration](copilot-cli.md), changing `OTEL_SERVICE_NAME` to `github-copilot-honeycomb-pilot`. Confirm the Collector's target is deliberately external before launching the task.

The example has bounded in-memory buffering and retry, **not durable queues or a complete sanitizer**. Content-off configuration is not sufficient enterprise enforcement. Add a reviewed allowlist policy before sending arbitrary work telemetry; metadata may contain paths and error text.

## Optional route: direct CLI export

For a strictly synthetic proof, the CLI supports `OTEL_EXPORTER_OTLP_HEADERS`, so an approved ingest key can be passed directly:

```sh
# Start from a fresh terminal; remove conflicting settings as in the CLI guide.
# Read/export HONEYCOMB_API_KEY privately using the prompt above.
export COPILOT_OTEL_ENABLED=true
export COPILOT_OTEL_EXPORTER_TYPE=otlp-http
export OTEL_EXPORTER_OTLP_ENDPOINT=https://api.honeycomb.io
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_HEADERS="x-honeycomb-team=$HONEYCOMB_API_KEY,x-honeycomb-dataset=copilot-synthetic-pilot"
export OTEL_SERVICE_NAME=github-copilot-synthetic-pilot
export OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=false
copilot
```

The shared dataset header supplies the metrics requirement; confirm the account's trace routing and dataset behavior. This minimal route does not provide separate metrics/traces destinations or pre-export filtering. Use the Collector route for a real pilot, then `unset OTEL_EXPORTER_OTLP_HEADERS HONEYCOMB_API_KEY` and close the terminal after the demo.

## 3. Find the conversation

According to [Agent Timeline documentation](https://docs.honeycomb.io/investigate/observe/agent-timeline), select **AI Ecosystem -> Conversations**, then open a conversation ID or recent conversation. You can also navigate from a `gen_ai.conversation.id` in query results.

The timeline needs:

| Attribute | Purpose |
| --- | --- |
| `gen_ai.conversation.id` on conversation spans | Group multiple traces into a session |
| `gen_ai.agent.name` | Separate agents and subagents; missing names show as unknown |
| `gen_ai.operation.name` | Classify `invoke_agent`, `chat`, `execute_tool` |
| Model, usage and tool attributes | Populate model/token/tool details |
| Optional message/tool content | Populate detailed context frames |

The CLI reference does **not** list every conversation/agent field on every tool span. Inspect actual payloads. If the timeline is incomplete, build a tested normalization/enrichment rule; do not assume attributes propagate automatically down a trace or overwrite every subagent with one global name.

## 4. Reproduce a full-context demonstration safely

On an approved synthetic task only, launch a **new process** with:

```sh
export OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=true
copilot
```

Open a model/tool span's **Gen AI** details. The CLI documents messages, system instructions, tool schemas and tool call arguments/results when content capture is on. Honeycomb describes parsing those fields into agent-oriented frames.

Exit that process, restore the switch to `false`, and start a new one to return to metadata mode. Stopping capture does not delete previously ingested content; apply the agreed retention/deletion process to the synthetic demo too.

The displayed “full context” is the exported payload, not hidden chain-of-thought or guaranteed complete history. Compaction, field coverage and backend limits still apply.

## 5. Start with a small board

Use separate non-overlapping grains for chat tokens and root invocation AI units. Add model-call latency, tool error rate, compaction events and accepted outcome labels when available. Drill into examples before making recommendations.

Honeycomb's Timeline Insights is documented as early access and requires Honeycomb Intelligence. It may summarize patterns, but it is not proof of correctness or causal improvement. Do not make the pilot depend on it.

## Troubleshooting

| Problem | Check |
| --- | --- |
| 401/403 | Ingest key scope, chosen environment and region |
| Traces work, metrics fail | Metrics dataset header and metrics pipeline |
| Traces visible, conversation absent | Conversation ID coverage and GenAI operation fields |
| Unknown agent rows | Agent name missing or not emitted on selected spans |
| Empty context frames | Content off, unsupported payload schema, filtering or truncation |
| Consumption looks inflated | Parent/child duplication; AI units vs currency |

**Next:** [Backend tradeoffs](../proposals/backends.md) explains when to keep this SaaS experience and when to move the durable store to OpenSearch.
