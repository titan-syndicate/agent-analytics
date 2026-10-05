# Run the Tilt + Docker Kubernetes local lab

**The repository now includes a working local lab.** Tilt deploys a pinned Grafana LGTM image into the dedicated `agent-analytics-lab` namespace and forwards its viewer and OTLP receiver to loopback. The [October 4 CLI experiment](../experiments/cli-local-otel.md) verified synthetic ingestion, real Copilot traces, tool spans and metrics.

The project now also deploys [Phoenix and Langfuse](viewer-comparison.md), with a shared Collector forwarding the same traces to all three backends. Initialize private viewer credentials before startup. The original experiment below describes the initial LGTM-only run.

!!! warning "Local development only"
    Storage is ephemeral, the cluster must be trusted, and this is not a privacy enforcement gateway. Use synthetic or approved low-risk tasks with content capture off. There is no durable archive or automatic seven-day retention guarantee.

## What runs?

```text
New Copilot CLI process via scripts/lab.sh run
    -> HTTP/protobuf at 127.0.0.1:4318
    -> Tilt port forward -> shared OTel Collector
    -> Tempo (raw traces), Phoenix + Langfuse (enriched traces)
    -> LGTM Prometheus (metrics), Loki (logs if emitted)

Browser -> 127.0.0.1:3000/explore -> Grafana
Browser -> 127.0.0.1:10350        -> Tilt health/logs
```

Source of truth: [Tiltfile](https://github.com/titan-syndicate/agent-analytics/blob/main/Tiltfile), [Kubernetes manifest](https://github.com/titan-syndicate/agent-analytics/blob/main/local/lgtm.yaml), and [lab helper](https://github.com/titan-syndicate/agent-analytics/blob/main/scripts/lab.sh).

The LGTM multi-architecture image is pinned to `0.35.0` and its immutable index digest. Its Pod has a 4 GiB memory limit, a 5 GiB `/data` volume cap and a separate 1 GiB `/loki` volume cap. Phoenix, Langfuse and the shared Collector add their own resources; see the [comparison topology](viewer-comparison.md). These are lab limits, not measured enterprise capacity or a precise disk-retention policy.

## Prerequisites

Install Bash 3.2+, jq, curl, OpenSSL, Docker Desktop, `kubectl`, Tilt, and an authenticated Copilot CLI. Enable Docker Desktop Kubernetes. Work from a checkout of this repository:

```sh
git clone https://github.com/titan-syndicate/agent-analytics.git
cd agent-analytics
bash scripts/lab.sh doctor
```

The selected context must be `docker-desktop`. Neither Tiltfile nor the helper switches context for you. Check that ports **3000, 3001, 4318, 6006, 9090 and 10350** are free and that the lab namespace is absent or belongs to this lab; do not adopt another person's deployment.

On macOS, a useful port check is:

```sh
lsof -nP -iTCP:3000 -iTCP:3001 -iTCP:4318 -iTCP:6006 -iTCP:9090 -iTCP:10350 -sTCP:LISTEN
```

The helper reports versions, Docker connectivity and node status. It does not install dependencies, configure authentication, or claim that the image-store compatibility check has passed; Tilt checks that at startup. Bash helpers use `jq` for JSON, `curl` for HTTP, and OpenSSL for random credentials/IDs. **Python is not required to run the lab.** Building the MkDocs site still uses Python, separately.

### Docker Desktop compatibility

The initial Docker Desktop **kind/containerd** cluster failed Tilt's check because Docker's containerd image store was disabled. Tilt reported:

```text
Your Docker Desktop Kubernetes cluster uses containerd,
but the containerd image snapshotter is disabled.
```

For that mode, follow Docker Desktop's image-store guidance before recreating the cluster. Alternatively, the **kubeadm cluster with Docker runtime** used in our experiment worked without that mismatch. Verify actual runtime/settings instead of relying solely on the cluster's name:

```sh
kubectl --context docker-desktop get nodes -o wide
docker info --format '{{json .DriverStatus}}'
```

**Recreating a cluster can remove unrelated workloads.** The lab never resets Docker Desktop or switches cluster provisioning mode automatically. Keep Docker Desktop licensing/procurement requirements in mind for enterprise distribution.

## Start Tilt

From the repository root:

```sh
bash scripts/viewer-setup.sh
tilt up --host 127.0.0.1 --stream
```

Leave that terminal running. The first image pull can take several minutes. Wait for the `lgtm` deployment to be ready in [Tilt](http://127.0.0.1:10350), or:

```sh
kubectl --context docker-desktop -n agent-analytics-lab \
  rollout status deployment/lgtm --timeout=300s
```

Open **[Grafana Explore](http://127.0.0.1:3000/explore)**. The manifest enables anonymous access with the **Viewer** role rather than the upstream image's anonymous Admin default. No login is needed for these read-only lab checks. Do not expose the development instance publicly or use its default admin credentials for shared deployment.

The pinned Grafana version also needs `GF_USERS_VIEWERS_CAN_EDIT=true` to let Viewers use Explore. This permits transient browser edits, not saving dashboards or administering the instance. The setting is deprecated upstream, so recheck Explore authorization when upgrading; successful datasource API queries alone do not prove the web UI is usable.

Loopback forwarding protects host access; other workloads in the Kubernetes cluster may still reach the Pod's receiver/UI. This setup is appropriate only for a trusted local cluster.

## Verify storage, not just HTTP acceptance

In a second terminal:

```sh
bash scripts/lab.sh smoke
```

The Bash helper creates a fresh synthetic three-span trace, posts OTLP HTTP/JSON, checks partial-success errors, and reads it back from all three viewers. `lab.sh smoke` delegates to `viewers.sh smoke`. It prints a trace ID and exits nonzero on failure. This replaces the original Python single-span probe.

This probes local HTTP/JSON receiver compatibility. The CLI checks below exercise the actual **HTTP/protobuf exporter**. Synthetic success alone does not prove Copilot capture.

## Run a CLI task

```sh
bash scripts/lab.sh run -- \
  -p "Reply with exactly: local telemetry ready. Do not use tools."
```

The wrapper verifies Grafana health, clears inherited `OTEL_*` / `COPILOT_OTEL_*` settings for the child process, then sets local HTTP/protobuf, `github-copilot-local`, and content capture off. It preserves your authentication and normal non-OTel settings, passes through CLI arguments, and uses `--no-remote-export` to disable session syncing for the new process.

It does not edit your shell profile, change a running desktop process, disable enterprise policy, or prevent ordinary Copilot model requests from reaching GitHub/providers. “Local-only” refers to **this analytics destination**, not offline model inference or the removal of existing saved session history.

### Repeat the two-task experiment

Use a non-sensitive scratch directory to avoid unrelated repository instructions/context. Replace `/absolute/path/to/agent-analytics` below with your checkout path:

```sh
lab_repo=/absolute/path/to/agent-analytics
scratch=$(mktemp -d)
cd "$scratch"
since=$(date +%s)

bash "$lab_repo/scripts/lab.sh" run -- \
  --no-custom-instructions --disable-builtin-mcps \
  --deny-tool=shell --deny-tool=write \
  -p "Reply with exactly: local telemetry ready. Do not use tools."

bash "$lab_repo/scripts/lab.sh" run -- \
  --no-custom-instructions --disable-builtin-mcps \
  --available-tools=bash --allow-tool='shell(printf)' \
  -p "Use the bash tool exactly once to run printf 'otel-tool-check\n', then reply with exactly that output. Do not read or write files, run other commands, or call other tools."

bash "$lab_repo/scripts/lab.sh" verify-copilot \
  --since "$since" --expected-traces 2

cd "$lab_repo"
rmdir "$scratch"
```

One-shots consume your Copilot quota/credits. They use the configured model/routing, so models and token totals can differ. The shell task is limited to the `printf` permission, not broad auto-approval. These flags were exercised on CLI **1.0.91**; check your version's help if flags differ.

The verifier requires recent service-matched traces containing invocation, model and tool operations, checks known content keys recursively, and waits for recent Copilot metric samples in Prometheus. It reports observed counts/names rather than assuming a fixed number of model calls. Isolate other instrumented tasks during the check: concurrent tasks with the same service can also match.

The helper checks a defined set of GenAI content keys, **not all potentially sensitive metadata**. Errors, paths or new vendor fields still require inspection and the proposed privacy allowlist.

## Use the web viewer

The lab now provisions an **[Agent cost investigation - SYNTHETIC DEMO](http://127.0.0.1:3000/d/agent-cost-demo)** dashboard. Populate it with `bash scripts/demo.sh` and follow [the scenario walkthrough](../insights/demo.md). It uses invented `agent_demo_*` metrics, not live CLI billing totals. Native CLI metrics still belong in Explore.

**Seeing little data on JVM/RED dashboards?** Those bundled dashboards do not target Copilot metrics. See [Generate CLI data and find it](generate-and-find-data.md#grafana-why-the-bundled-dashboards-are-empty) for suitable queries, short-lived metric lookback, a six-one-shot series, and Phoenix/Langfuse navigation. Starting Tilt does not globally configure plain `copilot`; launch each captured process through the wrapper.

### Traces

In Grafana **Explore -> Tempo**, use TraceQL:

```text
{ resource.service.name = "github-copilot-local" }
```

Choose a recent time range, open an interaction, and inspect `invoke_agent`, `chat` and `execute_tool` spans. Find model/token attributes on model calls; keep parent totals separate from child totals.

### Metrics

In **Explore -> Prometheus**, examples verified with the pinned backend and CLI 1.0.91 include:

```promql
gen_ai_client_inference_usage_input_tokens_total{service_name="github-copilot-local"}
```

```promql
github_copilot_tool_call_count_total{service_name="github-copilot-local"}
```

```promql
gen_ai_client_operation_duration_seconds_count{service_name="github-copilot-local"}
```

These are translated Prometheus names. Discover current labels and dimensions before aggregating; a counter reset or parent/child overlap can invalidate a naive total. Exact names differ across runtime/backends.

Use **Range** query mode covering the run for exited CLI processes. A bare Instant query can be empty after the normal lookback expires; `last_over_time(...[1h])` can confirm historical samples. It is not a total across separate CLI processes; see the [one-shot metrics caveats](generate-and-find-data.md#find-metrics-from-exited-one-shots).

Grafana is a generic diagnostic viewer. For agent-specific viewing, open [Phoenix and Langfuse](viewer-comparison.md), now deployed alongside it. The [viewer comparison](../proposals/agent-viewers.md) describes their tradeoffs.

## Stop and remove

Press Ctrl+C in the Tilt terminal to stop Tilt and its port forwards. Kubernetes resources continue running. To remove the lab and its ephemeral data, first verify its ownership:

```sh
kubectl --context docker-desktop -n agent-analytics-lab get all
```

Then, from this repository:

```sh
tilt down
```

This includes deleting the dedicated namespace, so do not place unrelated resources in it. `emptyDir` survives a container restart within the same Pod but is lost when the Pod is replaced/deleted. Deployment edits or cluster resets can erase the experiment's traces.

Stopping the backend does not change a running CLI's telemetry settings. Exit that process too. Deleting lab data does not remove CLI session history or previously synced sessions.

## Troubleshooting

| Problem | Check |
| --- | --- |
| Tilt containerd snapshotter error | Docker Desktop provisioner/runtime and image store; see above |
| Wrong context | Select the intended local context yourself; the lab intentionally refuses others |
| Port already in use | Identify the exact owning process; do not kill unrelated services |
| Pod never ready | Tilt logs/events, image pull, memory pressure, `/tmp/ready` probe |
| Synthetic check fails | Grafana/Tempo health, receiver/export failures, port forwards |
| CLI runs but no traces | Runtime help, managed settings, child export settings, process logs |
| Traces present but metrics missing | Wait for exporter flush; inspect metrics pipeline and actual metric names |
| Viewer has empty content panels | Expected with content capture off; not a reason to enable real-code capture |

## Local checks

```sh
bash tests/test_lab.sh
```

CI runs the helper's unit tests without starting Kubernetes or invoking a paid model. The [experiment record](../experiments/cli-local-otel.md) covers the manual end-to-end run.
