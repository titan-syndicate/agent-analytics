# Generate CLI data and find it in the viewers

**Use the wrapper for every CLI process you want to capture.** Starting Tilt deploys the receivers/viewers; it does not change your shell profile, globally configure `copilot`, or instrument an already-running session.

The existing lab has verified CLI traces in all three viewers. A blank bundled Grafana dashboard is not proof of missing telemetry: those dashboards target different workloads, and one-shot metric series stop emitting when their processes exit.

## Is my CLI configured?

| Launch method | Local lab routing |
| --- | --- |
| `python3 scripts/lab.py run -- -p "..."` | Configured for this new process |
| `python3 scripts/lab.py run` | Configured for this new interactive process |
| Plain `copilot` in an unrelated terminal | Not configured by this repository; depends on that terminal's environment/managed settings |
| A process started before configuration | Not retroactively configured |
| Copilot desktop | Not configured by the CLI wrapper; separate experiment |

From the repository root, use:

```sh
python3 scripts/lab.py run
```

For an instrumented interactive session, run this from the directory of your approved task, using the absolute path to `scripts/lab.py`. That directory supplies the CLI's normal working context. Unlike the controlled smoke tasks below, ordinary sessions can load repository instructions and use your usual tools.

The wrapper sets `COPILOT_OTEL_ENABLED=true`, HTTP/protobuf export to `http://127.0.0.1:4318`, service `github-copilot-local`, and message-content capture off. It disables session syncing for the child, clears conflicting inherited OTel settings, and preserves authentication. It does **not** make model inference offline or bypass enterprise-managed policy.

No global CLI configuration was installed during our experiment. To capture future work consistently, keep using the wrapper; for manual environment configuration see the [CLI guide](copilot-cli.md#2-set-a-deliberate-local-environment).

## Check the path before paying for model calls

If the lab is not already running, initialize it in a checkout:

```sh
python3 scripts/lab.py doctor
python3 scripts/viewer_setup.py
tilt up --host 127.0.0.1 --stream
```

Leave that terminal open. Wait for `lgtm`, `phoenix`, `langfuse` and `collector` to be healthy in [Tilt](http://127.0.0.1:10350). Then, in a second terminal at the repository root:

```sh
python3 scripts/viewers.py smoke
```

This injects a synthetic agent/model/tool trace and reads it from all three stores. It uses **no model call or Copilot quota** and prints the shared trace ID. It does not produce real CLI token/tool metrics; those need actual instrumented CLI tasks.

## Run a series of six one-shots

The following runs three pairs of tasks sequentially: a model-only reply and a narrowly permitted `printf` tool call. It uses an empty scratch directory, disables custom instructions/built-in MCPs, and does not edit source files. Run it from the repository root in Bash or Zsh.

**This consumes Copilot credits/quota.** Start with `pairs=1` for two calls; use `pairs=3` for six. Exact model calls, tokens and credit totals depend on routing. Do not launch a large batch just to fill charts.

```sh
(
  set -eu
  lab_repo="$PWD"
  pairs=3
  python3 "$lab_repo/scripts/viewers.py" smoke
  scratch=$(mktemp -d)
  trap 'cd "$lab_repo"; rmdir "$scratch"' EXIT
  cd "$scratch"
  since=$(date +%s)

  i=1
  while [ "$i" -le "$pairs" ]; do
    printf '\nPair %s of %s: model-only task\n' "$i" "$pairs"
    python3 "$lab_repo/scripts/lab.py" run -- \
      --no-custom-instructions --disable-builtin-mcps \
      --deny-tool=shell --deny-tool=write \
      -p "Reply with exactly: local telemetry ready. Do not use tools."

    printf '\nPair %s of %s: tool task\n' "$i" "$pairs"
    python3 "$lab_repo/scripts/lab.py" run -- \
      --no-custom-instructions --disable-builtin-mcps \
      --available-tools=bash --allow-tool='shell(printf)' \
      -p "Use the bash tool exactly once to run printf 'otel-tool-check\n', then reply with exactly that output. Do not read or write files, run other commands, or call other tools."
    i=$((i + 1))
  done

  python3 "$lab_repo/scripts/lab.py" verify-copilot \
    --since "$since" --expected-traces "$((pairs * 2))" \
    > "$lab_repo/.local-lab/batch-result.json"
  cat "$lab_repo/.local-lab/batch-result.json"

  cd "$lab_repo"
  python3 - <<'PY'
import json
import subprocess

with open(".local-lab/batch-result.json") as source:
    result = json.load(source)
for trace_id in result["trace_ids"]:
    subprocess.run(
        ["python3", "scripts/viewers.py", "verify", "--trace-id", trace_id],
        check=True,
    )
PY
)
```

The subshell stops on a failed task/check without changing your parent shell's directory/settings. Cleanup removes only the empty scratch directory; if it is unexpectedly nonempty, `rmdir` refuses deletion. The private, gitignored result file remains for local investigation.

The verifier requires at least six matching traces for three pairs, invocation/model/tool operations, and recent token/tool metric families. It checks known content keys, then the second helper checks every matched trace in Phoenix/Langfuse against Tempo. Stop other instrumented runs with the same service while testing: the time-window query can include concurrent sessions.

Expect roughly six root interactions and three tool operations if the model follows the tasks, but **not a fixed six model calls**: tool tasks usually need another inference after the tool returns. Read the observed counts, not an assumed total. CLI 1.0.91 exercised these permissions; consult your version's help if it rejects them.

## Grafana: why the bundled dashboards are empty

LGTM includes **JVM Overview (OpenTelemetry)** and **RED Metrics** dashboards. Copilot CLI is not a JVM service and does not emit the JVM heap/thread metrics those panels query. The bundled RED dashboards also expect different request metric families. This repository currently provisions **no Copilot-specific dashboard**.

Use [Grafana Explore](http://127.0.0.1:3000/explore) instead. TraceQL and PromQL are different languages for different data sources:

| Goal | Data source | Query mode |
| --- | --- | --- |
| Find a CLI interaction | Tempo | TraceQL |
| See numeric token/tool samples | Prometheus | PromQL, Code mode |

### Find a trace

Select **Tempo**, choose **Last 1 hour** (or a range containing your run), and enter:

```text
{ resource.service.name = "github-copilot-local" }
```

Run the query, open a trace, and inspect `invoke_agent`, `chat` and `execute_tool` spans. Expand a `chat` span to find model/input/output/cache attributes. Alternatively, use Tempo's Trace ID query mode with a `trace_ids` value from `.local-lab/batch-result.json`.

The synthetic viewer check uses service `agent-viewer-smoke`, so it intentionally does **not** match this CLI service filter. Its printed trace ID can still be opened directly.

### Find metrics from exited one-shots

Select **Prometheus**, switch to **Code**, choose **Last 1 hour**, and use a **Range** query to see samples at the times the CLI ran:

```promql
gen_ai_client_inference_usage_input_tokens_total{service_name="github-copilot-local"}
```

A bare **Instant** query evaluates at “now.” Prometheus normally only looks back about five minutes for an instant vector. After a one-shot exits, it stops emitting, so a query at now can be empty while the historical samples and traces remain stored. Changing the dashboard's displayed time range does not itself turn an Instant query into a Range query.

For a quick historical presence check in **Instant** mode, use an explicit lookback:

```promql
last_over_time(gen_ai_client_inference_usage_input_tokens_total{service_name="github-copilot-local"}[1h])
```

```promql
last_over_time(github_copilot_tool_call_count_total{service_name="github-copilot-local"}[1h])
```

```promql
last_over_time(gen_ai_client_operation_duration_seconds_count{service_name="github-copilot-local"}[1h])
```

These queries were exercised against the running lab. Replace `[1h]` with an appropriate supported lookback for your run. No result means no matching samples in that window, not zero usage.

**Do not treat these counters as a batch cost total.** In this lab, separate short-lived CLI processes can produce identical Prometheus label sets, with counter resets/overlapping lifetimes. `last_over_time` returns the last value **per series**, not the sum of every process. `sum_over_time` over counters would instead add repeated cumulative samples and overcount. `rate`/`increase` can be absent or misleading with sparse one-shot exports. Use individual `chat` span usage to compare these small runs; design explicit non-overlapping attribution before doing spend accounting.

## Phoenix: open the agent trace

Open [Phoenix](http://127.0.0.1:6006), select project **`copilot-lab`**, and open its traces/spans view. Clear unrelated filters and choose a time range containing your run. The **`default`** project is not the destination for new lab exports.

Find the trace using the ID from the verifier (trace-ID filtering/search where offered), or open a recent trace and compare its ID/details. Inspect the `AGENT` root, `LLM` model calls and `TOOL` steps. Model-call attributes include `llm.model_name`, `llm.token_count.prompt` and `llm.token_count.completion`. Session grouping uses the mapped conversation ID when the source span has one.

Input/output text is intentionally absent with content off. Phoenix may display a response envelope containing only response ID/model. Empty content panels do not justify enabling capture on private code.

## Langfuse: open the same trace

Open [Langfuse](http://127.0.0.1:3001), sign in as `local@example.invalid` using `LANGFUSE_INIT_USER_PASSWORD` from `.local-lab/credentials.json`, and select **Local lab -> Copilot comparison**.

Open the trace/observations view, clear unrelated filters and select the run's time range. Open the recent interaction and compare its trace ID with the verifier/Phoenix. Inspect `AGENT`, `GENERATION` and `TOOL` observations. The sessions view groups observations with a mapped session ID; missing source session attributes are not invented.

Langfuse can split input tokens into uncached, cache-read and cache-write categories, whereas Phoenix shows inclusive prompt tokens. Compare the sum of those Langfuse input categories with the source, not just its uncached `input` field. Displayed price estimates are not Copilot billing/AI Credits.

## Diagnose missing data in order

| Symptom | Next check |
| --- | --- |
| JVM/RED dashboard empty | Use Tempo/Prometheus Explore with the queries above |
| Traces exist, Instant metric query empty | Historical Range query or explicit `last_over_time` |
| No new CLI traces | Launch through `scripts/lab.py run`, wait for normal completion, check time/service filters |
| Synthetic check passes but no CLI metrics | Synthetic spans do not generate native CLI metrics; run the safe pair |
| Only one viewer empty | Correct project/time filters, shared trace ID, Collector exporter logs |
| Langfuse login fails | Current generated credentials/Secret and initialized database must match |
| Everything vanished | Pod replacement or `tilt down` erased ephemeral data |

For local diagnosis:

```sh
kubectl --context docker-desktop -n agent-analytics-lab get pods
kubectl --context docker-desktop -n agent-analytics-lab logs deployment/collector --tail=50
```

Keep logs/IDs private; error messages may contain sensitive metadata on real tasks. See the [comparison setup](viewer-comparison.md) for storage/deletion limits and the [insights catalog](../insights/catalog.md) for what this evidence can and cannot tell you.
