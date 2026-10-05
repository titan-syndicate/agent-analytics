# Compare Phoenix, Langfuse and Grafana locally

The Tilt project deploys **all three viewers** on Docker Desktop Kubernetes. A shared OTel Collector receives CLI telemetry at the unchanged `http://127.0.0.1:4318` address. Run a task once and compare its trace ID in all three backends.

| Viewer | Local URL | Role |
| --- | --- | --- |
| Phoenix | <http://127.0.0.1:6006> | Agent/model/tool trace exploration, sessions and evaluation |
| Langfuse | <http://127.0.0.1:3001> | Observations, sessions, scoring and experiments |
| Grafana | <http://127.0.0.1:3000/explore> | Raw traces plus Prometheus metrics |
| Tilt | <http://127.0.0.1:10350> | Deployment health and logs |

## Setup

Use the [local lab prerequisites](local-lab.md). Allow substantially more memory and disk than for LGTM alone: Langfuse adds PostgreSQL, Redis, ClickHouse, MinIO, web and worker containers. This is a single-machine evaluation topology, not a production Helm deployment. Our Docker Desktop VM has approximately 20 GiB RAM.

Before starting Tilt:

```sh
bash scripts/lab.sh doctor
bash scripts/viewer-setup.sh
tilt up --host 127.0.0.1 --stream
```

The setup script generates random passwords/project keys, creates a dedicated Kubernetes Secret, and saves a **private, gitignored** `.local-lab/credentials.json` with mode `0600`. Re-running it reuses the existing Secret. It never changes cluster context or resets Docker Desktop. Check namespace ownership before starting.

Local scripts are Bash plus `jq`, `curl` and OpenSSL. The credentials file is JSON, not executable shell configuration. We kept it in JSON so helpers never `source` secrets as code.

Langfuse initializes organization `local-lab`, project `copilot`, and user `local@example.invalid`. Find `LANGFUSE_INIT_USER_PASSWORD` in the private credentials file to sign in. Never paste the file into chat, commit it, or publish it. Phoenix and Grafana allow anonymous local access. Only the web UIs, shared receiver and MinIO media endpoint are forwarded to loopback; databases have no host forwards.

First pulls/migrations can take several minutes. The Collector is deployed after the three backends become ready, so do not launch instrumented tasks while Tilt still shows startup errors.

## Same traces, explicit mappings

```text
Copilot CLI -> shared Collector :4318
    -> original traces -> Tempo / Grafana
    -> enriched copies -> Phoenix AND Langfuse
    -> metrics/logs -> LGTM only
```

The Collector preserves trace/span IDs, timestamps, parent relationships and original attributes. Its viewer branch adds:

| Copilot field | Added viewer field |
| --- | --- |
| `invoke_agent` operation | OpenInference `AGENT`, Langfuse `agent` |
| `chat` operation | OpenInference `LLM`, Langfuse `generation` |
| `execute_tool` operation | OpenInference `TOOL`, Langfuse `tool` |
| Conversation ID, when present on that span | `session.id` and `langfuse.session.id` |
| Chat model and input/output tokens, when present | OpenInference model/token fields |

Token mappings apply to **chat spans only**; root usage is not copied into model totals. Missing conversation IDs remain missing: this mapping does not invent a session ID or perform cross-batch ancestor propagation. Check child/session completeness before trusting session aggregates. Cache and vendor-specific usage semantics remain a separate compatibility question.

The Phoenix project is `copilot-lab`; the Langfuse project is `Copilot comparison`. Content capture stays disabled in `scripts/lab.sh run`. Actual prompt/response text is not expected. Phoenix can synthesize an output envelope containing only the source response ID/model; that is metadata, not captured message content.

Each exporter has its own retry queue. This is not an atomic three-database transaction or durable delivery guarantee; inspect Collector logs if a viewer is unavailable. Previously stored Grafana data is not automatically backfilled into new viewers.

## Run the comparison

For a guided tour with invented cost-driver cases and a dedicated Grafana dashboard, [run the synthetic demo](../insights/demo.md). It does not consume Copilot quota.

For CLI launch configuration, a series of one-shots, viewer navigation and blank Grafana dashboard diagnosis, follow **[Generate CLI data and find it](generate-and-find-data.md)**.

First verify a fresh three-span synthetic trace in **all three stores**, including matching span IDs, operation kinds and parent relationships:

```sh
bash scripts/viewers.sh smoke
```

Start with the [two safe CLI tasks](local-lab.md#repeat-the-two-task-experiment). Record the trace IDs from the verifier, inspect the same IDs in each viewer, and compare:

1. Agent/model/tool kinds and parent relationships.
2. Model and token fields, including cache accounting and missing data.
3. Conversation grouping across traces and subagents.
4. Time to diagnose a tool failure/retry loop.
5. Outcome annotations, evaluations and experiment comparison.

To automate identity/kind/parent checks for a CLI trace:

```sh
bash scripts/viewers.sh verify --trace-id <trace-id-from-lab-verifier>
```

These helpers do storage read-back, not just endpoint health checks. They also compare models, present session IDs, timestamps within about one millisecond, and input/output tokens. Langfuse splits input into uncached/cache-read/cache-write categories and can split reasoning out of output; the verifier recombines those categories to compare with Copilot's inclusive counts. They do not certify financial accounting, every future conversion, session completeness, or evaluation quality.

## Verified October 4, 2026

With Phoenix **20.19.0**, Langfuse **4.50.0** and Collector **0.153.0**, a fresh synthetic three-span trace reached all three stores with matching identity, hierarchy and kinds. Two CLI 1.0.91 tasks then produced **two traces and six spans** in each store: two agents, three model calls and one tool call.

Read-back checks passed for IDs, parents, operation types, model names, session IDs where emitted, timestamps and cache-normalized input/output usage. Prometheus still received CLI token and tool metrics. Generated-user Langfuse login also passed. These are the same safe tasks used in the [initial experiment](../experiments/cli-local-otel.md), not real codebase tasks or an efficiency benchmark.

We corrected Phoenix's explicit Kubernetes port setting/project header, Langfuse's `HOSTNAME=0.0.0.0` for port forwarding, and a too-short Tempo search interval before the final checks. Collector configuration changes trigger a rollout so a changed mapping/header is actually loaded. This lab still makes no guarantee of session completeness for untested runtimes or sustained high-volume ingest.

There are three local copies of structural traces. Do not enable content on real repository tasks just to make the viewers look richer. This lab has no reviewed privacy gateway.

## Storage and cleanup

All backend storage is Kubernetes `emptyDir`, including Langfuse's databases/object store and Phoenix SQLite. A Pod replacement loses that backend's data; `tilt down` removes the lab namespace and its Secret. Ctrl+C stops port forwards but does not remove Pods.

After teardown, `.local-lab/credentials.json` remains on disk. Remove that exact file when no longer needed; re-run setup before the next lab start to recreate credentials. Do not rotate a Secret in place while Langfuse's databases survive: initialized keys/passwords would no longer match.

The manifests pin all container image digests. The Langfuse services share a Pod and use localhost for their dependencies; MinIO uses internal port 9002 to avoid ClickHouse's port 9000. This intentionally favors a disposable evaluation lab over independently scalable services.
