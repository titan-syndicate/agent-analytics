# Agent Analytics

A reader-first, local-first field guide to observing GitHub Copilot sessions and
turning evidence into better agent tooling, consistent outcomes, and efficient AI spend.

**Read the site:** <https://titan-syndicate.github.io/agent-analytics/>

Start with [recommendations for high-volume users](docs/start/recommendations.md),
then the [30-day pilot](docs/start/pilot.md). The site includes Copilot CLI and
Honeycomb setup, a runnable Tilt/Kubernetes lab, a desktop compatibility
experiment, [local session-file/SQLite analysis](docs/guides/local-session-data.md),
separate capture/viewer proposals, OpenSearch tradeoffs, and an
enterprise improvement loop.

This repository contains the reader and a **local development lab**, not an
enterprise telemetry product. The lab captures native Copilot CLI telemetry in
Grafana LGTM, Phoenix and Langfuse through a shared Collector. The session-file
importer, installable skill, policy gateway and custom viewer remain proposals.
No real session content or credentials
belong here.

**Start with the [cost-investigation demo](https://titan-syndicate.github.io/agent-analytics/insights/demo/).**
It works backward from Copilot spend, using six invented scenarios to show
context churn, verbose output, retries, agent fan-out and resolved model choice.
The goal is finding testable inefficiencies, not assigning engineer scores or
turning tokens into invoice dollars.

## Run the local OTel lab

Prerequisites: Bash 3.2+, jq, curl, OpenSSL, Docker Desktop with Kubernetes enabled, `kubectl`,
Tilt, and an installed/authenticated Copilot CLI. The selected Kubernetes context
must be `docker-desktop`; no script switches it automatically.

The local lab needs **no Python**. Bash handles launch/setup, `curl` makes HTTP
requests, `jq` reads/builds JSON, and OpenSSL generates random local keys. MkDocs
still uses Python to build the documentation site, but that is a separate task.

```sh
bash scripts/lab.sh doctor
bash scripts/viewer-setup.sh
tilt up --host 127.0.0.1 --stream
```

Leave Tilt running. Open **[Grafana](http://127.0.0.1:3000/explore)** for traces
and metrics, **[Phoenix](http://127.0.0.1:6006)** or
**[Langfuse](http://127.0.0.1:3001)** for agent views,
or **[Tilt](http://127.0.0.1:10350)** for deployment health/logs.
Langfuse login credentials are generated in the private, gitignored
`.local-lab/credentials.json`. Read the
[comparison guide](https://titan-syndicate.github.io/agent-analytics/guides/viewer-comparison/)
for deployment resources, mapping details and cleanup.
Anonymous access is limited to Grafana's Viewer role. Keep the cluster trusted:
loopback forwarding does not prevent other cluster workloads reaching the Pod.

## Try the cost-investigation demo first

With Tilt healthy, run:

```sh
bash scripts/demo.sh
cat .local-lab/demo-links.md
```

Open the **[synthetic cost dashboard](http://127.0.0.1:3000/d/agent-cost-demo)**.
The generator creates six invented scenarios and verifies them in all three
backends. **No Copilot calls, credits or private history are involved.** Fresh
per-scenario Phoenix/Langfuse links are in the local link file.

Follow the **[hands-on walkthrough](https://titan-syndicate.github.io/agent-analytics/insights/demo/)**
for what to click and which cost-driver questions each tool can answer.
Start with [the model-call mental model](https://titan-syndicate.github.io/agent-analytics/foundations/model-calls/),
then follow the scenario links to separate
[Grafana](https://titan-syndicate.github.io/agent-analytics/insights/demo-grafana/),
[Phoenix](https://titan-syndicate.github.io/agent-analytics/insights/demo-phoenix/) and
[Langfuse](https://titan-syndicate.github.io/agent-analytics/insights/demo-langfuse/)
walkthroughs. They include first-time navigation, exact rows/values and the limits
of cached-input and input-component analysis.
Then read the [cost objective](https://titan-syndicate.github.io/agent-analytics/insights/cost-objective/),
[agent analysis prompts](https://titan-syndicate.github.io/agent-analytics/insights/agent-analysis/)
and [research digest](https://titan-syndicate.github.io/agent-analytics/reference/cost-research/).

| Bash helper | What it does |
| --- | --- |
| `scripts/lab.sh doctor` | Checks installed tools and selected local cluster |
| `scripts/viewer-setup.sh` | Creates/reuses random local credentials; never commits keys |
| `scripts/lab.sh run` | Configures only the new CLI child's OTel environment |
| `scripts/viewers.sh smoke` / `verify` | Reads matching spans from all three stores |
| `scripts/lab.sh verify-copilot` | Checks native CLI traces and token/tool metrics |
| `scripts/demo.sh` | Generates labeled synthetic traces/metrics and fresh viewer links |

## Capture real CLI metadata

In another terminal:

```sh
bash scripts/lab.sh smoke
bash scripts/lab.sh run -- -p "Reply with exactly: local telemetry ready. Do not use tools."
```

The wrapper starts a new CLI process with local HTTP/protobuf export, content
capture off, and session syncing off. It clears inherited OTel overrides **for
that child only**, preserves authentication, and does not configure desktop
sessions. Enterprise-managed telemetry policy can still override local settings.

**Plain `copilot` is not globally configured by this lab.** Use
`bash scripts/lab.sh run` for a new instrumented interactive session, or
`bash scripts/lab.sh run -- -p "..."` for each one-shot. Existing CLI/app
processes are not retroactively instrumented.

## Generate data and use the viewers

Follow **[Generate CLI data and find it](https://titan-syndicate.github.io/agent-analytics/guides/generate-and-find-data/)**
for a copyable series of six safe one-shots, stored-data verification, and
step-by-step navigation in all three viewers. Start with one pair to limit quota
usage. `bash scripts/viewers.sh smoke` checks all three stores without a model
call, but does not generate native CLI metrics.

Grafana's bundled **JVM Overview** and **RED Metrics** dashboards are not Copilot
dashboards; empty panels there are expected. Use **Explore -> Tempo** for traces
and **Explore -> Prometheus** for metrics. After a short-lived CLI exits, an
Instant query at now can be empty even though historical samples remain.
Use a Range query covering the run, or this historical presence check:

```promql
last_over_time(gen_ai_client_inference_usage_input_tokens_total{service_name="github-copilot-local"}[1h])
```

This is the latest value per series, **not total usage across a batch**. Separate
CLI processes may reset the same series; use model-call spans for small-run
attribution rather than summing cumulative counter samples.

In Phoenix select **copilot-lab**; in Langfuse select **Local lab -> Copilot
comparison**. Use the run's time range and compare trace IDs from the verifier.
Actual prompt/response text is intentionally absent with content capture off.

Use **Explore -> Tempo** and search:

```text
{ resource.service.name = "github-copilot-local" }
```

For a repeatable two-task/tool/metrics check, follow the
[local lab guide](https://titan-syndicate.github.io/agent-analytics/guides/local-lab/).
Read the [verified experiment result](https://titan-syndicate.github.io/agent-analytics/experiments/cli-local-otel/)
and [agent-focused viewer options](https://titan-syndicate.github.io/agent-analytics/proposals/agent-viewers/).
Images are pinned to multi-architecture digests; telemetry storage is
ephemeral and lost on Pod replacement or `tilt down`. This is not a durable
archive, privacy sanitizer, or retention implementation.

Docker Desktop's kind/containerd mode can fail Tilt's image-store check when
its containerd image store is disabled. A kubeadm Docker-runtime cluster avoids
that specific mismatch. See the guide before changing settings or recreating a
cluster; recreation can delete unrelated workloads.

To stop the viewer/forwards, press Ctrl+C in the Tilt terminal. To remove this
lab's resources and telemetry, review the dedicated namespace, then run
`tilt down` from this repository. Never run it against a namespace you did not
intend this lab to own.

## Check the lab code

```sh
bash tests/test_lab.sh
```

## Preview and build

Use Python 3.10 or newer (CI uses 3.12):

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-docs.txt
.venv/bin/python -m mkdocs serve
```

For a production build with link and navigation validation:

```sh
.venv/bin/python -m mkdocs build --strict
```

[Publish documentation](.github/workflows/docs.yml) builds on relevant changes
to `main` and supports manual dispatch. Pull requests build without deploying.
Pages uses GitHub Actions as its publishing source; see
[site maintenance](docs/reference/site.md).
