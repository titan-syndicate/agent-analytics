# Experiment: Copilot CLI -> local OTel -> Grafana

**Result: passed on October 4, 2026.** We deployed this repository's Tilt lab, ran two synthetic Copilot CLI one-shots, and read their traces and metrics back from local storage. The viewer is **[Grafana Explore on this machine](http://127.0.0.1:3000/explore)** while Tilt is running.

**October 5 update:** The original helpers were Python; the current commands below refer to their Bash replacements. The replacement launcher and storage checks were exercised with the same two safe CLI tasks. Reasoning/output and cache/input categories were normalized during read-back. See [the synthetic cost-driver demo](../insights/demo.md) for a guided viewer tour without paid model calls.
The link is a loopback address, not an internet-hosted viewer. Other readers must start their own lab. GitHub Pages publishes this sanitized experiment report, **not telemetry or session content**.

## Tested configuration

| Component | Observed configuration |
| --- | --- |
| Host | macOS, local Docker Desktop |
| CLI | GitHub Copilot CLI 1.0.91 |
| Tilt | 0.37.8 |
| Docker engine | 29.8.1 |
| Kubernetes | Docker Desktop kubeadm, v1.32.2, Docker runtime |
| Backend | `grafana/otel-lgtm:0.35.0`, pinned multi-architecture index digest |
| Namespace | `agent-analytics-lab` |
| Host endpoints | Grafana `127.0.0.1:3000`, OTLP HTTP `127.0.0.1:4318`, Tilt `127.0.0.1:10350` |
| Client export | OTLP HTTP/protobuf, service `github-copilot-local` |
| Content | Disabled for the launched CLI processes |
| Session syncing | Disabled with `--no-remote-export` for those new sessions |
| Storage | Pod-local `emptyDir`, no source/home mounts |
| Viewer access | Anonymous Viewer role; loopback host forwards |

The image index digest is:

```text
sha256:2de1094c593c671cbfca878a28ffcd7e46ff5e32f2ce966c0cf33003f6cf4266
```

Viewer access to Explore additionally requires the pinned version's `viewers_can_edit` setting. The plain Viewer role initially redirected away from Explore even though datasource queries worked. The manifest enables transient browser editing without granting dashboard saving or Admin access.

After that configuration change replaced the ephemeral Pod, we repeated the same two tasks to leave fresh traces in the final viewer. The counts below describe a verified two-task run, not the sum of all repetitions.

## What we ran

First, `scripts/lab.sh smoke` submitted a fresh synthetic trace to the receiver and read the stored span back from Tempo through Grafana. This checked storage visibility, not just an HTTP success.

Then we ran two non-sensitive one-shots in an otherwise empty scratch directory:

| Task | Permissions/context | Observed result |
| --- | --- | --- |
| Reply with `local telemetry ready` and do not use tools | Custom instructions/built-in MCPs disabled; shell and write permissions denied | Expected text response; no source changes |
| Run `printf 'otel-tool-check\n'` once and return its output | Only the bash tool available; explicit `shell(printf)` permission | One shell tool call and expected text response; no source changes |

The tasks use the user's existing CLI authentication and model configuration. The resolved model in the retrieved chat spans was `claude-sonnet-5`. That is an observation of this experiment, not a recommendation or fixed model requirement.

The [lab guide](../guides/local-lab.md#repeat-the-two-task-experiment) contains repeatable commands. These consume Copilot credits/quota and can resolve to different models on another machine.

## Evidence read back from the backend

`scripts/lab.sh verify-copilot` searched the experiment's time window and service, then retrieved the complete matching traces and metric samples:

| Check | Observation |
| --- | --- |
| Synthetic receiver -> storage round trip | Passed |
| Copilot traces | 2 |
| Root `invoke_agent` operations | 2 |
| `chat` operations | 3 across the two tasks |
| `execute_tool` operations | 1 |
| Model-call/token metrics | Stored in Prometheus |
| Tool count/duration metrics | Stored in Prometheus |
| Streaming timing metrics | Present in the queried metric families |
| Known GenAI content keys | Absent in retrieved traces, including recursively inspected resources/events |
| Public disclosure | Only synthetic task descriptions, versions, counts and field-family observations |

Three model calls for two user prompts illustrate why **user messages are not the same as inference calls**. A tool-bearing task can require another inference step after the tool returns.

Verified Prometheus families included:

```text
gen_ai_client_inference_usage_input_tokens_total
gen_ai_client_inference_usage_output_tokens_total
gen_ai_client_inference_usage_cache_read_input_tokens_total
gen_ai_client_inference_usage_cache_write_input_tokens_total
gen_ai_client_operation_duration_seconds_*
gen_ai_client_operation_time_to_first_chunk_seconds_*
gen_ai_invoke_agent_duration_seconds_*
gen_ai_execute_tool_duration_seconds_*
github_copilot_tool_call_count_total
github_copilot_tool_call_duration_seconds_*
```

These are the names observed for CLI 1.0.91 and this backend's translation. They are not assumed universal names, and their existence does not certify the accuracy of a financial-cost model.

## Compatibility issue encountered

The initial Docker Desktop kind/containerd cluster was healthy to `kubectl`, but Tilt rejected it because Docker's containerd image store was disabled. The user recreated the cluster using kubeadm; the new cluster reported `docker://29.8.1`, and the same native Tilt deployment then worked.

We did not reset the cluster or edit Docker settings automatically. The [setup guide](../guides/local-lab.md#docker-desktop-compatibility) documents this distinction and the destructive consequences of cluster recreation.

An initial attempt to use `--deny-tool='*'` was rejected by the CLI's permission-rule parser before the task ran. The working task uses explicit `shell` and `write` denials instead. This is why the guide records the exercised flags rather than assuming wildcard semantics.

A verification attempt immediately after the repeated tasks received HTTP 400 from a backend query. During the later multi-viewer experiment, the diagnostic identified a collapsed Tempo search interval (`start == end`). The helper now searches with a 60-second lower-bound cushion and filters results by the original trace start timestamp, preserving the requested experiment window. It also prints backend error bodies rather than hiding the diagnostic. Failed verification is never treated as success.

## What this proves

The local Kubernetes/Tilt/backend path works for native Copilot CLI metadata export on the recorded versions. We can inspect model/tool spans and query numeric metrics without enabling content capture or adding a Honeycomb key.

The small helper covers prerequisite reporting, synthetic storage read-back, child CLI configuration and time-bounded evidence checks. Its unit tests exercise environment isolation, current/legacy Tempo shapes, known-content detection, metric timestamps, explicit failures and session-sync restrictions.

## What it does not prove

This was a capture smoke test, not a benchmark or an efficiency study. It does not establish task quality, enterprise ROI, sustained ingest capacity, complete privacy enforcement, durable storage or retention expiration.

The privacy check looks for named GenAI content fields, not every potentially sensitive string. No real repository tasks were needed; a production privacy boundary still requires a reviewed allowlist.

This initial run did **not** test desktop environment inheritance, import `~/.copilot` history, ingest into Honeycomb/OpenSearch, or claim that every client exports OTLP logs. Phoenix/Langfuse were subsequently deployed and [verified together in a follow-up](../guides/viewer-comparison.md#verified-october-4-2026). The [desktop experiment](../guides/desktop.md) remains a separate test requiring a fresh app/runtime launch.

## What to try next

Use a few approved, test-backed tasks and label accepted/rejected outcomes. Then examine tool reliability and interaction shape before making an optimization recommendation.

For an agent-oriented UI, [Phoenix is the first lightweight local candidate](../proposals/agent-viewers.md); verify Copilot attribute mapping with the same safe fixtures before deploying it as the default. Keep Grafana/Prometheus for operational numeric metrics.
