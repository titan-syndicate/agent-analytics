# A hands-on tour: where could Copilot usage go?

We want to explain what drives Copilot usage before we try to reduce it. This demo gives us six small, invented cases to practice on. **It is not evidence of waste in our organization.** The generator makes traces and summary metrics directly: no Copilot calls, credits or private session history.

**Start with [how a user request becomes model calls](../foundations/model-calls.md).** That page explains input, output, model selection and cached input, then connects them to agents, tools, traces and spans. It also explains the gap between measuring input size and knowing what contributed to it.

This page describes the scenarios. Each scenario links to a separate walkthrough for **[Grafana](demo-grafana.md)**, **[Phoenix](demo-phoenix.md)** and **[Langfuse](demo-langfuse.md)**. Those pages start with navigation, so you do not need to know the tools already.

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

The generator checks every trace in all three stores and checks all 42 metric series against the fixture totals. It writes fresh tool links and trace IDs to `.local-lab/demo-links.md` and `.local-lab/demo-latest.json`.

**Local links open services on your computer, not on GitHub Pages.** The tool guides include links to the October 5 seed on our running lab. Someone else's lab needs its own generated links. A Pod replacement erases that backend's data; rerun the generator and use the new local link file. See the [setup guide](../guides/viewer-comparison.md) for credentials and storage limits.

## What each tool adds

| Tool | Start with this question | Walkthrough |
| --- | --- | --- |
| [Grafana](http://127.0.0.1:3000/d/agent-cost-demo) | Which usage dimension changed? Then inspect original span attributes in Tempo | [Dashboard and raw traces](demo-grafana.md) |
| [Phoenix](http://127.0.0.1:6006) | What calls and tools made up this interaction? | [Find and read an agent tree](demo-phoenix.md) |
| [Langfuse](http://127.0.0.1:3001) | How do the individual operations, usage and outcome labels compare? | [Find and read observations](demo-langfuse.md) |

They show the **same underlying work**, not three independent confirmations of quality. A span is one recorded operation. Phoenix calls model spans `LLM`; Langfuse calls them `GENERATION`. Neither can tell us a task was correct without tests, review or other outcome evidence.

## The six cases at a glance

| Scenario | Input tokens across calls | Output tokens across calls | Model calls | Agent invocations | Failed tools |
| --- | ---: | ---: | ---: | ---: | ---: |
| `baseline` | 10,000 | 500 | 2 | 1 | 0 |
| `context` | 160,000 | 1,100 | 4 | 1 | 0 |
| `output` | 10,000 | 9,000 | 2 | 1 | 0 |
| `retry` | 75,000 | 1,200 | 5 | 1 | 4 |
| `fanout` | 54,000 | 2,000 | 5 | 4 | 0 |
| `routing` | 10,000 | 500 | 2 | 1 | 0 |

All are labeled as the same invented small-fix task class. Models (`demo-small`, `demo-large`) and outcome labels are made up. **No case has cache usage, message content, streaming measurements or a real price.** The totals show consumption across calls, not unique context or one context-window size.

## 1. Start with a scoped fix

**Question: What does a bounded interaction look like?**

The baseline has two model calls and one tool call. Input is 4,000 then 6,000 tokens; output is 200 then 300. Use it to learn the view before comparing a bigger number. It is a comparator, not a target every task must meet.

Walk through it in **[Grafana](demo-grafana.md#baseline)**, **[Phoenix](demo-phoenix.md#baseline)** or **[Langfuse](demo-langfuse.md#baseline)**.

**What to say:** “Here is one agent invocation containing several operations. The 10,000 input tokens are the sum of two model calls, not the size of one prompt.”

## 2. Repeated broad context

**Question: Why does the input get bigger on each call?**

The four calls take 8,000, 24,000, 48,000 and 80,000 input tokens. Output stays relatively small. In real work, this could be growing history, broad retrieval or necessary task context. The totals do not tell us which, and our fixture has no cache breakdown.

Walk through it in **[Grafana](demo-grafana.md#context)**, **[Phoenix](demo-phoenix.md#context)** or **[Langfuse](demo-langfuse.md#context)**.

**Try next:** Narrower retrieval or a task-state summary on a comparable task. Preserve the evidence the agent needs. Use the [input-component guide](../foundations/model-calls.md#what-goes-into-the-input) to decide what we would need to measure before blaming a skill or tool.

## 3. Verbose output

**Question: Is the agent generating more than this task needs?**

Input and call count match baseline, but output jumps from 500 to 9,000 tokens. That separates output growth from growing context. Without the actual answer or an outcome check, we cannot tell whether the extra output helped.

Walk through it in **[Grafana](demo-grafana.md#output)**, **[Phoenix](demo-phoenix.md#output)** or **[Langfuse](demo-langfuse.md#output)**.

**Try next:** A clear, concise output contract. Keep necessary code, tests and explanations; the goal is a useful result, not just a smaller bar.

## 4. Broken test harness retries

**Question: Are extra calls coming from an environment problem?**

This case has five model calls and four failed tool calls. The tool metadata says `runner unavailable`; the fixture outcome is unknown. That gives us a concrete lead before asking people to change their prompts.

Walk through it in **[Grafana](demo-grafana.md#retry)**, **[Phoenix](demo-phoenix.md#retry)** or **[Langfuse](demo-langfuse.md#retry)**.

**Try next:** Fix or preflight the runner. Some retries are useful recovery; test whether this specific failure loop is avoidable.

## 5. One prompt, several agents

**Question: Did delegation help, or duplicate work?**

More precisely, this is **one user request with several agent invocations**: a coordinator and three workers. Together they make five model calls. The root takes 22 seconds; adding overlapping worker durations would not give elapsed time.

Walk through it in **[Grafana](demo-grafana.md#fanout)**, **[Phoenix](demo-phoenix.md#fanout)** or **[Langfuse](demo-langfuse.md#fanout)**.

**Try next:** Give workers distinct deliverables and compare with a serial approach. This fixture shows the hierarchy, not the contents or usefulness of each worker's result.

## 6. A larger resolved model

**Question: Could a smaller model complete this task just as well?**

Tokens and call count match baseline; only the model label and duration differ. `demo-large` is an invented label, not a real rate or an Auto decision.

Walk through it in **[Grafana](demo-grafana.md#routing)**, **[Phoenix](demo-phoenix.md#routing)** or **[Langfuse](demo-langfuse.md#routing)**.

**Try next:** Compare fixed model choices on approved tasks, including acceptance and rework. A cheaper first call can still lead to a more expensive repair loop. A resolved model name alone does not explain why Auto chose it.

## Finish the tour with one decision

Pick a case. Write one hypothesis, what could disprove it, and one tooling change to test. “Ask everyone to use fewer tokens” is too broad; “preflight this failing runner” is something we can try and measure.

Continue with the [pattern guide](catalog.md), [improvement loop](improvement-loop.md), [agent-analysis prompts](agent-analysis.md) or [reading digest](../reference/cost-research.md). The aim is to turn a usage pattern into a better workflow, not an engineer score.
