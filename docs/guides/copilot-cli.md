# Capture local Copilot CLI sessions

**Run the backend first, then launch a new Copilot process with explicit telemetry settings.** The CLI documents OTel export; it does not retroactively instrument previously completed work.

This guide uses metadata-only capture to `127.0.0.1:4318`. It does not configure the desktop app or send anything to Honeycomb.

## 1. Establish prerequisites

Install and authenticate Copilot CLI using the [official installation guide](https://docs.github.com/en/copilot/how-tos/copilot-cli/install-copilot-cli). Start the [local lab](local-lab.md), or another OTLP backend supporting HTTP/protobuf.

Record these commands' output with your private pilot notes:

```sh
copilot version
copilot help monitoring
```

The CLI's version matters more than the app icon you launched it from. If the monitoring help or variables below are absent, upgrade through your approved channel and repeat the compatibility check.

## 2. Set a deliberate local environment

In a fresh terminal, remove conflicting telemetry settings **in that terminal only**, then set the local target:

```sh
unset COPILOT_OTEL_FILE_EXPORTER_PATH
unset OTEL_EXPORTER_OTLP_HEADERS
unset OTEL_EXPORTER_OTLP_TRACES_HEADERS OTEL_EXPORTER_OTLP_METRICS_HEADERS
unset OTEL_EXPORTER_OTLP_TRACES_ENDPOINT OTEL_EXPORTER_OTLP_METRICS_ENDPOINT
unset OTEL_EXPORTER_OTLP_TRACES_PROTOCOL OTEL_EXPORTER_OTLP_METRICS_PROTOCOL

export COPILOT_OTEL_ENABLED=true
export COPILOT_OTEL_EXPORTER_TYPE=otlp-http
export OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_SERVICE_NAME=github-copilot-local
export OTEL_RESOURCE_ATTRIBUTES=deployment.environment.name=local,agent_analytics.client_surface=cli
export OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=false

copilot
```

`agent_analytics.client_surface` is our **custom pilot attribute**, not an upstream standard. Do not add your name, email, home path or repository URL to resource attributes.

The base endpoint has **no `/v1/traces` suffix**: an OTLP HTTP exporter appends the signal paths. Port 4318 is HTTP; 4317 is conventionally gRPC. The CLI documents HTTP export, so do not point it at a gRPC-only receiver.

Enterprise-managed settings can override client configuration. If export routes elsewhere or content behavior differs, check policy with your administrator rather than trying to bypass it.

## 3. Run one safe task and find it

Use a non-sensitive scratch repository and ask for a small task, such as explaining a sample function and running its existing tests. Let the response finish, then exit normally to allow exporter flushing.

In Grafana at `http://127.0.0.1:3000`, open **Explore**, select Tempo and search for the `github-copilot-local` service. A representative TraceQL search is:

```text
{ resource.service.name = "github-copilot-local" }
```

Expect an invocation with model calls and tool spans if tools were used. Inspect attributes for conversation ID, operation, model and token usage. In the Prometheus data source, search the metric browser for `gen_ai` and `github_copilot`; OTLP-to-Prometheus naming and labels can change with backend versions, so discover the exported names before writing PromQL.

## 4. Check privacy and completeness

Verify **absence**, not merely blank UI panels, of:

```text
gen_ai.input.messages
gen_ai.output.messages
gen_ai.system_instructions
gen_ai.tool.definitions
gen_ai.tool.call.arguments
gen_ai.tool.call.result
```

Inspect span events and exception attributes too. Even with content disabled, error strings, skill paths and identifiers can be sensitive. This development backend has no separate enforcement gateway; use only approved low-risk tasks until [the proposed privacy boundary](../enterprise/privacy.md) exists.

Compare an independently counted interaction to expected invocation/chat spans. Wait for metric export and normal shutdown before declaring metrics missing. A trace from the synthetic probe alone does not prove Copilot capture works.

## Optional: isolate client export from networking

The documented file exporter can diagnose whether the CLI emits telemetry at all:

```sh
mkdir -p "$HOME/.local/state/agent-analytics"
chmod 700 "$HOME/.local/state/agent-analytics"
umask 077

env -u OTEL_EXPORTER_OTLP_ENDPOINT \
  COPILOT_OTEL_ENABLED=true \
  COPILOT_OTEL_EXPORTER_TYPE=file \
  COPILOT_OTEL_FILE_EXPORTER_PATH="$HOME/.local/state/agent-analytics/cli-smoke.jsonl" \
  OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=false \
  copilot
```

Treat the file as private telemetry. The format is the CLI's JSON-lines representation, not a guaranteed drop-in OTLP replay file. Inspect it locally; do not commit it or upload it for troubleshooting. Delete the exact file after the diagnosis:

```sh
rm "$HOME/.local/state/agent-analytics/cli-smoke.jsonl"
```

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Nothing reaches the backend | New process environment, runtime version, port forwarding, collector logs |
| HTTP 404 or 405 | Base endpoint vs signal-specific URL; correct HTTP port and path |
| HTTP 400 / decoding failure | HTTP/protobuf vs HTTP/JSON receiver support |
| Trace appears but metrics do not | Export timing, metrics pipeline, rejection logs, discovery of translated names |
| Some tools missing from a conversation view | Missing conversation ID/agent name on those spans; viewer normalization required |
| CLI in a container cannot reach the collector | Its `127.0.0.1` is the container, not your laptop; configure an explicit reachable host |
| “Cost” looks wildly wrong | Check units and parent/child double-counting before drawing conclusions |

Use `OTEL_LOG_LEVEL=INFO` temporarily if needed; avoid verbose diagnostics on sensitive tasks. Remove the extra logging after the check.

## Stop capture

Exit the instrumented process and close that terminal, or clear the settings before starting another one. Merely stopping Tilt is not an opt-out: an existing Copilot process may keep trying to export.

**Next:** [Desktop compatibility](desktop.md) or [useful insights](../insights/catalog.md).
