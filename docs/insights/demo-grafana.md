# Read the demo in Grafana

**Start with the dashboard to spot a difference, then use a trace to investigate it.** The dashboard gives one total per invented task; Tempo holds the individual operations behind that task. Those are different views of the same fixture.

Read [the model-call guide](../foundations/model-calls.md) for the difference between input size per call, usage across calls and agent activity.

## Get to the dashboard

1. Open **[Agent cost investigation - SYNTHETIC DEMO](http://127.0.0.1:3000/d/agent-cost-demo)**. If you start on Grafana's home page, use **Dashboards** and find that title. Do not use the bundled JVM/RED dashboards.
2. Set the dashboard time range to include the run, such as **Last 24 hours** for a fresh demo. Choose the **demo_run** printed by `bash scripts/demo.sh`; do not combine different runs when comparing cases.
3. Choose **All** scenarios for a side-by-side comparison, or select one **scenario** to inspect it alone. The seven data panels show input, output, model calls, agent invocations, tool calls, failed tools and wall seconds.

These are synthetic `agent_demo_*` gauges with exact fixture totals. They are not a real Copilot billing dashboard. The panels use the last recorded value in the selected time range, not a sum of repeatedly exported counters.

Scenario links below select a scenario but leave you to choose the run/time range. `.local-lab/demo-links.md` has fresh links that select your run too. All tool links are local to the computer where the lab runs.

## Open the original trace

1. Open **[Grafana Explore](http://127.0.0.1:3000/explore)** and select **Tempo** as the data source.
2. Choose **Trace ID** query mode, paste the scenario's trace ID from `.local-lab/demo-links.md` and run it. This avoids guessing between similarly named runs.
3. Open a span in the timeline to see its attributes. Read `gen_ai.operation.name`: `invoke_agent` is agent work, `chat` is a model call, and `execute_tool` is a tool call.
4. On `chat` spans, look for `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`, `gen_ai.request.model` and `gen_ai.response.model`. Real calls can also have cache attributes. The raw branch does not add Phoenix/Langfuse field names.

To browse instead, choose a time range containing the run and use TraceQL:

```text
{ resource.service.name = "agent-cost-demo" }
```

Open a result and confirm `agent_analytics.demo.scenario` and `agent_analytics.demo.run` in its attributes. Prometheus/PromQL is for metric samples; Tempo/TraceQL is for traces.

## Baseline

**[Open baseline in the dashboard](http://127.0.0.1:3000/d/agent-cost-demo?var-scenario=baseline)**.

Read **10,000 input**, **500 output**, **2 model calls**, **1 agent**, **1 tool**, **0 failed tools**, **8 wall seconds**. Then open the baseline trace in Tempo. Select its two `chat` spans: input is **4,000 / 6,000**, output is **200 / 300**.

**Say:** “The dashboard gives the task total. The trace explains how that total was built from individual model calls.”

Do not call the input total one context-window size. Do not add usage from an agent rollup to its child model-call usage.

[Back to the scenario](demo.md#1-start-with-a-scoped-fix) · [Phoenix](demo-phoenix.md#baseline) · [Langfuse](demo-langfuse.md#baseline)

## Context

**[Open context in the dashboard](http://127.0.0.1:3000/d/agent-cost-demo?var-scenario=context)**.

Compare **160,000 input / 1,100 output / 4 calls** with baseline. In Tempo, the four `chat` spans report **8,000 -> 24,000 -> 48,000 -> 80,000** input tokens.

**Say:** “Input is growing call by call. This is where we would investigate retrieval and history, rather than assuming the answer got too long.”

No cache fields exist in this fixture. Real cache usage is a separate measurement; neither it nor total input identifies which skill, file or tool supplied the text. See [input components and the attribution gap](../foundations/model-calls.md#what-goes-into-the-input).

[Back to the scenario](demo.md#2-repeated-broad-context) · [Phoenix](demo-phoenix.md#context) · [Langfuse](demo-langfuse.md#context)

## Output

**[Open output in the dashboard](http://127.0.0.1:3000/d/agent-cost-demo?var-scenario=output)**.

Input and model-call count match baseline, but output is **9,000**, not **500**. In Tempo, output on the two `chat` spans is **3,000 / 6,000**.

**Say:** “The extra consumption is output. We would next check whether the task required that much generated material.”

The dashboard has no content or quality evaluation. **24 wall seconds** is fixture duration, not a streaming responsiveness measurement or engineer time.

[Back to the scenario](demo.md#3-verbose-output) · [Phoenix](demo-phoenix.md#output) · [Langfuse](demo-langfuse.md#output)

## Retry

**[Open retry in the dashboard](http://127.0.0.1:3000/d/agent-cost-demo?var-scenario=retry)**.

Read **5 model calls**, **5 tool calls**, **4 failed tools** and **75,000 input**. In Tempo, open **DEMO test command 1** through **4**: error status and `agent_analytics.demo.tool_result=runner unavailable`. Command **5** says `passed`.

**Say:** “The chart tells us where to look; the tool attributes give us a specific harness problem to test.”

The task's outcome remains unknown. One tool eventually passing is not the same as accepting a fix.

[Back to the scenario](demo.md#4-broken-test-harness-retries) · [Phoenix](demo-phoenix.md#retry) · [Langfuse](demo-langfuse.md#retry)

## Fanout

**[Open fanout in the dashboard](http://127.0.0.1:3000/d/agent-cost-demo?var-scenario=fanout)**.

Read **4 agent invocations**, **5 model calls**, **54,000 input** and **22 wall seconds**. In Tempo, find the three **DEMO worker** agent spans and their child `chat` spans. Each worker's model call takes **10,000 input**; the coordinator's calls take **6,000** and **18,000**.

**Say:** “Delegation changes the amount and shape of work behind one user request. It can buy parallel progress, but we need outcomes to judge that tradeoff.”

The dashboard's wall time is the root duration, not the sum of worker durations. More agent calls alone is not evidence of waste.

[Back to the scenario](demo.md#5-one-prompt-several-agents) · [Phoenix](demo-phoenix.md#fanout) · [Langfuse](demo-langfuse.md#fanout)

## Routing

**[Open routing in the dashboard](http://127.0.0.1:3000/d/agent-cost-demo?var-scenario=routing)**.

Input, output and call count match baseline. In Tempo, the `chat` spans' model attributes say **demo-large** instead of **demo-small**. The dashboard does not calculate a dollar difference.

**Say:** “Same token counts, different model identity. This is a comparison to investigate, not proof a cheaper configuration would work.”

The fixture has no Auto decision or real prices. For real Copilot usage, reconcile financial claims with billing and current plan terms.

[Back to the scenario](demo.md#6-a-larger-resolved-model) · [Phoenix](demo-phoenix.md#routing) · [Langfuse](demo-langfuse.md#routing)

## What if the panels are blank?

Check the selected run and time range, then confirm you generated the demo after the latest LGTM Pod replacement. An empty result means no matching samples in that window, not zero usage.

For real CLI traces, use service **github-copilot-local**, not **agent-cost-demo**. The demo dashboard does not chart native CLI sessions. Follow [real CLI data and historical metric queries](../guides/generate-and-find-data.md#grafana-why-the-bundled-dashboards-are-empty); one-shot counters can reset or overlap and cannot be summed like these fixture totals.
