# Read the demo in Phoenix

**Phoenix is our view of the agent's work as a tree.** Start with one interaction, click its model calls and tools, and read the usage for each call. You do not need to understand evaluations or build a dashboard for this tour.

Keep the [model-call guide](../foundations/model-calls.md) handy: `AGENT` is the work being coordinated, `LLM` is one model call, and `TOOL` is one tool execution. A row in the tree is a **span**, not necessarily a user message.

## Get to the trace

1. Open **[Phoenix](http://127.0.0.1:6006)**. Choose **Projects**, then **copilot-lab**. The `default` project is not where our Collector sends these traces.
2. Open the project's **Traces** view. Set the time range to include your demo run, such as the last 24 hours for a fresh run, and clear unrelated filters. The **Spans** view lists individual operations; **Traces** is the easier starting point for a whole interaction.
3. Open the row named for your scenario, such as **DEMO A scoped fix**. If several runs have the same name, use the scenario's direct Phoenix link in `.local-lab/demo-links.md`. Compare the trace ID rather than guessing which row is newest.
4. In the trace detail view, find the tree of operation names. Click a row to select it and show that span's details. Use the disclosure arrow beside a parent to show hidden children; if they are already visible, there is nothing to expand.
5. For a model-call row, open **Attributes** in the details pane. Find `llm.model_name`, `llm.token_count.prompt` and `llm.token_count.completion`. “Prompt” here means model input, not just the text you typed.

The links below target the October 5 seed in our local lab. They open on **your computer**, not a public Phoenix instance. If a link is empty or fails after a reset, generate data again and use your fresh link file. A different lab can have a different project ID. See [setup and credentials](../guides/viewer-comparison.md).

## Baseline

**[Open the seeded baseline trace](http://127.0.0.1:6006/projects/UHJvamVjdDoy/spans/6c37acef04e65a7d54160e8f67de2a71?timeRangeKey=24h)**, or follow the navigation above and choose **DEMO A scoped fix**.

Here is what “expand the agent root” means. The top row, **DEMO A scoped fix**, represents the whole agent invocation. Its children represent operations inside it:

```text
DEMO A scoped fix                   AGENT: the whole invocation
    DEMO model call 1               LLM: input 4,000 / output 200
    DEMO model call 2               LLM: input 6,000 / output 300
    DEMO test command 1             TOOL: synthetic test operation
```

1. Select **DEMO model call 1**, not the top agent row. Open **Attributes**. Confirm prompt tokens **4,000**, completion tokens **200**, and model **demo-small**.
2. Select **DEMO model call 2**. Confirm **6,000** input and **300** output.
3. Select **DEMO test command 1**. Look for `gen_ai.tool.name=demo-test-runner` and `agent_analytics.demo.tool_result=passed`.

The tree may order rows by start time; the sketch above groups them by purpose. It is not claiming the fixture's tool/model timing reproduces a real agent loop.

**Say in the demo:** “Two model calls consumed 10,000 input tokens in total. This tree helps us see the operations behind that total. It does not show 10,000 unique tokens or prove the fix was good.”

Do not expect token fields on the root or the tool: this fixture puts usage on model calls. The Input/Output content panels are intentionally empty. The `accepted (fixture)` attribute is an invented label, not a test result.

[Back to the scenario](demo.md#1-start-with-a-scoped-fix) · [Compare in Grafana](demo-grafana.md#baseline) · [Compare in Langfuse](demo-langfuse.md#baseline)

## Context

**[Open the seeded context trace](http://127.0.0.1:6006/projects/UHJvamVjdDoy/spans/e8367ef54039121cfa20dd1bee4d60d5?timeRangeKey=24h)**. The root is **DEMO Repeated broad context**.

Select **DEMO model call 1** through **4** in turn. In **Attributes**, read `llm.token_count.prompt`: **8,000 -> 24,000 -> 48,000 -> 80,000**. Their completion counts are **250, 250, 300, 300**. The model stays `demo-small`.

**Say:** “The growth is in input, not a much longer answer. We would now ask what was added between calls.”

The tool spans give structural clues, but this fixture does not say which files or tool results contributed those tokens. It also has no cache fields. On a real `LLM` span, look in **Attributes** for the original `gen_ai.usage.cache_read.input_tokens` and `gen_ai.usage.cache_creation.input_tokens`; Phoenix's inclusive prompt count alone is not a cache breakdown.

Use the [input-component explanation](../foundations/model-calls.md#what-goes-into-the-input) before calling this “skill overhead” or “wasted context.”

[Back to the scenario](demo.md#2-repeated-broad-context) · [Grafana](demo-grafana.md#context) · [Langfuse](demo-langfuse.md#context)

## Output

**[Open the seeded output trace](http://127.0.0.1:6006/projects/UHJvamVjdDoy/spans/e4008f6921c86a3d901b3b25d558bdbd?timeRangeKey=24h)**. The root is **DEMO Verbose output**.

Select the two **DEMO model call** rows. Input is still **4,000 / 6,000**, while `llm.token_count.completion` is **3,000 / 6,000**. Compare with baseline's **200 / 300**. There are no extra model calls or workers to explain the difference.

**Say:** “This isolates output volume. We still need an outcome check to decide whether that output was useful.”

There is no answer text to read here. Nor do these spans contain time-to-first-chunk measurements: their durations cannot tell us how quickly a streamed answer began.

[Back to the scenario](demo.md#3-verbose-output) · [Grafana](demo-grafana.md#output) · [Langfuse](demo-langfuse.md#output)

## Retry

**[Open the seeded retry trace](http://127.0.0.1:6006/projects/UHJvamVjdDoy/spans/ba8fa99a0f5d32c837b94c6aa04fe53f?timeRangeKey=24h)**. The root is **DEMO Broken test harness retries**.

Select **DEMO test command 1** through **4**. Each tool span has an error status; in **Attributes**, `agent_analytics.demo.tool_result` says **runner unavailable**. Command **5** says **passed**. There are five model-call rows, with input **6,000, 9,000, 14,000, 20,000, 26,000**.

**Say:** “Now we have a candidate explanation for extra work: the runner kept failing. We should test a preflight before asking everyone to shorten their prompts.”

The fixture encodes the failure pattern; it does not prove causality from its timeline. The task outcome is `unknown (fixture)`, even though the last tool passed. A passing tool is not task acceptance.

[Back to the scenario](demo.md#4-broken-test-harness-retries) · [Grafana](demo-grafana.md#retry) · [Langfuse](demo-langfuse.md#retry)

## Fanout

**[Open the seeded fan-out trace](http://127.0.0.1:6006/projects/UHJvamVjdDoy/spans/a86558dd71762af330493881669df7e8?timeRangeKey=24h)**. The root is **DEMO One prompt, several agents**.

Find **DEMO worker 1**, **2** and **3** beneath the root. These are agent spans, not tools. Show their children if collapsed; each worker has an `LLM` model call with **10,000 input** tokens. The coordinator also has model calls **1** and **5**, with **6,000** and **18,000** input tokens. Together that is five calls and **54,000** input tokens.

**Say:** “One user request spread work across four agents. The hierarchy tells us who called whom; it does not tell us whether their scopes overlapped.”

Select the root to inspect its **22-second** duration. Worker intervals overlap; adding their durations does not give elapsed time. Our fixture places the tool spans under the coordinator, so do not expect one tool nested inside each worker.

[Back to the scenario](demo.md#5-one-prompt-several-agents) · [Grafana](demo-grafana.md#fanout) · [Langfuse](demo-langfuse.md#fanout)

## Routing

**[Open the seeded routing trace](http://127.0.0.1:6006/projects/UHJvamVjdDoy/spans/9b09adf01403f737a106184ec1605903?timeRangeKey=24h)**. The root is **DEMO Larger resolved model**.

Select each model-call row. In **Attributes**, `llm.model_name` is **demo-large**, while input/output counts match baseline. Compare `gen_ai.request.model` and `gen_ai.response.model`: both are `demo-large` in this fixture. There is no Auto decision to inspect.

**Say:** “This shows where to find model identity. In real work, we could compare model choices on the same accepted task. This trace alone cannot tell us what another model would do.”

Do not use a viewer's generic dollar estimate as Copilot billing. These invented models have no rate card.

[Back to the scenario](demo.md#6-a-larger-resolved-model) · [Grafana](demo-grafana.md#routing) · [Langfuse](demo-langfuse.md#routing)

## If the view does not look like this

If you see a table of individual spans, open a row to get the trace tree; the table is not itself the tree. If you only see the agent row, show its children. If fields are missing, check that you selected an `LLM` row and are reading **Attributes**, not looking for message text.

No data? Check **copilot-lab**, the time range, and the fresh trace link in `.local-lab/demo-links.md`. A direct link cannot recover data erased by a Pod replacement. See [missing-data diagnosis](../guides/generate-and-find-data.md#diagnose-missing-data-in-order).

Navigation labels can change between Phoenix versions; this lab pins **20.19.0**. The reliable identifiers are the project, trace ID, operation names and attributes above.
