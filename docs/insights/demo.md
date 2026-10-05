# A hands-on tour: where could Copilot usage go?

**This is a learning demo, not evidence of waste in our organization.** All six cases are invented. The script makes OTel traces and small summary metrics directly; it does not call Copilot, spend credits, or copy private sessions.

We are practicing three moves: notice a usage pattern, find its explanation in the trace, and ask what evidence we would need before changing anything.

## Start the demo

From the repository root, with Docker Desktop Kubernetes selected:

```sh
bash scripts/lab.sh doctor
bash scripts/viewer-setup.sh
tilt up --host 127.0.0.1 --stream
```

Leave Tilt running. In another terminal:

```sh
bash scripts/demo.sh
cat .local-lab/demo-links.md
```

Open the **[Agent cost investigation — SYNTHETIC DEMO dashboard](http://127.0.0.1:3000/d/agent-cost-demo)**. Select the run printed by the script and **All** scenarios. Each panel has one value per invented task. The demo-run filter prevents reruns from being added together.

The generator verifies every trace in Tempo, Phoenix and Langfuse before printing success, then checks all 42 metric series (seven measures for six cases) against the fixture totals. It records generated IDs and clickable links in `.local-lab/demo-links.md` and `.local-lab/demo-latest.json`. These are local, gitignored artifacts; they are the source of fresh links after every rerun.

Langfuse needs the generated local login described in the [setup guide](../guides/viewer-comparison.md). Phoenix is anonymous; choose project **copilot-lab**. The Grafana demo dashboard is separate from the bundled JVM/RED dashboards, which do not target Copilot.

## What each tool is good at

| Tool | Use it for this part of the conversation |
| --- | --- |
| Grafana demo dashboard | Spot which usage dimension changed across cases |
| Grafana Explore / Tempo | Inspect the original spans and attributes, without viewer enrichment |
| Phoenix | Follow the agent/model/tool tree and inspect individual call usage |
| Langfuse | Compare observations and sessions; start thinking about outcome labels/evaluations |

The `agent_demo_*` gauges are exact totals from the invented fixtures. **They are not production Copilot metrics or a billing dashboard.** On real CLI one-shots, process-local counters can reset/overlap; see [the metric caveats](../guides/generate-and-find-data.md#find-metrics-from-exited-one-shots).

## The six cases at a glance

| Scenario | Input tokens | Output tokens | Model calls | Agent invocations | Failed tools |
| --- | ---: | ---: | ---: | ---: | ---: |
| `baseline` | 10,000 | 500 | 2 | 1 | 0 |
| `context` | 160,000 | 1,100 | 4 | 1 | 0 |
| `output` | 10,000 | 9,000 | 2 | 1 | 0 |
| `retry` | 75,000 | 1,200 | 5 | 1 | 4 |
| `fanout` | 54,000 | 2,000 | 5 | 4 | 0 |
| `routing` | 10,000 | 500 | 2 | 1 | 0 |

Every case is labeled as the same invented small-fix task class. “Accepted” and “unknown” outcomes are **fixture labels**, not evaluations. Root/worker names and models (`demo-small`, `demo-large`) are made up. There is no real model rate card, Auto selection decision, prompt text or production benchmark here.

## 1. Start with a scoped fix

**Question:** What does a reasonably bounded interaction look like?

In [Grafana, select baseline](http://127.0.0.1:3000/d/agent-cost-demo?var-scenario=baseline): two model calls, 10,000 input tokens, 500 output tokens, one tool. This is our comparator, not a target every task must meet.

In **Phoenix**, open the baseline link from `demo-links.md`. Expand the `AGENT` root and its two `LLM` calls. The input values are 4,000 and 6,000. Their sum is consumption across calls; 10,000 is **not** the size of a single context window.

In **Langfuse**, open the matching trace. Inspect its `GENERATION` observations and the fixture outcome metadata. Ask what test or review would justify an accepted outcome on a real task. Trace status “OK” is not enough.

**Takeaway:** First establish a comparable successful task. Without that, a high number has no useful meaning.

## 2. Repeated broad context

**Question:** Are we repeatedly paying to send more context than this task needs?

In [Grafana, select context](http://127.0.0.1:3000/d/agent-cost-demo?var-scenario=context). Input rises to 160,000 while output stays fairly small. This is a different shape from a long answer.

In **Phoenix**, expand the four `LLM` calls. Inputs grow **8,000 -> 24,000 -> 48,000 -> 80,000**. Compare them with baseline. A real pattern like this could reflect broad retrieval, repeated history, task complexity, or caching differences. Tokens alone do not tell us which.

In **Langfuse**, look at call-by-call usage and model attributes rather than one rolled-up price. On real cached calls, distinguish uncached input, cache reads and cache creation. Record whether the extra context improved the result.

**Try next:** A narrower repository map/retrieval step or a task-state summary. Keep it only if the same required evidence and quality checks are preserved.

## 3. Verbose output

**Question:** Is the agent generating material the task does not need?

In [Grafana, select output](http://127.0.0.1:3000/d/agent-cost-demo?var-scenario=output). Input matches baseline, but output is 9,000 rather than 500.

In **Phoenix**, compare the two `LLM` completion counts (3,000 and 6,000) with baseline. This isolates output volume from context growth and extra agents.

In **Langfuse**, compare `GENERATION` usage and the fixture task outcome. Our metadata-only demo cannot say whether the text was useful. In a real pilot, ask the participant whether it was required, or use an approved output fixture.

**Try next:** A concise answer/output contract for that task class. Do not truncate necessary code, tests or explanations just to make the chart smaller.

## 4. Broken test harness retries

**Question:** Are we burning calls on an environment problem?

In [Grafana, select retry](http://127.0.0.1:3000/d/agent-cost-demo?var-scenario=retry). There are five model calls and four failed tool calls. The task's outcome is unknown, not accepted.

In **Phoenix**, inspect the error tool spans named `DEMO test command`. Their synthetic result metadata says `runner unavailable`. A trace tree turns “high input” into a concrete hypothesis: repeated setup failures.

In **Langfuse**, find the `TOOL` errors and inspect the nearby `GENERATION` observations. Ask whether an environment preflight would have prevented retries. Do not classify every retry as waste; some retries are good recovery.

**Try next:** Fix the runner/tool/auth path before coaching everyone to write better prompts. Compare a pinned preflight on the same task.

## 5. One prompt, several agents

**Question:** Did delegation make useful parallel progress, or duplicate work?

In [Grafana, select fanout](http://127.0.0.1:3000/d/agent-cost-demo?var-scenario=fanout). One task has four invocations: a coordinator and three workers. It has five model calls, not five user prompts.

In **Phoenix**, expand the worker `AGENT` children and their model calls. The parent relationships are explicit in this fixture. Compare the **22-second root wall time** with work across children; do not sum overlapping durations and call that elapsed time.

In **Langfuse**, open the same session/trace and compare the workers' observations. For real sessions, check which required deliverable each worker produced and whether scopes overlapped. A flatter tree can also reflect missing instrumentation, not missing work.

**Try next:** Clear, non-overlapping worker scopes, bounded fan-out, or a serial comparator. Fewer agents is not automatically better; parallel work can be worth the added consumption.

## 6. A larger resolved model

**Question:** Is this task using a model that is more capable than it needs?

In [Grafana, select routing](http://127.0.0.1:3000/d/agent-cost-demo?var-scenario=routing). Tokens and call counts match baseline. The resolved label is `demo-large` instead of `demo-small`. **No dollar comparison is shown**, because these are invented models.

In **Phoenix**, compare the model names on the `LLM` calls. In real captures, compare requested versus resolved model fields where both exist. Neither proves why Auto picked that model or what cheaper choice would have achieved.

In **Langfuse**, compare model and usage on the `GENERATION` observations. Ignore generic viewer cost estimates for Copilot billing. We need current GitHub usage terms and a controlled accepted-task comparison.

**Try next:** Run the same approved fixture with a fixed smaller configuration and compare acceptance/rework. A cheap first attempt that causes a repair loop may be more expensive overall.

## Direct links for the seeded October 5 demo

These **loopback** links open the fixture data seeded on this machine. They are not public telemetry links and will not work on another person's machine until that person generates their own data. After a Pod replacement or rerun, use the new local `demo-links.md`.

| Scenario | Phoenix trace | Langfuse trace |
| --- | --- | --- |
| baseline | [Open](http://127.0.0.1:6006/projects/UHJvamVjdDoy/spans/3770dd244e351cd73b5d9e7c98e0a90a?timeRangeKey=24h) | [Open](http://127.0.0.1:3001/project/copilot/traces/3770dd244e351cd73b5d9e7c98e0a90a) |
| context | [Open](http://127.0.0.1:6006/projects/UHJvamVjdDoy/spans/6ba4e8a5238b5485c12b102926541522?timeRangeKey=24h) | [Open](http://127.0.0.1:3001/project/copilot/traces/6ba4e8a5238b5485c12b102926541522) |
| output | [Open](http://127.0.0.1:6006/projects/UHJvamVjdDoy/spans/1e38a3092ef92e3f513b75bdc60e5a23?timeRangeKey=24h) | [Open](http://127.0.0.1:3001/project/copilot/traces/1e38a3092ef92e3f513b75bdc60e5a23) |
| retry | [Open](http://127.0.0.1:6006/projects/UHJvamVjdDoy/spans/62224d30bbcf309d6a075d41e85c3e11?timeRangeKey=24h) | [Open](http://127.0.0.1:3001/project/copilot/traces/62224d30bbcf309d6a075d41e85c3e11) |
| fanout | [Open](http://127.0.0.1:6006/projects/UHJvamVjdDoy/spans/fc3dc7cb01c701b5c23d6491e1802a7d?timeRangeKey=24h) | [Open](http://127.0.0.1:3001/project/copilot/traces/fc3dc7cb01c701b5c23d6491e1802a7d) |
| routing | [Open](http://127.0.0.1:6006/projects/UHJvamVjdDoy/spans/ff17aec8d119149a5084ded0c4478d6d?timeRangeKey=24h) | [Open](http://127.0.0.1:3001/project/copilot/traces/ff17aec8d119149a5084ded0c4478d6d) |

## Finish the tour with one decision

Pick one case. Write **one hypothesis**, the **evidence that could disprove it**, and **one tooling change** to test. If the next step is “ask everyone to use fewer tokens,” we probably have not found a concrete problem yet.

The seeded scenarios teach you what to look for. The [pattern guide](catalog.md), [improvement loop](improvement-loop.md) and [agent analysis prompts](agent-analysis.md) turn that into a pilot. The [reading digest](../reference/cost-research.md) connects these ideas to Uber's cost-driver framework and other published evidence.
